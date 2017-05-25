defmodule MqttClient.Connection.Controller do
  @moduledoc false

  alias MqttClient.Package
  alias MqttClient.Package.{
    Connect, Connack, Disconnect,
    Publish, Puback, Pubrec, Pubrel, Pubcomp,
    Subscribe, Suback,
    Unsubscribe, Unsuback,
    Pingreq, Pingresp
  }
  alias MqttClient.Connection.Transmitter

  use GenServer

  defstruct [client_id: nil]

  # Client API
  def start_link(opts) do
    client_id = Keyword.fetch!(opts, :client_id)
    GenServer.start_link(__MODULE__, client_id, name: via_name(client_id))
  end

  def via_name(client_id) do
    key = {__MODULE__, client_id}
    {:via, Registry, {Registry.MqttClient, key}}
  end

  def handle_incoming(client_id, <<package::binary>>) do
    GenServer.cast(via_name(client_id), {:package, package})
  end

  # Server callbacks
  def init(client_id) do
    {:ok, %__MODULE__{client_id: client_id}}
  end

  def handle_cast({:package, package}, state) do
    package
    |> Package.decode()
    |> handle_package(state)
  end


  # QoS LEVEL 0 ========================================================
  # incoming messages --------------------------------------------------
  defp handle_package(%Publish{qos: 0} = publish, state) do
    # todo: BROADCAST `payload` to everyone subscribing to `topic`
    IO.inspect {:received, publish}
    {:noreply, state}
  end


  # QoS LEVEL 1 ========================================================
  # incoming messages --------------------------------------------------
  defp handle_package(%Publish{qos: 1} = publish, state) do
    # todo: BROADCAST `payload` to everyone subscribing to `topic`
    puback = %Puback{identifier: publish.identifier}
    :ok = Transmitter.cast(state.client_id, puback)
    {:noreply, state}
  end
  # outgoing messages --------------------------------------------------
  #
  # During publish of QoS1 messages we should spin up a supervised
  # process storing the publish message; this process will handle the
  # publish, and republish it (with dup set to true) if it falls for a
  # timeout--it should stop republishing when we receive the *puback*
  # message for the identifier.
  #
  defp handle_package(%Puback{identifier: identifier}, state) do
    # todo: shut down the process tracking publish:identifier
    IO.inspect "acknowledge #{identifier}"
    {:noreply, state}
  end


  # QoS LEVEL 2 ========================================================
  # incoming messages --------------------------------------------------
  defp handle_package(%Publish{qos: 2} = publish, state) do
    # todo: BROADCAST `payload` to everyone subscribing to `topic`
    pubrec = %Pubrec{identifier: publish.identifier}
    :ok = Transmitter.cast(state.client_id, pubrec)
    # todo: store release identifier
    {:noreply, state}
  end
  defp handle_package(%Pubrel{identifier: identifier}, state) do
    pubcomp = %Pubcomp{identifier: identifier}
    :ok = Transmitter.cast(state.client_id, pubcomp)
    # todo: discard release identifier
    {:noreply, state}
  end
  # outgoing messages --------------------------------------------------
  #
  # During publish of QoS2 messages we should spin up a supervised
  # process storing the publish message; this process will handle the
  # publish, and republish it (with dup set to true) if it falls for a
  # timeout--it should stop republishing when we receive the *pubrel*
  # message for the identifier, and finally it should shut down the
  # process when we receive the pubcomp message.
  #
  defp handle_package(%Pubrec{identifier: identifier}, state) do
    # todo: tell message process to stop reposting (state=acknowledged)
    pubrel = %Pubrel{identifier: identifier}
    :ok = Transmitter.cast(state.client_id, pubrel)
    {:noreply, state}
  end
  defp handle_package(%Pubcomp{identifier: _identifier}, state) do
    # todo: shutdown the message process for identifier
    {:noreply, state}
  end


  # SUBSCRIBING ========================================================
  # incoming messages --------------------------------------------------
  defp handle_package(%Subscribe{}, state) do
    # not a server! (yet)
    {:noreply, state}
  end
  # outgoing messages --------------------------------------------------
  defp handle_package(%Suback{identifier: identifier, acks: acks}, state) do
    IO.inspect {:subacked, identifier, acks}
    {:noreply, state}
  end


  # UNSUBSCRIBING ======================================================
  # incoming messages --------------------------------------------------
  defp handle_package(%Unsubscribe{}, state) do
    # not a server
    {:noreply, state}
  end
  # outgoing messages --------------------------------------------------
  defp handle_package(%Unsuback{identifier: identifier}, state) do
    IO.inspect {:unsubacked, identifier}
    {:noreply, state}
  end


  # PING MESSAGES ======================================================
  # incoming messages --------------------------------------------------
  defp handle_package(%Pingresp{}, state) do
    IO.inspect "Pong"
    {:noreply, state}
  end
  # outgoing messages --------------------------------------------------
  defp handle_package(%Pingreq{}, state) do
    pingresp = %Pingresp{}
    :ok = Transmitter.cast(state.client_id, pingresp)
    {:noreply, state}
  end


  # CONNECTING =========================================================
  # incoming messages --------------------------------------------------
  defp handle_package(%Connect{}, state) do
    # not a server!
    {:noreply, state}
  end
  # outgoing messages --------------------------------------------------
  defp handle_package(%Connack{} = connack, state) do
    IO.inspect connack
    {:noreply, state}
  end


  # DISCONNECTING ======================================================
  # incoming messages --------------------------------------------------
  defp handle_package(%Disconnect{}, state) do
    {:noreply, state}
  end
end
