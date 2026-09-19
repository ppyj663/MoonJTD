# MoonJTD Design

## Purpose and boundaries

MoonJTD provides a pure MoonBit implementation of RFC 8927 JSON Type
Definition. The library accepts JSON schema documents, rejects structurally or
semantically invalid schemas, validates JSON values, and produces the standard
JTD error locations. A separate code-generation package turns a checked schema
into deterministic MoonBit declarations and JSON codecs. The project does not
implement JSON Schema, Avro, generic contract governance, or database schema
migration.

## Architecture

The root package contains an explicit algebraic data type for the eight JTD
forms. Parsing is split into syntactic classification and semantic checking so
callers cannot accidentally validate data with an unchecked schema. A compiled
schema stores resolved definition references while retaining source paths for
diagnostics. Validation carries configurable limits for errors, reference
depth, container depth, and visited values.

The `codegen` package maps definitions, property forms, enums, arrays, maps,
nullable values, and discriminator mappings to deterministic MoonBit source.
Unsupported or ambiguous identifiers produce diagnostics instead of silently
changing meaning. The CLI exposes schema checking, data validation, and code
generation without embedding filesystem behavior in the core library.

## Verification

Tests cover every schema form, every scalar boundary, RFC 3339 timestamps,
reference resolution, JSON Pointer escaping, recursion limits, deterministic
code generation, and malformed schemas. Vendored upstream fixtures carry
their original license and pinned revision. CI runs formatting, checking,
tests, coverage, examples, and repository-audit scripts on supported targets.

## Repository history

Development uses a feature branch and at least ten focused commits. Generated
or vendored material is never counted as authored MoonBit source. Source
provenance and AI assistance are documented before release.
