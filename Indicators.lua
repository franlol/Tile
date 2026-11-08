-------------------------------------------------------------------------------
-- MendFrames - Indicadores (estilo Cell)
-- Cada indicador vigila unas auras y las dibuja en un sitio fijo del marco:
-- icono, varios iconos, cuadrado de color, barra, texto, borde o tinte.
--
-- Las auras reales las elige y las dibuja el juego con sus contenedores
-- nativos de auras (CustomAuraContainerTemplate). El addon solo prepara el
-- aspecto: texturas, textos y barrido. Así funcionan igual en combate y en
-- instancias, donde el juego no deja que un addon lea las auras.
--
-- Hay dos excepciones, que no usan el contenedor:
--   · «Le falta»: solo fuera de combate (lee las auras de la unidad).
--   · Barras de escudos o de curación entrante: datos de la unidad.
-- El modo prueba dibuja auras de ejemplo con las mismas piezas.
-------------------------------------------------------------------------------

local _, ns = ...
local S, R = ns.S, ns.R

local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex

local FLAT = "Interface\\Buttons\\WHITE8X8"
local DISPEL_KINDS = { "Magic", "Curse", "Disease", "Poison" }

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

-- Textura del tinte: lisa o degradado (la opacidad va en la propia imagen,
-- porque el juego cambia el color del vértice al dibujar el tipo)
function ns.DispelTintAsset(shape)
    if shape == "solid" then return FLAT end
    return "Interface\\AddOns\\MendFrames\\Media\\"
        .. (shape == "down" and "DispelGradientDown" or "DispelGradientUp")
end

-------------------------------------------------------------------------------
-- Qué es cada indicador
-------------------------------------------------------------------------------
-- Barras que miden algo de la unidad (no un aura): escudos o curación entrante
local function UnitMeasure(cfg)
    local m = cfg.kind == "aura" and cfg.type == "bar" and cfg.barMeasure
    return m == "absorb" or m == "heal"
end
ns.IndicatorUnitMeasure = UnitMeasure

-- «Le falta»: lista de bufos, solo fuera de combate
local function Missing(cfg)
    return cfg.kind == "aura" and cfg.watch == "spells" and cfg.mode == "missing" and not UnitMeasure(cfg)
end
ns.IndicatorMissing = Missing

-- Enseña debuffs con tipo (magia, veneno...): su color puede salir del tipo
local function Typed(cfg)
    return cfg.kind ~= "aura" or cfg.watch == "dispellable" or cfg.watch == "debuffTypes"
end
ns.IndicatorTyped = Typed

local function WidgetType(cfg)
    if cfg.kind == "raiddebuff" then return "icon" end
    if cfg.kind == "debuffs" then return "icons" end
    return cfg.type
end

local function ClockSweep(cfg)
    local s = cfg.swipeStyle or "clock"
    return s == "clock" or s == "clockReverse" or s == "clockEdge"
end

-------------------------------------------------------------------------------
-- Indicadores del perfil activo
-------------------------------------------------------------------------------
ns.compiled = {}

function ns.CompileIndicators()
    wipe(ns.compiled)
    for i, cfg in ipairs(ns.P.indicators) do
        if cfg.enabled then
            local c = { index = i, cfg = cfg, kind = cfg.kind }
            if Missing(cfg) then
                c.byID = {}
                for _, key in ipairs(cfg.spells) do
                    ns.AddSpellKey(c.byID, nil, key, true, ns.KeyRank(cfg, key))
                end
            end
            table.insert(ns.compiled, c)
        end
    end
end

-- Qué auras elige el juego para un indicador: filtro, filtros extra y orden
local function Query(cfg)
    local sort = AuraContainerSortMethod
    if cfg.kind == "raiddebuff" then
        return "HARMFUL", { isBossAura = true }, sort and sort.UnitFrameDebuff
    elseif cfg.kind == "debuffs" then
        return cfg.onlyDispellable and "HARMFUL|RAID" or "HARMFUL"
    elseif cfg.watch == "dispellable" then
        -- los que puedo disipar (lo decide el juego), sin los tipos desmarcados
        local excluded = {}
        for kind, on in pairs(cfg.dispelTypes) do
            if not on then excluded[kind] = true end
        end
        return "HARMFUL|RAID", { excludeDispelTypes = excluded }
    elseif cfg.watch == "debuffTypes" then
        -- los tipos marcados, aunque mi clase no pueda disiparlos
        local included = {}
        for kind, on in pairs(cfg.dispelTypes) do
            if on then included[kind] = true end
        end
        return "HARMFUL", { includeDispelTypes = included }
    end
    -- bufos: por hechizo (todos los IDs de cada uno) o todos si no hay lista
    local filter = "HELPFUL" .. ((cfg.mine and not cfg.others) and "|PLAYER" or "")
    local cand = {}
    if #cfg.spells > 0 then
        local ids = {}
        for _, key in ipairs(cfg.spells) do
            for _, id in ipairs(ns.KeyIDs(key, ns.KeyRank(cfg, key))) do ids[id] = true end
        end
        cand.includeSpellIDs = ids
    end
    if cfg.others then cand.isFromPlayerOrPlayerPet = false end
    return filter, next(cand) and cand or nil
