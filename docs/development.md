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
| Rozdělení věd do úrovní (algoritmus) | `prototypes/science.lua` → `bands` |
| Recepty domu a překladišť | `prototypes/house.lua`, `prototypes/depots.lua` |
| Barvy dočasné grafiky | `prototypes/hall.lua` → `TINTS`, `prototypes/house.lua` → `TINTS` |
| Barva chodníků a popisků | `scripts/network.lua` → `LINK_COLOR`, `scripts/towns.lua` → `LABEL_COLOR` |

## Kompatibilita
- Vědy, suroviny milníků i laboratoře se odvozují z `data.raw` v `data-final-fixes.lua`; v `create.log` je vidět
  výsledek (řádky `research-towns: …`).
- `info.json` má volitelnou závislost `? pypostprocessing` – Py si v něm teprve dopočítává prerekvizity výzkumů,
  náš final-fixes musí běžet až po něm (jinak skončí všechny vědy na úrovni 1).
- Ověřeno 2026-10-05 (Factorio 2.0.77):
  - Bob's (16 modů `bob*`): odstraněno `lab`, `bob-burner-lab`, `bob-lab-2`, `bob-lab-alien`; 18 věd v 5 úrovních.
  - `pymodpack`: odstraněno `lab`; 11 věd v 5 úrovních; milníky bez vynechání.
  - Space Age: odstraněno `lab`, `biolab`; 12 věd (modrá už na úrovni 2 – k doladění).
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
6. Dodat milník + 4 domy → Povýšit → radnice a domy změní barvu, panel ukazuje úroveň 2.
7. Výzkum „Automation science pack“ se spustí vyrobením domu.
