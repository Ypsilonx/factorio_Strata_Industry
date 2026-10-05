---@diagnostic disable: undefined-global
--- Jména GUI prvků nesmí kolidovat s vlastnostmi/metodami LuaGuiElement (např. "state") – hra by spadla.
--- Headless testy GUI netvoří (nejsou hráči), proto statická kontrola proti API dokumentaci hry.
local A = require("assert")

--- Cesta k API dokumentaci; jiná instalace hry → proměnná prostředí FACTORIO_API_JSON.
local API_JSON = os.getenv("FACTORIO_API_JSON") or "C:/STEAM/steamapps/common/Factorio/doc-html/runtime-api.json"

--- Načte celý soubor jako text (nebo nil).
local function read(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local text = file:read("a")
  file:close()
  return text
end

--- Množina jmen z definice třídy LuaGuiElement.
local function reserved_names(api)
  local start = api:find('{"name":"LuaGuiElement","order"', 1, true)
  local first = api:find('"abstract":', start, true)
  local next_class = api:find('"abstract":', first + 1, true)
  local set = {}
  for name in api:sub(start, next_class):gmatch('"name":"([%w_]+)"') do set[name] = true end
  return set
end

return {
  { "jména prvků v gui.lua nekolidují s LuaGuiElement", function()
    local api = read(API_JSON)
    if not api then
      print("SKIP test_gui_names: chybí " .. API_JSON)
      return
    end
    local reserved = reserved_names(api)
    A.truthy(reserved["state"] and reserved["caption"], "seznam vlastností LuaGuiElement načten")
    local source = read("research-towns/scripts/gui.lua")
    A.truthy(source, "gui.lua existuje")
    local count = 0
    for name in source:gmatch('"(rt_[%w_]+)"') do
      count = count + 1
      A.eq(reserved[name], nil, "jméno prvku '" .. name .. "' koliduje s LuaGuiElement")
    end
    A.truthy(count > 0, "nalezena jména prvků")
  end },
}
