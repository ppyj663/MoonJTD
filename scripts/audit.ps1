param(
  [int]$MinimumProductionLines = 4000,
  [int]$MinimumCommits = 10
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$requiredFiles = @(
  "README.mbt.md",
  "LICENSE",
  "THIRD_PARTY_NOTICES.md",
  "moon.mod",
  ".github/workflows/ci.yml",
  "docs/conformance.md",
  "docs/plans/2026-09-19-moonjtd-design.md",
  "docs/plans/2026-09-19-moonjtd-implementation.md"
)

foreach ($relativePath in $requiredFiles) {
  $absolutePath = Join-Path $repositoryRoot $relativePath
  if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
    throw "Required repository file is missing: $relativePath"
  }
}

$moduleText = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "moon.mod")
foreach ($expected in @(
  'name = "ppyj663/moonjtd"',
  'license = "Apache-2.0"',
  'repository = "https://github.com/ppyj663/MoonJTD"'
)) {
  if (-not $moduleText.Contains($expected)) {
    throw "moon.mod is missing required metadata: $expected"
  }
}

$productionFiles = @(
  Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File -Filter "*.mbt" |
    Where-Object {
      $_.FullName -notmatch '[\\/]_build[\\/]' -and
      $_.Name -notmatch '(_test|_wbtest)\.mbt$'
    }
)
if ($productionFiles.Count -eq 0) {
  throw "No authored MoonBit production files were found."
}

$productionLines = 0
foreach ($file in $productionFiles) {
  $productionLines += (Get-Content -LiteralPath $file.FullName | Measure-Object -Line).Lines
}
Write-Output "Authored non-test MoonBit lines: $productionLines"
if ($productionLines -lt $MinimumProductionLines) {
  throw "Production MoonBit source has $productionLines lines; required $MinimumProductionLines."
}

$forbidden = @('TODO', 'FIXME', 'placeholder', 'Hello World')
foreach ($term in $forbidden) {
  $hits = @($productionFiles | Select-String -SimpleMatch $term)
  if ($hits.Count -gt 0) {
    throw "Production source contains forbidden unfinished marker '$term'."
  }
}

$commitText = (& git -C $repositoryRoot rev-list --count HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not inspect Git history."
}
$commitCount = [int]$commitText
Write-Output "Git commits: $commitCount"
if ($commitCount -lt $MinimumCommits) {
  throw "Git history has $commitCount commits; required $MinimumCommits."
}

$noticeText = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "THIRD_PARTY_NOTICES.md")
foreach ($term in @('RFC 8927', 'AI assistance', 'does not copy', '71ca275847318717c36f5a2322a8061070fe185d')) {
  if (-not $noticeText.Contains($term)) {
    throw "THIRD_PARTY_NOTICES.md is missing disclosure text: $term"
  }
}

Write-Output "Repository audit passed."
