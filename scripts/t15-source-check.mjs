import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(process.cwd())

function fail(message) {
  console.error(`[T15 SOURCE FAIL] ${message}`)
  process.exitCode = 1
}
function read(rel) {
  return fs.readFileSync(path.join(root, rel), 'utf8')
}

const pkg = JSON.parse(read('package.json'))
const gitignore = read('.gitignore')
const configure = read('scripts/t15-configure-backup.ps1')
const backup = read('scripts/t15-backup.ps1')
const restore = read('scripts/t15-restore-drill.ps1')
const schedule = read('scripts/t15-install-schedule.ps1')

if (pkg.version !== '0.15.0-t15.3') fail(`Unexpected root version: ${pkg.version}`)

for (const script of ['t15:configure','t15:backup','t15:schedule','t15:verify']) {
  if (!pkg.scripts?.[script]) fail(`Missing npm script ${script}`)
}

for (const token of [
  'ConvertFrom-SecureString',
  'DPAPI encrypted',
  "LOCALAPPDATA 'HomeTechVN\\Backup'",
  'Retention days',
  'Storage S3 backup',
]) {
  if (!configure.includes(token)) fail(`Configure script missing token: ${token}`)
}

if (backup.includes('[IO.Path]::GetRelativePath') || backup.includes('[System.IO.Path]::GetRelativePath')) {
  fail('Windows PowerShell 5.1 compatibility regression: Path.GetRelativePath is forbidden in t15-backup.ps1.')
}

for (const token of [
  "'roles.sql'",
  "'schema.sql'",
  "'data.sql'",
  "'history_schema.sql'",
  "'history_data.sql'",
  "'storage_metadata.sql'",
  'checksums.sha256',
  'manifest.json',
  'source.zip',
  'secretsIncluded = $false',
  'OBJECTS_PRESENT_S3_BACKUP_NOT_CONFIGURED',
  'S3_BACKUP_VERIFIED',
  'Get-CopyRowCount',
  'New-SourceArchive',
]) {
  if (!backup.includes(token)) fail(`Backup script missing required contract: ${token}`)
}

for (const forbidden of [
  'postgresql://postgres.puqvbenyenwemfbsqpfd:',
  'SUPABASE_SERVICE_ROLE_KEY=',
  'ZALO_ACCESS_TOKEN=',
  'TELEGRAM_BOT_TOKEN=',
]) {
  if (backup.includes(forbidden) || configure.includes(forbidden)) {
    fail(`Backup scripts contain forbidden plaintext-secret pattern: ${forbidden}`)
  }
}

for (const token of [
  '--format=custom',
  'pg_restore',
  'restore-drill.json',
  'T15 APP DATA RESTORE DRILL: PASS',
]) {
  if (!restore.includes(token)) fail(`Restore drill missing token: ${token}`)
}

for (const token of [
  'Resolve-LocalSuperuser',
  "'supabase_admin','postgres'",
  'create database $restoreDb template template0',
  'pg_dump FULL local database',
  'pg_restore FULL archive',
  'drop database if exists $restoreDb with (force)',
  'T15 FULL LOCAL RESTORE DRILL: PASS',
  'sourceConnectionTerminationUsed = $false',
]) {
  if (!restore.includes(token)) fail(`T15 v1.2 restore drill missing token: ${token}`)
}

if (restore.includes('pg_terminate_backend')) fail('T15 v1.2 restore drill must not call pg_terminate_backend.')
if (restore.includes('template postgres')) fail('T15 v1.2 restore drill must not clone the active postgres database.')
if (restore.includes('$markerJson') || restore.includes('{"stage":"T15"')) {
  fail('T15 restore marker must not pass a JSON literal through Windows docker/psql -c.')
}
if (!restore.includes("jsonb_build_object('stage','T15','restore','required')")) {
  fail('T15 restore marker must use PostgreSQL jsonb_build_object.')
}

if (!schedule.includes('New-ScheduledTaskTrigger -Daily')) fail('Daily schedule trigger missing.')
if (!schedule.includes('-LogonType Interactive')) fail('Schedule must avoid storing Windows account password.')

for (const token of ['.backup/','backup-output/','*.backup.zip']) {
  if (!gitignore.includes(token)) fail(`.gitignore missing T15 exclusion: ${token}`)
}

const migrationDir = path.join(root, 'supabase', 'migrations')
const migrations = fs.readdirSync(migrationDir).filter((x) => x.endsWith('.sql')).sort()
if (migrations.length !== 33) fail(`T15 must preserve exactly 33 migrations, found ${migrations.length}.`)
if (migrations.some((x) => x.includes('_t15_'))) fail('T15 must not add a database migration.')

if (!process.exitCode) {
  console.log('T15 DPAPI secret-storage contract: PASS')
  console.log('T15 DB/source/storage backup contract: PASS')
  console.log('T15 restore-drill source contract: PASS')
  console.log('T15 retention/schedule contract: PASS')
  console.log('T15 migration baseline unchanged: PASS (33/33)')
  console.log('T15 BACKUP SOURCE CHECK: PASS')
}
