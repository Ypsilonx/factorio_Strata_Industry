-- Headless integrační testy modu research-towns (spouští tools/run-tests.sh).
local runner = require("runner")

runner.register(require("cases.smoke"))
runner.register(require("cases.compat"))
runner.register(require("cases.prototypes"))
runner.register(require("cases.network"))
runner.register(require("cases.depots"))
runner.register(require("cases.upgrade"))

script.on_init(runner.on_init)
script.on_event(defines.events.on_tick, runner.on_tick)
