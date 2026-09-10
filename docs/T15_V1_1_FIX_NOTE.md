# HomeTechVN — T15 v1.1 FIX NOTE

Date: 31/08/2026

## Windows evidence from v1.0

The real remote dump successfully created:

- `roles.sql`
- `schema.sql`
- `data.sql`
- `history_schema.sql`
- `history_data.sql`
- `storage_metadata.sql`

The backup then failed only during local source/checksum packaging:

```text
Method invocation failed because [System.IO.Path] does not contain a method
named 'GetRelativePath'.
```

Therefore the Session Pooler credentials are valid and do not need to be
reconfigured.

## v1.1 fix

- removes the final executable `.NET Path.GetRelativePath` call;
- both source archive and checksum path calculation use
  `Get-RelativePathCompat`, compatible with Windows PowerShell 5.1;
- source checker explicitly rejects future `Path.GetRelativePath` use;
- restore drill now uses `pg_restore --disable-triggers` on the disposable
  local scratch database to handle the circular FK warning already observed for
  `repair_orders` / `repair_quotes`.

## Database impact

None.

```text
T1 → T13 = 33 locked migrations unchanged
T14 DB migrations = 0
T15 DB migrations = 0
```

## Credential impact

None.

Existing DPAPI configuration remains under:

```text
%LOCALAPPDATA%\HomeTechVN\Backup
```

and is reused automatically by `npm run t15:verify`.
