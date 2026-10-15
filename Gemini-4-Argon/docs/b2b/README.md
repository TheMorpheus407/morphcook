# MorphCook — B2B Corporate Wellness Architecture (Deferred post-v1)

## Status

Architecture designed for v1 compatibility; runtime implementation deferred (`SPEC.md` § Decisions Deferred).

## Backup & Profile Compatibility

- `UserProfile.b2bWellnessMetadata` (`b2b_wellness` JSON field) is preserved in local storage and protected by AES-256-GCM encryption (`morphcook-backup.json` with `ENC` magic bytes `[0x45, 0x4E, 0x43]`) whenever a backup password is supplied.
- No telemetry or network calls ever leave the device.
