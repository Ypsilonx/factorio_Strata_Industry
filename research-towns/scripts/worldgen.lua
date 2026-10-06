--- Runtime generování měst na Nauvisu: náhrada značek míst měst neutrálními radnicemi, vyčištění okolí,
--- hnízda v pozdějších chuncích, první město u spawnu a doplnění měst do rozehrané hry.
local levels = require("shared.levels")
local worldgen = require("shared.worldgen")
local config = require("scripts.config")
local towns = require("scripts.towns")

local M = {}

--- Povrch s městy.
M.SURFACE = "nauvis"

--- Čtverec kolem středu radnice rozšířený o margin.
local function area_around(position, margin)
  local r = levels.HALL_SIZE / 2 + margin
  return { { position.x - r, position.y - r }, { position.x + r, position.y + r } }
end

--- Odstraní stromy, kameny a útesy v půdorysu radnice a pásu TOWN_CLEAR_MARGIN kolem.
local function clear_ground(surface, position)
  local found = surface.find_entities_filtered({ area = area_around(position, worldgen.TOWN_CLEAR_MARGIN),
    type = { "tree", "simple-entity", "cliff" } })
  for _, entity in pairs(found) do
    if entity.valid then entity.destroy() end
  end
end

--- Zničí hnízda a červy biterů v okruhu TOWN_NEST_CLEAR kolem pozice (jen ve vygenerovaných chuncích);
--- area omezí hledání na nový chunk.
local function clear_nests(surface, position, area)
  local spec = { force = "enemy", type = { "unit-spawner", "turret" } }
  if area then spec.area = area else spec.position, spec.radius = position, worldgen.TOWN_NEST_CLEAR end
  for _, entity in pairs(surface.find_entities_filtered(spec)) do
    local dx, dy = entity.position.x - position.x, entity.position.y - position.y
    if entity.valid and dx * dx + dy * dy <= worldgen.TOWN_NEST_CLEAR ^ 2 then entity.destroy() end
  end
end

--- Nahradí značku místa města neutrální radnicí a zaeviduje neobjevené město.
--- @return table|nil město
function M.replace_site(site)
  local surface, position = site.surface, site.position
  site.destroy()
  clear_ground(surface, position)
  local hall = surface.create_entity({ name = config.hall_name(1), position = position, force = "neutral" })
  if not hall then return nil end
  local town = towns.register_wild(hall)
  clear_nests(surface, position)
  return town
end

--- Nový chunk na Nauvisu: značky → radnice; hnízda v chunku blízko známých měst se odstraní.
function M.on_chunk_generated(event)
  local surface = event.surface
  if surface.name ~= M.SURFACE then return end
  for _, site in pairs(surface.find_entities_filtered({ area = event.area, name = worldgen.SITE })) do
    if site.valid then M.replace_site(site) end
  end
  for _, key in ipairs(worldgen.cell_keys_around(event.area, worldgen.TOWN_NEST_CLEAR)) do
    for id in pairs(storage.town_cells[key] or {}) do
      local town = storage.towns[id]
      if town then clear_nests(surface, town.position, event.area) end
    end
  end
end

--- Je kandidát vhodné místo prvního města? (souš, bez útesů a hráčových staveb, daleko od jiných radnic)
local function first_site_ok(surface, position)
  local area = area_around(position, 1)
  if surface.count_tiles_filtered({ area = area, collision_mask = "water_tile" }) > 0 then return false end
  if surface.count_entities_filtered({ area = area, type = "cliff" }) > 0 then return false end
  if surface.count_entities_filtered({ area = area, force = "player" }) > 0 then return false end
  -- Značky ještě nenahrazené radnicí (chunk se právě generuje) se počítají jako radnice.
  local names = config.hall_names()
  names[#names + 1] = worldgen.SITE
  return surface.count_entities_filtered({ position = position, radius = worldgen.FIRST_TOWN_GAP, name = names }) == 0
end

--- Postaví první (partnerské) město 100–200 dlaždic od spawnu, pokud síla player žádné partnerské město nemá.
--- @return table|nil město
function M.ensure_first_town()
  local surface = game.surfaces[M.SURFACE]
  if not surface then return nil end
  local force = game.forces.player
  for _, town in pairs(storage.towns) do
    if town.state == "partner" and town.hall.valid and town.hall.force == force then return nil end
  end
  local spawn = force.get_spawn_position(surface)
  for _, position in ipairs(worldgen.first_town_candidates(spawn, surface.map_gen_settings.seed)) do
    surface.request_to_generate_chunks(position, 1)
    surface.force_generate_chunk_requests()
    if first_site_ok(surface, position) then
      clear_ground(surface, position)
      local town = towns.create(surface, position, force)
      if town then
        clear_nests(surface, position)
        return town
      end
    end
  end
  log("research-towns: první město se nepodařilo umístit")
  return nil
end

--- Biteři neútočí na neutrální města; jednou za hru doplní města do už vygenerovaných chunků (mod přidaný
--- do rozehrané hry) a postaví první město. again = true zopakuje doplnění (testy).
function M.ensure(again)
  game.forces.enemy.set_cease_fire("neutral", true)
  if storage.worldgen_done and not again then return end
  storage.worldgen_done = true
  local surface = game.surfaces[M.SURFACE]
  if not surface then return end
  surface.regenerate_entity({ worldgen.SITE })
  for _, site in pairs(surface.find_entities_filtered({ name = worldgen.SITE })) do
    if site.valid then M.replace_site(site) end
  end
  M.ensure_first_town()
end

return M
