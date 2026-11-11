-- Texte der Oberflaeche: Deutsch im deutschen Client, sonst Englisch.
-- Beide Tabellen muessen dieselben Schluessel haben (prueft tests/ui_smoke_test.lua).
local _, ns = ...

local de = {
  HEADER_RECIPE = "Rezept",
  HEADER_COST = "Kosten",
  HEADER_REVENUE = "Erlös",
  HEADER_WHERE = "Verkauf",
  HEADER_PROFIT = "Gewinn",
  WHERE_AH = "AH",
  WHERE_VENDOR = "Händler",

  NOTE_AH = "AH",
  NOTE_VENDOR = "Händler",
  NOTE_CRAFT = "selbst herstellen",
  NOTE_CRAFT_OLD = "selbst herstellen, Preis alt",
  AGE_DAYS = "%d Tage alt",
  AGE_UNKNOWN = "Alter unbekannt",

  SKILL = "Skillpunkt: %s",
  SKILL_OPTIMAL = "sicher",
  SKILL_MEDIUM = "wahrscheinlich",
  SKILL_EASY = "selten",
  SKILL_NONE = "keiner",

  TIP_COST = "Kosten",
  TIP_REVENUE_AH = "Erlös im AH",
  TIP_AH_FEE = "abzgl. 5 %",
  TIP_REVENUE_VENDOR = "Erlös beim Händler",
  TIP_PROFIT = "Gewinn",
  TIP_CLICK = "Klick zeigt das Rezept",

  STATUS_NO_RECIPES = "Keine gelernten Rezepte gefunden.",
  STATUS_NO_PRICES = "Keine AH-Preise: bitte im Auktionshaus scannen.",
  STATUS_PROFIT = "Gewinn bei %d von %d Rezepten",
  LEGEND = "? = Preis fehlt    ~ = Preis alt",
  LOCK = "Fixieren",
  RESET_DONE = "MoneyTalks: Gemerkte Rezepte gelöscht. Öffne deine Berufe, um sie neu einzulesen.",
}

local en = {
  HEADER_RECIPE = "Recipe",
  HEADER_COST = "Cost",
  HEADER_REVENUE = "Revenue",
  HEADER_WHERE = "Sell at",
  HEADER_PROFIT = "Profit",
  WHERE_AH = "AH",
  WHERE_VENDOR = "Vendor",

  NOTE_AH = "AH",
  NOTE_VENDOR = "vendor",
  NOTE_CRAFT = "craft yourself",
  NOTE_CRAFT_OLD = "craft yourself, old price",
  AGE_DAYS = "%d days old",
  AGE_UNKNOWN = "age unknown",

  SKILL = "Skill-up: %s",
  SKILL_OPTIMAL = "guaranteed",
  SKILL_MEDIUM = "likely",
  SKILL_EASY = "unlikely",
  SKILL_NONE = "none",

  TIP_COST = "Cost",
  TIP_REVENUE_AH = "AH revenue",
  TIP_AH_FEE = "minus 5%",
  TIP_REVENUE_VENDOR = "Vendor revenue",
  TIP_PROFIT = "Profit",
  TIP_CLICK = "Click to show the recipe",

  STATUS_NO_RECIPES = "No learned recipes found.",
  STATUS_NO_PRICES = "No AH prices yet: scan at the auction house.",
  STATUS_PROFIT = "Profit on %d of %d recipes",
  LEGEND = "? = price missing    ~ = old price",
  LOCK = "Lock",
  RESET_DONE = "MoneyTalks: Remembered recipes cleared. Open your professions to read them again.",
}

ns.L = GetLocale() == "deDE" and de or en
