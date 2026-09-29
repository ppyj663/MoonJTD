$ErrorActionPreference = 'Stop'

$moonCommand = Get-Command moon -ErrorAction SilentlyContinue
if ($moonCommand) {
  $moonPath = $moonCommand.Source
} else {
  $moonPath = Join-Path $env:USERPROFILE '.moon/bin/moon.exe'
  if (-not (Test-Path -LiteralPath $moonPath -PathType Leaf)) {
    throw 'MoonBit CLI was not found on PATH or in the standard user installation directory.'
  }
}

$toolchainOutput = (& $moonPath version --all 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
  throw 'Could not read MoonBit toolchain versions.'
}
Write-Output $toolchainOutput.TrimEnd()

$compilerLine = $toolchainOutput -split "`r?`n" |
  Where-Object { $_ -match '^moonc v' } |
  Select-Object -First 1
$match = [regex]::Match(
  [string]$compilerLine,
  '^moonc v(?<version>\d+\.\d+\.\d+)(?:\+(?<revision>[0-9a-f]+))?'
)
if (-not $match.Success) {
  throw 'Could not parse the MoonBit compiler version from `moon version --all`.'
}

$minimum = [version]'0.10.14'
$actual = [version]$match.Groups['version'].Value
$minimumRevision = '7d59c7ec9'
$actualRevision = $match.Groups['revision'].Value
if ($actual -lt $minimum -or ($actual -eq $minimum -and $actualRevision -ne $minimumRevision)) {
  throw "moonc $($match.Value) is below the required v0.10.14+$minimumRevision."
}

Write-Output "Compiler requirement met: $($match.Value) >= v0.10.14+$minimumRevision."
$global:LASTEXITCODE = 0
