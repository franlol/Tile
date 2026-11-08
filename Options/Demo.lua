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
local function Slider(parent, value, onChange, maxV, fmt)
    maxV = maxV or 100
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
    s:SetMinMaxValues(0, maxV)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    local val = Txt(f, "", 11.5, { 0.79, 0.80, 0.84 })
    val:SetPoint("RIGHT")
    val:SetJustifyH("RIGHT")
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        fill:SetWidth(math.max(1, 126 * v / maxV))
        val:SetText(fmt and fmt(v) or (v .. "%"))
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

local function Dropdown(parent, text, w, noStripe)
    local b = Btn(parent, "", w or 150, 26)
    local stripe = Fill(b, A, 1, "ARTWORK")
    stripe:SetSize(40, 8)
    stripe:SetPoint("LEFT", 9, 0)
    if noStripe then stripe:SetWidth(1) stripe:SetAlpha(0) end
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
    -- hueco libre para contenido propio (fichas, rejillas, listas)
    function s:Block(h)
        local b = CreateFrame("Frame", nil, self)
        b:SetPoint("TOPLEFT", 14, self.y - 6)
        b:SetSize(self:GetWidth() - 28, h)
        self.y = self.y - h - 12
        return b
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
-------------------------------------------------------------------------------
-- Más pantallas de muestra
-------------------------------------------------------------------------------
local function Chip(parent, icon, text)
    local c = Box(parent, 10, 24, C.raised, C.line2)
    local ic = Icon(c, icon, 16)
    ic:SetPoint("LEFT", 4, 0)
    local t = Txt(c, text, 11.5)
    t:SetPoint("LEFT", ic, "RIGHT", 6, 0)
    local x = Txt(c, "x", 11, C.dim)
    x:SetPoint("LEFT", t, "RIGHT", 8, 0)
    c:SetWidth(math.floor(t:GetStringWidth() + 46))
    return c
end

-- Fila de botones-ficha que se colocan seguidas y saltan de línea
local function Flow(block, items, w, gap)
    local x, y = 0, 0
    for _, it in ipairs(items) do
        local iw = it:GetWidth()
        if x > 0 and x + iw > w then x, y = 0, y - it:GetHeight() - gap end
        it:SetParent(block)
        it:ClearAllPoints()
        it:SetPoint("TOPLEFT", x, y)
        x = x + iw + gap
    end
end

