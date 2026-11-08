-------------------------------------------------------------------------------
-- MendFrames - Indicadores (estilo Cell)
-- Cada indicador del perfil vigila unas auras y las dibuja en un sitio fijo
-- del marco: icono, varios iconos, cuadrado de color, barra o texto.
-------------------------------------------------------------------------------

local _, ns = ...
local S, R, AnyS = ns.S, ns.R, ns.AnyS

local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local GetUnitAuras = C_UnitAuras and C_UnitAuras.GetUnitAuras
local GetAuraInstanceIDs = C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs
local GetAuraByInstance = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
local GetAuraDuration = C_UnitAuras and C_UnitAuras.GetAuraDuration
local GetAuraApplicationDisplayCount = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount

local FLAT = "Interface\\Buttons\\WHITE8X8"

ns.DISPEL_COLORS = {
    Magic   = { 0.2, 0.6, 1.0 },
    Curse   = { 0.6, 0.0, 1.0 },
    Disease = { 0.6, 0.4, 0.0 },
    Poison  = { 0.0, 0.6, 0.0 },
    none    = { 0.85, 0.1, 0.1 },
}

-- Iconos nativos de cada tipo (los de los marcos de banda de Blizzard)
ns.DISPEL_ICONS = {
    Magic   = "Interface\\RaidFrame\\Raid-Icon-DebuffMagic",
    Curse   = "Interface\\RaidFrame\\Raid-Icon-DebuffCurse",
    Disease = "Interface\\RaidFrame\\Raid-Icon-DebuffDisease",
    Poison  = "Interface\\RaidFrame\\Raid-Icon-DebuffPoison",
}

-- Texto con el icono del tipo delante (para las opciones)
function ns.DispelLabel(t, text)
    local icon = ns.DISPEL_ICONS[t]
    if not icon then return text end
    return ("|T%s:14:14:0:0|t %s"):format(icon, text)
end

-- Color de un tipo de debuff: el del perfil (configurable) o el de siempre
function ns.DispelColor(t)
    local c = ns.P and ns.P.dispelColors and ns.P.dispelColors[t]
    if c then return c.r, c.g, c.b end
    local d = ns.DISPEL_COLORS[t]
    if d then return d[1], d[2], d[3] end
    return nil
end

-------------------------------------------------------------------------------
-- Indicadores compilados del perfil activo
-------------------------------------------------------------------------------
ns.compiled = {}

local ORDER = { raiddebuff = 1, aura = 2, debuffs = 3 }

function ns.CompileIndicators()
    wipe(ns.compiled)
    for i, cfg in ipairs(ns.P.indicators) do
        ns.CopyDefaults(ns.STYLE_DEFAULTS, cfg.hl)
        for _, s in pairs(cfg.spellStyles) do ns.CopyDefaults(ns.STYLE_DEFAULTS, s) end
        if cfg.enabled then
            local c = { index = i, cfg = cfg, kind = cfg.kind, byID = {}, byName = {} }
            if cfg.kind == "debuffs" then
                -- lista negra: debuffs que este indicador no muestra
                c.blackID, c.blackName = {}, {}
                for _, key in ipairs(cfg.blacklist) do
                    ns.AddSpellKey(c.blackID, c.blackName, key, true, ns.KeyRank(cfg, key))
                end
            end
            if cfg.kind == "aura" and (cfg.watch == "dispellable" or cfg.watch == "debuffTypes") then
                -- el juego filtra los debuffs que puedo disipar (HARMFUL|RAID)
                c.filter = cfg.watch == "debuffTypes" and "HARMFUL" or "HARMFUL|RAID"
                c.any = true
                c.dispellable = true
            elseif cfg.kind == "aura" then
                c.filter = (cfg.auraType == "HARMFUL" and "HARMFUL" or "HELPFUL")
                    .. ((cfg.mine and not cfg.others) and "|PLAYER" or "")
                c.others = cfg.others
                c.any = #cfg.spells == 0
                -- por nombre y todos sus IDs (todos los rangos), salvo "solo este ID"
                for order, key in ipairs(cfg.spells) do
                    ns.AddSpellKey(c.byID, c.byName, key, order, ns.KeyRank(cfg, key))
                end
            end
            table.insert(ns.compiled, c)
        end
    end
    ns.styleVersion = (ns.styleVersion or 0) + 1
    -- primero los que "reclaman" auras, luego los genéricos
    table.sort(ns.compiled, function(a, b)
        local oa, ob = ORDER[a.kind] or 9, ORDER[b.kind] or 9
        if oa ~= ob then return oa < ob end
        return a.index < b.index
    end)
end

-- Devuelve (orden o nil, legible)
-- Solo por ID (los IDs de todos los rangos ya están en byID)
local function Match(aura, byID)
    local id = aura.spellId
    if S(id) then
        ns.MarkSecret()
        return nil, false
    end
    if id and byID[id] then return byID[id], true end
    return nil, true
end

-------------------------------------------------------------------------------
-- Temporizadores legibles (texto de tiempo, barras, color de aviso)
-------------------------------------------------------------------------------
local timers = {}   -- [widget] = { exp, dur, cfg }

-- Barras que miden algo del jugador (no de un aura): escudos o curación entrante
local function UnitMeasure(cfg)
    local m = cfg.type == "bar" and cfg.barMeasure
    return m == "absorb" or m == "heal"
end
ns.IndicatorUnitMeasure = UnitMeasure

local function V(v)
    if S(v) then return v end
    return v or 0
end

-- ¿Este widget escribe el tiempo restante? (el tipo «Texto» puede mostrar otra cosa)
function ns.ShowsTime(w, cfg)
    if w.wtype == "text" then return (cfg.textShow or "time") == "time" end
    return cfg.timer and true or false
end

local function FormatTime(t)
    if t >= 60 then return ("%dm"):format(math.ceil(t / 60)) end
    if t >= 3 then return ("%d"):format(math.ceil(t)) end
    return ("%.1f"):format(t)
end

-- Color de aviso: cuadrado/barra/texto cambian su color; iconos, su borde
local function SetWarn(w, cfg, warn)
    if w.SetMainColor then
        w:SetMainColor(warn and cfg.warnColor or cfg.color)
    elseif w.border then
        if warn then
            local c = cfg.warnColor
            w.border:SetColorTexture(c.r, c.g, c.b, 1)
        else
            local c = w.baseBorder or { 0, 0, 0 }
            w.border:SetColorTexture(c[1], c[2], c[3], 1)
        end
    end
