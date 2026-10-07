--- Integrační testy vylepšování domů a priority rozdělení surovin.
local levels = require("__research-towns__/shared/levels")
local H = require("helpers")
local R = H.REMOTE

--- Suroviny milníku úrovně (bez vědy) jako mapa jméno → množství; kapaliny test nepoužívá.
local function materials(level)
  local result = {}
  for _, req in ipairs(H.levels_data().upgrade[tostring(level)]) do
    if not req.science then
      H.check(req.type == "item", "test počítá jen s předměty v milníku " .. level)
      result[req.name] = (result[req.name] or 0) + req.amount
    end
  end
  return result
end

--- Text čísla úrovně nad domem (nil = žádný).
local function house_label(entity)
  for _, render in pairs(rendering.get_all_objects("research-towns")) do
    if render.type == "text" and render.target.entity == entity then return render.text end
  end
  return nil
end

return {
  {
    name = "pohlcování znečištění: dům nejvyšší úrovně pohlcuje, nižší ne; radnice má záporné emise",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.house = H.house(ctx, 11, 0)
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        local surface, position = ctx.house.surface, ctx.house.position
        surface.pollute(position, 1000)
        local before = surface.get_pollution(position)
        H.process(ctx.town)
        H.check(surface.get_pollution(position) >= before - 1e-6, "dům úrovně 1 pohlcuje")
        remote.call(R, "set_house_level", ctx.house.unit_number, levels.HOUSE_LEVEL_MAX)
        before = surface.get_pollution(position)
        H.process(ctx.town)
        H.check(surface.get_pollution(position) < before, "dům nejvyšší úrovně nepohlcuje: "
          .. before .. " → " .. surface.get_pollution(position))
        local hall = prototypes.entity[H.hall(ctx.town).name]
        H.check(hall.void_energy_source_prototype.emissions_per_joule.pollution < 0, "radnice nemá záporné emise")
      end },
    },
  },
  {
    name = "dodané suroviny vylepší dům a zvýší bonus",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      remote.call(R, "set_level", ctx.town, 2)
      ctx.house = H.house(ctx, 11, 0)
      H.check(remote.call(R, "house_level", ctx.house.unit_number) == 1, "nový dům má úroveň 1")
      H.check(house_label(ctx.house) == "1", "číslo nad novým domem: " .. tostring(house_label(ctx.house)))
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
      -- Dvojnásobek pokryje milník radnice, vylepšení domu i případnou spotřebu.
      local wanted = materials(1)
      for name, amount in pairs(materials(2)) do wanted[name] = (wanted[name] or 0) + amount end
      for name, amount in pairs(wanted) do ctx.depot.insert({ name = name, count = 2 * amount }) end
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      H.check(remote.call(R, "house_level", ctx.house.unit_number) == 2, "dům se nevylepšil")
      H.check(ctx.house.graphics_variation == 2, "vzhled domu neodpovídá úrovni 2: " .. ctx.house.graphics_variation)
      H.check(house_label(ctx.house) == "2", "číslo nad vylepšeným domem: " .. tostring(house_label(ctx.house)))
      local s = H.status(ctx.town)
      H.check(s.beacon_modules == levels.bonus_modules(2, { 2 }), "bonus: " .. s.beacon_modules)
      H.check(s.houses_to_upgrade == 0, "zbývá vylepšit: " .. s.houses_to_upgrade)
    end } },
  },
  {
    name = "radnice má přednost před domy",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      remote.call(R, "set_level", ctx.town, 2)
      H.house(ctx, 11, 0)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
      local house = materials(1)
      for name, amount in pairs(materials(2)) do
        if house[name] then
          ctx.item = name
          ctx.depot.insert({ name = name, count = amount })
          break
        end
      end
      H.check(ctx.item, "milníky 1 a 2 nesdílí surovinu – test nemá co ověřit")
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      H.check((H.delivered(ctx.town, "item", ctx.item) or 0) > 0, "radnice nic nedostala")
      for _, req in ipairs(H.status(ctx.town).house_requirements) do
        if req.name == ctx.item then H.check(req.delivered == 0, "dům dostal surovinu dřív než radnice") end
      end
    end } },
  },
  {
    name = "dům nad úroveň města nejde vylepšit",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      H.house(ctx, 11, 0)
    end,
    steps = { { ticks = 1, run = function(ctx)
      local s = H.status(ctx.town)
      H.check(s.houses_to_upgrade == 0 and s.house_target_level == nil, "na úrovni 1 je co vylepšovat")
    end } },
  },
}
