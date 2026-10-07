--- Kouř z komínů radnice, když zkoumá – aby i ve dne bylo vidět, že město pracuje. Místa komínů spočítá Blender
--- ze stejného modelu jako sprity (shared/night_lights.lua, M.smoke_hall). Lehký kouř hry (trivial smoke) jen
--- u radnic, které právě pracují; při zastavení výzkumu přestane.
local levels = require("shared.levels")
local night = require("shared.night_lights")
local config = require("scripts.config")

local M = {}

--- Jak často se z každého komína vypustí obláček (ticky; nesmí se krýt s jiným on_nth_tick modu).
M.TICKS = 9
--- Druh kouře (vanilla trivial-smoke, jako u kotle) a náhodný rozptyl místa obláčku (dlaždice).
M.NAME = "smoke"
M.SPREAD = 0.15

--- Vypustí kouř z komínů všech pracujících radnic partnerských měst.
function M.tick(event)
  for _, town in pairs(storage.towns) do
    local hall = town.hall
    if town.state == "partner" and hall.valid and hall.status == defines.entity_status.working then
      local variant = levels.variant(levels.hall_level(hall.name), config.level_count())
      local position = hall.position
      -- Střídání komínů podle ticku – obláčky nevycházejí ze všech komínů naráz.
      local points = night.smoke_hall[variant] or {}
      for i, point in ipairs(points) do
        if (event.tick / M.TICKS + i) % 2 < 1 then
          local jitter = ((event.tick * 7 + i * 13) % 11) / 10 - 0.5
          hall.surface.create_trivial_smoke({ name = M.NAME,
            position = { position.x + point[1] + jitter * M.SPREAD, position.y + point[2] } })
        end
      end
    end
  end
end

return M
