--- Dům: jedna entita, grafická varianta (graphics_variation) = úroveň domu (levels.house_variant).
--- Grafika z Blenderu (blender/build_hall.py --house N): základ, okna svítící v noci a stín.
local levels = require("shared.levels")
local reach = require("prototypes.reach")
local sprites = require("prototypes.house_sprites")

local GRAPHICS = "__research-towns__/graphics/"
local ICON = GRAPHICS .. "icons/house-1.png"
--- Výběrový obdélník domu 3×3 (sdílí ho i vizualizace dosahu).
local SELECTION = { { -1.5, -1.5 }, { 1.5, 1.5 } }

--- Vrstva spritu domu vzhledu variant (name = "base" | "light" | "shadow").
local function layer(variant, name)
  return {
    filename = GRAPHICS .. "entity/house/house-" .. variant .. "-" .. name .. ".png",
    width = sprites.width,
    height = sprites.height,
    shift = sprites.shift,
    scale = sprites.scale,
    draw_as_shadow = name == "shadow" or nil,
    draw_as_light = name == "light" or nil,
    blend_mode = name == "light" and "additive" or nil,
  }
end

--- Vzhledy domu: obytný dům má okna rozsvícená v noci trvale (světelná vrstva se kreslí jen ve tmě).
local pictures = {}
for variant = 1, levels.VARIANTS do
  pictures[variant] = { layers = { layer(variant, "base"), layer(variant, "light"), layer(variant, "shadow") } }
end

data:extend({
  {
    type = "simple-entity-with-owner",
    name = "rt-house",
    icon = ICON, icon_size = 64,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.5, result = "rt-house" },
    max_health = 400,
    corpse = "medium-remnants",
    collision_box = { { -1.4, -1.4 }, { 1.4, 1.4 } },
    selection_box = SELECTION,
    render_layer = "object",
    pictures = pictures,
    radius_visualisation_specification = reach.spec({ selection_box = SELECTION }, levels.HOUSE_REACH),
  },
  {
    type = "item", name = "rt-house", icon = ICON, icon_size = 64, subgroup = "rt-town", order = "a",
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
