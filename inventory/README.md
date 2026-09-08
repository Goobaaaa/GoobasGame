# Player inventory and equipment

Current mode: **single-player only**. Hosting and joining are disabled in the session layer and removed from the menus. References below to host authority describe the retained local transaction architecture; LAN behavior is historical and unavailable until multiplayer is revisited. The test runner now runs only inventory and solo gameplay tests, including disabled-host/join checks, near-instant tooltip coverage, rarity instances, stock cards, and shop naming.

## Try it

Open `project.godot` in Godot 4.7.2 and run the game. New Game and Continue both give a player without saved inventory a Small Backpack (6 × 4).

Press **I** to open/close the inventory. Near the starting position, approach the **Adventurer supplies** chest to your left and press **E**. The inventory opens with a **GROUND ITEMS** grid beside the backpack grid; it uses the same 48px cells as the backpack, lays items out in four columns, and scrolls vertically when needed. Each item is shown at its footprint with only its icon and quantity; hover it for the item name and full tooltip. Drag an item from that ground grid into a valid backpack cell. The same layout is used for deliveries beneath Pip and for player-created dropped-item chests. Pick up and equip the Large Backpack first if you want to collect all the examples together.

- Drag from an item's cell to move it. The pointer indicates its new **top-left cell**.
- Drag from the **GROUND ITEMS** grid into the backpack to collect supplies or delivery contents. The source quantity is removed only after the inventory transaction succeeds; failed or full-backpack transfers leave the item on the source.
- Drag a backpack item outside the inventory board to create a saved dropped-item chest at the player's position. Shift-drag drops half a stack. Equipment-slot items cannot be dropped through this path, and failed saves leave the item in the backpack.
- Green means the exact proposed transaction is valid; red means it will be rejected.
- Press **R** or **right-click** during a drag to rotate, if the definition allows it.
- Drop a stack onto a matching stack to fill it; any excess remains at its source.
- **Shift-drag** splits half a stack into a free position. The model also accepts any explicit split quantity.
- Drag equipment to its named slot. Drag it back to the grid to unequip it. An occupied compatible slot returns its previous item to the grid.
- Drag onto a single other grid item to swap if both resulting footprints fit. Equipment-to-grid swaps also check the equipment slot's compatibility and requirements.
- **Esc** cancels a drag first, then closes the inventory on the next press. Closing, reopening, cancelling, or releasing outside the board never removes an item.
- Hover for an immediate custom tooltip with the icon, name, rarity, description, category, stack count, value, weight, dimensions, bonuses, and requirements. Positive values are green, negative modifiers are red, and the rarity colour is shared across inventory/equipment/shop surfaces.

Equipment slots occupy no inventory cells. A backpack's own footprint describes its size **when carried**, while its inventory size determines the available container cells **when equipped**. Nested inventories inside unequipped packs are intentionally not supported: all carried contents belong to the player's one active container.

## Files and responsibilities

