class_name ItemRarity
extends RefCounted
## Central rarity presentation, balancing, and future loot-roll configuration.
## Item instances store the selected tier so generated loot can differ from its
## catalog definition without mutating shared Resource data.

const COMMON := "Common"
const RARE := "Rare"
const EPIC := "Epic"
const LEGENDARY := "Legendary"
const MYTHIC := "Mythic"
const ARTIFACT := "Artifact"
const TIERS: Array[String] = [COMMON, RARE, EPIC, LEGENDARY, MYTHIC, ARTIFACT]

const COLORS := {
	COMMON: Color("e5e7eb"),
	RARE: Color("69a7ff"),
	EPIC: Color("c084fc"),
	LEGENDARY: Color("f4a340"),
	MYTHIC: Color("f05b67"),
	ARTIFACT: Color("ffd866")
}

## These values are intentionally centralized so balance passes do not require
## changes to inventory, equipment, shop, or tooltip code.
const RULES := {
	COMMON: {"stat_multiplier":1.0, "bonus_modifiers":0, "modifier_strength":0.0, "value_multiplier":1.0, "artifact":false},
	RARE: {"stat_multiplier":1.15, "bonus_modifiers":1, "modifier_strength":1.0, "value_multiplier":1.35, "artifact":false},
	EPIC: {"stat_multiplier":1.35, "bonus_modifiers":2, "modifier_strength":1.2, "value_multiplier":1.8, "artifact":false},
	LEGENDARY: {"stat_multiplier":1.7, "bonus_modifiers":3, "modifier_strength":1.5, "value_multiplier":2.8, "artifact":false},
	MYTHIC: {"stat_multiplier":2.15, "bonus_modifiers":4, "modifier_strength":2.0, "value_multiplier":4.5, "artifact":false},
	ARTIFACT: {"stat_multiplier":2.75, "bonus_modifiers":5, "modifier_strength":3.0, "value_multiplier":10.0, "artifact":true}
}

## Loot probabilities are percentages and are deliberately data-like. Enemy,
## region, boss, difficulty, and event systems can blend or override these.
const PROGRESSION_WEIGHTS := {
	"early": {COMMON:75.0, RARE:22.0, EPIC:3.0, LEGENDARY:0.0, MYTHIC:0.0, ARTIFACT:0.0},
	"mid": {COMMON:40.0, RARE:35.0, EPIC:20.0, LEGENDARY:5.0, MYTHIC:0.0, ARTIFACT:0.0},
	"late": {COMMON:15.0, RARE:25.0, EPIC:30.0, LEGENDARY:20.0, MYTHIC:9.0, ARTIFACT:1.0}
}

static func normalize(value: String) -> String:
	var candidate := value.strip_edges().to_lower()
	for tier in TIERS:
		if tier.to_lower() == candidate: return tier
	return COMMON

static func color_for(value: String) -> Color:
	return COLORS.get(normalize(value), COLORS[COMMON])

static func rule_for(value: String) -> Dictionary:
	return RULES.get(normalize(value), RULES[COMMON]).duplicate(true)

static func weights_for_stage(stage: String) -> Dictionary:
	var key := stage.strip_edges().to_lower()
	if not PROGRESSION_WEIGHTS.has(key): key = "early"
	return PROGRESSION_WEIGHTS[key].duplicate(true)

static func weights_for_progression(progress: float) -> Dictionary:
	## Progress 0 is early game and 1 is late game. Mid-game is the midpoint.
	var value := clampf(progress, 0.0, 1.0)
	var first: Dictionary
	var second: Dictionary
	var amount: float
	if value <= 0.5:
		first = PROGRESSION_WEIGHTS.early
		second = PROGRESSION_WEIGHTS.mid
		amount = value * 2.0
	else:
		first = PROGRESSION_WEIGHTS.mid
		second = PROGRESSION_WEIGHTS.late
		amount = (value - 0.5) * 2.0
	var result := {}
	for tier in TIERS:
		result[tier] = lerpf(float(first[tier]), float(second[tier]), amount)
	return result

static func roll(rng: RandomNumberGenerator, weights: Dictionary = {}) -> String:
	var source := weights if not weights.is_empty() else weights_for_stage("early")
	var total := 0.0
	for tier in TIERS: total += maxf(0.0, float(source.get(tier, 0.0)))
	if total <= 0.0: return COMMON
	var generator := rng
	if generator == null:
		generator = RandomNumberGenerator.new()
		generator.randomize()
	var pick := generator.randf_range(0.0, total)
	for tier in TIERS:
		pick -= maxf(0.0, float(source.get(tier, 0.0)))
		if pick <= 0.0: return tier
	return TIERS.back()
