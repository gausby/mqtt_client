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


  def publish(client_id, opts \\ []) when is_list(opts) do
    {topic_payload, opts} = Keyword.split(opts, [:topic, :payload])
    publish(client_id, topic_payload[:topic], topic_payload[:payload], opts)
  end

  def publish(client_id, topic, payload, opts \\ []) do
    Transmitter.cast(client_id,
      %Package.Publish{
        topic: topic, payload: payload,
        qos: Keyword.get(opts, :qos, 0),
        retain: Keyword.get(opts, :retain, false)
      })
  end


  def subscribe(client_id, topic, qos \\ 0) do
    IO.inspect self()
    Transmitter.cast(client_id,
      %Package.Subscribe{
        identifier: Package.generate_random_identifier(),
        topics: [{topic, qos}]
      })
  end

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
