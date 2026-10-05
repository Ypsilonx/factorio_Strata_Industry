--- Remote rozhraní „research-towns“ (pro testy a jiné mody) a ladicí příkaz /rt-create-town.
local towns = require("scripts.towns")

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
  --- Nastaví režim městské tabule ("hall" | "house" | "upkeep").
  set_board_mode = function(unit_number, mode)
    local depot = storage.depots[unit_number]
    if depot and depot.kind == "board" then depot.mode = mode end
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
