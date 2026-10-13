# Pharmacy, Billing and Settlement - Phase 2 interface draft
Pharmacy: standalone recipe crafting, currently only player inventory. Shared hospital stock requires a separate authorized adapter. A compensation failure must freeze/alert instead of silently assuming rollback.

Billing: whitelist-priced itemized draft, not money withdrawal. Treatment events require server-owned verification and idempotency before bill issuance.

Settlement: queue receipt for review. A metadata field from a client-owned inventory item is not proof of valid revenue. Payment will need an issuance ledger, immutable unique reference, atomic transition and server-side account integration.

No direct payment, banking, item-use treatment or case rewards in phase 2. Optional modules must remain optional and exports should be versioned.
