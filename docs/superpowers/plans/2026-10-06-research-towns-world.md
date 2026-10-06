# Research Towns – města na mapě a převzetí (plán 2a) – implementační plán

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Města rozmístí generátor mapy (posuvník „Města“, vidět v náhledu mapy), první město u spawnu je hned partnerské, další hráč objeví, dodá dar a převezme.

**Architecture:** Data stage přidá `autoplace-control` `rt-towns`, pojmenované noise výrazy mřížky (čistá logika `shared/worldgen.lua`) a značku `rt-town-site`, kterou generátor rozmístí na Nauvisu. Runtime (`scripts/worldgen.lua`) při generování chunku nahradí značku neutrální radnicí a zaeviduje neobjevené město (`towns.register_wild`), vyčistí okolí a hnízda. Město má stav `wild` → `discovered` (objevení hráčem, `scripts/discovery.lua`; dar ze `shared/worldgen.lua`) → `partner` (převzetí po dodání daru přes překladiště, dnešní chování).

**Tech Stack:** Lua (Factorio 2.0.77 API), Lua 5.3 pro unit testy, headless Factorio (`tools/run-tests.sh`), Git Bash.

**Spec:** `docs/superpowers/specs/2026-10-06-research-towns-world-design.md` (navazuje na `2026-10-05-research-towns-design.md`).

## Global Constraints

- Prefix `rt`: prototypy `rt-…`, noise výrazy `rt_town_…`, GUI prvky `rt_…` (nesmí kolidovat s `LuaGuiElement` – hlídá `test_gui_names`), remote `research-towns`, log testů `RT-TEST`.
- Herní kód je Lua 5.2: žádné `//`, bitové operátory ani `math.tointeger`.
- Města jen na Nauvisu. Všechno odvozené z obsahu hry v `data-final-fixes.lua`.
- Stav jen ve `storage`; nový stav doplní `state.init` i do starého savu. Neobjevená města se nezpracovávají (nejsou v plánovači).
- Komentáře a docstringy česky (každá funkce `---` docstring), 2 mezery, `snake_case`.
- Locale `en` i `cs` se stejnými klíči; žádný text pro hráče natvrdo. Tón příběhu: partnerství rovného s rovným („the people of Nauvis“, „townsfolk“, nikdy „tribes“/„primitivní“).
- Laditelné hodnoty jen jako pojmenované konstanty (`shared/worldgen.lua`, `shared/levels.lua`).
- Konec každého úkolu: `bash tools/run-unit.sh` a `bash tools/run-tests.sh vanilla` zelené; v Task 7 navíc `space-age`, `worldgen` a `mods`.
- Soubory v repu mají CRLF (autocrlf) – upravuj nástrojem Edit, ne `perl -0` s `\n`.
- Commit jen v krocích „Commit“; push nikdy. Zpráva končí řádky
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` a `Claude-Session: https://claude.ai/code/session_01NAMWsnMZJNsTjQY1Ye9sjg`.

## Review Focus

1. **Rozehraná hra s existujícími městy** – po aktualizaci nesmí zmizet ani se přepsat partnerské radnice, první město se nesmí přidat podruhé (pokrývá Task 4, test „rozehraná hra“ přes `worldgen.ensure` dvakrát).
2. **Značka na hranici chunku / dvojí nalezení** – radnice se nesmí vytvořit dvakrát (Task 4: náhrada je idempotentní, značka se po náhradě zničí; test „žádné značky nezůstaly“).
3. **Překladiště u neobjeveného města** – nesmí sbírat dar ani odebírat elektřinu města (Task 3: test „neobjevené město“; rozvodna u objeveného města se nepřipojí).
4. **Dar se stanoví jednou** – další povýšení jiných měst nesmí měnit dar už objeveného města (Task 3: dar uložený v `town.gift`, test porovná po povýšení jiného města).
5. **Četnost 0 / vypnutá Města** – generátor nesmí dát žádné město, první město ano (Task 1: noise výraz obsahuje `rt_town_frequency > 0`; první město staví skript nezávisle na posuvníku).

---

### Task 1: Čistá logika světa (`shared/worldgen.lua`)

**Files:**
- Create: `research-towns/shared/worldgen.lua`
- Create: `tests/unit/test_worldgen.lua`
- Modify: `tests/unit/run.lua` (SUITES)

**Interfaces:**
- Produces (`shared/worldgen.lua`): konstanty `CONTROL = "rt-towns"`, `SITE = "rt-town-site"`, `MAP_COLOR`, `TOWN_CELL_BASE`, `TOWN_CELL_MAX`, `TOWN_CELL_MARGIN`, `TOWN_SPAWN_CLEAR`, `TOWN_CLEAR_MARGIN`, `TOWN_NEST_CLEAR`, `DISCOVERY_RADIUS`, `GIFT_SHARE`, `INDEX_CELL`, `FIRST_TOWN_DISTANCES`, `FIRST_TOWN_DIRECTIONS`, `FIRST_TOWN_GAP`; funkce
  `cell_size(frequency) -> number`, `noise_expressions() -> table<string, string>`,
  `gift_level(partner_levels: integer[]) -> integer`, `gift(requirements: table[]|nil, share: number) -> table[]`,
  `cell_key(position) -> string`, `cell_keys_around(area: BoundingBox, radius: number) -> string[]`,
  `first_town_candidates(spawn: MapPosition, seed: integer) -> MapPosition[]`.

- [ ] **Step 1: Write the failing test** – `tests/unit/test_worldgen.lua`:

```lua
--- Jednotkové testy čisté logiky světa: mřížka měst, dar, prostorový index, místo prvního města.
local A = require("assert")
local worldgen = require("shared.worldgen")

return {
  { "velikost buňky: výchozí, strop při nízké četnosti, minimum 20 měst do 1500", function()
    A.eq(worldgen.cell_size(1), worldgen.TOWN_CELL_BASE, "četnost 1")
    A.eq(worldgen.cell_size(1 / 6), worldgen.TOWN_CELL_MAX, "nejnižší četnost na stropu")
    A.truthy(worldgen.cell_size(6) < worldgen.TOWN_CELL_BASE, "vysoká četnost = menší buňky")
    local cells = math.pi * 1500 ^ 2 / worldgen.cell_size(1 / 6) ^ 2
    A.truthy(cells >= 30, "buněk do 1500 při nejnižší četnosti: " .. cells)
  end },
  { "noise výrazy obsahují konstanty a vypnutí při četnosti 0", function()
    local e = worldgen.noise_expressions()
    for _, name in ipairs({ "rt_town_frequency", "rt_town_cell", "rt_town_x", "rt_town_y", "rt_town_probability" }) do
      A.truthy(type(e[name]) == "string", "chybí " .. name)
    end
    A.truthy(e.rt_town_frequency:find("control:rt-towns:frequency", 1, true), "posuvník")
    A.truthy(e.rt_town_cell:find(tostring(worldgen.TOWN_CELL_MAX), 1, true), "strop buňky")
    A.truthy(e.rt_town_probability:find("rt_town_frequency > 0", 1, true), "četnost 0 vypne města")
    A.truthy(e.rt_town_probability:find("distance > " .. worldgen.TOWN_SPAWN_CLEAR, 1, true), "okolí spawnu")
    A.truthy(e.rt_town_x:find("floor(x / rt_town_cell)", 1, true), "posun podle indexu buňky")
  end },
  { "dar: úroveň o jednu nižší než nejvyšší partner, bez vědy, nahoru", function()
    A.eq(worldgen.gift_level({}), 1, "bez partnerů")
    A.eq(worldgen.gift_level({ 1 }), 1, "úroveň 1")
    A.eq(worldgen.gift_level({ 3, 5, 2 }), 4, "nejvyšší 5")
    local gift = worldgen.gift({
      { type = "item", name = "red", amount = 200, science = true },
      { type = "item", name = "wood", amount = 201 },
      { type = "fluid", name = "water", amount = 1000 },
    }, 0.25)
    A.eq(#gift, 2, "věda vynechaná")
    A.eq(gift[1].name, "wood", "pořadí zachované")
    A.eq(gift[1].amount, 51, "201 × 0,25 nahoru")
    A.eq(gift[2].amount, 250, "kapalina")
    A.eq(#worldgen.gift(nil, 0.25), 0, "bez milníku")
  end },
  { "prostorový index po buňkách", function()
    A.eq(worldgen.cell_key({ x = 0, y = 0 }), "0:0", "počátek")
    A.eq(worldgen.cell_key({ x = -1, y = -1 }), "-1:-1", "záporné")
    A.eq(worldgen.cell_key({ x = worldgen.INDEX_CELL, y = 5 }), "1:0", "další buňka")
    local keys = worldgen.cell_keys_around({ left_top = { x = 0, y = 0 }, right_bottom = { x = 32, y = 32 } }, 150)
    local set = {}
    for _, key in ipairs(keys) do set[key] = true end
    A.eq(#keys, 4, "4 buňky: " .. table.concat(keys, " "))
    A.truthy(set["-1:-1"] and set["0:0"] and set["-1:0"] and set["0:-1"], "sousední buňky")
  end },
  { "kandidáti prvního města: vzdálenosti, směry, determinismus", function()
    local spawn = { x = 10, y = -20 }
    local list = worldgen.first_town_candidates(spawn, 123456789)
    A.eq(#list, #worldgen.FIRST_TOWN_DISTANCES * worldgen.FIRST_TOWN_DIRECTIONS, "počet")
    for i = 1, worldgen.FIRST_TOWN_DIRECTIONS do
      local d = math.sqrt((list[i].x - spawn.x) ^ 2 + (list[i].y - spawn.y) ^ 2)
      A.truthy(math.abs(d - worldgen.FIRST_TOWN_DISTANCES[1]) < 1.5, "první vzdálenost: " .. d)
      A.eq(list[i].x % 1, 0.5, "střed dlaždice x")
    end
    local again = worldgen.first_town_candidates(spawn, 123456789)
    A.eq(again[1].x, list[1].x, "stejný seed = stejné pořadí")
  end },
}
```

