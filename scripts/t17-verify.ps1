Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

$T17ExcludedServices = 'realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor'

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
    if (Test-Path $configPath) { return }
    Invoke-CheckedCommand -FilePath $Npx -Arguments @('supabase','init') | Out-Null
    if (-not (Test-Path $configPath)) { throw 'supabase init khong tao config.toml.' }
}

function Read-ProjectId {
    $content = Get-Content -Path (Join-Path $ProjectRoot 'supabase\config.toml') -Raw
    $match = [regex]::Match($content, '(?m)^\s*project_id\s*=\s*["'']([^"'']+)["'']')
    if (-not $match.Success) { throw 'Khong doc duoc project_id trong config.toml.' }
    return $match.Groups[1].Value
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
    if ($unexpected.Count -gt 0) { throw ("T17 must not add DB migration:`n- " + ($unexpected -join "`n- ")) }
    if (@($actual | Where-Object { $_ -match '_t17_' }).Count -gt 0) {
        throw 'T17 Demo Integration must not contain a t17 DB migration.'
    }
    Write-Host '[PASS] T1-T16 migration chain unchanged: 36/36'
    return $actual
}

function Invoke-SqlFile {
    param(
        [Parameter(Mandatory=$true)][string]$Container,
        [Parameter(Mandatory=$true)][string]$File,
        [Parameter(Mandatory=$true)][string]$ExpectedMarker
    )
    $path = Join-Path $ProjectRoot $File
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
        throw "SQL marker missing: $ExpectedMarker"
    }
    return $text
}

function Save-AppEnvState {
    param(
        [Parameter(Mandatory=$true)][string]$AppEnvPath,
        [Parameter(Mandatory=$true)][string]$BackupPath
    )
    if (Test-Path $AppEnvPath) {
        Copy-Item -Path $AppEnvPath -Destination $BackupPath -Force
        return $true
    }
    return $false
}

