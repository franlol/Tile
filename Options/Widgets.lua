-------------------------------------------------------------------------------
-- MendFrames - Controles propios para la ventana de opciones
-- (sin plantillas de Blizzard que cambian entre versiones)
-------------------------------------------------------------------------------

local _, ns = ...

local UI = {}
ns.UI = UI

local FLAT = "Interface\\Buttons\\WHITE8X8"
UI.ACCENT = { 0.31, 0.76, 0.97 }
local ACCENT = UI.ACCENT
UI.W = 230          -- ancho estándar de un control
UI.GAP = 10         -- separación entre controles
UI.SECTION_GAP = 10 -- separación extra antes de cada título de sección
UI.ATTACH_GAP = 2   -- separación de un control unido al anterior (su color, su brillo...)

-- Marca un control como parte del de arriba: va pegado a él
function UI.Attach(w)
    w.attached = true
    return w
end

UI.widgets = {}     -- controles con Refresh()
UI.stacks = {}      -- columnas que se recolocan al refrescar

-------------------------------------------------------------------------------
-- Enlace con la base de datos: Bind(raíz, "a.b.c", después)
-------------------------------------------------------------------------------
local function Resolve(root, path)
    local t = root
    local keys = {}
    for k in path:gmatch("[^%.]+") do keys[#keys + 1] = tonumber(k) or k end
    for i = 1, #keys - 1 do t = t[keys[i]] end
    return t, keys[#keys]
end

function UI.Bind(rootFn, path, after)
    return function()
        local t, k = Resolve(rootFn(), path)
        return t[k]
    end, function(v)
        local t, k = Resolve(rootFn(), path)
        t[k] = v
        if after then after(v) end
    end
end

-------------------------------------------------------------------------------
-- Básicos
-------------------------------------------------------------------------------
function UI.Backdrop(f, bg, border)
    f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    f:SetBackdropColor(unpack(bg or { 0.08, 0.08, 0.1, 0.95 }))
    f:SetBackdropBorderColor(unpack(border or { 0.25, 0.25, 0.3, 1 }))
end

function UI.Label(parent, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

function UI.Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w or 100, h or 20)
    UI.Backdrop(b, { 0.15, 0.15, 0.18, 1 })
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text or "")
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.25, 0.25, 0.3, 1) end)
    b:SetScript("OnClick", onClick)
    return b
end

function UI.EditBox(parent, w)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(w or 120, 20)
    UI.Backdrop(e, { 0.03, 0.03, 0.04, 1 })
    e:SetFontObject(ChatFontNormal)
    e:SetTextInsets(5, 5, 0, 0)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    return e
end

local function Register(w)
    table.insert(UI.widgets, w)
    return w
end

-- Título de sección (como control para poder apilarlo)
function UI.Header(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f.isHeader = true
    f:SetSize(UI.W, 22)
    f.text = UI.Label(f, text, "GameFontNormal")
    f.text:SetPoint("BOTTOMLEFT", 0, 3)
    f.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.3)
    f.line:SetPoint("BOTTOMLEFT")
    f.line:SetPoint("BOTTOMRIGHT")
    f.line:SetHeight(1)
    return f
end

-- Texto de ayuda apilable
function UI.Note(parent, text, w)
    local f = CreateFrame("Frame", nil, parent)
    f.text = UI.Label(f, text)
    f.text:SetPoint("TOPLEFT")
    f.text:SetWidth(w or UI.W)
    f.text:SetTextColor(0.65, 0.65, 0.65)
    f:SetSize(w or UI.W, f.text:GetStringHeight() + 2)
    return f
end

