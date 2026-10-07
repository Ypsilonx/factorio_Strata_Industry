--- Noční světla radnice a domů: skutečné světlo (rendering.draw_light) v místech oken, luceren, lamp a ohně,
--- která spočítá Blender ze stejného modelu jako sprity (shared/night_lights.lua). Světla jsou navázaná na entitu,
--- se zbouráním zmizí sama; ve storage.lights je jen evidence kvůli výměně při změně vzhledu.
local night = require("shared.night_lights")

local M = {}

--- Vzhled světla podle druhu: barva, dosah (scale světla utility/light_medium) a síla. Sloučená svítidla
--- (počet v night_lights) zvětší dosah s odmocninou počtu.
M.STYLE = {
  window = { color = { r = 1, g = 0.75, b = 0.45 }, scale = 0.7, intensity = 0.5 },
  lamp = { color = { r = 1, g = 0.9, b = 0.7 }, scale = 1.3, intensity = 0.85 },
  fire = { color = { r = 1, g = 0.55, b = 0.2 }, scale = 1.1, intensity = 0.8 },
}
--- Od jaké tmy světla svítí (0 = i ve dne, 1 = jen úplná tma).
M.MIN_DARKNESS = 0.3

--- Zničí vykreslená světla záznamu.
local function destroy(record)
  for _, object in ipairs(record.objects) do
    if object.valid then object.destroy() end
  end
end

--- Zajistí světla entity pro vzhled variant (kind = "hall" | "house"); stejný vzhled nepřekresluje.
--- @param entity LuaEntity
--- @param kind string
--- @param variant integer
function M.ensure(entity, kind, variant)
  local key = entity.unit_number
  local record = storage.lights[key]
  if record and record.variant == variant then return end
  if record then destroy(record) end
  local objects = {}
  for _, light in ipairs(night[kind][variant] or {}) do
    local x, y, style, count = light[1], light[2], M.STYLE[light[3]], light[4]
    objects[#objects + 1] = rendering.draw_light({
      sprite = "utility/light_medium", surface = entity.surface, target = { entity = entity, offset = { x, y } },
      scale = style.scale * math.sqrt(count), intensity = style.intensity, color = style.color,
      minimum_darkness = M.MIN_DARKNESS,
    })
  end
  storage.lights[key] = { variant = variant, objects = objects }
end

--- Zapomene světla odstraněné entity (vykreslení zmizelo s entitou).
--- @param key integer unit_number
function M.forget(key)
  local record = storage.lights[key]
  if record then destroy(record) end
  storage.lights[key] = nil
end

--- Zničí všechna světla (po změně verze se pozice z Blenderu mohly změnit – volající je znovu zajistí).
function M.reset()
  for _, record in pairs(storage.lights) do destroy(record) end
  storage.lights = {}
end

--- Počet světel entity (testy).
--- @param key integer unit_number
--- @return integer
function M.count(key)
  local record = storage.lights[key]
  return record and #record.objects or 0
end

return M
