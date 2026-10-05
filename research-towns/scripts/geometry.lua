--- Čistá geometrie: vzdálenost mezi budovami měřená mezi okraji (dosah jako u sloupů, ale od okraje).
local M = {}

--- Nejmenší vzdálenost mezi okraji dvou obdélníků (0 při dotyku nebo překryvu).
--- @param a BoundingBox
--- @param b BoundingBox
--- @return number
function M.gap(a, b)
  local dx = math.max(0, b.left_top.x - a.right_bottom.x, a.left_top.x - b.right_bottom.x)
  local dy = math.max(0, b.left_top.y - a.right_bottom.y, a.left_top.y - b.right_bottom.y)
  return math.sqrt(dx * dx + dy * dy)
end

--- Obdélník rozšířený o r na všech stranách (oblast pro hledání sousedů).
function M.expand(box, r)
  return {
    left_top = { x = box.left_top.x - r, y = box.left_top.y - r },
    right_bottom = { x = box.right_bottom.x + r, y = box.right_bottom.y + r },
  }
end

return M
