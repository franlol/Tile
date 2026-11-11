-------------------------------------------------------------------------------
-- Tile - Core
-- Raid frames for healers built for WoW Forever (12.x engine).
-- In instances and in combat the client can return "secret values": they can
-- be passed to widgets (SetValue, SetText, SetTexture...) but cannot be
-- compared or used in math. The whole addon goes through the helpers here.
-------------------------------------------------------------------------------

local ADDON, ns = ...
local L = ns.L
_G.Tile = ns

ns.version = "0.2.0"

-------------------------------------------------------------------------------
-- Brand color: the green of the icon. Change it here and the whole addon
-- (texts, headers, underlines, checkmarks, sliders, hovers...) follows.
-------------------------------------------------------------------------------
ns.ACCENT_HEX = "45c072"
ns.ACCENT = {
    tonumber(ns.ACCENT_HEX:sub(1, 2), 16) / 255,
    tonumber(ns.ACCENT_HEX:sub(3, 4), 16) / 255,
    tonumber(ns.ACCENT_HEX:sub(5, 6), 16) / 255,
}
-- Text in the brand color (for chat and labels)
function ns.AccentText(s)
    return "|cff" .. ns.ACCENT_HEX .. s .. "|r"
end

-------------------------------------------------------------------------------
-- Secret values
-------------------------------------------------------------------------------
local issecretvalue = _G.issecretvalue or function() return false end

function ns.S(v) return issecretvalue(v) end

function ns.R(v)
    if issecretvalue(v) then return nil end
    return v
end

function ns.AnyS(...)
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return true end
    end
    return false
end

-------------------------------------------------------------------------------
-- Utilities
-------------------------------------------------------------------------------
function ns.Print(...)
    print(ns.AccentText("Tile") .. ":", ...)
end

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
ns.CopyDefaults = CopyDefaults

ns.GetSpellName = (C_Spell and C_Spell.GetSpellName) or function(id)
    return (GetSpellInfo and GetSpellInfo(id)) or nil
end

ns.GetSpellIcon = (C_Spell and C_Spell.GetSpellTexture) or function(id)
    return GetSpellTexture and GetSpellTexture(id)
end

