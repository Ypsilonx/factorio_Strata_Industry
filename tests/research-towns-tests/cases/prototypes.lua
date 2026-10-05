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
    local reach = {
      ["rt-goods-depot"] = levels.DEPOT_REACH, ["rt-fluid-depot"] = levels.DEPOT_REACH,
      ["rt-power-depot"] = levels.DEPOT_REACH, ["rt-house"] = levels.HOUSE_REACH,
    }
    for name, distance in pairs(reach) do
      local proto = prototypes.entity[name]
      local spec = proto.radius_visualisation_specification
      local half = proto.selection_box.right_bottom.x
      H.check(spec and math.abs(spec.distance - (half + distance)) < 1e-6,
        name .. ": dosah " .. serpent.line(spec and spec.distance) .. " ≠ " .. (half + distance))
    end
  end } } },
  { name = "výzkum červené vědy se spouští vyrobením domu", steps = { { ticks = 1, run = function()
    local trigger = prototypes.technology["automation-science-pack"].research_trigger
    H.check(serpent.line(trigger):find("rt-house", 1, true), "spouštěč: " .. serpent.line(trigger))
    H.check(prototypes.recipe["lab"].hidden, "recept laboratoře není skrytý")
  end } } },
}
