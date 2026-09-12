defmodule EmailProvider.TestSenders do
  @moduledoc "Senders that fail on demand, so failure handling can be tested."

  defmodule Permanent do
    @moduledoc "Always refuses with a 5xx, the shape of a hard bounce."
    @behaviour EmailProvider.Delivery.Sender

    @impl true
    def deliver(_raw, _from, _to), do: {:error, "550 5.1.1 no such user here"}
  end

  defmodule Temporary do
    @moduledoc "Always refuses with a 4xx, the shape of a deferral."
    @behaviour EmailProvider.Delivery.Sender

    @impl true
    def deliver(_raw, _from, _to), do: {:error, "451 4.7.1 try again later"}
  end

  defmodule Recording do
    @moduledoc "Captures what it was handed so a test can inspect the wire bytes."
    @behaviour EmailProvider.Delivery.Sender

    def start_link, do: Agent.start_link(fn -> [] end, name: __MODULE__)
    def sent, do: Agent.get(__MODULE__, & &1)

    @impl true
    def deliver(raw, from, to) do
      Agent.update(__MODULE__, &[%{raw: raw, from: from, to: to} | &1])
      {:ok, %{receipt: "recorded"}}
    end
  end
end
