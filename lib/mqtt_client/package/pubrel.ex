defmodule MqttClient.Package.Pubrel do
  @opcode 6

  alias MqttClient.Package

  @type package_identifier :: 0x0001..0xFFFF

  @opaque t :: %__MODULE__{
    __META__: Package.Meta.t(),
    identifier: package_identifier() | nil
  }
  defstruct [
    __META__: %Package.Meta{opcode: @opcode, flags: 0b0010},
    identifier: nil
  ]

  @spec decode(binary()) :: t
  def decode(<<@opcode::4, 2::4, 2, identifier::big-integer-size(16)>>)
  when identifier in 0x0001..0xFFFF do
    %__MODULE__{identifier: identifier}
  end


  # Protocols ----------------------------------------------------------
  defimpl MqttClient.Encodable do
    @spec encode(Package.Pubrel.t()) :: iodata()
    def encode(%Package.Pubrel{identifier: identifier} = t)
    when identifier in 0x0001..0xFFFF do
      [Package.Meta.encode(t.__META__), <<2, t.identifier::big-integer-size(16)>>]
    end
  end
end
