[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ConfigRoot = Join-Path $env:LOCALAPPDATA 'HomeTechVN\Backup'
$ConfigPath = Join-Path $ConfigRoot 'config.json'
$SecretPath = Join-Path $ConfigRoot 'secrets.json'

function Read-Default {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [Parameter(Mandatory=$true)][string]$Default
    )
    $value = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value.Trim()
}

function Read-YesNo {
    param(
        [Parameter(Mandatory=$true)][string]$Prompt,
        [bool]$Default = $false
    )
    $suffix = if ($Default) { '[Y/n]' } else { '[y/N]' }
    $answer = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer.Trim().ToLowerInvariant() -in @('y','yes','1','true','co','co')
}

function Protect-Secret {
    param([Parameter(Mandatory=$true)][Security.SecureString]$Value)
    return ConvertFrom-SecureString -SecureString $Value
}

New-Item -ItemType Directory -Path $ConfigRoot -Force | Out-Null

$defaultOutput = if (Test-Path 'D:\') {
    'D:\HOMETECHVN_BACKUPS'
} else {
    Join-Path $env:USERPROFILE 'HOMETECHVN_BACKUPS'
}

Write-Host '=== HomeTechVN T15 Backup Configuration ==='
Write-Host 'Secrets are encrypted with Windows DPAPI for the CURRENT Windows user.'
Write-Host "Config root: $ConfigRoot"
Write-Host ''

$outputDir = Read-Default -Prompt 'Backup output directory' -Default $defaultOutput
$retentionText = Read-Default -Prompt 'Retention days' -Default '30'
[int]$retentionDays = 30
if (-not [int]::TryParse($retentionText, [ref]$retentionDays) -or $retentionDays -lt 7 -or $retentionDays -gt 3650) {
    throw 'Retention days must be an integer from 7 to 3650.'
}

Write-Host ''
Write-Host 'Supabase Dashboard > Connect > Session pooler.'
Write-Host 'Paste the connection URL while KEEPING the [YOUR-PASSWORD] placeholder.'
$dbUrlTemplate = Read-Host 'Session pooler URL template'
if ([string]::IsNullOrWhiteSpace($dbUrlTemplate)) {
    throw 'Session pooler URL template is required.'
}
if ($dbUrlTemplate -notmatch '\[YOUR[-_]PASSWORD\]') {
    throw 'For safety, paste the URL with [YOUR-PASSWORD] placeholder instead of a plaintext password.'
}

$dbPassword = Read-Host 'Database password' -AsSecureString
if ($dbPassword.Length -eq 0) { throw 'Database password is required.' }

$dbPasswordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword)
try {
    $dbPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($dbPasswordPtr)
    $encodedPassword = [Uri]::EscapeDataString($dbPasswordPlain)
    $dbUrlPlain = [regex]::Replace(
        $dbUrlTemplate.Trim(),
        '\[YOUR[-_]PASSWORD\]',
        $encodedPassword,
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $dbUrl = ConvertTo-SecureString -String $dbUrlPlain -AsPlainText -Force
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($dbPasswordPtr)
    $dbPasswordPlain = $null
    $encodedPassword = $null
    $dbUrlPlain = $null
}

$storageEnabled = Read-YesNo -Prompt 'Configure Supabase Storage S3 backup now?' -Default $false
$s3Endpoint = ''
$s3Region = 'ap-southeast-1'
$s3AccessKey = $null
$s3SecretKey = $null

if ($storageEnabled) {
    $s3Endpoint = Read-Default `
        -Prompt 'Storage S3 endpoint' `
        -Default 'https://puqvbenyenwemfbsqpfd.storage.supabase.co/storage/v1/s3'
    $s3Region = Read-Default -Prompt 'Storage S3 region' -Default 'ap-southeast-1'
    $s3AccessKey = Read-Host 'Storage S3 access key ID' -AsSecureString
    $s3SecretKey = Read-Host 'Storage S3 secret access key' -AsSecureString
    if ($s3AccessKey.Length -eq 0 -or $s3SecretKey.Length -eq 0) {
        throw 'Both Storage S3 access key ID and secret access key are required when Storage backup is enabled.'
    }
}

$config = [ordered]@{
    formatVersion = 1
    projectRef = 'puqvbenyenwemfbsqpfd'
    sourceRoot = $ProjectRoot
    outputDir = $outputDir
    retentionDays = $retentionDays
    storage = [ordered]@{
        enabled = $storageEnabled
        endpoint = $s3Endpoint
        region = $s3Region
    }
    createdAt = (Get-Date).ToString('o')
    createdBy = "$env:USERDOMAIN\$env:USERNAME"
}

$secrets = [ordered]@{
    formatVersion = 1
    dbUrl = Protect-Secret -Value $dbUrl
    s3AccessKeyId = if ($storageEnabled) { Protect-Secret -Value $s3AccessKey } else { $null }
    s3SecretAccessKey = if ($storageEnabled) { Protect-Secret -Value $s3SecretKey } else { $null }
}

$config | ConvertTo-Json -Depth 8 | Set-Content -Path $ConfigPath -Encoding UTF8
$secrets | ConvertTo-Json -Depth 4 | Set-Content -Path $SecretPath -Encoding UTF8

# Defense in depth. DPAPI already binds ciphertext to this Windows user.
try {
    & icacls.exe $ConfigRoot /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F" | Out-Null
} catch {
    Write-Warning "Could not tighten ACL automatically: $($_.Exception.Message)"
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

Write-Host ''
Write-Host '[PASS] Backup configuration saved.'
Write-Host "Config:  $ConfigPath"
Write-Host "Secrets: $SecretPath (DPAPI encrypted)"
Write-Host "Output:  $outputDir"
Write-Host "Retention: $retentionDays days"
Write-Host "Storage S3 backup: $storageEnabled"
Write-Host ''
Write-Host 'Next: npm run t15:backup'
