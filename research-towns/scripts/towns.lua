--- Runtime města: založení, popisky, bonus za domy, stav pro GUI/remote, zánik radnice.
local levels = require("shared.levels")
local config = require("scripts.config")
local depots = require("scripts.depots")
local milestones = require("scripts.milestones")
local names = require("scripts.names")
local network = require("scripts.network")
local lights = require("scripts.lights")
local scheduler = require("scripts.scheduler")
local story = require("shared.story")
local houses = require("scripts.houses")
local upkeep = require("scripts.upkeep")
local board = require("scripts.board")
local worldgen = require("shared.worldgen")

local M = {}

local LABEL_COLOR = { r = 1, g = 0.85, b = 0.5 }
local BONUS_MODULE = "rt-bonus-module"
local PRODUCTIVITY_MODULE = "rt-productivity-module"

--- Zajistí noční světla radnice podle jejího vzhledu (vzhled z úrovně prototypu radnice).
function M.refresh_lights(town)
  -- Ruina nesvítí (její světla zmizela s radnicí).
  if not town.hall.valid or town.state == "ruin" then return end
  local variant = levels.variant(levels.hall_level(town.hall.name), config.level_count())
  lights.ensure(town.hall, "hall", variant)
end

--- Zničí popisky města.
local function destroy_labels(town)
  for _, render in pairs(town.labels or {}) do
    if render.valid then render.destroy() end
  end
  town.labels = nil
end

--- Vykreslí popisek nad radnicí a na mapě (podle pozice – přežije výměnu entity při povýšení).
local function draw_labels(town)
  destroy_labels(town)
  local hall = town.hall
  local text = { town.state == "ruin" and "rt.town-label-ruin" or "rt.town-label", town.name, town.level }
  local above = { x = hall.position.x, y = hall.position.y - levels.HALL_SIZE / 2 - 1 }
  town.labels = {
    rendering.draw_text({ text = text, surface = hall.surface, target = above, color = LABEL_COLOR,
      scale = 2, alignment = "center" }),
    rendering.draw_text({ text = text, surface = hall.surface, target = hall.position, color = LABEL_COLOR,
      scale = 1.5, alignment = "center", render_mode = "chart" }),
  }
end

--- Zajistí skrytý beacon radnice: nezničitelný; když přesto zmizí (jiný mod, editor), vytvoří ho znovu.
--- @return LuaEntity|nil
local function ensure_beacon(town)
  local beacon = town.beacon
  if not (beacon and beacon.valid) then
    local hall = town.hall
    if not hall.valid then return nil end
    beacon = hall.surface.create_entity({ name = "rt-hall-beacon", position = hall.position, force = hall.force })
    town.beacon = beacon
  end
  beacon.destructible = false
  return beacon
end

--- Nastaví počet modulů daného jména v inventáři beaconu.
local function set_modules(inventory, name, wanted)
  local have = inventory.get_item_count(name)
  if wanted > have then
    inventory.insert({ name = name, count = wanted - have })
  elseif wanted < have then
    inventory.remove({ name = name, count = have - wanted })
  end
end

--- Nastaví skrytý beacon: moduly rychlosti podle aktivních domů a produktivity podle nekonečné úrovně.
function M.update_bonus(town)
  local beacon = ensure_beacon(town)
  if not beacon then return end
  local inventory = beacon.get_module_inventory()
  set_modules(inventory, BONUS_MODULE, levels.bonus_modules(town.level, network.active_house_levels(town)))
  set_modules(inventory, PRODUCTIVITY_MODULE, levels.productivity_modules(town.level, config.level_count()))
end

--- Po změně sítě: přestaví seznamy domů, přiřazení překladišť a bonus dotčených měst.
--- @param touched table<integer, true>
function M.on_network_changed(touched)
  for id in pairs(touched) do
    local town = storage.towns[id]
    if town then
      network.rebuild_houses(town)
      for key in pairs(town.depots) do
        local depot = storage.depots[key]
        if depot then depots.resolve(depot) end
      end
      M.update_bonus(town)
    end
  end
