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

- Pickup cooldown is 15 minutes per configured point; each interaction grants one carton containing 5–10 random medical items.
- Carton destination is selected from `Config.Hospitals`.
- Cartons store serials and contents in resource KVP per character. Boxes stack only when owner, destination, type/date/recipe, and exact contents match; direct give/drop is blocked to keep records attached to their owner.
- Daily special-carton recipes rotate using Japan time. A same-day delivery to the specified hospital receives the configured premium; expired cartons pay the regular amount.
- Regular and special sale multipliers, prices, and recipe pool are balance placeholders. Tune them in config after playtesting.
- AED is in the item catalog but has no buy/sell price, so it is omitted from trade menus.
- Effects in `config/items.lua` describe intended medical behavior. Treatment-system hooks are not implemented yet.

## Values needed from the target server

1. **Pickup points:** add entries to `Config.CollectionPoints` in `config/config.lua`; IDs must be unique.
2. **External material item IDs:** confirm the real ox_inventory IDs currently written as `cloth`, `plastic`, `aluminum`, and `glass` in `config/recipes.lua`.
3. **Hospital map locations:** check the default coordinates against the server's map and MLOs.
4. **EMS job/duty rules:** confirm `ambulance` and `Config.RequireOnDuty`.
5. **Balance:** tune item prices, carton multipliers, item weights, and random content weights after server-side play.

These values can remain placeholders while the project structure and code are organized.

## Deferred implementation

- Apply item effects through the server's ambulance/injury resource.
- Add the agreed revival choices, charges, and temporary crutch behavior.
- Implement purified-water production using the chosen fire source and add any finalized burn-cream-plus-cloth product.
- Add item images and verify inventory metadata/stacking behavior in the live server.
- Run end-to-end server checks after the target coordinates and external item IDs are known.
