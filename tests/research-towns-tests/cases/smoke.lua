--- Vzor testu: setup postaví scénu ve výřezu ctx.origin, steps se spustí po zadaném počtu ticků.
--- Volitelně `requires = "space-age"` – bez daného modu se test přeskočí.
return {
  {
    name = "mod se načte a povrch existuje",
    setup = function(ctx) ctx.chest = ctx.surface.create_entity({ name = "iron-chest", position = { ctx.origin.x + 0.5, ctx.origin.y + 0.5 }, force = "player" }) end,
    steps = { { ticks = 10, run = function(ctx)
      if not ctx.chest.valid then error("bedna zmizela") end
    end } },
  },
  {
    name = "testovací povrch města negeneruje (lab dlaždice)",
    steps = { { ticks = 1, run = function(ctx)
      local sites = ctx.surface.count_entities_filtered({ name = "rt-town-site" })
      if sites > 0 then error("značek na testovacím povrchu: " .. sites) end
    end } },
  },
}
