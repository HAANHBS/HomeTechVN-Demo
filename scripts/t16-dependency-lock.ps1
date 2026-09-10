[CmdletBinding()]
param(
    [string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $ProjectRoot 'docs\snapshots'
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

function Resolve-CommandPath {
    param([Parameter(Mandatory=$true)][string[]]$Names)
    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) { return $cmd.Source }
    }
    throw "Command not found: $($Names -join ', ')"
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$false)][string[]]$Arguments = @()
    )
    Write-Host ('> ' + $FilePath + ' ' + ($Arguments -join ' '))
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $FilePath @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    foreach ($line in $output) { Write-Host $line }
    if ($code -ne 0) {
        throw "Dependency-lock command failed ($code): $FilePath $($Arguments -join ' ')"
    }
}

$npm = Resolve-CommandPath -Names @('npm.cmd','npm')
$targets = @(
    [pscustomobject]@{ Name='root'; Prefix=$ProjectRoot; Lock=(Join-Path $ProjectRoot 'package-lock.json') },
    [pscustomobject]@{ Name='app'; Prefix=(Join-Path $ProjectRoot 'app'); Lock=(Join-Path $ProjectRoot 'app\package-lock.json') },
    [pscustomobject]@{ Name='worker'; Prefix=(Join-Path $ProjectRoot 'worker'); Lock=(Join-Path $ProjectRoot 'worker\package-lock.json') }
)

foreach ($target in $targets) {
    Write-Host ''
    Write-Host "=== Dependency lock: $($target.Name) ==="

    Invoke-Checked -FilePath $npm -Arguments @(
        '--prefix',$target.Prefix,
        'install','--package-lock-only','--ignore-scripts','--no-audit','--no-fund'
    )

    if (-not (Test-Path $target.Lock) -or (Get-Item $target.Lock).Length -lt 200) {
        throw "package-lock missing/too small: $($target.Lock)"
    }

    Invoke-Checked -FilePath $npm -Arguments @(
        '--prefix',$target.Prefix,
        'ci','--no-audit','--no-fund'
    )
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$stageDir = Join-Path $env:TEMP "HomeTechVN_T16_Locks_$stamp"
New-Item -ItemType Directory -Path (Join-Path $stageDir 'app') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stageDir 'worker') -Force | Out-Null

Copy-Item (Join-Path $ProjectRoot 'package-lock.json') (Join-Path $stageDir 'package-lock.json')
Copy-Item (Join-Path $ProjectRoot 'app\package-lock.json') (Join-Path $stageDir 'app\package-lock.json')
Copy-Item (Join-Path $ProjectRoot 'worker\package-lock.json') (Join-Path $stageDir 'worker\package-lock.json')

$manifest = [ordered]@{
    format = 'hometechvn-t16-dependency-locks-v1'
    createdAt = (Get-Date).ToString('o')
    root = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $ProjectRoot 'package-lock.json')).Hash.ToLowerInvariant()
    app = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $ProjectRoot 'app\package-lock.json')).Hash.ToLowerInvariant()
    worker = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $ProjectRoot 'worker\package-lock.json')).Hash.ToLowerInvariant()
}
$manifest | ConvertTo-Json | Set-Content -Path (Join-Path $stageDir 'manifest.json') -Encoding UTF8

$zipPath = Join-Path $OutputDir "T16_DEPENDENCY_LOCKS_$stamp.zip"
Compress-Archive -Path (Join-Path $stageDir '*') -DestinationPath $zipPath -Force
Remove-Item $stageDir -Recurse -Force

if (-not (Test-Path $zipPath) -or (Get-Item $zipPath).Length -lt 300) {
    throw 'Dependency lock bundle was not created.'
}

Write-Host ''
Write-Host 'T16 DEPENDENCY LOCK CHECK: PASS'
Write-Host "Root lock SHA256: $($manifest.root)"
Write-Host "App lock SHA256: $($manifest.app)"
Write-Host "Worker lock SHA256: $($manifest.worker)"
Write-Host "Lock bundle: $zipPath"
