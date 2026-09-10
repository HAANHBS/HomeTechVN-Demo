# HomeTechVN — T14 MASTER CHECKLIST

## Database integrity
- [x] T14 adds no database migration
- [x] T1–T13 remains exactly 33 migrations
- [x] T13 database regression retained
- [x] no Supabase schema/function change

## PWA installability
- [x] `vite-plugin-pwa` pinned to 1.3.0
- [x] Web App Manifest
- [x] name / short_name
- [x] start_url `/`
- [x] scope `/`
- [x] standalone display
- [x] window-controls-overlay preferred where supported
- [x] theme/background colors
- [x] 192x192 PNG
- [x] 512x512 PNG
- [x] 512x512 maskable PNG
- [x] 180x180 Apple touch icon
- [x] in-app install prompt
- [x] installed-state detection
- [x] public Warranty page does not show install CTA

## Service Worker / update
- [x] Workbox generated Service Worker
- [x] prompt update strategy
- [x] `skipWaiting: false`
- [x] old cache cleanup
- [x] periodic update check while online
- [x] update notification
- [x] no forced automatic reload
- [x] SW no-cache Cloudflare header
- [x] manifest no-cache Cloudflare header

## Offline safety
- [x] app shell/static precache only
- [x] no Supabase runtime caching
- [x] no Background Sync
- [x] global offline modal lock
- [x] explicit business-operation warning
- [x] no stale public Warranty data presented as current
- [x] no queued writes replayed after reconnect

## Responsive / UI
- [x] T11 global responsive regression PASS
- [x] T12 public Warranty regression PASS
- [x] T13 Reports regression PASS
- [x] install button safe-area support
- [x] update toast responsive
- [x] offline page responsive
- [x] print hides PWA controls
- [x] T14 PWA source check PASS
- [x] Windows PWA build check

## Build artifact acceptance
- [x] built `manifest.webmanifest`
- [x] built `sw.js`
- [x] built PWA icons
- [x] built manifest references 192/512/maskable icons
- [x] generated SW contains no Supabase domain cache rule
- [x] generated SW contains no Background Sync plugin
- [x] T14 LOCAL REPRODUCIBILITY: PASS
- [x] T14 PWA CORE CHECKS: PASS
- [x] T14 RESPONSIVE UI CHECK: PASS
- [x] T14 APP BUILD: PASS
