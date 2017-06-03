defmodule MqttClient.Subscription.Dispatcher do
  @moduledoc false

  use GenServer

  # Client API
  def start_link() do
    GenServer.start_link(__MODULE__, :na)
  end

  # Server callbacks
  def init(:na) do
    {:ok, nil}
  end
end
