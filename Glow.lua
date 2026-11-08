-------------------------------------------------------------------------------
-- MendFrames - Brillos y resaltados
-- pixel: líneas que recorren el borde · autocast: chispas que giran
-- button: brillo de botón de acción de Blizzard · proc: brillo de "proc" de Blizzard
-- Si una plantilla de Blizzard no existe en este cliente, se usa "pixel".
-------------------------------------------------------------------------------

local _, ns = ...

local Glow = {}
ns.Glow = Glow

local FLAT = "Interface\\Buttons\\WHITE8X8"
local SPARKLE = "Interface\\Artifacts\\Artifacts"
local SPARKLE_COORDS = { 0.8115234375, 0.9169921875, 0.8798828125, 0.9853515625 }

local function Holder(target, pad)
    local g = CreateFrame("Frame", nil, target)
    g:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad)
    g:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad)
    g:SetFrameLevel(target:GetFrameLevel() + 8)
    return g
end

-- posición (x, y) y si es tramo horizontal, para un punto p del perímetro
local function Perimeter(p, w, h)
    if p < w then return p, 0, true end
    p = p - w
    if p < h then return w, -p, false end
    p = p - h
    if p < w then return w - p, -h, true end
    p = p - w
    return 0, -(h - p), false
end

-------------------------------------------------------------------------------
-- Píxel
-------------------------------------------------------------------------------
local function PixelUpdate(g, elapsed)
    g.t = (g.t + elapsed * g.freq) % 1
    local w, h = g:GetSize()
    if w <= 0 or h <= 0 then return end
    local per = 2 * (w + h)
    local len = math.max(2, per / g.n * 0.45)
    for i, line in ipairs(g.lines) do
        local p = (((i - 1) / g.n + g.t) % 1) * per
        local x, y, horiz = Perimeter(p, w, h)
        line:ClearAllPoints()
        if horiz then
            local edgeLeft = (y == 0) and (w - x) or x
            local l = math.min(len, math.max(1, edgeLeft))
            line:SetSize(l, g.th)
            if y == 0 then
                line:SetPoint("TOPLEFT", g, "TOPLEFT", x, 0)
            else
                line:SetPoint("BOTTOMRIGHT", g, "TOPLEFT", x, y)
            end
        else
            local edgeLeft = (x == w) and (h + y) or -y
            local l = math.min(len, math.max(1, edgeLeft))
            line:SetSize(g.th, l)
            if x == w then
                line:SetPoint("TOPRIGHT", g, "TOPLEFT", x, y)
            else
                line:SetPoint("BOTTOMLEFT", g, "TOPLEFT", 0, y)
            end
        end
    end
end

local function StartPixel(target, c, opts)
    local g = Holder(target, 2)
    g.n = opts.lines or 8
    g.th = opts.thickness or 2
    g.freq = opts.freq or 0.25
    g.t = 0
    g.lines = {}
    for i = 1, g.n do
        local l = g:CreateTexture(nil, "OVERLAY")
        l:SetTexture(FLAT)
        l:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        g.lines[i] = l
    end
    g:SetScript("OnUpdate", PixelUpdate)
    return g
end

-------------------------------------------------------------------------------
-- Chispas (autocast)
-------------------------------------------------------------------------------
local function SparkUpdate(g, elapsed)
    g.t = (g.t + elapsed * g.freq) % 1
    local w, h = g:GetSize()
    if w <= 0 or h <= 0 then return end
    local per = 2 * (w + h)
    local n = g.groups
    for i, s in ipairs(g.sparks) do
        local group = (i - 1) % n
        local sub = math.floor((i - 1) / n)
        local speed = 1 + sub * 0.15
        local p = ((group / n + g.t * speed + sub * 0.02) % 1) * per
        local x, y = Perimeter(p, w, h)
        s:ClearAllPoints()
        s:SetPoint("CENTER", g, "TOPLEFT", x, y)
    end
end

