--- Čistá logika průběžné spotřeby: radnice spotřebovává suroviny všech splněných milníků (bez vědeckých
--- balíčků). Zásoba = { ["item/wood"] = 12.5, … } ve stejném tvaru jako postup milníku.
local levels = require("shared.levels")
local milestones = require("scripts.milestones")

local M = {}

--- Tolerance pro kapaliny a zlomky.
local EPSILON = 1e-6

--- Spotřeba za minutu: součet množství splněných milníků × UPKEEP_RATE × násobič × (1 + HOUSE_UPKEEP_SHARE × domy).
--- @param completed table[][] požadavky splněných milníků
--- @return table[] { {type, name, amount} } seřazené podle klíče suroviny
function M.per_minute(completed, multiplier, active_houses)
  if multiplier <= 0 then return {} end
  local factor = levels.UPKEEP_RATE * multiplier * (1 + levels.HOUSE_UPKEEP_SHARE * active_houses)
  local sums, keys = {}, {}
  for _, list in ipairs(completed) do
    for _, req in ipairs(list) do
      if not req.science then
        local key = milestones.key(req.type, req.name)
        if not sums[key] then
          sums[key] = { type = req.type, name = req.name, amount = 0 }
          keys[#keys + 1] = key
        end
        sums[key].amount = sums[key].amount + req.amount * factor
      end
    end
  end
  table.sort(keys)
  local result = {}
  for i, key in ipairs(keys) do result[i] = sums[key] end
  return result
end

--- Kopie seznamu s množstvím × factor (spotřeba za minutu → za interval / cílová zásoba).
function M.times(list, factor)
  local out = {}
  for i, req in ipairs(list) do out[i] = { type = req.type, name = req.name, amount = req.amount * factor } end
  return out
end

--- Pokryje zásoba potřebu všech surovin?
function M.covered(need, stock)
  for _, req in ipairs(need) do
    if (stock[milestones.key(req.type, req.name)] or 0) + EPSILON < req.amount then return false end
  end
  return true
end

--- Odebere potřebu ze zásoby (volat jen po covered).
function M.consume(need, stock)
  for _, req in ipairs(need) do
    local key = milestones.key(req.type, req.name)
    stock[key] = math.max(0, (stock[key] or 0) - req.amount)
  end
end

return M
