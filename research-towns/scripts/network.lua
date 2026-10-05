--- Runtime síť města: uzly (radnice, domy) ve storage.nodes, vazby = visuté chodníky v dosahu.
--- Příslušnost k městu a hloubku počítá čistá logika scripts/graph.lua.
local levels = require("shared.levels")
local geometry = require("scripts.geometry")
local graph = require("scripts.graph")

local M = {}

--- Jméno prototypu domu.
M.HOUSE = "rt-house"

--- Barva dočasného chodníku (finální sprite z Blenderu je plán 3).
local LINK_COLOR = { r = 0.55, g = 0.45, b = 0.3, a = 0.9 }

--- Jména všech budov sítě (domy + radnice).
function M.names()
  local names = levels.hall_names()
  names[#names + 1] = M.HOUSE
  return names
end

--- Klíč dvojice uzlů pro vykreslený chodník (nezávislý na pořadí).
local function pair_key(a, b)
  if a < b then return a .. ":" .. b end
  return b .. ":" .. a
end

--- Propojí dva uzly a vykreslí chodník.
local function link(a, b)
  a.links[b.key] = true
  b.links[a.key] = true
  storage.renders[pair_key(a.key, b.key)] = rendering.draw_line({
    color = LINK_COLOR, width = 4, from = a.entity.position, to = b.entity.position, surface = a.entity.surface,
  })
end

--- Zruší vazbu dvou uzlů i s vykreslením.
local function unlink(a_key, b_key)
  local other = storage.nodes[b_key]
  if other then other.links[a_key] = nil end
  local key = pair_key(a_key, b_key)
  local render = storage.renders[key]
  if render and render.valid then render.destroy() end
  storage.renders[key] = nil
end

--- Uzly sítě v dosahu entity (mezera mezi okraji ≤ HOUSE_REACH).
local function nodes_in_reach(entity)
  local box = entity.selection_box
  local result = {}
  local found = entity.surface.find_entities_filtered({ area = geometry.expand(box, levels.HOUSE_REACH), name = M.names() })
  for _, other in pairs(found) do
    local node = storage.nodes[other.unit_number]
    if node and other ~= entity and geometry.gap(box, other.selection_box) <= levels.HOUSE_REACH then
      result[#result + 1] = node
    end
  end
  return result
end

--- Je dům aktivní (patří k městu a je nejvýš MAX_HOUSE_DEPTH domů od radnice)?
function M.is_active(node)
  return node.town ~= nil and node.depth ~= nil and node.depth <= levels.MAX_HOUSE_DEPTH
end

--- Nastaví domu grafickou variantu podle úrovně města a ikonu „odpojeno“, když není aktivní.
local function refresh_house(node)
  local town = node.town and storage.towns[node.town]
  node.entity.graphics_variation = town and town.level or 1
  local active = M.is_active(node)
  if active and node.warning then
    if node.warning.valid then node.warning.destroy() end
    node.warning = nil
  elseif not active and not node.warning then
    node.warning = rendering.draw_sprite({
      sprite = "utility/warning_icon", target = { entity = node.entity }, surface = node.entity.surface,
      x_scale = 0.7, y_scale = 0.7,
    })
  end
end

--- Přepočte město a hloubku všech uzlů v komponentách daných klíčů.
--- @param keys any[]
--- @return table<integer, true> dotčená města (stará i nová)
function M.recompute(keys)
  local union = {}
  for _, key in ipairs(keys) do
    if storage.nodes[key] and not union[key] then
      for member in pairs(graph.component(storage.nodes, key)) do union[member] = true end
    end
  end
  local roots, touched = {}, {}
  for key in pairs(union) do
    local node = storage.nodes[key]
    if node.town then touched[node.town] = true end
    if node.kind == "hall" and node.town then roots[#roots + 1] = { key = key, town = node.town } end
  end
  table.sort(roots, function(a, b) return a.town < b.town end)
  local assigned = graph.assign(storage.nodes, roots)
  for key in pairs(union) do
    local node = storage.nodes[key]
    if node.kind == "house" then
      local result = assigned[key]
      node.town = result and result.town
      node.depth = result and result.depth
      if node.town then touched[node.town] = true end
      refresh_house(node)
    end
  end
  return touched
end

--- Zaeviduje budovu sítě, propojí ji se vším v dosahu (radnice s radnicí ne) a přepočte síť.
--- @param kind "hall"|"house"
--- @param town_id integer|nil jen pro radnici
--- @return table<integer, true> dotčená města
function M.add(entity, kind, town_id)
  local node = { key = entity.unit_number, entity = entity, kind = kind, town = town_id, links = {} }
  storage.nodes[node.key] = node
  for _, other in ipairs(nodes_in_reach(entity)) do
    if not (kind == "hall" and other.kind == "hall") then link(node, other) end
  end
  return M.recompute({ node.key })
end

--- Vyřadí budovu ze sítě a přepočte zbytek.
--- @return table<integer, true> dotčená města
function M.remove(key)
  local node = storage.nodes[key]
  if not node then return {} end
  local neighbours = {}
  for other in pairs(node.links) do
    neighbours[#neighbours + 1] = other
    unlink(key, other)
  end
  if node.warning and node.warning.valid then node.warning.destroy() end
  storage.nodes[key] = nil
  local touched = M.recompute(neighbours)
  if node.town then touched[node.town] = true end
  return touched
end

--- Přestaví seznam domů města.
function M.rebuild_houses(town)
  town.houses = {}
  for key, node in pairs(storage.nodes) do
    if node.kind == "house" and node.town == town.id then town.houses[key] = true end
  end
end

--- Počet aktivních domů města.
function M.active_houses(town)
  local count = 0
  for key in pairs(town.houses) do
    local node = storage.nodes[key]
    if node and M.is_active(node) then count = count + 1 end
  end
  return count
end

--- Obnoví vzhled všech domů města (po povýšení).
function M.refresh_town_houses(town)
  for key in pairs(town.houses) do
    local node = storage.nodes[key]
    if node then refresh_house(node) end
  end
end

--- Přenese uzel radnice na novou entitu (výměna prototypu při povýšení – nové unit_number).
function M.replace_hall(old_key, entity)
  local node = storage.nodes[old_key]
  local new_key = entity.unit_number
  storage.nodes[old_key] = nil
  for other_key in pairs(node.links) do
    local other = storage.nodes[other_key]
    other.links[old_key] = nil
    other.links[new_key] = true
    storage.renders[pair_key(new_key, other_key)] = storage.renders[pair_key(old_key, other_key)]
    storage.renders[pair_key(old_key, other_key)] = nil
  end
  node.key = new_key
  node.entity = entity
  storage.nodes[new_key] = node
end

return M
