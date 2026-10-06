--- Čistá logika vzhledu spojení budov města (šňůra s praporky a lucernami nad vyšlapaným chodníkem).
--- Pozice jsou v dlaždicích mapy; y roste dolů (jako na obrazovce), takže prověšení přičítá k y.
--- Vykreslení (rendering) dělá scripts/network.lua. Visuté lávky pro vyšší úrovně města přijdou s grafikou
--- domů (plán 3b) – do té doby mají všechny úrovně šňůry.
local M = {}

--- atan2: hra běží na Lua 5.2 (math.atan2), unit testy na Lua 5.3 (math.atan se dvěma argumenty).
local atan2 = math.atan2 or math.atan

--- Počet úseků šňůry, největší prověšení a prověšení na dlaždici délky.
M.ROPE_SEGMENTS = 10
M.SAG_MAX = 0.6
M.SAG_PER_TILE = 0.08
--- Výška úchytu šňůry nad středem budovy (dlaždice na obrazovce): střechy domu, radnice.
M.ANCHOR = { house = 1.3, hall = 2.4 }
--- Rozestup praporků po šňůře (dlaždice) a jejich tlumené barvy (RGBA 0–1).
M.FLAG_SPACING = 0.6
M.FLAG_COLORS = {
  { r = 0.55, g = 0.18, b = 0.12, a = 1 }, { r = 0.2, g = 0.3, b = 0.45, a = 1 },
  { r = 0.62, g = 0.48, b = 0.2, a = 1 }, { r = 0.32, g = 0.42, b = 0.2, a = 1 },
}
--- Rozměr praporku (půlka šířky, výška).
M.FLAG_HALF_WIDTH = 0.09
M.FLAG_HEIGHT = 0.22

--- Body prověšené šňůry z a do b (segments + 1 bodů).
--- @param a { x: number, y: number }
--- @param b { x: number, y: number }
--- @return { x: number, y: number }[]
function M.rope(a, b, segments)
  local length = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
  local sag = math.min(M.SAG_MAX, length * M.SAG_PER_TILE)
  local points = {}
  for i = 0, segments do
    local t = i / segments
    points[#points + 1] = { x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t + sag * 4 * t * (1 - t) }
  end
  return points
end

--- Praporky po šňůře v rozestupu FLAG_SPACING (ne na koncích u budov).
--- @param seed integer střídání barev (stejné spojení = stejné barvy)
--- @return { vertices: { x: number, y: number }[], color: integer }[]
function M.flags(points, seed)
  local result = {}
  local walked, next_at = 0, M.FLAG_SPACING
  for i = 2, #points do
    local p, q = points[i - 1], points[i]
    local step = math.sqrt((q.x - p.x) ^ 2 + (q.y - p.y) ^ 2)
    while step > 0 and walked + step >= next_at do
      local t = (next_at - walked) / step
      local x, y = p.x + (q.x - p.x) * t, p.y + (q.y - p.y) * t
      result[#result + 1] = {
        vertices = { { x = x - M.FLAG_HALF_WIDTH, y = y }, { x = x + M.FLAG_HALF_WIDTH, y = y },
          { x = x, y = y + M.FLAG_HEIGHT } },
        color = (seed + #result) % #M.FLAG_COLORS + 1,
      }
      next_at = next_at + M.FLAG_SPACING
    end
    walked = walked + step
  end
  -- Poslední praporek těsně u budovy vynechat.
  local total = walked
  if #result > 0 and total - (next_at - M.FLAG_SPACING) < M.FLAG_SPACING / 2 then result[#result] = nil end
  return result
end

--- Styl spojení podle vzhledu města (levels.variant): šňůra s praporky (osada, automatizace), dřevěná visutá
--- lávka (logistika, chemie), prosklená lávka (město vědy).
--- @return "garland"|"wood"|"glass"
function M.style(variant)
  if variant >= 5 then return "glass" end
  if variant >= 3 then return "wood" end
  return "garland"
end

--- Úseky visuté lávky z a do b: celé dlaždice (textura se neroztahuje víc než o pár procent), každý se středem,
--- délkou a natočením pro rendering.draw_sprite (orientace 0 = sprite na východ, po směru hodin; y dolů).
--- @return { center: { x: number, y: number }, length: number, orientation: number }[]
function M.walkway(a, b)
  local dx, dy = b.x - a.x, b.y - a.y
  local length = math.sqrt(dx * dx + dy * dy)
  local count = math.max(1, math.ceil(length - 1e-9))
  local orientation = (atan2(dy, dx) / (2 * math.pi)) % 1
  local segments = {}
  for i = 1, count do
    local t = (i - 0.5) / count
    segments[i] = { center = { x = a.x + dx * t, y = a.y + dy * t }, length = length / count,
      orientation = orientation }
  end
  return segments
end

--- Lucerny ve třetinách šňůry.
--- @return { x: number, y: number }[]
function M.lanterns(points)
  local n = #points - 1
  return { points[math.floor(n / 3) + 1], points[math.floor(2 * n / 3) + 1] }
end

return M