end

-- Actualiza un temporizador; devuelve false si ya terminó
local function TickTimer(w, e, now)
    local remain = e.exp - now
    if remain <= 0 then
        if w.timerText then w.timerText:SetText("") end
        return false
    end
    local cfg = e.cfg
    if w.timerText and ns.ShowsTime(w, cfg) then w.timerText:SetText(FormatTime(remain)) end
    if w.bar and (cfg.barMeasure or "time") == "time" then w.bar:SetValue(remain / e.dur) end
    if w.drainOn then w.drain:SetValue(1 - remain / e.dur) end
    local warn = cfg.warnAt > 0 and remain <= cfg.warnAt
    if warn ~= e.warned then
        e.warned = warn
        SetWarn(w, cfg, warn)
    end
    -- "mostrar solo si quedan menos de N s"
    if (cfg.showBelow or 0) > 0 and cfg.mode ~= "missing" then
        local show = remain <= cfg.showBelow
        if show ~= w:IsShown() then w:SetShown(show) end
    end
    return true
end

local tick = CreateFrame("Frame")
local elapsedTotal = 0
tick:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 0.1 then return end
    elapsedTotal = 0
    local now = GetTime()
    for w, e in pairs(timers) do
        if not TickTimer(w, e, now) then timers[w] = nil end
    end
end)

-------------------------------------------------------------------------------
-- Widgets
-------------------------------------------------------------------------------
local function TimerText(f, parent)
    local t = (parent or f):CreateFontString(nil, "OVERLAY")
    t:SetPoint("CENTER", 0, 0)
    f.timerText = t
    return t
end

local function CountText(f, parent)
    local t = (parent or f):CreateFontString(nil, "OVERLAY")
    t:SetPoint("BOTTOMRIGHT", 2, -1)
    f.count = t
    return t
end

local function NewCooldown(f)
    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:SetReverse(true)
    cd:SetDrawEdge(false)
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    f.cd = cd
    -- vaciado (vertical, horizontal o barra fina): alternativa al reloj
    local drain = CreateFrame("StatusBar", nil, f)
    drain:SetStatusBarTexture(FLAT)
    drain:SetMinMaxValues(0, 1)
    drain:SetFrameLevel(cd:GetFrameLevel())
    drain.bg = drain:CreateTexture(nil, "BACKGROUND")
    drain.bg:SetAllPoints()
    drain.bg:SetTexture(FLAT)
    drain:Hide()
    f.drain = drain
    -- textos por encima del barrido
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints()
    top:SetFrameLevel(cd:GetFrameLevel() + 2)
    f.top = top
    return cd
end

function ns.CreateIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border:SetColorTexture(0, 0, 0, 1)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    NewCooldown(f)
    TimerText(f, f.top)
    CountText(f, f.top)
    f:Hide()
    return f
end

local creators = {}

creators.icon = function(parent)
    local f = ns.CreateIcon(parent)
    f.wtype = "icon"
    return f
end

creators.icons = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "icons"
    f.icons = {}
    return f
end

creators.square = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "square"
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border:SetColorTexture(0, 0, 0, 1)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexture(FLAT)
    NewCooldown(f)
    TimerText(f, f.top)
    CountText(f, f.top)
    f.SetMainColor = function(self, c) self.tex:SetVertexColor(c.r, c.g, c.b, c.a or 1) end
    f:Hide()
    return f
end

creators.bar = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "bar"
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border:SetColorTexture(0, 0, 0, 0.8)
    f.bg = f:CreateTexture(nil, "BORDER")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.5)
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetAllPoints()
    f.bar:SetStatusBarTexture(FLAT)
    f.bar:SetMinMaxValues(0, 1)
    -- textos por encima de la barra
    f.top = CreateFrame("Frame", nil, f)
    f.top:SetAllPoints()
    f.top:SetFrameLevel(f.bar:GetFrameLevel() + 2)
    TimerText(f, f.top)
    CountText(f, f.top)
    f.SetMainColor = function(self, c) self.bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1) end
    f:Hide()
    return f
end

creators.text = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "text"
    f:SetSize(30, 12)
    NewCooldown(f)
    f.cd:SetDrawSwipe(false)
    TimerText(f, f.top)
    CountText(f, f.top)
    f.SetMainColor = function(self, c)
        self.timerText:SetTextColor(c.r, c.g, c.b, c.a or 1)
        -- números del reloj de Blizzard (se usan cuando la duración es secreta)
        local fs = self.cd.GetCountdownFontString and self.cd:GetCountdownFontString()
        if fs then fs:SetTextColor(c.r, c.g, c.b, c.a or 1) end
    end
    f:Hide()
    return f
end

-- Icono nativo del tipo (magia, veneno...) encima del borde o del tinte
local function AddTypeIcon(f)
    f.typeIcon = f:CreateTexture(nil, "OVERLAY", nil, 7)
    f.typeIcon:Hide()
end

