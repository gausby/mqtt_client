defmodule MqttClient.Package.Disconnect do
  @opcode 14

  alias MqttClient.Package

  @opaque t :: %__MODULE__{
    __META__: Package.Meta.t()
  }
  defstruct [
    __META__: %Package.Meta{opcode: @opcode, flags: 0}
  ]

  @spec decode(binary()) :: t
  def decode(<<@opcode::4, 0::4, 0>>), do: %__MODULE__{}


  # Protocols ----------------------------------------------------------
  defimpl MqttClient.Encodable do
    @spec encode(Package.Disconnect.t) :: iodata()
    def encode(%Package.Disconnect{} = t) do
      [Package.Meta.encode(t.__META__), 0]
    end
  end
end
