Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

$ExpectedMigrations = @(
    '20260829143948_t1_core_foundation.sql',
    '20260829144121_t1_security_hardening.sql',
    '20260829150727_t1_private_security_and_rls_performance.sql',
    '20260829162450_t2_crm_customer_devices.sql',
    '20260829162924_t2_client_insert_defaults.sql',
    '20260829162949_t2_device_types_access.sql',
    '20260830051756_t3_product_inventory.sql',
    '20260830052012_t3_performance_indexes_and_settings_policy.sql',
    '20260830080141_t4_sales.sql',
    '20260830080302_t4_rpc_execution_and_item_uniqueness.sql',
    '20260830081007_t4_payment_checklist_guard.sql',
    '20260830082723_t5_repair_schema.sql',
    '20260830083011_t5_repair_workflow.sql',
    '20260830083317_t5_repair_part_replan_guard.sql'
)

function Get-Stamp { return Get-Date -Format 'yyyyMMdd_HHmmss' }

function Resolve-CommandPath {
    param([Parameter(Mandatory=$true)][string[]]$Names)
    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) { return $cmd.Source }
    }
    throw "Khong tim thay lenh: $($Names -join ', ')"
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$false)][string[]]$Arguments = @(),
        [switch]$AllowFailure
    )
    Write-Host ''
    Write-Host ('> ' + $FilePath + ' ' + ($Arguments -join ' '))

    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $FilePath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    if ($null -eq $exitCode) { $exitCode = 0 }
    foreach ($line in $output) { Write-Host $line }

    if (($exitCode -ne 0) -and (-not $AllowFailure)) {
        $text = $output -join [Environment]::NewLine
        throw "Lenh that bai, exit code ${exitCode}: $FilePath $($Arguments -join ' ')`n$text"
    }
    return $exitCode
}

function Ensure-SupabaseConfig {
    param([string]$Npx)
    $configPath = Join-Path $ProjectRoot 'supabase\config.toml'
    if (Test-Path $configPath) {
        Write-Host '[PASS] supabase/config.toml da ton tai.'
        return
    }
    Write-Host '[INFO] Chua co supabase/config.toml -> supabase init'
    Invoke-CheckedCommand -FilePath $Npx -Arguments @('supabase','init') | Out-Null
    if (-not (Test-Path $configPath)) { throw 'supabase init khong tao config.toml.' }
}

function Assert-Migrations {
    $migrationDir = Join-Path $ProjectRoot 'supabase\migrations'
    $actual = @(
        Get-ChildItem -Path $migrationDir -Filter '*.sql' -File |
        Select-Object -ExpandProperty Name |
        Sort-Object
    )
    $missing = @($ExpectedMigrations | Where-Object { $_ -notin $actual })
    $unexpected = @($actual | Where-Object { $_ -notin $ExpectedMigrations })
    if ($missing.Count -gt 0) { throw ("Thieu migration:`n- " + ($missing -join "`n- ")) }
    if ($unexpected.Count -gt 0) { throw ("Co migration ngoai checkpoint T5:`n- " + ($unexpected -join "`n- ")) }
    Write-Host '[PASS] Migration T1+T2+T3+T4+T5: 14/14'
    return $actual
}

function Read-ProjectId {
    $content = Get-Content -Path (Join-Path $ProjectRoot 'supabase\config.toml') -Raw
    $match = [regex]::Match($content, '(?m)^\s*project_id\s*=\s*["'']([^"'']+)["'']')
    if (-not $match.Success) { throw 'Khong doc duoc project_id trong config.toml.' }
    return $match.Groups[1].Value
}

function Invoke-T5SqlVerify {
    param([Parameter(Mandatory=$true)][string]$Container)
    $verifyFile = Join-Path $ProjectRoot 'supabase\tests\t5_verify.sql'
    if (-not (Test-Path $verifyFile)) { throw "Khong tim thay $verifyFile" }

    Write-Host ''
    Write-Host "> docker.exe exec -i $Container psql ... < t5_verify.sql"

    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(
            Get-Content -Path $verifyFile -Raw |
            & docker.exe exec -i $Container psql -U postgres -d postgres -v ON_ERROR_STOP=1 2>&1
        )
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    foreach ($line in $output) { Write-Host $line }
    $text = $output -join [Environment]::NewLine
    if ($exitCode -ne 0) { throw "T5 SQL verify fail, psql exit=$exitCode`n$text" }
    if ($text -notmatch 'T5 FINAL CORE CHECKS: PASS') { throw 'Khong tim thay marker T5 PASS.' }
    return $text
}

try {
    Write-Host '=== HomeTechVN T5 v1.1 - Repair Verification ==='
    Write-Host "Project root: $ProjectRoot"

    $npx = Resolve-CommandPath -Names @('npx.cmd','npx')
    $npm = Resolve-CommandPath -Names @('npm.cmd','npm')
    Write-Host "[PASS] npx: $npx"
    Write-Host "[PASS] npm: $npm"

    Ensure-SupabaseConfig -Npx $npx
    $migrations = Assert-Migrations

    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','stop','--no-backup') -AllowFailure | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','start') | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','reset','--local') | Out-Null

    $projectId = Read-ProjectId
    $container = "supabase_db_$projectId"
    $state = & docker.exe inspect -f '{{.State.Status}}' $container 2>&1
    if ($LASTEXITCODE -ne 0 -or ($state -join '').Trim() -ne 'running') {
        throw "Database container khong running: $($state -join ' ')"
    }
    Write-Host "[PASS] $container running"

    $sqlOutput = Invoke-T5SqlVerify -Container $container

    Write-Host '[INFO] Dong bo app dependencies + package-lock.json'
    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix','app','install','--no-audit','--no-fund') | Out-Null
    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix','app','run','build') | Out-Null
    Write-Host '[PASS] React/TypeScript/Vite production build'

    $snapshotDir = Join-Path $ProjectRoot 'docs\snapshots'
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    $snapshotPath = Join-Path $snapshotDir ('T5_LOCAL_VERIFY_' + (Get-Stamp) + '.txt')
    $snapshot = @(
        'HomeTechVN T5 local verification',
        ('Checked: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')),
        ('Project: ' + $projectId),
        '',
        'Migrations:',
        ($migrations -join [Environment]::NewLine),
        '',
        'SQL VERIFY:',
        $sqlOutput,
        '',
        'APP BUILD: PASS',
        'T5 LOCAL REPRODUCIBILITY: PASS',
        'T5 FINAL CORE CHECKS: PASS'
    )
    Set-Content -Path $snapshotPath -Value $snapshot -Encoding UTF8

    Write-Host ''
    Write-Host '=========================================='
    Write-Host 'T5 LOCAL REPRODUCIBILITY: PASS'
    Write-Host 'T5 FINAL CORE CHECKS: PASS'
    Write-Host 'T5 APP BUILD: PASS'
    Write-Host "Snapshot: $snapshotPath"
    Write-Host '=========================================='
    exit 0
}
catch {
    Write-Host ''
    Write-Host '[T5 FAIL]' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
