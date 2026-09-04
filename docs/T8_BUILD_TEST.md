# T8 Build / Test

## Remote runtime — PASS
- four T8 tables created with RLS
- service catalog / recurring schedule
- monthly due-date advancement
- unique completion id per occurrence
- SERVICE-source Warranty
- multiple warranties on the same recurring schedule, one per completion
- software product catalog
- `LIC-000001` sequence
- subscription end-date derivation
- renewal date extension
- suspend / activate / cancel
- plaintext key rejection
- URI-only `secret_ref`
- Technician read-only
- Cashier denied
- direct writes revoked
- rollback cleanup

## Advisor — PASS for T8
No new T8 security warning and no missing FK index finding.
Existing DEV notices remain outside T8.

## Windows
Production build was subsequently accepted on Windows. Historical command:

```powershell
npm run t8:verify
```
