--- Čistá logika světa: rozmístění měst generátorem mapy (mřížka s posunem), dar za partnerství,
--- prostorový index měst a kandidáti místa prvního města. Sdílí ho data stage i control stage.
local M = {}

--- Ovládání generátoru mapy (posuvník „Města“) a značka místa města, kterou skript nahradí radnicí.
M.CONTROL = "rt-towns"
M.SITE = "rt-town-site"
--- Barva radnice a značky na mapě i v náhledu mapy.
M.MAP_COLOR = { r = 1, g = 0.75, b = 0.2 }
--- Velikost buňky mřížky (dlaždice) při četnosti 1 a strop při nízké četnosti: i nejnižší četnost dá
--- aspoň ~20 měst do 1500 dlaždic od spawnu.
M.TOWN_CELL_BASE = 250
M.TOWN_CELL_MAX = 400
--- Okraj buňky bez měst – sousední města nebudou nalepená na sebe.
M.TOWN_CELL_MARGIN = 40
--- Poloviční velikost okna, kde smí stát radnice buňky (dlaždice). Jediná dlaždice byla často pod vodou,
--- útesem nebo rudou (vznikla jen ~45 % měst); okno 14×14 je menší než radnice 15×15, takže se do něj
--- vejde nanejvýš jedna – generátor zkusí dlaždice okna a první volná vyhraje.
M.TOWN_SITE_WINDOW = 7
--- Kolem spawnu generátor města nedává (první město staví skript).
M.TOWN_SPAWN_CLEAR = 120
--- Pás kolem radnice bez stromů, kamenů a útesů; okruh bez hnízd biterů.
M.TOWN_CLEAR_MARGIN = 10
M.TOWN_NEST_CLEAR = 150
--- Hráč objeví město, když je do této vzdálenosti od okraje radnice.
M.DISCOVERY_RADIUS = 40
--- Dar za partnerství: podíl surovin milníku.
M.GIFT_SHARE = 0.25
--- Velikost buňky prostorového indexu měst (dlaždice).
M.INDEX_CELL = 256
--- První město: vzdálenosti od spawnu v pořadí zkoušení, počet směrů a odstup od jiné radnice.
M.FIRST_TOWN_DISTANCES = { 150, 120, 180, 100, 200 }
M.FIRST_TOWN_DIRECTIONS = 16
M.FIRST_TOWN_GAP = 100

--- Velikost buňky mřížky pro četnost z posuvníku (stejný vzorec jako noise výraz rt_town_cell).
function M.cell_size(frequency)
  return math.min(M.TOWN_CELL_MAX, M.TOWN_CELL_BASE / math.sqrt(frequency))
end

--- Pojmenované noise výrazy generátoru (jméno → výraz). Posun radnice v buňce je pro celou buňku stejný –
--- šum se vzorkuje v indexu buňky (posun závislý na x, y slil v pokusu radnice do „housenek“).
--- Pravděpodobnost je 1 v okně TOWN_SITE_WINDOW kolem bodu buňky; 0 jinde, kolem spawnu a při četnosti 0.
function M.noise_expressions()
  local span = "(rt_town_cell - " .. (2 * M.TOWN_CELL_MARGIN) .. ")"
  --- Souřadnice radnice v buňce pro osu ("x" / "y"); seed odliší osy.
  local function offset(axis, seed)
    return "floor(" .. axis .. " / rt_town_cell) * rt_town_cell + " .. M.TOWN_CELL_MARGIN .. " + " .. span
      .. " * (0.5 + 0.5 * clamp(basis_noise{x = floor(x / rt_town_cell) * 0.37, y = floor(y / rt_town_cell) * 0.41,"
      .. " seed0 = map_seed, seed1 = " .. seed .. ", input_scale = 1, output_scale = 1.5}, -1, 1))"
  end
  return {
    rt_town_frequency = "var('control:" .. M.CONTROL .. ":frequency')",
    rt_town_cell = string.format("min(%d, %d / sqrt(max(rt_town_frequency, 0.0001)))", M.TOWN_CELL_MAX,
      M.TOWN_CELL_BASE),
    rt_town_x = offset("x", 7101),
    rt_town_y = offset("y", 7102),
    rt_town_probability = string.format(
      "(rt_town_frequency > 0) * (distance > %d) * (abs(x - rt_town_x) < %d) * (abs(y - rt_town_y) < %d)",
      M.TOWN_SPAWN_CLEAR, M.TOWN_SITE_WINDOW, M.TOWN_SITE_WINDOW),
  }
end

--- Úroveň milníku, ze kterého je dar: o jednu nižší než nejvyšší úroveň partnerských měst, nejméně 1.
--- @param partner_levels integer[]
function M.gift_level(partner_levels)
  local highest = 1
  for _, level in ipairs(partner_levels) do highest = math.max(highest, level) end
  return math.max(1, highest - 1)
end

--- Dar za partnerství: suroviny milníku bez vědeckých balíčků × share, nahoru na celé kusy.
--- @param requirements table[]|nil požadavky milníku
--- @return table[] { {type, name, amount} }
function M.gift(requirements, share)
  local list = {}
  for _, req in ipairs(requirements or {}) do
    if not req.science then
      list[#list + 1] = { type = req.type, name = req.name, amount = math.ceil(req.amount * share - 1e-9) }
    end
  end
  return list
end

--- Klíč buňky prostorového indexu pro pozici.
function M.cell_key(position)
  return math.floor(position.x / M.INDEX_CELL) .. ":" .. math.floor(position.y / M.INDEX_CELL)
end

--- Klíče buněk indexu, do kterých zasahuje oblast rozšířená o radius.
--- @param area { left_top: MapPosition, right_bottom: MapPosition }
--- @return string[]
function M.cell_keys_around(area, radius)
  local keys = {}
  local x1 = math.floor((area.left_top.x - radius) / M.INDEX_CELL)
  local x2 = math.floor((area.right_bottom.x + radius) / M.INDEX_CELL)
  local y1 = math.floor((area.left_top.y - radius) / M.INDEX_CELL)
  local y2 = math.floor((area.right_bottom.y + radius) / M.INDEX_CELL)
  for cx = x1, x2 do
    for cy = y1, y2 do keys[#keys + 1] = cx .. ":" .. cy end
  end
  return keys
end

--- Kandidáti místa prvního města (středy dlaždic): kruhy FIRST_TOWN_DISTANCES kolem spawnu, každý
--- ve FIRST_TOWN_DIRECTIONS směrech; počáteční směr ze seedu mapy.
--- @return MapPosition[]
function M.first_town_candidates(spawn, seed)
  local list, n = {}, M.FIRST_TOWN_DIRECTIONS
  local start = seed % n
  for _, distance in ipairs(M.FIRST_TOWN_DISTANCES) do
    for i = 0, n - 1 do
      local angle = 2 * math.pi * ((start + i) % n) / n
      list[#list + 1] = { x = math.floor(spawn.x + distance * math.cos(angle)) + 0.5,
        y = math.floor(spawn.y + distance * math.sin(angle)) + 0.5 }
    end
  end
  return list
end

return M
