-------------------------------------------------------------------------------
-- Tile - Defaults for profiles and indicators
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
ns.FLAT, ns.FONT = FLAT, FONT

local function C(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end

-- States of the status text: their switch, color and text (English key)
ns.STATUS_STATES = {
    offline = { show = "showOffline", color = "offlineColor", text = "Offline" },
    res = { show = "showRes", color = "resColor", text = "Resurrecting" },
    dead = { show = "showDead", color = "deadColor", text = "Dead" },
    ghost = { show = "showGhost", color = "ghostColor", text = "Ghost" },
    charm = { show = "showCharm", color = "charmColor", text = "Charmed" },
    summon = { show = "showSummon", color = "summonColor", text = "Summon" },
    afk = { show = "showAFK", color = "afkColor", text = "AFK" },
}

-- A color from one of the game's tables (or r, g, b if it is missing)
local function GameColor(t, r, g, b)
    if t and t.r then return C(t.r, t.g, t.b) end
    return C(r, g, b)
end

-- Starting colors of the Colors page: the game's own
local function ClassDefaults()
    local fallback = {
        WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
        ROGUE = { 1, 0.96, 0.41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 },
        MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1, 0.49, 0.04 },
    }
    local t = {}
    for token, f in pairs(fallback) do
        t[token] = GameColor(RAID_CLASS_COLORS and RAID_CLASS_COLORS[token], f[1], f[2], f[3])
    end
    return t
end

local function PowerDefaults()
    local P = PowerBarColor
    return {
        MANA = GameColor(P and P.MANA, 0, 0, 1),
        RAGE = GameColor(P and P.RAGE, 1, 0, 0),
        ENERGY = GameColor(P and P.ENERGY, 1, 1, 0),
    }
end

-- Status icon: its own settings plus the shared background and border ones
local function Element(t)
    t.bg, t.bgColor = false, C(0, 0, 0, 0.6)
    t.border, t.borderColor, t.borderSize = false, C(0, 0, 0, 1), 1
    t.pad = 1
    return t
end

-------------------------------------------------------------------------------
-- Global database (shared by every character)
-------------------------------------------------------------------------------
ns.dbDefaults = {
    locked = true,
    testing = false,
    testSize = "raid20",
    hideBlizzard = true,
    language = "enUS",   -- enUS | esES
    profiles = {},
    chars = {},
    spellIndex = {},     -- name -> IDs index (rebuilt when the client version changes)
    minimap = { angle = 225, hide = false }, -- minimap button: position (degrees), hidden
    -- what test mode simulates (Profiles page, Preview); health: mixed | full | low
    preview = {
        range = true, offline = true, dead = true, threat = true, target = true,
        ready = true, heals = true, pets = true, indicators = true, icons = true, states = true,
        health = "mixed",
    },
}

-- Profile assigned to each group size (per character)
ns.SIZE_KEYS = { "party", "raid10", "raid20", "raid40" }
ns.SIZE_NAMES = {
    party = "Party / solo (1-5)",
    raid10 = "Raid up to 10",
    raid20 = "Raid up to 20",
    raid40 = "Raid up to 40",
}
ns.SIZE_TEST = { party = 5, raid10 = 10, raid20 = 20, raid40 = 40 }

