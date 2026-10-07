--- Integrační testy specializací: každé město jinou, bonus k produktivitě receptů síly podle úrovně partnerských
--- měst, klesající přínos stejné specializace, ruina bonus ruší, přepočet výzkumů bonus nesmaže.
local spec = require("__research-towns__/shared/specialization")
local H = require("helpers")
local R = H.REMOTE

--- Specializace ve hře (mod-data).
local function list()
  return H.levels_data().specializations
end

--- Specializace podle jména.
local function entry(name)
  for _, e in ipairs(list()) do
    if e.name == name then return e end
  end
  error("neznámá specializace " .. tostring(name))
end

--- Bonus jednoho města úrovně level, jak ho hra skutečně použije (celá procenta).
local function expect(level, multiplier)
  return spec.total({ spec.town_bonus(level, multiplier) }, multiplier)
end

--- Vlastní síla testu (bonus je per síla, ostatní testy mění města síly „player“).
local function own_force(ctx, suffix)
  ctx.force = game.create_force("rt-spec-" .. suffix)
  return ctx.force
end

--- Partnerské město vlastní síly na posunu (dx, dy) od počátku testu.
local function town_at(ctx, dx, dy)
  local id = remote.call(R, "create_town", ctx.surface.name, { x = ctx.origin.x + dx + 0.5, y = ctx.origin.y + dy + 0.5 },
    ctx.force.name)
  H.check(id, "radnici nelze postavit")
  return id
end

--- Bonus k produktivitě prvního receptu specializace města u síly testu.
local function bonus(ctx, town)
  local recipe = entry(H.status(town).specialization).recipes[1]
  return ctx.force.recipes[recipe].productivity_bonus
end

return {
  {
    name = "specializace: ve hře aspoň pět materiálů, sousední města mají různé",
    setup = function(ctx)
      own_force(ctx, "distinct")
      ctx.a = town_at(ctx, 0, 0)
      ctx.b = town_at(ctx, 20, 0)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(#list() >= 5, "málo specializací: " .. #list())
      local a, b = H.status(ctx.a).specialization, H.status(ctx.b).specialization
      H.check(a and b, "město nemá specializaci")
      H.check(a ~= b, "dvě po sobě založená města mají stejnou specializaci " .. a)
    end } },
  },
  {
    name = "specializace: partner dává bonus podle úrovně, ruina ho ruší, přepočet výzkumů ho nesmaže",
    setup = function(ctx)
      own_force(ctx, "bonus")
      ctx.town = town_at(ctx, 0, 0)
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        remote.call(R, "set_level", ctx.town, 3)
        H.check(math.abs(bonus(ctx, ctx.town) - expect(3)) < 1e-4, "bonus úrovně 3: " .. bonus(ctx, ctx.town))
        ctx.force.reset_technology_effects()
        H.check(math.abs(bonus(ctx, ctx.town) - expect(3)) < 1e-4, "bonus po přepočtu výzkumů zmizel")
        -- Mapové nastavení „Síla specializací“ se projeví hned (vrátit ve stejném ticku – ostatní testy počítají s 1).
        remote.call(R, "set_specialization_multiplier", 0.5)
        local half = bonus(ctx, ctx.town)
        remote.call(R, "set_specialization_multiplier", 1)
        H.check(math.abs(half - expect(3, 0.5)) < 1e-4, "násobič 0,5 se neprojevil: " .. half)
        H.check(math.abs(bonus(ctx, ctx.town) - expect(3)) < 1e-4, "návrat násobiče na 1")
        H.hall(ctx.town).die()
      end },
      { ticks = 1, run = function(ctx)
        H.check(H.status(ctx.town).state == "ruin", "radnice nezanikla v ruinu")
        H.check(math.abs(bonus(ctx, ctx.town)) < 1e-4, "ruina dává bonus: " .. bonus(ctx, ctx.town))
      end },
    },
  },
  {
    name = "specializace: druhé město stejné specializace přidá jen díl",
    setup = function(ctx)
      own_force(ctx, "decay")
      ctx.a = town_at(ctx, 0, 0)
      ctx.b = town_at(ctx, 20, 0)
    end,
    steps = { { ticks = 1, run = function(ctx)
      -- Druhému městu vnutíme stejnou specializaci jako prvnímu (v normální hře by dostalo jinou).
      remote.call(R, "set_specialization", ctx.b, H.status(ctx.a).specialization)
      remote.call(R, "set_level", ctx.a, 5)
      remote.call(R, "set_level", ctx.b, 5)
      local expected = spec.total({ spec.town_bonus(5), spec.town_bonus(5) })
      H.check(expected < 2 * expect(5), "klesající přínos se neuplatnil")
      H.check(math.abs(bonus(ctx, ctx.a) - expected) < 1e-4, "bonus dvou měst " .. bonus(ctx, ctx.a) .. " ≠ " .. expected)
    end } },
  },
}