-------------------------------------------------------------------------------
-- Casilla
-------------------------------------------------------------------------------
function UI.Check(parent, text, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(UI.W, 18)
    local c = CreateFrame("Button", nil, f, "BackdropTemplate")
    c:SetSize(14, 14)
    c:SetPoint("LEFT")
    UI.Backdrop(c, { 0.05, 0.05, 0.06, 1 })
    c.mark = c:CreateTexture(nil, "OVERLAY")
    c.mark:SetPoint("TOPLEFT", 3, -3)
    c.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    c.mark:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    f.label = UI.Label(f, text)
    f.label:SetPoint("LEFT", c, "RIGHT", 6, 0)
    f.label:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    c:SetHitRectInsets(0, -(UI.W - 20), 0, 0)
    f.Refresh = function() c.mark:SetShown(get() and true or false) end
    c:SetScript("OnClick", function()
        set(not get())
        f.Refresh()
    end)
    return Register(f)
end

-------------------------------------------------------------------------------
-- Deslizador con botones < >
-------------------------------------------------------------------------------
function UI.Slider(parent, text, minV, maxV, step, fmt, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(UI.W, 34)
    f.label = UI.Label(f, text)
    f.label:SetPoint("TOPLEFT")
    f.value = UI.Label(f, "")
    f.value:SetPoint("TOPRIGHT")

    local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("TOPLEFT", 18, -16)
    s:SetPoint("TOPRIGHT", -18, -16)
    s:SetHeight(10)
    UI.Backdrop(s, { 0.05, 0.05, 0.06, 1 })
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    thumb:SetSize(8, 12)
    s:SetThumbTexture(thumb)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)

    local function Round(v)
        v = math.floor(v / step + 0.5) * step
        if step < 1 then v = tonumber(("%.2f"):format(v)) end
        return math.min(maxV, math.max(minV, v))
    end
    local function Show(v) f.value:SetText(fmt and fmt(v) or tostring(v)) end

    s:SetScript("OnValueChanged", function(_, v, user)
        v = Round(v)
        Show(v)
        if user and v ~= get() then set(v) end
    end)

    local function Nudge(d)
        local v = Round((get() or minV) + d * step)
        s:SetValue(v)
        set(v)
        Show(v)
    end
    local minus = UI.Button(f, "<", 14, 14, function() Nudge(-1) end)
    minus:SetPoint("RIGHT", s, "LEFT", -3, 0)
    local plus = UI.Button(f, ">", 14, 14, function() Nudge(1) end)
    plus:SetPoint("LEFT", s, "RIGHT", 3, 0)

    f.Refresh = function()
        local v = get() or minV
        s:SetValue(v)
        Show(v)
    end
    return Register(f)
end

-------------------------------------------------------------------------------
-- Desplegable (con scroll si hay muchas opciones)
-------------------------------------------------------------------------------
local openMenu
local MAX_ITEMS = 14

function UI.CloseMenu()
    if openMenu then openMenu:Hide() openMenu = nil end
end

function UI.Dropdown(parent, text, options, get, set, width)
    width = width or UI.W
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, text and 36 or 20)
    local yOff = 0
    if text then
        f.label = UI.Label(f, text)
        f.label:SetPoint("TOPLEFT")
        yOff = -14
    end
    local b = UI.Button(f, "", width, 18)
    b:SetPoint("TOPLEFT", 0, yOff)
    b:SetPoint("TOPRIGHT", 0, yOff)   -- sigue el ancho del marco
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", 6, 0)
    b.text:SetPoint("RIGHT", -16, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b.arrow = UI.Label(b, "v")
    b.arrow:SetPoint("RIGHT", -6, 0)
    f.button = b

    local function Opts() return type(options) == "function" and options() or options end

    -- Si la opción trae una fuente (3er campo), el texto se pinta con ella
    local function ApplyFont(fs, font)
        if font then
            ns.SetFont(fs, font, 12, "")
        else
            fs:SetFontObject(GameFontHighlightSmall)
        end
    end
    UI.ApplyOptionFont = ApplyFont

    f.Refresh = function()
        local cur = get()
        for _, o in ipairs(Opts()) do
            if o[1] == cur then
                ApplyFont(b.text, o[3])
                b.text:SetText(o[2])
                return
            end
        end
        ApplyFont(b.text, nil)
        b.text:SetText(cur ~= nil and tostring(cur):match("([^\\]+)$") or "")
    end

    b:SetScript("OnClick", function()
        if openMenu then
            local owner = openMenu.owner
            UI.CloseMenu()
            if owner == f then return end
        end
        local opts = Opts()
        local list = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        UI.Backdrop(list, { 0.06, 0.06, 0.08, 1 }, { ACCENT[1], ACCENT[2], ACCENT[3], 1 })
        list:SetFrameStrata("FULLSCREEN_DIALOG")
        list:SetClampedToScreen(true)
        list.owner = f
        local shown = math.min(#opts, MAX_ITEMS)
        list:SetSize(math.max(b:GetWidth(), 150), shown * 18 + 4)
        list:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -1)
        list:EnableMouse(true)
        local offset = 0
        local maxOffset = math.max(0, #opts - MAX_ITEMS)
        local scrollable = maxOffset > 0
        local items = {}
        local bar
        local function Fill()
            for i = 1, shown do
                local o = opts[i + offset]
                local item = items[i]
                item.value = o and o[1]
                ApplyFont(item.t, o and o[3])
                item.t:SetText(o and o[2] or "")
                item.sel:SetShown(o and o[1] == get() or false)
            end
        end
        local function ScrollTo(v)
            offset = math.max(0, math.min(maxOffset, math.floor(v + 0.5)))
            Fill()
            if bar and math.floor(bar:GetValue() + 0.5) ~= offset then bar:SetValue(offset) end
        end
        -- con barra de desplazamiento, las opciones dejan sitio a la derecha
        local itemW = list:GetWidth() - 4 - (scrollable and 12 or 0)
        for i = 1, shown do
            local item = CreateFrame("Button", nil, list)
            item:SetSize(itemW, 18)
            item:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 18)
            item.hl = item:CreateTexture(nil, "HIGHLIGHT")
            item.hl:SetAllPoints()
            item.hl:SetColorTexture(1, 1, 1, 0.1)
            item.sel = item:CreateTexture(nil, "BACKGROUND")
            item.sel:SetAllPoints()
            item.sel:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.2)
            item.t = UI.Label(item, "")
            item.t:SetPoint("LEFT", 4, 0)
            item.t:SetPoint("RIGHT", -4, 0)
            item.t:SetWordWrap(false)
            item:SetScript("OnClick", function(self)
                set(self.value)
                f.Refresh()
                UI.CloseMenu()
            end)
            items[i] = item
        end
        if scrollable then
            -- barra de desplazamiento arrastrable
            bar = CreateFrame("Slider", nil, list, "BackdropTemplate")
            bar:SetOrientation("VERTICAL")
            bar:SetPoint("TOPRIGHT", -3, -3)
            bar:SetPoint("BOTTOMRIGHT", -3, 3)
            bar:SetWidth(8)
            UI.Backdrop(bar, { 0.03, 0.03, 0.04, 1 }, { 0.2, 0.2, 0.25, 1 })
            local thumb = bar:CreateTexture(nil, "OVERLAY")
            thumb:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
            -- el tamaño del tirador refleja la parte visible de la lista
            thumb:SetSize(6, math.max(16, (list:GetHeight() - 6) * shown / #opts))
            bar:SetThumbTexture(thumb)
            bar:SetMinMaxValues(0, maxOffset)
            bar:SetValueStep(1)
            bar:SetObeyStepOnDrag(true)
            bar:SetValue(0)
            bar:SetScript("OnValueChanged", function(_, v) ScrollTo(v) end)
            list:EnableMouseWheel(true)
            list:SetScript("OnMouseWheel", function(_, d) ScrollTo(offset - d) end)
            -- al abrir, enseñar la opción seleccionada
            local cur = get()
            for k, o in ipairs(opts) do
                if o[1] == cur then ScrollTo(k - math.ceil(shown / 2)) break end
            end
        end
        Fill()
        openMenu = list
    end)
    f:SetScript("OnHide", function() if openMenu and openMenu.owner == f then UI.CloseMenu() end end)
    return Register(f)
end

-------------------------------------------------------------------------------
-- Muestra de color
-------------------------------------------------------------------------------
local function OpenColorPicker(c, hasAlpha, onChange)
    local prev = { r = c.r, g = c.g, b = c.b, a = c.a }
    local function Apply()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        c.r, c.g, c.b = r, g, b
        if hasAlpha then
            local a = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha())
                or (OpacitySliderFrame and 1 - OpacitySliderFrame:GetValue()) or 1
            c.a = a
        end
        onChange()
    end
    local function Cancel()
        c.r, c.g, c.b, c.a = prev.r, prev.g, prev.b, prev.a
        onChange()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b, opacity = c.a or 1, hasOpacity = hasAlpha,
            swatchFunc = Apply, opacityFunc = Apply, cancelFunc = Cancel,
        })
    else
        ColorPickerFrame.func = Apply
        ColorPickerFrame.opacityFunc = Apply
        ColorPickerFrame.cancelFunc = Cancel
        ColorPickerFrame.hasOpacity = hasAlpha
        ColorPickerFrame.opacity = 1 - (c.a or 1)
        ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-- getEdit (opcional): devuelve la tabla a modificar al hacer clic (si la de
-- getColor es solo de lectura, p. ej. valores por defecto)
function UI.Swatch(parent, text, getColor, onChange, hasAlpha, getEdit)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(UI.W, 18)
    local s = CreateFrame("Button", nil, f, "BackdropTemplate")
    s:SetSize(28, 14)
    s:SetPoint("LEFT")
    UI.Backdrop(s, { 1, 1, 1, 1 }, { 0.6, 0.6, 0.6, 1 })
    f.label = UI.Label(f, text)
    f.label:SetPoint("LEFT", s, "RIGHT", 6, 0)
    f.Refresh = function()
        local c = getColor()
        s:SetBackdropColor(c.r, c.g, c.b, 1)
    end
    s:SetScript("OnClick", function()
        OpenColorPicker((getEdit or getColor)(), hasAlpha, function()
            f.Refresh()
            onChange()
        end)
    end)
    return Register(f)
