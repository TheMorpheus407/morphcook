# B2B API surfaces

The interfaces of the B2B design: three files that cross between the operator
and a phone, and the admin API behind them. [README.md](README.md) explains the
architecture, and [wireframes.md](wireframes.md) shows the screens.

Nothing here is built. The app side needs no server: the license, the pack and
the report are files and codes, so they can be implemented and tested with
fixtures before any API exists.

## License token

A license is a compact signed token, in the shape of a JSON Web Signature
(RFC 7515) with EdDSA (RFC 8037). The app verifies it offline with a public key
that ships in the app. The `cryptography` package that the backup code already
uses provides Ed25519.

```
<header>.<payload>.<signature>        each part base64url without padding
```

Header:

```json
{ "alg": "EdDSA", "typ": "mc-license", "kid": "2027-01" }
```

Payload:

```json
{
  "v": 1,
  "org": "org_7f3a2c",
  "cohort": "acme-2027-q1",
  "seat": "s_91b0d4",
  "ent": ["team-menu", "collections", "challenge", "report-export"],
  "nbf": 1798761600,
  "exp": 1806192000
}
```

| Claim | Meaning |
|-------|---------|
| `v` | token version, 1 |
| `org` | organization id, random, no name |
| `cohort` | cohort slug. Reports carry it, and packs are addressed to it. |
| `seat` | random seat id. It identifies a token in the operator's records and appears on no report. |
| `ent` | entitlements, see below |
| `nbf`, `exp` | valid from and until, seconds since the epoch |

Entitlements:

| Id | Unlocks |
|----|---------|
| `team-menu` | importing team menus into the plan |
| `collections` | installing packs of extra dishes |
| `challenge` | the challenge card on the insights screen |
| `report-export` | the report export |

An id the app does not know is ignored, so a newer token works on an older app
with the entitlements that app understands.

### Verification

1. Split the token into three parts. Anything else is `malformed`.
2. Decode the header. `alg` has to be `EdDSA` and `typ` has to be `mc-license`.
   Otherwise `malformed`.
3. Look up `kid` in the key set of the app and in its deny list. An unknown or
   denied `kid` is `unknown-key`.
4. Verify the signature over the ASCII bytes of `<header>.<payload>`. A wrong one
   is `bad-signature`.
5. Decode the payload. `v` must be 1 or lower, or the result is `needs-update`.
6. Compare `nbf` and `exp` with the injected clock: `not-yet-valid`, `expired`.
7. Otherwise the token is `valid`.

The result is one of `valid`, `malformed`, `unknown-key`, `bad-signature`,
`needs-update`, `not-yet-valid` and `expired`. Each has its own copy in the
company plan screen. The verifier is a pure function of the token, the key set and
the time, so it is tested with a fixed clock and fixture keys.

### Where the app keeps it

In the reserved `Profile.b2b` map:

```json
{
  "v": 1,
  "license": {
    "token": "<the token>",
    "org": "org_7f3a2c",
    "cohort": "acme-2027-q1",
    "ent": ["team-menu", "collections", "challenge", "report-export"],
    "valid_until": "2027-03-28",
    "activated_at": "2027-01-05T08:12:00Z"
  },
  "packs": [{ "id": "acme-canteen", "version": 3, "installed_at": "2027-01-05T08:14:00Z" }]
}
```

The token stays in the block, so the app verifies it again at every start and the
stored claims cannot drift from the signed ones. A backup carries the block inside
`profile`, and the backup password encrypts it.

### Keys

The app ships a set of public keys by `kid`. A new key arrives with an app
release. A key that leaked goes onto the deny list of the next release, and
tokens signed by it stop working when a person updates. The private key sits in
a signing service, offline or in an HSM, and the admin API asks that service to
sign.

## Content pack

A pack is one JSON file with the extension `.mcpack.json`. A person opens it
through the share sheet or the file picker, like a backup.

```json
{
  "format": "morphcook-pack",
  "v": 1,
  "id": "acme-canteen",
  "version": 3,
  "org": "org_7f3a2c",
  "cohort": "acme-2027-q1",
  "kind": "collection",
  "title": { "en": "the canteen", "de": "die Kantine" },
  "valid_from": "2027-01-04",
  "valid_until": "2027-03-28",
  "dishes": [ { "id": "acme-canteen-salad", "...": "dish.schema.json" } ],
  "recipes": [ { "id": "acme-canteen-salad-vegan", "...": "recipe.schema.json" } ],
  "menus": [
    { "week": "2027-W03", "slots": { "mon.lunch": "bolognese", "tue.lunch": "acme-canteen-salad" } }
  ],
  "signature": { "kid": "2027-01", "alg": "EdDSA", "sig": "<base64url>" }
}
```

| Field | Rules |
|-------|-------|
| `kind` | `collection` carries `dishes` and `recipes`, `menu` carries `menus`, and a pack may carry both. |
| `version` | A higher version replaces the installed one. A lower one is ignored. |
| `dishes`, `recipes` | They follow `pipeline/schemas/dish.schema.json` and `recipe.schema.json`. Ids start with the pack's organization slug, so they cannot collide with the bundled corpus. Dishes use `partition_id: "pack"` and `frequency_tier: "extended"`. |
| `menus` | A slot names a **dish**, from the bundled corpus or from the pack. The app picks the version that fits the person's profile when it fills the plan. |
| `signature` | Ed25519 over the canonical JSON of everything except `signature`: keys sorted, no whitespace. |

Import checks, in order. The first failure stops the import and changes nothing:

