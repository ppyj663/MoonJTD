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
  "docs/development-log.md",
  "docs/reproducibility.md",
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

$authoredFiles = @(
  Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File -Filter "*.mbt" |
    Where-Object {
      $_.FullName -notmatch '[\\/]_build[\\/]' -and
      $_.Name -notmatch '(_test|_wbtest)\.mbt$'
    }
)
if ($authoredFiles.Count -eq 0) {
  throw "No authored MoonBit production files were found."
}

$coreLines = 0
$commandLines = 0
$exampleLines = 0
foreach ($file in $authoredFiles) {
  $lineCount = (Get-Content -LiteralPath $file.FullName | Measure-Object -Line).Lines
  $relativePath = [IO.Path]::GetRelativePath($repositoryRoot, $file.FullName).Replace('\', '/')
  if ($relativePath.StartsWith('cmd/')) {
    $commandLines += $lineCount
  } elseif ($relativePath.StartsWith('examples/')) {
    $exampleLines += $lineCount
  } else {
    $coreLines += $lineCount
  }
}

$readmeText = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "README.mbt.md")
foreach ($term in @(
  '## Repository structure',
  '## Current release status',
  'authored product MoonBit lines',
  'docs/development-log.md',
  'THIRD_PARTY_NOTICES.md'
)) {
  if (-not $readmeText.Contains($term)) {
    throw "README.mbt.md is missing required review information: $term"
  }
}

$licenseText = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "LICENSE")
foreach ($term in @('Apache License', 'Version 2.0, January 2004', 'END OF TERMS AND CONDITIONS')) {
  if (-not $licenseText.Contains($term)) {
    throw "LICENSE is not the complete expected Apache-2.0 text: $term"
  }
}
$productLines = $coreLines + $commandLines
Write-Output "Core library MoonBit lines: $coreLines"
Write-Output "Command and conformance MoonBit lines: $commandLines"
Write-Output "Example MoonBit lines (excluded from product gate): $exampleLines"
Write-Output "Authored product MoonBit lines: $productLines"
if ($productLines -lt $MinimumProductionLines) {
  throw "Product MoonBit source has $productLines lines; required $MinimumProductionLines."
}

$forbidden = @('TODO', 'FIXME', 'placeholder', 'Hello World')
foreach ($term in $forbidden) {
  $hits = @($authoredFiles | Select-String -SimpleMatch $term)
  if ($hits.Count -gt 0) {
    throw "Production source contains forbidden unfinished marker '$term'."
  }
}

$commitText = (& git -C $repositoryRoot rev-list --count HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not inspect Git history."
}
$commitCount = [int]$commitText
$focusedCommitText = (& git -C $repositoryRoot rev-list --count --no-merges HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not inspect focused Git history."
}
$focusedCommitCount = [int]$focusedCommitText
Write-Output "Git commits: $commitCount total, $focusedCommitCount non-merge"
if ($focusedCommitCount -lt $MinimumCommits) {
  throw "Git history has $focusedCommitCount non-merge commits; required $MinimumCommits."
}

$noticeText = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "THIRD_PARTY_NOTICES.md")
foreach ($term in @('RFC 8927', 'AI assistance', 'does not copy', '71ca275847318717c36f5a2322a8061070fe185d')) {
  if (-not $noticeText.Contains($term)) {
    throw "THIRD_PARTY_NOTICES.md is missing disclosure text: $term"
  }
}

$trackedPaths = @(& git -C $repositoryRoot ls-files)
if ($LASTEXITCODE -ne 0) {
  throw "Could not inspect tracked repository files."
}
$forbiddenTrackedPaths = @(
  $trackedPaths | Where-Object {
    $_ -match '(^|/)(_build|target|\.mooncakes|\.moonagent)(/|$)' -or
    $_ -match '\.(exe|dll|pem|key)$'
  }
)
if ($forbiddenTrackedPaths.Count -gt 0) {
  throw "Generated, secret-like, or build files are tracked: $($forbiddenTrackedPaths -join ', ')"
}

Write-Output "Repository audit passed."
