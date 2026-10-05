--- Čistá logika grafu sítě města: uzly = radnice a domy, vazby = visuté chodníky.
local M = {}

--- Množina klíčů dosažitelných ze startu po vazbách (celá komponenta).
--- @param nodes table<any, {links: table<any, true>}>
--- @return table<any, true>
function M.component(nodes, start)
  local seen, queue, head = { [start] = true }, { start }, 1
  while queue[head] do
    local key = queue[head]
    head = head + 1
    for other in pairs(nodes[key].links) do
      if nodes[other] and not seen[other] then
        seen[other] = true
        queue[#queue + 1] = other
      end
    end
  end
  return seen
end

--- Vícezdrojové BFS od radnic: každý dosažitelný dům dostane město nejbližší radnice a hloubku
--- (radnice = 0). Remízu vyhraje radnice dřív v `roots` (volající řadí podle id města).
--- Přes cizí radnici se nepokračuje.
--- @param roots { {key: any, town: integer} }
--- @return table<any, {town: integer, depth: integer}>
function M.assign(nodes, roots)
  local result, queue, head = {}, {}, 1
  for _, root in ipairs(roots) do
    if nodes[root.key] and not result[root.key] then
      result[root.key] = { town = root.town, depth = 0 }
      queue[#queue + 1] = root.key
    end
  end
  while queue[head] do
    local key = queue[head]
    head = head + 1
    local here = result[key]
    for other in pairs(nodes[key].links) do
      local node = nodes[other]
      if node and node.kind ~= "hall" and not result[other] then
        result[other] = { town = here.town, depth = here.depth + 1 }
        queue[#queue + 1] = other
      end
    end
  end
  return result
end

return M
