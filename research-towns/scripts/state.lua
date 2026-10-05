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
  storage.gui_board = storage.gui_board or {}
  storage.next_town_id = storage.next_town_id or 1
  -- Doplnění polí ze starších verzí (0.1.0).
  for _, town in pairs(storage.towns) do
    town.house_progress = town.house_progress or {}
    town.stock = town.stock or {}
    if town.upkeep_ok == nil then town.upkeep_ok = true end
  end
  for _, node in pairs(storage.nodes) do
    if node.kind == "house" then node.level = node.level or 1 end
  end
  for _, depot in pairs(storage.depots) do
    if depot.kind == "board" then depot.mode = depot.mode or "hall" end
  end
end

return M
