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
    '20260830083317_t5_repair_part_replan_guard.sql',
    '20260830093152_t6_checklist_schema.sql',
    '20260830093342_t6_checklist_workflow_and_sales_bridge.sql',
    '20260830093439_t6_rls_helper_execute.sql',
    '20260830105628_t7_warranty_schema.sql',
    '20260830105854_t7_warranty_workflow.sql',
    '20260830110030_t7_server_public_lookup_contract.sql',
    '20260830110102_t7_warranty_inventory_unit_index.sql',
    '20260830113613_t8_service_license_schema.sql',
    '20260830113900_t8_service_license_workflow.sql',
    '20260830121533_t9_reminder_schema.sql',
    '20260830121806_t9_reminder_engine.sql',
    '20260830122012_t9_service_role_private_usage.sql',
    '20260830123046_t9_manual_resolve_rearm.sql',
    '20260830135438_t10_notification_schema_and_channel_config.sql',
    '20260830135738_t10_notification_outbox_workflow.sql',
    '20260830141222_t10_notification_config_secret_guard.sql',
    '20260830144205_t11_dashboard_snapshot.sql',
    '20260830154502_t12_public_warranty_lookup.sql',
    '20260830171108_t13_reports_snapshot.sql',
    '20260831104002_t16_security_audit_core_hardening.sql',
    '20260831104029_t16_audit_search_and_security_snapshot.sql',
    '20260831105049_t16_audit_actor_history_independence.sql'
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
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($null -eq $exitCode) { $exitCode = 0 }
    foreach ($line in $output) { Write-Host $line }
    if (($exitCode -ne 0) -and (-not $AllowFailure)) {
        throw "Lenh that bai, exit code ${exitCode}: $FilePath $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)"
    }
    return $output
}

function Ensure-SupabaseConfig {
    param([string]$Npx)
    $configPath = Join-Path $ProjectRoot 'supabase\config.toml'
    if (Test-Path $configPath) {
        Write-Host '[PASS] supabase/config.toml da ton tai.'
        return
    }
    Invoke-CheckedCommand -FilePath $Npx -Arguments @('supabase','init') | Out-Null
    if (-not (Test-Path $configPath)) { throw 'supabase init khong tao config.toml.' }
}

function Assert-Migrations {
    $actual = @(
        Get-ChildItem -Path (Join-Path $ProjectRoot 'supabase\migrations') -Filter '*.sql' -File |
        Select-Object -ExpandProperty Name |
        Sort-Object
    )
    $missing = @($ExpectedMigrations | Where-Object { $_ -notin $actual })
    $unexpected = @($actual | Where-Object { $_ -notin $ExpectedMigrations })
    if ($missing.Count -gt 0) { throw ("Thieu migration:`n- " + ($missing -join "`n- ")) }
    if ($unexpected.Count -gt 0) { throw ("Migration ngoai T16 checkpoint:`n- " + ($unexpected -join "`n- ")) }
    Write-Host '[PASS] Migration T1-T16 exact chain: 36/36'
    return $actual
}

function Read-ProjectId {
    $content = Get-Content -Path (Join-Path $ProjectRoot 'supabase\config.toml') -Raw
    $match = [regex]::Match($content, '(?m)^\s*project_id\s*=\s*["'']([^"'']+)["'']')
    if (-not $match.Success) { throw 'Khong doc duoc project_id trong config.toml.' }
    return $match.Groups[1].Value
}

function Invoke-SqlFile {
    param(
        [Parameter(Mandatory=$true)][string]$Container,
        [Parameter(Mandatory=$true)][string]$File,
        [Parameter(Mandatory=$true)][string]$ExpectedMarker
    )
    $path = Join-Path $ProjectRoot $File
    if (-not (Test-Path $path)) { throw "SQL test missing: $File" }

    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(
            Get-Content -Path $path -Raw |
            & docker.exe exec -i $Container psql -U postgres -d postgres -v ON_ERROR_STOP=1 2>&1
        )
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }

    foreach ($line in $output) { Write-Host $line }
    $text = $output -join [Environment]::NewLine
    if ($code -ne 0) { throw "SQL regression failed: $File`n$text" }
    if ($text -notmatch [regex]::Escape($ExpectedMarker)) {
        throw "SQL marker missing in $File`: $ExpectedMarker"
    }
    return $text
}

