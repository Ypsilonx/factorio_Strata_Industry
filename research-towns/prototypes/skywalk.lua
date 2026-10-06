--- Sprity visutých lávek mezi budovami města (textura úseku 1 dlaždice z Blenderu, pohled shora). Skript je
--- kreslí přes rendering.draw_sprite – natočené a opakované podél spojení, bez kolize (scripts/network.lua).
local GRAPHICS = "__research-towns__/graphics/entity/skywalk/"

data:extend({
  { type = "sprite", name = "rt-skywalk-wood", filename = GRAPHICS .. "skywalk-wood.png", size = 64, scale = 0.5 },
  { type = "sprite", name = "rt-skywalk-glass", filename = GRAPHICS .. "skywalk-glass.png", size = 64, scale = 0.5 },
})
