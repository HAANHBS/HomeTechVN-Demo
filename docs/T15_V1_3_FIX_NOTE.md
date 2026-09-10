# HomeTechVN — T15 v1.3 FIX NOTE

Date: 31/08/2026

## Windows v1.2 finding

The full local restore drill successfully:

- found `supabase_admin` as SUPERUSER;
- removed any old scratch database;
- created a new scratch database from `template0`.

It then failed at marker insertion because Windows PowerShell → `docker.exe` →
`psql -c` stripped the embedded JSON double quotes.

The intended value:

```json
{"stage":"T15","restore":"required"}
```

reached PostgreSQL as invalid JSON resembling:

```text
{stage:T15,restore:required}
```

## v1.3 correction

No JSON literal is sent through the command line.

The SQL now constructs JSON natively:

```sql
jsonb_build_object('stage','T15','restore','required')
```

The source checker rejects future regressions if either `$markerJson` or the
literal marker JSON is reintroduced into the restore script.

## Database / credentials

No database change.
No credential change.
Do not rerun `t15:configure`.

```text
T1 → T13 = 33 locked migrations unchanged
T14 DB migrations = 0
T15 DB migrations = 0
```
