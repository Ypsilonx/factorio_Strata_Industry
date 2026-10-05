--- Městská tabule: signály pro obvodovou síť podle režimu (čistá funkce signals) a zápis do kombinátoru.
local M = {}

--- Režimy tabule v pořadí položek v GUI.
M.MODES = { "hall", "house", "upkeep" }
--- Tag režimu v plánu (blueprintu).
M.TAG = "rt_board_mode"

--- Zaokrouhlí kladné množství nahoru (tolerance kvůli kapalinám).
local function ceil(value)
  return math.ceil(value - 1e-6)
end

--- Signály tabule pro režim a stav města (towns.status). Nulové hodnoty se vynechají.
--- @return { type: string, name: string, count: integer }[]
function M.signals(mode, status)
  local list = {}
  local function add(kind, name, count)
    if count > 0 then list[#list + 1] = { type = kind, name = name, count = count } end
  end
  if mode == "hall" then
    for _, req in ipairs(status.requirements) do add(req.type, req.name, ceil(req.amount - req.delivered)) end
  elseif mode == "house" then
    for _, req in ipairs(status.house_requirements) do add(req.type, req.name, ceil(req.amount - req.delivered)) end
    add("virtual", "rt-signal-houses", status.houses_to_upgrade)
  elseif mode == "upkeep" then
    for _, req in ipairs(status.upkeep) do add(req.type, req.name, ceil(req.per_minute)) end
  end
  add("virtual", "rt-signal-power-mw", ceil(status.power_watts / 1e6))
  add("virtual", "rt-signal-power-percent", status.power_percent)
  return list
end

--- Zapíše signály do první sekce konstantního kombinátoru (přepíše, co tam hráč nastavil).
function M.write(entity, list)
  local behavior = entity.get_or_create_control_behavior()
  local section = behavior.get_section(1) or behavior.add_section()
  local filters = {}
  for i, signal in ipairs(list) do
    local value = { type = signal.type, name = signal.name }
    -- Kvalitu mají jen předměty; u kapalin a virtuálních signálů se nevyplňuje.
    if signal.type == "item" then
      value.quality = "normal"
      value.comparator = "="
    end
    filters[i] = { value = value, min = signal.count }
  end
  section.filters = filters
end

return M
