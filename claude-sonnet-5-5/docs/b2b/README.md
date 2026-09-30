# B2B corporate wellness licensing

**Status: architecture designed, implementation deferred.** The v1 app ships
nothing of this except one reserved field (see [What exists today](#what-exists-today)).
This folder holds the design, so that a later Pro or B2B release can build on
it without reopening the decisions the offline architecture already made.

| Document | Read it for |
|----------|-------------|
| this file | the idea, the constraints, the architecture, privacy and the build plan |
| [wireframes.md](wireframes.md) | the app screens and the admin console |
| [api-surfaces.md](api-surfaces.md) | the license token, the content pack, the wellness report and the admin API |

## The idea

An employer buys MorphCook as a wellness benefit. Employees get the same app
they would get for free, plus what an employer can add to a cookbook:

- **Team menus.** A weekly menu for a cohort, for example the canteen's week,
  that an employee imports into the meal plan with one tap.
- **Company collections.** Extra dishes and recipe collections, published by
  the employer, that follow the same recipe schema and quality gates as the
  bundled corpus.
- **Challenges.** A variety challenge computed on the phone from the cooking
  history and the shopping insights the app already keeps.
- **A wellness report.** An aggregate that an employee can export and hand to
  the program, if they choose to.

The employer never sees an individual's cookbook, plan, history or profile.

## Constraints from the v1 architecture

The design keeps every rule that makes v1 what it is:

1. **No backend and no network calls at runtime.** The app talks to nobody.
   Everything a company adds arrives as a file or a code, and everything the
   program learns leaves as a file that a person chose to share.
2. **No accounts.** A license is a signed token, verified on the device. There is
   no login.
3. **No LLM calls from the app.** Team menus and collections are authored
   ahead of time, with the same pipeline that writes the bundled corpus.
4. **Free v1.** Nothing in v1 is gated. The architecture only has to leave room.
5. **Data stays on the device.** Backups carry the B2B fields inside the profile,
   so a backup password protects them like the rest.

## Architecture

```
  employer                       MorphCook operator                 employee phone
  ────────                       ──────────────────                 ──────────────
  HR admin ── web console ─────▶ Admin API  ──▶ signing service
                                   │   │            │  (Ed25519 private key,
                                   │   │            │   kept offline or in an HSM)
                                   │   └─ pack validation
                                   │      (same schemas and quality gates
                                   │       as pipeline/)
                                   │
              licenses (tokens) ◀──┘
              content packs     ◀──────────────────────────────────┐
                    │                                              │
                    ▼  a code, a QR code or a file                 │
              HR hands them out ─────────────▶  app: verifies the signature with the
                                                public key inside the app,
                                                stores the result in profile.b2b
                                                        │
              wellness report (a file) ◀────────────────┘  the employee exports it,
              uploaded by the employee or collected by HR    after a preview
                    │
                    ▼
              Admin API: aggregates reports per cohort, shows them
              only when enough people took part
```

There are three artifacts and no session between the phone and the operator:

| Artifact | Direction | Format |
|----------|-----------|--------|
| License token | operator → employee | signed compact token, see [api-surfaces.md](api-surfaces.md#license-token) |
| Content pack | operator → employee | signed JSON file, see [content pack](api-surfaces.md#content-pack) |
| Wellness report | employee → program | JSON file the person exports, see [report](api-surfaces.md#wellness-report) |

### On the device

| Piece | Where it lives | Notes |
|-------|----------------|-------|
| The B2B block | `Profile.b2b` (exists) | Opaque map. Round-trips through storage and backups. |
| `LicenseVerifier` | `lib/domain/b2b/` (new, pure Dart) | Parses the token, checks the signature and the dates against the injected clock. |
| Public keys | a Dart constant, listed by `kid` | The `cryptography` package the backup already uses provides Ed25519. |
| `PackImporter` | `lib/domain/b2b/` (new) | Verifies a pack, checks its recipes against the bundled ontology, stores them in the local record store. |
| `Entitlements` | `lib/state/` (new controller) | Exposes what the current license unlocks. Screens ask it and never read the token. |
| Company plan section | Settings (new) | Enter or scan a code, see the status, remove it. |
| Team menu | Plan tab (new) | Import a menu into the week. |

Pack recipes live beside the bundled ones. The matching, ranking and switcher
code treats them like any other recipe, because a pack recipe is a normal
recipe that passed the same schema and gates.

### On the operator side

| Piece | Job |
|-------|-----|
| Admin API | organizations, cohorts, licenses, packs, reports |
| Signing service | signs tokens and packs. The private key never touches the API servers. |
| Pack validation | runs the gates of `pipeline/`: schema, ontology, flags against ingredients, near-duplicates, house style |
| Report store | keeps aggregates per cohort, never per person |

## Privacy

- The app sends nothing. Telemetry, analytics ids and license checks that call
  home do not exist in it.
- A token identifies a seat by a random id, an organization and a cohort. Names,
  email addresses and device ids never enter it. The employer decides whether
  to keep a list that maps seats to people. MorphCook does not need that list
  and does not ask for it.
- A report holds counts for a cohort and a period. Seat ids, recipe lists,
  profile data and dates finer than the period stay out of it. The export
  screen shows the whole file before it leaves the phone.
- The console shows a cohort's aggregate only when at least 10 reports
  contributed. A smaller cohort sees participation and nothing else.
- A backup with a password encrypts the B2B block together with the profile.

## Threats and what the design accepts

| Threat | Response |
|--------|----------|
| A token is shared beyond its seat | Not preventable offline. Tokens expire with their cohort, each cohort has a seat count that the contract enforces, and binding a token to a device would need an identifier that the privacy rules forbid. The design accepts the leak. |
| A forged token or pack | Ed25519 signatures with a key set embedded in the app. Unknown `kid` or a bad signature means the token is ignored. |
| A leaked signing key | Rotate: a new `kid` ships in an app release, and the old one goes on a deny list in the same release. |
| A pack with a wrong flag (a "vegan" recipe with honey) | Packs go through the same gates as the corpus before they are signed, and the app checks flags against its own ingredient dictionary again on import. |
| Expiry with a wrong device clock | The app compares against the device clock only. A person who sets it back keeps a benefit for a while. The design accepts that. |
| A report that identifies someone in a small cohort | The console's threshold, and the report format having nothing to identify. |

## What exists today

- `Profile.b2b` is an opaque, optional map. The app never reads or shows it. It
  survives storage, export and import, plain and encrypted, and the tests cover
  that (`test/data/profile_test.dart`, `test/state/backup_service_test.dart`).
- The backup format needs no change: the block travels inside `profile`.
- The recipe and dish schemas in `pipeline/schemas/` are the schemas a pack has to
  satisfy, and `pipeline/pipeline.sh` is how a pack's recipes are written.

Everything else in this folder is design.

## Build plan

Each step is sized for one ticket of at most an hour, with the tests in the same
ticket.

| # | Step | Done when |
|---|------|-----------|
| 1 | `LicenseVerifier` | valid, expired, not yet valid, unknown `kid`, altered payload and truncated tokens are all told apart, with a fixed clock |
| 2 | `Entitlements` controller and the `profile.b2b` shape | a valid token unlocks its entitlements, an invalid one unlocks nothing, removal clears everything |
| 3 | Company plan section in Settings | enter, scan and remove a code; every state has its copy in English and German |
| 4 | `PackImporter`: signature and schema | a pack with a bad signature or a schema error changes nothing |
| 5 | `PackImporter`: ontology and flag checks | a pack recipe with a wrong `contains` is rejected with the reason |
| 6 | Pack recipes in search, dish pages and cook mode | a pack recipe behaves like a bundled one in the matching and ranking tests |
| 7 | Team menu import | one tap fills the week's empty slots and never overwrites a filled one |
| 8 | Challenge card on Insights | progress is computed from history and insights, with reduced motion respected |
| 9 | Report export with preview | the exported file matches [the report format](api-surfaces.md#wellness-report) and shows before it is shared |
| 10 | Admin API and console (separate repository) | see [api-surfaces.md](api-surfaces.md) |

Steps 1 to 9 need no server. They can ship and be tested with fixture tokens and
packs, and step 10 can follow with real customers.

## Open decisions

- **License terms and pricing.** Deferred with the licence choice for the project.
- **The operator of the signing service.** Also deferred.
- **Whether HR distributes tokens by mail, by QR poster or through an HR system.**
  The API supports all three. The first customer decides.
- **A public key set that outlives the first key.** The mechanism is designed
  (`kid`, deny list per release). The rotation policy is not.
