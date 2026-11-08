-------------------------------------------------------------------------------
-- MendFrames - Registro de debuffs por instancia
--
-- Los datos van en Data\*.lua y solo llaman a ns.RegisterInstance:
--   ns.RegisterInstance(clave, {
--       name   = "Molten Core",
--       kind   = "raid" | "dungeon" | "solo" | "world" | "zone",
--       status = nil | "unannounced",      -- en el cliente pero sin anunciar
--       zones  = { "Azshara" },            -- solo mundo abierto: zonas donde se activa
--       bosses = { { "Jefe", { [spellID | "Nombre"] = prioridad } }, ... },
--   })
-- clave: ID de mapa de la instancia (GetInstanceInfo, 8º valor), o una cadena
-- ("w:...") para mundo abierto. Prioridad de 1 a 5 (5 = se muestra antes).
--
-- Lo que da el juego manda: un hechizo puesto por nombre se busca en el
-- cliente (todos sus IDs), los jefes que se pelean (ENCOUNTER_START) se
-- añaden solos a su instancia, y el registrador apunta los debuffs nuevos.
-- Jefes y orden: los del cliente según los datos de ForeverDB.net.
-------------------------------------------------------------------------------

local _, ns = ...

ns.RaidDebuffs = {}   -- [clave] = definición
ns.RaidOrder = {}     -- claves en orden de registro
ns.PRIO_MAX = 5

-- Categorías de la lista de instancias, en orden
ns.KINDS = { "raid", "dungeon", "solo", "world", "zone" }
ns.KIND_NAMES = {
    raid = "Bandas",
    dungeon = "Mazmorras",
    solo = "Instancias de un jugador",
    world = "Jefes del mundo",
    zone = "Eventos y zonas",
    unannounced = "Sin anunciar (en el cliente)",
    other = "Otras",
}

local zoneIndex   -- [zona] = { claves } (se rehace al registrar)

function ns.RegisterInstance(key, def)
    def.kind = def.kind or "raid"
    def.bosses = def.bosses or {}
    -- un hechizo por nombre se guarda como "n:Nombre"; si sale en varios
    -- jefes de la misma instancia, se queda en el primero
    local used = {}
    for _, b in ipairs(def.bosses) do
        local spells = {}
        for k, prio in pairs(b[2] or {}) do
            if type(k) == "string" and not k:find("^n:") then k = "n:" .. k end
            if not used[k] then
                used[k] = true
                spells[k] = prio
            end
        end
        b[2] = spells
    end
    if not ns.RaidDebuffs[key] then ns.RaidOrder[#ns.RaidOrder + 1] = key end
    ns.RaidDebuffs[key] = def
    zoneIndex = nil
end

ns.RegisterInstance(0, { name = "Global (todas las instancias)", kind = "global" })

-- Claves de mundo abierto que se activan en una zona
function ns.ZoneKeys(zone)
    if not zoneIndex then
        zoneIndex = {}
        for _, key in ipairs(ns.RaidOrder) do
            for _, z in ipairs(ns.RaidDebuffs[key].zones or {}) do
                zoneIndex[z] = zoneIndex[z] or {}
                table.insert(zoneIndex[z], key)
            end
        end
    end
    return (zone and zoneIndex[zone]) or {}
end

-- Nombre visible de una instancia
function ns.InstanceName(key)
    local def = ns.RaidDebuffs[key]
    if def then return def.name end
    return (ns.db and ns.db.raid.names[key]) or ("Instancia " .. tostring(key))
end

-- Jefes de una instancia: los de los datos, en orden, y luego los que el
-- juego ha dicho al empezar un encuentro (si no estaban)
function ns.InstanceBosses(key)
    local out, have = {}, {}
    local def = ns.RaidDebuffs[key]
    for _, b in ipairs(def and def.bosses or {}) do
        out[#out + 1] = b[1]
        have[b[1]] = true
    end
    for _, name in ipairs(ns.db and ns.db.raid.learned[key] or {}) do
        if not have[name] then
            out[#out + 1] = name
            have[name] = true
        end
    end
    return out
end
