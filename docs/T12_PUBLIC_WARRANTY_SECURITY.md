# T12 Public Warranty Security Contract

The QR URL is a capability URL. Anyone holding the full opaque URL can view the deliberately limited public warranty payload.

## Never expose publicly

- warranty/customer/device UUIDs
- `lookup_token` as a response field
- full customer phone
- full serial number
- customer address/email/Zalo
- sales/repair/service source UUIDs
- claim issue description
- intake condition
- customer request
- technician assignment
- decision notes
- service notes
- QC notes
- resolution/internal notes

## Public fields

Only the minimum required to confirm warranty authenticity and progress:

- warranty code
- effective status
- start/end date
- remaining days
- coverage
- product/device label
- masked serial
- masked phone
- latest claim status and lifecycle timestamps

## Token properties

T7 created an opaque 64-character hexadecimal random token and a unique btree index. T12 does not replace it with a sequential code or UUID.

Invalid format and unknown token both return:

```json
{"found": false}
```

## Search-engine/referrer protection

Cloudflare Pages `_headers` for `/w/*`:

```text
X-Robots-Tag: noindex, nofollow, noarchive
Referrer-Policy: no-referrer
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Cache-Control: no-store
```
