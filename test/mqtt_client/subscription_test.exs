defmodule MqttClient.SubscriptionTest do
  use ExUnit.Case
  doctest MqttClient

  alias MqttClient.Subscription

  setup_all do
    {:ok, pid} = MqttClient.Subscription.start_link()
    context = [subscription_pid: pid]
    {:ok, context}
  end

  test "hello", context do
    IO.inspect context[:subscription_pid]
  end

  test "stuff", context do
    # Subscription.List.insert(self(), "a/b/+/c")
    Subscription.List.insert(context[:subscription_pid], "a/c/hest/#")
    Subscription.List.insert(self(), "#")

    for _ <- 1..50000 do
      Subscription.List.lookup("a/b/hest")
    end
    IO.inspect Subscription.List.lookup("a/c/hest")

    IO.inspect "done"
  end
end
