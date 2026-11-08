-------------------------------------------------------------------------------
-- MendFrames - Spell catalog per class (WoW Forever)
--
-- Source: foreverdb.net (data extracted from the Forever client, Nov 2026).
-- Classic spells keep their Classic ID (rank 1). New Forever spells that come
-- from talents are stored by name ("n:..."): the aura they apply can have a
-- different ID than the talent, and the name covers all of them.
-- The client is in English, so spell names are in English.
--
-- Each group holds a single aura type (buff or debuff). The "from whom"
-- (mine / others / anyone) is chosen when adding it.
-- family: equivalent spells (e.g. Fortitude and Prayer of Fortitude); in
-- "missing" mode one indicator is created per family.
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local function S(class, key, note, extra)
    local e = { class = class, note = note }
    if type(key) == "number" then e.id = key else e.name = key end
    if extra then for k, v in pairs(extra) do e[k] = v end end
    return e
end

ns.CLASS_NAMES.GENERAL = "General"

ns.Catalog = {
    {
        key = "hots",
        name = "HoTs and shields",
        desc = "Heals over time and shields on allies.",
        auraType = "HELPFUL",
        origin = "mine",
        defaults = { type = "icons", point = "TOPRIGHT", x = -2, y = -2, width = 11, height = 11,
            max = 4, grow = "LEFT", timer = false, swipe = true },
        spells = {
            S("PRIEST", 139, "HoT", { rec = true }),
            S("PRIEST", 17, "Shield", { rec = true }),
            S("PRIEST", "Prayer of Mending", "Bounces between allies (talent)", { rec = true }),
            S("PRIEST", "Divine Aegis", "Shield after a crit (talent)"),
            S("PRIEST", 14893, "Inspiration: armor after a crit"),
            S("DRUID", 774, "HoT", { rec = true }),
            S("DRUID", 8936, "Heal + HoT", { rec = true }),
            S("DRUID", "Wild Growth", "Group HoT (talent)", { rec = true }),
            S("SHAMAN", "Riptide", "HoT, boosts Chain Heal (talent)", { rec = true }),
            S("SHAMAN", 16177, "Ancestral Fortitude: armor after a crit"),
            S("SHAMAN", 29203, "Healing Way (stacks)", { rec = true }),
            S("PALADIN", "Oath of Light", "Oath of Light (talent)", { rec = true }),
            S("PALADIN", "Light's Vigil", "Light's Vigil (talent)"),
        },
    },
    {
        key = "defensives",
        name = "Defensives",
        desc = "Damage reductions and immunities. Useful to know when a tank or a player is protected.",
        auraType = "HELPFUL",
        origin = "any",
        defaults = { type = "icons", point = "LEFT", x = 2, y = 0, width = 12, height = 12,
            max = 2, grow = "RIGHT", timer = true },
        spells = {
            S("WARRIOR", 871, "Shield Wall", { rec = true }),
            S("WARRIOR", 12975, "Last Stand", { rec = true }),
            S("WARRIOR", 2565, "Shield Block"),
            S("PALADIN", 642, "Divine Shield", { rec = true }),
            S("PALADIN", 498, "Divine Protection", { rec = true }),
            S("PALADIN", 1022, "Blessing of Protection", { rec = true }),
            S("PALADIN", "Templar's Bulwark", "Templar's Bulwark: absorbs (talent)", { rec = true }),
            S("PALADIN", 6940, "Blessing of Sacrifice"),
            S("DRUID", 22812, "Barkskin", { rec = true }),
            S("DRUID", 22842, "Frenzied Regeneration", { rec = true }),
            S("ROGUE", 5277, "Evasion", { rec = true }),
            S("HUNTER", 19263, "Deterrence", { rec = true }),
            S("MAGE", 11958, "Ice Block", { rec = true }),
            S("MAGE", 11426, "Ice Barrier"),
            S("MAGE", 1463, "Mana Shield"),
            S("WARLOCK", 6229, "Shadow Ward"),
            S("PRIEST", 6346, "Fear Ward"),
        },
    },
    {
        key = "raidbuffs",
        name = "Raid buffs",
        desc = "Long raid buffs. Usually added in \"Missing\" mode and out of combat only: one warning is created per buff.",
        auraType = "HELPFUL",
        origin = "any",
        mode = "missing",
        defaults = { type = "square", point = "BOTTOMRIGHT", x = -2, y = 5, width = 6, height = 6,
            onlyOOC = true },
        spells = {
            S("PRIEST", 1243, "Fortitude", { family = "fort", rec = true }),
            S("PRIEST", 21562, "Prayer of Fortitude", { family = "fort", rec = true }),
            S("PRIEST", 14752, "Divine Spirit", { family = "spirit" }),
            S("PRIEST", 27681, "Prayer of Spirit", { family = "spirit" }),
            S("PRIEST", 976, "Shadow Protection", { family = "shadowprot" }),
            S("DRUID", 1126, "Mark of the Wild", { family = "motw", rec = true }),
            S("DRUID", 21849, "Gift of the Wild", { family = "motw", rec = true }),
            S("DRUID", 467, "Thorns", { family = "thorns" }),
            S("MAGE", 1459, "Arcane Intellect", { family = "int", rec = true }),
            S("MAGE", 23028, "Arcane Brilliance", { family = "int", rec = true }),
            S("PALADIN", 20217, "Blessing of Kings", { family = "kings", rec = true }),
            S("PALADIN", 25898, "Greater Blessing of Kings", { family = "kings", rec = true }),
            S("PALADIN", 19740, "Blessing of Might", { family = "might" }),
            S("PALADIN", 25782, "Greater Blessing of Might", { family = "might" }),
            S("PALADIN", 19742, "Blessing of Wisdom", { family = "wisdom" }),
            S("PALADIN", 25894, "Greater Blessing of Wisdom", { family = "wisdom" }),
            S("PALADIN", 1038, "Blessing of Salvation", { family = "salv" }),
            S("PALADIN", 25895, "Greater Blessing of Salvation", { family = "salv" }),
            S("PALADIN", 19977, "Blessing of Light", { family = "light" }),
            S("WARRIOR", 6673, "Battle Shout", { family = "shout" }),
        },
    },
    {
        key = "externals",
        name = "Boosts and utility",
        desc = "Useful buffs cast on other players.",
        auraType = "HELPFUL",
        origin = "any",
        defaults = { type = "icons", point = "RIGHT", x = -2, y = 0, width = 11, height = 11,
            max = 2, grow = "UP", timer = false },
        spells = {
            S("PRIEST", 10060, "Power Infusion", { rec = true }),
            S("DRUID", 29166, "Innervate", { rec = true }),
            S("PALADIN", 1044, "Blessing of Freedom", { rec = true }),
            S("WARLOCK", 20707, "Soulstone", { rec = true }),
        },
    },
}

