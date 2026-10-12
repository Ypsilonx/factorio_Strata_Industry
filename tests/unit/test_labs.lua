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
  { "laboratoř jako surovina cizího receptu se rozloží na suroviny jejího receptu", function()
    local r = raw()
    r.recipe.lab.ingredients = { { type = "item", name = "electronic-circuit", amount = 10 },
      { type = "item", name = "iron-gear-wheel", amount = 10 } }
    r.recipe["lab-2"].ingredients = { { type = "item", name = "lab", amount = 1 },
      { type = "item", name = "copper-cable", amount = 3 } }
    r.recipe["lab-2"].results[1].amount = 2
    r.recipe.greenhouse = { name = "greenhouse", ingredients = {
      { type = "item", name = "lab", amount = 2 }, { type = "item", name = "electronic-circuit", amount = 1 },
      { type = "item", name = "lab-2", amount = 1 }, { type = "fluid", name = "water", amount = 50 } },
      results = { { type = "item", name = "greenhouse", amount = 1 } } }
    r.recipe["greenhouse-recycling"] = { name = "greenhouse-recycling", hidden = true,
      ingredients = { { type = "item", name = "greenhouse", amount = 1 } },
      results = { { type = "item", name = "lab", amount = 1 } } }
    local _, expanded = labs.remove(r, "rt-house")
    A.eq(table.concat(expanded, ","), "greenhouse", "rozložen jen cizí neskrytý recept")
    -- 2× lab = 20 obvodů + 20 kol; +1 obvod; lab-2 dává 2 ks → ½ × (10 obvodů + 10 kol + 3 kabely), kabely ⌈1,5⌉.
    local got = {}
    for _, ingredient in ipairs(r.recipe.greenhouse.ingredients) do got[#got + 1] = ingredient.name .. "×" .. ingredient.amount end
    A.eq(table.concat(got, ","), "electronic-circuit×26,iron-gear-wheel×25,copper-cable×2,water×50", "suroviny")
    A.eq(r.recipe["lab-2"].ingredients[1].name, "lab", "recept laboratoře beze změny")
    A.eq(r.recipe["greenhouse-recycling"].ingredients[1].name, "greenhouse", "recyklace beze změny")
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