- [ ] **Step 2: Add suite and run to verify it fails**

V `tests/unit/run.lua` přidej `"test_worldgen"` na konec seznamu `SUITES` (za `"test_board"`).
Run: `bash tools/run-unit.sh`
Expected: FAIL – `module 'shared.worldgen' not found`.

- [ ] **Step 3: Write implementation** – `research-towns/shared/worldgen.lua`:

```lua
--- Čistá logika světa: rozmístění měst generátorem mapy (mřížka s posunem), dar za partnerství,
--- prostorový index měst a kandidáti místa prvního města. Sdílí ho data stage i control stage.
local M = {}

--- Ovládání generátoru mapy (posuvník „Města“) a značka místa města, kterou skript nahradí radnicí.
M.CONTROL = "rt-towns"
M.SITE = "rt-town-site"
--- Barva radnice a značky na mapě i v náhledu mapy.
M.MAP_COLOR = { r = 1, g = 0.75, b = 0.2 }
--- Velikost buňky mřížky (dlaždice) při četnosti 1 a strop při nízké četnosti: i nejnižší četnost dá
--- aspoň ~20 měst do 1500 dlaždic od spawnu.
M.TOWN_CELL_BASE = 250
M.TOWN_CELL_MAX = 450
--- Okraj buňky bez měst – sousední města nebudou nalepená na sebe.
M.TOWN_CELL_MARGIN = 40
--- Kolem spawnu generátor města nedává (první město staví skript).
M.TOWN_SPAWN_CLEAR = 120
--- Pás kolem radnice bez stromů, kamenů a útesů; okruh bez hnízd biterů.
M.TOWN_CLEAR_MARGIN = 10
M.TOWN_NEST_CLEAR = 150
--- Hráč objeví město, když je do této vzdálenosti od okraje radnice.
M.DISCOVERY_RADIUS = 40
--- Dar za partnerství: podíl surovin milníku.
M.GIFT_SHARE = 0.25
--- Velikost buňky prostorového indexu měst (dlaždice).
M.INDEX_CELL = 256
--- První město: vzdálenosti od spawnu v pořadí zkoušení, počet směrů a odstup od jiné radnice.
M.FIRST_TOWN_DISTANCES = { 150, 120, 180, 100, 200 }
M.FIRST_TOWN_DIRECTIONS = 16
M.FIRST_TOWN_GAP = 100

--- Velikost buňky mřížky pro četnost z posuvníku (stejný vzorec jako noise výraz rt_town_cell).
function M.cell_size(frequency)
  return math.min(M.TOWN_CELL_MAX, M.TOWN_CELL_BASE / math.sqrt(frequency))
end

--- Pojmenované noise výrazy generátoru (jméno → výraz). Posun radnice v buňce je pro celou buňku stejný –
--- šum se vzorkuje v indexu buňky (posun závislý na x, y slil v pokusu radnice do „housenek“).
--- Pravděpodobnost je 1 právě na jedné dlaždici buňky; 0 jinde, kolem spawnu a při četnosti 0.
function M.noise_expressions()
  local span = "(rt_town_cell - " .. (2 * M.TOWN_CELL_MARGIN) .. ")"
  --- Souřadnice radnice v buňce pro osu ("x" / "y"); seed odliší osy.
  local function offset(axis, seed)
    return "floor(" .. axis .. " / rt_town_cell) * rt_town_cell + " .. M.TOWN_CELL_MARGIN .. " + " .. span
      .. " * (0.5 + 0.5 * clamp(basis_noise{x = floor(x / rt_town_cell) * 0.37, y = floor(y / rt_town_cell) * 0.41,"
      .. " seed0 = map_seed, seed1 = " .. seed .. ", input_scale = 1, output_scale = 1.5}, -1, 1))"
  end
  return {
    rt_town_frequency = "var('control:" .. M.CONTROL .. ":frequency')",
    rt_town_cell = string.format("min(%d, %d / sqrt(max(rt_town_frequency, 0.0001)))", M.TOWN_CELL_MAX,
      M.TOWN_CELL_BASE),
    rt_town_x = offset("x", 7101),
    rt_town_y = offset("y", 7102),
    rt_town_probability = string.format(
      "(rt_town_frequency > 0) * (distance > %d) * (abs(x - rt_town_x) < 0.5) * (abs(y - rt_town_y) < 0.5)",
      M.TOWN_SPAWN_CLEAR),
  }
end

--- Úroveň milníku, ze kterého je dar: o jednu nižší než nejvyšší úroveň partnerských měst, nejméně 1.
--- @param partner_levels integer[]
function M.gift_level(partner_levels)
  local highest = 1
  for _, level in ipairs(partner_levels) do highest = math.max(highest, level) end
  return math.max(1, highest - 1)
end

--- Dar za partnerství: suroviny milníku bez vědeckých balíčků × share, nahoru na celé kusy.
--- @param requirements table[]|nil požadavky milníku
--- @return table[] { {type, name, amount} }
function M.gift(requirements, share)
  local list = {}
  for _, req in ipairs(requirements or {}) do
    if not req.science then
      list[#list + 1] = { type = req.type, name = req.name, amount = math.ceil(req.amount * share - 1e-9) }
    end
  end
  return list
end

--- Klíč buňky prostorového indexu pro pozici.
function M.cell_key(position)
  return math.floor(position.x / M.INDEX_CELL) .. ":" .. math.floor(position.y / M.INDEX_CELL)
end

--- Klíče buněk indexu, do kterých zasahuje oblast rozšířená o radius.
--- @param area { left_top: MapPosition, right_bottom: MapPosition }
--- @return string[]
function M.cell_keys_around(area, radius)
  local keys = {}
  local x1, x2 = math.floor((area.left_top.x - radius) / M.INDEX_CELL), math.floor((area.right_bottom.x + radius) / M.INDEX_CELL)
  local y1, y2 = math.floor((area.left_top.y - radius) / M.INDEX_CELL), math.floor((area.right_bottom.y + radius) / M.INDEX_CELL)
  for cx = x1, x2 do
    for cy = y1, y2 do keys[#keys + 1] = cx .. ":" .. cy end
  end
  return keys
end

--- Kandidáti místa prvního města (středy dlaždic): kruhy FIRST_TOWN_DISTANCES kolem spawnu, každý
--- ve FIRST_TOWN_DIRECTIONS směrech; počáteční směr ze seedu mapy.
--- @return MapPosition[]
function M.first_town_candidates(spawn, seed)
  local list, n = {}, M.FIRST_TOWN_DIRECTIONS
  local start = seed % n
  for _, distance in ipairs(M.FIRST_TOWN_DISTANCES) do
    for i = 0, n - 1 do
      local angle = 2 * math.pi * ((start + i) % n) / n
      list[#list + 1] = { x = math.floor(spawn.x + distance * math.cos(angle)) + 0.5,
        y = math.floor(spawn.y + distance * math.sin(angle)) + 0.5 }
    end
  end
  return list
end

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=… fail=0`.

