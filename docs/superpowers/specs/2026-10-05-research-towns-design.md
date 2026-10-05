# Research Towns – návrh (v0.1)

- Titul: **Research Towns**, interní jméno `research-towns` (ověřeno volné na portálu 2026-10-05), prefix `rt`.
- Cílová hra: Factorio 2.0 base game i Space Age. **Kompatibilita s overhauly je požadavek**: vše, co závisí na
  obsahu hry (vědy, suroviny, laboratoře), se odvozuje z `data.raw` v `data-final-fixes.lua`, nic natvrdo podle
  jmen. Ověřuje se s Bob's a Pyanodonem (stažené u uživatele), Krastorio 2 až po stažení.

## Cíl

Na Nauvisu jsou roztroušená města (obyvatelé nejsou vidět). **Výzkum neprobíhá v laboratořích, ale v radnicích
měst.** Města generuje generátor mapy, hráč je musí najít a převzít. Pak jim vozí vědecké balíčky, staví domy
a přes překladiště dodává suroviny, kapaliny a elektřinu – tím město povyšuje. Vyšší úroveň = přijímá vyšší
vědy a domy dávají větší bonus k rychlosti výzkumu. Rychlejší radnice potřebuje víc přívodů balíčků → hráč
plánuje a přestavuje okolí.

## Stavby

| Stavba | Typ prototypu | Kdo ji staví | Role |
|---|---|---|---|
| **Radnice** | `lab` | generátor mapy | Jediné místo výzkumu. Jméno, úroveň 1–5, pevně 15×15, úroveň mění vzhled. Nejde vytěžit. |
| **Ruina radnice** | `container` | skript | Vznikne po zničení radnice; po dodání materiálu se radnice obnoví. |
| **Dům** | `simple-entity-with-owner` | hráč | Jeden předmět „dům“, obyčejný recept v montážním stroji. Úroveň a vzhled přebírá od města. Bonus k rychlosti výzkumu. |
| **Překladiště zboží** | `container` | hráč | Dodávka pevných surovin pro milníky. |
| **Překladiště kapalin** | `storage-tank` | hráč | Dodávka kapalin a plynů pro milníky. |
| **Městská rozvodna** | `electric-energy-interface` | hráč | Odběr elektřiny města (trvalá spotřeba dle úrovně). |

