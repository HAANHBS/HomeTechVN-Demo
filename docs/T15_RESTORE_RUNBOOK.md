# HomeTechVN — T15 RESTORE RUNBOOK

## Safety rule

Never test a restore by overwriting the active production project.

Restore first to:

- a new Supabase project, or
- a disposable local/self-hosted test target.

Only perform a production cutover after validation.

## Backup components

Required:

```text
database/roles.sql
database/schema.sql
database/data.sql
database/history_schema.sql
database/history_data.sql
database/storage_metadata.sql
source.zip
checksums.sha256
manifest.json
```

If `manifest.storage.metadataObjectCount > 0`, Storage object files are also
required and `manifest.storage.status` must be `S3_BACKUP_VERIFIED`.

## Step 1 — Validate backup

Before restore:

1. `manifest.status` must be `FULL`.
2. `secretsIncluded` must be `false`.
3. Recompute every SHA-256 from `checksums.sha256`.
4. Verify all required files are non-empty.
5. If Storage objects existed, verify local Storage count/bytes.

Do not restore from a backup whose checksum validation fails.

## Step 2 — Create a NEW Supabase target

Create a separate project.

Record:

- target project ref
- target region
- target PostgreSQL version
- target database URL
- target Auth settings
- target Storage configuration
- target Cloudflare/frontend URL

Do not reuse the production project for the drill.

## Step 3 — Restore roles/schema/data

Use the current official Supabase backup/restore procedure.

Conceptually:

```text
roles.sql
schema.sql
SET session_replication_role = replica
data.sql
```

Use `ON_ERROR_STOP=1` / single transaction as supported by the target procedure.

## Step 4 — Restore migration history

Restore:

```text
history_schema.sql
history_data.sql
```

This preserves the Supabase CLI migration ledger.

## Step 5 — Restore Storage objects

Database restore alone restores only Storage metadata.

When `metadataObjectCount > 0`, copy the actual object bytes through the
Supabase S3 protocol/rclone workflow.

Do not manually place files into internal Storage directories.

## Step 6 — Re-create platform configuration

Several values are intentionally not restored from source backup:

- API keys
- JWT secrets
- database password
- OAuth provider secrets
- SMTP credentials
- Cloudflare Worker secrets
- Telegram token
- Email provider key
- Zalo token
- custom domain/DNS credentials

Re-create these from the operational configuration register and secret manager.

Never copy old plaintext secrets into source control.

## Step 7 — Validate target

Minimum checks:

- Auth user count
- roles / permissions
- customers
- products / inventory
- sales / payments
- repairs
- warranty / claims
- services / licenses
- reminders / notifications
- Dashboard
- Reports
- public Warranty QR
- PWA installation/build
- Worker notification delivery configuration

Use the stage verifiers against the restored target where appropriate.

## Step 8 — Cutover

Only after the restored target is validated:

1. stop writes to the old production system;
2. take a final backup;
3. restore/apply the final delta if required;
4. update frontend/backend project configuration;
5. deploy;
6. verify;
7. re-enable users.

Keep the old project read-only until the new environment has passed acceptance.