end

--- Zařadí město do prostorového indexu (hnízda u nových chunků, viz scripts/worldgen.lua).
local function index_add(town)
  local key = worldgen.cell_key(town.position)
  storage.town_cells[key] = storage.town_cells[key] or {}
  storage.town_cells[key][town.id] = true
end

--- Vyřadí město z prostorového indexu.
local function index_remove(town)
  local cell = storage.town_cells[worldgen.cell_key(town.position)]
  if cell then cell[town.id] = nil end
end

--- Založí záznam města pro radnici (jméno, úroveň 1, prázdný postup) a zařadí ho do indexu.
--- @param state "wild"|"partner"
local function new_town(hall, state)
  local id = storage.next_town_id
  storage.next_town_id = id + 1
  local town = {
    id = id, name = names.generate(id), level = 1, hall = hall, state = state, position = hall.position,
    progress = {}, house_progress = {}, stock = {}, upkeep_ok = true, depots = {}, houses = {}, power_ok = false,
  }
  storage.towns[id] = town
  index_add(town)
  return town
end

--- Založí partnerské město s radnicí úrovně 1; nil, když tam radnice nejde postavit.
--- @param position MapPosition střed radnice
function M.create(surface, position, force)
  local name = config.hall_name(1)
  if not surface.can_place_entity({ name = name, position = position, force = force }) then return nil end
  local hall = surface.create_entity({ name = name, position = position, force = force })
  if not hall then return nil end
  local town = new_town(hall, "partner")
  -- Bez elektřiny radnice nezkoumá; zapne ji první zpracování.
  hall.disabled_by_script = true
  draw_labels(town)
  M.on_network_changed(network.add(hall, "hall", town.id))
  M.refresh_lights(town)
  scheduler.schedule(town, game.tick + 1)
  return town
end

--- Zaeviduje neutrální radnici (z generátoru) jako neobjevené město: nezničitelná, vypnutá, mimo síť.
function M.register_wild(hall)
  hall.destructible = false
  hall.disabled_by_script = true
  local town = new_town(hall, "wild")
  storage.wild_halls[hall.unit_number] = town.id
  M.refresh_lights(town)
  -- Odstranění bez události (jiný mod, editor) ohlásí on_object_destroyed.
  script.register_on_object_destroyed(hall)
  return town
end

