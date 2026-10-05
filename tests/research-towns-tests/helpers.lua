--- Pomocné funkce pro integrační testy: stavění entit, napájení, volání remote rozhraní modu.
local H = {}

--- Jméno remote rozhraní modu.
H.REMOTE = "research-towns"

--- Selže s chybou, pokud podmínka neplatí.
--- @param condition any
--- @param message string
function H.check(condition, message)
  if not condition then error(message, 2) end
end

--- Postaví entitu na dlaždici (dx, dy) relativně k počátku testu; vyvolá script_raised_built.
--- @return LuaEntity
function H.place(ctx, name, dx, dy, extra)
  local spec = {
    name = name,
    position = { ctx.origin.x + dx + 0.5, ctx.origin.y + dy + 0.5 },
    force = "player",
    raise_built = true,
  }
  for key, value in pairs(extra or {}) do spec[key] = value end
  local entity = ctx.surface.create_entity(spec)
  if not entity then error("nelze postavit " .. name, 2) end
  return entity
end

--- Napájí okolí bodu (dx, dy): neomezený zdroj a rozvodna (pokrývá ±9 dlaždic).
--- @return LuaEntity rozvodna (jejím zbouráním test odpojí proud)
function H.power(ctx, dx, dy)
  local source = H.place(ctx, "electric-energy-interface", dx - 4, dy)
  source.power_production = 1e9
  source.electric_buffer_size = 1e10
  return H.place(ctx, "substation", dx, dy)
end

return H
