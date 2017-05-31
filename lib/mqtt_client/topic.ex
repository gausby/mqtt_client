defmodule MqttClient.Topic do
  @moduledoc false

  @doc """
  Validate a given topic filter (todo, describe topic filters)
  """
  def valid_filter?("/"), do: {:ok, [""]} #<1>
  def valid_filter?(topic_filter) when byte_size(topic_filter) < 65535 do #<2>
    topic_filter
    |> String.split("/")
    |> do_valid_filter([])
  end
  def valid_filter?(_), do: {:error, :invalid_topic_filter}

  defp do_valid_filter([], acc), do: {:ok, Enum.reverse(acc)}
  defp do_valid_filter(["#"], acc), do: do_valid_filter([], ["#" | acc]) #<3>
  defp do_valid_filter(["+" | rest], acc),
    do: do_valid_filter(rest, ["+" | acc])
  defp do_valid_filter(["" | _], _), #<4>
    do: {:error, :invalid_topic_filter}
  defp do_valid_filter([level|rest], acc) do
    unless String.contains?(level, ["+", "#"]) do #<5>
      do_valid_filter(rest, [level|acc])
    else
      {:error, :invalid_topic_filter}
    end
  end
  #<1> The topic '/' is allowed.
  #<2> According to the spec a valid topic filter string should not
  #    exceed 65535 bytes in length (this should be enough for most
  #    topics!)
  #<3> The multi-level wild-card character is only allowed as the
  #    last item. `sports/#` is valid; `sports/#/results` is not.
  #<4> [MQTT-4.7.3-1] All Topic Names and Topic Filters MUST be at
  #    least 1 character long.
  #<5> [MQTT-4.7.1-1] The multi-level wildcard character MUST be
  #    specified either on its own or following a topic level
  #    separator. In either case it MUST be the last character
  #    specified in the Topic Filter.


  @doc """
  Validate a given topic

  Topics are different from 'topic filters' as # and + are not allowed
  """
  def valid?("/"), do: {:ok, [""]} #<1>
  def valid?(topic) when byte_size(topic) < 65535 do #<2>
    topic
    |> String.split("/")
    |> do_valid_topic([])
  end
  def valid?(_), do: {:error, :invalid_topic}

  defp do_valid_topic([], acc), do: {:ok, Enum.reverse(acc)}
  defp do_valid_topic(["#"], acc), do: {:error, :invalid_topic} #<3>
  defp do_valid_topic(["+" | rest], acc), do: {:error, :invalid_topic}
  defp do_valid_topic(["" | _], _), #<4>
    do: {:error, :invalid_topic}
  defp do_valid_topic([level|rest], acc) do
    unless String.contains?(level, ["+", "#"]) do #<5>
      do_valid_topic(rest, [level|acc])
    else
      {:error, :invalid_topic}
    end
  end
  #<1> The topic '/' is allowed.
  #<2> According to the spec a valid topic filter string should not
  #    exceed 65535 bytes in length (this should be enough for most
  #    topics!)
  #<3> The multi-level wild-card character is only allowed in topic
  #    filters.
  #<4> [MQTT-4.7.3-1] All Topic Names and Topic Filters MUST be at
  #    least 1 character long.
  #<5> [MQTT-4.7.1-1] The multi-level wildcard character MUST be
  #    specified either on its own or following a topic level
  #    separator. In either case it MUST be the last character
  #    specified in the Topic Filter.

end
