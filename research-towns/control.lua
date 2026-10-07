-- Research Towns – napojení událostí na moduly; logika je ve scripts/.
local levels = require("shared.levels")
local state = require("scripts.state")
local scheduler = require("scripts.scheduler")
local network = require("scripts.network")
local lights = require("scripts.lights")
local depots = require("scripts.depots")
local towns = require("scripts.towns")
local specializations = require("scripts.specializations")
local gui = require("scripts.gui")
local worldgen = require("scripts.worldgen")
local discovery = require("scripts.discovery")
local board = require("scripts.board")
require("scripts.remote")

--- Postavení domu nebo překladiště (hráč, robot, skript): připojí ho k městu.
local function on_built(event)
  local entity = event.entity
  if entity.name == network.HOUSE then
    towns.on_network_changed(network.add(entity, "house"))
    depots.resolve_unassigned()
  elseif depots.KINDS[entity.name] then
    depots.add(entity, event.tags)
  end
end

--- Odstranění budovy města (vytěžení, zničení, skript).
local function on_removed(event)
  local entity = event.entity
  if levels.hall_level(entity.name) then
    -- Zničená radnice (biteři) se změní v ruinu; jinak (skript) město zaniká.
    if event.name == defines.events.on_entity_died then
      towns.on_hall_died(entity.unit_number)
    else
      towns.on_hall_removed(entity.unit_number)
    end
  elseif entity.name == network.HOUSE then
    towns.on_network_changed(network.remove(entity.unit_number))
  elseif depots.KINDS[entity.name] then
    depots.remove(entity.unit_number)
  end
end

--- Budova zmizela bez události (jiný mod, editor, smazání chunku); useful_id = unit_number.
--- Už uklizené záznamy (běžné odstranění, výměna radnice) tu nic nenajdou.
local function on_object_destroyed(event)
  local key = event.useful_id
  local node = key and storage.nodes[key]
  if node then
    if node.kind == "hall" then
      towns.on_hall_removed(key)
    else
      towns.on_network_changed(network.remove(key))
    end
  elseif key and storage.wild_halls[key] then
    towns.remove_wild(key)
  elseif key and storage.depots[key] then
    depots.remove(key)
  end
end

--- Shift+klik kopírování nastavení mezi tabulemi přenese režim; signály se přepíšou hned
--- (vložení přepsalo i signály kombinátoru signály zdrojové tabule).
local function on_settings_pasted(event)
  local source = storage.depots[event.source.unit_number]
  local target = storage.depots[event.destination.unit_number]
  if not (target and target.kind == "board") then return end
  if source and source.kind == "board" then target.mode = source.mode end
  local town = target.town and storage.towns[target.town]
  if town and town.hall.valid then
    towns.refresh_boards(town)
  else
    board.write(target.entity, {})
  end
end

--- Plán, do kterého se zapisují tagy: záznam v knihovně, předmět plánu, nebo plán v přípravě (starší cesty).
--- @return LuaRecord|LuaItemStack|nil
local function blueprint_target(event, player)
  local record = event.record
  if record and record.valid and record.type == "blueprint" then return record end
  local candidates = { event.stack, player.blueprint_to_setup, player.cursor_stack }
  -- Pole s nil uprostřed – ipairs by skončil u prvního nil.
  for i = 1, 3 do
    local stack = candidates[i]
    if stack and stack.valid_for_read and stack.is_blueprint then return stack end
  end
  return nil
end

--- Plán (blueprint) si u tabulí zapamatuje režim do tagu.
local function on_setup_blueprint(event)
  local target = blueprint_target(event, game.get_player(event.player_index))
  if not target then return end
  for index, entity in pairs(event.mapping.get()) do
    local depot = entity.valid and storage.depots[entity.unit_number]
    if depot and depot.kind == "board" then target.set_blueprint_entity_tag(index, board.TAG, depot.mode) end
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
script.on_event(defines.events.on_object_destroyed, on_object_destroyed)
script.on_event(defines.events.on_chunk_generated, worldgen.on_chunk_generated)
script.on_event(defines.events.on_player_created, function(event) gui.ensure(game.get_player(event.player_index)) end)
script.on_event(defines.events.on_gui_opened, gui.on_opened)
script.on_event(defines.events.on_gui_closed, gui.on_closed)
script.on_event(defines.events.on_gui_click, gui.on_click)
script.on_event(defines.events.on_gui_confirmed, gui.on_confirmed)
script.on_event(defines.events.on_gui_selection_state_changed, gui.on_selection_changed)
script.on_event(defines.events.on_entity_settings_pasted, on_settings_pasted)
script.on_event(defines.events.on_player_setup_blueprint, on_setup_blueprint)
script.on_event(defines.events.on_technology_effects_reset, specializations.on_effects_reset)
script.on_event(defines.events.on_runtime_mod_setting_changed, specializations.on_setting_changed)
-- Obnova otevřených panelů; bez otevřeného okna jen jedna kontrola prázdné tabulky.
script.on_nth_tick(gui.REFRESH_TICKS, gui.refresh)
-- Objevení měst hráči (60 se nekryje s TOWN_INTERVAL ani REFRESH_TICKS – stejné číslo by handler přepsalo).
script.on_nth_tick(discovery.CHECK_TICKS, discovery.check)
script.on_init(function()
  state.init()
  worldgen.ensure()
  gui.rebuild_all()
end)
script.on_configuration_changed(function()
  state.init()
  scheduler.clear()
  -- Pozice nočních světel z Blenderu se mohly změnit – vykreslit znovu (domy při towns.refresh níže).
  lights.reset()
  for _, node in pairs(storage.nodes) do
    if node.kind == "house" and node.entity.valid then network.refresh_house(node) end
  end
  -- Specializace: starší save je nemá, po změně modů mohla zmizet (přidělení v pořadí id – stejné výsledky).
  local ids = {}
  for id in pairs(storage.towns) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do specializations.assign(storage.towns[id]) end
  for _, town in pairs(storage.towns) do
    towns.refresh_lights(town)
  end
  for _, town in pairs(storage.towns) do
    -- Neobjevená města se nezpracovávají; objevená jen kvůli daru.
    if town.hall.valid and town.state ~= "wild" then
      -- Vzorce, počet úrovní (jiné mody) i prototypy se mohly změnit – srovnat bez ztráty postupu.
      towns.refresh(town)
      scheduler.schedule(town, game.tick + 1)
    end
  end
  specializations.apply_all()
  -- Starší save má spojení jako jednoduché čáry – překreslit na chodník a šňůru.
  network.redraw_links()
  worldgen.ensure()
  gui.rebuild_all()
end)
