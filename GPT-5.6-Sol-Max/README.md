# MorphCook

MorphCook is an offline-first Flutter cookbook in which every dietary version is
a complete recipe linked to a shared dish concept. It ships with a bilingual
English/German corpus and keeps profiles, saved variants, plans, shopping data,
and cooking history entirely on the device.

## Run

```sh
cd app
flutter pub get
flutter run
```

Only Android and iOS are configured. The app does not request internet access.

## Verify

```sh
cd app
flutter analyze
flutter test
```

The bundled corpus lives in `app/assets/` and is loaded through the partition
manifest. UI fonts are bundled in the application; runtime font fetching is
disabled.