end

-------------------------------------------------------------------------------
-- Piezas comunes (las usan el botón nativo y el widget de muestra)
-------------------------------------------------------------------------------
local INSET = {
    TOPLEFT = { 1, -1 }, TOP = { 0, -1 }, TOPRIGHT = { 2, -1 },
    LEFT = { 1, 0 }, CENTER = { 0, 0 }, RIGHT = { 2, 0 },
    BOTTOMLEFT = { 1, -1 }, BOTTOM = { 0, -1 }, BOTTOMRIGHT = { 2, -1 },
}

local function TextCfg(cfg)
    return cfg.timerText or ns.indicatorDefaults.timerText, cfg.stacksText or ns.indicatorDefaults.stacksText
end

local function NewBorder(f)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetPoint("TOPLEFT", -1, 1)
    t:SetPoint("BOTTOMRIGHT", 1, -1)
    t:SetColorTexture(0, 0, 0, 1)
    return t
end

local function NewCooldown(f)
    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:SetHideCountdownNumbers(true)
    return cd
end

-- Vaciado (vertical, horizontal o barra fina abajo): alternativa al reloj
local function NewDrain(f)
    local d = CreateFrame("StatusBar", nil, f)
    d:SetStatusBarTexture(FLAT)
    d:SetMinMaxValues(0, 1)
    d.bg = d:CreateTexture(nil, "BACKGROUND")
    d.bg:SetAllPoints()
    d.bg:SetTexture(FLAT)
    return d
end

-- Capa por encima del barrido para los textos
local function NewTop(f, above)
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints()
    top:SetFrameLevel((above or f):GetFrameLevel() + 2)
    return top
end

local function StyleSweep(cd, drain, cfg, h)
    local style = cfg.swipeStyle or "clock"
    if cd then
        cd:SetReverse(style ~= "clockReverse")
        cd:SetDrawEdge(style == "clockEdge")
    end
    if not drain then return end
    drain:ClearAllPoints()
    if style == "bar" then
        local size = math.max(2, math.floor((h or 10) * 0.15 + 0.5))
        drain:SetPoint("BOTTOMLEFT")
        drain:SetPoint("BOTTOMRIGHT")
        drain:SetHeight(size)
        drain:SetOrientation("HORIZONTAL")
        drain:SetStatusBarColor(1, 1, 1, 0.95)
        drain.bg:SetVertexColor(0, 0, 0, 0.7)
    else
        drain:SetAllPoints()
        drain:SetOrientation(style == "drainV" and "VERTICAL" or "HORIZONTAL")
        drain:SetStatusBarColor(0, 0, 0, 0.6)
        drain.bg:SetVertexColor(0, 0, 0, 0)
    end
end

-- Texto del tiempo / de las cargas sobre un elemento
local function StyleTimer(fs, cfg, anchor, r, g, b)
    local tt = TextCfg(cfg)
    local o = INSET[tt.point or "CENTER"] or INSET.CENTER
    ns.StyleText(fs, tt, anchor, o[1], o[2])
    ns.ColorText(fs, tt, r, g, b)
end

local function StyleCount(fs, cfg, anchor, r, g, b)
    local _, st = TextCfg(cfg)
    local o = INSET[st.point or "BOTTOMRIGHT"] or INSET.CENTER
    ns.StyleText(fs, st, anchor, o[1], o[2])
    ns.ColorText(fs, st, r, g, b)
end

-- El tipo «Texto»: el propio texto va donde el indicador
local function StyleMainText(fs, cfg, anchor, r, g, b)
    local tt = TextCfg(cfg)
    ns.SetFont(fs, tt.font, tt.size or 9, tt.outline or "")
    fs:ClearAllPoints()
    local p = cfg.point or "CENTER"
    fs:SetPoint(p, anchor, p)
    fs:SetJustifyH(p:find("LEFT") and "LEFT" or (p:find("RIGHT") and "RIGHT" or "CENTER"))
    local c = cfg.color
    fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
end

-- Cargas al lado del texto (tipo «Texto»)
local function StyleSideCount(fs, cfg, main)
    local _, st = TextCfg(cfg)
    ns.SetFont(fs, st.font, st.size or 9, st.outline or "")
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", main, "RIGHT", 1, 0)
    ns.ColorText(fs, st)
end

-- Las cuatro líneas de un borde de grosor th
local function PlaceEdges(edges, th)
    for edge, tex in pairs(edges) do
        tex:ClearAllPoints()
        if edge == "TOP" or edge == "BOTTOM" then
            tex:SetPoint(edge .. "LEFT")
            tex:SetPoint(edge .. "RIGHT")
            tex:SetHeight(th)
        else
            tex:SetPoint("TOP" .. edge)
            tex:SetPoint("BOTTOM" .. edge)
            tex:SetWidth(th)
        end
    end