local function StartAutocast(target, c, opts)
    local g = Holder(target, 1)
    g.freq = opts.freq or 0.25
    g.t = 0
    g.sparks = {}
    g.groups = math.max(1, opts.particles or 4)
    local sizes = { 7, 6, 5 }
    local sc = opts.glowScale or 1
    for i = 1, g.groups * 3 do
        local s = g:CreateTexture(nil, "OVERLAY")
        s:SetTexture(SPARKLE)
        s:SetTexCoord(unpack(SPARKLE_COORDS))
        if not s:GetTexture() then s:SetTexture(FLAT) end
        s:SetBlendMode("ADD")
        s:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        local sz = sizes[math.floor((i - 1) / g.groups) + 1] * sc
        s:SetSize(sz, sz)
        g.sparks[i] = s
    end
    g:SetScript("OnUpdate", SparkUpdate)
    return g
end

-------------------------------------------------------------------------------
-- Comunes a los efectos con gráficos de Blizzard
-------------------------------------------------------------------------------
local function Speed(opts) return (opts.freq or 0.25) * 4 end   -- 0.25 -> 1x

-- Color: el elegido, o el original de Blizzard si keepColor
local function Color(t, c, opts)
    if opts and opts.keepColor then
        t:SetDesaturated(false)
        t:SetVertexColor(1, 1, 1, c.a or 1)
    else
        t:SetDesaturated(true)
        t:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    end
end

-- Textura con animación de fotogramas (atlas de Blizzard); nil si no existe
local function FlipTex(g, atlas, rows, cols, frames)
    local tex = g:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas(atlas)
    if not tex:GetAtlas() then tex:Hide() return nil end
    tex:SetBlendMode("ADD")
    local ag = tex:CreateAnimationGroup()
    local fb = ag:CreateAnimation("FlipBook")
    fb:SetFlipBookRows(rows)
    fb:SetFlipBookColumns(cols)
    fb:SetFlipBookFrames(frames)
    fb:SetFlipBookFrameWidth(0)
    fb:SetFlipBookFrameHeight(0)
    return tex, ag, fb
end

-------------------------------------------------------------------------------
-- Botón de acción (estallido + bucle) y Proc (solo bucle), como las barras de
-- acción modernas. Hechos a mano para que respondan a color, tamaño y velocidad.
-------------------------------------------------------------------------------
local function StartProcGlow(target, c, opts, withStart)
    local g = Holder(target, 0)
    g.ags = {}
    local w, h = target:GetSize()
    local sc, sp = opts.glowScale or 1, Speed(opts)
    local ok = pcall(function()
        local loop, lag, lfb = FlipTex(g, "UI-HUD-ActionBar-Proc-Loop-Flipbook", 6, 5, 30)
        if not loop then error("sin atlas") end
        loop:SetPoint("CENTER", target, "CENTER")
        loop:SetSize(w * 1.4 * sc, h * 1.4 * sc)
        Color(loop, c, opts)
        lag:SetLooping("REPEAT")
        lfb:SetDuration(1 / sp)
        g.ags[1] = lag
        if withStart then
            local st, sag, sfb = FlipTex(g, "UI-HUD-ActionBar-Proc-Start-Flipbook", 6, 5, 30)
            if st then
                st:SetPoint("CENTER", target, "CENTER")
                st:SetSize(w * 3.4 * sc, h * 3.4 * sc)
                Color(st, c, opts)
                sfb:SetDuration(0.7 / sp)
                loop:SetAlpha(0)
                sag:SetScript("OnFinished", function()
                    st:Hide()
                    loop:SetAlpha(1)
                    lag:Play()
                end)
                g.ags[2] = sag
                sag:Play()
                return
            end
        end
        lag:Play()
    end)
    if ok then return g end
    g:Hide()
end

local function StartButton(target, c, opts) return StartProcGlow(target, c, opts, true) end
local function StartProc(target, c, opts) return StartProcGlow(target, c, opts, false) end

