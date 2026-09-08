# Lantern Lane stylised material pass

These are original material sources created for Lantern Lane's PC visual upgrade. They are intended to evoke a cosy fantasy workshop/alchemy district without copying assets from Alchemy Factory or another game.

## Materials
- `wood_planks_albedo.svg` — timber beams, floors, signs and roof surfaces.
- `stone_floor_albedo.svg` — street paving and masonry floors.
- `plaster_wall_albedo.svg` — warm medieval plaster facades and interior walls.
- `aged_brass_albedo.svg` — trim, lanterns and alchemy/mechanical accents.

The game loads them through `scripts/material_library.gd`, which caches shared `StandardMaterial3D` resources and uses world-space triplanar mapping so the current procedural blockout can receive textures without individually authored UVs.

## Art direction
Target a readable, cosy first-person fantasy-shop look: chunky silhouettes, warm plaster and timber, stone foundations, aged brass accents, warm practical lighting, and brighter magical/potion colours layered on top. Keep materials stylised rather than photorealistic.

## Future PBR pass
For final production assets, replace or extend these source textures with authored 2K albedo/normal/roughness maps while keeping the same material names and shared-material workflow.
