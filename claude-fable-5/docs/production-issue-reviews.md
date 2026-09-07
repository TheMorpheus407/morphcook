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