-------------------------------------------------------------------------------
-- Efectos con texturas de Blizzard (sin plantillas: solo archivos de textura
-- que existen desde siempre en el cliente). Cada uno devuelve nil si este
-- cliente no tiene la textura, para pasar al siguiente de la cadena.
-------------------------------------------------------------------------------
local ICON_ALERT = "Interface\\SpellActivationOverlay\\IconAlert"
local ICON_ANTS = "Interface\\SpellActivationOverlay\\IconAlertAnts"
local GLOW_COORDS = { 0.00781250, 0.50781250, 0.27734375, 0.52734375 }

-- Crea una textura; nil si el archivo no existe en este cliente
local function Tex(g, path, layer, blend)
    local t = g:CreateTexture(nil, layer or "OVERLAY")
    local ok = t:SetTexture(path)
    if ok == false or not t:GetTexture() then
        t:Hide()
        return nil
    end
    t:SetBlendMode(blend or "ADD")
    return t
end


-- Holder con una lista de pasos de animación
local function AnimHolder(target, pad)
    local g = Holder(target, pad or 0)
    g.steps = {}
    g.t = 0
    g:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        for _, f in ipairs(self.steps) do f(self, elapsed) end
    end)
    return g
end

local function SizeAround(t, target, mult)
    local w, h = target:GetSize()
    t:ClearAllPoints()
    t:SetPoint("CENTER", target, "CENTER")
    t:SetSize(w * mult, h * mult)
end

-- latido de alfa entre lo y hi
local function PulseStep(t, lo, hi, speed)
    return function(g)
        local s = (math.sin(g.t * math.pi * 2 * speed) + 1) / 2
        t:SetAlpha(lo + (hi - lo) * s)
    end
end

-- hormigas: flipbook 5x5 (22 fotogramas de 48 px en una textura de 256)
local function AntsStep(t, speed)
    local frame, acc = 0, 0
    local size = 48 / 256
    return function(_, elapsed)
        acc = acc + elapsed * speed
        if acc < 0.025 then return end
        acc = 0
        frame = (frame + 1) % 22
        local col, row = frame % 5, math.floor(frame / 5)
        t:SetTexCoord(col * size, (col + 1) * size, row * size, (row + 1) * size)
    end
end

local function StartClassic(target, c, opts, antsOnly)
    local g = AnimHolder(target)
    local sc = opts.glowScale or 1
    if not antsOnly then
        local glow = Tex(g, ICON_ALERT)
        if not glow then g:Hide() return end
        glow:SetTexCoord(unpack(GLOW_COORDS))
        SizeAround(glow, target, 1.45 * sc)
        Color(glow, c, opts)
        table.insert(g.steps, PulseStep(glow, 0.55, 1, 0.8 * Speed(opts)))
    end
    local ants = Tex(g, ICON_ANTS)
    if ants then
        SizeAround(ants, target, 1.25 * sc)
        Color(ants, c, opts)
        table.insert(g.steps, AntsStep(ants, Speed(opts)))
    elseif antsOnly then
        g:Hide()
        return
    end
    return g
end

local function StartSimple(path, mult, coords, pulse)
    return function(target, c, opts)
        local g = AnimHolder(target)
        local t = Tex(g, path)
        if not t then g:Hide() return end
        if coords then t:SetTexCoord(unpack(coords)) end
        SizeAround(t, target, mult * (opts.glowScale or 1))
        Color(t, c, opts)
        if pulse then table.insert(g.steps, PulseStep(t, 0.35, 1, 0.8 * Speed(opts))) end
        return g
    end
end

local function StartPing(target, c, opts)
    local g = AnimHolder(target)
    local t = Tex(g, "Interface\\Cooldown\\ping4")
    if not t then g:Hide() return end
    Color(t, c, opts)
    local w, h = target:GetSize()
    local sc = opts.glowScale or 1
    t:SetPoint("CENTER", target, "CENTER")
    table.insert(g.steps, function(self)
        local p = (self.t * 0.9 * Speed(opts)) % 1
        local m = (0.8 + p * 1.2) * sc
        t:SetSize(w * m, h * m)
        t:SetAlpha(1 - p)
    end)
    return g
