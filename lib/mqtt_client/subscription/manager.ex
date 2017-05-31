defmodule MqttClient.Subscription.Manager do
  @moduledoc false

  use GenServer

  @name __MODULE__

  # Client API
  def start_link() do
    GenServer.start_link(__MODULE__, :na, name: @name)
  end

  defp via_name(pid) when is_pid(pid), do: pid


  def add_subscription(pid, subscriber_pid, topics) when is_list(topics) do
    GenServer.call(pid, {:insert, subscriber_pid, topics})
  end

  def remove_subscription(pid, subscriber_pid, topics) when is_list(topics) do
    GenServer.call(pid, {:remove, subscriber_pid, topics})
  end


  # Server callbacks
  def init(:na) do
    subscribers = :ets.new(__MODULE__, [:named_table])
    {:ok, subscribers}
  end

  def handle_call({:insert, pid, topics}, _from, subscribers) do
    updated_subscriptions =
      case :ets.lookup(subscribers, pid) do
        [{^pid, current_topics}] ->
          Enum.into(topics, current_topics)

        [] ->
          Process.monitor(pid)
          MapSet.new(topics)
      end
    :ets.insert(subscribers, {pid, updated_subscriptions})
    {:reply, {:ok, updated_subscriptions}, subscribers}
  end

  def handle_call({:remove, pid, topics}, _from, subscribers) do
    case :ets.lookup(subscribers, pid) do
      [{^pid, current_topics}] ->
        updated_subscriptions = do_remove_topics(current_topics, topics)
        :ets.insert(subscribers, {pid, updated_subscriptions})
        {:reply, {:ok, updated_subscriptions}, subscribers}

      [] ->
        {:reply, {:error, :unknown_subscriber}, subscribers}
    end
  end

  def handle_info({:DOWN, _ref, :process, subscriber_pid, :normal}, subscribers) do
    IO.inspect {:removing, subscriber_pid, :ets.take(subscribers, subscriber_pid)}
    {:noreply, subscribers}
  end

  defp do_remove_topics(current_topics, topics) do
    MapSet.difference(current_topics, MapSet.new(topics))
  end
end
