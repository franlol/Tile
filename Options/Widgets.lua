-------------------------------------------------------------------------------
-- Tile - Custom controls for the options window
-- (no Blizzard templates, which change between versions)
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI

local FLAT = "Interface\\Buttons\\WHITE8X8"
UI.ACCENT = ns.ACCENT -- brand color (Core.lua)
local ACCENT = UI.ACCENT
UI.W = 230          -- standard width of a control
UI.GAP = 10         -- spacing between controls
UI.SECTION_GAP = 10 -- extra spacing before each section title
UI.ATTACH_GAP = 2   -- spacing of a control attached to the previous one (its color, its brightness...)

-- Marks a control as part of the one above: it sits right below it
function UI.Attach(w)
    w.attached = true
    return w
end

-- Button that asks for a second click to confirm (delete, reset...).
-- The first click changes the text to "Sure?"; if not confirmed within 3 s, it goes back.
function UI.Confirm(b, armedText)
    local orig = b:GetScript("OnClick")
    local token, saved = 0, nil
    local function Disarm()
        if not b.armed then return end
        b.armed = nil
        b.text:SetText(saved or "")
        b.text:SetTextColor(1, 1, 1)
    end
    b.Disarm = Disarm
    b:SetScript("OnClick", function(self, ...)
        if self.armed then
            Disarm()
            if orig then orig(self, ...) end
            return
        end
        saved = self.text:GetText()
        self.armed = true
        self.text:SetText(armedText or L["Sure?"])
        self.text:SetTextColor(1, 0.45, 0.35)
        token = token + 1
        local mine = token
        C_Timer.After(3, function() if token == mine then Disarm() end end)
    end)
    b:HookScript("OnHide", Disarm)
    return b
end

UI.widgets = {}     -- controls with Refresh()
UI.stacks = {}      -- columns that are relaid out on refresh

-------------------------------------------------------------------------------
-- Binding to the database: Bind(root, "a.b.c", after)
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
-- Basics
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

-- Section title (as a control so it can be stacked)
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

-- Stackable help text
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
-- Checkbox
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
-- Slider with < > buttons
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
-- Scroll bar in the addon's style: it can be dragged, and the mouse wheel
-- over its list or page moves it. Used by pages, lists and dropdowns.
-- onScroll(v) receives the position (0..max) when it moves.
-------------------------------------------------------------------------------
function UI.ScrollBar(parent, onScroll)
    local bar = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(8)
    UI.Backdrop(bar, { 0.03, 0.03, 0.04, 1 }, { 0.2, 0.2, 0.25, 1 })
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
    thumb:SetSize(6, 16)
    bar:SetThumbTexture(thumb)
    bar.thumb = thumb
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetValue(0)
    bar.cur = 0
    bar:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v + 0.5)
        if v == self.cur then return end
        self.cur = v
        onScroll(v)
    end)
    -- max: how far it can scroll; frac: visible part (0..1)
    function bar:SetRange(max, frac)
        max = math.max(0, math.floor((max or 0) + 0.5))
        self:SetMinMaxValues(0, max)
        self.thumb:SetHeight(math.max(16, (self:GetHeight() - 2) * math.min(1, frac or 1)))
        self:SetShown(max > 0)
    end
    -- place it without notifying (when the position changes elsewhere)
    function bar:SetPos(v)
        self.cur = math.floor((v or 0) + 0.5)
        self:SetValue(self.cur)
    end
    return bar
end

-------------------------------------------------------------------------------
-- Dropdown (with scroll when there are many options)
-------------------------------------------------------------------------------
local openMenu
local MAX_ITEMS = 14

function UI.CloseMenu()
    if openMenu then openMenu:Hide() openMenu = nil end
end

