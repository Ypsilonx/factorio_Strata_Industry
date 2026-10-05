--- Integrační testy průběžné spotřeby surovin.
local H = require("helpers")
local R = H.REMOTE

--- Město úrovně 2 s elektřinou, překladištěm se surovinami spotřeby a balíčky v radnici.
local function supplied_town(ctx, packs)
  ctx.town = H.town(ctx)
  remote.call(R, "set_level", ctx.town, 2)
  H.place(ctx, "rt-power-depot", -4, 10)
  H.power(ctx, -10, 13)
  ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
  H.supply_upkeep(ctx.town, ctx.depot, 1000)
  if packs then H.hall(ctx.town).insert({ name = "automation-science-pack", count = packs }) end
end

return {
  {
    name = "úroveň 1 nic nespotřebovává",
    setup = function(ctx) ctx.town = H.town(ctx) end,
    steps = { { ticks = 1, run = function(ctx)
      local s = H.status(ctx.town)
      H.check(#s.upkeep == 0 and s.upkeep_ok, "spotřeba na úrovni 1")
    end } },
  },
  {
    name = "spotřeba odebírá suroviny a bez nich radnice stojí",
    setup = function(ctx) supplied_town(ctx, 50) end,
    steps = {
      { ticks = 30, run = function(ctx)
        H.research()
        H.process(ctx.town)
        local s = H.status(ctx.town)
        H.check(#s.upkeep > 0, "úroveň 2 nemá spotřebu")
        H.check(s.upkeep_ok and not H.hall(ctx.town).disabled_by_script, "zásobená radnice stojí")
        H.check(s.upkeep[1].stock > 0, "zásoba se nenaplnila")
        ctx.depot.clear_items_inside()
        -- Zásoba je na UPKEEP_BUFFER_SECONDS (30 intervalů po 2 s); 40 zpracování ji jistě vyčerpá.
        for _ = 1, 40 do H.process(ctx.town) end
        s = H.status(ctx.town)
        H.check(not s.upkeep_ok, "spotřeba hlášena jako pokrytá bez surovin")
        H.check(H.hall(ctx.town).disabled_by_script, "radnice bez surovin zkoumá")
      end },
    },
  },
  {
    name = "bez výzkumu se nespotřebovává",
    setup = function(ctx) supplied_town(ctx, nil) end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      local name = H.status(ctx.town).upkeep[1].name
      local before = H.stock(ctx.town, name)
      H.process(ctx.town)
      H.check(H.stock(ctx.town, name) == before, "prázdná radnice spotřebovala zásobu")
    end } },
  },
}
