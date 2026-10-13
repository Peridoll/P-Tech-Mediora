# Mediora Pharmacy v0.1 (draft)
Independent EMS player-inventory crafting. Recipes are prototypes (bandage/medkit), not treatment effects and not a hospital shared-inventory implementation.
Requires qbx_core, ox_lib, ox_inventory, ox_target. Register `ptech_pharma_base`, `bandage`, `medkit` in ox_inventory first, and update job names/coordinates/recipes. No other Mediora module is required.
The server validates job, duty, proximity, ingredients, capacity and per-player locks. Inventory operations are sequential, not database-atomic; a failed compensation is logged for administrators. FiveM live tests and concurrent inventory failure tests are required before production. Do not assume the source server's item IDs exist in a new installation.
