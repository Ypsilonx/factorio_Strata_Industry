--- Balanc úrovní měst – jediné místo, kde se ladí čísla. Sdílí ho data stage i control stage.
--- Počet úrovní = počet věd ve hře (spočítá data-final-fixes, runtime ho čte z mod-data); hodnoty úrovní jsou
--- vzorce, takže fungují pro vanillu (7 věd) i overhauly (Bob's 18). Suroviny milníků jsou seznamy kandidátů:
--- v data-final-fixes vyhraje první existující a dostupný (kompatibilita s overhauly), viz prototypes/science.lua.
local M = {}

--- Nejvýš tolik domů v sérii od radnice (hloubka v grafu sítě).
M.MAX_HOUSE_DEPTH = 5
--- Dosah propojení domů: mezera mezi okraji budov v dlaždicích.
M.HOUSE_REACH = 6
--- Dosah překladiště k nejbližší budově města (mezera mezi okraji).
M.DEPOT_REACH = 4
--- Jak často se město zpracuje (ticky).
M.TOWN_INTERVAL = 120
--- Bonus za jeden skrytý modul v beaconu radnice.
M.BONUS_STEP = 0.01
--- Počet slotů skrytého beaconu (rychlost do SPEED_BONUS_CAP + produktivita do PRODUCTIVITY_MAX).
M.BONUS_SLOTS = 250
--- Rozměr radnice v dlaždicích.
M.HALL_SIZE = 15

--- Rychlost výzkumu radnice na první a na poslední vědecké úrovni (mezi nimi lineárně).
M.SPEED_FIRST = 2
M.SPEED_LAST = 10
--- Domy s bonusem: HOUSES_PER_LEVEL × úroveň, nejvýš HOUSE_LIMIT_MAX. Stejný počet je podmínkou povýšení.
M.HOUSES_PER_LEVEL = 4
M.HOUSE_LIMIT_MAX = 20
--- Nejvyšší úroveň domu (20 domů × (5 + 1) % = strop rychlosti SPEED_BONUS_CAP).
M.HOUSE_LEVEL_MAX = 5
--- Strop bonusu k rychlosti ze všech domů dohromady (+120 %).
M.SPEED_BONUS_CAP = 1.2
--- Příkon města (MW) na první a na poslední vědecké úrovni (mezi nimi geometricky).
M.POWER_FIRST_MW = 1
M.POWER_LAST_MW = 150
--- Nad poslední vědou roste příkon o tento díl příkonu poslední úrovně za každou úroveň.
M.POWER_INFINITE_GROWTH = 0.1
--- Kusů nové vědy v milníku.
M.SCIENCE_PACKS = 200
--- Množství surovin milníku k → k+1 = základ z TIERS × (1 + MILESTONE_GROWTH × (k − 1)).
M.MILESTONE_GROWTH = 0.25
--- Počet grafických variant radnice a domu (rozloží se rovnoměrně na vědecké úrovně).
M.VARIANTS = 5
--- Nekonečné úrovně: produktivita radnice se blíží PRODUCTIVITY_MAX; každá úroveň nad poslední vědou přidá
--- (1 − PRODUCTIVITY_DECAY) ze zbývajícího rozdílu (klesající křivka).
M.PRODUCTIVITY_MAX = 1
M.PRODUCTIVITY_DECAY = 0.9
--- Průběžná spotřeba: za minutu podíl množství každého splněného milníku (bez věd) × startup násobič.
M.UPKEEP_RATE = 0.01
--- Každý aktivní dům zvýší spotřebu o tento díl.
M.HOUSE_UPKEEP_SHARE = 0.05
--- Zásoba radnice na tolik sekund provozu; po jejím vyčerpání radnice stojí. Tabule v režimu Spotřeba
--- požaduje celou zásobu, aby překladiště drželo dost i při nepravidelných dodávkách.
M.UPKEEP_BUFFER_SECONDS = 300

--- Pohlcování znečištění (za minutu, × startup násobič): radnice při výzkumu od první k poslední vědě
--- (mezi nimi geometricky; pro srovnání kotel vypouští 30/min), aktivní dům nejvyšší úrovně stále.
M.HALL_ABSORB_FIRST = 30
M.HALL_ABSORB_LAST = 1000
M.HOUSE_ABSORB = 15
--- Obnova ruiny radnice: podíl surovin milníku současné úrovně (bez vědy), nahoru na celé kusy.
M.REPAIR_SHARE = 0.5

--- Pásma kandidátů surovin milníků od nejranějšího; tier_index je roztáhne na libovolný počet úrovní.
--- Nad poslední vědou se používá poslední pásmo.
M.TIERS = {
  {
    { type = "item", candidates = { "wood" }, amount = 200 },
    { type = "item", candidates = { "iron-plate" }, amount = 400 },
    { type = "item", candidates = { "copper-plate" }, amount = 200 },
    { type = "item", candidates = { "stone-brick", "stone" }, amount = 200 },
  },
  {
    { type = "item", candidates = { "steel-plate", "iron-plate" }, amount = 400 },
    { type = "item", candidates = { "electronic-circuit" }, amount = 400 },
    { type = "item", candidates = { "pipe" }, amount = 100 },
    { type = "fluid", candidates = { "water" }, amount = 20000 },
  },
  {
    { type = "item", candidates = { "plastic-bar" }, amount = 500 },
    { type = "item", candidates = { "advanced-circuit", "electronic-circuit" }, amount = 300 },
    { type = "item", candidates = { "engine-unit" }, amount = 100 },
    { type = "item", candidates = { "concrete", "stone-brick" }, amount = 1000 },
    { type = "fluid", candidates = { "petroleum-gas", "crude-oil" }, amount = 30000 },
  },
  {
    { type = "item", candidates = { "processing-unit", "advanced-circuit" }, amount = 400 },
    { type = "item", candidates = { "low-density-structure", "plastic-bar" }, amount = 200 },
    { type = "item", candidates = { "electric-engine-unit", "engine-unit" }, amount = 200 },
    { type = "item", candidates = { "refined-concrete", "concrete" }, amount = 1000 },
    { type = "fluid", candidates = { "lubricant", "heavy-oil" }, amount = 30000 },
  },
  {
    { type = "item", candidates = { "flying-robot-frame", "electric-engine-unit" }, amount = 200 },
    { type = "item", candidates = { "rocket-fuel", "solid-fuel" }, amount = 300 },
    { type = "item", candidates = { "low-density-structure", "plastic-bar" }, amount = 400 },
    { type = "item", candidates = { "processing-unit", "advanced-circuit" }, amount = 600 },
    { type = "fluid", candidates = { "lubricant", "heavy-oil" }, amount = 50000 },
  },
}

--- Jméno prototypu radnice dané vědecké úrovně.
function M.hall_name(tier)
  return "rt-town-hall-" .. tier
end

--- Úroveň podle jména prototypu radnice, nebo nil pro jinou entitu.
function M.hall_level(name)
  local level = name:match("^rt%-town%-hall%-(%d+)$")
  return level and tonumber(level)
end

--- Jméno prototypu ruiny radnice daného vzhledu (1..VARIANTS).
function M.ruin_name(variant)
  return "rt-town-ruin-" .. variant
end

--- Jména prototypů ruin všech vzhledů.
function M.ruin_names()
  local names = {}
  for variant = 1, M.VARIANTS do names[variant] = M.ruin_name(variant) end
  return names
end

--- Jména prototypů radnic 1..count.
function M.hall_names(count)
  local names = {}
  for tier = 1, count do names[tier] = M.hall_name(tier) end
  return names
end

--- Vědecká úroveň (prototyp radnice) pro úroveň města; nad poslední vědou zůstává nejvyšší.
function M.hall_tier(level, count)
  return math.min(level, count)
end

--- Rychlost výzkumu radnice vědecké úrovně tier z count.
function M.researching_speed(tier, count)
  if count <= 1 then return M.SPEED_FIRST end
  return M.SPEED_FIRST + (M.SPEED_LAST - M.SPEED_FIRST) * (tier - 1) / (count - 1)
end

--- Kolik domů dává bonus (a kolik jich je potřeba k povýšení) na dané úrovni.
function M.house_limit(level)
  return math.min(M.HOUSE_LIMIT_MAX, M.HOUSES_PER_LEVEL * level)
end

--- Příkon města v MW.
function M.power_mw(level, count)
  local tier = M.hall_tier(level, count)
  local mw = M.POWER_FIRST_MW
  if count > 1 then mw = M.POWER_FIRST_MW * (M.POWER_LAST_MW / M.POWER_FIRST_MW) ^ ((tier - 1) / (count - 1)) end
  if level > count then mw = mw * (1 + M.POWER_INFINITE_GROWTH * (level - count)) end
  return mw
end

--- Kolik znečištění za minutu pohlcuje radnice vědecké úrovně tier z count při výzkumu (bez násobiče).
function M.hall_absorption(tier, count)
  if count <= 1 then return M.HALL_ABSORB_FIRST end
  return M.HALL_ABSORB_FIRST * (M.HALL_ABSORB_LAST / M.HALL_ABSORB_FIRST) ^ ((tier - 1) / (count - 1))
end

--- Kolik znečištění za minutu pohlcuje aktivní dům úrovně house_level (jen nejvyšší úroveň; bez násobiče).
function M.house_absorption(house_level)
  return house_level >= M.HOUSE_LEVEL_MAX and M.HOUSE_ABSORB or 0
end

--- Příkon města v joulech za tick.
function M.power_per_tick(level, count)
  return M.power_mw(level, count) * 1e6 / 60
end

--- Index pásma TIERS pro milník level → level+1. Konečné milníky (1..count−1) se rozloží rovnoměrně
--- na všechna pásma; poslední konečný a nekonečné milníky dostanou poslední pásmo.
function M.tier_index(level, count)
  local last = count - 1
  if level >= last then return last <= 1 and 1 or #M.TIERS end
  return math.floor((level - 1) * (#M.TIERS - 1) / (last - 1)) + 1
end

--- Násobek množství surovin milníku level → level+1.
function M.milestone_scale(level)
  return 1 + M.MILESTONE_GROWTH * (level - 1)
end

--- Kopie požadavků s množstvím × milestone_scale(level) (zaokrouhleno; ostatní pole zůstanou).
--- @param requirements table[] { {type, name, amount, science?} }
function M.scaled(requirements, level)
  local scale = M.milestone_scale(level)
  local out = {}
  for i, req in ipairs(requirements) do
    out[i] = { type = req.type, name = req.name, amount = math.floor(req.amount * scale + 0.5), science = req.science }
  end
  return out
end

--- Grafická varianta (1..VARIANTS) radnice nebo domu dané úrovně.
function M.variant(level, count)
  local tier = M.hall_tier(level, count)
  return math.min(M.VARIANTS, math.floor((tier - 1) * M.VARIANTS / count) + 1)
end

--- Bonus jednoho domu k rychlosti výzkumu: (úroveň domu + 1) %.
function M.house_bonus(house_level)
  return (house_level + 1) / 100
end

--- Počet bonusových modulů rychlosti: domy od nejvyšší úrovně, nejvýš house_limit(level) domů,
--- součet zastropovaný SPEED_BONUS_CAP.
--- @param house_levels integer[] úrovně aktivních domů
function M.bonus_modules(level, house_levels)
  local sorted = {}
  for i, house_level in ipairs(house_levels) do sorted[i] = house_level end
  table.sort(sorted, function(a, b) return a > b end)
  local bonus = 0
  for i = 1, math.min(#sorted, M.house_limit(level)) do bonus = bonus + M.house_bonus(sorted[i]) end
  return math.floor(math.min(bonus, M.SPEED_BONUS_CAP) / M.BONUS_STEP + 0.5)
end

--- Nejvyšší úroveň, na kterou lze dům vylepšit ve městě dané úrovně (úroveň města, poslední věda, HOUSE_LEVEL_MAX).
function M.house_level_max(level, count)
  return math.min(level, count, M.HOUSE_LEVEL_MAX)
end

--- Grafická varianta domu: jeho úroveň (úroveň domu je nejvýš HOUSE_LEVEL_MAX = VARIANTS).
function M.house_variant(house_level)
  return math.min(house_level, M.VARIANTS)
end

--- Dávají domy už plný bonus k rychlosti (SPEED_BONUS_CAP)? Pak další vylepšování nic nepřidá.
--- @param house_levels integer[] úrovně aktivních domů
function M.bonus_full(level, house_levels)
  return M.bonus_modules(level, house_levels) >= math.floor(M.SPEED_BONUS_CAP / M.BONUS_STEP + 0.5)
end

--- Produktivita výzkumu radnice (0.1 = +10 %); jen nad poslední vědou.
function M.productivity(level, count)
  if level <= count then return 0 end
  return M.PRODUCTIVITY_MAX * (1 - M.PRODUCTIVITY_DECAY ^ (level - count))
end

--- Počet modulů produktivity ve skrytém beaconu.
function M.productivity_modules(level, count)
  return math.floor(M.productivity(level, count) / M.BONUS_STEP + 0.5)
end

return M
