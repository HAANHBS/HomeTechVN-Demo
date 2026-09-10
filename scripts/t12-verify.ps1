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
    '20260830154502_t12_public_warranty_lookup.sql'
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
    } finally { $ErrorActionPreference = $previous }
    if ($null -eq $exitCode) { $exitCode = 0 }
    foreach ($line in $output) { Write-Host $line }
    if (($exitCode -ne 0) -and (-not $AllowFailure)) {
        throw "Lenh that bai, exit code ${exitCode}: $FilePath $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)"
    }
    return $exitCode
}

function Ensure-SupabaseConfig {
    param([string]$Npx)
    $configPath = Join-Path $ProjectRoot 'supabase\config.toml'
    if (Test-Path $configPath) { Write-Host '[PASS] supabase/config.toml da ton tai.'; return }
    Invoke-CheckedCommand -FilePath $Npx -Arguments @('supabase','init') | Out-Null
    if (-not (Test-Path $configPath)) { throw 'supabase init khong tao config.toml.' }
}

function Assert-Migrations {
    $actual = @(Get-ChildItem -Path (Join-Path $ProjectRoot 'supabase\migrations') -Filter '*.sql' -File | Select-Object -ExpandProperty Name | Sort-Object)
    $missing = @($ExpectedMigrations | Where-Object { $_ -notin $actual })
    $unexpected = @($actual | Where-Object { $_ -notin $ExpectedMigrations })
    if ($missing.Count -gt 0) { throw ("Thieu migration:`n- " + ($missing -join "`n- ")) }
    if ($unexpected.Count -gt 0) { throw ("Co migration ngoai checkpoint T12:`n- " + ($unexpected -join "`n- ")) }
    Write-Host '[PASS] Migration T1+T2+T3+T4+T5+T6+T7+T8+T9+T10+T11+T12: 32/32'
    return $actual
}

function Read-ProjectId {
    $content = Get-Content -Path (Join-Path $ProjectRoot 'supabase\config.toml') -Raw
    $match = [regex]::Match($content, '(?m)^\s*project_id\s*=\s*["'']([^"'']+)["'']')
    if (-not $match.Success) { throw 'Khong doc duoc project_id trong config.toml.' }
    return $match.Groups[1].Value
}

function Invoke-T12SqlVerify {
    param([Parameter(Mandatory=$true)][string]$Container)
    $verifyFile = Join-Path $ProjectRoot 'supabase\tests\t12_verify.sql'
    if (-not (Test-Path $verifyFile)) { throw "Khong tim thay $verifyFile" }
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(Get-Content -Path $verifyFile -Raw | & docker.exe exec -i $Container psql -U postgres -d postgres -v ON_ERROR_STOP=1 2>&1)
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    foreach ($line in $output) { Write-Host $line }
    $text = $output -join [Environment]::NewLine
    if ($exitCode -ne 0) { throw "T12 SQL verify fail, psql exit=$exitCode`n$text" }
    if ($text -notmatch 'T12 FINAL CORE CHECKS: PASS') { throw 'Khong tim thay marker T12 FINAL CORE CHECKS: PASS.' }
    return $text
}

try {
    Write-Host '=== HomeTechVN T12 v1.0 - Public QR Warranty Verification ==='
    Write-Host "Project root: $ProjectRoot"

    $npx = Resolve-CommandPath -Names @('npx.cmd','npx')
    $npm = Resolve-CommandPath -Names @('npm.cmd','npm')
    $node = Resolve-CommandPath -Names @('node.exe','node')

    Ensure-SupabaseConfig -Npx $npx
    $migrations = Assert-Migrations

    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','stop','--no-backup') -AllowFailure | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','start') | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','reset','--local') | Out-Null

    $projectId = Read-ProjectId
    $container = "supabase_db_$projectId"
    $state = & docker.exe inspect -f '{{.State.Status}}' $container 2>&1
    if ($LASTEXITCODE -ne 0 -or ($state -join '').Trim() -ne 'running') { throw "Database container khong running: $($state -join ' ')" }

    $sqlOutput = Invoke-T12SqlVerify -Container $container

    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t11-ui-check.mjs')) | Out-Null
    Write-Host '[PASS] T11 global responsive UI regression checks'

    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t12-ui-check.mjs')) | Out-Null
    Write-Host '[PASS] T12 public QR warranty UI/privacy checks'

    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix','app','install','--no-audit','--no-fund') | Out-Null
    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix','app','run','build') | Out-Null
    Write-Host '[PASS] React/TypeScript/Vite production build'

    $snapshotDir = Join-Path $ProjectRoot 'docs\snapshots'
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    $snapshotPath = Join-Path $snapshotDir ('T12_LOCAL_VERIFY_' + (Get-Stamp) + '.txt')
    $snapshot = @(
        'HomeTechVN T12 local verification',
        ('Checked: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')),
        ('Project: ' + $projectId),
        '',
        'Migrations:',
        ($migrations -join [Environment]::NewLine),
        '',
        'SQL VERIFY:',
        $sqlOutput,
        '',
        'GLOBAL RESPONSIVE UI CHECK: PASS',
        'PUBLIC WARRANTY UI CHECK: PASS',
        'APP BUILD: PASS',
        'T12 LOCAL REPRODUCIBILITY: PASS',
        'T12 FINAL CORE CHECKS: PASS',
        'T12 RESPONSIVE UI CHECK: PASS',
        'T12 APP BUILD: PASS'
    )
    Set-Content -Path $snapshotPath -Value $snapshot -Encoding UTF8

    Write-Host ''
    Write-Host '=========================================='
    Write-Host 'T12 LOCAL REPRODUCIBILITY: PASS'
    Write-Host 'T12 FINAL CORE CHECKS: PASS'
    Write-Host 'T12 RESPONSIVE UI CHECK: PASS'
    Write-Host 'T12 APP BUILD: PASS'
    Write-Host "Snapshot: $snapshotPath"
    Write-Host '=========================================='
    exit 0
} catch {
    Write-Host ''
    Write-Host '[T12 FAIL]' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
