# HomeTechVN - T17 v1.5 FULL REVIEW

This version replaces incremental loader patching with a whole-stage reliability pass.

## Root causes found across v1.0-v1.4

1. Assumed legacy `status -o env` key names.
2. Assumed `status -o env` contained API/key fields at all.
3. Double-escaped .NET regex in PowerShell.
4. Fixed guessed Docker component name.
5. UTF-8-without-BOM PowerShell source containing non-ASCII text/box drawing characters.
6. Stale `$local.AnonKey` remained in the Dashboard RPC path after the loader moved to `PublishableKey`.
7. `npm run t17:verify` entered PowerShell before any independent syntax/encoding gate existed.

## v1.5 controls

- `t17-demo-load.ps1` rewritten around small testable discovery helpers.
- JSON status -> env status -> ASCII-sanitized pretty status -> config.toml -> actual running Docker containers.
- No fixed Kong/Auth/REST container names.
- No service-role/secret key dependency.
- Discovery parser self-test runs before destructive local reset.
- All project `.ps1` files are normalized to ASCII source and UTF-8 BOM for Windows PowerShell 5.1.
- New Node-based global PowerShell lexical/encoding checker runs before any T17 PowerShell verifier.
- `npm run t17:verify` now starts in Node, not PowerShell.
- Stale `AnonKey` property removed; all local HTTP calls use `PublishableKey` consistently.
- Real connected Supabase rollback integration tests passed before packaging.
- Migration chain remains exactly 36/36; T17 adds zero DB migration.


## v1.5 Node resolver boundary

Local API/key discovery moved out of Windows PowerShell into `scripts/t17-resolve-local-config.mjs`. Both `t17:verify` and `t17:demo-load` start with Node-based PowerShell static validation and resolver self-tests before PowerShell is invoked.
