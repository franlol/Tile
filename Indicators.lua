-------------------------------------------------------------------------------
-- MendFrames - Indicadores (estilo Cell)
-- Cada indicador del perfil vigila unas auras y las dibuja en un sitio fijo
-- del marco: icono, varios iconos, cuadrado de color, barra o texto.
-------------------------------------------------------------------------------

local _, ns = ...
local S, R, AnyS = ns.S, ns.R, ns.AnyS

local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
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

-------------------------------------------------------------------------------
-- Indicadores compilados del perfil activo
-------------------------------------------------------------------------------
ns.compiled = {}

local ORDER = { raiddebuff = 1, aura = 2, debuffs = 3, dispel = 4 }

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
            if cfg.kind == "aura" then
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
    if w.timerText and (cfg.timer or w.wtype == "text") then w.timerText:SetText(FormatTime(remain)) end
    if w.bar then w.bar:SetValue(remain / e.dur) end
    if w.drainOn then w.drain:SetValue(remain / e.dur) end
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

creators.border = function(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f.wtype = "border"
    f:Hide()
    return f
end

creators.overlay = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "overlay"
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.tex:SetTexture(FLAT)
    f:Hide()
    return f
end

-- Tinte de "Disipable": degradado del color con la intensidad elegida
local function SetOverlayColor(w, r, g, b, alpha)
    if w.tex.SetGradient and CreateColor then
        w.tex:SetVertexColor(1, 1, 1, 1)
        w.tex:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, alpha))
    else
        w.tex:SetVertexColor(r, g, b, alpha)
    end
end

local function WidgetType(cfg)
    if cfg.kind == "raiddebuff" then return "icon" end
    if cfg.kind == "debuffs" then return "icons" end
    if cfg.kind == "dispel" then return cfg.type == "overlay" and "overlay" or "border" end
    return cfg.type
end

-- Estilo del barrido: el reloj de siempre (normal, al revés o con borde),
-- una sombra que se vacía en vertical u horizontal, o una barra fina abajo
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

local function StyleTexts(w, cfg)
    local size = cfg.fontSize or 9
    local font = cfg.font or STANDARD_TEXT_FONT
    if w.timerText then
        ns.SetFont(w.timerText, font, size, "OUTLINE")
        w.timerText:SetText("")
        w.timerText:ClearAllPoints()
        if w.wtype == "text" then
            w.timerText:SetPoint("CENTER")
        else
            local p = cfg.timerPoint or "CENTER"
            local o = INSET[p] or INSET.CENTER
            w.timerText:SetPoint(p, w, p, o[1], o[2])
        end
    end
    if w.count then
        ns.SetFont(w.count, font, size, "OUTLINE")
        w.count:SetText("")
        w.count:ClearAllPoints()
        if w.wtype == "text" then
            w.count:SetPoint("LEFT", w.timerText, "RIGHT", 1, 0)
        else
            local p = cfg.stacksPoint or "BOTTOMRIGHT"
            local o = INSET[p] or INSET.CENTER
            w.count:SetPoint(p, w, p, o[1], o[2])
        end
    end
    if w.cd and w.cd.GetCountdownFontString then
        local fs = w.cd:GetCountdownFontString()
        if fs then pcall(ns.SetFont, fs, font, size, "OUTLINE") end
    end
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
    w:ClearAllPoints()
    local t = w.wtype
    if t == "border" then
        local th = math.max(1, cfg.width or 2)
        w:SetPoint("TOPLEFT", b, "TOPLEFT", -th + 1, th - 1)
        w:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", th - 1, -th + 1)
        w:SetBackdrop({ edgeFile = FLAT, edgeSize = th })
        return
    elseif t == "overlay" then
        w:SetAllPoints(b.health)
        return
    end

    w:SetPoint(cfg.point, b, cfg.point, cfg.x, cfg.y)
    if t == "text" then
        w:SetSize(math.max(10, cfg.fontSize * 2.5), cfg.fontSize + 2)
    else
        w:SetSize(cfg.width, cfg.height)
    end
    w.baseW, w.baseH = w:GetSize()
    if w.border then w.border:SetShown(cfg.showBorder ~= false) end
    if t == "bar" then
        w.bar:SetOrientation(cfg.barOrient == "VERTICAL" and "VERTICAL" or "HORIZONTAL")
        w.bar:SetReverseFill(cfg.barReverse and true or false)
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
    end
