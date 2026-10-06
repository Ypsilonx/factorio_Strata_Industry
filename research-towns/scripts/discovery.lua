--- Objevení měst hráči: jednou za CHECK_TICKS hledá u každého připojeného hráče neobjevené radnice v okruhu.
--- Neobjevených měst může být hodně, ale hledá se jen v okolí hráčů (filtr na sílu neutral).
local levels = require("shared.levels")
local worldgen = require("shared.worldgen")
local config = require("scripts.config")
local towns = require("scripts.towns")

local M = {}

--- Jak často se kontroluje blízkost hráčů (ticky).
M.CHECK_TICKS = 60

--- Objeví neobjevená města v dosahu připojených hráčů. Fyzická pozice – v mapě (remote view) je
--- player.position pozice kamery a hráč by objevil města bez chůze.
function M.check()
  local radius = worldgen.DISCOVERY_RADIUS + levels.HALL_SIZE / 2
  for _, player in pairs(game.connected_players) do
    local halls = player.physical_surface.find_entities_filtered({ position = player.physical_position,
      radius = radius, name = config.hall_name(1), force = "neutral" })
    for _, hall in pairs(halls) do
      local id = storage.wild_halls[hall.unit_number]
      local town = id and storage.towns[id]
      if town and town.state == "wild" then towns.discover(town, player.force) end
    end
  end
end

return M
