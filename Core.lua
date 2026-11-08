-------------------------------------------------------------------------------
-- MendFrames - Core
-- Marcos de banda para sanadores pensados para WoW Forever (motor 12.x).
-- En instancias y en combate el cliente puede devolver "valores secretos":
-- se pueden pasar a los widgets (SetValue, SetText, SetTexture...) pero no se
-- pueden comparar ni operar. Todo el addon pasa por los helpers de aquí.
-------------------------------------------------------------------------------

local ADDON, ns = ...
_G.MendFrames = ns

ns.version = "0.2.0"

-------------------------------------------------------------------------------
-- Valores secretos
-------------------------------------------------------------------------------
local issecretvalue = _G.issecretvalue or function() return false end

function ns.S(v) return issecretvalue(v) end

function ns.R(v)
    if issecretvalue(v) then return nil end
    return v
end

function ns.AnyS(...)
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return true end
    end
    return false
end

ns.sawSecret = false
function ns.MarkSecret() ns.sawSecret = true end

-------------------------------------------------------------------------------
-- Utilidades
-------------------------------------------------------------------------------
function ns.Print(...)
    print("|cff4fc3f7MendFrames|r:", ...)
end

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
ns.CopyDefaults = CopyDefaults

ns.GetSpellName = (C_Spell and C_Spell.GetSpellName) or function(id)
    return (GetSpellInfo and GetSpellInfo(id)) or nil
end

ns.GetSpellIcon = (C_Spell and C_Spell.GetSpellTexture) or function(id)
    return GetSpellTexture and GetSpellTexture(id)
end