--- Úrovně partnerských měst síly.
--- @return integer[]
local function partner_levels(force)
  local list = {}
  for _, town in pairs(storage.towns) do
    if town.state == "partner" and town.hall.valid and town.hall.force == force then list[#list + 1] = town.level end
  end
  return list
end

--- Hráč síly objevil město: dar z milníku, který síla už zvládla (stanoví se jednou), popisky, značka na mapě,
--- zpráva a zařazení do plánovače (sběr daru).
function M.discover(town, force)
  local hall = town.hall
  town.state = "discovered"
  town.force = force.name
  town.progress = {}
  town.gift = worldgen.gift(config.upgrade(worldgen.gift_level(partner_levels(force))), worldgen.GIFT_SHARE)
  draw_labels(town)
  force.add_chart_tag(hall.surface, { position = hall.position, text = town.name, icon = { type = "item", name = "rt-house" } })
  local gps = string.format("[gps=%d,%d,%s]", math.floor(hall.position.x), math.floor(hall.position.y), hall.surface.name)
  force.print({ "rt.town-discovered", town.name, gps })
  depots.resolve_unassigned()
  scheduler.schedule(town, game.tick + 1)
end

--- Dar dodán: radnice přejde na sílu, napojí se na síť (domy v dosahu se připojí) a město začne na úrovni 1.
function M.take_over(town, force)
  local hall = town.hall
  storage.wild_halls[hall.unit_number] = nil
  hall.force = force
  hall.destructible = true
  town.state = "partner"
  town.gift = nil
  town.progress = {}
  M.on_network_changed(network.add(hall, "hall", town.id))
  M.refresh(town)
  force.print({ "rt.town-partnered", town.name })
end

--- Neutrální radnice zmizela bez události (jiný mod, editor): město zaniká, překladiště se uvolní.
function M.remove_wild(key)
  local id = storage.wild_halls[key]
  if not id then return end
  storage.wild_halls[key] = nil
  lights.forget(key)
  local town = storage.towns[id]
  if not town then return end
  destroy_labels(town)
  index_remove(town)
  storage.towns[id] = nil
  for depot_key in pairs(town.depots) do
    local depot = storage.depots[depot_key]
    if depot then depots.resolve(depot) end
  end
end

--- Přejmenuje město.
function M.rename(town, name)
  town.name = name
  draw_labels(town)
end

--- Lze město povýšit? (není na max. úrovni, milník splněný, dost aktivních domů)
function M.can_upgrade(town)
  local requirements = config.upgrade(town.level)
  return requirements ~= nil and milestones.complete(requirements, town.progress)
    and network.active_houses(town) >= levels.house_limit(town.level)
end

--- Přesune obsah inventáře entity do dočasného inventáře (zachová trvanlivost balíčků i moduly).
local function take_inventory(entity, inventory_id)
  local source = entity.get_inventory(inventory_id)
  if not source then return nil end
  local buffer = game.create_inventory(#source)
  for i = 1, #source do buffer[i].transfer_stack(source[i]) end
  return buffer
end

--- Vrátí obsah dočasného inventáře do entity a dočasný inventář zničí.
local function restore_inventory(buffer, entity, inventory_id)
  if not buffer then return end
  local target = entity.get_inventory(inventory_id)
  for i = 1, #buffer do
    if buffer[i].valid_for_read then target.insert(buffer[i]) end
  end
  buffer.destroy()
end

--- Vymění entitu radnice za jiný prototyp (stejný půdorys) a přenese balíčky i moduly.
local function replace_hall(town, name)
  local old = town.hall
  local surface, position, force = old.surface, old.position, old.force
  local packs = take_inventory(old, defines.inventory.lab_input)
  local modules = take_inventory(old, defines.inventory.lab_modules)
  local old_key = old.unit_number
  old.destroy()
  local hall = surface.create_entity({ name = name, position = position, force = force })
  restore_inventory(packs, hall, defines.inventory.lab_input)
  restore_inventory(modules, hall, defines.inventory.lab_modules)
  network.replace_hall(old_key, hall)
  town.hall = hall
end

--- Nastaví úroveň města: radnici vymění jen při změně prototypu (nad poslední vědou zůstává), vynuluje postup
--- milníku a přepočte domy, elektřinu, bonus i popisky.
function M.set_level(town, level)
  town.level = level
  town.progress = {}
  M.refresh(town)
end

--- Srovná město s aktuální úrovní, vzorci a prototypy bez ztráty postupu (po povýšení, po změně konfigurace
--- nebo ve starém savu): prototyp radnice, vzhled domů, odběr rozvoden, moduly beaconu a popisky.
function M.refresh(town)
  if not town.hall.valid or town.state ~= "partner" then return end
  local name = config.hall_name(town.level)
  if town.hall.name ~= name then replace_hall(town, name) end
  M.refresh_lights(town)
  town.hall.disabled_by_script = not (town.power_ok and town.upkeep_ok)
  network.refresh_town_houses(town)
  network.redraw_town_links(town)
  depots.apply_town_power(town)
  M.update_bonus(town)
  draw_labels(town)
end

--- Povýší město o úroveň, pokud to podmínky dovolí.
--- @return boolean
function M.upgrade(town)
  if not M.can_upgrade(town) then return false end
  M.set_level(town, town.level + 1)
  town.hall.force.print({ story.upgrade_message(town.level), town.name, town.level })
  return true
end

--- Aktivní domy nejvyšší úrovně pohlcují znečištění v místě domu (za interval zpracování města; ve statistice
--- znečištění jako dům).
--- @param candidates table[] aktivní domy ({ key, level })
local function absorb_pollution(candidates)
  local share = config.absorption_multiplier() * levels.TOWN_INTERVAL / 3600
  for _, house in ipairs(candidates) do
    local amount = levels.house_absorption(house.level) * share
    if amount > 0 then
      local entity = storage.nodes[house.key].entity
      entity.surface.pollute(entity.position, -amount, network.HOUSE)
    end
  end
end

--- Dávají aktivní domy města plný bonus k rychlosti?
local function house_bonus_full(town, candidates)
  local list = {}
  for i, house in ipairs(candidates) do list[i] = house.level end
  return levels.bonus_full(town.level, list)
end

--- Dům, který se právě vylepšuje, a jeho požadavky (nil, nil = nic k vylepšení, i když je bonus plný –
--- suroviny by se utratily zbytečně).
local function house_target(town, candidates)
  if house_bonus_full(town, candidates) then return nil, nil end
  local target = houses.pick(candidates, levels.house_level_max(town.level, config.level_count()))
  return target, target and config.house_requirements(target.level)
end

--- Požadavky s dodaným množstvím pro GUI/remote/tabuli.
local function with_delivered(requirements, progress)
  local list = {}
  for _, req in ipairs(requirements or {}) do
    list[#list + 1] = {
      type = req.type, name = req.name, amount = req.amount,
      delivered = math.min(req.amount, progress[milestones.key(req.type, req.name)] or 0),
    }
  end
  return list
end

--- Spotřeba města za minutu.
local function upkeep_rate(town, active_houses)
  return upkeep.per_minute(config.completed_milestones(town.level), config.upkeep_multiplier(), active_houses)
end

--- Spotřeba se zásobou a cílovou (plnou) zásobou pro GUI/remote/tabuli.
local function upkeep_status(town, active_houses)
  local list = {}
  for i, req in ipairs(upkeep_rate(town, active_houses)) do
    list[i] = { type = req.type, name = req.name, per_minute = req.amount,
      buffer = req.amount * levels.UPKEEP_BUFFER_SECONDS / 60,
      stock = town.stock[milestones.key(req.type, req.name)] or 0 }
  end
  return list
end

--- Postup k další úrovni (0–1): suroviny a věda milníku a počet aktivních domů rovným dílem.
local function level_progress(town)
  local requirements = config.upgrade(town.level)
  if not requirements then return nil end
  local houses_part = network.active_houses(town) / levels.house_limit(town.level)
  return milestones.fraction(requirements, town.progress, { houses_part })
end

--- Stav města pro GUI a remote rozhraní.
function M.status(town)
  if town.state ~= "partner" then
    -- Cizí město ukazuje dar, ruina cenu obnovy.
    local requirements, progress = town.gift, town.progress
    if town.state == "ruin" then requirements, progress = town.repair, town.repair_progress end
    return {
      id = town.id, name = town.name, level = town.level, state = town.state, hall = town.hall.unit_number,
      requirements = with_delivered(requirements, progress), house_requirements = {}, houses_to_upgrade = 0,
      upkeep = {}, power_watts = 0, power_percent = 0,
      level_progress = milestones.fraction(requirements, progress), house_upgrade_progress = nil,
    }
  end
  local count = config.level_count()
  local candidates = network.house_candidates(town)
  local target, house_reqs = house_target(town, candidates)
  local beacon = town.beacon
  return {
    id = town.id, name = town.name, level = town.level, state = town.state, level_count = count,
    hall = town.hall.unit_number,
    active_houses = network.active_houses(town), house_limit = levels.house_limit(town.level),
    bonus = levels.bonus_modules(town.level, network.active_house_levels(town)) * levels.BONUS_STEP,
    productivity = levels.productivity_modules(town.level, count) * levels.BONUS_STEP,
    beacon_modules = beacon and beacon.valid and beacon.get_module_inventory().get_item_count(BONUS_MODULE) or 0,
    power_ok = town.power_ok, power_watts = levels.power_mw(town.level, count) * 1e6,
    power_percent = depots.power_percent(town),
    requirements = with_delivered(config.upgrade(town.level), town.progress), can_upgrade = M.can_upgrade(town),
    house_requirements = with_delivered(house_reqs, town.house_progress),
    houses_to_upgrade = target and houses.upgradable(candidates, levels.house_level_max(town.level, count)) or 0,
    house_target_level = target and target.level,
    house_bonus_full = house_bonus_full(town, candidates),
    level_progress = level_progress(town),
    house_upgrade_progress = milestones.fraction(house_reqs, town.house_progress),
    upkeep = upkeep_status(town, #candidates), upkeep_ok = town.upkeep_ok,
  }
end

--- Zapíše signály do všech tabulí města (stav se počítá jen, když nějaká tabule je).
function M.refresh_boards(town)
  local status
  for key in pairs(town.depots) do
    local depot = storage.depots[key]
    if depot and depot.kind == "board" and depot.entity.valid then
      status = status or M.status(town)
      board.write(depot.entity, board.signals(depot.mode, status))
    end
  end
end

--- Může radnice zkoumat? (rozběhnutý výzkum a v radnici jsou všechny jeho vědy) – jen tehdy se spotřebovává.
local function wants_research(hall)
  local research = hall.force.current_research
  if not research or #research.research_unit_ingredients == 0 then return false end
  local inventory = hall.get_inventory(defines.inventory.lab_input)
  for _, ingredient in pairs(research.research_unit_ingredients) do
    if inventory.get_item_count(ingredient.name) == 0 then return false end
  end
  return true
end

--- Objevené město: sběr daru z překladišť; po dodání celého daru převzetí silou překladišť
--- (bez překladiště silou, která město objevila).
local function process_gift(town)
  depots.collect(town, { { requirements = town.gift, progress = town.progress } })
  if milestones.complete(town.gift, town.progress) then
    M.take_over(town, depots.owner_force(town) or game.forces[town.force])
  else
    M.refresh_boards(town)
  end
end

--- Poloha radnice jako odkaz do chatu ([gps=…]).
local function gps(entity)
  return string.format("[gps=%d,%d,%s]", math.floor(entity.position.x), math.floor(entity.position.y),
    entity.surface.name)
end

--- Ruinu nahradí radnice stejné úrovně: město je zase partnerské (postup milníku, zásoba, domy a překladiště
--- zůstaly), elektřina, bonus, světla a popisky se srovnají.
function M.restore(town)
  local ruin = town.hall
  local key, surface, position, force = ruin.unit_number, ruin.surface, ruin.position, ruin.force
  ruin.destroy()
  local hall = surface.create_entity({ name = config.hall_name(town.level), position = position, force = force })
  network.replace_hall(key, hall)
  town.hall = hall
  town.state = "partner"
  town.repair, town.repair_progress = nil, nil
  -- Bez elektřiny nezkoumá; zapne ji první zpracování.
  town.power_ok = false
  M.refresh(town)
  force.print({ "rt.town-restored", town.name, gps(hall) })
end

--- Ruina: sběr materiálu na obnovu z překladišť; po dodání celé ceny se radnice obnoví.
local function process_repair(town)
  depots.collect(town, { { requirements = town.repair, progress = town.repair_progress } })
  if milestones.complete(town.repair, town.repair_progress) then
    M.restore(town)
  else
    M.refresh_boards(town)
  end
end

--- Pravidelné zpracování: dodávky z překladišť (zásoba spotřeby → milník radnice → vylepšení domu),
--- vylepšení domu, spotřeba zásoby, kontrola elektřiny a zapnutí/vypnutí výzkumu.
function M.process(town)
  if not town.hall.valid then return end
  if town.state ~= "partner" then
    if town.state == "discovered" then process_gift(town) end
    if town.state == "ruin" then process_repair(town) end
    return
  end
  local candidates = network.house_candidates(town)
  local target, house_reqs = house_target(town, candidates)
  local rate = upkeep_rate(town, #candidates)
  depots.collect(town, {
    { requirements = upkeep.times(rate, levels.UPKEEP_BUFFER_SECONDS / 60), progress = town.stock },
    { requirements = config.upgrade(town.level), progress = town.progress },
    { requirements = house_reqs, progress = town.house_progress },
  })
  if house_reqs and milestones.complete(house_reqs, town.house_progress) then
    local node = storage.nodes[target.key]
    node.level = node.level + 1
    town.house_progress = {}
    network.refresh_house(node)
    M.update_bonus(town)
  end
  if not (town.beacon and town.beacon.valid) then M.update_bonus(town) end
  absorb_pollution(candidates)
  -- Elektřina před spotřebou: radnice bez elektřiny nezkoumá, takže ani nespotřebovává.
  town.power_ok = depots.power_ok(town)
  if town.power_ok and wants_research(town.hall) then
    local need = upkeep.times(rate, levels.TOWN_INTERVAL / 3600)
    town.upkeep_ok = upkeep.covered(need, town.stock)
    if town.upkeep_ok then upkeep.consume(need, town.stock) end
  else
    town.upkeep_ok = true
  end
  town.hall.disabled_by_script = not (town.power_ok and town.upkeep_ok)
  M.refresh_boards(town)
end

--- Radnici partnerského města zničili biteři: na stejném místě vznikne nezničitelná ruina jejího vzhledu (hned –
--- skript staví bez kontroly kolize, umírající radnice ještě stojí). Město si drží jméno, úroveň, postup milníku,
--- zásobu, domy i překladiště; nezkoumá, neodebírá elektřinu a čeká na materiál na obnovu. Jiné město zaniká.
--- @param key integer unit_number zničené radnice
function M.on_hall_died(key)
  local node = storage.nodes[key]
  local town = node and storage.towns[node.town]
  if not (town and town.state == "partner" and town.hall.valid) then return M.on_hall_removed(key) end
  local old = town.hall
  local variant = levels.variant(levels.hall_level(old.name), config.level_count())
  local ruin = old.surface.create_entity({ name = levels.ruin_name(variant), position = old.position, force = old.force })
  if not ruin then return M.on_hall_removed(key) end
  ruin.destructible = false
  ruin.disabled_by_script = true
  network.replace_hall(key, ruin)
  town.hall = ruin
  town.state = "ruin"
  town.repair = worldgen.gift(config.upgrade(town.level), levels.REPAIR_SHARE)
  town.repair_progress = {}
  town.power_ok = false
  depots.apply_town_power(town)
  draw_labels(town)
  ruin.force.print({ "rt.town-ruined", town.name, gps(ruin) })
end

--- Radnice zmizela jinak (editor, jiný mod) nebo zanikla ruina: město zaniká, domy se odpojí a překladiště
--- uvolní.
function M.on_hall_removed(key)
  local node = storage.nodes[key]
  if not node then return end
  local town = storage.towns[node.town]
  local touched = network.remove(key)
  if town then
    if town.beacon and town.beacon.valid then town.beacon.destroy() end
    destroy_labels(town)
    index_remove(town)
    storage.towns[town.id] = nil
    for depot_key in pairs(town.depots) do
      local depot = storage.depots[depot_key]
      if depot then depots.resolve(depot) end
    end
  end
  M.on_network_changed(touched)
end

return M