end

local function NewEdges(f)
    local edges = {}
    for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local tex = f:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(FLAT)
        edges[edge] = tex
    end
    return edges
end

local function PlaceTypeIcon(icon, cfg, anchor)
    local pos = cfg.typeIconPos or {}
    local sz = cfg.typeIconSize or 14
    icon:ClearAllPoints()
    icon:SetPoint(pos.point or "CENTER", anchor, pos.point or "CENTER", pos.x or 0, pos.y or 0)
    icon:SetSize(sz, sz)
end

-- Color de borde y tinte: el del tipo de debuff o el del indicador
local function FrameColor(cfg, kind)
    if Typed(cfg) and cfg.dispelColor then
        local r, g, b = ns.DispelColor(kind or "none")
        if r then return r, g, b end
        return ns.DispelColor("none")
    end
    return cfg.color.r, cfg.color.g, cfg.color.b
end

-------------------------------------------------------------------------------
-- Botón nativo: el juego le asigna un aura y rellena sus piezas
-------------------------------------------------------------------------------
local function DispelColorMap(cfg, noneR, noneG, noneB)
    local map = { None = CreateColor(noneR, noneG, noneB) }
    for _, kind in ipairs(DISPEL_KINDS) do
        map[kind] = CreateColor(FrameColor(cfg, kind))
    end
    return map
end

-- El color lo pone el juego según el tipo del aura
local function AddDispelTexture(button, tex, colors)
    button:AddDispelTypeTexture(tex, {
        showAlways = true,
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        customDispelColorMap = colors,
    })
end

local function AddTypeIcon(button, cfg)
    local icon = button:CreateTexture(nil, "OVERLAY", nil, 1)
    PlaceTypeIcon(icon, cfg, button)
    local assets = {}
    for _, kind in ipairs(DISPEL_KINDS) do assets[kind] = { asset = ns.DISPEL_ICONS[kind] } end
    button:AddDispelTypeTexture(icon, {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset,
        customDispelAssetMap = assets,
    })
end

local function BuildFrameButton(button, cfg, wt)
    local typed = Typed(cfg) and cfg.dispelColor
    local colors = typed and DispelColorMap(cfg, ns.DispelColor("none"))
    local function Paint(tex)
        if typed then
            AddDispelTexture(button, tex, colors)
        else
            tex:SetVertexColor(cfg.color.r, cfg.color.g, cfg.color.b, 1)
        end
    end
    if wt == "overlay" then
        -- la intensidad va en un marco aparte: el juego cambia el color del vértice
        local tint = CreateFrame("Frame", nil, button)
        tint:SetAllPoints()
        tint:SetAlpha(cfg.overlayAlpha or 0.6)
        local tex = tint:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetTexture(ns.DispelTintAsset(cfg.tintShape))
        Paint(tex)
    else
        local edges = NewEdges(button)
        PlaceEdges(edges, math.max(1, cfg.width or 2))
        for _, tex in pairs(edges) do Paint(tex) end
    end
    if Typed(cfg) and cfg.typeIcon then AddTypeIcon(button, cfg) end
end

local function BuildTextButton(button, cfg)
    local show = cfg.textShow or "time"
    local top = NewTop(button)
    local main = top:CreateFontString(nil, "OVERLAY")
    StyleMainText(main, cfg, button)
    if show == "time" then
        button:SetDurationText(main, {})
    elseif show == "name" then
        button:SetSpellName(main)
    elseif show == "stacks" then
        button:SetApplicationCount(main, {})
    elseif show == "caster" then
        button:SetCasterName(main, {})
    else
        main:SetText(cfg.customText or "")
    end
    if cfg.stacks and show ~= "stacks" then
        local count = top:CreateFontString(nil, "OVERLAY")
        StyleSideCount(count, cfg, main)
        button:SetApplicationCount(count, {})
    end
end

