--- Vizualizace dosahu budov města (zobrazí se při stavění i při výběru, jako u sloupů).
local M = {}

--- Sprite oblasti dosahu (vanilla vizualizace sloupu).
M.SPRITE = {
  filename = "__base__/graphics/entity/small-electric-pole/electric-pole-radius-visualization.png",
  width = 12, height = 12, priority = "extra-high-no-scale",
}

--- Specifikace vizualizace: čtverec okraj budovy + dosah. Skutečný dosah se měří mezi okraji eukleidovsky,
--- takže v rozích čtverce je o něco menší – pro orientaci při stavění to stačí.
--- @param entity table prototyp s `selection_box` ve tvaru {{x1, y1}, {x2, y2}}
--- @param reach number dosah v dlaždicích
function M.spec(entity, reach)
  return { sprite = M.SPRITE, distance = entity.selection_box[2][1] + reach, draw_in_cursor = true, draw_on_selection = true }
end

return M
