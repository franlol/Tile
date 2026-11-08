-------------------------------------------------------------------------------
-- MendFrames - Valores por defecto de perfiles e indicadores
-------------------------------------------------------------------------------

local _, ns = ...

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
ns.FLAT, ns.FONT = FLAT, FONT

local function C(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end

-------------------------------------------------------------------------------
-- Base de datos global (compartida por todos los personajes)
-------------------------------------------------------------------------------
ns.dbDefaults = {
    version = 2,
    locked = true,
    hideBlizzard = true,
    profiles = {},
    chars = {},
    spellIndex = {},     -- índice nombre -> IDs (se rehace si cambia la versión del cliente)
    raid = {
        recorder = true,
        custom = {},     -- [instancia] = { [spellID | "n:Nombre"] = prioridad }
        disabled = {},   -- [instancia] = { [clave] = true }
        seen = {},       -- [instancia] = { [spellID] = { name, icon, count } }
        names = {},      -- [instancia] = nombre visto en el juego
        styles = {},     -- [instancia] = { [clave] = estilo de resaltado }
    },
}

-- Perfil asignado a cada tamaño de grupo (por personaje)
ns.SIZE_KEYS = { "party", "raid10", "raid20", "raid40" }
ns.SIZE_NAMES = {
    party = "Grupo / solo (1-5)",
    raid10 = "Banda de hasta 10",
    raid20 = "Banda de hasta 20",
    raid40 = "Banda de hasta 40",
}
ns.SIZE_TEST = { party = 5, raid10 = 10, raid20 = 20, raid40 = 40 }

-------------------------------------------------------------------------------
-- Perfil
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
        sameSize = true,      -- mismo ancho y alto que los jugadores
        width = 76,
        height = 22,
        perColumn = 5,
    },
    bars = {
        healthTex = FLAT,
        bgTex = FLAT,                 -- textura del fondo
        powerTex = FLAT,
        healthColor = "class",        -- barra: class | custom | gradient
        customColor = C(0.2, 0.75, 0.3),
        bgColor = "class",            -- fondo: mismas opciones que la barra: class | custom | gradient
        bgCustom = C(0.15, 0.15, 0.15),
        smooth = false,               -- vida: animación nativa al llenarse/vaciarse
        powerSmooth = false,          -- maná/energía/ira: animación nativa
        healthBrightness = 1,         -- 0.1..1: oscurece el color de la barra
        bgBrightness = 0.25,          -- 0.1..1: oscurece el color del fondo
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
        auraTooltip = "ooc",          -- tooltip de auras: always | ooc | never
    },
    texts = {
        name = {
            show = true, font = FONT, size = 11, outline = "OUTLINE",
            colorMode = "white", color = C(1, 1, 1),
            point = "TOP", x = 0, y = -5, width = 92,
        },
        status = {
            show = true, font = FONT, size = 10, outline = "OUTLINE",
            colorMode = "custom", color = C(0.75, 0.75, 0.75),
            point = "CENTER", x = 0, y = -3,
        },
        health = {
            show = true, format = "none", hideFull = true,
            font = FONT, size = 9, outline = "OUTLINE",
            colorMode = "custom", color = C(1, 1, 1),
            point = "BOTTOM", x = 0, y = 5,
        },
    },
    elements = {
        role     = { show = true, point = "TOPLEFT", x = 2, y = -2, size = 10 },
        leader   = { show = true, point = "TOPLEFT", x = 12, y = -1, size = 9 },
        raidIcon = { show = true, point = "TOP", x = 0, y = 5, size = 12 },
        ready    = { show = true, point = "CENTER", x = 0, y = 0, size = 18 },
    },
    -- indicators: se crea aparte (lista ordenada)
}

-------------------------------------------------------------------------------
-- Resaltado (brillo, borde/tinte del marco, latido, tamaño, sonido).
-- Lo tienen los indicadores y, como excepción, hechizos concretos.
-------------------------------------------------------------------------------
ns.STYLE_DEFAULTS = {
    glow = "none",
    target = "icon",        -- icon | frame
    color = C(1, 0.85, 0.1),
    lines = 8,
    thickness = 2,
    freq = 0.25,
    glowScale = 1,
    particles = 4,          -- grupos de chispas
    keepColor = false,      -- usar el color original de Blizzard
    offsetX = 0,            -- desplazamiento del brillo
    offsetY = 0,
    border = false,
    borderColor = C(1, 0.1, 0.1),
    tint = false,
    tintColor = C(1, 0.1, 0.1, 0.35),
    pulse = false,
    scale = 1,
    sound = "none",
    soundOnlyMe = false,
}

