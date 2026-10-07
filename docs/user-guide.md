# Research Towns – návod

> *Nauvis nikdy nebyl prázdný. V jeho údolích žijí lidé odnepaměti – znají každou řeku, každé roční období a vědí,
> jak s planetou žít. Ty znáš stroje. Dodávej jejich městům suroviny a know-how a vyrostou v centra plná
> výzkumníků. Jejich pokrok je tvým pokrokem a tvůj jejich.*

Laboratoře ve hře nejsou. Zkoumá se v **radnicích** měst. Stručný návod je i ve hře v okně **Tipy a triky**.

## Města a partnerství

- **Města na mapě:** při tvorbě mapy zvolíš četnost a velikost měst (posuvník Města), v náhledu mapy je uvidíš.
  První město je 100–200 dlaždic od místa přistání a je hned tvoje.
- **Partnerství:** k dalším městům dojdi – obyvatelé tě přivítají a požádají o dar (suroviny, které už vyrábíš).
  Dodej ho přes překladiště u jejich radnice a město se stane partnerem.

## Výzkum a růst

1. **Radnice** zkoumá jako laboratoř. Když zkoumá, kouří z komínů – je to vidět i ve dne. Každá úroveň města otevře **jednu novou vědu** (úroveň 1 = první věda;
   vanilla 7 úrovní, Space Age 12, overhauly podle počtu věd).
2. **Domy** (vyrobíš v montážním stroji) postav do dosahu radnice nebo jiného domu – propojí se chodníkem
   (šňůrou, později lávkou; vyšlapaný chodník – trasu sítě – uvidíš při najetí myší na dům nebo radnici).
   Nejvýš 5 domů v sérii od radnice; dům dál je neaktivní (ikona varování). K povýšení
   potřebuje město 4 aktivní domy na úroveň (nejvýš 20).
3. **Městská rozvodna** u radnice nebo domu odebírá elektřinu města; bez ní radnice nezkoumá. Je to skutečná
   rozvodna – připoj ji drátem ke své síti (jako klasickou rozvodnu). Město bere elektřinu jen přes ni; klasická
   rozvodna u radnice nestačí.
4. **Překladiště zboží (sklad 2×2) a kapalin** u radnice nebo aktivního domu dodávají suroviny. Pořadí: nejdřív
   zásoba pro provoz, pak milník radnice (nová věda + suroviny), pak vylepšení domů. Co nikdo nepotřebuje, zůstane.
5. Až je milník splněný a máš dost domů, klikni v panelu radnice na **Povýšit město**. Progress bar v panelu
   ukazuje, kolik zbývá (suroviny, věda i počet domů).
6. **Spotřeba:** suroviny splněných milníků město průběžně spotřebovává, když zkoumá. Když dojdou, radnice stojí.
   Spotřeba je v celých kusech za minutu; radnice si drží zásobu na 5 minut provozu.
7. **Vylepšení domů** je dobrovolné: dodávky navíc vylepšují domy postupně jeden po druhém (stejné suroviny jako
   milník radnice, bez vědy) až do úrovně 5. Dům dává bonus (úroveň + 1) %, všechny domy dohromady nejvýš +120 %.
   Úroveň domu uvidíš jako číslo nad domem v Alt režimu.
8. **Za poslední vědou** město roste dál; každá úroveň přidá produktivitu výzkumu radnice.
9. **Městská tabule** posílá do obvodové sítě požadavky města – režim Radnice, Dům nebo Spotřeba zvolíš v jejím
   okně (Spotřeba = celá zásoba na 5 minut); navíc signály příkonu (MW), pokrytí elektřiny (%), postupu k další
   úrovni (%) a postupu vylepšení domu (%).

## Bonusy pro tvou továrnu

- **Specializace:** každé město se vyzná v jednom základním materiálu, který se odvodí z dat hry (vanilla:
  železné a měděné pláty, ocel, ozubená kola, kabely, trubky, obvody…; overhauly mají vlastní). Sousední města
  mají vždy různé. Partnerské město zvyšuje **produktivitu všech receptů, které ten materiál vyrábějí** (i lití
  ve Space Age) o +1 % za každou úroveň města nad 5 (zapne se od úrovně 6), nejvýš +15 % na město – potřebuješ méně rudy. Další města se stejnou
  specializací přidají jen polovinu, čtvrtinu… svého bonusu, celkem nejvýš +25 % na materiál. Bonus se počítá
  v celých procentech (tak ho drží hra). Specializaci uvidíš v panelu radnice u každého města, i u toho, které
  ještě není partner – vybírej partnery chytře. Bonusy z výzkumů produktivity zůstávají.
- **Čistý vzduch:** zkoumající radnice pohlcuje znečištění (30/min na první vědě až 1000/min na poslední)
  a každý dům úrovně 5 pohlcuje 15/min.

## Nebezpečí

- **Trosky:** když biteři radnici zničí, zůstanou trosky a město přežije – úroveň, postup milníku, domy
  i překladiště zůstanou, ale nezkoumá, neodebírá elektřinu a jeho specializace nedává bonus. Panel trosek ukáže
  cenu obnovy (polovina surovin milníku současné úrovně); dodej ji přes překladiště města a radnice se obnoví ve
  stejné úrovni.

## Nastavení modu

| Nastavení | Kde | Výchozí | Co dělá |
|---|---|---|---|
| Násobič spotřeby surovin | při spuštění (startup) | 1 | Kolik surovin města průběžně spotřebovávají (0 = bez spotřeby). Pro pomalé overhauly jako Pyanodon ho sniž. |
| Násobič pohlcování znečištění | při spuštění (startup) | 1 | Kolik znečištění pohlcují radnice a domy úrovně 5 (0 = vůbec). |
| Síla specializací měst | mapa (za běhu) | 1 | Násobí bonus specializací (od úrovně města 6) i jeho stropy (0,5 = poloviční, 0 = vypnuto). Jde měnit i v rozehrané hře (Nastavení → Mody → Mapa), bonusy se hned přepočítají. |

Četnost a velikost měst nastavíš posuvníkem **Města** v generátoru mapy.

Ladicí příkaz: `/rt-create-town` (admin) založí radnici severně od hráče.
