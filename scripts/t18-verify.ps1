Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

function Get-Stamp { return Get-Date -Format 'yyyyMMdd_HHmmss' }

function Resolve-CommandPath {
    param([Parameter(Mandatory=$true)][string[]]$Names)
    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $command) { return $command.Source }
    }
    throw "Khong tim thay lenh: $($Names -join ', ')"
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$false)][string[]]$Arguments = @()
    )
    Write-Host ''
    Write-Host ('> ' + $FilePath + ' ' + ($Arguments -join ' '))
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $FilePath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($null -eq $exitCode) { $exitCode = 0 }
    foreach ($line in $output) { Write-Host $line }
    if ($exitCode -ne 0) {
        throw "Lenh that bai, exit code ${exitCode}: $FilePath $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)"
    }
    return $output
}

function Assert-Markers {
    param(
        [Parameter(Mandatory=$true)][object[]]$Output,
        [Parameter(Mandatory=$true)][string[]]$Markers,
        [Parameter(Mandatory=$true)][string]$Scope
    )
    $text = $Output -join [Environment]::NewLine
    foreach ($marker in $Markers) {
        if ($text -notmatch [regex]::Escape($marker)) {
            throw "$Scope marker missing: $marker"
        }
    }
}

try {
    Write-Host '=== HomeTechVN T18 v1.3 - Production Release Gate ==='
    Write-Host "Project root: $ProjectRoot"

    $node = Resolve-CommandPath -Names @('node.exe', 'node')
    $npm = Resolve-CommandPath -Names @('npm.cmd', 'npm')

    $sourceOutput = Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t18-source-check.mjs'))
    Assert-Markers -Output $sourceOutput -Markers @('T18 SOURCE CHECK: PASS') -Scope 'T18 source check'
    $packagePolicyOutput = Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t18-package-policy-self-test.mjs'))
    Assert-Markers -Output $packagePolicyOutput -Markers @('T18 PACKAGE POLICY SELF TEST: PASS') -Scope 'T18 package policy'

    $inheritedOutput = Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t17-verify.mjs'))
    Assert-Markers -Output $inheritedOutput -Scope 'T17 inherited verifier' -Markers @(
        'T17 LOCAL REPRODUCIBILITY: PASS',
        'T17 INHERITED REGRESSION CHECKS: PASS',
        'T17 DEMO INTEGRATION CHECKS: PASS',
        'T17 APP BUILD: PASS',
        'T17 WORKER CHECK: PASS',
        'T17 CLEAN BASELINE AFTER VERIFY: PASS'
    )

    $appEnvPath = Join-Path $ProjectRoot 'app\.env.local'
    if (-not (Test-Path $appEnvPath -PathType Leaf)) {
        throw 'Missing app/.env.local. Run npm run t18:configure, enter the hosted Supabase Project URL and browser-safe Publishable key, then rerun npm run t18:verify.'
    }
    $envHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $appEnvPath).Hash
    $envOutput = Invoke-CheckedCommand -FilePath $node -Arguments @(
        (Join-Path $ProjectRoot 'scripts\t18-production-env-check.mjs'),
        '--file',
        $appEnvPath
    )
    Assert-Markers -Output $envOutput -Scope 'T18 production environment' -Markers @(
        'T18 RUNTIME CONFIG POLICY: PASS (WORKING COPY)',
        'T18 PRODUCTION CONFIG SAFETY: PASS'
    )

    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix', 'app', 'run', 'build') | Out-Null
    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t14-build-check.mjs')) | Out-Null
    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t18-build-check.mjs')) | Out-Null
    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix', 'worker', 'run', 'check') | Out-Null
    $workerOutput = Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t18-worker-self-test.mjs'))
    Assert-Markers -Output $workerOutput -Scope 'T18 Worker' -Markers @(
        'T18 WORKER HEALTH/UNAUTHORIZED CONTRACT: PASS',
        'T18 WORKER CRON-OFF SAFETY SELF TEST: PASS'
    )

    $snapshotDir = Join-Path $ProjectRoot 'docs\snapshots'
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    $releasePath = Join-Path $snapshotDir ('HOMETECHVN_T18_RELEASE_' + (Get-Stamp) + '.zip')
    $packageOutput = Invoke-CheckedCommand -FilePath 'powershell.exe' -Arguments @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $ProjectRoot 'scripts\t18-package.ps1'),
        '-OutputPath', $releasePath
    )
    Assert-Markers -Output $packageOutput -Scope 'T18 package' -Markers @('T18 RELEASE PACKAGE SAFETY: PASS')

    $envHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $appEnvPath).Hash
    if ($envHashBefore -ne $envHashAfter) {
        throw 'T18 verifier changed app/.env.local; working-copy runtime configuration must be preserved byte-for-byte.'
    }

    $snapshotPath = Join-Path $snapshotDir ('T18_LOCAL_VERIFY_' + (Get-Stamp) + '.txt')
    $releaseHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $releasePath).Hash.ToLowerInvariant()
    $snapshot = @(
        'HomeTechVN T18 Production Release Gate verification',
        ('Checked: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')),
        '',
        'T17 FINAL integrity baseline: PASS',
        'Locked migration chain #1-#36: PASS',
        'T18 DB migration: 0; next migration #37 reserved',
        'T17 inherited runtime regression: PASS',
        'Production hosted config validation: PASS',
        'Production app build: PASS',
        'Worker safe activation defaults: PASS',
        'Release ZIP runtime-config exclusion: PASS',
        'Working-copy app/.env.local preservation: PASS',
        'Clean database baseline inherited from T17: PASS',
        ('Release candidate: ' + $releasePath),
        ('Release SHA-256: ' + $releaseHash),
        '',
        'T18 LOCAL REPRODUCIBILITY: PASS',
        'T18 INHERITED REGRESSION CHECKS: PASS',
        'T18 PRODUCTION CONFIG SAFETY: PASS',
        'T18 WORKER SAFE-ACTIVATION CHECK: PASS',
        'T18 PRODUCTION BUILD: PASS',
        'T18 RELEASE PACKAGE SAFETY: PASS',
        'T18 CLEAN BASELINE AFTER VERIFY: PASS'
    )
    Set-Content -Path $snapshotPath -Value $snapshot -Encoding UTF8

    Write-Host ''
    Write-Host '=========================================='
    Write-Host 'T18 LOCAL REPRODUCIBILITY: PASS'
    Write-Host 'T18 INHERITED REGRESSION CHECKS: PASS'
    Write-Host 'T18 PRODUCTION CONFIG SAFETY: PASS'
    Write-Host 'T18 WORKER SAFE-ACTIVATION CHECK: PASS'
    Write-Host 'T18 PRODUCTION BUILD: PASS'
    Write-Host 'T18 RELEASE PACKAGE SAFETY: PASS'
    Write-Host 'T18 CLEAN BASELINE AFTER VERIFY: PASS'
    Write-Host "Release candidate: $releasePath"
    Write-Host "Release SHA-256: $releaseHash"
    Write-Host "Snapshot: $snapshotPath"
    Write-Host '=========================================='
    exit 0
} catch {
    Write-Host ''
    Write-Host '[T18 FAIL]' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
