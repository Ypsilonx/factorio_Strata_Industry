--- Jednotkové testy průběžné spotřeby.
local A = require("assert")
local levels = require("shared.levels")
local upkeep = require("scripts.upkeep")

local COMPLETED = {
  { { type = "item", name = "red", amount = 200, science = true }, { type = "item", name = "wood", amount = 100 } },
  { { type = "item", name = "wood", amount = 300 }, { type = "fluid", name = "water", amount = 1000 } },
}

return {
  { "sčítá suroviny všech splněných milníků bez vědy", function()
    local list = upkeep.per_minute(COMPLETED, 1, 0)
    A.eq(#list, 2, "dva druhy (věda vynechaná)")
    A.eq(list[1].name, "water", "seřazeno podle klíče (fluid/ < item/)")
    A.eq(list[2].amount, math.ceil(400 * levels.UPKEEP_RATE - 1e-6), "dřevo za minutu")
  end },
  { "spotřeba je zaokrouhlená nahoru na celé kusy", function()
    local small = { { { type = "item", name = "wood", amount = 30 }, { type = "fluid", name = "water", amount = 1050 } } }
    local list = upkeep.per_minute(small, 1, 0)
    A.eq(list[2].amount, 1, "0,3 ks → 1")
    A.eq(list[1].amount, math.ceil(1050 * levels.UPKEEP_RATE), "kapalina také nahoru")
  end },
  { "domy a násobič zvyšují spotřebu", function()
    local big = { { { type = "item", name = "wood", amount = 100000 } } }
    local base = upkeep.per_minute(big, 1, 0)[1].amount
    local houses = upkeep.per_minute(big, 1, 10)[1].amount
    A.eq(houses, math.ceil(base * (1 + 10 * levels.HOUSE_UPKEEP_SHARE) - 1e-6), "10 domů")
    A.eq(upkeep.per_minute(big, 2, 0)[1].amount, 2 * base, "násobič 2")
    A.eq(#upkeep.per_minute(COMPLETED, 0, 5), 0, "násobič 0 vypne spotřebu")
    A.eq(#upkeep.per_minute({}, 1, 5), 0, "úroveň 1 nic nespotřebovává")
  end },
  { "zásoba pokryje potřebu a odebere se", function()
    local need = upkeep.times({ { type = "item", name = "wood", amount = 60 } }, 0.5)
    A.eq(need[1].amount, 30, "times")
    local stock = { ["item/wood"] = 40 }
    A.truthy(upkeep.covered(need, stock), "40 ≥ 30")
    upkeep.consume(need, stock)
    A.eq(stock["item/wood"], 10, "odebráno")
    A.truthy(not upkeep.covered(need, stock), "10 < 30")
    A.truthy(upkeep.covered({}, {}), "bez spotřeby je pokryto")
  end },
}
