defmodule MqttClient.SubscriptionTest do
  use ExUnit.Case
  doctest MqttClient

  alias MqttClient.Subscription

  setup_all do
    {:ok, pid} = MqttClient.Subscription.start_link()
    context = [subscription_pid: pid]
    {:ok, context}
  end

  test "stuff", context do
    Subscription.List.insert(self(), "a/b/+/c")
    Subscription.List.insert(context[:subscription_pid], "a/c/hest")
    Subscription.List.insert(context[:subscription_pid], "+/+/hest")
    Subscription.List.insert(self(), "a/c/+")
    Subscription.List.insert(self(), "+/#")
    Subscription.List.insert(self(), "#")

    # for _ <- 1..500_000 do
    #   Subscription.List.lookup("a/b/hest")
    # end
    # IO.inspect Subscription.List.lookup("a/c/hest")
    # IO.inspect Subscription.List.lookup("hest/a")

    # IO.inspect "done"
  end
end
