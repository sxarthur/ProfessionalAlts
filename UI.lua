-- ProfessionalAlts/UI.lua
-- Dashboard updated:
-- - Shows tier info per saved profession (e.g. Herbalism (Dragon Isles))
-- - Live debug now labels Base vs Tier correctly
-- - Removes duplicate GetAllRecipeIDs count output

local PA = _G.PA

local function PA_Print(msg)
  print("|cffffd200ProfessionalAlts:|r " .. tostring(msg))
end

local function FormatAgo(ts)
  if not ts or ts == 0 then return "never" end
  local now = time()
  local d = now - ts
  if d < 60 then return d .. "s ago" end
  if d < 3600 then return math.floor(d / 60) .. "m ago" end
  return math.floor(d / 3600) .. "h ago"
end

local frame = CreateFrame("Frame", "ProfessionalAltsFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(560, 420)
frame:SetPoint("CENTER")
frame:Hide()
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame.TitleText:SetText("ProfessionalAlts")

local rescanBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
rescanBtn:SetSize(110, 22)
rescanBtn:SetPoint("TOPRIGHT", -40, -30)
rescanBtn:SetText("Rescan")
rescanBtn:SetScript("OnClick", function()
  if PA and PA.ScanCurrentProfession then
    PA_Print("Rescan requested (open a profession window for best results).")
    PA:ScanCurrentProfession(false)
    C_Timer.After(0, function() if frame:IsShown() then frame:Update() end end)
  end
end)

local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
refreshBtn:SetSize(110, 22)
refreshBtn:SetPoint("RIGHT", rescanBtn, "LEFT", -8, 0)
refreshBtn:SetText("Refresh")
refreshBtn:SetScript("OnClick", function()
  frame:Update()
end)

local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 14, -60)
scrollFrame:SetPoint("BOTTOMRIGHT", -32, 14)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
text:SetPoint("TOPLEFT")
text:SetJustifyH("LEFT")
text:SetJustifyV("TOP")
text:SetWidth(520)

local function SafeRecipeIDs()
  if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
    local ids = C_TradeSkillUI.GetAllRecipeIDs()
    if type(ids) == "table" then return ids end
  end
  return nil
end

function frame:Update()
  if not ProfessionalAltsDB or not ProfessionalAltsDB.realms then
    text:SetText("DB not initialized yet. Try /reload or relog.\n")
    return
  end

  local realm = (PA and PA.GetRealm and PA:GetRealm()) or GetRealmName() or "UnknownRealm"
  local charKey = (PA and PA.GetCharKey and PA:GetCharKey()) or ((UnitName("player") or "Unknown") .. "-" .. realm)

  local realmRec = ProfessionalAltsDB.realms[realm]
  local charRec = realmRec and realmRec.chars and realmRec.chars[charKey] or nil

  local lines = {}
  table.insert(lines, "|cffffd200Status|r")
  table.insert(lines, "Realm: " .. tostring(realm))
  table.insert(lines, "Character: " .. tostring(charKey))
  table.insert(lines, "Player level: " .. tostring(UnitLevel("player")))
  table.insert(lines, "")

  if not charRec then
    table.insert(lines, "|cffff0000No character record found in DB.|r")
    table.insert(lines, "Check .toc load order and make sure PLAYER_LOGIN ran.")
    text:SetText(table.concat(lines, "\n"))
    content:SetHeight(text:GetStringHeight() + 20)
    return
  end

  table.insert(lines, "|cffffd200Saved snapshot|r")
  table.insert(lines, "Last scan (char): " .. FormatAgo(charRec.lastScan))
  table.insert(lines, "")

  local profs = charRec.professions or {}
  local any = false
  for skillLineID, prof in pairs(profs) do
    any = true

    local knownCount = 0
    local totalCount = 0
    if prof.knownRecipes then for _ in pairs(prof.knownRecipes) do knownCount = knownCount + 1 end end
    if prof.allRecipes then for _ in pairs(prof.allRecipes) do totalCount = totalCount + 1 end end

    local title = tostring(prof.name or "Unknown")
    if prof.tierName then
      title = title .. " |cffaaaaaa(" .. tostring(prof.tierName) .. ")|r"
    end

    table.insert(lines, ("|cff00c0ff%s|r  (skillLineID %s)"):format(title, tostring(skillLineID)))
    table.insert(lines, ("  Rank: %s/%s"):format(tostring(prof.rank or 0), tostring(prof.maxRank or 0)))

    if prof.tierSkill and prof.tierMax then
      table.insert(lines, ("  Tier skill: %s/%s"):format(tostring(prof.tierSkill), tostring(prof.tierMax)))
    end

    table.insert(lines, ("  Recipes: known %d / total %d"):format(knownCount, totalCount))
    table.insert(lines, "")
  end

  if not any then
    table.insert(lines, "|cffff8040No professions saved yet for this character.|r")
    table.insert(lines, "Open a profession window to allow scanning.")
    table.insert(lines, "")
  end

  -- Live debug
  table.insert(lines, "|cffffd200Live debug (right now)|r")

  local gi = (C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfo) and C_TradeSkillUI.GetProfessionInfo() or nil
  if type(gi) == "table" then
    table.insert(lines, "GetProfessionInfo(): professionID=" .. tostring(gi.professionID) ..
      " name=" .. tostring(gi.professionName) ..
      " skill=" .. tostring(gi.skillLevel) .. "/" .. tostring(gi.maxSkillLevel))
  else
    table.insert(lines, "GetProfessionInfo(): |cffff8040nil|r (unreliable on this build)")
  end

  local bi = (C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo) and C_TradeSkillUI.GetBaseProfessionInfo() or nil
  if type(bi) == "table" then
    table.insert(lines, "Base (selected): professionID=" .. tostring(bi.professionID) ..
      " name=" .. tostring(bi.professionName) ..
      " skill=" .. tostring(bi.skillLevel) .. "/" .. tostring(bi.maxSkillLevel))
  else
    table.insert(lines, "Base (selected): |cffff8040nil|r")
  end

  local ids = SafeRecipeIDs()
  local count = ids and #ids or nil
  table.insert(lines, "GetAllRecipeIDs() count: " .. tostring(count or "nil"))

  local firstRecipeID = ids and ids[1] or nil
  if firstRecipeID and C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID then
    local ri = C_TradeSkillUI.GetProfessionInfoByRecipeID(firstRecipeID)
    if type(ri) == "table" then
      table.insert(lines, "Tier (by recipe): professionID=" .. tostring(ri.professionID) ..
        " name=" .. tostring(ri.professionName) ..
        " skill=" .. tostring(ri.skillLevel) .. "/" .. tostring(ri.maxSkillLevel))
    else
      table.insert(lines, "Tier (by recipe): |cffff8040nil|r")
    end
  else
    table.insert(lines, "Tier (by recipe): |cffff8040not available / no recipeIDs|r")
  end

  text:SetText(table.concat(lines, "\n"))
  content:SetHeight(text:GetStringHeight() + 40)
end

function PA:ToggleUI()
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
    frame:Update()
  end
end

frame:SetScript("OnShow", function() frame:Update() end)
