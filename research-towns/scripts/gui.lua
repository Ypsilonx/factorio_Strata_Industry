--- GUI: panel radnice (u okna laboratoře, jen u radnic) a volba režimu městské tabule (u okna kombinátoru).
local towns = require("scripts.towns")
local config = require("scripts.config")
local board = require("scripts.board")
local levels = require("shared.levels")

local M = {}

--- Jak často se obnoví otevřené panely (ticky).
M.REFRESH_TICKS = 30
--- Počet slotů surovin na řádek a šířka progress baru v záhlaví sekce (px).
M.SLOT_COLUMNS = 8
M.BAR_WIDTH = 100

--- Jména prvků (prefix rt_, nesmí kolidovat s vlastnostmi LuaGuiElement – hlídá test_gui_names).
M.NAMES = {
  frame = "rt_town_frame",
  name = "rt_town_name",
  level = "rt_town_level",
  houses = "rt_town_houses",
  productivity = "rt_town_productivity",
  power = "rt_town_power",
  level_header = "rt_town_level_header",
  requirements = "rt_town_requirements",
  house_header = "rt_town_house_header",
  house_requirements = "rt_town_house_requirements",
  upkeep_status = "rt_town_upkeep_status",
  upkeep = "rt_town_upkeep",
  upgrade = "rt_town_upgrade",
  board_frame = "rt_board_frame",
  board_mode = "rt_board_mode",
  -- Uvnitř záhlaví sekce (flow).
  header_caption = "rt_header_caption",
  header_bar = "rt_header_bar",
  header_percent = "rt_header_percent",
}

--- Přidá záhlaví sekce: popisek vlevo, progress bar s procenty vpravo.
local function add_header(frame, name)
  local n = M.NAMES
  local flow = frame.add({ type = "flow", name = name, direction = "horizontal" })
  flow.style.vertical_align = "center"
  flow.add({ type = "label", name = n.header_caption })
  flow.add({ type = "empty-widget" }).style.horizontally_stretchable = true
  flow.add({ type = "progressbar", name = n.header_bar }).style.width = M.BAR_WIDTH
  flow.add({ type = "label", name = n.header_percent })
end

--- Přidá mřížku slotů surovin.
local function add_slots(frame, name)
  frame.add({ type = "table", name = name, column_count = M.SLOT_COLUMNS, style = "filter_slot_table" })
end

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
  add_header(frame, n.level_header)
  add_slots(frame, n.requirements)
  add_header(frame, n.house_header)
  add_slots(frame, n.house_requirements)
  frame.add({ type = "label", name = n.upkeep_status })
  add_slots(frame, n.upkeep)
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

--- Město otevřené radnice (partnerské i cizí), nebo nil.
local function town_of(entity)
  if not (entity and entity.valid) then return nil end
  local node = storage.nodes[entity.unit_number]
  if node then return node.kind == "hall" and storage.towns[node.town] or nil end
  local id = storage.wild_halls[entity.unit_number]
  return id and storage.towns[id]
end

--- Naplní mřížku sloty surovin: ikona s nativním popupem, číslo v rohu a vlastní tooltip.
--- @param slots { type: string, name: string, number: number|nil, style: string, tooltip: LocalisedString }[]
local function fill_slots(grid, slots)
  grid.clear()
  for _, slot in ipairs(slots) do
    -- elem_tooltip = nativní popup předmětu/kapaliny jako v inventáři; tooltip se ukáže pod ním.
    grid.add({ type = "sprite-button", sprite = slot.type .. "/" .. slot.name, style = slot.style, number = slot.number,
      elem_tooltip = { type = slot.type, name = slot.name }, tooltip = slot.tooltip })
  end
end