function ns.SpellIDFromName(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        if info and info.spellID then return info.spellID end
    elseif GetSpellInfo then
        local id = select(7, GetSpellInfo(name))
        if id then return id end
    end
end

-------------------------------------------------------------------------------
-- Índice nativo nombre -> todos los IDs de hechizo (todos los rangos)
--
-- La identidad de un hechizo es su nombre, tal como lo da el cliente. Los IDs
-- no se escriben a mano: se le piden al cliente recorriendo sus hechizos en
-- segundo plano (unos miles por fotograma) solo para los nombres que usa el
-- addon. El índice se guarda y se rehace si cambia la versión del cliente, así
-- que rangos nuevos, IDs nuevos o expansiones se recogen solos.
-------------------------------------------------------------------------------
local SCAN_MAX, SCAN_STEP = 1500000, 5000
local pending = {}   -- [nombre en minúsculas] = { left = IDs por revisar, ids = {} }
local scanID = 1
local scanFrame = CreateFrame("Frame")
scanFrame:Hide()

local function ClientBuild()
    local version, build = GetBuildInfo()
    return tostring(version) .. "." .. tostring(build)
end

local function Index()
    local idx = ns.db.spellIndex
    if type(idx) ~= "table" or idx.build ~= ClientBuild() then
        idx = { build = ClientBuild(), names = {} }
        ns.db.spellIndex = idx
    end
    return idx
end

scanFrame:SetScript("OnUpdate", function(self)
    local last = math.min(SCAN_MAX, scanID + SCAN_STEP - 1)
    for id = scanID, last do
        local name = ns.GetSpellName(id)
        if name then
            local p = pending[name:lower()]
            if p then p.ids[#p.ids + 1] = id end
        end
    end
    local step = last - scanID + 1
    scanID = last + 1
    if scanID > SCAN_MAX then scanID = 1 end

    local names, finished = Index().names, false
    for lower, p in pairs(pending) do
        p.left = p.left - step
        if p.left <= 0 then
            table.sort(p.ids)
            names[lower] = (#p.ids > 0) and p.ids or false   -- false: no existe en este cliente
            pending[lower] = nil
            finished = true
        end
    end
    if finished and ns.OnSpellIndexUpdated then ns.OnSpellIndexUpdated() end
    if not next(pending) then self:Hide() end
end)

-- Todos los IDs de un nombre (lista ordenada), o nil si aún se están buscando
function ns.SpellIDs(name)
    if not name or name == "" or not ns.db then return nil end
    local lower = name:lower()
    local v = Index().names[lower]
    if v == nil then
        if not pending[lower] then
            pending[lower] = { left = SCAN_MAX, ids = {} }
            scanFrame:Show()
        end
        return nil
    end
    return v or nil
end

-- Un ID para un nombre (el del libro de hechizos si lo conoces, si no el primero)
function ns.ResolveName(name)
    if not name or name == "" then return nil end
    local id = ns.SpellIDFromName(name)
    if id then return id end
    local ids = ns.SpellIDs(name)
    return ids and ids[1]
end

-- Nombre de una clave de hechizo (número o "n:Nombre")
function ns.KeyName(key)
    if type(key) == "number" then return ns.GetSpellName(key) end
    if type(key) == "string" then return key:match("^n:(.+)$") or key end
end

-- Todos los IDs de una clave de hechizo. La comparación es SOLO por ID: el
-- nombre únicamente sirve para encontrar, una vez, todos los IDs (rangos).
-- pick: IDs elegidos a mano ({ [id] = true }). Si hay alguno, solo esos;
-- si no hay ninguno, todos los IDs del hechizo.
function ns.KeyIDs(key, pick)
    if type(pick) == "number" then return { pick } end
    if type(pick) == "table" and next(pick) then
        local out = {}
        for id in pairs(pick) do out[#out + 1] = id end
        table.sort(out)
        return out
    end
    local out = {}
    if type(key) == "number" then out[1] = key end
    local name = ns.KeyName(key)
    if name then
        for _, id in ipairs(ns.SpellIDs(name) or {}) do
            if id ~= key then out[#out + 1] = id end
        end
    end
    return out
end

-- Registra una clave en una tabla de búsqueda por ID
function ns.AddSpellKey(byID, _, key, value, rankID)
    for _, id in ipairs(ns.KeyIDs(key, rankID)) do
        if byID[id] == nil then byID[id] = value end
    end
end

-- Rangos de jugador de un hechizo: { { rank = 1, id = 139 }, ... }
-- Solo cuentan los IDs que el juego marca con un rango ("Rank N"); las
-- versiones de PNJ u objetos con el mismo nombre no tienen rango y se ignoran.
local GetSubtext = (C_Spell and C_Spell.GetSpellSubtext) or GetSpellSubtext
function ns.SpellRanks(key)
    local out, seen = {}, {}
    if not GetSubtext then return out end
    for _, id in ipairs(ns.KeyIDs(key)) do
        local sub = GetSubtext(id)
        local n = type(sub) == "string" and tonumber(sub:match("(%d+)"))
        if n and not seen[n] then
            seen[n] = true
            out[#out + 1] = { rank = n, id = id }
        end
    end
    table.sort(out, function(a, b) return a.rank < b.rank end)
    return out
end

-- IDs elegidos a mano para un hechizo de un indicador ({ [id] = true }),
-- o nil si no hay ninguno (= todos los IDs del hechizo)
function ns.KeyRank(cfg, key)
    local r = cfg.ranks and cfg.ranks[key]
    if type(r) == "number" then r = { [r] = true } cfg.ranks[key] = r end   -- formato anterior
    if type(r) == "table" and next(r) then return r end
    -- compatibilidad con el antiguo botón "ID"
    if cfg.exact and cfg.exact[key] and type(key) == "number" then return { [key] = true } end
end

-- Texto del rango de un ID ("Rank 3"), si el juego lo tiene
function ns.SpellSubtext(id)
    local sub = GetSubtext and GetSubtext(id)
    if type(sub) == "string" and sub ~= "" then return sub end
end

-- Cuando el índice encuentra IDs nuevos: recompilar lo que depende de ellos
function ns.OnSpellIndexUpdated()
    if ns.P and ns.CompileIndicators then ns.CompileIndicators() end
    if ns.RebuildDebuffLookup then ns.RebuildDebuffLookup() end
    if ns.OnSpellResolved then ns.OnSpellResolved() end
end

-- Nombre e icono de una clave de hechizo (número o "n:Nombre")
function ns.SpellKeyInfo(key)
    if type(key) == "number" then
        return ns.GetSpellName(key) or ("?" .. key), ns.GetSpellIcon(key)
    end
    local name = type(key) == "string" and (key:match("^n:(.+)$") or key) or nil
    if not name then return "?", nil end
    local id = ns.ResolveName(name)
    return (id and ns.GetSpellName(id)) or name, id and ns.GetSpellIcon(id), id
end

-- Convierte lo que escribe el usuario en una clave de hechizo.
-- Un nombre se guarda como nombre (vale cualquier rango); su icono e ID se
-- buscan en segundo plano.
function ns.ParseSpellInput(txt)
    txt = (txt or ""):trim()
    if txt == "" then return nil end
    local n = tonumber(txt)
    if n then return n end
    local id = ns.SpellIDFromName(txt)
    if id then return id end
    ns.ResolveName(txt)
    return "n:" .. txt
end

-------------------------------------------------------------------------------
-- Cola para cosas que no se pueden hacer en combate
-------------------------------------------------------------------------------
ns.pending = {}
ns.pendingOrder = {}
function ns.RunOOC(key, func)
    if InCombatLockdown() then
        if not ns.pending[key] then table.insert(ns.pendingOrder, key) end
        ns.pending[key] = func
    else
        func()
    end
end

-------------------------------------------------------------------------------
-- Perfiles
-------------------------------------------------------------------------------
function ns.CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

function ns.CharProfiles()
    local c = ns.db.chars[ns.charKey]
    if not c then
        c = {}
        ns.db.chars[ns.charKey] = c
    end
    for _, k in ipairs(ns.SIZE_KEYS) do
        if not c[k] or not ns.db.profiles[c[k]] then c[k] = "Default" end
    end
    return c
end

-- Tamaño real del grupo (sin contar el modo prueba)
function ns.RealSizeKey()
    if IsInRaid() then
        local n = GetNumGroupMembers()
        if n <= 10 then return "raid10" end
        if n <= 20 then return "raid20" end
        return "raid40"
    end
    return "party"
end

function ns.SizeKey()
    if ns.testing then return ns.testSize or "raid20" end
    return ns.RealSizeKey()
end

-- Perfil que se está viendo ahora mismo. En modo prueba se ve el que se
-- edita en las opciones: así lo que cambias siempre se ve al momento.
function ns.ActiveProfileName()
    if ns.testing and ns.editName and ns.db.profiles[ns.editName] then return ns.editName end
    return ns.CharProfiles()[ns.SizeKey()]
end

-- Perfil que se edita en las opciones (por defecto, el activo)
function ns.EditedProfileName()
    if ns.editName and ns.db.profiles[ns.editName] then return ns.editName end
    return ns.ActiveProfileName()
end
function ns.EP() return ns.db.profiles[ns.EditedProfileName()] end

function ns.ActivateProfile(force)
    local name = ns.ActiveProfileName()
    if name == ns.activeName and not force then return end
    ns.activeName = name
    ns.P = ns.db.profiles[name]
    if ns.header and ns.ApplyProfile then ns.ApplyProfile() end
    if ns.OnProfileChanged then ns.OnProfileChanged() end
end

-- Tras cambiar una opción del perfil editado
function ns.ProfileChanged()
    if ns.EditedProfileName() == ns.activeName then
        ns.ApplyProfile()
    end
end

-------------------------------------------------------------------------------
-- Instancia actual y tabla de debuffs de banda
-------------------------------------------------------------------------------
ns.instKey = 0
ns.instName = nil
ns.inInstance = false

ns.debuffByID = {}
ns.debuffByName = {}

function ns.GetDebuffList(key)
    local out = {}
    local def = ns.RaidDebuffs[key]
    if def then
        for id, prio in pairs(def.spells) do out[id] = { prio = prio, default = true } end
    end
    local custom = ns.db.raid.custom[key]
    if custom then
        for id, prio in pairs(custom) do
            if out[id] then
                out[id].prio = prio
                out[id].changed = true
            else
                out[id] = { prio = prio, custom = true }
            end
        end
    end
    local disabled = ns.db.raid.disabled[key]
    if disabled then
        for id, e in pairs(out) do
            if disabled[id] then e.disabled = true end
        end
    end
    return out
end

-- Debuff de banda: se reconoce por su nombre y por todos sus IDs (todos los rangos)
local function AddDebuff(key, prio)
    for _, id in ipairs(ns.KeyIDs(key)) do
        if (ns.debuffByID[id] or 0) < prio then ns.debuffByID[id] = prio end
    end
end
ns.styleByID = {}
ns.styleByName = {}

-- Estilo de resaltado de un debuff (nil si no tiene). create = crearlo.
function ns.GetDebuffStyle(instKey, key, create)
    local t = ns.db.raid.styles[instKey]
    local s = t and t[key]
    if not s and create then
        if not t then t = {} ns.db.raid.styles[instKey] = t end
        s = CopyDefaults(ns.STYLE_DEFAULTS, {})
        t[key] = s
    end
    return s
end

function ns.RebuildDebuffLookup()
    wipe(ns.debuffByID)
    wipe(ns.debuffByName)
    wipe(ns.styleByID)
    wipe(ns.styleByName)
    local keys = { 0 }
    if ns.instKey ~= 0 then keys[2] = ns.instKey end
    for _, key in ipairs(keys) do
        for id, e in pairs(ns.GetDebuffList(key)) do
            if not e.disabled and e.prio and e.prio > 0 then AddDebuff(id, e.prio) end
        end
        for id, s in pairs(ns.db.raid.styles[key] or {}) do
            CopyDefaults(ns.STYLE_DEFAULTS, s)
            -- el de la instancia sustituye al global: se asigna siempre
            for _, sid in ipairs(ns.KeyIDs(id)) do ns.styleByID[sid] = s end
        end
    end
    ns.styleVersion = (ns.styleVersion or 0) + 1
    if ns.UpdateAllButtons then ns.UpdateAllButtons() end
    if ns.testing and ns.LayoutTest then ns.LayoutTest() end
end

local function UpdateInstance()
    local name, instType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if (instType == "raid" or instType == "party") and instanceID and not ns.S(instanceID) then
        ns.instKey = instanceID
        ns.instName = name
        ns.inInstance = true
        if name and not ns.S(name) then ns.db.raid.names[instanceID] = name end
    else
        ns.instKey = 0
        ns.instName = nil
        ns.inInstance = false
    end
    ns.RebuildDebuffLookup()
end

function ns.RecordDebuff(spellID, name, icon)
    if not ns.db.raid.recorder or not ns.inInstance then return end
    if ns.debuffByID[spellID] then return end
    local key = ns.instKey
    local seen = ns.db.raid.seen[key]
    if not seen then
        seen = {}
        ns.db.raid.seen[key] = seen
    end
    local e = seen[spellID]
    if e then
        e.count = (e.count or 0) + 1
        return
    end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    if n >= 150 then return end
    seen[spellID] = { name = name, icon = icon, count = 1 }
end

-------------------------------------------------------------------------------
-- Ocultar los marcos de banda de Blizzard
-------------------------------------------------------------------------------
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

function ns.HideBlizzard()
    if not ns.db.hideBlizzard then return end
    ns.RunOOC("hideBlizzard", function()
        for _, name in ipairs({ "CompactRaidFrameManager", "CompactRaidFrameContainer", "CompactPartyFrame", "PartyFrame" }) do
            local f = _G[name]
            if f then
                pcall(f.UnregisterAllEvents, f)
                pcall(f.SetParent, f, hiddenParent)
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Carga de la base de datos (con migración desde la 0.1)
-------------------------------------------------------------------------------
local function LoadDB()
    local old = MendFramesDB
    if type(old) == "table" and not old.version then
        local db = { raid = old.raid, hideBlizzard = old.layout and old.layout.hideBlizzard }
        local p = ns.NewProfile()
        for _, k in ipairs({ "width", "height", "spacing", "groupSpacing", "orientation", "groupBy",
            "scale", "showSolo", "showParty", "showPlayer" }) do
            if old.layout and old.layout[k] ~= nil then p.layout[k] = old.layout[k] end
        end
        if old.pets then
            for k, v in pairs(old.pets) do if p.pets[k] ~= nil then p.pets[k] = v end end
        end
        if old.pos then p.pos = old.pos end
        db.profiles = { Default = p }
        MendFramesDB = db
    end
    MendFramesDB = CopyDefaults(ns.dbDefaults, MendFramesDB)
    ns.db = MendFramesDB
    if not next(ns.db.profiles) then
        ns.db.profiles.Default = ns.NewProfile()
    end
    if not ns.db.profiles.Default then
        ns.db.profiles.Default = ns.NewProfile()
    end
    for _, p in pairs(ns.db.profiles) do ns.FixProfile(p) end
end

-------------------------------------------------------------------------------
-- Eventos
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ns.eventFrame = ev
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")

ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        LoadDB()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        ns.charKey = ns.CharKey()
        ns.CharProfiles()
        ns.activeName = ns.ActiveProfileName()
        ns.P = ns.db.profiles[ns.activeName]
        ns.CreateFrames()
        ns.HideBlizzard()
        ns.Print("cargado. Escribe |cffffff00/mf|r para abrir las opciones.")
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        UpdateInstance()
        if ns.header then ns.ActivateProfile() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if ns.header then ns.ActivateProfile() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if ns.db and not ns.db.locked then
            ns.SetLocked(true)
            ns.Print("marcos bloqueados al entrar en combate.")
        end
        if ns.UpdateAllButtons then ns.UpdateAllButtons() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        local order = ns.pendingOrder
        ns.pendingOrder = {}
        for _, key in ipairs(order) do
            local func = ns.pending[key]
            ns.pending[key] = nil
            if func then func() end
        end
        if ns.UpdateAllButtons then ns.UpdateAllButtons() end
    end
end)

-------------------------------------------------------------------------------
-- Comandos
-------------------------------------------------------------------------------
SLASH_MENDFRAMES1 = "/mf"
SLASH_MENDFRAMES2 = "/mendframes"
SlashCmdList.MENDFRAMES = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "lock" or msg == "bloquear" then
        ns.SetLocked(true)
    elseif msg == "unlock" or msg == "mover" or msg == "desbloquear" then
        ns.SetLocked(false)
    elseif msg == "demo" or msg == "muestra" then
        ns.ToggleDemo()
    elseif msg == "nativos" then
        -- diagnóstico temporal: ¿tiene este cliente los componentes nativos de Blizzard?
        local function T(kind, tmpl)
            local ok = pcall(CreateFrame, kind, nil, UIParent, tmpl)
            return ok and "|cff55ff55sí|r" or "|cffff5555no|r"
        end
        ns.Print("UIPanelScrollFrameTemplate: " .. T("ScrollFrame", "UIPanelScrollFrameTemplate"))
        ns.Print("ScrollFrameTemplate: " .. T("ScrollFrame", "ScrollFrameTemplate"))
        ns.Print("WowScrollBoxList: " .. T("Frame", "WowScrollBoxList"))
        ns.Print("MinimalScrollBar: " .. T("EventFrame", "MinimalScrollBar"))
        ns.Print("WowStyle1DropdownTemplate: " .. T("DropdownButton", "WowStyle1DropdownTemplate"))
        ns.Print("ScrollUtil: " .. (ScrollUtil and "|cff55ff55sí|r" or "|cffff5555no|r")
            .. "  MenuUtil: " .. (MenuUtil and "|cff55ff55sí|r" or "|cffff5555no|r")
            .. "  CreateScrollBoxListLinearView: " .. (CreateScrollBoxListLinearView and "|cff55ff55sí|r" or "|cffff5555no|r"))
    elseif msg == "test" or msg == "prueba" then
        ns.ToggleTest()
    elseif msg == "brillos" or msg == "glows" then
        ns.Glow.Diagnose()
    elseif msg == "estado" or msg == "status" then
        local n = 0
        for _ in pairs(ns.debuffByID) do n = n + 1 end
        ns.Print(("perfil: %s (%s) | instancia: %s (%s) | valores secretos vistos: %s | debuffs de banda activos: %d"):format(
            tostring(ns.activeName), ns.SIZE_NAMES[ns.SizeKey()] or "?",
            tostring(ns.instName or "ninguna"), tostring(ns.instKey),
            ns.sawSecret and "sí" or "no", n))
    elseif msg == "reset" then
        ns.RunOOC("reset", function()
            ns.P.pos = ns.DeepCopy(ns.profileDefaults.pos)
            ns.ApplyPositions()
            ns.Print("posiciones restablecidas.")
        end)
    else
        ns.ToggleOptions()
    end
end
