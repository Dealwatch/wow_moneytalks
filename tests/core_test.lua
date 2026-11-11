-- Selbsttest der Rechenlogik. Aus dem Repo-Root starten: lua tests/core_test.lua
local ns = {}
assert(loadfile("MoneyTalks/Core.lua"))("MoneyTalks", ns)

local ah = { [1] = 100, [2] = 500, [10] = 2000 } -- Item 3 hat keinen AH-Preis
local vendor = { [2] = 50, [3] = 10 }
local function ahPrice(id) return ah[id] end
local function vendorPrice(id) return vendor[id] end

-- 4x Leder @100 (AH) + 2x Faden @50 (Haendler billiger als AH) = 500
-- Verkauf 2000 * 0.95 = 1900 -> Gewinn 1400
local r = ns.Evaluate(
  { outputItemID = 10, outputQty = 1, reagents = { { itemID = 1, qty = 4 }, { itemID = 2, qty = 2 } } },
  ahPrice, vendorPrice)
assert(r.cost == 500 and r.value == 1900 and r.profit == 1400)
assert(r.reagents[2].fromVendor and not r.reagents[1].fromVendor)

-- Material ohne jeden Preis: Kosten unvollstaendig, kein Gewinn
r = ns.Evaluate({ outputItemID = 10, outputQty = 1, reagents = { { itemID = 99, qty = 1 } } }, ahPrice, vendorPrice)
assert(r.costIncomplete and r.profit == nil and r.value == 1900)

-- Kein Endprodukt (Verzauberung) oder Endprodukt nie im AH gesehen: nur Kosten
r = ns.Evaluate({ outputQty = 1, reagents = { { itemID = 3, qty = 5 } } }, ahPrice, vendorPrice)
assert(r.cost == 50 and r.value == nil and r.profit == nil)

-- Verlust wird negativ ausgewiesen
r = ns.Evaluate({ outputItemID = 1, outputQty = 1, reagents = { { itemID = 2, qty = 10 } } }, ahPrice, vendorPrice)
assert(r.profit == 95 - 500)

local rows = {
  { name = "b", result = { profit = nil } },
  { name = "a", result = { profit = -5 } },
  { name = "c", result = { profit = 10 } },
}
ns.SortByProfit(rows)
assert(rows[1].name == "c" and rows[2].name == "a" and rows[3].name == "b")

print("core_test ok")
