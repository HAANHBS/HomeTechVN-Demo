Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

$ExpectedMigrations = @(
    '20260829143948_t1_core_foundation.sql',
    '20260829144121_t1_security_hardening.sql',
    '20260829150727_t1_private_security_and_rls_performance.sql'
)

$LegacyMigrations = @(
    '20260828150000_t1_core.sql'
)

function Get-Stamp {
    return Get-Date -Format 'yyyyMMdd_HHmmss'
}

function Resolve-Npx {
    $cmd = Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        return $cmd.Source
    }

    $cmd = Get-Command 'npx' -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        return $cmd.Source
    }

    throw 'Khong tim thay npx/npx.cmd trong PATH.'
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$false)][string[]]$Arguments = @(),
        [switch]$AllowFailure
    )

    Write-Host ''
    Write-Host ('> ' + $FilePath + ' ' + ($Arguments -join ' '))

    & $FilePath @Arguments
    $exitCode = $LASTEXITCODE

    if ($null -eq $exitCode) {
        $exitCode = 0
    }

    if (($exitCode -ne 0) -and (-not $AllowFailure)) {
        throw "Lenh that bai, exit code ${exitCode}: $FilePath $($Arguments -join ' ')"
    }

    return $exitCode
}

function Invoke-CapturedCommand {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$false)][string[]]$Arguments = @()
    )

    Write-Host ''
    Write-Host ('> ' + $FilePath + ' ' + ($Arguments -join ' '))

    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    if ($null -eq $exitCode) {
        $exitCode = 0
    }

    foreach ($line in $output) {
        Write-Host $line
    }

    if ($exitCode -ne 0) {
        throw "Lenh that bai, exit code ${exitCode}: $FilePath $($Arguments -join ' ')"
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output = ($output -join [Environment]::NewLine)
    }
}


function Ensure-SupabaseConfig {
    $configPath = Join-Path $ProjectRoot 'supabase\config.toml'
    if (Test-Path $configPath) {
        Write-Host '[PASS] supabase/config.toml da ton tai.'
        return
    }

    Write-Host '[INFO] Chua co supabase/config.toml -> chay supabase init'
    $npx = Resolve-Npx
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase', 'init') | Out-Null

    if (-not (Test-Path $configPath)) {
        throw 'supabase init ket thuc nhung van khong tim thay supabase/config.toml.'
    }

    Write-Host '[PASS] Da tao supabase/config.toml.'
}

function Repair-Migrations {
    $migrationsDir = Join-Path $ProjectRoot 'supabase\migrations'
    if (-not (Test-Path $migrationsDir)) {
        throw "Khong tim thay migrations dir: $migrationsDir"
    }

    foreach ($legacy in $LegacyMigrations) {
        $legacyPath = Join-Path $migrationsDir $legacy
        if (Test-Path $legacyPath) {
            $backupDir = Join-Path $ProjectRoot ('docs\legacy_migrations_backup\' + (Get-Stamp))
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            $target = Join-Path $backupDir $legacy
            Move-Item -Path $legacyPath -Destination $target -Force

            Write-Host '[FIXED] Da chuyen migration cu ra khoi supabase/migrations:'
            Write-Host "  FROM: $legacyPath"
            Write-Host "  TO:   $target"
        }
    }

    $actual = @(
        Get-ChildItem -Path $migrationsDir -Filter '*.sql' -File |
        Select-Object -ExpandProperty Name |
        Sort-Object
    )

    $missing = @($ExpectedMigrations | Where-Object { $_ -notin $actual })
    $unexpected = @($actual | Where-Object { $_ -notin $ExpectedMigrations })

    if ($missing.Count -gt 0) {
        throw ("Thieu migration T1 bat buoc:`n- " + ($missing -join "`n- "))
    }

    if ($unexpected.Count -gt 0) {
        throw (
            "Phat hien migration SQL la. Script DUNG va KHONG xoa file:`n- " +
            ($unexpected -join "`n- ")
        )
    }

    Write-Host '[PASS] Migration list hop le:'
    foreach ($m in $actual) {
        Write-Host "  - $m"
    }

    return $actual
}

function Read-ProjectId {
    $configPath = Join-Path $ProjectRoot 'supabase\config.toml'
    $content = Get-Content -Path $configPath -Raw
    $match = [regex]::Match($content, '(?m)^\s*project_id\s*=\s*["'']([^"'']+)["'']')

    if (-not $match.Success) {
        throw 'Khong doc duoc project_id tu supabase/config.toml.'
    }

    return $match.Groups[1].Value
}

function Verify-LocalDatabase {
    param(
        [Parameter(Mandatory=$true)][string]$ProjectId
    )

    $container = "supabase_db_$ProjectId"

    $inspect = Invoke-CapturedCommand -FilePath 'docker.exe' -Arguments @(
        'inspect', '-f', '{{.State.Status}}', $container
    )

    if ($inspect.Output.Trim() -ne 'running') {
        throw "Container $container khong running."
    }

    $verifyFile = Join-Path $ProjectRoot 'supabase\tests\t1_verify.sql'
    if (-not (Test-Path $verifyFile)) {
        throw "Khong tim thay verify SQL: $verifyFile"
    }

    Write-Host ''
    Write-Host "> docker.exe exec -i $container psql -U postgres -d postgres -v ON_ERROR_STOP=1 < t1_verify.sql"

    # psql writes NOTICE messages to stderr even when the SQL succeeds.
    # With global $ErrorActionPreference='Stop', Windows PowerShell can promote that
    # stderr record to a terminating NativeCommandError before $LASTEXITCODE is read.
    # Temporarily use Continue ONLY for this native command, then restore the caller setting.
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
        throw "t1_verify.sql that bai, psql exit code $verifyExitCode.`n$verifyText"
    }

    if ($verifyText -notmatch 'T1 FINAL CORE CHECKS: PASS') {
        throw 'Verify SQL exit 0 nhung khong tim thay marker T1 FINAL CORE CHECKS: PASS.'
    }

    Write-Host '[PASS] T1 FINAL CORE CHECKS: PASS'
    return $verifyText
}

