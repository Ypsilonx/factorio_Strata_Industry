--- Dům: jedna entita, úroveň města určuje grafickou variantu (graphics_variation = úroveň).
local levels = require("shared.levels")

--- Odstín variant podle úrovně (dočasná grafika).
local TINTS = {
  { r = 1, g = 1, b = 1 }, { r = 0.8, g = 1, b = 0.8 }, { r = 0.8, g = 0.9, b = 1 },
  { r = 1, g = 0.85, b = 0.6 }, { r = 1, g = 0.7, b = 1 },
}
local ICON = "__base__/graphics/icons/stone-furnace.png"

local pictures = {}
for level = 1, levels.MAX_LEVEL do
  pictures[level] = { filename = ICON, size = 64, scale = 1.5, tint = TINTS[level] }
end

data:extend({
  {
    type = "simple-entity-with-owner",
    name = "rt-house",
    icon = ICON,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.5, result = "rt-house" },
    max_health = 400,
    corpse = "medium-remnants",
    collision_box = { { -1.4, -1.4 }, { 1.4, 1.4 } },
    selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } },
    render_layer = "object",
    pictures = pictures,
  },
  {
    type = "item", name = "rt-house", icon = ICON, subgroup = "rt-town", order = "a",
    place_result = "rt-house", stack_size = 20,
  },
  {
    type = "recipe", name = "rt-house", enabled = true, energy_required = 10,
    ingredients = {
      { type = "item", name = "wood", amount = 10 },
      { type = "item", name = "stone-brick", amount = 20 },
      { type = "item", name = "iron-plate", amount = 10 },
    },
    results = { { type = "item", name = "rt-house", amount = 1 } },
  },
})