creators.border = function(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f.wtype = "border"
    AddTypeIcon(f)
    f:Hide()
    return f
end

creators.overlay = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "overlay"
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.tex:SetTexture(FLAT)
    AddTypeIcon(f)
    f:Hide()
    return f
end

-- Tinte de "Disipable": degradado del color con la intensidad elegida
-- Tinte sobre la vida: liso, o degradado de abajo arriba / de arriba abajo
local function SetOverlayColor(w, r, g, b, alpha, shape)
    w.tex:SetTexture(ns.DispelTintAsset(shape))
    w.tex:SetVertexColor(r, g, b, alpha)
end

local function WidgetType(cfg)
    if cfg.kind == "raiddebuff" then return "icon" end
    if cfg.kind == "debuffs" then return "icons" end
    return cfg.type
end

-- Estilo del barrido: el reloj de siempre (normal, al revés o con borde),
-- una sombra que se llena en vertical u horizontal, o una barra fina abajo
-- que crece (las tres muestran el tiempo que ya ha pasado)
local function SetupSweep(w, cfg)
    local cd, d = w.cd, w.drain
    if not cd then return end
    local style = cfg.swipeStyle or "clock"
    local on = cfg.swipe ~= false and w.wtype ~= "text"
    local clock = style == "clock" or style == "clockReverse" or style == "clockEdge"
    cd:SetReverse(style ~= "clockReverse")
    cd:SetDrawEdge(style == "clockEdge")
    cd:SetDrawSwipe(on and clock)
    w.drainOn = on and not clock and d ~= nil
    if not d then return end
    if not w.drainOn then d:Hide() return end
    d:ClearAllPoints()
    if style == "bar" then
        local h = math.max(2, math.floor((w:GetHeight() or 10) * 0.15 + 0.5))
        d:SetPoint("BOTTOMLEFT")
        d:SetPoint("BOTTOMRIGHT")
        d:SetHeight(h)
        d:SetOrientation("HORIZONTAL")
        d:SetStatusBarColor(1, 1, 1, 0.95)
        d.bg:SetVertexColor(0, 0, 0, 0.7)
    else
        d:SetAllPoints()
        d:SetOrientation(style == "drainV" and "VERTICAL" or "HORIZONTAL")
        d:SetStatusBarColor(0, 0, 0, 0.6)
        d.bg:SetVertexColor(0, 0, 0, 0)
    end
end

-------------------------------------------------------------------------------
-- Colocar un widget según su configuración
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Tooltip de auras al pasar el ratón por un elemento del marco. Solo se activa
-- el movimiento del ratón (no los clics), para que el clic siga llegando al
-- botón seguro del marco (seleccionar, menú...).
-------------------------------------------------------------------------------
local function AuraTooltip(w)
    local a = w.mfAura
    local mode = ns.P and ns.P.bars.auraTooltip or "never"
    if not a or mode == "never" or (mode == "ooc" and InCombatLockdown()) then return end
    GameTooltip:SetOwner(w, "ANCHOR_RIGHT")
    local ok = false
    if w.mfUnit and a.auraInstanceID then
        local f = w.mfHarmful and GameTooltip.SetUnitDebuffByAuraInstanceID or GameTooltip.SetUnitBuffByAuraInstanceID
        if f then ok = pcall(f, GameTooltip, w.mfUnit, a.auraInstanceID) end
    end
    if not ok and a.spellId and not S(a.spellId) then
        ok = pcall(GameTooltip.SetSpellByID, GameTooltip, a.spellId)
    end
    if ok then GameTooltip:Show() else GameTooltip:Hide() end
end

local canPassClicks = UIParent.SetMouseMotionEnabled and UIParent.SetMouseClickEnabled

local function SetupMouse(w)
    if not canPassClicks then return end
    local on = ns.P.bars.auraTooltip ~= "never"
    w:SetMouseMotionEnabled(on)
    w:SetMouseClickEnabled(false)
    if on and not w.mfTip then
        w.mfTip = true
        w:SetScript("OnEnter", AuraTooltip)
        w:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
end

-- Guarda qué aura enseña el elemento (para el tooltip)
local function RememberAura(w, unit, aura, cfg)
    w.mfAura = aura
    w.mfUnit = unit
    w.mfHarmful = cfg.auraType == "HARMFUL" or cfg.kind == "raiddebuff" or cfg.kind == "debuffs"
end

-- desplazamiento hacia dentro para un punto (que el texto no se salga)
local INSET = {
    TOPLEFT = { 1, -1 }, TOP = { 0, -1 }, TOPRIGHT = { 2, -1 },
    LEFT = { 1, 0 }, CENTER = { 0, 0 }, RIGHT = { 2, 0 },
    BOTTOMLEFT = { 1, -1 }, BOTTOM = { 0, -1 }, BOTTOMRIGHT = { 2, -1 },
}

local function TextCfg(cfg)
    return cfg.timerText or ns.indicatorDefaults.timerText, cfg.stacksText or ns.indicatorDefaults.stacksText
end

-- Color de los textos del tiempo y las cargas. En el tipo «Texto», el color
-- del tiempo es el del indicador (y el de aviso), como el resto de tipos.
local function ColorTexts(w, cfg, unit)
    local tt, st = TextCfg(cfg)
    local r, g, b
    if tt.colorMode == "class" or st.colorMode == "class" then
        r, g, b = ns.ClassColorOf(unit, w.previewClass, w.previewIsPet)
    end
    if w.timerText and w.wtype ~= "text" then
        ns.ColorText(w.timerText, tt, r, g, b)
        local fs = w.cd and w.cd.GetCountdownFontString and w.cd:GetCountdownFontString()
        if fs then ns.ColorText(fs, tt, r, g, b) end
    end
    if w.count then ns.ColorText(w.count, st, r, g, b) end
end

local function StyleTexts(w, cfg)
    local tt, st = TextCfg(cfg)
    if w.timerText then
        if w.wtype == "text" then
            -- el propio indicador es el texto: va en su sitio
            ns.SetFont(w.timerText, tt.font, tt.size or 9, tt.outline or "")
            w.timerText:ClearAllPoints()
            local p = cfg.point or "CENTER"
            w.timerText:SetPoint(p, w, p)
            w.timerText:SetJustifyH(p:find("LEFT") and "LEFT" or (p:find("RIGHT") and "RIGHT" or "CENTER"))
        else
            local o = INSET[tt.point or "CENTER"] or INSET.CENTER
            ns.StyleText(w.timerText, tt, w, o[1], o[2])
        end
        w.timerText:SetText("")
    end
    if w.count then
        if w.wtype == "text" then
            ns.SetFont(w.count, st.font, st.size or 9, st.outline or "")
            w.count:ClearAllPoints()
            w.count:SetPoint("LEFT", w.timerText, "RIGHT", 1, 0)
        else
            local o = INSET[st.point or "BOTTOMRIGHT"] or INSET.CENTER
            ns.StyleText(w.count, st, w, o[1], o[2])
        end
        w.count:SetText("")
    end
    if w.cd and w.cd.GetCountdownFontString then
        local fs = w.cd:GetCountdownFontString()
        if fs then pcall(ns.SetFont, fs, tt.font, tt.size or 9, tt.outline or "") end
    end
    ColorTexts(w, cfg, nil)
end

local function GrowOffset(cfg, i)
    local step
    if cfg.grow == "UP" or cfg.grow == "DOWN" then step = cfg.height + cfg.spacing
    else step = cfg.width + cfg.spacing end
    local n = (i - 1) * step
    if cfg.grow == "LEFT" then return -n, 0
    elseif cfg.grow == "UP" then return 0, n
    elseif cfg.grow == "DOWN" then return 0, -n end
    return n, 0
end

local function LayoutWidget(w, cfg, b)
    w.previewClass, w.previewIsPet = b.testClass, b.testIndex and b.isPet or nil
    w:ClearAllPoints()
    local t = w.wtype
    if w.typeIcon then
        local pos = cfg.typeIconPos or {}
        local sz = cfg.typeIconSize or 14
        w.typeIcon:ClearAllPoints()
        w.typeIcon:SetPoint(pos.point or "CENTER", w, pos.point or "CENTER", pos.x or 0, pos.y or 0)
        w.typeIcon:SetSize(sz, sz)
    end
    if t == "border" then
        local th = math.max(1, cfg.width or 2)
        if cfg.borderInside then
            w:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
            w:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        else
            w:SetPoint("TOPLEFT", b, "TOPLEFT", -th + 1, th - 1)
            w:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", th - 1, -th + 1)
        end
        w:SetBackdrop({ edgeFile = FLAT, edgeSize = th })
        return
    elseif t == "overlay" then
        w:SetAllPoints(b.health)
        return
    end

    w:SetPoint(cfg.point, b, cfg.point, cfg.x, cfg.y)
    if t == "text" then
        local size = TextCfg(cfg).size or 9
        w:SetSize(math.max(10, size * 2.5), size + 2)
    else
        w:SetSize(cfg.width, cfg.height)
        -- ocupar un lado entero del marco (como la línea de amenaza)
        if t == "bar" and (cfg.span == "width" or cfg.span == "height") then
            local L = ns.P.layout
            local fw, fh = L.width, L.height
            if b.isPet then fw, fh = ns.PetSize() end
            if cfg.span == "width" then w:SetWidth(math.max(1, fw - 2)) else w:SetHeight(math.max(1, fh - 2)) end
        end
    end
    w.baseW, w.baseH = w:GetSize()
    if w.border then w.border:SetShown(cfg.showBorder ~= false) end
    if t == "bar" then
        w.bar:SetOrientation(cfg.barOrient == "VERTICAL" and "VERTICAL" or "HORIZONTAL")
        w.bar:SetReverseFill(cfg.barReverse and true or false)
        local m = cfg.barMeasure or "time"
        if m == "stacks" then w.bar:SetMinMaxValues(0, math.max(1, cfg.barMaxStacks or 5))
        elseif m == "time" then w.bar:SetMinMaxValues(0, 1) end
        -- escudos / curación: sin fondo, para que vacía no se vea
        w.bg:SetShown(not UnitMeasure(cfg))
    end

    if t == "icons" then
        for i = 1, math.max(cfg.max, #w.icons) do
            local icon = w.icons[i]
            if not icon and i <= cfg.max then
                icon = ns.CreateIcon(w)
                w.icons[i] = icon
            end
            if icon then
                icon:ClearAllPoints()
                local x, y = GrowOffset(cfg, i)
                icon:SetPoint(cfg.point, w, cfg.point, x, y)
                icon:SetSize(cfg.width, cfg.height)
                icon.wtype = "icon"
                icon.previewClass, icon.previewIsPet = w.previewClass, w.previewIsPet
                icon.border:SetShown(cfg.showBorder ~= false)
                SetupMouse(icon)
                StyleTexts(icon, cfg)
                SetupSweep(icon, cfg)
                icon:Hide()
            end
        end
    else
        StyleTexts(w, cfg)
        SetupMouse(w)
    end
    if w.SetMainColor then w:SetMainColor(cfg.color) end
    SetupSweep(w, cfg)
end

-- Crea/reutiliza los widgets de todos los indicadores de un botón
function ns.BuildIndicators(b)
    b.ind = b.ind or {}
    b.pool = b.pool or {}
    for _, w in pairs(b.ind) do
        ns.HideWidget(w)
        ns.ReleaseNativeIndicator(w)
        local p = b.pool[w.wtype]
        if not p then p = {} b.pool[w.wtype] = p end
        table.insert(p, w)
    end
    wipe(b.ind)
    for _, c in ipairs(ns.compiled) do
        local wt = WidgetType(c.cfg)
        local p = b.pool[wt]
        local w = p and table.remove(p)
        if not w then
            local parent = (wt == "border") and b or b.overlay
            w = creators[wt](parent)
        end
        LayoutWidget(w, c.cfg, b)
        -- orden de dibujo = orden de la lista (los de abajo, por encima)
        w:SetFrameLevel(b.overlay:GetFrameLevel() + (wt == "border" and 1 or (3 + c.index * 3)))
        b.ind[c.index] = w
        ns.BuildNativeIndicator(b, w, c.cfg)
    end
    -- franjas propias: su sitio depende de las demás y de la barra de maná
    if ns.AnchorHealth then ns.AnchorHealth(b, b.powerShown) end
end

-------------------------------------------------------------------------------
-- Pintar un aura en un widget
-------------------------------------------------------------------------------
local function ApplyCooldown(w, unit, aura, cfg)
    local cd = w.cd
    if not cd then return end
    local wantNumbers = ns.ShowsTime(w, cfg) and AnyS(aura.duration, aura.expirationTime)
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(not wantNumbers) end
    if not (cfg.swipe or wantNumbers) then cd:Clear() return end
    if unit and GetAuraDuration and cd.SetCooldownFromDurationObject and aura.auraInstanceID then
        local ok = pcall(function()
            local d = GetAuraDuration(unit, aura.auraInstanceID)
            if d then cd:SetCooldownFromDurationObject(d) else cd:Clear() end
        end)
        if ok then return end
    end
    local dur, exp = aura.duration, aura.expirationTime
    if not AnyS(dur, exp) and dur and exp and dur > 0 then
        cd:SetCooldown(exp - dur, dur)
    else
        cd:Clear()
    end
end

local function ApplyDrain(w, unit, aura)
    local d = w.drain
    if not d then return end
    if not w.drainOn then d:Hide() return end
    -- duración secreta (en combate): la barra avanza sola con el tiempo
    -- transcurrido (si el cliente no admite el sentido, muestra el que queda)
    if unit and GetAuraDuration and d.SetTimerDuration and aura.auraInstanceID then
        local ok = pcall(function()
            local obj = GetAuraDuration(unit, aura.auraInstanceID)
            if not obj then error("sin duración") end
            local dir = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime
            local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
            if not (dir and pcall(d.SetTimerDuration, d, obj, interp or 0, dir)) then
                d:SetTimerDuration(obj)
            end
        end)
        if ok then d:Show() return end
    end
    local dur, exp = aura.duration, aura.expirationTime
    if not AnyS(dur, exp) and dur and exp and dur > 0 then
        d:SetValue(math.min(1, math.max(0, 1 - (exp - GetTime()) / dur)))
        d:Show()
    else
        d:Hide() -- sin duración (aura permanente)
    end
end

local function ApplyCount(w, unit, aura, cfg)
    if not w.count then return end
    if not cfg.stacks then w.count:SetText("") return end
    local n = aura.applications
    if not S(n) then
        w.count:SetText((n and n > 1) and n or "")
        return
    end
    if unit and GetAuraApplicationDisplayCount and aura.auraInstanceID then
        if pcall(function()
            w.count:SetText(GetAuraApplicationDisplayCount(unit, aura.auraInstanceID, 2, 99))
        end) then return end
    end
    w.count:SetText("")
end

local function ApplyTimer(w, unit, aura, cfg)
    local dur, exp = aura.duration, aura.expirationTime
    if not AnyS(dur, exp) and dur and exp and dur > 0 then
        local e = timers[w] or {}
        e.exp, e.dur, e.cfg, e.warned = exp, dur, cfg, nil
        timers[w] = e
        if not TickTimer(w, e, GetTime()) then timers[w] = nil end
    else
        timers[w] = nil
        if w.timerText then w.timerText:SetText("") end
        if w.bar and (cfg.barMeasure or "time") == "time" then
            local ok = unit and aura.auraInstanceID and GetAuraDuration and w.bar.SetTimerDuration and pcall(function()
                w.bar:SetTimerDuration(GetAuraDuration(unit, aura.auraInstanceID))
            end)
            if not ok then w.bar:SetValue(1) end
        end
    end
end

-- color de borde según tipo de magia (si se puede leer)
local function DispelBorder(w, aura, cfg)
    if not w.border then return end
    local t = cfg.dispelColor and R(aura.dispelName)
    local bb = w.baseBorder
    if not bb then bb = { 0, 0, 0 } w.baseBorder = bb end
    local r, g, b
    if t then r, g, b = ns.DispelColor(t) end
    bb[1], bb[2], bb[3] = r or 0, g or 0, b or 0
    w.border:SetColorTexture(bb[1], bb[2], bb[3], 1)
end

-- Recorta a N letras (respeta tildes); los textos secretos no se pueden tocar
local function Letters(s, n)
    if S(s) or not s or n <= 0 then return s end
    return s:match("^" .. ("[%z\1-\127\194-\244][\128-\191]*"):rep(n)) or s
end

-- Lo que escribe un indicador de tipo «Texto» que no muestra el tiempo
local function ApplyTextContent(w, unit, aura, cfg)
    if w.wtype ~= "text" then return end
    local show = cfg.textShow or "time"
    if show == "time" then return end
    local fs = w.timerText
    if show == "custom" then
        fs:SetText(cfg.customText or "")
    elseif show == "name" then
        local name = aura.name
        if not S(name) and name == nil then
            local id = R(aura.spellId)
            name = id and ns.GetSpellName(id) or ""
        end
        fs:SetText(Letters(name, cfg.nameLetters or 0))
    elseif show == "stacks" then
        local n = aura.applications
        if not S(n) then
            fs:SetText((n and n > 0) and n or "")
        elseif unit and GetAuraApplicationDisplayCount and aura.auraInstanceID then
            if not pcall(function() fs:SetText(GetAuraApplicationDisplayCount(unit, aura.auraInstanceID, 1, 99)) end) then
                fs:SetText("")
            end
        else
            fs:SetText("")
        end
    elseif show == "caster" then
        local src = R(aura.sourceUnit)
        local ok, name = false, nil
        if src then ok, name = pcall(UnitName, src) end
        if not ok or (not S(name) and name == nil) then name = "" end
        fs:SetText(name)
    end
    -- con «Cargas» el número ya es el texto: no repetirlo al lado
    if w.count and show == "stacks" then w.count:SetText("") end
end

function ns.ShowAura(w, unit, aura, cfg)
    RememberAura(w, unit, aura, cfg)
    if w.tex and w.wtype ~= "square" then w.tex:SetTexture(aura.icon) end
    if w.SetMainColor then w:SetMainColor(cfg.color) end
    if w.wtype == "icon" then DispelBorder(w, aura, cfg) end
    local tt, st = TextCfg(cfg)
    if tt.colorMode == "class" or st.colorMode == "class" then ColorTexts(w, cfg, unit) end
    w:Show()
    ApplyCooldown(w, unit, aura, cfg)
    ApplyDrain(w, unit, aura)
    ApplyCount(w, unit, aura, cfg)
    ApplyTimer(w, unit, aura, cfg)   -- puede ocultarlo ("solo si quedan menos de")
    ApplyTextContent(w, unit, aura, cfg)
    -- barra que mide las cargas del aura en vez del tiempo
    if w.wtype == "bar" and cfg.barMeasure == "stacks" then
        timers[w] = nil
        w.bar:SetValue(V(aura.applications))
    end
end

-- Indicador en modo "le falta": se muestra fijo, sin tiempo
function ns.ShowMissing(w, cfg)
    timers[w] = nil
    RememberAura(w, nil, { spellId = ns.KeyIDs(cfg.spells[1] or 0)[1] }, cfg)
    if w.cd then w.cd:Clear() end
    if w.drain then w.drain:Hide() end
    if w.count then w.count:SetText("") end
    if w.SetMainColor then w:SetMainColor(cfg.color) end
    ColorTexts(w, cfg, nil)
    -- «le falta»: no hay debuff, así que tampoco icono de tipo
    if w.typeIcon then w.typeIcon:Hide() end
    if w.wtype == "border" then
        local c = cfg.color
        w:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    elseif w.wtype == "overlay" then
        local c = cfg.color
        SetOverlayColor(w, c.r, c.g, c.b, cfg.overlayAlpha or 0.6, cfg.tintShape)
    elseif w.wtype == "icon" then
        local key = cfg.spells[1]
        local _, icon = ns.SpellKeyInfo(key)
        w.tex:SetTexture(icon or 134400)
        w.tex:SetDesaturated(true)
    elseif w.wtype == "bar" then
        w.bar:SetValue(1)
    elseif w.wtype == "text" then
        -- le falta el aura: su texto propio, el nombre del hechizo o «!»
        local show = cfg.textShow or "time"
        if show == "custom" and (cfg.customText or "") ~= "" then
            w.timerText:SetText(cfg.customText)
        elseif show == "name" then
            local name = ns.SpellKeyInfo(cfg.spells[1])
            w.timerText:SetText(Letters(name, cfg.nameLetters or 0) or "!")
        else
            w.timerText:SetText("!")
        end
    end
    w:Show()
end

local function HideWidget(w)
    if not w then return end
    if w.nativeDispel then w.nativeDispel:Hide() end
    timers[w] = nil
    ns.ClearHighlight(w)
    w.hlSoundIdent = nil
    if w.icons then
        for _, ic in ipairs(w.icons) do
            ic:Hide()
            timers[ic] = nil
            ns.ClearHighlight(ic)
            ic.hlSoundIdent = nil
        end
    end
    if w.tex and w.tex.SetDesaturated then w.tex:SetDesaturated(false) end
    w:Hide()
end
ns.HideWidget = HideWidget

-- Resaltado de un hechizo de un indicador: el propio (si lo tiene) o el del indicador
local function StyleFor(cfg, key)
    local s = key ~= nil and cfg.spellStyles[key]
    return s or cfg.hl
end
ns.IndicatorStyleFor = StyleFor

local function Ident(aura)
    local id = aura.auraInstanceID
    if not S(id) and id then return id end
    return aura
end

-- styles[i] / keys: resaltado de cada icono
local function ShowIcons(b, w, unit, list, cfg, styles)
    for i, ic in ipairs(w.icons) do
        local aura = list[i]
        if aura and i <= cfg.max then
            ns.ShowAura(ic, unit, aura, cfg)
            ic.wtype = "icon"
            DispelBorder(ic, aura, cfg)
            ns.ApplyHighlight(b, ic, styles and styles[i] or cfg.hl, Ident(aura), unit)
        else
            ic:Hide()
            timers[ic] = nil
            ns.ClearHighlight(ic)
            ic.hlSoundIdent = nil
        end
    end
    w:SetShown(#list > 0)
end

-- Estilo de banda para un aura (por ID o por nombre, si se pueden leer)
function ns.StyleForAura(aura)
    local id = aura.spellId
    if not S(id) and id and ns.styleByID[id] then return ns.styleByID[id] end
end

-------------------------------------------------------------------------------
-- Lectura de auras con caché por actualización
-------------------------------------------------------------------------------
local cache, cachePool, cacheComplete = {}, {}, {}

-- Lectura nativa de las auras de una unidad. Con auras secretas (combate,
-- instancias) el juego no deja leerlas por índice desde un addon
-- También puede bloquear todas las APIs, incluida la consulta por ID.
-- Una lectura fallida o incompleta no demuestra que falte un aura.
-- Diagnóstico: qué vía falla y con qué error (MendFramesDB.auraDiag)
local function Diag(way, ok, err, n)
    local d = ns.db and ns.db.auraDiag
    if not d then return end
    local e = d[way]
    if not e then
        e = { ok = 0, fail = 0, auras = 0 }
        d[way] = e
    end
    if ok then
        e.ok = e.ok + 1
        e.auras = e.auras + (n or 0)
    else
        e.fail = e.fail + 1
        e.lastError = tostring(err)
        e.inCombat = InCombatLockdown() and true or false
    end
end

local function ReadAuras(unit, filter, l)
    if GetAuraInstanceIDs and GetAuraByInstance then
        local ok, ids = pcall(GetAuraInstanceIDs, unit, filter)
        Diag("instanceIDs", ok and type(ids) == "table", ok and ("tipo " .. type(ids)) or ids, ok and type(ids) == "table" and #ids or 0)
        if ok and type(ids) == "table" then
            local complete = #ids <= 40
            for _, id in ipairs(ids) do
                local ok2, a = pcall(GetAuraByInstance, unit, id)
                Diag("byInstance", ok2 and a ~= nil, ok2 and "nil" or a, 1)
                if ok2 and a then l[#l + 1] = a end
                if not ok2 or not a then complete = false end
                if #l >= 40 then break end
            end
            return complete
        end
    end
    if GetUnitAuras then
        local ok, list = pcall(GetUnitAuras, unit, filter, 40)
        Diag("unitAuras", ok and type(list) == "table", ok and ("tipo " .. type(list)) or list, ok and type(list) == "table" and #list or 0)
        if ok and type(list) == "table" then
            for _, a in ipairs(list) do l[#l + 1] = a end
            return #list < 40
        end
    end
    if GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, a = pcall(GetAuraDataByIndex, unit, i, filter)
            if not ok then Diag("byIndex", false, a) end
            if not ok then return false end
            if not a then return true end
            l[#l + 1] = a
        end
    end
    return false
end

local function GetList(unit, filter)
    local l = cache[filter]
    if l then return l, cacheComplete[filter] end
    l = table.remove(cachePool) or {}
    cacheComplete[filter] = ReadAuras(unit, filter, l)
    cache[filter] = l
    return l, cacheComplete[filter]
end

local function ResetCache()
    for k, l in pairs(cache) do
        wipe(l)
        table.insert(cachePool, l)
        cache[k] = nil
        cacheComplete[k] = nil
    end
end

local claimed, matches = {}, {}
-- tablas reutilizadas en cada actualización (sin crear basura)
local matchPool, tmpList, tmpStyles = {}, {}, {}
local function SortMatches(a, b) return a.order < b.order end

local function ShowDispel(b, w, found, cfg, unit, style)
    local r, g, bl
    if cfg.dispelColor then
        local t = R(found.dispelName)
        r, g, bl = ns.DispelColor(t or "none")
        if not r then r, g, bl = ns.DispelColor("none") end
    else
        r, g, bl = cfg.color.r, cfg.color.g, cfg.color.b
    end
    if w.wtype == "overlay" then
        SetOverlayColor(w, r, g, bl, cfg.overlayAlpha or 0.6, cfg.tintShape)
    else
        w:SetBackdropBorderColor(r, g, bl, 1)
    end
    -- icono del tipo (si el juego deja leerlo)
    if w.typeIcon then
        local t = cfg.typeIcon and R(found.dispelName)
        local file = t and ns.DISPEL_ICONS[t]
        if file then
            w.typeIcon:SetTexture(file)
            w.typeIcon:Show()
        else
            w.typeIcon:Hide()
        end
    end
    w:Show()
    ns.ApplyHighlight(b, w, style or cfg.hl, Ident(found), unit)
end

-------------------------------------------------------------------------------
-- Actualizar todos los indicadores de un botón
-------------------------------------------------------------------------------
-- Barra de escudos o de curación entrante del jugador (datos de la unidad)
local function ShowUnitBar(w, unit, cfg)
    timers[w] = nil
    local max = UnitHealthMax(unit)
    local value
    if cfg.barMeasure == "absorb" then value = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit)
    else value = UnitGetIncomingHeals and UnitGetIncomingHeals(unit) end
    w.bar:SetMinMaxValues(0, V(max))
    w.bar:SetValue(V(value))
    if w.SetMainColor then w:SetMainColor(cfg.color) end
    if w.timerText then w.timerText:SetText("") end
    if w.count then w.count:SetText("") end
    w:Show()
end

-- Tras cambiar los escudos, la curación entrante o la vida máxima
function ns.UpdateUnitBars(b)
    local unit = b.unit
    if not unit or not b.ind then return end
    local inCombat = InCombatLockdown()
    for _, c in ipairs(ns.compiled) do
        local w = b.ind[c.index]
        if w and c.kind == "aura" and UnitMeasure(c.cfg) then
            if c.cfg.onlyOOC and inCombat then HideWidget(w) else ShowUnitBar(w, unit, c.cfg) end
        end
    end
end

function ns.UpdateAuras(b)
    local unit = b.unit
    if not unit or not b.ind then return end
    ResetCache()
    wipe(claimed)
    local inCombat = InCombatLockdown()

    for _, c in ipairs(ns.compiled) do
        local cfg, w = c.cfg, b.ind[c.index]
        if not w then
            -- nada
        elseif w.nativeDispel then
            timers[w] = nil
            ns.ClearHighlight(w)
            w:Hide()
            w.nativeDispel:SetUnit(unit)
            w.nativeDispel:SetShown(not (cfg.onlyOOC and inCombat))
        elseif c.kind == "aura" and UnitMeasure(cfg) then
            if cfg.onlyOOC and inCombat then HideWidget(w) else ShowUnitBar(w, unit, cfg) end
        elseif c.kind == "aura" then
            if cfg.onlyOOC and inCombat then
                HideWidget(w)
            elseif cfg.mode == "missing" then
                local list, complete = GetList(unit, c.filter)
                local present, unknown = false, not complete
                for _, a in ipairs(list) do
                    local m, readable = Match(a, c.byID, c.byName)
                    if m then present = true break end
                    if not readable then unknown = true end
                end
                if present or unknown or c.any then
                    HideWidget(w)
                else
                    ns.ShowMissing(w, cfg)
                    ns.ApplyHighlight(b, w, cfg.hl, "missing", unit)
                end
            else
                wipe(matches)
                for _, a in ipairs(GetList(unit, c.filter)) do
                    local order
                    if c.any then order = 1 else order = Match(a, c.byID, c.byName) end
                    -- «puedo disipar»: solo los tipos marcados. Si el juego oculta el
                    -- tipo, se muestra o no según «mostrarlo igualmente»
                    if order and c.dispellable then
                        local t = R(a.dispelName)
                        if t then
                            if not cfg.dispelTypes[t] then order = nil end
                        elseif cfg.watch == "debuffTypes" or not cfg.unknownType then
                            order = nil
                        end
                    end
                    -- "de los demás": descartar las que he puesto yo
                    if order and c.others then
                        local src = R(a.sourceUnit)
                        if src == "player" or src == "pet" or R(a.isFromPlayerOrPlayerPet) == true then
                            order = nil
                        end
                    end
                    if order then
                        local n = #matches + 1
                        local m = matchPool[n]
                        if not m then m = {} matchPool[n] = m end
                        m.aura, m.order = a, order
                        matches[n] = m
                        local id = a.auraInstanceID
                        if cfg.auraType == "HARMFUL" and not c.dispellable and id and not S(id) then claimed[id] = true end
                    end
                end
                if #matches == 0 then
                    HideWidget(w)
                else
                    table.sort(matches, SortMatches)
                    if w.wtype == "icons" then
                        local list, styles = wipe(tmpList), wipe(tmpStyles)
                        for i, m in ipairs(matches) do
                            list[i] = m.aura
                            styles[i] = StyleFor(cfg, (not c.any) and cfg.spells[m.order] or nil)
                        end
                        ShowIcons(b, w, unit, list, cfg, styles)
                    elseif w.wtype == "border" or w.wtype == "overlay" then
                        local m = matches[1]
                        ShowDispel(b, w, m.aura, cfg, unit, StyleFor(cfg, (not c.any) and cfg.spells[m.order] or nil))
                    else
                        local m = matches[1]
                        if w.tex and w.tex.SetDesaturated then w.tex:SetDesaturated(false) end
                        ns.ShowAura(w, unit, m.aura, cfg)
                        ns.ApplyHighlight(b, w, StyleFor(cfg, (not c.any) and cfg.spells[m.order] or nil),
                            Ident(m.aura), unit)
                    end
                end
            end

        elseif c.kind == "raiddebuff" then
            local best, bestPrio
            local list, complete = GetList(unit, "HARMFUL")
            if not complete and ns.inInstance then ns.raidSecret = true end
            for _, a in ipairs(list) do
                local prio, readable = Match(a, ns.debuffByID)
                if prio then
                    if not bestPrio or prio > bestPrio then best, bestPrio = a, prio end
                elseif not readable then
                    if ns.inInstance then ns.raidSecret = true end
                elseif ns.inInstance then
                    local id = R(a.spellId)
                    if id and R(a.sourceUnit) ~= "player" then
                        ns.RecordDebuff(id, R(a.name), R(a.icon), R(a.auraInstanceID))
                    end
                end
            end
            if best then
                local id = best.auraInstanceID
                if id and not S(id) then claimed[id] = true end
                ns.ShowAura(w, unit, best, cfg)
                -- excepción de la banda (si la tiene) o resaltado del indicador
                ns.ApplyHighlight(b, w, ns.StyleForAura(best) or cfg.hl, Ident(best), unit)
            else
                HideWidget(w)
            end

        elseif c.kind == "debuffs" then
            local list = wipe(tmpList)
            for _, a in ipairs(GetList(unit, cfg.onlyDispellable and "HARMFUL|RAID" or "HARMFUL")) do
                local id = a.auraInstanceID
                local skip = cfg.excludeClaimed and id and not S(id) and claimed[id]
                if not skip and Match(a, c.blackID, c.blackName) then skip = true end
                if not skip then list[#list + 1] = a end
                if #list >= cfg.max then break end
            end
            ShowIcons(b, w, unit, list, cfg)

        end
    end
end

-------------------------------------------------------------------------------
-- Datos falsos para el modo prueba
-- ns.preview = { cfg = indicador, key = hechizo } o { raid = { inst, key } }
-- para enseñar en varios marcos lo que se está editando en opciones
-------------------------------------------------------------------------------
function ns.TestAuras(b, i, all)
    if not b.ind then return end
    local now = GetTime()
    local pv = ns.preview
    for _, c in ipairs(ns.compiled) do
        local cfg, w = c.cfg, b.ind[c.index]
        if w then
            w.previewClass, w.previewIsPet = b.testClass, b.isPet
            for _, icon in ipairs(w.icons or {}) do
                icon.previewClass, icon.previewIsPet = b.testClass, b.isPet
            end
            local previewDispelType
            if c.dispellable then
                for _, kind in ipairs({ "Magic", "Curse", "Disease", "Poison" }) do
                    if cfg.dispelTypes[kind] then previewDispelType = kind break end
                end
            end
            local function Fake(key, n, dispel)
                local _, icon = ns.SpellKeyInfo(key)
                local dur = 15 + (i * 7 + n * 5) % 30
                return { icon = icon or 136207, duration = dur, expirationTime = now + dur * (0.3 + ((i + n) % 7) / 10),
                    applications = (n == 2) and 3 or 0, dispelName = dispel,
                    spellId = key ~= nil and ns.KeyIDs(key)[1] or nil }   -- para el tooltip
            end
            HideWidget(w)
            -- all: la muestra de Indicadores enseña el indicador que se edita
            -- (b.previewOnly) o, si no, todos a la vez
            local focus = all or (pv and pv.cfg == cfg)
            -- solo el que se edita: los demás se quedan ocultos
            local skip = (b.previewOnly and c.index ~= b.previewOnly)
                or (c.dispellable and not previewDispelType)
            if skip then
                -- nada
            elseif c.kind == "aura" and UnitMeasure(cfg) then
                w.bar:SetMinMaxValues(0, 100)
                w.bar:SetValue((i % 3 == 0 or focus) and (15 + (i * 13) % 40) or 0)
                if w.SetMainColor then w:SetMainColor(cfg.color) end
                w:Show()
            elseif c.kind == "aura" then
                if cfg.mode == "missing" then
                    if i % 4 == 1 or (focus and i % 3 == 1) then
                        ns.ShowMissing(w, cfg)
                        ns.ApplyHighlight(b, w, cfg.hl)
                    end
                elseif (i + c.index) % 3 ~= 0 or (focus and i % 2 == 1) then
                    local first = (focus and pv and pv.cfg == cfg and pv.key ~= nil) and pv.key or cfg.spells[1]
                    if w.wtype == "icons" then
                        local list, styles = {}, {}
                        for n = 1, math.min(cfg.max, math.max(1, #cfg.spells)) do
                            local key = (n == 1) and first or cfg.spells[n] or cfg.spells[1]
                            list[n] = Fake(key, n)
                            styles[n] = StyleFor(cfg, key)
                        end
                        ShowIcons(b, w, nil, list, cfg, styles)
                    elseif w.wtype == "border" or w.wtype == "overlay" then
                        -- en pocos marcos, para que no tape todo el modo prueba
                        if i % 6 == 4 or focus then
                            ShowDispel(b, w, Fake(first, 1, previewDispelType or "Magic"), cfg, nil, StyleFor(cfg, first))
                        end
                    else
                        if w.tex and w.tex.SetDesaturated then w.tex:SetDesaturated(false) end
                        ns.ShowAura(w, nil, Fake(first, 1), cfg)
                        ns.ApplyHighlight(b, w, StyleFor(cfg, first))
                    end
                end
            elseif c.kind == "raiddebuff" then
                local raid = pv and pv.raid
                if raid and (i % 5 == 2 or i == 1) then
                    ns.ShowAura(w, nil, Fake(raid.key, 1, "Magic"), cfg)
                    ns.ApplyHighlight(b, w, ns.GetDebuffStyle(raid.inst, raid.key) or cfg.hl)
                elseif not raid and (i % 5 == 2 or (focus and i % 3 == 1)) then
                    ns.ShowAura(w, nil, Fake(20475, 1, "Magic"), cfg)
                    ns.ApplyHighlight(b, w, ns.StyleForAura({ spellId = 20475, name = ns.GetSpellName(20475) }) or cfg.hl)
                end
            elseif c.kind == "debuffs" then
                local n = i % 3
                if focus and n == 0 then n = 1 end
                if all then n = cfg.max end
                local list = {}
                for k = 1, math.min(cfg.max, n) do list[k] = Fake(nil, k, k == 1 and "Poison" or nil) end
                for k, a in ipairs(list) do a.icon = (k == 1) and 136016 or 136207 end
                ShowIcons(b, w, nil, list, cfg)
            end
        end
    end
end
