--- Jednotkové testy postupu milníků.
local A = require("assert")
local milestones = require("scripts.milestones")

local REQS = { { type = "item", name = "wood", amount = 100 }, { type = "fluid", name = "water", amount = 50 } }

return {
  { "přijme jen potřebné a jen do potřeby", function()
    local progress = {}
    A.eq(milestones.accept(REQS, progress, "item", "wood", 30), 30, "část")
    milestones.add(progress, "item", "wood", 30)
    A.eq(milestones.accept(REQS, progress, "item", "wood", 500), 70, "zbytek")
    A.eq(milestones.accept(REQS, progress, "item", "iron-ore", 10), 0, "nepotřebné")
    A.eq(milestones.accept(nil, progress, "item", "wood", 10), 0, "bez milníku")
  end },
  { "splnění s tolerancí kapalin", function()
    local progress = {}
    milestones.add(progress, "item", "wood", 100)
    A.eq(milestones.complete(REQS, progress), false, "chybí voda")
    milestones.add(progress, "fluid", "water", 49.99999)
    A.eq(milestones.complete(REQS, progress), true, "voda v toleranci")
    A.eq(milestones.complete(nil, progress), false, "max. úroveň")
  end },
}
