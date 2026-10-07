--- Ruina radnice: zůstane po radnici zničené biteri (scripts/towns.lua). Laboratoř 15×15 odvozená z vanilla
--- laboratoře, aby se u ní otevřel panel města (cena obnovy); skript ji drží vypnutou a nezničitelnou.
--- Jeden prototyp na každý vzhled radnice – ruina vypadá jako zničené město, které tam stálo.
local levels = require("shared.levels")
local sprites = require("prototypes.hall_sprites")

local GRAPHICS = "__research-towns__/graphics/"

--- Vrstva spritu ruiny vzhledu variant (name = "base" | "shadow").
local function layer(variant, name)
  return {
    filename = GRAPHICS .. "entity/ruin/ruin-" .. variant .. "-" .. name .. ".png",
    width = sprites.width,
    height = sprites.height,
    shift = sprites.shift,
    scale = sprites.scale,
    draw_as_shadow = name == "shadow" or nil,
  }
end

local half = levels.HALL_SIZE / 2
for variant = 1, levels.VARIANTS do
  local ruin = table.deepcopy(data.raw.lab["lab"])
  ruin.name = levels.ruin_name(variant)
  ruin.localised_name = { "entity-name.rt-town-ruin" }
  ruin.localised_description = { "entity-description.rt-town-ruin" }
  ruin.icon = GRAPHICS .. "icons/hall-" .. variant .. ".png"
  ruin.icon_size = 64
  ruin.icons = nil
  ruin.flags = { "not-blueprintable", "not-deconstructable", "not-rotatable", "get-by-unit-number" }
  ruin.minable = nil
  ruin.placeable_by = nil
  ruin.corpse = nil
  ruin.fast_replaceable_group = nil
  ruin.next_upgrade = nil
  ruin.collision_box = { { -half + 0.1, -half + 0.1 }, { half - 0.1, half - 0.1 } }
  ruin.selection_box = { { -half, -half }, { half, half } }
  ruin.map_color = { r = 0.35, g = 0.3, b = 0.28 }
  local picture = { layers = { layer(variant, "base"), layer(variant, "shadow") } }
  ruin.on_animation = picture
  ruin.off_animation = picture
  ruin.light = nil
  ruin.energy_source = { type = "void" }
  ruin.energy_usage = "1W"
  -- Nepřijímá vědu ani moduly – je to jen místo obnovy.
  ruin.inputs = {}
  ruin.module_slots = 0
  ruin.allowed_effects = nil
  ruin.hidden = true
  data:extend({ ruin })
end
