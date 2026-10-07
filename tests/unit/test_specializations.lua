--- Jednotkové testy specializací měst: výběr materiálů z falešného data.raw, přidělení městům a bonus.
local A = require("assert")
local levels = require("shared.levels")
local collect = require("prototypes.specializations")
local spec = require("shared.specialization")

--- Malý svět: pláty z rudy (dva recepty na železo), kola a kabely z plátů, obvody, věda, recyklace a barely.
local function raw()
  local r = { recipe = {}, item = {}, fluid = {}, tool = {}, resource = {}, tile = {}, tree = {}, technology = {} }
  for _, name in ipairs({ "iron-ore", "copper-ore", "iron-plate", "copper-plate", "gear", "cable", "circuit", "barrel",
    "water-barrel", "rt-house", "lonely" }) do
    r.item[name] = { name = name }
  end
  r.tool["red-pack"] = { name = "red-pack" }
  r.fluid.water = { name = "water" }
  r.resource["iron-ore"] = { name = "iron-ore", minable = { result = "iron-ore" } }
  r.resource["copper-ore"] = { name = "copper-ore", minable = { result = "copper-ore" } }
  local function recipe(name, ingredients, results, extra)
    local list = {}
    for i, ing in ipairs(ingredients) do list[i] = { type = ing[3] or "item", name = ing[1], amount = ing[2] } end
    local out = {}
    for i, res in ipairs(results) do out[i] = { type = res[3] or "item", name = res[1], amount = res[2] } end
    r.recipe[name] = { name = name, ingredients = list, results = out }
    for k, v in pairs(extra or {}) do r.recipe[name][k] = v end
  end
  recipe("iron-plate", { { "iron-ore", 1 } }, { { "iron-plate", 1 } })
  recipe("iron-plate-alt", { { "iron-ore", 2 } }, { { "iron-plate", 3 } })
  recipe("copper-plate", { { "copper-ore", 1 } }, { { "copper-plate", 1 } })
  recipe("gear", { { "iron-plate", 2 } }, { { "gear", 1 } })
  recipe("cable", { { "copper-plate", 1 } }, { { "cable", 2 } })
  recipe("circuit", { { "iron-plate", 1 }, { "cable", 3 } }, { { "circuit", 1 } })
  recipe("red-pack", { { "gear", 1 }, { "copper-plate", 1 } }, { { "red-pack", 1 } })
  recipe("rt-house", { { "gear", 1 }, { "iron-plate", 1 } }, { { "rt-house", 1 } })
  recipe("pipe-thing", { { "iron-plate", 1 } }, { { "lonely", 1 } })
  -- Recyklace (skrytá) a barely (bez rozkladu) se nepočítají.
  recipe("gear-recycling", { { "gear", 1 } }, { { "iron-plate", 2 } }, { hidden = true, category = "recycling" })
  recipe("barrel", { { "iron-plate", 1 } }, { { "barrel", 1 } })
  recipe("fill-water", { { "barrel", 1 }, { "water", 50, "fluid" } }, { { "water-barrel", 1 } },
    { allow_decomposition = false })
  recipe("fill-water-2", { { "barrel", 1 }, { "water", 50, "fluid" } }, { { "water-barrel", 1 } },
    { allow_decomposition = false })
  -- Obal s rozkladem (Py): naplnění z kapaliny a vyprázdnění zpět; hodně receptů barel s olejem používá.
  r.item["oil-barrel"] = { name = "oil-barrel" }
  r.fluid.oil = { name = "oil" }
  recipe("make-oil", { { "copper-ore", 1 } }, { { "oil", 10, "fluid" } })
  recipe("fill-oil", { { "barrel", 1 }, { "oil", 50, "fluid" } }, { { "oil-barrel", 1 } })
  recipe("empty-oil", { { "oil-barrel", 1 } }, { { "oil", 50, "fluid" }, { "barrel", 1 } }, { main_product = "oil" })
  for i = 1, 8 do recipe("oily-" .. i, { { "oil-barrel", 1 } }, { { "gear", 1 } }) end
  -- Voda se čerpá ze světa; i když ji nějaký recept vyrábí a hodně receptů ji používá, specializací není.
  r.tile.water = { name = "water", fluid = "water" }
  recipe("ice-melting", { { "iron-ore", 1 } }, { { "water", 20, "fluid" } })
  for i = 1, 6 do recipe("wet-" .. i, { { "water", 1, "fluid" } }, { { "gear", 1 } }) end
  -- Lití z taveniny (Space Age) je bez rozkladu, ale pláty vyrábí – patří ke specializaci.
  recipe("cast-iron", { { "molten-iron", 10, "fluid" } }, { { "iron-plate", 1 } }, { allow_decomposition = false })
  -- Recept se dvěma výsledky bez hlavního výrobku nikomu nepatří.
  recipe("split", { { "iron-ore", 1 } }, { { "iron-plate", 1 }, { "copper-plate", 1 } })
  return r
