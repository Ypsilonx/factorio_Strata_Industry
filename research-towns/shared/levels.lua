--- Balanc úrovní měst – jediné místo, kde se ladí čísla. Sdílí ho data stage i control stage.
--- Suroviny milníků jsou seznamy kandidátů: v data-final-fixes vyhraje první existující a dostupný
--- (kompatibilita s overhauly), viz prototypes/science.lua.
local M = {}

--- Počet úrovní města.
M.MAX_LEVEL = 5
--- Nejvýš tolik domů v sérii od radnice (hloubka v grafu sítě).
M.MAX_HOUSE_DEPTH = 5
--- Dosah propojení domů: mezera mezi okraji budov v dlaždicích.
M.HOUSE_REACH = 6
--- Dosah překladiště k nejbližší budově města (mezera mezi okraji).
M.DEPOT_REACH = 4
--- Jak často se město zpracuje (ticky).
M.TOWN_INTERVAL = 120
--- Bonus k rychlosti výzkumu za jeden skrytý modul v beaconu radnice.
M.BONUS_STEP = 0.05
--- Počet slotů skrytého beaconu (strop bonusu = BONUS_SLOTS × BONUS_STEP).
M.BONUS_SLOTS = 200
--- Rozměr radnice v dlaždicích.
M.HALL_SIZE = 15

--- Úrovně: rychlost radnice, limit domů s bonusem, bonus za dům, příkon města a milník na další úroveň.
M.LEVELS = {
  {
    researching_speed = 2, house_limit = 4, house_bonus = 0.10, power_mw = 1,
    upgrade = {
      { type = "item", candidates = { "wood" }, amount = 200 },
      { type = "item", candidates = { "iron-plate" }, amount = 400 },
      { type = "item", candidates = { "copper-plate" }, amount = 200 },
      { type = "item", candidates = { "stone-brick", "stone" }, amount = 200 },
    },
  },
  {
    researching_speed = 4, house_limit = 8, house_bonus = 0.15, power_mw = 4,
    upgrade = {
      { type = "item", candidates = { "steel-plate", "iron-plate" }, amount = 400 },
      { type = "item", candidates = { "electronic-circuit" }, amount = 400 },
      { type = "item", candidates = { "pipe" }, amount = 100 },
      { type = "fluid", candidates = { "water" }, amount = 20000 },
    },
  },
  {
    researching_speed = 6, house_limit = 12, house_bonus = 0.20, power_mw = 15,
    upgrade = {
      { type = "item", candidates = { "plastic-bar" }, amount = 500 },
      { type = "item", candidates = { "advanced-circuit", "electronic-circuit" }, amount = 300 },
      { type = "item", candidates = { "engine-unit" }, amount = 100 },
      { type = "item", candidates = { "concrete", "stone-brick" }, amount = 1000 },
      { type = "fluid", candidates = { "petroleum-gas", "crude-oil" }, amount = 30000 },
    },
  },
  {
    researching_speed = 8, house_limit = 16, house_bonus = 0.25, power_mw = 50,
    upgrade = {
      { type = "item", candidates = { "processing-unit", "advanced-circuit" }, amount = 400 },
      { type = "item", candidates = { "low-density-structure", "plastic-bar" }, amount = 200 },
      { type = "item", candidates = { "electric-engine-unit", "engine-unit" }, amount = 200 },
      { type = "item", candidates = { "refined-concrete", "concrete" }, amount = 1000 },
      { type = "fluid", candidates = { "lubricant", "heavy-oil" }, amount = 30000 },
    },
  },
  {
    researching_speed = 10, house_limit = 20, house_bonus = 0.30, power_mw = 150,
  },
}

--- Parametry úrovně.
--- @param level integer 1..MAX_LEVEL
function M.get(level)
  return M.LEVELS[level]
end

--- Jméno prototypu radnice dané úrovně.
function M.hall_name(level)
  return "rt-town-hall-" .. level
end

--- Úroveň podle jména prototypu radnice, nebo nil pro jinou entitu.
function M.hall_level(name)
  local level = name:match("^rt%-town%-hall%-(%d+)$")
  return level and tonumber(level)
end

--- Jména všech prototypů radnic.
function M.hall_names()
  local names = {}
  for level = 1, M.MAX_LEVEL do names[level] = M.hall_name(level) end
  return names
end

--- Příkon města dané úrovně v joulech za tick.
function M.power_per_tick(level)
  return M.LEVELS[level].power_mw * 1e6 / 60
end

--- Počet skrytých bonusových modulů pro aktivní domy (domy nad limit úrovně se nepočítají).
function M.bonus_modules(level, active_houses)
  local cfg = M.LEVELS[level]
  local counted = math.min(active_houses, cfg.house_limit)
  return math.floor(counted * cfg.house_bonus / M.BONUS_STEP + 0.5)
end

return M
