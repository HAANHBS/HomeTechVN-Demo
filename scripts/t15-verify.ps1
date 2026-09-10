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
    '20260830171108_t13_reports_snapshot.sql'
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
        [switch]$AllowFailure,
        [string]$Display = $null
    )

    Write-Host ''
    if ($Display) {
        Write-Host "> $Display"
    } else {
        Write-Host ('> ' + $FilePath + ' ' + ($Arguments -join ' '))
    }

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
        throw "Lenh that bai, exit code ${exitCode}: $FilePath`n$($output -join [Environment]::NewLine)"
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
    if (-not (Test-Path $configPath)) {
        throw 'supabase init khong tao config.toml.'
    }
}

function Assert-Migrations {
    $actual = @(
        Get-ChildItem -Path (Join-Path $ProjectRoot 'supabase\migrations') -Filter '*.sql' -File |
        Select-Object -ExpandProperty Name |
        Sort-Object
    )

    $missing = @($ExpectedMigrations | Where-Object { $_ -notin $actual })
    $unexpected = @($actual | Where-Object { $_ -notin $ExpectedMigrations })

    if ($missing.Count -gt 0) {
        throw ("Thieu migration:`n- " + ($missing -join "`n- "))
    }
    if ($unexpected.Count -gt 0) {
        throw ("T15 Backup khong duoc them/sua migration. Co file ngoai baseline:`n- " + ($unexpected -join "`n- "))
    }
    if (@($actual | Where-Object { $_ -match '_t15_' }).Count -gt 0) {
        throw 'T15 Backup khong can database migration.'
    }

    Write-Host '[PASS] Database migration baseline T1-T13 remains 33/33; T15 adds 0 migration.'
    return $actual
}

function Read-ProjectId {
    $content = Get-Content -Path (Join-Path $ProjectRoot 'supabase\config.toml') -Raw
    $match = [regex]::Match($content, '(?m)^\s*project_id\s*=\s*["'']([^"'']+)["'']')
    if (-not $match.Success) {
        throw 'Khong doc duoc project_id trong config.toml.'
    }
    return $match.Groups[1].Value
}

function Invoke-T13Regression {
    param([Parameter(Mandatory=$true)][string]$Container)

    $verifyFile = Join-Path $ProjectRoot 'supabase\tests\t13_verify.sql'
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(
            Get-Content -Path $verifyFile -Raw |
            & docker.exe exec -i $Container psql -U postgres -d postgres -v ON_ERROR_STOP=1 2>&1
        )
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }

    foreach ($line in $output) { Write-Host $line }
    $text = $output -join [Environment]::NewLine

    if ($exitCode -ne 0) {
        throw "T13 regression SQL fail, psql exit=$exitCode`n$text"
    }
    if ($text -notmatch 'T13 FINAL CORE CHECKS: PASS') {
        throw 'Khong tim thay marker T13 FINAL CORE CHECKS: PASS.'
    }

    return $text
}

function Verify-BackupChecksums {
    param([Parameter(Mandatory=$true)][string]$BackupDir)

    $checksumPath = Join-Path $BackupDir 'checksums.sha256'
    if (-not (Test-Path $checksumPath)) {
        throw "Backup checksum file missing: $checksumPath"
    }

    $checked = 0
    foreach ($line in Get-Content -Path $checksumPath) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch '^([0-9a-fA-F]{64})\s{2}(.+)$') {
            throw "Invalid checksum line: $line"
        }

        $expectedHash = $Matches[1].ToLowerInvariant()
        $relative = $Matches[2].Replace('/', [IO.Path]::DirectorySeparatorChar)
        $file = Join-Path $BackupDir $relative

        if (-not (Test-Path $file)) {
            throw "Checksum payload missing: $relative"
        }

        $actualHash = (Get-FileHash -Algorithm SHA256 -Path $file).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            throw "Checksum mismatch: $relative"
        }
        $checked += 1
    }

    if ($checked -lt 7) {
        throw "Too few backup payload checksums verified: $checked"
    }

    Write-Host "[PASS] Backup checksum verification: $checked payload files"
    return $checked
}