end

local function StartStar(target, c, opts)
    local g = AnimHolder(target)
    local t = Tex(g, "Interface\\Cooldown\\star4")
    if not t then g:Hide() return end
    SizeAround(t, target, 1.9 * (opts.glowScale or 1))
    Color(t, c, opts)
    table.insert(g.steps, function(self)
        t:SetRotation(self.t * 1.5 * Speed(opts))
    end)
    table.insert(g.steps, PulseStep(t, 0.5, 1, 0.6 * Speed(opts)))
    return g
end

local function StartSpark(target, c, opts)
    local g = AnimHolder(target, 1)
    local sparks = {}
    for i = 1, 2 do
        local s = Tex(g, "Interface\\CastingBar\\UI-CastingBar-Spark")
        if not s then g:Hide() return end
        Color(s, c, opts)
        sparks[i] = s
    end
    table.insert(g.steps, function(self)
        local w, h = self:GetSize()
        if w <= 0 then return end
        local per = 2 * (w + h)
        for i, s in ipairs(sparks) do
            local p = ((self.t * 0.4 * Speed(opts) + (i - 1) / 2) % 1) * per
            local x, y, horiz = Perimeter(p, w, h)
            local sz = 10 * (opts.glowScale or 1)
            s:SetSize(sz * 1.6, sz * 1.6)
            s:SetRotation(horiz and 0 or math.pi / 2)
            s:ClearAllPoints()
            s:SetPoint("CENTER", self, "TOPLEFT", x, y)
        end
    end)
    return g
end

-------------------------------------------------------------------------------
-- Tipos, cadena de respaldo y API
-------------------------------------------------------------------------------
Glow.TYPES = {
    { "none", "Ninguno" },
    { "button", "Botón de acción (Blizzard)" },
    { "proc", "Proc (Blizzard, moderno)" },
    { "classic", "Brillo de botón clásico + hormigas" },
    { "ants", "Hormigas (borde animado)" },
    { "border", "Borde de botón (amarillo)" },
    { "hilight", "Resaltado de botón" },
    { "autocastable", "Borde de autolanzamiento" },
    { "ping", "Onda (ping)" },
    { "star", "Estrella giratoria" },
    { "spark", "Chispa de lanzamiento" },
    { "autocast", "Chispas" },
    { "pixel", "Píxel (líneas en el borde)" },
}
Glow.NAMES = {}
for _, t in ipairs(Glow.TYPES) do Glow.NAMES[t[1]] = t[2] end

local STARTERS = {
    button = function(t, c, o) return StartButton(t, c, o) end,
    proc = function(t, c, o) return StartProc(t, c, o) end,
    classic = function(t, c, o) return StartClassic(t, c, o) end,
    ants = function(t, c, o) return StartClassic(t, c, o, true) end,
    border = StartSimple("Interface\\Buttons\\UI-ActionButton-Border", 1.75, nil, true),
    hilight = StartSimple("Interface\\Buttons\\CheckButtonHilight", 1.1, nil, true),
    autocastable = StartSimple("Interface\\Buttons\\UI-AutoCastableOverlay", 1.7, { 0.14, 0.86, 0.14, 0.86 }, true),
    ping = StartPing,
    star = StartStar,
    spark = StartSpark,
    autocast = function(t, c, o) return StartAutocast(t, c, o) end,
    pixel = function(t, c, o) return StartPixel(t, c, o) end,
}

-- si un efecto no existe en este cliente, se prueba el siguiente
local CHAIN = {
    button = { "button", "classic", "border", "pixel" },
    proc = { "proc", "button", "classic", "pixel" },
    classic = { "classic", "border", "pixel" },
    ants = { "ants", "classic", "pixel" },
    autocast = { "autocast", "spark", "pixel" },
}

