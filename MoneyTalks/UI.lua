local ADDON, ns = ...
local L = ns.L

local ROW_HEIGHT, ICON_SIZE = 18, 14
local NAME_WIDTH, MONEY_WIDTH, WHERE_WIDTH, PROFIT_WIDTH, MARK_WIDTH = 180, 88, 58, 84, 12
local LIST_WIDTH = NAME_WIDTH + 2 * MONEY_WIDTH + WHERE_WIDTH + PROFIT_WIDTH + MARK_WIDTH
local WIDTH = LIST_WIDTH + 50

local function AHPrice(itemID)
  return Auctionator.API.v1.GetAuctionPriceByItemID(ADDON, itemID)
end

local function AHAge(itemID)
  return Auctionator.API.v1.GetAuctionAgeByItemID(ADDON, itemID)
end

-- Auctionator merkt sich Haendlerpreise, sobald man den Haendler einmal besucht hat.
local function VendorPrice(itemID)
  return Auctionator.API.v1.GetVendorPriceByItemID(ADDON, itemID)
end

-- Was ein Haendler fuer das Item zahlt. nil, solange das Spiel die Itemdaten noch laedt.
local awaitingItemInfo = {}
local function VendorSellPrice(itemID)
  local price = select(11, C_Item.GetItemInfo(itemID))
  if not price then awaitingItemInfo[itemID] = true end
  return price
end

-- Preisquellen fuer Core.lua; producers wird in ReadRecipes gesetzt
local ctx = {
  ahPrice = AHPrice, ahAge = AHAge, vendorPrice = VendorPrice, vendorSellPrice = VendorSellPrice,
}

-- copper = nil/false ergibt ein graues "?": das einzige Zeichen fuer "Preis fehlt"
local function Money(copper, color)
  if not copper then return GRAY_FONT_COLOR:WrapTextInColorCode("?") end
  local abs = math.abs(math.floor(copper))
  if abs >= 10000 then abs = abs - abs % 100 end -- ab 1 Gold ohne Kupfer: ruhigeres Bild
  local text = (copper < 0 and "-" or "") .. GetMoneyString(abs, true)
  return color and color:WrapTextInColorCode(text) or text
end

local function ProfitText(profit)
  return Money(profit, profit and (profit > 0 and GREEN_FONT_COLOR or profit < 0 and RED_FONT_COLOR))
end

