Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$ExpectedMigrations = @(
    '20260829143948_t1_core_foundation.sql',
    '20260829144121_t1_security_hardening.sql',
    '20260829150727_t1_private_security_and_rls_performance.sql'
)

$Legacy = '20260828150000_t1_core.sql'

function New-Fixture {
    param(
        [switch]$WithLegacy,
        [switch]$WithUnexpected
    )

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('hometechvn-t1-' + [guid]::NewGuid().ToString('N'))
    $migrations = Join-Path $root 'supabase\migrations'
    New-Item -ItemType Directory -Path $migrations -Force | Out-Null

    foreach ($name in $ExpectedMigrations) {
        Set-Content -Path (Join-Path $migrations $name) -Value '-- test' -Encoding UTF8
    }

    if ($WithLegacy) {
        Set-Content -Path (Join-Path $migrations $Legacy) -Value '-- legacy' -Encoding UTF8
    }

    if ($WithUnexpected) {
        Set-Content -Path (Join-Path $migrations '20990101000000_unexpected.sql') -Value '-- unexpected' -Encoding UTF8
    }

    return $root
}

# Static fixture tests only; no Docker/Supabase needed.
$root1 = New-Fixture
$files1 = @(Get-ChildItem (Join-Path $root1 'supabase\migrations') -Filter '*.sql' | % Name | Sort-Object)
if (($files1 -join '|') -ne ($ExpectedMigrations -join '|')) {
    throw 'Clean fixture mismatch.'
}
Remove-Item -Path $root1 -Recurse -Force

$root2 = New-Fixture -WithLegacy
$legacyPath = Join-Path $root2 ('supabase\migrations\' + $Legacy)
if (-not (Test-Path $legacyPath)) {
    throw 'Legacy fixture was not created.'
}
Remove-Item -Path $root2 -Recurse -Force

$root3 = New-Fixture -WithUnexpected
$unexpected = Join-Path $root3 'supabase\migrations\20990101000000_unexpected.sql'
if (-not (Test-Path $unexpected)) {
    throw 'Unexpected fixture was not created.'
}
Remove-Item -Path $root3 -Recurse -Force

Write-Host 'PASS: PowerShell fixture/static test scaffolding'
