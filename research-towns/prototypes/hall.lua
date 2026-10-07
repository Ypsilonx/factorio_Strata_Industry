--- Prototyp radnice: laboratoř 15×15 odvozená z vanilla laboratoře; úroveň mění vědy, rychlost a vzhled.
--- Grafika z Blenderu (blender/build_hall.py): vzhled podle levels.variant, vrstvy základ, světla a stín.
local levels = require("shared.levels")
local worldgen = require("shared.worldgen")
local sprites = require("prototypes.hall_sprites")

local M = {}

local GRAPHICS = "__research-towns__/graphics/"

--- Vrstva spritu radnice vzhledu variant (layer = "base" | "light" | "shadow").
local function layer(variant, name)
  return {
    filename = GRAPHICS .. "entity/hall/hall-" .. variant .. "-" .. name .. ".png",
    width = sprites.width,
    height = sprites.height,
    shift = sprites.shift,
    scale = sprites.scale,
    draw_as_shadow = name == "shadow" or nil,
    draw_as_light = name == "light" or nil,
    blend_mode = name == "light" and "additive" or nil,
  }
end

--- Animace radnice: vypnutá = základ + stín, zapnutá (zkoumá) navíc svítí okna a lampy.
local function animation(variant, on)
  local layers = { layer(variant, "base") }
  if on then layers[#layers + 1] = layer(variant, "light") end
  layers[#layers + 1] = layer(variant, "shadow")
  return { layers = layers }
end

--- Přidá prototyp radnice dané vědecké úrovně.
--- @param level integer 1..count
--- @param count integer počet vědeckých úrovní
--- @param sciences string[] vědy, které radnice přijímá
function M.create(level, count, sciences)
  local base = data.raw.lab["lab"]
  local half = levels.HALL_SIZE / 2
  local variant = levels.variant(level, count)
  local hall = table.deepcopy(base)
  hall.name = levels.hall_name(level)
  -- Jedno jméno pro všechny úrovně (počet úrovní závisí na modech); číslo úrovně jde parametrem.
  hall.localised_name = { "entity-name.rt-town-hall", tostring(level) }
  hall.localised_description = { "entity-description.rt-town-hall" }
  hall.icon = GRAPHICS .. "icons/hall-" .. variant .. ".png"
  hall.icon_size = 64
  hall.icons = nil
  -- get-by-unit-number: remote town_status vrací unit_number radnice, jiné mody ji podle něj dohledají.
  hall.flags = { "not-blueprintable", "not-deconstructable", "not-rotatable", "get-by-unit-number" }
  hall.minable = nil
  hall.placeable_by = nil
  hall.fast_replaceable_group = nil
  hall.next_upgrade = nil
  hall.max_health = 3000
  -- Barva na mapě i v náhledu mapy (stejná jako značka místa města).
  hall.map_color = worldgen.MAP_COLOR
  hall.collision_box = { { -half + 0.1, -half + 0.1 }, { half - 0.1, half - 0.1 } }
  hall.selection_box = { { -half, -half }, { half, half } }
  hall.on_animation = animation(variant, true)
  hall.off_animation = animation(variant, false)
  -- Elektřinu města odebírají rozvodny; radnici zapíná/vypíná skript (disabled_by_script).
  -- Při výzkumu pohlcuje znečištění (záporné emise; počítají se jen při spotřebě, tedy když radnice zkoumá).
  local absorb = levels.hall_absorption(level, count) * settings.startup["rt-pollution-absorption"].value
  hall.energy_source = { type = "void", emissions_per_minute = { pollution = -absorb } }
  hall.energy_usage = "1W"
  hall.researching_speed = levels.researching_speed(level, count)
  hall.inputs = sciences
  hall.allowed_effects = { "speed", "productivity", "consumption", "pollution" }
  data:extend({ hall })
end

return M
