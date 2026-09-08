# Validation — 2026-09-08

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