-- Click outside the open dropdown: it closes (native game event)
local outside = CreateFrame("Frame")
pcall(outside.RegisterEvent, outside, "GLOBAL_MOUSE_DOWN")
outside:SetScript("OnEvent", function()
    local m = openMenu
    if not m then return end
    -- clicks on the list or on its own button (which already opens and closes it) are ignored
    if m:IsMouseOver() or (m.owner and m.owner.button and m.owner.button:IsMouseOver()) then return end
    UI.CloseMenu()
end)

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
    b:SetPoint("TOPRIGHT", 0, yOff)   -- follows the frame width
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", 6, 0)
    b.text:SetPoint("RIGHT", -16, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b.arrow = UI.Label(b, "v")
    b.arrow:SetPoint("RIGHT", -6, 0)
    f.button = b

    local function Opts() return type(options) == "function" and options() or options end

    -- If the option has a font (3rd field), the text is drawn with it
    local function ApplyFont(fs, font)
        if font then
            ns.SetFont(fs, font, 12, "")
        else
            fs:SetFontObject(GameFontHighlightSmall)
        end
    end
    UI.ApplyOptionFont = ApplyFont

    -- If the option has a texture (4th field), it is shown as a sample behind it
    local function ApplyTex(frame, tex)
        if not frame.preview then
            if not tex then return end
            frame.preview = frame:CreateTexture(nil, "BORDER")
            frame.preview:SetPoint("TOPLEFT", 1, -1)
            frame.preview:SetPoint("BOTTOMRIGHT", -1, 1)
            frame.preview:SetVertexColor(0.45, 0.6, 0.75, 1)
        end
        if tex then frame.preview:SetTexture(tex) end
        frame.preview:SetShown(tex ~= nil)
    end

    f.Refresh = function()
        local cur = get()
        for _, o in ipairs(Opts()) do
            if o[1] == cur then
                ApplyFont(b.text, o[3])
                ApplyTex(b, o[4])
                b.text:SetText(o[2])
                return
            end
        end
        ApplyFont(b.text, nil)
        ApplyTex(b, nil)
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
                ApplyTex(item, o and o[4])
                item.t:SetText(o and o[2] or "")
                item.sel:SetShown(o and o[1] == get() or false)
            end
        end
        local function ScrollTo(v)
            offset = math.max(0, math.min(maxOffset, math.floor(v + 0.5)))
            Fill()
            if bar then bar:SetPos(offset) end
        end
        -- with a scroll bar, the options leave room on the right
        local itemW = list:GetWidth() - 4 - (scrollable and 12 or 0)
        for i = 1, shown do
            local item = CreateFrame("Button", nil, list)
            item:SetSize(itemW, 18)
            item:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 18)
            item.hl = item:CreateTexture(nil, "HIGHLIGHT")
            item.hl:SetAllPoints()
            item.hl:SetColorTexture(1, 1, 1, 0.1)
            item.sel = item:CreateTexture(nil, "ARTWORK")
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
            -- draggable scroll bar
            bar = UI.ScrollBar(list, ScrollTo)
            bar:SetPoint("TOPRIGHT", -3, -3)
            bar:SetPoint("BOTTOMRIGHT", -3, 3)
            bar:SetRange(maxOffset, shown / #opts)
            list:EnableMouseWheel(true)
            list:SetScript("OnMouseWheel", function(_, d) ScrollTo(offset - d) end)
            -- on open, show the selected option
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
-- Color swatch
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

-- getEdit (optional): returns the table to change on click (when the one from
-- getColor is read only, e.g. default values)
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
-- Page with vertical scroll
-------------------------------------------------------------------------------
function UI.ScrollPage(parent)
    -- The game's ScrollFrame with our bar on the right
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetPoint("TOPLEFT")
    sf:SetPoint("BOTTOMRIGHT", -12, 0)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(560, 10)
    sf:SetScrollChild(content)
    sf:EnableMouseWheel(true)
    local bar = UI.ScrollBar(parent, function(v) sf:SetVerticalScroll(v) end)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -2)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -2, 2)
    local function UpdateBar()
        local h, view = content:GetHeight(), sf:GetHeight()
        local max = math.max(0, h - view)
        if sf:GetVerticalScroll() > max then sf:SetVerticalScroll(max) end
        bar:SetRange(max, h > 0 and view / h or 1)
        bar:SetPos(sf:GetVerticalScroll())
    end
    sf:SetScript("OnMouseWheel", function(self, d)
        local max = math.max(0, content:GetHeight() - self:GetHeight())
        local v = math.min(max, math.max(0, self:GetVerticalScroll() - d * 40))
        self:SetVerticalScroll(v)
        bar:SetPos(v)
    end)
    sf:SetScript("OnSizeChanged", UpdateBar)
    content.UpdateBar = UpdateBar
    sf.content = content
    return sf, content
end

