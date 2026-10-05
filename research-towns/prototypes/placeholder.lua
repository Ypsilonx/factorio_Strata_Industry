--- Dočasná grafika z vanilla sprajtů: zvětšení a obarvení (finální grafika z Blenderu je plán 3).
local M = {}

--- Hluboká kopie tabulky (bez závislosti na util, kvůli testům mimo hru).
local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, inner in pairs(value) do result[key] = copy(inner) end
  return result
end

--- Vrátí kopii animace/spritu zvětšenou faktorem; tint se nepoužije na stíny a světla.
--- @param source table Sprite/Animation (i s `layers`)
--- @param factor number
--- @param tint table|nil
function M.scaled(source, factor, tint)
  local result = copy(source)
  local function visit(node)
    if node.layers then
      for _, layer in ipairs(node.layers) do visit(layer) end
      return
    end
    node.scale = (node.scale or 1) * factor
    if node.shift then node.shift = { node.shift[1] * factor, node.shift[2] * factor } end
    if tint and not node.draw_as_shadow and not node.draw_as_light then node.tint = tint end
  end
  visit(result)
  return result
end

return M
