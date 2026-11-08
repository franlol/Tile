-------------------------------------------------------------------------------
-- MendFrames - Defaults for profiles and indicators
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
ns.FLAT, ns.FONT = FLAT, FONT

local function C(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end

-------------------------------------------------------------------------------
-- Global database (shared by every character)
-------------------------------------------------------------------------------
ns.dbDefaults = {
    version = 2,
    locked = true,
    hideBlizzard = true,
    language = "enUS",   -- enUS | esES
    profiles = {},
    chars = {},
    spellIndex = {},     -- name -> IDs index (rebuilt when the client version changes)
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
        aggro = true,
        aggroColor = C(1, 0.1, 0.1, 1),
    },
    texts = {
        name = {
            show = true, font = FONT, size = 11, outline = "OUTLINE",
            colorMode = "white", color = C(1, 1, 1),
            point = "TOP", x = 0, y = -5, width = 92,
            surname = true,   -- first name and surname (Forever); false = first name only
        },
        status = {
            show = true, font = FONT, size = 10, outline = "OUTLINE",
            colorMode = "custom", color = C(0.75, 0.75, 0.75),
            point = "CENTER", x = 0, y = -3,
            -- extra states (each with its own color); Offline, Dead and Ghost always
            showRes = true, resColor = C(0.3, 1, 0.45),        -- "Resurrecting": someone is casting a resurrection on them
            showCharm = true, charmColor = C(1, 0.4, 0.8),     -- "Charmed": mind controlled
            showSummon = true, summonColor = C(0.7, 0.55, 1),  -- "Summon": pending, accepted or declined
            showAFK = true, afkColor = C(1, 0.8, 0.3),         -- "AFK": away
        },
        health = {
            show = true, format = "none", hideFull = true,
            font = FONT, size = 9, outline = "OUTLINE",
            colorMode = "custom", color = C(1, 1, 1),
            point = "BOTTOM", x = 0, y = 5,
        },
    },
    elements = {
        -- when: always | ready (only during ready checks) | ooc (out of combat)
        -- onTop: above the indicators
        role     = { show = true, when = "always", onTop = false, point = "TOPLEFT", x = 2, y = -2, size = 10 },
        leader   = { show = true, when = "always", onTop = false, point = "TOPLEFT", x = 12, y = -1, size = 9 },
        raidIcon = { show = true, when = "always", onTop = false, point = "TOP", x = 0, y = 5, size = 12 },
        ready    = { show = true, when = "ready", onTop = true, point = "CENTER", x = 0, y = 0, size = 18 },
    },
    -- colors per debuff type (indicator borders and tint)
    dispelColors = {
        Magic = C(0.2, 0.6, 1), Curse = C(0.6, 0, 1), Disease = C(0.6, 0.4, 0), Poison = C(0, 0.6, 0),
        none = C(0.85, 0.1, 0.1),
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
    swipeStyle = "clock",   -- clock | clockReverse | clockEdge | drainV | drainH | bar
    max = 3,
    grow = "LEFT",
    spacing = 1,
    others = false,         -- only others' (not mine)
    dispelColor = true,     -- border by magic type
    onlyDispellable = true,
    -- time and stack texts (same style as every other text)
    timerText = { font = FONT, size = 9, outline = "OUTLINE", colorMode = "white", color = C(1, 1, 1),
        point = "CENTER", x = 0, y = 0 },
    stacksText = { font = FONT, size = 9, outline = "OUTLINE", colorMode = "white", color = C(1, 1, 1),
        point = "BOTTOMRIGHT", x = 0, y = 0 },
    showBorder = true,       -- black border for icons, squares and bars
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
        spells = { "n:Drink", "n:Food", "n:Food & Drink", "n:Refreshment" },
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
    ns.CopyDefaults(ns.profileDefaults, p)
    if type(inds) ~= "table" then
        local _, class = UnitClass("player")
        inds = ns.DefaultIndicators(class)
    end
    for _, ind in ipairs(inds) do ns.FixIndicator(ind) end
    p.indicators = inds
    return p
end
