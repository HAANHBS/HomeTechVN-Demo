# T9 Build / Test

## Remote — PASS
- schema and workflow preflight
- exactly 12 seeded system rules
- 12 deterministic reminder candidates
- 9 DUE / 3 PENDING at deterministic test clock
- dedupe / idempotent generator rerun
- Sales acknowledgement and snooze
- Sales generator/rule management denied
- Manager disable/re-enable rule reconciliation
- automatic resolution after source condition clears
- service-role server execution path
- transaction rollback cleanup

## Security — PASS
- RLS enabled
- authenticated browser gets SELECT only
- mutations are RPC-only
- no anon table access
- no public SECURITY DEFINER wrapper added
- generator protected by notification.manage or service_role
- advisory transaction lock prevents simultaneous generator execution

## Static frontend — PASS
- 20 TS/TSX files parse cleanly
- local routing/component structural check found no T9-specific type mismatch
- Reminder UI contains no direct reminder table mutation
- frontend secret scan PASS

## Pending
The artifact environment could not download npm packages from registry.
Real production build: PASS — T9 Windows acceptance completed.
