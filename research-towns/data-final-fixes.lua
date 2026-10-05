-- Research Towns – vše odvozené z obsahu hry: odstranění laboratoří, pásma věd, milníky, radnice, mod-data.
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

local bands = science.bands(data.raw, levels.MAX_LEVEL)
local sciences = science.sciences(bands, levels.MAX_LEVEL)
local availability = science.availability(data.raw, science.tech_levels(data.raw, bands))
local exists = science.exists_in(data.raw)

local mod_data = { sciences = {}, upgrade = {} }
for level = 1, levels.MAX_LEVEL do
  hall.create(level, sciences[level])
  mod_data.sciences[tostring(level)] = sciences[level]
  log("research-towns: úroveň " .. level .. " vědy: " .. table.concat(sciences[level], ", "))
  local upgrade = levels.get(level).upgrade
  if upgrade then
    local resolved, dropped = science.resolve(upgrade, availability, level, exists)
    mod_data.upgrade[tostring(level)] = resolved
    local names = {}
    for _, req in ipairs(resolved) do names[#names + 1] = req.name .. "×" .. req.amount end
    log("research-towns: milník " .. level .. "→" .. (level + 1) .. ": " .. table.concat(names, ", ")
      .. (#dropped > 0 and (" | vynecháno: " .. table.concat(dropped, ", ")) or ""))
  end
end

data:extend({ { type = "mod-data", name = "rt-levels", data = mod_data } })
