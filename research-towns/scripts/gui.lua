--- GUI: panel radnice (u okna laboratoře, jen u radnic) a volba režimu městské tabule (u okna kombinátoru).
local towns = require("scripts.towns")
local config = require("scripts.config")
local board = require("scripts.board")

local M = {}

--- Jak často se obnoví otevřené panely (ticky).
M.REFRESH_TICKS = 30

--- Jména prvků (prefix rt_, nesmí kolidovat s vlastnostmi LuaGuiElement – hlídá test_gui_names).
M.NAMES = {
  frame = "rt_town_frame",
  name = "rt_town_name",
  level = "rt_town_level",
  houses = "rt_town_houses",
  productivity = "rt_town_productivity",
  power = "rt_town_power",
  requirements = "rt_town_requirements",
  house_upgrade = "rt_town_house_upgrade",
  house_requirements = "rt_town_house_requirements",
  upkeep_status = "rt_town_upkeep_status",
  upkeep = "rt_town_upkeep",
  upgrade = "rt_town_upgrade",
  board_frame = "rt_board_frame",
  board_mode = "rt_board_mode",
}

--- Vytvoří (znovu) prázdný panel hráči.
function M.ensure(player)
  local relative = player.gui.relative
  if relative[M.NAMES.frame] then relative[M.NAMES.frame].destroy() end
  local n = M.NAMES
  local frame = relative.add({
    type = "frame", name = n.frame, direction = "vertical", caption = { "rt.gui-title" },
    anchor = { gui = defines.relative_gui_type.lab_gui, position = defines.relative_gui_position.right,
      names = config.hall_names() },
  })
  frame.add({ type = "textfield", name = n.name, tooltip = { "rt.gui-rename" } })
  frame.add({ type = "label", name = n.level })
  frame.add({ type = "label", name = n.houses })
  frame.add({ type = "label", name = n.productivity })
  frame.add({ type = "label", name = n.power })
  frame.add({ type = "label", caption = { "rt.gui-requirements" } })
  frame.add({ type = "table", name = n.requirements, column_count = 2 })
  frame.add({ type = "label", name = n.house_upgrade })
  frame.add({ type = "table", name = n.house_requirements, column_count = 2 })
  frame.add({ type = "label", name = n.upkeep_status })
  frame.add({ type = "table", name = n.upkeep, column_count = 2 })
  frame.add({ type = "button", name = n.upgrade, caption = { "rt.gui-upgrade" } })
  if relative[n.board_frame] then relative[n.board_frame].destroy() end
  local board_frame = relative.add({
    type = "frame", name = n.board_frame, direction = "vertical", caption = { "rt.gui-board-title" },
    anchor = { gui = defines.relative_gui_type.constant_combinator_gui, position = defines.relative_gui_position.right,
      names = { "rt-town-board" } },
  })
  board_frame.add({ type = "label", caption = { "rt.gui-board-mode" } })
  local items = {}
  for i, mode in ipairs(board.MODES) do items[i] = { "rt.board-mode-" .. mode } end
  board_frame.add({ type = "drop-down", name = n.board_mode, items = items, selected_index = 1 })
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

--- Naplní tabulku řádky „ikona s nativním popupem + popisek“.
--- @param rows { type: string, name: string, caption: LocalisedString }[]
local function fill_list(list, rows)
  list.clear()
  for _, row in ipairs(rows) do
    -- elem_tooltip = nativní popup předmětu/kapaliny jako v inventáři.
    list.add({ type = "sprite", sprite = row.type .. "/" .. row.name, elem_tooltip = { type = row.type, name = row.name } })
    list.add({ type = "label", caption = row.caption })
  end
end

--- Řádky „dodáno / potřeba“ z požadavků se stavem dodání.
local function progress_rows(requirements)
  local rows = {}
  for i, req in ipairs(requirements) do
    rows[i] = { type = req.type, name = req.name,
      caption = string.format("%d / %d", math.floor(req.delivered), req.amount) }
  end
  return rows
end

--- Naplní panel hráče stavem města.
local function fill(player, town)
  local frame = player.gui.relative[M.NAMES.frame]
  if not frame then return end
  local n = M.NAMES
  local status = towns.status(town)
  frame[n.level].caption = { "rt.gui-level", status.level, math.min(status.level, status.level_count), status.level_count }
  frame[n.houses].caption = { "rt.gui-houses", status.active_houses, status.house_limit,
    string.format("%d", math.floor(status.bonus * 100 + 0.5)) }
  local productivity = math.floor(status.productivity * 100 + 0.5)
  frame[n.productivity].visible = productivity > 0
  frame[n.productivity].caption = { "rt.gui-productivity", productivity }
  local megawatts = string.format("%.0f", status.power_watts / 1e6)
  frame[n.power].caption = status.power_ok and { "rt.gui-power-ok", megawatts } or { "rt.gui-power-missing", megawatts }
  fill_list(frame[n.requirements], progress_rows(status.requirements))
  frame[n.house_upgrade].caption = status.house_target_level
    and { "rt.gui-house-upgrade", status.houses_to_upgrade, status.house_target_level + 1 }
    or { "rt.gui-house-upgrade-none" }
  fill_list(frame[n.house_requirements], progress_rows(status.house_requirements))
  local upkeep_rows = {}
  for i, item in ipairs(status.upkeep) do
    upkeep_rows[i] = { type = item.type, name = item.name,
      caption = { "rt.gui-upkeep-row", string.format("%.1f", item.per_minute), math.floor(item.stock) } }
  end
  frame[n.upkeep_status].caption = #upkeep_rows == 0 and { "rt.gui-upkeep-none" }
    or (status.upkeep_ok and { "rt.gui-upkeep-ok" } or { "rt.gui-upkeep-missing" })
  fill_list(frame[n.upkeep], upkeep_rows)
  frame[n.upgrade].enabled = status.can_upgrade
end

--- Otevření okna: u tabule nastaví volbu režimu; u radnice si zapamatuje město a naplní panel
--- (jméno jen při otevření – nepřepisuje psaní).
function M.on_opened(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == "rt-town-board" then
    local depot = storage.depots[entity.unit_number]
    local player = game.get_player(event.player_index)
    if not player.gui.relative[M.NAMES.board_frame] then M.ensure(player) end
    storage.gui_board[event.player_index] = entity.unit_number
    local dropdown = player.gui.relative[M.NAMES.board_frame][M.NAMES.board_mode]
    for i, mode in ipairs(board.MODES) do
      if depot and depot.mode == mode then dropdown.selected_index = i end
    end
    return
  end
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
  storage.gui_board[event.player_index] = nil
end

--- Klik na „Povýšit“.
function M.on_click(event)
  if event.element.name ~= M.NAMES.upgrade then return end
  local town = storage.towns[storage.gui[event.player_index]]
  if not town then return end
  local hall = town.hall
  if not towns.upgrade(town) then return end
  if town.hall == hall then
    -- Nad poslední vědou zůstává stejná radnice a okno zůstává otevřené – jen obnovit panel.
    fill(game.get_player(event.player_index), town)
  else
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

--- Volba režimu tabule v jejím okně; signály se přepíšou hned.
function M.on_selection_changed(event)
  if event.element.name ~= M.NAMES.board_mode then return end
  local depot = storage.depots[storage.gui_board[event.player_index]]
  if not depot then return end
  depot.mode = board.MODES[event.element.selected_index]
  local town = depot.town and storage.towns[depot.town]
  if town and town.hall.valid then towns.refresh_boards(town) end
end

return M
