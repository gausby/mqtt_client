defmodule MqttClient.SubscriptionTest do
  use ExUnit.Case
  doctest MqttClient

  alias MqttClient.Subscription

  setup_all do
    {:ok, pid} = MqttClient.start(:normal, [])
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
    IO.inspect Subscription.List.lookup("a/c/hest")
    IO.inspect Subscription.List.lookup("hest/a")

    IO.inspect "done"
  end

  test "add a subscription to a process" do
    {:ok, client_id} = MqttClient.connect([])
    parent = self()
    :timer.sleep 20
    {:ok, task_pid} = Task.start(
      fn() ->
        :ok = MqttClient.subscribe(client_id, [{"a/b", 2}], [])
        receive do
          message ->
            IO.inspect {self(), message}
            send parent, :received
        end
      end)
    :timer.sleep(20)
    MqttClient.publish(client_id, [topic: "a/b", payload: "hi peeps !", qos: 2])
    assert_receive :received
    :timer.sleep 200
  end

  # should only subscribe once if the manager is already subscribed
end
