[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $env:LOCALAPPDATA 'HomeTechVN\Backup\config.json'),
    [string]$SecretPath = (Join-Path $env:LOCALAPPDATA 'HomeTechVN\Backup\secrets.json'),
    [switch]$SkipRetention
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

function Resolve-CommandPath {
    param([Parameter(Mandatory=$true)][string[]]$Names)
    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) { return $cmd.Source }
    }
    throw "Command not found: $($Names -join ', ')"
}

function Unprotect-Secret {
    param([Parameter(Mandatory=$true)][string]$CipherText)
    $secure = ConvertTo-SecureString -String $CipherText
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Invoke-Safe {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$false)][string[]]$Arguments = @(),
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

    foreach ($line in $output) { Write-Host $line }
    if ($null -eq $exitCode) { $exitCode = 0 }
    if ($exitCode -ne 0) {
        throw "Command failed with exit code $exitCode. See output above."
    }
    return $output
}

function Get-FileSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}

function Get-CopyRowCount {
    param(
        [Parameter(Mandatory=$true)][string]$SqlPath,
        [Parameter(Mandatory=$true)][string]$TableName
    )

    $count = 0
    $inside = $false
    $escaped = [regex]::Escape($TableName)
    foreach ($line in Get-Content -Path $SqlPath) {
        if (-not $inside) {
            if ($line -match "^COPY\s+(?:`"|)?storage(?:`"|)?\.(?:`"|)?$escaped(?:`"|)?\s+\(") {
                $inside = $true
            }
            continue
        }

        if ($line -eq '\.') { break }
        $count += 1
    }
    return $count
}

function Get-RelativePathCompat {
    param(
        [Parameter(Mandatory=$true)][string]$BasePath,
        [Parameter(Mandatory=$true)][string]$TargetPath
    )

    $baseFull = [IO.Path]::GetFullPath($BasePath).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    $targetFull = [IO.Path]::GetFullPath($TargetPath)
    $baseUri = New-Object Uri($baseFull)
    $targetUri = New-Object Uri($targetFull)
    return [Uri]::UnescapeDataString(
        $baseUri.MakeRelativeUri($targetUri).ToString()
    ).Replace('/', [IO.Path]::DirectorySeparatorChar)
}