end

-------------------------------------------------------------------------------
-- Página con scroll vertical
-------------------------------------------------------------------------------
function UI.ScrollPage(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetAllPoints()
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(560, 10)
    sf:SetScrollChild(content)
    sf:EnableMouseWheel(true)
    local bar = sf:CreateTexture(nil, "OVERLAY")
    bar:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.5)
    bar:SetWidth(3)
    local function UpdateBar()
        local h, view = content:GetHeight(), sf:GetHeight()
        if h <= view + 1 then bar:Hide() return end
        local frac = view / h
        bar:SetHeight(math.max(20, view * frac))
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -1, -(sf:GetVerticalScroll() / h) * view)
        bar:Show()
    end
    sf:SetScript("OnMouseWheel", function(self, d)
        local max = math.max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 40)))
        UpdateBar()
    end)
    content.UpdateBar = UpdateBar
    sf.content = content
    return sf, content
end

-------------------------------------------------------------------------------
-- Columna: coloca uno debajo de otro solo los controles visibles
-- (cada control puede tener showIf = function() return bool end)
-------------------------------------------------------------------------------
-- Activar / desactivar un control sin quitarlo del sitio (sin saltos de diseño):
-- desactivado se ve en gris y una capa invisible se come los clics.
function UI.SetEnabled(w, on)
    w:SetAlpha(on and 1 or 0.35)
    if not w.blocker then
        if on then return end
        w.blocker = CreateFrame("Frame", nil, w)
        w.blocker:SetAllPoints()
        w.blocker:EnableMouse(true)
    end
    w.blocker:SetFrameLevel(w:GetFrameLevel() + 20)
    w.blocker:SetShown(not on)
