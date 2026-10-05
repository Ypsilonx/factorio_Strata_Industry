--- Integrační testy překladišť: přiřazení k městu, výběr surovin, kapaliny, elektřina.
local H = require("helpers")
local R = H.REMOTE

--- Najde v milníku města první požadavek daného typu.
local function first_requirement(id, kind)
  for _, req in ipairs(H.status(id).requirements) do
    if req.type == kind then return req end
  end
  error("milník nemá požadavek typu " .. kind)
end

return {
  {
    name = "překladiště odebere jen potřebné a jen do potřeby",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
      ctx.req = first_requirement(ctx.town, "item")
      ctx.depot.insert({ name = ctx.req.name, count = ctx.req.amount + 50 })
      ctx.depot.insert({ name = "iron-ore", count = 30 })
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "town_of", ctx.depot.unit_number) == ctx.town, "překladiště nepřiřazeno")
      H.process(ctx.town)
      H.check(H.delivered(ctx.town, "item", ctx.req.name) == ctx.req.amount, "dodáno ≠ potřeba")
      H.check(ctx.depot.get_item_count(ctx.req.name) == 50, "přebytek nezůstal v překladišti")
      H.check(ctx.depot.get_item_count("iron-ore") == 30, "nepotřebná ruda zmizela")
    end } },
  },
  {
    name = "překladiště mimo dosah nepatří k městu",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 14)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "town_of", ctx.depot.unit_number) == nil, "vzdálené překladiště přiřazeno")
    end } },
  },
  {
    name = "překladiště u neaktivního domu nepatří k městu",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      for _, dx in ipairs({ 11, 16, 21, 26, 31, 36 }) do H.house(ctx, dx, 0) end
      ctx.depot = H.place(ctx, "rt-goods-depot", 39, 0)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "town_of", ctx.depot.unit_number) == nil, "překladiště u 6. domu přiřazeno")
    end } },
  },
  {
    name = "překladiště kapalin dodá kapalinu milníku",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      remote.call(R, "set_level", ctx.town, 2)
      ctx.depot = H.place(ctx, "rt-fluid-depot", 4, 11)
      ctx.req = first_requirement(ctx.town, "fluid")
      ctx.depot.insert_fluid({ name = ctx.req.name, amount = 1000 })
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      local delivered = H.delivered(ctx.town, "fluid", ctx.req.name)
      H.check(math.abs(delivered - 1000) < 0.01, "dodaná kapalina: " .. tostring(delivered))
    end } },
  },
  {
    name = "při přetížené síti město nebere elektřinu ostatním spotřebičům",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      H.place(ctx, "rt-power-depot", -4, 10)
      H.power(ctx, -10, 13)
      local usage = 1e6 / 60
      -- Konkurenční spotřebič stejné priority (rozvodna mimo dosah města) chce 3× příkon města.
      local other = H.place(ctx, "rt-power-depot", -16, 18)
      other.power_usage = 3 * usage
      other.electric_buffer_size = 6 * usage
      -- Zdroj pokryje jen 60 % celkové poptávky.
      local source = ctx.surface.find_entity("electric-energy-interface", { ctx.origin.x - 13.5, ctx.origin.y + 13.5 })
      source.power_production = 0.6 * 4 * usage
      source.electric_buffer_size = 0.6 * 4 * usage
    end,
    steps = { { ticks = 180, run = function(ctx)
      H.process(ctx.town)
      H.check(not H.status(ctx.town).power_ok, "elektřina hlášena jako pokrytá při přetížené síti")
    end } },
  },
  {
    name = "bez elektřiny radnice nezkoumá",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      H.place(ctx, "rt-power-depot", -4, 10)
      ctx.substation = H.power(ctx, -10, 13)
    end,
    steps = {
      { ticks = 30, run = function(ctx)
        H.process(ctx.town)
        H.check(H.status(ctx.town).power_ok, "elektřina nepokryta")
        H.check(not H.hall(ctx.town).disabled_by_script, "radnice vypnutá i s elektřinou")
        ctx.substation.destroy()
      end },
      { ticks = 120, run = function(ctx)
        H.process(ctx.town)
        H.check(not H.status(ctx.town).power_ok, "elektřina pokryta bez rozvodny")
        H.check(H.hall(ctx.town).disabled_by_script, "radnice zkoumá bez elektřiny")
      end },
    },
  },
}