-------------------------------------------------------------------------------
-- Column: places only the visible controls one below the other
-- (each control can have showIf = function() return bool end)
-------------------------------------------------------------------------------
-- Enable / disable a control without removing it (no layout jumps):
-- disabled it looks grey and an invisible layer swallows the clicks.
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

-- showIf: the control is removed (for options of another indicator type)
-- enableIf: the control stays in place and is disabled (sub-options)
-- fill: the controls stretch to the content width (resizable window)
-- Each title opens a card (box with a background) that wraps its controls
-- up to the next title; every card of a column has the same width.
UI.CARD_PAD = 10

local function Card(header, content)
    local card = header.card
    if not card then
        card = CreateFrame("Frame", nil, content, "BackdropTemplate")
        UI.Backdrop(card, { 0.095, 0.095, 0.118, 1 }, { 0.19, 0.19, 0.235, 1 })
        header.card = card
    end
    -- below the controls (which are one level above the content)
    card:SetFrameLevel(content:GetFrameLevel())
    return card
end

function UI.Stack(content, x, y, list, gap, fill)
    local st = { content = content, x = x, y = y, list = list, gap = gap or UI.GAP, fill = fill }
    function st:Layout()
        local PAD = UI.CARD_PAD
        local yy = self.y
        local first = true
        local afterHeader = false
        local card, cardTop

        -- card width: the widest control of the column
        local maxW = UI.W
        if not self.fill then
            for _, w in ipairs(self.list) do
                if not w.isHeader and (not w.showIf or w.showIf()) then maxW = math.max(maxW, w:GetWidth()) end
            end
        end
        local function CloseCard()
            if not card then return end
            local bottom = yy + self.gap -- bottom edge of the last control
            card:SetHeight(cardTop - bottom + PAD)
            yy = bottom - PAD - self.gap
            card = nil
        end

        for _, w in ipairs(self.list) do
            local visible = not w.showIf or w.showIf()
            w:SetShown(visible)
            if w.card then w.card:SetShown(visible) end
            if visible and w.enableIf then UI.SetEnabled(w, w.enableIf() and true or false) end
            if visible then
                if w.isHeader then
                    CloseCard()
                    -- extra gap between cards (except before the first one)
                    if not first then yy = yy - UI.SECTION_GAP end
                    card = Card(w, self.content)
                    cardTop = yy
                    card:ClearAllPoints()
                    card:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x, yy)
                    yy = yy - 4
                end
                -- attached to the previous one: almost no gap (never attached to a title:
                -- if the control it depends on is hidden, it goes like a normal one)
                if w.attached and not first and not afterHeader then yy = yy + self.gap - UI.ATTACH_GAP end
                first = false
                afterHeader = w.isHeader and true or false
                local inset = card and PAD or 0
                w:ClearAllPoints()
                w:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x + inset, yy)
                if self.fill and not w.fixedWidth then
                    w:SetWidth(math.max(UI.W, self.content:GetWidth() - self.x - 16 - 2 * inset))
                    if w.OnWidth then w.OnWidth(w:GetWidth()) end
                elseif w.isHeader then
                    w:SetWidth(maxW) -- the title line crosses the whole card
                end
                if card and w.isHeader then
                    card:SetWidth((self.fill and w:GetWidth() or maxW) + 2 * PAD)
                end
                yy = yy - w:GetHeight() - self.gap
            end
        end
        CloseCard()
        self.bottom = yy
        return yy
    end
    table.insert(UI.stacks, st)
    st:Layout()
    return st
end

-- Fits the height of a page's content to the lowest control
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
-- Spell tooltip only when hovering an icon.
-- getID() returns the ID to show; extra(tooltip) adds lines (optional).
-- The click goes through the icon (it still reaches the row or button below).
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
-- Common option lists
-------------------------------------------------------------------------------
function UI.PointList()
    return {
        { "TOPLEFT", L["Top left"] }, { "TOP", L["Top"] }, { "TOPRIGHT", L["Top right"] },
        { "LEFT", L["Left"] }, { "CENTER", L["Center"] }, { "RIGHT", L["Right"] },
        { "BOTTOMLEFT", L["Bottom left"] }, { "BOTTOM", L["Bottom"] }, { "BOTTOMRIGHT", L["Bottom right"] },
    }
end

UI.pct = function(v) return ("%d%%"):format(v * 100 + 0.5) end