end

-- showIf: el control se quita (para opciones de otro tipo de indicador)
-- enableIf: el control se queda en su sitio y se desactiva (sub-opciones)
-- fill: los controles se estiran al ancho del contenido (ventana redimensionable)
function UI.Stack(content, x, y, list, gap, fill)
    local st = { content = content, x = x, y = y, list = list, gap = gap or UI.GAP, fill = fill }
    function st:Layout()
        local yy = self.y
        local first = true
        for _, w in ipairs(self.list) do
            local visible = not w.showIf or w.showIf()
            w:SetShown(visible)
            if visible and w.enableIf then UI.SetEnabled(w, w.enableIf() and true or false) end
            if visible then
                -- hueco extra antes de cada título de sección (salvo el primero)
                if w.isHeader and not first then yy = yy - UI.SECTION_GAP end
                -- unido al anterior: casi sin hueco
                if w.attached and not first then yy = yy + self.gap - UI.ATTACH_GAP end
                first = false
                w:ClearAllPoints()
                w:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x, yy)
                if self.fill and not w.fixedWidth then
                    w:SetWidth(math.max(UI.W, self.content:GetWidth() - self.x - 16))
                    if w.OnWidth then w.OnWidth(w:GetWidth()) end
                end
                yy = yy - w:GetHeight() - self.gap
            end
        end
        self.bottom = yy
        return yy
    end
    table.insert(UI.stacks, st)
    st:Layout()
    return st
