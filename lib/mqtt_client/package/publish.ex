defmodule MqttClient.Package.Publish do
  @opcode 3

  alias MqttClient.Package

  @type qos :: 0|1|2
  @type package_identifier :: 0x0001..0xFFFF

  @opaque t :: %__MODULE__{
    __META__: Package.Meta.t,
    topic: binary() | nil,
    qos: qos(),
    payload: binary(),
    identifier: package_identifier() | nil,
    dup: boolean(),
    retain: boolean()
  }
  defstruct [
    __META__: %Package.Meta{opcode: @opcode, flags: 0},
    identifier: nil,
    topic: nil,
    payload: "",
    qos: 0,
    dup: false,
    retain: false
  ]

  @spec decode(binary()) :: t
  def decode(<<@opcode::4, 0::1, 0::2, retain::1,
               length_prefixed_payload::binary>>) do
    payload = drop_length_prefix(length_prefixed_payload)
    {topic, payload} = decode_message(payload)
    %__MODULE__{qos: 0, identifier: nil,
                dup: false, retain: retain == 1,
                topic: topic, payload: payload
    }
  end
  def decode(<<@opcode::4, dup::1, qos::integer-size(2), retain::1,
             length_prefixed_payload::binary>>) do
    payload = drop_length_prefix(length_prefixed_payload)
    {topic, identifier, payload} = decode_message_with_id(payload)
    %__MODULE__{qos: qos, identifier: identifier,
                dup: dup == 1, retain: retain == 1,
                topic: topic, payload: payload
    }
  end

  defp drop_length_prefix(payload) do
    case payload do
      <<0::1, _::7, r::binary>> -> r
      <<1::1, _::7, 0::1, _::7, r::binary>> -> r
      <<1::1, _::7, 1::1, _::7, 0::1, _::7, r::binary>> -> r
      <<1::1, _::7, 1::1, _::7, 1::1, _::7, 0::1, _::7, r::binary>> -> r
    end
  end

  defp decode_message(<<topic_length::big-integer-size(16), msg::binary>>) do
    <<topic::binary-size(topic_length), payload::binary>> = msg
    {topic, payload}
  end
  defp decode_message_with_id(<<topic_length::big-integer-size(16), msg::binary>>) do
    <<topic::binary-size(topic_length),
      identifier::big-integer-size(16),
      payload::binary>> = msg
    {topic, identifier, payload}
  end


  # Protocols ----------------------------------------------------------
  defimpl MqttClient.Encodable do
    @spec encode(Package.Publish.t) :: iodata()
    def encode(%Package.Publish{identifier: nil, qos: 0} = t) do
      [ Package.Meta.encode(%{t.__META__|flags: encode_flags(t)}),
        Package.variable_length_encode([
          Package.length_encode(t.topic),
          t.payload
        ])
      ]
    end
    def encode(%Package.Publish{identifier: identifier, qos: qos} = t)
    when identifier in 0x0001..0xFFFF and qos in 1..2 do
      [ Package.Meta.encode(%{t.__META__|flags: encode_flags(t)}),
        Package.variable_length_encode([
          Package.length_encode(t.topic),
          <<identifier::big-integer-size(16)>>,
          t.payload
        ])
      ]
    end

    defp encode_flags(%{dup: dup, qos: qos, retain: retain}) do
      <<flags::4>> = <<flag(dup)::1, qos::integer-size(2), flag(retain)::1>>
      flags
    end

    defp flag(f) when f in [0, nil, false], do: 0
    defp flag(_), do: 1
  end
end
