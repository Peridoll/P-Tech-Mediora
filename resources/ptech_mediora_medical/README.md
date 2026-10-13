# P-Tech Mediora Medical v0.1.0

Independent examination and diagnosis-report resource extracted from NovaPeridoll `ptech_medical` v0.5.0. This release does **not** implement treatment, X-ray examinations, drug consumption or billing.

## Features

- `/pmedical`: inspect nearest player in range; requires configured on-duty medical job.
- Read Wasabi injury observations and show a standalone NUI screen (`Config.UI='context'` for ox_lib fallback).
- Issue one non-stackable `ptech_diagnosis` inventory report on successfully authorized examination. The report contains server-resolved identity and untrusted Wasabi-client observation data, **not** a treatment or billing authorization.
- No dependency on other P-Tech / Mediora resources. NPC training was intentionally excluded for the separate `ptech_mediora_patients` package.

## Dependencies

Qbox (`qbx_core`), `ox_lib`, `ox_inventory`, `wasabi_ambulance`, OneSync.
The protected Wasabi export `diagnosePlayer` and returned schema must be verified in your licensed in-game installation.

## Install

1. Add `ptech_diagnosis` to `ox_inventory/data/items.lua` **inside** the existing items table; do not replace the file. Example:
   `['ptech_diagnosis'] = { label = '診断書', weight = 10, stack = false, close = true },`
2. Put this entire directory in your server resources and `ensure ptech_mediora_medical` after dependencies.
3. Configure `Jobs`, `ReportItem`, `Distance` and `UI` in `config.lua`.
4. Stop or disable the old `ptech_medical` clinical feature before deploying this resource; avoid overlapping `/pmedical` commands and old client events.
5. Validate live with two connected players, permitted job/duty, valid range and routing bucket; re-login to confirm metadata persistence and check NUI focus.

## Security / compatibility

All inventory issuance and patient identity checks are performed on the server, including proximity, bucket and one-use examination ticket. Injury data from Wasabi is client-observed; do not rely on it for treatment or prices. Namespaced callback IDs have changed from `ptech_medical:*` to `ptech_mediora_medical:*`; any external integrations must be updated.

## Current verification

The clinical code was transferred and decoupled from the legacy shared NUI and NPC training module. Live FiveM, Wasabi export shape, and UI focus have **not** yet been verified. Do not deploy to production without in-game tests.