end

--- Dostupnost: všechno kromě „lonely“ (recept nejde odemknout).
local function available(key)
  return key ~= "item/lonely"
end

return {
  { "výběr: nejpoužívanější vyrobitelné meziprodukty, bez rud, vědy, vlastních předmětů a barelů", function()
    local list = collect.collect(raw(), available, 3)
    local names = {}
    for i, entry in ipairs(list) do names[i] = entry.name end
    -- iron-plate: gear, circuit, rt-house, pipe-thing, barrel = 5; gear: red-pack, rt-house = 2; cable: circuit = 1;
    -- copper-plate: cable, red-pack = 2 (remíza s gear → podle jména).
    A.eq(table.concat(names, ","), "iron-plate,copper-plate,gear", "pořadí")
    A.eq(table.concat(list[1].recipes, ","), "cast-iron,iron-plate,iron-plate-alt",
      "všechny recepty železa včetně lití, bez recyklace")
    A.eq(list[1].type, "item", "typ")
  end },
  { "výběr: méně kandidátů než požadovaný počet vrátí všechny", function()
    local list = collect.collect(raw(), available, 50)
    for _, entry in ipairs(list) do
      A.truthy(entry.name ~= "iron-ore" and entry.name ~= "red-pack" and entry.name ~= "rt-house"
        and entry.name ~= "lonely" and entry.name ~= "water-barrel", "nepatří mezi specializace: " .. entry.name)
    end
  end },
  { "přidělení: nejméně používaná specializace, mezi rovnými podle id města", function()
    local products = { "a", "b", "c" }
    A.eq(spec.pick(products, {}, 1), "a", "první město")
    A.eq(spec.pick(products, {}, 2), "b", "jiné id → jiná volba")
    A.eq(spec.pick(products, { a = 1 }, 1), "b", "a už má jedno město")
    A.eq(spec.pick(products, { a = 1, b = 1, c = 1 }, 3), "c", "všechny jednou → zase od začátku podle id")
    A.eq(spec.pick(products, { a = 2, b = 1, c = 2 }, 9), "b", "nejméně použitá")
    A.eq(spec.pick({}, {}, 1), nil, "bez specializací")
  end },
  { "bonus města roste s úrovní do stropu", function()
    local first = levels.SPEC_START_LEVEL + 1
    A.eq(spec.town_bonus(levels.SPEC_START_LEVEL), 0, "do úrovně SPEC_START_LEVEL bez bonusu")
    A.truthy(math.abs(spec.town_bonus(first) - levels.SPEC_STEP) < 1e-9, "první úroveň s bonusem")
    A.truthy(math.abs(spec.town_bonus(1000) - levels.SPEC_TOWN_MAX) < 1e-9, "strop města")
    A.truthy(math.abs(spec.town_bonus(first, 0.5) - levels.SPEC_STEP * 0.5) < 1e-9, "násobič z nastavení")
    A.eq(spec.town_bonus(first + 3, 0), 0, "násobič 0 = specializace vypnuté")
  end },
  { "součet měst stejné specializace: klesající přínos a strop", function()
    A.eq(spec.total({}), 0, "žádné město")
    A.truthy(math.abs(spec.total({ 0.1 }) - 0.1) < 1e-9, "jedno město")
    local two = spec.total({ 0.1, 0.2 })
    A.truthy(math.abs(two - (0.2 + 0.1 * levels.SPEC_DECAY)) < 1e-9, "druhé město přidá jen díl: " .. two)
    A.truthy(math.abs(spec.total({ 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3 }) - levels.SPEC_MAX) < 1e-9, "strop")
    A.truthy(math.abs(spec.total({ 1, 1, 1 }, 2) - levels.SPEC_MAX * 2) < 1e-9, "strop roste s násobičem")
    -- Hra drží produktivitu receptu po celých procentech – součet se zaokrouhlí dolů.
    A.truthy(math.abs(spec.total({ 0.015 }) - 0.01) < 1e-9, "1,5 % → 1 %")
    A.eq(spec.total({ 0.005 }), 0, "0,5 % → 0 %")
  end },
}
