# MoonJTD

MoonJTD is a MoonBit-native implementation of JSON Type Definition (JTD), as
specified by RFC 8927. It validates schemas and JSON instances, emits standard
`instancePath` / `schemaPath` diagnostics, and generates idiomatic MoonBit
types and JSON codecs.

## Why JTD

JTD is intentionally smaller than JSON Schema. Its eight mutually exclusive
forms map predictably to mainstream type systems, including records, enums,
arrays, dictionaries, nullable values, references, and tagged unions. This
makes it useful for API contracts and source generation where deterministic
types matter more than arbitrary validation constraints.

## Project status

The MVP contains the complete eight-form JTD data model, strict schema checks,
bounded validation, MoonBit type generation, a builder API, schema analysis,
machine-readable reports, a CLI, runnable examples, and multi-target CI.

JTD is an Experimental RFC rather than an IETF Standards Track specification.
MoonJTD states that status explicitly and targets the published RFC semantics.

## Scope

MoonJTD implements RFC 8927. It is not a JSON Schema validator, an Apache Avro
codec, a database migration system, or a general-purpose data-contract
platform.

## Install

```bash
moon add ppyj663/moonjtd
```

The package will be published to Mooncakes after the release audit. Until then,
use the Git repository as the authoritative source.

## Library example

```moonbit nocheck
let document = @jtd.parse_checked_schema(
  "{\"properties\":{\"id\":{\"type\":\"uint32\"}}}",
)

match document {
  Ok(schema) => {
    let errors = @jtd.validate(schema, Json::object(Map([
      ("id", Json::number(7.0)),
    ])))
    println(errors.length())
  }
  Err(errors) => for error in errors { println(error.to_string()) }
}
```

The typed builder avoids raw schema JSON:

```moonbit nocheck
///|
let user = @jtd.jtd_object()
  .required("id", @jtd.jtd_uint32())
  .required("name", @jtd.jtd_string())
  .optional("email", @jtd.jtd_string())
  .build()
```

Run the examples:

```bash
moon run examples/quickstart --target js
moon run examples/codegen --target js
```

## CLI

```text
moonjtd check schema.jtd.json
moonjtd validate schema.jtd.json instance.json
moonjtd generate schema.jtd.json RootType output.mbt
moonjtd inspect schema.jtd.json
moonjtd format schema.jtd.json output.json
```

During development, replace `moonjtd` with `moon run cmd/main --target js --`.

Exit status is `0` for success, `1` for an invalid schema/instance or failed
generation, and `2` for usage or filesystem errors.

## Validation safety

`ValidationOptions` bounds the number of diagnostics, instance depth,
reference depth, and visited nodes. `SchemaCheckOptions` independently bounds
untrusted schema traversal. Recursive references therefore fail closed instead
of overflowing the runtime stack indefinitely.

## Testing

```bash
moon fmt --check
moon check --target js
moon test --target js
moon test --target wasm-gc
moon test --target native
moon coverage analyze
```

## Standards and provenance

- RFC 8927, *JSON Type Definition*, November 2020.
- RFC 6901 JSON Pointer paths for validation diagnostics.
- RFC 3339 timestamps as refined by RFC 8927.

See `THIRD_PARTY_NOTICES.md` for source and AI-assistance disclosure. No source
code from another JTD implementation is copied into this repository.

## License

Apache-2.0. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.
