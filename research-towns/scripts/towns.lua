--- Runtime města: založení, popisky, bonus za domy, stav pro GUI/remote, zánik radnice.
local levels = require("shared.levels")
local config = require("scripts.config")
local milestones = require("scripts.milestones")
local names = require("scripts.names")
local network = require("scripts.network")
local scheduler = require("scripts.scheduler")

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

--- Nastaví počet bonusových modulů ve skrytém beaconu podle aktivních domů.
function M.update_bonus(town)
  local beacon = town.beacon
  if not (beacon and beacon.valid) then return end
  local inventory = beacon.get_module_inventory()
  local wanted = levels.bonus_modules(town.level, network.active_houses(town))
  local have = inventory.get_item_count(BONUS_MODULE)
  if wanted > have then
    inventory.insert({ name = BONUS_MODULE, count = wanted - have })
  elseif wanted < have then
    inventory.remove({ name = BONUS_MODULE, count = have - wanted })
  end
end

--- Po změně sítě: přestaví seznamy domů a přepočte bonus dotčených měst.
--- Task 7 sem doplní přepočet překladišť.
--- @param touched table<integer, true>
function M.on_network_changed(touched)
  for id in pairs(touched) do
    local town = storage.towns[id]
    if town then
      network.rebuild_houses(town)
      M.update_bonus(town)
    end
  end
end

--- Založí město s radnicí úrovně 1; nil, když tam radnice nejde postavit.
--- @param position MapPosition střed radnice
function M.create(surface, position, force)
  local name = levels.hall_name(1)
  if not surface.can_place_entity({ name = name, position = position, force = force }) then return nil end
  local hall = surface.create_entity({ name = name, position = position, force = force })
  if not hall then return nil end
  local id = storage.next_town_id
  storage.next_town_id = id + 1
  local town = {
    id = id, name = names.generate(id), level = 1, hall = hall, progress = {},
    depots = {}, houses = {}, power_ok = false,
  }
  town.beacon = surface.create_entity({ name = "rt-hall-beacon", position = hall.position, force = force })
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

--- Stav města pro GUI a remote rozhraní.
function M.status(town)
  local cfg = levels.get(town.level)
  local active = network.active_houses(town)
  local requirements = {}
  for _, req in ipairs(config.upgrade(town.level) or {}) do
    requirements[#requirements + 1] = {
      type = req.type, name = req.name, amount = req.amount,
      delivered = math.min(req.amount, town.progress[milestones.key(req.type, req.name)] or 0),
    }
  end
  local beacon = town.beacon
  return {
    id = town.id, name = town.name, level = town.level, hall = town.hall.unit_number,
    active_houses = active, house_limit = cfg.house_limit,
    bonus = levels.bonus_modules(town.level, active) * levels.BONUS_STEP,
    beacon_modules = beacon and beacon.valid and beacon.get_module_inventory().get_item_count(BONUS_MODULE) or 0,
    power_ok = town.power_ok, power_watts = cfg.power_mw * 1e6,
    requirements = requirements, can_upgrade = M.can_upgrade and M.can_upgrade(town) or false,
  }
end

--- Radnice zanikla. Plán 1: město zaniká, domy se odpojí (ruina přijde v plánu 2).
--- Task 7 doplní uvolnění překladišť.
function M.on_hall_removed(key)
  local node = storage.nodes[key]
  if not node then return end
  local town = storage.towns[node.town]
  local touched = network.remove(key)
  if town then
    if town.beacon and town.beacon.valid then town.beacon.destroy() end
    destroy_labels(town)
    storage.towns[town.id] = nil
  end
  M.on_network_changed(touched)
end

return M
