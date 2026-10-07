--- Runtime síť města: uzly (radnice, domy) ve storage.nodes, vazby = spojení budov v dosahu (chodník a šňůra).
--- Příslušnost k městu a hloubku počítá čistá logika scripts/graph.lua.
local levels = require("shared.levels")
local config = require("scripts.config")
local geometry = require("scripts.geometry")
local graph = require("scripts.graph")
local links = require("scripts.links")
local lights = require("scripts.lights")

local M = {}

--- Jméno prototypu domu.
M.HOUSE = "rt-house"

--- Vzhled spojení budov: vyšlapaný chodník na zemi, šňůra (jako dráty, nad pásy a insertery), její stín
--- a lucerny. Tvar a praporky počítá scripts/links.lua. Jen vykreslení – nic nemá kolizi.
local PATH_COLOR = { r = 0.3, g = 0.25, b = 0.17, a = 0.55 }
local PATH_WIDTH = 10
local ROPE_COLOR = { r = 0.16, g = 0.12, b = 0.08, a = 1 }
local ROPE_SHADOW = { r = 0, g = 0, b = 0, a = 0.25 }
--- Posun stínu šňůry na zemi (slunce zleva shora → stín doprava dolů).
local ROPE_SHADOW_OFFSET = { x = 0.5, y = 0.35 }
local LANTERN_COLOR = { r = 1, g = 0.72, b = 0.38, a = 1 }
--- Vrstva lávky na zemi: nad vyšlapaným chodníkem (ground-patch), pod budovami i předměty na zemi.
local WALKWAY_LAYER = "ground-patch-higher"
--- Barva čísla úrovně nad domem (jen v Alt režimu).
local LEVEL_COLOR = { r = 1, g = 0.85, b = 0.5 }

