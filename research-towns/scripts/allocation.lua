--- Čistá logika: rozdělení dodávky suroviny mezi příjemce v pořadí priority
--- (spotřeba → milník radnice → vylepšení domu). Příjemce = { requirements = table[]|nil, progress = table }.
--- Předměty se dělí po celých kusech: zlomek, který chce zásoba spotřeby, se zaokrouhlí nahoru pro ni,
--- aby do postupu milníku nepadaly zlomky kusů.
local milestones = require("scripts.milestones")

local M = {}

--- Kolik suroviny příjemce přijme z dostupného množství (předměty nahoru na celé kusy, nejvýš available).
local function take_for(sink, kind, name, available)
  local take = milestones.accept(sink.requirements, sink.progress, kind, name, available)
  if kind == "item" and take > 0 then take = math.min(available, math.ceil(take - 1e-9)) end
  return take
end

--- Kolik suroviny chtějí příjemci dohromady (nejvýš available).
function M.wanted(sinks, kind, name, available)
  local total = 0
  for _, sink in ipairs(sinks) do
    total = total + take_for(sink, kind, name, available - total)
  end
  return total
end

--- Připíše skutečně odebrané množství příjemcům v pořadí priority.
function M.distribute(sinks, kind, name, amount)
  local left = amount
  for _, sink in ipairs(sinks) do
    local take = take_for(sink, kind, name, left)
    if take > 0 then
      milestones.add(sink.progress, kind, name, take)
      left = left - take
    end
  end
end

return M