1. the signature, the `kid` and the license: a `collections` or `team-menu`
   entitlement has to be active, and the pack's cohort has to match,
2. the validity window,
3. schema validation of every dish and recipe,
4. the ontology: every flag, diet, meal type, technique and unit exists,
5. the ingredient ids exist in the bundled dictionary,
6. `contains` covers what the ingredients bring, using the same derivation as the
   corpus tooling.

Checks 3 to 6 are the gates of `pipeline/`. The operator runs them before it
signs a pack, and the app runs them again on import, because the app trusts its
own dictionary and nobody else's.

Removing a plan deletes the license and the pack files. A recipe that a person
saved from a pack stays in the cookbook as a snapshot in the local record
store, so the cookbook never has a dead entry. The bundled corpus is the only
place where the cookbook resolves an id.

## Wellness report

An employee exports it after a preview. The app never sends it.

```json
{
  "format": "morphcook-report",
  "v": 1,
  "report_id": "9c1f5a0e-3b1d-4c0a-9d0e-5e9a3f0b7a41",
  "cohort": "acme-2027-q1",
  "period": { "from": "2027-01-04", "to": "2027-03-28" },
  "aggregates": {
    "cooked": 23,
    "unique_recipes": 17,
    "variety_score": 41,
    "plan_weeks_filled": 9,
    "diets_cooked": { "classic": 11, "vegan": 12 }
  }
}
```

| Rule | Why |
|------|-----|
| Seat ids, recipe lists and profile fields stay out | Nothing in the file points to a person. |
| `report_id` is random per export | The console drops the same file uploaded twice. |
| `period` is the cohort window | No finer dates. |
| Counts only | Every value is a count of things the app already computes for the insights screen. |

The console shows a cohort's aggregate when at least 10 distinct reports
contributed.

## Admin API

REST over HTTPS, JSON bodies, versioned in the path (`/v1`). It belongs to the
operator, and the app never calls it.

Authentication: OpenID Connect for people in the console, with the roles `owner`,
`admin` and `viewer` per organization. API keys with a scope for automation, for
example an HR system that requests licenses in bulk.

| Method and path | Purpose | Roles |
|-----------------|---------|-------|
| `POST /v1/organizations` | create an organization | operator |
| `GET /v1/organizations/{org}` | read it | viewer |
| `POST /v1/organizations/{org}/cohorts` | create a cohort: window, entitlements, seat count | admin |
| `GET /v1/organizations/{org}/cohorts` | list cohorts | viewer |
| `POST /v1/organizations/{org}/cohorts/{cohort}/licenses` | issue tokens for a number of seats | admin |
| `GET /v1/organizations/{org}/cohorts/{cohort}/licenses` | list seats and their status. It lists seat ids only. | admin |
| `POST /v1/organizations/{org}/packs` | upload a pack for validation and signing | admin |
| `GET /v1/organizations/{org}/packs/{pack}` | read a pack's state and its gate issues | viewer |
| `POST /v1/reports` | ingest an exported report file | public, rate limited |
| `GET /v1/organizations/{org}/reports` | aggregates per cohort. Parameters: `cohort`, `from`, `to`. | viewer |

### Examples

Create a cohort:

```http
POST /v1/organizations/org_7f3a2c/cohorts
Content-Type: application/json

{
  "slug": "acme-2027-q1",
  "valid_from": "2027-01-04",
  "valid_until": "2027-03-28",
  "seats": 250,
  "entitlements": ["team-menu", "collections", "challenge", "report-export"]
}
```

Issue licenses. `Idempotency-Key` makes a retry return the same tokens instead of
issuing new ones:

```http
POST /v1/organizations/org_7f3a2c/cohorts/acme-2027-q1/licenses
Idempotency-Key: 2f6c1d5e-1c9a-4b0e-8c2d-7d1e9f0a1b22
Content-Type: application/json

{ "count": 250, "format": "json" }
```

```json
{
  "cohort": "acme-2027-q1",
  "issued": 250,
  "licenses": [ { "seat": "s_91b0d4", "token": "eyJhbGciOiJFZERTQSIs..." } ]
}
```

The tokens appear in this response once. The API keeps seat ids and their status
and never stores a token, so a lost file means issuing new seats.

Upload a pack that fails a gate:

```json
{
  "id": "acme-canteen",
  "version": 3,
  "state": "rejected",
  "issues": [
    {
      "recipe": "acme-canteen-salad-vegan",
      "code": "diet-claim",
      "message": "labelled \"vegan\" but its flags or macros contradict that"
    }
  ]
}
```

The `code` values are the issue codes of the corpus tooling (`schema`, `flag`,
`contains`, `diet-claim`, `duplicate`, `style`, and so on).

### Conventions

- **Errors** use RFC 9457 `application/problem+json`, with a stable `type` per
  case, so a client tells a wrong cohort apart from an expired one without
  reading the text.
- **Lists** paginate with a cursor, like search in the app: `?cursor=&limit=`,
  20 by default, and `next_cursor` in the response.
- **Rate limits** apply per API key, and per address on `POST /v1/reports`.
- **Retention.** Reports are kept for 24 months. Nothing else in the API holds
  personal data.

### Webhooks

An organization can register one HTTPS endpoint. Deliveries are signed with a
shared secret in the `MorphCook-Signature` header and retried with backoff.

| Event | When |
|-------|------|
| `licenses.issued` | a batch of tokens was issued |
| `pack.approved`, `pack.rejected` | validation of a pack finished |
| `cohort.expiring` | 14 days before `valid_until` |
| `reports.threshold_reached` | a cohort reached 10 reports, so its aggregate is visible |
