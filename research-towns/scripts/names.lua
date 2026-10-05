--- Čistá logika jmen měst: deterministická jména z pořadového čísla (stejná pro všechny hráče).
local M = {}

local PREFIXES = { "Iron", "Copper", "Cog", "Gear", "Coal", "Stone", "Ash", "Rust", "Steam", "Brass", "Ember", "Flint" }
local SUFFIXES = { "ford", "ton", "wick", "bury", "dale", "field", "haven", "stead", "holm", "gate", "bridge", "worth" }

--- Jméno n-tého města; krok 37 (nesoudělný se 144) promíchá kombinace, po vyčerpání se přidá číslo.
--- @param n integer 1, 2, …
function M.generate(n)
  local count = #PREFIXES * #SUFFIXES
  local k = ((n - 1) * 37) % count
  local name = PREFIXES[k % #PREFIXES + 1] .. SUFFIXES[math.floor(k / #PREFIXES) + 1]
  local round = math.floor((n - 1) / count)
  if round > 0 then name = name .. " " .. (round + 1) end
  return name
end

return M
