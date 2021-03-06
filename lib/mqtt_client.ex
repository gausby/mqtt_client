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

  defdelegate connect(server, opts \\ []), to: MqttClient.Connection

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

  def subscribe(client_id, topic_filters, opts \\ []) do
    MqttClient.Subscription.subscribe(client_id, self(), topic_filters, opts)
  end

  def unsubscribe(client_id, topic_filters) do
    MqttClient.Subscription.unsubscribe(client_id, self(), topic_filters)
  end

  def ping(client_id) do
    Transmitter.cast(client_id, %Package.Pingreq{})
  end
end
