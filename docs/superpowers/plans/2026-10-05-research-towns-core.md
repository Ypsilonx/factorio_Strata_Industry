# Research Towns – jádro (v0.1, plán 1/3) – implementační plán

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hratelné jádro modu `research-towns`: radnice (laboratoř 15×15, úrovně 1–5) zkoumá místo laboratoří, domy tvoří síť města (max. 5 v sérii) a dávají bonus, překladiště dodávají suroviny/kapaliny pro milníky a elektřinu, povýšení tlačítkem v GUI. Vše kompatibilní s overhauly (vědy, suroviny i laboratoře odvozené z `data.raw`).

**Architecture:** Data stage: v `data-final-fixes.lua` čisté funkce nad `data.raw` rozdělí vědy do úrovní, vyřeší kandidáty surovin milníků, odstraní všechny laboratoře a vytvoří 5 prototypů radnice; výsledek jde do runtime přes `mod-data`. Runtime: síť města je vlastní graf ve `storage` (čistá logika v `scripts/graph.lua`), města se zpracují plánovačem jednou za 120 ticků, bonus k rychlosti dává skrytý beacon s moduly. Města v tomto plánu zakládá remote/příkaz – generátor mapy, převzetí a ruiny jsou **plán 2**, grafika z Blenderu a vydání **plán 3**.

**Tech Stack:** Lua (Factorio 2.0.77 API), sumneko.lua + FMTK ve VSCode, Lua 5.3 pro unit testy čisté logiky, headless Factorio (`--create` + `--benchmark`), Git Bash skripty.

**Spec:** `docs/superpowers/specs/2026-10-05-research-towns-design.md`

## Global Constraints

- Interní jméno `research-towns` (složka modu v repu), titul „Research Towns“, autor `Ypsilonx`, licence MIT, verze `0.1.0`, `factorio_version` `"2.0"`, závislost `"base >= 2.0.0"`.
- Prefix `rt`: prototypy `rt-…`, GUI prvky `rt_…`, mod-data `rt-levels`, log tag testů `RT-TEST`, remote interface `research-towns`.
- Testovací mod `research-towns-tests` v `tests/research-towns-tests/`.
- Herní kód běží na Lua 5.2: **žádné** `//`, bitové operátory ani `math.tointeger`; jen `math.floor`.
- Nic natvrdo podle jmen cizího obsahu kromě seznamů kandidátů v `shared/levels.lua`; vše odvozené z obsahu hry v `data-final-fixes.lua`.
- Veškerý stav jen ve `storage`; žádná práce každý tick kromě jednoho vyhledání v `storage.schedule`.
- Komentáře a docstringy česky (každá funkce má `---` docstring), 2 mezery odsazení, `snake_case`.
- Locale `en` i `cs` se stejnou sadou klíčů; žádný text pro hráče natvrdo.
- Commit jen v krocích „Commit“ tohoto plánu (schválení plánu = schválení těchto commitů); push nikdy. Zpráva commitu končí řádky:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` a `Claude-Session: https://claude.ai/code/session_01DKxsrfKeSA4fz3oSMUXVMg`.

## Review Focus

1. **Overhaul s jiným stromem věd** (Pyanodon ~10 věd, Bob's) – každá věda musí skončit v nějaké úrovni a nejvyšší radnice musí umět každý výzkum. → `cases/compat.lua` (Task 4) + běh `mods` v Task 10.
2. **Výzkum spouštěný vyrobením laboratoře** (vanilla `automation-science-pack`) – bez přesměrování hra uvízne na začátku. → unit `test_labs` (Task 3) + integrační test spouštěče (Task 4).
3. **Kapalina vyráběná jen vyprázdněním barelu** nesmí být považována za dostupnou dřív, než je opravdu vyrobitelná. → unit `test_science` „barely se nepočítají“ (Task 3).
4. **Zbourání domu uprostřed řetězu** – zbytek se musí odpojit a překladiště u odpojených domů nesmí dál zásobovat. → `cases/network.lua` + `cases/depots.lua` (Task 6, 7).
5. **Povýšení s balíčky a moduly v radnici** – výměna prototypu nesmí ztratit obsah. → `cases/upgrade.lua` (Task 8).

---

## Mapa souborů

```
research-towns/                     mod (junction do %APPDATA%/Factorio/mods)
  info.json, changelog.txt, data.lua, data-final-fixes.lua, control.lua
  shared/levels.lua                 BALANC: konstanty, úrovně, kandidáti surovin, čisté pomocné funkce
  prototypes/placeholder.lua        čistá: zvětšení/obarvení vanilla grafiky (dočasná grafika)
  prototypes/science.lua            čistá: hloubky výzkumů, pásma věd, dostupnost předmětů, výběr kandidátů
  prototypes/labs.lua               čistá: odstranění laboratoří, přesměrování spouštěčů
  prototypes/group.lua              podskupina předmětů
  prototypes/hall.lua               prototyp radnice dané úrovně (volá data-final-fixes)
  prototypes/house.lua              dům (entita, předmět, recept)
  prototypes/depots.lua             překladiště zboží/kapalin, městská rozvodna
  prototypes/bonus.lua              skrytý beacon + bonusový modul
  scripts/geometry.lua              čistá: mezera mezi obdélníky, rozšíření oblasti
  scripts/graph.lua                 čistá: komponenta grafu, vícezdrojové BFS (město + hloubka)
  scripts/milestones.lua            čistá: postup milníků
  scripts/names.lua                 čistá: jména měst
  scripts/config.lua                runtime čtení mod-data rt-levels
  scripts/state.lua                 inicializace storage
  scripts/scheduler.lua             plánovač měst po ticích
  scripts/network.lua               runtime síť: uzly, vazby, vykreslení chodníků, přepočet
  scripts/depots.lua                runtime překladiště: přiřazení, výběr, elektřina
  scripts/towns.lua                 runtime města: založení, zpracování, bonus, povýšení, popisky
  scripts/gui.lua                   panel u okna radnice
  scripts/remote.lua                remote interface + příkaz /rt-create-town
  locale/en/locale.cfg, locale/cs/locale.cfg
tests/unit/                         run.lua, assert.lua, test_*.lua
tests/research-towns-tests/         info.json, control.lua, runner.lua, helpers.lua, cases/*.lua
tools/                              run-unit.sh, run-tests.sh, link-mod.sh
.vscode/                            settings.json (existuje), tasks.json, extensions.json, launch.json
docs/development.md, docs/user-guide.md, README.md, LICENSE
```

---

### Task 1: Kostra modu, testovací infrastruktura a smoke test

**Files:**
- Create: `research-towns/info.json`, `research-towns/changelog.txt`, `research-towns/data.lua`, `research-towns/data-final-fixes.lua`, `research-towns/control.lua`, `research-towns/locale/en/locale.cfg`, `research-towns/locale/cs/locale.cfg`
- Create (ze šablon skillu `factorio-mod`): `tests/unit/run.lua`, `tests/unit/assert.lua`, `tests/unit/test_locale.lua`, `tests/research-towns-tests/{info.json,control.lua,runner.lua,cases/smoke.lua}`, `tools/{run-unit.sh,run-tests.sh,link-mod.sh}`, `.gitattributes`, `.gitignore`, `.luacheckrc`, `.vscode/tasks.json`, `.vscode/extensions.json`
- Create: `tests/research-towns-tests/helpers.lua`, `.vscode/launch.json`, `LICENSE`
- Modify: `.vscode/settings.json`

**Interfaces:**
- Produces: `bash tools/run-unit.sh` (řádek `UNIT pass=N fail=M`, exit 0 = OK); `bash tools/run-tests.sh vanilla|space-age|mods <mod>…` (řádky `RT-TEST …`, exit 0 = OK).
- Produces: test = `{ name, requires?, setup(ctx)?, steps = { { ticks, run(ctx) } } }`, `ctx = { surface, origin = {x, y} }`; `runner.register(list)`.
- Produces: `helpers.lua` – `H.REMOTE`, `H.place(ctx, name, dx, dy, extra) → LuaEntity`, `H.check(cond, msg)`, `H.power(ctx, dx, dy) → LuaEntity` (rozvodna), další funkce doplní Task 6–8.

- [ ] **Step 1: Zkopírovat šablony a nahradit zástupné řetězce**

```bash
cd /d/61_Programing/factorio_Strata_Industry
T="$HOME/.claude/skills/factorio-mod/templates"
mkdir -p tests/unit tests/research-towns-tests/cases tools .vscode
cp "$T"/tests/unit/*.lua tests/unit/
cp "$T"/tests/integration/{runner.lua,control.lua,info.json} tests/research-towns-tests/
cp "$T"/tests/integration/cases/smoke.lua tests/research-towns-tests/cases/
cp "$T"/tools/{run-unit.sh,run-tests.sh,link-mod.sh} tools/
cp "$T"/{.gitattributes,.gitignore,.luacheckrc} .
cp "$T"/vscode/{tasks.json,extensions.json} .vscode/
grep -rl "__MOD_NAME__\|__TEST_MOD__\|__TAG__\|__TAG_LOWER__\|__MOD_TITLE__" tests tools .vscode | xargs sed -i \
  -e 's/__MOD_NAME__/research-towns/g' -e 's/__TEST_MOD__/research-towns-tests/g' \
  -e 's/__TAG_LOWER__/rt/g' -e 's/__TAG__/RT/g' -e 's/__MOD_TITLE__/Research Towns/g'
grep -rn "__MOD_\|__TAG\|__TEST_MOD" tests tools .vscode || echo "zástupné řetězce nahrazeny"
grep -c "__PATH__executable__" tools/run-tests.sh
```

Expected: „zástupné řetězce nahrazeny“ a `1` (token Factoria `__PATH__executable__` zůstal).

- [ ] **Step 2: Upravit runner na velké výřezy (radnice 15×15 + řetěz domů)**

V `tests/research-towns-tests/runner.lua` nahradit v `M.on_init` generování chunků a výpočet počátku:

```lua
  surface.request_to_generate_chunks({ 0, 0 }, 12)
```

```lua
    -- Výřez 96×96 dlaždic: radnice 15×15 uprostřed, řetěz domů sahá do +38 dlaždic.
    local origin = { x = ((index - 1) % 6) * 96 - 288, y = math.floor((index - 1) / 6) * 96 - 288 }
```

- [ ] **Step 3: Napsat mod (info.json, changelog, prázdné stage soubory, locale)**

`research-towns/info.json`:

```json
{
  "name": "research-towns",
  "version": "0.1.0",
  "title": "Research Towns",
  "author": "Ypsilonx",
  "factorio_version": "2.0",
  "description": "Labs are gone. Research happens in town halls of towns you supply with science packs, goods, fluids and power. Compatible with overhaul mods.",
  "dependencies": ["base >= 2.0.0"]
}
```

`research-towns/changelog.txt`:

```
---------------------------------------------------------------------------------------------------
Version: 0.1.0
Date: 2026-10-05
  Features:
    - Town halls replace labs; towns level up from goods, fluids and power delivered through depots.
```

`research-towns/data.lua`:

```lua
-- Research Towns – prototypy nezávislé na obsahu jiných modů (doplňují další úkoly).
```

`research-towns/data-final-fixes.lua`:

```lua
-- Research Towns – vše odvozené z obsahu hry (vědy, laboratoře, suroviny milníků); doplní Task 4.
```

`research-towns/control.lua`:

```lua
-- Research Towns – napojení událostí na moduly; logika je ve scripts/ (doplní Task 6).
```

`research-towns/locale/en/locale.cfg`:

```
[mod-name]
research-towns=Research Towns

[mod-description]
research-towns=Labs are gone. Research happens in town halls of towns you supply with science packs, goods, fluids and power.
```

`research-towns/locale/cs/locale.cfg`:

```
[mod-name]
research-towns=Research Towns

[mod-description]
research-towns=Laboratoře nejsou. Zkoumá se v radnicích měst, kterým dodáváš vědecké balíčky, zboží, kapaliny a elektřinu.
```

- [ ] **Step 4: helpers.lua, info.json testovacího modu, VSCode a licence**

`tests/research-towns-tests/helpers.lua`:

```lua
--- Pomocné funkce pro integrační testy: stavění entit, napájení, volání remote rozhraní modu.
local H = {}

--- Jméno remote rozhraní modu.
H.REMOTE = "research-towns"

--- Selže s chybou, pokud podmínka neplatí.
--- @param condition any
--- @param message string
function H.check(condition, message)
  if not condition then error(message, 2) end
end

--- Postaví entitu na dlaždici (dx, dy) relativně k počátku testu; vyvolá script_raised_built.
--- @return LuaEntity
function H.place(ctx, name, dx, dy, extra)
  local spec = {
    name = name,
    position = { ctx.origin.x + dx + 0.5, ctx.origin.y + dy + 0.5 },
    force = "player",
    raise_built = true,
  }
  for key, value in pairs(extra or {}) do spec[key] = value end
  local entity = ctx.surface.create_entity(spec)
  if not entity then error("nelze postavit " .. name, 2) end
  return entity
end

--- Napájí okolí bodu (dx, dy): neomezený zdroj a rozvodna (pokrývá ±9 dlaždic).
--- @return LuaEntity rozvodna (jejím zbouráním test odpojí proud)
function H.power(ctx, dx, dy)
  local source = H.place(ctx, "electric-energy-interface", dx - 4, dy)
  source.power_production = 1e9
  source.electric_buffer_size = 1e10
  return H.place(ctx, "substation", dx, dy)
end

return H
```

`tests/research-towns-tests/info.json` – ze šablony, zkontrolovat obsah:

```json
{
  "name": "research-towns-tests",
  "version": "0.1.0",
  "title": "Research Towns – tests",
  "author": "Ypsilonx",
  "factorio_version": "2.0",
  "dependencies": ["research-towns"]
}
```

`.vscode/settings.json` (zachovat existující klíče `Lua.workspace.*`, doplnit):

```json
{
  "Lua.runtime.version": "Lua 5.2",
  "Lua.diagnostics.globals": ["data", "mods", "settings", "script", "storage", "defines", "game", "prototypes", "helpers", "rendering", "remote", "commands", "log", "serpent", "table_size", "localised_print"],
  "files.encoding": "utf8",
  "Lua.workspace.userThirdParty": [
    "c:\\Users\\cibul\\AppData\\Roaming\\Code\\User\\workspaceStorage\\5cabece8e5d4669bc00fbad05a47d90a\\justarandomgeek.factoriomod-debug\\sumneko-3rd"
  ],
  "Lua.workspace.checkThirdParty": "ApplyInMemory"
}
```

`.vscode/launch.json` (FMTK debugger – hra načte mod přes junction z `tools/link-mod.sh`):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "factoriomod",
      "request": "launch",
      "name": "Factorio – Research Towns",
      "factorioPath": "C:/STEAM/steamapps/common/Factorio/bin/x64/factorio.exe"
    }
  ]
}
```

`LICENSE` – standardní text MIT License, řádek `Copyright (c) 2026 Ypsilonx`.

- [ ] **Step 5: Spustit unit testy a integrační smoke test**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=1 fail=0`

Run: `bash tools/run-tests.sh vanilla && bash tools/run-tests.sh space-age`
Expected: v obou `RT-TEST PASS mod se načte a povrch existuje` a `RT-TEST DONE pass=1 fail=0 skip=0`.

- [ ] **Step 6: Commit**

```bash
git add research-towns tests tools .vscode .gitattributes .gitignore .luacheckrc LICENSE docs
git commit -m "chore: kostra modu research-towns a testovací infrastruktura"
```

---

### Task 2: Balanc úrovní (`shared/levels.lua`)

**Files:**
- Create: `research-towns/shared/levels.lua`
- Create: `tests/unit/test_levels.lua`
- Modify: `tests/unit/run.lua` (SUITES)

**Interfaces:**
- Produces (sdílené data i control stage):
  - konstanty `MAX_LEVEL=5`, `MAX_HOUSE_DEPTH=5`, `HOUSE_REACH=6`, `DEPOT_REACH=4`, `TOWN_INTERVAL=120`, `BONUS_STEP=0.05`, `BONUS_SLOTS=200`, `HALL_SIZE=15`
  - `LEVELS[level] = { researching_speed, house_limit, house_bonus, power_mw, upgrade = { {type, candidates, amount} } | nil }`
  - `get(level) → table`, `hall_name(level) → string`, `hall_level(name) → integer|nil`, `hall_names() → string[]`, `power_per_tick(level) → number` (J/tick), `bonus_modules(level, active_houses) → integer`

- [ ] **Step 1: Napsat failing test**

`tests/unit/test_levels.lua`:

