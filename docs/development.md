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
| Překladiště v Blenderu (zboží na paletách, nádrž, průzor) | `blender/rt_depots.py` → `PALLETS`, `PALLET_ITEMS`, `ITEM_SCALE`, `TANK`, `GAUGE` |
| Grafika z Blenderu (počet vzhledů, modely, paleta, světla) | `shared/levels.lua` → `VARIANTS`; `blender/rt_hall.py`, `rt_house.py`, `rt_depots.py` (modely), `rt_materials.py` → `PALETTE`, `blender/camera.toml` (projekce, světla); build `blender/build_hall.py` |
| Vzhled jako vanilla (kontrast, sytost, hrany, kouty, rez, mech, tašky) | `blender/camera.toml` → `[sun]`, `[fill]`, `[world]` `strength`, `[grade]` `saturation`, `contrast`; `blender/rt_materials.py` → `PALETTE_SATURATION`, `EDGE_HIGHLIGHT`, `EDGE_LIGHTEN`, `CREVICE_DEPTH`, `RUST`, `MOSS`, `ROOF_TINTS`, `GROUND_TINT` |
| Textury ze hry (terén, sprity strojů, stíny) | `blender/rt_terrain.py` → `TERRAINS`; `blender/rt_sprites.py` → `MACHINES`, `SHADOWS`, `SHADOW_ALPHA`, `CARD_LIFT`; stín budov na spritech `blender/rt_render.py` → `CARD_SHADOW`, `CARD_TILT_DEG`; vyznění stínů u okraje `fade_edges` |
| Rozložení radnice (domy, statky, stromy, bedny) | `blender/rt_hall.py` → `ERA_SITES`, `ERA_RESERVE`, `POLE_CLEAR`, `FREE_TREES`, `FARM_MIN_ZONE`, `CHEST_SCALE`, `MAX_HOUSES` |
| Noční světla (barva, dosah, síla, od jaké tmy; sloučení svítidel) | `scripts/lights.lua` → `STYLE`, `MIN_DARKNESS`; pozice generuje `blender/build_hall.py --lights` (nebo `--install`) do `shared/night_lights.lua`, sloučení `LIGHT_CLUSTER` |
| Panel radnice: slotů na řádek, šířka progress baru | `scripts/gui.lua` → `SLOT_COLUMNS`, `BAR_WIDTH` |
| Rozmístění měst, dar, objevení, první město | `shared/worldgen.lua` → `TOWN_CELL_BASE`, `TOWN_CELL_MAX`, `TOWN_CELL_MARGIN`, `TOWN_SITE_WINDOW`, `TOWN_SPAWN_CLEAR`, `TOWN_NEST_CLEAR`, `TOWN_PLAYER_CLEAR`, `DISCOVERY_RADIUS`, `GIFT_SHARE`, `FIRST_TOWN_*`, barva na mapě `MAP_COLOR` |
| Spojení budov (chodník, šňůra, praporky, lucerny, lávky) | `scripts/network.lua` → `PATH_COLOR`, `PATH_WIDTH`, `ROPE_COLOR`, `ROPE_SHADOW_OFFSET`, `LANTERN_COLOR`, `WALKWAY_LAYER`; tvar a styl podle úrovně `scripts/links.lua` → `SAG_*`, `ANCHOR`, `FLAG_*`, `style`; textura lávek `blender/build_hall.py` → `skywalk_model` |
| Barva popisků města | `scripts/towns.lua` → `LABEL_COLOR` |

## Grafika (Blender)

Sprity vznikají skriptem `blender/build_hall.py` (headless, z kořene repa), přepínače viz docstring skriptu:

```
"C:/STEAM/steamapps/common/Blender/blender.exe" -b --factory-startup --python blender/build_hall.py -- --variant 3 --draft
```

- `--draft` rychlý náhled → `blender/renders/preview-*.png` (den, noc, vedle vanilla budov); výpis „jas, kontrast,
  stíny, světla, sytost“ srovnávej s vanilla (kontrast ~0,20, sytost ~0,4).
- `--install` zapíše vrstvy (base, light, shadow) a ikony do modu.
- `--scene hall|house N` jen postaví scénu v otevřeném Blenderu přes MCP (prohlížení modelu, bez renderu;
  doladění barev a stín na spritech ze hry vznikají až při skládání vrstev, v náhledu Blenderu nejsou).
- Textury a sprity ze hry se čtou z instalace Factoria a skládají do `blender/renders/sprites` (necommituje se).

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
- Ověřeno 2026-10-06, plán 2a (města na mapě), unit 68/68, vanilla 52/52, Space Age 52/52, worldgen 1/1:
  Bob's (17 modů) compat 6/6, `pymodpack` compat 6/6 – posuvník Města a značky na Nauvisu vzniknou,
  první město se umístilo (v `create.log` chybí „první město se nepodařilo umístit“).

