--- Jednotkové testy grafiky radnice: PNG z Blenderu existují a mají rozměry zapsané buildem v hall_sprites.lua
--- (headless hra sprity nenačítá, chybějící nebo špatně velký soubor by se ukázal až ve hře).
local A = require("assert")
local levels = require("shared.levels")

--- Rozměry PNG z hlavičky IHDR (šířka, výška), nebo nil, když soubor chybí.
local function png_size(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local header = file:read(24)
  file:close()
  local function u32(i)
    local a, b, c, d = header:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

return {
  { "vrstvy radnice všech vzhledů mají rozměry z hall_sprites", function()
    local sprites = require("prototypes.hall_sprites")
    A.truthy(sprites.width > 0 and sprites.height > 0, "rozměry v hall_sprites")
    for variant = 1, levels.VARIANTS do
      for _, layer in ipairs({ "base", "light", "shadow" }) do
        local path = string.format("research-towns/graphics/entity/hall/hall-%d-%s.png", variant, layer)
        local w, h = png_size(path)
        A.truthy(w, "chybí " .. path)
        A.eq(w, sprites.width, path .. " šířka")
        A.eq(h, sprites.height, path .. " výška")
      end
    end
  end },
  { "ikony radnice 64×64", function()
    for variant = 1, levels.VARIANTS do
      local path = string.format("research-towns/graphics/icons/hall-%d.png", variant)
      local w, h = png_size(path)
      A.truthy(w, "chybí " .. path)
      A.eq(w, 64, path .. " šířka")
      A.eq(h, 64, path .. " výška")
    end
  end },
}