```lua
--- Jednotkové testy balanční tabulky úrovní a pomocných funkcí.
local A = require("assert")
local levels = require("shared.levels")

return {
  { "pět úrovní se všemi poli", function()
    A.eq(#levels.LEVELS, levels.MAX_LEVEL, "počet úrovní")
    for level = 1, levels.MAX_LEVEL do
      local cfg = levels.get(level)
      A.truthy(cfg.researching_speed > 0 and cfg.house_limit > 0 and cfg.house_bonus > 0 and cfg.power_mw > 0,
        "pole úrovně " .. level)
    end
  end },
  { "limity, příkon a rychlost rostou", function()
    for level = 2, levels.MAX_LEVEL do
      local a, b = levels.get(level - 1), levels.get(level)
      A.truthy(b.house_limit > a.house_limit, "limit domů roste " .. level)
      A.truthy(b.power_mw > a.power_mw, "příkon roste " .. level)
      A.truthy(b.researching_speed > a.researching_speed, "rychlost roste " .. level)
    end
  end },
  { "milníky mají všechny úrovně kromě poslední", function()
    for level = 1, levels.MAX_LEVEL - 1 do
      local upgrade = levels.get(level).upgrade
      A.truthy(upgrade and #upgrade > 0, "milník úrovně " .. level)
      for _, req in ipairs(upgrade) do
        A.truthy((req.type == "item" or req.type == "fluid") and #req.candidates > 0 and req.amount > 0,
          "požadavek úrovně " .. level)
      end
    end
    A.eq(levels.get(levels.MAX_LEVEL).upgrade, nil, "poslední úroveň nemá milník")
  end },
  { "jména radnic tam i zpět", function()
    A.eq(levels.hall_name(3), "rt-town-hall-3", "hall_name")
    A.eq(levels.hall_level("rt-town-hall-3"), 3, "hall_level")
    A.eq(levels.hall_level("lab"), nil, "cizí jméno")
    A.eq(#levels.hall_names(), levels.MAX_LEVEL, "hall_names")
  end },
  { "příkon v joulech za tick", function()
    A.eq(levels.power_per_tick(1), levels.get(1).power_mw * 1e6 / 60, "power_per_tick")
  end },
  { "bonusové moduly se stropem limitu domů", function()
    local cfg = levels.get(1)
    A.eq(levels.bonus_modules(1, 0), 0, "bez domů")
    A.eq(levels.bonus_modules(1, cfg.house_limit), math.floor(cfg.house_limit * cfg.house_bonus / levels.BONUS_STEP + 0.5), "na limitu")
    A.eq(levels.bonus_modules(1, cfg.house_limit + 10), levels.bonus_modules(1, cfg.house_limit), "nad limitem")
    local top = levels.get(levels.MAX_LEVEL)
    A.truthy(levels.bonus_modules(levels.MAX_LEVEL, top.house_limit) <= levels.BONUS_SLOTS, "vejde se do beaconu")
  end },
}
```

V `tests/unit/run.lua`: `local SUITES = { "test_locale", "test_levels" }`

- [ ] **Step 2: Ověřit, že test selže**

Run: `bash tools/run-unit.sh`
Expected: chyba `module 'shared.levels' not found`.

- [ ] **Step 3: Implementace**

`research-towns/shared/levels.lua`:

```lua
--- Balanc úrovní měst – jediné místo, kde se ladí čísla. Sdílí ho data stage i control stage.
--- Suroviny milníků jsou seznamy kandidátů: v data-final-fixes vyhraje první existující a dostupný
--- (kompatibilita s overhauly), viz prototypes/science.lua.
local M = {}

--- Počet úrovní města.
M.MAX_LEVEL = 5
--- Nejvýš tolik domů v sérii od radnice (hloubka v grafu sítě).
M.MAX_HOUSE_DEPTH = 5
--- Dosah propojení domů: mezera mezi okraji budov v dlaždicích.
M.HOUSE_REACH = 6
--- Dosah překladiště k nejbližší budově města (mezera mezi okraji).
M.DEPOT_REACH = 4
--- Jak často se město zpracuje (ticky).
M.TOWN_INTERVAL = 120
--- Bonus k rychlosti výzkumu za jeden skrytý modul v beaconu radnice.
M.BONUS_STEP = 0.05
--- Počet slotů skrytého beaconu (strop bonusu = BONUS_SLOTS × BONUS_STEP).
M.BONUS_SLOTS = 200
--- Rozměr radnice v dlaždicích.
M.HALL_SIZE = 15

--- Úrovně: rychlost radnice, limit domů s bonusem, bonus za dům, příkon města a milník na další úroveň.
M.LEVELS = {
  {
    researching_speed = 2, house_limit = 4, house_bonus = 0.10, power_mw = 1,
    upgrade = {
      { type = "item", candidates = { "wood" }, amount = 200 },
      { type = "item", candidates = { "iron-plate" }, amount = 400 },
      { type = "item", candidates = { "copper-plate" }, amount = 200 },
      { type = "item", candidates = { "stone-brick", "stone" }, amount = 200 },
    },
  },
  {
    researching_speed = 4, house_limit = 8, house_bonus = 0.15, power_mw = 4,
    upgrade = {
      { type = "item", candidates = { "steel-plate", "iron-plate" }, amount = 400 },
      { type = "item", candidates = { "electronic-circuit" }, amount = 400 },
      { type = "item", candidates = { "pipe" }, amount = 100 },
      { type = "fluid", candidates = { "water" }, amount = 20000 },
    },
  },
  {
    researching_speed = 6, house_limit = 12, house_bonus = 0.20, power_mw = 15,
    upgrade = {
      { type = "item", candidates = { "plastic-bar" }, amount = 500 },
      { type = "item", candidates = { "advanced-circuit", "electronic-circuit" }, amount = 300 },
      { type = "item", candidates = { "engine-unit" }, amount = 100 },
      { type = "item", candidates = { "concrete", "stone-brick" }, amount = 1000 },
      { type = "fluid", candidates = { "petroleum-gas", "crude-oil" }, amount = 30000 },
    },
  },
  {
    researching_speed = 8, house_limit = 16, house_bonus = 0.25, power_mw = 50,
    upgrade = {
      { type = "item", candidates = { "processing-unit", "advanced-circuit" }, amount = 400 },
      { type = "item", candidates = { "low-density-structure", "plastic-bar" }, amount = 200 },
      { type = "item", candidates = { "electric-engine-unit", "engine-unit" }, amount = 200 },
      { type = "item", candidates = { "refined-concrete", "concrete" }, amount = 1000 },
      { type = "fluid", candidates = { "lubricant", "heavy-oil" }, amount = 30000 },
    },
  },
  {
    researching_speed = 10, house_limit = 20, house_bonus = 0.30, power_mw = 150,
  },
}

--- Parametry úrovně.
--- @param level integer 1..MAX_LEVEL
function M.get(level)
  return M.LEVELS[level]
end

--- Jméno prototypu radnice dané úrovně.
function M.hall_name(level)
  return "rt-town-hall-" .. level
end

--- Úroveň podle jména prototypu radnice, nebo nil pro jinou entitu.
function M.hall_level(name)
  local level = name:match("^rt%-town%-hall%-(%d+)$")
  return level and tonumber(level)
end

--- Jména všech prototypů radnic.
function M.hall_names()
  local names = {}
  for level = 1, M.MAX_LEVEL do names[level] = M.hall_name(level) end
  return names
end

--- Příkon města dané úrovně v joulech za tick.
function M.power_per_tick(level)
  return M.LEVELS[level].power_mw * 1e6 / 60
end

--- Počet skrytých bonusových modulů pro aktivní domy (domy nad limit úrovně se nepočítají).
function M.bonus_modules(level, active_houses)
  local cfg = M.LEVELS[level]
  local counted = math.min(active_houses, cfg.house_limit)
  return math.floor(counted * cfg.house_bonus / M.BONUS_STEP + 0.5)
end

return M
```

- [ ] **Step 4: Ověřit, že testy projdou**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=7 fail=0`

- [ ] **Step 5: Commit**

```bash
git add research-towns/shared tests/unit
git commit -m "feat: balanční tabulka úrovní měst"
```

---

### Task 3: Čistá logika kompatibility – pásma věd, dostupnost surovin, odstranění laboratoří

**Files:**
- Create: `research-towns/prototypes/science.lua`, `research-towns/prototypes/labs.lua`, `research-towns/prototypes/placeholder.lua`
- Create: `tests/unit/test_science.lua`, `tests/unit/test_labs.lua`, `tests/unit/test_placeholder.lua`
- Modify: `tests/unit/run.lua` (SUITES)

**Interfaces:**
- Produces `prototypes/science.lua`:
  - `bands(raw, max_level) → table<pack, level>`
  - `sciences(bands, max_level) → table<level, string[]>` (kumulativně, seřazeno podle pásma a jména)
  - `tech_levels(raw, bands) → table<tech, level>`
  - `availability(raw, tech_levels) → table<"item/<n>"|"fluid/<n>", level>`
  - `exists_in(raw) → fun(type, name): boolean`
  - `resolve(requirements, availability, level, exists) → { {type, name, amount} }, string[]` (vynechané)
- Produces `prototypes/labs.lua`: `lab_items(raw) → set`, `remove(raw, replacement_item) → set` (skryje recepty laboratoří, odebere odemčení, přesměruje spouštěče)
- Produces `prototypes/placeholder.lua`: `scaled(source, factor, tint|nil) → table` (kopie)

- [ ] **Step 1: Napsat failing testy**

`tests/unit/test_science.lua`:

```lua
--- Jednotkové testy odvození věd a dostupnosti surovin z falešného data.raw.
local A = require("assert")
local science = require("prototypes.science")

--- Zkrácený strom: červená → zelená → modrá a vojenská; skrytý výzkum s tajnou vědou.
local function raw()
  local r = { technology = {}, recipe = {}, item = {}, fluid = {}, tool = {}, resource = {}, tree = {}, tile = {} }
  local function tech(name, prerequisites, packs, effects, hidden)
    local ingredients = {}
    for i, pack in ipairs(packs) do ingredients[i] = { pack, 1 } end
    r.technology[name] = { name = name, prerequisites = prerequisites, effects = effects or {},
      unit = { count = 10, time = 5, ingredients = ingredients }, hidden = hidden }
  end
  tech("t-red", {}, { "red" })
  tech("t-green", { "t-red" }, { "red", "green" })
  tech("t-blue", { "t-green" }, { "red", "green", "blue" }, { { type = "unlock-recipe", recipe = "steel" } })
  tech("t-mil", { "t-green" }, { "red", "green", "mil" })
  tech("t-secret", {}, { "secret" }, nil, true)
  r.technology["t-trigger"] = { name = "t-trigger", prerequisites = { "t-blue" }, research_trigger = { type = "craft-item", item = "gear" } }
  for _, name in ipairs({ "steel", "gear", "secret-item", "wood", "iron-ore", "barrel" }) do r.item[name] = { name = name } end
  r.item["hidden-thing"] = { name = "hidden-thing", hidden = true }
  r.fluid.water = { name = "water" }
  r.fluid.lube = { name = "lube" }
  r.recipe.steel = { name = "steel", enabled = false, results = { { type = "item", name = "steel", amount = 1 } } }
  r.recipe.gear = { name = "gear", results = { { type = "item", name = "gear", amount = 1 } } }
  r.recipe.recycle = { name = "recycle", hidden = true, results = { { type = "item", name = "secret-item", amount = 1 } } }
  r.recipe["empty-lube-barrel"] = { name = "empty-lube-barrel", subgroup = "empty-barrel",
    results = { { type = "fluid", name = "lube", amount = 50 }, { type = "item", name = "barrel", amount = 1 } } }
  r.resource["iron-ore"] = { name = "iron-ore", minable = { result = "iron-ore" } }
  r.tree.tree = { name = "tree", minable = { results = { { type = "item", name = "wood", amount = 4 } } } }
  r.tile.water = { name = "water", fluid = "water" }
  return r
end

