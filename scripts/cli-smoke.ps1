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
$missingSchema = "fixtures/.missing-$runId.jtd.json"
$missingInstance = "fixtures/.missing-$runId.json"

function Invoke-CliCase {
  param(
    [string]$Name,
    [int]$ExpectedExitCode,
    [string[]]$MoonArguments
  )

  Write-Output "== $Name (expected exit $ExpectedExitCode) =="
  $output = @(& $moonPath @MoonArguments 2>&1)
  $actualExitCode = $LASTEXITCODE
  foreach ($line in $output) {
    Write-Output ([string]$line)
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
  Invoke-CliCase 'valid schema check' 0 @('run', 'cmd/main', '--target', 'js', '--', 'check', 'fixtures/user.jtd.json')
  Invoke-CliCase 'valid instance' 0 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', 'fixtures/user-valid.json')
  Invoke-CliCase 'invalid instance' 1 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', 'fixtures/user-invalid.json')
  Invoke-CliCase 'invalid schema' 1 @('run', 'cmd/main', '--target', 'js', '--', 'check', 'fixtures/invalid-schema.json')
  Invoke-CliCase 'malformed instance JSON' 1 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', 'fixtures/malformed-json.json')
  Invoke-CliCase 'missing schema file' 2 @('run', 'cmd/main', '--target', 'js', '--', 'check', $missingSchema)
  Invoke-CliCase 'missing instance file' 2 @('run', 'cmd/main', '--target', 'js', '--', 'validate', 'fixtures/user.jtd.json', $missingInstance)
  Invoke-CliCase 'inspect' 0 @('run', 'cmd/main', '--target', 'js', '--', 'inspect', 'fixtures/user.jtd.json')
  Invoke-CliCase 'generate' 0 @('run', 'cmd/main', '--target', 'js', '--', 'generate', 'fixtures/user.jtd.json', 'User', $generatedPath)
  Invoke-CliCase 'format' 0 @('run', 'cmd/main', '--target', 'js', '--', 'format', 'fixtures/user.jtd.json', $formattedPath)
  Invoke-CliCase 'unknown command' 2 @('run', 'cmd/main', '--target', 'js', '--', 'unknown')
} finally {
  Pop-Location
  foreach ($path in @($generatedPath, $formattedPath)) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      Remove-Item -LiteralPath $path
    }
  }
}

Write-Output 'CLI smoke checks passed.'
