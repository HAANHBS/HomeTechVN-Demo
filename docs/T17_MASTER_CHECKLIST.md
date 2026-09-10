# HomeTechVN — T17 MASTER CHECKLIST

## Baseline
- [x] starts from T16 FINAL
- [x] T1–T16 migration chain remains 36/36
- [x] T17 adds zero DB migrations
- [x] old 36 migration bytes unchanged

## Local demo safety
- [x] destructive loader explicitly LOCAL only
- [x] hosted Supabase URL refused
- [x] service-role key remains process-memory only
- [x] no service-role key written to app/env/docs/snapshot
- [x] demo data contains no real customer data
- [x] demo marker says LOCAL_ONLY
- [x] `app/.env.local` remains ignored from artifacts

## Auth
- [x] login-capable users created through local Auth signup API
- [x] five roles represented
- [x] password login test implemented
- [x] JWT → self-profile RLS → roles.code test implemented
- [x] Admin JWT → Dashboard RPC test implemented
- [x] frontend has no hard-coded demo email/password defaults

## Integrated dataset
- [x] CRM customers
- [x] customer devices
- [x] product categories
- [x] serialized product
- [x] bulk inventory
- [x] low-stock product
- [x] completed sale
- [x] real payment workflow
- [x] required sales checklist
- [x] serialized inventory OUT
- [x] unpaid receivable order
- [x] SALE warranty
- [x] CLOSED warranty claim
- [x] completed repair
- [x] repair inventory part issue
- [x] REPAIR warranty
- [x] READY repair
- [x] recurring service schedule
- [x] expiring software license
- [x] external `vault://` license secret reference
- [x] reminder generation
- [x] notification preparation
- [x] IN_APP notification assertion
- [x] Dashboard assertion
- [x] Reports assertion
- [x] Security/Audit assertion
- [x] public Warranty lookup assertion
- [x] public lookup internal-field leakage assertion

## Demo UI
- [x] local-demo safety banner
- [x] login role quick-fill
- [x] env-gated demo controls
- [x] responsive Tailwind layout
- [x] no demo banner on public Warranty route

## Static regression
- [x] T15 resolved PowerShell regressions guarded
- [x] T16 resolved PowerShell regression guarded
- [x] T17 source checker
- [ ] T11 responsive source check PASS on Windows
- [ ] T12 Warranty privacy source check PASS on Windows
- [ ] T13 Reports source check PASS on Windows
- [ ] T14 PWA source/build check PASS on Windows

## Windows final gate
- [ ] dependency lock/npm ci PASS
- [ ] T1–T16 SQL regression PASS
- [ ] T15 restore regression PASS
- [ ] T16 concurrency regression PASS
- [ ] T17 DEMO LOAD PASS
- [ ] T17 DEMO INTEGRATION CHECKS PASS
- [ ] T17 DEMO AUTH LOGIN CHECK PASS
- [ ] T17 DEMO ROLE JWT CHECK PASS
- [ ] T17 DEMO RESPONSIVE UI CHECK PASS
- [ ] T17 APP BUILD PASS
- [ ] T17 WORKER CHECK PASS
- [ ] T17 LOCAL REPRODUCIBILITY PASS


### T17 v1.5 full reliability pass

See `docs/T17_V1_5_FULL_REVIEW.md` and `docs/T17_REAL_REMOTE_VALIDATION.md`. PowerShell source is globally normalized for Windows PowerShell 5.1 and `npm run t17:verify` now performs an independent Node static gate before entering PowerShell.


## v1.5 global reliability gates
- [x] v1.5 global PowerShell gate: all `.ps1` ASCII source + UTF-8 BOM
- [x] PowerShell quote/bracket/here-string lexical balance gate
- [x] literal TAB prohibited in `.ps1`
- [x] Node local-config resolver self-test
- [x] no fixed Docker component names
- [x] no stale `$local.AnonKey` path
- [x] no T15 version-bound source checker in T17 verifier
- [x] real connected Supabase Sales/Warranty rollback test PASS
- [x] real connected Supabase Repair/Service/Reminder/Notification rollback test PASS
- [x] connected Supabase Dashboard/Reports/Security snapshot PASS
- [x] connected Supabase test residue = 0
- [ ] Windows `npm run t17:verify` final acceptance


## FINAL acceptance record

- [x] T17 LOCAL REPRODUCIBILITY: PASS
- [x] T17 INHERITED REGRESSION CHECKS: PASS
- [x] T17 DEMO INTEGRATION CHECKS: PASS
- [x] T17 DEMO AUTH LOGIN CHECK: PASS
- [x] T17 DEMO ROLE JWT CHECK: PASS
- [x] T17 DEMO RESPONSIVE UI CHECK: PASS
- [x] T17 APP BUILD: PASS
- [x] T17 WORKER CHECK: PASS
- [x] T17 CLEAN BASELINE AFTER VERIFY: PASS
- [x] T17 accepted FINAL & LOCKED on 2026-09-01
