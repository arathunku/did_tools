defmodule DIDTools.DID do
  @type resolver() :: :http | :dns | nil
  @type t() :: %__MODULE__{
          did: String.t(),
          type: :plc | :web,
          resolver: resolver()
        }
  @enforce_keys ~w(did type resolver)a
  defstruct did: nil, type: nil, resolver: nil

  @spec new(String.t()) ::
          {:ok, t()}
          | {:error, {:invalid_type, String.t()}}
          | {:error, {:invalid_did, String.t()}}

  def new(did), do: new(did, nil)

  @doc """
  Creates a DID data struct from a DID string and a resolver.
  """
  @spec new(String.t(), resolver()) ::
          {:ok, t()}
          | {:error, {:invalid_type, String.t()}}
          | {:error, {:invalid_did, String.t()}}

  def new(did, resolver) when resolver in ~w(nil http dns)a do
    case String.split(did, ":", trim: true) do
      ["did", type, _] when type in ~w(plc web) ->
        {:ok,
         %__MODULE__{
           did: did,
           type: type |> String.to_existing_atom(),
           resolver: resolver
         }}

      ["did", type, _] ->
        {:error, {:invalid_type, type}}

      _ ->
        {:error, {:invalid_did, did}}
    end
  end

  def domain(%__MODULE__{type: :web, did: "did:web:" <> domain}), do: domain
  def domain(_), do: nil
end