- [ ] **Step 5: Commit**

```bash
git add research-towns/shared/worldgen.lua tests/unit/test_worldgen.lua tests/unit/run.lua
git commit -m "feat: čistá logika rozmístění měst, daru a prostorového indexu"
```

---

### Task 2: Generátor mapy – posuvník Města a značka místa města

**Files:**
- Create: `research-towns/prototypes/worldgen.lua`
- Modify: `research-towns/data-final-fixes.lua` (na konec `require("prototypes.worldgen")`)
- Modify: `research-towns/prototypes/hall.lua` (`map_color`)
- Modify: `research-towns/locale/en/locale.cfg`, `research-towns/locale/cs/locale.cfg`
- Modify: `tests/research-towns-tests/runner.lua` (testovací povrch bez měst, větší vygenerovaná oblast)
- Modify: `tests/research-towns-tests/cases/compat.lua` (kontroly prototypů generátoru)

**Interfaces:**
- Consumes: `shared/worldgen.lua` (Task 1): `CONTROL`, `SITE`, `MAP_COLOR`, `noise_expressions()`.
- Produces: prototypy `autoplace-control` `rt-towns`, `simple-entity` `rt-town-site` (autoplace na Nauvisu), noise výrazy `rt_town_*`; radnice mají `map_color = worldgen.MAP_COLOR`.

- [ ] **Step 1: Write the failing test** – do `tests/research-towns-tests/cases/compat.lua` přidej na začátek souboru `local worldgen = require("__research-towns__/shared/worldgen")` a do vráceného seznamu nový test:

```lua
  { name = "generátor mapy: posuvník Města a značka místa města na Nauvisu", steps = { { ticks = 1, run = function()
    H.check(prototypes.autoplace_control[worldgen.CONTROL], "chybí autoplace-control " .. worldgen.CONTROL)
    local site = prototypes.entity[worldgen.SITE]
    H.check(site and site.autoplace_specification, "značka nemá autoplace")
    local mgs = game.surfaces.nauvis.map_gen_settings
    H.check(mgs.autoplace_controls[worldgen.CONTROL], "Nauvis nemá posuvník Města")
    H.check(mgs.autoplace_settings.entity.settings[worldgen.SITE], "Nauvis nerozmísťuje značky")
    H.check(prototypes.entity["rt-town-hall-1"].map_color, "radnice nemá barvu na mapě")
  end } } },
```

a do `tests/research-towns-tests/cases/smoke.lua` test pro testovací povrch:

```lua
  {
    name = "testovací povrch města negeneruje (četnost 0)",
    steps = { { ticks = 1, run = function(ctx)
      local sites = ctx.surface.count_entities_filtered({ name = "rt-town-site" })
      if sites > 0 then error("značek na testovacím povrchu: " .. sites) end
    end } },
  },
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tools/run-tests.sh vanilla`
Expected: FAIL u „generátor mapy: posuvník Města…“ (chybí autoplace-control).

- [ ] **Step 3: Prototypy generátoru** – `research-towns/prototypes/worldgen.lua`:

```lua
--- Generátor mapy: posuvník „Města“, pojmenované noise výrazy mřížky a značka místa města, kterou skript při
--- generování chunku nahradí radnicí (regenerate_entity v rozehrané hře tak nesáhne na existující radnice).
--- Volá se z data-final-fixes – jiný mod mohl v data-updates upravit map_gen_settings Nauvisu.
local levels = require("shared.levels")
local worldgen = require("shared.worldgen")

local half = levels.HALL_SIZE / 2

local list = {
  { type = "autoplace-control", name = worldgen.CONTROL, category = "enemy", richness = false, order = "z-[rt-towns]" },
  {
    type = "simple-entity",
    name = worldgen.SITE,
    hidden = true,
    flags = { "placeable-neutral", "not-blueprintable", "not-deconstructable" },
    collision_box = { { -half + 0.1, -half + 0.1 }, { half - 0.1, half - 0.1 } },
    map_color = worldgen.MAP_COLOR,
    picture = { filename = "__core__/graphics/empty.png", size = 1 },
    -- Pořadí „a“: značky se rozmístí před stromy, takže je stromy neblokují.
    autoplace = { control = worldgen.CONTROL, order = "a[rt-town]", probability_expression = "rt_town_probability" },
  },
}
for name, expression in pairs(worldgen.noise_expressions()) do
  list[#list + 1] = { type = "noise-expression", name = name, expression = expression }
end
data:extend(list)

local nauvis = data.raw.planet and data.raw.planet.nauvis
local settings = nauvis and nauvis.map_gen_settings
if settings then
  settings.autoplace_controls = settings.autoplace_controls or {}
  settings.autoplace_controls[worldgen.CONTROL] = {}
  settings.autoplace_settings = settings.autoplace_settings or {}
  settings.autoplace_settings.entity = settings.autoplace_settings.entity or { settings = {} }
  settings.autoplace_settings.entity.settings[worldgen.SITE] = {}
else
  log("research-towns: Nauvis nemá map_gen_settings – generátor města nedává, zůstane jen první město")
end
```

Na konec `research-towns/data-final-fixes.lua` přidej:

```lua
-- Generátor mapy: posuvník Města a značky míst měst na Nauvisu.
require("prototypes.worldgen")
```

V `research-towns/prototypes/hall.lua` přidej nahoru `local worldgen = require("shared.worldgen")` a v `M.create` za řádek `hall.max_health = 3000` přidej:

```lua
  -- Barva na mapě i v náhledu mapy (stejná jako značka místa města).
  hall.map_color = worldgen.MAP_COLOR
```

- [ ] **Step 4: Locale** – v `locale/en/locale.cfg` přidej novou sekci (před `[mod-setting-name]`) a klíč entity:

```
[autoplace-control-names]
rt-towns=[entity=rt-town-hall-1] Towns
```

do sekce `[entity-name]` přidej `rt-town-site=Town site`.
V `locale/cs/locale.cfg` totéž česky: sekce `[autoplace-control-names]` s `rt-towns=[entity=rt-town-hall-1] Města` a v `[entity-name]` `rt-town-site=Místo města`.

- [ ] **Step 5: Větší testovací povrch** – v `tests/research-towns-tests/runner.lua` v `M.on_init` změň
`surface.request_to_generate_chunks({ 0, 0 }, 12)` na:

```lua
  -- Poloměr 16 chunků: výřezy testů (6 v řadě po 96 dlaždicích) sahají s počtem testů až k ±480 dlaždicím.
  surface.request_to_generate_chunks({ 0, 0 }, 16)
```

Povrch `rt-test` má `generate_with_lab_tiles = true` – generátor na něm entity (ani značky měst) nedává;
test „testovací povrch města negeneruje“ to hlídá.

