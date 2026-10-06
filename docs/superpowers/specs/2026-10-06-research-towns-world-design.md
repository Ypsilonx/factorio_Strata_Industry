# Research Towns – plán 2a: města na mapě a jejich převzetí

Navazuje na `2026-10-05-research-towns-design.md` (sekce „Generování a objevení měst“, „Generátor měst“).
Schváleno s uživatelem 2026-10-06.

## Cíl

Mod jde hrát bez ladicího příkazu: hráč najde první město u spawnu, rozjede výzkum a průzkumem mapy získává
další města. Úspěch = silný první dojem a jasný začátek příběhu (nové město = malá scéna partnerství).

Mimo rozsah 2a: znečištění (2b), ruiny (2c), specializace (2d), cestování obyvatel mezi městy (po vydání).

## Generátor mapy

- Nový **autoplace-control „Města“** (`rt-towns`, kategorie `enemy`, bez richness) v okně nové mapy. Hráč
  nastavuje jen **četnost**; posuvník velikosti zůstane nevyužitý (nejde skrýt).
- Generátor rozmísťuje **značku místa města** `rt-town-site` (`simple-entity`, půdorys radnice 15×15,
  `map_color` radnice, síla `neutral`). Skript ji při generování chunku nahradí radnicí. Důvod značky:
  `regenerate_entity` v rozehrané hře pak nemůže sáhnout na existující radnice.
- **Mřížka s posunem:** jedna značka na buňku mřížky v okně 14×14 dlaždic (`TOWN_SITE_WINDOW`; menší než radnice, takže nanejvýš jedna – jediná dlaždice byla často pod vodou), posun uvnitř buňky z šumu vzorkovaného podle indexu buňky
  (pro celou buňku konstantní – v pokusu z proměnného posunu vznikaly „housenky“ slitých radnic).
  Okraj buňky bez měst = `TOWN_CELL_MARGIN`, aby sousední města nebyla nalepená.
- **Velikost buňky** = `min(TOWN_CELL_MAX, TOWN_CELL_BASE / sqrt(četnost))`; výchozí `TOWN_CELL_BASE = 250`,
  `TOWN_CELL_MAX = 400`. Strop zaručuje požadavek uživatele: **i při nejnižší četnosti aspoň ~20 měst do
  1 500 dlaždic od spawnu** (π·1500² / 400² ≈ 44 buněk; ověřeno testem `worldgen` na 3 seedech: 25–31 měst). Hardmode s pár městy není.
- Kolem spawnu se značky negenerují (`distance > TOWN_SPAWN_CLEAR`, 120 dlaždic) – první město řeší skript.
- Jen **Nauvis** (`data.raw.planet.nauvis.map_gen_settings`); když planeta chybí, autoplace se nepřidá
  a zůstane jen první město.
- Náhled mapy ukazuje města (ověřeno pokusem 2026-10-06: entita s autoplace a `map_color` je v náhledu vidět).

## Po vygenerování chunku (`on_chunk_generated`, jen Nauvis)

- Značky v chunku se nahradí neutrální radnicí úrovně 1 a zaeviduje se **neobjevené město** (jméno, úroveň 1,
  stav `wild`). Radnice je nezničitelná (`destructible = false`) a vypnutá (`disabled_by_script`).
- Kolem radnice se odstraní stromy, kameny a útesy (`TOWN_CLEAR_MARGIN` = 10 dlaždic) a hnízda biterů
  v poloměru `TOWN_NEST_CLEAR` = 150 dlaždic. Chunky vygenerované později se proti známým městům kontrolují
  také (prostorový index měst po buňkách, ne smyčka přes všechna města).

## První město

- Při startu hry (`on_init`, případně první spuštění nové verze ve hře bez měst) skript najde souš ve
  vzdálenosti 100–200 dlaždic od spawnu (vygeneruje potřebné chunky, `find_non_colliding_position`),
  postaví radnici a město je rovnou **partnerské** (síla `player`) – stejně jako dnešní `/rt-create-town`.
  Kandidát musí být bez vody, útesů a hráčových staveb a aspoň `FIRST_TOWN_GAP` (100 dlaždic) od jiné radnice.

## Stavy města

`wild` (neobjevené) → `discovered` (objevené, chce dar) → `partner` (hráčovo, dnešní chování).

- **Objevení:** jednou za 60 ticků pro každého připojeného hráče na Nauvisu hledání neutrálních radnic
  v okruhu `DISCOVERY_RADIUS` = 40 dlaždic. Objevené město: zpráva s příběhem, značka na mapě se jménem
  (`force.add_chart_tag`), stanoví se **dar** a město se zařadí do plánovače (jen kvůli sběru daru).
