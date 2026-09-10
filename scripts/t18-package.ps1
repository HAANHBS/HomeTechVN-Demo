param(
    [Parameter(Mandatory=$false)][string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

function Get-Stamp { return Get-Date -Format 'yyyyMMdd_HHmmss' }

function Get-RelativeProjectPath {
    param([Parameter(Mandatory=$true)][string]$FullName)
    $rootFull = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/')
    $fileFull = [IO.Path]::GetFullPath($FullName)
    $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $fileFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Package source escaped project root: $fileFull"
    }
    return $fileFull.Substring($prefix.Length).Replace('\','/')
}

function Should-IncludeFile {
    param([Parameter(Mandatory=$true)][string]$RelativePath)
    $relative = $RelativePath.Replace('\','/').TrimStart('/')
    $segments = @($relative.Split('/'))
    $blockedDirectories = @(
        '.git', 'node_modules', 'dist', '.temp', '.branches', '.wrangler',
        '.t10-dryrun', 'snapshots', 'legacy_migrations_backup',
        'config_backups', '.backup', 'backup-output'
    )
    foreach ($segment in $segments) {
        if ($segment -in $blockedDirectories) { return $false }
    }

    $leaf = $segments[$segments.Count - 1]
    if ($leaf -match '^\.env(?:\..*)?$') {
        return $leaf -in @('.env.example', '.env.production.example')
    }
    if ($leaf -match '^\.dev\.vars(?:\..*)?$') {
        return $leaf -eq '.dev.vars.example'
    }
    if ($relative -eq 'supabase/config.toml') { return $false }
    if ($leaf -match '\.(zip|log|bak|tmp)$') { return $false }
    return $true
}

function Remove-OwnedTempDirectory {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path $Path)) { return }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $temp = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\','/')
    $expectedPrefix = $temp + [IO.Path]::DirectorySeparatorChar + 'HomeTechVN_T18_Package_'
    if (-not $full.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove non-owned package directory: $full"
    }
    Remove-Item -LiteralPath $full -Recurse -Force
}

function Get-ArchiveEntries {
    param([Parameter(Mandatory=$true)][string]$ArchivePath)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        return @($archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
    } finally {
        $archive.Dispose()
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $snapshotDir = Join-Path $ProjectRoot 'docs\snapshots'
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
    $OutputPath = Join-Path $snapshotDir ('HOMETECHVN_T18_RELEASE_' + (Get-Stamp) + '.zip')
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputParent = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputParent -Force | Out-Null

$stageParent = Join-Path $env:TEMP ('HomeTechVN_T18_Package_' + (Get-Stamp) + '_' + [guid]::NewGuid().ToString('N'))
$stageRoot = Join-Path $stageParent 'HOMETECHVN_T18_RELEASE'
$rootFiles = @('.env.example', '.gitignore', 'README.md', 'package.json', 'package-lock.json')
$rootDirectories = @('app', 'docs', 'scripts', 'supabase', 'worker')

try {
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

    foreach ($name in $rootFiles) {
        $source = Join-Path $ProjectRoot $name
        if ((Test-Path $source -PathType Leaf) -and (Should-IncludeFile -RelativePath $name)) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $stageRoot $name)
        }
    }

    foreach ($name in $rootDirectories) {
        $sourceDirectory = Join-Path $ProjectRoot $name
        if (-not (Test-Path $sourceDirectory -PathType Container)) { throw "Missing package directory: $name" }
        foreach ($file in Get-ChildItem -LiteralPath $sourceDirectory -Recurse -File) {
            $relative = Get-RelativeProjectPath -FullName $file.FullName
            if (-not (Should-IncludeFile -RelativePath $relative)) { continue }
            $destination = Join-Path $stageRoot $relative.Replace('/', '\')
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $destination
        }
    }

    # WorkingCopyRuntimeConfigAllowed: runtime config may exist in D:\HOMETECHVN,
    # but it is excluded from the allowlisted stage and validated only in the ZIP.
    $stagedFiles = @(Get-ChildItem -LiteralPath $stageRoot -Recurse -File)
    foreach ($file in $stagedFiles) {
        $relative = $file.FullName.Substring($stageRoot.Length).TrimStart('\','/').Replace('\','/')
        if (-not (Should-IncludeFile -RelativePath $relative)) {
            throw "Forbidden file reached release staging: $relative"
        }
    }

    if (Test-Path $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory(
        $stageRoot,
        $OutputPath,
        [IO.Compression.CompressionLevel]::Optimal,
        $true
    )

    if (-not (Test-Path $OutputPath -PathType Leaf)) { throw 'Release ZIP was not created.' }
    $entries = @(Get-ArchiveEntries -ArchivePath $OutputPath)
    $prefix = 'HOMETECHVN_T18_RELEASE/'
    $requiredRelativePaths = @(
        'package.json'
        'app/package.json'
        'scripts/t18-verify.ps1'
        'supabase/migrations/20260831105049_t16_audit_actor_history_independence.sql'
        'worker/src/index.js'
    )
    foreach ($relativePath in $requiredRelativePaths) {
        $entry = $prefix + $relativePath
        if ($entry -notin $entries) { throw "Release ZIP missing required entry: $entry" }
    }
    foreach ($entry in $entries) {
        if (-not $entry.StartsWith($prefix, [StringComparison]::Ordinal)) {
            throw "Release ZIP entry escaped root: $entry"
        }
        if ($entry.EndsWith('/')) { continue }
        $relative = $entry.Substring($prefix.Length)
        if (-not (Should-IncludeFile -RelativePath $relative)) {
            throw "Local runtime configuration must not be packaged: $relative"
        }
    }

    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $OutputPath).Hash.ToLowerInvariant()
    Write-Host 'T18 RELEASE PACKAGE SAFETY: PASS'
    Write-Host "Release candidate: $OutputPath"
    Write-Host "Release SHA-256: $hash"
} finally {
    Remove-OwnedTempDirectory -Path $stageParent
}