- [ ] **Step 6: Run tests**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla`
Expected: všechny PASS včetně dvou nových testů.

- [ ] **Step 7: Ověř náhled mapy (ruční, jednorázové)**

```bash
F="C:/STEAM/steamapps/common/Factorio/bin/x64/factorio.exe"; RUN="$(cygpath -m .test-run/vanilla)"
"$F" --config "$RUN/config.ini" --mod-directory "$RUN/mods" --generate-map-preview "$RUN/preview.png" --map-gen-seed 123
```

Prohlédni `.test-run/vanilla/preview.png` (nástroj Read): oranžově-žluté čtverečky 15×15 rozmístěné rovnoměrně
(~250 dlaždic od sebe), žádné „housenky“ slitých radnic, žádné v okruhu ~120 dlaždic od středu. Pokud se
radnice slévají, zkontroluj, že `rt_town_x/y` vzorkují šum jen v `floor(x / rt_town_cell)`. `.test-run/` je v `.gitignore`.

- [ ] **Step 8: Commit**

```bash
git add research-towns/prototypes/worldgen.lua research-towns/data-final-fixes.lua research-towns/prototypes/hall.lua research-towns/locale tests/research-towns-tests
git commit -m "feat: posuvník Města a rozmístění míst měst generátorem mapy"
```

---

### Task 3: Stavy města – neobjevené, objevené s darem, převzetí

**Files:**
- Modify: `research-towns/scripts/towns.lua`
- Modify: `research-towns/scripts/depots.lua` (`resolve`, nové `owner_force`)
- Modify: `research-towns/scripts/state.lua`
- Modify: `research-towns/scripts/remote.lua`
- Modify: `research-towns/control.lua` (`on_object_destroyed`, `on_configuration_changed`)
- Modify: `research-towns/locale/en/locale.cfg`, `research-towns/locale/cs/locale.cfg`
- Modify: `tests/unit/test_state.lua`
- Create: `tests/research-towns-tests/cases/takeover.lua`
- Modify: `tests/research-towns-tests/control.lua` (registrace `cases.takeover`)

**Interfaces:**
- Consumes: `shared/worldgen.lua` (Task 1): `cell_key`, `gift_level`, `gift`, `GIFT_SHARE`.
- Produces (`scripts/towns.lua`): `town.state` ∈ `"wild" | "discovered" | "partner"`, `town.position`, `town.gift`, `town.force` (jméno síly, která město objevila);
  `M.register_wild(hall: LuaEntity) -> town`, `M.discover(town, force: LuaForce)`, `M.take_over(town, force: LuaForce)`, `M.remove_wild(key: integer)`;
  `M.status(town)` vrací u nepartnerského města `{ id, name, level = 1, state, hall, requirements (dar s delivered), house_requirements = {}, houses_to_upgrade = 0, upkeep = {}, power_watts = 0, power_percent = 0, level_progress, house_upgrade_progress = nil }`.
- Produces (`storage`): `storage.wild_halls[unit_number] = town_id` (jen neobjevená a objevená města), `storage.town_cells[cell_key] = { [town_id] = true }`.
- Produces (`scripts/depots.lua`): `M.owner_force(town) -> LuaForce|nil`.
- Produces (remote): `create_wild_town(surface_name, position) -> id|nil`, `discover(id, force_name)`, `list_towns() -> { {id, state, surface, position, force} }`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_state.lua` – přidej druhý test do vráceného seznamu:

```lua
  { "starý save: města jsou partnerská, mají pozici a jsou v indexu", function()
    storage = { towns = { [1] = { id = 1, progress = {}, hall = { valid = true, position = { x = 10, y = 20 } } } } }
    state.init()
    A.eq(storage.towns[1].state, "partner", "stav")
    A.eq(storage.towns[1].position.x, 10, "pozice")
    A.truthy(storage.wild_halls, "tabulka neutrálních radnic")
    A.truthy(storage.town_cells["0:0"][1], "index")
    storage = nil
  end },
```

`tests/research-towns-tests/cases/takeover.lua`:

```lua
--- Integrační testy neobjeveného města, objevení s darem a převzetí po dodání daru.
local H = require("helpers")
local R = H.REMOTE

--- Vlastní síla testu: dar se počítá z nejvyšší úrovně měst síly, jiné testy mění úrovně měst síly „player“.
local function own_force(ctx, suffix)
  ctx.force = game.create_force("rt-gift-" .. suffix)
  return ctx.force.name
end

--- Neutrální radnice uprostřed výřezu testu.
local function wild(ctx)
  ctx.town = remote.call(R, "create_wild_town", ctx.surface.name, { x = ctx.origin.x + 0.5, y = ctx.origin.y + 0.5 })
  H.check(ctx.town, "neutrální radnici nelze postavit")
end

--- Signály tabule jako mapa jméno → hodnota.
local function signals(entity)
  local result = {}
  local section = entity.get_control_behavior().get_section(1)
  for _, filter in pairs(section and section.filters or {}) do
    if filter.value then result[filter.value.name] = filter.min end
  end
  return result
end

return {
  {
    name = "neobjevené město: nezničitelné, nezkoumá, nepřipojí překladiště ani domy",
    setup = function(ctx)
      wild(ctx)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
      ctx.house = H.house(ctx, 11, 0)
    end,
    steps = { { ticks = 1, run = function(ctx)
      local s = H.status(ctx.town)
      H.check(s.state == "wild", "stav " .. tostring(s.state))
      local hall = H.hall(ctx.town)
      H.check(hall.force.name == "neutral" and not hall.destructible, "neutrální a nezničitelná")
      H.check(hall.disabled_by_script, "neobjevená radnice zkoumá")
      H.check(remote.call(R, "town_of", ctx.depot.unit_number) == nil, "překladiště se připojilo")
      H.check(remote.call(R, "depth_of", ctx.house.unit_number) == nil, "dům se připojil")
    end } },
  },
  {
    name = "objevení stanoví dar z milníku 1, připojí překladiště a tabuli, rozvodnu ne",
    setup = function(ctx)
      local force = own_force(ctx, "discover")
      wild(ctx)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10, { force = force })
      ctx.power = H.place(ctx, "rt-power-depot", -4, 10, { force = force })
      ctx.board = H.place(ctx, "rt-town-board", 2, 9, { force = force })
    end,
    steps = { { ticks = 1, run = function(ctx)
      remote.call(R, "discover", ctx.town, ctx.force.name)
      H.process(ctx.town)
      local s = H.status(ctx.town)
      H.check(s.state == "discovered", "stav " .. tostring(s.state))
      local expected = {}
      for _, req in ipairs(H.levels_data().upgrade["1"]) do
        if not req.science then expected[req.name] = math.ceil(req.amount * 0.25 - 1e-9) end
      end
      H.check(#s.requirements > 0, "prázdný dar")
      for _, req in ipairs(s.requirements) do
        H.check(expected[req.name] == req.amount, "dar " .. req.name .. ": " .. req.amount)
      end
      H.check(remote.call(R, "town_of", ctx.depot.unit_number) == ctx.town, "překladiště nepřipojené")
      H.check(remote.call(R, "town_of", ctx.power.unit_number) == nil, "rozvodna připojená k cizímu městu")
      local first = s.requirements[1]
      H.check(signals(ctx.board)[first.name] == first.amount, "tabule: " .. serpent.line(signals(ctx.board)))
    end } },
  },
  {
    name = "dodaný dar převezme město pro sílu překladiště a dům se pak připojí",
    setup = function(ctx)
      local force = own_force(ctx, "takeover")
      wild(ctx)
      remote.call(R, "discover", ctx.town, force)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10, { force = force })
      for _, req in ipairs(H.status(ctx.town).requirements) do
        H.check(req.type == "item", "dar z milníku 1 má jen předměty")
        ctx.depot.insert({ name = req.name, count = req.amount })
      end
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        H.process(ctx.town)
        local s = H.status(ctx.town)
        H.check(s.state == "partner", "stav " .. tostring(s.state))
        local hall = H.hall(ctx.town)
        H.check(hall.force == ctx.force, "síla " .. hall.force.name)
        H.check(hall.destructible, "radnice zůstala nezničitelná")
        H.check(s.level == 1, "úroveň " .. s.level)
        ctx.house = H.place(ctx, "rt-house", 11, 0, { force = ctx.force.name })
      end },
      { ticks = 1, run = function(ctx)
        H.check(remote.call(R, "depth_of", ctx.house.unit_number) == 1, "dům se nepřipojil")
      end },
    },
  },
  {
    name = "dar objeveného města se nemění povýšením jiného města",
    setup = function(ctx)
      local force = own_force(ctx, "fixed")
      wild(ctx)
      remote.call(R, "discover", ctx.town, force)
      ctx.before = serpent.line(H.status(ctx.town).requirements)
      local other = remote.call(R, "create_town", ctx.surface.name, { x = ctx.origin.x + 30.5, y = ctx.origin.y + 30.5 }, force)
      remote.call(R, "set_level", other, 4)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(serpent.line(H.status(ctx.town).requirements) == ctx.before, "dar se změnil")
    end } },
  },
}
```

