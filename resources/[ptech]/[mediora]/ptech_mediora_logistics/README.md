# P-Tech Mediora Logistics

Qbox EMS supply procurement and hospital trading resource using `ox_inventory` and `ox_lib`.

## Install

1. Copy the resource folder into the server's resources directory.
2. Merge [`assets/install/ox_inventory/items.lua`](assets/install/ox_inventory/items.lua) into `ox_inventory/data/items.lua`.
3. Add the resource to `server.cfg` after `qbx_core`, `ox_lib`, and `ox_inventory`.
4. Set pickup coordinates and verify hospital locations in `config/config.lua`.
5. Match the external crafting material IDs in `config/recipes.lua` to the server's inventory items.

## Current features

- EMS supply pickup with a configurable cooldown and random item count.
- Serialized cartons assigned a random hospital destination.
- Hospital delivery, item purchase and sale, and item crafting menus.
- Daily special-carton recipes with a same-day delivery bonus.
- Carton opening with recorded contents and per-character persistence.

See [`DEVELOPMENT.md`](DEVELOPMENT.md) for configuration details, implementation notes, and remaining decisions. Coordinates, economy multipliers, and external crafting material IDs are provisional until set for the target server.
