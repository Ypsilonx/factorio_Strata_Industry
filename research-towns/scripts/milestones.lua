--- Čistá logika milníků: kolik suroviny přijmout a zda je milník splněný.
--- progress = { ["item/wood"] = 120, ["fluid/water"] = 5000 }
local M = {}

--- Tolerance pro kapaliny (odebírají se po desetinných částech).
local EPSILON = 1e-3

--- Klíč postupu pro surovinu.
function M.key(kind, name)
  return kind .. "/" .. name
end

--- Kolik ještě chybí z požadavku.
function M.remaining(req, progress)
  return math.max(0, req.amount - (progress[M.key(req.type, req.name)] or 0))
end

--- Kolik z dostupného množství přijmout (0 = surovina není potřeba nebo je splněná).
--- @param requirements table[]|nil nil = město je na nejvyšší úrovni
function M.accept(requirements, progress, kind, name, available)
  for _, req in ipairs(requirements or {}) do
    if req.type == kind and req.name == name then return math.min(available, M.remaining(req, progress)) end
  end
  return 0
end

--- Připíše přijaté množství k postupu.
function M.add(progress, kind, name, amount)
  local key = M.key(kind, name)
  progress[key] = (progress[key] or 0) + amount
end

--- Jsou splněné všechny požadavky? (bez milníku → false)
function M.complete(requirements, progress)
  if not requirements then return false end
  for _, req in ipairs(requirements) do
    if M.remaining(req, progress) > EPSILON then return false end
  end
  return true
end

return M
