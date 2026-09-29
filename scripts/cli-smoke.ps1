$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$moon = Get-Command moon -ErrorAction SilentlyContinue
if ($moon) {
  $moonPath = $moon.Source
} else {
  $moonPath = Join-Path $env:USERPROFILE '.moon/bin/moon.exe'
  if (-not (Test-Path -LiteralPath $moonPath -PathType Leaf)) {
    throw 'MoonBit CLI was not found on PATH or in the standard user installation directory.'
  }
}

$buildDirectory = Join-Path $repositoryRoot '_build'
if (-not (Test-Path -LiteralPath $buildDirectory -PathType Container)) {
  New-Item -ItemType Directory -Path $buildDirectory | Out-Null
}
$runId = [guid]::NewGuid().ToString('N')
$generatedPath = Join-Path $buildDirectory "cli-smoke-$runId.mbt"
$formattedPath = Join-Path $buildDirectory "cli-smoke-$runId.json"
$reportPath = Join-Path $buildDirectory "cli-smoke-$runId-report.json"
$markdownReportPath = Join-Path $buildDirectory "cli-smoke-$runId-report.md"
$unavailableOutputDirectory = Join-Path $buildDirectory "cli-smoke-missing-$runId"
$unwritableGeneratedPath = Join-Path $unavailableOutputDirectory 'generated.mbt'
$unwritableFormattedPath = Join-Path $unavailableOutputDirectory 'formatted.json'
$missingSchema = "fixtures/.missing-$runId.jtd.json"
$missingInstance = "fixtures/.missing-$runId.json"

function Invoke-CliCase {
  param(
    [string]$Name,
    [int]$ExpectedExitCode,
    [string[]]$MoonArguments,
    [string[]]$ExpectedText = @()
  )

  Write-Output "== $Name (expected exit $ExpectedExitCode) =="
  $output = @(& $moonPath @MoonArguments 2>&1)
  $actualExitCode = $LASTEXITCODE
  foreach ($line in $output) {
    Write-Output ([string]$line)
  }
  if ($ExpectedText.Count -gt 0) {
    $combinedOutput = [string]::Join("`n", [string[]]$output)
    foreach ($expected in $ExpectedText) {
      if (-not $combinedOutput.Contains($expected)) {
        throw "$Name output did not contain '$expected'."
      }
    }
  }
  if ($actualExitCode -ne $ExpectedExitCode) {
    throw "$Name returned exit $actualExitCode; expected $ExpectedExitCode."
  }
  Write-Output "PASS $Name"
}

