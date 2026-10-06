--- Jednotkové testy čisté logiky světa: mřížka měst, dar, prostorový index, místo prvního města.
local A = require("assert")
local worldgen = require("shared.worldgen")

return {
  { "velikost buňky: výchozí, strop při nízké četnosti, minimum 20 měst do 1500", function()
    A.eq(worldgen.cell_size(1), worldgen.TOWN_CELL_BASE, "četnost 1")
    A.eq(worldgen.cell_size(1 / 6), worldgen.TOWN_CELL_MAX, "nejnižší četnost na stropu")
    A.truthy(worldgen.cell_size(6) < worldgen.TOWN_CELL_BASE, "vysoká četnost = menší buňky")
    local cells = math.pi * 1500 ^ 2 / worldgen.cell_size(1 / 6) ^ 2
    A.truthy(cells >= 30, "buněk do 1500 při nejnižší četnosti: " .. cells)
  end },
  { "noise výrazy obsahují konstanty a vypnutí při četnosti 0", function()
    local e = worldgen.noise_expressions()
    for _, name in ipairs({ "rt_town_frequency", "rt_town_cell", "rt_town_x", "rt_town_y", "rt_town_probability" }) do
      A.truthy(type(e[name]) == "string", "chybí " .. name)
    end
    A.truthy(e.rt_town_frequency:find("control:rt-towns:frequency", 1, true), "posuvník")
    A.truthy(e.rt_town_cell:find(tostring(worldgen.TOWN_CELL_MAX), 1, true), "strop buňky")
    A.truthy(e.rt_town_probability:find("rt_town_frequency > 0", 1, true), "četnost 0 vypne města")
    A.truthy(e.rt_town_probability:find("distance > " .. worldgen.TOWN_SPAWN_CLEAR, 1, true), "okolí spawnu")
    A.truthy(e.rt_town_x:find("floor(x / rt_town_cell)", 1, true), "posun podle indexu buňky")
    A.truthy(e.rt_town_probability:find("< " .. worldgen.TOWN_SITE_WINDOW, 1, true), "okno místa radnice")
    A.truthy(e.rt_town_probability:find("control:rt-towns:size') > 0", 1, true), "vypnutí Měst v GUI (size 0)")
  end },
  { "okno místa radnice je menší než radnice – v buňce nanejvýš jedno město", function()
    local levels = require("shared.levels")
    A.truthy(2 * worldgen.TOWN_SITE_WINDOW < levels.HALL_SIZE, "okno " .. 2 * worldgen.TOWN_SITE_WINDOW)
    A.truthy(worldgen.TOWN_SITE_WINDOW < worldgen.TOWN_CELL_MARGIN, "okno nepřesáhne okraj buňky")
  end },
  { "dar: úroveň o jednu nižší než nejvyšší partner, bez vědy, nahoru", function()
    A.eq(worldgen.gift_level({}), 1, "bez partnerů")
    A.eq(worldgen.gift_level({ 1 }), 1, "úroveň 1")
    A.eq(worldgen.gift_level({ 3, 5, 2 }), 4, "nejvyšší 5")
    local gift = worldgen.gift({
      { type = "item", name = "red", amount = 200, science = true },
      { type = "item", name = "wood", amount = 201 },
      { type = "fluid", name = "water", amount = 1000 },
    }, 0.25)
    A.eq(#gift, 2, "věda vynechaná")
    A.eq(gift[1].name, "wood", "pořadí zachované")
    A.eq(gift[1].amount, 51, "201 × 0,25 nahoru")
    A.eq(gift[2].amount, 250, "kapalina")
    A.eq(#worldgen.gift(nil, 0.25), 0, "bez milníku")
  end },
  { "prostorový index po buňkách", function()
    A.eq(worldgen.cell_key({ x = 0, y = 0 }), "0:0", "počátek")
    A.eq(worldgen.cell_key({ x = -1, y = -1 }), "-1:-1", "záporné")
    A.eq(worldgen.cell_key({ x = worldgen.INDEX_CELL, y = 5 }), "1:0", "další buňka")
    local keys = worldgen.cell_keys_around({ left_top = { x = 0, y = 0 }, right_bottom = { x = 32, y = 32 } }, 150)
    local set = {}
    for _, key in ipairs(keys) do set[key] = true end
    A.eq(#keys, 4, "4 buňky: " .. table.concat(keys, " "))
    A.truthy(set["-1:-1"] and set["0:0"] and set["-1:0"] and set["0:-1"], "sousední buňky")
  end },
  { "kandidáti prvního města: vzdálenosti, směry, determinismus", function()
    local spawn = { x = 10, y = -20 }
    local list = worldgen.first_town_candidates(spawn, 123456789)
    A.eq(#list, #worldgen.FIRST_TOWN_DISTANCES * worldgen.FIRST_TOWN_DIRECTIONS, "počet")
    for i = 1, worldgen.FIRST_TOWN_DIRECTIONS do
      local d = math.sqrt((list[i].x - spawn.x) ^ 2 + (list[i].y - spawn.y) ^ 2)
      A.truthy(math.abs(d - worldgen.FIRST_TOWN_DISTANCES[1]) < 1.5, "první vzdálenost: " .. d)
      A.eq(list[i].x % 1, 0.5, "střed dlaždice x")
    end
    local again = worldgen.first_town_candidates(spawn, 123456789)
    A.eq(again[1].x, list[1].x, "stejný seed = stejné pořadí")
  end },
}