try {
    Write-Host '=== HomeTechVN T15 v1.0 - Backup + Restore Verification ==='
    Write-Host "Project root: $ProjectRoot"

    $npx = Resolve-CommandPath -Names @('npx.cmd','npx')
    $npm = Resolve-CommandPath -Names @('npm.cmd','npm')
    $node = Resolve-CommandPath -Names @('node.exe','node')

    Ensure-SupabaseConfig -Npx $npx
    $migrations = Assert-Migrations

    # Static/security contract first.
    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t15-source-check.mjs')) | Out-Null

    # First run: securely configure production backup on the user's Windows machine.
    $backupConfig = Join-Path $env:LOCALAPPDATA 'HomeTechVN\Backup\config.json'
    $backupSecrets = Join-Path $env:LOCALAPPDATA 'HomeTechVN\Backup\secrets.json'
    if (-not (Test-Path $backupConfig) -or -not (Test-Path $backupSecrets)) {
        Write-Host ''
        Write-Host '[INFO] T15 production backup is not configured yet.'
        Write-Host '[INFO] The setup will ask for the Session Pooler URL template and password securely.'
        Invoke-CheckedCommand -FilePath 'powershell.exe' -Arguments @(
            '-NoProfile','-ExecutionPolicy','Bypass',
            '-File',(Join-Path $ProjectRoot 'scripts\t15-configure-backup.ps1')
        ) | Out-Null
    }

    # Create a REAL remote backup and require FULL status.
    $backupOutput = Invoke-CheckedCommand -FilePath 'powershell.exe' -Arguments @(
        '-NoProfile','-ExecutionPolicy','Bypass',
        '-File',(Join-Path $ProjectRoot 'scripts\t15-backup.ps1'),
        '-SkipRetention'
    )
    if (($backupOutput -join [Environment]::NewLine) -notmatch 'T15 PRODUCTION BACKUP: PASS') {
        throw 'Production backup did not return PASS.'
    }

    $config = Get-Content $backupConfig -Raw | ConvertFrom-Json
    $latestPathFile = Join-Path ([string]$config.outputDir) 'LATEST.txt'
    if (-not (Test-Path $latestPathFile)) {
        throw 'LATEST.txt was not produced by T15 backup.'
    }

    $latestBackup = (Get-Content $latestPathFile -Raw).Trim()
    if (-not (Test-Path $latestBackup)) {
        throw "Latest backup directory does not exist: $latestBackup"
    }

    $manifestPath = Join-Path $latestBackup 'manifest.json'
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.format -ne 'hometechvn-backup-v1' -or $manifest.status -ne 'FULL') {
        throw "Latest production backup is not FULL: $($manifest.status)"
    }
    if ([bool]$manifest.secretsIncluded) {
        throw 'Backup manifest reports secretsIncluded=true.'
    }

    $checksumCount = Verify-BackupChecksums -BackupDir $latestBackup

    foreach ($required in @(
        'database\roles.sql',
        'database\schema.sql',
        'database\data.sql',
        'database\history_schema.sql',
        'database\history_data.sql',
        'database\storage_metadata.sql',
        'source.zip'
    )) {
        $file = Join-Path $latestBackup $required
        if (-not (Test-Path $file) -or (Get-Item $file).Length -eq 0) {
            throw "Required production backup artifact missing/empty: $required"
        }
    }

    Write-Host '[PASS] Real remote production backup: FULL'

    # Local reproducibility + actual application-data restore drill.
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','stop','--no-backup') -AllowFailure | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','start') | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','reset','--local') | Out-Null

    $projectId = Read-ProjectId
    $container = "supabase_db_$projectId"
    $state = & docker.exe inspect -f '{{.State.Status}}' $container 2>&1
    if ($LASTEXITCODE -ne 0 -or ($state -join '').Trim() -ne 'running') {
        throw "Database container khong running: $($state -join ' ')"
    }

    $sqlOutput = Invoke-T13Regression -Container $container

    # Verify current Supabase CLI can produce all official local logical-dump components.
    $localDumpDir = Join-Path $env:TEMP ("HomeTechVN_T15_LocalDump_" + (Get-Stamp))
    New-Item -ItemType Directory -Path $localDumpDir -Force | Out-Null

    $localRoles = Join-Path $localDumpDir 'roles.sql'
    $localSchema = Join-Path $localDumpDir 'schema.sql'
    $localData = Join-Path $localDumpDir 'data.sql'
    $localHistorySchema = Join-Path $localDumpDir 'history_schema.sql'
    $localHistoryData = Join-Path $localDumpDir 'history_data.sql'
    $localStorageMeta = Join-Path $localDumpDir 'storage_metadata.sql'

    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','dump','--local','-f',$localRoles,'--role-only') | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','dump','--local','-f',$localSchema) | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','dump','--local','-f',$localData,'--use-copy','--data-only','-x','storage.buckets_vectors','-x','storage.vector_indexes') | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','dump','--local','-f',$localHistorySchema,'--schema','supabase_migrations') | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','dump','--local','-f',$localHistoryData,'--use-copy','--data-only','--schema','supabase_migrations') | Out-Null
    Invoke-CheckedCommand -FilePath $npx -Arguments @('supabase','db','dump','--local','-f',$localStorageMeta,'--use-copy','--data-only','--schema','storage','-x','storage.buckets_vectors','-x','storage.vector_indexes') | Out-Null

    foreach ($file in @($localRoles,$localSchema,$localData,$localHistorySchema,$localHistoryData,$localStorageMeta)) {
        if (-not (Test-Path $file) -or (Get-Item $file).Length -eq 0) {
            throw "Local Supabase logical dump artifact missing/empty: $file"
        }
    }
    Write-Host '[PASS] Official Supabase CLI logical dump components generated locally'

    $drillDir = Join-Path $localDumpDir 'restore-drill'
    $drillOutput = Invoke-CheckedCommand -FilePath 'powershell.exe' -Arguments @(
        '-NoProfile','-ExecutionPolicy','Bypass',
        '-File',(Join-Path $ProjectRoot 'scripts\t15-restore-drill.ps1'),
        '-Container',$container,
        '-OutputDir',$drillDir
    )

    if (($drillOutput -join [Environment]::NewLine) -notmatch 'T15 APP DATA RESTORE DRILL: PASS') {
        throw 'T15 restore drill did not return PASS.'
    }
    if (-not (Test-Path (Join-Path $drillDir 'restore-drill.json'))) {
        throw 'Restore drill report was not created.'
    }

    # Preserve all UI/PWA behavior and build.
    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t11-ui-check.mjs')) | Out-Null
    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t12-ui-check.mjs')) | Out-Null
    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t13-ui-check.mjs')) | Out-Null
    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t14-pwa-check.mjs')) | Out-Null

    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix','app','install','--no-audit','--no-fund') | Out-Null
    Invoke-CheckedCommand -FilePath $npm -Arguments @('--prefix','app','run','build') | Out-Null
    Invoke-CheckedCommand -FilePath $node -Arguments @((Join-Path $ProjectRoot 'scripts\t14-build-check.mjs')) | Out-Null

    $snapshotDir = Join-Path $ProjectRoot 'docs\snapshots'
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    $snapshotPath = Join-Path $snapshotDir ('T15_LOCAL_VERIFY_' + (Get-Stamp) + '.txt')

    $snapshot = @(
        'HomeTechVN T15 backup/restore verification',
        ('Checked: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')),
        ('Project: ' + $projectId),
        ('Production backup: ' + $latestBackup),
        ('Production backup status: ' + $manifest.status),
        ('Production backup payload checksums: ' + $checksumCount),
        ('Storage backup status: ' + $manifest.storage.status),
        ('Storage metadata object count: ' + $manifest.storage.metadataObjectCount),
        '',
        'Migrations:',
        ($migrations -join [Environment]::NewLine),
        '',
        'T13 DATABASE REGRESSION:',
        $sqlOutput,
        '',
        'OFFICIAL LOCAL LOGICAL DUMPS: PASS',
        'APP DATA RESTORE DRILL: PASS',
        'T11-T14 RESPONSIVE/PWA REGRESSION: PASS',
        'APP BUILD: PASS',
        '',
        'T15 LOCAL REPRODUCIBILITY: PASS',
        'T15 BACKUP CORE CHECKS: PASS',
        'T15 RESTORE DRILL: PASS',
        'T15 RESPONSIVE UI CHECK: PASS',
        'T15 APP BUILD: PASS'
    )

    Set-Content -Path $snapshotPath -Value $snapshot -Encoding UTF8

    # Local temp backup can be removed after its report has been summarized.
    Remove-Item $localDumpDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host ''
    Write-Host '=========================================='
    Write-Host 'T15 LOCAL REPRODUCIBILITY: PASS'
    Write-Host 'T15 BACKUP CORE CHECKS: PASS'
    Write-Host 'T15 RESTORE DRILL: PASS'
    Write-Host 'T15 RESPONSIVE UI CHECK: PASS'
    Write-Host 'T15 APP BUILD: PASS'
    Write-Host "Production backup: $latestBackup"
    Write-Host "Snapshot: $snapshotPath"
    Write-Host '=========================================='
    exit 0
} catch {
    Write-Host ''
    Write-Host '[T15 FAIL]' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
