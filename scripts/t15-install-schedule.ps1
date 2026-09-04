[CmdletBinding()]
param(
    [string]$Time = '02:15',
    [string]$TaskName = 'HomeTechVN-T15-Daily-Backup'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ConfigPath = Join-Path $env:LOCALAPPDATA 'HomeTechVN\Backup\config.json'
$SecretPath = Join-Path $env:LOCALAPPDATA 'HomeTechVN\Backup\secrets.json'

if (-not (Test-Path $ConfigPath) -or -not (Test-Path $SecretPath)) {
    throw 'Backup configuration is missing. Run npm run t15:configure first.'
}

if ($Time -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$') {
    throw 'Time must be HH:mm in 24-hour format.'
}

$powerShell = (Get-Command powershell.exe).Source
$backupScript = Join-Path $ProjectRoot 'scripts\t15-backup.ps1'
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$backupScript`""

$action = New-ScheduledTaskAction -Execute $powerShell -Argument $arguments -WorkingDirectory $ProjectRoot
$trigger = New-ScheduledTaskTrigger -Daily -At $Time
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

# Interactive logon avoids storing a Windows account password in the task definition.
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description 'HomeTechVN T15 daily logical database/source/storage backup' `
    -Force | Out-Null

Write-Host '[PASS] Windows Scheduled Task installed.'
Write-Host "Task: $TaskName"
Write-Host "Daily time: $Time"
Write-Host 'Logon mode: Interactive (no Windows password stored in task).'
Write-Host ''
Write-Host "Test manually: Start-ScheduledTask -TaskName '$TaskName'"
