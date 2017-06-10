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

  defstruct [client_id: nil, pubrec: MapSet.new()]

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
  defp handle_package(%Publish{qos: 0, dup: false} = publish, state) do
    # BROADCAST `payload` to everyone subscribing to `topic`
    MqttClient.Subscription.broadcast(publish)
    {:noreply, state}
  end


  # QoS LEVEL 1 ========================================================
  # incoming messages --------------------------------------------------
  defp handle_package(%Publish{qos: 1} = publish, state) do
    # send publish acknowledgement to sender
    puback = %Puback{identifier: publish.identifier}
    :ok = Transmitter.cast(state.client_id, puback)
    # BROADCAST `payload` to everyone subscribing to `topic`
    MqttClient.Subscription.broadcast(publish)
    {:noreply, state}
  end
  # outgoing messages --------------------------------------------------
  defp handle_package(%Puback{identifier: identifier}, state) do
    # todo: shut down the process tracking publish:identifier
    IO.inspect "acknowledge message #{identifier}"
    {:noreply, state}
  end


  # QoS LEVEL 2 ========================================================
  # incoming messages --------------------------------------------------
  defp handle_package(%Publish{qos: 2} = publish, state) do
    unless MapSet.member?(state.pubrec, publish.identifier) do
      pubrec = %Pubrec{identifier: publish.identifier}
      :ok = Transmitter.cast(state.client_id, pubrec)
      # BROADCAST `payload` to everyone subscribing to `topic`
      MqttClient.Subscription.broadcast(publish)
      new_state =
        %{state|pubrec: MapSet.put(state.pubrec, publish.identifier)}
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  defp handle_package(%Pubrel{identifier: identifier}, state) do
    if MapSet.member?(state.pubrec, identifier) do
      pubcomp = %Pubcomp{identifier: identifier}
      :ok = Transmitter.cast(state.client_id, pubcomp)
      new_state =
        %{state|pubrec: MapSet.delete(state.pubrec, identifier)}
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  # outgoing messages --------------------------------------------------
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
