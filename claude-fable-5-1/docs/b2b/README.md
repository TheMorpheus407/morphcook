# B2B corporate wellness licensing — deferred

Architecture note only; nothing here is implemented in v1 and nothing in
the app is gated. The design goal is that adding a Pro/B2B tier later is
purely additive: new fields, new screens, no migrations.

## Data model hooks (already compatible)

- The backup format (`schema_version` 1) tolerates unknown top-level keys
  on import and would carry an optional `b2b` object:
  `{"org_id": "...", "seat_token": "...", "programme": "..."}`.
- `Profile` is serialised as JSON with unknown keys ignored, so an
  `org_id` / `programme` pair can be added without touching existing
  installs.
- Content stays bundled; a B2B build would ship an additional partition
  (`assets/programme-<org>.json`) through the same manifest mechanism.

## Wireframes (text)

1. **Settings → "Your organisation"** — a card with the programme name,
   the seat status and a "leave programme" button. Redeem flow: enter a
   code, no account, no network beyond a one-time signed token check.
2. **Home masthead** — an optional second line "in partnership with
   {org}"; nothing else changes on the front page.
3. **Programme partition** — dishes flagged `programme_only` appear in a
   "from your programme" row, using the same variant lattice.

## API surface (future, all offline-verifiable)

```
POST /v1/seats/redeem      { code } → { org_id, programme, seat_token (signed) }
GET  /v1/programmes/{id}   → partition manifest delta (signed)
```

Tokens are verified with a bundled public key; the app never calls these
endpoints in v1 builds (no HTTP client is configured).