end

-- Ajusta la altura del contenido de una página al control más bajo
function UI.FitContent(content, stacks, extra)
    local low = 0
    for _, st in ipairs(stacks) do low = math.min(low, st.bottom or 0) end
    content:SetHeight(-low + (extra or 20))
    if content.UpdateBar then content.UpdateBar() end
end

function UI.RefreshAll()
    for _, w in ipairs(UI.widgets) do
        if w.Refresh then w.Refresh(w) end
    end
    for _, st in ipairs(UI.stacks) do st:Layout() end
    if UI.OnRefresh then UI.OnRefresh() end
end

-------------------------------------------------------------------------------
-- Tooltip de hechizo solo al pasar por encima de un icono.
-- getID() devuelve el ID a enseñar; extra(tooltip) añade líneas (opcional).
-- El clic atraviesa el icono (sigue llegando a la fila o botón de debajo).
-------------------------------------------------------------------------------
function UI.IconTip(parent, tex, getID, extra)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(tex)
    f:SetFrameLevel(parent:GetFrameLevel() + 2)
    if f.SetMouseMotionEnabled and f.SetMouseClickEnabled then
        f:SetMouseMotionEnabled(true)
        f:SetMouseClickEnabled(false)
    else
        f:EnableMouse(true)
    end
    f:SetScript("OnEnter", function(self)
        local id = getID()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok = id and pcall(GameTooltip.SetSpellByID, GameTooltip, id)
        if extra then extra(GameTooltip, ok) ok = true end
        if ok then GameTooltip:Show() else GameTooltip:Hide() end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return f
end

-------------------------------------------------------------------------------
-- Listas de opciones comunes
-------------------------------------------------------------------------------
UI.POINTS = {
    { "TOPLEFT", "Arriba izquierda" }, { "TOP", "Arriba" }, { "TOPRIGHT", "Arriba derecha" },
    { "LEFT", "Izquierda" }, { "CENTER", "Centro" }, { "RIGHT", "Derecha" },
    { "BOTTOMLEFT", "Abajo izquierda" }, { "BOTTOM", "Abajo" }, { "BOTTOMRIGHT", "Abajo derecha" },
}

UI.pct = function(v) return ("%d%%"):format(v * 100 + 0.5) end
