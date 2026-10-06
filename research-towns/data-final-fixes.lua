-- Research Towns – vše odvozené z obsahu hry: odstranění laboratoří, úrovně podle věd, milníky, radnice, mod-data.
-- Běží až po final-fixes modů s „menším“ jménem (např. pypostprocessing), takže vidí konečný strom věd.
local levels = require("shared.levels")
local science = require("prototypes.science")
local labs = require("prototypes.labs")
local hall = require("prototypes.hall")

local removed = labs.remove(data.raw, "rt-house")
local lab_names = {}
for name in pairs(removed) do lab_names[#lab_names + 1] = name end
table.sort(lab_names)
log("research-towns: odstraněné laboratoře: " .. table.concat(lab_names, ", "))

local bands, count = science.bands(data.raw)
local sciences = science.sciences(bands, count)
local availability = science.availability(data.raw, science.tech_levels(data.raw, bands))
local exists = science.exists_in(data.raw)

--- Vyřeší pásmo surovin pro milník level → level+1 a zaloguje výsledek.
local function milestone(level)
  local resolved, dropped = science.resolve(levels.TIERS[levels.tier_index(level, count)], availability, level, exists)
  local names = {}
  for _, req in ipairs(resolved) do names[#names + 1] = req.name .. "×" .. req.amount end
  log("research-towns: suroviny milníku " .. level .. "→" .. (level + 1) .. " (základ): " .. table.concat(names, ", ")
    .. (#dropped > 0 and (" | vynecháno: " .. table.concat(dropped, ", ")) or ""))
  return resolved
end

local mod_data = { level_count = count, sciences = {}, upgrade = {} }
log("research-towns: " .. count .. " úrovní (věd)")
for level = 1, count do
  hall.create(level, count, sciences[level])
  mod_data.sciences[tostring(level)] = sciences[level]
  log("research-towns: úroveň " .. level .. " vědy: " .. table.concat(sciences[level], ", "))
  if level < count then
    local upgrade = levels.scaled(milestone(level), level)
    table.insert(upgrade, 1,
      { type = "item", name = science.new_at(bands, level + 1), amount = levels.SCIENCE_PACKS, science = true })
    mod_data.upgrade[tostring(level)] = upgrade
  end
end
-- Nekonečné úrovně: základ posledního pásma, runtime ho násobí milestone_scale(úroveň).
mod_data.infinite = milestone(count)

data:extend({ { type = "mod-data", name = "rt-levels", data = mod_data } })

-- Generátor mapy: posuvník Města a značky míst měst na Nauvisu.
require("prototypes.worldgen")
