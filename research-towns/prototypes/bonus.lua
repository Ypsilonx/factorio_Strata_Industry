--- Skrytý beacon uprostřed radnice: moduly rychlosti (bonus za domy) a produktivity (nekonečné úrovně).
local levels = require("shared.levels")

local beacon = table.deepcopy(data.raw.beacon["beacon"])
beacon.name = "rt-hall-beacon"
beacon.hidden = true
beacon.minable = nil
beacon.flags = { "not-on-map", "not-blueprintable", "not-deconstructable", "no-copy-paste",
  "not-selectable-in-game", "hide-alt-info", "placeable-off-grid" }
beacon.collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } }
beacon.collision_mask = { layers = {} }
beacon.selection_box = nil
-- Dosah 7 od středu pokryje radnici (±7.4), ale ne sousední stroje (začínají na ±7.5).
beacon.supply_area_distance = math.floor(levels.HALL_SIZE / 2)
beacon.energy_source = { type = "void" }
beacon.energy_usage = "1W"
beacon.module_slots = levels.BONUS_SLOTS
beacon.allowed_module_categories = { "rt-bonus" }
beacon.allowed_effects = { "speed", "productivity" }
beacon.distribution_effectivity = 1
beacon.distribution_effectivity_bonus_per_quality_level = 0
beacon.profile = { 1 }
beacon.beacon_counter = "same_type"
beacon.graphics_set = nil
beacon.radius_visualisation_picture = nil
beacon.water_reflection = nil
beacon.icons_positioning = nil

data:extend({
  { type = "module-category", name = "rt-bonus" },
  {
    type = "module", name = "rt-bonus-module", icon = "__base__/graphics/icons/speed-module.png",
    hidden = true, subgroup = "rt-town", category = "rt-bonus", tier = 1, stack_size = 200,
    effect = { speed = levels.BONUS_STEP },
  },
  {
    type = "module", name = "rt-productivity-module", icon = "__base__/graphics/icons/productivity-module.png",
    hidden = true, subgroup = "rt-town", category = "rt-bonus", tier = 1, stack_size = 200,
    effect = { productivity = levels.BONUS_STEP },
  },
  beacon,
})