| File | Responsibility |
| --- | --- |
| `inventory/item_definition.gd` | Editor-configurable Resource for all item metadata and equipment compatibility. |
| `inventory/item_rarity.gd` | Central rarity tiers, colours, stat/value rules, and progression weights. |
| `inventory/backpack_definition.gd` | Extends item data with independent inventory dimensions and optional weight capacity. |
| `inventory/item_registry.gd` | Discovers `.tres` definitions recursively in `items/definitions`; resolves stable IDs. |
| `inventory/item_instance.gd` | Creates JSON-safe records with random persistent instance IDs, quantity, rarity, rotation, position, and custom properties. |
| `inventory/inventory_grid.gd` | Footprints, bounds, overlap, first-fit placement, and bounded repacking search. |
| `inventory/equipment_rules.gd` | Slot IDs, compatibility, base stats, generic additive stat aggregation. |
| `inventory/player_inventory.gd` | Transactional container/equipment model, stacking, splitting, swaps, pickup, resizing, validation, serialization data. |
| `ui/inventory_board.gd` | Draws slots, grid and icons; translates mouse input into move/equip/drop commands and highlights. |
| `ui/inventory_panel.gd` | Panel layout, current backpack title, backpack/ground grids, usage and gold. |
| `ui/ground_loot_board.gd` | Renders finite ground/container contents as footprint-aware item tiles and routes drag/drop collection. |
| `ui/item_tooltip.gd` | Reusable immediate tooltip description and coloured custom tooltip control, independent of board/card hit testing. |
| `ui/stock_item_card.gd` | Reusable icon, quantity, quick-control, price, and buy card for Pip's catalogue. |
| `ui/stock_order_panel.gd` | Responsive stock-card grid, basket compatibility, delivery countdown, and order routing. |
| `shops/shop_naming.gd` | Configurable 3–30 character shop-name validation and normalization. |
| `items/loot_generator.gd` | Future mob/dungeon loot entry point that rolls a rarity and creates a persistent item instance. |
| `items/definitions/*.tres` | Eleven supplied test item definitions. |
| `items/icons/*.svg` | Simple editable icons for those definitions. |
| `items/adventurer_supplies.gd` | Temporary finite sample loot and the chest position. |
| `tests/inventory.gd` and `.tscn` | Model, persistence and game/UI integration checks, plus optional rendered capture. |

Existing systems were extended: `scripts/game.gd` routes I/E and creates the supplies chest; `ui/game_ui.gd` includes inventory, naming, and stock cards in modal/input handling; `networking/session.gd` validates inventory commands, shop names, order affordability, and inventory-space preflight; `saves/save_store.gd` validates the optional inventory and shop-name extensions; `scripts/player.gd` exposes recalculated `stats` and applies `movement_speed` to movement. The existing five-minute delivery contract and sale-display system remain in place.

## Rarity and future loot

`ItemRarity` is the single source for `Common`, `Rare`, `Epic`, `Legendary`, `Mythic`, and `Artifact`. Colours are in `COLORS`, stat/value scaling and future modifier counts are in `RULES`, and configurable early/mid/late probabilities are in `PROGRESSION_WEIGHTS`. `weights_for_progression(0.0..1.0)` blends the profiles; `LootGenerator.create_item()` is the future mob/dungeon entry point. Artifact is marked for unique behaviour and remains 0% in early/mid profiles and 1% in the supplied late profile.

Definitions still provide the base `modifiers`. A generated instance stores its selected rarity, and `ItemDefinition.effective_modifiers(instance)` applies the rarity multiplier plus any rolled `properties.modifiers`. Stacking compares rarity as well as ID and custom properties, so a generated rare potion never silently merges into a common stack.

## Pip's catalogue and shop names

Pip's menu is a responsive icon-card grid. Each card owns manual quantity entry, `-10/-1/+1/+10/MAX`, a live total, a per-item **BUY** button, and the shared item tooltip. Existing `Catalog.PRODUCTS` entries remain the stock list; add/remove a product there and provide a matching `.tres` definition and icon. Per-card **BUY** adds the item to the backpack immediately and charges only after the inventory transaction can accept it. The **PLACE DELIVERY ORDER** button remains for the earlier multi-item basket/five-minute delivery flow; it also preflights space, while the delivery box performs the final capacity check when it arrives.

On first purchase, `GameUI.show_shop_naming()` asks for a 3–30 character name. `ShopNaming` owns normalization/validation, `Session.state.shop_name` is saved with the existing JSON business save, and `FantasyWorld` updates the exterior/interior Label3D signs. For manual testing, edit `shop_name` in `user://saves/lantern_lane.json` (or the isolated test save) to a valid 3–30 character string, then Continue.

## Add an item without changing inventory code