function Restore-AppEnvState {
    param(
        [Parameter(Mandatory=$true)][string]$AppEnvPath,
        [Parameter(Mandatory=$true)][string]$BackupPath,
        [Parameter(Mandatory=$true)][bool]$PreviouslyExisted
    )
    if ($PreviouslyExisted) {
        if (-not (Test-Path $BackupPath)) {
            throw 'T17 app env backup is missing during restore.'
        }
        Copy-Item -Path $BackupPath -Destination $AppEnvPath -Force
    } else {
        Remove-Item -Path $AppEnvPath -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -Path $BackupPath -Force -ErrorAction SilentlyContinue
}

function Assert-CleanBusinessBaseline {
    param([Parameter(Mandatory=$true)][string]$Container)

    $sql = @'
select jsonb_build_object(
  'auth_users', (select count(*) from auth.users),
  'profiles', (select count(*) from public.profiles),
  'customers', (select count(*) from public.customers),
  'customer_devices', (select count(*) from public.customer_devices),
  'product_categories', (select count(*) from public.product_categories),
  'products', (select count(*) from public.products),
  'inventory_units', (select count(*) from public.inventory_units),
  'inventory_transactions', (select count(*) from public.inventory_transactions),
  'sales_orders', (select count(*) from public.sales_orders),
  'sales_order_items', (select count(*) from public.sales_order_items),
  'payments', (select count(*) from public.payments),
  'repair_orders', (select count(*) from public.repair_orders),
  'repair_diagnostics', (select count(*) from public.repair_diagnostics),
  'repair_quotes', (select count(*) from public.repair_quotes),
  'repair_parts', (select count(*) from public.repair_parts),
  'warranties', (select count(*) from public.warranties),
  'warranty_claims', (select count(*) from public.warranty_claims),
  'services', (select count(*) from public.services),
  'service_schedules', (select count(*) from public.service_schedules),
  'software_products', (select count(*) from public.software_products),
  'software_licenses', (select count(*) from public.software_licenses),
  'reminders', (select count(*) from public.reminders),
  'notifications', (select count(*) from public.notifications),
  'notification_logs', (select count(*) from public.notification_logs),
  'reminder_rules_total', (select count(*) from public.reminder_rules),
  'reminder_rules_system', (select count(*) from public.reminder_rules where is_system),
  'reminder_rules_non_system', (select count(*) from public.reminder_rules where not is_system),
  'reminder_rule_codes', (
    select coalesce(jsonb_agg(rule_code order by rule_code),'[]'::jsonb)
    from public.reminder_rules
  )
)::text;
'@

    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(
            $sql |
            & docker.exe exec -i $Container psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 2>&1
        )
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }

    if ($code -ne 0) {
        throw "T17 clean-baseline assertion query failed:`n$($output -join [Environment]::NewLine)"
    }

    $jsonLine = @(
        $output |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object { $_ -like '{*}' }
    ) | Select-Object -Last 1

    if ([string]::IsNullOrWhiteSpace($jsonLine)) {
        throw 'T17 clean-baseline assertion returned no JSON.'
    }

    $counts = $jsonLine | ConvertFrom-Json

    $businessFields = @(
        'auth_users','profiles','customers','customer_devices',
        'product_categories','products','inventory_units','inventory_transactions',
        'sales_orders','sales_order_items','payments',
        'repair_orders','repair_diagnostics','repair_quotes','repair_parts',
        'warranties','warranty_claims',
        'services','service_schedules','software_products','software_licenses',
        'reminders','notifications','notification_logs'
    )

    $nonZero = @()
    foreach ($field in $businessFields) {
        if ([int64]$counts.$field -ne 0) {
            $nonZero += "$field=$($counts.$field)"
        }
    }

    if ($nonZero.Count -gt 0) {
        throw "T17 final business/auth baseline is not empty: $($nonZero -join ', ')"
    }

    $expectedRuleCodes = @(
        'LICENSE_30D',
        'LICENSE_7D',
        'LOW_STOCK',
        'MAINTENANCE_7D',
        'QUOTE_WAITING_24H',
        'RECEIVABLE_DUE',
        'REPAIR_OVERDUE',
        'REPAIR_READY',
        'REPAIR_UNCOLLECTED_3D',
        'REPAIR_UNCOLLECTED_7D',
        'WARRANTY_30D',
        'WARRANTY_7D'
    )

    $actualRuleCodes = @($counts.reminder_rule_codes | ForEach-Object { [string]$_ })
    $missingRuleCodes = @($expectedRuleCodes | Where-Object { $_ -notin $actualRuleCodes })
    $unexpectedRuleCodes = @($actualRuleCodes | Where-Object { $_ -notin $expectedRuleCodes })

    if ([int64]$counts.reminder_rules_total -ne 12 -or
        [int64]$counts.reminder_rules_system -ne 12 -or
        [int64]$counts.reminder_rules_non_system -ne 0 -or
        $missingRuleCodes.Count -gt 0 -or
        $unexpectedRuleCodes.Count -gt 0) {
        throw (
            'T17 system reminder-rule baseline mismatch: ' +
            "total=$($counts.reminder_rules_total), " +
            "system=$($counts.reminder_rules_system), " +
            "non_system=$($counts.reminder_rules_non_system), " +
            "missing=[$($missingRuleCodes -join ',')], " +
            "unexpected=[$($unexpectedRuleCodes -join ',')]"
        )
    }

    Write-Host '[PASS] T17 final transactional/Auth business data is empty.'
    Write-Host '[PASS] T17 system reminder-rule foundation is intact: 12/12.'
    Write-Host 'T17 CLEAN BASELINE AFTER VERIFY: PASS'
}

