--- Integrační testy sítě města: připojení domů, hloubka, odpojení, limit bonusu.
local levels = require("__research-towns__/shared/levels")
local H = require("helpers")
local R = H.REMOTE

--- Řetěz domů na ose x: mezera 2 mezi sousedy, nesousedící domy mají mezeru 7 (> dosah 6).
local CHAIN = { 11, 16, 21, 26, 31, 36 }

--- Postaví prvních n domů řetězu.
local function chain(ctx, n)
  ctx.houses = {}
  for i = 1, n do ctx.houses[i] = H.house(ctx, CHAIN[i], 0) end
end

return {
  {
    name = "noční světla: radnice i dům mají světla, se zbořením domu zmizí",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.house = H.house(ctx, 11, 0)
      ctx.hall = H.status(ctx.town).hall
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        H.check(remote.call(R, "light_count", ctx.hall) > 0, "radnice nemá noční světla")
        H.check(remote.call(R, "light_count", ctx.house.unit_number) > 0, "dům nemá noční světla")
        ctx.house_key = ctx.house.unit_number
        ctx.house.destroy({ raise_destroy = true })
      end },
      { ticks = 1, run = function(ctx)
        H.check(remote.call(R, "light_count", ctx.house_key) == 0, "světla zbořeného domu zůstala")
      end },
    },
  },
  {
    name = "spojení domu s radnicí: chodník, šňůra, praporky a lucerny; se zbořením zmizí",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.house = H.house(ctx, 11, 0)
      ctx.hall = H.status(ctx.town).hall
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        local count = remote.call(R, "link_renders", ctx.hall, ctx.house.unit_number)
        -- Chodník + stín + 10 úseků šňůry + praporky + 2 lucerny se světlem.
        H.check(count >= 16, "vykreslených objektů spojení: " .. count)
        H.check(remote.call(R, "link_path_visible", ctx.hall, ctx.house.unit_number) == false,
          "vyšlapaný chodník je vidět i bez najetí myší")
        ctx.house_key = ctx.house.unit_number
        ctx.house.destroy({ raise_destroy = true })
      end },
      { ticks = 1, run = function(ctx)
        H.check(remote.call(R, "link_renders", ctx.hall, ctx.house_key) == 0, "spojení zůstalo")
      end },
    },
  },
  {
    name = "spojení podle úrovně města: šňůra, po povýšení dřevěná lávka",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.house = H.house(ctx, 11, 0)
      ctx.hall = H.status(ctx.town).hall
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        H.check(remote.call(R, "link_style", ctx.hall, ctx.house.unit_number) == "garland", "úroveň 1 není šňůra")
        -- Úroveň se vzhledem 3 (logistika): první úroveň, jejíž varianta je ≥ 3.
        local level = 1
        while levels.variant(level, H.level_count()) < 3 do level = level + 1 end
        remote.call(R, "set_level", ctx.town, level)
        ctx.hall = H.status(ctx.town).hall
      end },
      { ticks = 1, run = function(ctx)
        local style = remote.call(R, "link_style", ctx.hall, ctx.house.unit_number)
        H.check(style == "wood", "po povýšení styl " .. tostring(style))
        H.check(remote.call(R, "link_renders", ctx.hall, ctx.house.unit_number) >= 3, "lávka bez úseků")
      end },
    },
  },
  {
    name = "dům u radnice patří k městu v hloubce 1",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.house = H.house(ctx, 11, 0)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "town_of", ctx.house.unit_number) == ctx.town, "dům nepatří k městu")
      H.check(remote.call(R, "depth_of", ctx.house.unit_number) == 1, "hloubka domu není 1")
      H.check(ctx.house.graphics_variation == 1, "varianta domu není úroveň 1")
    end } },
  },
  {
    name = "šestý dům v sérii je neaktivní",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      chain(ctx, 6)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "depth_of", ctx.houses[6].unit_number) == 6, "hloubka 6. domu")
      local active = H.status(ctx.town).active_houses
      H.check(active == 5, "aktivní domy: " .. active)
    end } },
  },
  {
    name = "zbouráním domu se zbytek řetězu odpojí",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      chain(ctx, 4)
    end,
    steps = {
      { ticks = 1, run = function(ctx) ctx.houses[2].destroy({ raise_destroy = true }) end },
      { ticks = 1, run = function(ctx)
        H.check(remote.call(R, "town_of", ctx.houses[3].unit_number) == nil, "3. dům zůstal připojený")
        H.check(remote.call(R, "town_of", ctx.houses[1].unit_number) == ctx.town, "1. dům se odpojil")
        H.check(H.status(ctx.town).active_houses == 1, "aktivní domy po zbourání")
      end },
    },
  },
  {
    name = "bonus domů zrychluje radnici, beacon je nezničitelný a obnoví se",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      for _, dy in ipairs({ -6, -2, 2, 6 }) do H.house(ctx, 11, dy) end
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        local hall = H.hall(ctx.town)
        local expected = levels.bonus_modules(1, { 1, 1, 1, 1 }) * levels.BONUS_STEP
        local speed = hall.effects and hall.effects.speed or 0
        H.check(math.abs(speed - expected) < 1e-6, "rychlost radnice: " .. speed .. " ≠ " .. expected)
        local beacon = ctx.surface.find_entities_filtered({ name = "rt-hall-beacon", position = hall.position })[1]
        H.check(beacon and not beacon.destructible, "beacon jde zničit")
        beacon.destroy()
        H.process(ctx.town)
      end },
      { ticks = 1, run = function(ctx)
        local s = H.status(ctx.town)
        H.check(s.beacon_modules == levels.bonus_modules(1, { 1, 1, 1, 1 }), "beacon se neobnovil: " .. s.beacon_modules)
      end },
    },
  },
  {
    name = "zničení bez události (jiný mod) se uklidí",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      chain(ctx, 3)
      ctx.depot = H.place(ctx, "rt-power-depot", -4, 10)
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        ctx.unit = ctx.houses[3].unit_number
        ctx.houses[2].destroy()
        ctx.depot.destroy()
      end },
      { ticks = 3, run = function(ctx)
        H.check(remote.call(R, "town_of", ctx.unit) == nil, "dům za zničeným zůstal připojený")
        H.process(ctx.town)
        H.check(H.status(ctx.town).active_houses == 1, "aktivní domy po zničení")
        H.hall(ctx.town).destroy()
      end },
      { ticks = 3, run = function(ctx)
        H.check(remote.call(R, "town_status", ctx.town) == nil, "město přežilo zničení radnice")
        H.check(remote.call(R, "town_of", ctx.houses[1].unit_number) == nil, "dům zůstal u zaniklého města")
      end },
    },
  },
  {
    name = "domy nad limit nedávají bonus",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      for _, dy in ipairs({ -6, -2, 2, 6 }) do
        H.house(ctx, 11, dy)
        H.house(ctx, -11, dy)
      end
    end,
    steps = { { ticks = 1, run = function(ctx)
      local s = H.status(ctx.town)
      H.check(s.active_houses == 8, "aktivní domy: " .. s.active_houses)
      local expected = levels.bonus_modules(1, { 1, 1, 1, 1, 1, 1, 1, 1 })
      H.check(s.beacon_modules == expected, "moduly beaconu: " .. s.beacon_modules .. " ≠ " .. expected)
    end } },
  },
}
