# Research Towns – plán 3a: grafika radnice z Blenderu

Navazuje na `2026-10-05-research-towns-design.md` (plán 3 – grafika a vydání). Schváleno s uživatelem 2026-10-06.
Plán 3 je rozdělený: **3a** pipeline + kalibrace + radnice, **3b** dům + visutý chodník, **3c** překladiště,
rozvodna, tabule, ikony a ikony signálů, **3d** thumbnail, screenshoty, portál.

## Cíl

Radnice dostane vlastní grafiku, která vypráví příběh partnerství: místní architektura se s úrovní města
mění ve fúzi s technikou. Grafika zapadá do vizuálu Factoria – tlumené, zemité barvy, žádné výrazné tóny.

## Styl a kompozice

- **Areál 15×15 kolem nádvoří:** zadní řada dílna – **badatelna** (věž/kopule) – dílna; dlážděné nádvoří se
  studnou/kašnou a lampami; menší domky po stranách; **brána** vepředu (vstup balíčků).
- **5 vzhledů** (`levels.VARIANTS`, rozložené na úrovně města přes `levels.variant`):

| Vzhled | Materiály a prvky |
|---|---|
| 1 Osada | dřevo, kámen, doškové/dřevěné střechy, hliněné nádvoří, vatry, kamenná věž s dřevěnou vyhlídkou |
| 2 Dílny | první cihly a plechové střechy, okapy a komíny dílen, dlážděné nádvoří, olejové lampy |
| 3 Škola | patrová badatelna z kamene a cihel, ocelové nosníky, potrubí mezi budovami, elektrické lampy, malá prosklená kopule |
| 4 Technická | kopule z mosazi a skla s teleskopem, lávky mezi budovami, osvětlené dílny |
| 5 Město vědy | velká prosklená kopule s prstencem, vysoká věž, zelené střechy a zahrady, svítící ornamenty; pod technikou pořád kamenná osada |

- **Paleta:** tlumená, zemitá (okr, hlína, šedý kámen, zašlé dřevo), mosaz zašlá, sklo tmavé; sytost a jas
  porovnané s vanilla sprity (laboratoř, montážní stroj, kamenná pec) na stejném terénu.
- **Výzkum:** statická budova + **svítící vrstva** (okna, lampy, vatry, kopule) jen ve stavu zapnuto.
  Animace (teleskop, kouř) později – otočný díl kopule je v modelu samostatný objekt.

## Technika

- Skripty v `blender/` (zdroj pravdy, idempotentní): `build_hall.py` (vstup), `rt_materials.py` (paleta,
  materiály s patinou), `rt_hall.py` (geometrie areálu podle vzhledu), `rt_render.py` (kamera, světla, render,
  skládání vrstev), `camera.toml` (projekce a světla – laditelné).
- Projekce jako ve hře: ortografická kamera pod 45°, 64 px na dlaždici, ve hře `scale = 0.5`; kalibrace proti
  vanilla laboratoři (`__base__/graphics/entity/lab/lab.png`, překryv obrysu, měřítka a jasu).
- Spuštění headless: `blender -b --factory-startup --python blender/build_hall.py [-- --variant N] [--preview]`.
- **Výstupy** (vzhled N = 1–5): `research-towns/graphics/entity/hall/hall-N-{base,light,shadow}.png`
  a `research-towns/graphics/icons/hall-N.png` (64×64). Náhledy do `blender/renders/` (mimo git).
- **Prototyp** (`prototypes/hall.lua`): `off_animation` = base + shadow, `on_animation` = base + light
  (`draw_as_light`) + shadow; ikona radnice z `hall-N.png`. Dočasná grafika radnice (tónovaná laboratoř,
  `TINTS`) se odstraní.

## Postup

1. Kalibrace projekce a jasu (zkušební laboratoř přes vanilla sprite) – náhled uživateli.
2. Vzhled 1 – náhled na terénu vedle vanilla budov; uživatel schválí styl a barvy.
3. Vzhledy 2–5 – každý s náhledem.
4. Zapojení do modu, testy, ruční kontrola ve hře.

## Testování

- Unit: PNG radnice existují a mají očekávané rozměry (čtení hlavičky PNG v Lua), počet vzhledů = `VARIANTS`.
- Integrační testy (vanilla, Space Age) zůstanou zelené.
- Ručně ve hře: radnice všech vzhledů (`set_level`), svítící vrstva při výzkumu a v noci, stín, výběrový
  obdélník sedí na budovu, ikona v panelu a na mapě.
