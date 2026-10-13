# P-Tech Mediora Procurement v0.1.0

Independent medical-material procurement resource extracted from the former `ptech_medical/modules/logistics`.

## Implemented
- Duty-checked EMS supply orders at the hospital.
- Supplier collection, return delivery, medical-material warehouse deposit.
- Receipt issuance for **later settlement**, without immediate cash payment.
- Dedicated NUI dashboard, waypoints, ox_target interaction and inventory checks.

## Default configuration
- Jobs: ambulance
- Warehouse: `ptech_hospital_pharma`
- Material: `ptech_pharma_base` x10 per cargo
- Cargo: `ptech_medical_cargo`
- Receipt: `ptech_medical_receipt`
- Receipt nominal amount: $200,000; this module does not pay or redeem receipts.
- Hospital and supplier coordinates must be verified/adjusted to the actual server map.

## Dependencies
`qbx_core`, `ox_lib`, `ox_target`, `ox_inventory`, OneSync. No mandatory dependency on another Mediora resource.

## Installation
1. Register cargo, receipt and material items using the legacy `ptech_medicalJobs/install/items.lua` definitions or equivalent, inside the existing ox_inventory items table. **Never replace the full inventory file.**
2. Deploy this folder and `ensure ptech_mediora_procurement` after dependencies.
3. Configure hospital and suppliers, jobs, stash and items.
4. Stop the legacy logistics module in `ptech_medical` (or stop that legacy resource once its other modules are migrated). Never run two job implementations on the same warehouse and items concurrently.
5. Verify pickup, delivery, inventory capacity and receipt metadata in an actual FiveM test environment.

## Migration notes
- Network callbacks/events were renamed from `ptech_medicalJobs:*` to `ptech_mediora_procurement:*`.
- Existing stash ID and item names were preserved. Existing receipt items are **not** automatically redeemed.
- The old shared iframe NUI host has been replaced by a standalone NUI page; callback names remain `logistics_action` and `logistics_close` within this resource.
- The source NovaPeridoll repository is not modified.

## Test status
Source-level migration only. Lua runtime tests and FiveM integration tests have not been run on this extracted version. Production deployment is blocked pending validation.
