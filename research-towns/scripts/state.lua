--- Inicializace tabulek ve storage (nová hra i starší uložená pozice).
local M = {}

--- Založí chybějící tabulky.
function M.init()
  storage.towns = storage.towns or {}
  storage.nodes = storage.nodes or {}
  storage.depots = storage.depots or {}
  storage.renders = storage.renders or {}
  storage.schedule = storage.schedule or {}
  storage.gui = storage.gui or {}
  storage.next_town_id = storage.next_town_id or 1
end

return M
