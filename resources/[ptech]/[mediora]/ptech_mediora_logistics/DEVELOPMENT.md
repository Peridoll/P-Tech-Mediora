# Development notes

## Resource layout

```text
ptech_mediora_logistics/
├── assets/install/ox_inventory/items.lua  # Manual ox_inventory item definitions
├── config/
│   ├── config.lua                         # Framework, locations, cooldown, economy, UI text
│   ├── items.lua                          # Medical item catalog and effects metadata
│   └── recipes.lua                        # Crafting and daily special-carton recipes
├── main/
│   ├── client/client.lua                  # Markers, prompts, and menus
│   └── server/server.lua                  # Inventory, carton state, economy, and crafting
├── fxmanifest.lua
├── README.md
└── DEVELOPMENT.md
```

## Current behavior and assumptions

- Pickup cooldown is 15 minutes per configured point. Grade 1 starts at 5–10 random medical items; higher grades scale the count using their configured multiplier.
- Each collection point has a configurable grade from 1 to 5. Its profile changes the item-count multiplier, C/UC/R/SR/UR odds, and resale multiplier. Collected items keep their source grade and rarity as inventory metadata; different source grades form separate stacks. The initial odds and multipliers are balance placeholders.
- Carton destination is selected from `Config.Hospitals`.
- Cartons store serials, source grade, and each parcel's contents in resource KVP per character. New boxes stack by owner, destination, and box type even when their contents or grades differ; opening or delivering consumes parcels in queue order. Direct give/drop is blocked to keep records attached to their owner.
- Using a box opens a menu to set a waypoint to its destination or open it. Opening plays an animation with a configurable five-second progress action; canceling leaves the box untouched. All hospitals accept deliveries; only the configured full-service hospital allows crafting, and only the configured trade hospital allows buying and selling. Server handlers enforce these restrictions.
- Daily special-carton recipes rotate using Japan time. A same-day delivery to the specified hospital receives the configured premium; expired cartons pay the regular amount.
- Regular and special sale multipliers, prices, and recipe pool are balance placeholders. Tune them in config after playtesting.
- Reusable revival equipment is not an inventory item. The catalog contains consumable medical tools; priced tools appear in the purchase/sale menus, and configured recipes appear in the crafting menu.
- Effects in `config/items.lua` describe intended medical behavior. Treatment-system hooks are not implemented yet.

## Values needed from the target server

1. **Pickup points:** add entries to `Config.CollectPoints` in `config/config.lua`; IDs must be unique and each point should be assigned a route grade from 1 to 5.
2. **External material item IDs:** confirm the real ox_inventory IDs currently written as `cloth`, `plastic`, `aluminum`, and `glass` in `config/recipes.lua`.
3. **Hospital map locations:** check the default coordinates against the server's map and MLOs.
4. **EMS job/duty rules:** confirm `ambulance` and `Config.RequireOnDuty`.
5. **Balance:** tune item prices, carton multipliers, grade profiles, rarity odds, and within-rank item weights after server-side play.

These values can remain placeholders while the project structure and code are organized.

## Deferred implementation

- Apply item effects through the server's ambulance/injury resource.
- Add the agreed revival choices, charges, and temporary crutch behavior.
- Implement purified-water production using the chosen fire source and add any finalized burn-cream-plus-cloth product.
- Verify inventory metadata, rarity display, and grade-based stacking behavior in the live server; add item images.
- Run end-to-end server checks after the target coordinates and external item IDs are known.