Odstraní se **všechny laboratoře** (vanilla i z jiných modů, např. biolab, laboratoře Bob's/Krastoria): skrytý
recept, odebrané z výzkumu. Výzkumy se spouštěčem „vyrob/postav laboratoř“ (vanilla `automation-science-pack`!)
se přesměrují na vyrobení domu, jinak by hra uvízla. Laboratoře v existujícím savu dál fungují.

## Generování a objevení měst

- Města vznikají při generování chunků na Nauvisu (`on_chunk_generated`), deterministicky ze seedu mapy.
  Parametry jako startup nastavení: hustota (průměrná vzdálenost mezi městy) a minimální rozestup.
- **Garantované první město** ve vzdálenosti cca 100–200 dlaždic od spawnu (jinak by nešlo začít zkoumat).
- Místo pro město musí být souše bez útesů; stromy a kameny v půdorysu radnice a okolním pásu se odstraní.
  Hnízda biterů v poloměru kolem města se při generování odstraní.
- Nalezené město je **neutrální** (biteři na něj neútočí, nic nedělá). Hráč ho **převezme** tak, že k radnici
  dojde (postava v dosahu N dlaždic) – město přejde na sílu hráče, dostane jméno a úroveň 1.
  Od té chvíle je cílem biterů.
- Přidání modu do existujícího savu: generátor projde už vygenerované chunky stejně, garantované město se
  umístí do volného místa nejblíž spawnu.

## Síť města

- Síť tvoří **jen radnice a domy**. Dům se připojí k radnici nebo k jinému domu v dosahu (konstanta jako
  u sloupů); spojení se vykreslí jako **visutý chodník** (`rendering`, bez kolize).
- Dům smí být od radnice nejvýš **5 domů v sérii** (nejkratší cesta v grafu ≤ 5). Dál je neaktivní.
- **Překladiště nejsou součástí sítě**, jen dodávají: připojí se k nejbližší budově města (radnice/dům)
  ve svém dosahu, síť nerozšiřují. V dosahu dvou měst → bližší.
- Síť je vlastní graf ve skriptu, nekříží se s elektrickou sítí.
- Po odebrání nebo zničení domu se graf přepočítá od radnice; odpojené domy a překladiště jsou neaktivní
  (ikona „odpojeno“) a po obnovení spojení se připojí samy.

## Úrovně

**Rozdělení věd do úrovní se počítá automaticky** z výzkumného stromu: každá věda dostane „hloubku“ (nejmělčí
výzkum, který ji používá), nejranější věda(y) patří úrovni 1, ostatní se podle pořadí rovnoměrně rozdělí do úrovní
2–5. Funguje tak s libovolným počtem věd (Pyanodon ~10, Space Age +5). Radnice přijímá všechny vědy své
a nižších úrovní. Příklad pro vanillu:

| Úroveň | Radnice přijímá (vanilla) | Max. domů s bonusem |
|---|---|---|
| 1 | automation | 4 |
| 2 | + logistic, military | 8 |
| 3 | + chemical | 12 |
| 4 | + production, utility | 16 |
| 5 | + space | 20 |

(Počty domů = úroveň × 4, konstanta k ladění.) Domy navíc nad limit jsou připojené, ale nedávají bonus.

**Povýšení na úroveň K+1** – hráč klikne v GUI „Povýšit“, jakmile je splněno:
1. **Milník surovin:** do překladišť města dodáno požadované množství pevných surovin a kapalin pro danou
   úroveň (jednorázově; skript je jednou za několik sekund vybere z překladišť a připíše k postupu, nad
   potřebu nic neodebírá).
2. **Domy:** připojeno aspoň tolik aktivních domů, kolik je limit současné úrovně.

Povýšení vymění radnici za prototyp vyšší úrovně (stejný rozměr; přenese balíčky, jméno a stav) a všechny
domy města za prototyp vyšší úrovně (jiný vzhled, větší bonus).

Suroviny a množství jsou v jedné tabulce konstant. Každá surovina je **seznam kandidátů** (např.
`{ "stone-brick", "concrete" }`); v `data-final-fixes` vyhraje první, který existuje a **je dostupný nejpozději
vědami současné úrovně** (recept od začátku nebo výzkum, jehož vědy i vědy prerekvizit spadají do úrovně ≤ K;
skryté recepty a vyprazdňování barelů se nepočítají). Když žádný kandidát nevyhoví, požadavek se vynechá a
zaloguje. Výsledek jde do runtime přes prototyp `mod-data`.

## Elektřina

- Město má **trvalou spotřebu elektřiny** podle úrovně, výrazně rostoucí (např. 1 MW → 4 → 15 → 50 → 150 MW,
  konstanty k ladění). Odebírá ji přes městské rozvodny (lze jich mít víc, spotřeba se mezi ně rozdělí).
- Radnice sama elektřinu nepotřebuje (`energy_source = void`); **zkoumá jen, když je spotřeba města pokrytá**
  za poslední interval. Jinak je vypnutá (`disabled_by_script`) a GUI ukáže „nedostatek elektřiny“.

## Výzkum a bonusy

- Rychlost = základ radnice dle úrovně + bonus za aktivní domy do limitu (bonus domu roste s úrovní města),
  řešeno skrytým beaconem u radnice.
- Vědecké balíčky jdou do radnice **přímo** (insertery). Rychlejší radnice spotřebuje víc balíčků → hlavní
  prostorová hádanka modu.

## Ruina

- Radnici nejde vytěžit. Po zničení (biteři) vznikne na stejném místě **ruina**; město si drží jméno, úroveň
  i postup milníku, ale nezkoumá a domy jsou neaktivní.
- Ruina je bedna: hráč do ní dodá materiál na obnovu (cena roste s úrovní) a radnice se obnoví ve stejné úrovni.
- Zničené domy a překladiště se obnovují běžně (duchové, roboti).

## GUI radnice

Relativní GUI ukotvené k oknu laboratoře, jen pro radnice: jméno (přejmenovatelné, popisek na mapě), úroveň,
rychlost výzkumu a bonus z domů (aktivní / limit), stav elektřiny, checklist milníku (suroviny s postupem,
domy) a tlačítko „Povýšit“. Ruina má obdobné GUI s cenou obnovy.

## Runtime a výkon

- Stav jen ve `storage`: `cities[id] = {name, hall, level, state, progress, houses, depots}`,
  `nodes[unit_number] = {city, entity, neighbors, depth}`.
- Výběr z překladišť, kontrola elektřiny a přepočet bonusu plánovačem jednou za několik sekund na město.
- Pokryté všechny cesty stavby/odstranění (hráč, robot, `script_raised_*`, `on_entity_died`).
- Remote interface s gettery stavu města (pro testy a jiné mody).

## Mimo rozsah v0.1

- Vlastní planeta rasy, města na jiných površích.
- Průběžná spotřeba surovin, spokojenost a úpadek města (kromě elektřiny).
- Nové předměty (jídlo, oblečení) – jen existující předměty hry.
- Speciální mechaniky Space Age (biolab, výzkum na jiných planetách) – vědy SA se jen zařadí do úrovní.
- Finální grafika – v0.1 tónované vanilla sprity.
- Zakládání nových měst hráčem.

## Klíčová rozhodnutí

| Rozhodnutí | Volba | Důvod |
|---|---|---|
| Kde se zkoumá | Jen radnice (`lab`) | Výzkum počítá hra nativně, vědy zůstávají jak jsou. |
| Odkud jsou města | Generátor mapy, hráč objeví a převezme | Průzkum mapy je součást hry. |
| Úroveň odemyká vědy | Ano | Bez toho by stačilo jedno malé město na všechno. |
| Síť města | Radnice + domy, max. 5 domů v sérii | Město drží tvar, nejde ho natáhnout přes mapu. |
| Zásobování | Překladiště mimo síť, jednorázové milníky | Jednoduché, víc překladišť = víc přívodů. |
| Elektřina | Trvalá spotřeba dle úrovně | Vysoká úroveň má stálou cenu v energetice. |
| Domy | Jeden typ, úroveň dle města, limit bonusu | Bez nekonečného zrychlování; jednoduchá výroba. |
| Ztráta radnice | Ruina s obnovou, nejde vytěžit | Útok biterů bolí, ale nemaže hodiny hraní. |
| Rozměr radnice a domů | Pevný, úroveň mění jen vzhled | Výměna prototypu se vždy podaří. |
| Kompatibilita | Vědy, suroviny a laboratoře odvozené z `data.raw` | Pyanodon, Bob's, Krastorio bez ruční údržby. |

## Testování

- Unit (Lua 5.3): graf sítě (připojení, hloubka ≤ 5, rozpad, nejbližší město), přiřazení překladišť,
  postup a podmínky povýšení, limit domů, rozmístění měst (determinismus, rozestupy), locale en/cs.
- Integrační headless (vanilla + Space Age): převzetí města, stavba/odstranění domů a překladišť, výběr
  surovin, elektřina zapíná/vypíná výzkum, povýšení s výměnou radnice a domů, radnice zkoumá jen vědy své
  úrovně, zničení → ruina → obnova.
- Kompatibilita (`tools/run-tests.sh mods …`): Bob's, Pyanodon – radnice vzniknou, každá věda je v některé
  úrovni, žádný výzkum nevyžaduje laboratoř, všechny požadavky milníků existují.
- Výkon: N měst s plnými sítěmi, ms/tick proti prázdné mapě.

## Rozšíření (schváleno 2026-10-05, po dokončení plánu 1)

Mění sekci „Úrovně“; implementace v plánu 1b (úrovně) a v plánu 2 (svět).

### Úroveň = jeden vědecký balíček (plán 1b)
- **Počet úrovní = počet věd ve hře** (vanilla 7, Pyanodon 11, Space Age 12, Bob's 18). Pořadí věd podle hloubky
  ve stromu výzkumů (stávající `science.lua`); úroveň k přijímá prvních k věd. Nahrazuje pevných 5 úrovní a pásma.
- **Milník k → k+1 = N kusů nové vědy + suroviny.** Úroveň se tak odemkne zhruba ve chvíli, kdy hráč novou vědu
  umí vyrábět – tempo měst se srovná s tempem výzkumu i v pomalých overhaulech.
- Suroviny milníků: dosavadních 5 „pásem“ kandidátů se roztáhne na libovolný počet úrovní, množství roste
  plynule vzorcem s úrovní (konstanty v `shared/levels.lua`).
- **Po poslední vědě nekonečné úrovně:** každá přidá produktivitu výzkumu radnice (bonusové moduly ve skrytém
  beaconu, klesající křivka kvůli stropu produktivity), cena roste vzorcem (suroviny posledního pásma + elektřina).
  Vzhled zůstává na nejvyšší grafické variantě, úroveň ukazuje popisek a panel.
- **Domy** zůstávají podmínkou růstu i bonusem k rychlosti; limit domů s bonusem roste do stropu 20.
- Rychlost radnice podle úrovně: vzorec místo tabulky; v Pyanodonu doladit po zkušebním hraní (víc měst =
  paralelní výzkum).

### Specializace měst (plán 2)
- Každé vygenerované město dostane specializaci (např. kovy, elektronika, chemie, stavebniny) určenou ze skupin
  receptů ve hře (ne natvrdo podle jmen – kompatibilita s overhauly).
- Bonus: produktivita receptů dané skupiny pro celou sílu (`LuaRecipe.productivity_bonus`), roste s úrovní města.
  Víc měst stejné specializace se nesčítá naplno (klesající přínos), respektuje strop produktivity.
- Milníky specializovaného města preferují suroviny jeho skupiny.

### Pohlcování znečištění (plán 2)
- Radnice při výzkumu pohlcuje znečištění (záporné emise prototypu – ověřit), domy pohlcují skriptem při
  zpracování města (`surface.pollute` se zápornou hodnotou – ověřit). Množství podle úrovně, konstanty k ladění.

### Generátor měst (plán 2)
- Vlastní `autoplace-control` „Města“ v okně nové mapy (četnost, velikost – jako biteři); generátor z něj čte hustotu
  a rozestupy. Měst má být na mapě hodně.

### Balanc domů po prvním hraní (2026-10-05)
- **Hotovo:** bonus za dům = (úroveň + 1) % (dřív 10–30 %), krok bonusu 1 %; překladiště a dům ukazují dosah
  (`radius_visualisation_specification`).
- **Plán 1b – vylepšování domů (potvrzeno 2026-10-05):**
  - Domy s městem nepovyšují automaticky. Vylepšení domu na úroveň k stojí **stejné suroviny jako milník
    radnice k−1 → k, bez vědeckých balíčků**.
  - Vylepšení je **dobrovolné**: podmínkou povýšení města je jen **počet** připojených domů, ne jejich úroveň.
    Nevylepšený dům funguje dál, jen dává bonus podle **své** úrovně.
  - Domy se vylepšují postupně jeden po druhém, od radnice podle hloubky v síti. Jednotlivé domy se nezásobují –
    suroviny jdou do překladišť města.
  - **Pořadí rozdělení surovin z překladišť:** 1) aktuální milník radnice, 2) vylepšení domů, 3) co nikdo
    nepotřebuje, zůstane v překladišti. (Před milník se řadí průběžná spotřeba – viz níže.) Přepínač „pro radnici / pro domy“ v GUI překladiště jen případně později.