Glow.used = {}   -- [tipo pedido] = tipo que se ha podido usar

-- key: dueño del brillo (varios indicadores pueden brillar sobre el mismo marco)
function Glow.Start(target, gtype, color, opts, key)
    key = key or "default"
    Glow.Stop(target, key)
    if not gtype or gtype == "none" then return end
    opts = opts or {}
    color = color or { r = 1, g = 0.85, b = 0.1, a = 1 }

    -- marco intermedio: aplica el desplazamiento X/Y (y el margen del píxel)
    -- a cualquier efecto sin tocar cada uno
    local ox, oy = opts.offsetX or 0, opts.offsetY or 0
    local w, h = target:GetSize()
    local pad = 0
    if gtype == "pixel" then pad = math.max(0, ((opts.glowScale or 1) - 1) * math.min(w, h) / 2) end
    local proxy = CreateFrame("Frame", nil, target)
    proxy:SetPoint("TOPLEFT", target, "TOPLEFT", ox - pad, oy + pad)
    proxy:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", ox + pad, oy - pad)
    proxy:SetSize(w + pad * 2, h + pad * 2)
    proxy:SetFrameLevel(target:GetFrameLevel())

    local g, used
    for _, t in ipairs(CHAIN[gtype] or { gtype, "pixel" }) do
        local f = STARTERS[t]
        if f then
            local ok, res = pcall(f, proxy, color, opts)
            if ok and res then g, used = res, t break end
        end
    end
    if g then g.proxy = proxy else proxy:Hide() end
    Glow.used[gtype] = used
    target.mfGlows = target.mfGlows or {}
    target.mfGlows[key] = g
    return used
end

