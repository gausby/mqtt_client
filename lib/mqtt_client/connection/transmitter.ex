defmodule MqttClient.Connection.Transmitter do
  @moduledoc false

  use GenStateMachine

  defstruct []

  # Client API
  def start_link(opts) do
    client_id = Keyword.fetch!(opts, :client_id)
    data = %__MODULE__{}
    GenStateMachine.start_link(__MODULE__, data, name: via_name(client_id))
  end

  defp via_name(client_id) do
    key = {__MODULE__, client_id}
    {:via, Registry, {Registry.MqttClient, key}}
  end

  def handle_socket(client_id, socket) do
    GenStateMachine.call(via_name(client_id), {:handle_socket, socket})
  end

  def cast(client_id, message) do
    package = MqttClient.Package.encode(message)
    GenStateMachine.cast(via_name(client_id), {:transmit, package})
  end

  # Server callbacks
  def init(data) do
    {:ok, :disconnected, data, []}
  end

  def handle_event({:call, from}, {:handle_socket, socket}, :disconnected, data) do
    new_state = {:connected, socket}
    next_actions = [{:reply, from, :ok}]
    {:next_state, new_state, data, next_actions}
  end

  def handle_event(:cast, {:transmit, package}, {:connected, socket}, _data) do
    :gen_tcp.send(socket, package)
    :keep_state_and_data
  end
  def handle_event(:cast, {:transmit, _}, _, _data) do
    {:keep_state_and_data, [:postpone]}
  end
end