return {
  { "první věda je úroveň 1, ostatní rovnoměrně 2–5", function()
    local bands = science.bands(raw(), 5)
    A.eq(bands.red, 1, "red")
    A.eq(bands.green, 2, "green")
    A.eq(bands.blue, 3, "blue")
    A.eq(bands.mil, 4, "mil")
    A.eq(bands.secret, nil, "věda skrytého výzkumu")
  end },
  { "vědy úrovní jsou kumulativní", function()
    local list = science.sciences(science.bands(raw(), 5), 5)
    A.eq(table.concat(list[1], ","), "red", "úroveň 1")
    A.eq(table.concat(list[3], ","), "red,green,blue", "úroveň 3")
    A.eq(table.concat(list[5], ","), "red,green,blue,mil", "úroveň 5")
  end },
  { "úroveň výzkumu zahrnuje prerekvizity", function()
    local levels = science.tech_levels(raw(), science.bands(raw(), 5))
    A.eq(levels["t-red"], 1, "t-red")
    A.eq(levels["t-blue"], 3, "t-blue")
    A.eq(levels["t-trigger"], 3, "spouštěný výzkum dědí z prerekvizit")
  end },
  { "dostupnost: recept, výzkum, suroviny ze světa", function()
    local r = raw()
    local avail = science.availability(r, science.tech_levels(r, science.bands(r, 5)))
    A.eq(avail["item/gear"], 1, "recept od začátku")
    A.eq(avail["item/steel"], 3, "recept za výzkumem")
    A.eq(avail["item/iron-ore"], 1, "ruda")
    A.eq(avail["item/wood"], 1, "strom")
    A.eq(avail["fluid/water"], 1, "kapalina z dlaždice")
  end },
  { "skryté recepty a barely se nepočítají", function()
    local r = raw()
    local avail = science.availability(r, science.tech_levels(r, science.bands(r, 5)))
    A.eq(avail["item/secret-item"], nil, "recyklace")
    A.eq(avail["fluid/lube"], nil, "vyprázdnění barelu")
  end },
  { "kandidáti: první dostupný na úrovni, jinak vynechat", function()
    local r = raw()
    local avail = science.availability(r, science.tech_levels(r, science.bands(r, 5)))
    local exists = science.exists_in(r)
    local reqs = {
      { type = "item", candidates = { "steel", "gear" }, amount = 5 },
      { type = "item", candidates = { "missing", "hidden-thing" }, amount = 1 },
      { type = "fluid", candidates = { "water" }, amount = 100 },
    }
    local at2, dropped = science.resolve(reqs, avail, 2, exists)
    A.eq(#at2, 2, "počet vyřešených na úrovni 2")
    A.eq(at2[1].name, "gear", "ocel ještě není dostupná")
    A.eq(at2[2].name, "water", "voda")
    A.eq(dropped[1], "missing|hidden-thing", "vynechaný požadavek")
    local at3 = science.resolve(reqs, avail, 3, exists)
    A.eq(at3[1].name, "steel", "na úrovni 3 ocel")
  end },
  { "stejná surovina se v milníku nezdvojí", function()
    local r = raw()
    local avail = science.availability(r, science.tech_levels(r, science.bands(r, 5)))
    local reqs = {
      { type = "item", candidates = { "gear" }, amount = 5 },
      { type = "item", candidates = { "gear", "wood" }, amount = 5 },
    }
    local out = science.resolve(reqs, avail, 1, science.exists_in(r))
    A.eq(out[2].name, "wood", "druhý požadavek vzal dalšího kandidáta")
  end },
}
```

`tests/unit/test_labs.lua`:

```lua
--- Jednotkové testy odstranění laboratoří a přesměrování spouštěčů výzkumů.
local A = require("assert")
local labs = require("prototypes.labs")

--- Vanilla laboratoř + laboratoř „cizího modu“, výzkumy s odemčením a spouštěči.
local function raw()
  return {
    lab = {
      lab = { name = "lab", minable = { result = "lab" } },
      ["lab-2"] = { name = "lab-2", minable = { results = { { type = "item", name = "lab-2", amount = 1 } } } },
    },
    recipe = {
      lab = { name = "lab", results = { { type = "item", name = "lab", amount = 1 } } },
      ["lab-2"] = { name = "lab-2", enabled = false, results = { { type = "item", name = "lab-2", amount = 1 } } },
      ["copper-cable"] = { name = "copper-cable", results = { { type = "item", name = "copper-cable", amount = 2 } } },
    },
    technology = {
      electronics = { name = "electronics", effects = {
        { type = "unlock-recipe", recipe = "copper-cable" }, { type = "unlock-recipe", recipe = "lab" } } },
      asp = { name = "asp", research_trigger = { type = "craft-item", item = "lab" } },
      table_form = { name = "table_form", research_trigger = { type = "craft-item", item = { name = "lab-2" } } },
      built = { name = "built", research_trigger = { type = "build-entity", entity = "lab-2" } },
      other = { name = "other", research_trigger = { type = "craft-item", item = "copper-cable" } },
    },
  }
end

return {
  { "předměty laboratoří", function()
    local items = labs.lab_items(raw())
    A.truthy(items.lab and items["lab-2"], "lab i lab-2")
  end },
  { "recepty laboratoří skryté a neodemykané", function()
    local r = raw()
    labs.remove(r, "rt-house")
    A.truthy(r.recipe.lab.hidden and r.recipe.lab.enabled == false, "lab skrytý")
    A.truthy(r.recipe["lab-2"].hidden, "lab-2 skrytý")
    A.eq(#r.technology.electronics.effects, 1, "odemčení laboratoře odebráno")
    A.eq(r.technology.electronics.effects[1].recipe, "copper-cable", "ostatní odemčení zůstalo")
  end },
  { "spouštěče s laboratoří přesměrované na dům", function()
    local r = raw()
    labs.remove(r, "rt-house")
    A.eq(r.technology.asp.research_trigger.item, "rt-house", "craft-item")
    A.eq(r.technology.table_form.research_trigger.item, "rt-house", "craft-item s tabulkou")
    A.eq(r.technology.built.research_trigger.item, "rt-house", "build-entity")
    A.eq(r.technology.other.research_trigger.item, "copper-cable", "cizí spouštěč beze změny")
  end },
}
```

`tests/unit/test_placeholder.lua`:

```lua
--- Jednotkové testy zvětšení dočasné vanilla grafiky.
local A = require("assert")
local placeholder = require("prototypes.placeholder")

return {
  { "vrstvy se zvětší, stín se neobarví, originál zůstane", function()
    local source = { layers = { { scale = 0.5, shift = { 1, 2 } }, { scale = 0.5, draw_as_shadow = true } } }
    local tint = { r = 1, g = 0, b = 0 }
    local copy = placeholder.scaled(source, 5, tint)
    A.eq(copy.layers[1].scale, 2.5, "scale")
    A.eq(copy.layers[1].shift[2], 10, "shift")
    A.eq(copy.layers[1].tint, tint, "tint")
    A.eq(copy.layers[2].tint, nil, "stín bez tintu")
    A.eq(source.layers[1].scale, 0.5, "originál beze změny")
  end },
}
```

V `tests/unit/run.lua`: `local SUITES = { "test_locale", "test_levels", "test_science", "test_labs", "test_placeholder" }`

- [ ] **Step 2: Ověřit, že testy selžou**

Run: `bash tools/run-unit.sh`
Expected: chyba `module 'prototypes.science' not found`.

- [ ] **Step 3: Implementace**

`research-towns/prototypes/science.lua`:

```lua
--- Čistá logika nad data.raw (testovaná mimo hru): rozdělení věd do úrovní měst, úroveň výzkumů
--- a dostupnost předmětů/kapalin. Díky tomu mod funguje s libovolným stromem věd (Pyanodon, Bob's, Krastorio).
local M = {}

--- Typy prototypů, které jsou předměty (pro kontrolu existence kandidátů).
local ITEM_TYPES = { "item", "tool", "module", "capsule", "ammo", "item-with-entity-data", "rail-planner", "repair-tool" }
--- Typy entit, jejichž vytěžení dává suroviny ze světa (dostupné od začátku).
local WORLD_TYPES = { "resource", "tree", "simple-entity", "fish" }

--- Je výzkum ve hře použitelný (ne skrytý ani vypnutý)?
local function usable(tech)
  return not tech.hidden and tech.enabled ~= false
end

--- Jméno vědy ze složky výzkumu ({ "pack", 1 } nebo { name = … }).
local function pack_name(ingredient)
  return ingredient[1] or ingredient.name
end

--- Hloubka výzkumů: 1 + nejdelší řetěz prerekvizit.
--- @return table<string, integer>
function M.tech_depths(raw)
  local depth = {}
  local function visit(name)
    if depth[name] then return depth[name] end
    depth[name] = 1 -- ochrana proti cyklu v rozbitém modu
    local d = 1
    for _, prerequisite in ipairs(raw.technology[name].prerequisites or {}) do
      if raw.technology[prerequisite] then d = math.max(d, visit(prerequisite) + 1) end
    end
    depth[name] = d
    return d
  end
  for name in pairs(raw.technology) do visit(name) end
  return depth
end

--- Rozdělí vědy používané výzkumy do úrovní: nejranější věda(y) = 1, ostatní podle pořadí rovnoměrně 2..max.
--- @return table<string, integer> věda → úroveň
function M.bands(raw, max_level)
  local depths = M.tech_depths(raw)
  local tier = {}
  for name, tech in pairs(raw.technology) do
    if usable(tech) and tech.unit then
      for _, ingredient in ipairs(tech.unit.ingredients) do
        local pack = pack_name(ingredient)
        if not tier[pack] or depths[name] < tier[pack] then tier[pack] = depths[name] end
      end
    end
  end
  local packs = {}
  for pack in pairs(tier) do packs[#packs + 1] = pack end
  table.sort(packs, function(a, b)
    if tier[a] ~= tier[b] then return tier[a] < tier[b] end
    return a < b
  end)
  local bands, rest = {}, {}
  for _, pack in ipairs(packs) do
    if tier[pack] == tier[packs[1]] then bands[pack] = 1 else rest[#rest + 1] = pack end
  end
  for rank, pack in ipairs(rest) do
    bands[pack] = math.floor((rank - 1) * (max_level - 1) / #rest) + 2
  end
  return bands
end

--- Vědy, které přijímá radnice každé úrovně (kumulativně, seřazeno podle pásma a jména).
--- @return table<integer, string[]>
function M.sciences(bands, max_level)
  local result = {}
  for level = 1, max_level do
    local list = {}
    for pack, band in pairs(bands) do
      if band <= level then list[#list + 1] = pack end
    end
    table.sort(list, function(a, b)
      if bands[a] ~= bands[b] then return bands[a] < bands[b] end
      return a < b
    end)
    result[level] = list
  end
  return result
end

--- Úroveň města potřebná pro výzkum: nejvyšší pásmo jeho věd i věd všech prerekvizit.
--- @return table<string, integer>
function M.tech_levels(raw, bands)
  local level = {}
  local function visit(name)
    if level[name] then return level[name] end
    level[name] = 1
    local tech = raw.technology[name]
    local l = 1
    if tech.unit then
      for _, ingredient in ipairs(tech.unit.ingredients) do l = math.max(l, bands[pack_name(ingredient)] or 1) end
    end
    for _, prerequisite in ipairs(tech.prerequisites or {}) do
      if raw.technology[prerequisite] then l = math.max(l, visit(prerequisite)) end
    end
    level[name] = l
    return l
  end
  for name in pairs(raw.technology) do visit(name) end
  return level
end

--- Počítá se recept pro dostupnost? (skryté recepty – např. recyklace – a vyprazdňování barelů ne)
local function counts(recipe)
  return not recipe.hidden and recipe.subgroup ~= "empty-barrel"
end

--- Zapíše úroveň k suroviny, pokud je nižší než dosavadní.
local function lower(result, key, level)
  if not result[key] or level < result[key] then result[key] = level end
end

--- Nejnižší úroveň města, od které je předmět/kapalina získatelná (recept nebo svět).
--- @return table<string, integer> klíč "item/<jméno>" | "fluid/<jméno>" → úroveň
function M.availability(raw, tech_levels)
  local unlocks = {}
  for name, tech in pairs(raw.technology) do
    if usable(tech) then
      for _, effect in ipairs(tech.effects or {}) do
        if effect.type == "unlock-recipe" then lower(unlocks, effect.recipe, tech_levels[name]) end
      end
    end
  end
  local result = {}
  for name, recipe in pairs(raw.recipe) do
    if counts(recipe) then
      local level = recipe.enabled ~= false and 1 or unlocks[name]
      if level then
        for _, product in ipairs(recipe.results or {}) do
          lower(result, (product.type or "item") .. "/" .. product.name, level)
        end
      end
    end
  end
  for _, entity_type in ipairs(WORLD_TYPES) do
    for _, entity in pairs(raw[entity_type] or {}) do
      local minable = entity.minable
      if minable then
        if minable.result then lower(result, "item/" .. minable.result, 1) end
        for _, product in ipairs(minable.results or {}) do
          lower(result, (product.type or "item") .. "/" .. product.name, 1)
        end
      end
    end
  end
  for _, tile in pairs(raw.tile or {}) do
    if tile.fluid then lower(result, "fluid/" .. tile.fluid, 1) end
  end
  return result
end

--- Vrátí funkci, která ověří, že předmět/kapalina existuje a není skrytá.
--- @return fun(type: string, name: string): boolean
function M.exists_in(raw)
  return function(kind, name)
    if kind == "fluid" then
      local fluid = raw.fluid[name]
      return fluid ~= nil and not fluid.hidden
    end
    for _, item_type in ipairs(ITEM_TYPES) do
      local item = raw[item_type] and raw[item_type][name]
      if item then return not item.hidden end
    end
    return false
  end
end

--- Vybere pro každý požadavek prvního kandidáta, který existuje a je dostupný nejpozději na dané úrovni.
--- Jedna surovina se v milníku použije jen jednou.
--- @return table[] { {type, name, amount} }, string[] vynechané požadavky (kandidáti spojení „|“)
function M.resolve(requirements, availability, level, exists)
  local out, dropped, used = {}, {}, {}
  for _, req in ipairs(requirements) do
    local chosen
    for _, name in ipairs(req.candidates) do
      local key = req.type .. "/" .. name
      local at = availability[key]
      if not used[key] and exists(req.type, name) and at and at <= level then
        chosen = name
        used[key] = true
        break
      end
    end
    if chosen then
      out[#out + 1] = { type = req.type, name = chosen, amount = req.amount }
    else
      dropped[#dropped + 1] = table.concat(req.candidates, "|")
    end
  end
  return out, dropped
end

return M
```

`research-towns/prototypes/labs.lua`:

```lua
--- Čistá logika nad data.raw: odstranění všech laboratoří (vanilla i z modů) – výzkum přebírají radnice.
local M = {}

--- Jméno ze specifikace předmětu/entity (řetězec nebo { name = … }).
local function id(value)
  if type(value) == "table" then return value.name end
  return value
end

--- Množina předmětů, ze kterých se staví laboratoře.
--- @return table<string, true>
function M.lab_items(raw)
  local items = {}
  for _, lab in pairs(raw.lab or {}) do
    local minable = lab.minable
    if minable then
      if minable.result then items[minable.result] = true end
      for _, product in ipairs(minable.results or {}) do items[product.name] = true end
    end
  end
  return items
end

--- Skryje recepty laboratoří, odebere je z výzkumů a spouštěče „vyrob/postav laboratoř“ přesměruje
--- na vyrobení náhradního předmětu (jinak by např. vanilla výzkum červené vědy nešel spustit).
--- @return table<string, true> předměty laboratoří
function M.remove(raw, replacement_item)
  local items = M.lab_items(raw)
  local hidden = {}
  for name, recipe in pairs(raw.recipe) do
    for _, product in ipairs(recipe.results or {}) do
      if items[product.name] then
        recipe.hidden = true
        recipe.enabled = false
        hidden[name] = true
      end
    end
  end
  for _, tech in pairs(raw.technology) do
    local effects = tech.effects
    if effects then
      for i = #effects, 1, -1 do
        if effects[i].type == "unlock-recipe" and hidden[effects[i].recipe] then table.remove(effects, i) end
      end
    end
    local trigger = tech.research_trigger
    if trigger and ((trigger.type == "craft-item" and items[id(trigger.item)])
        or (trigger.type == "build-entity" and raw.lab[id(trigger.entity)])) then
      tech.research_trigger = { type = "craft-item", item = replacement_item }
    end
  end
  return items
end

return M
```

`research-towns/prototypes/placeholder.lua`:

```lua
--- Dočasná grafika z vanilla sprajtů: zvětšení a obarvení (finální grafika z Blenderu je plán 3).
local M = {}

--- Hluboká kopie tabulky (bez závislosti na util, kvůli testům mimo hru).
local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, inner in pairs(value) do result[key] = copy(inner) end
  return result
end

--- Vrátí kopii animace/spritu zvětšenou faktorem; tint se nepoužije na stíny a světla.
--- @param source table Sprite/Animation (i s `layers`)
--- @param factor number
--- @param tint table|nil
function M.scaled(source, factor, tint)
  local result = copy(source)
  local function visit(node)
    if node.layers then
      for _, layer in ipairs(node.layers) do visit(layer) end
      return
    end
    node.scale = (node.scale or 1) * factor
    if node.shift then node.shift = { node.shift[1] * factor, node.shift[2] * factor } end
    if tint and not node.draw_as_shadow and not node.draw_as_light then node.tint = tint end
  end
  visit(result)
  return result
end

return M
```

- [ ] **Step 4: Ověřit, že testy projdou**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=18 fail=0`

- [ ] **Step 5: Commit**

```bash
git add research-towns/prototypes tests/unit
git commit -m "feat: odvození věd, dostupnosti surovin a odstranění laboratoří z data.raw"
```

---

### Task 4: Prototypy – radnice, domy, překladiště, bonus, mod-data

**Files:**
- Create: `research-towns/prototypes/{group,hall,house,depots,bonus}.lua`
- Modify: `research-towns/data.lua`, `research-towns/data-final-fixes.lua`, obě `locale.cfg`
- Create: `tests/research-towns-tests/cases/prototypes.lua`, `tests/research-towns-tests/cases/compat.lua`
- Modify: `tests/research-towns-tests/control.lua`

**Interfaces:**
- Consumes: `shared/levels.lua` (Task 2), `prototypes/science.lua`, `labs.lua`, `placeholder.lua` (Task 3).
- Produces prototypy: `rt-town-hall-1..5` (lab, bez předmětu, nevytěžitelná), `rt-house` (simple-entity-with-owner 3×3, 5 grafických variant = úroveň; předmět + recept), `rt-goods-depot` (container), `rt-fluid-depot` (storage-tank), `rt-power-depot` (electric-energy-interface), `rt-hall-beacon` (skrytý beacon), `rt-bonus-module` (skrytý modul, speed = `BONUS_STEP`), mod-data `rt-levels` = `{ sciences = { ["1"] = {…}, … }, upgrade = { ["1"] = { {type, name, amount} }, … ["4"] } }`.

- [ ] **Step 1: Napsat failing integrační testy**

`tests/research-towns-tests/cases/compat.lua` (obecné kontroly – běží i s cizími mody):

```lua
--- Obecné kontroly platné s jakýmkoli overhaul modem (pouští je i `tools/run-tests.sh mods …`).
local levels = require("__research-towns__/shared/levels")
local H = require("helpers")

--- Množina z pole.
local function set(list)
  local result = {}
  for _, value in ipairs(list) do result[value] = true end
  return result
end

return {
  { name = "radnice 1–5 existují a vědy s úrovní přibývají", steps = { { ticks = 1, run = function()
    local previous = 0
    for level = 1, levels.MAX_LEVEL do
      local proto = prototypes.entity[levels.hall_name(level)]
      H.check(proto and proto.type == "lab", "chybí radnice " .. level)
      H.check(#proto.lab_inputs >= previous, "úroveň " .. level .. " přijímá méně věd než předchozí")
      previous = #proto.lab_inputs
    end
  end } } },
  { name = "nejvyšší radnice umí všechny vědy výzkumů", steps = { { ticks = 1, run = function()
    local top = set(prototypes.entity[levels.hall_name(levels.MAX_LEVEL)].lab_inputs)
    for name, tech in pairs(prototypes.technology) do
      if tech.enabled and not tech.hidden then
        for _, ingredient in pairs(tech.research_unit_ingredients) do
          H.check(top[ingredient.name], "věda " .. ingredient.name .. " výzkumu " .. name .. " není v žádné úrovni")
        end
      end
    end
  end } } },
  { name = "žádný výzkum neodemyká laboratoř", steps = { { ticks = 1, run = function()
    for name, tech in pairs(prototypes.technology) do
      for _, effect in pairs(tech.effects) do
        if effect.type == "unlock-recipe" then
          for _, product in pairs(prototypes.recipe[effect.recipe].products) do
            local item = prototypes.item[product.name]
            local result = item and item.place_result
            H.check(not (result and result.type == "lab"), "výzkum " .. name .. " odemyká laboratoř " .. product.name)
          end
        end
      end
    end
  end } } },
  { name = "suroviny milníků existují", steps = { { ticks = 1, run = function()
    local data = prototypes.mod_data["rt-levels"].data
    for level = 1, levels.MAX_LEVEL - 1 do
      local upgrade = data.upgrade[tostring(level)]
      H.check(upgrade and #upgrade > 0, "úroveň " .. level .. " nemá milník")
      for _, req in ipairs(upgrade) do
        local found = req.type == "fluid" and prototypes.fluid[req.name] or prototypes.item[req.name]
        H.check(found, "surovina " .. req.name .. " neexistuje")
      end
    end
  end } } },
}
```

`tests/research-towns-tests/cases/prototypes.lua` (vanilla/Space Age specifika):

```lua
--- Kontroly prototypů pro vanillu a Space Age.
local levels = require("__research-towns__/shared/levels")
local H = require("helpers")

return {
  { name = "úroveň 1 přijímá jen červenou vědu, úroveň 2 i zelenou", steps = { { ticks = 1, run = function()
    local first = prototypes.entity[levels.hall_name(1)].lab_inputs
    H.check(#first == 1 and first[1] == "automation-science-pack", "úroveň 1: " .. serpent.line(first))
    local second = prototypes.entity[levels.hall_name(2)].lab_inputs
    local has_green = false
    for _, name in ipairs(second) do has_green = has_green or name == "logistic-science-pack" end
    H.check(has_green, "úroveň 2 bez zelené: " .. serpent.line(second))
  end } } },
  { name = "výzkum červené vědy se spouští vyrobením domu", steps = { { ticks = 1, run = function()
    local trigger = prototypes.technology["automation-science-pack"].research_trigger
    H.check(serpent.line(trigger):find("rt-house", 1, true), "spouštěč: " .. serpent.line(trigger))
    H.check(prototypes.recipe["lab"].hidden, "recept laboratoře není skrytý")
  end } } },
}
```

`tests/research-towns-tests/control.lua`:

```lua
-- Headless integrační testy modu research-towns (spouští tools/run-tests.sh).
local runner = require("runner")

runner.register(require("cases.smoke"))
runner.register(require("cases.compat"))
runner.register(require("cases.prototypes"))

script.on_init(runner.on_init)
script.on_event(defines.events.on_tick, runner.on_tick)
```

- [ ] **Step 2: Ověřit, že testy selžou**

Run: `bash tools/run-tests.sh vanilla`
Expected: `RT-TEST FAIL radnice 1–5 existují…: … chybí radnice 1` (a další FAIL), exit ≠ 0.

- [ ] **Step 3: Prototypy z data.lua**

`research-towns/prototypes/group.lua`:

```lua
--- Podskupina předmětů města v záložce Výroba.
data:extend({ { type = "item-subgroup", name = "rt-town", group = "production", order = "z-rt" } })
```

`research-towns/prototypes/house.lua`:

```lua
--- Dům: jedna entita, úroveň města určuje grafickou variantu (graphics_variation = úroveň).
local levels = require("shared.levels")

--- Odstín variant podle úrovně (dočasná grafika).
local TINTS = {
  { r = 1, g = 1, b = 1 }, { r = 0.8, g = 1, b = 0.8 }, { r = 0.8, g = 0.9, b = 1 },
  { r = 1, g = 0.85, b = 0.6 }, { r = 1, g = 0.7, b = 1 },
}
local ICON = "__base__/graphics/icons/stone-furnace.png"

local pictures = {}
for level = 1, levels.MAX_LEVEL do
  pictures[level] = { filename = ICON, size = 64, scale = 1.5, tint = TINTS[level] }
end

data:extend({
  {
    type = "simple-entity-with-owner",
    name = "rt-house",
    icon = ICON,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.5, result = "rt-house" },
    max_health = 400,
    corpse = "medium-remnants",
    collision_box = { { -1.4, -1.4 }, { 1.4, 1.4 } },
    selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } },
    render_layer = "object",
    pictures = pictures,
  },
  {
    type = "item", name = "rt-house", icon = ICON, subgroup = "rt-town", order = "a",
    place_result = "rt-house", stack_size = 20,
  },
  {
    type = "recipe", name = "rt-house", enabled = true, energy_required = 10,
    ingredients = {
      { type = "item", name = "wood", amount = 10 },
      { type = "item", name = "stone-brick", amount = 20 },
      { type = "item", name = "iron-plate", amount = 10 },
    },
    results = { { type = "item", name = "rt-house", amount = 1 } },
  },
})
```

`research-towns/prototypes/depots.lua`:

```lua
--- Překladiště: zboží (bedna), kapaliny (nádrž) a městská rozvodna (spotřebič elektřiny).
--- Odvozené z vanilla prototypů; skript je přiřadí k nejbližšímu městu.
local placeholder = require("prototypes.placeholder")

local TINT = { r = 0.9, g = 0.75, b = 0.5 }

--- Odvodí prototyp z vanilla entity: nové jméno, vlastní předmět, obarvená ikona, bez upgradů.
local function derive(source, name)
  local entity = table.deepcopy(source)
  entity.name = name
  entity.hidden = nil
  entity.minable = { mining_time = 0.3, result = name }
  entity.icons = { { icon = source.icon, icon_size = source.icon_size, tint = TINT } }
  entity.icon = nil
  entity.fast_replaceable_group = nil
  entity.next_upgrade = nil
  return entity
end

local goods = derive(data.raw.container["iron-chest"], "rt-goods-depot")
goods.inventory_size = 48
goods.picture = placeholder.scaled(goods.picture, 1, TINT)

local fluid = derive(data.raw["storage-tank"]["storage-tank"], "rt-fluid-depot")

local power = derive(data.raw["electric-energy-interface"]["electric-energy-interface"], "rt-power-depot")
power.flags = { "placeable-neutral", "player-creation" }
power.gui_mode = "none"
power.energy_production = "0W"
power.energy_usage = "0W"
-- Odběr (power_usage) a zásobník nastavuje skript podle úrovně města; limit toku jen omezuje špičku.
power.energy_source = {
  type = "electric", usage_priority = "secondary-input",
  buffer_capacity = "1MJ", input_flow_limit = "2GW", output_flow_limit = "0W",
}

--- Předmět a recept překladiště.
local function item_and_recipe(entity, order, ingredients)
  return {
    type = "item", name = entity.name, icons = entity.icons, subgroup = "rt-town", order = order,
    place_result = entity.name, stack_size = 50,
  }, {
    type = "recipe", name = entity.name, enabled = true, energy_required = 2, ingredients = ingredients,
    results = { { type = "item", name = entity.name, amount = 1 } },
  }
end

data:extend({ goods, fluid, power })
data:extend({ item_and_recipe(goods, "b", {
  { type = "item", name = "iron-chest", amount = 2 }, { type = "item", name = "iron-gear-wheel", amount = 5 } }) })
data:extend({ item_and_recipe(fluid, "c", {
  { type = "item", name = "pipe", amount = 10 }, { type = "item", name = "iron-plate", amount = 20 },
  { type = "item", name = "stone-brick", amount = 10 } }) })
data:extend({ item_and_recipe(power, "d", {
  { type = "item", name = "copper-cable", amount = 20 }, { type = "item", name = "iron-plate", amount = 10 },
  { type = "item", name = "stone-brick", amount = 10 } }) })
```

Pozn.: `data:extend` přijímá pole – `item_and_recipe` vrací dvě hodnoty, které tabulkový konstruktor `{ f() }` rozbalí obě.

`research-towns/prototypes/bonus.lua`:

```lua
--- Skrytý beacon uprostřed radnice: počet bonusových modulů = bonus k rychlosti výzkumu za domy.
local levels = require("shared.levels")

local beacon = table.deepcopy(data.raw.beacon["beacon"])
beacon.name = "rt-hall-beacon"
beacon.hidden = true
beacon.minable = nil
beacon.flags = { "not-on-map", "not-blueprintable", "not-deconstructable", "no-copy-paste",
  "not-selectable-in-game", "hide-alt-info", "placeable-off-grid" }
beacon.collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } }
beacon.collision_mask = { layers = {} }
beacon.selection_box = nil
-- Dosah 7 od středu pokryje radnici (±7.4), ale ne sousední stroje (začínají na ±7.5).
beacon.supply_area_distance = math.floor(levels.HALL_SIZE / 2)
beacon.energy_source = { type = "void" }
beacon.energy_usage = "1W"
beacon.module_slots = levels.BONUS_SLOTS
beacon.allowed_module_categories = { "rt-bonus" }
beacon.allowed_effects = { "speed" }
beacon.distribution_effectivity = 1
beacon.distribution_effectivity_bonus_per_quality_level = 0
beacon.profile = { 1 }
beacon.beacon_counter = "same_type"
beacon.graphics_set = nil
beacon.radius_visualisation_picture = nil
beacon.water_reflection = nil
beacon.icons_positioning = nil

data:extend({
  { type = "module-category", name = "rt-bonus" },
  {
    type = "module", name = "rt-bonus-module", icon = "__base__/graphics/icons/speed-module.png",
    hidden = true, subgroup = "rt-town", category = "rt-bonus", tier = 1, stack_size = 200,
    effect = { speed = levels.BONUS_STEP },
  },
  beacon,
})
```

`research-towns/data.lua`:

```lua
-- Research Towns – prototypy nezávislé na obsahu jiných modů.
require("prototypes.group")
require("prototypes.house")
require("prototypes.depots")
require("prototypes.bonus")
```

- [ ] **Step 4: Radnice a odvození z obsahu hry (data-final-fixes)**

`research-towns/prototypes/hall.lua`:

```lua
--- Prototyp radnice: laboratoř 15×15 odvozená z vanilla laboratoře; úroveň mění vědy, rychlost a vzhled.
local levels = require("shared.levels")
local placeholder = require("prototypes.placeholder")

local M = {}

--- Odstín dočasné grafiky podle úrovně.
M.TINTS = {
  { r = 1, g = 1, b = 1 }, { r = 0.8, g = 1, b = 0.8 }, { r = 0.8, g = 0.9, b = 1 },
  { r = 1, g = 0.85, b = 0.6 }, { r = 1, g = 0.7, b = 1 },
}

--- Přidá prototyp radnice dané úrovně.
--- @param level integer
--- @param sciences string[] vědy, které radnice přijímá
function M.create(level, sciences)
  local base = data.raw.lab["lab"]
  local half = levels.HALL_SIZE / 2
  local factor = levels.HALL_SIZE / 3
  local hall = table.deepcopy(base)
  hall.name = levels.hall_name(level)
  hall.icons = { { icon = base.icon, icon_size = base.icon_size, tint = M.TINTS[level] } }
  hall.icon = nil
  hall.flags = { "not-blueprintable", "not-deconstructable", "not-rotatable" }
  hall.minable = nil
  hall.placeable_by = nil
  hall.fast_replaceable_group = nil
  hall.next_upgrade = nil
  hall.max_health = 3000
  hall.collision_box = { { -half + 0.1, -half + 0.1 }, { half - 0.1, half - 0.1 } }
  hall.selection_box = { { -half, -half }, { half, half } }
  hall.on_animation = placeholder.scaled(base.on_animation, factor, M.TINTS[level])
  hall.off_animation = placeholder.scaled(base.off_animation, factor, M.TINTS[level])
  -- Elektřinu města odebírají rozvodny; radnici zapíná/vypíná skript (disabled_by_script).
  hall.energy_source = { type = "void" }
  hall.energy_usage = "1W"
  hall.researching_speed = levels.get(level).researching_speed
  hall.inputs = sciences
  hall.allowed_effects = { "speed", "productivity", "consumption", "pollution" }
  data:extend({ hall })
end

return M
```

`research-towns/data-final-fixes.lua`:

```lua
-- Research Towns – vše odvozené z obsahu hry: odstranění laboratoří, pásma věd, milníky, radnice, mod-data.
-- Běží až po final-fixes modů s „menším“ jménem (např. pypostprocessing), takže vidí konečný strom věd.
local levels = require("shared.levels")
local science = require("prototypes.science")
local labs = require("prototypes.labs")
local hall = require("prototypes.hall")

local removed = labs.remove(data.raw, "rt-house")
local lab_names = {}
for name in pairs(removed) do lab_names[#lab_names + 1] = name end
table.sort(lab_names)
log("research-towns: odstraněné laboratoře: " .. table.concat(lab_names, ", "))

local bands = science.bands(data.raw, levels.MAX_LEVEL)
local sciences = science.sciences(bands, levels.MAX_LEVEL)
local availability = science.availability(data.raw, science.tech_levels(data.raw, bands))
local exists = science.exists_in(data.raw)

local mod_data = { sciences = {}, upgrade = {} }
for level = 1, levels.MAX_LEVEL do
  hall.create(level, sciences[level])
  mod_data.sciences[tostring(level)] = sciences[level]
  log("research-towns: úroveň " .. level .. " vědy: " .. table.concat(sciences[level], ", "))
  local upgrade = levels.get(level).upgrade
  if upgrade then
    local resolved, dropped = science.resolve(upgrade, availability, level, exists)
    mod_data.upgrade[tostring(level)] = resolved
    local names = {}
    for _, req in ipairs(resolved) do names[#names + 1] = req.name .. "×" .. req.amount end
    log("research-towns: milník " .. level .. "→" .. (level + 1) .. ": " .. table.concat(names, ", ")
      .. (#dropped > 0 and (" | vynecháno: " .. table.concat(dropped, ", ")) or ""))
  end
end

data:extend({ { type = "mod-data", name = "rt-levels", data = mod_data } })
```

- [ ] **Step 5: Locale (en + cs)**

Do `research-towns/locale/en/locale.cfg` připsat:

```
[entity-name]
rt-town-hall-1=Town hall (level 1)
rt-town-hall-2=Town hall (level 2)
rt-town-hall-3=Town hall (level 3)
rt-town-hall-4=Town hall (level 4)
rt-town-hall-5=Town hall (level 5)
rt-house=House
rt-goods-depot=Goods depot
rt-fluid-depot=Fluid depot
rt-power-depot=Town substation
rt-hall-beacon=Town research bonus

[entity-description]
rt-town-hall-1=Researches like a lab. Accepts only the science packs of its town level.
rt-town-hall-2=Researches like a lab. Accepts only the science packs of its town level.
rt-town-hall-3=Researches like a lab. Accepts only the science packs of its town level.
rt-town-hall-4=Researches like a lab. Accepts only the science packs of its town level.
rt-town-hall-5=Researches like a lab. Accepts only the science packs of its town level.
rt-house=Connects to a town hall or another house (at most 5 houses in a row). Speeds up research.
rt-goods-depot=Delivers items to the nearest town for its next level.
rt-fluid-depot=Delivers fluids to the nearest town for its next level.
rt-power-depot=Supplies the nearest town with electricity. Without enough power the town hall stops researching.

[item-name]
rt-house=House
rt-goods-depot=Goods depot
rt-fluid-depot=Fluid depot
rt-power-depot=Town substation
rt-bonus-module=Town research bonus
```

Do `research-towns/locale/cs/locale.cfg` připsat:

```
[entity-name]
rt-town-hall-1=Radnice (úroveň 1)
rt-town-hall-2=Radnice (úroveň 2)
rt-town-hall-3=Radnice (úroveň 3)
rt-town-hall-4=Radnice (úroveň 4)
rt-town-hall-5=Radnice (úroveň 5)
rt-house=Dům
rt-goods-depot=Překladiště zboží
rt-fluid-depot=Překladiště kapalin
rt-power-depot=Městská rozvodna
rt-hall-beacon=Výzkumný bonus města

[entity-description]
rt-town-hall-1=Zkoumá jako laboratoř. Přijímá jen vědecké balíčky úrovně svého města.
rt-town-hall-2=Zkoumá jako laboratoř. Přijímá jen vědecké balíčky úrovně svého města.
rt-town-hall-3=Zkoumá jako laboratoř. Přijímá jen vědecké balíčky úrovně svého města.
rt-town-hall-4=Zkoumá jako laboratoř. Přijímá jen vědecké balíčky úrovně svého města.
rt-town-hall-5=Zkoumá jako laboratoř. Přijímá jen vědecké balíčky úrovně svého města.
rt-house=Připojí se k radnici nebo k jinému domu (nejvýš 5 domů v sérii). Zrychluje výzkum.
rt-goods-depot=Dodává předměty nejbližšímu městu pro jeho další úroveň.
rt-fluid-depot=Dodává kapaliny nejbližšímu městu pro jeho další úroveň.
rt-power-depot=Zásobuje nejbližší město elektřinou. Bez dostatku elektřiny radnice nezkoumá.

[item-name]
rt-house=Dům
rt-goods-depot=Překladiště zboží
rt-fluid-depot=Překladiště kapalin
rt-power-depot=Městská rozvodna
rt-bonus-module=Výzkumný bonus města
```

- [ ] **Step 6: Ověřit testy (unit + obě varianty)**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla && bash tools/run-tests.sh space-age`
Expected: `UNIT pass=18 fail=0`; v obou variantách `RT-TEST DONE pass=7 fail=0 skip=0`.
Pokud hra odmítne beacon bez grafiky, nastavit v `bonus.lua` místo `graphics_set = nil` hodnotu `{ animation_list = {} }` a test zopakovat.
Zkontrolovat v `.test-run/vanilla/create.log` řádky `research-towns: úroveň …` a `milník …` (žádné „vynecháno“ ve vanille).

- [ ] **Step 7: Commit**

```bash
git add research-towns tests/research-towns-tests
git commit -m "feat: prototypy radnice, domů, překladišť a bonusu odvozené z obsahu hry"
```

---

### Task 5: Čistá runtime logika – geometrie, graf sítě, milníky, jména

**Files:**
- Create: `research-towns/scripts/{geometry,graph,milestones,names}.lua`
- Create: `tests/unit/{test_geometry,test_graph,test_milestones,test_names}.lua`
- Modify: `tests/unit/run.lua`

**Interfaces:**
- Produces `scripts/geometry.lua`: `gap(a, b) → number` (BoundingBox `{left_top={x,y}, right_bottom={x,y}}`), `expand(box, r) → BoundingBox`
- Produces `scripts/graph.lua`: `component(nodes, start) → set`, `assign(nodes, roots) → table<key, {town, depth}>`; uzel `{ kind = "hall"|"house", links = { [key] = true } }`, `roots = { {key, town} }` seřazené podle `town`
- Produces `scripts/milestones.lua`: `key(type, name)`, `remaining(req, progress)`, `accept(requirements, progress, type, name, available) → number`, `add(progress, type, name, amount)`, `complete(requirements, progress) → boolean`
- Produces `scripts/names.lua`: `generate(n) → string`

- [ ] **Step 1: Napsat failing testy**

`tests/unit/test_geometry.lua`:

```lua
--- Jednotkové testy vzdálenosti mezi obdélníky.
local A = require("assert")
local geometry = require("scripts.geometry")

--- Obdélník z rohů.
local function box(x1, y1, x2, y2)
  return { left_top = { x = x1, y = y1 }, right_bottom = { x = x2, y = y2 } }
end

return {
  { "dotyk a překryv = 0", function()
    A.eq(geometry.gap(box(0, 0, 2, 2), box(2, 0, 4, 2)), 0, "dotyk")
    A.eq(geometry.gap(box(0, 0, 3, 3), box(1, 1, 2, 2)), 0, "překryv")
  end },
  { "mezera do strany a šikmo", function()
    A.eq(geometry.gap(box(0, 0, 2, 2), box(5, 0, 7, 2)), 3, "do strany")
    A.eq(geometry.gap(box(0, 0, 1, 1), box(4, 5, 5, 6)), 5, "šikmo 3-4-5")
  end },
  { "rozšíření oblasti", function()
    local e = geometry.expand(box(0, 0, 2, 2), 3)
    A.eq(e.left_top.x, -3, "left")
    A.eq(e.right_bottom.y, 5, "bottom")
  end },
}
```

`tests/unit/test_graph.lua`:

```lua
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
```

`tests/unit/test_milestones.lua`:

```lua
--- Jednotkové testy postupu milníků.
local A = require("assert")
local milestones = require("scripts.milestones")

local REQS = { { type = "item", name = "wood", amount = 100 }, { type = "fluid", name = "water", amount = 50 } }

return {
  { "přijme jen potřebné a jen do potřeby", function()
    local progress = {}
    A.eq(milestones.accept(REQS, progress, "item", "wood", 30), 30, "část")
    milestones.add(progress, "item", "wood", 30)
    A.eq(milestones.accept(REQS, progress, "item", "wood", 500), 70, "zbytek")
    A.eq(milestones.accept(REQS, progress, "item", "iron-ore", 10), 0, "nepotřebné")
    A.eq(milestones.accept(nil, progress, "item", "wood", 10), 0, "bez milníku")
  end },
  { "splnění s tolerancí kapalin", function()
    local progress = {}
    milestones.add(progress, "item", "wood", 100)
    A.eq(milestones.complete(REQS, progress), false, "chybí voda")
    milestones.add(progress, "fluid", "water", 49.99999)
    A.eq(milestones.complete(REQS, progress), true, "voda v toleranci")
    A.eq(milestones.complete(nil, progress), false, "max. úroveň")
  end },
}
```

`tests/unit/test_names.lua`:

```lua
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
```

V `tests/unit/run.lua` doplnit do SUITES: `"test_geometry", "test_graph", "test_milestones", "test_names"`.

- [ ] **Step 2: Ověřit, že testy selžou**

Run: `bash tools/run-unit.sh`
Expected: chyba `module 'scripts.geometry' not found`.

- [ ] **Step 3: Implementace**

`research-towns/scripts/geometry.lua`:

```lua
--- Čistá geometrie: vzdálenost mezi budovami měřená mezi okraji (dosah jako u sloupů, ale od okraje).
local M = {}

--- Nejmenší vzdálenost mezi okraji dvou obdélníků (0 při dotyku nebo překryvu).
--- @param a BoundingBox
--- @param b BoundingBox
--- @return number
function M.gap(a, b)
  local dx = math.max(0, b.left_top.x - a.right_bottom.x, a.left_top.x - b.right_bottom.x)
  local dy = math.max(0, b.left_top.y - a.right_bottom.y, a.left_top.y - b.right_bottom.y)
  return math.sqrt(dx * dx + dy * dy)
end

--- Obdélník rozšířený o r na všech stranách (oblast pro hledání sousedů).
function M.expand(box, r)
  return {
    left_top = { x = box.left_top.x - r, y = box.left_top.y - r },
    right_bottom = { x = box.right_bottom.x + r, y = box.right_bottom.y + r },
  }
end

return M
```

`research-towns/scripts/graph.lua`:

```lua
--- Čistá logika grafu sítě města: uzly = radnice a domy, vazby = visuté chodníky.
local M = {}

--- Množina klíčů dosažitelných ze startu po vazbách (celá komponenta).
--- @param nodes table<any, {links: table<any, true>}>
--- @return table<any, true>
function M.component(nodes, start)
  local seen, queue, head = { [start] = true }, { start }, 1
  while queue[head] do
    local key = queue[head]
    head = head + 1
    for other in pairs(nodes[key].links) do
      if nodes[other] and not seen[other] then
        seen[other] = true
        queue[#queue + 1] = other
      end
    end
  end
  return seen
end

--- Vícezdrojové BFS od radnic: každý dosažitelný dům dostane město nejbližší radnice a hloubku
--- (radnice = 0). Remízu vyhraje radnice dřív v `roots` (volající řadí podle id města).
--- Přes cizí radnici se nepokračuje.
--- @param roots { {key: any, town: integer} }
--- @return table<any, {town: integer, depth: integer}>
function M.assign(nodes, roots)
  local result, queue, head = {}, {}, 1
  for _, root in ipairs(roots) do
    if nodes[root.key] and not result[root.key] then
      result[root.key] = { town = root.town, depth = 0 }
      queue[#queue + 1] = root.key
    end
  end
  while queue[head] do
    local key = queue[head]
    head = head + 1
    local here = result[key]
    for other in pairs(nodes[key].links) do
      local node = nodes[other]
      if node and node.kind ~= "hall" and not result[other] then
        result[other] = { town = here.town, depth = here.depth + 1 }
        queue[#queue + 1] = other
      end
    end
  end
  return result
end

return M
```

`research-towns/scripts/milestones.lua`:

```lua
--- Čistá logika milníků: kolik suroviny přijmout a zda je milník splněný.
--- progress = { ["item/wood"] = 120, ["fluid/water"] = 5000 }
local M = {}

--- Tolerance pro kapaliny (odebírají se po desetinných částech).
local EPSILON = 1e-3

--- Klíč postupu pro surovinu.
function M.key(kind, name)
  return kind .. "/" .. name
end

--- Kolik ještě chybí z požadavku.
function M.remaining(req, progress)
  return math.max(0, req.amount - (progress[M.key(req.type, req.name)] or 0))
end

--- Kolik z dostupného množství přijmout (0 = surovina není potřeba nebo je splněná).
--- @param requirements table[]|nil nil = město je na nejvyšší úrovni
function M.accept(requirements, progress, kind, name, available)
  for _, req in ipairs(requirements or {}) do
    if req.type == kind and req.name == name then return math.min(available, M.remaining(req, progress)) end
  end
  return 0
end

--- Připíše přijaté množství k postupu.
function M.add(progress, kind, name, amount)
  local key = M.key(kind, name)
  progress[key] = (progress[key] or 0) + amount
end

--- Jsou splněné všechny požadavky? (bez milníku → false)
function M.complete(requirements, progress)
  if not requirements then return false end
  for _, req in ipairs(requirements) do
    if M.remaining(req, progress) > EPSILON then return false end
  end
  return true
end

return M
```

`research-towns/scripts/names.lua`:

```lua
--- Čistá logika jmen měst: deterministická jména z pořadového čísla (stejná pro všechny hráče).
local M = {}

local PREFIXES = { "Iron", "Copper", "Cog", "Gear", "Coal", "Stone", "Ash", "Rust", "Steam", "Brass", "Ember", "Flint" }
local SUFFIXES = { "ford", "ton", "wick", "bury", "dale", "field", "haven", "stead", "holm", "gate", "bridge", "worth" }

--- Jméno n-tého města; krok 37 (nesoudělný se 144) promíchá kombinace, po vyčerpání se přidá číslo.
--- @param n integer 1, 2, …
function M.generate(n)
  local count = #PREFIXES * #SUFFIXES
  local k = ((n - 1) * 37) % count
  local name = PREFIXES[k % #PREFIXES + 1] .. SUFFIXES[math.floor(k / #PREFIXES) + 1]
  local round = math.floor((n - 1) / count)
  if round > 0 then name = name .. " " .. (round + 1) end
  return name
end

return M
```

- [ ] **Step 4: Ověřit, že testy projdou**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=29 fail=0`

- [ ] **Step 5: Commit**

```bash
git add research-towns/scripts tests/unit
git commit -m "feat: čistá logika sítě města, milníků a jmen"
```

---

### Task 6: Runtime – města, síť domů, chodníky, remote rozhraní

**Files:**
- Create: `research-towns/scripts/{config,state,scheduler,network,towns,remote}.lua`
- Modify: `research-towns/control.lua`, obě `locale.cfg`
- Modify: `tests/research-towns-tests/helpers.lua`, `tests/research-towns-tests/control.lua`
- Create: `tests/research-towns-tests/cases/network.lua`

**Interfaces:**
- Consumes: Task 2 (`levels`), Task 5 (`geometry`, `graph`, `names`).
- Produces `storage`: `towns[id] = { id, name, level, hall, beacon, progress, depots = set, houses = set, power_ok, labels, scheduled_tick }`, `nodes[unit] = { key, entity, kind, town, depth, links = set, warning }`, `depots[unit]` (Task 7), `renders["a:b"]`, `schedule[tick]`, `gui[player_index]`, `next_town_id`.
- Produces `scripts/network.lua`: `HOUSE`, `names() → string[]`, `is_active(node) → boolean`, `add(entity, kind, town_id?) → touched`, `remove(key) → touched`, `recompute(keys) → touched`, `rebuild_houses(town)`, `active_houses(town) → integer`, `refresh_town_houses(town)`, `replace_hall(old_key, entity)`; `touched` = `table<town_id, true>`.
- Produces `scripts/towns.lua`: `create(surface, position, force) → town|nil`, `on_network_changed(touched)`, `update_bonus(town)`, `status(town) → table`, `rename(town, name)`, `on_hall_removed(key)`; Task 7/8 doplní `process`, `can_upgrade`, `set_level`, `upgrade`.
- Produces remote `research-towns`: `create_town(surface_name, position, force?) → id|nil`, `town_status(id) → table|nil`, `town_of(unit_number) → id|nil`, `depth_of(unit_number) → integer|nil`; status = `{ id, name, level, hall (unit_number), active_houses, house_limit, bonus, beacon_modules, power_ok, power_watts, requirements = { {type, name, amount, delivered} }, can_upgrade }`.
- Produces helpers: `H.town(ctx) → id`, `H.status(id)`, `H.hall(id) → LuaEntity`, `H.house(ctx, dx, dy)`.

- [ ] **Step 1: Napsat failing integrační testy**

Do `tests/research-towns-tests/helpers.lua` před `return H` připsat:

```lua
--- Založí město s radnicí uprostřed výřezu testu.
--- @return integer id města
function H.town(ctx)
  local id = remote.call(H.REMOTE, "create_town", ctx.surface.name, { x = ctx.origin.x + 0.5, y = ctx.origin.y + 0.5 })
  if not id then error("radnici nelze postavit", 2) end
  return id
end

--- Stav města z remote rozhraní.
function H.status(id)
  return remote.call(H.REMOTE, "town_status", id)
end

--- Entita radnice města.
function H.hall(id)
  return game.get_entity_by_unit_number(H.status(id).hall)
end

--- Postaví dům (3×3) na (dx, dy) od počátku; radnice zabírá -7..+8, dům na dx=11 má mezeru 2.
function H.house(ctx, dx, dy)
  return H.place(ctx, "rt-house", dx, dy)
end
```

`tests/research-towns-tests/cases/network.lua`:

```lua
--- Integrační testy sítě města: připojení domů, hloubka, odpojení, limit bonusu.
local levels = require("__research-towns__/shared/levels")
local H = require("helpers")
local R = H.REMOTE

--- Řetěz domů na ose x: mezera 2 mezi sousedy, nesousedící domy mají mezeru 7 (> dosah 6).
local CHAIN = { 11, 16, 21, 26, 31, 36 }

--- Postaví prvních n domů řetězu.
local function chain(ctx, n)
  ctx.houses = {}
  for i = 1, n do ctx.houses[i] = H.house(ctx, CHAIN[i], 0) end
end

return {
  {
    name = "dům u radnice patří k městu v hloubce 1",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.house = H.house(ctx, 11, 0)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "town_of", ctx.house.unit_number) == ctx.town, "dům nepatří k městu")
      H.check(remote.call(R, "depth_of", ctx.house.unit_number) == 1, "hloubka domu není 1")
      H.check(ctx.house.graphics_variation == 1, "varianta domu není úroveň 1")
    end } },
  },
  {
    name = "šestý dům v sérii je neaktivní",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      chain(ctx, 6)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "depth_of", ctx.houses[6].unit_number) == 6, "hloubka 6. domu")
      local active = H.status(ctx.town).active_houses
      H.check(active == 5, "aktivní domy: " .. active)
    end } },
  },
  {
    name = "zbouráním domu se zbytek řetězu odpojí",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      chain(ctx, 4)
    end,
    steps = {
      { ticks = 1, run = function(ctx) ctx.houses[2].destroy({ raise_destroy = true }) end },
      { ticks = 1, run = function(ctx)
        H.check(remote.call(R, "town_of", ctx.houses[3].unit_number) == nil, "3. dům zůstal připojený")
        H.check(remote.call(R, "town_of", ctx.houses[1].unit_number) == ctx.town, "1. dům se odpojil")
        H.check(H.status(ctx.town).active_houses == 1, "aktivní domy po zbourání")
      end },
    },
  },
  {
    name = "domy nad limit nedávají bonus",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      for _, dy in ipairs({ -6, -2, 2, 6 }) do
        H.house(ctx, 11, dy)
        H.house(ctx, -11, dy)
      end
    end,
    steps = { { ticks = 1, run = function(ctx)
      local s = H.status(ctx.town)
      H.check(s.active_houses == 8, "aktivní domy: " .. s.active_houses)
      local expected = levels.bonus_modules(1, 8)
      H.check(s.beacon_modules == expected, "moduly beaconu: " .. s.beacon_modules .. " ≠ " .. expected)
    end } },
  },
}
```

Do `tests/research-towns-tests/control.lua` přidat `runner.register(require("cases.network"))`.

- [ ] **Step 2: Ověřit, že testy selžou**

Run: `bash tools/run-tests.sh vanilla`
Expected: `RT-TEST FAIL … No such interface: research-towns` (setup), exit ≠ 0.

- [ ] **Step 3: Pomocné moduly – config, state, scheduler**

`research-towns/scripts/config.lua`:

```lua
--- Úrovně vyřešené v data stage (mod-data „rt-levels“): vědy radnic a suroviny milníků.
local data = prototypes.mod_data["rt-levels"].data

local M = {}

--- Suroviny pro povýšení z dané úrovně ({ {type, name, amount} }), nil na nejvyšší úrovni.
function M.upgrade(level)
  return data.upgrade[tostring(level)]
end

--- Vědy, které přijímá radnice dané úrovně.
function M.sciences(level)
  return data.sciences[tostring(level)]
end

return M
```

`research-towns/scripts/state.lua`:

```lua
--- Inicializace tabulek ve storage (nová hra i starší uložená pozice).
local M = {}

--- Založí chybějící tabulky.
function M.init()
  storage.towns = storage.towns or {}
  storage.nodes = storage.nodes or {}
  storage.depots = storage.depots or {}
  storage.renders = storage.renders or {}
  storage.schedule = storage.schedule or {}
  storage.gui = storage.gui or {}
  storage.next_town_id = storage.next_town_id or 1
end

return M
```

`research-towns/scripts/scheduler.lua`:

```lua
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
```

- [ ] **Step 4: Síť (network.lua)**

`research-towns/scripts/network.lua`:

```lua
--- Runtime síť města: uzly (radnice, domy) ve storage.nodes, vazby = visuté chodníky v dosahu.
--- Příslušnost k městu a hloubku počítá čistá logika scripts/graph.lua.
local levels = require("shared.levels")
local geometry = require("scripts.geometry")
local graph = require("scripts.graph")

local M = {}

--- Jméno prototypu domu.
M.HOUSE = "rt-house"

--- Barva dočasného chodníku (finální sprite z Blenderu je plán 3).
local LINK_COLOR = { r = 0.55, g = 0.45, b = 0.3, a = 0.9 }

--- Jména všech budov sítě (domy + radnice).
function M.names()
  local names = levels.hall_names()
  names[#names + 1] = M.HOUSE
  return names
end

--- Klíč dvojice uzlů pro vykreslený chodník (nezávislý na pořadí).
local function pair_key(a, b)
  if a < b then return a .. ":" .. b end
  return b .. ":" .. a
end

--- Propojí dva uzly a vykreslí chodník.
local function link(a, b)
  a.links[b.key] = true
  b.links[a.key] = true
  storage.renders[pair_key(a.key, b.key)] = rendering.draw_line({
    color = LINK_COLOR, width = 4, from = a.entity.position, to = b.entity.position, surface = a.entity.surface,
  })
end

--- Zruší vazbu dvou uzlů i s vykreslením.
local function unlink(a_key, b_key)
  local other = storage.nodes[b_key]
  if other then other.links[a_key] = nil end
  local key = pair_key(a_key, b_key)
  local render = storage.renders[key]
  if render and render.valid then render.destroy() end
  storage.renders[key] = nil
end

--- Uzly sítě v dosahu entity (mezera mezi okraji ≤ HOUSE_REACH).
local function nodes_in_reach(entity)
  local box = entity.selection_box
  local result = {}
  local found = entity.surface.find_entities_filtered({ area = geometry.expand(box, levels.HOUSE_REACH), name = M.names() })
  for _, other in pairs(found) do
    local node = storage.nodes[other.unit_number]
    if node and other ~= entity and geometry.gap(box, other.selection_box) <= levels.HOUSE_REACH then
      result[#result + 1] = node
    end
  end
  return result
end

--- Je dům aktivní (patří k městu a je nejvýš MAX_HOUSE_DEPTH domů od radnice)?
function M.is_active(node)
  return node.town ~= nil and node.depth ~= nil and node.depth <= levels.MAX_HOUSE_DEPTH
end

--- Nastaví domu grafickou variantu podle úrovně města a ikonu „odpojeno“, když není aktivní.
local function refresh_house(node)
  local town = node.town and storage.towns[node.town]
  node.entity.graphics_variation = town and town.level or 1
  local active = M.is_active(node)
  if active and node.warning then
    if node.warning.valid then node.warning.destroy() end
    node.warning = nil
  elseif not active and not node.warning then
    node.warning = rendering.draw_sprite({
      sprite = "utility/warning_icon", target = { entity = node.entity }, surface = node.entity.surface,
      x_scale = 0.7, y_scale = 0.7,
    })
  end
end

--- Přepočte město a hloubku všech uzlů v komponentách daných klíčů.
--- @param keys any[]
--- @return table<integer, true> dotčená města (stará i nová)
function M.recompute(keys)
  local union = {}
  for _, key in ipairs(keys) do
    if storage.nodes[key] and not union[key] then
      for member in pairs(graph.component(storage.nodes, key)) do union[member] = true end
    end
  end
  local roots, touched = {}, {}
  for key in pairs(union) do
    local node = storage.nodes[key]
    if node.town then touched[node.town] = true end
    if node.kind == "hall" and node.town then roots[#roots + 1] = { key = key, town = node.town } end
  end
  table.sort(roots, function(a, b) return a.town < b.town end)
  local assigned = graph.assign(storage.nodes, roots)
  for key in pairs(union) do
    local node = storage.nodes[key]
    if node.kind == "house" then
      local result = assigned[key]
      node.town = result and result.town
      node.depth = result and result.depth
      if node.town then touched[node.town] = true end
      refresh_house(node)
    end
  end
  return touched
end

--- Zaeviduje budovu sítě, propojí ji se vším v dosahu (radnice s radnicí ne) a přepočte síť.
--- @param kind "hall"|"house"
--- @param town_id integer|nil jen pro radnici
--- @return table<integer, true> dotčená města
function M.add(entity, kind, town_id)
  local node = { key = entity.unit_number, entity = entity, kind = kind, town = town_id, links = {} }
  storage.nodes[node.key] = node
  for _, other in ipairs(nodes_in_reach(entity)) do
    if not (kind == "hall" and other.kind == "hall") then link(node, other) end
  end
  return M.recompute({ node.key })
end

--- Vyřadí budovu ze sítě a přepočte zbytek.
--- @return table<integer, true> dotčená města
function M.remove(key)
  local node = storage.nodes[key]
  if not node then return {} end
  local neighbours = {}
  for other in pairs(node.links) do
    neighbours[#neighbours + 1] = other
    unlink(key, other)
  end
  if node.warning and node.warning.valid then node.warning.destroy() end
  storage.nodes[key] = nil
  local touched = M.recompute(neighbours)
  if node.town then touched[node.town] = true end
  return touched
end

--- Přestaví seznam domů města.
function M.rebuild_houses(town)
  town.houses = {}
  for key, node in pairs(storage.nodes) do
    if node.kind == "house" and node.town == town.id then town.houses[key] = true end
  end
end

--- Počet aktivních domů města.
function M.active_houses(town)
  local count = 0
  for key in pairs(town.houses) do
    local node = storage.nodes[key]
    if node and M.is_active(node) then count = count + 1 end
  end
  return count
end

--- Obnoví vzhled všech domů města (po povýšení).
function M.refresh_town_houses(town)
  for key in pairs(town.houses) do
    local node = storage.nodes[key]
    if node then refresh_house(node) end
  end
end

--- Přenese uzel radnice na novou entitu (výměna prototypu při povýšení – nové unit_number).
function M.replace_hall(old_key, entity)
  local node = storage.nodes[old_key]
  local new_key = entity.unit_number
  storage.nodes[old_key] = nil
  for other_key in pairs(node.links) do
    local other = storage.nodes[other_key]
    other.links[old_key] = nil
    other.links[new_key] = true
    storage.renders[pair_key(new_key, other_key)] = storage.renders[pair_key(old_key, other_key)]
    storage.renders[pair_key(old_key, other_key)] = nil
  end
  node.key = new_key
  node.entity = entity
  storage.nodes[new_key] = node
end

return M
```

- [ ] **Step 5: Města (towns.lua) a remote (remote.lua)**

`research-towns/scripts/towns.lua`:

```lua
--- Runtime města: založení, popisky, bonus za domy, stav pro GUI/remote, zánik radnice.
local levels = require("shared.levels")
local config = require("scripts.config")
local milestones = require("scripts.milestones")
local names = require("scripts.names")
local network = require("scripts.network")
local scheduler = require("scripts.scheduler")

local M = {}

local LABEL_COLOR = { r = 1, g = 0.85, b = 0.5 }
local BONUS_MODULE = "rt-bonus-module"

--- Zničí popisky města.
local function destroy_labels(town)
  for _, render in pairs(town.labels or {}) do
    if render.valid then render.destroy() end
  end
  town.labels = nil
end

--- Vykreslí popisek nad radnicí a na mapě (podle pozice – přežije výměnu entity při povýšení).
local function draw_labels(town)
  destroy_labels(town)
  local hall = town.hall
  local text = { "rt.town-label", town.name, town.level }
  local above = { x = hall.position.x, y = hall.position.y - levels.HALL_SIZE / 2 - 1 }
  town.labels = {
    rendering.draw_text({ text = text, surface = hall.surface, target = above, color = LABEL_COLOR,
      scale = 2, alignment = "center" }),
    rendering.draw_text({ text = text, surface = hall.surface, target = hall.position, color = LABEL_COLOR,
      scale = 1.5, alignment = "center", render_mode = "chart" }),
  }
end

--- Nastaví počet bonusových modulů ve skrytém beaconu podle aktivních domů.
function M.update_bonus(town)
  local beacon = town.beacon
  if not (beacon and beacon.valid) then return end
  local inventory = beacon.get_module_inventory()
  local wanted = levels.bonus_modules(town.level, network.active_houses(town))
  local have = inventory.get_item_count(BONUS_MODULE)
  if wanted > have then
    inventory.insert({ name = BONUS_MODULE, count = wanted - have })
  elseif wanted < have then
    inventory.remove({ name = BONUS_MODULE, count = have - wanted })
  end
end

--- Po změně sítě: přestaví seznamy domů a přepočte bonus dotčených měst.
--- Task 7 sem doplní přepočet překladišť.
--- @param touched table<integer, true>
function M.on_network_changed(touched)
  for id in pairs(touched) do
    local town = storage.towns[id]
    if town then
      network.rebuild_houses(town)
      M.update_bonus(town)
    end
  end
end

--- Založí město s radnicí úrovně 1; nil, když tam radnice nejde postavit.
--- @param position MapPosition střed radnice
function M.create(surface, position, force)
  local name = levels.hall_name(1)
  if not surface.can_place_entity({ name = name, position = position, force = force }) then return nil end
  local hall = surface.create_entity({ name = name, position = position, force = force })
  if not hall then return nil end
  local id = storage.next_town_id
  storage.next_town_id = id + 1
  local town = {
    id = id, name = names.generate(id), level = 1, hall = hall, progress = {},
    depots = {}, houses = {}, power_ok = false,
  }
  town.beacon = surface.create_entity({ name = "rt-hall-beacon", position = hall.position, force = force })
  storage.towns[id] = town
  -- Bez elektřiny radnice nezkoumá; zapne ji první zpracování (Task 7).
  hall.disabled_by_script = true
  draw_labels(town)
  M.on_network_changed(network.add(hall, "hall", id))
  scheduler.schedule(town, game.tick + 1)
  return town
end

--- Přejmenuje město.
function M.rename(town, name)
  town.name = name
  draw_labels(town)
end

--- Stav města pro GUI a remote rozhraní.
function M.status(town)
  local cfg = levels.get(town.level)
  local active = network.active_houses(town)
  local requirements = {}
  for _, req in ipairs(config.upgrade(town.level) or {}) do
    requirements[#requirements + 1] = {
      type = req.type, name = req.name, amount = req.amount,
      delivered = math.min(req.amount, town.progress[milestones.key(req.type, req.name)] or 0),
    }
  end
  local beacon = town.beacon
  return {
    id = town.id, name = town.name, level = town.level, hall = town.hall.unit_number,
    active_houses = active, house_limit = cfg.house_limit,
    bonus = levels.bonus_modules(town.level, active) * levels.BONUS_STEP,
    beacon_modules = beacon and beacon.valid and beacon.get_module_inventory().get_item_count(BONUS_MODULE) or 0,
    power_ok = town.power_ok, power_watts = cfg.power_mw * 1e6,
    requirements = requirements, can_upgrade = M.can_upgrade and M.can_upgrade(town) or false,
  }
end

--- Radnice zanikla. Plán 1: město zaniká, domy se odpojí (ruina přijde v plánu 2).
--- Task 7 doplní uvolnění překladišť.
function M.on_hall_removed(key)
  local node = storage.nodes[key]
  if not node then return end
  local town = storage.towns[node.town]
  local touched = network.remove(key)
  if town then
    if town.beacon and town.beacon.valid then town.beacon.destroy() end
    destroy_labels(town)
    storage.towns[town.id] = nil
  end
  M.on_network_changed(touched)
end

return M
```

`research-towns/scripts/remote.lua`:

```lua
--- Remote rozhraní „research-towns“ (pro testy a jiné mody) a ladicí příkaz /rt-create-town.
local towns = require("scripts.towns")

--- Město podle id, nebo nil.
local function town(id)
  return storage.towns[id]
end

remote.add_interface("research-towns", {
  --- Založí město; vrací id, nebo nil, když radnice nejde postavit.
  create_town = function(surface_name, position, force_name)
    local created = towns.create(game.surfaces[surface_name], position, force_name or "player")
    return created and created.id
  end,
  --- Stav města (viz towns.status), nebo nil.
  town_status = function(id)
    local t = town(id)
    return t and towns.status(t)
  end,
  --- Id města, ke kterému patří budova (radnice, dům, překladiště), nebo nil.
  town_of = function(unit_number)
    local record = storage.nodes[unit_number] or storage.depots[unit_number]
    return record and record.town
  end,
  --- Hloubka domu od radnice, nebo nil.
  depth_of = function(unit_number)
    local node = storage.nodes[unit_number]
    return node and node.depth
  end,
  --- Přejmenuje město.
  rename = function(id, name)
    local t = town(id)
    if t then towns.rename(t, name) end
  end,
})

commands.add_command("rt-create-town", { "rt.command-create-town" }, function(command)
  local player = command.player_index and game.get_player(command.player_index)
  if not (player and player.admin) then return end
  local position = { x = math.floor(player.position.x) + 0.5, y = math.floor(player.position.y) - 12 + 0.5 }
  local created = towns.create(player.surface, position, player.force)
  player.print(created and { "rt.town-created", created.name } or { "rt.town-cannot-place" })
end)
```

- [ ] **Step 6: control.lua a locale**

`research-towns/control.lua`:

```lua
-- Research Towns – napojení událostí na moduly; logika je ve scripts/.
local levels = require("shared.levels")
local state = require("scripts.state")
local scheduler = require("scripts.scheduler")
local network = require("scripts.network")
local towns = require("scripts.towns")
require("scripts.remote")

--- Postavení domu (hráč, robot, skript): připojí ho do sítě.
local function on_built(event)
  local entity = event.entity
  if entity.name == network.HOUSE then
    towns.on_network_changed(network.add(entity, "house"))
  end
end

--- Odstranění budovy města (vytěžení, zničení, skript).
local function on_removed(event)
  local entity = event.entity
  if levels.hall_level(entity.name) then
    towns.on_hall_removed(entity.unit_number)
  elseif entity.name == network.HOUSE then
    towns.on_network_changed(network.remove(entity.unit_number))
  end
end

--- Pravidelné zpracování města (Task 7 doplní suroviny a elektřinu) a další naplánování.
local function process(town)
  if not town.hall.valid then return end
  scheduler.schedule(town, game.tick + levels.TOWN_INTERVAL)
end

local built_filters = { { filter = "name", name = network.HOUSE } }
local removed_filters = {}
for _, name in ipairs(network.names()) do removed_filters[#removed_filters + 1] = { filter = "name", name = name } end

for _, id in ipairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}) do
  script.on_event(id, on_built, built_filters)
end

for _, id in ipairs({
  defines.events.on_player_mined_entity,
  defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy,
}) do
  script.on_event(id, on_removed, removed_filters)
end

script.on_event(defines.events.on_tick, function(event) scheduler.run(event.tick, process) end)
script.on_init(state.init)
script.on_configuration_changed(function()
  state.init()
  scheduler.clear()
  for _, town in pairs(storage.towns) do
    if town.hall.valid then scheduler.schedule(town, game.tick + 1) end
  end
end)
```

Do obou locale připsat sekci `[rt]` – en:

```
[rt]
town-label=__1__ (level __2__)
command-create-town=Creates a level 1 town hall north of the player (admin, for testing).
town-created=Town __1__ was founded.
town-cannot-place=A town hall does not fit here.
```

cs:

```
[rt]
town-label=__1__ (úroveň __2__)
command-create-town=Založí radnici úrovně 1 severně od hráče (admin, pro testování).
town-created=Bylo založeno město __1__.
town-cannot-place=Radnice se sem nevejde.
```

- [ ] **Step 7: Ověřit testy**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla && bash tools/run-tests.sh space-age`
Expected: unit `fail=0`; obě varianty `RT-TEST DONE pass=11 fail=0 skip=0`.

- [ ] **Step 8: Commit**

```bash
git add research-towns tests/research-towns-tests
git commit -m "feat: města, síť domů s visutými chodníky a remote rozhraní"
```

---

### Task 7: Překladiště, milníky a elektřina

**Files:**
- Create: `research-towns/scripts/depots.lua`
- Modify: `research-towns/scripts/towns.lua` (`process`, `on_network_changed`, `on_hall_removed`), `research-towns/control.lua`, `research-towns/scripts/remote.lua`
- Create: `tests/research-towns-tests/cases/depots.lua`
- Modify: `tests/research-towns-tests/helpers.lua`, `tests/research-towns-tests/control.lua`

**Interfaces:**
- Consumes: `network.names()`, `network.is_active(node)` (Task 6), `milestones` (Task 5), `config.upgrade(level)`.
- Produces `scripts/depots.lua`: `KINDS = { [name] = "goods"|"fluid"|"power" }`, `names()`, `add(entity) → depot`, `remove(key)`, `resolve(depot)`, `resolve_unassigned()`, `apply_town_power(town)`, `collect(town)`, `power_ok(town) → boolean`; záznam `storage.depots[unit] = { key, entity, kind, town }`.
- Produces `towns.process(town)`; remote `process(id)`, `set_level(id, level)` (doplní Task 8 – tady jen `process`).
- Produces helpers: `H.process(id)`, `H.delivered(id, type, name) → number|nil`.

- [ ] **Step 1: Napsat failing testy**

Do `helpers.lua` připsat:

```lua
--- Okamžitě zpracuje město (výběr z překladišť, elektřina) – nečeká na plánovač.
function H.process(id)
  remote.call(H.REMOTE, "process", id)
end

--- Kolik suroviny už město dostalo k dalšímu milníku (nil = surovina v milníku není).
function H.delivered(id, kind, name)
  for _, req in ipairs(H.status(id).requirements) do
    if req.type == kind and req.name == name then return req.delivered end
  end
  return nil
end
```

`tests/research-towns-tests/cases/depots.lua`:

```lua
--- Integrační testy překladišť: přiřazení k městu, výběr surovin, kapaliny, elektřina.
local H = require("helpers")
local R = H.REMOTE

--- Najde v milníku města první požadavek daného typu.
local function first_requirement(id, kind)
  for _, req in ipairs(H.status(id).requirements) do
    if req.type == kind then return req end
  end
  error("milník nemá požadavek typu " .. kind)
end

return {
  {
    name = "překladiště odebere jen potřebné a jen do potřeby",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
      ctx.req = first_requirement(ctx.town, "item")
      ctx.depot.insert({ name = ctx.req.name, count = ctx.req.amount + 50 })
      ctx.depot.insert({ name = "iron-ore", count = 30 })
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "town_of", ctx.depot.unit_number) == ctx.town, "překladiště nepřiřazeno")
      H.process(ctx.town)
      H.check(H.delivered(ctx.town, "item", ctx.req.name) == ctx.req.amount, "dodáno ≠ potřeba")
      H.check(ctx.depot.get_item_count(ctx.req.name) == 50, "přebytek nezůstal v překladišti")
      H.check(ctx.depot.get_item_count("iron-ore") == 30, "nepotřebná ruda zmizela")
    end } },
  },
  {
    name = "překladiště mimo dosah nepatří k městu",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 14)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "town_of", ctx.depot.unit_number) == nil, "vzdálené překladiště přiřazeno")
    end } },
  },
  {
    name = "překladiště u neaktivního domu nepatří k městu",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      for _, dx in ipairs({ 11, 16, 21, 26, 31, 36 }) do H.house(ctx, dx, 0) end
      ctx.depot = H.place(ctx, "rt-goods-depot", 39, 0)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "town_of", ctx.depot.unit_number) == nil, "překladiště u 6. domu přiřazeno")
    end } },
  },
  {
    name = "překladiště kapalin dodá kapalinu milníku",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      remote.call(R, "set_level", ctx.town, 2)
      ctx.depot = H.place(ctx, "rt-fluid-depot", 4, 11)
      ctx.req = first_requirement(ctx.town, "fluid")
      ctx.depot.insert_fluid({ name = ctx.req.name, amount = 1000 })
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      local delivered = H.delivered(ctx.town, "fluid", ctx.req.name)
      H.check(math.abs(delivered - 1000) < 0.01, "dodaná kapalina: " .. tostring(delivered))
    end } },
  },
  {
    name = "bez elektřiny radnice nezkoumá",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      H.place(ctx, "rt-power-depot", -4, 10)
      ctx.substation = H.power(ctx, -10, 13)
    end,
    steps = {
      { ticks = 30, run = function(ctx)
        H.process(ctx.town)
        H.check(H.status(ctx.town).power_ok, "elektřina nepokryta")
        H.check(not H.hall(ctx.town).disabled_by_script, "radnice vypnutá i s elektřinou")
        ctx.substation.destroy()
      end },
      { ticks = 120, run = function(ctx)
        H.process(ctx.town)
        H.check(not H.status(ctx.town).power_ok, "elektřina pokryta bez rozvodny")
        H.check(H.hall(ctx.town).disabled_by_script, "radnice zkoumá bez elektřiny")
      end },
    },
  },
}
```

Do `control.lua` testovacího modu přidat `runner.register(require("cases.depots"))`.

- [ ] **Step 2: Ověřit, že testy selžou**

Run: `bash tools/run-tests.sh vanilla`
Expected: FAIL u testů `cases/depots.lua` (`překladiště nepřiřazeno`, `Unknown interface function process` …), exit ≠ 0.

- [ ] **Step 3: Implementace depots.lua**

`research-towns/scripts/depots.lua`:

```lua
--- Runtime překladiště: přiřazení k nejbližší budově města, výběr surovin pro milník, elektřina města.
local levels = require("shared.levels")
local config = require("scripts.config")
local geometry = require("scripts.geometry")
local milestones = require("scripts.milestones")
local network = require("scripts.network")

