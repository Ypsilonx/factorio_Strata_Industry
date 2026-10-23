# Stav projektu

Aktualizováno: 2026-10-23

## Cíl

Udržovat vydaný mod (0.2.x pro Factorio 2.1, 0.1.x zůstává pro 2.0) a sbírat zpětnou vazbu hráčů; další funkce
viz `ROADMAP.md`.

## Hotovo

- Vydáno 0.1.0 (2026-10-07) a 0.1.1 (2026-10-12) pro Factorio 2.0.
- Vydáno 0.2.0 (2026-10-23, tag `v0.2.0`) pro Factorio 2.1: port (recycler, `categories`, vědy typu item, fluid API),
  přepínač „Vylepšovat domy“, stav radnice (`custom_status`), ukazatel příkonu v panelu, spotřeba města v okně sítě.
  Testy 2.1.23: unit 84/84, vanilla 69/69, Space Age 69/69, Bob's 3.0 compat 7/7, `pymodpack` 3.1 compat 7/7,
  worldgen 1/1; ruční kontrola ve hře OK.

## Rozpracováno

- Nic.

## Další krok

1. Krastorio 2 (`run-tests.sh mods Krastorio2`) – až bude verze pro 2.1.

## Otevřené otázky / slepé uličky

- Spotřebič města `rt-power-load` už není `hidden` (kvůli oknu elektrické sítě) – pokud by se nevhodně ukazoval
  v nabídkách entit (filtry plánovačů), řešit jinak.
- Název složky repa / GitHubu `factorio_Strata_Industry` neodpovídá modu `research-towns` – přejmenování na `factorio_research-towns` odloženo (postup: paměť `~/.claude/projects/…`, junction `link-mod.sh`, GitHub + `remote set-url`, `SOURCE_URL` v `tools/publish.sh`, `docs/mod-portal.md`, cesty ve skillu `factorio-mod`, smazat `.test-run`).
- ❌ Dvě kapaliny v překladišti kapalin – zamítnuto kvůli složitosti, zůstává jeden vstup.