V `tests/research-towns-tests/control.lua` přidej `runner.register(require("cases.takeover"))` za `cases.board`.

- [ ] **Step 2: Run to verify failure**

Run: `bash tools/run-unit.sh; bash tools/run-tests.sh vanilla`
Expected: unit FAIL (`state` je nil), integrace FAIL (`create_wild_town` neexistuje).

- [ ] **Step 3: `scripts/state.lua`** – nahoru `local worldgen = require("shared.worldgen")`; v `M.init` za `storage.next_town_id = …` přidej `storage.wild_halls = storage.wild_halls or {}` a `storage.town_cells = storage.town_cells or {}`; ve smyčce přes města doplň:

```lua
    town.state = town.state or "partner"
    if not town.position and town.hall and town.hall.valid then town.position = town.hall.position end
    if town.position then
      local key = worldgen.cell_key(town.position)
      storage.town_cells[key] = storage.town_cells[key] or {}
      storage.town_cells[key][town.id] = true
    end
```

- [ ] **Step 4: `scripts/towns.lua` – evidence a index.** Nahoru přidej `local worldgen = require("shared.worldgen")`. Funkci `M.create` nahraď tímto blokem:

```lua
--- Zařadí město do prostorového indexu (hnízda u nových chunků, viz scripts/worldgen.lua).
local function index_add(town)
  local key = worldgen.cell_key(town.position)
  storage.town_cells[key] = storage.town_cells[key] or {}
  storage.town_cells[key][town.id] = true
end

--- Vyřadí město z prostorového indexu.
local function index_remove(town)
  local cell = storage.town_cells[worldgen.cell_key(town.position)]
  if cell then cell[town.id] = nil end
end

--- Založí záznam města pro radnici (jméno, úroveň 1, prázdný postup) a zařadí ho do indexu.
--- @param state "wild"|"partner"
local function new_town(hall, state)
  local id = storage.next_town_id
  storage.next_town_id = id + 1
  local town = {
    id = id, name = names.generate(id), level = 1, hall = hall, state = state, position = hall.position,
    progress = {}, house_progress = {}, stock = {}, upkeep_ok = true, depots = {}, houses = {}, power_ok = false,
  }
  storage.towns[id] = town
  index_add(town)
  return town
end

--- Založí partnerské město s radnicí úrovně 1; nil, když tam radnice nejde postavit.
--- @param position MapPosition střed radnice
function M.create(surface, position, force)
  local name = config.hall_name(1)
  if not surface.can_place_entity({ name = name, position = position, force = force }) then return nil end
  local hall = surface.create_entity({ name = name, position = position, force = force })
  if not hall then return nil end
  local town = new_town(hall, "partner")
  -- Bez elektřiny radnice nezkoumá; zapne ji první zpracování.
  hall.disabled_by_script = true
  draw_labels(town)
  M.on_network_changed(network.add(hall, "hall", town.id))
  scheduler.schedule(town, game.tick + 1)
  return town
end

--- Zaeviduje neutrální radnici (z generátoru) jako neobjevené město: nezničitelná, vypnutá, mimo síť.
function M.register_wild(hall)
  hall.destructible = false
  hall.disabled_by_script = true
  local town = new_town(hall, "wild")
  storage.wild_halls[hall.unit_number] = town.id
  -- Odstranění bez události (jiný mod, editor) ohlásí on_object_destroyed.
  script.register_on_object_destroyed(hall)
  return town
end

--- Úrovně partnerských měst síly.
--- @return integer[]
local function partner_levels(force)
  local list = {}
  for _, town in pairs(storage.towns) do
    if town.state == "partner" and town.hall.valid and town.hall.force == force then list[#list + 1] = town.level end
  end
  return list
end

--- Hráč síly objevil město: dar z milníku, který síla už zvládla (stanoví se jednou), popisky, značka na mapě,
--- zpráva a zařazení do plánovače (sběr daru).
function M.discover(town, force)
  local hall = town.hall
  town.state = "discovered"
  town.force = force.name
  town.progress = {}
  town.gift = worldgen.gift(config.upgrade(worldgen.gift_level(partner_levels(force))), worldgen.GIFT_SHARE)
  draw_labels(town)
  force.add_chart_tag(hall.surface, { position = hall.position, text = town.name, icon = { type = "item", name = "rt-house" } })
  local gps = string.format("[gps=%d,%d,%s]", math.floor(hall.position.x), math.floor(hall.position.y), hall.surface.name)
  force.print({ "rt.town-discovered", town.name, gps })
  depots.resolve_unassigned()
  scheduler.schedule(town, game.tick + 1)
end

--- Dar dodán: radnice přejde na sílu, napojí se na síť (domy v dosahu se připojí) a město začne na úrovni 1.
function M.take_over(town, force)
  local hall = town.hall
  storage.wild_halls[hall.unit_number] = nil
  hall.force = force
  hall.destructible = true
  town.state = "partner"
  town.gift = nil
  town.progress = {}
  M.on_network_changed(network.add(hall, "hall", town.id))
  M.refresh(town)
  force.print({ "rt.town-partnered", town.name })
end

--- Neutrální radnice zmizela bez události (jiný mod, editor): město zaniká, překladiště se uvolní.
function M.remove_wild(key)
  local id = storage.wild_halls[key]
  if not id then return end
  storage.wild_halls[key] = nil
  local town = storage.towns[id]
  if not town then return end
  destroy_labels(town)
  index_remove(town)
  storage.towns[id] = nil
  for depot_key in pairs(town.depots) do
    local depot = storage.depots[depot_key]
    if depot then depots.resolve(depot) end
  end
end
```

V `M.refresh` změň první řádek na `if not town.hall.valid or town.state ~= "partner" then return end`.
V `M.on_hall_removed` za `destroy_labels(town)` přidej `index_remove(town)`.

- [ ] **Step 5: `scripts/towns.lua` – stav a zpracování.** Na začátek `M.status` (za `function M.status(town)`) vlož:

```lua
  if town.state ~= "partner" then
    return {
      id = town.id, name = town.name, level = town.level, state = town.state, hall = town.hall.unit_number,
      requirements = with_delivered(town.gift, town.progress), house_requirements = {}, houses_to_upgrade = 0,
      upkeep = {}, power_watts = 0, power_percent = 0,
      level_progress = milestones.fraction(town.gift, town.progress), house_upgrade_progress = nil,
    }
  end
```

a do vraceného stavu partnerského města přidej pole `state = town.state,`. Před `M.process` vlož:

```lua
--- Objevené město: sběr daru z překladišť; po dodání celého daru převzetí silou překladišť
--- (bez překladiště silou, která město objevila).
local function process_gift(town)
  depots.collect(town, { { requirements = town.gift, progress = town.progress } })
  if milestones.complete(town.gift, town.progress) then
    M.take_over(town, depots.owner_force(town) or game.forces[town.force])
  else
    M.refresh_boards(town)
  end
end
```

a na začátek `M.process` za `if not town.hall.valid then return end`:

```lua
  if town.state ~= "partner" then
    if town.state == "discovered" then process_gift(town) end
    return
  end
```

- [ ] **Step 6: `scripts/depots.lua`.** Nad `M.resolve` vlož:

