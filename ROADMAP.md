# Roadmap

## Vize

Města Nauvisu jako jediné místo výzkumu, kompatibilní s overhauly; vizuálně živá města, na kterých je vidět práce.

## Milníky

### M1 – Vydání 0.1 ✅
- Cíl: hratelný mod na portálu (města, úrovně, domy, překladiště, specializace, ruiny, grafika).
- Hotovo když: vydáno 0.1.0 / 0.1.1, testy vanilla, Space Age, Bob's a Py zelené.

### M2 – Kompatibilita Krastorio 2 ⏳
- Hotovo když: `run-tests.sh mods Krastorio2` zelené a zapsané v `docs/development.md` a `mod-portal.md`.

### M3 – Živější město (nápady z playtestu 2026-10-07) ⏳
- Pracovní animace radnice při výzkumu: animace strojů ze hry ve výřezech (montážní stroj, parní stroj, kotel,
  radar, laboratoře), pulzující světla; po érách osada (výheň) → město vědy (laboratoře, kopule, antény).
  Radnice je laboratoř – `on_animation` může mít víc snímků, statický základ s `repeat_count`.
- Vkladače ze hry u dílen a skladů (podstavec + ruka v poloze, nejlépe spolu s animací).
- Předměty ze hry po městě: ikony toho, co město spotřebovává / překladiště obsahuje, kreslí skript, obnova jen při změně.

## Mimo rozsah (vědomě neděláme)

- Dvě kapaliny v překladišti kapalin – složitost neodpovídá přínosu.
