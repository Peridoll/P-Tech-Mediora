# Mediora modules — provisional architecture

Mediora is the P-Tech medical product family, not a mandatory monolithic FiveM resource.

| Planned resource | Responsibility | Legacy source | Status |
| --- | --- | --- | --- |
| `ptech_mediora_clinical` | Examination, observation, diagnosis reports; later treatment | `ptech_medical/modules/clinical` | Legacy prototype exists; not migrated |
| `ptech_mediora_procurement` | Medical supply procurement, warehouse delivery, receipts | `ptech_medical/modules/logistics` | Legacy implementation exists; not migrated |
| `ptech_mediora_escort` | Patient carrying and vehicle transfers | `ptech_medical/modules/escort` | Legacy implementation exists; not migrated |
| `ptech_mediora_pharmacy` | Compounding/production, materials and stock | None verified | Proposed |
| `ptech_mediora_billing` | Medical fee calculation and invoicing | Existing okokBilling separately | Proposed |
| `ptech_mediora_settlement` | Receipt and outstanding payment settlement | None verified | Proposed; boundary subject to review |
| `ptech_mediora_core` | Only justified shared infrastructure | None verified | Optional, not yet needed |

Each resource should have its own `fxmanifest.lua`, configuration and documented dependencies. A common UI aesthetic does not imply a shared mandatory running resource. Product names and module boundaries are proposals until verified with integration tests.

## Integration approach

- Core is optional by default; if any module needs mandatory shared infrastructure, make the exception explicit.
- Use versioned exports or server events with `GetResourceState` checks and defensive error handling.
- Maintain legacy identifiers where necessary through temporary compatibility shims and documented migration.
- Preserve medical authority boundaries: Wasabi supplies observations; treatment and money must be authorized server-side.
