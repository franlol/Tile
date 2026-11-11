-------------------------------------------------------------------------------
-- Tile - World bosses (open world: matched by zone)
-- Zone = the name the game gives (GetRealZoneText, enUS client), at their
-- Classic spots. If Forever turns them into instances (Storm Cliffs,
-- The Tainted Scar, Nightmare Grove), they go in Data\Raids.lua.
-- Debuffs by name: their IDs are looked up in the client.
-------------------------------------------------------------------------------

local _, ns = ...
local R = ns.RegisterInstance

R("w:Azuregos", { name = "Azuregos", kind = "world", zones = { "Azshara" }, bosses = {
    { "Azuregos", {
        "Chill",
        "Manastorm",
        "Mark of Frost"
    } }
} })

R("w:Kazzak", { name = "Lord Kazzak", kind = "world", zones = { "Blasted Lands" }, bosses = {
    { "Lord Kazzak", {
        "Mark of Kazzak",
        "Twisted Reflection",
        "Capture Soul",
        "Void Bolt"
    } }
} })

R("w:Dragons", { name = "Dragones de la Pesadilla", kind = "world",
    zones = { "Duskwood", "Ashenvale", "Feralas", "The Hinterlands" }, bosses = {
    { "Emeriss", {
        "Volatile Infection",
        "Corruption of the Earth"
    } },
    { "Lethon" },
    { "Taerar", {
        22686,  -- Bellowing Roar
    } },
    { "Ysondre" },
    { "Comunes a los dragones", {
        "Sleep",           -- Dream Fog
        "Noxious Breath",
        "Mark of Nature"
    } }
} })