function New-SourceArchive {
    param(
        [Parameter(Mandatory=$true)][string]$SourceRoot,
        [Parameter(Mandatory=$true)][string]$Destination
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    if (Test-Path $Destination) { Remove-Item $Destination -Force }
    $stream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew)
    try {
        $archive = New-Object IO.Compression.ZipArchive -ArgumentList @(
            $stream,
            [IO.Compression.ZipArchiveMode]::Create,
            $false
        )
        try {
            $rootResolved = (Resolve-Path $SourceRoot).Path
            $files = Get-ChildItem -Path $rootResolved -File -Recurse -Force

            foreach ($file in $files) {
                $relative = Get-RelativePathCompat -BasePath $rootResolved -TargetPath $file.FullName
                $parts = $relative -split '[\\/]'
                $relativeUnix = ($parts -join '/')

                if ($parts -contains '.git' -or
                    $parts -contains 'node_modules' -or
                    $parts -contains 'dist' -or
                    $parts -contains '.wrangler' -or
                    $parts -contains '.temp' -or
                    $parts -contains '.branches' -or
                    $parts -contains '.backup' -or
                    $parts -contains 'backup-output') {
                    continue
                }

                if ($relativeUnix -like 'docs/snapshots/*' -or
                    $relativeUnix -like 'docs/config_backups/*' -or
                    $relativeUnix -like 'docs/legacy_migrations_backup/*') {
                    continue
                }

                $name = $file.Name
                if ($name -eq '.env' -or
                    ($name -like '.env.*' -and $name -ne '.env.example') -or
                    $relativeUnix -eq 'worker/.dev.vars' -or
                    $relativeUnix -like 'worker/.dev.vars.*' -and $relativeUnix -ne 'worker/.dev.vars.example' -or
                    $name -like '*.log') {
                    continue
                }

                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $archive,
                    $file.FullName,
                    $relativeUnix,
                    [IO.Compression.CompressionLevel]::Optimal
                ) | Out-Null
            }
        } finally {
            $archive.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Set-RcloneEnvironment {
    param(
        [Parameter(Mandatory=$true)][string]$Endpoint,
        [Parameter(Mandatory=$true)][string]$Region,
        [Parameter(Mandatory=$true)][string]$AccessKeyId,
        [Parameter(Mandatory=$true)][string]$SecretAccessKey
    )
    $env:RCLONE_CONFIG_HTV_TYPE = 's3'
    $env:RCLONE_CONFIG_HTV_PROVIDER = 'Other'
    $env:RCLONE_CONFIG_HTV_ENDPOINT = $Endpoint
    $env:RCLONE_CONFIG_HTV_REGION = $Region
    $env:RCLONE_CONFIG_HTV_ACCESS_KEY_ID = $AccessKeyId
    $env:RCLONE_CONFIG_HTV_SECRET_ACCESS_KEY = $SecretAccessKey
}

function Clear-RcloneEnvironment {
    Remove-Item Env:RCLONE_CONFIG_HTV_TYPE -ErrorAction SilentlyContinue
    Remove-Item Env:RCLONE_CONFIG_HTV_PROVIDER -ErrorAction SilentlyContinue
    Remove-Item Env:RCLONE_CONFIG_HTV_ENDPOINT -ErrorAction SilentlyContinue
    Remove-Item Env:RCLONE_CONFIG_HTV_REGION -ErrorAction SilentlyContinue
    Remove-Item Env:RCLONE_CONFIG_HTV_ACCESS_KEY_ID -ErrorAction SilentlyContinue
    Remove-Item Env:RCLONE_CONFIG_HTV_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
}

if (-not (Test-Path $ConfigPath)) {
    throw "Backup config missing: $ConfigPath. Run npm run t15:configure first."
}
if (-not (Test-Path $SecretPath)) {
    throw "Backup secret file missing: $SecretPath. Run npm run t15:configure first."
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
$secrets = Get-Content -Path $SecretPath -Raw | ConvertFrom-Json

if ($config.projectRef -ne 'puqvbenyenwemfbsqpfd') {
    throw "Unexpected projectRef in backup config: $($config.projectRef)"
}

$dbUrl = Unprotect-Secret -CipherText $secrets.dbUrl
if ([string]::IsNullOrWhiteSpace($dbUrl)) { throw 'Decrypted DB URL is empty.' }

$npx = Resolve-CommandPath -Names @('npx.cmd','npx')
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupName = "HomeTechVN_$timestamp"
$outputRoot = [string]$config.outputDir
$backupDir = Join-Path $outputRoot $backupName
$dbDir = Join-Path $backupDir 'database'
$storageDir = Join-Path $backupDir 'storage'
New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
New-Item -ItemType Directory -Path $storageDir -Force | Out-Null

$status = 'FULL'
$storageStatus = 'NOT_REQUIRED_EMPTY'
$storageRemoteObjects = 0
$storageRemoteBuckets = 0
$storageBackupObjects = 0
$storageBackupBytes = 0

try {
    Write-Host "=== HomeTechVN T15 Production Backup ==="
    Write-Host "Output: $backupDir"
    Write-Host "Project: $($config.projectRef)"

    $rolesPath = Join-Path $dbDir 'roles.sql'
    $schemaPath = Join-Path $dbDir 'schema.sql'
    $dataPath = Join-Path $dbDir 'data.sql'
    $historySchemaPath = Join-Path $dbDir 'history_schema.sql'
    $historyDataPath = Join-Path $dbDir 'history_data.sql'
    $storageMetaPath = Join-Path $dbDir 'storage_metadata.sql'

    Invoke-Safe -FilePath $npx -Arguments @(
        'supabase','db','dump','--db-url',$dbUrl,
        '-f',$rolesPath,'--role-only'
    ) -Display 'npx supabase db dump --db-url [REDACTED] -f roles.sql --role-only' | Out-Null

    Invoke-Safe -FilePath $npx -Arguments @(
        'supabase','db','dump','--db-url',$dbUrl,
        '-f',$schemaPath
    ) -Display 'npx supabase db dump --db-url [REDACTED] -f schema.sql' | Out-Null

    Invoke-Safe -FilePath $npx -Arguments @(
        'supabase','db','dump','--db-url',$dbUrl,
        '-f',$dataPath,'--use-copy','--data-only',
        '-x','storage.buckets_vectors','-x','storage.vector_indexes'
    ) -Display 'npx supabase db dump --db-url [REDACTED] -f data.sql --use-copy --data-only [vector exclusions]' | Out-Null

    Invoke-Safe -FilePath $npx -Arguments @(
        'supabase','db','dump','--db-url',$dbUrl,
        '-f',$historySchemaPath,'--schema','supabase_migrations'
    ) -Display 'npx supabase db dump --db-url [REDACTED] -f history_schema.sql --schema supabase_migrations' | Out-Null

    Invoke-Safe -FilePath $npx -Arguments @(
        'supabase','db','dump','--db-url',$dbUrl,
        '-f',$historyDataPath,'--use-copy','--data-only','--schema','supabase_migrations'
    ) -Display 'npx supabase db dump --db-url [REDACTED] -f history_data.sql --use-copy --data-only --schema supabase_migrations' | Out-Null

    # Storage file bytes are not part of DB backups. This dump is metadata/audit only.
    Invoke-Safe -FilePath $npx -Arguments @(
        'supabase','db','dump','--db-url',$dbUrl,
        '-f',$storageMetaPath,'--use-copy','--data-only','--schema','storage',
        '-x','storage.buckets_vectors','-x','storage.vector_indexes'
    ) -Display 'npx supabase db dump --db-url [REDACTED] -f storage_metadata.sql --use-copy --data-only --schema storage [vector exclusions]' | Out-Null

    foreach ($required in @(
        $rolesPath,$schemaPath,$dataPath,$historySchemaPath,$historyDataPath,$storageMetaPath
    )) {
        if (-not (Test-Path $required) -or (Get-Item $required).Length -eq 0) {
            throw "Backup artifact is missing/empty: $required"
        }
    }

    $storageRemoteBuckets = Get-CopyRowCount -SqlPath $storageMetaPath -TableName 'buckets'
    $storageRemoteObjects = Get-CopyRowCount -SqlPath $storageMetaPath -TableName 'objects'

    if ([bool]$config.storage.enabled) {
        $rclone = Resolve-CommandPath -Names @('rclone.exe','rclone')
        $accessKey = Unprotect-Secret -CipherText $secrets.s3AccessKeyId
        $secretKey = Unprotect-Secret -CipherText $secrets.s3SecretAccessKey

        Set-RcloneEnvironment `
            -Endpoint ([string]$config.storage.endpoint) `
            -Region ([string]$config.storage.region) `
            -AccessKeyId $accessKey `
            -SecretAccessKey $secretKey

        try {
            $rawBuckets = @(
                & $rclone lsf 'htv:' --dirs-only 2>&1
            )
            if ($LASTEXITCODE -ne 0) {
                throw "rclone bucket listing failed: $($rawBuckets -join ' ')"
            }

            $buckets = @(
                $rawBuckets |
                ForEach-Object { $_.ToString().Trim().TrimEnd('/') } |
                Where-Object { $_ }
            )

            foreach ($bucket in $buckets) {
                $localBucket = Join-Path $storageDir $bucket
                New-Item -ItemType Directory -Path $localBucket -Force | Out-Null

                Invoke-Safe -FilePath $rclone -Arguments @(
                    'copy',"htv:$bucket",$localBucket,
                    '--checksum','--create-empty-src-dirs'
                ) -Display "rclone copy htv:$bucket [LOCAL_BACKUP]\$bucket --checksum" | Out-Null

                $remoteJson = & $rclone size "htv:$bucket" --json 2>&1
                if ($LASTEXITCODE -ne 0) { throw "rclone remote size failed for bucket $bucket" }
                $localJson = & $rclone size $localBucket --json 2>&1
                if ($LASTEXITCODE -ne 0) { throw "rclone local size failed for bucket $bucket" }

                $remoteSize = ($remoteJson -join "`n") | ConvertFrom-Json
                $localSize = ($localJson -join "`n") | ConvertFrom-Json

                if ([int64]$remoteSize.count -ne [int64]$localSize.count -or
                    [int64]$remoteSize.bytes -ne [int64]$localSize.bytes) {
                    throw "Storage verification failed for bucket $bucket. Remote count/bytes=$($remoteSize.count)/$($remoteSize.bytes), local=$($localSize.count)/$($localSize.bytes)"
                }

                $storageBackupObjects += [int64]$localSize.count
                $storageBackupBytes += [int64]$localSize.bytes
            }

            if ($storageRemoteObjects -ne $storageBackupObjects) {
                throw "Storage metadata/object backup count mismatch. DB metadata=$storageRemoteObjects, S3 backup=$storageBackupObjects"
            }

            $storageStatus = 'S3_BACKUP_VERIFIED'
        } finally {
            Clear-RcloneEnvironment
            $accessKey = $null
            $secretKey = $null
        }
    } elseif ($storageRemoteObjects -gt 0) {
        $status = 'PARTIAL'
        $storageStatus = 'OBJECTS_PRESENT_S3_BACKUP_NOT_CONFIGURED'
        throw "Storage contains $storageRemoteObjects object(s), but S3 backup is not configured. Backup cannot be FULL."
    } else {
        $storageStatus = 'NOT_REQUIRED_EMPTY'
    }

    $sourceZip = Join-Path $backupDir 'source.zip'
    New-SourceArchive -SourceRoot ([string]$config.sourceRoot) -Destination $sourceZip
    if ((Get-Item $sourceZip).Length -eq 0) { throw 'source.zip is empty.' }

    # Checksums cover every payload artifact, excluding the checksum/manifest files themselves.
    $payloadFiles = @(
        Get-ChildItem -Path $backupDir -File -Recurse |
        Where-Object { $_.Name -notin @('manifest.json','checksums.sha256') } |
        Sort-Object FullName
    )

    $checksumLines = foreach ($file in $payloadFiles) {
        $relative = (Get-RelativePathCompat -BasePath $backupDir -TargetPath $file.FullName).Replace('\','/')
        "$(Get-FileSha256 -Path $file.FullName)  $relative"
    }
    $checksumPath = Join-Path $backupDir 'checksums.sha256'
    Set-Content -Path $checksumPath -Value $checksumLines -Encoding UTF8

    $manifest = [ordered]@{
        format = 'hometechvn-backup-v1'
        status = $status
        createdAt = (Get-Date).ToString('o')
        projectRef = [string]$config.projectRef
        backupName = $backupName
        sourceRoot = [string]$config.sourceRoot
        database = [ordered]@{
            roles = 'database/roles.sql'
            schema = 'database/schema.sql'
            data = 'database/data.sql'
            migrationHistorySchema = 'database/history_schema.sql'
            migrationHistoryData = 'database/history_data.sql'
            storageMetadata = 'database/storage_metadata.sql'
        }
        storage = [ordered]@{
            status = $storageStatus
            metadataBucketCount = $storageRemoteBuckets
            metadataObjectCount = $storageRemoteObjects
            backedUpObjectCount = $storageBackupObjects
            backedUpBytes = $storageBackupBytes
        }
        source = [ordered]@{
            archive = 'source.zip'
        }
        checksums = 'checksums.sha256'
        secretsIncluded = $false
        restorePolicy = 'Restore to a NEW Supabase/local drill target; never overwrite production for testing.'
    }

    $manifestPath = Join-Path $backupDir 'manifest.json'
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding UTF8

    if (-not $SkipRetention) {
        $cutoff = (Get-Date).AddDays(-[int]$config.retentionDays)
        Get-ChildItem -Path $outputRoot -Directory -Filter 'HomeTechVN_*' |
            Where-Object { $_.FullName -ne $backupDir -and $_.LastWriteTime -lt $cutoff } |
            ForEach-Object {
                $oldManifest = Join-Path $_.FullName 'manifest.json'
                if (Test-Path $oldManifest) {
                    try {
                        $old = Get-Content $oldManifest -Raw | ConvertFrom-Json
                        if ($old.format -eq 'hometechvn-backup-v1' -and $old.status -eq 'FULL') {
                            Remove-Item $_.FullName -Recurse -Force
                            Write-Host "[RETENTION] Removed verified old backup: $($_.Name)"
                        }
                    } catch {
                        Write-Warning "Retention skipped unreadable backup: $($_.FullName)"
                    }
                }
            }
    }

    Set-Content -Path (Join-Path $outputRoot 'LATEST.txt') -Value $backupDir -Encoding UTF8

    Write-Host ''
    Write-Host '=========================================='
    Write-Host 'T15 PRODUCTION BACKUP: PASS'
    Write-Host "Status: $status"
    Write-Host "Storage: $storageStatus ($storageRemoteObjects object metadata row(s))"
    Write-Host "Backup: $backupDir"
    Write-Host 'Secrets included: NO'
    Write-Host '=========================================='
} catch {
    # Keep failed/partial backup for investigation; do not prune it.
    $failure = [ordered]@{
        format = 'hometechvn-backup-v1'
        status = 'FAILED'
        createdAt = (Get-Date).ToString('o')
        projectRef = [string]$config.projectRef
        error = $_.Exception.Message
        secretsIncluded = $false
    }
    $failure | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $backupDir 'manifest.json') -Encoding UTF8
    Write-Host ''
    Write-Host '[T15 BACKUP FAIL]' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
} finally {
    $dbUrl = $null
    Clear-RcloneEnvironment
}
