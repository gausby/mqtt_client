# MqttClient

A WIP Elixir MqttClient implementation that aims to support all of the
MQTT 3.1.1 specification.

## Installation

When [available in Hex](https://hex.pm/docs/publish), the package can
be installed as:

  1. Add `mqtt_client` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:mqtt_client, "~> 0.1.0"}]
    end
    ```

  2. Ensure `mqtt_client` is started before your application:

    ```elixir
    def application do
      [applications: [:mqtt_client]]
    end
    ```
