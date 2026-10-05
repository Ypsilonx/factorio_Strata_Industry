--- Jednotkové testy balanční tabulky úrovní a pomocných funkcí.
local A = require("assert")
local levels = require("shared.levels")

return {
  { "pět úrovní se všemi poli", function()
    A.eq(#levels.LEVELS, levels.MAX_LEVEL, "počet úrovní")
    for level = 1, levels.MAX_LEVEL do
      local cfg = levels.get(level)
      A.truthy(cfg.researching_speed > 0 and cfg.house_limit > 0 and cfg.house_bonus > 0 and cfg.power_mw > 0,
        "pole úrovně " .. level)
    end
  end },
  { "limity, příkon a rychlost rostou", function()
    for level = 2, levels.MAX_LEVEL do
      local a, b = levels.get(level - 1), levels.get(level)
      A.truthy(b.house_limit > a.house_limit, "limit domů roste " .. level)
      A.truthy(b.power_mw > a.power_mw, "příkon roste " .. level)
      A.truthy(b.researching_speed > a.researching_speed, "rychlost roste " .. level)
    end
  end },
  { "milníky mají všechny úrovně kromě poslední", function()
    for level = 1, levels.MAX_LEVEL - 1 do
      local upgrade = levels.get(level).upgrade
      A.truthy(upgrade and #upgrade > 0, "milník úrovně " .. level)
      for _, req in ipairs(upgrade) do
        A.truthy((req.type == "item" or req.type == "fluid") and #req.candidates > 0 and req.amount > 0,
          "požadavek úrovně " .. level)
      end
    end
    A.eq(levels.get(levels.MAX_LEVEL).upgrade, nil, "poslední úroveň nemá milník")
  end },
  { "jména radnic tam i zpět", function()
    A.eq(levels.hall_name(3), "rt-town-hall-3", "hall_name")
    A.eq(levels.hall_level("rt-town-hall-3"), 3, "hall_level")
    A.eq(levels.hall_level("lab"), nil, "cizí jméno")
    A.eq(#levels.hall_names(), levels.MAX_LEVEL, "hall_names")
  end },
  { "příkon v joulech za tick", function()
    A.eq(levels.power_per_tick(1), levels.get(1).power_mw * 1e6 / 60, "power_per_tick")
  end },
  { "bonusové moduly se stropem limitu domů", function()
    local cfg = levels.get(1)
    A.eq(levels.bonus_modules(1, 0), 0, "bez domů")
    A.eq(levels.bonus_modules(1, cfg.house_limit), math.floor(cfg.house_limit * cfg.house_bonus / levels.BONUS_STEP + 0.5), "na limitu")
    A.eq(levels.bonus_modules(1, cfg.house_limit + 10), levels.bonus_modules(1, cfg.house_limit), "nad limitem")
    local top = levels.get(levels.MAX_LEVEL)
    A.truthy(levels.bonus_modules(levels.MAX_LEVEL, top.house_limit) <= levels.BONUS_SLOTS, "vejde se do beaconu")
  end },
}
