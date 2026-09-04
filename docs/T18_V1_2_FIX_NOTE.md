# HomeTechVN T18 v1.2 — Missing production config workflow

## Reported failure

```text
[T18 FAIL]
Missing app/.env.local. Configure the hosted HTTPS Supabase URL and
browser-safe publishable key before T18 verification.
```

## Root cause

T18 v1.1 correctly prohibited runtime config from the release ZIP, but it
incorrectly assumed every accepted T17 working copy already retained
`app/.env.local`. T17 clean-baseline behavior may legitimately restore the
file's original absent state, leaving no supported command to satisfy T18.

## Fix

T18 v1.2 adds:

```powershell
npm run t18:configure
```

The command prompts for the hosted Supabase Project URL and browser-safe
Publishable key, rejects local URLs, placeholders, `sb_secret_`, service-role
material, and invalid legacy keys, then writes `app/.env.local`. The file stays
ignored and is still excluded and independently rejected by release-package
inspection.

The production validator is now import-safe so the configure helper and the
verifier share one validation implementation. A configure self-test runs before
the Windows verifier.