-------------------------------------------------------------------------------
-- Indicadores
-- kind: aura (personalizado) | raiddebuff | debuffs | dispel
-- type: icon | icons | square | bar | text | border | overlay
-------------------------------------------------------------------------------
ns.indicatorDefaults = {
    name = "Indicador",
    enabled = true,
    kind = "aura",
    type = "square",
    auraType = "HELPFUL",   -- HELPFUL | HARMFUL
    mine = true,            -- solo las mías
    mode = "present",       -- present | missing
    onlyOOC = false,        -- solo fuera de combate
    spells = {},
    point = "TOPRIGHT",
    x = -2,
    y = -2,
    width = 9,
    height = 9,
    color = C(0.2, 1, 0.3),
    warnColor = C(1, 0.25, 0.2),
    warnAt = 0,             -- segundos (0 = sin aviso)
    timer = false,
    stacks = true,
    swipe = true,
    fontSize = 9,
    max = 3,
    grow = "LEFT",
    spacing = 1,
    others = false,         -- solo las de los demás (no las mías)
    dispelColor = true,     -- borde según tipo de magia
    onlyDispellable = true,
    excludeClaimed = true,
    font = FONT,             -- fuente del tiempo y las cargas
    timerPoint = "CENTER",   -- dónde va el tiempo dentro del elemento
    stacksPoint = "BOTTOMRIGHT",
    showBorder = true,       -- borde negro de iconos, cuadrados y barras
    barOrient = "HORIZONTAL",
    barReverse = false,
    overlayAlpha = 0.6,      -- intensidad del tinte (Disipable)
    showBelow = 0,           -- solo mostrar si quedan menos de N s (0 = siempre)
    blacklist = {},          -- Debuffs: hechizos que no se muestran
    hl = ns.STYLE_DEFAULTS,  -- resaltado del indicador (se copia)
    spellStyles = {},        -- [clave de hechizo] = resaltado propio (sustituye al del indicador)
    ranks = {},              -- [clave de hechizo] = { [id] = true } IDs elegidos (vacío = todos)
    exact = {},              -- (antiguo, se lee por compatibilidad)
}

local function Ind(t)
    return t
end

function ns.BuiltinIndicators()
    return {
        Ind { name = "Debuff de banda", kind = "raiddebuff", type = "icon",
            point = "CENTER", x = 0, y = -3, width = 20, height = 20,
            timer = true, stacks = true, dispelColor = true, auraType = "HARMFUL", mine = false },
        Ind { name = "Debuffs", kind = "debuffs", type = "icons",
            point = "BOTTOMLEFT", x = 2, y = 5, width = 12, height = 12, max = 3, grow = "RIGHT",
            timer = false, stacks = true, auraType = "HARMFUL", mine = false,
            onlyDispellable = false, excludeClaimed = true, dispelColor = true },
        Ind { name = "Disipable (borde)", kind = "dispel", type = "border",
            width = 2, onlyDispellable = true, auraType = "HARMFUL", mine = false, dispelColor = true },
    }
end

-- Nombres de clase (el catálogo de hechizos está en Catalog.lua)
ns.CLASS_NAMES = {
    PRIEST = "Sacerdote", DRUID = "Druida", PALADIN = "Paladín", SHAMAN = "Chamán",
    MAGE = "Mago", WARRIOR = "Guerrero", ROGUE = "Pícaro", HUNTER = "Cazador", WARLOCK = "Brujo",
}
ns.CLASS_ORDER = { "PRIEST", "DRUID", "PALADIN", "SHAMAN", "MAGE", "WARRIOR", "ROGUE", "HUNTER", "WARLOCK", "GENERAL" }

-------------------------------------------------------------------------------
-- Utilidades de perfiles
-------------------------------------------------------------------------------
function ns.DeepCopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = ns.DeepCopy(v) end
    return o
end

function ns.FixIndicator(ind)
    ns.CopyDefaults(ns.indicatorDefaults, ind)
    return ind
end

-- Añade lo recomendado del catálogo para una clase
function ns.AddRecommended(list, class)
    local plan = {
        { key = "hots", origin = "mine", mode = "present" },
        { key = "raidbuffs", origin = "any", mode = "missing" },
        { key = "healdebuffs", origin = "any", mode = "present" },
    }
    local added = 0
    for _, p in ipairs(plan) do
        local g = ns.CatalogByKey and ns.CatalogByKey[p.key]
        local entries = g and ns.CatalogRecommended(g, class) or {}
        -- de los debufos importantes, solo los que provoca la propia clase
        if p.key == "healdebuffs" then
            local mine = {}
            for _, e in ipairs(entries) do if e.class == class then table.insert(mine, e) end end
            entries = mine
        end
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

function ns.FixProfile(p)
    local inds = p.indicators
    p.indicators = nil
    -- antiguo "Color" único -> color de barra + color de fondo
    local b = p.bars
    if b and b.colorMode and b.healthColor == nil then
        if b.colorMode == "dark" then
            b.healthColor, b.bgColor = "custom", "class"
            b.customColor = C(0.18, 0.18, 0.18)
        elseif b.colorMode == "custom" then
            b.healthColor, b.bgColor = "custom", "dark"
        else
            b.healthColor, b.bgColor = "class", "dark"
        end
        b.colorMode = nil
    end
    -- textura del fondo sin elegir (antes "igual que la barra"): la de la barra
    if b and (b.bgTex == nil or b.bgTex == "") and b.healthTex then
        b.bgTex = b.healthTex
    end
    -- antiguo fondo "barra oscurecida" -> mismas opciones que la barra + brillo
    if b and b.bgColor == "dark" then
        if b.healthColor == "custom" and b.customColor then
            local cc = b.customColor
            b.bgColor, b.bgCustom = "custom", C(cc.r * 0.25, cc.g * 0.25, cc.b * 0.25)
        else
            b.bgColor = b.healthColor or "class"
            b.bgBrightness = 0.25
        end
    end
    ns.CopyDefaults(ns.profileDefaults, p)
    if type(inds) ~= "table" then
        local _, class = UnitClass("player")
        inds = ns.DefaultIndicators(class)
    end
    for _, ind in ipairs(inds) do ns.FixIndicator(ind) end
    p.indicators = inds
    return p
end
