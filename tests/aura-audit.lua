-- Behavioral tests with a simulated client. These do not validate WoW's secure
-- environment, actual graphics, real events, or the availability of its APIs.
local combat, apiMode = false, "blocked"
local nativeFrames, queries, passed = {}, 0, 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end
local function object(parent)
    local o = { parent = parent, shown = true, registered = {}, regions = {}, scripts = {} }
    local methods = {
        GetParent = function(self) return self.parent end,
        GetFrameLevel = function() return 10 end,
        GetFont = function() return "TestFont" end,
        GetWidth = function(self) return self.width or 76 end,
        GetHeight = function(self) return self.height or 42 end,
        GetSize = function(self) return self.width or 76, self.height or 42 end,
        GetStatusBarTexture = function(self)
            self.barTexture = self.barTexture or object(self)
            return self.barTexture
        end,
        Hide = function(self) self.shown = false end,
        Show = function(self) self.shown = true end,
        SetShown = function(self, v) self.shown = v end,
        IsShown = function(self) return self.shown end,
        IsVisible = function(self) return self.shown end,
        SetUnit = function(self, v) self.unit = v end,
        SetTexture = function(self, v) self.texture = v end,
        SetAlpha = function(self, v) self.alpha = v end,
        SetText = function(self, v) self.text = v end,
        SetTextColor = function(self, ...) self.textColor = { ... } end,
        SetStatusBarColor = function(self, ...) self.barColor = { ... } end,
        SetSize = function(self, w, h) self.width, self.height = w, h end,
        SetPoint = function(self, ...) self.lastPoint = { ... } end,
        SetScript = function(self, event, fn) self.scripts[event] = fn end,
        GetCountdownFontString = function() return nil end,
    }
    methods.CreateTexture = function(self)
        local t = object(self)
        self.regions[#self.regions + 1] = t
        return t
    end
    methods.CreateFontString = methods.CreateTexture
    methods.AddDispelTypeTexture = function(self, tex, options)
        self.registered[#self.registered + 1] = { tex = tex, options = options }
    end
    methods.AddAuraSlot = function(self, key, filter, options)
        self.filter, self.options, self.slot = filter, options, object(self)
        options.initializeFrame(self.slot)
    end
    methods.AddAuraGroup = function(self, key, filter, options)
        self.filter, self.options, self.group = filter, options, {}
        for i = 1, options.maxFrameCount do
            self.group[i] = object(self)
            options.initializeFrame(self.group[i])
        end
    end
    return setmetatable(o, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if key:match("^Set") or key == "EnableMouse" or key == "ClearAllPoints" or key == "RegisterEvent" then return function() end end
    end })
end
CreateFrame = function(kind, name, parent)
    local o = object(parent)
    if kind == "AuraContainer" then nativeFrames[#nativeFrames + 1] = o end
    return o
end
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end
InCombatLockdown = function() return combat end
GetTime = function() return 10 end
GetBuildInfo = function() return "test-client", "test-build" end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
UIParent = object()
Enum = { CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 1, CustomAsset = 2, Icon = 3 } }
AnchorUtil = { FlowLayoutAxis = { Horizontal = 1, Vertical = 2 }, FlowDirection = { Left = 1, Right = 2, Up = 3, Down = 4 } }
C_UnitAuras = {
    GetUnitAuraInstanceIDs = function()
        queries = queries + 1
        if apiMode == "blocked" then error("Auras cannot be accessed when secret") end
        if apiMode == "partial" or apiMode == "present" then return { 100 } end
        if apiMode == "truncated" then local ids = {} for i = 1, 41 do ids[i] = i end return ids end
        return {}
    end,
    GetAuraDataByAuraInstanceID = function(_, id)
        if apiMode == "partial" then error("instance unreadable") end
        return { auraInstanceID = id, spellId = 123, icon = 42, name = "Test Aura", applications = 2, duration = 10, expirationTime = 20 }
    end,
    GetUnitAuras = function() queries = queries + 1 error("blocked bulk read") end,
    GetAuraDataByIndex = function() queries = queries + 1 error("blocked index read") end,
}
local ns = {
    db = { profiles = {} }, P = {}, compiled = {},
    S = function(value) return type(value) == "table" and value.secret == true end,
    R = function(value) if type(value) == "table" and value.secret then return nil end return value end,
    AnyS = function() return false end,
    ClearHighlight = function() end, ApplyHighlight = function() end,
    StyleActive = function(s) return s and (s.glow ~= "none" or s.tint or s.border or s.pulse or s.sound ~= "none" or s.scale ~= 1) end,
    StyleText = function() end, ColorText = function() end,
    Print = function() end, MarkSecret = function() end,
    KeyIDs = function(key) return { key } end, AddSpellKey = function() end,
    ClassColorOf = function() return 1, 1, 1 end,
}
-- LOAD_ADDON_HERE

local function cfg(extra)
    local c = ns.FixIndicator(ns.DeepCopy(extra or {}))
    c.name = c.name or "Test"
    return c
end
local parent = object()
local b = { unit = "player", overlay = parent, ind = {}, pool = {} }
local typed = cfg { kind = "aura", watch = "debuffTypes", type = "overlay", dispelTypes = { Poison = true, Magic = false, Disease = false, Curse = false } }
local list = cfg { kind = "debuffs", type = "icons", onlyDispellable = false }
local w, lw = object(parent), object(parent)
w.wtype, lw.wtype = "overlay", "icons"
b.ind = { w, lw }
ns.BuildNativeIndicator(b, w, typed)
ns.BuildNativeIndicator(b, lw, list)
local native, listNative = w.nativeDispel, lw.nativeDispel
check(native and native.filter == "HARMFUL", "Hunter must not require player dispel capability")
check(native.options.candidateFilters.includeDispelTypes.Poison and not native.options.candidateFilters.includeDispelTypes.Magic, "Type selection")
check(native.slot.registered[1].tex.texture == ns.DispelTintAsset(typed.tintShape), "Shared preview/native gradient")
check(native.slot.registered[1].tex.parent.alpha == typed.overlayAlpha, "Tint intensity")
check(native.slot.registered[2].options.customDispelAssetMap.Poison.asset == ns.DISPEL_ICONS.Poison, "Shared type icon")
check(listNative and listNative.filter == "HARMFUL" and #listNative.group == list.max, "Native debuff list")
ns.compiled = { { index = 1, cfg = typed, kind = "aura" }, { index = 2, cfg = list, kind = "debuffs" } }
for _, state in ipairs { false, true, false, true, false } do
    combat = state
    ns.UpdateAuras(b)
    check(w.nativeDispel == native and native.shown and listNative.shown, "Stable renderer across combat transitions")
    check(not w.shown and not lw.shown, "Legacy frames must stay hidden")
end
check(queries == 0, "Native indicators must not query restricted aura APIs")
-- Pending changes must not alter future frames allocated by a native group.
local snapshotWidth = list.width
list.width = 99
local later = object(listNative)
listNative.options.initializeFrame(later)
check(later.width == snapshotWidth, "Deferred native callback must use applied settings")
list.width = snapshotWidth
ns.ReleaseNativeIndicator(w)
check(not native.shown and native.unit == "none" and not w.nativeDispel, "Native release disconnects the unit")
ns.BuildNativeIndicator(b, w, typed)
check(w.nativeDispel ~= native and w.auraRoute == "native-dispel", "Native rebuild")

-- Every unsupported option must explain why it uses the restricted reader.
local cases = {
    { { kind = "raiddebuff" }, "legacy" },
    { { kind = "aura", auraType = "HELPFUL", spells = { 123 } }, "legacy" },
    { { kind = "aura", mode = "missing", spells = { 123 } }, "legacy" },
    { { kind = "aura", type = "bar", barMeasure = "absorb" }, "unit" },
    { { kind = "aura", type = "bar", barMeasure = "heal" }, "unit" },
    { { onlyOOC = true }, "ooc" },
    { { enabled = false }, "disabled" },
    { { kind = "debuffs", blacklist = { 123 } }, "legacy" },
    { { kind = "debuffs", warnAt = 3 }, "legacy" },
    { { kind = "debuffs", showBelow = 3 }, "legacy" },
    { { kind = "debuffs", swipeStyle = "drainV" }, "legacy" },
    { { kind = "debuffs", swipe = false, swipeStyle = "drainV" }, "native-debuffs" },
    { { kind = "aura", type = "overlay", watch = "debuffTypes", mode = "missing" }, "legacy" },
}
for _, entry in ipairs(cases) do
    local c = cfg(entry[1])
    check(ns.IndicatorAuraPlan(c).route == entry[2], "Unexpected capability classification")
    check(#ns.IndicatorAuraSummary(c) > 0, "Missing compatibility explanation")
end
local highlighted = cfg { kind = "aura", type = "overlay", watch = "debuffTypes" }
highlighted.hl.tint = true
ns.BuildNativeIndicator(b, w, highlighted)
check(not w.nativeDispel and w.auraRoute == "legacy", "Unsupported highlight must not be silently ignored")
local previousEnum = Enum
Enum = nil
check(ns.IndicatorAuraPlan(typed).route == "legacy", "Missing native API must be reported")
Enum = previousEnum

-- A failed, partial, or truncated query must never prove that an aura is absent.
local missing = cfg { kind = "aura", type = "square", mode = "missing", spells = { 999 } }
local mw = object(parent)
mw.wtype = "square"
b.ind = { mw }
ns.compiled = { { index = 1, cfg = missing, kind = "aura", filter = "HELPFUL", byID = { [999] = 1 }, byName = {} } }
for _, mode in ipairs { "blocked", "partial", "truncated" } do
    apiMode = mode
    ns.UpdateAuras(b)
    check(not mw.shown, "Unreadable aura list caused false missing-aura warning: " .. mode)
end
apiMode = "empty"
ns.UpdateAuras(b)
check(mw.shown, "A complete empty list must allow the missing indicator")
apiMode = "present"
ns.compiled[1].byID = { [123] = 1 }
ns.UpdateAuras(b)
check(not mw.shown, "A present aura must hide the missing indicator")

-- Removing an indicator must retire its native wrapper even when it is pooled.
ns.BuildNativeIndicator(b, w, typed)
local removed = w.nativeDispel
b.ind = { w }
ns.compiled = {}
ns.BuildIndicators(b)
check(not removed.shown and removed.unit == "none" and not w.nativeDispel, "Removed indicator kept an active native unit")

-- A partial creation failure must disconnect its container and remain visible in diagnostics.
local oldCreate = CreateFrame
CreateFrame = function(kind, name, owner)
    local result = oldCreate(kind, name, owner)
    if kind == "AuraContainer" then result.AddAuraSlot = function() error("simulated native creation failure") end end
    return result
end
ns.BuildNativeIndicator(b, w, typed)
local failed = nativeFrames[#nativeFrames]
check(not w.nativeDispel and w.auraRoute == "legacy-error" and w.nativeAuraError, "Native failure not reported")
check(not failed.shown and failed.unit == "none", "Partial native creation remained connected")
CreateFrame = oldCreate
ns.P = { indicators = { typed, list, missing } }
ns.db.profiles.Default = ns.P
ns.activeName = "Default"
ns.buttons = {}
ns.AuditIndicators()
check(ns.db.indicatorAudit.profiles.Default[3].route == "legacy", "Audit did not record the unsafe indicator")

-- Secret display strings may be forwarded to SetText, never sliced or queried.
local secretName = setmetatable({ secret = true }, { __index = function() error("secret string was inspected") end })
local textCfg = cfg { kind = "aura", type = "text", textShow = "name", nameLetters = 3 }
local textWidget = object(parent)
textWidget.wtype, textWidget.timerText = "text", object()
ns.ShowAura(textWidget, "player", { name = secretName }, textCfg)
check(textWidget.timerText.text == secretName, "Secret aura name was not forwarded directly")
textCfg.textShow = "caster"
local nameCalls = 0
UnitName = function() nameCalls = nameCalls + 1 return secretName end
ns.ShowAura(textWidget, "player", { sourceUnit = { secret = true } }, textCfg)
check(nameCalls == 0 and textWidget.timerText.text == "", "Secret source unit was queried")
ns.ShowAura(textWidget, "player", { sourceUnit = "player" }, textCfg)
check(textWidget.timerText.text == secretName, "Secret caster name was not forwarded directly")
print("PASS: " .. passed .. " behavioral assertions (simulated client)")
