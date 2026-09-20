# Reproducibility

The audited local baseline used this MoonBit toolchain:

```text
moon 0.1.20260904 (94521db 2026-09-04)
moonc v0.10.12+1634b282e (2026-09-07)
moonrun 0.1.20260904 (94521db 2026-09-04)
```

The project depends only on `moonbitlang/core/json` and core runtime modules.
Generated `pkg.generated.mbti` files are committed and checked by `moon info`
in CI, so a public-interface drift fails the build.

CI uses the official MoonBit Unix installer and prints the complete installed
version before running checks. This deliberately tests the current supported
toolchain while preserving the exact successful version in each Actions log.
The runner image is fixed to `ubuntu-24.04` instead of the moving
`ubuntu-latest` alias.

For a local reproduction:

```powershell
moon version --all
moon fmt --check
moon check --target js
moon test --target js
moon check --target wasm-gc
moon test --target wasm-gc
moon check --target native
pwsh ./scripts/coverage.ps1 -MinimumPercent 75
pwsh ./scripts/conformance.ps1
pwsh ./scripts/audit.ps1
```

Native tests require a C compiler (`clang`, `gcc`, `cc`, or MSVC `cl`). Static
native checking does not require one. The conformance script requires network
access only to fetch two hash-pinned upstream JSON files; cached files remain
under ignored `_build/conformance/` storage.
