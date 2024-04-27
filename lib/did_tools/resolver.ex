defmodule DIDTools.Resolver do
  require Logger
  alias DIDTools.DID
  alias DIDTools.Document

  # TODO: take care of handle.invalid

  @req_options [
    max_retries: 5,
    connect_options: [timeout: 5_000],
    receive_timeout: 5_000
  ]

  # Cloudflare DNS by default
  @dns_options_default [nameservers: [{{1, 1, 1, 1}, 53}, {{1, 1, 0, 0}, 53}], timeout: 5_000]
  @dns_options Keyword.merge(
                 @dns_options_default,
                 Application.compile_env(:did_tools, :dns_options, [])
               )
  @plc_directory_url "https://plc.directory"
  @atproto_subdomain "_atproto"
  @atproto_subdomain_value_prefix "did="
  # must be https on real world
  @http_well_known_path "/.well-known/atproto-did"

  # > The .test TLD is intended for examples, testing, and development. It may be used in atproto development, but should fail in real-world environments.
  @blocked_tlds ~w(alt arpa example internal invalid local localhost onion)

  @moduledoc """

  Resolver for ATProto handles or DID. Following https://atproto.com/specs/handle spec.

  ## Usage

      iex> alias DIDTools.{Resolver, DID, Document}
      iex> {:ok, did} = Resolver.did_by_handle("arathunku.com")
      {:ok, %DID{did: "did:plc:yww4iq4ogs7f4bmqbiwfzbck", type: :plc, resolver: :dns}}
      iex> {:ok, _doc} = DIDTools.Resolver.doc_by_did(did);
      {:ok, %Document{
         did: did,
         doc: %{
           "@context" => ["https://www.w3.org/ns/did/v1",
            "https://w3id.org/security/multikey/v1",
            "https://w3id.org/security/suites/secp256k1-2019/v1"],
           "alsoKnownAs" => ["at://arathunku.com"],
           "id" => "did:plc:yww4iq4ogs7f4bmqbiwfzbck",
           "service" => [
             %{
               "id" => "#atproto_pds",
               "serviceEndpoint" => "https://enoki.us-east.host.bsky.network",
               "type" => "AtprotoPersonalDataServer"
             }
           ],
           "verificationMethod" => [
             %{
               "controller" => "did:plc:yww4iq4ogs7f4bmqbiwfzbck",
               "id" => "did:plc:yww4iq4ogs7f4bmqbiwfzbck#atproto",
               "publicKeyMultibase" => "zQ3shQ81CThGCgKCogk2Ci3DpHwNJZRjQK1ii2LfWtEDPw37G",
               "type" => "Multikey"
             }
           ]
         }
       }}

      iex> alias DIDTools.{Resolver, DID, Document}
      iex> Resolver.doc_by_did("did:web:feed.atproto.blue")
      {:ok, %Document{
         did: %DID{
           did: "did:web:feed.atproto.blue",
           type: :web,
           resolver: nil
         },
         doc: %{
           "@context" => ["https://www.w3.org/ns/did/v1"],
           "id" => "did:web:feed.atproto.blue",
           "service" => [
             %{
               "id" => "#bsky_fg",
               "serviceEndpoint" => "https://feed.atproto.blue",
               "type" => "BskyFeedGenerator"
             }
           ]
         }
       }}
  """

  @doc """
  Get DID by handle. It will first try to resolve by DNS, then by HTTP.

  DNS resolve expects to find a TXT record with the key `_atproto` and a value starting with `did=`.
  Right now defaults to Cloudflare DNS nameservers, but alternative nameserver can be configured.
  (`config :did_tools, dns_options: [nameservers: [{{8, 8, 8, 8}, 53}, {{8, 8, 4, 4}, 53}]`).

  HTTP resolve expects to receive a plain text content with a DID string
  at `https://<handle>/.well-known/atproto-did`.

  Timeouts and max redirects are very limited (within ~5s and 5 redirects).
  """
  @spec did_by_handle(String.t()) :: {:ok, DID.t()} | {:error, {atom(), any()}}
  def did_by_handle(handle) do
    handle = handle |> String.downcase() |> String.trim_leading("@")
    tld = String.split(handle, ".") |> List.last()

    if tld in @blocked_tlds do
      {:error, {:blocked_tld, tld}}
    else
      resolve_by_dns(handle) || resolve_by_http(handle) || {:error, {:not_found, handle}}
    end
  end

  @doc """
  Fetches a DID document by DID string or DID struct.

  See `DIDTools.Document` for the document structure and available methods.
  """
  @spec doc_by_did(String.t()) :: {:ok, Document.t()} | {:error, {atom(), any()}}
  @spec doc_by_did(DID.t()) :: {:ok, Document.t()} | {:error, {atom(), any()}}
  def doc_by_did(%DID{} = did), do: resolve_did(did)

  def doc_by_did(did) do
    with {:ok, did} <- DID.new(did) do
      resolve_did(did)
    end
  end

  defp resolve_by_http(handle) do
    url = %URI{scheme: "https", host: handle, path: @http_well_known_path} |> URI.to_string()
    req = Req.new(@req_options)

    case Req.get(req, url: url) do
      {:ok, %{status: status, body: body}} when status >= 200 and status < 300 ->
        body
        |> DID.new(:http)

      {:ok, %{status: status}} ->
        Logger.debug(fn -> "HTTP request to #{url} returned status #{status}" end)
        nil

      _ ->
        nil
    end
  end

  defp resolve_by_dns(handle) do
    case :inet_res.lookup(
           String.to_charlist(@atproto_subdomain <> "." <> handle),
           :in,
           :txt,
           @dns_options
         ) do
      [records] when records != [] ->
        records
        |> Stream.map(&to_string/1)
        |> Stream.filter(&String.starts_with?(&1, @atproto_subdomain_value_prefix))
        |> Stream.take(1)
        |> Stream.map(&String.trim_leading(&1, @atproto_subdomain_value_prefix))
        |> Enum.to_list()
        |> List.first()
        |> case do
          nil -> nil
          did -> DID.new(did, :dns)
        end

      _ ->
        nil
    end
  end

  defp resolve_did(%DID{type: :web} = did) do
    Req.new(@req_options)
    |> Req.Request.merge_options(base_url: "https://" <> DID.domain(did))
    |> Req.merge(url: "/.well-known/did.json")
    |> resolve_did_request(did)
  end

  defp resolve_did(%DID{type: :plc} = did) do
    Req.new(@req_options)
    |> Req.Request.merge_options(base_url: @plc_directory_url)
    |> Req.merge(url: "/" <> did.did)
    |> resolve_did_request(did)
  end

  defp resolve_did_request(req, did) do
    case Req.get(req) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        with {:ok, doc} <- Jason.decode(body) do
          {:ok, %Document{did: did, doc: doc}}
        end

      {:ok, %{status: 200, body: doc}} when is_map(doc) ->
        {:ok, %Document{did: did, doc: doc}}

      result ->
        {:error, {:invalid_plc_result, result}}
    end
  end
end
