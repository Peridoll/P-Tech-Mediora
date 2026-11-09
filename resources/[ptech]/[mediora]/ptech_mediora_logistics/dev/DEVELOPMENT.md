# Development notes

## Resource layout

```text
ptech_mediora_logistics/
├── config.lua                            # Framework, locations, economy, and progress settings
├── recipes.lua                           # Crafting and daily special-carton recipes
├── install/
│   ├── images/                           # Carton inventory icons
│   └── ox_inventory/items.lua            # Medical item catalog and effects metadata
├── main/
│   ├── client/client.lua                 # Markers, prompts, and menus
│   ├── server/server.lua                 # Inventory, carton state, economy, and crafting
│   └── ui/progress/logistics.svg          # Crate animation rendered by Core
├── dev/
│   ├── README.md
│   └── DEVELOPMENT.md
└── fxmanifest.lua
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
- Effects in `install/ox_inventory/items.lua` describe intended medical behavior. Treatment-system hooks are not implemented yet.

## 物流の経済試案（クラウドから引き継ぎ）

- タブレットは道具ごとの基準販売価格。ピルボックス窓口は基準価格の120%。窓口の表示と決済は同じ価格を使う。
- 未開封の通常回収箱は、内容物の買い取り単価 × 個数の合計の20%。金額は納品成立後に通知する。既存の特注段ボールは別計算。
- 道具の買い取り単価は道具ごとに調整する。最安の購入経路であるタブレット価格以上の買い取りを許さない。
- 白個人医の窓口売上は病院資金に全額入れ、病院がプレイヤーから買い取った物品は倉庫に入れる方針。売るときは倉庫在庫を先に使い、不足分だけ病院資金で仕入れる。病院資金で行う仕入れは病院の売上として計上しない。
- 現地の販売単価はEMS・白個人医・黒個人医で共通にする方針。個人医の権限と窓口、病院口座・倉庫との連携は未実装。
- 不足分の仕入れ単価は半額案。半額の基準と品目ごとの日次上限は未確定。倉庫優先で、在庫と当日の残り仕入れ枠を超える数量は供給しない案。
- 治療で請求する道具代は、現地購入した道具を使っても赤字にならない額を検討する。道具ごとの治療請求額は未確定。
- 道具ごとに基準価格・窓口価格・買い取り額・仕入れ単価・治療時の道具代を並べ、プレイヤーの売り戻し差額と、倉庫在庫・外部仕入れそれぞれの病院粗利を比較する。供給量は回収箱から出た個数と日次仕入れ数で別に集計する。集計画面は未実装。

## Values needed from the target server

1. **Pickup points:** add entries to `Config.CollectPoints` in `config.lua`; IDs must be unique and each point should be assigned a route grade from 1 to 5.
2. **External material item IDs:** confirm the real ox_inventory IDs currently written as `cloth`, `plastic`, `aluminum`, and `glass` in `recipes.lua`.
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
