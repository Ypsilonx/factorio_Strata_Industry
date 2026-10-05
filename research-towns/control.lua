-- Research Towns – napojení událostí na moduly; logika je ve scripts/.
local levels = require("shared.levels")
local state = require("scripts.state")
local scheduler = require("scripts.scheduler")
local network = require("scripts.network")
local towns = require("scripts.towns")
require("scripts.remote")

--- Postavení domu (hráč, robot, skript): připojí ho do sítě.
local function on_built(event)
  local entity = event.entity
  if entity.name == network.HOUSE then
    towns.on_network_changed(network.add(entity, "house"))
  end
end

--- Odstranění budovy města (vytěžení, zničení, skript).
local function on_removed(event)
  local entity = event.entity
  if levels.hall_level(entity.name) then
    towns.on_hall_removed(entity.unit_number)
  elseif entity.name == network.HOUSE then
    towns.on_network_changed(network.remove(entity.unit_number))
  end
end

--- Pravidelné zpracování města (Task 7 doplní suroviny a elektřinu) a další naplánování.
local function process(town)
  if not town.hall.valid then return end
  scheduler.schedule(town, game.tick + levels.TOWN_INTERVAL)
end

local built_filters = { { filter = "name", name = network.HOUSE } }
local removed_filters = {}
for _, name in ipairs(network.names()) do removed_filters[#removed_filters + 1] = { filter = "name", name = name } end

for _, id in ipairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}) do
  script.on_event(id, on_built, built_filters)
end

for _, id in ipairs({
  defines.events.on_player_mined_entity,
  defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy,
}) do
  script.on_event(id, on_removed, removed_filters)
end

script.on_event(defines.events.on_tick, function(event) scheduler.run(event.tick, process) end)
script.on_init(state.init)
script.on_configuration_changed(function()
  state.init()
  scheduler.clear()
  for _, town in pairs(storage.towns) do
    if town.hall.valid then scheduler.schedule(town, game.tick + 1) end
  end
end)
