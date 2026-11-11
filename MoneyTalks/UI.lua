local ADDON, ns = ...

local ROW_HEIGHT, NAME_WIDTH, MONEY_WIDTH = 16, 190, 85
local WIDTH = NAME_WIDTH + 3 * MONEY_WIDTH + 50

local function AHPrice(itemID)
  return Auctionator.API.v1.GetAuctionPriceByItemID(ADDON, itemID)
end

-- Auctionator merkt sich Haendlerpreise, sobald man den Haendler einmal besucht hat.
local function VendorPrice(itemID)
  return Auctionator.API.v1.GetVendorPriceByItemID(ADDON, itemID)
end

local function Money(copper)
  if not copper then return GRAY_FONT_COLOR:WrapTextInColorCode("?") end
  copper = math.floor(copper)
  if copper < 0 then
    return RED_FONT_COLOR:WrapTextInColorCode("-" .. GetMoneyString(-copper, true))
  end
  return GetMoneyString(copper, true)
end

-- Liest alle gelernten Rezepte des gerade offenen Berufs.
local function ReadRecipes()
  local rows = {}
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
      rows[#rows + 1] = {
        name = info.name,
        recipe = recipe,
        result = ns.Evaluate(recipe, AHPrice, VendorPrice),
      }
    end
  end
  ns.SortByProfit(rows)
  return rows
end

local frame, content
local rowFrames = {}

local function Column(parent, width, justify, anchorTo)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetWidth(width)
  fs:SetJustifyH(justify)
  fs:SetWordWrap(false)
  if anchorTo then
    fs:SetPoint("LEFT", anchorTo, "RIGHT")
  else
    fs:SetPoint("LEFT")
  end
  return fs
end

local function CreateRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(WIDTH - 50, ROW_HEIGHT)
  row.name = Column(row, NAME_WIDTH, "LEFT")
  row.cost = Column(row, MONEY_WIDTH, "RIGHT", row.name)
  row.value = Column(row, MONEY_WIDTH, "RIGHT", row.cost)
  row.profit = Column(row, MONEY_WIDTH, "RIGHT", row.value)
  return row
end

local function ShowTooltip(row)
  local data = row.data
  if not data then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(data.name)
  for _, r in ipairs(data.result.reagents) do
    local name = C_Item.GetItemNameByID(r.itemID) or ("item:" .. r.itemID)
    GameTooltip:AddDoubleLine(
      r.qty .. "x " .. name .. (r.fromVendor and " (Händler)" or ""),
      Money(r.unit and r.unit * r.qty), 1, 1, 1, 1, 1, 1)
  end
  GameTooltip:AddDoubleLine("Materialkosten", Money(data.result.cost))
  GameTooltip:AddDoubleLine("AH-Wert (nach 5 % Gebühr)", Money(data.result.value))
  GameTooltip:AddDoubleLine("Gewinn", Money(data.result.profit))
  GameTooltip:Show()
end

local function Refresh()
  local rows = ReadRecipes()
  for i, data in ipairs(rows) do
    local row = rowFrames[i]
    if not row then
      row = CreateRow(content)
      row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
      row:EnableMouse(true)
      row:SetScript("OnEnter", ShowTooltip)
      row:SetScript("OnLeave", GameTooltip_Hide)
      rowFrames[i] = row
    end
    row.data = data
    row.name:SetText(data.name)
    -- "+" = mindestens ein Material ohne Preis, die Kosten sind also zu niedrig
    row.cost:SetText(Money(data.result.cost) .. (data.result.costIncomplete and "+" or ""))
    row.value:SetText(Money(data.result.value))
    row.profit:SetText(Money(data.result.profit))
    row:Show()
  end
  for i = #rows + 1, #rowFrames do
    rowFrames[i]:Hide()
  end
  content:SetHeight(math.max(#rows * ROW_HEIGHT, 1))
end

local function CreateMainFrame()
  frame = CreateFrame("Frame", "MoneyTalksFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(WIDTH, 420)
  if ProfessionsFrame then
    frame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 4, 0)
  else
    frame:SetPoint("CENTER")
  end
  if frame.TitleText then frame.TitleText:SetText("MoneyTalks") end

  local header = CreateRow(frame)
  header:SetPoint("TOPLEFT", 14, -30)
  header.name:SetText("Rezept")
  header.cost:SetText("Mats")
  header.value:SetText("AH-Wert")
  header.profit:SetText("Gewinn")

  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 14, -50)
  scroll:SetPoint("BOTTOMRIGHT", -32, 10)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(WIDTH - 50, 1)
  scroll:SetScrollChild(content)

  -- neu rechnen, sobald Auctionator nach einem Scan neue Preise hat
  Auctionator.API.v1.RegisterForDBUpdate(ADDON, function()
    if frame:IsShown() then Refresh() end
  end)
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
events:SetScript("OnEvent", function(_, event)
  if event == "TRADE_SKILL_SHOW" then
    Open()
  elseif event == "TRADE_SKILL_CLOSE" then
    if frame then frame:Hide() end
  elseif frame and frame:IsShown() then
    Refresh()
  end
end)

SLASH_MONEYTALKS1, SLASH_MONEYTALKS2 = "/mt", "/moneytalks"
SlashCmdList.MONEYTALKS = function()
  if frame and frame:IsShown() then frame:Hide() else Open() end
end
