--- Virtuální signály městské tabule. Ikony jsou složené: budova + malý symbol vpravo dole (dočasné,
--- finální grafika z Blenderu je plán 3).
local HALL = "__base__/graphics/icons/lab.png"
local HOUSE = "__base__/graphics/icons/stone-furnace.png"
local SIGNAL = "__base__/graphics/icons/signal/"

--- Ikona budovy se symbolem signálu v rohu.
--- @param base string ikona budovy (64 px)
--- @param symbol string jméno souboru symbolu ve složce signálů
local function icons(base, symbol)
  return {
    { icon = base, icon_size = 64 },
    { icon = SIGNAL .. symbol, icon_size = 64, scale = 0.25, shift = { 8, 8 } },
  }
end

data:extend({
  { type = "virtual-signal", name = "rt-signal-houses", icons = icons(HOUSE, "signal-number-sign.png"),
    subgroup = "virtual-signal", order = "z-rt-a" },
  { type = "virtual-signal", name = "rt-signal-power-mw", icon = "__base__/graphics/icons/accumulator.png",
    subgroup = "virtual-signal", order = "z-rt-b" },
  { type = "virtual-signal", name = "rt-signal-power-percent", icon = "__base__/graphics/icons/substation.png",
    subgroup = "virtual-signal", order = "z-rt-c" },
  { type = "virtual-signal", name = "rt-signal-level-progress", icons = icons(HALL, "signal-percent.png"),
    subgroup = "virtual-signal", order = "z-rt-d" },
  { type = "virtual-signal", name = "rt-signal-house-progress", icons = icons(HOUSE, "signal-percent.png"),
    subgroup = "virtual-signal", order = "z-rt-e" },
})