### Obvodová síť (plán 1b)
- Kontejner ve Factoriu do sítě vždy posílá svůj obsah, vlastní signály neumí – proto nová budova
  **Městská tabule** (`constant-combinator`) v dosahu města, kterou skript plní:
  - režim **Radnice**: zbývající množství milníku radnice (signály předmětů/kapalin),
  - režim **Dům**: požadavek na vylepšení **jednoho** domu + virtuální signál „počet domů k vylepšení“
    (hráč si násobí aritmetickým kombinátorem).
  - Režim se volí v GUI tabule; víc tabulí = víc režimů naráz. Pořadí „nejdřív radnice, pak domy“ odpovídá
    pořadí rozdělení surovin v překladištích.
  - Kapaliny jdou jako signály kapalin. Elektřina: virtuální signály „potřebný příkon (MW)“ a „pokrytí elektřiny
    (%)“ – trvalá spotřeba se nedodává do překladiště, takže tabule ukazuje jen stav.
- Varianta s logistickou požadavkovou bednou zamítnuta (neřeší kapaliny ani elektřinu).

### Domy v nekonečných úrovních (plán 1b)
- Úroveň domu sleduje úrovně města (počet úrovní = počet věd), ne pevných 5.
- Bonus domů k **rychlosti** roste do poslední vědecké úrovně a je zastropovaný na **+120 %** celkem.
- V nekonečných úrovních dává **produktivitu výzkumu jen radnice** za svůj milník (jeden zdroj, klesající křivka
  kvůli stropu produktivity). Domy se vylepšují dobrovolně stejně jako dřív a přidávají jen rychlost do stropu
  +120 %; samy produktivitu nepřidávají.
