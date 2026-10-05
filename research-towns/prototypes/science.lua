--- Čistá logika nad data.raw (testovaná mimo hru): rozdělení věd do úrovní měst, úroveň výzkumů
--- a dostupnost předmětů/kapalin. Díky tomu mod funguje s libovolným stromem věd (Pyanodon, Bob's, Krastorio).
local M = {}

--- Typy prototypů, které jsou předměty (pro kontrolu existence kandidátů).
local ITEM_TYPES = { "item", "tool", "module", "capsule", "ammo", "item-with-entity-data", "rail-planner", "repair-tool" }
--- Typy entit, jejichž vytěžení dává suroviny ze světa (dostupné od začátku).
local WORLD_TYPES = { "resource", "tree", "simple-entity", "fish" }

--- Je výzkum ve hře použitelný (ne skrytý ani vypnutý)?
local function usable(tech)
  return not tech.hidden and tech.enabled ~= false
end

--- Jméno vědy ze složky výzkumu ({ "pack", 1 } nebo { name = … }).
local function pack_name(ingredient)
  return ingredient[1] or ingredient.name
end

--- Hloubka výzkumů: 1 + nejdelší řetěz prerekvizit.
--- @return table<string, integer>
function M.tech_depths(raw)
  local depth = {}
  local function visit(name)
    if depth[name] then return depth[name] end
    depth[name] = 1 -- ochrana proti cyklu v rozbitém modu
    local d = 1
    for _, prerequisite in ipairs(raw.technology[name].prerequisites or {}) do
      if raw.technology[prerequisite] then d = math.max(d, visit(prerequisite) + 1) end
    end
    depth[name] = d
    return d
  end
  for name in pairs(raw.technology) do visit(name) end
  return depth
end

--- Rozdělí vědy používané výzkumy do úrovní: nejranější věda(y) = úroveň 1, každá další věda (podle hloubky
--- prvního výzkumu, který ji používá, při shodě podle jména) otevírá další úroveň.
--- @return table<string, integer> věda → úroveň, integer počet úrovní
function M.bands(raw)
  local depths = M.tech_depths(raw)
  local tier = {}
  for name, tech in pairs(raw.technology) do
    if usable(tech) and tech.unit then
      for _, ingredient in ipairs(tech.unit.ingredients) do
        local pack = pack_name(ingredient)
        if not tier[pack] or depths[name] < tier[pack] then tier[pack] = depths[name] end
      end
    end
  end
  local packs = {}
  for pack in pairs(tier) do packs[#packs + 1] = pack end
  table.sort(packs, function(a, b)
    if tier[a] ~= tier[b] then return tier[a] < tier[b] end
    return a < b
  end)
  local bands, count = {}, 1
  for _, pack in ipairs(packs) do
    if tier[pack] == tier[packs[1]] then
      bands[pack] = 1
    else
      count = count + 1
      bands[pack] = count
    end
  end
  return bands, count
end

--- Vědy, které přijímá radnice každé úrovně 1..count (kumulativně, seřazeno podle úrovně a jména).
--- @return table<integer, string[]>
function M.sciences(bands, count)
  local result = {}
  for level = 1, count do
    local list = {}
    for pack, band in pairs(bands) do
      if band <= level then list[#list + 1] = pack end
    end
    table.sort(list, function(a, b)
      if bands[a] ~= bands[b] then return bands[a] < bands[b] end
      return a < b
    end)
    result[level] = list
  end
  return result
end

--- Věda, kterou daná úroveň otevírá (pro úroveň ≥ 2 právě jedna), nebo nil.
function M.new_at(bands, level)
  for pack, band in pairs(bands) do
    if band == level then return pack end
  end
  return nil
end

--- Úroveň města potřebná pro výzkum: nejvyšší pásmo jeho věd i věd všech prerekvizit.
--- @return table<string, integer>
function M.tech_levels(raw, bands)
  local level = {}
  local function visit(name)
    if level[name] then return level[name] end
    level[name] = 1
    local tech = raw.technology[name]
    local l = 1
    if tech.unit then
      for _, ingredient in ipairs(tech.unit.ingredients) do l = math.max(l, bands[pack_name(ingredient)] or 1) end
    end
    for _, prerequisite in ipairs(tech.prerequisites or {}) do
      if raw.technology[prerequisite] then l = math.max(l, visit(prerequisite)) end
    end
    level[name] = l
    return l
  end
  for name in pairs(raw.technology) do visit(name) end
  return level
end

--- Zapíše úroveň k surovině, pokud je nižší než dosavadní; vrací true při změně.
local function lower(result, key, level)
  if not result[key] or level < result[key] then
    result[key] = level
    return true
  end
  return false
end

--- Klíč suroviny ("item/<jméno>" | "fluid/<jméno>").
local function key_of(entry)
  return (entry.type or "item") .. "/" .. entry.name
end

--- Nejnižší úroveň města, od které je předmět/kapalina získatelná (svět nebo recept).
--- Výrobek receptu je dostupný na max(úroveň odemčení, dostupnost všech ingrediencí) – počítá se jako pevný bod,
--- takže vyprázdnění obalu (barel, kanystr Py) nemůže být dřív než naplnění, bez ohledu na jména podskupin.
--- Skryté recepty (např. recyklace) se nepočítají.
--- @return table<string, integer>
function M.availability(raw, tech_levels)
  local unlocks = {}
  for name, tech in pairs(raw.technology) do
    if usable(tech) then
      for _, effect in ipairs(tech.effects or {}) do
        if effect.type == "unlock-recipe" then lower(unlocks, effect.recipe, tech_levels[name]) end
      end
    end
  end
  local result = {}
  for _, entity_type in ipairs(WORLD_TYPES) do
    for _, entity in pairs(raw[entity_type] or {}) do
      local minable = entity.minable
      if minable then
        if minable.result then lower(result, "item/" .. minable.result, 1) end
        for _, product in ipairs(minable.results or {}) do lower(result, key_of(product), 1) end
      end
    end
  end
  for _, tile in pairs(raw.tile or {}) do
    if tile.fluid then lower(result, "fluid/" .. tile.fluid, 1) end
  end
  -- Recepty, které se dají odemknout, s jejich úrovní odemčení.
  local recipes = {}
  for name, recipe in pairs(raw.recipe) do
    local level = recipe.enabled ~= false and 1 or unlocks[name]
    if not recipe.hidden and level then recipes[#recipes + 1] = { recipe = recipe, level = level } end
  end
  -- Relaxace do pevného bodu: úrovně jen klesají, takže cyklus skončí.
  local changed = true
  while changed do
    changed = false
    for _, entry in ipairs(recipes) do
      local level = entry.level
      for _, ingredient in ipairs(entry.recipe.ingredients or {}) do
        local at = result[key_of(ingredient)]
        if not at then
          level = nil
          break
        end
        if at > level then level = at end
      end
      if level then
        for _, product in ipairs(entry.recipe.results or {}) do
          if lower(result, key_of(product), level) then changed = true end
        end
      end
    end
  end
  return result
end

--- Vrátí funkci, která ověří, že předmět/kapalina existuje a není skrytá.
--- @return fun(kind: string, name: string): boolean
function M.exists_in(raw)
  return function(kind, name)
    if kind == "fluid" then
      local fluid = raw.fluid[name]
      return fluid ~= nil and not fluid.hidden
    end
    for _, item_type in ipairs(ITEM_TYPES) do
      local item = raw[item_type] and raw[item_type][name]
      if item then return not item.hidden end
    end
    return false
  end
end

--- Vybere pro každý požadavek prvního kandidáta, který existuje a je dostupný nejpozději na dané úrovni.
--- Jedna surovina se v milníku použije jen jednou.
--- @return table[] { {type, name, amount} }, string[] vynechané požadavky (kandidáti spojení „|“)
function M.resolve(requirements, availability, level, exists)
  local out, dropped, used = {}, {}, {}
  for _, req in ipairs(requirements) do
    local chosen
    for _, name in ipairs(req.candidates) do
      local key = req.type .. "/" .. name
      local at = availability[key]
      if not used[key] and exists(req.type, name) and at and at <= level then
        chosen = name
        used[key] = true
        break
      end
    end
    if chosen then
      out[#out + 1] = { type = req.type, name = chosen, amount = req.amount }
    else
      dropped[#dropped + 1] = table.concat(req.candidates, "|")
    end
  end
  return out, dropped
end

return M
