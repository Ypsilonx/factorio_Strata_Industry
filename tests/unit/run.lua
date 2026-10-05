---@diagnostic disable: undefined-global
--- Runner jednotkových testů čisté Lua logiky modu (spouští se z kořene repozitáře: lua tests/unit/run.lua).
package.path = "research-towns/?.lua;tests/unit/?.lua;" .. package.path

--- Seznam testovacích sad; každá vrací pole { "název", funkce }.
local SUITES = { "test_locale", "test_levels", "test_science", "test_labs", "test_placeholder",
  "test_geometry", "test_graph", "test_milestones", "test_names", "test_gui_names", "test_story",
  "test_allocation", "test_houses", "test_state", "test_upkeep" }

local pass, fail = 0, 0
for _, suite in ipairs(SUITES) do
  for _, case in ipairs(require(suite)) do
    local ok, err = pcall(case[2])
    if ok then
      pass = pass + 1
    else
      fail = fail + 1
      print("FAIL " .. suite .. " :: " .. case[1] .. ": " .. tostring(err))
    end
  end
end
print(string.format("UNIT pass=%d fail=%d", pass, fail))
os.exit(fail == 0 and 0 or 1)
