# Poznatky ze zkoušek ve hře

## 2026-10-06 – první zkouška plánu 1b (master `4514b8c`)

### K úpravě

- [x] **Zaokrouhlit požadavky spotřeby ve hře.** Spotřeba za minutu vychází ve zlomcích kusů,
  např. 0,3 ks/min. Panel radnice i městská tabule je zobrazují tak, jak jsou, a to ve hře nedává smysl.
  Zobrazovat celé kusy, nebo přepočítat interval tak, aby šlo o celé kusy
  (souvisí s `scripts/upkeep.lua`, `scripts/gui.lua` a `scripts/board.lua`).
- [x] **Úroveň domu musí být vidět ve hře.** Hráč nepozná, které domy jsou vylepšené
  a které ne. Grafická varianta (`levels.variant`) se mění jen po pásmech, takže to nestačí.
  Návrh: číslo úrovně nad domem (`rendering.draw_text`) nebo popisek
  či vlastní tooltip domu (`scripts/network.lua`, `M.refresh_house`).
- [x] **Zásoba spotřeby nestačí.** Překladiště zboží nestíhalo doplňovat zásobu na 1 minutu. Zásoba je teď na
  5 minut (`UPKEEP_BUFFER_SECONDS`) a tabule v režimu Spotřeba požaduje celou zásobu.
- [x] **Postup k další úrovni.** Progress bar v panelu radnice (úroveň i vylepšení domu) a signály na tabuli.

Vyřešeno 2026-10-06: spotřeba zaokrouhlená nahoru na celé kusy, číslo úrovně nad domem v Alt režimu.

- [x] **Panel radnice se překrýval.** Progress bary s procenty se nevešly. Suroviny jsou teď sloty jako v inventáři
  (číslo = kolik chybí), postup v % v záhlaví sekce.
- [x] **Ikony signálů postupu.** Složené ikony: radnice/dům + symbol % (dočasné do plánu 3).
- [x] **Vylepšování domů po stropu bonusu nic nepřináší.** Na úrovni 5 dá 20 domů × 6 % = +120 % = strop. Vylepšování
  se teď při plném bonusu zastaví a domy mají strop úrovně 5. Smysl po stropu: domy úrovně 5 budou pohlcovat
  znečištění (plán 2).

### Co funguje

- Městská tabule je super. Režimy i signály v obvodové síti fungují podle očekávání.

## Odložené drobnosti z review plánu 1b

- [x] Knihovní plán (blueprint) a `event.stack`/`record` u tagu režimu tabule. Tagy se zapisují i do záznamu v knihovně (`event.record`).
- [x] Logistická skupina nebo vypnutá sekce u tabule. Tabule sekci odpojí od skupiny a zapne.
- [x] Zlomky kusů v postupu milníku. Předměty se dělí po celých kusech (`scripts/allocation.lua`).
- [x] Zpoždění obnovy tabule po Shift+klik (vložení nastavení). Signály se přepíšou hned.
- [x] Remote `set_board_mode` nekontroluje platnost režimu. Neplatný režim vyhodí chybu, neplatný tag z plánu → Radnice.
- [x] Verze: zůstává 0.1.0 (mod zatím nebyl vydaný).

## 2026-10-07 – vizuál po zkoušce ve hře (nápady na později)

Hotovo: lávky na zemi, vzhled jako ve Factoriu (textury a sprity ze hry, stíny), detaily domů, noční světla,
nová překladiště. Odloženo jako nápady – zatím se nedělá:

- [ ] **Pracovní animace radnice** (radnice zkoumá): animace strojů ze hry v malých výřezech (montážní stroj,
  parní stroj, kotel, radar, laboratoře), kouř z komínů skriptem, pulzující světla laboratoře a kopulí; po
  úrovních viz návrh v konverzaci (osada: výheň a kouř → město vědy: laboratoře, kopule, antény). Radnice je
  laboratoř – `on_animation` může mít víc snímků, statický základ s `repeat_count`.
- [ ] **Vkladače ze hry** u dílen a skladů (skládají se z podstavce a ruky v poloze – nejlépe spolu s animací).
- [ ] **Předměty ze hry po městě** (krok 6 plánu): ikony předmětů, které město spotřebovává nebo překladiště
  právě obsahuje, rozházené kolem radnice, domů a na paletách skladu; kreslí skript, obnova jen při změně.
- [ ] **Dvě kapaliny v překladišti kapalin** (varianta B/C) – zamítnuto kvůli složitosti, jeden vstup zůstává.
