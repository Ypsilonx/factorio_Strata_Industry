--- Jednotkové testy odstranění laboratoří a přesměrování spouštěčů výzkumů.
local A = require("assert")
local labs = require("prototypes.labs")

--- Vanilla laboratoř + laboratoř „cizího modu“, výzkumy s odemčením a spouštěči.
local function raw()
  return {
    lab = {
      lab = { name = "lab", minable = { result = "lab" } },
      ["lab-2"] = { name = "lab-2", minable = { results = { { type = "item", name = "lab-2", amount = 1 } } } },
    },
    recipe = {
      lab = { name = "lab", results = { { type = "item", name = "lab", amount = 1 } } },
      ["lab-2"] = { name = "lab-2", enabled = false, results = { { type = "item", name = "lab-2", amount = 1 } } },
      ["copper-cable"] = { name = "copper-cable", results = { { type = "item", name = "copper-cable", amount = 2 } } },
    },
    technology = {
      electronics = { name = "electronics", effects = {
        { type = "unlock-recipe", recipe = "copper-cable" }, { type = "unlock-recipe", recipe = "lab" } } },
      asp = { name = "asp", research_trigger = { type = "craft-item", item = "lab" } },
      table_form = { name = "table_form", research_trigger = { type = "craft-item", item = { name = "lab-2" } } },
      built = { name = "built", research_trigger = { type = "build-entity", entity = "lab-2" } },
      other = { name = "other", research_trigger = { type = "craft-item", item = "copper-cable" } },
    },
  }
end

return {
  { "předměty laboratoří", function()
    local items = labs.lab_items(raw())
    A.truthy(items.lab and items["lab-2"], "lab i lab-2")
  end },
  { "recepty laboratoří skryté a neodemykané", function()
    local r = raw()
    labs.remove(r, "rt-house")
    A.truthy(r.recipe.lab.hidden and r.recipe.lab.enabled == false, "lab skrytý")
    A.truthy(r.recipe["lab-2"].hidden, "lab-2 skrytý")
    A.eq(#r.technology.electronics.effects, 1, "odemčení laboratoře odebráno")
    A.eq(r.technology.electronics.effects[1].recipe, "copper-cable", "ostatní odemčení zůstalo")
  end },
  { "spouštěče s laboratoří přesměrované na dům", function()
    local r = raw()
    labs.remove(r, "rt-house")
    A.eq(r.technology.asp.research_trigger.item, "rt-house", "craft-item")
    A.eq(r.technology.table_form.research_trigger.item, "rt-house", "craft-item s tabulkou")
    A.eq(r.technology.built.research_trigger.item, "rt-house", "build-entity")
    A.eq(r.technology.other.research_trigger.item, "copper-cable", "cizí spouštěč beze změny")
  end },
}
