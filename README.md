# Lantern Lane — playable foundation

Open **project.godot** in Godot 4 and press **F6** on `scenes/main.tscn`, or **F5** from any scene. Tested with the installed **Godot 4.7.2**, using the Compatibility renderer. No addons or external art downloads are required at runtime.

## First play
1. Choose **New Game**. You start on the street with **1,000 gold**.
2. Walk to any of the three shop doors. Look at it, press **E**, and buy the deed for **300 gold**.
3. Press **E** at the same door to enter. **B** opens the furniture catalog.
4. Choose furniture, look down at the grid, rotate with **R**, then left-click a green preview to place it.
5. Look at the inside door and press **E** to leave. Find **Pip**, the floating purple IMP beside your shop, and press **E**.
6. Talk to Pip, choose quantities in the icon-card catalogue, check each live total, and click **BUY** to add a purchase immediately to your backpack. Use **PLACE DELIVERY ORDER** for the retained five-minute delivery flow, then collect the box beneath Pip with **E**.
7. On the first purchase, name your shop. The name is saved and appears on the storefront sign.
8. **F5** saves; **Esc → Return to Main Menu → Continue** restores the business.

**Controls:** WASD move · mouse look · Space jump · E interact · B furniture · R rotate 90° · left mouse place · right mouse cancel · Esc cancel/close/menu · F5 save.

## Player inventory and equipment

Press **I** to open your backpack and equipment panel. Approach the **Adventurer supplies** chest beside the starting position and press **E** to open the panel with a **GROUND ITEMS** grid. Items use the same-sized cells as the backpack and show only their icons and quantities; hover an item for its name and details. Drag them into the backpack grid to collect them. Drag a backpack item outside the inventory to create a loot chest on the ground; approach it and press **E** to loot it again. **R** or right-click during a drag rotates, and **Shift-drag** splits a stack. Equipping the Large Backpack first makes room to try all examples. The delivery box beneath Pip uses the same ground-items grid. Inventory saves through the existing host save system.

See [the inventory guide](inventory/README.md) for resource creation, backpack sizing, stat modifiers, architecture, controls, save format, LAN identity limitations, and tests.

## Deliveries and supply boxes

Pip's basket displays the total and available gold and blocks unaffordable orders. Each saved order arrives after **five real-world minutes**, including time while the game is closed. The ledger shows the next arrival countdown. All arrived orders share a box beneath Pip; pending orders cannot be collected early. Press **E** on the box and choose pickup quantities beside each item. If your backpack is full, the items remain in the box.

The delivery box disappears once all arrived goods have been collected and reappears when another order arrives. The Adventurer supplies chest also disappears after its last item is collected. Both empty states persist across Continue; starter supplies are not refilled on login.

Implementation: `items/delivery_orders.gd` owns prices/validation and five-minute deadlines (`DELAY_SECONDS = 300`); `ui/stock_order_panel.gd` and `ui/stock_item_card.gd` own the responsive catalogue; the existing session commits immediate `buy_item` purchases, inventory-space preflight, delivery orders and collection with the existing backed-up save system. `scripts/world.gd` derives box presence from remaining contents and updates the saved shop sign. All eight shop products have definitions and icons in `items/definitions`/`items/icons`. Old paid ledger-only saves are converted to a delivery without charging again. The cumulative `ordered_stock` ledger remains history, while `deliveries` stores remaining uncollected quantities.

Delivery tests are included in `tests/run_tests.ps1`; they fast-forward saved test deadlines rather than waiting five minutes or changing the production delay.

## Single-player development

## Stocking tables and shelves

Approach placed display furniture inside your shop and press **E**. Select backpack items, quantity and sell price, then **Stock**. The panel shows reference buy price, sell price and estimated profit, and lets you reprice or return unsold stock. Each unit takes display space according to its size; full or unsuitable displays reject the transfer safely. Stocked furniture shows individual temporary packages and a **FOR SALE** indicator. Stock and prices save with the game. See [sale-display authoring and architecture](shops/SALE_DISPLAYS.md) for capacities and the future 3D-model hook.

## Single-player development

Multiplayer is currently disabled. The menus offer New Game and Continue only, and the session rejects LAN hosting/joining before creating a connection. Existing local saves still load. The underlying networking code and historical LAN tests are retained for future work; the active test runner exercises single-player gameplay and verifies multiplayer is blocked.

### Historical LAN implementation (disabled)
On the host, choose **Host Game • LAN**. It loads the local save, or creates one if none exists. To host a fresh business, first use New Game, return to the menu, then Host Game.

On another instance/computer, enter the host's LAN IPv4 address and choose **Join Game**. Use **127.0.0.1** for two instances on this computer. The server uses **UDP 24567**, with up to **8 players**. Allow Godot on the Windows private-network firewall if prompted. There is no discovery, matchmaking, account service, or port forwarding setup.

