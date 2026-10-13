# P-Tech resources layout

Mediora resources are grouped under:

```text
resources/
  [ptech]/
    [mediora]/
      ptech_mediora_medical/
      ptech_mediora_patients/
      ptech_mediora_escort/
      ptech_mediora_procurement/
      ptech_mediora_pharmacy/
      ptech_mediora_billing/
      ptech_mediora_settlement/
```

The bracketed directories are **organization categories**, not FiveM resources.
Each `ptech_mediora_*` folder still has its own `fxmanifest.lua`.
When deploying, copy the complete `[ptech]` folder tree into the server's `resources/`.
In server.cfg, you can continue to use individual `ensure ptech_mediora_medical`, etc., unchanged.

**Migration:** remove old top-level copies from your *test server* so each resource exists exactly once. Do not run the old integrated `ptech_medical` features simultaneously with split resources. This PR only moves repository files and does not modify the running NovaPeridoll server. Any prior paths in migration documents referring to `resources/ptech_mediora_*` describe the pre-reorganization location.

SQL migrations for Billing and Settlement remain inside each resource folder. Item registrations still need to be applied separately in ox_inventory. No FiveM runtime tests were performed as part of this folder-only change.