--- Jména všech budov sítě (domy + radnice).
function M.names()
  local names = config.hall_names()
  names[#names + 1] = M.HOUSE
  return names
end

--- Klíč dvojice uzlů pro vykreslený chodník (nezávislý na pořadí).
local function pair_key(a, b)
  if a < b then return a .. ":" .. b end
  return b .. ":" .. a
end

--- Úchyt šňůry nad budovou (pozice na mapě posunutá nahoru o výšku střechy).
local function anchor(node)
  local p = node.entity.position
  return { x = p.x, y = p.y - links.ANCHOR[node.kind == "hall" and "hall" or "house"] }
end

--- Styl spojení podle vzhledu města (šňůra / dřevěná / prosklená lávka); domy bez města mají šňůru.
local function link_style(a, b)
  local town = storage.towns[a.town or b.town or 0]
  if not (town and town.state == "partner") then return "garland" end
  return links.style(levels.variant(town.level, config.level_count()))
end

--- Lávka (prkenná / dlážděná cesta) na zemi mezi středy budov: úseky spritu natočené po směru spojení.
--- Leží pod budovami (vrstva nad vyšlapaným chodníkem), takže konce zakryje budova.
local function draw_walkway(add, a, b, style, surface)
  local sprite = "rt-skywalk-" .. style
  local pa, pb = a.entity.position, b.entity.position
  for _, s in ipairs(links.walkway(pa, pb)) do
    add(rendering.draw_sprite({ sprite = sprite, target = s.center, surface = surface, orientation = s.orientation,
      x_scale = s.length, render_layer = WALKWAY_LAYER }))
  end
  local middle = { x = (pa.x + pb.x) / 2, y = (pa.y + pb.y) / 2 }
  add(rendering.draw_light({ sprite = "utility/light_small", target = middle, surface = surface, scale = 0.8,
    intensity = 0.5, minimum_darkness = 0.3, color = LANTERN_COLOR }))
end

--- Vykreslí spojení dvou budov; vrátí seznam vykreslených objektů (pole + .style).
--- @return LuaRenderObject[]
local function draw_link(a, b)
  local surface = a.entity.surface
  local pa, pb = a.entity.position, b.entity.position
  local list = { style = link_style(a, b) }
  local function add(object) list[#list + 1] = object end
  -- Vyšlapaný chodník je skrytý; ukáže se jen při najetí myší na budovu města (M.on_selected) jako trasa sítě.
  list.path = rendering.draw_line({ color = PATH_COLOR, width = PATH_WIDTH, from = pa, to = pb, surface = surface,
    render_layer = "ground-patch", visible = false })
  add(list.path)
  if list.style ~= "garland" then
    draw_walkway(add, a, b, list.style, surface)
    return list
  end
  local o = ROPE_SHADOW_OFFSET
  add(rendering.draw_line({ color = ROPE_SHADOW, width = 2, surface = surface, render_layer = "ground-patch-higher",
    from = { pa.x + o.x, pa.y + o.y }, to = { pb.x + o.x, pb.y + o.y } }))
  local points = links.rope(anchor(a), anchor(b), links.ROPE_SEGMENTS)
  for i = 2, #points do
    add(rendering.draw_line({ color = ROPE_COLOR, width = 2, from = points[i - 1], to = points[i], surface = surface,
      render_layer = "wires" }))
  end
  for _, flag in ipairs(links.flags(points, a.key + b.key)) do
    add(rendering.draw_polygon({ color = links.FLAG_COLORS[flag.color], vertices = flag.vertices, surface = surface,
      render_layer = "wires" }))
  end
  for _, p in ipairs(links.lanterns(points)) do
    add(rendering.draw_circle({ color = LANTERN_COLOR, radius = 0.08, filled = true, target = p, surface = surface,
      render_layer = "wires" }))
    add(rendering.draw_light({ sprite = "utility/light_small", target = p, surface = surface, scale = 0.6,
      intensity = 0.6, minimum_darkness = 0.3, color = LANTERN_COLOR }))
  end
  return list
end

--- Skryje hráči chodníky, které mu ukázalo najetí myší.
local function hide_paths(player_index)
  for _, path in ipairs(storage.link_hover[player_index] or {}) do
    if path.valid then
      local players = {}
      for _, p in ipairs(path.players) do
        local index = type(p) == "number" and p or p.index
        if index ~= player_index then players[#players + 1] = index end
      end
      path.players = players
      -- Prázdný seznam hráčů = vidí všichni – bez dalšího hráče skrýt úplně.
      path.visible = #players > 0
    end
  end
  storage.link_hover[player_index] = nil
end

--- Najetí myší na budovu města: hráči se ukážou chodníky celé sítě města (bez města jen spojení té budovy),
--- jako trasa u potrubí; předchozí ukázané se skryjí.
function M.on_selected(event)
  local player = game.get_player(event.player_index)
  hide_paths(event.player_index)
  local selected = player and player.selected
  local node = selected and selected.unit_number and storage.nodes[selected.unit_number]
  if not node then return end
  local keys = { node.key }
  if node.town then
    keys = {}
    for key, other in pairs(storage.nodes) do
      if other.town == node.town then keys[#keys + 1] = key end
    end
  end
  local shown, seen = {}, {}
  for _, key in ipairs(keys) do
    for other in pairs(storage.nodes[key].links) do
      local pair = pair_key(key, other)
      local value = storage.renders[pair]
      local path = not seen[pair] and type(value) == "table" and value.path
      seen[pair] = true
      if path and path.valid then
        local players = {}
        for _, p in ipairs(path.players) do players[#players + 1] = type(p) == "number" and p or p.index end
        players[#players + 1] = event.player_index
        path.players = players
        path.visible = true
        shown[#shown + 1] = path
      end
    end
  end
  storage.link_hover[event.player_index] = shown
end

--- Je chodník spojení dvou budov vidět? (testy; nil = spojení neexistuje)
function M.link_path_visible(a_key, b_key)
  local value = storage.renders[pair_key(a_key, b_key)]
  local path = type(value) == "table" and value.path
  if not (path and path.valid) then return nil end
  return path.visible
end

--- Zničí vykreslení spojení (seznam objektů, nebo jeden objekt ze staršího savu).
local function destroy_renders(value)
  if not value then return end
  if value.object_name == "LuaRenderObject" then
    if value.valid then value.destroy() end
    return
  end
  for _, object in ipairs(value) do
    if object.valid then object.destroy() end
  end
end

--- Propojí dva uzly a vykreslí spojení.
local function link(a, b)
  a.links[b.key] = true
  b.links[a.key] = true
  local key = pair_key(a.key, b.key)
  destroy_renders(storage.renders[key])
  storage.renders[key] = draw_link(a, b)
end

--- Zruší vazbu dvou uzlů i s vykreslením.
local function unlink(a_key, b_key)
  local other = storage.nodes[b_key]
  if other then other.links[a_key] = nil end
  local key = pair_key(a_key, b_key)
  destroy_renders(storage.renders[key])
  storage.renders[key] = nil
end

--- Překreslí všechna spojení (po změně verze – starší save má jednoduché čáry).
function M.redraw_links()
  for key, value in pairs(storage.renders) do
    destroy_renders(value)
    local a_key, b_key = key:match("^(%d+):(%d+)$")
    local a, b = storage.nodes[tonumber(a_key)], storage.nodes[tonumber(b_key)]
    if a and b and a.entity.valid and b.entity.valid then
      storage.renders[key] = draw_link(a, b)
    else
      storage.renders[key] = nil
    end
  end
end

--- Překreslí spojení budov města (po změně úrovně se mění styl: šňůra → lávka).
function M.redraw_town_links(town)
  local keys = { town.hall.unit_number }
  for key in pairs(town.houses) do keys[#keys + 1] = key end
  local done = {}
  for _, key in ipairs(keys) do
    local node = storage.nodes[key]
    for other_key in pairs(node and node.links or {}) do
      local pair = pair_key(key, other_key)
      local other = storage.nodes[other_key]
      if not done[pair] and other and node.entity.valid and other.entity.valid then
        done[pair] = true
        destroy_renders(storage.renders[pair])
        storage.renders[pair] = draw_link(node, other)
      end
    end
  end
end

--- Styl vykresleného spojení dvou uzlů, nebo nil (testy; starší save s jednou čárou nemá styl).
function M.link_style(a_key, b_key)
  local value = storage.renders[pair_key(a_key, b_key)]
  return value and value.object_name ~= "LuaRenderObject" and value.style or nil
end

--- Počet platných vykreslených objektů spojení dvou uzlů (testy).
function M.link_render_count(a_key, b_key)
  local value = storage.renders[pair_key(a_key, b_key)]
  if not value then return 0 end
  if value.object_name == "LuaRenderObject" then return value.valid and 1 or 0 end
  local count = 0
  for _, object in ipairs(value) do
    if object.valid then count = count + 1 end
  end
  return count
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

--- Nastaví domu grafickou variantu a číslo podle jeho úrovně a ikonu „odpojeno“, když není aktivní.
function M.refresh_house(node)
  if not node.entity.valid then return end
  node.entity.graphics_variation = levels.house_variant(node.level)
  lights.ensure(node.entity, "house", levels.house_variant(node.level))
  if node.label and node.label.valid then
    node.label.text = tostring(node.level)
  else
    node.label = rendering.draw_text({
      text = tostring(node.level), surface = node.entity.surface, target = { entity = node.entity },
      color = LEVEL_COLOR, scale = 2, alignment = "center", vertical_alignment = "middle", only_in_alt_mode = true,
    })
  end
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
      M.refresh_house(node)
    end
  end
  return touched
end

--- Zaeviduje budovu sítě, propojí ji se vším v dosahu (radnice s radnicí ne) a přepočte síť.
--- @param kind "hall"|"house"
--- @param town_id integer|nil jen pro radnici
--- @return table<integer, true> dotčená města
function M.add(entity, kind, town_id)
  local node = { key = entity.unit_number, entity = entity, kind = kind, town = town_id, links = {},
    level = kind == "house" and 1 or nil }
  storage.nodes[node.key] = node
  -- Odstranění bez události (jiný mod, editor) ohlásí on_object_destroyed.
  script.register_on_object_destroyed(entity)
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
  if node.label and node.label.valid then node.label.destroy() end
  lights.forget(key)
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

--- Úrovně aktivních domů města.
--- @return integer[]
function M.active_house_levels(town)
  local list = {}
  for key in pairs(town.houses) do
    local node = storage.nodes[key]
    if node and M.is_active(node) then list[#list + 1] = node.level end
  end
  return list
end

--- Aktivní domy města jako kandidáti vylepšení { key, level, depth }.
function M.house_candidates(town)
  local list = {}
  for key in pairs(town.houses) do
    local node = storage.nodes[key]
    if node and M.is_active(node) then list[#list + 1] = { key = key, level = node.level, depth = node.depth } end
  end
  return list
end

--- Obnoví vzhled všech domů města (po povýšení).
function M.refresh_town_houses(town)
  for key in pairs(town.houses) do
    local node = storage.nodes[key]
    if node then M.refresh_house(node) end
  end
end

--- Přenese uzel radnice na novou entitu (výměna prototypu při povýšení – nové unit_number).
function M.replace_hall(old_key, entity)
  local node = storage.nodes[old_key]
  local new_key = entity.unit_number
  storage.nodes[old_key] = nil
  lights.forget(old_key)
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
  script.register_on_object_destroyed(entity)
end

return M