try {
    Write-Host '=== HomeTechVN T17 v1.14 - Clean-Baseline Verified Demo Integration ==='
    Write-Host "Project root: $ProjectRoot"

    $npx = Resolve-CommandPath -Names @('npx.cmd','npx')
    $node = Resolve-CommandPath -Names @('node.exe','node')
    $npm = Resolve-CommandPath -Names @('npm.cmd','npm')

    $appEnvPath = Join-Path $ProjectRoot 'app\.env.local'
    $appEnvBackupPath = Join-Path $env:TEMP ('HomeTechVN_T17_AppEnv_' + (Get-Stamp) + '.bak')
    $appEnvWasPresent = Save-AppEnvState -AppEnvPath $appEnvPath -BackupPath $appEnvBackupPath
    $appEnvRestoreCompleted = $false

    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t17-source-check.mjs')) | Out-Null
    $discoverySelfTest = Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t17-resolve-local-config.mjs'),'--self-test')
    if (($discoverySelfTest -join [Environment]::NewLine) -notmatch 'T17 LOCAL CONFIG RESOLVER SELF TEST: PASS') { throw 'T17 local config resolver self-test did not PASS.' }

    # Preserve T16 dependency reproducibility gate against T17 package manifests.
    $lockOutput = Invoke-CheckedCommand -FilePath 'powershell.exe' -Arguments @(
        '-NoProfile','-ExecutionPolicy','Bypass',
        '-File',(Join-Path $ProjectRoot 'scripts\t16-dependency-lock.ps1')
    )
    if (($lockOutput -join [Environment]::NewLine) -notmatch 'T16 DEPENDENCY LOCK CHECK: PASS') {
        throw 'T17 inherited dependency-lock gate failed.'
    }

    Ensure-SupabaseConfig -Npx $npx
    $migrations = Assert-Migrations

    # Clean local replay before inherited regression.
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','stop','--no-backup') -AllowFailure | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','start','-x',$T17ExcludedServices) | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','reset','--local') | Out-Null

    $projectId = Read-ProjectId
    $container = "supabase_db_$projectId"
    $state = (& docker.exe inspect -f '{{.State.Status}}' $container 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $state -ne 'running') {
        throw "Database container not running: $container / $state"
    }

    # Database regression T1-T13 + T16.
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

    foreach ($test in $dbTests) {
        Write-Host ''
        Write-Host "=== Regression $($test[0]) ==="
        Invoke-SqlFile -Container $container -File $test[0] -ExpectedMarker $test[1] | Out-Null
    }
    Write-Host '[PASS] T1-T16 inherited SQL regression suite'

    # T15 restore architecture still works against the T17 baseline.
    $restoreDir = Join-Path $env:TEMP ("HomeTechVN_T17_T15Restore_" + (Get-Stamp))
    $restoreOutput = Invoke-CheckedCommand -FilePath 'powershell.exe' -Arguments @(
        '-NoProfile','-ExecutionPolicy','Bypass',
        '-File',(Join-Path $ProjectRoot 'scripts\t15-restore-drill.ps1'),
        '-Container',$container,
        '-OutputDir',$restoreDir
    )
    if (($restoreOutput -join [Environment]::NewLine) -notmatch 'T15 APP DATA RESTORE DRILL: PASS') {
        throw 'T15 restore regression failed on T17 baseline.'
    }
    Remove-Item $restoreDir -Recurse -Force -ErrorAction SilentlyContinue

    # T16 real parallel-session race protection remains valid.
    $raceOutput = Invoke-CheckedCommand -FilePath 'powershell.exe' -Arguments @(
        '-NoProfile','-ExecutionPolicy','Bypass',
        '-File',(Join-Path $ProjectRoot 'scripts\t16-concurrency-check.ps1'),
        '-Container',$container
    )
    if (($raceOutput -join [Environment]::NewLine) -notmatch 'T16 CONCURRENCY CHECK: PASS') {
        throw 'T16 concurrency regression failed.'
    }

    # Load actual login-capable local demo through the Node implementation.
    $demoOutput = Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t17-demo-load.mjs'),'--no-reset')

    foreach ($marker in @(
        'T17 DEMO LOAD: PASS',
        'T17 DEMO INTEGRATION CHECKS: PASS',
        'T17 DEMO AUTH LOGIN CHECK: PASS',
        'T17 DEMO ROLE JWT CHECK: PASS',
        'T17 DEMO DASHBOARD RPC CHECK: PASS'
    )) {
        if (($demoOutput -join [Environment]::NewLine) -notmatch [regex]::Escape($marker)) {
            throw "T17 demo marker missing: $marker"
        }
    }

    # Re-run source/UI/privacy/PWA checks with the demo env file now present.
    foreach ($script in @(
        'scripts\t11-ui-check.mjs',
        'scripts\t12-ui-check.mjs',
        'scripts\t13-ui-check.mjs',
        'scripts\t14-pwa-check.mjs',
        'scripts\t17-source-check.mjs'
    )) {
        Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot $script)) | Out-Null
    }

    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix','app','run','build') | Out-Null
    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t14-build-check.mjs')) | Out-Null
    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix','worker','run','check') | Out-Null

    # Demo build must visibly contain local demo marker; public warranty remains routed before auth/demo UI.
    $distDir = Join-Path $ProjectRoot 'app\dist'
    $bundleText = @(
        Get-ChildItem -Path (Join-Path $distDir 'assets') -Filter '*.js' -File |
        ForEach-Object { Get-Content $_.FullName -Raw }
    ) -join [Environment]::NewLine

    if ($bundleText -notmatch 'LOCAL DEMO') {
        throw 'Demo-mode production build does not contain LOCAL DEMO marker.'
    }

    # T17 fixtures are ephemeral. Restore any pre-existing app env and return
    # the local database to the normal seed baseline before acceptance.
    Restore-AppEnvState -AppEnvPath $appEnvPath -BackupPath $appEnvBackupPath -PreviouslyExisted $appEnvWasPresent
    $appEnvRestoreCompleted = $true

    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','reset','--local') | Out-Null
    Assert-CleanBusinessBaseline -Container $container

    $snapshotDir = Join-Path $ProjectRoot 'docs\snapshots'
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    $snapshotPath = Join-Path $snapshotDir ('T17_LOCAL_VERIFY_' + (Get-Stamp) + '.txt')

    $lockBundle = Get-ChildItem -Path $snapshotDir -Filter 'T16_DEPENDENCY_LOCKS_*.zip' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    $demoSnapshot = Get-ChildItem -Path $snapshotDir -Filter 'T17_DEMO_LOAD_*.json' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    $snapshot = @(
        'HomeTechVN T17 Demo Integration verification',
        ('Checked: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')),
        ('Project: ' + $projectId),
        '',
        'Database migration chain: 36/36 unchanged',
        'T17 DB migration: 0',
        'T1-T16 SQL regression: PASS',
        'T15 restore regression: PASS',
        'T16 concurrency regression: PASS',
        'T17 local-only hosted-URL refusal: PASS',
        'T17 local Auth signup user creation: PASS',
        'T17 password login x5 roles: PASS',
        'T17 JWT self-profile RLS + role metadata x5 roles: PASS',
        'T17 integrated dataset SQL: PASS',
        'T17 Sales/Repair/Warranty/Service/License/Reminder/Notification integration: PASS',
        'T17 public Warranty lookup regression: PASS',
        'T17 demo responsive/build check: PASS',
        'T17 app build: PASS',
        'T17 Worker check: PASS',
        'T17 clean business/auth baseline after verification: PASS',
        ('Dependency lock bundle: ' + $lockBundle.FullName),
        ('Demo snapshot: ' + $demoSnapshot.FullName),
        '',
        'T17 LOCAL REPRODUCIBILITY: PASS',
        'T17 INHERITED REGRESSION CHECKS: PASS',
        'T17 DEMO INTEGRATION CHECKS: PASS',
        'T17 DEMO AUTH LOGIN CHECK: PASS',
        'T17 DEMO ROLE JWT CHECK: PASS',
        'T17 DEMO RESPONSIVE UI CHECK: PASS',
        'T17 APP BUILD: PASS',
        'T17 WORKER CHECK: PASS',
        'T17 CLEAN BASELINE AFTER VERIFY: PASS'
    )
    Set-Content -Path $snapshotPath -Value $snapshot -Encoding UTF8

    Write-Host ''
    Write-Host '=========================================='
    Write-Host 'T17 LOCAL REPRODUCIBILITY: PASS'
    Write-Host 'T17 INHERITED REGRESSION CHECKS: PASS'
    Write-Host 'T17 DEMO INTEGRATION CHECKS: PASS'
    Write-Host 'T17 DEMO AUTH LOGIN CHECK: PASS'
    Write-Host 'T17 DEMO ROLE JWT CHECK: PASS'
    Write-Host 'T17 DEMO RESPONSIVE UI CHECK: PASS'
    Write-Host 'T17 APP BUILD: PASS'
    Write-Host 'T17 WORKER CHECK: PASS'
    Write-Host 'T17 CLEAN BASELINE AFTER VERIFY: PASS'
    Write-Host "Dependency lock bundle: $($lockBundle.FullName)"
    Write-Host "Demo snapshot: $($demoSnapshot.FullName)"
    Write-Host "Snapshot: $snapshotPath"
    Write-Host '=========================================='
    exit 0
} catch {
    if ($null -ne (Get-Variable -Name appEnvPath -ErrorAction SilentlyContinue)) {
        try {
            $restoreAlreadyCompleted = $false
            if ($null -ne (Get-Variable -Name appEnvRestoreCompleted -ErrorAction SilentlyContinue)) {
                $restoreAlreadyCompleted = [bool]$appEnvRestoreCompleted
            }

            if (-not $restoreAlreadyCompleted -and
                $null -ne (Get-Variable -Name appEnvWasPresent -ErrorAction SilentlyContinue)) {
                Restore-AppEnvState -AppEnvPath $appEnvPath -BackupPath $appEnvBackupPath -PreviouslyExisted $appEnvWasPresent
                $appEnvRestoreCompleted = $true
            }
        } catch {
            Write-Host '[T17 CLEANUP WARNING] Could not restore app/.env.local after failure.' -ForegroundColor Yellow
        }
    }
    Write-Host ''
    Write-Host '[T17 FAIL]' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