1. Duplicate a suitable `.tres` under `items/definitions`, or create an **ItemDefinition** resource through Godot's New Resource dialog and save it in that directory.
2. Give it a new, nonempty, permanent `id`, such as `steel_sword`. IDs must be globally unique. Do not rename a released ID without migrating saves.
3. Set `display_name`, `description`, `category`, `rarity`, `icon`, `grid_size`, `max_stack`, `can_rotate`, `weight`, and `value`. Grid dimensions and stack limit must be positive; rare/unique equipment normally uses stack limit 1.
4. Leave `equipment_slots` empty for ordinary materials, consumables, and other carried items. Item categories are descriptive; equipment compatibility uses the explicit slot IDs.
5. Add it to an actual loot/reward source. For a temporary test, add its ID and quantity to `AdventurerSupplies.CONTENTS`, then start a new game. Existing saves retain their previous finite chest contents, so editing the fixture does not silently refill a saved chest.

Definitions are loaded automatically once per process. Restart the running game after adding or editing a definition. Godot imports custom PNG/SVG textures normally. All eight shop products now have matching inventory definitions. Paid orders arrive after five minutes in a collection box beneath Pip; collection uses the same safe stacking and placement API. Contents are removed only after the inventory transfer saves successfully. Pickup quantity controls allow smaller transfers when space is limited. Empty delivery and adventurer-supplies boxes disappear and remain empty after Continue.

## Add equipment

Use **ItemDefinition**, stack limit 1, and one or more of these `equipment_slots`:

`head`, `chest`, `legs`, `hands`, `feet`, `cape`, `back`, `main_hand`, `off_hand`.

For example, a steel helmet can use:

```gdscript
equipment_slots = PackedStringArray("head")
modifiers = {"armour":12, "strength":3, "movement_speed":-0.5}
requirements = {"strength":2}
```

Modifiers are **flat additive numbers** keyed by arbitrary stat names; absent base values start at zero. A new `fire_resistance`, `loot_find`, or other key requires no inventory code changes. Use a consistent unit for each key (for example, chance in percentage points). The stats start from `EquipmentRules.BASE_STATS` and are rebuilt from equipped definitions each time; no incremental apply/remove drift is possible. Requirements are checked at equip time, excluding the incoming item and the item it replaces, so equipment cannot satisfy its own requirements.

Gameplay can read `player.stats.get("damage", 0)` or `Session.inventory_for(peer_id).final_stats()`. Movement speed is wired to the existing controller. Combat, health damage/healing, and other gameplay systems do not exist yet, so their stat values are available for future consumers rather than inventing those systems here. Removing a prerequisite item does not auto-unequip other equipment; requirements are admission checks in this version.

Add a new equipment slot to `EquipmentRules.SLOTS` and give it a position in `InventoryBoard.SLOT_POSITIONS`; opt compatible definitions into that slot. This requires no stack/grid changes. Two-handed weapon rules, percentage multipliers, and comparison panels can be added at their corresponding equipment/stat/tooltip boundaries later.

## Add a backpack

Duplicate an existing backpack or create a **BackpackDefinition** resource. Set:

```gdscript
id = "ranger_pack"
display_name = "Ranger Pack"
grid_size = Vector2i(2, 3)        # Occupied cells when carried
equipment_slots = PackedStringArray("back")
max_stack = 1
inventory_size = Vector2i(9, 5)  # Available cells when equipped
weight_capacity = 0.0           # Optional future encumbrance setting
modifiers = {"luck":2}
```

Set positive inventory dimensions. The panel rebuilds and scrolls to support grids beyond the supplied sizes. `visual` is an optional PackedScene reference for future attachment to character/world models; this first version displays equipment in the UI and does not attach models to the first-person avatar.

Backpack changes operate on a deep copy. The incoming pack leaves the grid, the old pack returns to the grid, and all remaining contents must fit the new dimensions. Existing positions are preserved when possible. Otherwise the grid performs a largest-first search with optional rotation. Search is capped at 100,000 recursive states to avoid freezing on pathological arrangements; a cap exhaustion conservatively rejects the change. It never discards items. You can manually rearrange contents or free space and retry. Failure returns exactly:

> Not enough inventory space to equip this backpack.

Removing the sole backpack into its own contents cannot succeed because no container capacity would remain. Swapping it with another compatible carried pack is supported.

