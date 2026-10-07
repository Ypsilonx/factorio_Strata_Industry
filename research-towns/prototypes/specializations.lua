--- Specializace měst (data stage): základní materiály, na které město dává bonus k produktivitě. Odvozené z obsahu
--- hry, nic natvrdo – kompatibilita s overhauly (Pyanodon, Bob's): nejpoužívanější vyrobitelné meziprodukty
--- (počet receptů, ve kterých jsou surovinou), každý se všemi recepty, které ho vyrábějí jako hlavní výrobek.
local M = {}

--- Typy předmětů, které můžou být specializací (vědecké balíčky – typ tool – ne).
local ITEM_TYPES = { "item", "module", "capsule", "ammo", "item-with-entity-data", "rail-planner", "repair-tool" }
--- Vlastní předměty modu nejsou materiálem specializace.
local OWN_PREFIX = "rt-"

--- Je recept skutečný výrobní postup? Skryté (recyklace Space Age), recyklace a parametry ne.
local function real(recipe)
  return not recipe.hidden and not recipe.parameter and recipe.category ~= "recycling"
end

--- Počítá se recept do používanosti surovin? Recepty bez rozkladu (plnění a vyprázdnění barelů, kanystrů) ne – jinak
--- by obal vypadal jako nejpoužívanější materiál. Jako výrobce se ale počítají (lití z taveniny ve Space Age).
local function counts(recipe)
  return real(recipe) and recipe.allow_decomposition ~= false
end

--- Typy entit, jejichž vytěžení dává suroviny ze světa (ne simple-entity – ruiny na Fulgoře dávají ocel a kola).
local WORLD_TYPES = { "resource", "tree", "fish" }

--- Materiály ze světa (těžba, čerpání) – ty specializací nejsou, bonus na rudu nebo vodu nemá smysl.
--- @return table<string, true> klíče „item/…“, „fluid/…“
local function world(raw)
  local set = {}
  for _, entity_type in ipairs(WORLD_TYPES) do
    for _, entity in pairs(raw[entity_type] or {}) do
      local minable = entity.minable
      if minable then
        if minable.result then set["item/" .. minable.result] = true end
        for _, product in ipairs(minable.results or {}) do set[(product.type or "item") .. "/" .. product.name] = true end
      end
    end
  end
  for _, tile in pairs(raw.tile or {}) do
    if tile.fluid then set["fluid/" .. tile.fluid] = true end
  end
  return set
end

--- Obaly (barely, kanystry v jakémkoli modu): předmět vyrobený z kapaliny, ze kterého jiný recept tutéž kapalinu
--- zase vrátí. Specializací nejsou – jen přenášejí kapalinu.
--- @return table<string, true> klíče „item/…“
local function containers(raw)
  local filled_with = {}
  for _, recipe in pairs(raw.recipe) do
    if real(recipe) then
      for _, result in ipairs(recipe.results or {}) do
        if (result.type or "item") == "item" then
          for _, ingredient in ipairs(recipe.ingredients or {}) do
            if ingredient.type == "fluid" then
              filled_with[result.name] = filled_with[result.name] or {}
              filled_with[result.name][ingredient.name] = true
            end
          end
        end
      end
    end
  end
  local set = {}
  for _, recipe in pairs(raw.recipe) do
    if real(recipe) then
      for _, ingredient in ipairs(recipe.ingredients or {}) do
        local fluids = (ingredient.type or "item") == "item" and filled_with[ingredient.name]
        for _, result in ipairs(fluids and recipe.results or {}) do
          if result.type == "fluid" and fluids[result.name] then set["item/" .. ingredient.name] = true end
        end
      end
    end
  end
  return set
end

--- Hlavní výrobek receptu ({type, name}), nebo nil: main_product, jinak jediný výsledek.
local function main_product(recipe)
  local results = recipe.results or {}
  if recipe.main_product and recipe.main_product ~= "" then
    for _, result in ipairs(results) do
      if result.name == recipe.main_product then return { type = result.type or "item", name = result.name } end
    end
    return nil
  end
  if #results == 1 then return { type = results[1].type or "item", name = results[1].name } end
  return nil
end

--- Je materiál vhodný? Existuje, není skrytý, není věda ani vlastní předmět modu.
local function eligible(raw, product)
  if product.name:sub(1, #OWN_PREFIX) == OWN_PREFIX then return false end
  if product.type == "fluid" then
    local fluid = raw.fluid and raw.fluid[product.name]
    return fluid ~= nil and not fluid.hidden
  end
  for _, item_type in ipairs(ITEM_TYPES) do
    local item = raw[item_type] and raw[item_type][product.name]
    if item then return not item.hidden end
  end
  return false
end

--- Vybere až count specializací.
--- @param raw table data.raw
--- @param available fun(key: string): boolean dá se materiál („item/…“, „fluid/…“) získat? (science.availability)
--- @param count integer
--- @return table[] { {type, name, recipes = string[]} } od nejpoužívanějšího (remíza podle jména)
function M.collect(raw, available, count)
  local usage, producers, types = {}, {}, {}
  for name, recipe in pairs(raw.recipe) do
    if counts(recipe) then
      local seen = {}
      for _, ingredient in ipairs(recipe.ingredients or {}) do
        local key = (ingredient.type or "item") .. "/" .. ingredient.name
        if not seen[key] then
          seen[key] = true
          usage[key] = (usage[key] or 0) + 1
        end
      end
    end
    if real(recipe) then
      local product = main_product(recipe)
      if product then
        local key = product.type .. "/" .. product.name
        producers[key] = producers[key] or {}
        table.insert(producers[key], name)
        types[key] = product
      end
    end
  end
  local candidates, from_world, packed = {}, world(raw), containers(raw)
  for key, product in pairs(types) do
    if usage[key] and not from_world[key] and not packed[key] and eligible(raw, product) and available(key) then
      table.sort(producers[key])
      candidates[#candidates + 1] = { type = product.type, name = product.name, recipes = producers[key],
        usage = usage[key] }
    end
  end
  table.sort(candidates, function(a, b)
    if a.usage ~= b.usage then return a.usage > b.usage end
    return a.name < b.name
  end)
  local list = {}
  for i = 1, math.min(count, #candidates) do
    local c = candidates[i]
    list[i] = { type = c.type, name = c.name, recipes = c.recipes }
  end
  return list
end

return M
