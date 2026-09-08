# Lantern Lane — playable foundation

Open **project.godot** in Godot 4 and press **F6** on `scenes/main.tscn`, or **F5** from any scene. Tested with the installed **Godot 4.7.2**, using the Compatibility renderer. No addons or external art downloads are required at runtime.

## First play
1. Choose **New Game**. You start on the street with **1,000 gold**.
2. Walk to any of the three shop doors. Look at it, press **E**, and buy the deed for **300 gold**.
3. Press **E** at the same door to enter. **B** opens the furniture catalog.
4. Choose furniture, look down at the grid, rotate with **R**, then left-click a green preview to place it.
5. Look at the inside door and press **E** to leave. Find **Pip**, the floating purple IMP beside your shop, and press **E**.
6. Choose stock quantities and click **Order**. Your purse and order ledger update immediately.
7. **F5** saves; **Esc → Return to Main Menu → Continue** restores the business.

**Controls:** WASD move · mouse look · Space jump · E interact · B furniture · R rotate 90° · left mouse place · right mouse cancel · Esc cancel/close/menu · F5 save.

## LAN co-op
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
- `networking/session.gd`: ENet lifecycle, roster/poses, shared state, host transaction validation.
- `saves/save_store.gd`: schema validation, JSON loading, temporary writes, previous-save backup.
- `ui/game_ui.gd`: main/pause/purchase/furniture/stock menus, HUD and feedback.
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
Normal play writes **user://saves/lantern_lane.json** (under Godot's app data for this project). The save includes version, money, purchased_shop, host player_position, furniture cell records, and ordered_stock quantities. Transactions, a 20-second autosave, F5, leaving, and window close write the host save.

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
The street, avatars, IMP and product icons are deliberate placeholders. Furniture is simple Blender art. Interiors use door teleports; only one of the three storefronts can be purchased per co-op. There is no furniture removal/refund/moving, guest save identity, host migration, anti-cheat movement, physical stock delivery, customer AI, selling, combat, crafting, quests, or complex economy.

**Recommended next step:** add a physical stock-delivery crate and shelf stocking, using the existing product IDs and order ledger. This creates a useful stock lifecycle before introducing customers and sales.

