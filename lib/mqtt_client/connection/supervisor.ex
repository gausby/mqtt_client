defmodule MqttClient.Connection.Supervisor do
  @moduledoc false

  use Supervisor

  alias MqttClient.Connection

  def start_link(opts) do
    Supervisor.start_link(__MODULE__,
      [ client_id: Keyword.fetch!(opts, :client_id),
        host: Keyword.get(opts, :host, 'localhost'),
        port: Keyword.get(opts, :port, 1883)
      ])
  end

  def init(opts) do
    children = [
      worker(Connection.Transmitter, [Keyword.take(opts, [:client_id])]),
      worker(Connection.Receiver, [Keyword.take(opts, [:host, :port, :client_id])]),
      worker(Connection.Controller, [Keyword.take(opts, [:client_id])])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