```lua
--- Město, ke kterému se překladiště může připojit přes budovu other (nil = nemůže): radnice nebo aktivní dům
--- partnerského města; objevená cizí radnice jen kvůli daru (zboží, kapaliny, tabule – rozvodna ne).
local function anchor_town(depot, other)
  local node = storage.nodes[other.unit_number]
  if node then return anchors(node) and node.town or nil end
  local id = storage.wild_halls[other.unit_number]
  local town = id and storage.towns[id]
  if town and town.state == "discovered" and depot.kind ~= "power" then return id end
  return nil
end
```

V `M.resolve` nahraď výběr kotvy (od `local best, best_gap` po `depot.town = best and best.town`):

```lua
  local best_town, best_gap
  local found = entity.surface.find_entities_filtered({ area = geometry.expand(box, levels.DEPOT_REACH), name = network.names() })
  for _, other in pairs(found) do
    local town_id = anchor_town(depot, other)
    if town_id then
      local gap = geometry.gap(box, other.selection_box)
      if gap <= levels.DEPOT_REACH and (not best_town or gap < best_gap or (gap == best_gap and town_id < best_town)) then
        best_town, best_gap = town_id, gap
      end
    end
  end
  local old = depot.town
  depot.town = best_town
```

Docstring `M.resolve` uprav na „Přiřadí překladiště k městu nejbližší kotvy v dosahu (remíza → nižší id města) a přepočte elektřinu.“ (beze změny smyslu). Na konec modulu (před `return M`) přidej:

```lua
--- Síla překladišť města (první podle unit_number, tabule se nepočítá), nebo nil.
function M.owner_force(town)
  local keys = {}
  for key in pairs(town.depots) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local depot = storage.depots[key]
    if depot and depot.kind ~= "board" and depot.entity.valid then return depot.entity.force end
  end
  return nil
end
```

- [ ] **Step 7: `scripts/remote.lua`.** Nahoru `local config = require("scripts.config")`; do rozhraní přidej:

```lua
  --- Založí neobjevené město s neutrální radnicí (testy); vrací id, nebo nil.
  create_wild_town = function(surface_name, position)
    local hall = game.surfaces[surface_name].create_entity({ name = config.hall_name(1), position = position, force = "neutral" })
    return hall and towns.register_wild(hall).id
  end,
  --- Objeví neobjevené město za sílu (jako by k němu došel hráč).
  discover = function(id, force_name)
    local t = town(id)
    if t and t.state == "wild" then towns.discover(t, game.forces[force_name or "player"]) end
  end,
  --- Seznam měst { id, state, surface, position, force } (testy generátoru).
  list_towns = function()
    local list = {}
    for id, t in pairs(storage.towns) do
      if t.hall.valid then
        list[#list + 1] = { id = id, state = t.state, surface = t.hall.surface.name, position = t.position,
          force = t.hall.force.name }
      end
    end
    return list
  end,
```

- [ ] **Step 8: `control.lua`.** V `on_object_destroyed` přidej větev před `elseif key and storage.depots[key]`:

```lua
  elseif key and storage.wild_halls[key] then
    towns.remove_wild(key)
```

V `on_configuration_changed` nahraď smyčku přes města:

```lua
  for _, town in pairs(storage.towns) do
    -- Neobjevená města se nezpracovávají; objevená jen kvůli daru.
    if town.hall.valid and town.state ~= "wild" then
      towns.refresh(town)
      scheduler.schedule(town, game.tick + 1)
    end
  end
```

- [ ] **Step 9: Locale zpráv** – sekce `[rt]` v `en`:

```
town-discovered=The people of __1__ greet you with curiosity. As a sign of friendship they ask for a small gift – build a goods or fluid depot next to their town hall. __2__
town-partnered=__1__ accepts your gift. The partnership is sealed – their scholars are getting to work.
```

v `cs`:

```
town-discovered=Obyvatelé města __1__ tě zvědavě vítají. Na znamení přátelství žádají malý dar – postav u jejich radnice překladiště zboží nebo kapalin. __2__
town-partnered=__1__ přijímá tvůj dar. Partnerství je uzavřené – jejich učenci se dávají do práce.
```

- [ ] **Step 10: Run tests**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla`
Expected: vše PASS včetně 4 testů `takeover` a nového testu `test_state`.

- [ ] **Step 11: Commit**

```bash
git add research-towns tests
git commit -m "feat: neobjevená a objevená města, dar za partnerství a převzetí"
```

---

### Task 4: Generování měst na Nauvisu a první město

**Files:**
- Create: `research-towns/scripts/worldgen.lua`
- Modify: `research-towns/control.lua` (`on_init`, `on_configuration_changed`, `on_chunk_generated`)
- Create: `tests/research-towns-tests/cases/worldgen.lua`
- Modify: `tests/research-towns-tests/control.lua` (registrace `cases.worldgen`)

**Interfaces:**
- Consumes: `shared/worldgen.lua` (Task 1), `towns.register_wild`, `towns.create` (Task 3), remote `list_towns` (Task 3).
- Produces (`scripts/worldgen.lua`): `M.SURFACE = "nauvis"`, `M.on_chunk_generated(event)`, `M.replace_site(site: LuaEntity) -> town|nil`, `M.ensure_first_town() -> town|nil`, `M.ensure()` (cease-fire, jednorázové doplnění do rozehrané hry, první město); `storage.worldgen_done`.

- [ ] **Step 1: Write the failing test** – `tests/research-towns-tests/cases/worldgen.lua`:

```lua
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
      H.check(#remote.call(R, "list_towns") == before, "přibyla města: " .. before .. " → " .. #remote.call(R, "list_towns"))
    end } },
  },
}
```

V `tests/research-towns-tests/control.lua` přidej `runner.register(require("cases.worldgen"))`.

- [ ] **Step 2: Run to verify failure**

Run: `bash tools/run-tests.sh vanilla`
Expected: FAIL – na Nauvisu není partnerské město, zůstaly značky.

- [ ] **Step 3: Implementation** – `research-towns/scripts/worldgen.lua`:

```lua
--- Runtime generování měst na Nauvisu: náhrada značek míst měst neutrálními radnicemi, vyčištění okolí,
--- hnízda v pozdějších chuncích, první město u spawnu a doplnění měst do rozehrané hry.
local levels = require("shared.levels")
local worldgen = require("shared.worldgen")
local config = require("scripts.config")
local towns = require("scripts.towns")

local M = {}

--- Povrch s městy.
M.SURFACE = "nauvis"

--- Čtverec kolem středu radnice rozšířený o margin.
local function area_around(position, margin)
  local r = levels.HALL_SIZE / 2 + margin
  return { { position.x - r, position.y - r }, { position.x + r, position.y + r } }
end

--- Odstraní stromy, kameny a útesy v půdorysu radnice a pásu TOWN_CLEAR_MARGIN kolem.
local function clear_ground(surface, position)
  local found = surface.find_entities_filtered({ area = area_around(position, worldgen.TOWN_CLEAR_MARGIN),
    type = { "tree", "simple-entity", "cliff" } })
  for _, entity in pairs(found) do
    if entity.valid then entity.destroy() end
  end
end

--- Zničí hnízda a červy biterů v okruhu TOWN_NEST_CLEAR kolem pozice (jen ve vygenerovaných chuncích);
--- area omezí hledání na nový chunk.
local function clear_nests(surface, position, area)
  local spec = { force = "enemy", type = { "unit-spawner", "turret" } }
  if area then spec.area = area else spec.position, spec.radius = position, worldgen.TOWN_NEST_CLEAR end
  for _, entity in pairs(surface.find_entities_filtered(spec)) do
    local dx, dy = entity.position.x - position.x, entity.position.y - position.y
    if entity.valid and dx * dx + dy * dy <= worldgen.TOWN_NEST_CLEAR ^ 2 then entity.destroy() end
  end
end