local function BuildAuraButton(button, cfg, wt)
    button:EnableMouse(false)
    if wt == "border" or wt == "overlay" then return BuildFrameButton(button, cfg, wt) end
    if wt == "text" then return BuildTextButton(button, cfg) end

    local w, h = button:GetSize()
    local border = NewBorder(button)
    border:SetShown(cfg.showBorder ~= false)
    if wt == "icon" and Typed(cfg) and cfg.dispelColor and cfg.showBorder ~= false then
        AddDispelTexture(button, border, DispelColorMap(cfg, 0, 0, 0))
    end
    local above = button
    if wt == "icon" then
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button:SetIcon(icon)
    elseif wt == "square" then
        local tex = button:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetColorTexture(cfg.color.r, cfg.color.g, cfg.color.b, cfg.color.a or 1)
    elseif wt == "bar" then
        border:SetColorTexture(0, 0, 0, 0.8)
        local bg = button:CreateTexture(nil, "BORDER")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.5)
        local bar = CreateFrame("StatusBar", nil, button)
        bar:SetAllPoints()
        bar:SetStatusBarTexture(FLAT)
        local c = cfg.color
        bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        bar:SetOrientation(cfg.barOrient == "VERTICAL" and "VERTICAL" or "HORIZONTAL")
        bar:SetReverseFill(cfg.barReverse and true or false)
        if cfg.barMeasure == "stacks" then
            button:SetApplicationBar(bar, { maxApplications = math.max(1, cfg.barMaxStacks or 5) })
        else
            button:SetDurationBar(bar, {})
        end
        above = bar
    end
    if wt ~= "bar" and cfg.swipe ~= false then
        if ClockSweep(cfg) then
            local cd = NewCooldown(button)
            StyleSweep(cd, nil, cfg)
            button:SetDurationCooldown(cd)
            above = cd
        else
            local drain = NewDrain(button)
            StyleSweep(nil, drain, cfg, h)
            local dir = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime
            button:SetDurationBar(drain, { direction = dir })
            above = drain
        end
    end
    local top = NewTop(button, above)
    if cfg.timer then
        local fs = top:CreateFontString(nil, "OVERLAY")
        StyleTimer(fs, cfg, button)
        button:SetDurationText(fs, {})
    end
    if cfg.stacks then
        local fs = top:CreateFontString(nil, "OVERLAY")
        StyleCount(fs, cfg, button)
        button:SetApplicationCount(fs, {})
    end
    return w
end

