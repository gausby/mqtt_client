defmodule MqttClient.Subscription.List do
  @moduledoc false
  use GenServer

  alias MqttClient.Topic

  # Client API
  def start_link() do
    GenServer.start_link(__MODULE__, :na)
  end

  def lookup(topics) do
    with {:ok, query} <- Topic.valid?(topics),
         query_with_index = Enum.with_index(query, 1),
         root_set = MapSet.new(get_root()),
         subscriber_pids = collect(query_with_index, :root) do
      Enum.into(subscriber_pids, root_set)
    else
      reason -> raise "handle this: #{inspect reason}"
    end
  end

  def insert(pid, topic_filter) do
    {:ok, topics} = Topic.valid_filter?(topic_filter)
    topic_list = topics |> Enum.with_index(1) |> Enum.reverse()
    case topic_list do
      [{"#", _} | rest] ->
        insert_edges(rest)
        catch_all(pid, get_key(rest))

      _ ->
        insert_edges(topic_list)
        subscribe(pid, get_key(topic_list))
    end
  end


  #=Server callbacks ===================================================
  def init(:na) do
    :ets.new(__MODULE__, [:named_table, :public])
    {:ok, :na}
  end


  #=Helpers ============================================================
  defp catch_all(pid, {{topic, level}, parent} = key) do
    case :ets.lookup(__MODULE__, key) do
      [{{{^topic, ^level}, ^parent}, _refs, _subs, catch_alls}] ->
        :ets.update_element(__MODULE__, key, {4, [pid | catch_alls]})
    end
  end

  defp subscribe(pid, {{topic, level}, parent} = key) do
    case :ets.lookup(__MODULE__, key) do
      [{{{^topic, ^level}, ^parent}, _refs, subscriptions, _catch_alls}] ->
        :ets.update_element(__MODULE__, key, {3, [pid | subscriptions]})
    end
  end

  defp get_key([]), do: {{:root, 0}, nil}
  defp get_key([{topic, 1}]), do: {{topic, 1}, :root}
  defp get_key([{topic, level}, {parent, _}|_]),
    do: {{topic, level}, parent}

  defp insert_edges([_|rest] = topics) do
    topics |> get_key() |> insert_edge()
    insert_edges(rest)
  end
  defp insert_edges(edge) do
    edge |> get_key() |> insert_edge()
  end

  defp get_root() do
    key = {{:root, 0}, nil}
    case :ets.lookup(__MODULE__, key) do
      [{^key, _ref_counter, _subs, catch_alls}] ->
        catch_alls

      [] ->
        []
    end
  end

  defp collect([], _), do: []
  defp collect([{topic, level}|rest], parent) do
    collect_node({{topic, level}, parent}, rest)
    ++ collect_node({{"+", level}, parent}, rest)
  end

  defp collect_node(key, []) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, _ref_counter, subs, catch_alls}] ->
        catch_alls ++ subs
      [] ->
        []
    end
  end
  defp collect_node({{topic, _level}, _parent} = key, rest) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, _ref_counter, _subs, catch_alls}] ->
        catch_alls ++ collect(rest, topic)
      [] ->
        []
    end
  end

  defp insert_edge({{_topic, _level}, _parent} = key) do
    unless :ets.insert_new(__MODULE__, {key, 1, [], []}) do
      # increment reference counter for this route
      :ets.update_counter(__MODULE__, key, {2, 1})
    end
  end
end