-- /mf brillos: qué efectos funcionan en este cliente
function Glow.Diagnose()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(30, 30)
    f:SetPoint("CENTER")
    f:SetAlpha(0)
    local ok, bad = {}, {}
    for _, t in ipairs(Glow.TYPES) do
        if t[1] ~= "none" then
            local used = Glow.Start(f, t[1], nil, {})
            Glow.Stop(f)
            if used == t[1] then ok[#ok + 1] = t[2]
            else bad[#bad + 1] = ("%s -> %s"):format(t[2], used and Glow.NAMES[used] or "nada") end
        end
    end
    f:Hide()
    ns.Print("|cff55ff55funcionan:|r " .. table.concat(ok, ", "))
    if #bad > 0 then
        ns.Print("|cffff7755no disponibles (se usa otro):|r " .. table.concat(bad, "; "))
    end
end

function Glow.Stop(target, key)
    key = key or "default"
    local g = target and target.mfGlows and target.mfGlows[key]
    if not g then return end
    g:SetScript("OnUpdate", nil)
    if g.ag then g.ag:Stop() end
    if g.ags then for _, ag in ipairs(g.ags) do ag:Stop() end end
    if g.ProcLoop then pcall(g.ProcLoop.Stop, g.ProcLoop) end
    if g.animIn then pcall(g.animIn.Stop, g.animIn) end
    g:Hide()
    if g.proxy then g.proxy:Hide() end
    target.mfGlows[key] = nil
end

-------------------------------------------------------------------------------
-- Resaltado (ns.STYLE_DEFAULTS está en Defaults.lua)
-------------------------------------------------------------------------------

ns.SOUNDS = {
    { "none", "Ninguno" },
    { "RAID_WARNING", "Aviso de banda" },
    { "READY_CHECK", "Comprobación de listos" },
    { "ALARM_CLOCK_WARNING_3", "Alarma" },
    { "UI_RAID_BOSS_WHISPER_WARNING", "Susurro de jefe" },
    { "IG_PLAYER_INVITE", "Campanilla" },
    { "PVP_THROUGH_QUEUE", "Cola de JcJ" },
}

local lastSound = 0
function ns.PlayAlert(name, force)
    if not name or name == "none" then return end
    local now = GetTime()
    if not force and now - lastSound < 1.5 then return end
    lastSound = now
    local id = SOUNDKIT and SOUNDKIT[name]
    if id then pcall(PlaySound, id, "Master") end
end

ns.styleVersion = 0

local function Pulse(w, on)
    if on then
        if not w.mfPulse then
            local ag = w:CreateAnimationGroup()
            ag:SetLooping("BOUNCE")
            local a = ag:CreateAnimation("Alpha")
            a:SetFromAlpha(1)
            a:SetToAlpha(0.35)
            a:SetDuration(0.45)
            w.mfPulse = ag
        end
        w.mfPulse:Play()
    elseif w.mfPulse then
        w.mfPulse:Stop()
        w:SetAlpha(1)
    end
end

-- Borde y tinte del marco propios de cada elemento (pueden coexistir varios)
local function FrameDecor(b, w)
    if w.hlBorder then
        w.hlBorder:SetParent(b)
        w.hlBorder:ClearAllPoints()
        w.hlBorder:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
        w.hlBorder:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
        w.hlTint:SetAllPoints(b.health)
        return
    end
    w.hlBorder = CreateFrame("Frame", nil, b, "BackdropTemplate")
    w.hlBorder:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
    w.hlBorder:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
    w.hlBorder:SetBackdrop({ edgeFile = FLAT, edgeSize = 2 })
    w.hlBorder:SetFrameLevel(b.overlay:GetFrameLevel() + 4)
    w.hlBorder:Hide()
    w.hlTint = b.overlay:CreateTexture(nil, "ARTWORK")
    w.hlTint:SetAllPoints(b.health)
    w.hlTint:SetTexture(FLAT)
    w.hlTint:Hide()
end

-- ¿El estilo hace algo?
function ns.StyleActive(s)
    return s and (s.glow ~= "none" or s.border or s.tint or s.pulse or (s.scale or 1) ~= 1 or s.sound ~= "none") or false
end

-- Quita el resaltado de un elemento (icono, cuadrado, barra...)
function ns.ClearHighlight(w)
    if not w or not w.hlStyle then return end
    if w.hlGlowTarget then Glow.Stop(w.hlGlowTarget, w) w.hlGlowTarget = nil end
    Pulse(w, false)
    w:SetScale(1)
    if w.hlBorder then w.hlBorder:Hide() w.hlTint:Hide() end
    w.hlStyle, w.hlVer = nil, nil
end

-- Aplica un estilo a un elemento visible del botón b.
-- ident identifica el aura mostrada (para el sonido: una vez por aura).
function ns.ApplyHighlight(b, w, style, ident, unit)
    if not ns.StyleActive(style) then
        ns.ClearHighlight(w)
        w.hlSoundIdent = nil
        return
    end
    -- sonido al aparecer
    if style.sound ~= "none" and ident ~= nil and w.hlSoundIdent ~= ident then
        w.hlSoundIdent = ident
        if unit and (not style.soundOnlyMe or ns.R(UnitIsUnit(unit, "player"))) then
            ns.PlayAlert(style.sound)
        end
    end
    if w.hlStyle == style and w.hlVer == ns.styleVersion and w.hlOwner == b then return end
    ns.ClearHighlight(w)
    w.hlStyle, w.hlVer, w.hlOwner = style, ns.styleVersion, b

    if (style.scale or 1) ~= 1 then w:SetScale(style.scale) end
    if style.glow ~= "none" then
        local target = style.target == "frame" and b or w
        Glow.Start(target, style.glow, style.color, style, w)
        w.hlGlowTarget = target
    end
    if style.pulse then Pulse(w, true) end
    if style.border or style.tint then
        FrameDecor(b, w)
        if style.border then
            local c = style.borderColor
            w.hlBorder:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 1)
            w.hlBorder:Show()
        end
        if style.tint then
            local c = style.tintColor
            w.hlTint:SetVertexColor(c.r, c.g, c.b, c.a or 0.35)
            w.hlTint:Show()
        end
    end
end
