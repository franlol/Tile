-------------------------------------------------------------------------------
-- MendFrames - Panel de muestra (/mf demo)
-- Solo aspecto: maqueta del panel nuevo para verla dentro del juego.
-- Los controles se mueven, pero no cambian ninguna opción real.
-------------------------------------------------------------------------------

local _, ns = ...

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT
local demo

-- Colores base
local C = {
    win = { 0.055, 0.059, 0.075 },
    bar = { 0.071, 0.078, 0.098 },
    card = { 0.082, 0.090, 0.114 },
    raised = { 0.110, 0.122, 0.153 },
    line = { 0.137, 0.149, 0.184 },
    line2 = { 0.165, 0.180, 0.220 },
    text = { 0.91, 0.914, 0.933 },
    muted = { 0.64, 0.66, 0.71 },
    dim = { 0.55, 0.576, 0.627 },
    off = { 0.165, 0.18, 0.22 },
}

local A, INK -- acento (color de clase) y tinta sobre el acento

local function ClassAccent()
    local _, cls = UnitClass("player")
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    local r, g, b = 0.31, 0.76, 0.97
    if c then r, g, b = c.r, c.g, c.b end
    A = { r, g, b }
    local lum = 0.299 * r + 0.587 * g + 0.114 * b
    INK = lum > 0.5 and { 0.08, 0.07, 0.05 } or { 1, 1, 1 }
end

-------------------------------------------------------------------------------
-- Piezas
-------------------------------------------------------------------------------
local function Fill(parent, col, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(col[1], col[2], col[3], a or 1)
    return t
end

local function Box(parent, w, h, bg, border, a)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if w then f:SetSize(w, h) end
    f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    f:SetBackdropColor(bg[1], bg[2], bg[3], a or 1)
    local e = border or C.line
    f:SetBackdropBorderColor(e[1], e[2], e[3], 1)
    return f
end

local function Txt(parent, s, size, col, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(FONT, size or 12, "")
    local c = col or C.text
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetText(s or "")
    fs:SetJustifyH("LEFT")
    return fs
end

local function HLine(parent)
    local t = Fill(parent, C.line, 1, "ARTWORK")
    t:SetHeight(1)
    return t
end

local function Icon(parent, path, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    t:SetTexture(path)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return t
end

-- Botón plano con borde que se ilumina al pasar el ratón
local function Btn(parent, text, w, h, bg)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    local c = bg or C.raised
    b:SetBackdropColor(c[1], c[2], c[3], 1)
    b:SetBackdropBorderColor(C.line2[1], C.line2[2], C.line2[3], 1)
    b.text = Txt(b, text, 12)
    b.text:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(A[1], A[2], A[3], 0.8) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(C.line2[1], C.line2[2], C.line2[3], 1) end)
    return b
end

-- Interruptor
local function Toggle(parent, on, onChange)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(36, 20)
    b.track = Fill(b, C.off, 1, "ARTWORK")
    b.track:SetAllPoints()
    b.knob = b:CreateTexture(nil, "OVERLAY")
    b.knob:SetSize(14, 14)
    function b:Set(v)
        self.on = v
        if v then
            self.track:SetColorTexture(A[1], A[2], A[3], 1)
            self.knob:SetColorTexture(INK[1], INK[2], INK[3], 1)
            self.knob:ClearAllPoints()
            self.knob:SetPoint("RIGHT", -3, 0)
        else
            self.track:SetColorTexture(C.off[1], C.off[2], C.off[3], 1)
            self.knob:SetColorTexture(0.6, 0.62, 0.68, 1)
            self.knob:ClearAllPoints()
            self.knob:SetPoint("LEFT", 3, 0)
        end
    end
    b:SetScript("OnClick", function(self)
        self:Set(not self.on)
        if onChange then onChange(self.on) end
    end)
    b:Set(on)
    return b
end

-- Botones segmentados (uno elegido)
local function Segmented(parent, labels, sel, onChange)
    local f = Box(parent, 10, 26, C.win, C.line)
    local x = 3
    local btns = {}
    local function Paint()
        for i, b in ipairs(btns) do
            if i == f.sel then
                b.bg:SetColorTexture(A[1], A[2], A[3], 1)
                b.text:SetTextColor(INK[1], INK[2], INK[3])
            else
                b.bg:SetColorTexture(0, 0, 0, 0)
                b.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
            end
        end
    end
    for i, l in ipairs(labels) do
        local b = CreateFrame("Button", nil, f)
        b.bg = Fill(b, C.off, 1, "ARTWORK")
        b.bg:SetAllPoints()
        b.text = Txt(b, l, 11.5)
        b.text:SetPoint("CENTER")
        local w = math.floor(b.text:GetStringWidth() + 20)
        b:SetSize(w, 20)
        b:SetPoint("LEFT", x, 0)
        x = x + w + 2
        b:SetScript("OnClick", function()
            f.sel = i
            Paint()
            if onChange then onChange(i) end
        end)
        btns[i] = b
    end
    f:SetWidth(x + 1)
    f.sel = sel
    Paint()
    return f
end

-- Deslizador con la parte llena de color y el valor al lado
local function Slider(parent, value, onChange)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(170, 20)
    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("LEFT")
    s:SetSize(126, 16)
    local track = Fill(s, C.off, 1, "BACKGROUND")
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    local fill = Fill(s, A, 1, "ARTWORK")
    fill:SetPoint("LEFT")
    fill:SetHeight(4)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.95, 0.95, 0.97, 1)
    thumb:SetSize(8, 14)
    s:SetThumbTexture(thumb)
    s:SetMinMaxValues(0, 100)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    local val = Txt(f, "", 11.5, { 0.79, 0.80, 0.84 })
    val:SetPoint("RIGHT")
    val:SetJustifyH("RIGHT")
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        fill:SetWidth(math.max(1, 126 * v / 100))
        val:SetText(v .. "%")
        if onChange then onChange(v) end
    end)
    s:SetValue(value)
    return f
