# T14 Build / Test

## Static — PASS

```text
T14 PWA SOURCE CHECK: PASS
T11 RESPONSIVE UI CHECK: PASS
T12 RESPONSIVE PUBLIC UI CHECK: PASS
T13 RESPONSIVE UI CHECK: PASS
```

Verified source contract:

- manifest members
- prompt update lifecycle
- in-app install prompt
- online/offline listeners
- global offline transaction lock
- no Background Sync config
- no Supabase runtime cache config
- PWA icon dimensions
- Cloudflare SW/manifest headers
- T12 public Warranty headers preserved

## Current build status

Artifact environment:

```text
npm install → timed out
```

Therefore:

```text
T14 real Vite PWA build: PASS
generated manifest inspection: PASS
generated sw.js inspection: PASS
```

Windows `npm run t14:verify` performs all three and is the authoritative
acceptance.


## Windows final acceptance — PASS

```text
T14 LOCAL REPRODUCIBILITY: PASS
T14 PWA CORE CHECKS: PASS
T14 RESPONSIVE UI CHECK: PASS
T14 APP BUILD: PASS
Snapshot: D:\HOMETECHVN\docs\snapshots\T14_LOCAL_VERIFY_20260831_011207.txt
```