The co-op shares **one purse, one purchased shop, furniture, and ordered stock**. The host stores the save. Guests start on the street on each connection; guest identity/position does not persist. Client movement is predicted locally and relayed at 20 Hz; remote avatars interpolate. Economy and placement transactions run on the host. Reliable snapshots initialize late joiners. Disconnecting the host returns guests to the menu.

## Files and responsibilities
- `project.godot`, `scenes/main.tscn`: boot configuration and main scene.
- `scripts/game.gd`: scene orchestration and input/interaction routing.
- `scenes/player/player.tscn`, `scripts/player.gd`: reusable first-person controller, ray interaction, remote avatar.
- `scenes/world/street.tscn`, `scripts/world.gd`, `scripts/geometry.gd`: procedural street blockout, lights, storefronts, collision.
- `shops/interior.gd`, `shops/grid_rules.gd`: 6 × 6 metre interior, 12 × 12 half-metre grid, bounds/overlap/wall validation.
- `shops/interactable.gd`, `shops/imp.gd`: doors, prompts, and animated IMP.
- `furniture/placement.gd`, `furniture/furniture_factory.gd`: colored ghost, rotation, catalog-based collision, GLB loading.
- `items/catalog.gd`: stable IDs, prices, categories, furniture footprints and eight stock products.
- `inventory/item_rarity.gd`, `items/loot_generator.gd`: shared rarity colours/scaling/progression weights and the future generated-loot entry point.
- `networking/session.gd`: ENet lifecycle, roster/poses, shared state, host transaction validation.
- `saves/save_store.gd`: schema validation, JSON loading, temporary writes, previous-save backup.
- `ui/game_ui.gd`, `ui/stock_order_panel.gd`, `ui/stock_item_card.gd`: main/pause/purchase/naming/furniture/stock menus, HUD, feedback and icon-card purchasing.
- `assets/furniture/*.glb`: six original low-poly furniture models generated through Blender MCP.
- `assets/blender/furniture_prototypes.blend`: isolated editable Blender source; original open scene preserved.
- `tests/`: repeatable gameplay and multi-process LAN tests, logs, and captured screens.

Most scene geometry is intentionally built by modular scripts at runtime. Main, street, and player are reusable scene entry points; inspect the **Remote** scene tree while playing to see generated nodes.

## Furniture
| ID | Gold | Cells | Category |
|---|---:|---:|---|
| small_table | 60 | 3 × 2 | Display |
| basic_shelf | 80 | 2 × 1 | Display |
| large_shelf | 140 | 4 × 2 | Display |
| wall_shelf | 45 | 2 × 1 | Wall |
| counter | 120 | 4 × 2 | Service |
| storage_crate | 35 | 2 × 2 | Storage |

Footprints cannot overlap walls, other furniture, the orange entrance area, or a player. Rotation swaps rectangular dimensions. Wall shelves mount 1.35 metres above the floor, with their back against a wall. Their cells remain reserved, so stacking furniture under wall shelves is not supported yet.

To add furniture, add a stable catalog entry and a matching metre-scale GLB at `assets/furniture/<id>.glb`. Use a floor-centered origin. Imported Blender models are rotated so their back aligns with grid +Z at rotation zero. The catalog owns dimensions and prices; GLBs contain only visuals. Missing GLBs intentionally fall back to clearly marked box geometry.

## Saves
Normal play writes **user://saves/lantern_lane.json** (under Godot's app data for this project). The save includes version, money, purchased_shop, the chosen `shop_name`, host player_position, furniture cell records, ordered_stock quantities, deliveries, and inventory item instances including persistent IDs and rarity. Transactions, a 20-second autosave, F5, leaving, and window close write the host save.

Writes use a temporary file and keep the previous valid file as `.bak`; loading can recover from that backup. New Game asks before replacing an existing save. There is one local save slot, and the backup is the previous write rather than a permanent archive.

## Verification
From PowerShell in the project:
```powershell
./tests/run_tests.ps1 -Godot 'C:/path/to/Godot.exe'
./tests/run_tests.ps1 -Godot 'C:/path/to/Godot.exe' -Visual
```
The default executable path matches this computer. Test saves and Godot settings are isolated in `.test-runtime`; normal saves are not touched. Tests require OS permission to launch Godot and open a local UDP socket.

The smoke test exercises actual movement/jump, interaction UI, purchase, IMP creation, interior access, ghost rotation and placement, rejection cases, ordering, persistence and corrupt-save recovery. The LAN test uses separate host, client and late-join processes to exercise real RPCs and shared world reconstruction. Detailed evidence is in `tests/VALIDATION.md`.

The networking approach follows [Godot's high-level multiplayer documentation](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html).

## Prototype limits and next step
The street, avatars, IMP and product icons are deliberate placeholders. Furniture is simple Blender art. Interiors use door teleports; only one storefront can be purchased. Multiplayer is disabled. There is no furniture removal/refund/moving, customer AI, selling, combat, crafting, quests, or complex economy yet.

**Next stock-system extension:** customer shopping and checkout, building on saved shelf listings and prices.
