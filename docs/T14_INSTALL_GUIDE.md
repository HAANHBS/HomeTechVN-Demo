# HomeTechVN — PWA INSTALL GUIDE

## Production prerequisite

Installability should be tested on the deployed HTTPS Cloudflare Pages URL.

`localhost` is acceptable for local development/testing, but actual staff
installation should use the production HTTPS origin.

## Windows 10 / 11

Recommended:

- Microsoft Edge
- Google Chrome

Steps:

1. Open the HomeTechVN HTTPS URL.
2. Sign in.
3. Use the in-app **Cài ứng dụng** button when available.
4. Accept the browser installation dialog.
5. HomeTechVN then appears as a standalone app and can be pinned to Start/taskbar.

If the in-app button is not shown, use the browser's install-app control/menu.

## Android

Recommended:

- Chrome
- Edge
- other browsers that support PWA installation

Steps:

1. Open HomeTechVN over HTTPS.
2. Sign in.
3. Tap **Cài ứng dụng** when offered.
4. Accept installation.

The installed app opens in standalone mode.

## ChromeOS / Chromebook

1. Open HomeTechVN in Chrome.
2. Use the **Cài ứng dụng** button or Chrome install control.
3. Confirm installation.
4. Launch HomeTechVN from the Chromebook launcher.

## Offline behavior

HomeTechVN may open its cached app shell without Internet, but v1 intentionally
blocks business operations offline.

The following require Internet:

- customer/device changes
- inventory receive/issue/adjust
- sales
- payments/refunds
- repair updates
- checklist writes
- warranty/claim writes
- service/license writes
- reminders/notification configuration
- reports requiring current data
- public warranty lookup

No transaction is placed into a hidden retry/background-sync queue.

## Update behavior

When a new deployed build is detected:

1. HomeTechVN shows an update prompt.
2. Finish the current form/action.
3. Select **Cập nhật**.
4. The installed app reloads on the new version.

If necessary, choose **Để sau** and update after the current work is saved.
