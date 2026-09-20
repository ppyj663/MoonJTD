# MoonJTD MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a conformant, bounded RFC 8927 validator and deterministic MoonBit code generator with a usable CLI.

**Architecture:** Parse JSON into a typed eight-form schema AST, perform root-aware semantic checks and reference compilation, then validate instances while tracking RFC JSON Pointer paths. Keep generation and command-line I/O in separate packages so the core remains portable.

**Tech Stack:** MoonBit, `moonbitlang/core` JSON values, MoonBit tests and coverage, GitHub Actions.

---

### Task 1: Repository and public contract

**Files:** `README.mbt.md`, `moon.mod`, `docs/plans/*`, `THIRD_PARTY_NOTICES.md`

1. Record the RFC version, non-goals, provenance, and MVP acceptance gates.
2. Run `moon check` and confirm the scaffold is healthy.
3. Commit as `chore: establish MoonJTD project baseline`.

### Task 2: Schema model and paths

**Files:** `schema.mbt`, `path.mbt`, `schema_test.mbt`

1. Write failing construction and JSON Pointer escaping tests.
2. Define all eight forms, scalar kinds, root definitions, and path segments.
3. Run `moon test`, then commit `feat: define RFC 8927 schema model`.

### Task 3: Schema parser

**Files:** `schema_parse.mbt`, `schema_parse_test.mbt`

1. Test each form plus mixed-form and wrong-type failures.
2. Implement strict member classification and recursive parsing.
3. Run tests and commit `feat: parse all JTD schema forms`.

### Task 4: Semantic schema validation

**Files:** `schema_check.mbt`, `schema_check_test.mbt`

1. Test definitions placement, refs, duplicate enums, property overlap, and discriminator constraints.
2. Implement root-aware validation with bounded traversal.
3. Run tests and commit `feat: validate JTD schema semantics`.

### Task 5: Scalar and timestamp semantics

**Files:** `scalar.mbt`, `timestamp.mbt`, matching tests.

1. Test integer boundaries and RFC 3339 valid/invalid forms.
2. Implement scalar classification without lossy coercion.
3. Commit `feat: implement JTD scalar semantics`.

### Task 6: Instance validator

**Files:** `validate.mbt`, `validate_test.mbt`

1. Test all forms, nullable behavior, additional properties, and tagged unions.
2. Emit standard instance and schema paths.
3. Commit `feat: validate JSON instances against JTD`.

### Task 7: Resource limits and diagnostics

**Files:** `limits.mbt`, `diagnostic.mbt`, `limits_test.mbt`

1. Test max errors, depth, refs, and nodes.
2. Add deterministic diagnostic rendering and fail-closed limits.
3. Commit `feat: bound validation and expose diagnostics`.

### Task 8: MoonBit type generation

**Files:** `codegen/model.mbt`, `codegen/render.mbt`, tests.

1. Test identifier sanitizing, structs, enums, arrays, maps, nullable values, and unions.
2. Generate stable formatted declarations.
3. Commit `feat: generate MoonBit types from JTD`.

### Task 9: JSON codec generation

**Files:** `codegen/codec.mbt`, `codegen/codec_test.mbt`

1. Add golden tests for generated decoders and encoders.
2. Generate strict codecs consistent with validator semantics.
3. Commit `feat: generate MoonBit JSON codecs`.

### Task 10: CLI and examples

**Files:** `cmd/moonjtd/*`, `examples/*`

1. Test arguments and exit-status mapping.
2. Implement `check`, `validate`, and `generate`.
3. Commit `feat: add MoonJTD CLI and examples`.

### Task 11: Conformance and differential fixtures

**Files:** `conformance/*`, `scripts/*`, `THIRD_PARTY_NOTICES.md`

1. Pin and document upstream JTD fixtures.
2. Add a runner and representative differential vectors.
3. Commit `test: add RFC 8927 conformance corpus`.

### Task 12: CI, release audit, and documentation

**Files:** `.github/workflows/ci.yml`, `docs/*`, `scripts/audit.ps1`

1. Gate format, check, tests, coverage, examples, source-line count, and provenance.
2. Run all gates locally on supported targets.
3. Commit `ci: enforce MoonJTD release quality gates`.

## Final implementation notes

This file records the plan before implementation. The delivered MVP preserves
the architecture and acceptance criteria but made these reviewed adjustments:

- Resource-limit behavior lives in `validate.mbt` and `schema_check.mbt`
  instead of a separate `limits.mbt`, keeping limits adjacent to the traversal
  state they constrain.
- Type generation is implemented in `codegen.mbt`. JSON encoding and decoding
  are provided by the schema-bound codec in `codec.mbt`; the MVP does not claim
  to generate statically typed codec source.
- The CLI package is `cmd/main`, with separate runnable examples under
  `examples/`.
- Upstream conformance data is not vendored because its repository declares no
  license. `scripts/conformance.ps1` downloads two files from a fixed revision,
  verifies both SHA-256 digests, and invokes `cmd/conformance` from ignored
  build storage.
- The final history contains two reviewed merge commits and more than ten
  focused non-merge commits. Exact feature-to-commit mapping is recorded in
  `docs/development-log.md`.