local M = {}

--- Prototypy překladišť a jejich druh.
M.KINDS = { ["rt-goods-depot"] = "goods", ["rt-fluid-depot"] = "fluid", ["rt-power-depot"] = "power" }

--- Jména prototypů překladišť.
function M.names()
  return { "rt-goods-depot", "rt-fluid-depot", "rt-power-depot" }
end

--- Nastaví odběr všech rozvoden města: příkon úrovně rozdělený rovným dílem; bez města nic.
--- Zásobník = 1 s odběru, takže výpadek sítě se projeví do pár sekund.
function M.apply_town_power(town)
  local list = {}
  for key in pairs(town.depots) do
    local depot = storage.depots[key]
    if depot and depot.kind == "power" then list[#list + 1] = depot end
  end
  for _, depot in ipairs(list) do
    local usage = levels.power_per_tick(town.level) / #list
    depot.entity.power_usage = usage
    depot.entity.electric_buffer_size = usage * 60
  end
end

--- Vypne odběr rozvodny bez města.
local function release_power(depot)
  if depot.kind == "power" and depot.entity.valid then
    depot.entity.power_usage = 0
    depot.entity.electric_buffer_size = 1
  end
end

--- Je uzel platnou kotvou překladiště? (radnice města nebo aktivní dům)
local function anchors(node)
  if node.kind == "hall" then return node.town ~= nil end
  return network.is_active(node)
end

--- Přiřadí překladiště k městu nejbližší kotvy v dosahu (remíza → nižší id města) a přepočte elektřinu.
function M.resolve(depot)
  local entity = depot.entity
  local box = entity.selection_box
  local best, best_gap
  local found = entity.surface.find_entities_filtered({ area = geometry.expand(box, levels.DEPOT_REACH), name = network.names() })
  for _, other in pairs(found) do
    local node = storage.nodes[other.unit_number]
    if node and anchors(node) then
      local gap = geometry.gap(box, other.selection_box)
      if gap <= levels.DEPOT_REACH and (not best or gap < best_gap or (gap == best_gap and node.town < best.town)) then
        best, best_gap = node, gap
      end
    end
  end
  local old = depot.town
  depot.town = best and best.town
  if old == depot.town then return end
  local old_town = old and storage.towns[old]
  if old_town then
    old_town.depots[depot.key] = nil
    M.apply_town_power(old_town)
  end
  if depot.town then
    local town = storage.towns[depot.town]
    town.depots[depot.key] = true
    M.apply_town_power(town)
  else
    release_power(depot)
  end
end

--- Zaeviduje nové překladiště.
function M.add(entity)
  local depot = { key = entity.unit_number, entity = entity, kind = M.KINDS[entity.name] }
  storage.depots[depot.key] = depot
  release_power(depot)
  M.resolve(depot)
  return depot
end

--- Vyřadí překladiště (vytěžení/zničení) a přepočte elektřinu jeho města.
function M.remove(key)
  local depot = storage.depots[key]
  if not depot then return end
  storage.depots[key] = nil
  local town = depot.town and storage.towns[depot.town]
  if town then
    town.depots[key] = nil
    M.apply_town_power(town)
  end
end

--- Zkusí přiřadit překladiště bez města (po změnách sítě se nová kotva mohla objevit kdekoli).
function M.resolve_unassigned()
  for _, depot in pairs(storage.depots) do
    if not depot.town and depot.entity.valid then M.resolve(depot) end
  end
end

--- Vybere z překladišť města suroviny potřebné k dalšímu milníku (každá kvalita se počítá).
function M.collect(town)
  local requirements = config.upgrade(town.level)
  if not requirements then return end
  for key in pairs(town.depots) do
    local depot = storage.depots[key]
    local entity = depot and depot.entity
    if entity and entity.valid then
      if depot.kind == "goods" then
        local inventory = entity.get_inventory(defines.inventory.chest)
        for _, item in pairs(inventory.get_contents()) do
          local take = milestones.accept(requirements, town.progress, "item", item.name, item.count)
          if take > 0 then
            local removed = inventory.remove({ name = item.name, quality = item.quality, count = take })
            milestones.add(town.progress, "item", item.name, removed)
          end
        end
      elseif depot.kind == "fluid" then
        local fluid = entity.fluidbox[1]
        if fluid then
          local take = milestones.accept(requirements, town.progress, "fluid", fluid.name, fluid.amount)
          if take > 0 then
            milestones.add(town.progress, "fluid", fluid.name, entity.remove_fluid({ name = fluid.name, amount = take }))
          end
        end
      end
    end
  end
end

--- Je spotřeba města pokrytá? (aspoň jedna rozvodna a každá má zásobník aspoň z poloviny plný)
function M.power_ok(town)
  local any = false
  for key in pairs(town.depots) do
    local depot = storage.depots[key]
    if depot and depot.kind == "power" then
      any = true
      local entity = depot.entity
      if not entity.valid or entity.energy < 0.5 * entity.electric_buffer_size then return false end
    end
  end
  return any
end

return M
```

- [ ] **Step 4: Napojení do towns.lua, control.lua a remote.lua**

V `research-towns/scripts/towns.lua`:
- přidat `local depots = require("scripts.depots")` k ostatním require,
- v `M.on_network_changed` za `network.rebuild_houses(town)` vložit:

```lua
      for key in pairs(town.depots) do
        local depot = storage.depots[key]
        if depot then depots.resolve(depot) end
      end
```

- v `M.on_hall_removed` za `storage.towns[town.id] = nil` vložit:

```lua
    for key in pairs(town.depots) do
      local depot = storage.depots[key]
      if depot then depots.resolve(depot) end
    end
```

- přidat funkci:

```lua
--- Pravidelné zpracování: suroviny z překladišť, kontrola elektřiny, zapnutí/vypnutí výzkumu.
function M.process(town)
  if not town.hall.valid then return end
  depots.collect(town)
  town.power_ok = depots.power_ok(town)
  town.hall.disabled_by_script = not town.power_ok
end
```

V `research-towns/control.lua`:
- přidat `local depots = require("scripts.depots")`,
- `on_built` rozšířit:

```lua
  if entity.name == network.HOUSE then
    towns.on_network_changed(network.add(entity, "house"))
    depots.resolve_unassigned()
  elseif depots.KINDS[entity.name] then
    depots.add(entity)
  end
```

- `on_removed` rozšířit o větev `elseif depots.KINDS[entity.name] then depots.remove(entity.unit_number)`,
- v `process` před `scheduler.schedule(...)` vložit `towns.process(town)`,
- filtry: do `built_filters` i `removed_filters` přidat `{ filter = "name", name = n }` pro každé `n` z `depots.names()`,
- přidat `script.on_nth_tick(levels.TOWN_INTERVAL, depots.resolve_unassigned)`.

V `research-towns/scripts/remote.lua` přidat do tabulky rozhraní:

```lua
  --- Okamžitě zpracuje město (pro testy).
  process = function(id)
    local t = town(id)
    if t then towns.process(t) end
  end,
```

Funkci `set_level` přidá Task 8 – do té doby test „překladiště kapalin…“ selže na `Unknown interface function set_level`; to je v tomto úkolu očekávané a zelenou ověří Task 8.

- [ ] **Step 5: Ověřit testy**

Run: `bash tools/run-tests.sh vanilla`
Expected: `RT-TEST DONE pass=15 fail=1 skip=0`, jediný FAIL je „překladiště kapalin dodá kapalinu milníku“ (`set_level` doplní Task 8).

- [ ] **Step 6: Commit**

```bash
git add research-towns tests/research-towns-tests
git commit -m "feat: překladiště zboží, kapalin a elektřiny pro milníky města"
```

---

### Task 8: Povýšení města a výzkum v radnici

**Files:**
- Modify: `research-towns/scripts/towns.lua` (`can_upgrade`, `set_level`, `upgrade`), `research-towns/scripts/remote.lua`
- Create: `tests/research-towns-tests/cases/upgrade.lua`
- Modify: `tests/research-towns-tests/control.lua`

**Interfaces:**
- Consumes: `network.replace_hall`, `network.refresh_town_houses`, `network.active_houses` (Task 6), `depots.apply_town_power` (Task 7).
- Produces `towns.can_upgrade(town) → boolean`, `towns.set_level(town, level)`, `towns.upgrade(town) → boolean`; remote `upgrade(id) → boolean`, `set_level(id, level)`.

- [ ] **Step 1: Napsat failing testy**

`tests/research-towns-tests/cases/upgrade.lua`:

```lua
--- Integrační testy povýšení města, vstupů radnice podle úrovně a výzkumu s elektřinou.
local levels = require("__research-towns__/shared/levels")
local H = require("helpers")
local R = H.REMOTE

--- Postaví k radnici n domů napravo (všechny v hloubce 1).
local function houses(ctx, n)
  ctx.houses = {}
  local rows = { -6, -2, 2, 6 }
  for i = 1, n do ctx.houses[i] = H.house(ctx, i <= 4 and 11 or -11, rows[(i - 1) % 4 + 1]) end
end

--- Dodá do nového překladiště všechny předměty aktuálního milníku.
local function deliver_items(ctx)
  ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
  for _, req in ipairs(H.status(ctx.town).requirements) do
    if req.type == "item" then ctx.depot.insert({ name = req.name, count = req.amount }) end
  end
end

return {
  {
    name = "radnice úrovně 1 přijme červenou, ne zelenou",
    setup = function(ctx) ctx.town = H.town(ctx) end,
    steps = { { ticks = 1, run = function(ctx)
      local hall = H.hall(ctx.town)
      H.check(hall.insert({ name = "logistic-science-pack", count = 1 }) == 0, "přijala zelenou")
      H.check(hall.insert({ name = "automation-science-pack", count = 1 }) == 1, "nepřijala červenou")
    end } },
  },
  {
    name = "povýšení vymění radnici, zachová balíčky a přebarví domy",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      houses(ctx, 4)
      deliver_items(ctx)
      H.hall(ctx.town).insert({ name = "automation-science-pack", count = 5 })
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        H.process(ctx.town)
        local s = H.status(ctx.town)
        H.check(s.can_upgrade, "nelze povýšit: " .. serpent.line(s.requirements))
        H.check(remote.call(R, "upgrade", ctx.town), "upgrade vrátil false")
      end },
      { ticks = 1, run = function(ctx)
        local s = H.status(ctx.town)
        local hall = H.hall(ctx.town)
        H.check(s.level == 2 and hall.name == levels.hall_name(2), "radnice není úrovně 2")
        H.check(hall.get_item_count("automation-science-pack") == 5, "balíčky se ztratily")
        H.check(hall.insert({ name = "logistic-science-pack", count = 1 }) == 1, "úroveň 2 nepřijme zelenou")
        for _, req in ipairs(s.requirements) do H.check(req.delivered == 0, "postup se nevynuloval") end
        H.check(ctx.houses[1].graphics_variation == 2, "dům nemá vzhled úrovně 2")
        H.check(s.beacon_modules == levels.bonus_modules(2, 4), "bonus po povýšení: " .. s.beacon_modules)
        H.check(remote.call(R, "town_of", ctx.depot.unit_number) == ctx.town, "překladiště ztratilo město")
      end },
    },
  },
  {
    name = "bez dost domů nelze povýšit",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      houses(ctx, 3)
      deliver_items(ctx)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      H.check(not H.status(ctx.town).can_upgrade, "povýšení se 3 domy")
      H.check(not remote.call(R, "upgrade", ctx.town), "upgrade prošel")
    end } },
  },
  {
    name = "radnice s elektřinou zkoumá",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      H.place(ctx, "rt-power-depot", -4, 10)
      H.power(ctx, -10, 13)
      local force = game.forces.player
      force.technologies["automation-science-pack"].researched = true
      force.add_research("automation")
      H.hall(ctx.town).insert({ name = "automation-science-pack", count = 50 })
    end,
    steps = {
      { ticks = 30, run = function(ctx)
        H.process(ctx.town)
        H.check(H.status(ctx.town).power_ok, "elektřina nepokryta")
      end },
      { ticks = 600, run = function()
        local force = game.forces.player
        H.check(force.research_progress > 0 or force.technologies["automation"].researched, "výzkum nepostoupil")
      end },
    },
  },
}
```

Do `control.lua` testovacího modu přidat `runner.register(require("cases.upgrade"))`.

- [ ] **Step 2: Ověřit, že testy selžou**

Run: `bash tools/run-tests.sh vanilla`
Expected: FAIL „povýšení vymění radnici…“ (`can_upgrade` false / `Unknown interface function upgrade`) a „překladiště kapalin…“, exit ≠ 0.

- [ ] **Step 3: Implementace**

Do `research-towns/scripts/towns.lua` přidat:

```lua
--- Lze město povýšit? (není na max. úrovni, milník splněný, dost aktivních domů)
function M.can_upgrade(town)
  local requirements = config.upgrade(town.level)
  return requirements ~= nil and milestones.complete(requirements, town.progress)
    and network.active_houses(town) >= levels.get(town.level).house_limit
