-- ProfessionalAlts/Scan.lua
-- FAST / NO THROTTLE + PROFESSION INFO FALLBACK + TIER METADATA
-- NEW: stores recipeItemID for each recipeID (critical for reliable tooltips)

local PA = _G.PA

local function PA_Print(msg)
  print("|cffffd200ProfessionalAlts:|r " .. tostring(msg))
end

local lastScanSignature = nil

local function GetCurrentProfessionInfo_Fallback(recipeIDs)
  if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfo then
    local info = C_TradeSkillUI.GetProfessionInfo()
    if type(info) == "table" and info.professionID then
      return info.professionID, info.professionName, info.skillLevel, info.maxSkillLevel
    end
  end

  if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    if type(info) == "table" and info.professionID then
      return info.professionID, info.professionName, info.skillLevel, info.maxSkillLevel
    end
  end

  if recipeIDs and recipeIDs[1] and C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID then
    local info = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeIDs[1])
    if type(info) == "table" and info.professionID then
      return info.professionID, info.professionName, info.skillLevel, info.maxSkillLevel
    end
  end

  return nil
end

local function ParseItemIDFromLink(link)
  if not link then return nil end
  local id = link:match("item:(%d+)")
  return id and tonumber(id) or nil
end

function PA:ScanCurrentProfession(_isThrottledIgnored)
  local rec = PA.GetCharRecord and PA:GetCharRecord() or nil
  if not rec then
    if lastScanSignature ~= "NO_CHAR_RECORD" then
      lastScanSignature = "NO_CHAR_RECORD"
      PA_Print("|cffff0000Scan failed|r (character record missing). Check DB init/load order.")
    end
    return
  end

  rec.level = UnitLevel("player")

  if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo) then
    if lastScanSignature ~= "NO_TRADE_SKILL_API" then
      lastScanSignature = "NO_TRADE_SKILL_API"
      PA_Print("|cffff0000Scan failed|r (TradeSkill API missing).")
    end
    return
  end

  local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
  if type(recipeIDs) ~= "table" or #recipeIDs == 0 then return end

  local skillLineID, profName, rank, maxRank = GetCurrentProfessionInfo_Fallback(recipeIDs)
  if not skillLineID then return end

  profName = profName or ("Profession " .. tostring(skillLineID))
  rank = rank or 0
  maxRank = maxRank or 0

  local tierName, tierSkill, tierMax = nil, nil, nil
  if recipeIDs[1] and C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID then
    local ti = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeIDs[1])
    if type(ti) == "table" then
      tierName = ti.professionName
      tierSkill = ti.skillLevel
      tierMax = ti.maxSkillLevel
    end
  end

  rec.professions = rec.professions or {}
  rec.professions[skillLineID] = rec.professions[skillLineID] or {}
  local p = rec.professions[skillLineID]

  p.name = profName
  p.rank = rank
  p.maxRank = maxRank
  p.tierName = tierName
  p.tierSkill = tierSkill
  p.tierMax = tierMax

  p.knownRecipes = p.knownRecipes or {}
  p.allRecipes = p.allRecipes or {}

  wipe(p.knownRecipes)
  wipe(p.allRecipes)

  local knownCount, totalCount = 0, 0

  for i = 1, #recipeIDs do
    local recipeID = recipeIDs[i]
    totalCount = totalCount + 1

    local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
    local recipeItemID = nil

    -- NEW: attach the recipe-itemID (for tooltip mapping)
    if C_TradeSkillUI.GetRecipeItemLink then
      local link = C_TradeSkillUI.GetRecipeItemLink(recipeID)
      recipeItemID = ParseItemIDFromLink(link)
    end

    if info then
      if info.learned then
        p.knownRecipes[recipeID] = true
        knownCount = knownCount + 1
      end

      p.allRecipes[recipeID] = {
        learned = info.learned and true or false,
        minSkillLineRank = info.minSkillLineRank, -- may be nil
        recipeItemID = recipeItemID,              -- NEW
      }
    else
      p.allRecipes[recipeID] = { recipeItemID = recipeItemID }
    end
  end

  rec.lastScan = time()

  local charKey = PA.GetCharKey and PA:GetCharKey() or (UnitName("player") or "Unknown")
  local sig = table.concat({
    tostring(charKey), tostring(skillLineID),
    tostring(rank), tostring(maxRank),
    tostring(knownCount), tostring(totalCount),
    tostring(tierName or ""), tostring(tierSkill or ""), tostring(tierMax or "")
  }, ":")

  if lastScanSignature ~= sig then
    lastScanSignature = sig
    local tierPart = tierName and (" — tier " .. tostring(tierName) ..
      (tierSkill and tierMax and (" ("..tierSkill.."/"..tierMax..")") or "")) or ""
    PA_Print("FAST scan done: " .. profName ..
      " (rank " .. rank .. "/" .. maxRank .. ")" ..
      tierPart ..
      " — known " .. knownCount .. "/" .. totalCount .. " recipes.")
  end
end
