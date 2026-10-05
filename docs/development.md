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

## Kompatibilita
- Vědy, suroviny milníků i laboratoře se odvozují z `data.raw` v `data-final-fixes.lua`; v `create.log` je vidět
  výsledek (řádky `research-towns: …`).
- `info.json` má volitelnou závislost `? pypostprocessing` – Py si v něm teprve dopočítává prerekvizity výzkumů,
  náš final-fixes musí běžet až po něm (jinak skončí všechny vědy na úrovni 1).
- Ověřeno 2026-10-05 (Factorio 2.0.77), plán 1b (úroveň = věda), unit 53/53, vanilla 37/37, Space Age 37/37:
  - Bob's (17 modů `bob*`): odstraněno `lab`, `bob-burner-lab`, `bob-lab-2`, `bob-lab-alien`; 16 úrovní; compat 5/5.
  - `pymodpack`: odstraněno `lab`; 11 úrovní; milníky bez vynechání; compat 5/5.
  - Space Age: odstraněno `lab`, `biolab`; 12 úrovní (modrá na úrovni 4, planetární vědy 8–12).
  - Vanilla: 7 úrovní (vojenská věda je úroveň 3 před modrou – podle stromu, potvrzeno).
  - Krastorio 2 zatím neověřeno (není staženo).

## Testy
- `bash tools/run-unit.sh` – čistá logika.
- `bash tools/run-tests.sh vanilla` a `space-age` – integrační testy.
- `bash tools/run-tests.sh mods <mod>…` – kompatibilita (jen `cases/compat.lua`).

## Ruční kontrola ve hře (headless ji neověří)
1. Nová hra, `/rt-create-town` (admin) – radnice 15×15 s popiskem a jménem, popisek i na mapě.
2. Postavit dům u radnice – chodník se vykreslí; dům daleko – ikona varování.
3. Otevřít radnici – panel vpravo: úroveň, domy, elektřina, milník s ikonami, tlačítko Povýšit neaktivní.
4. Přejmenovat město v panelu (Enter) – změní se popisek.
5. Rozvodna bez elektřiny → „Nedostatek elektřiny“, radnice nezkoumá; s elektřinou zkoumá.
6. Dodat milník (vč. zelené vědy) + 4 domy → Povýšit → radnice změní barvu, panel ukazuje úroveň 2; domy si drží vlastní úroveň.
7. Výzkum „Automation science pack“ se spustí vyrobením domu.
8. Panel radnice: úroveň s počtem věd, produktivita (jen nad poslední vědou), domy k vylepšení s požadavky,
   spotřeba za minutu a stav zásoby; ikony mají popup suroviny.
9. Městská tabule: okno s volbou režimu (Radnice / Dům / Spotřeba), signály v obvodové síti (připojit lampu nebo
   kombinátor), Shift+klik kopíruje režim na jinou tabuli, plán (blueprint) s tabulí si pamatuje režim.
10. Nastavení modů → Startup: „Násobič spotřeby surovin“ (0 vypne spotřebu).
11. Tipy a triky: kategorie Research Towns s aktualizovanými texty (úrovně, spotřeba, tabule).
