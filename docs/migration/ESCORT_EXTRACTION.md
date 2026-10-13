# Escort extraction notes — 2026-10-13

Source `Peridoll/NovaPeridoll/resources/[ptech]/ptech_medical/modules/escort/`, current integration v0.5.0.

## Scope
- Copy escort `config.lua`, `shared/targets.lua`, `client/main.lua`, `server/main.lua`.
- Remove `MedicalModules.escort` binding and combined resource feature guards.
- Own `fxmanifest.lua`, external dependencies, start/stop lifecycle.
- Rename `ems-escort:` client/server events to `ptech_mediora_escort:` for separate startup. Keep old exported method names and relevant state-bag keys.

## Compatibility
This is not a drop-in event-name-compatible replacement: external callers of the old prefix or resource export must migrate. Legacy escort should be disabled first to avoid duplicate state handlers. An optional backwards-compatibility adapter is not yet implemented.

## Quality gates
- Verify Lua syntax and exercise existing escort behavior in mocked runtime.
- Live in-game validate carry positions, vehicle occupancy, network ownership, target and job gating, disconnect/restart cleanup and PD priority.
- Confirm actual server external callers before switching over.
- Keep legacy NovaPeridoll unchanged until approved release.
