# HomeTechVN — T15 v1.2 FIX NOTE

Date: 31/08/2026

## Windows v1.1 failure

The production backup reached the local restore drill. The drill then failed on
`pg_terminate_backend()` because local Supabase had a SUPERUSER-owned
connection that the script's `postgres` role could not terminate.

## Root cause

The previous drill cloned the active `postgres` database as a template. That
unnecessarily required the source database to have zero connections.

## v1.2 redesign

- removes all `pg_terminate_backend` usage;
- never clones the active `postgres` database;
- detects an accessible local SUPERUSER (`supabase_admin` preferred);
- creates an independent scratch DB from `template0`;
- performs a FULL custom `pg_dump` of the local database;
- validates with `pg_restore --list`;
- performs a FULL `pg_restore` into scratch;
- verifies a restore-only marker and critical row-count signature including
  Auth, public/private business data and Storage metadata;
- cleans up with `DROP DATABASE ... WITH (FORCE)`;
- cleanup suppresses native NOTICE/error output so it cannot mask the real
  verifier result.

The earlier circular-FK warning was from the production data-only dump. The
full local restore drill restores constraints in post-data, so it does not need
the old trigger-disabling workaround.

Existing DPAPI backup credentials remain valid and are reused.
