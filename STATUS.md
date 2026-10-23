# Stav projektu

Aktualizováno: 2026-10-23

## Cíl

Vydání 0.2.0 pro Factorio 2.1 (stable): port z 2.0 + přepínač „Vylepšovat domy“ u každého města
(vypnuto = překladiště nedávají suroviny na domy, vše zůstane pro spotřebu a milník).

## Hotovo

- Vydáno 0.1.0 (2026-10-07) a 0.1.1 (2026-10-12) pro Factorio 2.0 – zůstávají pro hráče na 2.0.
- Port na 2.1 (commit a113b0f): `info.json` 2.1, recyklace z `recycler`, `categories`, vědy typu item ve specializacích,
  kapaliny v překladišti, `run-tests.sh` (recycler, prefix `+`). Testy 2.1.23: unit 84/84, vanilla 67/67,
  Space Age 67/67, Bob's 3.0 compat 7/7, `pymodpack` 3.1 compat 7/7.
- Přepínač „Vylepšovat domy“ (necommitnuto): `town.house_upgrades_off`, zaškrtávátko v panelu radnice, remote
  `house_upgrades`/`set_house_upgrades`, locale, tip, user-guide, integrační test. Unit 84/84, vanilla 68/68, SA 68/68.
- Elektřina města (necommitnuto): stav radnice `custom_status` (chybí rozvodna / elektřina / suroviny, ruina),
  ukazatel „Elektřina X / Y MW“ s progress barem v panelu, spotřebič `rt-power-load` viditelný v okně sítě
  („Město (výzkum)“). Vanilla 69/69, SA 69/69.

## Rozpracováno

- Vydání 0.2.0: verze, changelog, `mod-portal.md`, README, tip a příručka hotové; ruční kontrola ve hře OK
  (uživatel 2026-10-23); testy před vydáním unit 84/84, vanilla 69/69, SA 69/69, Bob's 7/7, Py 7/7. Čeká na
  commit a `tools/publish.sh --details` (popis portálu se změnil).

## Další krok

1. Krastorio 2 (`run-tests.sh mods Krastorio2`) – až bude verze pro 2.1.

## Otevřené otázky / slepé uličky

- Název složky repa / GitHubu `factorio_Strata_Industry` neodpovídá modu `research-towns` – přejmenování na `factorio_research-towns` odloženo (postup: paměť `~/.claude/projects/…`, junction `link-mod.sh`, GitHub + `remote set-url`, `SOURCE_URL` v `tools/publish.sh`, `docs/mod-portal.md`, cesty ve skillu `factorio-mod`, smazat `.test-run`).
- ❌ Dvě kapaliny v překladišti kapalin – zamítnuto kvůli složitosti, zůstává jeden vstup.
