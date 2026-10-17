# Stav projektu

Aktualizováno: 2026-10-17

## Cíl

Udržovat vydaný mod (0.1.x) a sbírat zpětnou vazbu hráčů; další funkce viz `ROADMAP.md`.

## Hotovo

- Vydáno 0.1.0 (2026-10-07) a 0.1.1 (2026-10-12, laboratoř v cizích receptech → suroviny jejího receptu).
- Města na mapě, partnerství, úrovně podle věd, domy, překladiště, tabule, spotřeba, specializace, znečištění, ruiny.
- Grafika z Blenderu: 5 vzhledů radnice, domy, ruiny, překladiště, noční světla, kouř, spojení budov.
- Testy 2026-10-17 (Factorio 2.0.77): unit 84/84, vanilla 67/67. Compat Bob's a `pymodpack` naposledy 2026-10-07.

## Rozpracováno

- Nic.

## Další krok

1. Ověřit kompatibilitu s Krastorio 2 (`Krastorio2`) – stáhnout, `run-tests.sh mods Krastorio2`, výsledek do `docs/development.md` a `mod-portal.md`.

## Otevřené otázky / slepé uličky

- Název složky repa / GitHubu `factorio_Strata_Industry` neodpovídá modu `research-towns` – přejmenování na `factorio_research-towns` odloženo (postup: paměť `~/.claude/projects/…`, junction `link-mod.sh`, GitHub + `remote set-url`, `SOURCE_URL` v `tools/publish.sh`, `docs/mod-portal.md`, cesty ve skillu `factorio-mod`, smazat `.test-run`).
- ❌ Dvě kapaliny v překladišti kapalin – zamítnuto kvůli složitosti, zůstává jeden vstup.
