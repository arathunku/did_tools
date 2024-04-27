# DIDTools

[![Actions Status](https://github.com/arathunku/did_tools/actions/workflows/elixir-build-and-test.yml/badge.svg)](https://github.com/arathunku/did_tools/actions/workflows/elixir-build-and-test.yml) 
[![Hex.pm](https://img.shields.io/hexpm/v/did_tools.svg?style=flat)](https://hex.pm/packages/did_tools)
[![Documentation](https://img.shields.io/badge/hex-docs-lightgreen.svg?style=flat)](https://hexdocs.pm/did_tools)
[![License](https://img.shields.io/hexpm/l/did_tools.svg?style=flat)](https://github.com/arathunku/did_tools/blob/main/LICENSE.md)

<!-- @moduledoc -->

Set of tools to work with Distributed Identifiers (DIDs) in Bluesky / AT Protocol.

## Installation

```elixir
def deps do
  [
    {:did_tools, "~> 0.1.0"}
  ]
end
```

## Usage

See `DIDTools.Resolver` module for more details usage.

```elixir
iex> DIDTools.Resolver.did_by_handle("arathunku.com")
{:ok,
 %DIDTools.DID{
   did: "did:plc:yww4iq4ogs7f4bmqbiwfzbck",
   type: :plc,
   resolver: :dns
 }}


iex> DIDTools.Resolver.doc_by_did("did:plc:ragtjsm2j2vknwkz3zp4oxrd")
{:ok,
 %DIDTools.Document{
   did: %DIDTools.DID{
     did: "did:plc:ragtjsm2j2vknwkz3zp4oxrd",
     type: :plc,
     resolver: nil
   },
   doc: %{
     "@context" => ["https://www.w3.org/ns/did/v1",
      "https://w3id.org/security/multikey/v1",
      "https://w3id.org/security/suites/secp256k1-2019/v1"],
     "alsoKnownAs" => ["at://pfrazee.com"],
     "id" => "did:plc:ragtjsm2j2vknwkz3zp4oxrd",
     "service" => [
       %{
         "id" => "#atproto_pds",
         "serviceEndpoint" => "https://morel.us-east.host.bsky.network",
         "type" => "AtprotoPersonalDataServer"
       }
     ],
     "verificationMethod" => [
       %{
         "controller" => "did:plc:ragtjsm2j2vknwkz3zp4oxrd",
         "id" => "did:plc:ragtjsm2j2vknwkz3zp4oxrd#atproto",
         "publicKeyMultibase" => "zQ3shbTzUCq5zuk7oSj5zaJndqWhjwGDaGuvBXpjg8C19qssW",
         "type" => "Multikey"
       }
     ]
   }
 }}
```
