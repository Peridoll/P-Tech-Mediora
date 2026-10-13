# Mediora Medical: examination and treatment design v0.1
Existing Medical independently handles real player observation and non-authoritative diagnosis report issuance.

Phase 2 adds a **configuration-only** catalogue of X-ray / ultrasound examinations and bandaging / immobilization treatment plans. No treatment execution or injury mutation is enabled. Wasabi injury observations cannot authorize charges, actual treatment or trusted diagnosis.

## Intended workflow
1. Server validates medic duty, target, distance and medical session.
2. Examiner reviews observed injuries; imaging request creates a server-owned exam record.
3. Adapter verifies supported Wasabi version and obtains trusted state or explicitly shows unknown.
4. Medic selects an applicable treatment; server verifies permissions and inventory use.
5. Validated adapter applies treatment and records outcome; optional Pharmacy / Billing read successful records via versioned exports.

## Release gates
- Define supported real Wasabi API and server-authoritative injury state.
- Design transaction and inventory rollback for consumed medicine.
- Mock-test authorization, expiration, race conditions, patient disconnect and adapter errors.
- In-game verify diagnosis, actual health changes and advanced exam before production.
