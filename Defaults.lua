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
        aggro = true,
        aggroColor = C(1, 0.1, 0.1, 1),
    },
    -- font and outline every text uses unless it has its own
    -- (a text with font = false / outline = false takes these)
    general = { font = FONT, outline = "OUTLINE" },
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
            point = "BOTTOM", x = 0, y = 5,
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

local function Ind(t)
    return t
end

function ns.BuiltinIndicators()
    return {
        Ind { name = L["Boss debuff"], kind = "raiddebuff", type = "icon",
            point = "CENTER", x = 0, y = -3, width = 20, height = 20,
            timer = true, stacks = true, dispelColor = true, mine = false },
        Ind { name = "Debuffs", kind = "debuffs", type = "icons",
            point = "BOTTOMLEFT", x = 2, y = 5, width = 12, height = 12, max = 3, grow = "RIGHT",
            timer = false, stacks = true, mine = false, onlyDispellable = false, dispelColor = true },
        Ind { name = L["Dispellable (border)"], kind = "aura", watch = "dispellable", type = "border",
            width = 2, mine = false, others = false, dispelColor = true },
        ns.RestIndicator(),
    }
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
    return p
end