--- Nahradí značku místa města neutrální radnicí a zaeviduje neobjevené město.
--- @return table|nil město
function M.replace_site(site)
  local surface, position = site.surface, site.position
  site.destroy()
  clear_ground(surface, position)
  local hall = surface.create_entity({ name = config.hall_name(1), position = position, force = "neutral" })
  if not hall then return nil end
  local town = towns.register_wild(hall)
  clear_nests(surface, position)
  return town
end

--- Nový chunk na Nauvisu: značky → radnice; hnízda v chunku blízko známých měst se odstraní.
function M.on_chunk_generated(event)
  local surface = event.surface
  if surface.name ~= M.SURFACE then return end
  for _, site in pairs(surface.find_entities_filtered({ area = event.area, name = worldgen.SITE })) do
    if site.valid then M.replace_site(site) end
  end
  for _, key in ipairs(worldgen.cell_keys_around(event.area, worldgen.TOWN_NEST_CLEAR)) do
    for id in pairs(storage.town_cells[key] or {}) do
      local town = storage.towns[id]
      if town then clear_nests(surface, town.position, event.area) end
    end
  end
end

--- Je kandidát vhodné místo prvního města? (souš, bez útesů a hráčových staveb, daleko od jiných radnic)
local function first_site_ok(surface, position)
  local area = area_around(position, 1)
  if surface.count_tiles_filtered({ area = area, collision_mask = "water_tile" }) > 0 then return false end
  if surface.count_entities_filtered({ area = area, type = "cliff" }) > 0 then return false end
  if surface.count_entities_filtered({ area = area, force = "player" }) > 0 then return false end
  -- Značky ještě nenahrazené radnicí (chunk se právě generuje) se počítají jako radnice.
  local names = config.hall_names()
  names[#names + 1] = worldgen.SITE
  return surface.count_entities_filtered({ position = position, radius = worldgen.FIRST_TOWN_GAP, name = names }) == 0
end

--- Postaví první (partnerské) město 100–200 dlaždic od spawnu, pokud síla player žádné partnerské město nemá.
--- @return table|nil město
function M.ensure_first_town()
  local surface = game.surfaces[M.SURFACE]
  if not surface then return nil end
  local force = game.forces.player
  for _, town in pairs(storage.towns) do
    if town.state == "partner" and town.hall.valid and town.hall.force == force then return nil end
  end
  local spawn = force.get_spawn_position(surface)
  for _, position in ipairs(worldgen.first_town_candidates(spawn, surface.map_gen_settings.seed)) do
    surface.request_to_generate_chunks(position, 1)
    surface.force_generate_chunk_requests()
    if first_site_ok(surface, position) then
      clear_ground(surface, position)
      local town = towns.create(surface, position, force)
      if town then
        clear_nests(surface, position)
        return town
      end
    end
  end
  log("research-towns: první město se nepodařilo umístit")
  return nil
end

--- Biteři neútočí na neutrální města; jednou za hru doplní města do už vygenerovaných chunků (mod přidaný
--- do rozehrané hry) a postaví první město. again = true zopakuje doplnění (testy).
function M.ensure(again)
  game.forces.enemy.set_cease_fire("neutral", true)
  if storage.worldgen_done and not again then return end
  storage.worldgen_done = true
  local surface = game.surfaces[M.SURFACE]
  if not surface then return end
  surface.regenerate_entity({ worldgen.SITE })
  for _, site in pairs(surface.find_entities_filtered({ name = worldgen.SITE })) do
    if site.valid then M.replace_site(site) end
  end
  M.ensure_first_town()
end

return M
```

- [ ] **Step 4: Wire into `control.lua`.** Nahoru `local worldgen = require("scripts.worldgen")`. Události:

```lua
script.on_event(defines.events.on_chunk_generated, worldgen.on_chunk_generated)
```

`script.on_init` doplň na:

```lua
script.on_init(function()
  state.init()
  worldgen.ensure()
  gui.rebuild_all()
end)
```

a v `on_configuration_changed` přidej `worldgen.ensure()` před `gui.rebuild_all()`.
Do `scripts/remote.lua` přidej (s `local worldgen = require("scripts.worldgen")` nahoře):

```lua
  --- Zopakuje doplnění měst do vygenerovaných chunků a první město (testy rozehrané hry).
  worldgen_ensure = function(again)
    worldgen.ensure(again)
  end,
```

- [ ] **Step 5: Run tests**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla`
Expected: vše PASS včetně 3 testů `worldgen`. Pokud „neutrálních měst“ < 2, zkontroluj náhled mapy z Task 2 Step 7.

- [ ] **Step 6: Commit**

```bash
git add research-towns tests
git commit -m "feat: generování měst na Nauvisu, první město a doplnění do rozehrané hry"
```

---

### Task 5: Objevení hráčem a panel cizího města

**Files:**
- Create: `research-towns/scripts/discovery.lua`
- Modify: `research-towns/control.lua` (`on_nth_tick`)
- Modify: `research-towns/scripts/gui.lua` (`town_of`, `fill`)
- Modify: `research-towns/locale/en/locale.cfg`, `research-towns/locale/cs/locale.cfg`

**Interfaces:**
- Consumes: `towns.discover` (Task 3), `storage.wild_halls`, `worldgen.DISCOVERY_RADIUS` (Task 1), stav `status.state` (Task 3).
- Produces (`scripts/discovery.lua`): `M.CHECK_TICKS = 60`, `M.check()`.

- [ ] **Step 1: `scripts/discovery.lua`**

```lua
--- Objevení měst hráči: jednou za CHECK_TICKS hledá u každého připojeného hráče neobjevené radnice v okruhu.
--- Neobjevených měst může být hodně, ale hledá se jen v okolí hráčů (filtr na sílu neutral).
local levels = require("shared.levels")
local worldgen = require("shared.worldgen")
local config = require("scripts.config")
local towns = require("scripts.towns")

local M = {}

--- Jak často se kontroluje blízkost hráčů (ticky).
M.CHECK_TICKS = 60

--- Objeví neobjevená města v dosahu připojených hráčů.
function M.check()
  local radius = worldgen.DISCOVERY_RADIUS + levels.HALL_SIZE / 2
  for _, player in pairs(game.connected_players) do
    local halls = player.surface.find_entities_filtered({ position = player.position, radius = radius,
      name = config.hall_name(1), force = "neutral" })
    for _, hall in pairs(halls) do
      local id = storage.wild_halls[hall.unit_number]
      local town = id and storage.towns[id]
      if town and town.state == "wild" then towns.discover(town, player.force) end
    end
  end
end

return M
```

V `control.lua`: `local discovery = require("scripts.discovery")` a `script.on_nth_tick(discovery.CHECK_TICKS, discovery.check)`
(60 se nekryje s `TOWN_INTERVAL` 120 ani `REFRESH_TICKS` 30 – `on_nth_tick` se stejným číslem by se přepsal).

- [ ] **Step 2: GUI** – v `scripts/gui.lua` nahraď `town_of`:

```lua
--- Město otevřené radnice (partnerské i cizí), nebo nil.
local function town_of(entity)
  if not (entity and entity.valid) then return nil end
  local node = storage.nodes[entity.unit_number]
  if node then return node.kind == "hall" and storage.towns[node.town] or nil end
  local id = storage.wild_halls[entity.unit_number]
  return id and storage.towns[id]
end
```

Ve `fill` za `local status = towns.status(town)` vlož:

```lua
  -- Cizí město ukazuje jen dar; partnerské vrátí viditelnost sekcí.
  local partner = status.state == "partner"
  for _, key in ipairs({ n.houses, n.power, n.house_header, n.house_requirements, n.upkeep_status, n.upkeep, n.upgrade }) do
    frame[key].visible = partner
  end
  if not partner then
    frame[n.productivity].visible = false
    frame[n.level].caption = { "rt.gui-gift-hint" }
    set_header(frame[n.level_header], { "rt.gui-gift" }, status.level_progress)
    fill_slots(frame[n.requirements], requirement_slots(status.requirements))
    return
  end
```

- [ ] **Step 3: Locale** – sekce `[rt]` v `en`:

```
gui-gift=Gift for the partnership
gui-gift-hint=Build a goods or fluid depot next to the town hall and deliver the gift.
```

v `cs`:

```
gui-gift=Dar na znamení partnerství
gui-gift-hint=Postav u radnice překladiště zboží nebo kapalin a dodej dar.
```

- [ ] **Step 4: Run tests**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla`
Expected: vše PASS (headless nemá hráče – objevení pokrývá remote `discover`; `test_gui_names` hlídá jména).

- [ ] **Step 5: Commit**

```bash
git add research-towns
git commit -m "feat: objevení města hráčem a panel s darem u cizího města"
```

---

### Task 6: Počet měst – test varianty `worldgen`

**Files:**
- Create: `tests/research-towns-tests/cases/worldgen_count.lua`
- Modify: `tests/research-towns-tests/control.lua`
- Modify: `tools/run-tests.sh`

**Interfaces:**
- Consumes: `shared/worldgen.lua` (`CONTROL`, `SITE`), prototypy z Task 2.

- [ ] **Step 1: Test** – `tests/research-towns-tests/cases/worldgen_count.lua`:

```lua
--- Pomalý test (jen `tools/run-tests.sh worldgen`): při nejnižší četnosti aspoň 20 měst do 1500 dlaždic.
--- Počítá značky na vlastních površích – skript je nahrazuje radnicemi jen na Nauvisu.
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
```

V `tests/research-towns-tests/control.lua` přidej `runner.register(require("cases.worldgen_count"))`.

- [ ] **Step 2: `tools/run-tests.sh`** – v hlavičce doplň do „Použití“ řádek
`#          tools/run-tests.sh worldgen               pomalý test počtu měst (nejnižší četnost, okruh 1500)`.
Za blok `if [ "$VARIANT" = "mods" ]; then … fi` přidej:

```bash
# Pomalý test počtu měst jen ve variantě worldgen; ostatní varianty ho vynechají.
if [ "$VARIANT" = "worldgen" ]; then
  sed -i '/runner.register/{/cases.worldgen_count/!d}' "$RUN/mods/research-towns-tests/control.lua"
else
  sed -i '/cases.worldgen_count/d' "$RUN/mods/research-towns-tests/control.lua"
fi
```

Aby byly vidět počty měst (setup běží při `--create`), přidej před poslední řádek skriptu
(`grep -q "RT-TEST DONE …"`) řádek:

```bash
grep -ahE "RT-TEST INFO" "$RUN/create.log" "$RUN/bench.log" | sed "s/.*RT-TEST/RT-TEST/" || true
```

- [ ] **Step 3: Run**

Run: `bash tools/run-tests.sh worldgen` (trvá déle – generuje 3 × ~9 000 chunků)
Expected: `RT-TEST INFO seed …` pro 3 seedy, `RT-TEST DONE pass=1 fail=0`.
Pokud některý seed < 20: sniž `TOWN_CELL_MAX` v `shared/worldgen.lua` (např. 400); unit test `cell_size`
počítá s konstantou, takže ho měnit netřeba.
Run: `bash tools/run-tests.sh vanilla` – počet testů se nezměnil (worldgen_count vynechaný).

- [ ] **Step 4: Commit**

```bash
git add tests tools/run-tests.sh research-towns/shared/worldgen.lua
git commit -m "test: varianta worldgen ověřuje minimum měst při nejnižší četnosti"
```

---

### Task 7: Texty, tipy, dokumentace, kompatibilita

**Files:**
- Modify: `research-towns/prototypes/tips.lua`, `research-towns/locale/en/locale.cfg`, `research-towns/locale/cs/locale.cfg`
- Modify: `research-towns/changelog.txt`, `docs/user-guide.md`, `docs/development.md`

- [ ] **Step 1: Tipy a triky** – v `prototypes/tips.lua` přidej položku za `rt-towns`:

```lua
  { type = "tips-and-tricks-item", name = "rt-exploring", category = "rt-towns", order = "b2", indent = 1, starting_status = "unlocked" },
```

Locale `en` – `[tips-and-tricks-item-name]` `rt-exploring=Finding towns`; `[tips-and-tricks-item-description]`:

```
rt-exploring=Towns are scattered across Nauvis – you can see them on the map and choose how many there are when creating a map ([entity=rt-town-hall-1] Towns). The first town lies close to your landing site and welcomes you right away.\n\nWhen you reach another town, its people greet you and ask for a gift. Deliver it through a [entity=rt-goods-depot] depot next to their town hall and the town becomes your partner.
```

`cs` – `rt-exploring=Hledání měst` a:

```
rt-exploring=Města jsou roztroušená po Nauvisu – uvidíš je na mapě a jejich četnost zvolíš při tvorbě mapy ([entity=rt-town-hall-1] Města). První město leží blízko místa přistání a přivítá tě hned.\n\nKdyž dojdeš k dalšímu městu, obyvatelé tě pozdraví a požádají o dar. Dodej ho přes [entity=rt-goods-depot] překladiště u jejich radnice a město se stane tvým partnerem.
```

- [ ] **Step 2: Changelog** – do sekce `Version: 0.1.0` → `Features:` přidej:

```
    - Towns are placed by the map generator (Towns slider, visible in the map preview); the first town near the spawn is your partner right away.
    - Other towns are discovered by walking up to them; deliver a gift through a depot to make them partners.
```

- [ ] **Step 3: `docs/user-guide.md`** – bod 1 doplň a nahraď poslední odstavec o ladicím příkazu:

```
0. **Města na mapě:** při tvorbě mapy zvolíš četnost měst (posuvník Města). První město je 100–200 dlaždic
   od místa přistání a je hned tvoje. K dalším městům dojdi – obyvatelé tě přivítají a požádají o dar
   (suroviny, které už vyrábíš). Dodej ho přes překladiště u jejich radnice a město se stane partnerem.
```

(vlož před bod 1) a řádek „Ladicí příkaz … Generování měst na mapě přijde v další verzi.“ nahraď
„Ladicí příkaz: `/rt-create-town` (admin) založí radnici severně od hráče.“

- [ ] **Step 4: `docs/development.md`** – do tabulky „Kde ladit hodnoty“ přidej řádek:

```
| Rozmístění měst, dar, objevení, první město | `shared/worldgen.lua` → `TOWN_CELL_BASE`, `TOWN_CELL_MAX`, `TOWN_CELL_MARGIN`, `TOWN_SPAWN_CLEAR`, `TOWN_NEST_CLEAR`, `DISCOVERY_RADIUS`, `GIFT_SHARE`, `FIRST_TOWN_*` |
```

do sekce testů řádek `- \`bash tools/run-tests.sh worldgen\` – pomalý test minima měst (nejnižší četnost, 3 seedy).`
a do „Ruční kontrola ve hře“ nové body:

```
13. Nová mapa: v okně generátoru posuvník „Města“, v náhledu mapy oranžové tečky měst; četnost mění jejich počet.
14. Start hry: první město 100–200 dlaždic od přistání, partnerské, se jménem na mapě.
15. Dojít k cizímu městu: zpráva s GPS, značka na mapě, panel radnice ukazuje dar; překladiště u radnice dar
    sebere, po dodání zpráva o partnerství, radnice začne zkoumat s elektřinou, domy se připojí.
16. Rozehraný save bez měst (mod přidaný později): po načtení přibudou města i první město.
```

- [ ] **Step 5: Všechny varianty testů**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla && bash tools/run-tests.sh space-age`
Expected: vše PASS.
Run: `bash tools/run-tests.sh mods boblibrary boblogistics` a `bash tools/run-tests.sh mods pymodpack` (mody ze `%APPDATA%/Factorio/mods`)
Expected: `compat` testy PASS (včetně „generátor mapy: posuvník Města…“). Výsledek (datum, verze) zapiš do `docs/development.md` do sekce kompatibility.

- [ ] **Step 6: Commit**

```bash
git add research-towns docs
git commit -m "docs: hledání měst – tipy, návod, changelog a ruční kontrola"
```
