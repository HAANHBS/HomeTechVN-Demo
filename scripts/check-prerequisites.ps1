param(
    [switch]$NoSnapshot
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version 3.0

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$Snapshot = $null

if (-not $NoSnapshot) {
    $SnapshotDir = Join-Path $ProjectRoot 'docs\snapshots'
    New-Item -ItemType Directory -Force -Path $SnapshotDir | Out-Null
    $Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $Snapshot = Join-Path $SnapshotDir "T1_ENV_$Stamp.txt"
}

function Write-Log {
    param(
        [AllowEmptyString()]
        [string]$Text = ''
    )

    Write-Host $Text
    if ($script:Snapshot) {
        Add-Content -LiteralPath $script:Snapshot -Value $Text -Encoding UTF8
    }
}

function Write-CommandOutput {
    param([object[]]$Output)

    foreach ($item in @($Output)) {
        if ($null -ne $item) {
            Write-Log ([string]$item)
        }
    }
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string[]]$CommandArgs = @()
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) {
        Write-Log "[MISSING] $Name"
        return $false
    }

    Write-Log "[FOUND] $Name -> $($command.Source)"

    try {
        $global:LASTEXITCODE = 0
        $output = & $Name @CommandArgs 2>&1
        $exitCode = $LASTEXITCODE
        Write-CommandOutput -Output $output

        if ($exitCode -ne 0) {
            Write-Log "[WARN] $Name returned exit code $exitCode"
            return $false
        }

        return $true
    }
    catch {
        Write-Log "[WARN] Could not run $Name $($CommandArgs -join ' '): $($_.Exception.Message)"
        return $false
    }
}

function Get-SupabaseProjectDependency {
    $localSupabaseCmd = Join-Path $script:ProjectRoot 'node_modules\.bin\supabase.cmd'
    $localSupabasePs1 = Join-Path $script:ProjectRoot 'node_modules\.bin\supabase.ps1'

    if (Test-Path -LiteralPath $localSupabaseCmd) {
        return $localSupabaseCmd
    }

    if (Test-Path -LiteralPath $localSupabasePs1) {
        return $localSupabasePs1
    }

    return $null
}

Write-Log '=== HomeTechVN T1 Prerequisite Check ==='
Write-Log "Checked at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
Write-Log "Project root: $ProjectRoot"
Write-Log ''

Write-Log 'Machine:'
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    Write-Log " Computer name: $env:COMPUTERNAME"
    Write-Log " Windows: $($os.Caption)"
    Write-Log " Version: $($os.Version)"
    Write-Log " Build: $($os.BuildNumber)"
    Write-Log " Architecture: $($os.OSArchitecture)"
    Write-Log " RAM GB: $([math]::Round($cs.TotalPhysicalMemory / 1GB, 2))"
}
catch {
    Write-Log "[WARN] Could not read machine info: $($_.Exception.Message)"
}

Write-Log ''
Write-Log 'Disk:'
try {
    $disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop
    foreach ($disk in $disks) {
        $free = [math]::Round($disk.FreeSpace / 1GB, 2)
        $size = [math]::Round($disk.Size / 1GB, 2)
        Write-Log " $($disk.DeviceID) Free $free GB / $size GB"
    }
}
catch {
    Write-Log "[WARN] Could not read disk information: $($_.Exception.Message)"
}

Write-Log ''
Write-Log 'Tools:'
$gitOk = Invoke-CheckedCommand -Name 'git' -CommandArgs @('--version')
$nodeOk = Invoke-CheckedCommand -Name 'node' -CommandArgs @('--version')
$npmOk = Invoke-CheckedCommand -Name 'npm' -CommandArgs @('--version')
$npxOk = Invoke-CheckedCommand -Name 'npx' -CommandArgs @('--version')
$dockerCliOk = Invoke-CheckedCommand -Name 'docker' -CommandArgs @('--version')

