--- Jednotkové testy tvaru spojení budov města: prověšená šňůra, praporky, lucerny.
local A = require("assert")
local links = require("scripts.links")

return {
  { "šňůra vede z bodu do bodu a uprostřed je prověšená dolů", function()
    local points = links.rope({ x = 0, y = 0 }, { x = 4, y = 0 }, links.ROPE_SEGMENTS)
    A.eq(#points, links.ROPE_SEGMENTS + 1, "počet bodů")
    A.eq(points[1].x, 0, "začátek")
    A.eq(points[#points].x, 4, "konec")
    local middle = points[links.ROPE_SEGMENTS / 2 + 1]
    A.truthy(middle.y > 0.1, "prověšení dolů (y roste na obrazovce dolů): " .. middle.y)
    A.truthy(middle.y <= links.SAG_MAX + 1e-9, "nejvýš SAG_MAX")
  end },
  { "praporky po šňůře v rozestupech, trojúhelník visí dolů", function()
    local points = links.rope({ x = 0, y = 0 }, { x = 5, y = 0 }, links.ROPE_SEGMENTS)
    local flags = links.flags(points, 7)
    A.truthy(#flags >= 5, "praporků: " .. #flags)
    local tri = flags[1].vertices
    A.eq(#tri, 3, "trojúhelník")
    A.truthy(tri[3].y > tri[1].y, "špička dolů")
    A.truthy(flags[1].color >= 1 and flags[1].color <= #links.FLAG_COLORS, "barva z palety")
  end },
  { "styl spojení podle vzhledu města: šňůra, dřevěná lávka, prosklená lávka", function()
    A.eq(links.style(1), "garland", "osada")
    A.eq(links.style(2), "garland", "automatizace")
    A.eq(links.style(3), "wood", "logistika")
    A.eq(links.style(4), "wood", "chemie")
    A.eq(links.style(5), "glass", "město vědy")
  end },
  { "lávka: úseky po celých dlaždicích, natočení po směru spojení", function()
    local segments = links.walkway({ x = 0, y = 0 }, { x = 3.5, y = 0 })
    A.eq(#segments, 4, "3,5 dlaždice → 4 úseky")
    A.truthy(math.abs(segments[1].length - 3.5 / 4) < 1e-9, "délka úseku")
    A.truthy(math.abs(segments[1].center.x - 3.5 / 8) < 1e-9, "střed prvního úseku")
    A.eq(segments[1].orientation, 0, "na východ = bez natočení")
    local down = links.walkway({ x = 0, y = 0 }, { x = 0, y = 2 })
    A.truthy(math.abs(down[1].orientation - 0.25) < 1e-9, "na jih (dolů) = čtvrt otáčky po směru hodin")
    local west = links.walkway({ x = 0, y = 0 }, { x = -1, y = 0 })
    A.truthy(math.abs(west[1].orientation - 0.5) < 1e-9, "na západ = půl otáčky")
  end },
  { "krátké spojení bez praporků, lucerny ve třetinách", function()
    local short = links.rope({ x = 0, y = 0 }, { x = 0.5, y = 0 }, links.ROPE_SEGMENTS)
    A.eq(#links.flags(short, 1), 0, "pod rozestupem žádný praporek")
    local points = links.rope({ x = 0, y = 0 }, { x = 6, y = 0 }, links.ROPE_SEGMENTS)
    local lanterns = links.lanterns(points)
    A.eq(#lanterns, 2, "dvě lucerny")
    A.truthy(math.abs(lanterns[1].x - 2) < 0.7 and math.abs(lanterns[2].x - 4) < 0.7, "ve třetinách")
  end },
}
