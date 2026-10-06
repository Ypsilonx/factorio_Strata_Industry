--- Integrační testy generování měst na Nauvisu (sdílený povrch – testy jen čtou a generují chunky).
local worldgen = require("__research-towns__/shared/worldgen")
local H = require("helpers")
local R = H.REMOTE

--- Města na Nauvisu daného stavu.
local function nauvis_towns(state)
  local list = {}
  for _, t in ipairs(remote.call(R, "list_towns")) do
    if t.surface == "nauvis" and t.state == state then list[#list + 1] = t end
  end
  return list
end

return {
  {
    name = "první město je partnerské 100–200 dlaždic od spawnu a jen jedno",
    steps = { { ticks = 1, run = function()
      local partners = nauvis_towns("partner")
      H.check(#partners == 1, "partnerských měst na Nauvisu: " .. #partners)
      local spawn = game.forces.player.get_spawn_position(game.surfaces.nauvis)
      local t = partners[1]
      local d = math.sqrt((t.position.x - spawn.x) ^ 2 + (t.position.y - spawn.y) ^ 2)
      H.check(d >= 98 and d <= 202, "vzdálenost prvního města " .. d)
      H.check(t.force == "player", "síla " .. t.force)
    end } },
  },
  {
    name = "generátor dává neutrální města bez značek a bez hnízd v okolí",
    setup = function()
      local nauvis = game.surfaces.nauvis
      nauvis.request_to_generate_chunks({ 0, 0 }, 16)
      nauvis.force_generate_chunk_requests()
    end,
    steps = { { ticks = 1, run = function()
      local nauvis = game.surfaces.nauvis
      H.check(nauvis.count_entities_filtered({ name = worldgen.SITE }) == 0, "zůstaly značky míst měst")
      local wild = nauvis_towns("wild")
      H.check(#wild >= 2, "neutrálních měst do 512 dlaždic: " .. #wild)
      for _, t in ipairs(wild) do
        local d = math.sqrt(t.position.x ^ 2 + t.position.y ^ 2)
        H.check(d > worldgen.TOWN_SPAWN_CLEAR - 1, "město u spawnu: " .. d)
        local nests = nauvis.count_entities_filtered({ position = t.position, radius = worldgen.TOWN_NEST_CLEAR,
          force = "enemy", type = { "unit-spawner", "turret" } })
        H.check(nests == 0, "hnízda u města " .. t.id .. ": " .. nests)
      end
      H.check(game.forces.enemy.get_cease_fire("neutral"), "biteři útočí na neutrální města")
    end } },
  },
  {
    name = "rozehraná hra bez nastavení Měst dostane cizí města",
    setup = function()
      -- Jako Nauvis ze savu před modem: v nastavení generátoru chybí posuvník Města i značky.
      local settings = game.surfaces.nauvis.map_gen_settings
      settings.autoplace_controls[worldgen.CONTROL] = nil
      settings.autoplace_settings.entity.settings[worldgen.SITE] = nil
      local surface = game.create_surface("rt-oldsave", settings)
      surface.request_to_generate_chunks({ 0, 0 }, 16)
      surface.force_generate_chunk_requests()
    end,
    steps = { { ticks = 1, run = function()
      remote.call(R, "worldgen_populate", "rt-oldsave")
      local wild = 0
      for _, t in ipairs(remote.call(R, "list_towns")) do
        if t.surface == "rt-oldsave" and t.state == "wild" then wild = wild + 1 end
      end
      H.check(wild >= 2, "cizích měst v rozehrané hře: " .. wild)
    end } },
  },
  {
    name = "doplnění do rozehrané hry nepostaví radnici u hráčovy základny",
    setup = function(ctx)
      -- Mimo Nauvis se značky nenahrazují – zůstanou jako v savu, kam se mod přidává.
      local surface = game.create_surface("rt-oldbase", game.surfaces.nauvis.map_gen_settings)
      surface.request_to_generate_chunks({ 0, 0 }, 16)
      surface.force_generate_chunk_requests()
      local sites = surface.find_entities_filtered({ name = worldgen.SITE })
      H.check(#sites >= 2, "značek na povrchu: " .. #sites)
      ctx.base = sites[1].position
      ctx.chest = surface.create_entity({ name = "iron-chest", force = "player",
        position = { ctx.base.x + 20, ctx.base.y } })
      H.check(ctx.chest, "bednu nelze postavit")
    end,
    steps = { { ticks = 1, run = function(ctx)
      remote.call(R, "worldgen_populate", "rt-oldbase")
      local surface = game.surfaces["rt-oldbase"]
      H.check(surface.count_entities_filtered({ name = worldgen.SITE }) == 0, "zůstaly značky")
      local near = surface.count_entities_filtered({ position = ctx.base, radius = 5, name = "rt-town-hall-1" })
      H.check(near == 0, "radnice u hráčovy bedny")
      local wild = 0
      for _, t in ipairs(remote.call(R, "list_towns")) do
        if t.surface == "rt-oldbase" then wild = wild + 1 end
      end
      H.check(wild >= 1, "ostatní značky se nenahradily")
    end } },
  },
  {
    name = "první město vznikne i při nejvyšší četnosti",
    setup = function(ctx)
      local settings = game.surfaces.nauvis.map_gen_settings
      settings.autoplace_controls[worldgen.CONTROL] = { frequency = 6, size = 1, richness = 1 }
      ctx.dense = game.create_surface("rt-dense", settings)
      ctx.dense.request_to_generate_chunks({ 0, 0 }, 8)
      ctx.dense.force_generate_chunk_requests()
      ctx.force = game.create_force("rt-first-dense")
    end,
    steps = { { ticks = 1, run = function(ctx)
      local id = remote.call(R, "worldgen_first_town", "rt-dense", ctx.force.name)
      H.check(id, "první město se při četnosti 6 neumístilo")
      H.check(H.status(id).state == "partner", "první město není partnerské")
    end } },
  },
  {
    name = "opakované ensure (rozehraná hra) nepřidá první město ani radnice navíc",
    steps = { { ticks = 1, run = function()
      local before = #remote.call(R, "list_towns")
      remote.call(R, "worldgen_ensure", true)
      H.check(#nauvis_towns("partner") == 1, "druhé první město")
      local after = #remote.call(R, "list_towns")
      H.check(after == before, "přibyla města: " .. before .. " → " .. after)
    end } },
  },
}