- **Dar:** suroviny milníku úrovně `k = max(1, nejvyšší úroveň partnerských měst síly − 1)` bez vědy
  × `GIFT_SHARE` (25 %), zaokrouhleno nahoru. Stanoví se při objevení a dál se nemění.
- **Dodání:** překladiště zboží a kapalin se k objevenému městu připojí jako k partnerskému (nejbližší kotva =
  radnice); domy ne. Panel radnice ukazuje sloty daru s procenty, městská tabule v režimu Radnice zbývající dar.
- **Převzetí:** po dodání celého daru přejde radnice na sílu překladišť města (první podle `unit_number`;
  bez překladiště síla, která město objevila); zapne se
  zničitelnost, radnice se napojí na síť (domy v dosahu se připojí), město začne na úrovni 1 s normálními
  milníky. Zpráva o partnerství.
- Neobjevené i objevené město nezkoumá. Biteři na neutrální sílu neútočí (ověřit cease-fire `enemy`↔`neutral`,
  případně nastavit).

## Příběh

- Nové texty: objevení města, žádost o dar, uzavření partnerství (en + cs, tón partnerství z hlavní specifikace).
- Tipy a triky: nová kategorie „Hledání měst“ (posuvník Města, objevení, dar).
- `docs/user-guide.md`: nový začátek hry (první město u spawnu, ostatní města na mapě).

## Moduly

| Soubor | Role |
|---|---|
| `shared/worldgen.lua` | Čistá logika: velikost buňky podle četnosti, noise výraz mřížky, dar, prostorový index. |
| `prototypes/worldgen.lua` | `autoplace-control`, prototyp `rt-town-site`, zápis do `map_gen_settings` Nauvisu. |
| `scripts/worldgen.lua` | `on_chunk_generated`: náhrada značek, čištění, hnízda; první město; doplnění do rozehrané hry. |
| `scripts/discovery.lua` | Objevení hráčem, zprávy, značky na mapě. |
| `scripts/towns.lua` | Stavy města, evidence neutrální radnice, sběr daru, převzetí. |

## Rozehraná hra

Při prvním spuštění verze s 2a (příznak ve `storage`): `regenerate_entity({"rt-town-site"})` na Nauvisu,
nahrazení všech značek (stejná funkce jako v `on_chunk_generated`), a když žádné partnerské město není,
postaví se první město. Značka koliduje s hráčovými stavbami → tam město nevznikne.

## Klíčová rozhodnutí

| Rozhodnutí | Volba | Důvod |
|---|---|---|
| Kdo umísťuje města | Generátor mapy (autoplace značky) | Města jsou vidět v náhledu mapy. |
| Rozmístění | Mřížka s posunem, strop velikosti buňky | Rovnoměrně, žádné shluky, minimum 20 do 1 500. |
| Nastavení | Jen četnost | Přání uživatele – zbytek náhoda. |
| Úroveň nalezených měst | Vždy 1 | Lineární příběh, žádné přeskakování milníků. |
| Převzetí | První město dojitím, další s darem | Hladký začátek, každé další město má scénu partnerství. |
| Výše daru | 25 % milníku, který hráč už zvládl | Roste s pokrokem, využije existující linky. |
| Značka místo radnice v autoplace | `rt-town-site` → skript | `regenerate_entity` nesmí ohrozit existující radnice. |

## Testování

- **Unit:** velikost buňky (výchozí, strop, maximum četnosti), noise výraz obsahuje konstanty, výpočet daru
  (úroveň, zaokrouhlení, bez vědy), prostorový index (vložení, hledání v okruhu), výběr nejbližšího města.
- **Integrační (vanilla + Space Age):** první město na Nauvisu existuje a je partnerské; značky v okolí spawnu
  jsou nahrazené neutrálními radnicemi; do `TOWN_NEST_CLEAR` od nich nejsou hnízda; objevení přes remote
  `discover` (headless nemá hráče); dar přes překladiště → převzetí, síla, napojení domu; testovací povrch
  `rt-test` města negeneruje.
- **Počet měst:** samostatná varianta `tools/run-tests.sh worldgen` – nejnižší četnost, vygenerovat okruh
  1 500 dlaždic, ověřit ≥ 20 měst na několika seedech.
- **Kompatibilita:** `run-tests.sh mods` (Bob's, Pyanodon) – první město vznikne, autoplace nespadne.
- **Ručně:** posuvník Města a náhled mapy, objevení s hráčem, zprávy, značka na mapě, dar a převzetí ve hře.