Write-Log ''
Write-Log 'Supabase project dependency:'
$localSupabase = Get-SupabaseProjectDependency
if ($localSupabase) {
    Write-Log "[FOUND] Local Supabase CLI -> $localSupabase"
    try {
        $global:LASTEXITCODE = 0
        $output = & $localSupabase --version 2>&1
        $localSupabaseExit = $LASTEXITCODE
        Write-CommandOutput -Output $output
        if ($localSupabaseExit -eq 0) {
            $supabaseDependencyOk = $true
            Write-Log '[PASS] Supabase CLI is installed in this project.'
        }
        else {
            $supabaseDependencyOk = $false
            Write-Log "[FAIL] Local Supabase CLI returned exit code $localSupabaseExit."
        }
    }
    catch {
        $supabaseDependencyOk = $false
        Write-Log "[FAIL] Could not run local Supabase CLI: $($_.Exception.Message)"
    }
}
else {
    $supabaseDependencyOk = $false
    Write-Log '[PENDING] Supabase CLI is not installed in this project.'
    Write-Log '          Run: npm install'
}

Write-Log ''
Write-Log 'npm dependency check:'
if ($npmOk) {
    try {
        Push-Location $ProjectRoot
        $global:LASTEXITCODE = 0
        $dependencyOutput = & npm ls supabase --depth=0 2>&1
        $dependencyExit = $LASTEXITCODE
        Write-CommandOutput -Output $dependencyOutput

        $dependencyText = ($dependencyOutput | ForEach-Object { [string]$_ }) -join "`n"
        if (($dependencyExit -eq 0) -and ($dependencyText -match 'supabase@')) {
            Write-Log '[PASS] npm confirms Supabase as a project dependency.'
        }
        else {
            Write-Log '[PENDING] npm does not currently show Supabase as an installed project dependency.'
            Write-Log '          Run: npm install'
        }
    }
    catch {
        Write-Log "[WARN] Could not verify npm dependency: $($_.Exception.Message)"
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Log '[SKIP] npm dependency check because npm is unavailable.'
}

Write-Log ''
Write-Log 'Docker engine:'
$dockerEngineOk = $false
if ($dockerCliOk) {
    try {
        $global:LASTEXITCODE = 0
        $dockerOutput = & docker version 2>&1
        $dockerExit = $LASTEXITCODE
        Write-CommandOutput -Output $dockerOutput
        if ($dockerExit -eq 0) {
            $dockerEngineOk = $true
            Write-Log '[PASS] Docker client and server are responding.'
        }
        else {
            Write-Log "[FAIL] docker version returned exit code $dockerExit."
        }
    }
    catch {
        Write-Log "[FAIL] Docker engine check failed: $($_.Exception.Message)"
    }
}
else {
    Write-Log '[SKIP] Docker engine check because docker CLI is unavailable.'
}

Write-Log ''
Write-Log 'Summary:'
Write-Log " Git:               $(if ($gitOk) { 'PASS' } else { 'FAIL' })"
Write-Log " Node.js:           $(if ($nodeOk) { 'PASS' } else { 'FAIL' })"
Write-Log " npm:               $(if ($npmOk) { 'PASS' } else { 'FAIL' })"
Write-Log " npx:               $(if ($npxOk) { 'PASS' } else { 'FAIL' })"
Write-Log " Docker CLI:        $(if ($dockerCliOk) { 'PASS' } else { 'FAIL' })"
Write-Log " Docker Engine:     $(if ($dockerEngineOk) { 'PASS' } else { 'FAIL' })"
Write-Log " Supabase project:  $(if ($supabaseDependencyOk) { 'PASS' } else { 'PENDING' })"
Write-Log ''
Write-Log '=== End ==='

if ($Snapshot) {
    Write-Log "Snapshot saved: $Snapshot"
}

# Exit non-zero only when a required base tool/engine is broken.
# Supabase project dependency remains PENDING until `npm install` is run.
if (-not ($gitOk -and $nodeOk -and $npmOk -and $npxOk -and $dockerCliOk -and $dockerEngineOk)) {
    exit 1
}

exit 0
