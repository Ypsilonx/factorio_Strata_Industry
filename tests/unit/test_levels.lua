--- Jednotkové testy balančních vzorců úrovní (počet úrovní = počet věd).
local A = require("assert")
local levels = require("shared.levels")

--- Je posloupnost f(1..n) neklesající?
local function non_decreasing(n, f)
  for i = 2, n do
    if f(i) < f(i - 1) then return false end
  end
  return true
end

return {
  { "rychlost radnice od SPEED_FIRST do SPEED_LAST", function()
    A.eq(levels.researching_speed(1, 7), levels.SPEED_FIRST, "první úroveň")
    A.eq(levels.researching_speed(7, 7), levels.SPEED_LAST, "poslední věda")
    A.eq(levels.researching_speed(1, 1), levels.SPEED_FIRST, "jediná věda")
    A.truthy(non_decreasing(18, function(t) return levels.researching_speed(t, 18) end), "roste i pro 18 úrovní")
  end },
  { "limit domů 4 na úroveň, strop 20", function()
    A.eq(levels.house_limit(1), 4, "úroveň 1")
    A.eq(levels.house_limit(5), 20, "úroveň 5")
    A.eq(levels.house_limit(9), 20, "nad stropem")
  end },
  { "příkon od 1 MW do 150 MW, nad poslední vědou dál roste", function()
    A.truthy(math.abs(levels.power_mw(1, 7) - 1) < 1e-9, "úroveň 1")
    A.truthy(math.abs(levels.power_mw(7, 7) - 150) < 1e-6, "poslední věda")
    A.truthy(math.abs(levels.power_mw(8, 7) - 165) < 1e-6, "první nekonečná")
    A.truthy(non_decreasing(30, function(l) return levels.power_mw(l, 18) end), "roste i pro 18 úrovní")
    A.eq(levels.power_per_tick(1, 7), levels.power_mw(1, 7) * 1e6 / 60, "joule za tick")
  end },
  { "pásma surovin se roztáhnou na libovolný počet úrovní", function()
    A.eq(levels.tier_index(1, 7), 1, "první milník")
    A.eq(levels.tier_index(6, 7), #levels.TIERS, "poslední konečný milník")
    A.eq(levels.tier_index(20, 7), #levels.TIERS, "nekonečné")
    A.eq(levels.tier_index(1, 2), 1, "jediný milník")
    local seen = {}
    for k = 1, 17 do seen[levels.tier_index(k, 18)] = true end
    for t = 1, #levels.TIERS do A.truthy(seen[t], "18 úrovní použije pásmo " .. t) end
    A.truthy(non_decreasing(17, function(k) return levels.tier_index(k, 18) end), "pásma neklesají")
  end },
  { "pásma mají platné kandidáty", function()
    for t, tier in ipairs(levels.TIERS) do
      A.truthy(#tier > 0, "pásmo " .. t)
      for _, req in ipairs(tier) do
        A.truthy((req.type == "item" or req.type == "fluid") and #req.candidates > 0 and req.amount > 0,
          "požadavek pásma " .. t)
      end
    end
  end },
  { "množství milníku roste s úrovní", function()
    A.eq(levels.milestone_scale(1), 1, "úroveň 1")
    local out = levels.scaled({ { type = "item", name = "a", amount = 100, science = true } }, 3)
    A.eq(out[1].amount, math.floor(100 * levels.milestone_scale(3) + 0.5), "úroveň 3")
    A.eq(out[1].science, true, "příznak vědy zůstane")
  end },
  { "grafické varianty pokryjí všechny úrovně", function()
    A.eq(levels.variant(1, 7), 1, "první")
    A.eq(levels.variant(7, 7), levels.VARIANTS, "poslední věda")
    A.eq(levels.variant(100, 7), levels.VARIANTS, "nekonečné")
    local seen = {}
    for t = 1, 18 do seen[levels.variant(t, 18)] = true end
    for v = 1, levels.VARIANTS do A.truthy(seen[v], "18 úrovní použije variantu " .. v) end
  end },
  { "bonus domu je (úroveň domu + 1) %", function()
    for h = 1, 5 do
      A.eq(levels.bonus_modules(1, { h }) * levels.BONUS_STEP, levels.house_bonus(h), "dům úrovně " .. h)
      A.truthy(math.abs(levels.house_bonus(h) - (h + 1) / 100) < 1e-9, "house_bonus " .. h)
    end
    A.eq(levels.bonus_modules(1, {}), 0, "bez domů")
  end },
  { "počítají se nejlepší domy do limitu a strop +120 %", function()
    A.eq(levels.bonus_modules(1, { 1, 1, 1, 1, 5 }), 6 + 2 + 2 + 2, "nejlepší 4 domy")
    local many = {}
    for i = 1, 20 do many[i] = 10 end
    A.eq(levels.bonus_modules(5, many), math.floor(levels.SPEED_BONUS_CAP / levels.BONUS_STEP + 0.5), "strop")
    A.truthy(levels.bonus_modules(5, many) <= levels.BONUS_SLOTS, "vejde se do beaconu")
  end },
  { "plný bonus domů: 20 domů úrovně 5 = 120 %", function()
    local fives, fours = {}, {}
    for i = 1, 20 do fives[i], fours[i] = 5, 4 end
    A.truthy(levels.bonus_full(5, fives), "20 × 6 % = strop")
    A.truthy(not levels.bonus_full(5, fours), "20 × 5 % pod stropem")
    A.truthy(not levels.bonus_full(1, { 1 }), "jeden dům")
  end },
  { "úroveň domu nejvýš úroveň města, poslední věda a 5", function()
    A.eq(levels.house_level_max(3, 7), 3, "město 3")
    A.eq(levels.house_level_max(9, 7), levels.HOUSE_LEVEL_MAX, "nad 5")
    A.eq(levels.house_level_max(9, 4), 4, "jen 4 vědy")
  end },
  { "vzhled domu = jeho úroveň (nejvýš počet vzhledů)", function()
    A.eq(levels.house_variant(1), 1, "úroveň 1")
    A.eq(levels.house_variant(3), 3, "úroveň 3")
    A.eq(levels.house_variant(levels.VARIANTS + 2), levels.VARIANTS, "nad počtem vzhledů poslední")
  end },
  { "produktivita jen nad poslední vědou, klesající přírůstky pod stropem", function()
    A.eq(levels.productivity(7, 7), 0, "poslední věda")
    local p1, p2, p3 = levels.productivity(8, 7), levels.productivity(9, 7), levels.productivity(10, 7)
    A.truthy(p1 > 0 and p2 > p1 and p3 > p2, "roste")
    A.truthy(p2 - p1 < p1, "přírůstky klesají")
    A.truthy(levels.productivity(1000, 7) <= levels.PRODUCTIVITY_MAX, "strop")
  end },
  { "rychlost i produktivita se vejdou do beaconu, příkon zůstane konečný", function()
    local speed = math.floor(levels.SPEED_BONUS_CAP / levels.BONUS_STEP + 0.5)
    A.truthy(speed + levels.productivity_modules(1000, 7) <= levels.BONUS_SLOTS, "sloty beaconu")
    local mw = levels.power_mw(100, 7)
    A.truthy(mw > levels.POWER_LAST_MW and mw < math.huge, "příkon na úrovni 100")
  end },
  { "jména radnic tam i zpět", function()
    A.eq(levels.hall_name(3), "rt-town-hall-3", "hall_name")
    A.eq(levels.hall_level("rt-town-hall-3"), 3, "hall_level")
    A.eq(levels.hall_level("lab"), nil, "cizí jméno")
    A.eq(#levels.hall_names(7), 7, "hall_names")
    A.eq(levels.hall_tier(9, 7), 7, "nad poslední vědou zůstává nejvyšší radnice")
  end },
}
