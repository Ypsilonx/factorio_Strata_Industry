--- Úrovně vyřešené v data stage (mod-data „rt-levels“): počet úrovní, vědy radnic a milníky.
local levels = require("shared.levels")

local data = prototypes.mod_data["rt-levels"].data

local M = {}

--- Počet vědeckých úrovní (= počet věd ve hře); nad ním jsou nekonečné úrovně.
function M.level_count()
  return data.level_count
end

--- Požadavky na povýšení z dané úrovně ({ {type, name, amount, science?} }). Nad poslední vědou nekonečný milník:
--- suroviny posledního pásma × milestone_scale(level), bez vědy.
function M.upgrade(level)
  if level < data.level_count then return data.upgrade[tostring(level)] end
  return levels.scaled(data.infinite, level)
end

--- Suroviny na vylepšení domu z úrovně house_level: stejné jako milník radnice house_level → +1, bez vědeckých
--- balíčků. Nil, když už dům nemá kam růst (poslední věda).
function M.house_requirements(house_level)
  if house_level >= data.level_count then return nil end
  local list = {}
  for _, req in ipairs(data.upgrade[tostring(house_level)]) do
    if not req.science then list[#list + 1] = req end
  end
  return list
end

--- Vědy, které přijímá radnice dané úrovně.
function M.sciences(level)
  return data.sciences[tostring(levels.hall_tier(level, data.level_count))]
end

--- Jméno prototypu radnice pro úroveň města.
function M.hall_name(level)
  return levels.hall_name(levels.hall_tier(level, data.level_count))
end

--- Jména všech prototypů radnic.
function M.hall_names()
  return levels.hall_names(data.level_count)
end

return M
