--- Jednotkové testy odvození věd a dostupnosti surovin z falešného data.raw.
local A = require("assert")
local science = require("prototypes.science")

--- Zkrácený strom: červená → zelená → modrá a vojenská; skrytý výzkum s tajnou vědou.
local function raw()
  local r = { technology = {}, recipe = {}, item = {}, fluid = {}, tool = {}, resource = {}, tree = {}, tile = {} }
  local function tech(name, prerequisites, packs, effects, hidden)
    local ingredients = {}
    for i, pack in ipairs(packs) do ingredients[i] = { pack, 1 } end
    r.technology[name] = { name = name, prerequisites = prerequisites, effects = effects or {},
      unit = { count = 10, time = 5, ingredients = ingredients }, hidden = hidden }
  end
  tech("t-red", {}, { "red" })
  tech("t-green", { "t-red" }, { "red", "green" })
  tech("t-blue", { "t-green" }, { "red", "green", "blue" }, { { type = "unlock-recipe", recipe = "steel" } })
  tech("t-mil", { "t-green" }, { "red", "green", "mil" })
  tech("t-secret", {}, { "secret" }, nil, true)
  r.technology["t-trigger"] = { name = "t-trigger", prerequisites = { "t-blue" }, research_trigger = { type = "craft-item", item = "gear" } }
  for _, name in ipairs({ "steel", "gear", "secret-item", "wood", "iron-ore", "barrel" }) do r.item[name] = { name = name } end
  r.item["hidden-thing"] = { name = "hidden-thing", hidden = true }
  r.fluid.water = { name = "water" }
  r.fluid.lube = { name = "lube" }
  r.recipe.steel = { name = "steel", enabled = false, results = { { type = "item", name = "steel", amount = 1 } } }
  r.recipe.gear = { name = "gear", results = { { type = "item", name = "gear", amount = 1 } } }
  r.recipe.recycle = { name = "recycle", hidden = true, results = { { type = "item", name = "secret-item", amount = 1 } } }
  r.recipe["empty-lube-barrel"] = { name = "empty-lube-barrel", subgroup = "empty-barrel",
    results = { { type = "fluid", name = "lube", amount = 50 }, { type = "item", name = "barrel", amount = 1 } } }
  r.resource["iron-ore"] = { name = "iron-ore", minable = { result = "iron-ore" } }
  r.tree.tree = { name = "tree", minable = { results = { { type = "item", name = "wood", amount = 4 } } } }
  r.tile.water = { name = "water", fluid = "water" }
  return r
end

return {
  { "první věda je úroveň 1, ostatní rovnoměrně 2–5", function()
    local bands = science.bands(raw(), 5)
    A.eq(bands.red, 1, "red")
    A.eq(bands.green, 2, "green")
    A.eq(bands.blue, 3, "blue")
    A.eq(bands.mil, 4, "mil")
    A.eq(bands.secret, nil, "věda skrytého výzkumu")
  end },
  { "vědy úrovní jsou kumulativní", function()
    local list = science.sciences(science.bands(raw(), 5), 5)
    A.eq(table.concat(list[1], ","), "red", "úroveň 1")
    A.eq(table.concat(list[3], ","), "red,green,blue", "úroveň 3")
    A.eq(table.concat(list[5], ","), "red,green,blue,mil", "úroveň 5")
  end },
  { "úroveň výzkumu zahrnuje prerekvizity", function()
    local levels = science.tech_levels(raw(), science.bands(raw(), 5))
    A.eq(levels["t-red"], 1, "t-red")
    A.eq(levels["t-blue"], 3, "t-blue")
    A.eq(levels["t-trigger"], 3, "spouštěný výzkum dědí z prerekvizit")
  end },
  { "dostupnost: recept, výzkum, suroviny ze světa", function()
    local r = raw()
    local avail = science.availability(r, science.tech_levels(r, science.bands(r, 5)))
    A.eq(avail["item/gear"], 1, "recept od začátku")
    A.eq(avail["item/steel"], 3, "recept za výzkumem")
    A.eq(avail["item/iron-ore"], 1, "ruda")
    A.eq(avail["item/wood"], 1, "strom")
    A.eq(avail["fluid/water"], 1, "kapalina z dlaždice")
  end },
  { "skryté recepty a barely se nepočítají", function()
    local r = raw()
    local avail = science.availability(r, science.tech_levels(r, science.bands(r, 5)))
    A.eq(avail["item/secret-item"], nil, "recyklace")
    A.eq(avail["fluid/lube"], nil, "vyprázdnění barelu")
  end },
  { "kandidáti: první dostupný na úrovni, jinak vynechat", function()
    local r = raw()
    local avail = science.availability(r, science.tech_levels(r, science.bands(r, 5)))
    local exists = science.exists_in(r)
    local reqs = {
      { type = "item", candidates = { "steel", "gear" }, amount = 5 },
      { type = "item", candidates = { "missing", "hidden-thing" }, amount = 1 },
      { type = "fluid", candidates = { "water" }, amount = 100 },
    }
    local at2, dropped = science.resolve(reqs, avail, 2, exists)
    A.eq(#at2, 2, "počet vyřešených na úrovni 2")
    A.eq(at2[1].name, "gear", "ocel ještě není dostupná")
    A.eq(at2[2].name, "water", "voda")
    A.eq(dropped[1], "missing|hidden-thing", "vynechaný požadavek")
    local at3 = science.resolve(reqs, avail, 3, exists)
    A.eq(at3[1].name, "steel", "na úrovni 3 ocel")
  end },
  { "stejná surovina se v milníku nezdvojí", function()
    local r = raw()
    local avail = science.availability(r, science.tech_levels(r, science.bands(r, 5)))
    local reqs = {
      { type = "item", candidates = { "gear" }, amount = 5 },
      { type = "item", candidates = { "gear", "wood" }, amount = 5 },
    }
    local out = science.resolve(reqs, avail, 1, science.exists_in(r))
    A.eq(out[2].name, "wood", "druhý požadavek vzal dalšího kandidáta")
  end },
}
