-------------------------------------------------------------------------------
-- MendFrames - Jefes del mundo (mundo abierto: se activan por zona)
-- Zona = nombre que da el juego (GetRealZoneText, cliente enUS), en sus
-- sitios de Classic. Si Forever los saca como instancia (Storm Cliffs,
-- The Tainted Scar, Nightmare Grove), van en Data\Raids.lua.
-- Debuffs por nombre: sus IDs se buscan en el cliente.
-------------------------------------------------------------------------------

local _, ns = ...
local R = ns.RegisterInstance

R("w:Azuregos", { name = "Azuregos", kind = "world", zones = { "Azshara" }, bosses = {
    { "Azuregos", {
        ["Chill"] = 3,
        ["Manastorm"] = 2,
        ["Mark of Frost"] = 2,
    } },
} })

R("w:Kazzak", { name = "Lord Kazzak", kind = "world", zones = { "Blasted Lands" }, bosses = {
    { "Lord Kazzak", {
        ["Mark of Kazzak"] = 5,
        ["Twisted Reflection"] = 4,
        ["Capture Soul"] = 2,
        ["Void Bolt"] = 2,
    } },
} })

R("w:Dragons", { name = "Dragones de la Pesadilla", kind = "world",
    zones = { "Duskwood", "Ashenvale", "Feralas", "The Hinterlands" }, bosses = {
    { "Emeriss", {
        ["Volatile Infection"] = 4,
        ["Corruption of the Earth"] = 3,
    } },
    { "Lethon" },
    { "Taerar", {
        [22686] = 4,  -- Bellowing Roar
    } },
    { "Ysondre" },
    { "Comunes a los dragones", {
        ["Sleep"] = 4,           -- Dream Fog
        ["Noxious Breath"] = 3,
        ["Mark of Nature"] = 2,
    } },
} })
