-- Reine Rechenlogik, ohne WoW-API: laeuft auch ausserhalb des Spiels (tests/core_test.lua).
local _, ns = ...

ns.AH_CUT = 0.95 -- das AH behaelt 5 % vom Verkaufspreis

-- recipe = { outputItemID, outputQty, reagents = { { itemID, qty }, ... } }
-- ahPrice / vendorPrice: function(itemID) -> Kupfer pro Stueck oder nil
function ns.Evaluate(recipe, ahPrice, vendorPrice)
  local cost, costIncomplete, reagents = 0, false, {}
  for _, r in ipairs(recipe.reagents) do
    local ah, vendor = ahPrice(r.itemID), vendorPrice(r.itemID)
    local unit = ah and vendor and math.min(ah, vendor) or ah or vendor
    if unit then
      cost = cost + unit * r.qty
    else
      costIncomplete = true
    end
    reagents[#reagents + 1] = {
      itemID = r.itemID, qty = r.qty, unit = unit,
      fromVendor = unit ~= nil and unit == vendor,
    }
  end

  local sale = recipe.outputItemID and ahPrice(recipe.outputItemID)
  local value = sale and math.floor(sale * recipe.outputQty * ns.AH_CUT)
  return {
    cost = cost,
    costIncomplete = costIncomplete,
    value = value,
    -- kein Gewinn, wenn ein Preis fehlt: lieber "?" als eine falsche Zahl
    profit = value and not costIncomplete and math.floor(value - cost) or nil,
    reagents = reagents,
  }
end

-- Hoechster Gewinn zuerst, Rezepte ohne berechenbaren Gewinn ans Ende.
function ns.SortByProfit(rows)
  table.sort(rows, function(a, b)
    local pa, pb = a.result.profit, b.result.profit
    if pa and pb and pa ~= pb then return pa > pb end
    if (pa == nil) ~= (pb == nil) then return pa ~= nil end
    return a.name < b.name
  end)
end
