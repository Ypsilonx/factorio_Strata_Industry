--- Runtime města: založení, popisky, bonus za domy, stav pro GUI/remote, zánik radnice.
local levels = require("shared.levels")
local config = require("scripts.config")
local depots = require("scripts.depots")
local milestones = require("scripts.milestones")
local names = require("scripts.names")
local network = require("scripts.network")
local scheduler = require("scripts.scheduler")
local story = require("shared.story")

local M = {}

local LABEL_COLOR = { r = 1, g = 0.85, b = 0.5 }
local BONUS_MODULE = "rt-bonus-module"

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
  local text = { "rt.town-label", town.name, town.level }
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

--- Nastaví počet bonusových modulů ve skrytém beaconu podle aktivních domů.
function M.update_bonus(town)
  local beacon = ensure_beacon(town)
  if not beacon then return end
  local inventory = beacon.get_module_inventory()
  local wanted = levels.bonus_modules(town.level, network.active_house_levels(town))
  local have = inventory.get_item_count(BONUS_MODULE)
  if wanted > have then
    inventory.insert({ name = BONUS_MODULE, count = wanted - have })
  elseif wanted < have then
    inventory.remove({ name = BONUS_MODULE, count = have - wanted })
  end
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

--- Založí město s radnicí úrovně 1; nil, když tam radnice nejde postavit.
--- @param position MapPosition střed radnice
function M.create(surface, position, force)
  local name = config.hall_name(1)
  if not surface.can_place_entity({ name = name, position = position, force = force }) then return nil end
  local hall = surface.create_entity({ name = name, position = position, force = force })
  if not hall then return nil end
  local id = storage.next_town_id
  storage.next_town_id = id + 1
  local town = {
    id = id, name = names.generate(id), level = 1, hall = hall, progress = {},
    depots = {}, houses = {}, power_ok = false,
  }
  storage.towns[id] = town
  -- Bez elektřiny radnice nezkoumá; zapne ji první zpracování (Task 7).
  hall.disabled_by_script = true
  draw_labels(town)
  M.on_network_changed(network.add(hall, "hall", id))
  scheduler.schedule(town, game.tick + 1)
  return town
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

--- Vymění radnici za prototyp dané úrovně (stejný půdorys), přenese obsah, přebarví domy,
--- vynuluje postup milníku a přepočte elektřinu i bonus.
function M.set_level(town, level)
  local old = town.hall
  local surface, position, force = old.surface, old.position, old.force
  local packs = take_inventory(old, defines.inventory.lab_input)
  local modules = take_inventory(old, defines.inventory.lab_modules)
  local old_key = old.unit_number
  old.destroy()
  local hall = surface.create_entity({ name = config.hall_name(level), position = position, force = force })
  restore_inventory(packs, hall, defines.inventory.lab_input)
  restore_inventory(modules, hall, defines.inventory.lab_modules)
  network.replace_hall(old_key, hall)
  town.hall = hall
  town.level = level
  town.progress = {}
  hall.disabled_by_script = not town.power_ok
  network.refresh_town_houses(town)
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

--- Stav města pro GUI a remote rozhraní.
function M.status(town)
  local count = config.level_count()
  local requirements = {}
  for _, req in ipairs(config.upgrade(town.level) or {}) do
    requirements[#requirements + 1] = {
      type = req.type, name = req.name, amount = req.amount,
      delivered = math.min(req.amount, town.progress[milestones.key(req.type, req.name)] or 0),
    }
  end
  local beacon = town.beacon
  return {
    id = town.id, name = town.name, level = town.level, level_count = count, hall = town.hall.unit_number,
    active_houses = network.active_houses(town), house_limit = levels.house_limit(town.level),
    bonus = levels.bonus_modules(town.level, network.active_house_levels(town)) * levels.BONUS_STEP,
    beacon_modules = beacon and beacon.valid and beacon.get_module_inventory().get_item_count(BONUS_MODULE) or 0,
    power_ok = town.power_ok, power_watts = levels.power_mw(town.level, count) * 1e6,
    requirements = requirements, can_upgrade = M.can_upgrade(town),
  }
end

--- Pravidelné zpracování: suroviny z překladišť, kontrola elektřiny, zapnutí/vypnutí výzkumu.
function M.process(town)
  if not town.hall.valid then return end
  depots.collect(town)
  if not (town.beacon and town.beacon.valid) then M.update_bonus(town) end
  town.power_ok = depots.power_ok(town)
  town.hall.disabled_by_script = not town.power_ok
end

--- Radnice zanikla. Plán 1: město zaniká, domy se odpojí a překladiště uvolní (ruina přijde v plánu 2).
function M.on_hall_removed(key)
  local node = storage.nodes[key]
  if not node then return end
  local town = storage.towns[node.town]
  local touched = network.remove(key)
  if town then
    if town.beacon and town.beacon.valid then town.beacon.destroy() end
    destroy_labels(town)
    storage.towns[town.id] = nil
    for depot_key in pairs(town.depots) do
      local depot = storage.depots[depot_key]
      if depot then depots.resolve(depot) end
    end
  end
  M.on_network_changed(touched)
end

return M
