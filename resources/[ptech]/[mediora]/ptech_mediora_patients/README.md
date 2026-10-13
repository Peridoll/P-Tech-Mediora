# Mediora Patients v0.1.0 (prototype)

Standalone EMS NPC patient visits and synthetic fixture testing.

## Modes

- **NPC visit job**: Start from the configured hospital via ox_target, travel to a spawned local NPC, complete simulated examination, return to hospital. No monetary reward, injury treatment or real Wasabi mutation in this version.
- **Test mode**: Use `/mpatienttest` (on-duty EMS) to spawn a **local-only** preview NPC, select healthy/injured/laststand/dead/unknown fixture data and inspect the synthetic payload in F8. This does not alter GTA health, Wasabi injury state or medical records, and is not yet a full end-to-end Medical/Escort test.

## Dependencies

`qbx_core`, `ox_lib`, `ox_target`, OneSync. No mandatory Mediora Medical, Escort or Core dependency.

## Setup

1. Copy `ptech_mediora_patients` into resources and ensure it after dependencies.
2. Edit `config.lua` hospital position, patient spawn spots, allowed EMS jobs, case definitions and spawn models to match your MLO.
3. Use hospital target `NPC診療依頼を確認` to start/finish visits, or `/mpatienttest` to open the development fixture menu.
4. Validate geometry, NUI/target interactions and session cleanup in-game.

## Important limitations

- NPCs are client-local mock actors; they are not authoritative network patients, cannot be reliably transported by other players and do not share actual Wasabi injury data.
- A patient visit currently performs a simulated progress-bar diagnosis with server-side proximity checks; it does not perform Medical examination or treatment.
- No persistence across resource restart and no pay/experience until separately designed.
- Live FiveM testing is outstanding; this PR is a development prototype, not production-ready.

## Future acceptance goals

- Optional Medical integration to open the same clinical UI and test diagnosis and treatment against controlled patient fixtures.
- Optional Escort integration through a separately registered, networked, state-bag-aware NPC (not a locally spawned ped).
- Explicit opt-in test mode with deterministic cases, expected outcomes, logs and clean rollback.
- Expand visit missions into dispatch, pickup and hospital delivery as an optional route.