## Testy
- `bash tools/run-unit.sh` – čistá logika.
- `bash tools/run-tests.sh vanilla` a `space-age` – integrační testy.
- `bash tools/run-tests.sh mods <mod>…` – kompatibilita (jen `cases/compat.lua`).
- `bash tools/run-tests.sh worldgen` – pomalý test minima měst (nejnižší četnost, 3 seedy, ~1,5 min);
  2026-10-06: 25 / 31 / 30 měst do 1 500 dlaždic.
- Náhled mapy s modem (po `run-tests.sh vanilla`): `factorio --config .test-run/vanilla/config.ini
  --mod-directory .test-run/vanilla/mods --generate-map-preview preview.png --map-gen-seed 123`.

## Ruční kontrola ve hře (headless ji neověří)
1. Nová hra, `/rt-create-town` (admin) – radnice 15×15 s popiskem a jménem, popisek i na mapě.
2. Postavit dům u radnice – chodník se vykreslí; dům daleko – ikona varování. V Alt režimu číslo úrovně nad domem;
   po vylepšení domu se zvýší.
3. Otevřít radnici – panel vpravo: úroveň, domy, elektřina, milník s ikonami, tlačítko Povýšit neaktivní.
4. Přejmenovat město v panelu (Enter) – změní se popisek.
5. Rozvodna bez elektřiny → „Nedostatek elektřiny“, radnice nezkoumá; s elektřinou zkoumá.
6. Dodat milník (vč. zelené vědy) + 4 domy → Povýšit → radnice změní barvu, panel ukazuje úroveň 2; domy si drží vlastní úroveň.
7. Výzkum „Automation science pack“ se spustí vyrobením domu.
8. Panel radnice: úroveň s počtem věd, produktivita (jen nad poslední vědou), domy k vylepšení s požadavky,
   suroviny jako sloty (číslo = kolik chybí, splněné zeleně, tooltip „Dodáno X / Y“ pod popupem suroviny), spotřeba
   jako sloty (číslo = za minutu, tooltip se zásobou, červeně když dojde). Záhlaví „Další úroveň“ a „Domy k vylepšení“
   s progress barem a procenty vpravo – nic se nepřekrývá. Při plném bonusu domů hláška „Domy dávají plný bonus“.
9. Městská tabule: okno s volbou režimu (Radnice / Dům / Spotřeba), signály v obvodové síti (připojit lampu nebo
   kombinátor; Spotřeba = celá zásoba na 5 minut; signály postupu úrovně a domu v %), Shift+klik kopíruje režim
   na jinou tabuli, plán (blueprint) s tabulí si pamatuje režim. Taky: přeplánovat plán v knihovně
   (Znovu vybrat oblast) si režim zachová; Shift+klik z obyčejného kombinátoru na tabuli – signály tabule se hned
   obnoví; přiřadit sekci tabule do logistické skupiny – tabule ji odpojí a skupina u jiných kombinátorů zůstane.
10. Nastavení modů → Startup: „Násobič spotřeby surovin“ (0 vypne spotřebu).
11. Tipy a triky: kategorie Research Towns s aktualizovanými texty (úrovně, spotřeba, tabule).
12. Nad poslední vědou (`/c remote.call("research-towns", "set_level", <id>, 8)`): Povýšit v panelu – okno zůstane
    otevřené a panel ukáže novou úroveň a produktivitu.
13. Nová mapa: v okně generátoru posuvník „Města“, v náhledu mapy oranžové čtverečky měst; četnost mění jejich počet.
14. Start hry: první město 100–200 dlaždic od přistání, partnerské, se jménem na mapě.
15. Dojít k cizímu městu: zpráva s GPS, značka na mapě, panel radnice (jde neutrální radnici otevřít?) ukazuje dar;
    překladiště u radnice dar sebere, po dodání zpráva o partnerství, radnice začne zkoumat s elektřinou, domy se
    připojí.
16. Rozehraný save bez měst (mod přidaný později): po načtení přibudou města i první město.
17. Grafika radnice: 5 vzhledů (`/c remote.call("research-towns", "set_level", <id>, N)`), výběr sedí na areál 15×15,
    stín doprava dolů, okna svítí jen při výzkumu, ikona v panelu.
18. Domy: vzhled podle úrovně domu 1–5 (chalupa → činžák), okna svítí v noci, ikona předmětu domu.
    Noční světla (`/c game.player.surface.daytime = 0.5`): okolí oken, luceren, lamp a ohně radnice i domů
    je osvětlené, světla sedí na svítidlech spritu a po povýšení domu / města se vymění (žádná nezůstanou viset).
19. Spojení: úroveň města 1–2 šňůra s praporky a lucernami, 3–4 dřevěná lávka, 5 prosklená lávka (leží na zemi
    pod budovami, natočená po směru spojení); nic nepřekáží chůzi ani stavbě pásů.
20. Překladiště: sklad 2×2 se zbožím ze hry na paletách (výběr i dosah 2×2), nádrž s domkem obsluhy, ventily
    a pákami – kapalina je vidět v průzoru na plášti nádrže, potrubí se připojí v rozích, rozvodna s rozsvíceným
    oknem, barevná tabule s erbem – dráty se připínají na levý sloupek, kontrolka svítí v lucerně;
    ikony v inventáři odpovídají modelům.