end

local function Swatch(parent, r, g, b)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(22, 22)
    f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    f:SetBackdropColor(r, g, b, 1)
    f:SetBackdropBorderColor(1, 1, 1, 0.3)
    return f
end

local function Dropdown(parent, text, w)
    local b = Btn(parent, "", w or 150, 26)
    local stripe = Fill(b, A, 1, "ARTWORK")
    stripe:SetSize(40, 8)
    stripe:SetPoint("LEFT", 9, 0)
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", stripe, "RIGHT", 8, 0)
    b.text:SetText(text)
    local arrow = Txt(b, "v", 11, C.muted)
    arrow:SetPoint("RIGHT", -9, 0)
    return b
end

-------------------------------------------------------------------------------
-- Sección (tarjeta con título y filas)
--   :Row(etiqueta, ayuda, control)      opción nueva (con línea encima)
--   :Sub(etiqueta, control)             parte de la opción de arriba
--   :Stacked(etiqueta, control)         etiqueta arriba, control debajo
-------------------------------------------------------------------------------
local function Section(parent, x, y, w, title)
    local s = Box(parent, w, 10, C.card, C.line)
    s:SetPoint("TOPLEFT", x, y)
    local h = Txt(s, title:upper(), 10.5, A)
    h:SetPoint("TOPLEFT", 14, -12)
    s.y = -30
    s.rows = 0
    local function Divider()
        if s.rows > 0 then
            local l = HLine(s)
            l:SetPoint("TOPLEFT", 14, s.y)
            l:SetPoint("TOPRIGHT", -14, s.y)
        end
        s.rows = s.rows + 1
    end
    function s:Row(label, help, control)
        Divider()
        local rh = help and 44 or 38
        local l = Txt(self, label, 12.5)
        if help then
            l:SetPoint("TOPLEFT", 14, self.y - 8)
            local hh = Txt(self, help, 11, C.dim)
            hh:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -3)
        else
            l:SetPoint("LEFT", self, "TOPLEFT", 14, self.y - rh / 2)
        end
        control:SetParent(self)
        control:ClearAllPoints()
        control:SetPoint("RIGHT", self, "TOPRIGHT", -14, self.y - rh / 2)
        self.y = self.y - rh
    end
    function s:Sub(label, control)
        local rh = 30
        local l = Txt(self, label, 12, { 0.73, 0.75, 0.79 })
        l:SetPoint("LEFT", self, "TOPLEFT", 28, self.y - rh / 2 + 3)
        control:SetParent(self)
        control:ClearAllPoints()
        control:SetPoint("RIGHT", self, "TOPRIGHT", -14, self.y - rh / 2 + 3)
        self.y = self.y - rh
    end
    function s:Stacked(label, control)
        Divider()
        local l = Txt(self, label, 12.5)
        l:SetPoint("TOPLEFT", 14, self.y - 10)
        control:SetParent(self)
        control:ClearAllPoints()
        control:SetPoint("TOPLEFT", 14, self.y - 30)
        self.y = self.y - 64
    end
    function s:Finish()
        self:SetHeight(-self.y + 8)
        return self.y
    end
    return s
