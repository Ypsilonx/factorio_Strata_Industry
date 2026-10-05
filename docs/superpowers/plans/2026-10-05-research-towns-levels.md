# Research Towns – úrovně (plán 1b) – implementační plán

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Úroveň města = jedna věda (milník = nová věda + suroviny), nekonečné úrovně s produktivitou radnice, dobrovolné vylepšování domů s vlastní úrovní a stropem rychlosti +120 %, průběžná spotřeba surovin splněných milníků a městská tabule pro obvodovou síť.

**Architecture:** Data stage spočítá počet úrovní z počtu věd (`science.bands`), vytvoří radnici pro každou vědu a do `mod-data` uloží milníky (věda + suroviny z pásma `TIERS`) i základ nekonečného milníku. Veškerá čísla jsou vzorce v `shared/levels.lua`. Runtime: zpracování města (`towns.process`) rozdělí dodávky z překladišť podle priority spotřeba → milník radnice → vylepšení domu (čistá logika `scripts/allocation.lua`), pak spotřebuje zásobu a zapíše signály do městských tabulí. Čistá logika (úrovně, výběr domu, spotřeba, signály) je testovaná unit testy, chování ve hře integračními testy.

**Tech Stack:** Lua (Factorio 2.0.77 API), Lua 5.3 pro unit testy, headless Factorio (`tools/run-tests.sh`), Git Bash.

**Spec:** `docs/superpowers/specs/2026-10-05-research-towns-design.md` – sekce „Rozšíření“: Úroveň = jeden vědecký balíček, Balanc domů, Obvodová síť, Domy v nekonečných úrovních, Průběžná spotřeba surovin, Příběh.

## Global Constraints

- Prefix `rt`: prototypy `rt-…`, GUI prvky `rt_…` (nesmí kolidovat s vlastnostmi `LuaGuiElement` – hlídá `test_gui_names`), mod-data `rt-levels`, nastavení `rt-…`, remote `research-towns`, log testů `RT-TEST`.
- Herní kód je Lua 5.2: žádné `//`, bitové operátory ani `math.tointeger`; jen `math.floor`/`math.ceil`.
- Nic natvrdo podle jmen cizího obsahu kromě seznamů kandidátů v `shared/levels.lua`; vše odvozené z obsahu hry v `data-final-fixes.lua`.
- Veškerý stav jen ve `storage`; žádná práce každý tick kromě plánovače. Nový stav doplní `state.init` i do starého savu.
- Komentáře a docstringy česky (každá funkce má `---` docstring), 2 mezery, `snake_case`.
- Locale `en` i `cs` se stejnými klíči; žádný text pro hráče natvrdo. Tón příběhu: partnerství, viz spec „Příběh“.
- Laditelné hodnoty jen jako pojmenované konstanty v `shared/levels.lua` (+ startup nastavení `rt-upkeep-multiplier`).
- Testy na konci každého úkolu: `bash tools/run-unit.sh` a `bash tools/run-tests.sh vanilla` zelené; v Task 7 navíc `space-age` a `mods`.
- Commit jen v krocích „Commit“ (schválení plánu = schválení těchto commitů); push nikdy. Zpráva končí řádky
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` a `Claude-Session: https://claude.ai/code/session_011qF8pn2anGDbxkcC6UqKtx`.

## Review Focus

