defmodule MqttClient.Subscription.Manager do
  @moduledoc false

  use GenServer

  # Client API
  def start_link() do
    GenServer.start_link(__MODULE__, :na, name: via_name())
  end

  defp via_name(pid) when is_pid(pid), do: pid
  defp via_name() do
    {:via, Registry, {Registry.MqttClient, __MODULE__}}
  end


  def add_subscription(client_id, subscriber_pid, topics) when is_list(topics) do
    GenServer.call(via_name(), {:insert, {client_id, subscriber_pid}, topics})
  end

  def remove_subscription(client_id, subscriber_pid, topics) when is_list(topics) do
    GenServer.call(via_name(), {:remove, {client_id, subscriber_pid}, topics})
  end

  # receive suback!


  # Server callbacks
  def init(:na) do
    subscribers = :ets.new(__MODULE__, [:named_table])
    {:ok, subscribers}
  end

  def handle_call({:insert, {client_id, pid}, topics}, _from, subscribers) do
    updated_subscriptions =
      case :ets.lookup(subscribers, pid) do
        [{^pid, ^client_id, current_topics}] ->
          Enum.into(topics, current_topics)

        [] ->
          Process.monitor(pid)
          MapSet.new(topics)
      end
    :ets.insert(subscribers, {pid, client_id, updated_subscriptions})
    # todo, fix
    for {topic, _} <- updated_subscriptions do
      MqttClient.Subscription.List.insert(pid, topic)
    end
    # todo, fix end
    {:reply, {:ok, updated_subscriptions}, subscribers}
  end

  def handle_call({:remove, {client_id, pid}, topics}, _from, subscribers) do
    case :ets.lookup(subscribers, pid) do
      [{^pid, current_topics}] ->
        updated_subscriptions = do_remove_topics(current_topics, topics)
        :ets.insert(subscribers, {pid, client_id, updated_subscriptions})
        {:reply, {:ok, updated_subscriptions}, subscribers}

      [] ->
        {:reply, {:error, :unknown_subscriber}, subscribers}
    end
  end

  def handle_info({:DOWN, _ref, :process, sub_pid, reason}, subscribers) do
    case :ets.take(subscribers, sub_pid) do
      [{^sub_pid, client_id, subscriptions}] ->
        IO.inspect "#{inspect sub_pid} subscribing to #{inspect subscriptions} on #{client_id} went down"
        # todo, clean up!

      [] ->
        "odd"
    end
    {:noreply, subscribers}
  end

  def handle_info(msg, subscribers) do
    IO.inspect {:handle_info, msg}
    {:noreply, subscribers}
  end

  defp do_remove_topics(current_topics, topics) do
    MapSet.difference(current_topics, MapSet.new(topics))
  end
end