end

-------------------------------------------------------------------------------
-- Vista previa: marcos de ejemplo
-------------------------------------------------------------------------------
local MEMBERS = {
    { "Brakkus", "WARRIOR", 0.38, 0.24, 0.14, "-3.1k", aggro = true, debuff = { 0.24, 0.55, 1 }, hots = 2 },
    { "Thalia", "PALADIN", 0.64, 0.16, 0, "-1.4k", target = true, hots = 1 },
    { "Elowen", "DRUID", 1, 0, 0.10, "" },
    { "Vexia", "WARLOCK", 0.76, 0, 0, "-620", far = true, debuff = { 0.64, 0.21, 0.93 } },
    { "Korran", "MAGE", 0, 0, 0, "Muerto", dead = true },
}

local function BuildPreview(parent, state)
    local frames = {}
    local W, H = 262, 42
    for i, m in ipairs(MEMBERS) do
        local c = RAID_CLASS_COLORS[m[2]] or { r = 0.6, g = 0.6, b = 0.6 }
        local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        f:SetSize(W, H)
        f:SetPoint("TOPLEFT", 18, -64 - (i - 1) * (H + 4))
        f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = (m.aggro or m.target) and 2 or 1 })
        f:SetBackdropColor(c.r * 0.22, c.g * 0.22, c.b * 0.22, 1)
        if m.target then
            f:SetBackdropBorderColor(1, 1, 1, 1)
        elseif m.aggro then
            f:SetBackdropBorderColor(1, 0.29, 0.24, 1)
        else
            f:SetBackdropBorderColor(0, 0, 0, 1)
        end
        local inner = W - 4
        local hp = Fill(f, { c.r * 0.85, c.g * 0.85, c.b * 0.85 }, 1, "BORDER")
        hp:SetPoint("TOPLEFT", 2, -2)
        hp:SetPoint("BOTTOMLEFT", 2, 2)
        hp:SetWidth(math.max(0.01, inner * m[3]))
        if m[3] == 0 then hp:Hide() end
        local pred = Fill(f, { 0.25, 0.83, 0.48 }, 0.55, "ARTWORK")
        pred:SetPoint("TOPLEFT", hp, "TOPRIGHT")
        pred:SetPoint("BOTTOMLEFT", hp, "BOTTOMRIGHT")
        pred:SetWidth(math.max(0.01, inner * m[4]))
        pred:SetShown(m[4] > 0)
        local abs = Fill(f, { 0.87, 0.91, 1 }, 0.5, "ARTWORK")
        abs:SetPoint("TOPLEFT", pred, "TOPRIGHT")
        abs:SetPoint("BOTTOMLEFT", pred, "BOTTOMRIGHT")
        abs:SetWidth(math.max(0.01, inner * m[5]))
        abs:SetShown(m[5] > 0)
        local name = Txt(f, m[1], 12.5, m.dead and C.dim or { 1, 1, 1 })
        name:SetShadowOffset(1, -1)
        name:SetShadowColor(0, 0, 0, 1)
        name:SetPoint("TOPLEFT", 7, -6)
        local tag = Txt(f, m[6], 11, { 0.95, 0.95, 0.96 })
        tag:SetShadowOffset(1, -1)
        tag:SetShadowColor(0, 0, 0, 1)
        tag:SetPoint("BOTTOMRIGHT", -7, 6)
        for k = 1, (m.hots or 0) do
            local sq = CreateFrame("Frame", nil, f, "BackdropTemplate")
            sq:SetSize(9, 9)
            sq:SetPoint("TOPRIGHT", -4 - (k - 1) * 12, -4)
            sq:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
            local hc = k == 1 and { 0.48, 0.86, 0.35 } or A
            sq:SetBackdropColor(hc[1], hc[2], hc[3], 1)
            sq:SetBackdropBorderColor(0, 0, 0, 1)
        end
        if m.debuff then
            local d = CreateFrame("Frame", nil, f, "BackdropTemplate")
            d:SetSize(15, 15)
            d:SetPoint("BOTTOMLEFT", 6, 5)
            d:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 2 })
            d:SetBackdropColor(0.1, 0.11, 0.13, 1)
            d:SetBackdropBorderColor(m.debuff[1], m.debuff[2], m.debuff[3], 1)
        end
        f.pred, f.abs, f.m = pred, abs, m
        frames[i] = f
    end
    function state.Refresh()
        for _, f in ipairs(frames) do
            f.pred:SetShown(state.heal and f.m[4] > 0)
            f.abs:SetShown(state.absorb and f.m[5] > 0)
            f:SetAlpha(f.m.far and state.range / 100 or 1)
        end
    end
