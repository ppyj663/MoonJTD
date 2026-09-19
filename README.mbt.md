# MoonJTD

MoonJTD is a MoonBit-native implementation of JSON Type Definition (JTD), as
specified by RFC 8927. It validates schemas and JSON instances, emits standard
`instancePath` / `schemaPath` diagnostics, and generates idiomatic MoonBit
types and JSON codecs.

## Project status

The repository is under active MVP development for OSC 2026. The intended MVP
contains the complete eight-form JTD data model, strict schema checks, bounded
validation, a MoonBit code generator, a CLI, conformance fixtures, and CI on
the JavaScript, Wasm-GC, and native targets.

JTD is an Experimental RFC rather than an IETF Standards Track specification.
MoonJTD states that status explicitly and targets the published RFC semantics.

## Scope

MoonJTD implements RFC 8927. It is not a JSON Schema validator, an Apache Avro
codec, a database migration system, or a general-purpose data-contract
platform.

## License

Apache-2.0. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.
