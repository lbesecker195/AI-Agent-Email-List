defmodule EmailProvider.Routes do
  @moduledoc """
  Inbound routing: match an incoming message, then act on it.

  Expressions:

      match_recipient("^support@example\\.com$")
      match_header("subject", "invoice")
      catch_all()

  Actions:

      forward("https://hooks.example.com/inbound")
      store()
      stop()

  Routes run highest priority first and stop at the first `stop()`.

  Patterns are customer-supplied and compiled at match time rather than
  interpolated into a literal, so a pattern is only ever data. They are length
  capped: `:re` has no backtracking budget, and an unbounded pattern on
  attacker-influenced subject lines is a way to burn a scheduler thread.
  """

  import Ecto.Query, warn: false
  require Logger

  alias EmailProvider.Repo
  alias EmailProvider.Accounts.User
  alias EmailProvider.Domains.Domain
  alias EmailProvider.Mail.Message
  alias EmailProvider.Routes.Route

  @max_pattern_length 512

  def list(%User{id: id}) do
    Repo.all(
      from r in Route, where: r.user_id == ^id, order_by: [desc: r.priority, asc: r.inserted_at]
    )
  end

  def get(%User{id: id}, route_id) do
    Repo.one(from r in Route, where: r.user_id == ^id and r.id == ^route_id)
  end

  def create(%User{id: id}, attrs) do
    %Route{}
    |> Route.changeset(%{
      user_id: id,
      priority: to_int(attrs["priority"], 0),
      description: attrs["description"],
      expression: attrs["expression"],
      actions: List.wrap(attrs["action"] || attrs["actions"])
    })
    |> Repo.insert()
  end

  def update(%Route{} = route, attrs) do
    params =
      %{}
      |> maybe_put(:priority, attrs["priority"] && to_int(attrs["priority"], route.priority))
      |> maybe_put(:description, attrs["description"])
      |> maybe_put(:expression, attrs["expression"])
      |> maybe_put(:actions, attrs["action"] && List.wrap(attrs["action"]))

    route |> Route.changeset(params) |> Repo.update()
  end

  def delete(%Route{} = route), do: Repo.delete(route)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp to_int(nil, default), do: default

  defp to_int(value, default) do
    case Integer.parse(to_string(value)) do
      {int, _} -> int
      :error -> default
    end
  end

  @doc "Run a domain owner's routes against an inbound message."
  def run(%Domain{user_id: user_id}, %Message{} = message) do
    %User{id: user_id}
    |> list()
    |> Enum.filter(& &1.enabled)
    |> Enum.reduce_while([], fn route, applied ->
      if matches?(route, message) do
        case apply_actions(route, message) do
          :stop -> {:halt, applied ++ [route.id]}
          :continue -> {:cont, applied ++ [route.id]}
        end
      else
        {:cont, applied}
      end
    end)
  end

  @doc "Does this route's expression match the message?"
  def matches?(%Route{expression: expression}, %Message{} = message) do
    cond do
      Regex.match?(~r/^\s*catch_all\s*\(\s*\)/, expression) ->
        true

      captures = Regex.run(~r/^\s*match_recipient\s*\(\s*"(.*)"\s*\)\s*$/s, expression) ->
        [_, pattern] = captures
        Enum.any?(message.recipients, &matches_pattern?(pattern, &1))

      captures = Regex.run(~r/^\s*match_header\s*\(\s*"(.*?)"\s*,\s*"(.*)"\s*\)\s*$/s, expression) ->
        [_, name, pattern] = captures
        matches_pattern?(pattern, header_value(message, name))

      true ->
        Logger.warning("unrecognised route expression: #{inspect(expression)}")
        false
    end
  end

  defp header_value(%Message{} = message, name) do
    case String.downcase(name) do
      "subject" ->
        message.subject || ""

      "from" ->
        message.sender || ""

      "to" ->
        Enum.join(message.recipients, ", ")

      other ->
        message.headers
        |> Enum.find_value("", fn {k, v} -> if String.downcase(k) == other, do: v end)
    end
  end

  defp matches_pattern?(pattern, _value) when byte_size(pattern) > @max_pattern_length do
    Logger.warning("route pattern over #{@max_pattern_length} bytes; refusing to run it")
    false
  end

  defp matches_pattern?(pattern, value) do
    case Regex.compile(unescape(pattern), "i") do
      {:ok, regex} -> Regex.match?(regex, to_string(value))
      {:error, _} -> false
    end
  end

  # The expression arrives as a quoted string, so \" and \\ are escaped in it.
  defp unescape(pattern) do
    pattern |> String.replace("\\\"", "\"") |> String.replace("\\\\", "\\")
  end

  defp apply_actions(%Route{actions: actions}, %Message{} = message) do
    Enum.reduce_while(actions, :continue, fn action, _acc ->
      cond do
        Regex.match?(~r/^\s*stop\s*\(/, action) ->
          {:halt, :stop}

        captures = Regex.run(~r/^\s*forward\s*\(\s*"(.*)"\s*\)\s*$/s, action) ->
          [_, target] = captures
          forward(target, message)
          {:cont, :continue}

        Regex.match?(~r/^\s*store\s*\(/, action) ->
          # Every inbound message is already stored; this exists so a route
          # reads the same as the Mailgun one it was copied from.
          {:cont, :continue}

        true ->
          Logger.warning("unrecognised route action: #{inspect(action)}")
          {:cont, :continue}
      end
    end)
  end

  defp forward(target, %Message{} = message) do
    if String.starts_with?(target, "http://") or String.starts_with?(target, "https://") do
      Task.Supervisor.start_child(EmailProvider.TaskSupervisor, fn ->
        body = %{
          recipient: List.first(message.recipients),
          sender: message.sender,
          subject: message.subject,
          "body-plain": message.body_text,
          "body-html": message.body_html,
          "message-id": message.rfc_message_id,
          "storage-key": message.storage_key
        }

        case Req.post(target,
               json: body,
               receive_timeout: 10_000,
               retry: :transient,
               max_retries: 2
             ) do
          {:ok, %{status: status}} when status in 200..299 ->
            :ok

          {:ok, %{status: status}} ->
            Logger.warning("route forward to #{target} returned #{status}")

          {:error, reason} ->
            Logger.warning("route forward to #{target} failed: #{inspect(reason)}")
        end
      end)
    else
      # Forwarding to an address would mean relaying mail to a destination the
      # customer named. That needs its own authorization story, so it is not
      # silently treated as a URL.
      Logger.warning("forward() to a non-URL target is not supported: #{inspect(target)}")
    end

    :ok
  end
end
