--- Jednotkové testy vzdálenosti mezi obdélníky.
local A = require("assert")
local geometry = require("scripts.geometry")

--- Obdélník z rohů.
local function box(x1, y1, x2, y2)
  return { left_top = { x = x1, y = y1 }, right_bottom = { x = x2, y = y2 } }
end

return {
  { "dotyk a překryv = 0", function()
    A.eq(geometry.gap(box(0, 0, 2, 2), box(2, 0, 4, 2)), 0, "dotyk")
    A.eq(geometry.gap(box(0, 0, 3, 3), box(1, 1, 2, 2)), 0, "překryv")
  end },
  { "mezera do strany a šikmo", function()
    A.eq(geometry.gap(box(0, 0, 2, 2), box(5, 0, 7, 2)), 3, "do strany")
    A.eq(geometry.gap(box(0, 0, 1, 1), box(4, 5, 5, 6)), 5, "šikmo 3-4-5")
  end },
  { "rozšíření oblasti", function()
    local e = geometry.expand(box(0, 0, 2, 2), 3)
    A.eq(e.left_top.x, -3, "left")
    A.eq(e.right_bottom.y, 5, "bottom")
  end },
}