- Grafické varianty domu (cca 5) se rozloží rovnoměrně na všechny úrovně; nad poslední vědou zůstává poslední.

### Průběžná spotřeba surovin (plán 1b, potvrzeno 2026-10-05)
- Město kromě elektřiny trvale spotřebovává **suroviny všech dosud splněných milníků** (kumulativně, bez
  vědeckých balíčků). Hráč tak linky postavené na milníky využije i dál. Úroveň 1 (bez milníku) spotřebovává
  jen elektřinu. Desítky druhů surovin jsou záměr – město je velké a překladišť se vejde dost.
- **Množství:** za minutu podíl z množství příslušného milníku × koeficient; každý aktivní dům přidá menší díl.
  V nekonečných úrovních se nepřidávají nové druhy, jen roste množství. Konstanty v `shared/levels.lua`,
  globální **koeficient spotřeby jako startup nastavení** (ladění pro Pyanodon a jiné overhauly).
- Spotřebovává se **jen když radnice zkoumá**. Radnice drží malou zásobu (~1 min provozu); když dojde kterákoli
  surovina, radnice se zastaví jako bez elektřiny (při částečném zásobování běží poměrnou část času).
  Zpracování v rámci `process` (interval `TOWN_INTERVAL`), žádná práce navíc za tick.
