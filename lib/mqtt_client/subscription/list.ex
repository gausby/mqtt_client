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

  defp catch_all(pid, {{topic, level}, parent} = key) do
    case :ets.lookup(__MODULE__, key) do
      [{{{^topic, ^level}, ^parent}, _subs, catch_alls}] ->
        :ets.update_element(__MODULE__, key, {3, [pid | catch_alls]})
    end
  end

  defp subscribe(pid, {{topic, level}, parent} = key) do
    case :ets.lookup(__MODULE__, key) do
      [{{{^topic, ^level}, ^parent}, subscriptions, _catch_alls}] ->
        :ets.update_element(__MODULE__, key, {2, [pid | subscriptions]})
    end
  end

  defp get_key([]), do: {{:root, 0}, nil}
  defp get_key([{topic, 1}]), do: {{topic, 1}, :root}
  defp get_key([{topic, level}, {parent, _}|_]),
    do: {{topic, level}, parent}


  defp insert_edges([]),
    do: insert_edge({{:root, 0}, nil})
  defp insert_edges([{_, 1} = edge]),
    do: insert_edge({edge, :root})
  defp insert_edges([edge, from|rest]) do
    {parent, _} = from
    insert_edge({edge, parent})
    insert_edges([from|rest])
  end

  defp insert_edge({{_topic, _level}, _from} = key) do
    :ets.insert_new(__MODULE__, {key, [], []})
  end


  def lookup(topics) do
    {:ok, query} = Topic.valid?(topics)
    query
    |> Enum.with_index(1)
    |> collect(:root)
    |> Enum.into(MapSet.new(get_root()))
  end

  def get_node(topic, level, parent) do
    :ets.lookup(__MODULE__, {{topic, level}, parent})
  end

  defp get_root() do
    case get_node(:root, 0, nil) do
      [{{{:root, 0}, nil}, _, catch_alls}] -> catch_alls
    end
  end

  defp collect([], _), do: []
  defp collect([{topic, level}], parent) do
    topic_level =
      case get_node(topic, level, parent) do
        [{{{^topic, ^level}, ^parent}, subs, catch_alls}] ->
          subs ++ catch_alls

        [] -> []
      end
    wildcard_level =
      case get_node("+", level, parent) do
        [{{{"+", ^level}, ^parent}, subs, catch_alls}] ->
          subs ++ catch_alls

        [] -> []
      end

    topic_level ++ wildcard_level
  end
  defp collect([{topic, level}|rest], parent) do
    topic_level =
      case get_node(topic, level, parent) do
        [{{{^topic, ^level}, ^parent}, _, catch_alls}] ->
          catch_alls ++ collect(rest, topic)

        [] -> []
      end
    wildcard_level =
      case get_node("+", level, parent) do
        [{{{"+", ^level}, ^parent}, _, catch_alls}] ->
          catch_alls ++ collect(rest, "+")

        [] -> []
      end

    topic_level ++ wildcard_level
  end
end
