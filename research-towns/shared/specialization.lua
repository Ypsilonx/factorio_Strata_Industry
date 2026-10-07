--- Pravidla specializací měst (čistá logika, sdílí ji runtime i testy): přidělení městu a výše bonusu.
--- Čísla k ladění jsou v shared/levels.lua (SPEC_*).
local levels = require("shared.levels")

local M = {}

--- Specializace pro nové město: ta, kterou má zatím nejméně měst; mezi rovnými podle id města – sousední
--- města tak mají různé specializace a prvních N měst má každé jinou.
--- @param products string[] jména specializací v pořadí z mod-data
--- @param used table<string, integer> kolik měst už danou specializaci má
--- @param id integer id města
--- @return string|nil
function M.pick(products, used, id)
  local least
  for _, name in ipairs(products) do
    local n = used[name] or 0
    if not least or n < least then least = n end
  end
  local candidates = {}
  for _, name in ipairs(products) do
    if (used[name] or 0) == least then candidates[#candidates + 1] = name end
  end
  if #candidates == 0 then return nil end
  return candidates[(id - 1) % #candidates + 1]
end

--- Bonus k produktivitě, který dává jedno partnerské město dané úrovně (SPEC_STEP za úroveň, nejvýš SPEC_TOWN_MAX),
--- × násobič z nastavení modu (výchozí 1, 0 = specializace vypnuté).
function M.town_bonus(level, multiplier)
  return math.min(levels.SPEC_TOWN_MAX, levels.SPEC_STEP * level) * (multiplier or 1)
end

--- Celkový bonus síly z měst se stejnou specializací: nejsilnější město naplno, každé další jen díl
--- (SPEC_DECAY^pořadí), celkem nejvýš SPEC_MAX × násobič (dolů na celá procenta) – deset měst nedá desetinásobek.
--- @param bonuses number[] bonusy jednotlivých měst (už s násobičem)
--- @param multiplier number|nil násobič z nastavení modu (výchozí 1)
function M.total(bonuses, multiplier)
  local sorted = {}
  for i, b in ipairs(bonuses) do sorted[i] = b end
  table.sort(sorted, function(a, b) return a > b end)
  local sum, weight = 0, 1
  for _, b in ipairs(sorted) do
    sum = sum + b * weight
    weight = weight * levels.SPEC_DECAY
  end
  -- Hra drží produktivitu receptu po celých procentech (zbytek zahodí) – zaokrouhlit dolů, ať panel ukazuje
  -- skutečný bonus.
  return math.floor(math.min(levels.SPEC_MAX * (multiplier or 1), sum) * 100 + 1e-6) / 100
end

return M
