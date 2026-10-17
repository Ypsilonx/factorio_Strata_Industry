# Research Towns

Mod do Factoria 2.0 (`research-towns`, prefix `rt`, log tag `RT`): laboratoře nahrazují radnice měst na Nauvisu,
města rostou podle dodávek. Vydaný na mods.factorio.com. Velikost: L.

Doména: factorio-mod (+ blender-workflow pro grafiku) – obecná pravidla jsou ve skillech, tady se neopakují.

## Spuštění a ověření

- Ověřit (po změně): `bash tools/run-unit.sh` + `bash tools/run-tests.sh vanilla`
- Před commitem milníku navíc: `bash tools/run-tests.sh space-age`
- Před vydáním navíc: `bash tools/run-tests.sh mods <bob…>` a `mods pymodpack`, pomalý `bash tools/run-tests.sh worldgen`
- Hraní / ladění: `bash tools/link-mod.sh`, pak F5 ve VSCode („Factorio – Research Towns“)
- Grafika: `blender/build_hall.py` (přepínače `--draft`, `--install`, `--scene` viz docstring a `docs/development.md`)

## Mapa projektu

- `research-towns/shared/levels.lua` – **veškerý balanc** (sdílí data i control stage); další laditelné hodnoty v tabulce „Kde ladit hodnoty“ v `docs/development.md`
- `research-towns/prototypes/` – data stage: `science.lua` (vědy → úrovně), `labs.lua` (rušení laboratoří), `hall`/`house`/`ruin`/`depots` (stavby), `specializations`, `worldgen` (posuvník Města), `*_sprites.lua` generované Blenderem
- `research-towns/scripts/` – runtime: `towns` (města), `scheduler` (zpracování po ticích), `network`+`graph`+`links` (síť budov), `depots`, `upkeep`, `milestones`, `houses`, `gui`, `board` (tabule), `worldgen`+`discovery`, `lights`, `smoke`, `remote` (rozhraní `research-towns` pro testy)
- `research-towns/shared/` – čistá logika sdílená runtime a testy (`worldgen`, `specialization`, `story`) + generované `night_lights.lua`
- `blender/` – pipeline spritů radnice, domů, ruin a překladišť (`build_hall.py` + moduly `rt_*.py`, `camera.toml`)
- `tests/unit/`, `tests/research-towns-tests/` (integrační, `cases/compat.lua` pro cizí mody)
- `docs/` – `development.md` (vývoj, ladění, checklist ruční kontroly), `user-guide.md`, `mod-portal.md`, návrhy v `docs/specs/`

## Rozhodnutí a pravidla tohoto projektu

- Úroveň města = jedna věda; vědy, suroviny milníků, laboratoře i specializace se odvozují z `data.raw` ve final-fixes (kompatibilita s overhauly).
- `info.json` má `? pypostprocessing` – Py dopočítává prerekvizity výzkumů, náš final-fixes musí běžet po něm.
- Rušené laboratoře se v cizích receptech nahrazují surovinami receptu laboratoře (`labs.remove`), recyklace se přegeneruje.
- Soubory `*_sprites.lua` a `shared/night_lights.lua` generuje `build_hall.py --install` – ručně neupravovat.

Stav práce: viz `STATUS.md`, směr: `ROADMAP.md`.