## Commands and extension API

UI operations use this path:

```gdscript
Session.request_action("inventory", {
    "action":"equip",
    "args":{"uid":instance_uid, "slot":"head"}
})
```

The host derives the player from the sending peer, resolves their current inventory, and invokes `transact`. Allowed actions are `pickup`, `move`, `split`, `equip`, and `drop`. `move`/`split` take integer `x`/`y` and Boolean `rotated`; `split` also takes `quantity`. `pickup` uses an item definition ID, quantity, and optional target placement (`x`, `y`, `rotated`) and currently checks the finite supplies and distance to the chest. Delivery collection uses the same placement API with a delivery UID. Dropping extracts the backpack instance atomically, stores it in `ground_loot`, and creates a world chest at the player's drop position.

`inventory.transact(action, args, true)` validates an identical preview without mutating live state. `inventory.add_item(id, quantity, properties, placement, preferred_uid)` is a safe all-or-nothing model API for server-side loot/crafting integrations; `preferred_uid` is optional and lets a re-looted unique instance retain its identity. Its caller must still perform source authority checks and commit/save the resulting `inventory.data` through the session. It fills compatible partial stacks before creating new instances. Per-instance properties must be JSON-compatible dictionaries, and stacks with different properties stay separate. Do not mutate registry resources per instance.

The **GROUND ITEMS** board is the container-loot presentation: supplies, delivered order contents, and player-created dropped chests remain authoritative in the save until a successful pickup. The board uses a four-column layout with the same cell size as the backpack and a nested vertical scroll container. Dropped items retain their unique instance ID and custom properties when re-looted. World-drop records are stored in `ground_loot`; the world creates/removes an interactable chest as that record becomes nonempty/empty.

## Saves and LAN

Inventory is an optional `inventories` dictionary in the existing version-1 world save. Old business saves load without it and receive starter inventory. Each inventory has its own schema version, `items`, `equipment`, and finite `loot` quantities. Each item stores `id` (definition ID), `uid` (instance ID), quantity, rarity, integer grid position, rotation, and properties. The `back` equipment record identifies the active backpack; dimensions/stats come from the current resource definition. `shop_name` is an optional backward-compatible top-level field and is added on the next successful load/save for purchased shops.

Commands commit only after the existing backed-up world write succeeds. Failed validation or save writes leave the old state intact. F5, autosave, leaving, and Continue reuse the existing persistence mechanism. Missing definitions, illegal counts, duplicates, bad equipment, and invalid footprints are rejected during save validation; the existing backup loader can recover a prior valid save. Changing an existing definition's size/capacity can invalidate saves, so such releases need explicit migration.

The local player inventory persists across Continue. Ground source quantities, dropped chests, item positions, rotations, and stacks are only changed after a successful saved transfer, so closing/reopening the panel does not lose state. Multiplayer is currently disabled; the retained LAN validation architecture has no persistent guest identity and should be revisited when co-op returns. Weight is displayed as carried item weight; `weight_capacity` is data for later encumbrance enforcement.

## Verification

```powershell
./tests/run_tests.ps1 -Godot 'C:/Users/49175/Downloads/Godot_v4.7.2-stable_win64.exe'
./tests/run_tests.ps1 -Godot 'C:/Users/49175/Downloads/Godot_v4.7.2-stable_win64.exe' -Visual
```

The runner includes inventory, sale-stock, delivery, and solo gameplay smoke tests; LAN tests remain in the repository but are not launched while multiplayer is disabled. Save locations are isolated under `.test-runtime`; normal player saves are not touched. Visual mode additionally captures `tests/inventory.png` and `tests/04_stock.png`. Tests exercise item conservation on rejected operations, stack remainders, swaps, custom properties, requirements, nonrotatable items, safe shrink/repack, serialization, rarity tiers/stat scaling, immediate tooltip construction, stock-card quantities/icons, shop-name validation/sign persistence, ground-item drag routing, open/close state, and delivery-box collection.
