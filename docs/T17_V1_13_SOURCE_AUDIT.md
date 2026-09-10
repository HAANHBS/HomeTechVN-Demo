# HomeTechVN — T17 v1.13 Source Audit

## Scope

Reviewed the complete T17 verification path:

```text
npm run t17:verify
→ t17-verify.mjs
→ T17 Node/static preflight
→ t17-verify.ps1
→ inherited T15/T16 verification
→ t17-demo-load.mjs
→ t17_demo_data.sql
→ t17_demo_assert.sql
→ real local Auth password login/JWT/RLS tests
→ UI/build/worker checks
→ final local clean-baseline reset
```

## Findings closed before v1.13

1. PowerShell UTF-8/regex parsing defects.
2. Generated `node_modules/.bin/*.ps1` false positives.
3. Duplicate `Read-SupabaseEnv` PowerShell function.
4. DB-only Supabase startup instead of Auth/API stack.
5. Storage/Studio health checks incorrectly included in T17 scope.
6. JWT subject assigned after authenticated role/RLS activation.
7. Direct authenticated call to non-executable `private.current_role_code()`.
8. Receivable fixture lacked the partial-payment transition to
   `PAYMENT_PENDING`.
9. Anonymous public-warranty assertion directly selected `public.warranties`.

## v1.13 permission-boundary audit

Connected Supabase was used to verify the contracts used by the final T17
assertions.

Expected:

```text
authenticated:
  dashboard_snapshot EXECUTE      YES
  report_snapshot EXECUTE         YES
  security_audit_snapshot EXECUTE YES
  profiles SELECT                 YES
  roles SELECT                    YES

anon:
  warranty_public_lookup EXECUTE  YES
  warranties SELECT               NO
```

The T17 assertions are aligned to these boundaries.

## Static invariants now enforced

```text
36 migrations exactly
0 T17 migrations
11 authenticated dataset phases
11 JWT subject assignments
0 private.current_role_code direct calls
anon assertion = RPC-only
public token captured before anon role
T17 SQL fixture/assertion = ASCII-only
T15/T16 known PowerShell regressions remain blocked
```

## Runtime status

Source/static verification can be completed in the artifact environment.

Final T17 acceptance still requires the Windows runtime command:

```text
npm run t17:verify
```

and is not marked FINAL until all final PASS markers are produced.
