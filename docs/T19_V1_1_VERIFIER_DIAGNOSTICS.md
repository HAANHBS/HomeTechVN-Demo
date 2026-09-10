# T19 v1.1 verifier diagnostics

T19 v1.1 does not change migration `#37`, the QR data model, permissions, or the application UI.

It fixes a verifier defect found on Windows: `t19-runtime-verify.mjs` previously ran inherited commands with `stdio: inherit`. If `t17-demo-load.mjs` failed, the final T19 error only repeated the command name and exit code, hiding the causal child output from the failure block.

The verifier now:

- captures stdout and stderr for every child process with a 64 MiB buffer;
- streams captured output to the terminal for normal progress visibility;
- includes the last 160 child-output lines in the thrown command error;
- writes `docs/snapshots/T19_FAILURE_YYYYMMDD_HHMMSS.txt` on failure;
- redacts JWTs, Supabase publishable/secret keys, and the local demo password from that snapshot;
- self-tests failed-child capture and diagnostic redaction before touching local Supabase;
- still performs the final local database reset and clean-baseline assertion after a primary failure.

The successfully applied migration and `T19 CLEAN BASELINE AFTER VERIFY: PASS` from the reported run show that the database migration and cleanup path worked. The exact T17 loader cause must be taken from the expanded child output or failure snapshot; it is not inferred from the generic exit code.