1. **Overhaul s mnoha vědami** (Bob's 18 úrovní, Py 11): rychlost, příkon, pásma surovin i grafické varianty musí dát rozumné hodnoty pro libovolný počet úrovní. → unit `test_levels` s počtem 18 (Task 1) + běh `mods` (Task 7).
2. **Stejná surovina v milníku radnice, ve vylepšení domu i ve spotřebě** (vanilla: milníky 1 a 2 mají stejné pásmo) – musí platit pořadí spotřeba → radnice → dům a přebytek zůstat v překladišti. → unit `test_allocation` (Task 3) + integrační „radnice má přednost“ (Task 3).
3. **Nečinná radnice** (žádný rozběhnutý výzkum nebo prázdná radnice) nesmí spotřebovávat zásobu. → integrační „bez výzkumu se nespotřebovává“ (Task 4).
4. **Starý save z 0.1.0** (domy bez úrovně, města bez zásoby) musí jít načíst. → unit `test_state` (Task 3, 4).
5. **Nekonečné úrovně daleko za poslední vědou** (úroveň 100): konečný příkon, produktivita pod stropem, moduly se vejdou do beaconu. → unit `test_levels` (Task 2).

---

## Mapa souborů

```
research-towns/
  settings.lua                     NOVÉ (T4): startup nastavení rt-upkeep-multiplier
  shared/levels.lua                PŘEPIS (T1, T2, T4): vzorce úrovní, pásma TIERS, bonusy, spotřeba
  prototypes/science.lua           ZMĚNA (T1): bands(raw) → (bands, count), new_at
  prototypes/hall.lua              ZMĚNA (T1): create(level, count, sciences), obecné jméno
  prototypes/bonus.lua             ZMĚNA (T2): modul produktivity, beacon povolí produktivitu
  prototypes/depots.lua            ZMĚNA (T6): městská tabule (constant-combinator)
  prototypes/signals.lua           NOVÉ (T6): virtuální signály tabule
  data.lua, data-final-fixes.lua   ZMĚNA (T1, T6)
  scripts/config.lua               ZMĚNA (T1–T4): počet úrovní, jména radnic, milníky, požadavky domů, spotřeba
  scripts/allocation.lua           NOVÉ (T3): čistá – rozdělení dodávky mezi příjemce podle priority
  scripts/houses.lua               NOVÉ (T3): čistá – výběr domu k vylepšení
  scripts/upkeep.lua               NOVÉ (T4): čistá – spotřeba za minutu, zásoba, odběr
  scripts/board.lua                NOVÉ (T6): signály tabule (čistá) + zápis do kombinátoru
  scripts/state.lua                ZMĚNA (T3, T4, T6): doplnění nových polí do starého savu
  scripts/network.lua              ZMĚNA (T1, T3): jména radnic z config, úroveň domu
  scripts/depots.lua               ZMĚNA (T1, T3, T6): příkon dle vzorce, collect se seznamem příjemců, tabule
  scripts/towns.lua                ZMĚNA (T1–T4, T6): zpracování města
  scripts/gui.lua                  ZMĚNA (T1, T5, T6): panel radnice, panel tabule
  scripts/remote.lua               ZMĚNA (T3, T6): house_level, board_mode, set_board_mode
  control.lua                      ZMĚNA (T6): tagy, kopírování nastavení, plán (blueprint), GUI tabule
  locale/en|cs/locale.cfg          ZMĚNA (T1, T4–T7)
tests/unit/                        test_levels, test_science (změna), test_allocation, test_houses, test_upkeep,
                                   test_state, test_board (nové), run.lua (SUITES)
tests/research-towns-tests/        helpers.lua, control.lua, cases/compat|prototypes|network|upgrade (změna),
                                   cases/houses|upkeep|board (nové)
docs/development.md, docs/user-guide.md, research-towns/changelog.txt, spec (Task 7)
```

---

### Task 1: Úroveň = věda (vzorce, data stage, runtime)

**Files:**
- Modify: `research-towns/shared/levels.lua` (přepis)
- Modify: `research-towns/prototypes/science.lua` (`bands`, `sciences`, nové `new_at`)
- Modify: `research-towns/prototypes/hall.lua`, `research-towns/data-final-fixes.lua`
- Modify: `research-towns/scripts/config.lua`, `network.lua`, `depots.lua`, `towns.lua`, `gui.lua`
- Modify: `research-towns/locale/en/locale.cfg`, `research-towns/locale/cs/locale.cfg`
- Test: `tests/unit/test_levels.lua` (přepis), `tests/unit/test_science.lua`
- Test: `tests/research-towns-tests/helpers.lua`, `cases/compat.lua`, `cases/prototypes.lua`, `cases/network.lua`, `cases/upgrade.lua`, `cases/depots.lua`

**Interfaces:**
- Produces (levels): `hall_name(tier)`, `hall_level(name)`, `hall_names(count)`, `hall_tier(level, count)`, `researching_speed(tier, count)`, `house_limit(level)`, `power_mw(level, count)`, `power_per_tick(level, count)`, `tier_index(level, count)`, `milestone_scale(level)`, `scaled(requirements, level)`, `variant(level, count)`, `house_bonus(house_level)`, `bonus_modules(level, house_levels)`, konstanty `TIERS`, `SCIENCE_PACKS`, `VARIANTS`, `SPEED_FIRST`, `SPEED_LAST`, `SPEED_BONUS_CAP`, … (viz kód).
- Produces (science): `bands(raw) → bands, count`, `sciences(bands, count)`, `new_at(bands, level) → string|nil`.
- Produces (mod-data `rt-levels`): `{ level_count, sciences = {["k"]=…}, upgrade = {["k"]={ {type,name,amount,science?} }}, infinite = { {type,name,amount} } }` – `upgrade[k]` pro k = 1..count−1, první položka je věda úrovně k+1 s `science = true`.
- Produces (config): `level_count()`, `upgrade(level)`, `sciences(level)`, `hall_name(level)`, `hall_names()`.
- Produces (network): `active_house_levels(town) → integer[]` (v T1 má každý aktivní dům úroveň města).
- Produces (status): nové pole `level_count`.
- Produces (test helpers): `H.level_count()`, `H.levels_data()`.

- [ ] **Step 1: Přepiš unit testy úrovní (RED)**

Celý obsah `tests/unit/test_levels.lua`:

```lua
--- Jednotkové testy balančních vzorců úrovní (počet úrovní = počet věd).
local A = require("assert")
local levels = require("shared.levels")

--- Je posloupnost f(1..n) neklesající?
local function non_decreasing(n, f)
  for i = 2, n do
    if f(i) < f(i - 1) then return false end
  end
  return true
end

return {
  { "rychlost radnice od SPEED_FIRST do SPEED_LAST", function()
    A.eq(levels.researching_speed(1, 7), levels.SPEED_FIRST, "první úroveň")
    A.eq(levels.researching_speed(7, 7), levels.SPEED_LAST, "poslední věda")
    A.eq(levels.researching_speed(1, 1), levels.SPEED_FIRST, "jediná věda")
    A.truthy(non_decreasing(18, function(t) return levels.researching_speed(t, 18) end), "roste i pro 18 úrovní")
  end },
  { "limit domů 4 na úroveň, strop 20", function()
    A.eq(levels.house_limit(1), 4, "úroveň 1")
    A.eq(levels.house_limit(5), 20, "úroveň 5")
    A.eq(levels.house_limit(9), 20, "nad stropem")
  end },
  { "příkon od 1 MW do 150 MW, nad poslední vědou dál roste", function()
    A.truthy(math.abs(levels.power_mw(1, 7) - 1) < 1e-9, "úroveň 1")
    A.truthy(math.abs(levels.power_mw(7, 7) - 150) < 1e-6, "poslední věda")
    A.truthy(math.abs(levels.power_mw(8, 7) - 165) < 1e-6, "první nekonečná")
    A.truthy(non_decreasing(30, function(l) return levels.power_mw(l, 18) end), "roste i pro 18 úrovní")
    A.eq(levels.power_per_tick(1, 7), levels.power_mw(1, 7) * 1e6 / 60, "joule za tick")
  end },
  { "pásma surovin se roztáhnou na libovolný počet úrovní", function()
    A.eq(levels.tier_index(1, 7), 1, "první milník")
    A.eq(levels.tier_index(6, 7), #levels.TIERS, "poslední konečný milník")
    A.eq(levels.tier_index(20, 7), #levels.TIERS, "nekonečné")
    A.eq(levels.tier_index(1, 2), 1, "jediný milník")
    local seen = {}
    for k = 1, 17 do seen[levels.tier_index(k, 18)] = true end
    for t = 1, #levels.TIERS do A.truthy(seen[t], "18 úrovní použije pásmo " .. t) end
    A.truthy(non_decreasing(17, function(k) return levels.tier_index(k, 18) end), "pásma neklesají")
  end },
  { "pásma mají platné kandidáty", function()
    for t, tier in ipairs(levels.TIERS) do
      A.truthy(#tier > 0, "pásmo " .. t)
      for _, req in ipairs(tier) do
        A.truthy((req.type == "item" or req.type == "fluid") and #req.candidates > 0 and req.amount > 0,
          "požadavek pásma " .. t)
      end
    end
  end },
  { "množství milníku roste s úrovní", function()
    A.eq(levels.milestone_scale(1), 1, "úroveň 1")
    local out = levels.scaled({ { type = "item", name = "a", amount = 100, science = true } }, 3)
    A.eq(out[1].amount, math.floor(100 * levels.milestone_scale(3) + 0.5), "úroveň 3")
    A.eq(out[1].science, true, "příznak vědy zůstane")
  end },
  { "grafické varianty pokryjí všechny úrovně", function()
    A.eq(levels.variant(1, 7), 1, "první")
    A.eq(levels.variant(7, 7), levels.VARIANTS, "poslední věda")
    A.eq(levels.variant(100, 7), levels.VARIANTS, "nekonečné")
    local seen = {}
    for t = 1, 18 do seen[levels.variant(t, 18)] = true end
    for v = 1, levels.VARIANTS do A.truthy(seen[v], "18 úrovní použije variantu " .. v) end
  end },
  { "bonus domu je (úroveň domu + 1) %", function()
    for h = 1, 5 do
      A.eq(levels.bonus_modules(1, { h }) * levels.BONUS_STEP, levels.house_bonus(h), "dům úrovně " .. h)
      A.truthy(math.abs(levels.house_bonus(h) - (h + 1) / 100) < 1e-9, "house_bonus " .. h)
    end
    A.eq(levels.bonus_modules(1, {}), 0, "bez domů")
  end },
  { "počítají se nejlepší domy do limitu a strop +120 %", function()
    A.eq(levels.bonus_modules(1, { 1, 1, 1, 1, 5 }), 6 + 2 + 2 + 2, "nejlepší 4 domy")
    local many = {}
    for i = 1, 20 do many[i] = 10 end
    A.eq(levels.bonus_modules(5, many), math.floor(levels.SPEED_BONUS_CAP / levels.BONUS_STEP + 0.5), "strop")
    A.truthy(levels.bonus_modules(5, many) <= levels.BONUS_SLOTS, "vejde se do beaconu")
  end },
  { "jména radnic tam i zpět", function()
    A.eq(levels.hall_name(3), "rt-town-hall-3", "hall_name")
    A.eq(levels.hall_level("rt-town-hall-3"), 3, "hall_level")
    A.eq(levels.hall_level("lab"), nil, "cizí jméno")
    A.eq(#levels.hall_names(7), 7, "hall_names")
    A.eq(levels.hall_tier(9, 7), 7, "nad poslední vědou zůstává nejvyšší radnice")
  end },
}
```

- [ ] **Step 2: Uprav unit testy věd (RED)**

V `tests/unit/test_science.lua` nahraď první dva testy (`"první věda je úroveň 1, ostatní rovnoměrně 2–5"` a `"vědy úrovní jsou kumulativní"`):

```lua
  { "první věda je úroveň 1, každá další otevírá novou úroveň", function()
    local bands, count = science.bands(raw())
    A.eq(bands.red, 1, "red")
    A.eq(bands.green, 2, "green")
    A.eq(bands.blue, 3, "blue")
    A.eq(bands.mil, 4, "mil (stejná hloubka jako blue → podle jména)")
    A.eq(bands.secret, nil, "věda skrytého výzkumu")
    A.eq(count, 4, "počet úrovní")
    A.eq(science.new_at(bands, 3), "blue", "úroveň 3 otevírá blue")
    A.eq(science.new_at(bands, 9), nil, "neexistující úroveň")
  end },
  { "vědy úrovní jsou kumulativní", function()
    local bands, count = science.bands(raw())
    local list = science.sciences(bands, count)
    A.eq(table.concat(list[1], ","), "red", "úroveň 1")
    A.eq(table.concat(list[3], ","), "red,green,blue", "úroveň 3")
    A.eq(table.concat(list[4], ","), "red,green,blue,mil", "úroveň 4")
  end },
```

Ve zbytku souboru nahraď všechny výskyty `science.bands(raw(), 5)` za `science.bands(raw())` a `science.bands(r, 5)` za `science.bands(r)` (`sed -i 's/science.bands(raw(), 5)/science.bands(raw())/; s/science.bands(r, 5)/science.bands(r)/' tests/unit/test_science.lua`). Výsledné úrovně výzkumů a dostupnost zůstávají stejné (green 2, blue 3).

- [ ] **Step 3: Spusť unit testy**

Run: `bash tools/run-unit.sh`
Expected: FAIL v `test_levels` (např. `attempt to call a nil value (field 'researching_speed')`) a v `test_science` (`count` je nil / `new_at` neexistuje).

- [ ] **Step 4: Přepiš `shared/levels.lua`**

Celý obsah `research-towns/shared/levels.lua`:

```lua
--- Balanc úrovní měst – jediné místo, kde se ladí čísla. Sdílí ho data stage i control stage.
--- Počet úrovní = počet věd ve hře (spočítá data-final-fixes, runtime ho čte z mod-data); hodnoty úrovní jsou
--- vzorce, takže fungují pro vanillu (7 věd) i overhauly (Bob's 18). Suroviny milníků jsou seznamy kandidátů:
--- v data-final-fixes vyhraje první existující a dostupný (kompatibilita s overhauly), viz prototypes/science.lua.
local M = {}

--- Nejvýš tolik domů v sérii od radnice (hloubka v grafu sítě).
M.MAX_HOUSE_DEPTH = 5
--- Dosah propojení domů: mezera mezi okraji budov v dlaždicích.
M.HOUSE_REACH = 6
--- Dosah překladiště k nejbližší budově města (mezera mezi okraji).
M.DEPOT_REACH = 4
--- Jak často se město zpracuje (ticky).
M.TOWN_INTERVAL = 120
--- Bonus za jeden skrytý modul v beaconu radnice.
M.BONUS_STEP = 0.01
--- Počet slotů skrytého beaconu.
M.BONUS_SLOTS = 200
--- Rozměr radnice v dlaždicích.
M.HALL_SIZE = 15

--- Rychlost výzkumu radnice na první a na poslední vědecké úrovni (mezi nimi lineárně).
M.SPEED_FIRST = 2
M.SPEED_LAST = 10
--- Domy s bonusem: HOUSES_PER_LEVEL × úroveň, nejvýš HOUSE_LIMIT_MAX. Stejný počet je podmínkou povýšení.
M.HOUSES_PER_LEVEL = 4
M.HOUSE_LIMIT_MAX = 20
--- Strop bonusu k rychlosti ze všech domů dohromady (+120 %).
M.SPEED_BONUS_CAP = 1.2
--- Příkon města (MW) na první a na poslední vědecké úrovni (mezi nimi geometricky).
M.POWER_FIRST_MW = 1
M.POWER_LAST_MW = 150
--- Nad poslední vědou roste příkon o tento díl příkonu poslední úrovně za každou úroveň.
M.POWER_INFINITE_GROWTH = 0.1
--- Kusů nové vědy v milníku.
M.SCIENCE_PACKS = 200
--- Množství surovin milníku k → k+1 = základ z TIERS × (1 + MILESTONE_GROWTH × (k − 1)).
M.MILESTONE_GROWTH = 0.25
--- Počet grafických variant radnice a domu (rozloží se rovnoměrně na vědecké úrovně).
M.VARIANTS = 5

--- Pásma kandidátů surovin milníků od nejranějšího; tier_index je roztáhne na libovolný počet úrovní.
--- Nad poslední vědou se používá poslední pásmo.
M.TIERS = {
  {
    { type = "item", candidates = { "wood" }, amount = 200 },
    { type = "item", candidates = { "iron-plate" }, amount = 400 },
    { type = "item", candidates = { "copper-plate" }, amount = 200 },
    { type = "item", candidates = { "stone-brick", "stone" }, amount = 200 },
  },
  {
    { type = "item", candidates = { "steel-plate", "iron-plate" }, amount = 400 },
    { type = "item", candidates = { "electronic-circuit" }, amount = 400 },
    { type = "item", candidates = { "pipe" }, amount = 100 },
    { type = "fluid", candidates = { "water" }, amount = 20000 },
  },
  {
    { type = "item", candidates = { "plastic-bar" }, amount = 500 },
    { type = "item", candidates = { "advanced-circuit", "electronic-circuit" }, amount = 300 },
    { type = "item", candidates = { "engine-unit" }, amount = 100 },
    { type = "item", candidates = { "concrete", "stone-brick" }, amount = 1000 },
    { type = "fluid", candidates = { "petroleum-gas", "crude-oil" }, amount = 30000 },
  },
  {
    { type = "item", candidates = { "processing-unit", "advanced-circuit" }, amount = 400 },
    { type = "item", candidates = { "low-density-structure", "plastic-bar" }, amount = 200 },
    { type = "item", candidates = { "electric-engine-unit", "engine-unit" }, amount = 200 },
    { type = "item", candidates = { "refined-concrete", "concrete" }, amount = 1000 },
    { type = "fluid", candidates = { "lubricant", "heavy-oil" }, amount = 30000 },
  },
  {
    { type = "item", candidates = { "flying-robot-frame", "electric-engine-unit" }, amount = 200 },
    { type = "item", candidates = { "rocket-fuel", "solid-fuel" }, amount = 300 },
    { type = "item", candidates = { "low-density-structure", "plastic-bar" }, amount = 400 },
    { type = "item", candidates = { "processing-unit", "advanced-circuit" }, amount = 600 },
    { type = "fluid", candidates = { "lubricant", "heavy-oil" }, amount = 50000 },
  },
}

--- Jméno prototypu radnice dané vědecké úrovně.
function M.hall_name(tier)
  return "rt-town-hall-" .. tier
end

--- Úroveň podle jména prototypu radnice, nebo nil pro jinou entitu.
function M.hall_level(name)
  local level = name:match("^rt%-town%-hall%-(%d+)$")
  return level and tonumber(level)
end

--- Jména prototypů radnic 1..count.
function M.hall_names(count)
  local names = {}
  for tier = 1, count do names[tier] = M.hall_name(tier) end
  return names
end

--- Vědecká úroveň (prototyp radnice) pro úroveň města; nad poslední vědou zůstává nejvyšší.
function M.hall_tier(level, count)
  return math.min(level, count)
end

--- Rychlost výzkumu radnice vědecké úrovně tier z count.
function M.researching_speed(tier, count)
  if count <= 1 then return M.SPEED_FIRST end
  return M.SPEED_FIRST + (M.SPEED_LAST - M.SPEED_FIRST) * (tier - 1) / (count - 1)
end

--- Kolik domů dává bonus (a kolik jich je potřeba k povýšení) na dané úrovni.
function M.house_limit(level)
  return math.min(M.HOUSE_LIMIT_MAX, M.HOUSES_PER_LEVEL * level)
end

--- Příkon města v MW.
function M.power_mw(level, count)
  local tier = M.hall_tier(level, count)
  local mw = M.POWER_FIRST_MW
  if count > 1 then mw = M.POWER_FIRST_MW * (M.POWER_LAST_MW / M.POWER_FIRST_MW) ^ ((tier - 1) / (count - 1)) end
  if level > count then mw = mw * (1 + M.POWER_INFINITE_GROWTH * (level - count)) end
  return mw
end

--- Příkon města v joulech za tick.
function M.power_per_tick(level, count)
  return M.power_mw(level, count) * 1e6 / 60
end

--- Index pásma TIERS pro milník level → level+1. Konečné milníky (1..count−1) se rozloží rovnoměrně
--- na všechna pásma; poslední konečný a nekonečné milníky dostanou poslední pásmo.
function M.tier_index(level, count)
  local last = count - 1
  if level >= last then return last <= 1 and 1 or #M.TIERS end
  return math.floor((level - 1) * (#M.TIERS - 1) / (last - 1)) + 1
end

--- Násobek množství surovin milníku level → level+1.
function M.milestone_scale(level)
  return 1 + M.MILESTONE_GROWTH * (level - 1)
end

--- Kopie požadavků s množstvím × milestone_scale(level) (zaokrouhleno; ostatní pole zůstanou).
--- @param requirements table[] { {type, name, amount, science?} }
function M.scaled(requirements, level)
  local scale = M.milestone_scale(level)
  local out = {}
  for i, req in ipairs(requirements) do
    out[i] = { type = req.type, name = req.name, amount = math.floor(req.amount * scale + 0.5), science = req.science }
  end
  return out
end

--- Grafická varianta (1..VARIANTS) radnice nebo domu dané úrovně.
function M.variant(level, count)
  local tier = M.hall_tier(level, count)
  return math.min(M.VARIANTS, math.floor((tier - 1) * M.VARIANTS / count) + 1)
end

--- Bonus jednoho domu k rychlosti výzkumu: (úroveň domu + 1) %.
function M.house_bonus(house_level)
  return (house_level + 1) / 100
end

--- Počet bonusových modulů rychlosti: domy od nejvyšší úrovně, nejvýš house_limit(level) domů,
--- součet zastropovaný SPEED_BONUS_CAP.
--- @param house_levels integer[] úrovně aktivních domů
function M.bonus_modules(level, house_levels)
  local sorted = {}
  for i, house_level in ipairs(house_levels) do sorted[i] = house_level end
  table.sort(sorted, function(a, b) return a > b end)
  local bonus = 0
  for i = 1, math.min(#sorted, M.house_limit(level)) do bonus = bonus + M.house_bonus(sorted[i]) end
  return math.floor(math.min(bonus, M.SPEED_BONUS_CAP) / M.BONUS_STEP + 0.5)
end

return M
```

- [ ] **Step 5: Uprav `prototypes/science.lua`**

Nahraď funkci `M.bands` a doplň `M.new_at` za funkci `M.sciences`:

```lua
--- Rozdělí vědy používané výzkumy do úrovní: nejranější věda(y) = úroveň 1, každá další věda (podle hloubky
--- prvního výzkumu, který ji používá, při shodě podle jména) otevírá další úroveň.
--- @return table<string, integer> věda → úroveň, integer počet úrovní
function M.bands(raw)
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
  local bands, count = {}, 1
  for _, pack in ipairs(packs) do
    if tier[pack] == tier[packs[1]] then
      bands[pack] = 1
    else
      count = count + 1
      bands[pack] = count
    end
  end
  return bands, count
end
```

V `M.sciences` přejmenuj parametr `max_level` na `count` (docstring: „Vědy, které přijímá radnice každé úrovně 1..count“). Za ni přidej:

```lua
--- Věda, kterou daná úroveň otevírá (pro úroveň ≥ 2 právě jedna), nebo nil.
function M.new_at(bands, level)
  for pack, band in pairs(bands) do
    if band == level then return pack end
  end
  return nil
end
```

- [ ] **Step 6: Spusť unit testy**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=… fail=0`

- [ ] **Step 7: Uprav integrační testy (RED)**

V `tests/research-towns-tests/helpers.lua` přidej před `return H`:

```lua
--- Data úrovní vyřešená v data stage (mod-data rt-levels).
function H.levels_data()
  return prototypes.mod_data["rt-levels"].data
end

--- Počet vědeckých úrovní (= počet věd ve hře).
function H.level_count()
  return H.levels_data().level_count
end
```

Celý obsah `tests/research-towns-tests/cases/compat.lua`:

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

--- Vědy, které přijímá radnice dané vědecké úrovně.
local function inputs(tier)
  return prototypes.entity[levels.hall_name(tier)].lab_inputs
end

--- Existuje předmět/kapalina požadavku?
local function exists(req)
  return (req.type == "fluid" and prototypes.fluid[req.name] or prototypes.item[req.name]) ~= nil
end

return {
  { name = "radnice všech úrovní existují a každá další přidá právě jednu vědu", steps = { { ticks = 1, run = function()
    local count = H.level_count()
    H.check(count >= 2, "jen " .. count .. " úroveň")
    local previous
    for tier = 1, count do
      local proto = prototypes.entity[levels.hall_name(tier)]
      H.check(proto and proto.type == "lab", "chybí radnice " .. tier)
      if previous then H.check(#proto.lab_inputs == previous + 1, "úroveň " .. tier .. " nepřidala jednu vědu") end
      previous = #proto.lab_inputs
    end
    H.check(prototypes.entity[levels.hall_name(count + 1)] == nil, "radnice nad počtem věd")
  end } } },
  { name = "úroveň 1 přijímá nejvýš polovinu věd nejvyšší úrovně", steps = { { ticks = 1, run = function()
    -- Hlídá pořadí final-fixes: když pásma vzniknou před dopočtem stromu overhaulu, skončí skoro vše na úrovni 1.
    local first, top = #inputs(1), #inputs(H.level_count())
    H.check(first * 2 <= top, "úroveň 1: " .. first .. " věd, nejvyšší: " .. top)
  end } } },
  { name = "nejvyšší radnice umí všechny vědy výzkumů", steps = { { ticks = 1, run = function()
    local top = set(inputs(H.level_count()))
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
  { name = "milník chce vědu další úrovně a existující suroviny", steps = { { ticks = 1, run = function()
    local data, count = H.levels_data(), H.level_count()
    for level = 1, count - 1 do
      local upgrade = data.upgrade[tostring(level)]
      H.check(upgrade and #upgrade > 1, "úroveň " .. level .. " nemá milník se surovinami")
      local here, next_level, sciences = set(inputs(level)), set(inputs(level + 1)), 0
      for _, req in ipairs(upgrade) do
        H.check(exists(req), "surovina " .. req.name .. " neexistuje")
        if req.science then
          sciences = sciences + 1
          H.check(next_level[req.name] and not here[req.name], "věda milníku " .. level .. ": " .. req.name)
        end
      end
      H.check(sciences == 1, "milník " .. level .. " má " .. sciences .. " věd")
    end
    H.check(#data.infinite > 0, "nekonečný milník je prázdný")
    for _, req in ipairs(data.infinite) do H.check(exists(req), "surovina " .. req.name .. " neexistuje") end
  end } } },
}
```

V `tests/research-towns-tests/cases/prototypes.lua` přidej do seznamu testů:

```lua
  { name = "rychlost radnice roste od první do poslední vědy", steps = { { ticks = 1, run = function()
    local count = H.level_count()
    local first = prototypes.entity[levels.hall_name(1)].researching_speed
    local last = prototypes.entity[levels.hall_name(count)].researching_speed
    H.check(math.abs(first - levels.SPEED_FIRST) < 1e-6, "rychlost úrovně 1: " .. first)
    H.check(math.abs(last - levels.SPEED_LAST) < 1e-6, "rychlost úrovně " .. count .. ": " .. last)
  end } } },
```

V `cases/network.lua` nahraď `levels.bonus_modules(1, 4)` za `levels.bonus_modules(1, { 1, 1, 1, 1 })` a `levels.bonus_modules(1, 8)` za `levels.bonus_modules(1, { 1, 1, 1, 1, 1, 1, 1, 1 })`.

V `cases/depots.lua` v testu „překladiště kapalin dodá kapalinu milníku“ nahraď `remote.call(R, "set_level", ctx.town, 2)` za nalezení první úrovně, jejíž milník chce kapalinu (pásma se teď roztahují, ve vanille má milník 2 jen předměty):

```lua
      local fluid_level
      for level = 1, H.level_count() - 1 do
        for _, req in ipairs(H.levels_data().upgrade[tostring(level)]) do
          if req.type == "fluid" and not fluid_level then fluid_level = level end
        end
      end
      H.check(fluid_level, "žádný milník nechce kapalinu")
      remote.call(R, "set_level", ctx.town, fluid_level)
```

V `cases/upgrade.lua` nahraď `levels.bonus_modules(2, 4)` za `levels.bonus_modules(2, { 2, 2, 2, 2 })` a kontrolu vzhledu domu za:

```lua
        H.check(ctx.houses[1].graphics_variation == levels.variant(2, H.level_count()), "dům nemá vzhled úrovně 2")
```

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla`
Expected: unit zelené; integrační FAIL (např. `attempt to compare nil with number` v `H.level_count`, protože mod-data `level_count` zatím neexistuje, a `bonus_modules` v runtime volá starou signaturu).

- [ ] **Step 8: Uprav prototyp radnice**

V `research-towns/prototypes/hall.lua` nahraď docstring a hlavičku `M.create` a řádky s tintem, ikonou a rychlostí:

```lua
--- Přidá prototyp radnice dané vědecké úrovně.
--- @param level integer 1..count
--- @param count integer počet vědeckých úrovní
--- @param sciences string[] vědy, které radnice přijímá
function M.create(level, count, sciences)
  local base = data.raw.lab["lab"]
  local half = levels.HALL_SIZE / 2
  local factor = levels.HALL_SIZE / 3
  local tint = M.TINTS[levels.variant(level, count)]
  local hall = table.deepcopy(base)
  hall.name = levels.hall_name(level)
  -- Jedno jméno pro všechny úrovně (počet úrovní závisí na modech); číslo úrovně jde parametrem.
  hall.localised_name = { "entity-name.rt-town-hall", level }
  hall.localised_description = { "entity-description.rt-town-hall" }
  hall.icons = { { icon = base.icon, icon_size = base.icon_size, tint = tint } }
```

a dále v téže funkci `M.TINTS[level]` → `tint` (obě animace) a
`hall.researching_speed = levels.researching_speed(level, count)`. Docstring `M.TINTS` změň na „Odstín dočasné grafiky podle varianty (levels.variant)“.

- [ ] **Step 9: Přepiš `data-final-fixes.lua`**

Celý obsah `research-towns/data-final-fixes.lua`:

```lua
-- Research Towns – vše odvozené z obsahu hry: odstranění laboratoří, úrovně podle věd, milníky, radnice, mod-data.
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

local bands, count = science.bands(data.raw)
local sciences = science.sciences(bands, count)
local availability = science.availability(data.raw, science.tech_levels(data.raw, bands))
local exists = science.exists_in(data.raw)

--- Vyřeší pásmo surovin pro milník level → level+1 a zaloguje výsledek.
local function milestone(level)
  local resolved, dropped = science.resolve(levels.TIERS[levels.tier_index(level, count)], availability, level, exists)
  local names = {}
  for _, req in ipairs(resolved) do names[#names + 1] = req.name .. "×" .. req.amount end
  log("research-towns: suroviny milníku " .. level .. "→" .. (level + 1) .. " (základ): " .. table.concat(names, ", ")
    .. (#dropped > 0 and (" | vynecháno: " .. table.concat(dropped, ", ")) or ""))
  return resolved
end

local mod_data = { level_count = count, sciences = {}, upgrade = {} }
log("research-towns: " .. count .. " úrovní (věd)")
for level = 1, count do
  hall.create(level, count, sciences[level])
  mod_data.sciences[tostring(level)] = sciences[level]
  log("research-towns: úroveň " .. level .. " vědy: " .. table.concat(sciences[level], ", "))
  if level < count then
    local upgrade = levels.scaled(milestone(level), level)
    table.insert(upgrade, 1,
      { type = "item", name = science.new_at(bands, level + 1), amount = levels.SCIENCE_PACKS, science = true })
    mod_data.upgrade[tostring(level)] = upgrade
  end
end
-- Nekonečné úrovně: základ posledního pásma, runtime ho násobí milestone_scale(úroveň).
mod_data.infinite = milestone(count)

data:extend({ { type = "mod-data", name = "rt-levels", data = mod_data } })
```

- [ ] **Step 10: Runtime – config, síť, překladiště, města, GUI**

Celý obsah `research-towns/scripts/config.lua`:

```lua
--- Úrovně vyřešené v data stage (mod-data „rt-levels“): počet úrovní, vědy radnic a milníky.
local levels = require("shared.levels")

local data = prototypes.mod_data["rt-levels"].data

local M = {}

--- Počet vědeckých úrovní (= počet věd ve hře); nad ním jsou nekonečné úrovně.
function M.level_count()
  return data.level_count
end

--- Požadavky na povýšení z dané úrovně ({ {type, name, amount, science?} }), nil nad poslední vědou.
function M.upgrade(level)
  return data.upgrade[tostring(level)]
end

--- Vědy, které přijímá radnice dané úrovně.
function M.sciences(level)
  return data.sciences[tostring(levels.hall_tier(level, data.level_count))]
end

--- Jméno prototypu radnice pro úroveň města.
function M.hall_name(level)
  return levels.hall_name(levels.hall_tier(level, data.level_count))
end

--- Jména všech prototypů radnic.
function M.hall_names()
  return levels.hall_names(data.level_count)
end

return M
```

V `research-towns/scripts/network.lua`:
- přidej `local config = require("scripts.config")` pod `local levels = …`;
- v `M.names()` nahraď `levels.hall_names()` za `config.hall_names()`;
- v `refresh_house` nahraď řádek s `graphics_variation` za
  `node.entity.graphics_variation = levels.variant(town and town.level or 1, config.level_count())`;
- přidej za `M.active_houses`:

```lua
--- Úrovně aktivních domů města (zatím mají domy úroveň města).
--- @return integer[]
function M.active_house_levels(town)
  local list = {}
  for key in pairs(town.houses) do
    local node = storage.nodes[key]
    if node and M.is_active(node) then list[#list + 1] = town.level end
  end
  return list
end
```

V `research-towns/scripts/depots.lua` v `M.apply_town_power` nahraď výpočet `usage` za
`local usage = levels.power_per_tick(town.level, config.level_count()) / #list`.

V `research-towns/scripts/towns.lua`:
- `M.update_bonus`: `local wanted = levels.bonus_modules(town.level, network.active_house_levels(town))`;
- `M.create`: `local name = config.hall_name(1)`;
- `M.can_upgrade`: poslední řádek `and network.active_houses(town) >= levels.house_limit(town.level)`;
- `M.set_level`: `local hall = surface.create_entity({ name = config.hall_name(level), position = position, force = force })`;
- `M.status` nahraď celou:

```lua
--- Stav města pro GUI a remote rozhraní.
function M.status(town)
  local count = config.level_count()
  local requirements = {}
  for _, req in ipairs(config.upgrade(town.level) or {}) do
    requirements[#requirements + 1] = {
      type = req.type, name = req.name, amount = req.amount,
      delivered = math.min(req.amount, town.progress[milestones.key(req.type, req.name)] or 0),
    }
  end
  local beacon = town.beacon
  return {
    id = town.id, name = town.name, level = town.level, level_count = count, hall = town.hall.unit_number,
    active_houses = network.active_houses(town), house_limit = levels.house_limit(town.level),
    bonus = levels.bonus_modules(town.level, network.active_house_levels(town)) * levels.BONUS_STEP,
    beacon_modules = beacon and beacon.valid and beacon.get_module_inventory().get_item_count(BONUS_MODULE) or 0,
    power_ok = town.power_ok, power_watts = levels.power_mw(town.level, count) * 1e6,
    requirements = requirements, can_upgrade = M.can_upgrade(town),
  }
end
```

V `research-towns/scripts/gui.lua`:
- přidej `local config = require("scripts.config")`;
- v `M.ensure` v kotvě `names = levels.hall_names()` → `names = config.hall_names()`;
- ve `fill` řádek s úrovní:
  `frame[n.level].caption = { "rt.gui-level", status.level, math.min(status.level, status.level_count), status.level_count }`.

Ověř, že nic nevolá odstraněné API: `grep -rn "MAX_LEVEL\|levels.get(\|LEVELS\[" research-towns tests` → žádný výsledek.

- [ ] **Step 11: Locale**

V `research-towns/locale/en/locale.cfg` nahraď pět řádků `rt-town-hall-1..5` v `[entity-name]` jedním řádkem `rt-town-hall=Town hall (level __1__)` a pět řádků v `[entity-description]` řádkem
`rt-town-hall=The heart of the town, where its scholars meet. Researches like a lab and accepts only the science packs of its town level.`
V `[rt]` změň `gui-level=Level __1__ (sciences __2__ / __3__)`.

V `cs` obdobně: `rt-town-hall=Radnice (úroveň __1__)`,
`rt-town-hall=Srdce města, kde se scházejí jeho učenci. Zkoumá jako laboratoř a přijímá jen vědecké balíčky úrovně svého města.`,
`gui-level=Úroveň __1__ (vědy __2__ / __3__)`.

- [ ] **Step 12: Spusť testy**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla`
Expected: `UNIT pass=… fail=0`, `RT-TEST DONE pass=… fail=0 skip=0`. V `.test-run/vanilla/write-data/factorio-current.log` řádek `research-towns: 7 úrovní (věd)`.

- [ ] **Step 13: Commit**

```bash
git add research-towns tests
git commit -m "feat: úroveň města = věda, vzorce úrovní místo tabulky

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011qF8pn2anGDbxkcC6UqKtx"
```

---

### Task 2: Nekonečné úrovně s produktivitou radnice

**Files:**
- Modify: `research-towns/shared/levels.lua`, `research-towns/prototypes/bonus.lua`
- Modify: `research-towns/scripts/config.lua`, `research-towns/scripts/towns.lua`
- Test: `tests/unit/test_levels.lua`, `tests/research-towns-tests/cases/upgrade.lua`

**Interfaces:**
- Consumes: `levels.scaled`, `levels.hall_tier`, `config.hall_name`, mod-data `infinite`.
- Produces (levels): `PRODUCTIVITY_MAX`, `PRODUCTIVITY_DECAY`, `productivity(level, count)`, `productivity_modules(level, count)`; `BONUS_SLOTS = 250`.
- Produces (config): `upgrade(level)` vrací pro `level >= level_count()` nekonečný milník násobený `milestone_scale(level)`.
- Produces (status): `productivity` (číslo, 0.1 = +10 %), `productivity_modules`.

- [ ] **Step 1: Unit testy produktivity (RED)**

Přidej do `tests/unit/test_levels.lua`:

```lua
  { "produktivita jen nad poslední vědou, klesající přírůstky pod stropem", function()
    A.eq(levels.productivity(7, 7), 0, "poslední věda")
    local p1, p2, p3 = levels.productivity(8, 7), levels.productivity(9, 7), levels.productivity(10, 7)
    A.truthy(p1 > 0 and p2 > p1 and p3 > p2, "roste")
    A.truthy(p2 - p1 < p1, "přírůstky klesají")
    A.truthy(levels.productivity(1000, 7) <= levels.PRODUCTIVITY_MAX, "strop")
  end },
  { "rychlost i produktivita se vejdou do beaconu, příkon zůstane konečný", function()
    local speed = math.floor(levels.SPEED_BONUS_CAP / levels.BONUS_STEP + 0.5)
    A.truthy(speed + levels.productivity_modules(1000, 7) <= levels.BONUS_SLOTS, "sloty beaconu")
    local mw = levels.power_mw(100, 7)
    A.truthy(mw > levels.POWER_LAST_MW and mw < math.huge, "příkon na úrovni 100")
  end },
```

Run: `bash tools/run-unit.sh`
Expected: FAIL `attempt to call a nil value (field 'productivity')`.

- [ ] **Step 2: Implementace v `levels.lua`**

Změň `M.BONUS_SLOTS = 250` (docstring: „Počet slotů skrytého beaconu (rychlost do SPEED_BONUS_CAP + produktivita do PRODUCTIVITY_MAX).“). Za `M.VARIANTS` přidej:

```lua
--- Nekonečné úrovně: produktivita radnice se blíží PRODUCTIVITY_MAX; každá úroveň nad poslední vědou přidá
--- (1 − PRODUCTIVITY_DECAY) ze zbývajícího rozdílu (klesající křivka).
M.PRODUCTIVITY_MAX = 1
M.PRODUCTIVITY_DECAY = 0.9
```

Na konec (před `return M`):

```lua
--- Produktivita výzkumu radnice (0.1 = +10 %); jen nad poslední vědou.
function M.productivity(level, count)
  if level <= count then return 0 end
  return M.PRODUCTIVITY_MAX * (1 - M.PRODUCTIVITY_DECAY ^ (level - count))
end

--- Počet modulů produktivity ve skrytém beaconu.
function M.productivity_modules(level, count)
  return math.floor(M.productivity(level, count) / M.BONUS_STEP + 0.5)
end
```

Run: `bash tools/run-unit.sh` → Expected: `fail=0`.

- [ ] **Step 3: Integrační test (RED)**

Přidej do `tests/research-towns-tests/cases/upgrade.lua`:

```lua
  {
    name = "nad poslední vědou zůstává nejvyšší radnice a přidá produktivitu",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.count = H.level_count()
      remote.call(R, "set_level", ctx.town, ctx.count + 3)
      H.hall(ctx.town).insert({ name = "automation-science-pack", count = 5 })
    end,
    steps = {
      { ticks = 1, run = function(ctx)
        local hall = H.hall(ctx.town)
        H.check(hall.name == levels.hall_name(ctx.count), "radnice: " .. hall.name)
        local expected = levels.productivity_modules(ctx.count + 3, ctx.count) * levels.BONUS_STEP
        local productivity = hall.effects and hall.effects.productivity or 0
        H.check(math.abs(productivity - expected) < 1e-6, "produktivita " .. productivity .. " ≠ " .. expected)
        H.check(#H.status(ctx.town).requirements > 0, "nekonečný milník je prázdný")
        ctx.unit = hall.unit_number
        remote.call(R, "set_level", ctx.town, ctx.count + 4)
      end },
      { ticks = 1, run = function(ctx)
        local hall = H.hall(ctx.town)
        H.check(hall.unit_number == ctx.unit, "stejný prototyp se zbytečně vyměnil")
        H.check(hall.get_item_count("automation-science-pack") == 5, "balíčky se ztratily")
        H.check(H.status(ctx.town).level == ctx.count + 4, "úroveň")
      end },
    },
  },
```

Run: `bash tools/run-tests.sh vanilla`
Expected: FAIL tohoto testu (produktivita 0 ≠ očekávaná, prázdný milník).

- [ ] **Step 4: Modul produktivity a beacon**

V `research-towns/prototypes/bonus.lua` změň `beacon.allowed_effects = { "speed", "productivity" }`, docstring souboru na „Skrytý beacon uprostřed radnice: moduly rychlosti (bonus za domy) a produktivity (nekonečné úrovně).“ a do `data:extend` přidej za `rt-bonus-module`:

```lua
  {
    type = "module", name = "rt-productivity-module", icon = "__base__/graphics/icons/productivity-module.png",
    hidden = true, subgroup = "rt-town", category = "rt-bonus", tier = 1, stack_size = 200,
    effect = { productivity = levels.BONUS_STEP },
  },
```

Do locale `[item-name]` přidej `rt-productivity-module=Town research productivity` (en) / `rt-productivity-module=Výzkumná produktivita města` (cs).

- [ ] **Step 5: Nekonečný milník v config**

V `research-towns/scripts/config.lua` nahraď `M.upgrade`:

```lua
--- Požadavky na povýšení z dané úrovně ({ {type, name, amount, science?} }). Nad poslední vědou nekonečný milník:
--- suroviny posledního pásma × milestone_scale(level), bez vědy.
function M.upgrade(level)
  if level < data.level_count then return data.upgrade[tostring(level)] end
  return levels.scaled(data.infinite, level)
end
```

- [ ] **Step 6: Moduly a výměna radnice v `towns.lua`**

Přidej konstantu `local PRODUCTIVITY_MODULE = "rt-productivity-module"` pod `BONUS_MODULE` a nahraď `M.update_bonus`:

```lua
--- Nastaví počet modulů daného jména v inventáři beaconu.
local function set_modules(inventory, name, wanted)
  local have = inventory.get_item_count(name)
  if wanted > have then
    inventory.insert({ name = name, count = wanted - have })
  elseif wanted < have then
    inventory.remove({ name = name, count = have - wanted })
  end
end

--- Nastaví skrytý beacon: moduly rychlosti podle aktivních domů a produktivity podle nekonečné úrovně.
function M.update_bonus(town)
  local beacon = ensure_beacon(town)
  if not beacon then return end
  local inventory = beacon.get_module_inventory()
  set_modules(inventory, BONUS_MODULE, levels.bonus_modules(town.level, network.active_house_levels(town)))
  set_modules(inventory, PRODUCTIVITY_MODULE, levels.productivity_modules(town.level, config.level_count()))
end
```

Nahraď `M.set_level`:

```lua
--- Vymění entitu radnice za jiný prototyp (stejný půdorys) a přenese balíčky i moduly.
local function replace_hall(town, name)
  local old = town.hall
  local surface, position, force = old.surface, old.position, old.force
  local packs = take_inventory(old, defines.inventory.lab_input)
  local modules = take_inventory(old, defines.inventory.lab_modules)
  local old_key = old.unit_number
  old.destroy()
  local hall = surface.create_entity({ name = name, position = position, force = force })
  restore_inventory(packs, hall, defines.inventory.lab_input)
  restore_inventory(modules, hall, defines.inventory.lab_modules)
  network.replace_hall(old_key, hall)
  town.hall = hall
end

--- Nastaví úroveň města: radnici vymění jen při změně prototypu (nad poslední vědou zůstává), vynuluje postup
--- milníku a přepočte domy, elektřinu, bonus i popisky.
function M.set_level(town, level)
  local name = config.hall_name(level)
  if town.hall.name ~= name then replace_hall(town, name) end
  town.level = level
  town.progress = {}
  town.hall.disabled_by_script = not town.power_ok
  network.refresh_town_houses(town)
  depots.apply_town_power(town)
  M.update_bonus(town)
  draw_labels(town)
end
```

V `M.status` přidej do vrácené tabulky:

```lua
    productivity = levels.productivity_modules(town.level, count) * levels.BONUS_STEP,
```

- [ ] **Step 7: Spusť testy**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla`
Expected: obě `fail=0`. Pokud by `hall.effects.productivity` zůstalo 0 (engine by produktivitu z beaconu do laboratoře nepustil), je to chyba návrhu, ne testu – zastav a zeptej se uživatele (alternativy mění chování pro hráče, např. globální `force.laboratory_productivity_bonus`).

- [ ] **Step 8: Commit**

```bash
git add research-towns tests
git commit -m "feat: nekonečné úrovně s produktivitou radnice

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011qF8pn2anGDbxkcC6UqKtx"
```

---

### Task 3: Úroveň domu, vylepšování domů a rozdělení dodávek

**Files:**
- Create: `research-towns/scripts/allocation.lua`, `research-towns/scripts/houses.lua`
- Modify: `research-towns/scripts/config.lua`, `network.lua`, `depots.lua`, `towns.lua`, `state.lua`, `remote.lua`
- Test: `tests/unit/test_allocation.lua`, `tests/unit/test_houses.lua`, `tests/unit/test_state.lua`, `tests/unit/run.lua`
- Test: `tests/research-towns-tests/cases/houses.lua` (nové), `cases/upgrade.lua`, `control.lua` testovacího modu

**Interfaces:**
- Consumes: `milestones.accept/add/complete/key`, `levels.variant`, `levels.bonus_modules`.
- Produces (allocation): `wanted(sinks, kind, name, available) → number`, `distribute(sinks, kind, name, amount)`; sink = `{ requirements = table[]|nil, progress = table }`.
- Produces (houses): `pick(candidates, max_level) → candidate|nil`, `upgradable(candidates, max_level) → integer`; candidate = `{ key, level, depth }`.
- Produces (config): `house_requirements(house_level) → table[]|nil`.
- Produces (network): `house_candidates(town) → candidate[]`, `active_house_levels(town)` z `node.level`, `M.refresh_house(node)` (exportováno).
- Produces (depots): `collect(town, sinks)`.
- Produces (town): `town.house_progress`; status `house_requirements` (`{type,name,amount,delivered}`), `houses_to_upgrade`, `house_target_level` (nil bez cíle).
- Produces (remote): `house_level(unit_number) → integer|nil`.

- [ ] **Step 1: Unit testy (RED)**

`tests/unit/test_allocation.lua`:

```lua
--- Jednotkové testy rozdělení dodávky mezi příjemce podle priority.
local A = require("assert")
local allocation = require("scripts.allocation")

--- Příjemce s jedním požadavkem na dřevo.
local function sink(amount, have)
  return { requirements = { { type = "item", name = "wood", amount = amount } }, progress = { ["item/wood"] = have } }
end

return {
  { "dodávka jde nejdřív prvnímu příjemci, zbytek dalšímu", function()
    local first, second = sink(100, 0), sink(50, 0)
    local sinks = { first, second }
    A.eq(allocation.wanted(sinks, "item", "wood", 1000), 150, "chtějí celkem")
    allocation.distribute(sinks, "item", "wood", 120)
    A.eq(first.progress["item/wood"], 100, "první naplněn")
    A.eq(second.progress["item/wood"], 20, "druhý dostal zbytek")
  end },
  { "málo suroviny dostane jen první", function()
    local first, second = sink(100, 90), sink(50, 0)
    allocation.distribute({ first, second }, "item", "wood", 5)
    A.eq(first.progress["item/wood"], 95, "první")
    A.eq(second.progress["item/wood"], 0, "druhý nic")
  end },
  { "příjemce bez požadavků a nepotřebná surovina", function()
    local sinks = { { requirements = nil, progress = {} }, sink(10, 0) }
    A.eq(allocation.wanted(sinks, "item", "wood", 1000), 10, "nil požadavky se přeskočí")
    A.eq(allocation.wanted(sinks, "item", "stone", 1000), 0, "kámen nikdo nechce")
  end },
}
```

`tests/unit/test_houses.lua`:

```lua
--- Jednotkové testy výběru domu k vylepšení.
local A = require("assert")
local houses = require("scripts.houses")

local CANDIDATES = {
  { key = 10, level = 2, depth = 1 },
  { key = 11, level = 1, depth = 3 },
  { key = 12, level = 1, depth = 2 },
  { key = 9, level = 1, depth = 2 },
}

return {
  { "nejnižší úroveň, pak nejmenší hloubka, pak klíč", function()
    A.eq(houses.pick(CANDIDATES, 3).key, 9, "vybraný dům")
  end },
  { "dům na úrovni města se nevylepšuje", function()
    A.eq(houses.pick({ { key = 1, level = 2, depth = 1 } }, 2), nil, "nic k vylepšení")
    A.eq(houses.upgradable(CANDIDATES, 2), 3, "pod úrovní 2 jsou tři domy")
    A.eq(houses.upgradable(CANDIDATES, 1), 0, "na úrovni 1 nic")
  end },
}
```

`tests/unit/test_state.lua`:

```lua
---@diagnostic disable: undefined-global, lowercase-global
--- Jednotkové testy doplnění stavu starého savu.
local A = require("assert")
local state = require("scripts.state")

return {
  { "starý save dostane úrovně domů a postup vylepšení", function()
    storage = {
      towns = { [1] = { id = 1, progress = {} } },
      nodes = { [5] = { kind = "house" }, [6] = { kind = "hall" } },
    }
    state.init()
    A.eq(storage.nodes[5].level, 1, "dům úroveň 1")
    A.eq(storage.nodes[6].level, nil, "radnice bez úrovně")
    A.truthy(storage.towns[1].house_progress, "postup vylepšení domů")
    storage = nil
  end },
}
```

V `tests/unit/run.lua` přidej do `SUITES` `"test_allocation", "test_houses", "test_state"`.

Run: `bash tools/run-unit.sh`
Expected: FAIL `module 'scripts.allocation' not found` (a obdobně další).

- [ ] **Step 2: Čistá logika**

`research-towns/scripts/allocation.lua`:

```lua
--- Čistá logika: rozdělení dodávky suroviny mezi příjemce v pořadí priority
--- (spotřeba → milník radnice → vylepšení domu). Příjemce = { requirements = table[]|nil, progress = table }.
local milestones = require("scripts.milestones")

local M = {}

--- Kolik suroviny chtějí příjemci dohromady (nejvýš available).
function M.wanted(sinks, kind, name, available)
  local total = 0
  for _, sink in ipairs(sinks) do
    total = total + milestones.accept(sink.requirements, sink.progress, kind, name, available - total)
  end
  return total
end

--- Připíše skutečně odebrané množství příjemcům v pořadí priority.
function M.distribute(sinks, kind, name, amount)
  local left = amount
  for _, sink in ipairs(sinks) do
    local take = milestones.accept(sink.requirements, sink.progress, kind, name, left)
    if take > 0 then
      milestones.add(sink.progress, kind, name, take)
      left = left - take
    end
  end
end

return M
```

`research-towns/scripts/houses.lua`:

```lua
--- Čistá logika: výběr domu k vylepšení. Kandidát = { key, level, depth } aktivního domu.
local M = {}

--- Dům, který se vylepšuje jako další: nejnižší úroveň pod max_level, pak nejmenší hloubka, pak nejmenší klíč.
--- @return table|nil
function M.pick(candidates, max_level)
  local best
  for _, house in ipairs(candidates) do
    if house.level < max_level then
      if not best or house.level < best.level
        or (house.level == best.level and (house.depth < best.depth
          or (house.depth == best.depth and house.key < best.key))) then
        best = house
      end
    end
  end
  return best
end

--- Počet domů, které lze ještě vylepšit.
function M.upgradable(candidates, max_level)
  local count = 0
  for _, house in ipairs(candidates) do
    if house.level < max_level then count = count + 1 end
  end
  return count
end

return M
```

V `research-towns/scripts/state.lua` přidej na konec `M.init` (před `end`):

```lua
  -- Doplnění polí ze starších verzí (0.1.0).
  for _, town in pairs(storage.towns) do
    town.house_progress = town.house_progress or {}
  end
  for _, node in pairs(storage.nodes) do
    if node.kind == "house" then node.level = node.level or 1 end
  end
```

Run: `bash tools/run-unit.sh` → Expected: `fail=0`.

- [ ] **Step 3: Integrační testy domů (RED)**

`tests/research-towns-tests/cases/houses.lua`:

```lua
--- Integrační testy vylepšování domů a priority rozdělení surovin.
local levels = require("__research-towns__/shared/levels")
local H = require("helpers")
local R = H.REMOTE

--- Suroviny milníku úrovně (bez vědy) jako mapa jméno → množství; kapaliny test nepoužívá.
local function materials(level)
  local result = {}
  for _, req in ipairs(H.levels_data().upgrade[tostring(level)]) do
    if not req.science then
      H.check(req.type == "item", "test počítá jen s předměty v milníku " .. level)
      result[req.name] = (result[req.name] or 0) + req.amount
    end
  end
  return result
end

return {
  {
    name = "dodané suroviny vylepší dům a zvýší bonus",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      remote.call(R, "set_level", ctx.town, 2)
      ctx.house = H.house(ctx, 11, 0)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
      -- Dvojnásobek pokryje milník radnice, vylepšení domu i případnou spotřebu.
      local wanted = materials(1)
      for name, amount in pairs(materials(2)) do wanted[name] = (wanted[name] or 0) + amount end
      for name, amount in pairs(wanted) do ctx.depot.insert({ name = name, count = 2 * amount }) end
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "house_level", ctx.house.unit_number) == 1, "nový dům má úroveň 1")
      H.process(ctx.town)
      H.check(remote.call(R, "house_level", ctx.house.unit_number) == 2, "dům se nevylepšil")
      local s = H.status(ctx.town)
      H.check(s.beacon_modules == levels.bonus_modules(2, { 2 }), "bonus: " .. s.beacon_modules)
      H.check(s.houses_to_upgrade == 0, "zbývá vylepšit: " .. s.houses_to_upgrade)
    end } },
  },
  {
    name = "radnice má přednost před domy",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      remote.call(R, "set_level", ctx.town, 2)
      H.house(ctx, 11, 0)
      ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
      local house = materials(1)
      for name, amount in pairs(materials(2)) do
        if house[name] then
          ctx.item = name
          ctx.depot.insert({ name = name, count = amount })
          break
        end
      end
      H.check(ctx.item, "milníky 1 a 2 nesdílí surovinu – test nemá co ověřit")
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      H.check((H.delivered(ctx.town, "item", ctx.item) or 0) > 0, "radnice nic nedostala")
      for _, req in ipairs(H.status(ctx.town).house_requirements) do
        if req.name == ctx.item then H.check(req.delivered == 0, "dům dostal surovinu dřív než radnice") end
      end
    end } },
  },
  {
    name = "dům nad úroveň města nejde vylepšit",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      H.house(ctx, 11, 0)
    end,
    steps = { { ticks = 1, run = function(ctx)
      local s = H.status(ctx.town)
      H.check(s.houses_to_upgrade == 0 and s.house_target_level == nil, "na úrovni 1 je co vylepšovat")
    end } },
  },
}
```

V `tests/research-towns-tests/control.lua` přidej `runner.register(require("cases.houses"))`.

V `cases/upgrade.lua` (test „povýšení vymění radnici…“) – domy si teď drží vlastní úroveň:

```lua
        H.check(ctx.houses[1].graphics_variation == levels.variant(1, H.level_count()), "dům změnil vzhled bez vylepšení")
        H.check(s.beacon_modules == levels.bonus_modules(2, { 1, 1, 1, 1 }), "bonus po povýšení: " .. s.beacon_modules)
```

(nahrazuje dvě kontroly z Task 1).

Run: `bash tools/run-tests.sh vanilla`
Expected: FAIL nových testů (`house_level` neexistuje v remote rozhraní).

- [ ] **Step 4: Runtime – config, síť, překladiště**

Do `research-towns/scripts/config.lua` přidej:

```lua
--- Suroviny na vylepšení domu z úrovně house_level: stejné jako milník radnice house_level → +1, bez vědeckých
--- balíčků. Nil, když už dům nemá kam růst (poslední věda).
function M.house_requirements(house_level)
  if house_level >= data.level_count then return nil end
  local list = {}
  for _, req in ipairs(data.upgrade[tostring(house_level)]) do
    if not req.science then list[#list + 1] = req end
  end
  return list
end
```

V `research-towns/scripts/network.lua`:
- v `M.add` u nového uzlu: `local node = { key = entity.unit_number, entity = entity, kind = kind, town = town_id, links = {}, level = kind == "house" and 1 or nil }`;
- `local function refresh_house(node)` změň na `function M.refresh_house(node)` (docstring: „Nastaví domu grafickou variantu podle jeho úrovně a ikonu „odpojeno“, když není aktivní.“), řádek varianty na
  `node.entity.graphics_variation = levels.variant(node.level, config.level_count())` (proměnná `town` se pak v té funkci nepoužívá – smaž její řádek) a obě volání `refresh_house(node)` v souboru na `M.refresh_house(node)`;
- nahraď `M.active_house_levels` a přidej `M.house_candidates`:

```lua
--- Úrovně aktivních domů města.
--- @return integer[]
function M.active_house_levels(town)
  local list = {}
  for key in pairs(town.houses) do
    local node = storage.nodes[key]
    if node and M.is_active(node) then list[#list + 1] = node.level end
  end
  return list
end

--- Aktivní domy města jako kandidáti vylepšení { key, level, depth }.
function M.house_candidates(town)
  local list = {}
  for key in pairs(town.houses) do
    local node = storage.nodes[key]
    if node and M.is_active(node) then list[#list + 1] = { key = key, level = node.level, depth = node.depth } end
  end
  return list
end
```

V `research-towns/scripts/depots.lua` přidej `local allocation = require("scripts.allocation")` a nahraď `M.collect`:

```lua
--- Vybere z překladišť města suroviny pro příjemce v pořadí priority (každá kvalita se počítá).
--- @param sinks table[] { {requirements = table[]|nil, progress = table} } – viz scripts/allocation.lua
function M.collect(town, sinks)
  for key in pairs(town.depots) do
    local depot = storage.depots[key]
    local entity = depot and depot.entity
    if entity and entity.valid then
      if depot.kind == "goods" then
        local inventory = entity.get_inventory(defines.inventory.chest)
        for _, item in pairs(inventory.get_contents()) do
          local take = allocation.wanted(sinks, "item", item.name, item.count)
          if take > 0 then
            local removed = inventory.remove({ name = item.name, quality = item.quality, count = take })
            allocation.distribute(sinks, "item", item.name, removed)
          end
        end
      elseif depot.kind == "fluid" then
        local fluid = entity.fluidbox[1]
        if fluid then
          local take = allocation.wanted(sinks, "fluid", fluid.name, fluid.amount)
          if take > 0 then
            allocation.distribute(sinks, "fluid", fluid.name, entity.remove_fluid({ name = fluid.name, amount = take }))
          end
        end
      end
    end
  end
end
```

(`milestones` a `config` v `depots.lua` pak už nejsou potřeba v `collect`; `config` zůstává kvůli příkonu, `require("scripts.milestones")` smaž, pokud se jinde v souboru nepoužívá.)

- [ ] **Step 5: Runtime – města a remote**

V `research-towns/scripts/towns.lua` přidej `local houses = require("scripts.houses")`. V `M.create` přidej do tabulky města `house_progress = {}`. Přidej před `M.status`:

```lua
--- Dům, který se právě vylepšuje, a jeho požadavky (nil, nil = nic k vylepšení).
local function house_target(town, candidates)
  local target = houses.pick(candidates, math.min(town.level, config.level_count()))
  return target, target and config.house_requirements(target.level)
end

--- Požadavky s dodaným množstvím pro GUI/remote/tabuli.
local function with_delivered(requirements, progress)
  local list = {}
  for _, req in ipairs(requirements or {}) do
    list[#list + 1] = {
      type = req.type, name = req.name, amount = req.amount,
      delivered = math.min(req.amount, progress[milestones.key(req.type, req.name)] or 0),
    }
  end
  return list
end
```

V `M.status` nahraď sestavení `requirements` za `local requirements = with_delivered(config.upgrade(town.level), town.progress)` a do vrácené tabulky přidej (před `return` spočítej `local candidates = network.house_candidates(town)` a `local target, house_reqs = house_target(town, candidates)`):

```lua
    house_requirements = with_delivered(house_reqs, town.house_progress),
    houses_to_upgrade = houses.upgradable(candidates, math.min(town.level, count)),
    house_target_level = target and target.level,
```

Nahraď `M.process`:

```lua
--- Pravidelné zpracování: dodávky z překladišť (milník radnice → vylepšení domu), vylepšení domu,
--- kontrola elektřiny, zapnutí/vypnutí výzkumu.
function M.process(town)
  if not town.hall.valid then return end
  local candidates = network.house_candidates(town)
  local target, house_reqs = house_target(town, candidates)
  depots.collect(town, {
    { requirements = config.upgrade(town.level), progress = town.progress },
    { requirements = house_reqs, progress = town.house_progress },
  })
  if house_reqs and milestones.complete(house_reqs, town.house_progress) then
    local node = storage.nodes[target.key]
    node.level = node.level + 1
    town.house_progress = {}
    network.refresh_house(node)
    M.update_bonus(town)
  end
  if not (town.beacon and town.beacon.valid) then M.update_bonus(town) end
  town.power_ok = depots.power_ok(town)
  town.hall.disabled_by_script = not town.power_ok
end
```

Do `research-towns/scripts/remote.lua` přidej do rozhraní:

```lua
  --- Úroveň domu, nebo nil.
  house_level = function(unit_number)
    local node = storage.nodes[unit_number]
    return node and node.level
  end,
```

- [ ] **Step 6: Spusť testy**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla`
Expected: obě `fail=0`.

- [ ] **Step 7: Commit**

```bash
git add research-towns tests
git commit -m "feat: úroveň domu, dobrovolné vylepšování a priorita dodávek

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011qF8pn2anGDbxkcC6UqKtx"
```

---

### Task 4: Průběžná spotřeba surovin

**Files:**
- Create: `research-towns/settings.lua`, `research-towns/scripts/upkeep.lua`
- Modify: `research-towns/shared/levels.lua`, `scripts/config.lua`, `scripts/towns.lua`, `scripts/state.lua`, locale
- Test: `tests/unit/test_upkeep.lua`, `tests/unit/test_state.lua`, `tests/unit/run.lua`
- Test: `tests/research-towns-tests/cases/upkeep.lua` (nové), `helpers.lua`, `control.lua` testovacího modu

**Interfaces:**
- Consumes: `milestones.key`, `config.upgrade`, `allocation` (přes `depots.collect`).
- Produces (levels): `UPKEEP_RATE`, `HOUSE_UPKEEP_SHARE`, `UPKEEP_BUFFER_SECONDS`.
- Produces (upkeep): `per_minute(completed, multiplier, active_houses) → { {type,name,amount} }`, `times(list, factor)`, `covered(need, stock) → boolean`, `consume(need, stock)`.
- Produces (config): `completed_milestones(level) → table[][]`, `upkeep_multiplier() → number`.
- Produces (town): `town.stock`, `town.upkeep_ok`; status `upkeep = { {type,name,per_minute,stock} }`, `upkeep_ok`.
- Produces (test helpers): `H.research()`.

- [ ] **Step 1: Unit testy (RED)**

`tests/unit/test_upkeep.lua`:

```lua
--- Jednotkové testy průběžné spotřeby.
local A = require("assert")
local levels = require("shared.levels")
local upkeep = require("scripts.upkeep")

local COMPLETED = {
  { { type = "item", name = "red", amount = 200, science = true }, { type = "item", name = "wood", amount = 100 } },
  { { type = "item", name = "wood", amount = 300 }, { type = "fluid", name = "water", amount = 1000 } },
}

return {
  { "sčítá suroviny všech splněných milníků bez vědy", function()
    local list = upkeep.per_minute(COMPLETED, 1, 0)
    A.eq(#list, 2, "dva druhy (věda vynechaná)")
    A.eq(list[1].name, "water", "seřazeno podle klíče (fluid/ < item/)")
    A.truthy(math.abs(list[2].amount - 400 * levels.UPKEEP_RATE) < 1e-9, "dřevo za minutu")
  end },
  { "domy a násobič zvyšují spotřebu", function()
    local base = upkeep.per_minute(COMPLETED, 1, 0)[2].amount
    local houses = upkeep.per_minute(COMPLETED, 1, 10)[2].amount
    A.truthy(math.abs(houses - base * (1 + 10 * levels.HOUSE_UPKEEP_SHARE)) < 1e-9, "10 domů")
    A.truthy(math.abs(upkeep.per_minute(COMPLETED, 2, 0)[2].amount - 2 * base) < 1e-9, "násobič 2")
    A.eq(#upkeep.per_minute(COMPLETED, 0, 5), 0, "násobič 0 vypne spotřebu")
    A.eq(#upkeep.per_minute({}, 1, 5), 0, "úroveň 1 nic nespotřebovává")
  end },
  { "zásoba pokryje potřebu a odebere se", function()
    local need = upkeep.times({ { type = "item", name = "wood", amount = 60 } }, 0.5)
    A.eq(need[1].amount, 30, "times")
    local stock = { ["item/wood"] = 40 }
    A.truthy(upkeep.covered(need, stock), "40 ≥ 30")
    upkeep.consume(need, stock)
    A.eq(stock["item/wood"], 10, "odebráno")
    A.truthy(not upkeep.covered(need, stock), "10 < 30")
    A.truthy(upkeep.covered({}, {}), "bez spotřeby je pokryto")
  end },
}
```

V `tests/unit/test_state.lua` doplň do testu za `state.init()` (a do `storage.towns[1]` nic nepřidávej):

```lua
    A.truthy(storage.towns[1].stock, "zásoba spotřeby")
    A.eq(storage.towns[1].upkeep_ok, true, "spotřeba pokryta")
```

V `tests/unit/run.lua` přidej `"test_upkeep"` do `SUITES`.

Run: `bash tools/run-unit.sh`
Expected: FAIL `module 'scripts.upkeep' not found` a v `test_state` „zásoba spotřeby“.

- [ ] **Step 2: Konstanty a čistá logika**

Do `research-towns/shared/levels.lua` za `M.VARIANTS` (resp. za konstanty produktivity):

```lua
--- Průběžná spotřeba: za minutu podíl množství každého splněného milníku (bez věd) × startup násobič.
M.UPKEEP_RATE = 0.01
--- Každý aktivní dům zvýší spotřebu o tento díl.
M.HOUSE_UPKEEP_SHARE = 0.05
--- Zásoba radnice na tolik sekund provozu; po jejím vyčerpání radnice stojí.
M.UPKEEP_BUFFER_SECONDS = 60
```

`research-towns/scripts/upkeep.lua`:

```lua
--- Čistá logika průběžné spotřeby: radnice spotřebovává suroviny všech splněných milníků (bez vědeckých
--- balíčků). Zásoba = { ["item/wood"] = 12.5, … } ve stejném tvaru jako postup milníku.
local levels = require("shared.levels")
local milestones = require("scripts.milestones")

local M = {}

--- Tolerance pro kapaliny a zlomky.
local EPSILON = 1e-6

--- Spotřeba za minutu: součet množství splněných milníků × UPKEEP_RATE × násobič × (1 + HOUSE_UPKEEP_SHARE × domy).
--- @param completed table[][] požadavky splněných milníků
--- @return table[] { {type, name, amount} } seřazené podle klíče suroviny
function M.per_minute(completed, multiplier, active_houses)
  if multiplier <= 0 then return {} end
  local factor = levels.UPKEEP_RATE * multiplier * (1 + levels.HOUSE_UPKEEP_SHARE * active_houses)
  local sums, keys = {}, {}
  for _, list in ipairs(completed) do
    for _, req in ipairs(list) do
      if not req.science then
        local key = milestones.key(req.type, req.name)
        if not sums[key] then
          sums[key] = { type = req.type, name = req.name, amount = 0 }
          keys[#keys + 1] = key
        end
        sums[key].amount = sums[key].amount + req.amount * factor
      end
    end
  end
  table.sort(keys)
  local result = {}
  for i, key in ipairs(keys) do result[i] = sums[key] end
  return result
end

--- Kopie seznamu s množstvím × factor (spotřeba za minutu → za interval / cílová zásoba).
function M.times(list, factor)
  local out = {}
  for i, req in ipairs(list) do out[i] = { type = req.type, name = req.name, amount = req.amount * factor } end
  return out
end

--- Pokryje zásoba potřebu všech surovin?
function M.covered(need, stock)
  for _, req in ipairs(need) do
    if (stock[milestones.key(req.type, req.name)] or 0) + EPSILON < req.amount then return false end
  end
  return true
end

--- Odebere potřebu ze zásoby (volat jen po covered).
function M.consume(need, stock)
  for _, req in ipairs(need) do
    local key = milestones.key(req.type, req.name)
    stock[key] = math.max(0, (stock[key] or 0) - req.amount)
  end
end

return M
```

V `research-towns/scripts/state.lua` doplň do cyklu přes města:

```lua
    town.stock = town.stock or {}
    if town.upkeep_ok == nil then town.upkeep_ok = true end
```

Run: `bash tools/run-unit.sh` → Expected: `fail=0`.

- [ ] **Step 3: Startup nastavení**

`research-towns/settings.lua`:

```lua
-- Research Towns – startup nastavení (laditelné bez úprav kódu).
data:extend({
  {
    type = "double-setting", name = "rt-upkeep-multiplier", setting_type = "startup",
    default_value = 1, minimum_value = 0, maximum_value = 100, order = "a",
  },
})
```

Locale en:

```
[mod-setting-name]
rt-upkeep-multiplier=Material upkeep multiplier

[mod-setting-description]
rt-upkeep-multiplier=How much material towns consume continuously (1 = default, 0 = no upkeep). Lower it for slow overhauls such as Pyanodon.
```

cs:

```
[mod-setting-name]
rt-upkeep-multiplier=Násobič spotřeby surovin

[mod-setting-description]
rt-upkeep-multiplier=Kolik surovin města průběžně spotřebovávají (1 = výchozí, 0 = bez spotřeby). Pro pomalé overhauly jako Pyanodon ho sniž.
```

Do `research-towns/scripts/config.lua`:

```lua
--- Požadavky splněných milníků města dané úrovně (1..level−1) pro průběžnou spotřebu.
--- @return table[][]
function M.completed_milestones(level)
  local list = {}
  for k = 1, level - 1 do list[k] = M.upgrade(k) end
  return list
end

--- Startup násobič spotřeby.
function M.upkeep_multiplier()
  return settings.startup["rt-upkeep-multiplier"].value
end
```

- [ ] **Step 4: Integrační testy (RED)**

Do `tests/research-towns-tests/helpers.lua` přidej:

```lua
--- Zajistí rozběhnutý výzkum jen s červenou vědou (sdílená síla – jiné testy mohou výzkum dokončit).
function H.research()
  local force = game.forces.player
  force.technologies["automation-science-pack"].researched = true
  if force.current_research then return end
  local names = {}
  for name in pairs(force.technologies) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local tech = force.technologies[name]
    local red_only = #tech.research_unit_ingredients == 1
      and tech.research_unit_ingredients[1].name == "automation-science-pack"
    if red_only and tech.enabled and not tech.researched and force.add_research(tech) then return end
  end
  error("není co zkoumat červenou vědou")
end

--- Vloží do překladiště každou surovinu spotřeby (status.upkeep) v daném množství; kapaliny přeskočí.
function H.supply_upkeep(id, depot, count)
  for _, item in ipairs(H.status(id).upkeep) do
    if item.type == "item" then depot.insert({ name = item.name, count = count }) end
  end
end

--- Zásoba spotřeby suroviny ve městě.
function H.stock(id, name)
  for _, item in ipairs(H.status(id).upkeep) do
    if item.name == name then return item.stock end
  end
  return nil
end
```

`tests/research-towns-tests/cases/upkeep.lua`:

```lua
--- Integrační testy průběžné spotřeby surovin.
local H = require("helpers")
local R = H.REMOTE

--- Město úrovně 2 s elektřinou, překladištěm se surovinami spotřeby a balíčky v radnici.
local function supplied_town(ctx, packs)
  ctx.town = H.town(ctx)
  remote.call(R, "set_level", ctx.town, 2)
  H.place(ctx, "rt-power-depot", -4, 10)
  H.power(ctx, -10, 13)
  ctx.depot = H.place(ctx, "rt-goods-depot", 0, 10)
  H.supply_upkeep(ctx.town, ctx.depot, 1000)
  if packs then H.hall(ctx.town).insert({ name = "automation-science-pack", count = packs }) end
end

return {
  {
    name = "úroveň 1 nic nespotřebovává",
    setup = function(ctx) ctx.town = H.town(ctx) end,
    steps = { { ticks = 1, run = function(ctx)
      local s = H.status(ctx.town)
      H.check(#s.upkeep == 0 and s.upkeep_ok, "spotřeba na úrovni 1")
    end } },
  },
  {
    name = "spotřeba odebírá suroviny a bez nich radnice stojí",
    setup = function(ctx) supplied_town(ctx, 50) end,
    steps = {
      { ticks = 30, run = function(ctx)
        H.research()
        H.process(ctx.town)
        local s = H.status(ctx.town)
        H.check(#s.upkeep > 0, "úroveň 2 nemá spotřebu")
        H.check(s.upkeep_ok and not H.hall(ctx.town).disabled_by_script, "zásobená radnice stojí")
        H.check(s.upkeep[1].stock > 0, "zásoba se nenaplnila")
        ctx.depot.clear_items_inside()
        -- Zásoba je na UPKEEP_BUFFER_SECONDS (30 intervalů po 2 s); 40 zpracování ji jistě vyčerpá.
        for _ = 1, 40 do H.process(ctx.town) end
        s = H.status(ctx.town)
        H.check(not s.upkeep_ok, "spotřeba hlášena jako pokrytá bez surovin")
        H.check(H.hall(ctx.town).disabled_by_script, "radnice bez surovin zkoumá")
      end },
    },
  },
  {
    name = "bez výzkumu se nespotřebovává",
    setup = function(ctx) supplied_town(ctx, nil) end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      local name = H.status(ctx.town).upkeep[1].name
      local before = H.stock(ctx.town, name)
      H.process(ctx.town)
      H.check(H.stock(ctx.town, name) == before, "prázdná radnice spotřebovala zásobu")
    end } },
  },
}
```

V `tests/research-towns-tests/control.lua` přidej `runner.register(require("cases.upkeep"))`.

Run: `bash tools/run-tests.sh vanilla`
Expected: FAIL nových testů (`status.upkeep` je nil).

- [ ] **Step 5: Spotřeba v `towns.lua`**

Přidej `local upkeep = require("scripts.upkeep")`. V `M.create` do tabulky města `stock = {}, upkeep_ok = true`. Přidej před `M.process`:

```lua
--- Chce radnice zkoumat? (rozběhnutý výzkum a nějaké balíčky) – jen tehdy se spotřebovává.
local function wants_research(hall)
  return hall.force.current_research ~= nil and not hall.get_inventory(defines.inventory.lab_input).is_empty()
end

--- Spotřeba města za minutu.
local function upkeep_rate(town, active_houses)
  return upkeep.per_minute(config.completed_milestones(town.level), config.upkeep_multiplier(), active_houses)
end
```

Nahraď `M.process`:

```lua
--- Pravidelné zpracování: dodávky z překladišť (zásoba spotřeby → milník radnice → vylepšení domu),
--- vylepšení domu, spotřeba zásoby, kontrola elektřiny a zapnutí/vypnutí výzkumu.
function M.process(town)
  if not town.hall.valid then return end
  local candidates = network.house_candidates(town)
  local target, house_reqs = house_target(town, candidates)
  local rate = upkeep_rate(town, #candidates)
  depots.collect(town, {
    { requirements = upkeep.times(rate, levels.UPKEEP_BUFFER_SECONDS / 60), progress = town.stock },
    { requirements = config.upgrade(town.level), progress = town.progress },
    { requirements = house_reqs, progress = town.house_progress },
  })
  if house_reqs and milestones.complete(house_reqs, town.house_progress) then
    local node = storage.nodes[target.key]
    node.level = node.level + 1
    town.house_progress = {}
    network.refresh_house(node)
    M.update_bonus(town)
  end
  if wants_research(town.hall) then
    local need = upkeep.times(rate, levels.TOWN_INTERVAL / 3600)
    town.upkeep_ok = upkeep.covered(need, town.stock)
    if town.upkeep_ok then upkeep.consume(need, town.stock) end
  else
    town.upkeep_ok = true
  end
  if not (town.beacon and town.beacon.valid) then M.update_bonus(town) end
  town.power_ok = depots.power_ok(town)
  town.hall.disabled_by_script = not (town.power_ok and town.upkeep_ok)
end
```

V `M.set_level` změň `town.hall.disabled_by_script = not (town.power_ok and town.upkeep_ok)`. V `M.status` přidej (`active` = `#candidates`):

```lua
    upkeep = (function()
      local list = {}
      for i, req in ipairs(upkeep_rate(town, #candidates)) do
        list[i] = { type = req.type, name = req.name, per_minute = req.amount,
          stock = town.stock[milestones.key(req.type, req.name)] or 0 }
      end
      return list
    end)(),
    upkeep_ok = town.upkeep_ok,
```

(Pokud je to čitelnější, vytáhni to do lokální funkce `upkeep_status(town, active)` nad `M.status` – výsledek stejný.)

- [ ] **Step 6: Spusť testy**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla`
Expected: obě `fail=0`.

- [ ] **Step 7: Commit**

```bash
git add research-towns tests
git commit -m "feat: průběžná spotřeba surovin splněných milníků

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011qF8pn2anGDbxkcC6UqKtx"
```

---

### Task 5: Panel radnice – produktivita, vylepšení domů, spotřeba

**Files:**
- Modify: `research-towns/scripts/gui.lua`, locale
- Test: `tests/unit/test_gui_names.lua` (beze změny – kontroluje nová jména), celá integrační sada (načtení modu)

**Interfaces:**
- Consumes: status `level_count`, `productivity`, `house_requirements`, `houses_to_upgrade`, `house_target_level`, `upkeep`, `upkeep_ok`.
- Produces: `gui.NAMES` rozšířené o `productivity`, `house_upgrade`, `house_requirements`, `upkeep_status`, `upkeep`.

- [ ] **Step 1: Jména prvků a stavba panelu**

V `research-towns/scripts/gui.lua` nahraď `M.NAMES` a `M.ensure`:

```lua
--- Jména prvků (prefix rt_, nesmí kolidovat s vlastnostmi LuaGuiElement – hlídá test_gui_names).
M.NAMES = {
  frame = "rt_town_frame",
  name = "rt_town_name",
  level = "rt_town_level",
  houses = "rt_town_houses",
  productivity = "rt_town_productivity",
  power = "rt_town_power",
  requirements = "rt_town_requirements",
  house_upgrade = "rt_town_house_upgrade",
  house_requirements = "rt_town_house_requirements",
  upkeep_status = "rt_town_upkeep_status",
  upkeep = "rt_town_upkeep",
  upgrade = "rt_town_upgrade",
}

--- Vytvoří (znovu) prázdný panel hráči.
function M.ensure(player)
  local relative = player.gui.relative
  if relative[M.NAMES.frame] then relative[M.NAMES.frame].destroy() end
  local n = M.NAMES
  local frame = relative.add({
    type = "frame", name = n.frame, direction = "vertical", caption = { "rt.gui-title" },
    anchor = { gui = defines.relative_gui_type.lab_gui, position = defines.relative_gui_position.right,
      names = config.hall_names() },
  })
  frame.add({ type = "textfield", name = n.name, tooltip = { "rt.gui-rename" } })
  frame.add({ type = "label", name = n.level })
  frame.add({ type = "label", name = n.houses })
  frame.add({ type = "label", name = n.productivity })
  frame.add({ type = "label", name = n.power })
  frame.add({ type = "label", caption = { "rt.gui-requirements" } })
  frame.add({ type = "table", name = n.requirements, column_count = 2 })
  frame.add({ type = "label", name = n.house_upgrade })
  frame.add({ type = "table", name = n.house_requirements, column_count = 2 })
  frame.add({ type = "label", name = n.upkeep_status })
  frame.add({ type = "table", name = n.upkeep, column_count = 2 })
  frame.add({ type = "button", name = n.upgrade, caption = { "rt.gui-upgrade" } })
end
```

- [ ] **Step 2: Plnění panelu**

Nahraď lokální `fill`:

```lua
--- Naplní tabulku řádky „ikona s nativním popupem + popisek“.
--- @param rows { type: string, name: string, caption: LocalisedString }[]
local function fill_list(list, rows)
  list.clear()
  for _, row in ipairs(rows) do
    -- elem_tooltip = nativní popup předmětu/kapaliny jako v inventáři.
    list.add({ type = "sprite", sprite = row.type .. "/" .. row.name, elem_tooltip = { type = row.type, name = row.name } })
    list.add({ type = "label", caption = row.caption })
  end
end

--- Řádky „dodáno / potřeba“ z požadavků se stavem dodání.
local function progress_rows(requirements)
  local rows = {}
  for i, req in ipairs(requirements) do
    rows[i] = { type = req.type, name = req.name,
      caption = string.format("%d / %d", math.floor(req.delivered), req.amount) }
  end
  return rows
end

--- Naplní panel hráče stavem města.
local function fill(player, town)
  local frame = player.gui.relative[M.NAMES.frame]
  if not frame then return end
  local n = M.NAMES
  local status = towns.status(town)
  frame[n.level].caption = { "rt.gui-level", status.level, math.min(status.level, status.level_count), status.level_count }
  frame[n.houses].caption = { "rt.gui-houses", status.active_houses, status.house_limit,
    string.format("%d", math.floor(status.bonus * 100 + 0.5)) }
  local productivity = math.floor(status.productivity * 100 + 0.5)
  frame[n.productivity].visible = productivity > 0
  frame[n.productivity].caption = { "rt.gui-productivity", productivity }
  local megawatts = string.format("%.0f", status.power_watts / 1e6)
  frame[n.power].caption = status.power_ok and { "rt.gui-power-ok", megawatts } or { "rt.gui-power-missing", megawatts }
  fill_list(frame[n.requirements], progress_rows(status.requirements))
  frame[n.house_upgrade].caption = status.house_target_level
    and { "rt.gui-house-upgrade", status.houses_to_upgrade, status.house_target_level + 1 }
    or { "rt.gui-house-upgrade-none" }
  fill_list(frame[n.house_requirements], progress_rows(status.house_requirements))
  local upkeep_rows = {}
  for i, item in ipairs(status.upkeep) do
    upkeep_rows[i] = { type = item.type, name = item.name,
      caption = { "rt.gui-upkeep-row", string.format("%.1f", item.per_minute), math.floor(item.stock) } }
  end
  frame[n.upkeep_status].caption = #upkeep_rows == 0 and { "rt.gui-upkeep-none" }
    or (status.upkeep_ok and { "rt.gui-upkeep-ok" } or { "rt.gui-upkeep-missing" })
  fill_list(frame[n.upkeep], upkeep_rows)
  frame[n.upgrade].enabled = status.can_upgrade
end
```

- [ ] **Step 3: Locale**

V `[rt]` smaž `gui-max-level` (nekonečné úrovně mají vždy milník) a přidej.
en:

```
gui-productivity=Research productivity: +__1__ %
gui-house-upgrade=Houses to upgrade: __1__ (next to level __2__)
gui-house-upgrade-none=All connected houses are at the town's level.
gui-upkeep-none=No material upkeep yet – the town lives on electricity.
gui-upkeep-ok=Upkeep per minute – supplies OK:
gui-upkeep-missing=Upkeep per minute – supplies ran out, the town hall has stopped:
gui-upkeep-row=__1__ /min (stock __2__)
```

cs:

```
gui-productivity=Produktivita výzkumu: +__1__ %
gui-house-upgrade=Domy k vylepšení: __1__ (další na úroveň __2__)
gui-house-upgrade-none=Všechny připojené domy jsou na úrovni města.
gui-upkeep-none=Zatím bez spotřeby surovin – městu stačí elektřina.
gui-upkeep-ok=Spotřeba za minutu – zásoby v pořádku:
gui-upkeep-missing=Spotřeba za minutu – zásoby došly, radnice stojí:
gui-upkeep-row=__1__ /min (zásoba __2__)
```

- [ ] **Step 4: Spusť testy**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla`
Expected: obě `fail=0` (`test_gui_names` projde nová jména). GUI headless netestuje – do ručního checklistu (Task 7) přidat „panel radnice: produktivita, vylepšení domů, spotřeba“.

- [ ] **Step 5: Commit**

```bash
git add research-towns
git commit -m "feat: panel radnice ukazuje produktivitu, vylepšení domů a spotřebu

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011qF8pn2anGDbxkcC6UqKtx"
```

---

### Task 6: Městská tabule (obvodová síť)

**Files:**
- Create: `research-towns/prototypes/signals.lua`, `research-towns/scripts/board.lua`
- Modify: `research-towns/prototypes/depots.lua`, `research-towns/data.lua`
- Modify: `research-towns/scripts/depots.lua`, `towns.lua`, `state.lua`, `gui.lua`, `remote.lua`, `research-towns/control.lua`, locale
- Test: `tests/unit/test_board.lua`, `tests/unit/run.lua`, `tests/research-towns-tests/cases/board.lua` (nové), `control.lua` testovacího modu

**Interfaces:**
- Consumes: status `requirements`, `house_requirements`, `houses_to_upgrade`, `upkeep`, `power_watts`; `depots.resolve`.
- Produces (board): `MODES = { "hall", "house", "upkeep" }`, `signals(mode, status) → { {type,name,count} }`, `write(entity, list)`, `TAG = "rt_board_mode"`.
- Produces (depots): druh `"board"` v `KINDS`, `depot.mode`, `add(entity, tags)`, `power_percent(town) → integer`.
- Produces (towns): `refresh_boards(town)`; status `power_percent`.
- Produces (remote): `board_mode(unit_number)`, `set_board_mode(unit_number, mode)`.
- Produces (prototypy): entita/předmět/recept `rt-town-board`, virtuální signály `rt-signal-houses`, `rt-signal-power-mw`, `rt-signal-power-percent`.

- [ ] **Step 1: Unit test signálů (RED)**

`tests/unit/test_board.lua`:

```lua
--- Jednotkové testy signálů městské tabule.
local A = require("assert")
local board = require("scripts.board")

local STATUS = {
  requirements = { { type = "item", name = "wood", amount = 200, delivered = 50.5 },
    { type = "fluid", name = "water", amount = 100, delivered = 100 } },
  house_requirements = { { type = "item", name = "pipe", amount = 10, delivered = 0 } },
  houses_to_upgrade = 3,
  upkeep = { { type = "item", name = "wood", per_minute = 2.3, stock = 0 } },
  power_watts = 4e6, power_percent = 75,
}

--- Signál podle jména, nebo nil.
local function find(list, name)
  for _, signal in ipairs(list) do
    if signal.name == name then return signal end
  end
  return nil
end

return {
  { "režim Radnice: zbývající milník zaokrouhlený nahoru, splněné vynechá", function()
    local list = board.signals("hall", STATUS)
    A.eq(find(list, "wood").count, 150, "dřevo")
    A.eq(find(list, "water"), nil, "splněná voda")
    A.eq(find(list, "rt-signal-power-mw").count, 4, "MW")
    A.eq(find(list, "rt-signal-power-percent").count, 75, "procenta")
  end },
  { "režim Dům: jeden dům + počet domů", function()
    local list = board.signals("house", STATUS)
    A.eq(find(list, "pipe").count, 10, "trubky")
    A.eq(find(list, "rt-signal-houses").count, 3, "domy")
    A.eq(find(list, "wood"), nil, "milník radnice ne")
  end },
  { "režim Spotřeba: za minutu nahoru", function()
    local list = board.signals("upkeep", STATUS)
    A.eq(find(list, "wood").count, 3, "dřevo za minutu")
    A.eq(find(list, "wood").type, "item", "typ")
  end },
}
```

V `tests/unit/run.lua` přidej `"test_board"` do `SUITES`.

Run: `bash tools/run-unit.sh`
Expected: FAIL `module 'scripts.board' not found`.

- [ ] **Step 2: `scripts/board.lua`**

```lua
--- Městská tabule: signály pro obvodovou síť podle režimu (čistá funkce signals) a zápis do kombinátoru.
local M = {}

--- Režimy tabule v pořadí položek v GUI.
M.MODES = { "hall", "house", "upkeep" }
--- Tag režimu v plánu (blueprintu).
M.TAG = "rt_board_mode"

--- Zaokrouhlí kladné množství nahoru (tolerance kvůli kapalinám).
local function ceil(value)
  return math.ceil(value - 1e-6)
end

--- Signály tabule pro režim a stav města (towns.status). Nulové hodnoty se vynechají.
--- @return { type: string, name: string, count: integer }[]
function M.signals(mode, status)
  local list = {}
  local function add(kind, name, count)
    if count > 0 then list[#list + 1] = { type = kind, name = name, count = count } end
  end
  if mode == "hall" then
    for _, req in ipairs(status.requirements) do add(req.type, req.name, ceil(req.amount - req.delivered)) end
  elseif mode == "house" then
    for _, req in ipairs(status.house_requirements) do add(req.type, req.name, ceil(req.amount - req.delivered)) end
    add("virtual", "rt-signal-houses", status.houses_to_upgrade)
  elseif mode == "upkeep" then
    for _, req in ipairs(status.upkeep) do add(req.type, req.name, ceil(req.per_minute)) end
  end
  add("virtual", "rt-signal-power-mw", ceil(status.power_watts / 1e6))
  add("virtual", "rt-signal-power-percent", status.power_percent)
  return list
end

--- Zapíše signály do první sekce konstantního kombinátoru (přepíše, co tam hráč nastavil).
function M.write(entity, list)
  local behavior = entity.get_or_create_control_behavior()
  local section = behavior.get_section(1) or behavior.add_section()
  local filters = {}
  for i, signal in ipairs(list) do
    local value = { type = signal.type, name = signal.name }
    -- Kvalitu mají jen předměty; u kapalin a virtuálních signálů se nevyplňuje.
    if signal.type == "item" then
      value.quality = "normal"
      value.comparator = "="
    end
    filters[i] = { value = value, min = signal.count }
  end
  section.filters = filters
end

return M
```

Run: `bash tools/run-unit.sh` → Expected: `fail=0`.

- [ ] **Step 3: Prototypy tabule a signálů**

V `research-towns/prototypes/depots.lua` přidej za `fluid`:

```lua
-- Městská tabule: konstantní kombinátor, jehož signály plní skript podle režimu (viz scripts/board.lua).
local board = derive(data.raw["constant-combinator"]["constant-combinator"], "rt-town-board")
```

do `data:extend({ goods, fluid, power })` přidej `board` a na konec souboru:

```lua
data:extend({ item_and_recipe(board, "e", {
  { type = "item", name = "copper-cable", amount = 10 }, { type = "item", name = "iron-plate", amount = 5 },
  { type = "item", name = "stone-brick", amount = 5 } }) })
```

(Docstring souboru: „Překladiště: zboží (bedna), kapaliny (nádrž), městská rozvodna a městská tabule.“)

`research-towns/prototypes/signals.lua`:

```lua
--- Virtuální signály městské tabule.
data:extend({
  { type = "virtual-signal", name = "rt-signal-houses", icon = "__base__/graphics/icons/stone-furnace.png",
    subgroup = "virtual-signal", order = "z-rt-a" },
  { type = "virtual-signal", name = "rt-signal-power-mw", icon = "__base__/graphics/icons/accumulator.png",
    subgroup = "virtual-signal", order = "z-rt-b" },
  { type = "virtual-signal", name = "rt-signal-power-percent", icon = "__base__/graphics/icons/substation.png",
    subgroup = "virtual-signal", order = "z-rt-c" },
})
```

Do `research-towns/data.lua` přidej `require("prototypes.signals")`.

Locale en (do existujících sekcí, nové sekce `[virtual-signal-name]` vytvoř):

```
[entity-name]
rt-town-board=Town board
[entity-description]
rt-town-board=The town announces what it needs. Sends the town's requests to the circuit network; choose the mode in its window. Its signals are rewritten by the town.
[item-name]
rt-town-board=Town board
[item-description]
rt-town-board=The town announces what it needs.
[virtual-signal-name]
rt-signal-houses=Houses to upgrade
rt-signal-power-mw=Town power demand (MW)
rt-signal-power-percent=Town power coverage (%)
[rt]
gui-board-title=Town board
gui-board-mode=Signals
board-mode-hall=Town hall – remaining for the next level
board-mode-house=House – one house upgrade + number of houses
board-mode-upkeep=Upkeep – per minute
```

cs:

```
[entity-name]
rt-town-board=Městská tabule
[entity-description]
rt-town-board=Město tu oznamuje, co potřebuje. Posílá požadavky města do obvodové sítě; režim zvolíš v jejím okně. Signály přepisuje město.
[item-name]
rt-town-board=Městská tabule
[item-description]
rt-town-board=Město tu oznamuje, co potřebuje.
[virtual-signal-name]
rt-signal-houses=Domy k vylepšení
rt-signal-power-mw=Příkon města (MW)
rt-signal-power-percent=Pokrytí elektřiny města (%)
[rt]
gui-board-title=Městská tabule
gui-board-mode=Signály
board-mode-hall=Radnice – zbývá do další úrovně
board-mode-house=Dům – vylepšení jednoho domu + počet domů
board-mode-upkeep=Spotřeba – za minutu
```

(Řádky vlož do odpovídajících existujících sekcí, ne jako duplicitní hlavičky.)

- [ ] **Step 4: Integrační testy (RED)**

`tests/research-towns-tests/cases/board.lua`:

```lua
--- Integrační testy městské tabule.
local H = require("helpers")
local R = H.REMOTE

--- Signály tabule jako mapa jméno → hodnota.
local function signals(entity)
  local result = {}
  local behavior = entity.get_control_behavior()
  local section = behavior and behavior.get_section(1)
  for _, filter in pairs(section and section.filters or {}) do
    if filter.value then result[filter.value.name] = filter.min end
  end
  return result
end

return {
  {
    name = "tabule v režimu Radnice posílá milník a příkon",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.board = H.place(ctx, "rt-town-board", 2, 9)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "board_mode", ctx.board.unit_number) == "hall", "výchozí režim")
      H.process(ctx.town)
      local got = signals(ctx.board)
      local science = H.levels_data().upgrade["1"][1]
      H.check(got[science.name] == science.amount, "věda milníku: " .. serpent.line(got))
      H.check(got["rt-signal-power-mw"] == 1, "příkon: " .. serpent.line(got))
    end } },
  },
  {
    name = "režimy Dům a Spotřeba",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      remote.call(R, "set_level", ctx.town, 2)
      H.house(ctx, 11, 0)
      ctx.board = H.place(ctx, "rt-town-board", 2, 9)
    end,
    steps = { { ticks = 1, run = function(ctx)
      remote.call(R, "set_board_mode", ctx.board.unit_number, "house")
      H.process(ctx.town)
      H.check(signals(ctx.board)["rt-signal-houses"] == 1, "domy: " .. serpent.line(signals(ctx.board)))
      remote.call(R, "set_board_mode", ctx.board.unit_number, "upkeep")
      H.process(ctx.town)
      local first = H.status(ctx.town).upkeep[1]
      H.check(signals(ctx.board)[first.name] == math.ceil(first.per_minute - 1e-6), "spotřeba: " .. serpent.line(signals(ctx.board)))
    end } },
  },
  {
    name = "tabule bez města nic neposílá",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      ctx.board = H.place(ctx, "rt-town-board", 0, 30)
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.process(ctx.town)
      H.check(next(signals(ctx.board)) == nil, "signály bez města: " .. serpent.line(signals(ctx.board)))
    end } },
  },
  {
    name = "režim z plánu (tag) se převezme",
    setup = function(ctx)
      ctx.town = H.town(ctx)
      local ghost = ctx.surface.create_entity({ name = "entity-ghost", inner_name = "rt-town-board", force = "player",
        position = { ctx.origin.x + 2.5, ctx.origin.y + 9.5 }, tags = { rt_board_mode = "upkeep" } })
      local _, board = ghost.revive({ raise_revive = true })
      ctx.board = board
    end,
    steps = { { ticks = 1, run = function(ctx)
      H.check(remote.call(R, "board_mode", ctx.board.unit_number) == "upkeep", "režim z tagu")
    end } },
  },
}
```

V `tests/research-towns-tests/control.lua` přidej `runner.register(require("cases.board"))`.

Run: `bash tools/run-tests.sh vanilla`
Expected: FAIL nových testů (`board_mode` neexistuje / signály prázdné).

- [ ] **Step 5: Runtime – překladiště, města, stav**

V `research-towns/scripts/depots.lua`:
- přidej `local board = require("scripts.board")`;
- `M.KINDS["rt-town-board"] = "board"` (do tabulky) a `"rt-town-board"` do `M.names()`;
- `M.add` nahraď:

```lua
--- Zaeviduje nové překladiště nebo tabuli; tagy z plánu nesou režim tabule.
--- @param tags table|nil
function M.add(entity, tags)
  local depot = { key = entity.unit_number, entity = entity, kind = M.KINDS[entity.name] }
  if depot.kind == "board" then depot.mode = tags and tags[board.TAG] or "hall" end
  storage.depots[depot.key] = depot
  -- Odstranění bez události (jiný mod, editor) ohlásí on_object_destroyed.
  script.register_on_object_destroyed(entity)
  release_power(depot)
  M.resolve(depot)
  return depot
end
```

- v `M.resolve` za `depot.town = best and best.town` (před `if old == depot.town then return end`) přidej:

```lua
  -- Tabule bez města nesmí posílat staré požadavky.
  if depot.kind == "board" and not depot.town then board.write(entity, {}) end
```

- přidej:

```lua
--- Pokrytí elektřiny města v procentech (nejhorší rozvodna; bez rozvodny 0).
function M.power_percent(town)
  local worst
  for key in pairs(town.depots) do
    local depot = storage.depots[key]
    local entity = depot and depot.kind == "power" and depot.entity
    if entity and entity.valid and entity.power_usage > 0 then
      local ratio = math.min(1, entity.energy / entity.power_usage)
      if not worst or ratio < worst then worst = ratio end
    end
  end
  return math.floor((worst or 0) * 100)
end
```

V `research-towns/scripts/towns.lua` přidej `local board = require("scripts.board")`, do `M.status` pole `power_percent = depots.power_percent(town),` a za `M.status`:

```lua
--- Zapíše signály do všech tabulí města (stav se počítá jen, když nějaká tabule je).
function M.refresh_boards(town)
  local status
  for key in pairs(town.depots) do
    local depot = storage.depots[key]
    if depot and depot.kind == "board" and depot.entity.valid then
      status = status or M.status(town)
      board.write(depot.entity, board.signals(depot.mode, status))
    end
  end
end
```

Na konec `M.process` přidej `M.refresh_boards(town)`.

V `research-towns/scripts/state.lua` doplň `storage.gui_board = storage.gui_board or {}` a do cyklu doplnění:

```lua
  for _, depot in pairs(storage.depots) do
    if depot.kind == "board" then depot.mode = depot.mode or "hall" end
  end
```

Do `research-towns/scripts/remote.lua`:

```lua
  --- Režim městské tabule, nebo nil.
  board_mode = function(unit_number)
    local depot = storage.depots[unit_number]
    return depot and depot.mode
  end,
  --- Nastaví režim městské tabule ("hall" | "house" | "upkeep").
  set_board_mode = function(unit_number, mode)
    local depot = storage.depots[unit_number]
    if depot and depot.kind == "board" then depot.mode = mode end
  end,
```

- [ ] **Step 6: Události – tagy, kopírování nastavení, plán, GUI tabule**

V `research-towns/control.lua`:
- v `on_built` změň `depots.add(entity)` na `depots.add(entity, event.tags)`;
- přidej `local board = require("scripts.board")` a handlery:

```lua
--- Shift+klik kopírování nastavení mezi tabulemi přenese režim.
local function on_settings_pasted(event)
  local source = storage.depots[event.source.unit_number]
  local target = storage.depots[event.destination.unit_number]
  if source and target and source.kind == "board" and target.kind == "board" then target.mode = source.mode end
end

--- Plán (blueprint) si u tabulí zapamatuje režim do tagu.
local function on_setup_blueprint(event)
  local player = game.get_player(event.player_index)
  local stack = player.blueprint_to_setup
  if not (stack and stack.valid_for_read) then stack = player.cursor_stack end
  if not (stack and stack.valid_for_read and stack.is_blueprint) then return end
  for index, entity in pairs(event.mapping.get()) do
    local depot = entity.valid and storage.depots[entity.unit_number]
    if depot and depot.kind == "board" then stack.set_blueprint_entity_tag(index, board.TAG, depot.mode) end
  end
end
```

a registrace:

```lua
script.on_event(defines.events.on_entity_settings_pasted, on_settings_pasted)
script.on_event(defines.events.on_player_setup_blueprint, on_setup_blueprint)
script.on_event(defines.events.on_gui_selection_state_changed, gui.on_selection_changed)
```

V `research-towns/scripts/gui.lua`:
- přidej `local board = require("scripts.board")`, do `M.NAMES` `board_frame = "rt_board_frame", board_mode = "rt_board_mode"`;
- na konec `M.ensure`:

```lua
  if relative[n.board_frame] then relative[n.board_frame].destroy() end
  local board_frame = relative.add({
    type = "frame", name = n.board_frame, direction = "vertical", caption = { "rt.gui-board-title" },
    anchor = { gui = defines.relative_gui_type.constant_combinator_gui, position = defines.relative_gui_position.right,
      names = { "rt-town-board" } },
  })
  board_frame.add({ type = "label", caption = { "rt.gui-board-mode" } })
  local items = {}
  for i, mode in ipairs(board.MODES) do items[i] = { "rt.board-mode-" .. mode } end
  board_frame.add({ type = "drop-down", name = n.board_mode, items = items, selected_index = 1 })
```

- v `M.on_opened` na začátek:

```lua
  local entity = event.entity
  if entity and entity.valid and entity.name == "rt-town-board" then
    local depot = storage.depots[entity.unit_number]
    local player = game.get_player(event.player_index)
    if not player.gui.relative[M.NAMES.board_frame] then M.ensure(player) end
    storage.gui_board[event.player_index] = entity.unit_number
    for i, mode in ipairs(board.MODES) do
      if depot and depot.mode == mode then player.gui.relative[M.NAMES.board_frame][M.NAMES.board_mode].selected_index = i end
    end
    return
  end
```

- v `M.on_closed` přidej `storage.gui_board[event.player_index] = nil`;
- přidej:

```lua
--- Volba režimu tabule v jejím okně; signály se přepíšou hned.
function M.on_selection_changed(event)
  if event.element.name ~= M.NAMES.board_mode then return end
  local depot = storage.depots[storage.gui_board[event.player_index]]
  if not depot then return end
  depot.mode = board.MODES[event.element.selected_index]
  local town = depot.town and storage.towns[depot.town]
  if town and town.hall.valid then towns.refresh_boards(town) end
end
```

- [ ] **Step 7: Spusť testy**

Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla`
Expected: obě `fail=0`.

- [ ] **Step 8: Commit**

```bash
git add research-towns tests
git commit -m "feat: městská tabule posílá požadavky města do obvodové sítě

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011qF8pn2anGDbxkcC6UqKtx"
```

---

### Task 7: Texty, dokumentace, kompatibilita

**Files:**
- Modify: `research-towns/locale/en|cs/locale.cfg` (tipy), `research-towns/changelog.txt`
- Modify: `docs/development.md`, `docs/user-guide.md`, `docs/superpowers/specs/2026-10-05-research-towns-design.md`

**Interfaces:**
- Consumes: vše z Task 1–6.

- [ ] **Step 1: Tipy a triky**

V `[tips-and-tricks-item-description]` přepiš `rt-depots` a `rt-milestones` (en):

```
rt-depots=Towns receive supplies through depots placed within reach of a town building:\n[entity=rt-goods-depot] items, [entity=rt-fluid-depot] fluids and [entity=rt-power-depot] electricity.\nA depot always serves the nearest town. A [entity=rt-town-board] town board sends the town's requests to the circuit network.
rt-milestones=Each town level opens one new science pack. Open the town hall to see what the town needs: the new science pack and materials. When the delivery is complete and enough houses are connected, press [font=default-bold]Upgrade town[/font].\n\nOnce a milestone is done, the town keeps using its materials – keep the supply lines running or the town hall stops. Extra deliveries upgrade houses one by one, which speeds up research. Beyond the last science pack, towns keep growing and gain research productivity.
```

cs:

```
rt-depots=Města dostávají zásoby přes překladiště postavená v dosahu městské budovy:\n[entity=rt-goods-depot] předměty, [entity=rt-fluid-depot] kapaliny a [entity=rt-power-depot] elektřinu.\nPřekladiště vždy zásobuje nejbližší město. [entity=rt-town-board] Městská tabule posílá požadavky města do obvodové sítě.
rt-milestones=Každá úroveň města otevře jeden nový vědecký balíček. Otevři radnici a uvidíš, co město potřebuje: nový balíček a suroviny. Až je dodávka kompletní a připojeno dost domů, stiskni [font=default-bold]Povýšit město[/font].\n\nSuroviny splněných milníků pak město průběžně spotřebovává – udrž zásobování, jinak radnice stojí. Dodávky navíc postupně vylepšují domy, a ty zrychlují výzkum. Za poslední vědou města rostou dál a získávají produktivitu výzkumu.
```

Run: `bash tools/run-unit.sh` → Expected: `fail=0` (`test_locale`).

- [ ] **Step 2: Dokumentace**

`docs/development.md` – tabulku „Kde ladit hodnoty“ nahraď:

```markdown
| Co | Kde |
|---|---|
| Rychlost radnice (první/poslední věda) | `research-towns/shared/levels.lua` → `SPEED_FIRST`, `SPEED_LAST` |
| Domy s bonusem a podmínka povýšení | `shared/levels.lua` → `HOUSES_PER_LEVEL`, `HOUSE_LIMIT_MAX` |
| Bonus domu, strop rychlosti | `shared/levels.lua` → `house_bonus`, `SPEED_BONUS_CAP` |
| Příkon města | `shared/levels.lua` → `POWER_FIRST_MW`, `POWER_LAST_MW`, `POWER_INFINITE_GROWTH` |
| Suroviny milníků (pásma kandidátů), kusů vědy, růst množství | `shared/levels.lua` → `TIERS`, `SCIENCE_PACKS`, `MILESTONE_GROWTH` |
| Produktivita nekonečných úrovní | `shared/levels.lua` → `PRODUCTIVITY_MAX`, `PRODUCTIVITY_DECAY` |
| Průběžná spotřeba, zásoba | `shared/levels.lua` → `UPKEEP_RATE`, `HOUSE_UPKEEP_SHARE`, `UPKEEP_BUFFER_SECONDS`; ve hře startup nastavení „Násobič spotřeby surovin“ |
| Max. domů v sérii, dosah domů a překladišť | `shared/levels.lua` → `MAX_HOUSE_DEPTH`, `HOUSE_REACH`, `DEPOT_REACH` |
| Interval zpracování města | `shared/levels.lua` → `TOWN_INTERVAL` |
| Krok bonusu, sloty beaconu | `shared/levels.lua` → `BONUS_STEP`, `BONUS_SLOTS` |
| Pořadí věd → úrovně (algoritmus) | `prototypes/science.lua` → `bands` |
| Recepty domu, překladišť a tabule | `prototypes/house.lua`, `prototypes/depots.lua` |
| Barvy dočasné grafiky, počet variant | `prototypes/hall.lua` → `TINTS`, `prototypes/house.lua` → `TINTS`, `shared/levels.lua` → `VARIANTS` |
| Barva chodníků a popisků | `scripts/network.lua` → `LINK_COLOR`, `scripts/towns.lua` → `LABEL_COLOR` |
```

Do ručního checklistu v `docs/development.md` doplň:
- panel radnice: úroveň s počtem věd, produktivita (jen nad poslední vědou), domy k vylepšení s požadavky, spotřeba za minutu a stav zásoby;
- městská tabule: okno s volbou režimu, signály v obvodové síti (připojit lampu/kombinátor), Shift+klik kopírování režimu, plán (blueprint) s tabulí si pamatuje režim;
- startup nastavení „Násobič spotřeby surovin“ v nastavení modů.

`docs/user-guide.md` – body 1–5 nahraď:

```markdown
1. **Radnice** zkoumá jako laboratoř. Každá úroveň města otevře **jednu novou vědu** (úroveň 1 = první věda).
2. **Domy** (vyrobíš v montážním stroji) postav do dosahu radnice nebo jiného domu – propojí se visutým
   chodníkem. Nejvýš 5 domů v sérii od radnice; dům dál je neaktivní (ikona varování). K povýšení potřebuje město
   4 aktivní domy na úroveň (nejvýš 20).
3. **Městská rozvodna** u radnice nebo domu odebírá elektřinu města; bez ní radnice nezkoumá.
4. **Překladiště zboží a kapalin** u radnice nebo aktivního domu dodávají suroviny. Pořadí: nejdřív zásoba pro
   provoz, pak milník radnice (nová věda + suroviny), pak vylepšení domů. Co nikdo nepotřebuje, zůstane.
5. Až je milník splněný a máš dost domů, klikni v panelu radnice na **Povýšit město**.
6. **Spotřeba:** suroviny splněných milníků město průběžně spotřebovává, když zkoumá. Když dojdou, radnice stojí.
   Množství nastavíš v nastavení modu (Násobič spotřeby surovin).
7. **Vylepšení domů** je dobrovolné: dodávky navíc vylepšují domy postupně jeden po druhém (stejné suroviny jako
   milník radnice, bez vědy). Dům dává bonus (úroveň + 1) %, všechny domy dohromady nejvýš +120 %.
8. **Za poslední vědou** město roste dál; každá úroveň přidá produktivitu výzkumu radnice.
9. **Městská tabule** posílá do obvodové sítě požadavky města – režim Radnice, Dům nebo Spotřeba zvolíš v jejím
   okně; navíc signály příkonu (MW) a pokrytí elektřiny (%).
```

V `research-towns/changelog.txt` přidej do `Features:` (sekce 0.1.0):

```
    - Each town level opens one science pack; infinite levels beyond the last science add research productivity.
    - Houses have their own level and are upgraded with surplus deliveries; total speed bonus capped at +120 %.
    - Towns continuously consume the materials of completed milestones (startup setting to adjust).
    - Town board sends the town's requests to the circuit network.
```

Ve specifikaci v sekci „Další kroky“ označ bod 1 jako hotový (`1. ~~Plán 1b – úrovně~~ – hotovo <datum>, plán docs/superpowers/plans/2026-10-05-research-towns-levels.md`).

- [ ] **Step 3: Testy všech variant a kompatibilita**

Run:
```bash
bash tools/run-unit.sh
bash tools/run-tests.sh vanilla
bash tools/run-tests.sh space-age
bash tools/run-tests.sh mods pymodpack
bash tools/run-tests.sh mods boblibrary bobplates bobelectronics bobtech
```
Expected: všude `fail=0`. Pro `mods` přečti v `.test-run/mods/write-data/factorio-current.log` řádky `research-towns:` (počet úrovní, milníky, vynechané kandidáty). Sady modů Bob's vezmi stejné jako při ověření v plánu 1 (viz `docs/development.md`, sekce Kompatibilita – 16 modů `bob*`; seznam si přečti z `%APPDATA%/Factorio/mods`).

Do `docs/development.md` sekce Kompatibilita zapiš výsledky (datum, verze hry, počet úrovní pro vanilla / Space Age / Py / Bob's, vynechané kandidáty).

- [ ] **Step 4: Commit**

```bash
git add research-towns docs
git commit -m "docs: plán 1b – návod, ladění, kompatibilita a tipy

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011qF8pn2anGDbxkcC6UqKtx"
```

---

## Poznámky k návrhu (pro implementátora)

- **Postup vylepšení domu patří městu, ne domu.** Když vybraný dům zmizí nebo se změní pořadí, rozpracovaný
  postup přejde na další vybraný dům. Jednodušší než postup na každém domě; pro hráče nepoznatelné.
- **Spotřeba se měří po intervalech** (`TOWN_INTERVAL`): za interval, kdy radnice chce zkoumat, se odebere
  potřeba celého intervalu. Při částečném zásobování radnice střídavě běží a stojí – v průměru poměrně.
- **Milníky 1 a 2 ve vanille sdílejí pásmo surovin** (`tier_index`), takže se v překladištích potkávají spotřeba,
  milník i vylepšení domu – to je důvod priority v `allocation.lua` a testu „radnice má přednost“.
- **Hodnoty jsou první odhad** pro hraní; laditelné v `shared/levels.lua` (tabulka v `docs/development.md`).
