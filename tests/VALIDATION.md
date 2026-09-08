# Validation — 2026-09-08

## Sale platforms — latest run

The full solo runner passed **27 stocking checks + 33 delivery checks + 123 inventory checks + 64 gameplay checks = 247 checks**, zero failures. Stocking tests cover per-unit size/quantity limits, partial-stack transfers, unique properties/IDs, repricing, buy reference and estimated profit, no premature gold award, failure rollback, full-backpack withdrawal, rotated-table ray interaction, FOR SALE prompts, save/reload, invalid overlap and duplicate ownership. The rendered stocking test also passed; `sale-panel.png` and `sale-display.png` were inspected. Normal saves were not touched.

## Timed delivery system — latest run

33 delivery checks passed in the rendered test, including basket totals/affordability, five-minute deadline boundaries, delayed physical appearance beneath Pip, actual player-ray targeting, premature/distant/duplicate pickup rejection, full-backpack conservation, order/pickup save-failure rollback, partial collection across reload, consecutive arrivals, both kinds of empty-box cleanup, and migration of previously paid ledger stock. Deadlines were advanced in isolated test state; the production delay remains 300 seconds. Order UI and physical box screenshots (`delivery-order.png`, `delivery-box.png`) were inspected. Rendered log: `delivery-visual.log`, no script errors.

The full single-player runner also passed the 123 inventory/mode/tooltip checks and 64 gameplay checks. The inventory integration check opens the same-sized ground-items grid, drags a footprint-sized item into an exact backpack cell, creates a saved ground chest by dragging outside the backpack, re-loots the original item, verifies it is interactable, and confirms it disappears after its last item is collected. The same run now covers all six rarity tiers, rarity stat scaling, near-instant tooltip timing, the icon-card Pip catalogue, quantity controls, and player shop naming/sign persistence. The rendered inventory and stock captures were inspected. Normal player saves were not used.

## Single-player and inventory crash fix — latest run

The user's normal `logs/godot.log` reports `Invalid access to property or key 'id' on a base object of type 'Dictionary'`, at `ui/item_tooltip.gd:16`, called by `InventoryBoard._make_custom_tooltip`. This is a script failure in the delayed tooltip path, not evidence of a native engine crash. Moving to empty space or refreshing inventory can invalidate hover data before the custom tooltip callback. The tooltip now rejects empty/unknown records and the board checks that the requested item/text still matches current inventory before constructing it.

Multiplayer menus are removed and both host/join APIs return `ERR_UNAVAILABLE` before network setup. The local session, save schema, and historical LAN implementation remain available for future development. The active runner no longer launches LAN tests.

Latest headless verification: **123 inventory/mode/tooltip checks + 64 gameplay checks passed**, with no script errors. Test saves are isolated in `.test-runtime`. The earlier evidence below describes historical runs before this change.

## Inventory extension verification — subsequent run

Godot 4.7.2 on Windows, with rendered inventory verification on NVIDIA RTX 3060 Ti. The updated runner passed **84 inventory checks**, **48 existing gameplay checks**, and **30 host/client/late-join checks**, all with zero failures. The rendered inventory run also passed all 84 checks; [inventory.png](inventory.png) was inspected for panel layout, grid dimensions, equipment, icons, stack counts, and pickup controls.

Inventory coverage includes pickup and overflow stacks, splitting, partial merges, grid/equipment swaps, rotation and nonrotatable definitions, bounds and overlap rejection, requirements, combined positive/negative stats, 6×4/8×5/10×6 packs, safe shrink/repacking, rejected smaller packs with exact unchanged state, failed-save rollback, custom properties, malformed data, duplicate IDs, JSON round trips, legacy saves, Continue, mouse press/move/release through the viewport, panel open/close, host pickup distance checks, and guest pickup/equip/stat replication with independent inventories.

Logs: `inventory.log`, `inventory-visual.log`, `smoke.log`, and `lan-{host,client,late}.log`. Headless runs report an environment-specific root certificate store error at engine startup; there were no script errors or failed assertions. The rendered run reports no errors. Saves/settings were isolated under `.test-runtime`; normal player saves were not used.

The following sections retain the original foundation's earlier validation evidence.

Verified using Godot 4.7.2 stable on Windows with the Compatibility renderer. Rendered smoke tests used the NVIDIA RTX 4090; the final regression suite also passed headlessly.

## Results

- Godot editor import: completed with no script/import errors in the final import log.
- Main scene: starts successfully.
- Solo smoke suite: zero failures.
- Separate-process ENet host, guest, and late joiner: zero failures.
- Final logs scanned for ERROR, FAIL, and WARNING: no matches.
- Test data/settings isolated under .test-runtime; normal user saves were not used.

## Gameplay checks

Main menu and new save; street spawn; first-person movement, floor collision and jumping; camera-ray shop prompt; E purchase UI; locked interior rejection; 300-gold purchase; duplicate purchase rejection; IMP appears only after ownership; entering and leaving the shop; B furniture catalog; floor ghost; 90-degree rotation; rotated 3×2 footprint; successful placement and payment; overlap, wall bounds and reserved entrance checks; wall shelf adjacency; six imported GLBs with collision; cancel; eight stock menu products; order quantity and payment; insufficient funds, invalid quantity and remote order rejection; saved position, ownership, furniture and stock restoration; malformed JSON backup recovery.

## Multiplayer checks

Real ENet sockets on localhost UDP 24567 with separate operating-system processes. Host/client registration; remote player instances; guest movement received by host; host movement interpolated on guest; guest purchase validated and shared; IMP on both peers; guest orders; server-issued interior teleport; guest furniture placement; guest save feedback; late-join ownership, furniture, orders and IMP; disconnected guests removed.

Cross-computer LAN connectivity, packet-loss simulation and hostile-client testing were not performed. The prototype trusts owner movement and is intended for cooperative LAN use.

## Evidence

- [Import log](import.log)
- [Gameplay log](smoke.log)
- [Host log](lan-host.log)
- [Guest log](lan-client.log)
- [Late join log](lan-late.log)
- [Main menu](01_menu.png)
- [Purchased storefront](02_street.png)
- [Grid placement](03_placement.png)
- [Stock menu](04_stock.png)

Screenshots were visually inspected for menu layout, readable controls, geometry, ghost alignment and stock rows. The final code-only change added explicit save feedback for guests; the regression suite passed after that change.

Run tests with `./tests/run_tests.ps1` (override `-Godot` for another engine path). Add `-Visual` to regenerate rendered screenshots.