end

--- Přesune obsah inventáře entity do dočasného inventáře (zachová trvanlivost balíčků i moduly).
local function take_inventory(entity, inventory_id)
  local source = entity.get_inventory(inventory_id)
  if not source then return nil end
  local buffer = game.create_inventory(#source)
  for i = 1, #source do buffer[i].transfer_stack(source[i]) end
  return buffer
end

--- Vrátí obsah dočasného inventáře do entity a dočasný inventář zničí.
local function restore_inventory(buffer, entity, inventory_id)
  if not buffer then return end
  local target = entity.get_inventory(inventory_id)
  for i = 1, #buffer do
    if buffer[i].valid_for_read then target.insert(buffer[i]) end
  end
  buffer.destroy()
end

--- Vymění radnici za prototyp dané úrovně (stejný půdorys), přenese obsah, přebarví domy,
--- vynuluje postup milníku a přepočte elektřinu i bonus.
function M.set_level(town, level)
  local old = town.hall
  local surface, position, force = old.surface, old.position, old.force
  local packs = take_inventory(old, defines.inventory.lab_input)
  local modules = take_inventory(old, defines.inventory.lab_modules)
  local old_key = old.unit_number
  old.destroy()
  local hall = surface.create_entity({ name = levels.hall_name(level), position = position, force = force })
  restore_inventory(packs, hall, defines.inventory.lab_input)
  restore_inventory(modules, hall, defines.inventory.lab_modules)
  network.replace_hall(old_key, hall)
  town.hall = hall
  town.level = level
  town.progress = {}
  hall.disabled_by_script = not town.power_ok
  network.refresh_town_houses(town)
  depots.apply_town_power(town)
  M.update_bonus(town)
  draw_labels(town)
end

--- Povýší město o úroveň, pokud to podmínky dovolí.
--- @return boolean
function M.upgrade(town)
  if not M.can_upgrade(town) then return false end
  M.set_level(town, town.level + 1)
  return true
end
```

V `M.status` nahradit `can_upgrade = M.can_upgrade and M.can_upgrade(town) or false` za `can_upgrade = M.can_upgrade(town)` (funkce teď vždy existuje; pořadí v souboru nevadí – pole `M` se čte až při volání).

Do remote rozhraní přidat:

```lua
  --- Povýší město, pokud jsou splněné podmínky.
  upgrade = function(id)
    local t = town(id)
    return t ~= nil and towns.upgrade(t)
  end,
  --- Nastaví úroveň bez podmínek (testy, ladění).
  set_level = function(id, level)
    local t = town(id)
    if t then towns.set_level(t, level) end
  end,
```

- [ ] **Step 4: Ověřit testy**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla && bash tools/run-tests.sh space-age`
Expected: unit `fail=0`; obě varianty `RT-TEST DONE pass=20 fail=0 skip=0`.

- [ ] **Step 5: Commit**

```bash
git add research-towns tests/research-towns-tests
git commit -m "feat: povýšení města s výměnou radnice a zachováním obsahu"
```

---

### Task 9: GUI radnice

**Files:**
- Create: `research-towns/scripts/gui.lua`
- Modify: `research-towns/control.lua`, obě `locale.cfg`
- Create: `tests/unit/test_gui_names.lua`
- Modify: `tests/unit/run.lua`

**Interfaces:**
- Consumes: `towns.status`, `towns.upgrade`, `towns.rename` (Task 6–8), `levels.hall_names()`.
- Produces `scripts/gui.lua`: `REFRESH_TICKS = 30`, `NAMES`, `ensure(player)`, `rebuild_all()`, `on_opened(event)`, `on_closed(event)`, `on_click(event)`, `on_confirmed(event)`, `refresh()`.

- [ ] **Step 1: Napsat failing test jmen prvků**

`tests/unit/test_gui_names.lua`:

```lua
---@diagnostic disable: undefined-global
--- Jména GUI prvků nesmí kolidovat s vlastnostmi/metodami LuaGuiElement (např. "state") – hra by spadla.
--- Headless testy GUI netvoří (nejsou hráči), proto statická kontrola proti API dokumentaci hry.
local A = require("assert")

--- Cesta k API dokumentaci; jiná instalace hry → proměnná prostředí FACTORIO_API_JSON.
local API_JSON = os.getenv("FACTORIO_API_JSON") or "C:/STEAM/steamapps/common/Factorio/doc-html/runtime-api.json"

--- Načte celý soubor jako text (nebo nil).
local function read(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local text = file:read("a")
  file:close()
  return text
end

--- Množina jmen z definice třídy LuaGuiElement.
local function reserved_names(api)
  local start = api:find('{"name":"LuaGuiElement","order"', 1, true)
  local first = api:find('"abstract":', start, true)
  local next_class = api:find('"abstract":', first + 1, true)
  local set = {}
  for name in api:sub(start, next_class):gmatch('"name":"([%w_]+)"') do set[name] = true end
  return set
end

return {
  { "jména prvků v gui.lua nekolidují s LuaGuiElement", function()
    local api = read(API_JSON)
    if not api then
      print("SKIP test_gui_names: chybí " .. API_JSON)
      return
    end
    local reserved = reserved_names(api)
    A.truthy(reserved["state"] and reserved["caption"], "seznam vlastností LuaGuiElement načten")
    local source = read("research-towns/scripts/gui.lua")
    A.truthy(source, "gui.lua existuje")
    local count = 0
    for name in source:gmatch('"(rt_[%w_]+)"') do
      count = count + 1
      A.eq(reserved[name], nil, "jméno prvku '" .. name .. "' koliduje s LuaGuiElement")
    end
    A.truthy(count > 0, "nalezena jména prvků")
  end },
}
```

Do SUITES přidat `"test_gui_names"`.

- [ ] **Step 2: Ověřit, že test selže**

Run: `bash tools/run-unit.sh`
Expected: `FAIL test_gui_names … gui.lua existuje`.

- [ ] **Step 3: Implementace gui.lua**

`research-towns/scripts/gui.lua`:

```lua
--- GUI radnice: panel ukotvený vpravo od okna laboratoře, zobrazený jen u radnic.
local levels = require("shared.levels")
local towns = require("scripts.towns")

local M = {}

--- Jak často se obnoví otevřené panely (ticky).
M.REFRESH_TICKS = 30

--- Jména prvků (prefix rt_, nesmí kolidovat s vlastnostmi LuaGuiElement – hlídá test_gui_names).
M.NAMES = {
  frame = "rt_town_frame",
  name = "rt_town_name",
  level = "rt_town_level",
  houses = "rt_town_houses",
  power = "rt_town_power",
  requirements = "rt_town_requirements",
  upgrade = "rt_town_upgrade",
}

--- Vytvoří (znovu) prázdný panel hráči.
function M.ensure(player)
  local relative = player.gui.relative
  if relative[M.NAMES.frame] then relative[M.NAMES.frame].destroy() end
  local frame = relative.add({
    type = "frame", name = M.NAMES.frame, direction = "vertical", caption = { "rt.gui-title" },
    anchor = { gui = defines.relative_gui_type.lab_gui, position = defines.relative_gui_position.right,
      names = levels.hall_names() },
  })
  frame.add({ type = "textfield", name = M.NAMES.name, tooltip = { "rt.gui-rename" } })
  frame.add({ type = "label", name = M.NAMES.level })
  frame.add({ type = "label", name = M.NAMES.houses })
  frame.add({ type = "label", name = M.NAMES.power })
  frame.add({ type = "label", caption = { "rt.gui-requirements" } })
  frame.add({ type = "table", name = M.NAMES.requirements, column_count = 2 })
  frame.add({ type = "button", name = M.NAMES.upgrade, caption = { "rt.gui-upgrade" } })
end

--- Vytvoří panely všem hráčům.
function M.rebuild_all()
  for _, player in pairs(game.players) do M.ensure(player) end
end

--- Město otevřené radnice, nebo nil.
local function town_of(entity)
  if not (entity and entity.valid) then return nil end
  local node = storage.nodes[entity.unit_number]
  return node and node.kind == "hall" and storage.towns[node.town]
end

--- Naplní panel hráče stavem města.
local function fill(player, town)
  local frame = player.gui.relative[M.NAMES.frame]
  if not frame then return end
  local n = M.NAMES
  local status = towns.status(town)
  frame[n.level].caption = { "rt.gui-level", status.level, levels.MAX_LEVEL }
  frame[n.houses].caption = { "rt.gui-houses", status.active_houses, status.house_limit,
    string.format("%d", math.floor(status.bonus * 100 + 0.5)) }
  local megawatts = string.format("%.0f", status.power_watts / 1e6)
  frame[n.power].caption = status.power_ok and { "rt.gui-power-ok", megawatts } or { "rt.gui-power-missing", megawatts }
  local list = frame[n.requirements]
  list.clear()
  for _, req in ipairs(status.requirements) do
    list.add({ type = "sprite", sprite = req.type .. "/" .. req.name })
    list.add({ type = "label", caption = string.format("%d / %d", math.floor(req.delivered), req.amount) })
  end
  if #status.requirements == 0 then list.add({ type = "label", caption = { "rt.gui-max-level" } }) end
  frame[n.upgrade].enabled = status.can_upgrade
end

--- Otevření okna: u radnice si zapamatuje město a naplní panel (jméno jen při otevření – nepřepisuje psaní).
function M.on_opened(event)
  local town = town_of(event.entity)
  if not town then return end
  local player = game.get_player(event.player_index)
  if not player.gui.relative[M.NAMES.frame] then M.ensure(player) end
  storage.gui[event.player_index] = town.id
  player.gui.relative[M.NAMES.frame][M.NAMES.name].text = town.name
  fill(player, town)
end

--- Zavření okna.
function M.on_closed(event)
  storage.gui[event.player_index] = nil
end

--- Klik na „Povýšit“.
function M.on_click(event)
  if event.element.name ~= M.NAMES.upgrade then return end
  local town = storage.towns[storage.gui[event.player_index]]
  if town and towns.upgrade(town) then
    -- Povýšení vyměnilo entitu radnice – okno staré radnice se zavřelo, panel znovu otevře hráč.
    storage.gui[event.player_index] = nil
  end
end

--- Potvrzení jména Enterem.
function M.on_confirmed(event)
  if event.element.name ~= M.NAMES.name then return end
  local town = storage.towns[storage.gui[event.player_index]]
  local text = event.element.text
  if town and text ~= "" then towns.rename(town, text) end
end

--- Obnoví otevřené panely; bez otevřeného okna jen jedna kontrola prázdné tabulky.
function M.refresh()
  for index, id in pairs(storage.gui) do
    local player = game.get_player(index)
    local town = storage.towns[id]
    if player and town and town.hall.valid then fill(player, town) else storage.gui[index] = nil end
  end
end

return M
```

- [ ] **Step 4: Napojení a locale**

V `research-towns/control.lua` přidat `local gui = require("scripts.gui")` a:

```lua
script.on_event(defines.events.on_player_created, function(event) gui.ensure(game.get_player(event.player_index)) end)
script.on_event(defines.events.on_gui_opened, gui.on_opened)
script.on_event(defines.events.on_gui_closed, gui.on_closed)
script.on_event(defines.events.on_gui_click, gui.on_click)
script.on_event(defines.events.on_gui_confirmed, gui.on_confirmed)
script.on_nth_tick(gui.REFRESH_TICKS, gui.refresh)
```

`script.on_init(state.init)` nahradit za:

```lua
script.on_init(function()
  state.init()
  gui.rebuild_all()
end)
```

a do handleru `on_configuration_changed` na konec přidat `gui.rebuild_all()`.

Do `[rt]` v en locale:

```
gui-title=Town
gui-rename=Town name (Enter to confirm)
gui-level=Level __1__ / __2__
gui-houses=Active houses: __1__ / __2__ (research +__3__ %)
gui-power-ok=Electricity: OK (__1__ MW)
gui-power-missing=Not enough electricity – needs __1__ MW
gui-requirements=Delivered for the next level:
gui-upgrade=Upgrade town
gui-max-level=Maximum level reached
```

Do `[rt]` v cs locale:

```
gui-title=Město
gui-rename=Jméno města (potvrdit Enterem)
gui-level=Úroveň __1__ / __2__
gui-houses=Aktivní domy: __1__ / __2__ (výzkum +__3__ %)
gui-power-ok=Elektřina: OK (__1__ MW)
gui-power-missing=Nedostatek elektřiny – potřeba __1__ MW
gui-requirements=Dodáno pro další úroveň:
gui-upgrade=Povýšit město
gui-max-level=Dosažena nejvyšší úroveň
```

- [ ] **Step 5: Ověřit testy**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla && bash tools/run-tests.sh space-age`
Expected: `UNIT pass=30 fail=0`; obě varianty `RT-TEST DONE pass=20 fail=0 skip=0`.

- [ ] **Step 6: Commit**

```bash
git add research-towns tests/unit
git commit -m "feat: GUI radnice s milníky, elektřinou a povýšením"
```

---

### Task 10: Kompatibilita s overhauly, dokumentace a ruční kontrola

**Files:**
- Create: `docs/development.md`, `docs/user-guide.md`, `README.md`
- Modify (jen pokud běh `mods` odhalí problém): `research-towns/shared/levels.lua` (kandidáti), `research-towns/prototypes/*.lua`

**Interfaces:**
- Consumes: vše z Task 1–9.

- [ ] **Step 1: Běh s Bob's**

Run: `bash tools/run-tests.sh mods bobassembly bobelectronics bobenemies bobequipment bobgreenhouse bobinserters boblogistics bobmining bobmodules bobores bobplates bobpower bobrevamp bobtech bobvehicleequipment bobwarfare`
Expected: `RT-TEST DONE pass=4 fail=0 skip=0` (jen `cases/compat.lua`).
V `.test-run/mods/create.log` zkontrolovat řádky `research-towns:` – odstraněné laboratoře (čekáno `lab` a laboratoře Bob's), vědy úrovní, milníky bez „vynecháno“. Při „vynecháno“ doplnit v `shared/levels.lua` dalšího kandidáta (existující předmět dostupný na dané úrovni) a běh zopakovat.

- [ ] **Step 2: Běh s Pyanodonem**

Run: `bash tools/run-tests.sh mods pymodpack`
Expected: `RT-TEST DONE pass=4 fail=0 skip=0`. Stejná kontrola `create.log` jako v Step 1; ověřit řádek `Loading mod research-towns … (data-final-fixes.lua)` až **za** `pypostprocessing` (radnice vidí konečný strom věd).
Pokud Py hlásí chybu při načtení kvůli receptům domů/překladišť (chybějící `wood`, `stone-brick` …), nahradit v `prototypes/house.lua` / `depots.lua` surovinu existující v Py a v obou overhaulech i vanille (ověřit `bash tools/run-tests.sh vanilla`).

- [ ] **Step 3: docs/development.md**

```markdown
# Research Towns – vývoj

## Prostředí
- Factorio 2.0 (Steam), cesta v `tools/run-tests.sh` (proměnná `FACTORIO_EXE`).
- VSCode + sumneko.lua + FMTK (`justarandomgeek.factoriomod-debug`); ladění: `bash tools/link-mod.sh`, pak F5 („Factorio – Research Towns“).
- Lua 5.3 v PATH pro unit testy (hra běží na Lua 5.2 – v modu nepoužívat `//`).

## Struktura
Viz mapa souborů v `docs/superpowers/plans/2026-10-05-research-towns-core.md`. `control.lua` jen napojuje události.

## Kde ladit hodnoty
| Co | Kde |
|---|---|
| Rychlost radnice, limit domů, bonus za dům, příkon (MW) podle úrovně | `research-towns/shared/levels.lua` → `LEVELS` |
| Suroviny a množství milníků (seznamy kandidátů) | `shared/levels.lua` → `LEVELS[k].upgrade` |
| Max. domů v sérii, dosah domů a překladišť | `shared/levels.lua` → `MAX_HOUSE_DEPTH`, `HOUSE_REACH`, `DEPOT_REACH` |
| Interval zpracování města | `shared/levels.lua` → `TOWN_INTERVAL` |
| Velikost kroku bonusu, strop bonusu | `shared/levels.lua` → `BONUS_STEP`, `BONUS_SLOTS` |
| Recepty domu a překladišť | `prototypes/house.lua`, `prototypes/depots.lua` |
| Barvy dočasné grafiky | `prototypes/hall.lua` → `TINTS`, `prototypes/house.lua` → `TINTS` |
| Barva chodníků a popisků | `scripts/network.lua` → `LINK_COLOR`, `scripts/towns.lua` → `LABEL_COLOR` |

## Testy
- `bash tools/run-unit.sh` – čistá logika.
- `bash tools/run-tests.sh vanilla` a `space-age` – integrační testy (obě varianty před každým commitem).
- `bash tools/run-tests.sh mods <mod>…` – kompatibilita; ověřeno 2026-10-05 s Bob's (16 modů bob*) a `pymodpack`.

## Ruční kontrola ve hře (headless ji neověří)
1. Nová hra, `/rt-create-town` (admin) – radnice 15×15 s popiskem a jménem, popisek i na mapě.
2. Postavit dům u radnice – chodník se vykreslí; dům daleko – ikona varování.
3. Otevřít radnici – panel vpravo: úroveň, domy, elektřina, milník s ikonami, tlačítko Povýšit neaktivní.
4. Přejmenovat město v panelu (Enter) – změní se popisek.
5. Rozvodna bez elektřiny → „Nedostatek elektřiny“, radnice nezkoumá; s elektřinou zkoumá.
6. Dodat milník + 4 domy → Povýšit → radnice a domy změní barvu, panel ukazuje úroveň 2.
7. Výzkum „Automation science pack“ se spustí vyrobením domu.
```

- [ ] **Step 4: docs/user-guide.md a README.md**

`docs/user-guide.md`:

```markdown
# Research Towns – návod

Laboratoře ve hře nejsou. Zkoumá se v **radnicích** měst.

1. **Radnice** zkoumá jako laboratoř, ale přijímá jen vědy úrovně svého města (úroveň 1 = první věda).
2. **Domy** (vyrobíš v montážním stroji) postav do dosahu radnice nebo jiného domu – propojí se visutým
   chodníkem. Nejvýš 5 domů v sérii od radnice; dům dál je neaktivní (ikona varování). Aktivní domy zrychlují
   výzkum, do limitu úrovně (úroveň × 4).
3. **Městská rozvodna** u radnice nebo domu odebírá elektřinu města; bez ní radnice nezkoumá.
4. **Překladiště zboží a kapalin** u radnice nebo aktivního domu dodávají suroviny pro další úroveň (vidíš je
   v panelu radnice). Bere se jen to, co milník potřebuje.
5. Až je milník splněný a máš dost domů, klikni v panelu radnice na **Povýšit město**.

Ladicí příkaz: `/rt-create-town` (admin) založí radnici severně od hráče. Generování měst na mapě přijde v další verzi.
```

`README.md`:

```markdown
# Research Towns

Mod do Factoria 2.0: laboratoře nahrazují radnice měst, která rostou podle toho, co jim dodáváš.
Kompatibilní s overhauly (vědy, suroviny i laboratoře se odvozují z obsahu hry).

- Návod: [docs/user-guide.md](docs/user-guide.md)
- Vývoj: [docs/development.md](docs/development.md)
- Návrh: [docs/superpowers/specs/2026-10-05-research-towns-design.md](docs/superpowers/specs/2026-10-05-research-towns-design.md)

Rychlý start vývoje: `bash tools/run-unit.sh`, `bash tools/run-tests.sh vanilla`, `bash tools/link-mod.sh` + F5 ve VSCode.
```

- [ ] **Step 5: Závěrečné ověření**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla && bash tools/run-tests.sh space-age`
Expected: `UNIT pass=30 fail=0`; obě varianty `RT-TEST DONE pass=20 fail=0 skip=0`. Uklidit `.test-run/` není potřeba (je v `.gitignore`).

- [ ] **Step 6: Commit**

```bash
git add docs README.md research-towns
git commit -m "docs: vývojářská a uživatelská dokumentace, ověření s Bob's a Pyanodonem"
```

---

## Navazující plány (mimo tento plán)

- **Plán 2 – Svět:** generátor měst (`on_chunk_generated`, garantované první město 100–200 dlaždic od spawnu, rozestupy, odstranění hnízd), převzetí neutrálního města, ruina a obnova radnice, výkonový test s mnoha městy.
- **Plán 3 – Grafika a vydání:** modely radnice (5 úrovní), domu (5 variant), překladišť a sprite chodníku z Blenderu (skill `blender-workflow`), ikony, thumbnail, `docs/mod-portal.md`, `tools/package.sh` + `publish.sh`.