-- Contenedor nativo de un indicador, pegado a su widget
local function NewContainer(w, cfg)
    local filter, candidates, sort = Query(cfg)
    local wt = WidgetType(cfg)
    local container = CreateFrame("AuraContainer", nil, w:GetParent(), "CustomAuraContainerTemplate")
    container:Hide()
    container:SetFrameLevel(w:GetFrameLevel())
    local options = { candidateFilters = candidates, sortMethod = sort }
    if wt == "icons" then
        container:SetPoint(cfg.point, w, cfg.point)
        container:SetFlowLayoutAnchorPoint(cfg.point)
        local vertical = cfg.grow == "UP" or cfg.grow == "DOWN"
        container:SetFlowLayoutAxis(vertical and AnchorUtil.FlowLayoutAxis.Vertical or AnchorUtil.FlowLayoutAxis.Horizontal)
        container:SetFlowLayoutGrowthDirection(
            cfg.grow == "LEFT" and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right,
            cfg.grow == "UP" and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
        options.maxFrameCount = cfg.max
        options.layout = { elementSpacing = cfg.spacing, elementWidth = cfg.width, elementHeight = cfg.height }
        options.initializeFrame = function(button)
            button:SetSize(cfg.width, cfg.height)
            BuildAuraButton(button, cfg, "icon")
        end
        container:AddAuraGroup("auras", filter, options)
    else
        container:SetSize(1, 1)
        container:SetPoint("CENTER", w, "CENTER")
        options.initializeFrame = function(button)
            button:SetSize(w:GetSize())
            button:SetPoint("TOPLEFT", w, "TOPLEFT")
            button:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT")
            BuildAuraButton(button, cfg, wt)
        end
        container:AddAuraSlot("aura", filter, options)
    end
    return container
end

-- Firma de todo lo que define un contenedor: si no cambia, se reutiliza
local function Sig(v, out)
    if type(v) == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, c) return tostring(a) < tostring(c) end)
        out[#out + 1] = "{"
        for _, k in ipairs(keys) do
            out[#out + 1] = tostring(k) .. "="
            Sig(v[k], out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    else
        out[#out + 1] = tostring(v)
    end
    return out
end

local function NativeKey(w, cfg)
    local filter, candidates, sort = Query(cfg)
    return table.concat(Sig({ cfg, ns.P.dispelColors, filter, candidates, sort, w:GetFrameLevel() }, {}))
end

-- Solo fuera de combate: crear contenedores no se puede hacer en combate
local function AttachNative(b, w, cfg)
    if b.testIndex or Missing(cfg) or UnitMeasure(cfg) then
        if w.native then
            w.native:Hide()
            w.native:SetUnit("none")
            w.native, w.nativeKey, w.nativeUnit = nil, nil, nil
        end
        return
    end
    local key = NativeKey(w, cfg)
    if w.native and w.nativeKey == key then return end
    if w.native then
        w.native:Hide()
        w.native:SetUnit("none")
    end
    w.native, w.nativeKey, w.nativeUnit = nil, nil, nil
    local ok, result = pcall(NewContainer, w, cfg)
    if ok then
        w.native, w.nativeKey = result, key
    elseif not ns.nativeWarned then
        ns.nativeWarned = true
        ns.Print("no se pudo crear un indicador: " .. tostring(result))
    end
end

-------------------------------------------------------------------------------
-- Widget propio: modo prueba, muestra de opciones, «Le falta» y barras de
-- escudos o curación. Se crea una vez por tipo y se vuelve a colocar.
-------------------------------------------------------------------------------
local function NewIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "icon"
    f.border = NewBorder(f)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.cd = NewCooldown(f)
    f.drain = NewDrain(f)
    f.drain:SetFrameLevel(f.cd:GetFrameLevel())
    f.top = NewTop(f, f.cd)
    f.timerText = f.top:CreateFontString(nil, "OVERLAY")
    f.count = f.top:CreateFontString(nil, "OVERLAY")
    f:Hide()
    return f
end

local creators = {}

creators.icon = NewIcon

creators.icons = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "icons"
    f.icons = {}
    return f
end

creators.square = function(parent)
    local f = NewIcon(parent)
    f.wtype = "square"
    f.tex:SetTexCoord(0, 1, 0, 1)
    f.tex:SetTexture(FLAT)
    return f
end

creators.bar = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "bar"
    f.border = NewBorder(f)
    f.border:SetColorTexture(0, 0, 0, 0.8)
    f.bg = f:CreateTexture(nil, "BORDER")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.5)
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetAllPoints()
    f.bar:SetStatusBarTexture(FLAT)
    f.bar:SetMinMaxValues(0, 1)
    f.top = NewTop(f, f.bar)
    f.timerText = f.top:CreateFontString(nil, "OVERLAY")
    f.count = f.top:CreateFontString(nil, "OVERLAY")
    f:Hide()
    return f
end

creators.text = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "text"
    f.top = NewTop(f)
    f.timerText = f.top:CreateFontString(nil, "OVERLAY")
    f.count = f.top:CreateFontString(nil, "OVERLAY")
    f:Hide()
    return f
end

creators.border = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "border"
    f.edges = NewEdges(f)
    f.typeIcon = f:CreateTexture(nil, "OVERLAY", nil, 7)
    f:Hide()
    return f
end

creators.overlay = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.wtype = "overlay"
    f.tint = CreateFrame("Frame", nil, f)
    f.tint:SetAllPoints()
    f.tex = f.tint:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.typeIcon = f:CreateTexture(nil, "OVERLAY", nil, 7)
    f:Hide()
    return f
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

-- Estilo de un icono o cuadrado propio (lo mismo que su botón nativo)
local function StyleIconWidget(f, cfg)
    f.border:SetShown(cfg.showBorder ~= false)
    f.border:SetColorTexture(0, 0, 0, 1)
    StyleSweep(f.cd, f.drain, cfg, f:GetHeight())
    f.swipeOn = cfg.swipe ~= false and ClockSweep(cfg)
    f.cd:SetDrawSwipe(f.swipeOn)
    f.drainOn = cfg.swipe ~= false and not ClockSweep(cfg)
    StyleTimer(f.timerText, cfg, f)
    StyleCount(f.count, cfg, f)
    if f.wtype == "square" then
        local c = cfg.color
        f.tex:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    end
end

local function LayoutWidget(w, cfg, b)
    w.previewClass, w.previewIsPet = b.testClass, b.testIndex and b.isPet or nil
    w:ClearAllPoints()
    local t = w.wtype
    if t == "border" then
        local th = math.max(1, cfg.width or 2)
        if cfg.borderInside then
            w:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
            w:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        else
            w:SetPoint("TOPLEFT", b, "TOPLEFT", -th + 1, th - 1)
            w:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", th - 1, -th + 1)
        end
        PlaceEdges(w.edges, th)
        PlaceTypeIcon(w.typeIcon, cfg, w)
        return
    elseif t == "overlay" then
        w:SetAllPoints(b.health)
        w.tint:SetAlpha(cfg.overlayAlpha or 0.6)
        w.tex:SetTexture(ns.DispelTintAsset(cfg.tintShape))
        PlaceTypeIcon(w.typeIcon, cfg, w)
        return
    end

    w:SetPoint(cfg.point, b, cfg.point, cfg.x, cfg.y)
    if t == "text" then
        local size = TextCfg(cfg).size or 9
        w:SetSize(math.max(10, size * 2.5), size + 2)
        StyleMainText(w.timerText, cfg, w)
        StyleSideCount(w.count, cfg, w.timerText)
        return
    end
    w:SetSize(cfg.width, cfg.height)
    -- ocupar un lado entero del marco (como la línea de amenaza)
    if t == "bar" and (cfg.span == "width" or cfg.span == "height") then
        local L = ns.P.layout
        local fw, fh = L.width, L.height
        if b.isPet then fw, fh = ns.PetSize() end
        if cfg.span == "width" then w:SetWidth(math.max(1, fw - 2)) else w:SetHeight(math.max(1, fh - 2)) end
    end
    if t == "bar" then
        w.border:SetShown(cfg.showBorder ~= false)
        w.bar:SetOrientation(cfg.barOrient == "VERTICAL" and "VERTICAL" or "HORIZONTAL")
        w.bar:SetReverseFill(cfg.barReverse and true or false)
        local c = cfg.color
        w.bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        -- escudos / curación: sin fondo, para que vacía no se vea
        w.bg:SetShown(not UnitMeasure(cfg))
        StyleTimer(w.timerText, cfg, w)
        StyleCount(w.count, cfg, w)
    elseif t == "icons" then
        for i = 1, math.max(cfg.max, #w.icons) do
            local icon = w.icons[i]
            if not icon and i <= cfg.max then
                icon = NewIcon(w)
                w.icons[i] = icon
            end
            if icon then
                icon:ClearAllPoints()
                local x, y = GrowOffset(cfg, i)
                icon:SetPoint(cfg.point, w, cfg.point, x, y)
                icon:SetSize(cfg.width, cfg.height)
                icon.previewClass, icon.previewIsPet = w.previewClass, w.previewIsPet
                StyleIconWidget(icon, cfg)
                icon:Hide()
            end
        end
    else
        StyleIconWidget(w, cfg)
    end
end

local function HideWidget(w)
    if not w then return end
    for _, ic in ipairs(w.icons or {}) do ic:Hide() end
    if w.tex and w.tex.SetDesaturated then w.tex:SetDesaturated(false) end
    w:Hide()
end
ns.HideWidget = HideWidget

-- Crea/reutiliza los widgets y contenedores de todos los indicadores de un
-- botón. Se llama fuera de combate (al aplicar el perfil).
function ns.BuildIndicators(b)
    b.ind = b.ind or {}
    b.pool = b.pool or {}
    for _, w in pairs(b.ind) do
        HideWidget(w)
        if w.native then w.native:Hide() end
        local p = b.pool[w.wtype]
        if not p then p = {} b.pool[w.wtype] = p end
        table.insert(p, w)
    end
    wipe(b.ind)
    for _, c in ipairs(ns.compiled) do
        local cfg = c.cfg
        local wt = WidgetType(cfg)
        local p = b.pool[wt]
        local w
        -- mejor el que ya tenía este mismo indicador (conserva su contenedor)
        for i = #(p or {}), 1, -1 do
            if p[i].cfgRef == cfg then w = table.remove(p, i) break end
        end
        w = w or (p and table.remove(p))
        if not w then
            w = creators[wt]((wt == "border") and b or b.overlay)
        end
        w.cfgRef = cfg
        LayoutWidget(w, cfg, b)
        -- orden de dibujo = orden de la lista (los de abajo, por encima)
        w:SetFrameLevel(b.overlay:GetFrameLevel() + (wt == "border" and 1 or (3 + c.index * 3)))
        b.ind[c.index] = w
        AttachNative(b, w, cfg)
    end
    -- los que sobran ya no se usan: sus contenedores, sin unidad
    for _, p in pairs(b.pool) do
        for _, w in ipairs(p) do
            if w.native then
                w.native:SetUnit("none")
                w.native, w.nativeKey, w.nativeUnit = nil, nil, nil
            end
            w.cfgRef = nil
        end
    end
    -- franjas propias: su sitio depende de las demás y de la barra de maná
    if ns.AnchorHealth then ns.AnchorHealth(b, b.powerShown) end
end

-- La unidad del botón ha cambiado: los contenedores siguen a la nueva
function ns.SetIndicatorsUnit(b, unit)
    for _, w in pairs(b.ind or {}) do
        if w.native then
            w.native:Hide()
            w.native:SetUnit(unit or "none")
            w.nativeUnit = unit
        end
    end
end

-------------------------------------------------------------------------------
-- Pintar auras de ejemplo (modo prueba) y «Le falta» en el widget propio
-------------------------------------------------------------------------------
local function FormatTime(t)
    if t >= 60 then return ("%dm"):format(math.ceil(t / 60)) end
    if t >= 3 then return ("%d"):format(math.ceil(t)) end
    return ("%.1f"):format(t)
end

-- Color de clase en los textos del tiempo y las cargas
local function ColorTexts(w, cfg)
    if w.wtype == "text" then return end
    local tt, st = TextCfg(cfg)
    local r, g, b
    if tt.colorMode == "class" or st.colorMode == "class" then
        r, g, b = ns.ClassColorOf(nil, w.previewClass, w.previewIsPet)
    end
    ns.ColorText(w.timerText, tt, r, g, b)
    ns.ColorText(w.count, st, r, g, b)
end

local function PaintFrame(w, cfg, kind)
    local r, g, b = FrameColor(cfg, kind)
    if w.wtype == "overlay" then
        w.tex:SetVertexColor(r, g, b, 1)
    else
        for _, tex in pairs(w.edges) do tex:SetVertexColor(r, g, b, 1) end
    end
    local file = Typed(cfg) and cfg.typeIcon and kind and ns.DISPEL_ICONS[kind]
    if file then w.typeIcon:SetTexture(file) end
    w.typeIcon:SetShown(file and true or false)
    w:Show()
end

local function PaintText(w, cfg, a)
    local show = cfg.textShow or "time"
    local fs = w.timerText
    if show == "time" then
        fs:SetText(FormatTime(a.expirationTime - GetTime()))
    elseif show == "custom" then
        fs:SetText(cfg.customText or "")
    elseif show == "name" then
        fs:SetText(a.spellId and ns.GetSpellName(a.spellId) or "")
    elseif show == "stacks" then
        fs:SetText(a.applications > 0 and a.applications or "")
    elseif show == "caster" then
        fs:SetText(UnitName("player") or "")
    end
    w.count:SetText((cfg.stacks and show ~= "stacks" and a.applications > 1) and a.applications or "")
    w:Show()
end

-- a: { icon, duration, expirationTime, applications, dispelName, spellId }
local function PaintAura(w, cfg, a)
    local wt = w.wtype
    if wt == "border" or wt == "overlay" then return PaintFrame(w, cfg, a.dispelName) end
    if wt == "text" then return PaintText(w, cfg, a) end
    local remain = a.expirationTime - GetTime()
    if wt == "icon" then
        w.tex:SetTexture(a.icon)
        w.tex:SetDesaturated(false)
        local r, g, b = 0, 0, 0
        if Typed(cfg) and cfg.dispelColor and a.dispelName then r, g, b = ns.DispelColor(a.dispelName) end
        w.border:SetColorTexture(r, g, b, 1)
    end
    if wt == "bar" then
        if cfg.barMeasure == "stacks" then
            w.bar:SetMinMaxValues(0, math.max(1, cfg.barMaxStacks or 5))
            w.bar:SetValue(a.applications)
        else
            w.bar:SetMinMaxValues(0, 1)
            w.bar:SetValue(remain / a.duration)
        end
    else
        if w.swipeOn then w.cd:SetCooldown(a.expirationTime - a.duration, a.duration) else w.cd:Clear() end
        w.drain:SetValue(1 - remain / a.duration)
        w.drain:SetShown(w.drainOn)
    end
    ColorTexts(w, cfg)
    w.timerText:SetText(cfg.timer and FormatTime(remain) or "")
    w.count:SetText((cfg.stacks and a.applications > 1) and a.applications or "")
    w:Show()
end

-- «Le falta»: el widget se ve fijo, sin tiempo
local function ShowMissing(w, cfg)
    local wt = w.wtype
    if wt == "border" or wt == "overlay" then return PaintFrame(w, cfg, nil) end
    if wt == "icons" then
        for i, ic in ipairs(w.icons) do
            if i == 1 then ShowMissing(ic, cfg) else ic:Hide() end
        end
        w:Show()
        return
    end
    local key = cfg.spells[1]
    if wt == "text" then
        local show = cfg.textShow or "time"
        if show == "custom" and (cfg.customText or "") ~= "" then
            w.timerText:SetText(cfg.customText)
        elseif show == "name" then
            w.timerText:SetText((ns.SpellKeyInfo(key)) or "!")
        else
            w.timerText:SetText("!")
        end
        w.count:SetText("")
        w:Show()
        return
    end
    if wt == "icon" then
        local _, icon = ns.SpellKeyInfo(key)
        w.tex:SetTexture(icon or ns.QUESTION_ICON)
        w.tex:SetDesaturated(true)
        w.border:SetColorTexture(0, 0, 0, 1)
    elseif wt == "bar" then
        w.bar:SetMinMaxValues(0, 1)
        w.bar:SetValue(1)
    end
    if w.cd then w.cd:Clear() end
    if w.drain then w.drain:Hide() end
    w.timerText:SetText("")
    w.count:SetText("")
    w:Show()
end

local function PaintIcons(w, cfg, list)
    for i, ic in ipairs(w.icons) do
        local a = list[i]
        if a and i <= cfg.max then PaintAura(ic, cfg, a) else ic:Hide() end
    end
    w:SetShown(#list > 0)
end

-------------------------------------------------------------------------------
-- Actualizar
-------------------------------------------------------------------------------
-- Barra de escudos o de curación entrante (datos de la unidad)
local function ShowUnitBar(w, unit, cfg)
    local max = UnitHealthMax(unit)
    local value
    if cfg.barMeasure == "absorb" then value = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit)
    else value = UnitGetIncomingHeals and UnitGetIncomingHeals(unit) end
    w.bar:SetMinMaxValues(0, S(max) and max or (max or 0))
    w.bar:SetValue(S(value) and value or (value or 0))
    w.timerText:SetText("")
    w.count:SetText("")
    w:Show()
end

-- Tras cambiar los escudos, la curación entrante o la vida máxima
function ns.UpdateUnitBars(b)
    local unit = b.unit
    if not unit or not b.ind then return end
    local inCombat = InCombatLockdown()
    for _, c in ipairs(ns.compiled) do
        local w = b.ind[c.index]
        if w and UnitMeasure(c.cfg) then
            if c.cfg.onlyOOC and inCombat then HideWidget(w) else ShowUnitBar(w, unit, c.cfg) end
        end
    end
end

-- ¿Tiene alguno de los bufos? true / false, o nil si el juego no deja saberlo
local function HasAura(unit, cfg, byID)
    if not GetAuraDataByIndex then return nil end
    local filter = "HELPFUL" .. ((cfg.mine and not cfg.others) and "|PLAYER" or "")
    for i = 1, 40 do
        local ok, a = pcall(GetAuraDataByIndex, unit, i, filter)
        if not ok then return nil end
        if not a then return false end
        local id = a.spellId
        if S(id) then return nil end
        if byID[id] then
            if not cfg.others then return true end
            local src = R(a.sourceUnit)
            if src ~= "player" and src ~= "pet" then return true end
        end
    end
    return nil
end

function ns.UpdateAuras(b)
    local unit = b.unit
    if not unit or not b.ind then return end
    local inCombat = InCombatLockdown()
    for _, c in ipairs(ns.compiled) do
        local cfg, w = c.cfg, b.ind[c.index]
        if not w then
            -- nada
        elseif w.native then
            w:Hide()
            if w.nativeUnit ~= unit then
                w.native:SetUnit(unit)
                w.nativeUnit = unit
            end
            w.native:SetShown(not (cfg.onlyOOC and inCombat))
        elseif UnitMeasure(cfg) then
            if cfg.onlyOOC and inCombat then HideWidget(w) else ShowUnitBar(w, unit, cfg) end
        elseif Missing(cfg) and not inCombat and HasAura(unit, cfg, c.byID) == false then
            ShowMissing(w, cfg)
        else
            HideWidget(w)
        end
    end
end

-------------------------------------------------------------------------------
-- Datos falsos para el modo prueba y la muestra de opciones
-- ns.preview = { cfg = indicador }: enseñarlo en más marcos mientras se edita
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
            -- tipo de ejemplo: uno de los marcados
            local kind
            if cfg.kind == "aura" and Typed(cfg) then
                for _, k in ipairs(DISPEL_KINDS) do
                    if cfg.dispelTypes[k] then kind = k break end
                end
            end
            local function Fake(key, n, dispel)
                local _, icon = ns.SpellKeyInfo(key)
                local dur = 15 + (i * 7 + n * 5) % 30
                return { icon = icon or 136207, duration = dur, expirationTime = now + dur * (0.3 + ((i + n) % 7) / 10),
                    applications = (n == 2) and 3 or 0, dispelName = dispel,
                    spellId = key ~= nil and ns.KeyIDs(key)[1] or nil }
            end
            HideWidget(w)
            -- all: la muestra de Indicadores enseña el indicador que se edita
            -- (b.previewOnly) o, si no, todos a la vez
            local focus = all or (pv and pv.cfg == cfg)
            local skip = (b.previewOnly and c.index ~= b.previewOnly)
                or (cfg.kind == "aura" and Typed(cfg) and not kind)
            if skip then
                -- nada
            elseif UnitMeasure(cfg) then
                w.bar:SetMinMaxValues(0, 100)
                w.bar:SetValue((i % 3 == 0 or focus) and (15 + (i * 13) % 40) or 0)
                w:Show()
            elseif Missing(cfg) then
                if i % 4 == 1 or (focus and i % 3 == 1) then ShowMissing(w, cfg) end
            elseif cfg.kind == "aura" then
                if (i + c.index) % 3 ~= 0 or (focus and i % 2 == 1) then
                    local first = cfg.spells[1]
                    if w.wtype == "icons" then
                        local list = {}
                        for n = 1, math.min(cfg.max, math.max(1, #cfg.spells)) do
                            list[n] = Fake(cfg.spells[n] or first, n)
                        end
                        PaintIcons(w, cfg, list)
                    elseif w.wtype == "border" or w.wtype == "overlay" then
                        -- en pocos marcos, para que no tape todo el modo prueba
                        if i % 6 == 4 or focus then PaintAura(w, cfg, Fake(first, 1, kind)) end
                    else
                        PaintAura(w, cfg, Fake(first, 1, kind))
                    end
                end
            elseif cfg.kind == "raiddebuff" then
                if i % 5 == 2 or (focus and i % 3 == 1) then PaintAura(w, cfg, Fake(20475, 1, "Magic")) end
            elseif cfg.kind == "debuffs" then
                local n = i % 3
                if focus and n == 0 then n = 1 end
                if all then n = cfg.max end
                local list = {}
                for k = 1, math.min(cfg.max, n) do
                    list[k] = Fake(nil, k, k == 1 and "Poison" or nil)
                    list[k].icon = (k == 1) and 136016 or 136207
                end
                PaintIcons(w, cfg, list)
            end
        end
    end
end
