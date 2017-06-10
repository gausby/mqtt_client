defmodule MqttClient.Connection.Supervisor do
  @moduledoc false

  use Supervisor

  alias MqttClient.Connection.{Transmitter, Receiver, Controller}

  # todo, handle websockets and tls protocols
  # todo, ensure the opts has a client_id

  def start_link({_protocol, _host, _port} = server, opts) do
    Supervisor.start_link(__MODULE__, {server, opts})
  end

  def init({{_protocol, _host, _port} = server, opts}) do
    children = [
      worker(Transmitter, [Keyword.take(opts, [:client_id])]),
      worker(Receiver, [server, Keyword.take(opts, [:client_id])]),
      worker(Controller, [Keyword.take(opts, [:client_id])])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
