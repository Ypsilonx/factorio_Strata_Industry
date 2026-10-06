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

--- Vrstvy všech vzhledů stavby (kind = "hall" | "house") mají rozměry z <kind>_sprites.lua, ikony 64×64.
local function check_kind(kind)
  local sprites = require("prototypes." .. kind .. "_sprites")
  A.truthy(sprites.width > 0 and sprites.height > 0, "rozměry v " .. kind .. "_sprites")
  for variant = 1, levels.VARIANTS do
    for _, layer in ipairs({ "base", "light", "shadow" }) do
      local path = string.format("research-towns/graphics/entity/%s/%s-%d-%s.png", kind, kind, variant, layer)
      local w, h = png_size(path)
      A.truthy(w, "chybí " .. path)
      A.eq(w, sprites.width, path .. " šířka")
      A.eq(h, sprites.height, path .. " výška")
    end
    local icon = string.format("research-towns/graphics/icons/%s-%d.png", kind, variant)
    local w, h = png_size(icon)
    A.truthy(w, "chybí " .. icon)
    A.eq(w, 64, icon .. " šířka")
    A.eq(h, 64, icon .. " výška")
  end
end

return {
  { "překladiště a tabule: vrstvy s rozměry z depot_sprites, ikony 64×64", function()
    local sprites = require("prototypes.depot_sprites")
    for _, name in ipairs({ "rt-goods-depot", "rt-fluid-depot", "rt-power-depot", "rt-town-board" }) do
      local entry = sprites[name]
      A.truthy(entry, "chybí rozměry " .. name)
      for _, layer in ipairs({ "base", "light", "shadow" }) do
        local path = string.format("research-towns/graphics/entity/depots/%s-%s.png", name, layer)
        local w, h = png_size(path)
        A.truthy(w, "chybí " .. path)
        A.eq(w, entry.width, path .. " šířka")
        A.eq(h, entry.height, path .. " výška")
      end
      local w = png_size("research-towns/graphics/icons/" .. name .. ".png")
      A.eq(w, 64, name .. " ikona")
    end
    A.truthy(sprites.gauge and sprites.board_wire and sprites.board_lamp, "okénko a body drátů")
  end },
  { "radnice: vrstvy všech vzhledů a ikony", function() check_kind("hall") end },
  { "dům: vrstvy všech vzhledů a ikony", function() check_kind("house") end },
}
