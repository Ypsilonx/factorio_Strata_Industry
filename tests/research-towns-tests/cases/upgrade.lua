--- Integrační testy povýšení města, vstupů radnice podle úrovně a výzkumu s elektřinou.
local levels = require("__research-towns__/shared/levels")
local H = require("helpers")
local R = H.REMOTE

--- Postaví k radnici n domů (všechny v hloubce 1).
local function houses(ctx, n)
  ctx.houses = {}
  local rows = { -6, -2, 2, 6 }
  for i = 1, n do ctx.houses[i] = H.house(ctx, i <= 4 and 11 or -11, rows[(i - 1) % 4 + 1]) end
end

--- Dodá do nového překladiště všechny předměty aktuálního milníku.
local function deliver_items(ctx)
  ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
  for _, req in ipairs(H.status(ctx.town).requirements) do
    if req.type == "item" then ctx.depot.insert({ name = req.name, count = req.amount }) end
  end
end

return {
  {
    name = "radnice úrovně 1 přijme červenou, ne zelenou",
    setup = function(ctx) ctx.town = H.town(ctx) end,
    steps = { { ticks = 1, run = function(ctx)
      local hall = H.hall(ctx.town)
      H.check(hall.insert({ name = "logistic-science-pack", count = 1 }) == 0, "přijala zelenou")
      H.check(hall.insert({ name = "automation-science-pack", count = 1 }) == 1, "nepřijala červenou")
    end } },
  },
  {
    name = "povýšení vymění radnici, zachová balíčky a přebarví domy",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      houses(ctx, 4)
      deliver_items(ctx)
      H.hall(ctx.town).insert({ name = "automation-science-pack", count = 5 })
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        H.process(ctx.town)
        local s = H.status(ctx.town)
        H.check(s.can_upgrade, "nelze povýšit: " .. serpent.line(s.requirements))
        H.check(remote.call(R, "upgrade", ctx.town), "upgrade vrátil false")
      end },
      { ticks = 1, run = function(ctx)
        local s = H.status(ctx.town)
        local hall = H.hall(ctx.town)
        H.check(s.level == 2 and hall.name == levels.hall_name(2), "radnice není úrovně 2")
        H.check(hall.get_item_count("automation-science-pack") == 5, "balíčky se ztratily")
        H.check(hall.insert({ name = "logistic-science-pack", count = 1 }) == 1, "úroveň 2 nepřijme zelenou")
        for _, req in ipairs(s.requirements) do H.check(req.delivered == 0, "postup se nevynuloval") end
        H.check(ctx.houses[1].graphics_variation == 1, "dům změnil vzhled bez vylepšení")
        H.check(s.beacon_modules == levels.bonus_modules(2, { 1, 1, 1, 1 }), "bonus po povýšení: " .. s.beacon_modules)
        H.check(remote.call(R, "town_of", ctx.depot.unit_number) == ctx.town, "překladiště ztratilo město")
      end },
    },
  },
  {
    name = "bez dost domů nelze povýšit",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      houses(ctx, 3)
      deliver_items(ctx)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      H.check(not H.status(ctx.town).can_upgrade, "povýšení se 3 domy")
      H.check(not remote.call(R, "upgrade", ctx.town), "upgrade prošel")
    end } },
  },
  {
    name = "radnice s elektřinou zkoumá",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      H.place(ctx, "rt-power-depot", -4, 10)
      H.power(ctx, -10, 13)
      local force = game.forces.player
      force.technologies["automation-science-pack"].researched = true
      force.add_research("automation")
      H.hall(ctx.town).insert({ name = "automation-science-pack", count = 50 })
      -- Pohlcovat jde jen existující znečištění.
      H.hall(ctx.town).surface.pollute(H.hall(ctx.town).position, 5000)
    end,
    steps = {
      { ticks = 30, run = function(ctx)
        H.process(ctx.town)
        H.check(H.status(ctx.town).power_ok, "elektřina nepokryta")
      end },
      { ticks = 600, run = function(ctx)
        local force = game.forces.player
        H.check(force.research_progress > 0 or force.technologies["automation"].researched, "výzkum nepostoupil")
        local hall = H.hall(ctx.town)
        local stats = hall.surface.pollution_statistics
        local absorbed = (stats.output_counts[hall.name] or 0) + math.max(0, -(stats.input_counts[hall.name] or 0))
        H.check(absorbed > 0, "zkoumající radnice nepohlcuje znečištění (statistika)")
      end },
    },
  },
  {
    name = "nad poslední vědou zůstává nejvyšší radnice a přidá produktivitu",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.count = H.level_count()
      remote.call(R, "set_level", ctx.town, ctx.count + 3)
      H.hall(ctx.town).insert({ name = "automation-science-pack", count = 5 })
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        local hall = H.hall(ctx.town)
        H.check(hall.name == levels.hall_name(ctx.count), "radnice: " .. hall.name)
        local expected = levels.productivity_modules(ctx.count + 3, ctx.count) * levels.BONUS_STEP
        local productivity = hall.effects and hall.effects.productivity or 0
        H.check(math.abs(productivity - expected) < 1e-6, "produktivita " .. productivity .. " ≠ " .. expected)
        H.check(#H.status(ctx.town).requirements > 0, "nekonečný milník je prázdný")
        ctx.unit = hall.unit_number
        remote.call(R, "set_level", ctx.town, ctx.count + 4)
      end },
      { ticks = 1, run = function(ctx)
        local hall = H.hall(ctx.town)
        H.check(hall.unit_number == ctx.unit, "stejný prototyp se zbytečně vyměnil")
        H.check(hall.get_item_count("automation-science-pack") == 5, "balíčky se ztratily")
        H.check(H.status(ctx.town).level == ctx.count + 4, "úroveň")
      end },
    },
  },
  {
    name = "obnova města (změna konfigurace) srovná příkon a bonus s aktuálními vzorci",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.depot = H.place(ctx, "rt-power-depot", -4, 10)
    end,
    steps = { { ticks = 1, run = function(ctx)
      -- Napodobí starý save: jiný odběr a moduly navíc.
      ctx.depot.power_usage = 1
      local beacon = ctx.surface.find_entities_filtered({ name = "rt-hall-beacon", position = H.hall(ctx.town).position })[1]
      beacon.get_module_inventory().insert({ name = "rt-bonus-module", count = 50 })
      remote.call(R, "refresh_town", ctx.town)
      local expected = levels.power_per_tick(1, H.level_count())
      H.check(math.abs(ctx.depot.power_usage - expected) < 1e-6, "odběr " .. ctx.depot.power_usage .. " ≠ " .. expected)
      H.check(H.status(ctx.town).beacon_modules == 0, "moduly navíc zůstaly")
    end } },
  },
}
