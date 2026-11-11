# wow_moneytalks

MoneyTalks ist ein Addon für WoW Forever. Es zeigt neben dem Berufsfenster für alle
gelernten Rezepte die Materialkosten, den AH-Wert des Endprodukts und den Gewinn,
sortiert nach Gewinn.

## Installation

1. Auctionator muss installiert sein (liefert die Preise).
2. Den Ordner `MoneyTalks` nach `World of Warcraft/_forever_/Interface/AddOns/` kopieren.
   Der Ordnername unter `World of Warcraft` kann abweichen; es ist der, in dem auch
   `Auctionator` liegt.
3. Das Spiel komplett neu starten (ein `/reload` erkennt neue Addons nicht), dann ein
   Berufsfenster öffnen. `/moneytalks` (kurz `/mtalk`) blendet die Liste ein und aus.

## Wie es funktioniert

- **Preise** kommen aus Auctionators Datenbank (`Auctionator.API.v1`). Auctionator füllt
  sie bei jedem Scan und jeder Suche im Auktionshaus. MoneyTalks scannt nichts selbst.
- **Händlerpreise** kennt Auctionator erst, nachdem du den Händler einmal besucht hast.
  Ist der Händler billiger als das AH, zählt der Händlerpreis.
- **Rezepte** liest das Addon über `C_TradeSkillUI` aus dem offenen Berufsfenster.
- **Gewinn** = AH-Wert × 0,95 (5 % AH-Gebühr) − Materialkosten.
- `?` heißt: kein Preis bekannt. `+` hinter den Kosten heißt: mindestens ein Material
  hat keinen Preis, die Kosten sind also zu niedrig.
- Mit der Maus über eine Zeile fahren zeigt die Kosten pro Material.

## Dateien

- `MoneyTalks/Core.lua`: Rechenlogik ohne WoW-API.
- `MoneyTalks/UI.lua`: Fenster, Rezepte auslesen, Anbindung an Auctionator.
- `tests/core_test.lua`: Selbsttest der Rechenlogik (`lua tests/core_test.lua`).

## Bekannte Grenzen

- Preise sind der niedrigste zuletzt gesehene Preis pro Stück. Ob davon genug im AH
  liegt und ob sich das Endprodukt verkauft, weiß das Addon nicht.
- Zwischenprodukte werden zum AH-Preis gerechnet, nicht zu den eigenen Herstellkosten.
- Verzauberungen haben kein Endprodukt und zeigen nur Kosten.
