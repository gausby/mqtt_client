defmodule MqttClient.TopicTest do
  use ExUnit.Case, async: false
  use EQC.ExUnit
  doctest MqttClient.Package

  alias MqttClient.Topic

  test "Validating a topic filter with single level wild-card(s)" do
    assert {:ok, [""]} = Topic.valid_filter?("/")
    assert {:ok, ["+"]} = Topic.valid_filter?("+")
    assert {:error, _} = Topic.valid_filter?("sport+")
    assert {:ok, ["sport", "+", "player1"]} = Topic.valid_filter?("sport/+/player1")
    assert {:ok, _} = Topic.valid_filter?("sport/tennis/+")

    assert {:error, _} = Topic.valid_filter?("#/sport/tennis/+")
    # All Topic Names and Topic Filters MUST be at least one character long
    assert {:error, _} = Topic.valid_filter?("sport//results")
  end

  test "Validating a topic filter with multiple-level wild-card" do
    assert {:ok, ["sport", "#"]} = Topic.valid_filter?("sport/#")
    assert {:error, _} = Topic.valid_filter?("sport//#")
    assert {:ok, _} = Topic.valid_filter?("hest/#")
    assert {:error, _} = Topic.valid_filter?("hest/#/results")
  end
end
