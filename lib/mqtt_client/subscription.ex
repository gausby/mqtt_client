defmodule MqttClient.Subscription do
  @moduledoc false

  use Supervisor

  alias MqttClient.Package
  alias MqttClient.Subscription
  alias MqttClient.Topic
  alias MqttClient.Connection.Transmitter

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: via_name())
  end

  defp via_name() do
    {:via, Registry, {Registry.MqttClient, __MODULE__}}
  end

  def subscribe(client_id, subscriber_pid, topic_filters, opts)
  when is_pid(subscriber_pid) do
    true = Topic.all_valid_topic_filters?(topic_filters)
    # inform the manager that the pid is subscribing to topic
    Subscription.Manager.add_subscription(client_id, subscriber_pid, topic_filters)
    # the manager will monitor the pid, should the process crash its pid should
    # get unsubscribed from the subscription list
    Transmitter.cast(client_id,
      %Package.Subscribe{
        identifier: Package.generate_random_identifier(),
        topics: topic_filters
      })
  end

  def broadcast(%Package.Publish{topic: topic, payload: payload}) do
    topic_list = String.split(topic, "/")
    for pid <- MqttClient.Subscription.List.lookup(topic) do
      send pid, {:publish, topic_list, payload}
    end
  end

  # callbacks
  def init(:ok) do
    children = [
      worker(MqttClient.Subscription.List, []),
      worker(MqttClient.Subscription.Manager, []),
      worker(MqttClient.Subscription.Dispatcher, [])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
