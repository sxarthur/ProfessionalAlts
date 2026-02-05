-- ProfessionalAlts/Tooltip.lua
-- HYBRID recipe tooltip:
-- 1) Preferred: itemID -> recipeID via scanned recipeItemID index (accurate, no unrelated items)
-- 2) Fallback (when not indexed yet): only for itemType == "Recipe":
--    try GetItemSpell / tooltip spell link, and show guidance if still missing.

local PA = _G.PA

local function PA_Print(msg)
  print("|cffffd200ProfessionalAlts:|r " .. tostring(msg))
end

local didInitPrint = false
local function InitPrintOnce()
  if didInitPrint then return end
  didInitPrint = true
  PA_Print("Tooltip module loaded.")
end

local function GetRealmRecord()
  if not ProfessionalAltsDB or not ProfessionalAltsDB.realms then return nil end
  local realm = (PA and PA.GetRealm and PA:GetRealm()) or GetRealmName()
  if not realm then return nil end
  local r = ProfessionalAltsDB.realms[realm]
  if not r or not r.chars then return nil end
  return r
end

local function TooltipHasProfessionalAlts(tooltip)
  if not tooltip or not tooltip.GetName then return false end
  local name = tooltip:GetName()
  if not name then return false end
  local n = tooltip:NumLines() or 0
  for i = 1, n do
    local fs = _G[name .. "TextLeft" .. i]
    if fs and fs.GetText then
      local t = fs:GetText()
      if t and t:find("ProfessionalAlts", 1, true) then
        return true
      end
    end
  end
  return false
end

local function AddHeader(tooltip)
  tooltip:AddLine(" ")
  tooltip:AddLine("|cffffd200ProfessionalAlts|r")
end

-- ---------- Index: itemID/spellID -> hits (rebuilt after scans) ----------

local indexCache = { lastSignature = nil, map = nil, spellMap = nil }

local function BuildRealmSignature(realmRec)
  if not realmRec or not realmRec.chars then return "none" end
  local parts = {}
  for charKey, rec in pairs(realmRec.chars) do
    table.insert(parts, tostring(charKey) .. ":" .. tostring(rec.lastScan or 0))
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

local indexCache = { lastSignature = nil, map = nil }

local function BuildRealmSignature(realmRec)
  if not realmRec or not realmRec.chars then return "none" end
  local parts = {}
  for charKey, rec in pairs(realmRec.chars) do
    table.insert(parts, tostring(charKey) .. ":" .. tostring(rec.lastScan or 0))
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

local function RebuildIndexIfNeeded(realmRec)
  local sig = BuildRealmSignature(realmRec)
  if indexCache.map and indexCache.lastSignature == sig then return end

  local map = {}
  local spellMap = {}
  if realmRec and realmRec.chars then
    for charKey, rec in pairs(realmRec.chars) do
      for _, prof in pairs(rec.professions or {}) do
        if prof and prof.allRecipes then
          for recipeID, entry in pairs(prof.allRecipes) do
            local itemID = entry and entry.recipeItemID
            if itemID then
              map[itemID] = map[itemID] or {}
              table.insert(map[itemID], { recipeID = recipeID, prof = prof, charKey = charKey })
            end
            local spellID = entry and entry.spellID
            if spellID then
              spellMap[spellID] = spellMap[spellID] or {}
              table.insert(spellMap[spellID], { recipeID = recipeID, prof = prof, charKey = charKey })
            end
          end
        end
      end
    end
  end

  indexCache.lastSignature = sig
  indexCache.map = map
  indexCache.spellMap = spellMap
end

-- ---------- Fallback: resolve a "maybe recipeID" from taught spell links ------

local function ResolveSpellID_FromTooltipData(itemID)
  if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
  local tip = C_TooltipInfo.GetItemByID(itemID)
  if not tip or not tip.lines then return nil end
  for _, line in ipairs(tip.lines) do
    local left = line.leftText
    local right = line.rightText
    if type(left) == "string" then
      local sid = left:match("|Hspell:(%d+)")
      if sid then return tonumber(sid) end
    end
    if type(right) == "string" then
      local sid = right:match("|Hspell:(%d+)")
      if sid then return tonumber(sid) end
    end
  end
  return nil
end

local function LooksLikeRecipeID(maybeRecipeID)
  if not maybeRecipeID then return false end
  if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo) then return false end
  local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, maybeRecipeID)
  return ok and type(info) == "table"
