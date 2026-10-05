--- Překladiště: zboží (bedna), kapaliny (nádrž) a městská rozvodna (spotřebič elektřiny).
--- Odvozené z vanilla prototypů; skript je přiřadí k nejbližšímu městu.
local placeholder = require("prototypes.placeholder")

local TINT = { r = 0.9, g = 0.75, b = 0.5 }

--- Odvodí prototyp z vanilla entity: nové jméno, vlastní předmět, obarvená ikona, bez upgradů.
local function derive(source, name)
  local entity = table.deepcopy(source)
  entity.name = name
  entity.hidden = nil
  entity.minable = { mining_time = 0.3, result = name }
  -- Zdroj má buď `icon`, nebo vrstvy `icons` (např. electric-energy-interface).
  local layers = source.icons and table.deepcopy(source.icons) or { { icon = source.icon, icon_size = source.icon_size } }
  for _, layer in ipairs(layers) do layer.tint = TINT end
  entity.icons = layers
  entity.icon = nil
  entity.fast_replaceable_group = nil
  entity.next_upgrade = nil
  return entity
end

local goods = derive(data.raw.container["iron-chest"], "rt-goods-depot")
goods.inventory_size = 48
goods.picture = placeholder.scaled(goods.picture, 1, TINT)

local fluid = derive(data.raw["storage-tank"]["storage-tank"], "rt-fluid-depot")

local power = derive(data.raw["electric-energy-interface"]["electric-energy-interface"], "rt-power-depot")
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

data:extend({ goods, fluid, power })
data:extend({ item_and_recipe(goods, "b", {
  { type = "item", name = "iron-chest", amount = 2 }, { type = "item", name = "iron-gear-wheel", amount = 5 } }) })
data:extend({ item_and_recipe(fluid, "c", {
  { type = "item", name = "pipe", amount = 10 }, { type = "item", name = "iron-plate", amount = 20 },
  { type = "item", name = "stone-brick", amount = 10 } }) })
data:extend({ item_and_recipe(power, "d", {
  { type = "item", name = "copper-cable", amount = 20 }, { type = "item", name = "iron-plate", amount = 10 },
  { type = "item", name = "stone-brick", amount = 10 } }) })
