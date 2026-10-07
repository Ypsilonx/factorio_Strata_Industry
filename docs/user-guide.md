# Research Towns – návod

> *Nauvis nikdy nebyl prázdný. V jeho údolích žijí lidé odnepaměti – znají každou řeku, každé roční období a vědí,
> jak s planetou žít. Ty znáš stroje. Dodávej jejich městům suroviny a know-how a vyrostou v centra plná
> výzkumníků. Jejich pokrok je tvým pokrokem a tvůj jejich.*

Laboratoře ve hře nejsou. Zkoumá se v **radnicích** měst. Stručný návod je i ve hře v okně **Tipy a triky**.

0. **Města na mapě:** při tvorbě mapy zvolíš četnost měst (posuvník Města) a v náhledu mapy je uvidíš.
   První město je 100–200 dlaždic od místa přistání a je hned tvoje. K dalším městům dojdi – obyvatelé tě
   přivítají a požádají o dar (suroviny, které už vyrábíš). Dodej ho přes překladiště u jejich radnice
   a město se stane partnerem.
1. **Radnice** zkoumá jako laboratoř. Každá úroveň města otevře **jednu novou vědu** (úroveň 1 = první věda).
2. **Domy** (vyrobíš v montážním stroji) postav do dosahu radnice nebo jiného domu – propojí se
   chodníkem (šňůrou, později lávkou). Nejvýš 5 domů v sérii od radnice; dům dál je neaktivní (ikona varování). K povýšení potřebuje město
   4 aktivní domy na úroveň (nejvýš 20).
3. **Městská rozvodna** u radnice nebo domu odebírá elektřinu města; bez ní radnice nezkoumá.
4. **Překladiště zboží a kapalin** u radnice nebo aktivního domu dodávají suroviny. Pořadí: nejdřív zásoba pro
   provoz, pak milník radnice (nová věda + suroviny), pak vylepšení domů. Co nikdo nepotřebuje, zůstane.
5. Až je milník splněný a máš dost domů, klikni v panelu radnice na **Povýšit město**. Progress bar v panelu
   ukazuje, kolik zbývá (suroviny, věda i počet domů).
6. **Spotřeba:** suroviny splněných milníků město průběžně spotřebovává, když zkoumá. Když dojdou, radnice stojí.
   Spotřeba je v celých kusech za minutu; radnice si drží zásobu na 5 minut provozu.
   Množství nastavíš v nastavení modu (Násobič spotřeby surovin).
7. **Vylepšení domů** je dobrovolné: dodávky navíc vylepšují domy postupně jeden po druhém (stejné suroviny jako
   milník radnice, bez vědy) až do úrovně 5. Dům dává bonus (úroveň + 1) %, všechny domy dohromady nejvýš +120 %.
   Úroveň domu uvidíš jako číslo nad domem v Alt režimu.
   **Znečištění:** radnice při výzkumu pohlcuje znečištění (víc s vyšší vědou) a domy úrovně 5 ho pohlcují
   trvale. Množství nastavíš v nastavení modu (Násobič pohlcování znečištění).
8. **Za poslední vědou** město roste dál; každá úroveň přidá produktivitu výzkumu radnice.
   **Trosky:** když biteři radnici zničí, zůstanou trosky a město přežije (úroveň, postup, domy i překladiště).
   Panel trosek ukáže cenu obnovy (polovina surovin milníku současné úrovně); dodej ji přes překladiště města
   a radnice se obnoví ve stejné úrovni. Během obnovy město nezkoumá a neodebírá elektřinu.
9. **Městská tabule** posílá do obvodové sítě požadavky města – režim Radnice, Dům nebo Spotřeba zvolíš v jejím
   okně (Spotřeba = celá zásoba na 5 minut); navíc signály příkonu (MW), pokrytí elektřiny (%), postupu k další
   úrovni (%) a postupu vylepšení domu (%).

Ladicí příkaz: `/rt-create-town` (admin) založí radnici severně od hráče.