end

local function ResolveFallbackRecipeID(itemID)
  local _, sid = GetItemSpell(itemID)
  if LooksLikeRecipeID(sid) then return sid end
  sid = ResolveSpellID_FromTooltipData(itemID)
  if LooksLikeRecipeID(sid) then return sid end
  return nil
end

-- ---------- Render using a prof+recipeID ------------------------------------

local function AddStatusLinesWithoutHeader(tooltip, prof, recipeID, charLabel)
  local function RenderLine(prefix, label)
    if charLabel then
      tooltip:AddLine(prefix .. " — " .. tostring(charLabel) .. " · " .. label)
    else
      tooltip:AddLine(prefix .. " — " .. label)
    end
  end

  local entry = prof.allRecipes and prof.allRecipes[recipeID] or nil
  local learned = (prof.knownRecipes and prof.knownRecipes[recipeID]) or (entry and entry.learned) or false
  local required = entry and entry.minSkillLineRank or 0

  local label = tostring(prof.name or "Unknown")
  if prof.tierName then label = label .. " (" .. tostring(prof.tierName) .. ")" end

  if learned then
    RenderLine("|cff00ff00Known|r", label)
    return
  end

  if not required or required <= 0 then
    RenderLine("|cff00c0ffUnlearned|r", label)
    tooltip:AddLine("|cffaaaaaaRequirement unknown (scan more tiers for better info).|r")
    return
  end

  local rank = prof.rank or 0
  if rank >= required then
    RenderLine("|cff00c0ffLearnable now|r", label)
    tooltip:AddLine("|cffaaaaaaYour skill: " .. rank .. " / Required: " .. required .. "|r")
  else
    local diff = required - rank
    RenderLine("|cffff8040Learnable later|r", label)
    tooltip:AddLine("|cffaaaaaaNeed +" .. diff .. " skill (" .. rank .. " → " .. required .. ")|r")
  end
end

local function FindRecipeHits(realmRec, recipeID)
  local hits = {}
  if not realmRec or not realmRec.chars then return hits end
  for charKey, rec in pairs(realmRec.chars) do
    for _, prof in pairs(rec.professions or {}) do
      if prof and prof.allRecipes and prof.allRecipes[recipeID] then
        table.insert(hits, { recipeID = recipeID, prof = prof, charKey = charKey })
      end
    end
  end
  return hits
end

local function NormalizeCharLabel(charKey)
  if not charKey then return nil end
  return charKey:match("^([^-]+)") or charKey
end

-- ---------- Hook -------------------------------------------------------------

local function ResolveItemIDFromTooltip(tooltip, tooltipData)
  local itemID = tooltipData and (tooltipData.id or tooltipData.itemID)
  if not itemID and tooltipData and tooltipData.hyperlink then
    local parsed = tooltipData.hyperlink:match("item:(%d+)")
    itemID = parsed and tonumber(parsed) or nil
  end
  if not itemID and tooltip and tooltip.GetItem then
    local _, link = tooltip:GetItem()
    if link then
      local parsed = link:match("item:(%d+)")
      itemID = parsed and tonumber(parsed) or nil
    end
  end
  return itemID
end

local function IsRecipeItem(itemID)
  if not itemID then return false end
  if C_Item and C_Item.GetItemInfoInstant then
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    if classID == 9 then
      return true
    end
  end
  local itemType = select(6, GetItemInfo(itemID))
  return itemType == "Recipe"
end