function ns.SpellIDFromName(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        if info and info.spellID then return info.spellID end
    elseif GetSpellInfo then
        local id = select(7, GetSpellInfo(name))
        if id then return id end
    end
end

-------------------------------------------------------------------------------
-- Native index name -> every spell ID (every rank)
--
-- A spell's identity is its name, as the client gives it. IDs are not written
-- by hand: the client is asked for them by walking its spells in the
-- background (a few thousand per frame), only for the names the addon uses.
-- The index is saved and rebuilt when the client version changes, so new
-- ranks, new IDs or expansions are picked up on their own.
-------------------------------------------------------------------------------
local SCAN_MAX, SCAN_STEP = 1500000, 5000
local pending = {}   -- [lowercase name] = { left = IDs still to check, ids = {} }
local scanID = 1
local scanFrame = CreateFrame("Frame")
scanFrame:Hide()

local function ClientBuild()
    local version, build = GetBuildInfo()
    return tostring(version) .. "." .. tostring(build)
end

local function Index()
    local idx = ns.db.spellIndex
    if type(idx) ~= "table" or idx.build ~= ClientBuild() then
        idx = { build = ClientBuild(), names = {} }
        ns.db.spellIndex = idx
    end
    return idx
end

scanFrame:SetScript("OnUpdate", function(self)
    local last = math.min(SCAN_MAX, scanID + SCAN_STEP - 1)
    for id = scanID, last do
        local name = ns.GetSpellName(id)
        if name then
            local p = pending[name:lower()]
            if p then p.ids[#p.ids + 1] = id end
        end
    end
    local step = last - scanID + 1
    scanID = last + 1
    if scanID > SCAN_MAX then scanID = 1 end

    local names, finished = Index().names, false
    for lower, p in pairs(pending) do
        p.left = p.left - step
        if p.left <= 0 then
            table.sort(p.ids)
            names[lower] = (#p.ids > 0) and p.ids or false   -- false: does not exist in this client
            pending[lower] = nil
            finished = true
        end
    end
    if finished and ns.OnSpellIndexUpdated then ns.OnSpellIndexUpdated() end
    if not next(pending) then self:Hide() end
end)

-- Every ID for a name (sorted list), or nil while they are still being looked up
function ns.SpellIDs(name)
    if not name or name == "" or not ns.db then return nil end
    local lower = name:lower()
    local v = Index().names[lower]
    if v == nil then
        if not pending[lower] then
            pending[lower] = { left = SCAN_MAX, ids = {} }
            scanFrame:Show()
        end
        return nil
    end
    return v or nil
end

-- One ID for a name (the spellbook one if known, otherwise the first)
function ns.ResolveName(name)
    if not name or name == "" then return nil end
    local id = ns.SpellIDFromName(name)
    if id then return id end
    local ids = ns.SpellIDs(name)
    return ids and ids[1]
end

-- Name of a spell key (number or "n:Name")
function ns.KeyName(key)
    if type(key) == "number" then return ns.GetSpellName(key) end
    if type(key) == "string" then return key:match("^n:(.+)$") or key end
end

-- Every ID of a spell key. Matching is ONLY by ID: the name is only used to
-- find, once, every ID (ranks).
-- pick: IDs chosen by hand ({ [id] = true }). If there are any, only those;
-- if there are none, every ID of the spell.
function ns.KeyIDs(key, pick)
    if type(pick) == "number" then return { pick } end
    if type(pick) == "table" and next(pick) then
        local out = {}
        for id in pairs(pick) do out[#out + 1] = id end
        table.sort(out)
        return out
    end
    local out = {}
    if type(key) == "number" then out[1] = key end
    local name = ns.KeyName(key)
    if name then
        for _, id in ipairs(ns.SpellIDs(name) or {}) do
            if id ~= key then out[#out + 1] = id end
        end
    end
    return out
end

-- Registers a key in a lookup table by ID
function ns.AddSpellKey(byID, _, key, value, rankID)
    for _, id in ipairs(ns.KeyIDs(key, rankID)) do
        if byID[id] == nil then byID[id] = value end
    end
end

-- IDs chosen by hand for a spell of an indicator ({ [id] = true }),
-- or nil when there are none (= every ID of the spell)
function ns.KeyRank(cfg, key)
    local r = cfg.ranks and cfg.ranks[key]
    if type(r) == "table" and next(r) then return r end
end

-- When the index finds new IDs: the indicators are rebuilt with them
function ns.OnSpellIndexUpdated()
    if ns.ClearIconCache then ns.ClearIconCache() end
    if ns.P and ns.header and ns.ApplyProfile then ns.ApplyProfile() end
    if ns.OnSpellResolved then ns.OnSpellResolved() end
end

-- Name and icon of a spell key (number or "n:Name")
-- Icon of a key: many NPC (internal) spells have the question mark icon; the
-- first real icon is searched among every ID with the same name. Display
-- only: detection uses every ID.
local QUESTION_ICON = 134400
local iconCache = {}
local function KeyIcon(key, first)
    local c = iconCache[key]
    if c ~= nil then return c or nil end
    local icon = first and ns.GetSpellIcon(first)
    if not icon or icon == QUESTION_ICON then
        local name = ns.KeyName(key)
        local ids = name and ns.SpellIDs(name)
        if not ids and name and ns.db and Index().names[name:lower()] == nil then
            return icon -- still searching: not cached
        end
        for _, id in ipairs(ids or {}) do
            local t = ns.GetSpellIcon(id)
            if t and t ~= QUESTION_ICON then
                icon = t
                break
            end
        end
    end
    iconCache[key] = icon or false
    return icon
end
ns.QUESTION_ICON = QUESTION_ICON

function ns.SpellKeyInfo(key)
    if type(key) == "number" then
        return ns.GetSpellName(key) or ("?" .. key), KeyIcon(key, key), key
    end
    local name = type(key) == "string" and (key:match("^n:(.+)$") or key) or nil
    if not name then return "?", nil end
    local id = ns.ResolveName(name)
    return (id and ns.GetSpellName(id)) or name, KeyIcon(key, id), id
end

-- the index changed: icons are looked up again
function ns.ClearIconCache() wipe(iconCache) end

-- Turns what the user types into a spell key.
-- A name is stored as a name (any rank works); its icon and ID are looked up
-- in the background.
function ns.ParseSpellInput(txt)
    txt = (txt or ""):trim()
    if txt == "" then return nil end
    local n = tonumber(txt)
    if n then return n end
    local id = ns.SpellIDFromName(txt)
    if id then return id end
    ns.ResolveName(txt)
    return "n:" .. txt
end

-------------------------------------------------------------------------------
-- Queue for things that cannot be done in combat
-------------------------------------------------------------------------------
ns.pending = {}
ns.pendingOrder = {}
function ns.RunOOC(key, func)
    if InCombatLockdown() then
        if not ns.pending[key] then table.insert(ns.pendingOrder, key) end
        ns.pending[key] = func
    else
        func()
    end
end

-------------------------------------------------------------------------------
-- Profiles
-------------------------------------------------------------------------------
function ns.CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

function ns.CharProfiles()
    local c = ns.db.chars[ns.charKey]
    if not c then
        c = {}
        ns.db.chars[ns.charKey] = c
    end
    for _, k in ipairs(ns.SIZE_KEYS) do
        if not c[k] or not ns.db.profiles[c[k]] then c[k] = "Default" end
    end
    return c
end

-- Real group size (ignoring test mode)
function ns.RealSizeKey()
    if IsInRaid() then
        local n = GetNumGroupMembers()
        if n <= 10 then return "raid10" end
        if n <= 20 then return "raid20" end
        return "raid40"
    end
    return "party"
end

function ns.SizeKey()
    if ns.testing then return ns.testSize or "raid20" end
    return ns.RealSizeKey()
end

-- Profile being shown right now. In test mode it is the one being edited in
-- the options: that way every change is visible at once.
function ns.ActiveProfileName()
    if ns.testing and ns.editName and ns.db.profiles[ns.editName] then return ns.editName end
    return ns.CharProfiles()[ns.SizeKey()]
end

-- Profile being edited in the options (the active one by default)
function ns.EditedProfileName()
    if ns.editName and ns.db.profiles[ns.editName] then return ns.editName end
    return ns.ActiveProfileName()
end
function ns.EP() return ns.db.profiles[ns.EditedProfileName()] end

-- Changes the profile being edited; it is remembered per character
function ns.SetEditName(name)
    ns.editName = name
    ns.CharProfiles().editing = name
end

function ns.ActivateProfile(force)
    local name = ns.ActiveProfileName()
    if name == ns.activeName and not force then return end
    ns.activeName = name
    ns.P = ns.db.profiles[name]
    if ns.header and ns.ApplyProfile then ns.ApplyProfile() end
    if ns.OnProfileChanged then ns.OnProfileChanged() end
end

-- After changing an option of the edited profile
function ns.ProfileChanged()
    if ns.EditedProfileName() == ns.activeName then
        ns.ApplyProfile()
    end
end

-------------------------------------------------------------------------------
-- Hide the Blizzard raid frames
-------------------------------------------------------------------------------
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

function ns.HideBlizzard()
    if not ns.db.hideBlizzard then return end
    ns.RunOOC("hideBlizzard", function()
        for _, name in ipairs({ "CompactRaidFrameManager", "CompactRaidFrameContainer", "CompactPartyFrame", "PartyFrame" }) do
            local f = _G[name]
            if f then
                pcall(f.UnregisterAllEvents, f)
                pcall(f.SetParent, f, hiddenParent)
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Load the database
-------------------------------------------------------------------------------
local function LoadDB()
    TileDB = CopyDefaults(ns.dbDefaults, TileDB)
    ns.db = TileDB
    ns.SetLanguage(ns.db.language)
    if not ns.db.profiles.Default then
        ns.db.profiles.Default = ns.NewProfile()
    end
    for _, p in pairs(ns.db.profiles) do ns.FixProfile(p) end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")

ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        LoadDB()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        ns.charKey = ns.CharKey()
        local editing = ns.CharProfiles().editing
        ns.editName = editing and ns.db.profiles[editing] and editing or nil
        ns.activeName = ns.ActiveProfileName()
        ns.P = ns.db.profiles[ns.activeName]
        ns.CreateFrames()
        -- test mode is remembered too
        if ns.db.testing then ns.ToggleTest(true, ns.db.testSize) end
        ns.HideBlizzard()
        ns.Print(L["loaded. Type |cffffff00/tile|r to open the options."])
    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        if ns.header then ns.ActivateProfile() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- frames cannot be moved in combat: lock them and unlock them again after
        if ns.db and not ns.db.locked then
            ns.SetLocked(true)
            ns.unlockAfterCombat = true
            ns.Print(L["frames locked when entering combat."])
        end
        if ns.UpdateAllButtons then ns.UpdateAllButtons() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.unlockAfterCombat then
            ns.unlockAfterCombat = nil
            ns.SetLocked(false)
        end
        local order = ns.pendingOrder
        ns.pendingOrder = {}
        for _, key in ipairs(order) do
            local func = ns.pending[key]
            ns.pending[key] = nil
            if func then func() end
        end
        if ns.UpdateAllButtons then ns.UpdateAllButtons() end
    end
end)

-------------------------------------------------------------------------------
-- Commands
-------------------------------------------------------------------------------
SLASH_TILE1 = "/tile"
SlashCmdList.TILE = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "lock" or msg == "bloquear" then
        ns.SetLocked(true)
    elseif msg == "unlock" or msg == "mover" or msg == "desbloquear" then
        ns.SetLocked(false)
    elseif msg == "test" or msg == "prueba" then
        ns.ToggleTest()
    elseif msg == "estado" or msg == "status" then
        ns.Print((L["profile: %s (%s)"]):format(tostring(ns.activeName), L[ns.SIZE_NAMES[ns.SizeKey()] or "?"]))
    elseif msg == "reset" then
        ns.RunOOC("reset", function()
            ns.P.pos = ns.DeepCopy(ns.profileDefaults.pos)
            ns.ApplyPositions()
            ns.Print(L["positions reset."])
        end)
    else
        ns.ToggleOptions()
    end
end
