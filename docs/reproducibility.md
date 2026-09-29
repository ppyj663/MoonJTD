# Reproducibility

The current local toolchain, also used by the successful CI run on 2026-09-27,
meets the committee's minimum compiler requirement `moonc v0.10.14+7d59c7ec9`:

```text
moon 0.1.20260920 (914d7da 2026-09-20)
moonc v0.10.14+7d59c7ec9 (2026-09-18)
moonrun 0.1.20260920 (914d7da 2026-09-20)
```

The project depends only on `moonbitlang/core/json` and core runtime modules.
Generated `pkg.generated.mbti` files are committed and checked by `moon info`
in CI, so a public-interface drift fails the build.

CI uses the official MoonBit Unix installer and verifies that `moonc` is at
least `v0.10.14+7d59c7ec9` before running checks. The check accepts later
compiler versions and rejects an unverified build with the same `0.10.14`
version number. Each Actions log records the full installed toolchain version.
The runner image is fixed to `ubuntu-24.04` instead of the moving
`ubuntu-latest` alias.

For a local reproduction:

```powershell
moon version --all
pwsh ./scripts/check-toolchain.ps1
moon fmt --check
moon build --target js
moon build --target wasm-gc
moon check --target js
moon test --target js
moon check --target wasm-gc
moon test --target wasm-gc
moon check --target native
moon test --target native
moon run examples/quickstart --target js
moon run examples/codegen --target js
pwsh ./scripts/cli-smoke.ps1
pwsh ./scripts/coverage.ps1 -MinimumPercent 75
pwsh ./scripts/conformance.ps1
pwsh ./scripts/audit.ps1
```

Native tests require a C compiler (`clang`, `gcc`, `cc`, or MSVC `cl`). Static
native checking does not require one. The conformance script requires network
access only to fetch two hash-pinned upstream JSON files; cached files remain
under ignored `_build/conformance/` storage.
