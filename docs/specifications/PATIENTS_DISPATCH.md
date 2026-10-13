# Mediora Patients: emergency dispatch and system test design
Independent Patients module gameplay: request -> accept -> route -> patient observation -> optional pickup -> handover -> debrief.
Patient status presets must be deterministic for test scenarios; reward not tied to arbitrary client claims.
For end-to-end Escort, use a server-created network ped with explicit registration and server-authorized occupancy. For Medical, a separately implemented adapter must surface synthetic injuries with a distinct TEST indicator, without impersonating Wasabi player exports.

## Scenario fixtures
- Healthy patient; no injury
- Bleeding injury and supported treatment
- Suspected fracture; imaging needed
- Laststand / death, support and revive authorization
- Network handoff during escort; loss of entity ownership
- Disconnect / restart during dispatch
- Inventory depletion; treatment refusal
- Unsupported Wasabi export or malformed injury data

## Current status
The separate Patients v0.1 implementation remains in its own Draft PR #5; not automatically merged into this branch. This document defines the next implementation contract only; dispatch and cross-resource integration are not implemented.
