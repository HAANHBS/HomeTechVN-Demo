Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

function Get-Stamp {
    return Get-Date -Format 'yyyyMMdd_HHmmss'
}

try {
    $configPath = Join-Path $ProjectRoot 'supabase\config.toml'
    if (-not (Test-Path $configPath)) {
        throw 'Khong tim thay supabase/config.toml.'
    }

    $content = Get-Content -Path $configPath -Raw
    $match = [regex]::Match($content, '(?m)^\s*project_id\s*=\s*["'']([^"'']+)["'']')
    if (-not $match.Success) {
        throw 'Khong doc duoc project_id.'
    }

    $projectId = $match.Groups[1].Value
    $container = "supabase_db_$projectId"
    $verifyFile = Join-Path $ProjectRoot 'supabase\tests\t1_verify.sql'

    Write-Host "Project: $projectId"
    Write-Host "Container: $container"

    $state = & docker.exe inspect -f '{{.State.Status}}' $container 2>&1
    if ($LASTEXITCODE -ne 0 -or ($state -join '').Trim() -ne 'running') {
        throw "Database container khong running: $($state -join ' ')"
    }
    Write-Host '[PASS] Database container running'

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $verifyOutput = @(
            Get-Content -Path $verifyFile -Raw |
            & docker.exe exec -i $container psql -U postgres -d postgres -v ON_ERROR_STOP=1 2>&1
        )
        $verifyExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    foreach ($line in $verifyOutput) {
        Write-Host $line
    }

    $verifyText = $verifyOutput -join [Environment]::NewLine

    if ($verifyExitCode -ne 0) {
        throw "psql exit code $verifyExitCode.`n$verifyText"
    }

    if ($verifyText -notmatch 'T1 FINAL CORE CHECKS: PASS') {
        throw 'Khong tim thay marker PASS.'
    }

    $snapshotDir = Join-Path $ProjectRoot 'docs\snapshots'
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    $snapshotPath = Join-Path $snapshotDir ('T1_LOCAL_VERIFY_' + (Get-Stamp) + '.txt')

    $snapshot = @(
        'HomeTechVN T1 final local verification',
        ('Checked: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')),
        ('Project: ' + $projectId),
        ('Container: ' + $container),
        '',
        $verifyText,
        '',
        'T1 LOCAL REPRODUCIBILITY: PASS',
        'T1 FINAL CORE CHECKS: PASS'
    )
    Set-Content -Path $snapshotPath -Value $snapshot -Encoding UTF8

    Write-Host ''
    Write-Host '=========================================='
    Write-Host 'T1 LOCAL REPRODUCIBILITY: PASS'
    Write-Host 'T1 FINAL CORE CHECKS: PASS'
    Write-Host "Snapshot: $snapshotPath"
    Write-Host '=========================================='
    exit 0
}
catch {
    Write-Host ''
    Write-Host '[T1 FAIL]' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
