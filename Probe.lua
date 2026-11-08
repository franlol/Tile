-------------------------------------------------------------------------------
-- MendFrames - Sondeo del cliente (/mf sondeo)
-- Mira qué datos da el juego (Diario de encuentros, eventos, APIs de auras) y
-- lo guarda en MendFramesDB.probe para revisarlo fuera del juego.
-- Solo lee: no cambia nada del addon.
-------------------------------------------------------------------------------

local _, ns = ...

local function Has(path)
    local t = _G
    for k in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return false end
        t = t[k]
    end
    return t ~= nil
end

-- Llama sin romper; devuelve todos los valores o nil + error
local function Pass(ok, ...)
    if not ok then return nil, tostring((...)) end
    return ...
end
local function Try(f, ...)
    if type(f) ~= "function" then return nil end
    return Pass(pcall(f, ...))
end

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return "<secreto>" end
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" or t == "nil" then return v end
    return "<" .. t .. ">"
end

-- Habilidades de un encuentro: árbol de secciones del diario
local function Sections(root, out, guard)
    local GetSection = C_EncounterJournal and C_EncounterJournal.GetSectionInfo
    if not GetSection then return end
    local stack = { root }
    while #stack > 0 and guard.n < 400 do
        local id = table.remove(stack)
        local info = id and Try(GetSection, id)
        if type(info) == "table" then
            guard.n = guard.n + 1
            out[#out + 1] = { title = Plain(info.title), spellID = Plain(info.spellID),
                headerType = Plain(info.headerType), filteredByDifficulty = Plain(info.filteredByDifficulty) }
            if info.siblingSectionID then stack[#stack + 1] = info.siblingSectionID end
            if info.firstChildSectionID then stack[#stack + 1] = info.firstChildSectionID end
        end
    end
end

local function ProbeEJ(p)
    local ej = { funcs = {} }
    p.ej = ej
    for _, f in ipairs({ "EJ_GetNumTiers", "EJ_SelectTier", "EJ_GetTierInfo", "EJ_GetInstanceByIndex",
        "EJ_SelectInstance", "EJ_GetInstanceInfo", "EJ_GetEncounterInfoByIndex", "EJ_GetEncounterInfo",
        "EJ_GetInstanceForMap", "C_EncounterJournal.GetSectionInfo", "C_EncounterJournal.GetEncountersOnMap" }) do
        ej.funcs[f] = Has(f)
    end
    if not Has("EJ_GetInstanceByIndex") then return end
    local nTiers = Try(EJ_GetNumTiers) or 1
    ej.numTiers = Plain(nTiers)
    ej.instances = {}
    for tier = 1, math.min(tonumber(nTiers) or 1, 30) do
        if EJ_SelectTier then Try(EJ_SelectTier, tier) end
        for _, isRaid in ipairs({ true, false }) do
            for i = 1, 80 do
                local jid, name = Try(EJ_GetInstanceByIndex, i, isRaid)
                if not jid then break end
                local inst = { tier = tier, raid = isRaid, journalID = Plain(jid), name = Plain(name), bosses = {} }
                if EJ_SelectInstance then Try(EJ_SelectInstance, jid) end
                if EJ_GetInstanceInfo then
                    local r = { Try(EJ_GetInstanceInfo, jid) }
                    -- 10º valor: ID de mapa de la instancia (el de GetInstanceInfo)
                    inst.mapID = Plain(r[10])
                end
                local guard = { n = 0 }
                for j = 1, 40 do
                    local bname, _, encID, rootSection, _, _, dungeonEncID, instID = Try(EJ_GetEncounterInfoByIndex, j, jid)
                    if not bname then break end
                    local b = { name = Plain(bname), encounterID = Plain(encID), dungeonEncounterID = Plain(dungeonEncID),
                        instanceID = Plain(instID), abilities = {} }
                    if rootSection then Sections(rootSection, b.abilities, guard) end
                    inst.bosses[#inst.bosses + 1] = b
                end
                ej.instances[#ej.instances + 1] = inst
            end
        end
    end
end

-- Otras fuentes de jefes en el cliente, por si el diario no tiene tiers
local function ProbeMore(p)
    local m = { funcs = {} }
    p.more = m
    for _, f in ipairs({ "GetLFGDungeonInfo", "GetLFGDungeonNumEncounters", "GetLFGDungeonEncounterInfo",
        "GetNumSavedInstances", "GetSavedInstanceEncounterInfo", "C_LFGInfo", "C_LFGList" }) do
        m.funcs[f] = Has(f)
    end

    -- 1) diario de encuentros abierto por ID directo (sin tiers)
    m.ejDirect = {}
    if EJ_GetInstanceInfo then
        for id = 1, 3000 do
            local r = { Try(EJ_GetInstanceInfo, id) }
            if r[1] then
                local e = { id = id, name = Plain(r[1]), mapID = Plain(r[10]), bosses = {} }
                for j = 1, 40 do
                    local bname = Try(EJ_GetEncounterInfoByIndex, j, id)
                    if not bname then break end
                    e.bosses[#e.bosses + 1] = Plain(bname)
                end
                m.ejDirect[#m.ejDirect + 1] = e
                if #m.ejDirect >= 200 then break end
            end
        end
    end
    -- encuentros sueltos del diario por ID
    m.ejEncounters = {}
    if EJ_GetEncounterInfo then
        for id = 1, 3000 do
            local name = Try(EJ_GetEncounterInfo, id)
            if name then
                m.ejEncounters[#m.ejEncounters + 1] = { id = id, name = Plain(name) }
                if #m.ejEncounters >= 50 then break end
            end
        end
    end

    -- 2) buscador de grupos: mazmorras y sus jefes
    m.lfg = {}
    if GetLFGDungeonInfo then
        for id = 1, 4000 do
            local r = { Try(GetLFGDungeonInfo, id) }
            if r[1] then
                local e = { id = id, name = Plain(r[1]), typeID = Plain(r[2]), maxPlayers = Plain(r[13]),
                    map22 = Plain(r[22]), map23 = Plain(r[23]), bosses = {} }
                local n = GetLFGDungeonNumEncounters and Try(GetLFGDungeonNumEncounters, id)
                for j = 1, math.min(tonumber(n) or 0, 40) do
                    e.bosses[#e.bosses + 1] = Plain((Try(GetLFGDungeonEncounterInfo, id, j)))
                end
                m.lfg[#m.lfg + 1] = e
                if #m.lfg >= 400 then break end
            end
        end
    end

    -- 3) bloqueos de banda (jefes de las instancias en las que estás guardado)
    m.saved = {}
    local nSaved = GetNumSavedInstances and Try(GetNumSavedInstances) or 0
    for i = 1, math.min(tonumber(nSaved) or 0, 40) do
        local r = { Try(GetSavedInstanceInfo, i) }
        local e = { name = Plain(r[1]), encounters = Plain(r[11]), bosses = {} }
        for j = 1, math.min(tonumber(r[11]) or 0, 40) do
            e.bosses[#e.bosses + 1] = Plain((Try(GetSavedInstanceEncounterInfo, i, j)))
        end
        m.saved[#m.saved + 1] = e
    end
end

-------------------------------------------------------------------------------
-- /mf comprobar: cada hechizo de los datos contra este cliente
-- Guarda en MendFramesDB.check los que no existen y los que no tienen icono.
-------------------------------------------------------------------------------
function ns.CheckData()
    local list = {}
    for _, inst in ipairs(ns.RaidOrder) do
        local def = ns.RaidDebuffs[inst]
        for _, b in ipairs(def.bosses or {}) do
            for key in pairs(b[2] or {}) do
                list[#list + 1] = { inst = inst, boss = b[1], key = key }
            end
        end
    end
    -- pedir al índice todos los nombres (se buscan en segundo plano)
    for _, e in ipairs(list) do
        if type(e.key) == "string" then ns.SpellIDs(ns.KeyName(e.key)) end
    end
    ns.Print(("comprobando %d hechizos de los datos; espera unos segundos..."):format(#list))

    local tries, ticker = 0, nil
    ticker = C_Timer.NewTicker(1, function()
        tries = tries + 1
        local names = ns.db.spellIndex and ns.db.spellIndex.names or {}
        local pending = 0
        for _, e in ipairs(list) do
            if type(e.key) == "string" and names[ns.KeyName(e.key):lower()] == nil then pending = pending + 1 end
        end
        if pending > 0 and tries < 120 then return end
        ticker:Cancel()

        local res = { when = date and date("%Y-%m-%d %H:%M:%S") or "?", total = #list,
            pending = pending, missing = {}, noIcon = {} }
        for _, e in ipairs(list) do
            local label = ("%s | %s | %s"):format(ns.InstanceName(e.inst), e.boss, tostring(e.key))
            local exists
            if type(e.key) == "number" then
                exists = ns.GetSpellName(e.key) ~= nil
            else
                exists = names[ns.KeyName(e.key):lower()] ~= false
            end
            if not exists then
                res.missing[#res.missing + 1] = label
            else
                local _, icon = ns.SpellKeyInfo(e.key)
                if not icon or icon == ns.QUESTION_ICON then res.noIcon[#res.noIcon + 1] = label end
            end
        end
        table.sort(res.missing)
        table.sort(res.noIcon)
        ns.db.check = res
        ns.Print(("comprobado: %d hechizos, %d no existen en este cliente, %d sin icono%s. Escribe |cffffff00/reload|r para guardarlo."):format(
            #list, #res.missing, #res.noIcon, pending > 0 and (", " .. pending .. " sin terminar de buscar") or ""))
        if ns.OnSpellResolved then ns.OnSpellResolved() end
    end)
end

function ns.Probe()
    local p = { when = date and date("%Y-%m-%d %H:%M:%S") or "?" }
    p.build = { Try(GetBuildInfo) }
    for i, v in ipairs(p.build) do p.build[i] = Plain(v) end
    p.locale = Plain(GetLocale and GetLocale())

    -- dónde estás
    local r = { Try(GetInstanceInfo) }
    p.instance = { name = Plain(r[1]), type = Plain(r[2]), difficulty = Plain(r[3]), mapID = Plain(r[8]) }
    p.zone = Plain(GetRealZoneText and GetRealZoneText())
    p.uiMap = Plain(C_Map and C_Map.GetBestMapForUnit and Try(C_Map.GetBestMapForUnit, "player"))

    -- eventos útiles
    p.events = {}
    local valid = C_EventUtils and C_EventUtils.IsEventValid
    for _, e in ipairs({ "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL", "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
        "UNIT_AURA", "COMBAT_LOG_EVENT_UNFILTERED", "ZONE_CHANGED_NEW_AREA" }) do
        p.events[e] = valid and Plain(Try(valid, e)) or "sin C_EventUtils"
    end

    -- APIs de auras (para leerlas cuando son secretas)
    p.auraAPI = {}
    for _, f in ipairs({ "C_UnitAuras.GetAuraDataByIndex", "C_UnitAuras.GetUnitAuras",
        "C_UnitAuras.GetUnitAuraInstanceIDs", "C_UnitAuras.GetAuraDataByAuraInstanceID",
        "C_UnitAuras.GetAuraDuration", "C_UnitAuras.IsAuraFilteredOutByInstanceID",
        "C_UnitAuras.GetAuraApplicationDisplayCount", "C_UnitAuras.GetAuraDispelTypeColor",
        "C_UnitAuras.AuraIsBigDefensive", "AuraUtil.ForEachAura", "AuraUtil.FindAuraByName",
        "C_Secrets", "C_Secrets.ShouldAurasBeSecret", "C_Secrets.ShouldUnitAuraIndexBeSecret",
        "C_Secrets.ShouldUnitAuraInstanceBeSecret", "C_Secrets.ShouldSpellAuraBeSecret" }) do
        p.auraAPI[f] = Has(f)
    end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        p.aurasSecretNow = Plain(Try(C_Secrets.ShouldAurasBeSecret))
    end

    ProbeEJ(p)
    ProbeMore(p)

    ns.db.probe = p
    ns.Print(("otras fuentes: diario por ID %d instancias, %d encuentros; buscador de grupos %d; bloqueos %d."):format(
        #p.more.ejDirect, #p.more.ejEncounters, #p.more.lfg, #p.more.saved))
    local ni, nb, na = 0, 0, 0
    for _, inst in ipairs(p.ej.instances or {}) do
        ni = ni + 1
        for _, b in ipairs(inst.bosses) do
            nb = nb + 1
            na = na + #b.abilities
        end
    end
    ns.Print(("sondeo hecho: diario de encuentros %s (%d instancias, %d jefes, %d habilidades); ENCOUNTER_START: %s."):format(
        p.ej.funcs.EJ_GetInstanceByIndex and "sí" or "no", ni, nb, na, tostring(p.events.ENCOUNTER_START)))
    ns.Print("Escribe |cffffff00/reload|r para que se guarde en el archivo.")
end
