# T14 Runbook

Overlay the candidate on the current HomeTechVN directory.

The ZIP excludes:

- `app/.env.local`
- `worker/.dev.vars`
- `node_modules`
- `dist`
- `.wrangler`

Run one command:

```powershell
cd D:\HOMETECHVN
npm run t14:verify
```

Verifier sequence:

1. require exactly the locked 33 T1–T13 migrations;
2. reject any T14 database migration;
3. local Supabase reset/replay;
4. run T13 SQL regression;
5. run T11 responsive regression;
6. run T12 public Warranty/privacy regression;
7. run T13 Reports regression;
8. run T14 PWA source check;
9. install app dependencies;
10. verify pinned `vite-plugin-pwa`;
11. TypeScript/Vite production build;
12. inspect generated manifest;
13. inspect generated `sw.js`;
14. verify 192/512/maskable/Apple icons;
15. assert generated SW has no Supabase domain caching;
16. assert generated SW has no Background Sync plugin;
17. write `docs\snapshots\T14_LOCAL_VERIFY_*.txt`.
