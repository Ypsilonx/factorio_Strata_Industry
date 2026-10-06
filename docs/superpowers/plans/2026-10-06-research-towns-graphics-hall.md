# Research Towns – grafika radnice (plán 3a) – implementační plán

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Radnice má vlastní grafiku z Blenderu v 5 vzhledech (osada → město vědy) se svítící vrstvou a stínem.

**Architecture:** Procedurální model a render v Blenderu (skripty v `blender/`, headless), výstupní PNG do
`research-towns/graphics/`. Prototyp radnice skládá sprity podle `levels.variant`. Modelování je iterativní:
každý vzhled se schvaluje podle náhledu, proto tasks 3–4 popisují díly, parametry a kritéria přijetí místo
hotového kódu geometrie (ten vzniká při ladění s uživatelem).

**Tech Stack:** Blender (`C:/STEAM/steamapps/common/Blender/blender.exe`, Cycles), Python (bpy, numpy),
Lua (Factorio 2.0 data stage), Lua 5.3 unit testy.

**Spec:** `docs/superpowers/specs/2026-10-06-research-towns-graphics-hall-design.md`

## Global Constraints

- Skript je zdroj pravdy; skripty idempotentní, pracují jen ve svých kolekcích (`RT_Hall`, `RT_Calib`, `RT_Ground`).
- Laditelné parametry kamery a světel jen v `blender/camera.toml`; paleta jen v `rt_materials.py` (`PALETTE`).
- Paleta tlumená, zemitá – sytost a jas porovnané s vanilla sprity na stejném terénu.
- Projekce: ortho, 45°, 64 px/dlaždici (ve hře `scale = 0.5`), supersampling 2×.
- Python: PEP 8, docstringy česky. Lua: konvence projektu. Locale beze změny.
- `blender/renders/`, `*.blend1` v `.gitignore`. Po práci smazat dočasné soubory.
- Commit jen v krocích Commit; zpráva končí řádky `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  a `Claude-Session: https://claude.ai/code/session_01NAMWsnMZJNsTjQY1Ye9sjg`.

## Review Focus

1. Výběrový obdélník a kolize (15×15) musí sedět na vykreslenou budovu – sprite shift odpovídá projekci.
2. Svítící vrstva jen ve stavu zapnuto (`on_animation`), ne ve vypnuté radnici.
3. Velikost sprite listu do limitu hry (max. 4096 px na stranu, rozumná paměť – 5 vzhledů × 3 vrstvy).
4. Kompatibilita: overhaul mody s jiným počtem úrovní – vzhled podle `levels.variant`, žádné pevné úrovně.
5. Barvy nesmí vyčnívat z vanilla vizuálu (kontrola vedle vanilla budov).

---

### Task 1: Pipeline a kalibrace projekce

**Files:** Create `blender/build_hall.py`, `blender/rt_render.py`, `blender/rt_materials.py`, `blender/camera.toml`;
Modify `.gitignore`.

- [ ] `camera.toml`: `[camera] elevation_deg = 45, px_per_tile = 64, supersample = 2`, `[sun] rotation_deg = [...]`,
  `strength`, `[fill]`, `[render] samples`. Hodnoty výchozí podle `factorio_loader-unloader/blender/so_render.py`.
- [ ] `rt_render.py`: načtení TOML (`tomllib`), `setup_scene(px_w, px_h, tiles_w, tiles_h, height_tiles)` (ortho kamera
  nad středem, `ortho_scale` z šířky v dlaždicích, posun kamery tak, aby budova vyšší než základna byla v záběru),
  `render_layers(...)` → base (RGBA, bez stínu), shadow (shadow catcher → alfa stínu), light (jen emise),
  `downsample`, `save_pixels`, `preview(sheet, terrain, vanilla_refs)` – náhled na trávníku vedle vanilla spritů.
- [ ] `build_hall.py --calibrate`: model zkušební laboratoře 3×3 (krabice 3×3×~2,5 dlaždice s výrazným obrysem),
  render ve stejné projekci, překryv s `__base__/graphics/entity/lab/lab.png` (hr list, první snímek) do
  `blender/renders/calibration.png` + výpis shift (px) a poměru jasu.
