--- Čistá logika: rozdělení dodávky suroviny mezi příjemce v pořadí priority
--- (spotřeba → milník radnice → vylepšení domu). Příjemce = { requirements = table[]|nil, progress = table }.
local milestones = require("scripts.milestones")

local M = {}

--- Kolik suroviny chtějí příjemci dohromady (nejvýš available).
function M.wanted(sinks, kind, name, available)
  local total = 0
  for _, sink in ipairs(sinks) do
    total = total + milestones.accept(sink.requirements, sink.progress, kind, name, available - total)
  end
  return total
end

--- Připíše skutečně odebrané množství příjemcům v pořadí priority. Přebytek (předměty se odebírají po celých
--- kusech, zásoba spotřeby chce zlomky) dostane první příjemce, který surovinu bral.
function M.distribute(sinks, kind, name, amount)
  local left, first = amount, nil
  for _, sink in ipairs(sinks) do
    local take = milestones.accept(sink.requirements, sink.progress, kind, name, left)
    if take > 0 then
      milestones.add(sink.progress, kind, name, take)
      left = left - take
      first = first or sink
    end
  end
  if first and left > 0 then milestones.add(first.progress, kind, name, left) end
end

return M
