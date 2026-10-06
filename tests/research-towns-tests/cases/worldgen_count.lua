--- Pomalý test (jen `tools/run-tests.sh worldgen`): při nejnižší četnosti aspoň 20 měst do 1500 dlaždic.
--- Počítá značky na vlastních površích – skript je nahrazuje radnicemi jen na Nauvisu.
-- map_gen_settings vrací kopii, zápis do ní je v pořádku (luacheck to nepozná).
-- luacheck: ignore 122
local worldgen = require("__research-towns__/shared/worldgen")
local H = require("helpers")

--- Seedy map, na kterých se počet ověřuje.
local SEEDS = { 1, 123456, 987654321 }
--- Požadované minimum a okruh.
local MINIMUM, RADIUS = 20, 1500

return {
  {
    name = "nejnižší četnost: aspoň 20 měst do 1500 dlaždic",
    setup = function(ctx)
      ctx.surfaces = {}
      for i, seed in ipairs(SEEDS) do
        local settings = game.surfaces.nauvis.map_gen_settings
        settings.seed = seed
        settings.autoplace_controls[worldgen.CONTROL] = { frequency = 1 / 6, size = 1, richness = 1 }
        local surface = game.create_surface("rt-worldgen-" .. i, settings)
        surface.request_to_generate_chunks({ 0, 0 }, math.ceil(RADIUS / 32) + 1)
        surface.force_generate_chunk_requests()
        ctx.surfaces[i] = surface
      end
    end,
    steps = { { ticks = 1, run = function(ctx)
      for i, surface in ipairs(ctx.surfaces) do
        local count = surface.count_entities_filtered({ name = worldgen.SITE, position = { 0, 0 }, radius = RADIUS })
        log("RT-TEST INFO seed " .. SEEDS[i] .. ": měst do " .. RADIUS .. " = " .. count)
        H.check(count >= MINIMUM, "seed " .. SEEDS[i] .. ": jen " .. count .. " měst")
      end
    end } },
  },
}
