-- Rauchtest fuer UI.lua mit nachgebauter WoW-API: faengt Laufzeitfehler (nil-Aufrufe,
-- falsche Reihenfolge) ab, prueft aber nicht das Aussehen. Start: lua tests/ui_smoke_test.lua
local created = {}

-- Objekt, das jede Methode annimmt und sich Texte, Skripte und Sichtbarkeit merkt
local function stub()
  local o = { scripts = {} }
  created[#created + 1] = o
  return setmetatable(o, { __index = function(_, key)
    if key == "TitleText" or key == "data" or key == "moving" then return nil end
    if key == "Text" then local t = stub(); rawset(o, "Text", t); return t end
    if key == "GetPoint" then return function() return "CENTER", nil, "CENTER", 10, 20 end end
    if key == "SetChecked" then return function(self, v) self.checked = v end end
    if key == "GetChecked" then return function(self) return self.checked end end
    if key == "SetTextColor" then return function(self, r, g, b) self.color = { r, g, b } end end
    if key == "CreateFontString" or key == "CreateTexture" then return stub end
    if key == "SetScript" then return function(self, name, fn) self.scripts[name] = fn end end
    if key == "SetText" then return function(self, text) self.text = text end end
    if key == "Show" then return function(self) self.shown = true end end
    if key == "Hide" then return function(self) self.shown = false end end
    if key == "IsShown" then return function(self) return self.shown end end
    return function() end
  end })
end

local color = { WrapTextInColorCode = function(_, text) return text end }
GRAY_FONT_COLOR, GREEN_FONT_COLOR, RED_FONT_COLOR = color, color, color
CreateFrame, UIParent, GameTooltip = stub, stub(), stub()
GameTooltip_Hide = function() end
GetMoneyString = function(copper) return copper .. "c" end
C_Timer = { After = function(_, fn) fn() end }
SlashCmdList = {}
Enum = {
  CraftingReagentType = { Basic = 1 },
  TradeskillRelativeDifficulty = { Optimal = 0, Medium = 1, Easy = 2, Trivial = 3 },
}

-- Item 1 = Leder (AH 100), 2 = Faden (Haendler 50), 10/11/12 = Endprodukte
local ahPrices = { [1] = 100, [10] = 2000, [11] = 100 }
local sellPrices = { [10] = 300, [11] = 400, [12] = 0 }
Auctionator = { API = { v1 = {
  GetAuctionPriceByItemID = function(_, id) return ahPrices[id] end,
  GetAuctionAgeByItemID = function(_, id) return id == 10 and 9 or ahPrices[id] and 0 end, -- Item 10: Preis 9 Tage alt
  GetVendorPriceByItemID = function(_, id) return id == 2 and 50 or nil end,
  RegisterForDBUpdate = function() end,
} } }
C_Item = {
  GetItemInfo = function(id) return "n", "l", 1, 1, 1, "t", "s", 1, "e", 1, sellPrices[id] end,
  GetItemNameByID = function(id) return "Item " .. id end,
}
local opened
C_TradeSkillUI = {
  GetAllRecipeIDs = function() return { 101, 102, 103, 104 } end,
  GetRecipeInfo = function(id)
    -- 101: orange (sicherer Skillpunkt), 102: grau (keiner), 103: gruen, aber canSkillUp = false
    return {
      name = "Rezept " .. id, icon = 1, learned = id ~= 104,
      relativeDifficulty = ({ [101] = 0, [102] = 3, [103] = 2 })[id], canSkillUp = id ~= 103,
    }
  end,
  GetRecipeSchematic = function(id)
    return {
      outputItemID = ({ [101] = 10, [102] = 11, [103] = 12 })[id], quantityMin = 1, quantityMax = 1,
      reagentSlotSchematics = {
        { reagentType = 1, quantityRequired = 4, reagents = { { itemID = 1 } } },
        { reagentType = 1, quantityRequired = 2, reagents = { { itemID = 2 } } },
        { reagentType = 0, quantityRequired = 1, reagents = { { itemID = 99 } } }, -- optional: zaehlt nicht
      },
    }
  end,
  OpenRecipe = function(id) opened = id end,
  IsNPCCrafting = function() return false end,
  IsTradeSkillLinked = function() return false end,
  IsTradeSkillGuild = function() return false end,
}

-- Deutsche und englische Texte muessen dieselben Schluessel haben
local function locale(code)
  GetLocale = function() return code end
  local t = {}
  assert(loadfile("MoneyTalks/Locale.lua"))("MoneyTalks", t)
  return t.L
end
local de, en = locale("deDE"), locale("enUS")
assert(de.HEADER_PROFIT == "Gewinn" and en.HEADER_PROFIT == "Profit")
for key in pairs(de) do assert(en[key], "englischer Text fehlt: " .. key) end
for key in pairs(en) do assert(de[key], "deutscher Text fehlt: " .. key) end

-- der restliche Test laeuft mit deutschen Texten
GetLocale = function() return "deDE" end
local ns = {}
assert(loadfile("MoneyTalks/Core.lua"))("MoneyTalks", ns)
assert(loadfile("MoneyTalks/Locale.lua"))("MoneyTalks", ns)
assert(loadfile("MoneyTalks/UI.lua"))("MoneyTalks", ns)

local events = created[#created] -- der Ereignis-Frame ist das einzige Objekt, das UI.lua beim Laden anlegt
events.scripts.OnEvent(events, "TRADE_SKILL_SHOW")
events.scripts.OnEvent(events, "TRADE_SKILL_LIST_UPDATE")
events.scripts.OnEvent(events, "GET_ITEM_INFO_RECEIVED", 10)

local texts, rows = {}, {}
for _, o in ipairs(created) do
  if o.text then texts[o.text] = true end
  if o.scripts.OnEnter and rawget(o, "shown") then rows[#rows + 1] = o end -- nur Rezeptzeilen haben einen Tooltip
end

-- Kosten je Rezept: 4x100 + 2x50 = 500. 101: AH 1900 -> +1400, AH-Preis alt -> "*".
-- 102: Haendler 400 -> -100. 103: kein Erloes.
assert(#rows == 3, "erwartet 3 gelernte Rezepte, gefunden " .. #rows)
assert(rows[1].data.recipeID == 101 and rows[1].profit.text == "1400c" and rows[1].where.text == "AH")
assert(rows[1].mark.text == "*" and rows[2].mark.text == "" and rows[3].mark.text == "")
assert(rows[2].data.recipeID == 102 and rows[2].profit.text == "-100c" and rows[2].where.text == "Händler")
assert(rows[3].data.recipeID == 103 and rows[3].profit.text == "?" and rows[3].where.text == "")
assert(texts["Gewinn bei 1 von 3 Rezepten"], "Statuszeile fehlt")

-- Namensfarbe: orange bei Skillpunkt, sonst weiss bzw. grau ohne berechenbaren Gewinn
assert(rows[1].name.color[2] == 0.5 and rows[1].data.skill.text == "sicher")
assert(rows[2].name.color[1] == 1 and rows[2].name.color[2] == 1 and rows[2].data.skill == nil)
assert(rows[3].name.color[1] == 0.5 and rows[3].data.skill == nil)

-- Fenster verschieben: frei merkt die Position, fixiert bewegt sich nicht
local main, lock
for _, o in ipairs(created) do
  if o.scripts.OnDragStart then main = o end
  if rawget(o, "Text") and o.scripts.OnClick then lock = o end
end
assert(main and lock and lock.Text.text == "Fixieren" and lock.checked == false)
main.scripts.OnDragStart(main); main.scripts.OnDragStop(main)
assert(MoneyTalksDB.pos[1] == "CENTER" and MoneyTalksDB.pos[3] == 10 and MoneyTalksDB.pos[4] == 20)
MoneyTalksDB.pos = nil
lock.checked = true; lock.scripts.OnClick(lock)
assert(MoneyTalksDB.locked == true)
main.scripts.OnDragStart(main); main.scripts.OnDragStop(main)
assert(MoneyTalksDB.pos == nil, "fixiertes Fenster darf sich nicht verschieben")

-- gelernte Rezepte werden gemerkt, das ungelernte (104) nicht
assert(MoneyTalksRecipes[101] and MoneyTalksRecipes[102] and MoneyTalksRecipes[103] and not MoneyTalksRecipes[104])
assert(MoneyTalksRecipes[101].outputItemID == 10 and #MoneyTalksRecipes[101].reagents == 2)

for _, row in ipairs(rows) do row.scripts.OnEnter(row) end
rows[1].scripts.OnClick(rows[1])
assert(opened == 101)

events.scripts.OnEvent(events, "TRADE_SKILL_CLOSE")
SlashCmdList.MONEYTALKS("")
local realPrint = print
print = function() end
SlashCmdList.MONEYTALKS("reset")
print = realPrint
assert(next(MoneyTalksRecipes) == nil)

print("ui_smoke_test ok")
