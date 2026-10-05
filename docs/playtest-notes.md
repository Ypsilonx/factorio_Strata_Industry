# Poznatky ze zkoušek ve hře

## 2026-10-06 – první zkouška plánu 1b (master `4514b8c`)

### K úpravě

- [ ] **Zaokrouhlit požadavky spotřeby ve hře.** Spotřeba za minutu vychází ve zlomcích kusů,
  např. 0,3 ks/min. Panel radnice i městská tabule je zobrazují tak, jak jsou, a to ve hře nedává smysl.
  Zobrazovat celé kusy, nebo přepočítat interval tak, aby šlo o celé kusy
  (souvisí s `scripts/upkeep.lua`, `scripts/gui.lua` a `scripts/board.lua`).
- [ ] **Úroveň domu musí být vidět ve hře.** Hráč nepozná, které domy jsou vylepšené
  a které ne. Grafická varianta (`levels.variant`) se mění jen po pásmech, takže to nestačí.
  Návrh: číslo úrovně nad domem (`rendering.draw_text`) nebo popisek
  či vlastní tooltip domu (`scripts/network.lua`, `M.refresh_house`).

### Co funguje

- Městská tabule je super. Režimy i signály v obvodové síti fungují podle očekávání.

## Odložené drobnosti z review plánu 1b

- [ ] Knihovní plán (blueprint) a `event.stack`/`record` u tagu režimu tabule.
- [ ] Logistická skupina nebo vypnutá sekce u tabule.
- [ ] Zlomky kusů v postupu milníku.
- [ ] Zpoždění obnovy tabule po Shift+klik (vložení nastavení).
- [ ] Remote `set_board_mode` nekontroluje platnost režimu.
- [ ] Rozhodnout verzi: 0.1.0, nebo 0.2.0.
