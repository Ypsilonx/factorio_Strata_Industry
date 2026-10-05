--- Jednotkové testy generátoru jmen měst.
local A = require("assert")
local names = require("scripts.names")

return {
  { "prvních 144 jmen je unikátních, pak číslo", function()
    local seen = {}
    for n = 1, 144 do
      local name = names.generate(n)
      A.eq(seen[name], nil, "duplicita " .. name)
      seen[name] = true
    end
    A.truthy(names.generate(145):match(" 2$"), "145. jméno s číslem")
  end },
}
