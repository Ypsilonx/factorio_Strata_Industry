--- Obecné kontroly platné s jakýmkoli overhaul modem (pouští je i `tools/run-tests.sh mods …`).
local levels = require("__research-towns__/shared/levels")
local H = require("helpers")

--- Množina z pole.
local function set(list)
  local result = {}
  for _, value in ipairs(list) do result[value] = true end
  return result
end

return {
  { name = "radnice 1–5 existují a vědy s úrovní přibývají", steps = { { ticks = 1, run = function()
    local previous = 0
    for level = 1, levels.MAX_LEVEL do
      local proto = prototypes.entity[levels.hall_name(level)]
      H.check(proto and proto.type == "lab", "chybí radnice " .. level)
      H.check(#proto.lab_inputs >= previous, "úroveň " .. level .. " přijímá méně věd než předchozí")
      previous = #proto.lab_inputs
    end
  end } } },
  { name = "nejvyšší radnice umí všechny vědy výzkumů", steps = { { ticks = 1, run = function()
    local top = set(prototypes.entity[levels.hall_name(levels.MAX_LEVEL)].lab_inputs)
    for name, tech in pairs(prototypes.technology) do
      if tech.enabled and not tech.hidden then
        for _, ingredient in pairs(tech.research_unit_ingredients) do
          H.check(top[ingredient.name], "věda " .. ingredient.name .. " výzkumu " .. name .. " není v žádné úrovni")
        end
      end
    end
  end } } },
  { name = "žádný výzkum neodemyká laboratoř", steps = { { ticks = 1, run = function()
    for name, tech in pairs(prototypes.technology) do
      for _, effect in pairs(tech.effects) do
        if effect.type == "unlock-recipe" then
          for _, product in pairs(prototypes.recipe[effect.recipe].products) do
            local item = prototypes.item[product.name]
            local result = item and item.place_result
            H.check(not (result and result.type == "lab"), "výzkum " .. name .. " odemyká laboratoř " .. product.name)
          end
        end
      end
    end
  end } } },
  { name = "suroviny milníků existují", steps = { { ticks = 1, run = function()
    local data = prototypes.mod_data["rt-levels"].data
    for level = 1, levels.MAX_LEVEL - 1 do
      local upgrade = data.upgrade[tostring(level)]
      H.check(upgrade and #upgrade > 0, "úroveň " .. level .. " nemá milník")
      for _, req in ipairs(upgrade) do
        local found = req.type == "fluid" and prototypes.fluid[req.name] or prototypes.item[req.name]
        H.check(found, "surovina " .. req.name .. " neexistuje")
      end
    end
  end } } },
}
