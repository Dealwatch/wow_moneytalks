-- Selbsttest der Rechenlogik. Aus dem Repo-Root starten: lua tests/core_test.lua
local ns = {}
assert(loadfile("MoneyTalks/Core.lua"))("MoneyTalks", ns)

local ah = { [1] = 100, [2] = 500, [10] = 2000 } -- Item 3 hat keinen AH-Preis
local vendor = { [2] = 50, [3] = 10 }
local function ahPrice(id) return ah[id] end
local function vendorPrice(id) return vendor[id] end
local sell = { [10] = 300, [20] = 0, [30] = 700 } -- was der Haendler zahlt
local function sellPrice(id) return sell[id] end

-- 4x Leder @100 (AH) + 2x Faden @50 (Haendler billiger als AH) = 500
-- Verkauf 2000 * 0.95 = 1900 -> Gewinn 1400
local r = ns.Evaluate(
  { outputItemID = 10, outputQty = 1, reagents = { { itemID = 1, qty = 4 }, { itemID = 2, qty = 2 } } },
  ahPrice, vendorPrice, sellPrice)
assert(r.cost == 500 and r.value == 1900 and r.profit == 1400)
assert(r.reagents[2].fromVendor and not r.reagents[1].fromVendor)

-- Material ohne jeden Preis: Kosten unvollstaendig, kein Gewinn
r = ns.Evaluate({ outputItemID = 10, outputQty = 1, reagents = { { itemID = 99, qty = 1 } } }, ahPrice, vendorPrice, sellPrice)
assert(r.costIncomplete and r.profit == nil and r.value == 1900)

-- Kein Endprodukt (Verzauberung) oder Endprodukt nie im AH gesehen: nur Kosten
r = ns.Evaluate({ outputQty = 1, reagents = { { itemID = 3, qty = 5 } } }, ahPrice, vendorPrice, sellPrice)
assert(r.cost == 50 and r.value == nil and r.profit == nil)

-- Verlust wird negativ ausgewiesen
r = ns.Evaluate({ outputItemID = 1, outputQty = 1, reagents = { { itemID = 2, qty = 10 } } }, ahPrice, vendorPrice, sellPrice)
assert(r.profit == 95 - 500)

-- AH (1900) schlaegt Haendler (300): im AH verkaufen
r = ns.Evaluate({ outputItemID = 10, outputQty = 1, reagents = {} }, ahPrice, vendorPrice, sellPrice)
assert(r.ahValue == 1900 and r.vendorValue == 300 and r.value == 1900 and not r.sellToVendor)

-- Haendler zahlt mehr als das AH nach Gebuehr: 2x 700 = 1400 gegen 2x 500 * 0.95 = 950
ah[30] = 500
r = ns.Evaluate({ outputItemID = 30, outputQty = 2, reagents = { { itemID = 1, qty = 1 } } }, ahPrice, vendorPrice, sellPrice)
assert(r.sellToVendor and r.value == 1400 and r.ahValue == 950 and r.profit == 1300)

-- Kein AH-Preis: Haendler ist die Untergrenze
ah[30] = nil
r = ns.Evaluate({ outputItemID = 30, outputQty = 1, reagents = {} }, ahPrice, vendorPrice, sellPrice)
assert(r.sellToVendor and r.value == 700 and r.ahValue == nil)

-- Haendler kauft das Item nicht (0) und kein AH-Preis: kein Wert
r = ns.Evaluate({ outputItemID = 20, outputQty = 1, reagents = {} }, ahPrice, vendorPrice, sellPrice)
assert(r.value == nil and r.vendorValue == nil and not r.sellToVendor and r.profit == nil)

local rows = {
  { name = "b", result = { profit = nil } },
  { name = "a", result = { profit = -5 } },
  { name = "c", result = { profit = 10 } },
}
ns.SortByProfit(rows)
assert(rows[1].name == "c" and rows[2].name == "a" and rows[3].name == "b")

print("core_test ok")
