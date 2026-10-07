--- Specializace měst (runtime): každé město dostane jiný základní materiál (mod-data „rt-levels“.specializations)
--- a jako partner zvyšuje své síle produktivitu receptů, které ho vyrábějí. Do receptů se zapisuje jen rozdíl
--- proti tomu, co mod přidal minule (storage.spec_applied), takže bonusy z výzkumů produktivity zůstanou.
local spec = require("shared.specialization")

local M = {}

local data = prototypes.mod_data["rt-levels"].data

--- Specializace ve hře ({ {type, name, recipes} }).
function M.list()
  return data.specializations or {}
end

--- Specializace podle jména materiálu, nebo nil (po změně modů mohla zmizet).
local function entry(name)
  for _, e in ipairs(M.list()) do
    if e.name == name then return e end
  end
  return nil
end

--- Přidělí městu specializaci, pokud ji nemá nebo už ve hře není: tu, kterou má zatím nejméně měst.
function M.assign(town)
  if town.specialization and entry(town.specialization) then return end
  local used = {}
  for _, other in pairs(storage.towns) do
    if other ~= town and other.specialization then
      used[other.specialization] = (used[other.specialization] or 0) + 1
    end
  end
  local names = {}
  for i, e in ipairs(M.list()) do names[i] = e.name end
  town.specialization = spec.pick(names, used, town.id)
end

--- Násobič síly specializací z mapového nastavení (0 = vypnuté).
function M.multiplier()
  return settings.global["rt-specialization-multiplier"].value
end

--- Bonusy partnerských měst síly podle specializace (jméno → { bonus města, … }).
local function town_bonuses(force)
  local per = {}
  for _, town in pairs(storage.towns) do
    if town.state == "partner" and town.specialization and town.hall.valid and town.hall.force == force then
      per[town.specialization] = per[town.specialization] or {}
      table.insert(per[town.specialization], spec.town_bonus(town.level, M.multiplier()))
    end
  end
  return per
end

--- Celkový bonus síly ke specializaci name (0–SPEC_MAX × násobič).
function M.force_total(force, name)
  return spec.total(town_bonuses(force)[name] or {}, M.multiplier())
end

--- Srovná bonusy receptů síly s jejími partnerskými městy (přičte rozdíl proti minule přidanému).
--- @param force LuaForce
function M.apply(force)
  storage.spec_applied[force.index] = storage.spec_applied[force.index] or {}
  local applied = storage.spec_applied[force.index]
  local per = town_bonuses(force)
  local target = {}
  for _, e in ipairs(M.list()) do
    local total = spec.total(per[e.name] or {}, M.multiplier())
    for _, recipe in ipairs(e.recipes) do target[recipe] = total end
  end
  for name in pairs(applied) do
    if not target[name] then target[name] = 0 end
  end
  for name, value in pairs(target) do
    local recipe = force.recipes[name]
    local delta = value - (applied[name] or 0)
    if recipe and math.abs(delta) > 1e-6 then
      -- Hra zaokrouhluje na celá procenta – do evidence skutečně zapsaný rozdíl, ne zamýšlený.
      local before = recipe.productivity_bonus
      recipe.productivity_bonus = before + delta
      applied[name] = (applied[name] or 0) + (recipe.productivity_bonus - before)
    end
    if applied[name] and math.abs(applied[name]) < 1e-6 then applied[name] = nil end
  end
end

--- Srovná bonusy všech sil (po zániku města, po změně modů).
function M.apply_all()
  for _, force in pairs(game.forces) do M.apply(force) end
end

--- Výzkumy síly se přepočítaly (force.reset_technology_effects) – vlastní úpravy receptů zmizely, přidat znovu.
function M.on_effects_reset(event)
  storage.spec_applied[event.force.index] = {}
  M.apply(event.force)
end

--- Změna mapového nastavení síly specializací – přepočítat bonusy všech sil.
function M.on_setting_changed(event)
  if event.setting == "rt-specialization-multiplier" then M.apply_all() end
end

--- Lokalizované jméno a rich text ikony materiálu specializace (pro GUI).
--- @return LocalisedString, string
function M.label(name)
  local e = entry(name)
  if not e then return { "", name }, "" end
  local proto = e.type == "fluid" and prototypes.fluid[name] or prototypes.item[name]
  return proto and proto.localised_name or { "", name }, "[" .. e.type .. "=" .. name .. "]"
end

return M
