--- Překladiště: zboží (bedna), kapaliny (káď), městská rozvodna (spotřebič elektřiny) a městská tabule.
--- Chování odvozené z vanilla prototypů, grafika z Blenderu (blender/build_hall.py --depots); skript je
--- přiřadí k nejbližšímu městu.
local levels = require("shared.levels")
local reach = require("prototypes.reach")
local sprites = require("prototypes.depot_sprites")

local GRAPHICS = "__research-towns__/graphics/"

--- Vrstvy spritu překladiště: základ, světla (draw_as_light) a stín.
local function picture(name)
  local entry = sprites[name]
  local layers = {}
  for _, layer in ipairs({ "base", "light", "shadow" }) do
    layers[#layers + 1] = {
      filename = GRAPHICS .. "entity/depots/" .. name .. "-" .. layer .. ".png",
      width = entry.width, height = entry.height, shift = entry.shift, scale = entry.scale,
      draw_as_shadow = layer == "shadow" or nil,
      draw_as_light = layer == "light" or nil,
      blend_mode = layer == "light" and "additive" or nil,
    }
  end
  return { layers = layers }
end

--- Odvodí prototyp z vanilla entity: nové jméno, vlastní předmět a ikona z Blenderu, bez upgradů.
local function derive(source, name)
  local entity = table.deepcopy(source)
  entity.name = name
  entity.hidden = nil
  entity.minable = { mining_time = 0.3, result = name }
  entity.icons = { { icon = GRAPHICS .. "icons/" .. name .. ".png", icon_size = 64 } }
  entity.icon = nil
  entity.fast_replaceable_group = nil
  entity.next_upgrade = nil
  entity.radius_visualisation_specification = reach.spec(entity, levels.DEPOT_REACH)
  return entity
end

-- Sklad 2×2 (bedna 1×1 byla na zboží, regál a palety moc malá).
local goods = derive(data.raw.container["iron-chest"], "rt-goods-depot")
goods.collision_box = { { -0.9, -0.9 }, { 0.9, 0.9 } }
goods.selection_box = { { -1, -1 }, { 1, 1 } }
goods.radius_visualisation_specification = reach.spec(goods, levels.DEPOT_REACH)
goods.inventory_size = 48
goods.picture = picture("rt-goods-depot")

-- Káď: stejný obrázek pro všechny směry (potrubní nástavce jsou ve všech čtyřech rozích); kapalina je vidět
-- v průzoru (window_bounding_box spočítaný z modelu), vanilla tmavé pozadí okénka se nekreslí.
local fluid = derive(data.raw["storage-tank"]["storage-tank"], "rt-fluid-depot")
fluid.pictures.picture = picture("rt-fluid-depot")
fluid.pictures.window_background = { filename = "__core__/graphics/empty.png", size = 1 }
fluid.window_bounding_box = sprites.gauge

-- Městská tabule: konstantní kombinátor, jehož signály plní skript podle režimu (viz scripts/board.lua).
-- Dráty se připínají na levý sloupek, kontrolka svítí v lucerně (body z modelu, stejné pro všechny směry).
local board = derive(data.raw["constant-combinator"]["constant-combinator"], "rt-town-board")
board.sprites = picture("rt-town-board")
local wire, lamp = sprites.board_wire, sprites.board_lamp
local point = {
  wire = { red = { wire[1] - 0.04, wire[2] }, green = { wire[1] + 0.04, wire[2] } },
  shadow = { red = { wire[1] + 0.9, wire[2] + 1.1 }, green = { wire[1] + 0.98, wire[2] + 1.1 } },
}
board.circuit_wire_connection_points = { point, point, point, point }
local led = { filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-S.png",
  width = 14, height = 12, scale = 0.5, shift = lamp }
board.activity_led_sprites = led
board.activity_led_light_offsets = { lamp, lamp, lamp, lamp }

local power = derive(data.raw["electric-energy-interface"]["electric-energy-interface"], "rt-power-depot")
power.picture = picture("rt-power-depot")
power.animation = nil
power.continuous_animation = nil
power.flags = { "placeable-neutral", "player-creation" }
power.gui_mode = "none"
power.energy_production = "0W"
power.energy_usage = "0W"
-- Odběr (power_usage) a zásobník nastavuje skript podle úrovně města; limit toku jen omezuje špičku.
power.energy_source = {
  type = "electric", usage_priority = "secondary-input",
  buffer_capacity = "1MJ", input_flow_limit = "2GW", output_flow_limit = "0W",
}

--- Předmět a recept překladiště.
local function item_and_recipe(entity, order, ingredients)
  return {
    type = "item", name = entity.name, icons = entity.icons, subgroup = "rt-town", order = order,
    place_result = entity.name, stack_size = 50,
  }, {
    type = "recipe", name = entity.name, enabled = true, energy_required = 2, ingredients = ingredients,
    results = { { type = "item", name = entity.name, amount = 1 } },
  }
end

data:extend({ goods, fluid, power, board })
data:extend({ item_and_recipe(goods, "b", {
  { type = "item", name = "iron-chest", amount = 2 }, { type = "item", name = "iron-gear-wheel", amount = 5 } }) })
data:extend({ item_and_recipe(fluid, "c", {
  { type = "item", name = "pipe", amount = 10 }, { type = "item", name = "iron-plate", amount = 20 },
  { type = "item", name = "stone-brick", amount = 10 } }) })
data:extend({ item_and_recipe(power, "d", {
  { type = "item", name = "copper-cable", amount = 20 }, { type = "item", name = "iron-plate", amount = 10 },
  { type = "item", name = "stone-brick", amount = 10 } }) })
data:extend({ item_and_recipe(board, "e", {
  { type = "item", name = "copper-cable", amount = 10 }, { type = "item", name = "iron-plate", amount = 5 },
  { type = "item", name = "stone-brick", amount = 5 } }) })
