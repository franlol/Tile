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
        healPredTex = FLAT,           -- curación entrante
        absorbTex = FLAT,             -- escudos
        powerColor = "power",         -- maná/energía/ira: power | class | custom
        powerCustom = C(0.3, 0.5, 1),
        powerBrightness = 1,
        powerBgAlpha = 0.8,           -- opacidad del fondo de la barra de recurso
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
    },
    texts = {
        name = {
            show = true, font = FONT, size = 11, outline = "OUTLINE",
            colorMode = "white", color = C(1, 1, 1),
            point = "TOP", x = 0, y = -5, width = 92,
            surname = true,   -- nombre y apellido (Forever); false = solo el nombre
        },
        status = {
            show = true, font = FONT, size = 10, outline = "OUTLINE",
            colorMode = "custom", color = C(0.75, 0.75, 0.75),
            point = "CENTER", x = 0, y = -3,
            -- estados extra (cada uno con su color); Desconectado, Muerto y Fantasma, siempre
            showRes = true, resColor = C(0.3, 1, 0.45),        -- «Resucitando»: le lanzan un resucitar
            showCharm = true, charmColor = C(1, 0.4, 0.8),     -- «Controlado»: bajo control mental
            showSummon = true, summonColor = C(0.7, 0.55, 1),  -- «Invocación»: pendiente, aceptada o rechazada
            showAFK = true, afkColor = C(1, 0.8, 0.3),         -- «Ausente»: AFK
        },
        health = {
            show = true, format = "none", hideFull = true,
            font = FONT, size = 9, outline = "OUTLINE",
            colorMode = "custom", color = C(1, 1, 1),
            point = "BOTTOM", x = 0, y = 5,
        },
    },
    elements = {
        -- when: always | ready (solo durante la comprobación de listos) | ooc (fuera de combate)
        -- onTop: por encima de los indicadores
        role     = { show = true, when = "always", onTop = false, point = "TOPLEFT", x = 2, y = -2, size = 10 },
        leader   = { show = true, when = "always", onTop = false, point = "TOPLEFT", x = 12, y = -1, size = 9 },
        raidIcon = { show = true, when = "always", onTop = false, point = "TOP", x = 0, y = 5, size = 12 },
        ready    = { show = true, when = "ready", onTop = true, point = "CENTER", x = 0, y = 0, size = 18 },
    },
    -- colores por tipo de debuff (bordes y tinte de los indicadores)
    dispelColors = {
        Magic = C(0.2, 0.6, 1), Curse = C(0.6, 0, 1), Disease = C(0.6, 0.4, 0), Poison = C(0, 0.6, 0),
        none = C(0.85, 0.1, 0.1),
    },
    -- indicators: se crea aparte (lista ordenada)
}

-------------------------------------------------------------------------------
-- Indicadores
-- kind: aura (personalizado) | raiddebuff (debuff de jefe) | debuffs
-- type: icon | icons | square | bar | text | border | overlay
-------------------------------------------------------------------------------
ns.indicatorDefaults = {
    name = "Indicador",
    enabled = true,
    kind = "aura",
    type = "square",
    mine = true,            -- solo las mías
    mode = "present",       -- present | missing («le falta»: solo fuera de combate)
    -- spells: bufos de la lista (vacía = todos) · dispellable: los debuffs que el
    -- juego dice que puedo disipar · debuffTypes: debuffs de los tipos marcados
    watch = "spells",
    -- «puedo disipar» / «por tipo»: qué tipos
    dispelTypes = { Magic = true, Curse = true, Disease = true, Poison = true },
    onlyOOC = false,        -- solo fuera de combate
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
    -- tipo «Texto»: qué muestra (time | custom | name | stacks | caster)
    textShow = "time",
    customText = "",
    swipeStyle = "clock",   -- clock | clockReverse | clockEdge | drainV | drainH | bar
    max = 3,
    grow = "LEFT",
    spacing = 1,
    others = false,         -- solo las de los demás (no las mías)
    dispelColor = true,     -- borde según tipo de magia
    onlyDispellable = true,
    -- textos del tiempo y de las cargas (mismo estilo que el resto de textos)
    timerText = { font = FONT, size = 9, outline = "OUTLINE", colorMode = "white", color = C(1, 1, 1),
        point = "CENTER", x = 0, y = 0 },
    stacksText = { font = FONT, size = 9, outline = "OUTLINE", colorMode = "white", color = C(1, 1, 1),
        point = "BOTTOMRIGHT", x = 0, y = 0 },
    showBorder = true,       -- borde negro de iconos, cuadrados y barras
    barOrient = "HORIZONTAL",
    barReverse = false,
    -- barra: qué mide (time | stacks | absorb | heal) y si ocupa un lado entero
    barMeasure = "time",
    barMaxStacks = 5,
    span = "none",          -- none | width | height
    overlayAlpha = 0.6,      -- intensidad del tinte
    tintShape = "up",        -- tinte: up (degradado de abajo arriba) | down (de arriba abajo) | solid (liso)
    typeIcon = true,         -- borde / tinte: icono nativo del tipo (magia, veneno...)
    typeIconSize = 14,
    typeIconPos = { point = "CENTER", x = 0, y = 0 },
    borderInside = false,    -- borde del marco: por dentro (true) o por fuera
    ranks = {},              -- [clave de hechizo] = { [id] = true } IDs elegidos (vacío = todos)
}

local function Ind(t)
    return t
end

function ns.BuiltinIndicators()
    return {
        Ind { name = "Debuff de jefe", kind = "raiddebuff", type = "icon",
            point = "CENTER", x = 0, y = -3, width = 20, height = 20,
            timer = true, stacks = true, dispelColor = true, mine = false },
        Ind { name = "Debuffs", kind = "debuffs", type = "icons",
            point = "BOTTOMLEFT", x = 2, y = 5, width = 12, height = 12, max = 3, grow = "RIGHT",
            timer = false, stacks = true, mine = false, onlyDispellable = false, dispelColor = true },
        Ind { name = "Disipable (borde)", kind = "aura", watch = "dispellable", type = "border",
            width = 2, mine = false, others = false, dispelColor = true },
        ns.RestIndicator(),
    }
end

-- Bebiendo / comiendo: el bufo que hay mientras se bebe o se come (no el
-- «Well Fed» de después). Es un indicador normal: se puede cambiar o borrar.
function ns.RestIndicator()
    return Ind { name = "Bebiendo / comiendo", kind = "aura", type = "icon",
        mine = false, others = false, mode = "present", onlyOOC = true,
        spells = { "n:Drink", "n:Food", "n:Food & Drink", "n:Refreshment" },
        point = "LEFT", x = 2, y = 0, width = 14, height = 14,
        timer = false, stacks = false }
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

-- Completa un indicador con los valores por defecto que le falten
function ns.FixIndicator(ind)
    ns.CopyDefaults(ns.indicatorDefaults, ind)
    return ind
end

-- Añade lo recomendado del catálogo para una clase
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

-- Completa un perfil (y sus indicadores) con los valores por defecto que le falten
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
