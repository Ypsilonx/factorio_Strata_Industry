-- Research Towns – napojení událostí na moduly; logika je ve scripts/.
local levels = require("shared.levels")
local state = require("scripts.state")
local scheduler = require("scripts.scheduler")
local network = require("scripts.network")
local depots = require("scripts.depots")
local towns = require("scripts.towns")
local gui = require("scripts.gui")
require("scripts.remote")

--- Postavení domu nebo překladiště (hráč, robot, skript): připojí ho k městu.
local function on_built(event)
  local entity = event.entity
  if entity.name == network.HOUSE then
    towns.on_network_changed(network.add(entity, "house"))
    depots.resolve_unassigned()
  elseif depots.KINDS[entity.name] then
    depots.add(entity)
  end
end

--- Odstranění budovy města (vytěžení, zničení, skript).
local function on_removed(event)
  local entity = event.entity
  if levels.hall_level(entity.name) then
    towns.on_hall_removed(entity.unit_number)
  elseif entity.name == network.HOUSE then
    towns.on_network_changed(network.remove(entity.unit_number))
  elseif depots.KINDS[entity.name] then
    depots.remove(entity.unit_number)
  end
end

--- Pravidelné zpracování města (suroviny, elektřina) a další naplánování.
local function process(town)
  if not town.hall.valid then return end
  towns.process(town)
  scheduler.schedule(town, game.tick + levels.TOWN_INTERVAL)
end

local built_filters = { { filter = "name", name = network.HOUSE } }
local removed_filters = {}
for _, name in ipairs(network.names()) do removed_filters[#removed_filters + 1] = { filter = "name", name = name } end
for _, name in ipairs(depots.names()) do
  built_filters[#built_filters + 1] = { filter = "name", name = name }
  removed_filters[#removed_filters + 1] = { filter = "name", name = name }
end

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
script.on_nth_tick(levels.TOWN_INTERVAL, depots.resolve_unassigned)
script.on_event(defines.events.on_player_created, function(event) gui.ensure(game.get_player(event.player_index)) end)
script.on_event(defines.events.on_gui_opened, gui.on_opened)
script.on_event(defines.events.on_gui_closed, gui.on_closed)
script.on_event(defines.events.on_gui_click, gui.on_click)
script.on_event(defines.events.on_gui_confirmed, gui.on_confirmed)
-- Obnova otevřených panelů; bez otevřeného okna jen jedna kontrola prázdné tabulky.
script.on_nth_tick(gui.REFRESH_TICKS, gui.refresh)
script.on_init(function()
  state.init()
  gui.rebuild_all()
end)
script.on_configuration_changed(function()
  state.init()
  scheduler.clear()
  for _, town in pairs(storage.towns) do
    if town.hall.valid then scheduler.schedule(town, game.tick + 1) end
  end
  gui.rebuild_all()
end)
