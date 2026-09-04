[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Container,
    [Parameter(Mandatory=$true)][string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-DockerChecked {
    param(
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [string]$Display = $null
    )

    if ($Display) { Write-Host "> $Display" }

    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& docker.exe @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }

    foreach ($line in $output) { Write-Host $line }

    if ($null -eq $exitCode) { $exitCode = 0 }
    if ($exitCode -ne 0) {
        throw "docker command failed ($exitCode): $($Arguments -join ' ')"
    }

    return $output
}

function Invoke-DockerProbe {
    param([Parameter(Mandatory=$true)][string[]]$Arguments)

    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& docker.exe @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }

    return [pscustomobject]@{
        ExitCode = if ($null -eq $exitCode) { 0 } else { $exitCode }
        Output = $output
    }
}

function Invoke-DockerBestEffort {
    param([Parameter(Mandatory=$true)][string[]]$Arguments)

    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & docker.exe @Arguments *> $null
    } catch {
        # Cleanup must never hide the primary verifier result.
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Resolve-LocalSuperuser {
    param([Parameter(Mandatory=$true)][string]$ContainerName)

    foreach ($candidate in @('supabase_admin','postgres')) {
        $probe = Invoke-DockerProbe -Arguments @(
            'exec',$ContainerName,
            'psql','-U',$candidate,'-d','postgres','-At',
            '-v','ON_ERROR_STOP=1',
            '-c',"select case when rolsuper then 'SUPERUSER' else 'NORMAL' end from pg_roles where rolname=current_user;"
        )

        if ($probe.ExitCode -eq 0) {
            $value = (($probe.Output -join "`n").Trim())
            Write-Host "[T15] Local DB role probe: $candidate => $value"
            if ($value -eq 'SUPERUSER') { return $candidate }
        }
    }

    throw 'No accessible local PostgreSQL SUPERUSER role was found inside the Supabase DB container. Expected supabase_admin or postgres.'
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$restoreDb = "t15_restore_$stamp"
$markerKey = "t15.restore.marker.$stamp"
$dumpHost = Join-Path $OutputDir 'full_local_restore_drill.dump'
$dumpContainer = "/tmp/t15_full_restore_$stamp.dump"
$adminRole = $null

try {
    Write-Host '=== T15 Full Local Restore Drill ==='
    Write-Host "Scratch DB: $restoreDb"

    $adminRole = Resolve-LocalSuperuser -ContainerName $Container
    Write-Host "[PASS] Local restore admin role: $adminRole"

    # Independent scratch database. Never clone the active postgres database and
    # never terminate source/service sessions.
    Invoke-DockerChecked -Arguments @(
        'exec',$Container,'psql','-U',$adminRole,'-d','template1',
        '-v','ON_ERROR_STOP=1',
        '-c',"drop database if exists $restoreDb with (force);"
    ) -Display "ensure scratch DB absent: $restoreDb" | Out-Null

    Invoke-DockerChecked -Arguments @(
        'exec',$Container,'psql','-U',$adminRole,'-d','template1',
        '-v','ON_ERROR_STOP=1',
        '-c',"create database $restoreDb template template0;"
    ) -Display 'create independent scratch DB from template0' | Out-Null

    # The marker is inserted before dumping. Since scratch started empty, it can
    # only appear after a successful restore.
    # Never pass JSON text with embedded double-quotes through
    # Windows PowerShell -> docker.exe -> psql -c. Build JSON in PostgreSQL.
    $markerSql = "insert into public.settings(key,value,description) values ('$markerKey',jsonb_build_object('stage','T15','restore','required'),'T15 restore drill marker');"
    Invoke-DockerChecked -Arguments @(
        'exec',$Container,'psql','-U',$adminRole,'-d','postgres',
        '-v','ON_ERROR_STOP=1',
        '-c',$markerSql
    ) -Display 'insert restore marker into local source DB' | Out-Null

    # FULL dump: managed schemas + app schemas + data. This avoids the circular
    # FK ordering warning that is specific to data-only restoration.
    Invoke-DockerChecked -Arguments @(
        'exec',$Container,
        'pg_dump','-U',$adminRole,'-d','postgres',
        '--format=custom','--no-owner','--no-privileges','--no-subscriptions',
        '-f',$dumpContainer
    ) -Display 'pg_dump FULL local database to custom archive' | Out-Null

    $copyOut = Invoke-DockerProbe -Arguments @('cp',"${Container}:$dumpContainer",$dumpHost)
    if ($copyOut.ExitCode -ne 0) {
        throw "docker cp restore-drill dump failed: $($copyOut.Output -join ' ')"
    }
    if (-not (Test-Path $dumpHost) -or (Get-Item $dumpHost).Length -lt 4096) {
        throw 'Full restore-drill dump is missing or unexpectedly small.'
    }

    $listOutput = Invoke-DockerChecked -Arguments @(
        'exec',$Container,'pg_restore','--list',$dumpContainer
    ) -Display 'pg_restore --list full archive structural check'

    $listText = $listOutput -join "`n"
    if ($listText -notmatch 'TABLE DATA') { throw 'Full restore-drill archive contains no TABLE DATA entries.' }
    if ($listText -notmatch 'SCHEMA') { throw 'Full restore-drill archive contains no schema entries.' }

    Invoke-DockerChecked -Arguments @(
        'exec',$Container,
        'pg_restore','-U',$adminRole,'-d',$restoreDb,
        '--no-owner','--no-privileges',
        '--single-transaction','--exit-on-error',
        $dumpContainer
    ) -Display 'pg_restore FULL archive into independent scratch DB' | Out-Null

    $markerResult = Invoke-DockerChecked -Arguments @(
        'exec',$Container,'psql','-U',$adminRole,'-d',$restoreDb,
        '-At','-v','ON_ERROR_STOP=1',
        '-c',"select coalesce(value->>'stage','') from public.settings where key='$markerKey';"
    ) -Display 'verify restored marker'

    if (($markerResult -join '').Trim() -ne 'T15') { throw 'Restore drill marker was not restored.' }

    $countSql = @"
select jsonb_build_object(
  'auth_users',(select count(*) from auth.users),
  'roles',(select count(*) from public.roles),
  'permissions',(select count(*) from public.permissions),
  'profiles',(select count(*) from public.profiles),
  'customers',(select count(*) from public.customers),
  'products',(select count(*) from public.products),
  'sales_orders',(select count(*) from public.sales_orders),
  'repair_orders',(select count(*) from public.repair_orders),
  'repair_quotes',(select count(*) from public.repair_quotes),
  'warranties',(select count(*) from public.warranties),
  'reminders',(select count(*) from public.reminders),
  'notifications',(select count(*) from public.notifications),
  'sales_costs',(select count(*) from private.sales_order_item_costs),
  'repair_costs',(select count(*) from private.repair_part_costs),
  'settings',(select count(*) from public.settings),
  'storage_buckets',(select count(*) from storage.buckets),
  'storage_objects',(select count(*) from storage.objects)
)::text;
"@

    $sourceCounts = Invoke-DockerChecked -Arguments @(
        'exec',$Container,'psql','-U',$adminRole,'-d','postgres','-At',
        '-v','ON_ERROR_STOP=1','-c',$countSql
    ) -Display 'read source critical row-count signature'

    $restoreCounts = Invoke-DockerChecked -Arguments @(
        'exec',$Container,'psql','-U',$adminRole,'-d',$restoreDb,'-At',
        '-v','ON_ERROR_STOP=1','-c',$countSql
    ) -Display 'read restored critical row-count signature'

    $sourceSignature = ($sourceCounts -join '').Trim()
    $restoreSignature = ($restoreCounts -join '').Trim()
    if ($sourceSignature -ne $restoreSignature) {
        throw "Critical row-count signature mismatch.`nSource: $sourceSignature`nRestore: $restoreSignature"
    }

    $report = [ordered]@{
        status = 'PASS'
        createdAt = (Get-Date).ToString('o')
        scratchDatabase = $restoreDb
        localAdminRole = $adminRole
        marker = $markerKey
        archive = $dumpHost
        archiveSha256 = (Get-FileHash -Algorithm SHA256 -Path $dumpHost).Hash.ToLowerInvariant()
        sourceCounts = ($sourceSignature | ConvertFrom-Json)
        restoredCounts = ($restoreSignature | ConvertFrom-Json)
        scope = 'Full local PostgreSQL database dump/restore into independent template0 scratch database.'
        sourceConnectionTerminationUsed = $false
        productionTouched = $false
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $OutputDir 'restore-drill.json') -Encoding UTF8

    Write-Host ''
    Write-Host 'T15 FULL LOCAL RESTORE DRILL: PASS'
    Write-Host 'T15 APP DATA RESTORE DRILL: PASS'
} finally {
    # Cleanup cannot obscure the primary result. No source-session termination is used.
    if ($adminRole) {
        Invoke-DockerBestEffort -Arguments @(
            'exec',$Container,'psql','-U',$adminRole,'-d','postgres',
            '-v','ON_ERROR_STOP=1',
            '-c',"delete from public.settings where key='$markerKey';"
        )

        Invoke-DockerBestEffort -Arguments @(
            'exec',$Container,'psql','-U',$adminRole,'-d','template1',
            '-v','ON_ERROR_STOP=1',
            '-c',"drop database if exists $restoreDb with (force);"
        )
    }

    Invoke-DockerBestEffort -Arguments @('exec',$Container,'rm','-f',$dumpContainer)
}
