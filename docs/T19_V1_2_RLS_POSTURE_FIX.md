# T19 v1.2 — RLS posture regression fix

The Windows v1.1 failure snapshot proved that demo loading completed, but the inherited T16 security assertion rejected migration #37 because both new private QR tables had RLS enabled without any policy.

T19 v1.2 keeps direct client access closed and adds one explicit `FOR ALL TO public USING (false) WITH CHECK (false)` policy to each QR table. This satisfies the global RLS posture contract without granting any row access. Table privileges for `anon` and `authenticated` remain revoked, and browser access remains limited to the authenticated public QR functions.

Regression coverage now checks:

- both exact deny-all policies and their expressions;
- zero RLS-enabled application tables without a policy;
- no direct authenticated access to private QR tokens;
- all 36 locked migrations remain byte-for-byte unchanged.
