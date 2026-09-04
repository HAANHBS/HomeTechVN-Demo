[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Container
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-DockerSql {
    param(
        [Parameter(Mandatory=$true)][string]$Sql,
        [string]$Database = 'postgres'
    )
    $output = @(
        & docker.exe exec $Container psql -U postgres -d $Database -At -v ON_ERROR_STOP=1 -c $Sql 2>&1
    )
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        throw "docker psql failed ($code): $($output -join [Environment]::NewLine)"
    }
    return $output
}

function Start-SqlJob {
    param(
        [Parameter(Mandatory=$true)][string]$DockerPath,
        [Parameter(Mandatory=$true)][string]$ContainerName,
        [Parameter(Mandatory=$true)][string]$Sql
    )
    Start-Job -ScriptBlock {
        param($Docker,$Container,$SqlText)
        $out = @(& $Docker exec $Container psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c $SqlText 2>&1)
        [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = ($out -join [Environment]::NewLine)
        }
    } -ArgumentList $DockerPath,$ContainerName,$Sql
}

$docker = (Get-Command docker.exe -ErrorAction Stop).Source
$stamp = Get-Date -Format 'yyyyMMddHHmmss'

Write-Host '=== T16 Multi-Session Concurrency Check ==='

# ------------------------------------------------------------------
# 1. Sequence race: simultaneous SECURITY DEFINER counter calls.
# ------------------------------------------------------------------
$entity = "T16_RACE_$stamp"
$jobs = @()
for ($i=1; $i -le 16; $i++) {
    $sql = "select private.next_simple_code('$entity','RACE',6);"
    $jobs += Start-SqlJob -DockerPath $docker -ContainerName $Container -Sql $sql
}

$jobs | Wait-Job | Out-Null
$results = @($jobs | Receive-Job)
$jobs | Remove-Job -Force

$failures = @($results | Where-Object { $_.ExitCode -ne 0 })
if ($failures.Count -gt 0) {
    throw "Sequence concurrency session failed:`n$($failures.Output -join [Environment]::NewLine)"
}

$codes = @(
    $results |
    ForEach-Object { $_.Output.Trim() } |
    Where-Object { $_ -match '^RACE-\d{6}$' }
)

if ($codes.Count -ne 16) {
    throw "Expected 16 sequence codes, got $($codes.Count): $($codes -join ', ')"
}
if (@($codes | Sort-Object -Unique).Count -ne 16) {
    throw "Duplicate sequence code detected: $($codes -join ', ')"
}

$expectedCodes = 1..16 | ForEach-Object { 'RACE-{0:D6}' -f $_ }
if (Compare-Object ($codes | Sort-Object) ($expectedCodes | Sort-Object)) {
    throw "Sequence race produced a gap/unexpected range: $($codes -join ', ')"
}

Write-Host '[PASS] 16 simultaneous sequence calls are unique and gap-free.'

# ------------------------------------------------------------------
# 2. Inventory race: stock=1, two sessions issue quantity=1.
#    Exactly one must succeed; the other must fail after the row lock.
# ------------------------------------------------------------------
$userId = 'd1600000-0000-4000-8000-00000000c001'
$productId = 'd1610000-0000-4000-8000-00000000c001'
$sku = "T16-RACE-$stamp"

$setupSql = @"
insert into auth.users(id,email,raw_user_meta_data)
values('$userId','t16-concurrency@example.invalid','{}'::jsonb)
on conflict (id) do nothing;

update public.profiles
set role_id=(select id from public.roles where code='admin'),
    is_active=true,
    full_name='T16 Concurrency Admin'
where id='$userId';

insert into public.products(id,sku,name,unit,sale_price,min_stock,track_serial,is_active)
values('$productId','$sku','T16 Concurrency Product','cai',100,0,false,true);

insert into public.inventory_transactions(
  product_id,transaction_type,quantity,reference_type,note,occurred_at
) values(
  '$productId','RECEIVE',1,'T16_CONCURRENCY','stock=1',now()
);
"@
Invoke-DockerSql -Sql $setupSql | Out-Null

$issueSql = @"
set role authenticated;
select set_config('request.jwt.claim.sub','$userId',true);
select public.inventory_issue(
  '$productId'::uuid,
  1,
  null::uuid[],
  'T16 concurrency issue',
  'T16_CONCURRENCY',
  null::uuid
);
"@

$issueJobs = @(
    Start-SqlJob -DockerPath $docker -ContainerName $Container -Sql $issueSql
    Start-SqlJob -DockerPath $docker -ContainerName $Container -Sql $issueSql
)
$issueJobs | Wait-Job | Out-Null
$issueResults = @($issueJobs | Receive-Job)
$issueJobs | Remove-Job -Force

$success = @($issueResults | Where-Object { $_.ExitCode -eq 0 })
$failed = @($issueResults | Where-Object { $_.ExitCode -ne 0 })

if ($success.Count -ne 1 -or $failed.Count -ne 1) {
    throw "Inventory race expected 1 success + 1 failure. Success=$($success.Count), failed=$($failed.Count).`n$($issueResults.Output -join [Environment]::NewLine)"
}
if (($failed[0].Output -notmatch 'Insufficient stock') -and ($failed[0].Output -notmatch 'available')) {
    throw "Inventory race loser did not fail for insufficient stock:`n$($failed[0].Output)"
}

$issueCountSql = "select count(*) from public.inventory_transactions where product_id='$productId' and transaction_type='ISSUE';"
$issueCountLines = @(Invoke-DockerSql -Sql $issueCountSql)

if ($issueCountLines.Count -lt 1) {
    throw 'Inventory race count query returned no output.'
}

$issueCount = ([string]$issueCountLines[$issueCountLines.Count - 1]).Trim()

if ($issueCount -ne '1') {
    throw "Inventory race persisted $issueCount ISSUE rows instead of exactly 1."
}

Write-Host '[PASS] Concurrent stock=1 issue: exactly one transaction succeeded.'
Write-Host 'T16 CONCURRENCY CHECK: PASS'