function Save-Snapshot {
    param(
        [Parameter(Mandatory=$true)][string[]]$Migrations,
        [Parameter(Mandatory=$true)][string]$ProjectId,
        [Parameter(Mandatory=$true)][string]$VerifyText,
        [Parameter(Mandatory=$true)][string]$StatusText
    )

    $snapshotDir = Join-Path $ProjectRoot 'docs\snapshots'
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null

    $snapshotPath = Join-Path $snapshotDir ('T1_LOCAL_VERIFY_' + (Get-Stamp) + '.txt')
    $lines = @(
        'HomeTechVN T1 local verification',
        ('Checked: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')),
        ('ProjectRoot: ' + $ProjectRoot),
        ('project_id: ' + $ProjectId),
        '',
        'Migrations:'
    )

    foreach ($m in $Migrations) {
        $lines += "- $m"
    }

    $lines += @(
        '',
        'VERIFY:',
        $VerifyText,
        '',
        'STATUS:',
        $StatusText
    )

    Set-Content -Path $snapshotPath -Value $lines -Encoding UTF8
    Write-Host "[PASS] Snapshot saved: $snapshotPath"
    return $snapshotPath
}

try {
    Write-Host '=== HomeTechVN T1 v2.1 - Windows DB-Only Repair + Reset + Verify ==='
    Write-Host "Project root: $ProjectRoot"

    $npx = Resolve-Npx
    Write-Host "[PASS] npx: $npx"

    Ensure-SupabaseConfig
    $migrations = Repair-Migrations

    # T1 verifies database migrations/RLS/functions only.
    # Start ONLY local Postgres so auxiliary service ports (Mailpit/Studio/etc.) cannot block T1.
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase', 'stop', '--no-backup') -AllowFailure | Out-Null

    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase', 'db', 'start') | Out-Null

    # Rebuild the local database from the migration chain + seed.
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase', 'db', 'reset', '--local') | Out-Null

    $projectId = Read-ProjectId
    Write-Host "[PASS] Local project_id: $projectId"

    $verifyText = Verify-LocalDatabase -ProjectId $projectId

    $dbContainer = "supabase_db_$projectId"
    $status = Invoke-CapturedCommand -FilePath 'docker.exe' -Arguments @(
        'inspect',
        '-f',
        'name={{.Name}} status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}',
        $dbContainer
    )

    $snapshot = Save-Snapshot `
        -Migrations $migrations `
        -ProjectId $projectId `
        -VerifyText $verifyText `
        -StatusText $status.Output

    Write-Host ''
    Write-Host '=========================================='
    Write-Host 'T1 LOCAL REPRODUCIBILITY: PASS'
    Write-Host 'T1 FINAL CORE CHECKS: PASS'
    Write-Host "Snapshot: $snapshot"
    Write-Host '=========================================='
    exit 0
}
catch {
    Write-Host ''
    Write-Host '[T1 FAIL]' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
