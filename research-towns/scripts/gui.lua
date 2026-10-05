--- GUI radnice: panel ukotvený vpravo od okna laboratoře, zobrazený jen u radnic.
local levels = require("shared.levels")
local towns = require("scripts.towns")

local M = {}

--- Jak často se obnoví otevřené panely (ticky).
M.REFRESH_TICKS = 30

--- Jména prvků (prefix rt_, nesmí kolidovat s vlastnostmi LuaGuiElement – hlídá test_gui_names).
M.NAMES = {
  frame = "rt_town_frame",
  name = "rt_town_name",
  level = "rt_town_level",
  houses = "rt_town_houses",
  power = "rt_town_power",
  requirements = "rt_town_requirements",
  upgrade = "rt_town_upgrade",
}

--- Vytvoří (znovu) prázdný panel hráči.
function M.ensure(player)
  local relative = player.gui.relative
  if relative[M.NAMES.frame] then relative[M.NAMES.frame].destroy() end
  local frame = relative.add({
    type = "frame", name = M.NAMES.frame, direction = "vertical", caption = { "rt.gui-title" },
    anchor = { gui = defines.relative_gui_type.lab_gui, position = defines.relative_gui_position.right,
      names = levels.hall_names() },
  })
  frame.add({ type = "textfield", name = M.NAMES.name, tooltip = { "rt.gui-rename" } })
  frame.add({ type = "label", name = M.NAMES.level })
  frame.add({ type = "label", name = M.NAMES.houses })
  frame.add({ type = "label", name = M.NAMES.power })
  frame.add({ type = "label", caption = { "rt.gui-requirements" } })
  frame.add({ type = "table", name = M.NAMES.requirements, column_count = 2 })
  frame.add({ type = "button", name = M.NAMES.upgrade, caption = { "rt.gui-upgrade" } })
end

--- Vytvoří panely všem hráčům.
function M.rebuild_all()
  for _, player in pairs(game.players) do M.ensure(player) end
end

--- Město otevřené radnice, nebo nil.
local function town_of(entity)
  if not (entity and entity.valid) then return nil end
  local node = storage.nodes[entity.unit_number]
  return node and node.kind == "hall" and storage.towns[node.town]
end

--- Naplní panel hráče stavem města.
local function fill(player, town)
  local frame = player.gui.relative[M.NAMES.frame]
  if not frame then return end
  local n = M.NAMES
  local status = towns.status(town)
  frame[n.level].caption = { "rt.gui-level", status.level, levels.MAX_LEVEL }
  frame[n.houses].caption = { "rt.gui-houses", status.active_houses, status.house_limit,
    string.format("%d", math.floor(status.bonus * 100 + 0.5)) }
  local megawatts = string.format("%.0f", status.power_watts / 1e6)
  frame[n.power].caption = status.power_ok and { "rt.gui-power-ok", megawatts } or { "rt.gui-power-missing", megawatts }
  local list = frame[n.requirements]
  list.clear()
  for _, req in ipairs(status.requirements) do
    -- elem_tooltip = nativní popup předmětu/kapaliny jako v inventáři.
    list.add({ type = "sprite", sprite = req.type .. "/" .. req.name, elem_tooltip = { type = req.type, name = req.name } })
    list.add({ type = "label", caption = string.format("%d / %d", math.floor(req.delivered), req.amount) })
  end
  if #status.requirements == 0 then list.add({ type = "label", caption = { "rt.gui-max-level" } }) end
  frame[n.upgrade].enabled = status.can_upgrade
end

--- Otevření okna: u radnice si zapamatuje město a naplní panel (jméno jen při otevření – nepřepisuje psaní).
function M.on_opened(event)
  local town = town_of(event.entity)
  if not town then return end
  local player = game.get_player(event.player_index)
  if not player.gui.relative[M.NAMES.frame] then M.ensure(player) end
  storage.gui[event.player_index] = town.id
  player.gui.relative[M.NAMES.frame][M.NAMES.name].text = town.name
  fill(player, town)
end

--- Zavření okna.
function M.on_closed(event)
  storage.gui[event.player_index] = nil
end

--- Klik na „Povýšit“.
function M.on_click(event)
  if event.element.name ~= M.NAMES.upgrade then return end
  local town = storage.towns[storage.gui[event.player_index]]
  if town and towns.upgrade(town) then
    -- Povýšení vyměnilo entitu radnice – okno staré radnice se zavřelo, panel znovu otevře hráč.
    storage.gui[event.player_index] = nil
  end
end

--- Potvrzení jména Enterem.
function M.on_confirmed(event)
  if event.element.name ~= M.NAMES.name then return end
  local town = storage.towns[storage.gui[event.player_index]]
  local text = event.element.text
  if town and text ~= "" then towns.rename(town, text) end
end

--- Obnoví otevřené panely; bez otevřeného okna jen jedna kontrola prázdné tabulky.
function M.refresh()
  for index, id in pairs(storage.gui) do
    local player = game.get_player(index)
    local town = storage.towns[id]
    if player and town and town.hall.valid then fill(player, town) else storage.gui[index] = nil end
  end
end

return M
