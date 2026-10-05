--- Jednotkové testy zvětšení dočasné vanilla grafiky.
local A = require("assert")
local placeholder = require("prototypes.placeholder")

return {
  { "vrstvy se zvětší, stín se neobarví, originál zůstane", function()
    local source = { layers = { { scale = 0.5, shift = { 1, 2 } }, { scale = 0.5, draw_as_shadow = true } } }
    local tint = { r = 1, g = 0, b = 0 }
    local copy = placeholder.scaled(source, 5, tint)
    A.eq(copy.layers[1].scale, 2.5, "scale")
    A.eq(copy.layers[1].shift[2], 10, "shift")
    A.eq(copy.layers[1].tint, tint, "tint")
    A.eq(copy.layers[2].tint, nil, "stín bez tintu")
    A.eq(source.layers[1].scale, 0.5, "originál beze změny")
  end },
}
