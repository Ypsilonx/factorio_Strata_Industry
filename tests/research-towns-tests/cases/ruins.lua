--- Integrační testy ruiny: zničená radnice se změní v ruinu, město přežije a obnoví se dodáním materiálu.
local levels = require("__research-towns__/shared/levels")
local H = require("helpers")
local R = H.REMOTE

--- Zničí radnici města jako biteři (on_entity_died).
local function destroy_hall(ctx)
  ctx.old_hall = H.status(ctx.town).hall
  H.hall(ctx.town).die()
end

return {
  {
    name = "zničená radnice: ruina na stejném místě, město drží úroveň, postup a domy; nezkoumá ani neodebírá",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      remote.call(R, "set_level", ctx.town, 2)
      ctx.house = H.house(ctx, 11, 0)
      ctx.power = H.place(ctx, "rt-power-depot", -4, 10)
      ctx.position = H.hall(ctx.town).position
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        destroy_hall(ctx)
      end },
      { ticks = 1, run = function(ctx)
        local s = H.status(ctx.town)
        H.check(s, "město zaniklo")
        H.check(s.state == "ruin", "stav " .. tostring(s.state))
        H.check(s.level == 2, "úroveň " .. tostring(s.level))
        local ruin = H.hall(ctx.town)
        H.check(ruin and ruin.valid and ruin.unit_number ~= ctx.old_hall, "ruina nevznikla")
        H.check(ruin.name:find("^rt%-town%-ruin%-") ~= nil, "ruina má jméno " .. ruin.name)
        H.check(ruin.position.x == ctx.position.x and ruin.position.y == ctx.position.y, "ruina jinde")
        H.check(not ruin.destructible and ruin.disabled_by_script, "ruina zničitelná nebo zapnutá")
        H.check(remote.call(R, "town_of", ctx.house.unit_number) == ctx.town, "dům se odpojil")
        H.check(#s.requirements > 0 and s.level_progress == 0, "cena obnovy chybí")
        H.process(ctx.town)
        H.check(ctx.power.power_usage == 0, "rozvodna ruiny odebírá elektřinu")
        H.check(remote.call(R, "light_count", ruin.unit_number) == 0, "ruina svítí")
      end },
    },
  },
  {
    name = "obnova ruiny: překladiště dodá materiál a radnice se obnoví ve stejné úrovni",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      remote.call(R, "set_level", ctx.town, 2)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        destroy_hall(ctx)
      end },
      { ticks = 1, run = function(ctx)
        local s = H.status(ctx.town)
        H.check(s.state == "ruin", "stav " .. tostring(s.state))
        local inventory = ctx.depot.get_inventory(defines.inventory.chest)
        for _, req in ipairs(s.requirements) do
          H.check(req.type == "item", "test počítá jen s předměty v ceně obnovy")
          inventory.insert({ name = req.name, count = req.amount })
        end
        H.process(ctx.town)
        s = H.status(ctx.town)
        H.check(s.state == "partner", "radnice se neobnovila: " .. tostring(s.state))
        H.check(s.level == 2, "úroveň po obnově " .. tostring(s.level))
        H.check(H.hall(ctx.town).name == levels.hall_name(2), "obnovená radnice " .. H.hall(ctx.town).name)
        H.check(H.hall(ctx.town).destructible, "obnovená radnice nezničitelná")
      end },
    },
  },
}
