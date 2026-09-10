# HomeTechVN — UI/UX STANDARD

Status: **GLOBAL SYSTEM REQUIREMENT — effective from T11**

This standard applies to Dashboard and every existing/future module.

## 1. Supported device classes

HomeTechVN must remain usable on:

- Desktop / laptop: 1024px and wider
- Tablet: 640–1023px
- Phone: 320–639px
- Touch and mouse/keyboard input

No primary workflow may require desktop-only hover behavior.

## 2. Touch / input

- Primary interactive controls: minimum 44px high.
- Coarse-pointer devices: minimum 48px high.
- Checkbox/radio remain compact but use 18px controls.
- Buttons use `touch-action: manipulation`.
- Mobile text inputs/selects/textareas use 16px font minimum to prevent unwanted browser zoom.
- Destructive actions remain visually distinct and must keep confirmation logic where already defined.

## 3. Navigation

- Dashboard is the default authenticated landing page.
- Every module has one-tap access back to `Tổng quan` through the global floating launcher.
- Dashboard quick navigation only shows modules the current account can access.
- Long navigation strips may scroll horizontally on phone/tablet.

## 4. Tables and dense data

- Every table must be inside a horizontal scrolling container.
- Wide tables keep a sensible minimum width instead of compressing columns into unreadable text.
- On touch devices horizontal table scrolling must remain momentum-enabled.
- New T11 static check rejects a TSX table without a nearby `overflow-x-auto` wrapper.

## 5. Layout and spacing

- Base page gutters: compact on phone, larger on tablet/desktop.
- Cards: rounded containers, clear section separation, no dense wall of controls.
- Dashboard KPI grid starts at 2 columns on phone and expands progressively.
- Important operational queues use stacked cards on narrow screens.
- Content max width prevents excessive line length on desktop.

## 6. Color and readability

Default visual direction:

- Soft dark slate background for long working sessions.
- Cyan as primary navigation/action accent.
- Emerald = healthy/success.
- Amber = warning/attention.
- Red = overdue/failure/urgent.
- Violet = reminder/secondary operational signal.
- Text remains high-contrast without pure-black/pure-white walls.

Color must never be the only status indicator: labels/counts/status text are also shown.

## 7. Accessibility / keyboard

- `:focus-visible` has a clear cyan outline.
- Reduced-motion user preference is respected.
- Controls must remain usable by keyboard.
- Status information must be available as text, not only visual color.
- Responsive behavior must not hide required actions.

## 8. Responsive acceptance gate

From T11 onward, a stage touching frontend UI must preserve:

```text
T11 RESPONSIVE UI CHECK: PASS
```

The check validates:

- touch target CSS foundation
- focus-visible behavior
- mobile font guard
- reduced-motion support
- safe-area launcher
- Dashboard responsive structure
- every TSX table has horizontal overflow protection

A successful TypeScript/Vite production build is still required separately.


## 9. PWA / connectivity

Effective from T14:

- PWA controls must remain usable on phone/tablet/desktop.
- Install/update controls must respect mobile safe-area insets.
- Service Worker updates must not force-reload a form in progress.
- Offline state must be explicit.
- HomeTechVN v1 must not permit or queue offline transaction writes.
- No Background Sync transaction queue may be introduced without a future
  stage that defines conflict resolution, replay idempotency and user-visible
  reconciliation.
- Public Warranty must not show cached/stale warranty data as current while
  offline.
