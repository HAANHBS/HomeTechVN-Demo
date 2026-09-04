# T16 Dependency Lock Evidence

Windows verifier result:

```text
T16 DEPENDENCY LOCK CHECK: PASS
Dependency lock bundle:
D:\HOMETECHVN\docs\snapshots\T16_DEPENDENCY_LOCKS_20260831_182122.zip
```

Expected bundle content from `scripts/t16-dependency-lock.ps1`:

```text
package-lock.json
app/package-lock.json
worker/package-lock.json
manifest.json
```

The accepted Windows verifier also runs `npm ci` against root/app/worker before
emitting T16 PASS.

The uploaded bundle bytes were not readable by the artifact-generation runtime
during FINAL packaging, so no unverified lock hash is copied into this
checkpoint.

Keep the original Windows bundle together with this FINAL package.