local function BuildProfilesPage(pg, CW)
    local FW = CW - 48
    local s1 = Section(pg, 24, 0, FW, "Perfil que estás editando")
    local tiles = s1:Block(60)
    local names = {
        { "Banda 40", "En uso ahora", "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
        { "Grupo", "1-5 jugadores", "Interface\\Icons\\Ability_Warrior_BattleShout" },
        { "ZG / AQ20", "Hasta 20", "Interface\\Icons\\INV_Misc_Head_Troll_01" },
        { "Default", "Sin asignar", "Interface\\Icons\\INV_Misc_QuestionMark" },
    }
    local tw = math.floor((FW - 28 - 3 * 10) / 4)
    local all = {}
    local function Pick(i)
        for k, t in ipairs(all) do
            if k == i then
                t:SetBackdropColor(A[1] * 0.16, A[2] * 0.16, A[3] * 0.16, 1)
                t:SetBackdropBorderColor(A[1], A[2], A[3], 1)
            else
                t:SetBackdropColor(C.raised[1], C.raised[2], C.raised[3], 1)
                t:SetBackdropBorderColor(C.line2[1], C.line2[2], C.line2[3], 1)
            end
        end
    end
    for i, n in ipairs(names) do
        local t = CreateFrame("Button", nil, tiles, "BackdropTemplate")
        t:SetSize(tw, 56)
        t:SetPoint("TOPLEFT", (i - 1) * (tw + 10), 0)
        t:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
        local ic = Icon(t, n[3], 30)
        ic:SetPoint("LEFT", 10, 0)
        local a = Txt(t, n[1], 13)
        a:SetPoint("TOPLEFT", ic, "TOPRIGHT", 10, -1)
        local b = Txt(t, n[2], 11, C.dim)
        b:SetPoint("BOTTOMLEFT", ic, "BOTTOMRIGHT", 10, 1)
        t:SetScript("OnClick", function() Pick(i) end)
        all[i] = t
    end
    Pick(1)
    local acts = s1:Block(28)
    local b1 = Btn(acts, "Duplicar", 96, 26)
    b1:SetPoint("LEFT")
    local b2 = Btn(acts, "Renombrar", 96, 26)
    b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
    local b3 = Btn(acts, "Restablecer", 96, 26)
    b3:SetPoint("LEFT", b2, "RIGHT", 8, 0)
    local b4 = Btn(acts, "Borrar", 80, 26)
    b4:SetPoint("LEFT", b3, "RIGHT", 8, 0)
    b4.text:SetTextColor(1, 0.45, 0.35)
    local nb = Btn(acts, "+ Nuevo perfil", 120, 26, A)
    nb.text:SetTextColor(INK[1], INK[2], INK[3])
    nb:SetPoint("RIGHT")
    local y1 = s1:Finish()

    local s2 = Section(pg, 24, y1 - 22, FW, "Qué perfil usa este personaje según el grupo")
    local sizes = {
        { "5", "Grupo / solo", "Grupo" }, { "10", "Banda de hasta 10", "Default" },
        { "20", "Banda de hasta 20", "ZG / AQ20" }, { "40", "Banda de hasta 40", "Banda 40", true },
    }
    for _, sz in ipairs(sizes) do
        local blk = s2:Block(30)
        local badge = Box(blk, 34, 24, sz[4] and A or C.raised, sz[4] and A or C.line2)
        badge:SetPoint("LEFT")
        local bt = Txt(badge, sz[1], 12, sz[4] and INK or C.text)
        bt:SetPoint("CENTER")
        local l = Txt(blk, sz[2], 12.5)
        l:SetPoint("LEFT", badge, "RIGHT", 12, 0)
        if sz[4] then
            local now = Txt(blk, "tu grupo ahora", 11, A)
            now:SetPoint("LEFT", l, "RIGHT", 10, 0)
        end
        local dd = Dropdown(blk, sz[3], 170, true)
        dd:SetPoint("RIGHT", -86, 0)
        local ed = Btn(blk, "Editar", 76, 26)
        ed:SetPoint("RIGHT")
    end
    s2:Finish()
end

local function BuildLayoutPage(pg, CW)
    local colW = (CW - 48 - 14) / 2
    local x1, x2 = 24, 24 + colW + 14
    local px = function(v) return v .. " px" end
    local s1 = Section(pg, x1, 0, colW, "Tamaño de cada marco")
    s1:Row("Ancho", nil, Slider(s1, 72, nil, 200, px))
    s1:Row("Alto", nil, Slider(s1, 42, nil, 100, px))
    s1:Row("Escala", nil, Slider(s1, 100, nil, 200))
    s1:Row("Entre jugadores", nil, Slider(s1, 2, nil, 12, px))
    s1:Sub("Entre grupos", Slider(s1, 8, nil, 40, px))
    local y1 = s1:Finish()
    local s2 = Section(pg, x1, y1 - 22, colW, "Mascotas")
    s2:Row("Mostrar mascotas", nil, Toggle(s2, true))
    s2:Row("Pegadas a la banda", "Como un grupo más", Toggle(s2, false))
    s2:Row("Mismo tamaño que los jugadores", nil, Toggle(s2, true))
    s2:Finish()

    local s3 = Section(pg, x2, 0, colW, "Organización")
    s3:Stacked("Orientación", Segmented(s3, { "Columnas", "Filas" }, 1))
    s3:Stacked("Agrupar por", Segmented(s3, { "Grupo", "Rol", "Clase" }, 2))
    s3:Row("Ordenar por nombre", nil, Toggle(s3, false))
    s3:Row("Mostrarme a mí", nil, Toggle(s3, true))
    local y3 = s3:Finish()
    local s4 = Section(pg, x2, y3 - 22, colW, "Grupos que se muestran")
    local blk = s4:Block(62)
    local cw = math.floor((colW - 28 - 3 * 6) / 4)
    for i = 1, 8 do
        local on = i <= 5
        local b = CreateFrame("Button", nil, blk, "BackdropTemplate")
        b:SetSize(cw, 28)
        b:SetPoint("TOPLEFT", ((i - 1) % 4) * (cw + 6), -math.floor((i - 1) / 4) * 34)
        b:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
        b.t = Txt(b, "Grupo " .. i, 11.5)
        b.t:SetPoint("CENTER")
        local function Paint()
            if b.on then
                b:SetBackdropColor(A[1] * 0.2, A[2] * 0.2, A[3] * 0.2, 1)
                b:SetBackdropBorderColor(A[1], A[2], A[3], 1)
                b.t:SetTextColor(1, 1, 1)
            else
                b:SetBackdropColor(C.win[1], C.win[2], C.win[3], 1)
                b:SetBackdropBorderColor(C.line2[1], C.line2[2], C.line2[3], 1)
                b.t:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
            end
        end
        b.on = on
        Paint()
        b:SetScript("OnClick", function() b.on = not b.on Paint() end)
    end
    s4:Finish()
end

local function BuildIndicatorsPage(pg, CW)
    -- lista de indicadores a la izquierda
    local LW = 200
    local list = Box(pg, LW, 470, C.card, C.line)
    list:SetPoint("TOPLEFT", 24, 0)
    local lh = Txt(list, "TUS INDICADORES", 10.5, A)
    lh:SetPoint("TOPLEFT", 12, -12)
    local items = {
        { "Rejuvenecimiento", "Icono · arriba dcha.", "Interface\\Icons\\Spell_Nature_Rejuvenation" },
        { "Recrecimiento", "Cuadrado · arriba dcha.", "Interface\\Icons\\Spell_Nature_ResistNature" },
        { "Crecimiento salvaje", "Barra · abajo", "Interface\\Icons\\Spell_Nature_Regeneration" },
        { "Debuffs de banda", "Icono grande · centro", "Interface\\Icons\\Spell_Shadow_AntiShadow" },
        { "Disipar", "Borde de color", "Interface\\Icons\\Spell_Holy_DispelMagic" },
        { "Debuffs", "Varios iconos · abajo izq.", "Interface\\Icons\\Spell_Shadow_CurseOfSargeras" },
    }
    local rows = {}
    local function Pick(i)
        for k, r in ipairs(rows) do
            r.bg:SetShown(k == i)
            r.mark:SetShown(k == i)
        end
    end
    for i, it in ipairs(items) do
        local r = CreateFrame("Button", nil, list)
        r:SetSize(LW - 12, 42)
        r:SetPoint("TOPLEFT", 6, -32 - (i - 1) * 44)
        r.bg = Fill(r, A, 0.13, "BACKGROUND")
        r.bg:SetAllPoints()
        r.mark = Fill(r, A, 1, "ARTWORK")
        r.mark:SetPoint("TOPLEFT", 0, -8)
        r.mark:SetPoint("BOTTOMLEFT", 0, 8)
        r.mark:SetWidth(3)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.04)
        local ic = Icon(r, it[3], 26)
        ic:SetPoint("LEFT", 10, 0)
        local n = Txt(r, it[1], 12)
        n:SetPoint("TOPLEFT", ic, "TOPRIGHT", 9, 0)
        local d = Txt(r, it[2], 10.5, C.dim)
        d:SetPoint("BOTTOMLEFT", ic, "BOTTOMRIGHT", 9, 0)
        r:SetScript("OnClick", function() Pick(i) end)
        rows[i] = r
    end
    Pick(1)
    local add = Btn(list, "+ Añadir indicador", LW - 24, 30, A)
    add.text:SetTextColor(INK[1], INK[2], INK[3])
    add:SetPoint("BOTTOM", 0, 12)

    -- editor a la derecha
    local RX = 24 + LW + 14
    local RW = CW - RX - 24
    local s1 = Section(pg, RX, 0, RW, "Rejuvenecimiento · qué vigila")
    s1:Stacked("Tipo", Segmented(s1, { "Icono", "Cuadrado", "Barra", "Texto" }, 1))
    s1:Stacked("De quién", Segmented(s1, { "Solo mías", "De otros", "De cualquiera" }, 1))
    local spells = s1:Block(56)
    Flow(spells, {
        Chip(spells, "Interface\\Icons\\Spell_Nature_Rejuvenation", "Rejuvenecimiento"),
        Chip(spells, "Interface\\Icons\\Spell_Nature_ResistNature", "Recrecimiento"),
        Btn(spells, "+ Hechizo", 84, 24),
    }, RW - 28, 6)
    local y1 = s1:Finish()

    local s2 = Section(pg, RX, y1 - 22, RW, "Posición")
    local blk = s2:Block(96)
    -- rejilla de anclaje 3x3 y muestra del marco con el indicador
    local sample = CreateFrame("Frame", nil, blk, "BackdropTemplate")
    sample:SetSize(150, 58)
    sample:SetPoint("LEFT", 110, 0)
    sample:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    sample:SetBackdropColor(0.1, 0.06, 0.02, 1)
    sample:SetBackdropBorderColor(0, 0, 0, 1)
    local hp = Fill(sample, { 1, 0.49, 0.04 }, 0.85, "BORDER")
    hp:SetPoint("TOPLEFT", 1, -1)
    hp:SetPoint("BOTTOMLEFT", 1, 1)
    hp:SetWidth(104)
    local sn = Txt(sample, "Elowen", 12, { 1, 1, 1 })
    sn:SetShadowOffset(1, -1)
    sn:SetPoint("LEFT", 8, 0)
    local mark = Icon(sample, "Interface\\Icons\\Spell_Nature_Rejuvenation", 16)
    local cells = {}
    local POS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
    local function PickCell(i)
        for k, c in ipairs(cells) do
            if k == i then c.t:SetColorTexture(A[1], A[2], A[3], 1) else c.t:SetColorTexture(C.off[1], C.off[2], C.off[3], 1) end
        end
        local p = POS[i]
        local ox = p:find("LEFT") and 3 or (p:find("RIGHT") and -3 or 0)
        local oy = p:find("TOP") and -3 or (p:find("BOTTOM") and 3 or 0)
        mark:ClearAllPoints()
        mark:SetPoint(p, sample, p, ox, oy)
    end
    for i = 1, 9 do
        local c = CreateFrame("Button", nil, blk)
        c:SetSize(26, 26)
        c:SetPoint("TOPLEFT", ((i - 1) % 3) * 30, -6 - math.floor((i - 1) / 3) * 30)
        c.t = c:CreateTexture(nil, "ARTWORK")
        c.t:SetAllPoints()
        local hl = c:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.15)
        c:SetScript("OnClick", function() PickCell(i) end)
        cells[i] = c
    end
    PickCell(3)
    local px = function(v) return v .. " px" end
    s2:Row("Tamaño", nil, Slider(s2, 16, nil, 50, px))
    s2:Row("Desplazamiento", nil, Slider(s2, 2, nil, 40, px))
    s2:Finish()
