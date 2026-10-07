--- Remote rozhraní „research-towns“ (pro testy a jiné mody) a ladicí příkaz /rt-create-town.
local towns = require("scripts.towns")
local board = require("scripts.board")
local config = require("scripts.config")
local worldgen = require("scripts.worldgen")
local network = require("scripts.network")
local lights = require("scripts.lights")

--- Město podle id, nebo nil.
local function town(id)
  return storage.towns[id]
end

remote.add_interface("research-towns", {
  --- Založí město; vrací id, nebo nil, když radnice nejde postavit.
  create_town = function(surface_name, position, force_name)
    local created = towns.create(game.surfaces[surface_name], position, force_name or "player")
    return created and created.id
  end,
  --- Stav města (viz towns.status), nebo nil.
  town_status = function(id)
    local t = town(id)
    return t and towns.status(t)
  end,
  --- Id města, ke kterému patří budova (radnice, dům, překladiště), nebo nil.
  town_of = function(unit_number)
    local record = storage.nodes[unit_number] or storage.depots[unit_number]
    return record and record.town
  end,
  --- Hloubka domu od radnice, nebo nil.
  depth_of = function(unit_number)
    local node = storage.nodes[unit_number]
    return node and node.depth
  end,
  --- Úroveň domu, nebo nil.
  house_level = function(unit_number)
    local node = storage.nodes[unit_number]
    return node and node.level
  end,
  --- Režim městské tabule, nebo nil.
  board_mode = function(unit_number)
    local depot = storage.depots[unit_number]
    return depot and depot.mode
  end,
  --- Nastaví režim městské tabule ("hall" | "house" | "upkeep") a hned přepíše její signály.
  set_board_mode = function(unit_number, mode)
    if not board.is_mode(mode) then error("research-towns: neplatný režim tabule: " .. tostring(mode)) end
    local depot = storage.depots[unit_number]
    if not (depot and depot.kind == "board") then return end
    depot.mode = mode
    local t = depot.town and town(depot.town)
    if t and t.hall.valid then towns.refresh_boards(t) end
  end,
  --- Založí neobjevené město s neutrální radnicí (testy); vrací id, nebo nil.
  create_wild_town = function(surface_name, position)
    local hall = game.surfaces[surface_name].create_entity({ name = config.hall_name(1), position = position, force = "neutral" })
    return hall and towns.register_wild(hall).id
  end,
  --- Objeví neobjevené město za sílu (jako by k němu došel hráč).
  discover = function(id, force_name)
    local t = town(id)
    if t and t.state == "wild" then towns.discover(t, game.forces[force_name or "player"]) end
  end,
  --- Seznam měst { id, state, surface, position, force } (testy generátoru).
  list_towns = function()
    local list = {}
    for id, t in pairs(storage.towns) do
      if t.hall.valid then
        list[#list + 1] = { id = id, state = t.state, surface = t.hall.surface.name, position = t.position,
          force = t.hall.force.name }
      end
    end
    return list
  end,
  --- Zopakuje doplnění měst do vygenerovaných chunků a první město (testy rozehrané hry).
  worldgen_ensure = function(again)
    worldgen.ensure(again)
  end,
  --- Doplní města do vygenerovaných chunků povrchu (testy rozehrané hry).
  worldgen_populate = function(surface_name)
    worldgen.populate(game.surfaces[surface_name])
  end,
  --- Postaví první město síly na povrchu (testy); vrací id, nebo nil.
  worldgen_first_town = function(surface_name, force_name)
    local t = worldgen.ensure_first_town(game.surfaces[surface_name], game.forces[force_name])
    return t and t.id
  end,
  --- Styl vykresleného spojení dvou budov ("garland" | "wood" | "glass"), nebo nil (testy).
  link_style = function(a, b)
    return network.link_style(a, b)
  end,
  --- Nastaví úroveň domu (testy) a obnoví jeho vzhled.
  set_house_level = function(unit_number, level)
    local node = storage.nodes[unit_number]
    if not (node and node.kind == "house") then error("není dům: " .. tostring(unit_number)) end
    node.level = level
    network.refresh_house(node)
  end,
  --- Počet nočních světel radnice nebo domu (testy).
  light_count = function(unit_number)
    return lights.count(unit_number)
  end,
  --- Počet vykreslených objektů spojení dvou budov (testy).
  link_renders = function(a, b)
    return network.link_render_count(a, b)
  end,
  --- Překreslí všechna spojení budov (starý save po změně vzhledu spojení).
  redraw_links = function()
    network.redraw_links()
  end,
  --- Srovná město s aktuálními vzorci (jako po změně konfigurace).
  refresh_town = function(id)
    local t = town(id)
    if t then towns.refresh(t) end
  end,
  --- Okamžitě zpracuje město (pro testy).
  process = function(id)
    local t = town(id)
    if t then towns.process(t) end
  end,
  --- Povýší město, pokud jsou splněné podmínky.
  upgrade = function(id)
    local t = town(id)
    return t ~= nil and towns.upgrade(t)
  end,
  --- Nastaví úroveň bez podmínek (testy, ladění).
  set_level = function(id, level)
    local t = town(id)
    if t then towns.set_level(t, level) end
  end,
  --- Přejmenuje město.
  rename = function(id, name)
    local t = town(id)
    if t then towns.rename(t, name) end
  end,
})

commands.add_command("rt-create-town", { "rt.command-create-town" }, function(command)
  local player = command.player_index and game.get_player(command.player_index)
  if not (player and player.admin) then return end
  local position = { x = math.floor(player.position.x) + 0.5, y = math.floor(player.position.y) - 12 + 0.5 }
  local created = towns.create(player.surface, position, player.force)
  player.print(created and { "rt.town-created", created.name } or { "rt.town-cannot-place" })
end)
