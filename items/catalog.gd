class_name Catalog
extends RefCounted
## Stable IDs are the persistence contract. Footprints use 0.5 metre cells.
const FURNITURE = {
 "small_table": {"name":"Small table", "price":60, "size":[3,2], "height":0.85, "category":"Display"},
 "basic_shelf": {"name":"Basic shelf", "price":80, "size":[2,1], "height":1.65, "category":"Display"},
 "large_shelf": {"name":"Large shelf", "price":140, "size":[4,2], "height":2.1, "category":"Display"},
 "wall_shelf": {"name":"Wall shelf", "price":45, "size":[2,1], "height":0.7, "category":"Wall", "wall":true},
 "counter": {"name":"Counter", "price":120, "size":[4,2], "height":1.1, "category":"Service"},
 "storage_crate": {"name":"Storage crate", "price":35, "size":[2,2], "height":0.75, "category":"Storage"}
}
const PRODUCTS = {
 "health_potion": {"name":"Health potion", "price":8, "category":"Potions", "icon":"HP", "color":"d95265"},
 "mana_potion": {"name":"Mana potion", "price":8, "category":"Potions", "icon":"MP", "color":"619deb"},
 "bread": {"name":"Bread", "price":3, "category":"Food", "icon":"BR", "color":"dcb579"},
 "apple": {"name":"Apples", "price":2, "category":"Food", "icon":"AP", "color":"d77156"},
 "iron_sword": {"name":"Iron sword", "price":25, "category":"Equipment", "icon":"SW", "color":"a5b6bf"},
 "wooden_shield": {"name":"Wooden shield", "price":18, "category":"Equipment", "icon":"SH", "color":"bd895d"},
 "magic_scroll": {"name":"Magic scroll", "price":12, "category":"Magic", "icon":"SC", "color":"b399dd"},
 "healing_herb": {"name":"Healing herbs", "price":5, "category":"Herbs", "icon":"HB", "color":"84b781"}
}
const SHOP_PRICE = 300
const SHOP_NAMES = ["The Copper Acorn", "Moon & Mortar", "The Wandering Quill"]

