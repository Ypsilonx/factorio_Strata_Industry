---@diagnostic disable: undefined-global, lowercase-global
--- Jednotkové testy doplnění stavu starého savu.
local A = require("assert")
local state = require("scripts.state")

return {
  { "starý save dostane úrovně domů a postup vylepšení", function()
    storage = {
      towns = { [1] = { id = 1, progress = {} } },
      nodes = { [5] = { kind = "house" }, [6] = { kind = "hall" } },
    }
    state.init()
    A.eq(storage.nodes[5].level, 1, "dům úroveň 1")
    A.eq(storage.nodes[6].level, nil, "radnice bez úrovně")
    A.truthy(storage.towns[1].house_progress, "postup vylepšení domů")
    A.truthy(storage.towns[1].stock, "zásoba spotřeby")
    A.eq(storage.towns[1].upkeep_ok, true, "spotřeba pokryta")
    storage = nil
  end },
  { "starý save: města jsou partnerská, mají pozici a jsou v indexu", function()
    storage = { towns = { [1] = { id = 1, progress = {}, hall = { valid = true, position = { x = 10, y = 20 } } } } }
    state.init()
    A.eq(storage.towns[1].state, "partner", "stav")
    A.eq(storage.towns[1].position.x, 10, "pozice")
    A.truthy(storage.wild_halls, "tabulka neutrálních radnic")
    A.truthy(storage.town_cells["0:0"][1], "index")
    storage = nil
  end },
}
