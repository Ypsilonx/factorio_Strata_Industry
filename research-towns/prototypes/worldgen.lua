--- Generátor mapy: posuvník „Města“, pojmenované noise výrazy mřížky a značka místa města, kterou skript při
--- generování chunku nahradí radnicí (regenerate_entity v rozehrané hře tak nesáhne na existující radnice).
--- Volá se z data-final-fixes – jiný mod mohl v data-updates upravit map_gen_settings Nauvisu.
local levels = require("shared.levels")
local worldgen = require("shared.worldgen")

local half = levels.HALL_SIZE / 2

local list = {
  { type = "autoplace-control", name = worldgen.CONTROL, category = "enemy", richness = false, order = "z-[rt-towns]" },
  {
    type = "simple-entity",
    name = worldgen.SITE,
    hidden = true,
    icon = "__base__/graphics/icons/lab.png",
    flags = { "placeable-neutral", "not-blueprintable", "not-deconstructable" },
    collision_box = { { -half + 0.1, -half + 0.1 }, { half - 0.1, half - 0.1 } },
    map_color = worldgen.MAP_COLOR,
    picture = { filename = "__core__/graphics/empty.png", size = 1 },
    -- Pořadí „a“: značky se rozmístí před stromy, takže je stromy neblokují.
    autoplace = { control = worldgen.CONTROL, order = "a[rt-town]", probability_expression = "rt_town_probability" },
  },
}
for name, expression in pairs(worldgen.noise_expressions()) do
  list[#list + 1] = { type = "noise-expression", name = name, expression = expression }
end
data:extend(list)

local nauvis = data.raw.planet and data.raw.planet.nauvis
local settings = nauvis and nauvis.map_gen_settings
if settings then
  settings.autoplace_controls = settings.autoplace_controls or {}
  settings.autoplace_controls[worldgen.CONTROL] = {}
  settings.autoplace_settings = settings.autoplace_settings or {}
  settings.autoplace_settings.entity = settings.autoplace_settings.entity or { settings = {} }
  settings.autoplace_settings.entity.settings[worldgen.SITE] = {}
else
  log("research-towns: Nauvis nemá map_gen_settings – generátor města nedává, zůstane jen první město")
end
