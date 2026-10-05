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
    storage = nil
  end },
}
