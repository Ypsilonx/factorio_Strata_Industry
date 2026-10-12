--- Kontroly prototypů pro vanillu a Space Age.
local levels = require("__research-towns__/shared/levels")
local H = require("helpers")

return {
  { name = "úroveň 1 přijímá jen červenou vědu, úroveň 2 i zelenou", steps = { { ticks = 1, run = function()
    local first = prototypes.entity[levels.hall_name(1)].lab_inputs
    H.check(#first == 1 and first[1] == "automation-science-pack", "úroveň 1: " .. serpent.line(first))
    local second = prototypes.entity[levels.hall_name(2)].lab_inputs
    local has_green = false
    for _, name in ipairs(second) do has_green = has_green or name == "logistic-science-pack" end
    H.check(has_green, "úroveň 2 bez zelené: " .. serpent.line(second))
  end } } },
  { name = "překladiště a dům ukazují dosah", steps = { { ticks = 1, run = function()
    -- Městská rozvodna je sloup – hra u něj ukazuje plochu napájení, ne vlastní vizualizaci dosahu.
    local reach = {
      ["rt-goods-depot"] = levels.DEPOT_REACH, ["rt-fluid-depot"] = levels.DEPOT_REACH,
      ["rt-house"] = levels.HOUSE_REACH,
    }
    for name, distance in pairs(reach) do
      local proto = prototypes.entity[name]
      local spec = proto.radius_visualisation_specification
      local half = proto.selection_box.right_bottom.x
      H.check(spec and math.abs(spec.distance - (half + distance)) < 1e-6,
        name .. ": dosah " .. serpent.line(spec and spec.distance) .. " ≠ " .. (half + distance))
    end
  end } } },
  { name = "rychlost radnice roste od první do poslední vědy", steps = { { ticks = 1, run = function()
    local count = H.level_count()
    local first = prototypes.entity[levels.hall_name(1)].get_researching_speed()
    local last = prototypes.entity[levels.hall_name(count)].get_researching_speed()
    H.check(math.abs(first - levels.SPEED_FIRST) < 1e-6, "rychlost úrovně 1: " .. first)
    H.check(math.abs(last - levels.SPEED_LAST) < 1e-6, "rychlost úrovně " .. count .. ": " .. last)
  end } } },
  { name = "výzkum červené vědy se spouští vyrobením domu", steps = { { ticks = 1, run = function()
    local trigger = prototypes.technology["automation-science-pack"].research_trigger
    H.check(serpent.line(trigger):find("rt-house", 1, true), "spouštěč: " .. serpent.line(trigger))
    H.check(prototypes.recipe["lab"].hidden, "recept laboratoře není skrytý")
  end } } },
  { name = "laboratoř v cizím receptu rozložená na suroviny (i v recyklaci)", steps = { { ticks = 1, run = function()
    -- Hra suroviny receptu řadí po svém – porovnat seřazené.
    local got = {}
    for _, ingredient in ipairs(prototypes.recipe["rt-test-lab-user"].ingredients) do
      got[#got + 1] = ingredient.name .. "×" .. ingredient.amount
    end
    table.sort(got)
    H.check(table.concat(got, ",") == "electronic-circuit×21,iron-gear-wheel×20,iron-plate×3,transport-belt×8",
      "suroviny: " .. table.concat(got, ","))
    local recycling = prototypes.recipe["rt-test-lab-user-recycling"]
    if script.active_mods["quality"] then
      H.check(recycling and recycling.enabled, "recyklace chybí nebo je vypnutá")
      local products = {}
      for _, product in ipairs(recycling.products) do products[product.name] = true end
      H.check(products["electronic-circuit"] and not products["lab"], "recyklace: " .. serpent.line(recycling.products))
    end
  end } } },
}
