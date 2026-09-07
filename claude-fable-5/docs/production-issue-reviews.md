# Production issue review record

Production baseline: MorphCook 1.6.0+10, original `claude-fable-5/app`.
The app source matches `morphcook-refined` v1.6.0 (9a31020), which F-Droid
builds. Other benchmark implementations are outside this work.

## Issue 6 — website recipe imports

Cookbook → link icon → paste a recipe URL → load → choose a recipe → review
and save. The imported text and optional photo are stored locally. Photos are
off by default; a failed photo download permits importing text alone. Source
attribution is retained. Imported recipes do not acquire verified diet,
allergy or nutrition labels. Ambiguous amounts remain original text with an
explicit indication that they do not scale.

Regression coverage: website parser/network limits, attribution round trips,
review/cancel/save, photo opt-in/fallback/cache, raw amounts throughout cooking
and shopping, and compatibility with existing personal recipes.

Reviewers: `review6_a`, `release_audit`, `web_import`. All approved after
iterations addressing ambiguous/compound quantities, expansion limits,
metadata allocation, and unscaled-amount labeling. The latter two reviewers
had contributed separate implementation portions; each independently reviewed
the complete diff and raised findings in integration authored by others.
`review6_a` additionally tested real Allrecipes HTML and confirmed the
expansion regression fails when its protection is disabled.

Validation: Flutter 3.38.3 analysis clean; full suite 211 passing tests;
20 parser tests passed after strengthening the expansion regression;
Android release APK builds successfully. Website availability remains subject
to the source site's access policy and published recipe data.

## Issue 7 — share recipes and cookbooks

Recipe details can share one recipe; the cookbook can share all saved and
personal recipes. Android receives one Bluetooth-compatible ZIP containing
readable recipe text and importable JSON. Photos are optional. Recipients
preview and confirm additions without replacing their profile, plans,
shopping list, cooking progress, or existing recipes. Duplicate imports are
idempotent and conflicting recipes/photos receive separate local copies.

Regression coverage: localized bundled recipes, source/raw-amount round trips,
photo opt-in, duplicate/conflict handling, persistence rollback, unrelated-data
preservation, bounded JSON/ZIP decoding, dense valid cookbooks, native share
files, cache lifetime, preview/cancel, and navigation during import.

Reviewers: `review6_a`, `release_audit`, `web_import`. All independently approved
the complete change after iterations covering Bluetooth MIME compatibility,
bounded archive inflation, receiver-copy lifetime, import navigation, and
pre-decode JSON limits that also accept the full valid format envelope.
Each reviewer contributed a separate implementation portion, disclosed that
contribution, and reviewed the complete integration and subsequent corrections.

Validation: Flutter 3.38.3 analysis clean; full suite 248 passing tests;
Android release APK built and installed. Android API 34 resolves the ZIP SEND
intent to its Bluetooth activity. Actual radio transfer requires a second
device and depends on the receiving device's available sharing apps.
