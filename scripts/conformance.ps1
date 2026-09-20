param(
  [string]$Revision = '71ca275847318717c36f5a2322a8061070fe185d'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root '_build/conformance'
$moon = Get-Command moon -ErrorAction SilentlyContinue
if ($null -eq $moon) {
  $fallback = Join-Path $env:USERPROFILE '.moon/bin/moon.exe'
  if (-not (Test-Path -LiteralPath $fallback)) {
    throw 'MoonBit CLI was not found on PATH or in the default user installation.'
  }
  $moonPath = $fallback
} else {
  $moonPath = $moon.Source
}

$files = @(
  @{
    Name = 'validation.json'
    Sha256 = 'CA2EE582044051A690E0A5B79E81F26F4A51623D8A5B73F7A1D488B6E7B11994'
  },
  @{
    Name = 'invalid_schemas.json'
    Sha256 = '96AC0AB36D73389F2BCA1F64896213CF4D30BFC88BE8DE7B6F1A633CC07BE26D'
  }
)

if ($Revision -ne '71ca275847318717c36f5a2322a8061070fe185d') {
  throw 'Only the audited, hash-pinned upstream revision is supported.'
}

New-Item -ItemType Directory -Force -Path $output | Out-Null
$base = "https://raw.githubusercontent.com/jsontypedef/json-typedef-spec/$Revision/tests"
foreach ($file in $files) {
  $destination = Join-Path $output $file.Name
  Invoke-WebRequest -Uri "$base/$($file.Name)" -OutFile $destination
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash
  if ($actual -ne $file.Sha256) {
    throw "SHA-256 mismatch for $($file.Name): expected $($file.Sha256), got $actual"
  }
}

Push-Location $root
try {
  & $moonPath run cmd/conformance --target js -- `
    '_build/conformance/validation.json' `
    '_build/conformance/invalid_schemas.json'
  if ($LASTEXITCODE -ne 0) {
    throw "Conformance runner failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}
