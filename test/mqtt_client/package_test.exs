defmodule MqttClient.PackageTest do
  use ExUnit.Case
  use EQC.ExUnit
  doctest MqttClient.Package

  alias MqttClient.Package

  property "encoding and decoding connect messages" do
    forall connect <- %Package.Connect{
      client_id: binary(),
      user_name: oneof([nil, binary()]), password: oneof([nil, binary()]),
      clean_session: bool(), keep_alive: choose(0, 65535),
      will: oneof([
        %Package.Publish{topic: nil, payload: nil, qos: 0, retain: false},
        %Package.Publish{topic: binary(), payload: binary(), qos: choose(0, 2),
                         retain: bool()},
      ])
    } do
      ensure connect ==
        connect
        |> Package.encode() |> IO.iodata_to_binary()
        |> Package.decode()
    end
  end

  @conn_results [
    :accepted,
    {:refused, :unacceptable_protocol_version},
    {:refused, :identifier_rejected},
    {:refused, :server_unavailable},
    {:refused, :bad_user_name_or_password},
    {:refused, :not_authorized}
  ]
  property "encoding and decoding connack messages" do
    forall connack <-
      %Package.Connack{session_present: bool(),
                       status: oneof(@conn_results)} do
      ensure connack ==
        connack
        |> Package.encode() |> IO.iodata_to_binary()
        |> Package.decode()
    end
  end

  property "encoding and decoding publish messages" do
    forall publish <-
      oneof([ %Package.Publish{identifier: nil,
                               qos: 0, dup: false,
                               topic: utf8(), payload: utf8(), retain: bool()},
              %Package.Publish{identifier: choose(0x0001, 0xFFFF),
                               qos: choose(1, 2), dup: bool(),
                               topic: utf8(), payload: utf8(), retain: bool()}]) do
      ensure publish ==
        publish
        |> Package.encode() |> IO.iodata_to_binary()
        |> Package.decode()
    end
  end

  property "encoding and decoding publish messages (large)" do
    forall publish <-
      oneof([ %Package.Publish{identifier: nil,
                               qos: 0, dup: false, retain: bool(),
                               topic: largebinary(), payload: largebinary()},
              %Package.Publish{identifier: choose(0x0001, 0xFFFF),
                               qos: choose(1, 2), dup: bool(), retain: bool(),
                               topic: largebinary(), payload: largebinary()}]) do
      ensure publish ==
        publish
        |> Package.encode() |> IO.iodata_to_binary()
        |> Package.decode()
    end
  end

  property "encoding and decoding subscribe messages" do
    forall {subscribe, subscriptions} <-
      {%Package.Subscribe{identifier: choose(0x0001, 0xFFFF)},
       list({list(utf8()), choose(0, 2)})} do
      subscriptions =
        Enum.map(subscriptions, fn({topics, qos}) ->
          {Enum.join(topics, "/"), qos}
        end)
      subscribe = %{subscribe|topics: subscriptions}

      ensure subscribe ==
        subscribe
        |> Package.encode() |> IO.iodata_to_binary()
        |> Package.decode()
    end
  end

  property "encoding and decoding unsubscribe messages" do
    forall {unsubscribe, topic_list} <-
      { %Package.Unsubscribe{identifier: choose(0x0001, 0xFFFF)},
        list(list(utf8())) } do
      topics = Enum.map(topic_list, &(Enum.join(&1, "/")))
      unsubscribe = %{unsubscribe|topics: topics}
      ensure unsubscribe ==
        unsubscribe
        |> Package.encode() |> IO.iodata_to_binary()
        |> Package.decode()
    end
  end

  property "encoding and decoding suback messages" do
    forall suback <-
      %Package.Suback{
        identifier: choose(0x0001, 0xFFFF),
        acks: list(oneof([ {:ok, choose(0, 2)},
                           {:error, :access_denied}]))} do
      ensure suback ==
        suback
        |> Package.encode() |> IO.iodata_to_binary()
        |> Package.decode()
    end
  end

  property "encoding and decoding acknowledgement messages" do
    forall ack <- oneof([
      %Package.Unsuback{identifier: choose(0x0001, 0xFFFF)},
      %Package.Puback{identifier: choose(0x0001, 0xFFFF)},
      %Package.Pubcomp{identifier: choose(0x0001, 0xFFFF)},
      %Package.Pubrel{identifier: choose(0x0001, 0xFFFF)},
      %Package.Pubrec{identifier: choose(0x0001, 0xFFFF)}
    ]) do
      ensure ack ==
        ack
        |> Package.encode() |> IO.iodata_to_binary()
        |> Package.decode()
    end
  end

  test "encoding and decoding ping requests" do
    pingreq = %Package.Pingreq{}
    assert ^pingreq =
      pingreq
      |> Package.encode() |> IO.iodata_to_binary()
      |> Package.decode()
  end

  test "encoding and decoding ping responses" do
    pingresp = %Package.Pingresp{}
    assert ^pingresp =
      pingresp
      |> Package.encode() |> IO.iodata_to_binary()
      |> Package.decode()
  end

  test "encoding and decoding disconnect messages" do
    disconnect = %Package.Disconnect{}
    assert ^disconnect =
      disconnect
      |> Package.encode() |> IO.iodata_to_binary()
      |> Package.decode()
  end
end
