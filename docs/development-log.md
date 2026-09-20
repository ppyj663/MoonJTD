# Development history

MoonJTD was developed as a new project, independently of MoonAvro and
MoonAttest. The Git history is intentionally preserved rather than squashed so
reviewers can follow feature boundaries and verification work.

## Baseline and core model

- `0bff7c4` establishes project metadata, licensing, and acceptance gates.
- `c4aaf30` defines the eight RFC 8927 schema forms and JSON Pointer model.
- `dce5d2c` adds strict recursive schema parsing.
- `0ff1c8c` adds bounded semantic schema checks.
- `5d8f019` implements scalar ranges and RFC 3339 timestamp semantics.
- `84e0953` validates JSON instances with structured diagnostic paths.

## Product capabilities

- `493426c` serializes and formats schema documents.
- `881ea42` generates deterministic MoonBit type declarations.
- `6c739c7` adds schema statistics and lint analysis.
- `31c62b3` adds the typed schema builder API.
- `6c462e0` adds the JavaScript command-line interface.
- `45ed022` emits machine-readable and Markdown reports.
- `71375e7` adds runnable quickstart and code-generation examples.
- `ff5f078` adds the schema-bound JSON codec.

## Quality and conformance

- `7af2d67` adds CI, coverage, source-size, provenance, example, and CLI gates.
- Pull request `#1` merges the complete MVP without squashing its feature
  commits.
- `01e76f9` enforces RFC 8927 keyword legality and discriminator constraints.
- `296d8a2` aligns properties-form diagnostic paths with the specification.
- `98b5681` adds the hash-pinned upstream conformance runner.
- `0501b84` makes all 365 upstream cases a required CI gate.
- Pull request `#2` merges the conformance work without squashing it.

At the conformance merge point `1aab926`, `main` contains 23 commits: 21
focused non-merge commits and two merge commits. Several commits were created
close together because the implementation was prepared and verified in staged
feature slices. Commit timestamps are not presented as elapsed development
time; the code, tests, diffs, PRs, and CI results are the review evidence.
