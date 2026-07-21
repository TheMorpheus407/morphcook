# MorphCook app

This Flutter project targets iOS and Android only. Recipe data lives in `assets/` and is loaded entirely on-device.

The project deliberately keeps local state small and inspectable:

- `shared_preferences` stores the profile and onboarding completion flag.
- Hive stores saved variants, meal plans, history, shopping events, content wishes, and cook progress.
- Backup export produces `morphcook-backup.json` plus `morphcook-backup.json.gz`; optionally the JSON file is AES-256-GCM encrypted.

Run `flutter analyze` and `flutter test` before release.
