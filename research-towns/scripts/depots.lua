--- Runtime překladiště: přiřazení k nejbližší budově města, výběr surovin podle priority, elektřina města.
local levels = require("shared.levels")
local config = require("scripts.config")
local geometry = require("scripts.geometry")
local allocation = require("scripts.allocation")
local board = require("scripts.board")
local network = require("scripts.network")

local M = {}

--- Prototypy překladišť a jejich druh.
M.KINDS = {
  ["rt-goods-depot"] = "goods", ["rt-fluid-depot"] = "fluid", ["rt-power-depot"] = "power", ["rt-town-board"] = "board",
}

--- Skrytý spotřebič města pod městskou rozvodnou (prototypes/depots.lua).
M.LOAD = "rt-power-load"

--- Spotřebič městské rozvodny (platný), nebo nil.
--- @return LuaEntity|nil
local function load_of(depot)
  return depot.load and depot.load.valid and depot.load or nil
end

--- Zajistí rozvodně skrytý spotřebič města na jejím místě (nová rozvodna, starší save).
local function ensure_load(depot)
  if depot.kind ~= "power" or load_of(depot) or not depot.entity.valid then return end
  local entity = depot.entity
  depot.load = entity.surface.create_entity({ name = M.LOAD, position = entity.position, force = entity.force })
end

--- Zajistí spotřebiče všech městských rozvoden (po změně verze modu).
function M.ensure_loads()
  for _, depot in pairs(storage.depots) do ensure_load(depot) end
end

--- Jména prototypů překladišť.
function M.names()
  return { "rt-goods-depot", "rt-fluid-depot", "rt-power-depot", "rt-town-board" }
end

