[CmdletBinding()]
param(
    [switch]$NoReset
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$node = Get-Command node.exe -ErrorAction SilentlyContinue
if ($null -eq $node) { $node = Get-Command node -ErrorAction SilentlyContinue }
if ($null -eq $node) { throw 'Node.js is required for T17 demo loader.' }
$argsList = @((Join-Path $ProjectRoot 'scripts\t17-demo-load.mjs'))
if ($NoReset) { $argsList += '--no-reset' }
& $node.Source @argsList
exit $LASTEXITCODE