try {
    Write-Host '=== HomeTechVN T16 v1.0 - Debt Cleanup + Security/Audit Verification ==='
    Write-Host "Project root: $ProjectRoot"

    $npx = Resolve-CommandPath -Names @('npx.cmd','npx')
    $node = Resolve-CommandPath -Names @('node.exe','node')
    $npm = Resolve-CommandPath -Names @('npm.cmd','npm')

    # Static debt/security contract before installing anything.
    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t16-source-check.mjs')) | Out-Null

    # Close the historical lockfile debt and prove npm ci for all JS packages.
    $lockOutput = Invoke-CheckedCommand -FilePath 'powershell.exe' -Arguments @(
        '-NoProfile','-ExecutionPolicy','Bypass',
        '-File',(Join-Path $ProjectRoot 'scripts\t16-dependency-lock.ps1')
    )
    if (($lockOutput -join [Environment]::NewLine) -notmatch 'T16 DEPENDENCY LOCK CHECK: PASS') {
        throw 'Dependency lock gate did not PASS.'
    }
    $lockBundle = Get-ChildItem -Path (Join-Path $ProjectRoot 'docs\snapshots') -Filter 'T16_DEPENDENCY_LOCKS_*.zip' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $lockBundle) { throw 'T16 dependency lock bundle not found.' }

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

    # Every DB stage T1-T13 is replayed against the final T16 schema.
    $dbTests = @(
        @('supabase\tests\t1_verify.sql','T1 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t2_verify.sql','T2 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t3_verify.sql','T3 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t4_verify.sql','T4 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t5_verify.sql','T5 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t6_verify.sql','T6 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t7_verify.sql','T7 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t8_verify.sql','T8 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t9_verify.sql','T9 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t10_verify.sql','T10 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t11_verify.sql','T11 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t12_verify.sql','T12 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t13_verify.sql','T13 FINAL CORE CHECKS: PASS'),
        @('supabase\tests\t16_verify.sql','T16 SECURITY CORE CHECKS: PASS')
    )

    $dbSummary = @()
    foreach ($test in $dbTests) {
        Write-Host ''
        Write-Host "=== SQL regression $($test[0]) ==="
        $dbSummary += Invoke-SqlFile -Container $container -File $test[0] -ExpectedMarker $test[1]
    }
    Write-Host '[PASS] T1-T13 SQL regressions + T16 security SQL'

    # Re-run the accepted T15 full local restore architecture on the T16 schema.
    $restoreDir = Join-Path $env:TEMP ("HomeTechVN_T16_T15Restore_" + (Get-Stamp))
    $restoreOutput = Invoke-CheckedCommand -FilePath 'powershell.exe' -Arguments @(
        '-NoProfile','-ExecutionPolicy','Bypass',
        '-File',(Join-Path $ProjectRoot 'scripts\t15-restore-drill.ps1'),
        '-Container',$container,
        '-OutputDir',$restoreDir
    )
    if (($restoreOutput -join [Environment]::NewLine) -notmatch 'T15 APP DATA RESTORE DRILL: PASS') {
        throw 'T15 restore regression did not PASS on T16 schema.'
    }
    Remove-Item $restoreDir -Recurse -Force -ErrorAction SilentlyContinue

    # True multi-session race tests close T3/T4 deferred coverage.
    $concurrencyOutput = Invoke-CheckedCommand -FilePath 'powershell.exe' -Arguments @(
        '-NoProfile','-ExecutionPolicy','Bypass',
        '-File',(Join-Path $ProjectRoot 'scripts\t16-concurrency-check.ps1'),
        '-Container',$container
    )
    if (($concurrencyOutput -join [Environment]::NewLine) -notmatch 'T16 CONCURRENCY CHECK: PASS') {
        throw 'T16 concurrency gate did not PASS.'
    }

    # Responsive/privacy/PWA/backup static regressions.
    foreach ($script in @(
        'scripts\t11-ui-check.mjs',
        'scripts\t12-ui-check.mjs',
        'scripts\t13-ui-check.mjs',
        'scripts\t14-pwa-check.mjs',
        'scripts\t16-source-check.mjs'
    )) {
        Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot $script)) | Out-Null
    }

    # package-lock + npm ci already installed exact dependency trees.
    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix','app','run','build') | Out-Null
    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t14-build-check.mjs')) | Out-Null
    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix','worker','run','check') | Out-Null

    $snapshotDir = Join-Path $ProjectRoot 'docs\snapshots'
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    $snapshotPath = Join-Path $snapshotDir ('T16_LOCAL_VERIFY_' + (Get-Stamp) + '.txt')

    $snapshot = @(
        'HomeTechVN T16 local verification',
        ('Checked: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')),
        ('Project: ' + $projectId),
        '',
        'Migrations:',
        ($migrations -join [Environment]::NewLine),
        '',
        'T1-T13 DB REGRESSION: PASS',
        'T15 FULL LOCAL RESTORE REGRESSION: PASS',
        'T16 DEPENDENCY LOCK CHECK: PASS',
        ('Dependency lock bundle: ' + $lockBundle.FullName),
        'T16 CONCURRENCY CHECK: PASS',
        'T16 SECURITY CORE CHECKS: PASS',
        'T16 AUDIT RESPONSIVE UI CHECK: PASS',
        'APP BUILD: PASS',
        'WORKER CHECK: PASS',
        '',
        'T16 LOCAL REPRODUCIBILITY: PASS',
        'T16 T1-T15 DEBT CLEANUP CHECKS: PASS',
        'T16 SECURITY CORE CHECKS: PASS',
        'T16 CONCURRENCY CHECK: PASS',
        'T16 AUDIT RESPONSIVE UI CHECK: PASS',
        'T16 APP BUILD: PASS',
        'T16 WORKER CHECK: PASS'
    )
    Set-Content -Path $snapshotPath -Value $snapshot -Encoding UTF8

    Write-Host ''
    Write-Host '=========================================='
    Write-Host 'T16 LOCAL REPRODUCIBILITY: PASS'
    Write-Host 'T16 T1-T15 DEBT CLEANUP CHECKS: PASS'
    Write-Host 'T16 SECURITY CORE CHECKS: PASS'
    Write-Host 'T16 CONCURRENCY CHECK: PASS'
    Write-Host 'T16 AUDIT RESPONSIVE UI CHECK: PASS'
    Write-Host 'T16 APP BUILD: PASS'
    Write-Host 'T16 WORKER CHECK: PASS'
    Write-Host "Dependency lock bundle: $($lockBundle.FullName)"
    Write-Host "Snapshot: $snapshotPath"
    Write-Host '=========================================='
    exit 0
} catch {
    Write-Host ''
    Write-Host '[T16 FAIL]' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
