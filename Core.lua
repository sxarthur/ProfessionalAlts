-- ProfessionalAlts/Core.lua
-- Updated to match FAST scanning behavior:
-- - Calls ScanCurrentProfession() aggressively on profession UI events
-- - Adds safe prints + slash commands (/profalts, /palts)
-- - No throttling flags needed (Scan.lua ignores them anyway)

local PA = _G.PA
local addonName = ...

local function PA_Print(msg)
  print("|cffffd200ProfessionalAlts:|r " .. tostring(msg))
end

-- Slash commands (avoid collisions)
SLASH_PROFESSIONALALTS1 = "/profalts"
SLASH_PROFESSIONALALTS2 = "/palts"


SlashCmdList["PROFESSIONALALTS"] = function(msg)
  msg = tostring(msg or ""):lower()
  msg = msg:gsub("^%s+", ""):gsub("%s+$", "")

  if msg == "" or msg == "help" then
    PA_Print("Commands: /profalts scan | /profalts scanall | /profalts ui | /profalts help")
    return
  end

  if msg == "scan" then
    if PA and PA.ScanCurrentProfession then
      PA_Print("Manual FAST scan requested (profession window must be open).")
      PA:ScanCurrentProfession(false)
    else
      PA_Print("|cffff0000Scan function not found|r (addon not fully loaded?)")
    end
    return
  end

  if msg == "scanall" then
    if PA and PA.ScanAllTiersForCurrentProfession then
      PA:ScanAllTiersForCurrentProfession()
    else
      PA_Print("ScanAll not available (missing function).")
    end
    return
  end

  if msg == "ui" then
    if PA and PA.ToggleUI then
      PA:ToggleUI()
    else
      PA_Print("UI not loaded. Check that UI.lua is listed in the .toc.")
    end
    return
  end

  PA_Print("Unknown command: " .. msg .. " (try /profalts help)")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LEVEL_UP")

-- Profession UI events
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")

-- Optional: some builds fire these when switching profession tabs/skill lines
f:RegisterEvent("TRADE_SKILL_CLOSE")

f:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    if PA and PA.InitDB then
      PA:InitDB()
      local rec = PA.GetCharRecord and PA:GetCharRecord() or nil
      if rec then
        rec.level = UnitLevel("player")
      end
      PA_Print("Loaded (FAST scan mode). Open a profession to scan.")
      PA_Print("Slash commands: /profalts, /palts")
    else
      PA_Print("|cffff0000ERROR|r: PA table/InitDB missing. Check .toc load order (DB.lua first).")
    end
    return
  end

  if event == "PLAYER_LEVEL_UP" then
    local rec = PA and PA.GetCharRecord and PA:GetCharRecord() or nil
    if rec then
      rec.level = UnitLevel("player")
    end
    return
  end

  if event == "TRADE_SKILL_SHOW" then
    -- Immediate scan when the profession UI opens
    if PA and PA.ScanCurrentProfession then
      PA:ScanCurrentProfession(false)
    end
    return
  end

  if event == "TRADE_SKILL_LIST_UPDATE" then
    -- Aggressive: rescan every list update (can lag)
    if PA and PA.ScanCurrentProfession then
      PA:ScanCurrentProfession(false)
    end
    return
  end

  if event == "TRADE_SKILL_CLOSE" then
    -- No action needed, but you can print for debugging if you want
    return
  end
end)
