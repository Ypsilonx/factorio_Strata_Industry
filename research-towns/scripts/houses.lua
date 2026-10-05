--- Čistá logika: výběr domu k vylepšení. Kandidát = { key, level, depth } aktivního domu.
local M = {}

--- Dům, který se vylepšuje jako další: nejnižší úroveň pod max_level, pak nejmenší hloubka, pak nejmenší klíč.
--- @return table|nil
function M.pick(candidates, max_level)
  local best
  for _, house in ipairs(candidates) do
    if house.level < max_level then
      if not best or house.level < best.level
        or (house.level == best.level and (house.depth < best.depth
          or (house.depth == best.depth and house.key < best.key))) then
        best = house
      end
    end
  end
  return best
end

--- Počet domů, které lze ještě vylepšit.
function M.upgradable(candidates, max_level)
  local count = 0
  for _, house in ipairs(candidates) do
    if house.level < max_level then count = count + 1 end
  end
  return count
end

--- Suroviny na vylepšení domu z milníku radnice: bez vědeckých balíčků. Nil, když nic nezbude
--- (prázdný seznam by znamenal vylepšení zadarmo).
--- @param upgrade table[]|nil požadavky milníku
function M.requirements(upgrade)
  local list = {}
  for _, req in ipairs(upgrade or {}) do
    if not req.science then list[#list + 1] = req end
  end
  return #list > 0 and list or nil
end

return M
