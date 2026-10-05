--- Prototyp radnice: laboratoř 15×15 odvozená z vanilla laboratoře; úroveň mění vědy, rychlost a vzhled.
local levels = require("shared.levels")
local placeholder = require("prototypes.placeholder")

local M = {}

--- Odstín dočasné grafiky podle varianty (levels.variant).
M.TINTS = {
  { r = 1, g = 1, b = 1 }, { r = 0.8, g = 1, b = 0.8 }, { r = 0.8, g = 0.9, b = 1 },
  { r = 1, g = 0.85, b = 0.6 }, { r = 1, g = 0.7, b = 1 },
}

--- Přidá prototyp radnice dané vědecké úrovně.
--- @param level integer 1..count
--- @param count integer počet vědeckých úrovní
--- @param sciences string[] vědy, které radnice přijímá
function M.create(level, count, sciences)
  local base = data.raw.lab["lab"]
  local half = levels.HALL_SIZE / 2
  local factor = levels.HALL_SIZE / 3
  local tint = M.TINTS[levels.variant(level, count)]
  local hall = table.deepcopy(base)
  hall.name = levels.hall_name(level)
  -- Jedno jméno pro všechny úrovně (počet úrovní závisí na modech); číslo úrovně jde parametrem.
  hall.localised_name = { "entity-name.rt-town-hall", tostring(level) }
  hall.localised_description = { "entity-description.rt-town-hall" }
  hall.icons = { { icon = base.icon, icon_size = base.icon_size, tint = tint } }
  hall.icon = nil
  -- get-by-unit-number: remote town_status vrací unit_number radnice, jiné mody ji podle něj dohledají.
  hall.flags = { "not-blueprintable", "not-deconstructable", "not-rotatable", "get-by-unit-number" }
  hall.minable = nil
  hall.placeable_by = nil
  hall.fast_replaceable_group = nil
  hall.next_upgrade = nil
  hall.max_health = 3000
  hall.collision_box = { { -half + 0.1, -half + 0.1 }, { half - 0.1, half - 0.1 } }
  hall.selection_box = { { -half, -half }, { half, half } }
  hall.on_animation = placeholder.scaled(base.on_animation, factor, tint)
  hall.off_animation = placeholder.scaled(base.off_animation, factor, tint)
  -- Elektřinu města odebírají rozvodny; radnici zapíná/vypíná skript (disabled_by_script).
  hall.energy_source = { type = "void" }
  hall.energy_usage = "1W"
  hall.researching_speed = levels.researching_speed(level, count)
  hall.inputs = sciences
  hall.allowed_effects = { "speed", "productivity", "consumption", "pollution" }
  data:extend({ hall })
end

return M
