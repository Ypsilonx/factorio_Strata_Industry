--- Integrační testy městské tabule.
local H = require("helpers")
local R = H.REMOTE

--- Signály tabule jako mapa jméno → hodnota.
local function signals(entity)
  local result = {}
  local behavior = entity.get_control_behavior()
  local section = behavior and behavior.get_section(1)
  for _, filter in pairs(section and section.filters or {}) do
    if filter.value then result[filter.value.name] = filter.min end
  end
  return result
end

return {
  {
    name = "tabule v režimu Radnice posílá milník a příkon",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.board = H.place(ctx, "rt-town-board", 2, 9)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "board_mode", ctx.board.unit_number) == "hall", "výchozí režim")
      H.process(ctx.town)
      local got = signals(ctx.board)
      local science = H.levels_data().upgrade["1"][1]
      H.check(got[science.name] == science.amount, "věda milníku: " .. serpent.line(got))
      H.check(got["rt-signal-power-mw"] == 1, "příkon: " .. serpent.line(got))
    end } },
  },
  {
    name = "režimy Dům a Spotřeba",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      remote.call(R, "set_level", ctx.town, 2)
      H.house(ctx, 11, 0)
      ctx.board = H.place(ctx, "rt-town-board", 2, 9)
    end,
    steps = { { ticks = 1, run = function(ctx)
      remote.call(R, "set_board_mode", ctx.board.unit_number, "house")
      H.process(ctx.town)
      H.check(signals(ctx.board)["rt-signal-houses"] == 1, "domy: " .. serpent.line(signals(ctx.board)))
      remote.call(R, "set_board_mode", ctx.board.unit_number, "upkeep")
      H.process(ctx.town)
      local first = H.status(ctx.town).upkeep[1]
      H.check(signals(ctx.board)[first.name] == math.ceil(first.per_minute - 1e-6), "spotřeba: " .. serpent.line(signals(ctx.board)))
    end } },
  },
  {
    name = "tabule bez města nic neposílá",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.board = H.place(ctx, "rt-town-board", 0, 30)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      H.check(next(signals(ctx.board)) == nil, "signály bez města: " .. serpent.line(signals(ctx.board)))
    end } },
  },
  {
    name = "režim z plánu (tag) se převezme",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      local ghost = ctx.surface.create_entity({ name = "entity-ghost", inner_name = "rt-town-board", force = "player",
        position = { ctx.origin.x + 2.5, ctx.origin.y + 9.5 }, tags = { rt_board_mode = "upkeep" } })
      local _, board = ghost.revive({ raise_revive = true })
      ctx.board = board
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "board_mode", ctx.board.unit_number) == "upkeep", "režim z tagu")
    end } },
  },
  {
    name = "tabule posílá i kapaliny milníku",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      for level = 1, H.level_count() - 1 do
        for _, req in ipairs(H.levels_data().upgrade[tostring(level)]) do
          if req.type == "fluid" and not ctx.fluid then
            ctx.fluid = req
            remote.call(R, "set_level", ctx.town, level)
          end
        end
      end
      H.check(ctx.fluid, "žádný milník nechce kapalinu")
      ctx.board = H.place(ctx, "rt-town-board", 2, 9)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      H.check(signals(ctx.board)[ctx.fluid.name] == ctx.fluid.amount, "kapalina: " .. serpent.line(signals(ctx.board)))
    end } },
  },
}
