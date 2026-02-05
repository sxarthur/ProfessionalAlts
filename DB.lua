ProfessionalAltsDB = ProfessionalAltsDB or {}

local PA = PA or {}
_G.PA = PA

function PA:GetRealm()
  return GetRealmName() or "UnknownRealm"
end

function PA:GetCharKey()
  local name = UnitName("player") or "Unknown"
  local realm = PA:GetRealm()
  return name .. "-" .. realm
end

function PA:InitDB()
  ProfessionalAltsDB.realms = ProfessionalAltsDB.realms or {}
  local realm = PA:GetRealm()
  ProfessionalAltsDB.realms[realm] = ProfessionalAltsDB.realms[realm] or { chars = {} }

  local charKey = PA:GetCharKey()
  local chars = ProfessionalAltsDB.realms[realm].chars
  chars[charKey] = chars[charKey] or {
    class = select(2, UnitClass("player")),
    level = UnitLevel("player"),
    professions = {},     -- [skillLineID] = { name, rank, maxRank, knownRecipes = { [recipeSpellID]=true }, ... }
    lastScan = 0,
  }
end

function PA:GetCharRecord()
  local realm = PA:GetRealm()
  local charKey = PA:GetCharKey()
  return ProfessionalAltsDB.realms[realm].chars[charKey]
end
