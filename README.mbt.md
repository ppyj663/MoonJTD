# MoonJTD

[![CI](https://github.com/ppyj663/MoonJTD/actions/workflows/ci.yml/badge.svg)](https://github.com/ppyj663/MoonJTD/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

MoonJTD is a MoonBit-native implementation of JSON Type Definition (JTD), as
specified by RFC 8927. It validates schemas and JSON instances, emits standard
`instancePath` / `schemaPath` diagnostics, and generates idiomatic MoonBit
types and a schema-bound JSON codec API.

## Why JTD

JTD is intentionally smaller than JSON Schema. Its eight mutually exclusive
forms map predictably to mainstream type systems, including records, enums,
arrays, dictionaries, nullable values, references, and tagged unions. This
makes it useful for API contracts and source generation where deterministic
types matter more than arbitrary validation constraints.

## Project status

The MVP contains the complete eight-form JTD data model, strict schema checks,
bounded validation, MoonBit type generation, a validated JSON codec API, a
builder API, schema analysis, machine-readable reports, a CLI, runnable
examples, and multi-target CI. The hash-pinned upstream conformance corpus
currently passes all 316 validation cases and all 49 invalid-schema cases.

JTD is an Experimental RFC rather than an IETF Standards Track specification.
MoonJTD states that status explicitly and targets the published RFC semantics.

## Scope

MoonJTD implements RFC 8927. It is not a JSON Schema validator, an Apache Avro
codec, a database migration system, or a general-purpose data-contract
platform.

## Current release status

MoonJTD is currently a source release and has not yet been published to
Mooncakes. Clone the repository to evaluate the library, CLI, and examples:

```bash
git clone https://github.com/ppyj663/MoonJTD.git
cd MoonJTD
moon test --target js
moon run examples/quickstart --target js
```

After the package is published, the intended installation command is
`moon add ppyj663/moonjtd`. Until then, the Git repository is the authoritative
source.

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

## Repository structure

```text
MoonJTD/
├── *.mbt, moon.pkg       # portable core library package
├── cmd/main/             # JavaScript CLI entry point
├── cmd/conformance/      # upstream RFC 8927 corpus runner
├── examples/             # runnable quickstart and code generation demos
├── fixtures/             # small, authored CLI smoke-test inputs
├── docs/                 # design, implementation, provenance, and history
├── scripts/              # coverage, conformance, and repository audits
└── .github/workflows/    # multi-target continuous integration
```

Generated `pkg.generated.mbti` interface files are committed so reviewers can
inspect the public API. Build output, downloaded conformance data, and
Mooncakes working state are ignored.

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
pwsh ./scripts/conformance.ps1
pwsh ./scripts/audit.ps1
```

The audited source totals are 4,389 authored product MoonBit lines (3,930
portable library lines plus 459 CLI/conformance-runner lines), excluding 70
example lines, 824 test lines, generated interfaces, and build output. The
complete MoonBit tree contains 5,283 lines. The release audit requires at least
4,000 authored product lines and 10 Git commits.

The conformance script downloads two data files from a fixed upstream commit,
checks their SHA-256 digests, and keeps them under ignored `_build/` storage.
The files are not redistributed by MoonJTD because their upstream repository
does not declare a license. See the [conformance notes](docs/conformance.md) for
the exact revision, hashes, runner behavior, and reproducibility details.

## Standards and provenance

- [RFC 8927](https://www.rfc-editor.org/rfc/rfc8927), *JSON Type Definition*,
  November 2020.
- [RFC 6901](https://www.rfc-editor.org/rfc/rfc6901) JSON Pointer paths for
  validation diagnostics.
- [RFC 3339](https://www.rfc-editor.org/rfc/rfc3339) timestamps as refined by
  RFC 8927.

See [third-party notices](THIRD_PARTY_NOTICES.md) for source and AI-assistance
disclosure, [development history](docs/development-log.md) for the feature and
commit trail, and [reproducibility](docs/reproducibility.md) for the validated
toolchain. No source code from another JTD implementation is copied into this
repository.

## License

Apache-2.0. See [LICENSE](LICENSE) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
