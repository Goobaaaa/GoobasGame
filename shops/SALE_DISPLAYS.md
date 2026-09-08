# Stocking sale displays

Place a table, shelf, wall shelf, or counter through **B** inside the shop. Approach it, look at the furniture, and press **E** to open **Stock your sale display**.

The left column lists backpack items. Select quantity and **Sell/unit**, then press **Stock**. The right column lists items for sale, allows **Set price**, and returns unsold listings to the backpack with **Return all**. Equipped items must be unequipped before stocking. Closing and reopening the panel preserves saved stock and prices.

The interface shows reference buy cost, proposed sell price, potential profit per unit, and potential profit for the selected/listed quantity. Below-cost prices are allowed and highlighted. The reference is the current Pip catalog price, or item `value` when there is no catalog entry. It is **not historical purchase-cost accounting**: free starter items and price changes are not treated as recorded expenses. Creating a listing does not pay the player. Customer purchasing and checkout are future systems.

## Display space

Every physical unit uses its own rectangular footprint. A stack of 20 potions occupies 20 cells, not one cell. A 1×3 sword uses three; a 2×2 shield uses four. Shapes must fit without overlapping and cannot straddle separate shelf tiers. Valid rotation is considered automatically. Existing unit positions are retained; the placement algorithm finds free space for the newly stocked units rather than rearranging the display.

| Furniture | Grid per tier | Tiers | Total cells |
| --- | --- | --- | --- |
| Small table | 6×4 | 1 | 24 |
| Basic shelf | 4×2 | 3 | 24 |
| Large shelf | 8×3 | 4 | 96 |
| Wall shelf | 4×2 | 1 | 8 |
| Counter | 6×2 | 1 | 12 |

Furniture placement cells remain 0.5m world cells; display cells are a separate layout. Capacity and local shelf heights are configured in `SaleStock.SURFACES` in `shops/sale_stock.gd`. A storage crate is not a sale platform. Capacity limits reflect the current footprint configuration, not model bounding-box volume or vertical piles. Larger objects can leave unusable gaps even when some cells remain free.

Item resources have optional `sale_size`: leave it `(0,0)` to reuse `grid_size`, or set positive dimensions for a display footprint different from the backpack footprint. `can_rotate` applies to display placement too. Changing footprints or furniture capacities for existing saves requires a migration if it would invalidate stocked positions.

## Visuals and future models

`shops/sale_display_visual.gd` creates one local `Unit_N` anchor per unit using saved tier, x/y and rotation, transformed with the placed furniture. Each unit currently shows a simple package and its item icon where available. A small green **FOR SALE** sign and interaction prompt identify stocked furniture; empty platforms show **EMPTY DISPLAY**.

Assign the existing ItemDefinition `visual` PackedScene to render a real product at each anchor, and set `display_scale` as needed. Author it as a Node3D scene with a bottom-centred origin, metre units, and dimensions appropriate to `sale_size` and available shelf spacing. Use visual-only scenes without their own interaction colliders/scripts so the furniture remains the interaction target. There is no automatic mesh fitting; future vertical stacking/volume rules can build on the per-unit anchor layout without changing inventory ownership or pricing.

## Logic and persistence

- `shops/sale_stock.gd`: footprint rules, stock transfer, repricing, withdrawal and save validation.
- `ui/sale_platform_panel.gd`: backpack/listing controls and economic estimates.
- `shops/sale_display_visual.gd`: per-unit visual anchors and status sign.
- Existing furniture factory/interior: makes placed display furniture interactable and rebuilds its visuals.
- Existing session/save store: distance/ownership checks and atomic save transactions.

The optional `sale_stock` save field maps platform keys to listings. A listing contains the actual item instance record, unit sell price, and one placement record per quantity. Whole-item transfers preserve instance ID and custom properties; partial stacks receive a new instance ID. Returned stacks can merge normally. A platform key uses a furniture `uid` when supplied, otherwise its catalog ID and placement coordinates/rotation. Since furniture moving is not implemented, these fallback keys remain stable; a future furniture-move feature should assign permanent furniture UIDs and migrate keys before moving them.

Neither stocking nor withdrawal can silently lose items: the session works on copies, validates space, and writes inventory and display state together. If either space validation or saving fails, both sides remain unchanged. Save validation rejects duplicate ownership, out-of-bounds footprints and overlapping units. Existing saves without `sale_stock` load with empty displays.

Run `tests/run_tests.ps1` for stocking and all existing solo regressions. `tests/sale_stock.gd` covers quantities, size capacity, repricing, profit reference, custom data/IDs, failed-save rollback, full-backpack withdrawal, ray interaction, persistence and corrupt-save rejection. Visual mode captures `tests/sale-panel.png` and `tests/sale-display.png` using isolated test saves.
