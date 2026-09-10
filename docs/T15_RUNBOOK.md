# T15 Runbook

## First acceptance run

Overlay T15 candidate into:

```text
D:\HOMETECHVN
```

Then:

```powershell
cd D:\HOMETECHVN
npm run t15:verify
```

If T15 has not been configured, verifier starts secure configuration.

You need the Supabase Dashboard:

```text
Connect → Session pooler
```

Copy the URL **with `[YOUR-PASSWORD]` still present**.

The script separately asks for the database password as a hidden SecureString.

Current project Storage has zero objects, so answer **No** to S3 Storage backup
for this first T15 acceptance unless you intentionally configure S3 now.

## After acceptance — daily schedule

Install the default 02:15 daily backup:

```powershell
npm run t15:schedule
```

Or choose another time:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\t15-install-schedule.ps1 `
  -Time 23:30
```

## Manual backup

```powershell
npm run t15:backup
```

A successful run prints:

```text
T15 PRODUCTION BACKUP: PASS
Status: FULL
Secrets included: NO
```

## Backup destination

The first configuration asks for the output directory.

Recommended:

```text
D:\HOMETECHVN_BACKUPS
```

Prefer an independent physical disk/NAS/synchronized off-site target, not only
the same system drive as the application.

## When Storage becomes non-empty

Re-run:

```powershell
npm run t15:configure
```

Enable Storage S3 backup and enter newly generated S3 credentials.

Install `rclone` on the backup PC.

The production script will not accept FULL status if database Storage metadata
contains objects but S3 backup is disabled.
