defmodule MqttClient do

  @moduledoc """
  MQTT Version 3.1 compliant client for Elixir

  """

  use Application

  alias MqttClient.Connection.Transmitter
  alias MqttClient.Package

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Registry, [:unique, Registry.MqttClient]),
      supervisor(MqttClient.Connection, []),
      supervisor(MqttClient.Subscription, [])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defdelegate connect(opts), to: MqttClient.Connection

  def publish(client_id, opts \\ []) when is_list(opts) do
    {topic_payload, opts} = Keyword.split(opts, [:topic, :payload])
    publish(client_id, topic_payload[:topic], topic_payload[:payload], opts)
  end

  def publish(client_id, topic, payload, opts \\ []) do
    qos = Keyword.get(opts, :qos, 0)
    identifier =
      if qos > 0 and opts[:identifier] == nil do
        Package.generate_random_identifier()
      end
    Transmitter.cast(client_id,
      %Package.Publish{
        identifier: identifier,
        topic: topic, payload: payload,
        qos: qos,
        retain: Keyword.get(opts, :retain, false)
      })
  end


  # def subscribe(client_id, topic, opts \\ [qos: 0]) do
  #   subscriber_pid = self()
  #   MqttClient.Subscription.add(client_id, subscriber_pid, topic, opts)
  # end

  def unsubscribe(client_id, topic) do
    Transmitter.cast(client_id,
      %Package.Unsubscribe{
        identifier: Package.generate_random_identifier(),
        topics: [topic]
      })
  end

  def ping(client_id) do
    Transmitter.cast(client_id, %Package.Pingreq{})
  end
end
