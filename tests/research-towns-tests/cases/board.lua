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
    name = "postup k další úrovni v panelu i na tabuli",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      H.house(ctx, 11, 0)
      ctx.board = H.place(ctx, "rt-town-board", 2, 9)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      local s = H.status(ctx.town)
      local parts = #H.levels_data().upgrade["1"] + 1
      local expected = (1 / s.house_limit) / parts
      H.check(math.abs(s.level_progress - expected) < 1e-9, "postup: " .. tostring(s.level_progress))
      local got = signals(ctx.board)
      H.check(got["rt-signal-level-progress"] == math.floor(expected * 100 + 1e-3), "signál: " .. serpent.line(got))
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
      H.check(signals(ctx.board)[first.name] == math.ceil(first.buffer - 1e-6), "spotřeba: " .. serpent.line(signals(ctx.board)))
      H.check(first.buffer == first.per_minute * 5, "zásoba na 5 minut: " .. serpent.line(first))
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
  {
    name = "tabule ve skupině nebo s vypnutou sekcí nepřepíše skupinu a zapne se",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.board = H.place(ctx, "rt-town-board", 2, 9)
      ctx.other = H.place(ctx, "constant-combinator", 0, 30)
      local group = "rt-test-group-" .. ctx.origin.x .. "-" .. ctx.origin.y
      local other = ctx.other.get_or_create_control_behavior().get_section(1)
        or ctx.other.get_control_behavior().add_section()
      other.group = group
      other.filters = { { value = { type = "item", name = "wood", quality = "normal", comparator = "=" }, min = 7 } }
      local section = ctx.board.get_or_create_control_behavior().get_section(1)
        or ctx.board.get_control_behavior().add_section()
      section.group = group
      section.active = false
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      local section = ctx.board.get_control_behavior().get_section(1)
      H.check(section.group == "" and section.active, "sekce tabule: " .. section.group .. " " .. tostring(section.active))
      H.check(signals(ctx.board)["rt-signal-power-mw"] == 1, "signály: " .. serpent.line(signals(ctx.board)))
      H.check(signals(ctx.other).wood == 7, "skupina přepsaná: " .. serpent.line(signals(ctx.other)))
    end } },
  },
  {
    name = "neplatný režim z remote i z plánu se odmítne",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      local ghost = ctx.surface.create_entity({ name = "entity-ghost", inner_name = "rt-town-board", force = "player",
        position = { ctx.origin.x + 2.5, ctx.origin.y + 9.5 }, tags = { rt_board_mode = "bogus" } })
      local _, board = ghost.revive({ raise_revive = true })
      ctx.board = board
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "board_mode", ctx.board.unit_number) == "hall", "neplatný tag → Radnice")
      local ok = pcall(remote.call, R, "set_board_mode", ctx.board.unit_number, "bogus")
      H.check(not ok, "remote přijal neplatný režim")
      H.check(remote.call(R, "board_mode", ctx.board.unit_number) == "hall", "režim se změnil")
      remote.call(R, "set_board_mode", ctx.board.unit_number, "upkeep")
      H.check(signals(ctx.board)["rt-signal-power-mw"] == 1, "signály se nepřepsaly hned")
    end } },
  },
}
