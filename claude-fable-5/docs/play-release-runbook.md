# Play release runbook

## One-time setup (human, ~30 min, Play Console UI)

1. **Developer account**: play.google.com/console, $25 one-time, identity
   verification (can take a day or two for new accounts).
2. **Create the app**: All apps → Create app → name `MorphCook`,
   default language English (US), App, Free. This binds the package name
   on first upload — ours is `de.themorpheus.morphcook`.
3. **Play App Signing**: accept the default (Google manages the signing
   key; our `morph-release-key.jks` is only the upload key — losing it is
   recoverable via support).
4. **Store listing**: paste from `docs/play-store-listing.md`; upload
   icon + feature graphic from `docs/store-assets/`; add 2+ phone
   screenshots (take on device). Add DE as a translation.
5. **Questionnaires**: data safety, content rating, target audience, ads
   declaration — answers are in the listing doc. Set the privacy policy
   URL.
6. **API access**: Play Console → Settings → API access → link/create a
   Cloud project → create a service account → grant it the app with
   permissions "Release to testing tracks" (+ "Manage production
   releases" when ready). Download the JSON key as
   `play-service-account.json` into the repo root (it is gitignored).

> Note: Google requires new personal developer accounts to run a closed
> test with ≥12 testers for 14 days before production access. An
> organization (Bootstrap Academy) account skips this.

## Every release (scriptable)

```sh
cd claude-fable-5/app
# bump version in pubspec.yaml (e.g. 1.0.1+2) — versionCode must increase
export PUB_CACHE="$PWD/../.pub-cache"
# NixOS: the NDK's clang needs zlib on the library path
export LD_LIBRARY_PATH="$(dirname "$(find /nix/store -maxdepth 3 -name libz.so.1 -path '*zlib*' | head -1)"):$LD_LIBRARY_PATH"
flutter test && flutter build appbundle --release

cd ..
python3 deploy/publish_play.py \
  --key ../play-service-account.json \
  --aab app/build/app/outputs/bundle/release/app-release.aab \
  --track internal \
  --notes "what changed, one or two lines"
```

Promote internal → production either in the Console UI or by re-running
with `--track production` (optionally `--rollout 0.2` for a staged 20%
rollout).

## Secrets inventory (all gitignored, back them up!)

| File | What | If lost |
|---|---|---|
| `app/android/morph-release-key.jks` + `key.properties` | upload signing key | recoverable: request upload-key reset in Play Console |
| `play-service-account.json` | API publishing credential | revoke + reissue in Cloud Console |
