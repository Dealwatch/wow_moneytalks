-- Reine Rechenlogik, ohne WoW-API: laeuft auch ausserhalb des Spiels (tests/core_test.lua).
local _, ns = ...

ns.AH_CUT = 0.95 -- das AH behaelt 5 % vom Verkaufspreis
ns.OLD_DAYS = 3 -- AH-Preise, die aelter sind, gelten als unzuverlaessig

-- recipe = { outputItemID, outputQty, reagents = { { itemID, qty }, ... } }
--
-- ctx beschreibt die Preisquellen, jeweils function(itemID) -> Wert oder nil:
--   ahPrice         Kupfer pro Stueck im AH
--   ahAge           vor wie vielen Tagen das Item zuletzt im AH gesehen wurde
--   vendorPrice     was ein Haendler fuer das Item verlangt
--   vendorSellPrice was ein Haendler fuer das Item zahlt
-- und ctx.producers = { [itemID] = { recipe, ... } }: Rezepte, die das Item herstellen.

local function IsOld(ctx, itemID)
  local age = ctx.ahAge(itemID)
  return age == nil or age > ns.OLD_DAYS
end

local ReagentCosts

-- Billigster Weg, ein Stueck zu bekommen: AH, Haendler oder selbst herstellen.
-- Rueckgabe: Stueckpreis, Quelle ("ah" | "vendor" | "craft"), ob ein alter AH-Preis drinsteckt.
-- visiting = Items, die gerade weiter oben in der Kette hergestellt werden. Das verhindert
-- Endlosschleifen bei Rezepten im Kreis (A aus B, B aus A).
local function UnitCost(ctx, itemID, visiting)
  local unit, source, old
  local ah, vendor = ctx.ahPrice(itemID), ctx.vendorPrice(itemID)
  if ah then
    unit, source, old = ah, "ah", IsOld(ctx, itemID)
  end
  if vendor and (not unit or vendor <= unit) then
    unit, source, old = vendor, "vendor", false
  end
  if not visiting[itemID] then
    visiting[itemID] = true
    for _, recipe in ipairs(ctx.producers[itemID] or {}) do
      local cost, incomplete, _, craftOld = ReagentCosts(ctx, recipe, visiting)
      local craftUnit = cost / recipe.outputQty
      -- nur wenn es wirklich billiger ist: kaufen macht weniger Arbeit
      if not incomplete and (not unit or craftUnit < unit) then
        unit, source, old = craftUnit, "craft", craftOld
      end
    end
    visiting[itemID] = nil
  end
  return unit, source, old
end

-- Rueckgabe: Gesamtkosten, ob ein Preis fehlt, Liste je Material, ob ein alter Preis drinsteckt
function ReagentCosts(ctx, recipe, visiting)
  local cost, incomplete, anyOld, reagents = 0, false, false, {}
  for _, r in ipairs(recipe.reagents) do
    local unit, source, old = UnitCost(ctx, r.itemID, visiting)
    if unit then
      cost = cost + unit * r.qty
    else
      incomplete = true
    end
    anyOld = anyOld or old == true
    reagents[#reagents + 1] = {
      itemID = r.itemID, qty = r.qty, unit = unit, source = source, old = old == true,
      age = source == "ah" and ctx.ahAge(r.itemID) or nil,
    }
  end
  return cost, incomplete, reagents, anyOld
end

function ns.Evaluate(recipe, ctx)
  local visiting = {}
  -- das Endprodukt selbst nicht als eigenes Zwischenprodukt einrechnen
  if recipe.outputItemID then visiting[recipe.outputItemID] = true end
  local cost, costIncomplete, reagents, costOld = ReagentCosts(ctx, recipe, visiting)

  local sale = recipe.outputItemID and ctx.ahPrice(recipe.outputItemID)
  local ahValue = sale and math.floor(sale * recipe.outputQty * ns.AH_CUT)
  local sell = recipe.outputItemID and ctx.vendorSellPrice(recipe.outputItemID)
  -- 0 = der Haendler kauft das Item nicht
  local vendorValue = sell and sell > 0 and math.floor(sell * recipe.outputQty) or nil
  -- bei Gleichstand Haendler: sofort, sicher und ohne Einstellgebuehr
  local sellToVendor = vendorValue ~= nil and (ahValue == nil or vendorValue >= ahValue)
  local value = sellToVendor and vendorValue or ahValue
  local ahValueOld = ahValue ~= nil and IsOld(ctx, recipe.outputItemID)
  return {
    cost = cost,
    costIncomplete = costIncomplete,
    reagents = reagents,
    ahValue = ahValue,
    ahValueAge = ahValue and ctx.ahAge(recipe.outputItemID) or nil,
    ahValueOld = ahValueOld,
    vendorValue = vendorValue,
    value = value, -- der bessere der beiden Verkaufswege
    sellToVendor = sellToVendor,
    -- kein Gewinn, wenn ein Preis fehlt: lieber "?" als eine falsche Zahl
    profit = value and not costIncomplete and math.floor(value - cost) or nil,
    -- der Gewinn beruht auf mindestens einem alten AH-Preis
    stale = costOld or (ahValueOld and not sellToVendor),
  }
end

-- Baut ctx.producers aus einer Rezeptsammlung { [irgendein Schluessel] = recipe }.
function ns.BuildProducers(recipes)
  local producers = {}
  for _, recipe in pairs(recipes) do
    if recipe.outputItemID then
      producers[recipe.outputItemID] = producers[recipe.outputItemID] or {}
      table.insert(producers[recipe.outputItemID], recipe)
    end
  end
  return producers
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