--- Sloty požadavků: číslo = kolik ještě chybí, splněné zeleně bez čísla.
local function requirement_slots(requirements)
  local slots = {}
  for i, req in ipairs(requirements) do
    local missing = math.ceil(req.amount - req.delivered - 1e-3)
    slots[i] = { type = req.type, name = req.name,
      number = missing > 0 and missing or nil, style = missing > 0 and "slot" or "green_slot",
      tooltip = { "rt.gui-slot-delivered", math.floor(req.delivered), req.amount } }
  end
  return slots
end

--- Sloty spotřeby: číslo = spotřeba za minutu, červeně když zásoba nepokryje ani jedno zpracování.
local function upkeep_slots(upkeep)
  local slots = {}
  for i, item in ipairs(upkeep) do
    local short = item.stock + 1e-6 < item.per_minute * levels.TOWN_INTERVAL / 3600
    slots[i] = { type = item.type, name = item.name, number = item.per_minute, style = short and "red_slot" or "slot",
      tooltip = { "rt.gui-upkeep-slot", item.per_minute, math.floor(item.stock), math.ceil(item.buffer - 1e-6) } }
  end
  return slots
end

--- Nastaví záhlaví sekce; bez postupu (nil) skryje progress bar i procenta.
local function set_header(header, caption, fraction)
  local n = M.NAMES
  header[n.header_caption].caption = caption
  header[n.header_bar].visible = fraction ~= nil
  header[n.header_bar].value = fraction or 0
  header[n.header_percent].visible = fraction ~= nil
  header[n.header_percent].caption = { "rt.gui-progress", board.percent(fraction) }
end

--- Naplní panel hráče stavem města.
local function fill(player, town)
  local frame = player.gui.relative[M.NAMES.frame]
  if not frame then return end
  local n = M.NAMES
  local status = towns.status(town)
  -- Cizí město ukazuje jen dar; partnerské vrátí viditelnost sekcí.
  local partner = status.state == "partner"
  for _, key in ipairs({ n.houses, n.power, n.house_header, n.house_requirements, n.upkeep_status, n.upkeep, n.upgrade }) do
    frame[key].visible = partner
  end
  if not partner then
    frame[n.productivity].visible = false
    frame[n.level].caption = { "rt.gui-gift-hint" }
    set_header(frame[n.level_header], { "rt.gui-gift" }, status.level_progress)
    fill_slots(frame[n.requirements], requirement_slots(status.requirements))
    return
  end
  frame[n.level].caption = { "rt.gui-level", status.level, math.min(status.level, status.level_count), status.level_count }
  frame[n.houses].caption = { "rt.gui-houses", status.active_houses, status.house_limit,
    string.format("%d", math.floor(status.bonus * 100 + 0.5)) }
  local productivity = math.floor(status.productivity * 100 + 0.5)
  frame[n.productivity].visible = productivity > 0
  frame[n.productivity].caption = { "rt.gui-productivity", productivity }
  local megawatts = string.format("%.0f", status.power_watts / 1e6)
  frame[n.power].caption = status.power_ok and { "rt.gui-power-ok", megawatts } or { "rt.gui-power-missing", megawatts }
  set_header(frame[n.level_header], { "rt.gui-requirements" }, status.level_progress)
  fill_slots(frame[n.requirements], requirement_slots(status.requirements))
  local house_caption = { "rt.gui-house-upgrade-none" }
  if status.house_target_level then
    house_caption = { "rt.gui-house-upgrade", status.houses_to_upgrade, status.house_target_level + 1 }
  elseif status.house_bonus_full then
    house_caption = { "rt.gui-house-upgrade-full" }
  end
  set_header(frame[n.house_header], house_caption, status.house_upgrade_progress)
  fill_slots(frame[n.house_requirements], requirement_slots(status.house_requirements))
  frame[n.upkeep_status].caption = #status.upkeep == 0 and { "rt.gui-upkeep-none" }
    or (status.upkeep_ok and { "rt.gui-upkeep-ok" } or { "rt.gui-upkeep-missing" })
  fill_slots(frame[n.upkeep], upkeep_slots(status.upkeep))
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
