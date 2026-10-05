--- Příběh modu: výběr zprávy při povýšení města (texty jsou v locale, sekce [rt]).
local M = {}

--- Počet zpráv o povýšení (`rt.town-upgraded-1` … `-N`); poslední je obecná a opakuje se.
M.UPGRADE_MESSAGES = 6

--- Klíč zprávy pro povýšení města na danou úroveň (úroveň 2 = první zpráva).
--- @param level integer nová úroveň města (≥ 2)
--- @return string locale klíč s parametry __1__ = jméno města, __2__ = úroveň
function M.upgrade_message(level)
  return "rt.town-upgraded-" .. math.min(level - 1, M.UPGRADE_MESSAGES)
end

return M
