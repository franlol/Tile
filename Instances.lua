-------------------------------------------------------------------------------
-- MendFrames - Instance guide
--
-- Bosses and their debuffs per instance, shown in the Instances page as a
-- reference. The game does not let addons tell these debuffs apart in combat
-- (they are secret), so the lists do not drive any indicator.
--
-- The data in Data\*.lua only calls ns.RegisterInstance:
--   ns.RegisterInstance(key, {
--       name   = "Molten Core",
--       kind   = "raid" | "dungeon" | "solo" | "world" | "zone",
--       status = nil | "unannounced",      -- in the client but not announced
--       zones  = { "Azshara" },            -- open world only: where it is
--       bosses = { { "Boss", { spellID | "Name", ... } }, ... },
--   })
-- key: instance map ID (GetInstanceInfo, 8th value), or a string ("w:...")
-- for the open world.
-------------------------------------------------------------------------------

local _, ns = ...

ns.Instances = {}       -- [key] = definition
ns.InstanceOrder = {}   -- keys in registration order

-- Categories of the instance list, in order (names are translation keys)
ns.INSTANCE_KINDS = { "raid", "dungeon", "solo", "world", "zone", "unannounced" }
ns.INSTANCE_KIND_NAMES = {
    raid = "Raids",
    dungeon = "Dungeons",
    solo = "Solo instances",
    world = "World bosses",
    zone = "Events and zones",
    unannounced = "Not announced (in the client)",
}

function ns.RegisterInstance(key, def)
    def.kind = def.kind or "raid"
    def.bosses = def.bosses or {}
    -- a spell given by name is stored as "n:Name" (the spell key format)
    for _, b in ipairs(def.bosses) do
        local spells = {}
        for _, k in ipairs(b[2] or {}) do
            if type(k) == "string" then k = "n:" .. k end
            spells[#spells + 1] = k
        end
        b[2] = spells
    end
    if not ns.Instances[key] then ns.InstanceOrder[#ns.InstanceOrder + 1] = key end
    ns.Instances[key] = def
end

-- Category of an instance in the list
function ns.InstanceCategory(key)
    local def = ns.Instances[key]
    if def.status == "unannounced" then return "unannounced" end
    return def.kind
end

-- Keys of the place where the player is: the instance, or the world bosses
-- of the current zone
function ns.CurrentInstanceKeys()
    local out = {}
    local _, instType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instType ~= "none" and instanceID and ns.Instances[instanceID] then
        out[#out + 1] = instanceID
    end
    local zone = GetRealZoneText()
    for _, key in ipairs(ns.InstanceOrder) do
        for _, z in ipairs(ns.Instances[key].zones or {}) do
            if z == zone then out[#out + 1] = key end
        end
    end
    return out
end

-- Does the game say this spell is crowd control? (any of its IDs)
local ccCache = {}
function ns.IsCrowdControlKey(key)
    if ccCache[key] ~= nil then return ccCache[key] end
    local ids = type(key) == "number" and { key } or ns.KeyIDs(key)
    if #ids == 0 then return false end   -- still looking up its IDs: not cached
    local cc = false
    if C_Spell and C_Spell.IsSpellCrowdControl then
        for _, id in ipairs(ids) do
            local ok, v = pcall(C_Spell.IsSpellCrowdControl, id)
            if ok and v == true then cc = true break end
        end
    end
    ccCache[key] = cc
    return cc
end
