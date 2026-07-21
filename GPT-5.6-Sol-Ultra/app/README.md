# MorphCook Flutter client

This directory contains the iOS and Android client. It is intentionally
offline-only: recipes and reference content are bundled under `assets/`, while
all user state stays in SharedPreferences/Hive or in files the user explicitly
exports through the system share sheet.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

For a signed Play release, provide `android/key.properties` (ignored by Git)
with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`, or set the
equivalent `MORPHCOOK_STORE_*` / `MORPHCOOK_KEY_*` environment variables. The
release build never falls back to the debug signing key.

See the repository-level `README.md` and `SPEC.md` for the product model,
feature scope, architecture, and verification overview.