end

-------------------------------------------------------------------------------
-- Pantalla de bienvenida (encima del panel)
-------------------------------------------------------------------------------
local CLASSES = {
    { "PRIEST", "Sacerdote", "Interface\\Icons\\Spell_Holy_Renew", { "Renovar", "Palabra de poder: escudo", "Rezo de alivio", "Disipar magia" }, 6 },
    { "DRUID", "Druida", "Interface\\Icons\\Spell_Nature_Rejuvenation", { "Rejuvenecimiento", "Recrecimiento", "Crecimiento salvaje", "Quitar maldición" }, 7 },
    { "PALADIN", "Paladín", "Interface\\Icons\\Spell_Holy_HolyBolt", { "Bendiciones", "Juramento de luz", "Limpiar" }, 5 },
    { "SHAMAN", "Chamán", "Interface\\Icons\\Spell_Nature_MagicImmunity", { "Mareas vivas", "Escudo de agua", "Purificar" }, 5 },
}

local function BuildWelcome(parent)
    local w = Box(parent, 780, 560, C.win, C.line2, 0.99)
    w:SetPoint("CENTER")
    w:SetFrameLevel(parent:GetFrameLevel() + 50)
    w:EnableMouse(true)
    w:Hide()

    local logo = Icon(w, "Interface\\Icons\\Spell_Nature_Rejuvenation", 30)
    logo:SetPoint("TOPLEFT", 36, -30)
    local brand = Txt(w, "MendFrames", 18)
    brand:SetPoint("LEFT", logo, "RIGHT", 10, 0)

    local title = Txt(w, "Bienvenido a MendFrames", 26)
    title:SetPoint("TOPLEFT", 36, -86)
    local sub = Txt(w, "¿Con qué clase curas? Dejamos tus HoTs, escudos y lo que puedes disipar ya colocados en los marcos. Luego puedes cambiarlo todo.", 13, C.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    sub:SetWidth(600)

    local cards = {}
    local summary = Txt(w, "", 12.5, { 0.73, 0.75, 0.79 })
    local cta = Btn(w, "Empezar  >", 150, 40)
    local function Select(i)
        for k, card in ipairs(cards) do
            local cc = card.cc
            if k == i then
                card:SetBackdropColor(cc.r * 0.14, cc.g * 0.14, cc.b * 0.14, 1)
                card:SetBackdropBorderColor(cc.r, cc.g, cc.b, 1)
                card.icon:SetDesaturated(false)
                card:SetPoint("TOPLEFT", card.x, -170 + 4)
            else
                card:SetBackdropColor(C.card[1], C.card[2], C.card[3], 1)
                card:SetBackdropBorderColor(C.line[1], C.line[2], C.line[3], 1)
                card.icon:SetDesaturated(true)
                card:SetPoint("TOPLEFT", card.x, -170)
            end
        end
        local d = CLASSES[i]
        local cc = cards[i].cc
        summary:SetText(("Se crearán |cffffffff%d indicadores|r para %s y se abrirá el modo prueba para que lo veas al momento."):format(d[5], d[2]))
        cta:SetBackdropColor(cc.r, cc.g, cc.b, 1)
        local lum = 0.299 * cc.r + 0.587 * cc.g + 0.114 * cc.b
        if lum > 0.5 then cta.text:SetTextColor(0.08, 0.07, 0.05) else cta.text:SetTextColor(1, 1, 1) end
    end
    for i, d in ipairs(CLASSES) do
        local cc = RAID_CLASS_COLORS[d[1]] or { r = 1, g = 1, b = 1 }
        local card = CreateFrame("Button", nil, w, "BackdropTemplate")
        card:SetSize(168, 236)
        card.x = 36 + (i - 1) * 180
        card:SetPoint("TOPLEFT", card.x, -170)
        card:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
        card.cc = cc
        card.icon = Icon(card, d[3], 40)
        card.icon:SetPoint("TOPLEFT", 14, -16)
        local n = Txt(card, d[2], 15, { cc.r, cc.g, cc.b })
        n:SetPoint("TOPLEFT", card.icon, "BOTTOMLEFT", 0, -12)
        local yy = -100
        for _, sp in ipairs(d[4]) do
            local dot = Fill(card, { cc.r, cc.g, cc.b }, 1, "ARTWORK")
            dot:SetSize(5, 5)
            dot:SetPoint("TOPLEFT", 15, yy - 4)
            local t = Txt(card, sp, 11.5, { 0.73, 0.75, 0.79 })
            t:SetPoint("TOPLEFT", 26, yy)
            t:SetWidth(132)
            yy = yy - 20
        end
        card:SetScript("OnClick", function() Select(i) end)
        cards[i] = card
    end

    local note = Box(w, 708, 40, C.card, C.line)
    note:SetPoint("BOTTOMLEFT", 36, 86)
    summary:SetParent(note)
    summary:SetPoint("LEFT", 14, 0)
    summary:SetWidth(680)

    local later = CreateFrame("Button", nil, w)
    later:SetSize(190, 40)
    later:SetPoint("BOTTOMLEFT", 30, 30)
    local lt = Txt(later, "Prefiero configurarlo yo", 12.5, C.muted)
    lt:SetPoint("LEFT", 6, 0)
    later:SetScript("OnClick", function() w:Hide() end)
    cta:SetPoint("BOTTOMRIGHT", -36, 30)
    cta.text:SetFont(FONT, 13.5, "")
    cta:SetScript("OnClick", function() w:Hide() end)

    local _, mine = UnitClass("player")
    local start = 2
    for i, d in ipairs(CLASSES) do if d[1] == mine then start = i end end
    Select(start)
    return w
end

-------------------------------------------------------------------------------
-- Ventana
-------------------------------------------------------------------------------
local NAV = {
    { "Perfiles", "Interface\\Icons\\INV_Misc_Note_01" },
    { "Diseño", "Interface\\Icons\\INV_Misc_Map_01" },
    { "Barras", "Interface\\Icons\\Spell_Holy_FlashHeal" },
    { "Textos", "Interface\\Icons\\INV_Scroll_03" },
    { "Iconos de estado", "Interface\\Icons\\Spell_ChargePositive" },
    { "Indicadores", "Interface\\Icons\\Spell_Nature_Rejuvenation" },
    { "Catálogo", "Interface\\Icons\\INV_Misc_Book_11" },
    { "Debuffs de banda", "Interface\\Icons\\Spell_Shadow_AntiShadow" },
}

local function Build()
    ClassAccent()
    local W, H = 1120, 680
    local f = Box(UIParent, W, H, C.win, C.line2, 0.98)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    _G.MendFramesDemo = f
    table.insert(UISpecialFrames, "MendFramesDemo")
    -- que quepa en pantallas con poca altura
    local avail = UIParent:GetHeight() * 0.92
    if H > avail then f:SetScale(avail / H) end

    -- Barra de título
    local top = Fill(f, C.bar, 1, "BORDER")
    top:SetPoint("TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", -1, -1)
    top:SetHeight(56)
    local tl = HLine(f)
    tl:SetPoint("TOPLEFT", 1, -57)
    tl:SetPoint("TOPRIGHT", -1, -57)

    local logo = Icon(f, "Interface\\Icons\\Spell_Nature_Rejuvenation", 30)
    logo:SetPoint("TOPLEFT", 18, -13)
    local ring = Box(f, 34, 34, { 0, 0, 0 }, A, 0)
    ring:SetPoint("CENTER", logo)
    local title = Txt(f, "MendFrames", 19)
    title:SetPoint("LEFT", logo, "RIGHT", 12, 0)
    local ver = Box(f, 48, 18, C.win, C.line2)
    ver:SetPoint("LEFT", title, "RIGHT", 10, -1)
    local vt = Txt(ver, "v" .. (ns.version or "0.2.0"), 10.5, C.muted)
    vt:SetPoint("CENTER")

    local close = Btn(f, "X", 30, 30)
    close:SetPoint("TOPRIGHT", -14, -13)
    close:SetScript("OnClick", function() f:Hide() end)
    local lock = Btn(f, "Bloquear", 86, 30)
    lock:SetPoint("RIGHT", close, "LEFT", -8, 0)
    local test = Btn(f, "", 132, 30)
    test:SetPoint("RIGHT", lock, "LEFT", -8, 0)
    test.text:ClearAllPoints()
    test.text:SetPoint("RIGHT", -12, 0)
    test.text:SetText("Modo prueba")
    local tt = Toggle(test, true)
    tt:SetPoint("LEFT", 10, 0)
    test:SetScript("OnClick", function() tt:Click() end)
    local welcome
    local hello = Btn(f, "Ver bienvenida", 116, 30)
    hello:SetPoint("RIGHT", test, "LEFT", -8, 0)
    hello:SetScript("OnClick", function() welcome:Show() end)
    local prof = Box(f, 190, 30, C.raised, C.line)
    prof:SetPoint("RIGHT", hello, "LEFT", -14, 0)
    local p1 = Txt(prof, "Editando", 12, C.muted)
    p1:SetPoint("LEFT", 12, 0)
    local p2 = Txt(prof, "Banda 40", 12)
    p2:SetPoint("LEFT", p1, "RIGHT", 6, 0)
    local dot = Fill(prof, A, 1, "ARTWORK")
    dot:SetSize(6, 6)
    dot:SetPoint("LEFT", p2, "RIGHT", 8, 0)
    local p3 = Txt(prof, "activo", 12, C.muted)
    p3:SetPoint("LEFT", dot, "RIGHT", 6, 0)

    -- Barra lateral
    local side = Fill(f, C.bar, 1, "BORDER")
    side:SetPoint("TOPLEFT", 1, -58)
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(210)
    local sl = Fill(f, C.line, 1, "ARTWORK")
    sl:SetPoint("TOPLEFT", 211, -58)
    sl:SetPoint("BOTTOMLEFT", 211, 1)
    sl:SetWidth(1)

    local search = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    search:SetSize(186, 30)
    search:SetPoint("TOPLEFT", 13, -72)
    search:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    search:SetBackdropColor(C.win[1], C.win[2], C.win[3], 1)
    search:SetBackdropBorderColor(C.line2[1], C.line2[2], C.line2[3], 1)
    search:SetFont(FONT, 12, "")
    search:SetTextColor(C.text[1], C.text[2], C.text[3])
    search:SetTextInsets(10, 10, 0, 0)
    search:SetAutoFocus(false)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    local ph = Txt(search, "Buscar opción...", 12, C.dim)
    ph:SetPoint("LEFT", 10, 0)
    search:SetScript("OnTextChanged", function(self) ph:SetShown(self:GetText() == "") end)

    local navs = {}
    local pageTitle, pageSub, bars, other
    local SUBS = {
        "Un diseño para cada tamaño de grupo.",
        "Tamaño, orden y grupos que se muestran.",
        "Texturas, colores y lo que se resalta en cada marco.",
        "Nombre, vida y estado: fuente, tamaño y posición.",
        "Rol, marca de banda, líder y listos.",
        "Tus HoTs, escudos y debuffs, donde tú quieras.",
        "Hechizos de cada clase listos para añadir.",
        "Los debuffs importantes de cada instancia.",
    }
    local function SelectNav(i)
        for k, b in ipairs(navs) do
            local on = k == i
            b.bg:SetShown(on)
            b.mark:SetShown(on)
            b.icon:SetDesaturated(not on)
            b.icon:SetAlpha(on and 1 or 0.7)
            if on then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(0.73, 0.75, 0.79) end
        end
        pageTitle:SetText(NAV[i][1])
        pageSub:SetText(SUBS[i])
        bars:SetShown(i == 3)
        other:SetShown(i ~= 3)
    end
    for i, n in ipairs(NAV) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(186, 34)
        b:SetPoint("TOPLEFT", 13, -114 - (i - 1) * 37)
        b.bg = Fill(b, A, 0.13, "BACKGROUND")
        b.bg:SetAllPoints()
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(1, 1, 1, 0.04)
        b.mark = Fill(b, A, 1, "ARTWORK")
        b.mark:SetPoint("TOPLEFT", 0, -7)
        b.mark:SetPoint("BOTTOMLEFT", 0, 7)
        b.mark:SetWidth(3)
        b.icon = Icon(b, n[2], 20)
        b.icon:SetPoint("LEFT", 12, 0)
        b.text = Txt(b, n[1], 12.5)
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
        b:SetScript("OnClick", function() SelectNav(i) end)
        navs[i] = b
    end
    local hint = Txt(f, "Escribe |cffc9cdd6/mf|r para abrir", 11, C.dim)
    hint:SetPoint("BOTTOMLEFT", 23, 16)

    -- Contenido
    local CX, CW = 212, W - 212 - 300
    pageTitle = Txt(f, "", 19)
    pageTitle:SetPoint("TOPLEFT", CX + 24, -76)
    pageSub = Txt(f, "", 12, C.muted)
    pageSub:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -6)

    local state = { heal = true, absorb = true, range = 40 }
    local function R() if state.Refresh then state.Refresh() end end

    bars = CreateFrame("Frame", nil, f)
    bars:SetPoint("TOPLEFT", CX, -128)
    bars:SetSize(CW, H - 140)
    local colW = (CW - 48 - 14) / 2
    local x1, x2 = 24, 24 + colW + 14

    local s1 = Section(bars, x1, 0, colW, "Vida")
    s1:Row("Textura", nil, Dropdown(s1, "Lisa", 140))
    s1:Row("Llenado suave", "La barra se desliza en vez de saltar", Toggle(s1, true))
    s1:Stacked("Color de la barra", Segmented(s1, { "Clase", "Un color", "Degradado" }, 1))
    s1:Sub("Brillo", Slider(s1, 85))
    local y1 = s1:Finish()

    local s2 = Section(bars, x1, y1 - 22, colW, "Fondo (vida que falta)")
    s2:Stacked("Color del fondo", Segmented(s2, { "Clase", "Un color", "Degradado" }, 1))
    s2:Sub("Brillo", Slider(s2, 35))
    s2:Row("Opacidad", nil, Slider(s2, 80))
    s2:Finish()

    local s3 = Section(bars, x2, 0, colW, "Curación y escudos")
    s3:Row("Curación entrante", "Lo que van a curarle en camino",
        Toggle(s3, true, function(v) state.heal = v R() end))
    s3:Sub("Color", Swatch(s3, 0.25, 0.83, 0.48))
    s3:Row("Escudos (absorción)", nil, Toggle(s3, true, function(v) state.absorb = v R() end))
    s3:Sub("Color", Swatch(s3, 0.87, 0.91, 1))
    local y3 = s3:Finish()

    local s4 = Section(bars, x2, y3 - 22, colW, "Resaltados")
    s4:Row("Fuera de rango", nil, Slider(s4, 40, function(v) state.range = v R() end))
    s4:Row("Resaltar mi objetivo", nil, Toggle(s4, true))
    s4:Sub("Color", Swatch(s4, 1, 1, 1))
    s4:Row("Marcar quien tiene amenaza", nil, Toggle(s4, true))
    s4:Sub("Color", Swatch(s4, 1, 0.29, 0.24))
    s4:Finish()

    other = Box(f, CW - 48, 200, C.win, C.line2)
    other:SetPoint("TOPLEFT", CX + 24, -140)
    local ot = Txt(other, "En esta muestra solo está hecha la sección «Barras»; el resto seguiría el mismo estilo.", 12.5, C.muted)
    ot:SetPoint("CENTER", 0, 16)
    local ob = Btn(other, "Ver Barras", 110, 30, A)
    ob.text:SetTextColor(INK[1], INK[2], INK[3])
    ob:SetPoint("CENTER", 0, -22)
    ob:SetScript("OnClick", function() SelectNav(3) end)

    -- Vista previa
    local pv = CreateFrame("Frame", nil, f)
    pv:SetPoint("TOPRIGHT", -1, -58)
    pv:SetPoint("BOTTOMRIGHT", -1, 1)
    pv:SetWidth(298)
    local pbg = Fill(pv, C.bar, 1, "BACKGROUND")
    pbg:SetAllPoints()
    local pl = Fill(pv, C.line, 1, "ARTWORK")
    pl:SetPoint("TOPLEFT")
    pl:SetPoint("BOTTOMLEFT")
    pl:SetWidth(1)
    local pt = Txt(pv, "Vista previa en vivo", 13)
    pt:SetPoint("TOPLEFT", 18, -18)
    local ps = Txt(pv, "Cambia una opción y míralo aquí", 11, C.dim)
    ps:SetPoint("TOPLEFT", pt, "BOTTOMLEFT", 0, -4)
    local size = Segmented(pv, { "5", "10", "20", "40" }, 1)
    size:SetPoint("TOPRIGHT", -16, -16)
    BuildPreview(pv, state)

    local ly = -64 - 5 * 46 - 14
    local function Legend(text, col, a)
        local sq = Fill(pv, col, a or 1, "ARTWORK")
        sq:SetSize(14, 8)
        sq:SetPoint("TOPLEFT", 18, ly - 3)
        local t = Txt(pv, text, 11, C.muted)
        t:SetPoint("TOPLEFT", 40, ly)
        ly = ly - 18
    end
    Legend("Curación entrante", { 0.25, 0.83, 0.48 }, 0.6)
    Legend("Escudo", { 0.87, 0.91, 1 }, 0.5)
    Legend("Debuff que puedes disipar", { 0.24, 0.55, 1 })
    Legend("Tus HoTs", { 0.48, 0.86, 0.35 })

    local tip = Box(pv, 262, 54, C.raised, C.line)
    tip:SetPoint("BOTTOMLEFT", 18, 18)
    local tipt = Txt(tip, "El color de acento sigue la clase de tu personaje.", 11, C.muted)
    tipt:SetPoint("TOPLEFT", 12, -12)
    tipt:SetWidth(238)

    welcome = BuildWelcome(f)
    SelectNav(3)
    R()
    return f
end

function ns.ToggleDemo()
    if InCombatLockdown() then ns.Print("la muestra se abre fuera de combate.") return end
    if not demo then
        demo = Build()
        return
    end
    demo:SetShown(not demo:IsShown())
end
