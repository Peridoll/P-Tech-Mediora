# Mediora Patients: gameplay and first-line testing

The Patients module serves two purposes without making another P-Tech resource mandatory.

## Gameplay track

Hospital intake → assigned NPC location → simulated examination → return/report. This supports short EMS activities during quiet periods. Additional complexity and rewards are deferred until game balance and integration are specified.

## Test track

- Deterministic fixtures: healthy, injury, laststand, dead and unknown data.
- Verify UI formatting, error handling and eligibility without risking real player data.
- To test Medical or Escort *end-to-end*, later introduce an explicitly registered network entity, a documented optional adapter API and consistent server-side authority. Local fake data printed to F8 is not proof that Wasabi/Medical or Escort worked.
- Keep mock display separate from real health/injury mutation and from money or item operations.

## Validation matrix

| Scenario | v0.1 ability | In-game verified? |
| --- | --- | --- |
| Spawn local patient | Implemented as prototype | No |
| Select synthetic injury preset | Implemented (data only) | No |
| Start/complete NPC visit | Implemented as prototype | No |
| Medical observation of actual injury | Not implemented | No |
| Medical treatment integration | Not implemented | No |
| Escort network transport integration | Not implemented | No |
| Shared NPC visibility | Not implemented | No |

Recommended follow-up: first verify standalone NPC job; then add opt-in network fixture API and Medical/ Escort adapters.