- [ ] Run: `blender -b --factory-startup --python blender/build_hall.py -- --calibrate`; Read `calibration.png`.
  Expected: obrys a výška zkušební krabice sedí na obrys laboratoře (±2 px), měřítko 64 px/dlaždici.
- [ ] Ukázat uživateli; po souhlasu commit „feat: blender pipeline a kalibrace projekce radnice“.

### Task 2: Prototyp radnice ze spritů + test rozměrů (s dočasnými rendery)

**Files:** Modify `research-towns/prototypes/hall.lua`; Create `tests/unit/test_graphics.lua`; Modify `tests/unit/run.lua`.

- [ ] Test (RED): pro každý vzhled 1..`levels.VARIANTS` existují `research-towns/graphics/entity/hall/hall-N-{base,light,shadow}.png`
  a `graphics/icons/hall-N.png`; rozměry z hlavičky PNG (IHDR, bajty 17–24) – base/light/shadow stejné, šířka
  = 15 × 64 + okraj z `rt_render` (zapsaný do `research-towns/graphics/entity/hall/hall.json` při buildu:
  `{ "width":…, "height":…, "shift": [x, y] }`), ikona 64×64.
- [ ] `hall.lua`: `on_animation`/`off_animation` z vrstev (base, light s `draw_as_light = true` jen v on, shadow
  s `draw_as_shadow = true`), `scale = 0.5`, `shift` z `hall.json` čteného v data stage? – **ne**: data stage
  nečte soubory; shift a rozměry zapíše build do `research-towns/prototypes/hall_sprites.lua` (generovaný Lua
  modul s tabulkou rozměrů), commitnutý. Ikona `icon = "__research-towns__/graphics/icons/hall-N.png"`.
  Odstranit `TINTS`, `placeholder.scaled` u radnice.
- [ ] Build dočasných renderů vzhledu 1 (jednoduchý blokový areál) pro všech 5 vzhledů, aby šlo zapojit a testovat.
- [ ] Run: `bash tools/run-unit.sh && bash tools/run-tests.sh vanilla` → zelené. Commit.

### Task 3: Vzhled 1 – osada (styl a paleta)

**Files:** Create `blender/rt_hall.py`; Modify `rt_materials.py`.

- [ ] Díly (funkce v `rt_hall.py`, parametr `variant`): `ground(court)` hliněné nádvoří 15×15 s okrajem,
  `research_hall(variant)` kamenná věž s dřevěnou vyhlídkou (zadní střed, ~5×4 dlaždice, výška ~4),
  `workshop(variant, side)` dílny vlevo/vpravo vzadu (~4×4), `side_house(variant, i)` 2 domky na každé straně,
  `gate(variant)` brána vepředu, `well()` studna uprostřed, `fire_pit()` vatry (emise do light vrstvy).
  Otočný díl kopule/vyhlídky jako samostatný objekt `RT_Hall_Rotor`.
- [ ] `rt_materials.py`: `PALETTE` (kámen, dřevo, došky, hlína, mosaz, sklo, cihla, plech) – tlumené hodnoty;
  materiály s patinou (AO, bevel, šum) jako v referenčním projektu.
- [ ] Náhled `blender/renders/preview-1.png` (areál na trávě vedle vanilla laboratoře, montážního stroje, kamenné pece).
- [ ] Ukázat uživateli, ladit podle připomínek; po schválení build do modu, unit + vanilla testy, commit.

### Task 4: Vzhledy 2–5

- [ ] Pro každý vzhled 2, 3, 4, 5 rozšířit díly podle tabulky ve specifikaci (cihly a plech; patro a potrubí a
  malá kopule; mosazná kopule s teleskopem a lávky; velká kopule, věž, zahrady, ornamenty).
- [ ] Každý vzhled: náhled → schválení uživatelem → build → testy → commit.
- [ ] Náhled `preview-all.png` (všech 5 vedle sebe) pro uživatele a pozdější portál.

### Task 5: Dokumentace a ruční kontrola

- [ ] `docs/development.md`: sekce Grafika (spuštění, výstupy, kde ladit: `camera.toml`, `PALETTE`, díly v `rt_hall.py`),
  ruční kontrola radnice ve hře; `changelog.txt` (Graphics: town hall models). Commit.
