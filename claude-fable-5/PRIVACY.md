# MorphCook Privacy Policy

*Effective: 2026-09-07 · Contact: Bootstrap Academy / The Morpheus —
via the support email listed on the Play Store page.*

## The short version

MorphCook is an **offline-first app**. It has no backend, no accounts, no
analytics, no ads, and no tracking. MorphCook has no collection server and does not sell personal data. Network
requests happen only when you explicitly load a recipe URL or choose to
download its photo. The requested website (and any redirect or image host)
receives your IP address and the URL requested, under its own privacy policy.
Your profile and cookbook are never sent with those requests. There are no
background downloads. Saved recipes and downloaded photos work offline.

## What stays on your device

Everything you enter lives only in the app's private storage on your
device:

- your profile (name, language, dietary avoidances, calorie target, time
  budget, accessibility preferences)
- saved recipes, cooking history, meal plans, shopping lists
- recipes you write yourself and photos you choose for recipes
- locally logged searches that returned no results (used only inside your
  own backup file, so missing dishes can be reported *by you* if you
  choose to share a backup)

MorphCook never uploads this data. If your phone's OS-level device backup is
enabled, the operating system may include app data in its encrypted device or
cloud backup under the terms and controls of your Apple or Google account.

## Website imports

Recipes imported from a link, their source attribution, and optional photos are
saved in private app storage after you review and save them. Photos are off by
default. You can remove a photo or delete a personal recipe from its detail page.
Website dietary claims are retained as unverified text and do not qualify an
imported recipe for dietary or allergy filtering.

## Backups

The backup includes your personal recipes and chosen recipe photos. It writes a
file (`morphcook-backup.json` / `.json.gz`) and hands it to the **system share
sheet**. Where it goes from
there is entirely your choice and handled by your device's OS and the app
you share it to. You can optionally encrypt the complete shared backup with a
password (AES-256-GCM); when you do, the app does not share an unencrypted
sidecar. Password-protected exports ask you to enter the password twice. We
cannot recover that password — nobody can, that's the point. MorphCook removes
its source export directory after the system share sheet closes. On Android,
the sharing component keeps a separate app-private cache copy long enough for
the receiving app to read it; MorphCook cleans stale sharing-cache copies the
next time Settings is initialized or you reset the app.

## Permissions

The app requests no sensitive permissions. It does not access your
location, contacts, camera, or microphone. The system file picker is opened
only when you explicitly choose a recipe photo or a backup to import. Selected
photo files are copied byte-for-byte into the app's private storage; embedded
metadata in that file (such as camera details or a location tag) therefore also
travels in an exported backup. MorphCook does not inspect that metadata. Broad
photo-library or file access is not requested.

## Children

The app is suitable for general audiences and collects no data from
anyone, children included.

## Changes

If a future version ever changes any of the above (for example an opt-in
online feature), this policy will be updated before that version ships,
and the change will be called out in the release notes.
