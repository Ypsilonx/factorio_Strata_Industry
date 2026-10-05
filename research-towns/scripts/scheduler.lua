--- Plánovač: každé město se zpracuje jen v ticku, kdy je na řadě (storage.schedule[tick] = { id, … }).
--- town.scheduled_tick brání dvojímu naplánování.
local M = {}

--- Zařadí město ke zpracování v daném ticku (pokud už naplánované není).
function M.schedule(town, tick)
  if town.scheduled_tick then return end
  local bucket = storage.schedule[tick]
  if not bucket then
    bucket = {}
    storage.schedule[tick] = bucket
  end
  bucket[#bucket + 1] = town.id
  town.scheduled_tick = tick
end

--- Vyjme seznam pro daný tick a pro každé stále existující město zavolá handler.
--- @param handler fun(town: table)
function M.run(tick, handler)
  local bucket = storage.schedule[tick]
  if not bucket then return end
  storage.schedule[tick] = nil
  for _, id in ipairs(bucket) do
    local town = storage.towns[id]
    if town and town.scheduled_tick == tick then
      town.scheduled_tick = nil
      handler(town)
    end
  end
end

--- Zahodí celý plán (po změně konfigurace se postaví znovu).
function M.clear()
  storage.schedule = {}
  for _, town in pairs(storage.towns) do town.scheduled_tick = nil end
end

return M
