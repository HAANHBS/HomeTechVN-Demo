# HomeTechVN T1 — Local Port Fix v1.9

Observed Windows runtime error:

`ports are not available ... 0.0.0.0:54324 ... bind: Only one usage of each socket address ...`

Supabase local uses `[inbucket].port = 54324` by default for its email testing web UI.

v1.9 behavior:

1. `supabase stop --no-backup`
2. test whether current `[inbucket].port` can actually bind
3. if free: keep it
4. if occupied:
   - report owning PID/process when Windows exposes it
   - find a free port starting at 54330
   - backup `supabase/config.toml`
   - update only `[inbucket].port`
   - verify the new TOML value
   - test that the selected port is still bindable
5. `supabase start`
6. `supabase db reset --local`
7. automatic SQL verification

The script does not terminate the process occupying 54324 and does not touch remote Supabase.

Run:

```powershell
cd D:\HOMETECHVN
npm run t1:repair
```