Push-Location $repositoryRoot
try {
  Invoke-CliCase 'help' 0 @('run', 'cmd/main', '--target', 'js', '--', '--help')
  Invoke-CliCase 'version' 0 @('run', 'cmd/main', '--target', 'js', '--', '--version')
  Invoke-CliCase 'missing required arguments' 2 @('run', 'cmd/main', '--target', 'js', '--', 'validate')
  Invoke-CliCase 'valid schema check' 0 @('run', 'cmd/main', '--target', 'js', '--', 'check', 'fixtures/user.jtd.json')
  Invoke-CliCase 'valid instance' 0 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', 'fixtures/user-valid.json')
  Invoke-CliCase 'invalid instance' 1 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', 'fixtures/user-invalid.json')
  Invoke-CliCase 'valid instance JSON report' 0 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', 'fixtures/user-valid.json', '--format', 'json') -ExpectedText @('"valid":true', '"errors":[]', '"truncated":false')
  Invoke-CliCase 'invalid instance JSON report' 1 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', 'fixtures/user-invalid.json', '--format', 'json') -ExpectedText @('"valid":false', '"instancePath":"/id"', '"schemaPath":"/definitions/user-id/type"')
  Invoke-CliCase 'validation report missing format' 2 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', 'fixtures/user-valid.json', '--format')
  Invoke-CliCase 'validation report unsupported format' 2 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', 'fixtures/user-valid.json', '--format', 'yaml')
  Invoke-CliCase 'invalid schema' 1 @('run', 'cmd/main', '--target', 'js', '--', 'check', 'fixtures/invalid-schema.json')
  Invoke-CliCase 'malformed instance JSON' 1 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', 'fixtures/malformed-json.json')
  Invoke-CliCase 'missing schema file' 2 @('run', 'cmd/main', '--target', 'js', '--', 'check', $missingSchema)
  Invoke-CliCase 'missing instance file' 2 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', $missingInstance)
  Invoke-CliCase 'inspect' 0 @('run', 'cmd/main', '--target', 'js', '--', 'inspect', 'fixtures/user.jtd.json')
  Invoke-CliCase 'report JSON to stdout' 0 @('run', 'cmd/main', '--target', 'js', '--', 'report', 'fixtures/user.jtd.json') -ExpectedText '"rootForm": "properties"'
  Invoke-CliCase 'report Markdown to stdout' 0 @('run', 'cmd/main', '--target', 'js', '--', 'report', 'fixtures/user.jtd.json', '--format', 'markdown') -ExpectedText '## Node inventory'
  Invoke-CliCase 'report JSON to file' 0 @('run', 'cmd/main', '--target', 'js', '--', 'report', 'fixtures/user.jtd.json', '--format', 'json', $reportPath)
  $reportData = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
  if ($reportData.rootForm -ne 'properties' -or $reportData.nodes.Count -lt 1) {
    throw 'JSON report file did not contain the schema summary and node inventory.'
  }
  Invoke-CliCase 'report Markdown to file' 0 @('run', 'cmd/main', '--target', 'js', '--', 'report', 'fixtures/user.jtd.json', $markdownReportPath, '--format', 'markdown')
  $markdownReport = Get-Content -Raw -LiteralPath $markdownReportPath
  if (-not $markdownReport.Contains('# MoonJTD schema report') -or -not $markdownReport.Contains('## Node inventory')) {
    throw 'Markdown report file did not contain its title and node inventory.'
  }
  Invoke-CliCase 'report missing format value' 2 @('run', 'cmd/main', '--target', 'js', '--', 'report', 'fixtures/user.jtd.json', '--format')
  Invoke-CliCase 'report unsupported format' 2 @('run', 'cmd/main', '--target', 'js', '--', 'report', 'fixtures/user.jtd.json', '--format', 'html')
  Invoke-CliCase 'report unknown option' 2 @('run', 'cmd/main', '--target', 'js', '--', 'report', 'fixtures/user.jtd.json', '--compact')
  Invoke-CliCase 'report output write failure' 2 @('run', 'cmd/main', '--target', 'js', '--', 'report', 'fixtures/user.jtd.json', $unwritableFormattedPath)
  Invoke-CliCase 'generate' 0 @('run', 'cmd/main', '--target', 'js', '--', 'generate', 'fixtures/user.jtd.json', 'User', $generatedPath)
  Invoke-CliCase 'format' 0 @('run', 'cmd/main', '--target', 'js', '--', 'format', 'fixtures/user.jtd.json', $formattedPath)
  Invoke-CliCase 'generated output write failure' 2 @('run', 'cmd/main', '--target', 'js', '--', 'generate', 'fixtures/user.jtd.json', 'User', $unwritableGeneratedPath)
  Invoke-CliCase 'formatted output write failure' 2 @('run', 'cmd/main', '--target', 'js', '--', 'format', 'fixtures/user.jtd.json', $unwritableFormattedPath)
  Invoke-CliCase 'unknown command' 2 @('run', 'cmd/main', '--target', 'js', '--', 'unknown')
} finally {
  Pop-Location
  foreach ($path in @($generatedPath, $formattedPath, $reportPath, $markdownReportPath)) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      Remove-Item -LiteralPath $path
    }
  }
}

$global:LASTEXITCODE = 0
Write-Output 'CLI smoke checks passed.'