--- Nastaví odběr všech rozvoden města: příkon úrovně rozdělený rovným dílem; bez města nic.
--- Zásobník jen na 2 ticky odběru: větší zásobník by si při přetížené síti bral víc než svůj podíl
--- (žádá se celý schodek) a kontrola v power_ok by pak selhala až při téměř nulové elektřině.
function M.apply_town_power(town)
  local list = {}
  for key in pairs(town.depots) do
    local depot = storage.depots[key]
    if depot and depot.kind == "power" and load_of(depot) then list[#list + 1] = depot end
  end
  -- Ruina (a cizí město) elektřinu neodebírá.
  local total = town.state == "partner" and levels.power_per_tick(town.level, config.level_count()) or 0
  for _, depot in ipairs(list) do
    local usage = total / #list
    depot.load.power_usage = usage
    depot.load.electric_buffer_size = math.max(1, usage * 2)
  end
end

--- Vypne odběr rozvodny bez města.
local function release_power(depot)
  local load = depot.kind == "power" and load_of(depot)
  if load then
    load.power_usage = 0
    load.electric_buffer_size = 1
  end
end

--- Je uzel platnou kotvou překladiště? (radnice města nebo aktivní dům)
local function anchors(node)
  if node.kind == "hall" then return node.town ~= nil end
  return network.is_active(node)
end

--- Město, ke kterému se překladiště může připojit přes budovu other (nil = nemůže): radnice nebo aktivní dům
--- partnerského města; objevená cizí radnice jen kvůli daru (zboží, kapaliny, tabule – rozvodna ne).
local function anchor_town(depot, other)
  local node = storage.nodes[other.unit_number]
  if node then return anchors(node) and node.town or nil end
  local id = storage.wild_halls[other.unit_number]
  local town = id and storage.towns[id]
  if town and town.state == "discovered" and depot.kind ~= "power" then return id end
  return nil
end

--- Přiřadí překladiště k městu nejbližší kotvy v dosahu (remíza → nižší id města) a přepočte elektřinu.
function M.resolve(depot)
  local entity = depot.entity
  -- Zmizelo bez události – záznam uklidí jeho vlastní on_object_destroyed.
  if not entity.valid then return end
  local box = entity.selection_box
  local best_town, best_gap
  local found = entity.surface.find_entities_filtered({ area = geometry.expand(box, levels.DEPOT_REACH), name = network.names() })
  for _, other in pairs(found) do
    local town_id = anchor_town(depot, other)
    if town_id then
      local gap = geometry.gap(box, other.selection_box)
      if gap <= levels.DEPOT_REACH and (not best_town or gap < best_gap or (gap == best_gap and town_id < best_town)) then
        best_town, best_gap = town_id, gap
      end
    end
  end
  local old = depot.town
  depot.town = best_town
  -- Tabule bez města nesmí posílat staré požadavky.
  if depot.kind == "board" and not depot.town then board.write(entity, {}) end
  if old == depot.town then return end
  local old_town = old and storage.towns[old]
  if old_town then
    old_town.depots[depot.key] = nil
    M.apply_town_power(old_town)
  end
  if depot.town then
    local town = storage.towns[depot.town]
    town.depots[depot.key] = true
    M.apply_town_power(town)
  else
    release_power(depot)
  end
end

--- Zaeviduje nové překladiště nebo tabuli; tagy z plánu nesou režim tabule.
--- @param tags table|nil
function M.add(entity, tags)
  local depot = { key = entity.unit_number, entity = entity, kind = M.KINDS[entity.name] }
  if depot.kind == "board" then
    -- Tag z importovaného plánu může nést cokoli.
    local mode = tags and tags[board.TAG]
    depot.mode = board.is_mode(mode) and mode or "hall"
  end
  storage.depots[depot.key] = depot
  ensure_load(depot)
  -- Odstranění bez události (jiný mod, editor) ohlásí on_object_destroyed.
  script.register_on_object_destroyed(entity)
  release_power(depot)
  M.resolve(depot)
  return depot
end

--- Vyřadí překladiště (vytěžení/zničení) a přepočte elektřinu jeho města.
function M.remove(key)
  local depot = storage.depots[key]
  if not depot then return end
  storage.depots[key] = nil
  if depot.load and depot.load.valid then depot.load.destroy() end
  local town = depot.town and storage.towns[depot.town]
  if town then
    town.depots[key] = nil
    M.apply_town_power(town)
  end
end

--- Zkusí přiřadit překladiště bez města (po změnách sítě se nová kotva mohla objevit kdekoli).
function M.resolve_unassigned()
  for _, depot in pairs(storage.depots) do
    if not depot.town and depot.entity.valid then M.resolve(depot) end
  end
end

--- Vybere z překladišť města suroviny pro příjemce v pořadí priority (každá kvalita se počítá).
--- @param sinks table[] { {requirements = table[]|nil, progress = table} } – viz scripts/allocation.lua
function M.collect(town, sinks)
  for key in pairs(town.depots) do
    local depot = storage.depots[key]
    local entity = depot and depot.entity
    if entity and entity.valid then
      if depot.kind == "goods" then
        local inventory = entity.get_inventory(defines.inventory.chest)
        for _, item in pairs(inventory.get_contents()) do
          local take = allocation.wanted(sinks, "item", item.name, item.count)
          if take > 0 then
            local removed = inventory.remove({ name = item.name, quality = item.quality, count = take })
            allocation.distribute(sinks, "item", item.name, removed)
          end
        end
      elseif depot.kind == "fluid" then
        local fluid = entity.fluidbox[1]
        if fluid then
          local take = allocation.wanted(sinks, "fluid", fluid.name, fluid.amount)
          if take > 0 then
            allocation.distribute(sinks, "fluid", fluid.name, entity.remove_fluid({ name = fluid.name, amount = take }))
          end
        end
      end
    end
  end
end

--- Bere spotřebič elektřinu přes městskou rozvodnu? (je ve stejné elektrické síti jako ona – klasická rozvodna,
--- která spotřebič jen přikryje plochou bez městské rozvodny v síti, se nepočítá)
local function fed_by_pole(depot)
  local load = load_of(depot)
  return load ~= nil and depot.entity.valid and load.electric_network_id ~= nil
    and load.electric_network_id == depot.entity.electric_network_id
end

--- Je spotřeba města pokrytá? (aspoň jedna rozvodna; každá napájená přes sebe a s aspoň jedním tickem odběru
--- v zásobníku)
function M.power_ok(town)
  local any = false
  for key in pairs(town.depots) do
    local depot = storage.depots[key]
    if depot and depot.kind == "power" then
      any = true
      local load = load_of(depot)
      if not (load and fed_by_pole(depot)) or load.energy < load.power_usage then return false end
    end
  end
  return any
end

--- Pokrytí elektřiny města v procentech (nejhorší rozvodna; bez rozvodny 0).
function M.power_percent(town)
  local worst
  for key in pairs(town.depots) do
    local depot = storage.depots[key]
    local entity = depot and depot.kind == "power" and load_of(depot)
    if entity and entity.power_usage > 0 then
      local ratio = fed_by_pole(depot) and math.min(1, entity.energy / entity.power_usage) or 0
      if not worst or ratio < worst then worst = ratio end
    end
  end
  return math.floor((worst or 0) * 100)
end

--- Spotřebič městské rozvodny (testy).
function M.load_of(key)
  local depot = storage.depots[key]
  return depot and load_of(depot)
end

--- Síla překladišť města (první podle unit_number, tabule se nepočítá), nebo nil.
function M.owner_force(town)
  local keys = {}
  for key in pairs(town.depots) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local depot = storage.depots[key]
    if depot and depot.kind ~= "board" and depot.entity.valid then return depot.entity.force end
  end
  return nil
end

return M