- **Pořadí rozdělení surovin z překladišť (mění sekci „Balanc domů“):** 1) spotřeba (doplnění zásoby),
  2) milník radnice, 3) vylepšení domů, 4) zbytek zůstává v překladišti.
- **GUI a tabule:** panel ukáže spotřebu za minutu a stav zásoby; tabule má režim **Spotřeba** (požadavek za
  minutu, signály předmětů/kapalin).

### Příběh (hotovo 2026-10-05)
- **Legenda:** Nauvis nikdy nebyl prázdný; jeho obyvatelé znají planetu, hráč zná stroje. Dodávky a know-how
  rozjedou technologický rozvoj měst – pokrok pomáhá oběma stranám.
- **Tón: partnerství rovného s rovným.** Obyvatelé mají vlastní znalosti (planeta, místní postupy) a vracejí je
  hráči. Žádné „primitivní/divoši“, žádné „přinášíme civilizaci“, nepoužívat „tribes“ (v EN „the people of
  Nauvis“, „townsfolk“, „local scholars“). Platí i pro budoucí texty (ruiny, specializace, převzetí měst).
- **Kde je:** popis modu (`info.json`, locale `mod-description`), popisky entit a předmětů, zpráva při založení
  města, zprávy při povýšení (`shared/story.lua`, klíče `rt.town-upgraded-N`, poslední se opakuje v dalších
  úrovních), kategorie v **Tipech a tricích** (`prototypes/tips.lua`), úvod `docs/user-guide.md`.
- Doplnit později: věty k ruinám a obnově (plán 2), specializacím (plán 2), popis pro portál (plán 3).

## Další kroky (stav 2026-10-05)
1. ~~**Plán 1b – úrovně**~~ – hotovo 2026-10-05, plán `docs/superpowers/plans/2026-10-05-research-towns-levels.md`: úroveň = věda (milník = nová věda + suroviny), nekonečné úrovně s produktivitou radnice,
   dobrovolné vylepšování domů (pořadí radnice → domy), strop rychlosti +120 %, průběžná spotřeba surovin
   milníků, městská tabule pro obvodovou síť.
2. **Plán 2 – svět:** posuvníky „Města“ v generátoru mapy, generování a převzetí měst, ruiny, specializace měst,
   pohlcování znečištění.
3. **Plán 3 – grafika a vydání:** modely z Blenderu (radnice, domy, překladiště, chodník, tabule), portál.
