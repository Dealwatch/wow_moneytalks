-- Selbsttest der Rechenlogik. Aus dem Repo-Root starten: lua tests/core_test.lua
local ns = {}
assert(loadfile("MoneyTalks/Core.lua"))("MoneyTalks", ns)

-- Preistabellen je Test neu befuellen; fehlendes Alter bei vorhandenem AH-Preis = heute gesehen
local ah, age, vendor, sell, recipes
local ctx = {
  ahPrice = function(id) return ah[id] end,
  ahAge = function(id) if age[id] ~= nil then return age[id] or nil end return ah[id] and 0 end,
  vendorPrice = function(id) return vendor[id] end,
  vendorSellPrice = function(id) return sell[id] end,
}
local function reset()
  ah, age, vendor, sell, recipes = {}, {}, {}, {}, {}
end
local function recipe(outputItemID, outputQty, ...)
  local r = { outputItemID = outputItemID, outputQty = outputQty, reagents = {} }
  for _, pair in ipairs({ ... }) do r.reagents[#r.reagents + 1] = { itemID = pair[1], qty = pair[2] } end
  recipes[#recipes + 1] = r
  return r
end
local function eval(r)
  ctx.producers = ns.BuildProducers(recipes)
  return ns.Evaluate(r, ctx)
end

---------------------------------------------------------------------------------------------
-- Kosten, Erloes, Gewinn
---------------------------------------------------------------------------------------------
reset()
ah = { [1] = 100, [2] = 500, [10] = 2000 }
vendor = { [2] = 50, [3] = 10 }
sell = { [10] = 300, [20] = 0, [30] = 700 }

-- 4x Leder @100 (AH) + 2x Faden @50 (Haendler billiger als AH) = 500
-- Verkauf 2000 * 0.95 = 1900 -> Gewinn 1400
local r = eval(recipe(10, 1, { 1, 4 }, { 2, 2 }))
assert(r.cost == 500 and r.value == 1900 and r.profit == 1400 and not r.stale)
assert(r.reagents[1].source == "ah" and r.reagents[2].source == "vendor")

-- Material ohne jeden Preis: Kosten unvollstaendig, kein Gewinn
r = eval(recipe(10, 1, { 99, 1 }))
assert(r.costIncomplete and r.profit == nil and r.value == 1900 and r.reagents[1].source == nil)

-- Kein Endprodukt (Verzauberung): nur Kosten
r = eval(recipe(nil, 1, { 3, 5 }))
assert(r.cost == 50 and r.value == nil and r.profit == nil)

-- Verlust wird negativ ausgewiesen
r = eval(recipe(1, 1, { 2, 10 }))
assert(r.profit == 95 - 500)

-- AH (1900) schlaegt Haendler (300): im AH verkaufen
r = eval(recipe(10, 1))
assert(r.ahValue == 1900 and r.vendorValue == 300 and r.value == 1900 and not r.sellToVendor)

-- Haendler zahlt mehr als das AH nach Gebuehr: 2x 700 = 1400 gegen 2x 500 * 0.95 = 950
ah[30] = 500
r = eval(recipe(30, 2, { 1, 1 }))
assert(r.sellToVendor and r.value == 1400 and r.ahValue == 950 and r.profit == 1300)

-- Kein AH-Preis: Haendler ist die Untergrenze
ah[30] = nil
r = eval(recipe(30, 1))
assert(r.sellToVendor and r.value == 700 and r.ahValue == nil)

-- Haendler kauft das Item nicht (0) und kein AH-Preis: kein Wert
r = eval(recipe(20, 1))
assert(r.value == nil and r.vendorValue == nil and not r.sellToVendor and r.profit == nil)

---------------------------------------------------------------------------------------------
-- Zwischenprodukte selbst herstellen
---------------------------------------------------------------------------------------------
-- Kette: 1 Leichtes Leder (10) -> 2 Mittleres (40 im AH) -> 3 Schweres (200 im AH)
reset()
ah = { [1] = 10, [2] = 40, [3] = 200, [50] = 5000 }
recipe(2, 1, { 1, 3 })       -- Mittleres aus 3 Leichtem = 30, billiger als 40 im AH
recipe(3, 1, { 2, 4 })       -- Schweres aus 4 Mittlerem = 120, billiger als 200 im AH
r = eval(recipe(50, 1, { 3, 2 }, { 1, 1 }))
-- 2x Schweres zu je 120 (ueber zwei Stufen selbst hergestellt) + 1x Leichtes zu 10 = 250
assert(r.cost == 250, "Kette ueber zwei Stufen: " .. r.cost)
assert(r.reagents[1].source == "craft" and r.reagents[1].unit == 120 and r.reagents[2].source == "ah")
assert(r.profit == 4750 - 250)

-- Selbst herstellen ist teurer oder gleich teuer: kaufen
ah[2] = 30
r = eval(recipes[2])
assert(r.reagents[1].source == "ah" and r.cost == 120)

-- Rezept liefert mehrere Stueck: Kosten pro Stueck
reset()
ah = { [1] = 100, [2] = 80 }
recipe(2, 5, { 1, 2 })       -- 5 Stueck aus 200 = 40 pro Stueck
r = eval(recipe(60, 1, { 2, 3 }))
assert(r.cost == 120 and r.reagents[1].source == "craft")

-- Zwischenprodukt nur selbst herstellbar (kein AH-Preis)
reset()
ah = { [1] = 100 }
recipe(2, 1, { 1, 2 })
r = eval(recipe(60, 1, { 2, 1 }))
assert(r.cost == 200 and not r.costIncomplete and r.reagents[1].source == "craft")

-- Dem Zwischenprodukt fehlt selbst ein Preis: zurueck auf den AH-Preis
reset()
ah = { [2] = 90 }
recipe(2, 1, { 1, 2 })       -- Item 1 hat keinen Preis
r = eval(recipe(60, 1, { 2, 1 }))
assert(r.cost == 90 and r.reagents[1].source == "ah")

-- Rezepte im Kreis (A aus B, B aus A) laufen nicht endlos
reset()
ah = { [1] = 100, [2] = 500 }
local aFromB = recipe(1, 1, { 2, 1 })
local bFromA = recipe(2, 1, { 1, 1 })
r = eval(bFromA)
assert(r.cost == 100 and r.reagents[1].source == "ah")
r = eval(aFromB)             -- B kaufen (500) oder aus gekauftem A herstellen (100): herstellen
assert(r.cost == 100 and r.reagents[1].source == "craft")
r = eval(recipe(60, 1, { 2, 1 }))
assert(r.cost == 100 and r.reagents[1].source == "craft") -- B aus A (100) statt 500 im AH

-- Zwei Rezepte fuer dasselbe Item: das billigere gewinnt
reset()
ah = { [1] = 100, [3] = 10 }
recipe(2, 1, { 1, 2 })       -- 200
recipe(2, 1, { 3, 5 })       -- 50
r = eval(recipe(60, 1, { 2, 1 }))
assert(r.cost == 50)

---------------------------------------------------------------------------------------------
-- Alte Preise (aelter als 3 Tage)
---------------------------------------------------------------------------------------------
reset()
ah = { [1] = 100, [2] = 50, [10] = 2000 }
age = { [1] = 3 }            -- genau 3 Tage: noch nicht alt
r = eval(recipe(10, 1, { 1, 1 }))
assert(not r.stale and r.reagents[1].age == 3 and not r.reagents[1].old)

age = { [1] = 4 }
r = eval(recipes[1])
assert(r.stale and r.reagents[1].old and r.reagents[1].age == 4)

-- Preis vorhanden, aber Alter unbekannt (ueber 21 Tage): alt
age = { [1] = false }
r = eval(recipes[1])
assert(r.stale and r.reagents[1].old and r.reagents[1].age == nil)

-- Altes Endprodukt: nur relevant, wenn im AH verkauft wird
age = { [10] = 9 }
r = eval(recipes[1])
assert(r.stale and r.ahValueOld and r.ahValueAge == 9)
sell = { [10] = 5000 }
r = eval(recipes[1])
assert(r.sellToVendor and not r.stale)

-- Haendlerpreise veralten nicht
reset()
ah = { [1] = 100, [10] = 2000 }
vendor = { [1] = 20 }
age = { [1] = 30 }
r = eval(recipe(10, 1, { 1, 1 }))
assert(not r.stale and r.reagents[1].source == "vendor")

-- Alter Preis steckt in einem selbst hergestellten Zwischenprodukt
reset()
ah = { [1] = 10, [2] = 100, [10] = 2000 }
age = { [1] = 8 }
recipe(2, 1, { 1, 2 })
r = eval(recipe(10, 1, { 2, 1 }))
assert(r.reagents[1].source == "craft" and r.reagents[1].old and r.stale)

---------------------------------------------------------------------------------------------
-- Sortierung
---------------------------------------------------------------------------------------------
local rows = {
  { name = "b", result = { profit = nil } },
  { name = "a", result = { profit = -5 } },
  { name = "c", result = { profit = 10 } },
}
ns.SortByProfit(rows)
assert(rows[1].name == "c" and rows[2].name == "a" and rows[3].name == "b")

print("core_test ok")
