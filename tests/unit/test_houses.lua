--- Jednotkové testy výběru domu k vylepšení.
local A = require("assert")
local houses = require("scripts.houses")

local CANDIDATES = {
  { key = 10, level = 2, depth = 1 },
  { key = 11, level = 1, depth = 3 },
  { key = 12, level = 1, depth = 2 },
  { key = 9, level = 1, depth = 2 },
}

return {
  { "nejnižší úroveň, pak nejmenší hloubka, pak klíč", function()
    A.eq(houses.pick(CANDIDATES, 3).key, 9, "vybraný dům")
  end },
  { "dům na úrovni města se nevylepšuje", function()
    A.eq(houses.pick({ { key = 1, level = 2, depth = 1 } }, 2), nil, "nic k vylepšení")
    A.eq(houses.upgradable(CANDIDATES, 2), 3, "pod úrovní 2 jsou tři domy")
    A.eq(houses.upgradable(CANDIDATES, 1), 0, "na úrovni 1 nic")
  end },
}