end

-------------------------------------------------------------------------------
-- Pintar un aura en un widget
-------------------------------------------------------------------------------
local function ApplyCooldown(w, unit, aura, cfg)
    local cd = w.cd
    if not cd then return end
    local wantNumbers = (cfg.timer or w.wtype == "text") and AnyS(aura.duration, aura.expirationTime)
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
    -- duración secreta (en combate): la barra se vacía sola
    if unit and GetAuraDuration and d.SetTimerDuration and aura.auraInstanceID then
        local ok = pcall(function()
            local obj = GetAuraDuration(unit, aura.auraInstanceID)
            if not obj then error("sin duración") end
            d:SetTimerDuration(obj)
        end)
        if ok then d:Show() return end
    end
    local dur, exp = aura.duration, aura.expirationTime
    if not AnyS(dur, exp) and dur and exp and dur > 0 then
        d:SetValue(math.max(0, (exp - GetTime()) / dur))
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
        if w.bar then
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
    local c = t and ns.DISPEL_COLORS[t]
    w.baseBorder = c or { 0, 0, 0 }
    w.border:SetColorTexture(w.baseBorder[1], w.baseBorder[2], w.baseBorder[3], 1)
end

function ns.ShowAura(w, unit, aura, cfg)
    RememberAura(w, unit, aura, cfg)
    if w.tex and w.wtype ~= "square" then w.tex:SetTexture(aura.icon) end
    if w.SetMainColor then w:SetMainColor(cfg.color) end
    if w.wtype == "icon" then DispelBorder(w, aura, cfg) end
    w:Show()
    ApplyCooldown(w, unit, aura, cfg)
    ApplyDrain(w, unit, aura)
    ApplyCount(w, unit, aura, cfg)
    ApplyTimer(w, unit, aura, cfg)   -- puede ocultarlo ("solo si quedan menos de")
end

-- Indicador en modo "le falta": se muestra fijo, sin tiempo
function ns.ShowMissing(w, cfg)
    timers[w] = nil
    RememberAura(w, nil, { spellId = ns.KeyIDs(cfg.spells[1] or 0)[1] }, cfg)
    if w.cd then w.cd:Clear() end
    if w.drain then w.drain:Hide() end
    if w.count then w.count:SetText("") end
    if w.SetMainColor then w:SetMainColor(cfg.color) end
    if w.wtype == "icon" then
        local key = cfg.spells[1]
        local _, icon = ns.SpellKeyInfo(key)
        w.tex:SetTexture(icon or 134400)
        w.tex:SetDesaturated(true)
    elseif w.wtype == "bar" then
        w.bar:SetValue(1)
    elseif w.wtype == "text" then
        w.timerText:SetText("!")
    end
    w:Show()
end

local function HideWidget(w)
    if not w then return end
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
    if id and not S(id) then return id end
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
local cache, cachePool = {}, {}

