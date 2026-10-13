# Mediora Medical initial extraction

Source: `Peridoll/NovaPeridoll/resources/[ptech]/ptech_medical/modules/clinical` (v0.5.0).

## Changes
- New, separately startable `ptech_mediora_medical` resource and manifest.
- Clinical client/server/shared/UI and dedicated NUI moved into their own root.
- Renamed `ptech_medical:*` callback / UI identifiers to `ptech_mediora_medical:*`.
- Removed synthetic NPC training to reserve it for `ptech_mediora_patients`.
- Removed combined-resource feature switches and shared NUI iframe dependency.
- Existing diagnosis report item ID `ptech_diagnosis` is retained.

## Not yet included
Treatment, medical equipment, medicines, billing and real NPC patient jobs.

## Test gates before production
- Validate Lua syntax and resource startup.
- Exercise NUI focus, refresh, Escape, job rules, routing bucket, disconnect and item metadata.
- Confirm Wasabi diagnosis export schema with the actual deployed version.
- Verify command conflict-free migration with legacy resource turned off.

No changes are made to the source NovaPeridoll repository.
