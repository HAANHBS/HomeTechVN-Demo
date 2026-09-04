# HomeTechVN — T4 BUILD / TEST

## Remote database tests

PASS:
- T4 DDL preflight in transaction rollback
- 3 Sales tables with RLS
- 12 public Sales RPCs
- security-invoker Sales summary view
- Sales role lifecycle
- Cashier payment lifecycle
- partial/full state rules
- refund path
- cancel + stock reversal
- serialized stock reversal
- cost snapshot privacy
- 16-item checklist and completion gate
- system-managed payment checklist item

## Source checks before ZIP

Required:
- TS/TSX syntax parse
- TypeScript structural check
- no frontend backend secret
- no direct Sales/Payment mutation
- no direct inventory-ledger mutation from Sales UI
- exact migration chain
- PowerShell structural check
- ZIP reopen/integrity check

## Windows acceptance

Production build is authoritative on the user's Windows environment:

```powershell
npm run t4:verify
```

Expected:

```text
T4 LOCAL REPRODUCIBILITY: PASS
T4 FINAL CORE CHECKS: PASS
T4 APP BUILD: PASS
```
