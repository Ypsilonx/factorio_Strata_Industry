-- „Cizí mod“ pro integrační testy: recept s laboratoří jako surovinou (jako skleník ze simply-greenhouse).
-- Recept je zamčený a bez výzkumu, aby předmět neovlivnil dostupnost surovin ani specializace měst.
data:extend({
  {
    type = "item",
    name = "rt-test-lab-user",
    icon = "__base__/graphics/icons/iron-chest.png",
    stack_size = 10,
  },
  {
    type = "recipe",
    name = "rt-test-lab-user",
    enabled = false,
    ingredients = {
      { type = "item", name = "lab", amount = 2 },
      { type = "item", name = "electronic-circuit", amount = 1 },
      { type = "item", name = "iron-plate", amount = 3 },
    },
    results = { { type = "item", name = "rt-test-lab-user", amount = 1 } },
  },
})
