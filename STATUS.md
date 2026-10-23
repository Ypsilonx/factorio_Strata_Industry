# Stav projektu

Aktualizováno: 2026-10-23

## Cíl

Vydání 0.2.0 pro Factorio 2.1 (stable): port z 2.0 + přepínač „Vylepšovat domy“ u každého města
(vypnuto = překladiště nedávají suroviny na domy, vše zůstane pro spotřebu a milník).

## Hotovo

- Vydáno 0.1.0 (2026-10-07) a 0.1.1 (2026-10-12) pro Factorio 2.0 – zůstávají pro hráče na 2.0.
- Port na 2.1 (necommitnuto): `info.json` 2.1, recyklace z `recycler`, `categories`, vědy typu item ve specializacích,
  kapaliny v překladišti, `run-tests.sh` (recycler, prefix `+`). Testy 2.1.23: unit 84/84, vanilla 67/67,
  Space Age 67/67, Bob's 3.0 compat 7/7, `pymodpack` 3.1 compat 7/7.

## Rozpracováno

- Ruční kontrola portu ve hře (uživatel) – hlavně načtení savu z 0.1.1/2.0.

## Další krok

1. Přepínač „Vylepšovat domy“: stav ve městě (výchozí zapnuto), `house_target` vrací nic, zaškrtávátko v okně radnice,
   remote getter/setter, locale en+cs, tip, `user-guide`, integrační test.
2. Vydání 0.2.0: changelog, `mod-portal.md` (2.1), worldgen test, balíček.
3. Krastorio 2 (`run-tests.sh mods Krastorio2`) – až bude verze pro 2.1.

## Otevřené otázky / slepé uličky

- Název složky repa / GitHubu `factorio_Strata_Industry` neodpovídá modu `research-towns` – přejmenování na `factorio_research-towns` odloženo (postup: paměť `~/.claude/projects/…`, junction `link-mod.sh`, GitHub + `remote set-url`, `SOURCE_URL` v `tools/publish.sh`, `docs/mod-portal.md`, cesty ve skillu `factorio-mod`, smazat `.test-run`).
- ❌ Dvě kapaliny v překladišti kapalin – zamítnuto kvůli složitosti, zůstává jeden vstup.
