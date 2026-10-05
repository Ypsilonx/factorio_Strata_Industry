---@diagnostic disable: undefined-global
--- Příběh: zprávy o povýšení města.
local A = require("assert")
local story = require("shared.story")

--- Vrátí obsah locale souboru jako řetězec.
local function read(path)
  local file = assert(io.open(path, "r"))
  local text = file:read("a")
  file:close()
  return text
end

return {
  { "povýšení na úroveň 2 je první zpráva", function()
    A.eq(story.upgrade_message(2), "rt.town-upgraded-1", "úroveň 2")
  end },
  { "po vyčerpání zpráv se opakuje poslední (obecná)", function()
    local last = "rt.town-upgraded-" .. story.UPGRADE_MESSAGES
    A.eq(story.upgrade_message(story.UPGRADE_MESSAGES + 1), last, "první za koncem")
    A.eq(story.upgrade_message(100), last, "úroveň 100")
  end },
  { "každá zpráva je v en i cs", function()
    for _, lang in ipairs({ "en", "cs" }) do
      local text = read("research-towns/locale/" .. lang .. "/locale.cfg")
      for i = 1, story.UPGRADE_MESSAGES do
        A.truthy(text:find("\ntown%-upgraded%-" .. i .. "="), lang .. ": chybí town-upgraded-" .. i)
      end
    end
  end },
}
