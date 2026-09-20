param(
  [double]$MinimumPercent = 75
)

$ErrorActionPreference = "Stop"

$moonCommand = Get-Command moon -ErrorAction SilentlyContinue
if ($moonCommand) {
  $moonExecutable = $moonCommand.Source
} else {
  $moonExecutable = Join-Path $env:USERPROFILE ".moon/bin/moon.exe"
  if (-not (Test-Path -LiteralPath $moonExecutable -PathType Leaf)) {
    throw "MoonBit CLI was not found on PATH or in the standard user installation directory."
  }
}

$coverageOutput = @(
  & $moonExecutable coverage analyze -p "ppyj663/moonjtd" -- -f summary 2>&1
)
$moonExitCode = $LASTEXITCODE
$coverageText = $coverageOutput -join [Environment]::NewLine
Write-Output $coverageText

if ($moonExitCode -ne 0) {
  throw "MoonBit coverage analysis failed with exit code $moonExitCode."
}

$coverageMatch = [regex]::Match(
  $coverageText,
  "(?m)^Total:\s*(\d+)\s*/\s*(\d+)\s*$"
)
if (-not $coverageMatch.Success) {
  throw "Could not parse the MoonBit coverage summary."
}

$coveredLines = [double]$coverageMatch.Groups[1].Value
$totalLines = [double]$coverageMatch.Groups[2].Value
if ($totalLines -le 0) {
  throw "MoonBit reported no instrumented library lines."
}

$coveragePercent = 100 * $coveredLines / $totalLines
$formattedPercent = "{0:N1}" -f $coveragePercent
Write-Output "Library line coverage: $formattedPercent% (minimum $MinimumPercent%)"

if ($coveragePercent -lt $MinimumPercent) {
  throw "Coverage $formattedPercent% is below the required $MinimumPercent%."
}

if ($env:GITHUB_STEP_SUMMARY) {
  Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value "MoonJTD library line coverage: **$formattedPercent%** (minimum $MinimumPercent%)."
}