-- Liest alle gelernten Rezepte des gerade offenen Berufs und merkt sie sich pro Charakter
-- (MoneyTalksRecipes), damit Zwischenprodukte aus anderen Berufen erkannt werden.
local function ReadRecipes()
  local rows = {}
  MoneyTalksRecipes = MoneyTalksRecipes or {}
  -- Rezepte aus Chat-Links, der Gilde oder von NPCs gehoeren nicht dem Charakter
  local own = not (C_TradeSkillUI.IsNPCCrafting() or C_TradeSkillUI.IsTradeSkillLinked()
    or C_TradeSkillUI.IsTradeSkillGuild())
  -- GetFilteredRecipeIDs nutzt Blizzards eigenes Fenster (beachtet aber dessen Suchfilter)
  local getIDs = C_TradeSkillUI.GetAllRecipeIDs or C_TradeSkillUI.GetFilteredRecipeIDs
  for _, recipeID in ipairs(getIDs() or {}) do
    local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
    local schematic = info and info.learned and C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
    if schematic then
      local reagents = {}
      for _, slot in ipairs(schematic.reagentSlotSchematics) do
        local itemID = slot.reagents[1] and slot.reagents[1].itemID
        if slot.reagentType == Enum.CraftingReagentType.Basic and itemID then
          reagents[#reagents + 1] = { itemID = itemID, qty = slot.quantityRequired }
        end
      end
      local recipe = {
        outputItemID = schematic.outputItemID, -- nil bei Verzauberungen: dann nur Kosten
        outputQty = (schematic.quantityMin + schematic.quantityMax) / 2,
        reagents = reagents,
      }
      rows[#rows + 1] = { recipeID = recipeID, name = info.name, icon = info.icon, recipe = recipe }
      if own then MoneyTalksRecipes[recipeID] = recipe end
    elseif own then
      MoneyTalksRecipes[recipeID] = nil -- nicht (mehr) gelernt
    end
  end
  -- erst jetzt rechnen: Zwischenprodukte brauchen die vollstaendige Rezeptsammlung
  ctx.producers = ns.BuildProducers(MoneyTalksRecipes)
  for _, row in ipairs(rows) do
    row.result = ns.Evaluate(row.recipe, ctx)
  end
  ns.SortByProfit(rows)
  return rows
end

local frame, content, status
local rowFrames = {}

local function Column(row, font, width, justify, leftOf, gap)
  local fs = row:CreateFontString(nil, "OVERLAY", font)
  fs:SetWidth(width)
  fs:SetJustifyH(justify)
  fs:SetWordWrap(false)
  fs:SetPoint("LEFT", leftOf, "RIGHT", gap or 0, 0)
  return fs
end

-- Spalten: Symbol + Rezept | Kosten | Erloes | Verkauf (AH/Haendler) | Gewinn | "~"
-- Das "~" hat eine eigene schmale Spalte, damit die Betraege buendig bleiben.
local function CreateRow(parent, frameType, font)
  local row = CreateFrame(frameType, nil, parent)
  row:SetSize(LIST_WIDTH, ROW_HEIGHT)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(ICON_SIZE, ICON_SIZE)
  row.icon:SetPoint("LEFT")
  row.name = Column(row, font, NAME_WIDTH - ICON_SIZE - 5, "LEFT", row.icon, 5)
  row.cost = Column(row, font, MONEY_WIDTH, "RIGHT", row.name)
  row.value = Column(row, font, MONEY_WIDTH, "RIGHT", row.cost)
  row.where = Column(row, font, WHERE_WIDTH, "RIGHT", row.value)
  row.profit = Column(row, font, PROFIT_WIDTH, "RIGHT", row.where)
  row.mark = Column(row, font, MARK_WIDTH, "RIGHT", row.profit)
  return row
end

local function AgeText(age)
  return age and L.AGE_DAYS:format(age) or L.AGE_UNKNOWN
end

-- Grauer Zusatz hinter einem Material: woher es am billigsten kommt, ob der Preis alt ist
local function ReagentNote(r)
  local note
  if r.source == "vendor" then
    note = L.NOTE_VENDOR
  elseif r.source == "craft" then
    note = r.old and L.NOTE_CRAFT_OLD or L.NOTE_CRAFT
  elseif r.old then
    note = AgeText(r.age)
  end
  return note and GRAY_FONT_COLOR:WrapTextInColorCode(" " .. note) or ""
end

-- Zeile im unteren Tooltip-Teil: Beschriftung gold, Betrag weiss; dim = ausgegraut
local function SummaryLine(label, value, dim)
  if dim then
    GameTooltip:AddDoubleLine(label, value, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
  else
    GameTooltip:AddDoubleLine(label, value, 1, 0.82, 0, 1, 1, 1)
  end
end

local function ShowTooltip(row)
  local result = row.data.result
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(row.data.name)
  for _, r in ipairs(result.reagents) do
    local name = C_Item.GetItemNameByID(r.itemID) or ("item:" .. r.itemID)
    GameTooltip:AddDoubleLine(
      r.qty .. "x " .. name .. ReagentNote(r), Money(r.unit and r.unit * r.qty), 1, 1, 1, 1, 1, 1)
  end
  GameTooltip:AddLine(" ")
  SummaryLine(L.TIP_COST, Money(not result.costIncomplete and result.cost))
  -- der schlechtere der beiden Verkaufswege wird ausgegraut
  local ahNote = L.TIP_AH_FEE .. (result.ahValueOld and ", " .. AgeText(result.ahValueAge) or "")
  SummaryLine(L.TIP_REVENUE_AH .. GRAY_FONT_COLOR:WrapTextInColorCode(" " .. ahNote),
    Money(result.ahValue), result.sellToVendor)
  SummaryLine(L.TIP_REVENUE_VENDOR, Money(result.vendorValue), result.value and not result.sellToVendor)
  SummaryLine(L.TIP_PROFIT, ProfitText(result.profit))
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L.TIP_CLICK, 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function CreateListRow(index)
  local row = CreateRow(content, "Button", "GameFontHighlightSmall")
  row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
  row.where:SetTextColor(0.6, 0.6, 0.6)
  row.mark:SetTextColor(0.5, 0.5, 0.5)
  if index % 2 == 0 then
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, 0.04)
  end
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  row:SetScript("OnEnter", ShowTooltip)
  row:SetScript("OnLeave", GameTooltip_Hide)
  row:SetScript("OnClick", function(self) C_TradeSkillUI.OpenRecipe(self.data.recipeID) end)
  return row
end

local function Refresh()
  local rows = ReadRecipes()
  local profitable, anyAHPrice = 0, false
  for i, data in ipairs(rows) do
    local result = data.result
    local row = rowFrames[i]
    if not row then
      row = CreateListRow(i)
      rowFrames[i] = row
    end
    row.data = data
    row.icon:SetTexture(data.icon)
    row.name:SetText(data.name)
    -- Rezepte ohne berechenbaren Gewinn treten optisch zurueck
    local shade = result.profit and 1 or 0.5
    row.name:SetTextColor(shade, shade, shade)
    row.cost:SetText(Money(not result.costIncomplete and result.cost))
    row.value:SetText(Money(result.value))
    row.where:SetText(result.value and (result.sellToVendor and L.WHERE_VENDOR or L.WHERE_AH) or "")
    row.profit:SetText(ProfitText(result.profit))
    -- "~" = der Gewinn beruht auf einem alten AH-Preis
    row.mark:SetText(result.profit and result.stale and "~" or "")
    row:Show()
    if result.profit and result.profit > 0 then profitable = profitable + 1 end
    anyAHPrice = anyAHPrice or result.ahValue ~= nil
  end
  for i = #rows + 1, #rowFrames do
    rowFrames[i]:Hide()
  end
  content:SetHeight(math.max(#rows * ROW_HEIGHT, 1))

  if #rows == 0 then
    status:SetText(L.STATUS_NO_RECIPES)
  elseif not anyAHPrice then
    status:SetText(L.STATUS_NO_PRICES)
  else
    status:SetText(L.STATUS_PROFIT:format(profitable, #rows))
  end
end

-- Das Spiel meldet Listen-Aenderungen oft mehrfach hintereinander (z. B. bei jedem
-- hergestellten Item); deshalb gesammelt und hoechstens alle 0,2 s neu rechnen.
local refreshQueued = false
local function QueueRefresh()
  if refreshQueued then return end
  refreshQueued = true
  C_Timer.After(0.2, function()
    refreshQueued = false
    if frame and frame:IsShown() then Refresh() end
  end)
end

local function CreateMainFrame()
  frame = CreateFrame("Frame", "MoneyTalksFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(WIDTH, 420)
  if ProfessionsFrame then
    frame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 4, 0)
  else
    frame:SetPoint("CENTER")
  end
  frame:SetClampedToScreen(true)
  if frame.TitleText then frame.TitleText:SetText("MoneyTalks") end

  local header = CreateRow(frame, "Frame", "GameFontNormalSmall")
  header:SetPoint("TOPLEFT", 14, -30)
  header.name:SetText(L.HEADER_RECIPE)
  header.cost:SetText(L.HEADER_COST)
  header.value:SetText(L.HEADER_REVENUE)
  header.where:SetText(L.HEADER_WHERE)
  header.profit:SetText(L.HEADER_PROFIT)

  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 14, -50)
  scroll:SetPoint("BOTTOMRIGHT", -32, 30)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(LIST_WIDTH, 1)
  scroll:SetScrollChild(content)

  status = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  status:SetPoint("BOTTOMLEFT", 16, 11)
  local legend = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  legend:SetPoint("BOTTOMRIGHT", -16, 11)
  legend:SetText(L.LEGEND)

  -- neu rechnen, sobald Auctionator nach einem Scan neue Preise hat
  Auctionator.API.v1.RegisterForDBUpdate(ADDON, QueueRefresh)
end

local function Open()
  if not frame then CreateMainFrame() end
  frame:Show()
  Refresh()
end

local events = CreateFrame("Frame")
events:RegisterEvent("TRADE_SKILL_SHOW")
events:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
events:RegisterEvent("TRADE_SKILL_CLOSE")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED") -- Haendlerpreise kommen evtl. erst nachtraeglich
events:SetScript("OnEvent", function(_, event, itemID)
  if event == "GET_ITEM_INFO_RECEIVED" then
    -- feuert fuer jedes Item im Spiel; nur reagieren, wenn wir darauf warten
    if awaitingItemInfo[itemID] then
      awaitingItemInfo[itemID] = nil
      QueueRefresh()
    end
  elseif event == "TRADE_SKILL_SHOW" then
    Open()
  elseif event == "TRADE_SKILL_CLOSE" then
    if frame then frame:Hide() end
  else
    QueueRefresh()
  end
end)

-- "/mt" ist von Blizzard belegt (Main Tank)
SLASH_MONEYTALKS1, SLASH_MONEYTALKS2 = "/moneytalks", "/mtalk"
SlashCmdList.MONEYTALKS = function(msg)
  if msg == "reset" then
    -- z. B. nach dem Verlernen eines Berufs, dessen Rezepte sonst gemerkt bleiben
    MoneyTalksRecipes = {}
    print(L.RESET_DONE)
  elseif frame and frame:IsShown() then
    frame:Hide()
  else
    Open()
  end
end