ns.CatalogByKey = {}
for _, g in ipairs(ns.Catalog) do ns.CatalogByKey[g.key] = g end

-- Spell key (for the indicator lists)
function ns.CatalogKey(e)
    return e.id or ("n:" .. e.name)
end

ns.ORIGIN_LABEL = { mine = "mine", others = "others", any = "all" }

-- Creates indicators from a catalog group.
-- entries: chosen entries · origin: mine | others | any · mode: present | missing
-- Returns the list of new indicators (one, or one per family when "missing").
function ns.CatalogMakeIndicators(g, entries, origin, mode)
    local out = {}
    local function Make(name, list)
        local ind = ns.DeepCopy(g.defaults)
        ind.name = name
        ind.kind = "aura"
        ind.mine = origin == "mine"
        ind.others = origin == "others"
        ind.mode = mode
        ind.spells = {}
        for _, e in ipairs(list) do table.insert(ind.spells, ns.CatalogKey(e)) end
        if mode == "missing" then
            ind.type = (ind.type == "icons") and "icon" or ind.type
            ind.onlyOOC = true
        end
        table.insert(out, ns.FixIndicator(ind))
    end
    if mode == "missing" then
        -- one warning per buff family
        local fams, order = {}, {}
        for _, e in ipairs(entries) do
            local f = e.family or ns.CatalogKey(e)
            if not fams[f] then fams[f] = {} table.insert(order, f) end
            table.insert(fams[f], e)
        end
        for i, f in ipairs(order) do
            local first = fams[f][1]
            Make((L["Missing: %s"]):format(L[first.note]), fams[f])
            -- so they do not overlap: side by side
            out[i].x = (out[i].x or 0) - (i - 1) * ((out[i].width or 6) + 2)
        end
    else
        Make(("%s · %s"):format(L[g.name], L[ns.ORIGIN_LABEL[origin] or origin]), entries)
    end
    return out
end

-- Recommended entries of a group for a class
function ns.CatalogRecommended(g, class)
    local out = {}
    for _, e in ipairs(g.spells) do
        if e.rec and (e.class == class or e.class == "GENERAL") then table.insert(out, e) end
    end
    return out
end
