--- Jednotkové testy rozdělení dodávky mezi příjemce podle priority.
local A = require("assert")
local allocation = require("scripts.allocation")

--- Příjemce s jedním požadavkem na dřevo.
local function sink(amount, have)
  return { requirements = { { type = "item", name = "wood", amount = amount } }, progress = { ["item/wood"] = have } }
end

return {
  { "dodávka jde nejdřív prvnímu příjemci, zbytek dalšímu", function()
    local first, second = sink(100, 0), sink(50, 0)
    local sinks = { first, second }
    A.eq(allocation.wanted(sinks, "item", "wood", 1000), 150, "chtějí celkem")
    allocation.distribute(sinks, "item", "wood", 120)
    A.eq(first.progress["item/wood"], 100, "první naplněn")
    A.eq(second.progress["item/wood"], 20, "druhý dostal zbytek")
  end },
  { "málo suroviny dostane jen první", function()
    local first, second = sink(100, 90), sink(50, 0)
    allocation.distribute({ first, second }, "item", "wood", 5)
    A.eq(first.progress["item/wood"], 95, "první")
    A.eq(second.progress["item/wood"], 0, "druhý nic")
  end },
  { "předměty po celých kusech: zlomek zásoby se zaokrouhlí pro ni, milník nedostane zlomek", function()
    local stock = { requirements = { { type = "item", name = "wood", amount = 15 } }, progress = { ["item/wood"] = 14.9 } }
    local milestone = sink(10, 0)
    local sinks = { stock, milestone }
    A.eq(allocation.wanted(sinks, "item", "wood", 5), 5, "zásoba 1 kus + milník 4")
    allocation.distribute(sinks, "item", "wood", 5)
    A.truthy(math.abs(stock.progress["item/wood"] - 15.9) < 1e-9, "celý kus do zásoby")
    A.eq(milestone.progress["item/wood"], 4, "milník celé kusy")
  end },
  { "kapaliny se dělí přesně", function()
    local stock = { requirements = { { type = "fluid", name = "water", amount = 0.5 } }, progress = {} }
    local milestone = { requirements = { { type = "fluid", name = "water", amount = 10 } }, progress = {} }
    allocation.distribute({ stock, milestone }, "fluid", "water", 3)
    A.eq(stock.progress["fluid/water"], 0.5, "zásoba")
    A.eq(milestone.progress["fluid/water"], 2.5, "milník")
  end },
  { "příjemce bez požadavků a nepotřebná surovina", function()
    local sinks = { { requirements = nil, progress = {} }, sink(10, 0) }
    A.eq(allocation.wanted(sinks, "item", "wood", 1000), 10, "nil požadavky se přeskočí")
    A.eq(allocation.wanted(sinks, "item", "stone", 1000), 0, "kámen nikdo nechce")
  end },
}
