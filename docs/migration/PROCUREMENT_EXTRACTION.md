# Procurement extraction — 2026-10-13

Source: `Peridoll/NovaPeridoll/resources/[ptech]/ptech_medical/modules/logistics` (v0.5.0).

Standalone resource: `resources/ptech_mediora_procurement`.

The job retains order → supplier collection → hospital delivery → shared stash material deposit → receipt creation. Direct cash rewards, XP/progression, pharmacy production and receipt redemption are intentionally not implemented.

Extraction removes `MedicalModules` and combined-resource feature guards, gives the job its own NUI and fxmanifest, and renames `ptech_medicalJobs:*` network identifiers to `ptech_mediora_procurement:*`. Item IDs and warehouse ID remain unchanged.

## Acceptance / migration gate
- Confirm current inventory item definitions; check exact warehouse permission/registration and capacity behavior.
- Test resource startup, Lua syntax and permission/state transitions.
- In-game test delivery, cancel, disconnect, restart, full inventory and rollback behavior.
- Confirm all old external event consumers are migrated before disabling legacy logistics.
- Do not enable old and new logistics together in the same server. Keep NovaPeridoll unchanged.
