-- Research Towns – startup nastavení (laditelné bez úprav kódu).
data:extend({
  {
    type = "double-setting", name = "rt-upkeep-multiplier", setting_type = "startup",
    default_value = 1, minimum_value = 0, maximum_value = 100, order = "a",
  },
  {
    type = "double-setting", name = "rt-pollution-absorption", setting_type = "startup",
    default_value = 1, minimum_value = 0, maximum_value = 100, order = "b",
  },
})
