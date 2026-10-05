--- Čistá logika nad data.raw: odstranění všech laboratoří (vanilla i z modů) – výzkum přebírají radnice.
local M = {}

--- Jméno ze specifikace předmětu/entity (řetězec nebo { name = … }).
local function id(value)
  if type(value) == "table" then return value.name end
  return value
end

--- Množina předmětů, ze kterých se staví laboratoře.
--- @return table<string, true>
function M.lab_items(raw)
  local items = {}
  for _, lab in pairs(raw.lab or {}) do
    local minable = lab.minable
    if minable then
      if minable.result then items[minable.result] = true end
      for _, product in ipairs(minable.results or {}) do items[product.name] = true end
    end
  end
  return items
end

--- Skryje recepty laboratoří, odebere je z výzkumů a spouštěče „vyrob/postav laboratoř“ přesměruje
--- na vyrobení náhradního předmětu (jinak by např. vanilla výzkum červené vědy nešel spustit).
--- @return table<string, true> předměty laboratoří
function M.remove(raw, replacement_item)
  local items = M.lab_items(raw)
  local hidden = {}
  for name, recipe in pairs(raw.recipe) do
    for _, product in ipairs(recipe.results or {}) do
      if items[product.name] then
        recipe.hidden = true
        recipe.enabled = false
        hidden[name] = true
      end
    end
  end
  for _, tech in pairs(raw.technology) do
    local effects = tech.effects
    if effects then
      for i = #effects, 1, -1 do
        if effects[i].type == "unlock-recipe" and hidden[effects[i].recipe] then table.remove(effects, i) end
      end
    end
    local trigger = tech.research_trigger
    if trigger and ((trigger.type == "craft-item" and items[id(trigger.item)])
        or (trigger.type == "build-entity" and raw.lab[id(trigger.entity)])) then
      tech.research_trigger = { type = "craft-item", item = replacement_item }
    end
  end
  return items
end

return M
