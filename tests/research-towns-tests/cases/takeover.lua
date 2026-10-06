--- Integrační testy neobjeveného města, objevení s darem a převzetí po dodání daru.
local H = require("helpers")
local R = H.REMOTE

--- Vlastní síla testu: dar se počítá z nejvyšší úrovně měst síly, jiné testy mění úrovně měst síly „player“.
local function own_force(ctx, suffix)
  ctx.force = game.create_force("rt-gift-" .. suffix)
  return ctx.force.name
end

--- Neutrální radnice uprostřed výřezu testu.
local function wild(ctx)
  ctx.town = remote.call(R, "create_wild_town", ctx.surface.name, { x = ctx.origin.x + 0.5, y = ctx.origin.y + 0.5 })
  H.check(ctx.town, "neutrální radnici nelze postavit")
end

--- Signály tabule jako mapa jméno → hodnota.
local function signals(entity)
  local result = {}
  local section = entity.get_control_behavior().get_section(1)
  for _, filter in pairs(section and section.filters or {}) do
    if filter.value then result[filter.value.name] = filter.min end
  end
  return result
end

return {
  {
    name = "neobjevené město: nezničitelné, nezkoumá, nepřipojí překladiště ani domy",
    setup = function(ctx)
      wild(ctx)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
      ctx.house = H.house(ctx, 11, 0)
    end,
    steps = { { ticks = 1, run = function(ctx)
      local s = H.status(ctx.town)
      H.check(s.state == "wild", "stav " .. tostring(s.state))
      local hall = H.hall(ctx.town)
      H.check(hall.force.name == "neutral" and not hall.destructible, "neutrální a nezničitelná")
      H.check(hall.disabled_by_script, "neobjevená radnice zkoumá")
      H.check(remote.call(R, "town_of", ctx.depot.unit_number) == nil, "překladiště se připojilo")
      H.check(remote.call(R, "depth_of", ctx.house.unit_number) == nil, "dům se připojil")
    end } },
  },
  {
    name = "objevení stanoví dar z milníku 1, připojí překladiště a tabuli, rozvodnu ne",
    setup = function(ctx)
      local force = own_force(ctx, "discover")
      wild(ctx)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10, { force = force })
      ctx.power = H.place(ctx, "rt-power-depot", -4, 10, { force = force })
      ctx.board = H.place(ctx, "rt-town-board", 2, 9, { force = force })
    end,
    steps = { { ticks = 1, run = function(ctx)
      remote.call(R, "discover", ctx.town, ctx.force.name)
      H.process(ctx.town)
      local s = H.status(ctx.town)
      H.check(s.state == "discovered", "stav " .. tostring(s.state))
      local expected = {}
      for _, req in ipairs(H.levels_data().upgrade["1"]) do
        if not req.science then expected[req.name] = math.ceil(req.amount * 0.25 - 1e-9) end
      end
      H.check(#s.requirements > 0, "prázdný dar")
      for _, req in ipairs(s.requirements) do
        H.check(expected[req.name] == req.amount, "dar " .. req.name .. ": " .. req.amount)
      end
      H.check(remote.call(R, "town_of", ctx.depot.unit_number) == ctx.town, "překladiště nepřipojené")
      H.check(remote.call(R, "town_of", ctx.power.unit_number) == nil, "rozvodna připojená k cizímu městu")
      local first = s.requirements[1]
      H.check(signals(ctx.board)[first.name] == first.amount, "tabule: " .. serpent.line(signals(ctx.board)))
    end } },
  },
  {
    name = "dodaný dar převezme město pro sílu překladiště a dům se pak připojí",
    setup = function(ctx)
      local force = own_force(ctx, "takeover")
      wild(ctx)
      remote.call(R, "discover", ctx.town, force)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10, { force = force })
      for _, req in ipairs(H.status(ctx.town).requirements) do
        H.check(req.type == "item", "dar z milníku 1 má jen předměty")
        ctx.depot.insert({ name = req.name, count = req.amount })
      end
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        H.process(ctx.town)
        local s = H.status(ctx.town)
        H.check(s.state == "partner", "stav " .. tostring(s.state))
        local hall = H.hall(ctx.town)
        H.check(hall.force == ctx.force, "síla " .. hall.force.name)
        H.check(hall.destructible, "radnice zůstala nezničitelná")
        H.check(s.level == 1, "úroveň " .. s.level)
        ctx.house = H.place(ctx, "rt-house", 11, 0, { force = ctx.force.name })
      end },
      { ticks = 1, run = function(ctx)
        H.check(remote.call(R, "depth_of", ctx.house.unit_number) == 1, "dům se nepřipojil")
      end },
    },
  },
  {
    name = "dar objeveného města se nemění povýšením jiného města",
    setup = function(ctx)
      local force = own_force(ctx, "fixed")
      wild(ctx)
      remote.call(R, "discover", ctx.town, force)
      ctx.before = serpent.line(H.status(ctx.town).requirements)
      local other = remote.call(R, "create_town", ctx.surface.name, { x = ctx.origin.x + 30.5, y = ctx.origin.y + 30.5 }, force)
      remote.call(R, "set_level", other, 4)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(serpent.line(H.status(ctx.town).requirements) == ctx.before, "dar se změnil")
    end } },
  },
}