-------------------------------------------------------------------------------
-- Profile
-------------------------------------------------------------------------------
ns.profileDefaults = {
    pos = {
        main = { "TOPLEFT", "UIParent", "TOPLEFT", 40, -260 },
        pets = { "TOPLEFT", "UIParent", "TOPLEFT", 40, -560 },
    },
    layout = {
        width = 76,
        height = 42,
        spacing = 2,
        groupSpacing = 6,
        orientation = "vertical",
        groupBy = "GROUP",
        sortByName = false,
        scale = 1,
        showSolo = false,
        showParty = true,
        showPlayer = true,
        groups = { true, true, true, true, true, true, true, true },
    },
    pets = {
        enabled = true,
        attach = true,
        sameSize = true,      -- same width and height as players
        width = 76,
        height = 22,
        perColumn = 5,
    },
    bars = {
        healthTex = FLAT,
        bgTex = FLAT,                 -- background texture
        powerTex = FLAT,
        healPredTex = FLAT,           -- incoming heals
        absorbTex = FLAT,             -- shields
        powerColor = "power",         -- mana/energy/rage: power | class | custom
        powerCustom = C(0.3, 0.5, 1),
        powerBrightness = 1,
        powerBgAlpha = 0.8,           -- background opacity of the resource bar
        healthColor = "class",        -- bar: class | custom | gradient
        customColor = C(0.2, 0.75, 0.3),
        bgColor = "class",            -- background: same options as the bar: class | custom | gradient
        bgCustom = C(0.15, 0.15, 0.15),
        smooth = false,               -- health: native animation when it fills/drains
        powerSmooth = false,          -- mana/energy/rage: native animation
        healthBrightness = 1,         -- 0.1..1: darkens the bar color
        bgBrightness = 0.25,          -- 0.1..1: darkens the background color
        bgAlpha = 0.75,
        borderColor = C(0, 0, 0, 1),
        showPower = true,
        powerOnlyMana = false,
        powerHeight = 3,
        showHealPred = true,
        healPredColor = C(0.3, 1, 0.4, 0.45),
        showAbsorb = true,
        absorbColor = C(1, 1, 1, 0.45),
        rangeAlpha = 0.35,
        targetHighlight = true,
        targetColor = C(1, 1, 1, 1),
        hoverHighlight = true,
        hoverColor = C(1, 0.82, 0, 1),
        showTooltip = true,
        tooltipNoCombat = false,      -- hide the unit tooltip while in combat
        aggro = true,
        aggroColor = C(1, 0.1, 0.1, 1),
    },
    -- offline players: their own look ("usual" = as any other player).
    -- Gray bars like Blizzard's raid frames; faded like out of range.
    offline = {
        health = "custom", healthColor = C(0.5, 0.5, 0.5),
        power = "custom", powerColor = C(0.5, 0.5, 0.5),
        name = "usual", nameColor = C(0.5, 0.5, 0.5),
        alpha = 0.35,
    },
    -- dead and ghost players: their bar is empty, so the background is what
    -- shows. bgAlpha is the background's own opacity while they are dead;
    -- alpha the frame's (range fading still applies on top)
    dead = {
        bg = "usual", bgColor = C(0.5, 0.5, 0.5),
        bgAlpha = 0.3,
        name = "usual", nameColor = C(0.5, 0.5, 0.5),
        alpha = 1,
    },
    -- font and outline every text uses unless it has its own
    -- (a text with font = false / outline = false takes these)
    general = { font = FONT, outline = "OUTLINE" },
    -- bottom positions are measured from above the resource bar (older
    -- profiles, without this, measured them from the frame's bottom edge)
    bottomRev = 1,
    texts = {
        name = {
            show = true, font = false, size = 11, outline = false,
            colorMode = "white", color = C(1, 1, 1),
            point = "TOP", x = 0, y = -5, width = 92,
            surname = true,   -- first name and surname (Forever); false = first name only
        },
        status = {
            show = true, font = false, size = 10, outline = false,
            point = "CENTER", x = 0, y = -3,
            -- states, by priority (the first one that applies shows), each with its color
            order = { "offline", "res", "dead", "ghost", "charm", "summon", "afk" },
            showOffline = true, offlineColor = C(0.75, 0.75, 0.75),
            showRes = true, resColor = C(0.3, 1, 0.45),        -- someone is casting a resurrection on them
            showDead = true, deadColor = C(0.75, 0.75, 0.75),
            showGhost = true, ghostColor = C(0.75, 0.75, 0.75),
            showCharm = true, charmColor = C(1, 0.4, 0.8),     -- mind controlled
            showSummon = true, summonColor = C(0.7, 0.55, 1),  -- pending, accepted or declined
            showAFK = true, afkColor = C(1, 0.8, 0.3),         -- away
        },
        health = {
            show = false, format = "deficit", hideFull = true,
            font = false, size = 9, outline = false,
            colorMode = "custom", color = C(1, 1, 1),
            point = "BOTTOM", x = 0, y = 1,
        },
    },
    elements = {
        -- when: always | ready (only during ready checks) | ooc (out of combat)
        -- onTop: priority, true = drawn above the indicators
        -- bg / border: optional box behind the icon (pad = space around the icon)
        role     = Element({ show = true, when = "always", onTop = false, point = "TOPLEFT", x = 2, y = -2, size = 10 }),
        leader   = Element({ show = true, when = "always", onTop = false, point = "TOPLEFT", x = 12, y = -1, size = 9 }),
        raidIcon = Element({ show = true, when = "always", onTop = false, point = "TOP", x = 0, y = 5, size = 12 }),
        ready    = Element({ show = true, when = "ready", onTop = true, point = "CENTER", x = 0, y = 0, size = 18 }),
    },
    -- colors per debuff type (indicator borders and tint)
    dispelColors = {
        Magic = C(0.2, 0.6, 1), Curse = C(0.6, 0, 1), Disease = C(0.6, 0.4, 0), Poison = C(0, 0.6, 0),
        none = C(0.85, 0.1, 0.1),
    },
    -- Colors page: what "class color", "resource color" and "by health" use
    colors = {
        class = ClassDefaults(),
        pet = C(0, 0.8, 0.2),   -- pets: a fixed green, like Blizzard's raid frames
        power = PowerDefaults(),
        gradient = { low = C(1, 0, 0), mid = C(1, 1, 0), high = C(0, 1, 0) },
    },
    -- indicators: created separately (ordered list)
}

-------------------------------------------------------------------------------
-- Indicators
-- kind: aura (custom) | raiddebuff (boss debuff) | debuffs
--       | heal (incoming heal square) | threat (threat count square)
-- type: icon | icons | square | bar | text | border | overlay
-------------------------------------------------------------------------------
ns.indicatorDefaults = {
    name = "Indicator",
    enabled = true,
    kind = "aura",
    type = "square",
    mine = true,            -- only mine
    mode = "present",       -- present | missing ("missing": out of combat only)
    -- spells: buffs in the list (empty = all) · dispellable: debuffs the game says
    -- I can dispel · debuffTypes: debuffs of the checked types
    watch = "spells",
    -- "I can dispel" / "by type": which types
    dispelTypes = { Magic = true, Curse = true, Disease = true, Poison = true },
    onlyOOC = false,        -- out of combat only
    spells = {},
    point = "TOPRIGHT",
    x = -2,
    y = -2,
    width = 9,
    height = 9,
    color = C(0.2, 1, 0.3),
    timer = false,
    stacks = true,
    swipe = true,
    -- "Text" type: what it shows (time | custom | name | stacks | caster)
    textShow = "time",
    customText = "",
    swipeStyle = "clock",   -- clock | clockReverse | drainV | drainH | bar
    swipeColor = C(0, 0, 0, 0.6),   -- sweep shade (the "thin bar" style: its background)
    swipeSpark = false,     -- spark on the moving end of the sweep (any style)
    sparkColor = C(1, 1, 1, 1),
    iconFit = "crop",       -- icons not square: crop (keeps proportions) | stretch
    max = 3,
    grow = "LEFT",
    spacing = 1,
    others = false,         -- only others' (not mine)
    dispelColor = true,     -- border by magic type
    onlyDispellable = true,
    -- time and stack texts (same style as every other text)
    timerText = { font = false, size = 9, outline = false, colorMode = "white", color = C(1, 1, 1),
        point = "CENTER", x = 0, y = 0 },
    stacksText = { font = false, size = 9, outline = false, colorMode = "white", color = C(1, 1, 1),
        point = "BOTTOMRIGHT", x = 0, y = 0 },
    showBorder = true,       -- border for icons, squares and bars
    borderColor = C(0, 0, 0, 1),
    borderSize = 1,
    barOrient = "HORIZONTAL",
    barReverse = false,
    -- bar: what it measures (time | stacks | absorb | heal) and whether it spans a whole side
    barMeasure = "time",
    barMaxStacks = 5,
    span = "none",          -- none | width | height
    overlayAlpha = 0.6,      -- tint intensity
    tintShape = "up",        -- tint: up (gradient from bottom to top) | down (top to bottom) | solid
    typeIcon = true,         -- border / tint: native type icon (magic, poison...)
    typeIconSize = 14,
    typeIconPos = { point = "CENTER", x = 0, y = 0 },
    borderInside = false,    -- frame border: inside (true) or outside
    ranks = {},              -- [spell key] = { [id] = true } chosen IDs (empty = all)
}

-- What each type starts with when an indicator changes to it: its size and
-- its own settings (position, spells and colors are kept). For a frame
-- border, width is the thickness.
ns.TYPE_DEFAULTS = {
    square  = { width = 9, height = 9 },
    icon    = { width = 14, height = 14, iconFit = "crop" },
    icons   = { width = 12, height = 12, iconFit = "crop", max = 3, grow = "LEFT", spacing = 1 },
    bar     = { width = 30, height = 4, span = "none", barOrient = "HORIZONTAL", barReverse = false,
                barMeasure = "time" },
    text    = { textShow = "time" },
    border  = { width = 2, borderInside = false },
    overlay = { overlayAlpha = 0.6, tintShape = "up" },
}

-- Changes the type of an indicator, with that type's defaults
function ns.SetIndicatorType(ind, t)
    if ind.type == t then return end
    ind.type = t
    for k, v in pairs(ns.TYPE_DEFAULTS[t] or {}) do ind[k] = ns.DeepCopy(v) end
end

local function Ind(t)
    return t
end

function ns.BuiltinIndicators()
    return {
        Ind { name = L["Boss debuff"], kind = "raiddebuff", type = "icon",
            point = "CENTER", x = 0, y = -3, width = 20, height = 20,
            timer = true, stacks = true, dispelColor = true, mine = false },
        Ind { name = "Debuffs", kind = "debuffs", type = "icons",
            point = "BOTTOMLEFT", x = 2, y = 1, width = 12, height = 12, max = 3, grow = "RIGHT",
            timer = false, stacks = true, mine = false, onlyDispellable = false, dispelColor = true },
        ns.HealIndicator(),
        ns.ThreatIndicator(),
        Ind { name = L["Dispellable (border)"], kind = "aura", watch = "dispellable", type = "border",
            width = 2, mine = false, others = false, dispelColor = true },
        ns.RestIndicator(),
    }
end

-- Incoming heal: a square that lights up while someone casts a heal on the player
function ns.HealIndicator()
    return Ind { name = L["Incoming heal"], kind = "heal", type = "square", mine = false,
        point = "BOTTOM", x = 0, y = 2, width = 7, height = 7, color = C(0.2, 1, 0.3),
        timer = false, stacks = false }
end

-- Threat count: how many enemies are attacking the player, hidden at 0
function ns.ThreatIndicator()
    return Ind { name = L["Threat count"], kind = "threat", type = "square", mine = false,
        point = "BOTTOMRIGHT", x = -2, y = 2, width = 11, height = 11, color = C(0.75, 0.08, 0.08),
        timer = false, stacks = true,
        stacksText = { font = false, size = 9, outline = false, colorMode = "white", color = C(1, 1, 1),
            point = "CENTER", x = 0, y = 0 } }
end

-- Drinking / eating: the buff present while drinking or eating (not the
-- "Well Fed" after it). It is a normal indicator: it can be changed or deleted.
function ns.RestIndicator()
    return Ind { name = L["Drinking / eating"], kind = "aura", type = "icon",
        mine = false, others = false, mode = "present", onlyOOC = true,
        spells = { "n:Drink", "n:Food", "n:Refreshment" },
        point = "LEFT", x = 2, y = 0, width = 14, height = 14,
        timer = false, stacks = false }
end

-- Class names (the spell catalog is in Catalog.lua)
ns.CLASS_NAMES = {
    PRIEST = "Priest", DRUID = "Druid", PALADIN = "Paladin", SHAMAN = "Shaman",
    MAGE = "Mage", WARRIOR = "Warrior", ROGUE = "Rogue", HUNTER = "Hunter", WARLOCK = "Warlock",
}
ns.CLASS_ORDER = { "PRIEST", "DRUID", "PALADIN", "SHAMAN", "MAGE", "WARRIOR", "ROGUE", "HUNTER", "WARLOCK", "GENERAL" }

-------------------------------------------------------------------------------
-- Profile utilities
-------------------------------------------------------------------------------
function ns.DeepCopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = ns.DeepCopy(v) end
    return o
end

-- Fills an indicator with the defaults it is missing
function ns.FixIndicator(ind)
    ns.CopyDefaults(ns.indicatorDefaults, ind)
    -- the old "clock with edge" style is now the clock with a spark
    if ind.swipeStyle == "clockEdge" then
        ind.swipeStyle = "clock"
        ind.swipeSpark = true
    end
    return ind
end

-- Adds the catalog recommendations for a class
function ns.AddRecommended(list, class)
    local plan = {
        { key = "hots", origin = "mine", mode = "present" },
        { key = "raidbuffs", origin = "any", mode = "missing" },
    }
    local added = 0
    for _, p in ipairs(plan) do
        local g = ns.CatalogByKey and ns.CatalogByKey[p.key]
        local entries = g and ns.CatalogRecommended(g, class) or {}
        if #entries > 0 then
            for _, ind in ipairs(ns.CatalogMakeIndicators(g, entries, p.origin, p.mode)) do
                table.insert(list, ind)
                added = added + 1
            end
        end
    end
    return added
end

function ns.DefaultIndicators(class)
    local list = {}
    for _, ind in ipairs(ns.BuiltinIndicators()) do
        table.insert(list, ns.FixIndicator(ind))
    end
    ns.AddRecommended(list, class)
    return list
end

function ns.NewProfile()
    local p = ns.DeepCopy(ns.profileDefaults)
    local _, class = UnitClass("player")
    p.indicators = ns.DefaultIndicators(class)
    return p
end

-------------------------------------------------------------------------------
-- Profiles that come with Tile, besides Default: their settings (only what
-- differs from Default) and their indicators. Each one is added once per
-- account (ns.AddPresetProfiles) and never replaces a profile with its name.
-------------------------------------------------------------------------------
local DARK_TEX = LibStub("LibFlatyUI-1.0").Media("statusbar", "Flaty: Dark")
local GRAY = C(0.5, 0.5, 0.5)

ns.PRESET_PROFILES = {
    -- compact, light text (Arial Narrow without outline), the game's raid bar
    Clear = {
        settings = {
            layout = { width = 85, height = 48, groupSpacing = 2, showSolo = true },
            pets = { width = 72 },
            bars = {
                healthTex = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
                bgTex = DARK_TEX, bgBrightness = 0.9, bgAlpha = 1, bgCustom = C(0.0784, 0.0784, 0.0784),
                smooth = true, rangeAlpha = 0.6,
                healPredColor = C(0.1373, 0.5333, 0.2039),
                targetColor = C(1, 0.898, 0.1373), hoverColor = C(1, 0.9922, 0.9804),
                aggroColor = C(1, 0, 0),
            },
            general = { font = "Fonts\\ARIALN.TTF", outline = "" },
            texts = {
                name = { size = 10, y = -3, width = 64 },
                status = { size = 13, y = -2, offlineColor = GRAY, deadColor = GRAY, ghostColor = GRAY },
            },
            elements = {
                role = { size = 8, x = 3, y = -4, bgColor = C(0.0588, 0.0588, 0.0588) },
                leader = { point = "LEFT", x = 2, y = 0, size = 13, onTop = true },
                raidIcon = { point = "CENTER", x = 21, y = -2, size = 20, onTop = true },
                ready = { point = "BOTTOM", x = 0, y = 4, size = 20 },
            },
            offline = { alpha = 1 },
            dead = { bgAlpha = 0.4 },
        },
        indicators = function()
            return {
                { name = L["Boss debuff"], kind = "raiddebuff", type = "icon", mine = false,
                    point = "CENTER", x = 0, y = 0, width = 16, height = 16, timer = true, dispelColor = false },
                { name = "Debuffs", kind = "debuffs", type = "icons", mine = false, onlyDispellable = false,
                    point = "BOTTOMLEFT", x = 2, y = 2, width = 11, height = 11, grow = "RIGHT",
                    swipeColor = C(0, 0, 0, 0.7943), swipeSpark = true,
                    stacksText = { font = "Fonts\\FRIZQT__.TTF", size = 9, outline = "OUTLINE", colorMode = "white",
                        color = C(1, 1, 1), point = "BOTTOMRIGHT", x = 0, y = 0 } },
                ns.HealIndicator(),
                ns.ThreatIndicator(),
                { name = L["Dispellable"], kind = "aura", watch = "dispellable", type = "overlay", mine = false,
                    overlayAlpha = 0.9, typeIconSize = 18, x = -3, width = 15, height = 4 },
                { name = L["Drinking / eating"], kind = "aura", type = "icons", mine = false,
                    spells = { "n:Drink", "n:Food", "n:Refreshment" },
                    point = "LEFT", x = 1, y = 0, width = 12, height = 12, max = 2, grow = "RIGHT", spacing = 0,
                    showBorder = false, stacks = false, swipeSpark = true },
                { name = ("%s · %s"):format(L["Defensives"], L["all"]), kind = "aura", type = "icons", mine = false,
                    spells = { 871, 12975, 2565, 642, 498, 1022, "n:Templar's Bulwark", 6940, 22812, 22842,
                        5277, 19263, 11958, 11426, 1463, 6229, 6346 },
                    point = "RIGHT", x = -2, y = 0, width = 8, height = 20, stacks = false },
            }
        end,
    },
}

-- Writes the values of src over dst (tables merged, the rest replaced)
local function Overwrite(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" and v.r == nil then
            Overwrite(v, dst[k])
        else
            dst[k] = ns.DeepCopy(v)
        end
    end
end

function ns.NewPresetProfile(name)
    local def = ns.PRESET_PROFILES[name]
    local p = ns.NewProfile()
    Overwrite(def.settings, p)
    p.indicators = {}
    for _, ind in ipairs(def.indicators()) do table.insert(p.indicators, ns.FixIndicator(ind)) end
    return p
end

-- Adds the profiles that come with Tile, once per account (a profile with
-- the same name is never replaced; one the player deletes does not come back)
function ns.AddPresetProfiles(db)
    db.presetsAdded = db.presetsAdded or {}
    for name in pairs(ns.PRESET_PROFILES) do
        if not db.presetsAdded[name] then
            if not db.profiles[name] then db.profiles[name] = ns.NewPresetProfile(name) end
            db.presetsAdded[name] = true
        end
    end
end

-- Fills a profile (and its indicators) with the defaults it is missing
function ns.FixProfile(p)
    local inds = p.indicators
    p.indicators = nil
    -- the old status text color (Offline, Dead and Ghost shared it) is now
    -- the color of each of those states
    local st = type(p.texts) == "table" and p.texts.status
    if type(st) == "table" and st.offlineColor == nil and st.colorMode then
        local c = st.colorMode == "white" and C(1, 1, 1) or (st.colorMode == "custom" and st.color)
        if c then
            st.offlineColor, st.deadColor, st.ghostColor = ns.DeepCopy(c), ns.DeepCopy(c), ns.DeepCopy(c)
        end
    end
    if type(st) == "table" then st.colorMode, st.color = nil, nil end
    -- priority of the states: every known one exactly once (missing ones at the end)
    if type(st) == "table" and type(st.order) == "table" then
        local order, seen = {}, {}
        for _, k in ipairs(st.order) do
            if ns.STATUS_STATES[k] and not seen[k] then order[#order + 1], seen[k] = k, true end
        end
        for _, k in ipairs(ns.profileDefaults.texts.status.order) do
            if not seen[k] then order[#order + 1] = k end
        end
        st.order = order
    end
    local hadGeneral = type(p.general) == "table"
    local hadBottomRev = p.bottomRev ~= nil
    local hadSquares = p.squaresRev ~= nil
    ns.CopyDefaults(ns.profileDefaults, p)
    -- the old "No text" health format is now the Show box turned off
    local ht = p.texts.health
    if ht.format == "none" then ht.show, ht.format = false, "deficit" end
    if type(inds) ~= "table" then
        local _, class = UnitClass("player")
        inds = ns.DefaultIndicators(class)
    end
    for _, ind in ipairs(inds) do ns.FixIndicator(ind) end
    p.indicators = inds
    -- before the general font: every text had its own font and outline. The
    -- ones equal to the general ones now follow it (nothing changes on screen).
    if not hadGeneral then
        local G = p.general
        local function Follow(t)
            if type(t) ~= "table" then return end
            if t.font == G.font then t.font = false end
            if t.outline == G.outline then t.outline = false end
        end
        Follow(p.texts.name)
        Follow(p.texts.status)
        Follow(p.texts.health)
        for _, ind in ipairs(inds) do
            Follow(ind.timerText)
            Follow(ind.stacksText)
        end
    end
    -- bottom positions now start above the resource bar and the bottom
    -- strips: lower their Y by that height once (nothing moves on screen)
    if not hadBottomRev then
        local B = p.bars
        local off = (B.showPower and B.powerHeight > 0) and (B.powerHeight + 1) or 0
        for _, ind in ipairs(inds) do
            if ind.enabled and ind.type == "bar" and ind.kind == "aura" and ind.span == "stripBottom" then
                off = off + math.max(1, ind.height or 1) + 1
            end
        end
        local function Lower(t)
            if off > 0 and type(t) == "table" and type(t.point) == "string" and t.point:find("BOTTOM") then
                t.y = math.max(-60, math.min(60, (t.y or 0) - off))
            end
        end
        Lower(p.texts.name)
        Lower(p.texts.status)
        Lower(p.texts.health)
        for _, e in pairs(p.elements) do Lower(e) end
        for _, ind in ipairs(inds) do
            local whole = ind.type == "border" or ind.type == "overlay"
            local strip = ind.type == "bar" and type(ind.span) == "string" and ind.span:find("^strip")
            if not whole and not strip then Lower(ind) end
        end
        p.bottomRev = 1
    end
    -- profiles from before the incoming heal and threat squares get them,
    -- turned off (nothing changes on screen until they are turned on), right
    -- after the built-in ones at the top of the list
    if not hadSquares then
        local has, at = {}, 1
        for i, ind in ipairs(inds) do
            has[ind.kind] = true
            if ind.kind ~= "aura" and at == i then at = i + 1 end
        end
        for _, e in ipairs({ { "heal", ns.HealIndicator }, { "threat", ns.ThreatIndicator } }) do
            if not has[e[1]] then
                local ind = ns.FixIndicator(e[2]())
                ind.enabled = false
                table.insert(inds, at, ind)
                at = at + 1
            end
        end
        p.squaresRev = 1
    end
    return p
end
