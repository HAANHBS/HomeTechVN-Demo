$ErrorActionPreference = "Stop"
Write-Host "HomeTechVN T1 - Local reset"
npx supabase db reset
Write-Host "PASS: migration + seed completed."
Write-Host "Next: run supabase/tests/t1_verify.sql in Studio SQL Editor."