end

local function BuildRaidPage(pg, CW)
    local FW = CW - 48
    local tabs = Segmented(pg, { "Núcleo de Magma", "Guarida Alanegra", "Zul'Gurub", "AQ40", "Naxxramas" }, 2)
    tabs:SetPoint("TOPLEFT", 24, 0)

    local s1 = Section(pg, 24, -40, FW, "Guarida Alanegra · por prioridad")
    local list = {
        { "Adrenalina ardiente", "Vaelastrasz", "Interface\\Icons\\Spell_Fire_Fire", true },
        { "Fuego de sombra", "Nefarian", "Interface\\Icons\\Spell_Shadow_ShadowBolt", true },
        { "Afligido: bronce", "Chromaggus", "Interface\\Icons\\Spell_Nature_Drowsy", false },
        { "Fuerza impía", "Chromaggus", "Interface\\Icons\\Spell_Shadow_UnholyStrength", false },
        { "Escarcha", "Chromaggus", "Interface\\Icons\\Spell_Frost_FrostShock", false },
    }
    for i, d in ipairs(list) do
        local blk = s1:Block(32)
        local n = Box(blk, 24, 24, i == 1 and A or C.raised, i == 1 and A or C.line2)
        n:SetPoint("LEFT")
        local nt = Txt(n, tostring(i), 11.5, i == 1 and INK or C.text)
        nt:SetPoint("CENTER")
        local ic = Icon(blk, d[3], 26)
        ic:SetPoint("LEFT", n, "RIGHT", 10, 0)
        local nm = Txt(blk, d[1], 12.5)
        nm:SetPoint("LEFT", ic, "RIGHT", 10, 0)
        local bo = Txt(blk, d[2], 11, C.dim)
        bo:SetPoint("LEFT", nm, "RIGHT", 10, 0)
        local grip = Txt(blk, "=", 14, C.dim)
        grip:SetPoint("RIGHT", -4, 0)
        local tg = Toggle(blk, d[4])
        tg:SetPoint("RIGHT", grip, "LEFT", -16, 0)
        local gl = Txt(blk, "Brillo", 11, C.muted)
        gl:SetPoint("RIGHT", tg, "LEFT", -8, 0)
    end
    local y1 = s1:Finish()

    local s2 = Section(pg, 24, y1 - 62, FW, "Vistos en esta instancia (no están en la lista)")
    local seen = {
        { "Veneno de la cría", "visto 14 veces", "Interface\\Icons\\Spell_Nature_CorrosiveBreath" },
        { "Llama gélida", "visto 6 veces", "Interface\\Icons\\Spell_Frost_FrostBolt02" },
    }
    for _, d in ipairs(seen) do
        local blk = s2:Block(30)
        local ic = Icon(blk, d[3], 24)
        ic:SetPoint("LEFT")
        local nm = Txt(blk, d[1], 12.5)
        nm:SetPoint("LEFT", ic, "RIGHT", 10, 0)
        local ct = Txt(blk, d[2], 11, C.dim)
        ct:SetPoint("LEFT", nm, "RIGHT", 10, 0)
        local add = Btn(blk, "+ Añadir", 84, 24)
        add:SetPoint("RIGHT")
    end
    s2:Finish()
end

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
    local pages = {}
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
        for k, pg in pairs(pages) do pg:SetShown(k == i) end
        other:SetShown(pages[i] == nil)
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
    local ot = Txt(other, "Esta sección no está en la muestra; seguiría el mismo estilo.", 12.5, C.muted)
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

    local function Page(build)
        local pg = CreateFrame("Frame", nil, f)
        pg:SetPoint("TOPLEFT", CX, -128)
        pg:SetSize(CW, H - 140)
        build(pg, CW)
        return pg
    end
    pages[1] = Page(BuildProfilesPage)
    pages[2] = Page(BuildLayoutPage)
    pages[3] = bars
    pages[6] = Page(BuildIndicatorsPage)
    pages[8] = Page(BuildRaidPage)

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
