defmodule DIDTools.Document do
  alias DIDTools.DID

  @type t() :: %__MODULE__{
          did: DID.t(),
          doc: any()
        }
  @enforce_keys ~w(did doc)a
  defstruct did: nil, doc: nil

  @doc """
  Returns a list of handles from a doc. They may not be all validated.

  Call `get_validated_handle/1` to get the first validated handle.
  """
  @spec get_handles(t()) :: [String.t()]
  def get_handles(%__MODULE__{doc: %{"alsoKnownAs" => handles}}) do
    handles
    |> Stream.filter(&String.starts_with?(&1, "at://"))
    |> Stream.map(&String.trim_leading(&1, "at://"))
    |> Enum.to_list()
  end

  def get_handles(%__MODULE__{}), do: []

  @doc """
  Returns first validated handle
  """
  @spec get_validated_handle(t()) :: String.t() | nil
  def get_validated_handle(%__MODULE__{did: %{did: did}} = doc) do
    get_handles(doc)
    |> Enum.find(fn handle ->
      case DIDTools.Resolver.did_by_handle(handle) do
        {:ok, %{did: ^did}} -> true
        _ -> false
      end
    end)
  end

  @doc """
  Finds serviceEndpoint for PDS service and returns it if it's present.
  """
  @spec pds_endpoint(t()) :: String.t() | nil
  def pds_endpoint(doc),
    do:
      Map.get(
        get_service(doc, "atproto_pds", "AtprotoPersonalDataServer") || %{},
        "serviceEndpoint"
      )

  @doc """
  Finds serviceEndpoint for labeler service and returns it if it's present.
  """
  @spec labeler_endpoint(t()) :: String.t() | nil
  def labeler_endpoint(doc),
    do: Map.get(get_service(doc, "atproto_labeler", "AtprotoLabeler") || %{}, "serviceEndpoint")

  @doc false
  def get_service(doc, "atproto_pds" = key, "AtprotoPersonalDataServer" = type),
    do: do_get_service(doc, key, type)

  def get_service(doc, "atproto_labeler" = key, "AtprotoLabeler" = type),
    do: do_get_service(doc, key, type)

  defp do_get_service(%__MODULE__{doc: %{"service" => services}}, key, type) do
    id = "##{key}"

    Enum.find(services, fn
      %{"type" => ^type, "id" => ^id} -> true
      _ -> false
    end)
  end

  defp do_get_service(%__MODULE__{doc: %{}}, _, _), do: nil
end
