--- Jednotkové testy grafu sítě města: komponenty a přiřazení měst s hloubkou.
local A = require("assert")
local graph = require("scripts.graph")

--- Sestaví uzly z hran; první písmeno H = radnice.
local function build(edges)
  local nodes = {}
  local function node(key)
    nodes[key] = nodes[key] or { kind = key:sub(1, 1) == "H" and "hall" or "house", links = {} }
    return nodes[key]
  end
  for _, edge in ipairs(edges) do
    node(edge[1]).links[edge[2]] = true
    node(edge[2]).links[edge[1]] = true
  end
  return nodes
end

return {
  { "řetěz domů dostane hloubky 1..n", function()
    local nodes = build({ { "H1", "a" }, { "a", "b" }, { "b", "c" } })
    local result = graph.assign(nodes, { { key = "H1", town = 1 } })
    A.eq(result.a.depth, 1, "a")
    A.eq(result.c.depth, 3, "c")
    A.eq(result.c.town, 1, "město")
  end },
  { "nepropojený dům nemá město", function()
    local nodes = build({ { "H1", "a" }, { "x", "y" } })
    local result = graph.assign(nodes, { { key = "H1", town = 1 } })
    A.eq(result.x, nil, "x")
  end },
  { "dva zdroje: bližší vyhrává, remíza nižší id", function()
    local nodes = build({ { "H1", "a" }, { "a", "m" }, { "m", "b" }, { "b", "H2" } })
    local result = graph.assign(nodes, { { key = "H1", town = 1 }, { key = "H2", town = 2 } })
    A.eq(result.a.town, 1, "a u H1")
    A.eq(result.b.town, 2, "b u H2")
    A.eq(result.m.town, 1, "m remíza (hloubka 2 od obou) → nižší id")
    A.eq(result.m.depth, 2, "hloubka m")
  end },
  { "radnice se BFS nepřebírá", function()
    local nodes = build({ { "H1", "a" }, { "a", "H2" } })
    local result = graph.assign(nodes, { { key = "H1", town = 1 } })
    A.eq(result.H2, nil, "cizí radnice bez města")
  end },
  { "komponenta", function()
    local nodes = build({ { "a", "b" }, { "b", "c" }, { "x", "y" } })
    local set = graph.component(nodes, "a")
    A.truthy(set.a and set.b and set.c, "a-b-c")
    A.eq(set.x, nil, "x mimo")
  end },
}