local function OnItemTooltip(tooltip, tooltipData)
  InitPrintOnce()

  local itemID = ResolveItemIDFromTooltip(tooltip, tooltipData)
  if not itemID then return end

  local realmRec = GetRealmRecord()
  if not realmRec then return end

  RebuildIndexIfNeeded(realmRec)

  -- 1) Preferred: exact match via scanned recipeItemID
  local hits = indexCache.map and indexCache.map[itemID] or nil
  if hits and #hits > 0 then
    if TooltipHasProfessionalAlts(tooltip) then return end
    AddHeader(tooltip)
    for _, hit in ipairs(hits) do
      AddStatusLinesWithoutHeader(tooltip, hit.prof, hit.recipeID, NormalizeCharLabel(hit.charKey))
      AddStatusLinesWithoutHeader(tooltip, hit.prof, hit.recipeID, hit.charKey)
    end
    return
  end

  -- 2) Fallback: only show for actual recipe items
  if not IsRecipeItem(itemID) then
    return
  end

  local rid = ResolveFallbackRecipeID(itemID)
  if not rid then
    local _, spellID = GetItemSpell(itemID)
    local spellHits = spellID and indexCache.spellMap and indexCache.spellMap[spellID] or nil
    if spellHits and #spellHits > 0 then
      if TooltipHasProfessionalAlts(tooltip) then return end
      AddHeader(tooltip)
      for _, hit in ipairs(spellHits) do
        AddStatusLinesWithoutHeader(tooltip, hit.prof, hit.recipeID, NormalizeCharLabel(hit.charKey))
      end
      return
    end
    if TooltipHasProfessionalAlts(tooltip) then return end
    AddHeader(tooltip)
    tooltip:AddLine("|cffff8040Couldn't resolve recipe ID from this item.|r")
    tooltip:AddLine("|cffaaaaaaOpen the correct profession tier and /profalts scan.|r")
    return
  end

  -- Try to locate this recipeID in any saved profession (all chars)
  local fallbackHits = FindRecipeHits(realmRec, rid)
  if #fallbackHits > 0 then
    if TooltipHasProfessionalAlts(tooltip) then return end
    AddHeader(tooltip)
    for _, hit in ipairs(fallbackHits) do
      AddStatusLinesWithoutHeader(tooltip, hit.prof, hit.recipeID, NormalizeCharLabel(hit.charKey))
      AddStatusLinesWithoutHeader(tooltip, hit.prof, hit.recipeID, hit.charKey)
    end
    return
  end

  if TooltipHasProfessionalAlts(tooltip) then return end
  AddHeader(tooltip)
  tooltip:AddLine("|cffff8040No scan data for this recipe yet.|r")
  tooltip:AddLine("|cffaaaaaaSwitch to the tier it belongs to and /profalts scan.|r")
end

local function OnSpellTooltip(tooltip, tooltipData)
  InitPrintOnce()

  local recipeID = tooltipData and (tooltipData.id or tooltipData.spellID)
  if not recipeID then return end
  if not LooksLikeRecipeID(recipeID) then return end

  local realmRec = GetRealmRecord()
  if not realmRec then return end

  local hits = LooksLikeRecipeID(recipeID) and FindRecipeHits(realmRec, recipeID) or {}
  local hits = FindRecipeHits(realmRec, recipeID)
  if #hits > 0 then
    if TooltipHasProfessionalAlts(tooltip) then return end
    AddHeader(tooltip)
    for _, hit in ipairs(hits) do
      AddStatusLinesWithoutHeader(tooltip, hit.prof, hit.recipeID, NormalizeCharLabel(hit.charKey))
    end
    return
  end

  RebuildIndexIfNeeded(realmRec)
  local spellHits = indexCache.spellMap and indexCache.spellMap[recipeID] or nil
  if spellHits and #spellHits > 0 then
    if TooltipHasProfessionalAlts(tooltip) then return end
    AddHeader(tooltip)
    for _, hit in ipairs(spellHits) do
      AddStatusLinesWithoutHeader(tooltip, hit.prof, hit.recipeID, NormalizeCharLabel(hit.charKey))
      AddStatusLinesWithoutHeader(tooltip, hit.prof, hit.recipeID, hit.charKey)
    end
    return
  end

  if TooltipHasProfessionalAlts(tooltip) then return end
  AddHeader(tooltip)
  tooltip:AddLine("|cffff8040No scan data for this recipe yet.|r")
  tooltip:AddLine("|cffaaaaaaSwitch to the tier it belongs to and /profalts scan.|r")
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, tooltipData)
    OnItemTooltip(tooltip, tooltipData)
    C_Timer.After(0, function()
      if tooltip and tooltip:IsShown() then
        OnItemTooltip(tooltip, tooltipData)
      end
    end)
  end)
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, tooltipData)
    OnSpellTooltip(tooltip, tooltipData)
    C_Timer.After(0, function()
      if tooltip and tooltip:IsShown() then
        OnSpellTooltip(tooltip, tooltipData)
      end
    end)
  end)
else
  PA_Print("TooltipDataProcessor not available; recipe tooltips disabled.")
end
