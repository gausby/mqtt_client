defmodule MqttClient.Package.Pingreq do
  @opcode 12

  alias MqttClient.Package

  @opaque t :: %__MODULE__{
    __META__: Package.Meta.t()
  }
  defstruct [
    __META__: %Package.Meta{opcode: @opcode, flags: 0}
  ]

  @spec decode(binary()) :: t
  def decode(<<@opcode::4, 0::4, 0>>) do
    %__MODULE__{}
  end

  # Protocols ----------------------------------------------------------
  defimpl MqttClient.Encodable do
    @spec encode(Package.Pingreq.t()) :: iodata()
    def encode(%Package.Pingreq{} = t) do
      [Package.Meta.encode(t.__META__), 0]
    end
  end
end
