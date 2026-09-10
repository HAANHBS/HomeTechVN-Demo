# HomeTechVN — T17 v1.2 FIX NOTE

Windows v1.1 showed `supabase status -o env` returned only `DB_URL`.

v1.2 removes dependency on one CLI output shape.

API URL: CLI env -> `supabase/config.toml` `[api].port` -> local default 54321.

Public API key: CLI env publishable/anon aliases -> ordinary `supabase status` -> local Docker container environment (`supabase_kong_*`, `supabase_auth_*`, `supabase_rest_*`) reading only public publishable/anon variables.

No service-role/secret key is required. Key values are never printed. Localhost-only safety remains enforced.

Database impact: none. Migration chain remains 36/36; T17 adds 0 migration.
