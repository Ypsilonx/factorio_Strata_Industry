--- Obecné kontroly platné s jakýmkoli overhaul modem (pouští je i `tools/run-tests.sh mods …`).
local levels = require("__research-towns__/shared/levels")
local worldgen = require("__research-towns__/shared/worldgen")
local H = require("helpers")

--- Množina z pole.
local function set(list)
  local result = {}
  for _, value in ipairs(list) do result[value] = true end
  return result
end

--- Vědy, které přijímá radnice dané vědecké úrovně.
local function inputs(tier)
  return prototypes.entity[levels.hall_name(tier)].lab_inputs
end

--- Existuje předmět/kapalina požadavku?
local function exists(req)
  return (req.type == "fluid" and prototypes.fluid[req.name] or prototypes.item[req.name]) ~= nil
end

return {
  { name = "radnice všech úrovní existují a každá další přidá právě jednu vědu", steps = { { ticks = 1, run = function()
    local count = H.level_count()
    H.check(count >= 2, "jen " .. count .. " úroveň")
    local previous
    for tier = 1, count do
      local proto = prototypes.entity[levels.hall_name(tier)]
      H.check(proto and proto.type == "lab", "chybí radnice " .. tier)
      if previous then H.check(#proto.lab_inputs == previous + 1, "úroveň " .. tier .. " nepřidala jednu vědu") end
      previous = #proto.lab_inputs
    end
    H.check(prototypes.entity[levels.hall_name(count + 1)] == nil, "radnice nad počtem věd")
  end } } },
  { name = "úroveň 1 přijímá nejvýš polovinu věd nejvyšší úrovně", steps = { { ticks = 1, run = function()
    -- Hlídá pořadí final-fixes: když pásma vzniknou před dopočtem stromu overhaulu, skončí skoro vše na úrovni 1.
    local first, top = #inputs(1), #inputs(H.level_count())
    H.check(first * 2 <= top, "úroveň 1: " .. first .. " věd, nejvyšší: " .. top)
  end } } },
  { name = "nejvyšší radnice umí všechny vědy výzkumů", steps = { { ticks = 1, run = function()
    local top = set(inputs(H.level_count()))
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
  { name = "milník chce vědu další úrovně a existující suroviny", steps = { { ticks = 1, run = function()
    local data, count = H.levels_data(), H.level_count()
    for level = 1, count - 1 do
      local upgrade = data.upgrade[tostring(level)]
      H.check(upgrade and #upgrade > 1, "úroveň " .. level .. " nemá milník se surovinami")
      local here, next_level, sciences = set(inputs(level)), set(inputs(level + 1)), 0
      for _, req in ipairs(upgrade) do
        H.check(exists(req), "surovina " .. req.name .. " neexistuje")
        if req.science then
          sciences = sciences + 1
          H.check(next_level[req.name] and not here[req.name], "věda milníku " .. level .. ": " .. req.name)
        end
      end
      H.check(sciences == 1, "milník " .. level .. " má " .. sciences .. " věd")
    end
    H.check(#data.infinite > 0, "nekonečný milník je prázdný")
    for _, req in ipairs(data.infinite) do H.check(exists(req), "surovina " .. req.name .. " neexistuje") end
  end } } },
  { name = "generátor mapy: posuvník Města a značka místa města na Nauvisu", steps = { { ticks = 1, run = function()
    H.check(prototypes.autoplace_control[worldgen.CONTROL], "chybí autoplace-control " .. worldgen.CONTROL)
    local site = prototypes.entity[worldgen.SITE]
    H.check(site and site.autoplace_specification, "značka nemá autoplace")
    local mgs = game.surfaces.nauvis.map_gen_settings
    H.check(mgs.autoplace_controls[worldgen.CONTROL], "Nauvis nemá posuvník Města")
    H.check(mgs.autoplace_settings.entity.settings[worldgen.SITE], "Nauvis nerozmísťuje značky")
    H.check(prototypes.entity["rt-town-hall-1"].map_color, "radnice nemá barvu na mapě")
  end } } },
}
