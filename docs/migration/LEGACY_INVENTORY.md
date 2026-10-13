# Legacy inventory and migration baseline — 2026-10-13

Source repository: [Peridoll/NovaPeridoll](https://github.com/Peridoll/NovaPeridoll)

Legacy resource: `resources/[ptech]/ptech_medical` version **0.5.0** on `main` at inspection time.

## Observed implementation

- `modules/clinical`: exam, patient injury observations, non-stackable `ptech_diagnosis` report, NPC training. Treatment, pricing and billing remain unimplemented.
- `modules/logistics`: medical supply ordering, collection, delivery into `ptech_hospital_pharma`, `ptech_medical_receipt`; receipt settlement not implemented. Config: `ptech_pharma_base` x10 and receipt value 200000; direct payment/progression disabled.
- `modules/escort`: EMS carry, player/NPC handling and vehicle entry/exit.
- Current manifest combines all three into one resource and declares `ox_lib`, `qbx_core`, `wasabi_ambulance`, `ox_inventory`, `ox_target`, `/onesync` for the whole resource.
- Current README instructs disabling old `ptech_medicalJobs` and `ptech_emsEscort` when running unified `ptech_medical`.
- UI uses shared NUI host plus clinical and logistics pages. Legacy event names `ptech_medicalJobs:*` persist.
- The existing `okokBilling` resource in NovaPeridoll is a third-party billing system, not Mediora billing implementation.

## Verification limitations

Repository docs describe Lua mock/NUI tests, but no live FiveM validation. Qbox radial menus, Wasabi export results, CEF iframe focus, escort network synchronization, inventory persistence and billing need in-game verification.

## Migration gates

1. Inventory every legacy file and runtime export/event before changing naming.
2. Copy only source owned or licensed for reuse; do not automatically vendor proprietary Wasabi/okokBilling code.
3. Separate each resource and its own manifest, deps and config; preserve per-module behavior.
4. Document item registration/installation and remove no server resources automatically.
5. Add contract and mock tests; then run in-game validation before deployment.
6. Provide a compatibility and rollback checklist before replacing `ptech_medical` in production.

Original source must remain unchanged until an explicit deployment migration is approved.
