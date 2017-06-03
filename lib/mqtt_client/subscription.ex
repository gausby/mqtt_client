defmodule MqttClient.Subscription do
  @moduledoc false

  use Supervisor

  alias MqttClient.Package
  alias MqttClient.Connection.Transmitter

  @name __MODULE__

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def subscribe(client_id, subscriber_pid, topics, opts)
  when is_pid(subscriber_pid) do
    # validate topics
    # inform the manager that the pid is subscribing to topic
    # the manager will monitor the pid
    Transmitter.cast(client_id,
      %Package.Subscribe{
        identifier: Package.generate_random_identifier(),
        topics: topics # [{topic, qos}]
      })
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
