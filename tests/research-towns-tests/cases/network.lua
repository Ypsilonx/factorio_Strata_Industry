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
      local expected = levels.bonus_modules(1, 8)
      H.check(s.beacon_modules == expected, "moduly beaconu: " .. s.beacon_modules .. " ≠ " .. expected)
    end } },
  },
}
