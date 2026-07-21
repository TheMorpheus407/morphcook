# MorphCook

An offline-first Flutter cookbook for iOS and Android. MorphCook treats every dietary version as a complete recipe in its own right, linked to a shared dish concept.

The runnable app is in [`app/`](app/). It includes:

- bilingual EN/DE onboarding, profile matching, search, saved recipe variants, and in-place variant switching;
- weekly meal planning with drag-and-drop, a unit-aware shopping list, and shopping insights;
- dark cook mode with persisted step/timer progress, servings scaling, accessible visual alerts, and opt-in one-handed advance;
- local-only persistence, human-readable/GZip backup, optional AES-256-GCM encrypted JSON backup, and import merge/replace;
- bundled partitioned recipe content, ingredient hierarchy, guide entries, ontology, and searchable FAQ.

Run locally:

```bash
cd app
flutter pub get
flutter run
```

Validate core behavior:

```bash
cd app
flutter analyze
flutter test
```

No runtime network calls, account system, analytics, or cloud sync are used.
