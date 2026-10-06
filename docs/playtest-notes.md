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

### Co funguje

- Městská tabule je super. Režimy i signály v obvodové síti fungují podle očekávání.

## Odložené drobnosti z review plánu 1b

- [ ] Knihovní plán (blueprint) a `event.stack`/`record` u tagu režimu tabule.
- [ ] Logistická skupina nebo vypnutá sekce u tabule.
- [ ] Zlomky kusů v postupu milníku.
- [ ] Zpoždění obnovy tabule po Shift+klik (vložení nastavení).
- [ ] Remote `set_board_mode` nekontroluje platnost režimu.
- [ ] Rozhodnout verzi: 0.1.0, nebo 0.2.0.
