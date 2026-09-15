defmodule EmailProviderWeb.MCP.Tools do
  @moduledoc """
  The tools this service exposes over MCP.

  ## Why one of them needs no credentials

  `create_account` is deliberately unauthenticated. An agent that has just
  discovered this server has nothing: no key, no account, and no human to go and
  get one. Every other transactional email provider stops exactly there, behind
  a credit card or an identity check, which is the reason an agent cannot use
  them at all. Letting an agent mint its own account is the entire point of this
  service, so it is the one tool that must work from a cold start.

  Everything else takes the API key that call returns.

  ## Descriptions are part of the interface

  A tool description is not documentation, it is the prompt an agent reads
  before deciding what to call. Each one below says what the tool does, what it
  costs against the daily allowance, and what it will refuse, because an agent
  that learns "domains must be verified first" from a description makes one call
  instead of three and a failure.
  """

  alias EmailProvider.{Accounts, Domains, Mail, RateLimit, Reputation, Warmup}

  @doc "Every tool, in the shape `tools/list` returns."
  def list do
    Enum.map(catalog(), fn tool ->
      %{
        name: tool.name,
        description: tool.description,
        inputSchema: tool.schema
      }
    end)
  end

  @doc "True when a tool can be called without an API key."
  def public?(name), do: Enum.any?(catalog(), &(&1.name == name and &1.public))

  def known?(name), do: Enum.any?(catalog(), &(&1.name == name))

  @doc """
  Run a tool.

  Returns `{:ok, text}` or `{:error, text}`. Both come back to the agent as tool
  content; an error is not a protocol failure, it is a result the agent should
  read and act on.
  """
  def call(name, args, context) do
    case Enum.find(catalog(), &(&1.name == name)) do
      nil -> {:error, "No tool named #{name}. Call tools/list to see what exists."}
      tool -> tool.run.(args || %{}, context)
    end
  end

  # -- the catalog ---------------------------------------------------------

  defp catalog do
    [
      %{
        name: "create_account",
        public: true,
        description:
          "Create an account on this email service and get an API key back. Needs no " <>
            "existing credentials, so an agent with nothing can call this first. The key is " <>
            "returned once and never again. Free, with no card and no trial clock.",
        schema: %{
          type: "object",
          properties: %{
            email: %{type: "string", description: "A contact address for the account."},
            password: %{
              type: "string",
              description: "At least 12 characters. Needed only to sign in to the web console."
            },
            name: %{type: "string", description: "Optional display name."}
          },
          required: ["email", "password"]
        },
        run: &create_account/2
      },
      %{
        name: "list_domains",
        public: false,
        description:
          "List the sending domains on this account, with their verification state and " <>
            "how much of today's sending allowance each has left.",
        schema: %{type: "object", properties: %{}},
        run: &list_domains/2
      },
      %{
        name: "add_domain",
        public: false,
        description:
          "Register a domain to send from, and get the DNS records that must be published " <>
            "before it will work. Publishing DNS usually needs a human with registrar " <>
            "access, so start this early. The domain cannot send until verify_domain succeeds.",
        schema: %{
          type: "object",
          properties: %{
            name: %{
              type: "string",
              description:
                "A bare domain such as mail.yourcompany.com. A subdomain is better than the root."
            }
          },
          required: ["name"]
        },
        run: &add_domain/2
      },
      %{
        name: "verify_domain",
        public: false,
        description:
          "Re-read DNS now and mark the domain active if its SPF and DKIM records are " <>
            "visible. DNS takes minutes to hours to propagate; poll this every few minutes, " <>
            "not every few seconds.",
        schema: %{
          type: "object",
          properties: %{name: %{type: "string"}},
          required: ["name"]
        },
        run: &verify_domain/2
      },
      %{
        name: "send_email",
        public: false,
        description:
          "Send a message. The domain must be verified and the from address must belong " <>
            "to it. Counts one against the daily allowance per recipient. Set test_mode " <>
            "true to run the whole pipeline, including content screening, without sending " <>
            "anything and without spending allowance — do that first when building.",
        schema: %{
          type: "object",
          properties: %{
            domain: %{type: "string", description: "The verified domain to send from."},
            from: %{type: "string", description: "An address at that domain."},
            to: %{type: "string", description: "One address, or several separated by commas."},
            subject: %{type: "string"},
            text: %{type: "string", description: "Plain text body."},
            html: %{type: "string", description: "Optional HTML body."},
            test_mode: %{
              type: "boolean",
              description: "Accept and screen the message but send nothing. Defaults to false."
            }
          },
          required: ["domain", "from", "to"]
        },
        run: &send_email/2
      },
      %{
        name: "get_sending_limits",
        public: false,
        description:
          "How much this domain may send today and what graduates it to the next rung, plus " <>
            "this account's standing: how many domains it may hold and whether sending is " <>
            "paused. New domains start at a low daily cap and climb as they prove themselves, " <>
            "so check this before planning a bulk send rather than discovering it part-way. " <>
            "Call it with no domain for the account-level answer alone.",
        schema: %{
          type: "object",
          properties: %{
            domain: %{
              type: "string",
              description: "Optional. Omit for account limits without a domain's allowance."
            }
          }
        },
        run: &get_limits/2
      },
      %{
        name: "list_messages",
        public: false,
        description:
          "Recent messages for a domain, sent and received. Use direction to filter, and " <>
            "folder to separate inbox from spam on received mail.",
        schema: %{
          type: "object",
          properties: %{
            domain: %{type: "string"},
            direction: %{type: "string", enum: ["outbound", "inbound"]},
            folder: %{type: "string", enum: ["inbox", "spam"]},
            limit: %{type: "integer", description: "Up to 100. Defaults to 25."}
          },
          required: ["domain"]
        },
        run: &list_messages/2
      },
      %{
        name: "get_delivery_events",
        public: false,
        description:
          "What happened to messages on this domain: accepted, delivered, failed, and so " <>
            "on. A send returning success means queued, not delivered; this is where the " <>
            "delivery outcome actually appears.",
        schema: %{
          type: "object",
          properties: %{
            domain: %{type: "string"},
            event: %{
              type: "string",
              description: "Filter to one type, such as delivered or failed."
            },
            recipient: %{type: "string"},
            limit: %{type: "integer"}
          },
          required: ["domain"]
        },
        run: &get_events/2
      }
    ]
  end

  # -- handlers ------------------------------------------------------------

  defp create_account(args, context) do
    with {:ok, email} <- required(args, "email"),
         {:ok, password} <- required(args, "password"),
         :ok <- signup_allowed(context) do
      case Accounts.register_user(%{
             email: email,
             name: Map.get(args, "name"),
             password: password
           }) do
        {:ok, user} ->
          {:ok, _key, plaintext} = Accounts.create_api_key(user, label: "mcp")

          {:ok,
           """
           Account created for #{user.email}.

           API key (shown once, store it now): #{plaintext}

           Send it as `Authorization: Bearer <key>` on every later call to this
           server. Next: add_domain, publish the DNS records it returns, then
           verify_domain.
           """}

        {:error, changeset} ->
          {:error, "Could not create the account: " <> changeset_errors(changeset)}
      end
    end
  end

  defp list_domains(_args, %{user: user}) do
    case Domains.list_domains(user) do
      [] ->
        {:ok, "No domains yet. Call add_domain to register one."}

      domains ->
        {:ok,
         Enum.map_join(domains, "\n", fn domain ->
           limits = Warmup.status(domain)

           "#{domain.name} — #{domain.state}" <>
             if domain.state == "active" do
               ", #{limits.remaining_today} of #{limits.daily_limit} left today (rung #{limits.stage})"
             else
               ", cannot send until verified"
             end
         end)}
    end
  end

  defp add_domain(args, %{user: user}) do
    with {:ok, name} <- required(args, "name") do
      case Domains.create_domain(user, %{"name" => name}) do
        {:ok, domain, smtp_password} ->
          records =
            domain
            |> Domains.dns_records()
            |> Enum.filter(& &1.required)
            |> Enum.map_join("\n\n", fn record ->
              "#{record.record_type}  #{record.name}\n#{record.value}"
            end)

          {:ok,
           """
           Added #{domain.name}, currently unverified.

           Publish these two records, then call verify_domain:

           #{records}

           SMTP password for this domain, shown once: #{smtp_password}
           """}

        {:error, :domain_limit, message} ->
          {:error, message}

        {:error, changeset} ->
          {:error, "Could not add that domain: " <> changeset_errors(changeset)}
      end
    end
  end

  defp verify_domain(args, %{user: user}) do
    with {:ok, name} <- required(args, "name"),
         {:ok, domain} <- fetch_domain(user, name) do
      {:ok, checked} = Domains.verify_domain(domain)

      if checked.state == "active" do
        {:ok, "#{checked.name} is verified and can send."}
      else
        missing =
          [
            is_nil(checked.spf_verified_at) && "SPF",
            is_nil(checked.dkim_verified_at) && "DKIM"
          ]
          |> Enum.filter(& &1)
          |> Enum.join(" and ")

        {:error,
         "#{checked.name} is still unverified: the #{missing} record is not visible in DNS " <>
           "yet. DNS can take hours. Wait a few minutes and call verify_domain again."}
      end
    end
  end

  defp send_email(args, %{user: user}) do
    with {:ok, domain_name} <- required(args, "domain"),
         {:ok, domain} <- fetch_domain(user, domain_name) do
      params =
        %{
          "from" => Map.get(args, "from"),
          "to" => Map.get(args, "to"),
          "subject" => Map.get(args, "subject"),
          "text" => Map.get(args, "text"),
          "html" => Map.get(args, "html")
        }
        |> then(fn p ->
          if args["test_mode"] == true, do: Map.put(p, "o:testmode", "yes"), else: p
        end)

      case Mail.send_message(user, domain, params) do
        {:ok, messages} when is_list(messages) ->
          ids = Enum.map_join(messages, ", ", & &1.rfc_message_id)

          if args["test_mode"] == true do
            {:ok, "Accepted in test mode. Nothing was sent and no allowance was used. #{ids}"}
          else
            {:ok,
             "Queued #{length(messages)} message(s): #{ids}. Queued is not delivered — call " <>
               "get_delivery_events to see the outcome."}
          end

        {:error, reason, details} ->
          {:error, explain(reason, details)}
      end
    end
  end

  defp get_limits(args, %{user: user}) do
    standing = Reputation.summary(user)

    account = """

    Account: #{standing.tier} — up to #{standing.domain_limit} domains\
    #{if standing.refusals_last_24h > 0, do: ", #{standing.refusals_last_24h} messages refused by screening in the last 24h", else: ""}.\
    #{unless standing.sending_allowed, do: " Sending is currently paused on this account.", else: ""}
    """

    case Map.get(args, "domain") do
      # Asking about no domain in particular is a fair question, and answering
      # it saves an agent a round trip through a refusal.
      nil ->
        {:ok, String.trim(account) <> "\n\nPass a domain name for its daily sending allowance."}

      name ->
        with {:ok, domain} <- fetch_domain(user, name) do
          limits = Warmup.status(domain)

          {:ok,
           """
           #{domain.name}: rung #{limits.stage} of #{limits.stage_count}, #{limits.daily_limit} a day.
           Sent today: #{limits.sent_today}. Remaining: #{limits.remaining_today}.
           Graduates #{limits.graduates_when}.
           The allowance resets at #{limits.resets_at}.
           #{String.trim(account)}
           """}
        end
    end
  end

  defp list_messages(args, %{user: user}) do
    with {:ok, name} <- required(args, "domain"),
         {:ok, domain} <- fetch_domain(user, name) do
      messages =
        Mail.list_messages(domain,
          direction: args["direction"],
          folder: args["folder"],
          limit: min(args["limit"] || 25, 100)
        )

      if messages == [] do
        {:ok, "No messages for #{domain.name}."}
      else
        {:ok,
         Enum.map_join(messages, "\n", fn message ->
           correspondent =
             if message.direction == "outbound",
               do: Enum.join(message.recipients, ", "),
               else: message.sender

           "#{message.direction}  #{message.status}  #{correspondent}  #{message.subject}"
         end)}
      end
    end
  end

  defp get_events(args, %{user: user}) do
    with {:ok, name} <- required(args, "domain"),
         {:ok, domain} <- fetch_domain(user, name) do
      events =
        Mail.list_events(domain, %{
          "event" => args["event"],
          "recipient" => args["recipient"],
          "limit" => to_string(min(args["limit"] || 25, 100))
        })

      if events == [] do
        {:ok, "No events for #{domain.name} yet."}
      else
        {:ok,
         Enum.map_join(events, "\n", fn event ->
           detail = event.payload["reason"] || event.payload["receipt"] || ""
           "#{event.occurred_at}  #{event.type}  #{event.recipient}  #{detail}"
         end)}
      end
    end
  end

  # -- shared --------------------------------------------------------------

  # Shares its counters with the REST signup deliberately: these are two doors
  # into one room, and an abuser who found both should not get twice as much.
  defp signup_allowed(%{client_ip: ip}) when is_binary(ip) do
    config = Application.get_env(:email_provider, EmailProviderWeb.Plugs.SignupLimit, [])

    with :ok <- RateLimit.hit({:signup_hour, ip}, Keyword.get(config, :per_hour, 5), 3_600),
         :ok <- RateLimit.hit({:signup_day, ip}, Keyword.get(config, :per_day, 20), 86_400) do
      :ok
    else
      {:error, retry_after} ->
        {:error,
         "Too many accounts have been created from this address. Wait #{retry_after} seconds. " <>
           "One account can hold several domains, so you probably do not need another."}
    end
  end

  defp signup_allowed(_context), do: :ok

  defp required(args, key) do
    case Map.get(args, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "The #{key} argument is required."}
    end
  end

  defp fetch_domain(user, name) do
    case Domains.get_user_domain(user, name) do
      nil ->
        {:error,
         "No domain called #{name} on this account. Call list_domains to see what you have, " <>
           "or add_domain to register it."}

      domain ->
        {:ok, domain}
    end
  end

  # The API answers with a shape. An agent reads a sentence and decides what to
  # do next, so each failure says what would make the next attempt work.
  defp explain(:domain_not_verified, details),
    do:
      "#{details.domain} is not verified, so it cannot send. Publish its DNS records and " <>
        "call verify_domain."

  defp explain(:forbidden_sender, details),
    do: "#{details.message}. You sent from #{details.got}."

  defp explain(:rate_limited, details),
    do:
      "Daily limit reached: #{details.daily_limit} a day on rung #{details.stage}, " <>
        "#{details.remaining_today} left. Resets in #{details.retry_after_seconds} seconds. " <>
        "Do not retry before then."

  defp explain(:content_rejected, details),
    do:
      "Content screening refused this message (#{Enum.join(details.categories, ", ")}). " <>
        "This is permanent; do not rephrase and retry in a loop."

  defp explain(:sender_throttled, details), do: details.message

  defp explain(:all_recipients_suppressed, _details),
    do: "Every recipient is on this domain's suppression list, so nothing was sent."

  defp explain(:bad_request, reason) when is_binary(reason), do: reason
  defp explain(_reason, details), do: inspect(details)

  defp changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.map_join("; ", fn {field, messages} -> "#{field} #{Enum.join(messages, ", ")}" end)
  end
end
