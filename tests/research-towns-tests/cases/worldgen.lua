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
