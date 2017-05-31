defmodule MqttClient.Subscription.List do
  @moduledoc false
  use GenServer

  alias MqttClient.Topic

  # Client API
  def start_link() do
    GenServer.start_link(__MODULE__, :na)
  end

  # Server callbacks
  def init(:na) do
    :ets.new(__MODULE__, [:named_table, :public])
    {:ok, :na}
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

  defp catch_all(pid, {:root, 0} = key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, subs, nil}] ->
        :ets.insert(__MODULE__, {key, subs, MapSet.new([pid])})

      [{^key, subs, catch_alls}] ->
        :ets.insert(__MODULE__, {key, subs, MapSet.put(catch_alls, pid)})
    end
  end
  defp catch_all(pid, {{topic, level}, parent} = key) do
    case :ets.lookup(__MODULE__, key) do
      [{{{^topic, ^level}, ^parent}, subs, nil}] ->
        :ets.insert(__MODULE__, {key, subs, MapSet.new([pid])})

      [{{{^topic, ^level}, ^parent}, subs, catch_alls}] ->
        :ets.insert(__MODULE__, {key, subs, MapSet.put(catch_alls, pid)})
    end
  end

  defp subscribe(pid, {{topic, level}, parent} = key) do
    case :ets.lookup(__MODULE__, key) do
      [{{{^topic, ^level}, ^parent}, nil, catch_alls}] ->
        :ets.insert(__MODULE__, {key, MapSet.new([pid]), catch_alls})

      [{{{^topic, ^level}, ^parent}, subscriptions, catch_alls}] ->
        :ets.insert(__MODULE__, {key, MapSet.put(subscriptions, pid), catch_alls})
    end
  end

  defp get_key([]), do: {{:root, 0}, nil}
  defp get_key([{topic, 1}]), do: {{topic, 1}, :root}
  defp get_key([{topic, level}, {parent, _}|_]),
    do: {{topic, level}, parent}


  defp insert_edges([]), do: insert_edge({{:root, 0}, nil})
  defp insert_edges([{_, 1} = edge]), do: insert_edge(edge, {:root, 0})
  defp insert_edges([edge, from|rest]) do
    insert_edge(edge, from)
    insert_edges([from|rest])
  end

  defp insert_edge({{:root, 0}, nil}) do
    :ets.insert_new(__MODULE__, {{{:root, 0}, nil}, nil, nil})
  end
  defp insert_edge({topic, level}, {from, _}) do
    :ets.insert_new(__MODULE__, {{{topic, level}, from}, nil, nil})
  end

  def get_node(topic, level, parent) do
    :ets.lookup(__MODULE__, {{topic, level}, parent})
  end

  def lookup(topics) do
    {:ok, query} = Topic.valid?(topics)
    query
    |> Enum.with_index(1)
    |> collect(:root)
    |> List.flatten()
    |> Enum.reduce(get_root(), fn(item, acc) -> MapSet.union(acc, item) end)
  end

  defp get_root() do
    case :ets.lookup(__MODULE__, {{:root, 0}, nil}) do
      [] -> MapSet.new()
      [{{{:root, 0}, nil}, nil, nil}] -> MapSet.new()
      [{{{:root, 0}, nil}, nil, catch_alls}] -> catch_alls
    end
  end

  defp collect([], _), do: []
  defp collect([{topic, level}], parent) do
    for current_topic <- ["+", topic] do
      case get_node(current_topic, level, parent) do
        [{{{^current_topic, ^level}, ^parent}, nil, catch_alls}] ->
          catch_alls

        [{{{^current_topic, ^level}, ^parent}, subs, nil}] ->
          subs

        [{{{^current_topic, ^level}, ^parent}, subs, catch_alls}] ->
          MapSet.union(subs, catch_alls)

        [] -> nil
      end
    end
    |> Enum.reject(fn(a) -> a == nil end)
  end
  defp collect([{topic, level}|rest], parent) do
    for current_topic <- ["+", topic] do
      case get_node(current_topic, level, parent) do
        [{{{^current_topic, ^level}, ^parent}, _, nil}] ->
          collect(rest, current_topic)

        [{{{^current_topic, ^level}, ^parent}, _, catch_alls}] ->
          [catch_alls] ++ collect(rest, current_topic)

        [] -> nil
      end
    end
    |> Enum.reject(fn(a) -> a == nil end)
  end
end
