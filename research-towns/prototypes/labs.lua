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

--- Recepty předmětů laboratoří: pro každý předmět první neskrytý recept (podle jména), který ho vyrábí.
--- @return table<string, {ingredients: table, per: number}> suroviny receptu a kolik kusů předmětu dá
function M.lab_parts(raw, items)
  local names = {}
  for name in pairs(raw.recipe) do names[#names + 1] = name end
  table.sort(names)
  local parts = {}
  for _, name in ipairs(names) do
    local recipe = raw.recipe[name]
    if not recipe.hidden then
      for _, product in ipairs(recipe.results or {}) do
        local amount = product.amount or 1
        if items[product.name] and not parts[product.name] and amount > 0 then
          parts[product.name] = { ingredients = recipe.ingredients or {}, per = amount }
        end
      end
    end
  end
  return parts
end

--- Mělká kopie tabulky suroviny.
local function copy(ingredient)
  local result = {}
  for key, value in pairs(ingredient) do result[key] = value end
  return result
end

--- Nový seznam surovin, ve kterém je každý předmět laboratoře nahrazený surovinami jejího receptu
--- (rekurzivně – laboratoř může být z jiné laboratoře); stejné suroviny se sloučí, kusy se zaokrouhlí nahoru.
--- @param visiting table<string, true> právě rozkládané laboratoře (ochrana proti cyklu receptů)
local function expand(ingredients, parts, visiting)
  local result, index = {}, {}
  local function add(ingredient, amount)
    local key = (ingredient.type or "item") .. "/" .. ingredient.name
    if index[key] then
      index[key].amount = index[key].amount + amount
    else
      local entry = copy(ingredient)
      entry.amount = amount
      result[#result + 1] = entry
      index[key] = entry
    end
  end
  for _, ingredient in ipairs(ingredients) do
    local part = ingredient.type ~= "fluid" and parts[ingredient.name]
    if part and not visiting[ingredient.name] then
      visiting[ingredient.name] = true
      for _, sub in ipairs(expand(part.ingredients, parts, visiting)) do
        local amount = sub.amount * ingredient.amount / part.per
        add(sub, sub.type == "fluid" and amount or math.ceil(amount))
      end
      visiting[ingredient.name] = nil
    else
      add(ingredient, ingredient.amount)
    end
  end
  return result
end

--- Skryje recepty laboratoří, odebere je z výzkumů a spouštěče „vyrob/postav laboratoř“ přesměruje
--- na vyrobení náhradního předmětu (jinak by např. vanilla výzkum červené vědy nešel spustit).
--- Cizí recepty, které mají laboratoř jako surovinu (např. skleník ze simply-greenhouse), dostanou místo ní
--- suroviny receptu laboratoře – jinak by nešly vyrobit.
--- @return table<string, true> předměty laboratoří
--- @return string[] jména receptů s rozloženou laboratoří (seřazená)
function M.remove(raw, replacement_item)
  local items = M.lab_items(raw)
  local parts = M.lab_parts(raw, items)
  local expanded = {}
  for name, recipe in pairs(raw.recipe) do
    local makes_lab = false
    for _, product in ipairs(recipe.results or {}) do makes_lab = makes_lab or items[product.name] ~= nil end
    local uses_lab = false
    for _, ingredient in ipairs(recipe.ingredients or {}) do
      uses_lab = uses_lab or (ingredient.type ~= "fluid" and parts[ingredient.name] ~= nil)
    end
    -- Skryté recepty (recyklace) a recepty laboratoří samotných se nerozkládají.
    if uses_lab and not makes_lab and not recipe.hidden then
      recipe.ingredients = expand(recipe.ingredients, parts, {})
      expanded[#expanded + 1] = name
    end
  end
  table.sort(expanded)
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
  return items, expanded
end

return M
