--- Jednotkové testy signálů městské tabule.
local A = require("assert")
local board = require("scripts.board")

local STATUS = {
  requirements = { { type = "item", name = "wood", amount = 200, delivered = 50.5 },
    { type = "fluid", name = "water", amount = 100, delivered = 100 } },
  house_requirements = { { type = "item", name = "pipe", amount = 10, delivered = 0 } },
  houses_to_upgrade = 3,
  upkeep = { { type = "item", name = "wood", per_minute = 2.3, stock = 0 } },
  power_watts = 4e6, power_percent = 75,
}

--- Signál podle jména, nebo nil.
local function find(list, name)
  for _, signal in ipairs(list) do
    if signal.name == name then return signal end
  end
  return nil
end

return {
  { "režim Radnice: zbývající milník zaokrouhlený nahoru, splněné vynechá", function()
    local list = board.signals("hall", STATUS)
    A.eq(find(list, "wood").count, 150, "dřevo")
    A.eq(find(list, "water"), nil, "splněná voda")
    A.eq(find(list, "rt-signal-power-mw").count, 4, "MW")
    A.eq(find(list, "rt-signal-power-percent").count, 75, "procenta")
  end },
  { "režim Dům: jeden dům + počet domů", function()
    local list = board.signals("house", STATUS)
    A.eq(find(list, "pipe").count, 10, "trubky")
    A.eq(find(list, "rt-signal-houses").count, 3, "domy")
    A.eq(find(list, "wood"), nil, "milník radnice ne")
  end },
  { "režim Spotřeba: za minutu nahoru", function()
    local list = board.signals("upkeep", STATUS)
    A.eq(find(list, "wood").count, 3, "dřevo za minutu")
    A.eq(find(list, "wood").type, "item", "typ")
  end },
}
