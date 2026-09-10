# HomeTechVN — T17 v1.4 FIX NOTE

Date: 01/09/2026

The v1.3 Windows run failed because the fallback guessed `supabase_kong_HOMETECHVN`, which does not exist in the current local stack.

v1.4 discovery order:

1. `supabase status -o json`
2. `supabase status -o env`
3. ordinary `supabase status`
4. section-aware `supabase/config.toml` scan for local API port
5. `docker ps --format '{{.Names}}'`, then inspect only actual running Supabase containers

No fixed container names are guessed. Docker inspect failures are non-fatal fallback misses. No service-role/secret key is required, raw key values are never printed, and non-local API URLs remain blocked.

Database impact: none. Migration chain remains 36/36; T17 adds 0 migration.
