--- Úrovně vyřešené v data stage (mod-data „rt-levels“): vědy radnic a suroviny milníků.
local data = prototypes.mod_data["rt-levels"].data

local M = {}

--- Suroviny pro povýšení z dané úrovně ({ {type, name, amount} }), nil na nejvyšší úrovni.
function M.upgrade(level)
  return data.upgrade[tostring(level)]
end

--- Vědy, které přijímá radnice dané úrovně.
function M.sciences(level)
  return data.sciences[tostring(level)]
end

return M
