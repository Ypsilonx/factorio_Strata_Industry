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
        H.check(ctx.houses[1].graphics_variation == 2, "dům nemá vzhled úrovně 2")
        H.check(s.beacon_modules == levels.bonus_modules(2, 4), "bonus po povýšení: " .. s.beacon_modules)
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
    end,
    steps = {
      { ticks = 30, run = function(ctx)
        H.process(ctx.town)
        H.check(H.status(ctx.town).power_ok, "elektřina nepokryta")
      end },
      { ticks = 600, run = function()
        local force = game.forces.player
        H.check(force.research_progress > 0 or force.technologies["automation"].researched, "výzkum nepostoupil")
      end },
    },
  },
}
