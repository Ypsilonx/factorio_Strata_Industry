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


--- Založí město s radnicí uprostřed výřezu testu.
--- @return integer id města
function H.town(ctx)
  local id = remote.call(H.REMOTE, "create_town", ctx.surface.name, { x = ctx.origin.x + 0.5, y = ctx.origin.y + 0.5 })
  if not id then error("radnici nelze postavit", 2) end
  return id
end

--- Stav města z remote rozhraní.
function H.status(id)
  return remote.call(H.REMOTE, "town_status", id)
end

--- Entita radnice města.
function H.hall(id)
  return game.get_entity_by_unit_number(H.status(id).hall)
end

--- Postaví dům (3×3) na (dx, dy) od počátku; radnice zabírá -7..+8, dům na dx=11 má mezeru 2.
function H.house(ctx, dx, dy)
  return H.place(ctx, "rt-house", dx, dy)
end

return H
