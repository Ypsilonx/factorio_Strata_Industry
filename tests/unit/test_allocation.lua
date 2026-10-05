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
  { "přebytek po zaokrouhlení na celé kusy dostane první příjemce, který bral", function()
    local stock = { requirements = { { type = "item", name = "wood", amount = 0.3 } }, progress = {} }
    local milestone = sink(10, 10)
    local sinks = { milestone, stock }
    A.eq(allocation.wanted(sinks, "item", "wood", 5), 0.3, "chce zlomek")
    allocation.distribute(sinks, "item", "wood", 1)
    A.eq(stock.progress["item/wood"], 1, "celý kus ve zásobě")
    A.eq(milestone.progress["item/wood"], 10, "splněný milník nic navíc")
  end },
  { "příjemce bez požadavků a nepotřebná surovina", function()
    local sinks = { { requirements = nil, progress = {} }, sink(10, 0) }
    A.eq(allocation.wanted(sinks, "item", "wood", 1000), 10, "nil požadavky se přeskočí")
    A.eq(allocation.wanted(sinks, "item", "stone", 1000), 0, "kámen nikdo nechce")
  end },
}