local function GetList(unit, filter)
    local l = cache[filter]
    if l then return l end
    l = table.remove(cachePool) or {}
    if GetAuraDataByIndex then
        for i = 1, 40 do
            local a = GetAuraDataByIndex(unit, i, filter)
            if not a then break end
            l[#l + 1] = a
        end
    end
    cache[filter] = l
    return l
end

local function ResetCache()
    for k, l in pairs(cache) do
        wipe(l)
        table.insert(cachePool, l)
        cache[k] = nil
    end
end

local claimed, matches = {}, {}
-- tablas reutilizadas en cada actualización (sin crear basura)
local matchPool, tmpList, tmpStyles = {}, {}, {}
local function SortMatches(a, b) return a.order < b.order end

local function ShowDispel(b, w, found, cfg, unit)
    local r, g, bl
    if cfg.dispelColor then
        local t = R(found.dispelName)
        local col = ns.DISPEL_COLORS[t or "none"] or ns.DISPEL_COLORS.none
        r, g, bl = col[1], col[2], col[3]
    else
        r, g, bl = cfg.color.r, cfg.color.g, cfg.color.b
    end
    if w.wtype == "overlay" then
        SetOverlayColor(w, r, g, bl, cfg.overlayAlpha or 0.6)
    else
        w:SetBackdropBorderColor(r, g, bl, 1)
    end
    w:Show()
    ns.ApplyHighlight(b, w, cfg.hl, Ident(found), unit)
end

-------------------------------------------------------------------------------
-- Actualizar todos los indicadores de un botón
-------------------------------------------------------------------------------
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
        elseif c.kind == "aura" then
            if cfg.onlyOOC and inCombat then
                HideWidget(w)
            elseif cfg.mode == "missing" then
                local present, unknown = false, false
                for _, a in ipairs(GetList(unit, c.filter)) do
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
                        if cfg.auraType == "HARMFUL" and id and not S(id) then claimed[id] = true end
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
            for _, a in ipairs(GetList(unit, "HARMFUL")) do
                local prio, readable = Match(a, ns.debuffByID, ns.debuffByName)
                if prio then
                    if not bestPrio or prio > bestPrio then best, bestPrio = a, prio end
                elseif readable and ns.inInstance then
                    local id = R(a.spellId)
                    if id and R(a.sourceUnit) ~= "player" then
                        ns.RecordDebuff(id, R(a.name), R(a.icon))
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

        elseif c.kind == "dispel" then
            local found
            for _, a in ipairs(GetList(unit, cfg.onlyDispellable and "HARMFUL|RAID" or "HARMFUL")) do
                if cfg.onlyDispellable or R(a.dispelName) then found = a break end
            end
            if found then ShowDispel(b, w, found, cfg, unit) else HideWidget(w) end
        end
    end
end

-------------------------------------------------------------------------------
-- Datos falsos para el modo prueba
-- ns.preview = { cfg = indicador, key = hechizo } o { raid = { inst, key } }
-- para enseñar en varios marcos lo que se está editando en opciones
-------------------------------------------------------------------------------
function ns.TestAuras(b, i)
    if not b.ind then return end
    local now = GetTime()
    local pv = ns.preview
    for _, c in ipairs(ns.compiled) do
        local cfg, w = c.cfg, b.ind[c.index]
        if w then
            local function Fake(key, n, dispel)
                local _, icon = ns.SpellKeyInfo(key)
                local dur = 15 + (i * 7 + n * 5) % 30
                return { icon = icon or 136207, duration = dur, expirationTime = now + dur * (0.3 + ((i + n) % 7) / 10),
                    applications = (n == 2) and 3 or 0, dispelName = dispel,
                    spellId = key ~= nil and ns.KeyIDs(key)[1] or nil }   -- para el tooltip
            end
            HideWidget(w)
            local focus = pv and pv.cfg == cfg
            if c.kind == "aura" then
                if cfg.mode == "missing" then
                    if i % 4 == 1 or (focus and i % 3 == 1) then
                        ns.ShowMissing(w, cfg)
                        ns.ApplyHighlight(b, w, cfg.hl)
                    end
                elseif (i + c.index) % 3 ~= 0 or (focus and i % 2 == 1) then
                    local first = (focus and pv.key ~= nil) and pv.key or cfg.spells[1]
                    if w.wtype == "icons" then
                        local list, styles = {}, {}
                        for n = 1, math.min(cfg.max, math.max(1, #cfg.spells)) do
                            local key = (n == 1) and first or cfg.spells[n] or cfg.spells[1]
                            list[n] = Fake(key, n)
                            styles[n] = StyleFor(cfg, key)
                        end
                        ShowIcons(b, w, nil, list, cfg, styles)
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
                local list = {}
                for k = 1, math.min(cfg.max, n) do list[k] = Fake(nil, k, k == 1 and "Poison" or nil) end
                for k, a in ipairs(list) do a.icon = (k == 1) and 136016 or 136207 end
                ShowIcons(b, w, nil, list, cfg)
            elseif c.kind == "dispel" then
                if i % 6 == 4 or (focus and i % 3 == 1) then
                    ShowDispel(b, w, { dispelName = "Magic" }, cfg)
                end
            end
        end
    end
end
