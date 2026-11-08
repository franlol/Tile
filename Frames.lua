-------------------------------------------------------------------------------
-- MendFrames - Marcos (cabeceras seguras, botones, actualizaciones, modo prueba)
-------------------------------------------------------------------------------

local _, ns = ...
local S, R, AnyS = ns.S, ns.R, ns.AnyS

local FLAT = "Interface\\Buttons\\WHITE8X8"

ns.buttons = {}
local testButtons = {}

local UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED",
    "UNIT_AURA", "UNIT_CONNECTION", "UNIT_NAME_UPDATE", "UNIT_FLAGS",
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_THREAT_SITUATION_UPDATE",
}

local function V(v)
    if S(v) then return v end
    return v or 0
end

-------------------------------------------------------------------------------
-- Llenado suave de barras: SOLO la animación nativa del cliente
-- (StatusBar:SetValue(valor, interpolación)). Si el cliente no la tiene, la
-- opción no está disponible y las barras cambian al momento.
-------------------------------------------------------------------------------
local NATIVE_SMOOTH = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
ns.hasNativeSmooth = NATIVE_SMOOTH ~= nil

-- diagnóstico (/mf suave): cuenta las veces que se fija la barra vigilada
local diag

local function SetBarValue(bar, v, smooth)
    if diag and bar == diag.bar then
        diag.calls = diag.calls + 1
        if smooth then diag.smooth = diag.smooth + 1 end
        local ev = diag.event or "otro"
        diag.byEvent[ev] = (diag.byEvent[ev] or 0) + 1
    end
    if smooth and NATIVE_SMOOTH then
        bar:SetValue(v, NATIVE_SMOOTH)
    else
        bar:SetValue(v)
    end
end
ns.SetBarValue = SetBarValue

-- /mf suave: prueba la animación nativa en tu propio marco y cuenta durante 5 s
-- cuántas veces se fija tu barra de vida y por qué
function ns.DiagnoseSmooth()
    local pb
    for _, b in ipairs(ns.buttons) do
        if b.unit and R(UnitIsUnit(b.unit, "player")) then pb = b break end
    end
    ns.Print(("animación nativa en este cliente: %s | opción vida: %s | opción maná: %s"):format(
        NATIVE_SMOOTH and "sí" or "NO", tostring(ns.P.bars.smooth), tostring(ns.P.bars.powerSmooth)))
    if not pb then
        ns.Print("no encuentro tu marco: activa 'Mostrar estando solo' o entra en un grupo.")
        return
    end
    if NATIVE_SMOOTH then
        -- 1) vaciar al momento y volver a llenar con la animación nativa
        local _, max = pb.health:GetMinMaxValues()
        if not S(max) then
            pb.health:SetValue(0)
            C_Timer.After(0.4, function()
                pb.health:SetValue(max, NATIVE_SMOOTH)
                ns.Print("prueba 1: ¿se ha rellenado tu barra de vida con animación?")
            end)
        end
    end
    -- 2) contar durante 5 segundos
    diag = { bar = pb.health, calls = 0, smooth = 0, byEvent = {} }
    C_Timer.After(5, function()
        local parts = {}
        for ev, n in pairs(diag.byEvent) do parts[#parts + 1] = ev .. "=" .. n end
        ns.Print(("prueba 2: barra de vida fijada %d veces en 5 s (%d con animación). Por evento: %s"):format(
            diag.calls, diag.smooth, #parts > 0 and table.concat(parts, ", ") or "ninguno"))
        diag = nil
    end)
end

-- el evento que está en curso, para el recuento del diagnóstico
function ns.DiagEvent(ev) if diag then diag.event = ev end end

-------------------------------------------------------------------------------
-- Tamaño de las mascotas: el de los jugadores o el suyo propio
function ns.PetSize()
    local P = ns.P
    if P.pets.sameSize then return P.layout.width, P.layout.height end
    return P.pets.width, P.pets.height
end

-- Visual de un botón (reales y de prueba)
-------------------------------------------------------------------------------
local function NewBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(FLAT)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

function ns.BuildVisuals(b)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0, 0, 0, 1)

    b.health = NewBar(b)
    b.health.bg = b.health:CreateTexture(nil, "BACKGROUND")
    b.health.bg:SetAllPoints()
    if b.health.SetClipsChildren then b.health:SetClipsChildren(true) end

    b.pred = NewBar(b.health)
    b.pred:SetPoint("TOPLEFT", b.health:GetStatusBarTexture(), "TOPRIGHT")
    b.pred:SetPoint("BOTTOMLEFT", b.health:GetStatusBarTexture(), "BOTTOMRIGHT")

    b.absorb = NewBar(b.health)
    b.absorb:SetPoint("TOPLEFT", b.pred:GetStatusBarTexture(), "TOPRIGHT")
    b.absorb:SetPoint("BOTTOMLEFT", b.pred:GetStatusBarTexture(), "BOTTOMRIGHT")

    b.power = NewBar(b)
    b.power.bg = b.power:CreateTexture(nil, "BACKGROUND")
    b.power.bg:SetAllPoints()
    b.power.bg:SetColorTexture(0, 0, 0, 0.8)

    local overlay = CreateFrame("Frame", nil, b)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(b.health:GetFrameLevel() + 5)
    b.overlay = overlay

    b.name = overlay:CreateFontString(nil, "OVERLAY")
    b.name:SetWordWrap(false)
    b.status = overlay:CreateFontString(nil, "OVERLAY")
    b.hpText = overlay:CreateFontString(nil, "OVERLAY")

    b.role = overlay:CreateTexture(nil, "OVERLAY")
    b.leader = overlay:CreateTexture(nil, "OVERLAY")
    b.raidIcon = overlay:CreateTexture(nil, "OVERLAY")
    b.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    b.ready = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
    b.ready:Hide()

    b.hl = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.hl:SetAllPoints()
    b.hl:SetBackdrop({ edgeFile = FLAT, edgeSize = 1 })
    b.hl:SetFrameLevel(overlay:GetFrameLevel() + 2)
    b.hl:SetAlpha(0)

    b.aggro = overlay:CreateTexture(nil, "OVERLAY")
    b.aggro:SetPoint("TOPLEFT", 1, -1)
    b.aggro:SetPoint("TOPRIGHT", -1, -1)
    b.aggro:SetHeight(2)
    b.aggro:Hide()

    b.ind, b.pool = {}, {}
end

local function PlaceText(fs, t, b)
    ns.SetFont(fs, t.font, t.size, t.outline)
    fs:ClearAllPoints()
    fs:SetPoint(t.point, b, t.point, t.x, t.y)
    local j = t.point:find("LEFT") and "LEFT" or (t.point:find("RIGHT") and "RIGHT" or "CENTER")
    fs:SetJustifyH(j)
    fs:SetShown(t.show)
end

local function PlaceElement(tex, e, b)
    tex:ClearAllPoints()
    tex:SetPoint(e.point, b, e.point, e.x, e.y)
    tex:SetSize(e.size, e.size)
end

-- Ajusta la barra de vida según haya o no barra de maná
local function AnchorHealth(b, powerShown)
    local P = ns.P
    local powerH = powerShown and P.bars.powerHeight or 0
    b.health:ClearAllPoints()
    b.health:SetPoint("TOPLEFT", 1, -1)
    b.health:SetPoint("BOTTOMRIGHT", -1, 1 + (powerH > 0 and powerH + 1 or 0))
    b.power:SetShown(powerH > 0)
    b.powerShown = powerShown
end

function ns.LayoutButton(b, isPet)
    local P = ns.P
    local L, B, T, E = P.layout, P.bars, P.texts, P.elements
    local w = isPet and (ns.PetSize()) or L.width

    b.isPet = isPet
    b.bg:SetColorTexture(B.borderColor.r, B.borderColor.g, B.borderColor.b, B.borderColor.a or 1)
    b.health:SetStatusBarTexture(B.healthTex)
    b.health.bg:SetTexture(B.bgTex)
    b.pred:SetStatusBarTexture(B.healthTex)
    b.absorb:SetStatusBarTexture(B.healthTex)
    b.power:SetStatusBarTexture(B.powerTex)
    local pc, ac = B.healPredColor, B.absorbColor
    b.pred:SetStatusBarColor(pc.r, pc.g, pc.b, pc.a)
    b.absorb:SetStatusBarColor(ac.r, ac.g, ac.b, ac.a)
    b.pred:SetWidth(w - 2)
    b.absorb:SetWidth(w - 2)

    AnchorHealth(b, B.showPower and not isPet)
    b.power:ClearAllPoints()
    b.power:SetPoint("BOTTOMLEFT", 1, 1)
    b.power:SetPoint("BOTTOMRIGHT", -1, 1)
    b.power:SetHeight(B.powerHeight)

    PlaceText(b.name, T.name, b)
    b.name:SetWidth(math.max(10, w * T.name.width / 100))
    if isPet then
        b.name:ClearAllPoints()
        b.name:SetPoint("CENTER")
    end
    PlaceText(b.status, T.status, b)
    PlaceText(b.hpText, T.health, b)

    PlaceElement(b.role, E.role, b)
    PlaceElement(b.leader, E.leader, b)
    PlaceElement(b.raidIcon, E.raidIcon, b)
    PlaceElement(b.ready, E.ready, b)

    local tc, gc = B.targetColor, B.aggroColor
    b.hl:SetBackdropBorderColor(tc.r, tc.g, tc.b, tc.a)
    b.aggro:SetColorTexture(gc.r, gc.g, gc.b, gc.a)

    ns.BuildIndicators(b)
end

-------------------------------------------------------------------------------
-- Actualizaciones
-------------------------------------------------------------------------------
local function UnitColor(unit, isPet, testClass)
    if isPet then return 0.25, 0.75, 0.3 end
    local class = testClass
    if not class then
        local _, c = UnitClass(unit)
        class = R(c)
    end
    local c = class and (RAID_CLASS_COLORS or {})[class]
    if c then return c.r, c.g, c.b end
    return 0.5, 0.5, 0.5
end

local function TextColor(fs, t, r, g, bl)
    if t.colorMode == "class" then fs:SetTextColor(r, g, bl)
    elseif t.colorMode == "custom" then fs:SetTextColor(t.color.r, t.color.g, t.color.b)
    else fs:SetTextColor(1, 1, 1) end
end

-- Degradado rojo -> amarillo -> verde según el porcentaje de vida (0..1)
local function Gradient(pct)
    pct = math.max(0, math.min(1, pct))
    if pct < 0.5 then return 1, pct * 2, 0 end
    return 2 - pct * 2, 1, 0
end

-- Porcentaje de vida legible, o nil si el juego lo oculta
local function HealthPct(b, testPct)
    if testPct then return testPct end
    if not b.unit then return nil end
    local cur, max = UnitHealth(b.unit), UnitHealthMax(b.unit)
    if AnyS(cur, max) or not max or max <= 0 then return nil end
    return cur / max
end

-- Color de la barra de vida y de su fondo (la vida que falta)
-- Color para un modo (class | custom | gradient). El brillo solo oscurece el
-- color de clase y el degradado; un color elegido a mano se ve tal cual.
-- Si el juego oculta la vida, el degradado usa el color de clase.
local function ModeColor(mode, custom, brightness, cr, cg, cb, pct)
    if mode == "custom" then return custom.r, custom.g, custom.b end
    local r, g, bl = cr, cg, cb
    if mode == "gradient" and pct then r, g, bl = Gradient(pct) end
    local k = brightness or 1
    return r * k, g * k, bl * k
end

-- Color de la barra de vida y de su fondo (la vida que falta): mismas opciones
function ns.UpdateBarColor(b, testClass, testPct)
    local B = ns.P.bars
    local cr, cg, cb = UnitColor(b.unit, b.isPet, testClass)
    local pct
    if B.healthColor == "gradient" or B.bgColor == "gradient" then pct = HealthPct(b, testPct) end
    b.health:SetStatusBarColor(ModeColor(B.healthColor, B.customColor, B.healthBrightness, cr, cg, cb, pct))
    local r, g, bl = ModeColor(B.bgColor, B.bgCustom, B.bgBrightness, cr, cg, cb, pct)
    b.health.bg:SetVertexColor(r, g, bl, B.bgAlpha)
end

function ns.UpdateColors(b, testClass, testPct)
    local T = ns.P.texts
    local r, g, bl = UnitColor(b.unit, b.isPet, testClass)
    ns.UpdateBarColor(b, testClass, testPct)
    TextColor(b.name, T.name, r, g, bl)
    TextColor(b.status, T.status, r, g, bl)
    TextColor(b.hpText, T.health, r, g, bl)
end

local function Abbrev(n)
    if n >= 1000000 then return ("%.1fm"):format(n / 1000000) end
    if n >= 10000 then return ("%dk"):format(n / 1000) end
    if n >= 1000 then return ("%.1fk"):format(n / 1000) end
    return tostring(n)
end

local function HealthText(b, u, cur, max)
    local t = ns.P.texts.health
    local fs = b.hpText
    if not t.show or t.format == "none" then fs:SetText("") return end
    if not AnyS(cur, max) then
        if not max or max <= 0 or (t.hideFull and cur >= max) then fs:SetText("") return end
        if t.format == "deficit" then fs:SetText("-" .. Abbrev(max - cur))
        elseif t.format == "percent" then fs:SetText(("%d%%"):format(cur / max * 100))
        elseif t.format == "current" then fs:SetText(Abbrev(cur))
        else fs:SetText(Abbrev(cur) .. "/" .. Abbrev(max)) end
        return
    end
    -- valores secretos: lo que el cliente permita, si no, nada
    local ok = pcall(function()
        if t.format == "percent" and UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
            fs:SetFormattedText("%d%%", UnitHealthPercent(u, false, CurveConstants.ScaleTo100))
        elseif t.format == "deficit" and UnitHealthMissing and AbbreviateNumbers then
            fs:SetText(AbbreviateNumbers(UnitHealthMissing(u)))
        elseif AbbreviateNumbers then
            fs:SetText(AbbreviateNumbers(cur))
        else
            error("sin soporte")
        end
    end)
    if not ok then fs:SetText("") end
end

-- Curación entrante y escudos. Van aparte de la vida: así sus cambios no
-- vuelven a fijar la barra de vida (y no cortan su animación).
function ns.UpdatePrediction(b, max)
    local u = b.unit
    local B = ns.P.bars
    max = max or UnitHealthMax(u)
    if B.showHealPred and UnitGetIncomingHeals then
        b.pred:SetMinMaxValues(0, V(max))
        b.pred:SetValue(V(UnitGetIncomingHeals(u)))
        b.pred:Show()
    else
        b.pred:Hide()
    end
    if B.showAbsorb and UnitGetTotalAbsorbs then
        b.absorb:SetMinMaxValues(0, V(max))
        b.absorb:SetValue(V(UnitGetTotalAbsorbs(u)))
        b.absorb:Show()
    else
        b.absorb:Hide()
    end
end

function ns.UpdateHealth(b)
    local u = b.unit
    local B = ns.P.bars
    local max, cur = UnitHealthMax(u), UnitHealth(u)
    b.health:SetMinMaxValues(0, V(max))
    -- suave solo si es la misma unidad (al cambiar de jugador, salto directo)
    SetBarValue(b.health, V(cur), B.smooth and b.lastHealthUnit == u)
    b.lastHealthUnit = u
    if B.healthColor == "gradient" or B.bgColor == "gradient" then ns.UpdateBarColor(b) end
    ns.UpdatePrediction(b, max)

    local text
    if R(UnitIsConnected(u)) == false then
        text = "Desconectado"
    elseif R(UnitIsGhost(u)) then
        text = "Fantasma"
    elseif R(UnitIsDead(u)) then
        text = "Muerto"
    end
    b.status:SetText(ns.P.texts.status.show and text or "")
    if text then
        b.hpText:SetText("")
        b.health.bg:SetAlpha(0.4)
    else
        HealthText(b, u, cur, max)
        b.health.bg:SetAlpha(1)
    end
end

function ns.UpdatePower(b)
    local B = ns.P.bars
    local u = b.unit
    local want = B.showPower and not b.isPet
    local ptype, token = UnitPowerType(u)
    if want and B.powerOnlyMana then
        local pt = R(ptype)
        if pt ~= nil and pt ~= 0 then want = false end
    end
    if want ~= b.powerShown then AnchorHealth(b, want) end
    if not want then return end
    b.power:SetMinMaxValues(0, V(UnitPowerMax(u)))
    -- suave solo si es la misma unidad (al cambiar de jugador, salto directo)
    SetBarValue(b.power, V(UnitPower(u)), B.powerSmooth and b.lastPowerUnit == u)
    b.lastPowerUnit = u
    token = R(token)
    local c = token and PowerBarColor and PowerBarColor[token]
    if c then b.power:SetStatusBarColor(c.r, c.g, c.b) else b.power:SetStatusBarColor(0.3, 0.5, 1) end
end

function ns.UpdateName(b)
    b.name:SetText(UnitName(b.unit))
end

function ns.UpdateRole(b)
    if not ns.P.elements.role.show or b.isPet then b.role:Hide() return end
    local role = UnitGroupRolesAssigned and R(UnitGroupRolesAssigned(b.unit))
    local atlas = (role == "TANK" and "roleicon-tiny-tank") or (role == "HEALER" and "roleicon-tiny-healer")
        or (role == "DAMAGER" and "roleicon-tiny-dps")
    if atlas and pcall(b.role.SetAtlas, b.role, atlas) then b.role:Show() else b.role:Hide() end
end

function ns.UpdateLeader(b)
    if not ns.P.elements.leader.show or b.isPet then b.leader:Hide() return end
    local u = b.unit
    if R(UnitIsGroupLeader(u)) then
        b.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        b.leader:Show()
    elseif UnitIsGroupAssistant and R(UnitIsGroupAssistant(u)) then
        b.leader:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
        b.leader:Show()
    else
        b.leader:Hide()
    end
end

function ns.UpdateRaidIcon(b)
    if not ns.P.elements.raidIcon.show then b.raidIcon:Hide() return end
    local idx = R(GetRaidTargetIndex(b.unit))
    if idx and SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(b.raidIcon, idx)
        b.raidIcon:Show()
    else
        b.raidIcon:Hide()
    end
end

local READY_TEX = {
    ready = READY_CHECK_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Ready",
    notready = READY_CHECK_NOT_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-NotReady",
    waiting = READY_CHECK_WAITING_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

function ns.UpdateReady(b)
    if not ns.P.elements.ready.show or b.isPet or not ns.readyActive then b.ready:Hide() return end
    local status = GetReadyCheckStatus and R(GetReadyCheckStatus(b.unit))
    if status and READY_TEX[status] then
        b.ready:SetTexture(READY_TEX[status])
        b.ready:Show()
    else
        b.ready:Hide()
    end
end

function ns.UpdateTarget(b)
    if not ns.P.bars.targetHighlight then b.hl:SetAlpha(0) return end
    local is = UnitIsUnit("target", b.unit)
    if S(is) then
        if b.hl.SetAlphaFromBoolean then pcall(b.hl.SetAlphaFromBoolean, b.hl, is, 1, 0) end
    else
        b.hl:SetAlpha(is and 1 or 0)
    end
end

function ns.UpdateThreat(b)
    if not ns.P.bars.aggro then b.aggro:Hide() return end
    local t = R(UnitThreatSituation and UnitThreatSituation(b.unit))
    b.aggro:SetShown(t and t >= 2 or false)
end

function ns.UpdateRange(b)
    local u = b.unit
    local alpha = ns.P.bars.rangeAlpha
    if R(UnitIsUnit("player", u)) == true then b:SetAlpha(1) return end
    local inRange, checked = UnitInRange(u)
    if S(inRange) or S(checked) then
        if b.SetAlphaFromBoolean then pcall(b.SetAlphaFromBoolean, b, inRange, 1, alpha) end
        return
    end
    if R(UnitIsVisible(u)) == false then b:SetAlpha(alpha) return end
    b:SetAlpha(((not checked) or inRange) and 1 or alpha)
end

function ns.UpdateButton(b)
    if not b.unit or not UnitExists(b.unit) then return end
    ns.UpdateColors(b)
    ns.UpdateName(b)
    ns.UpdatePower(b)
    ns.UpdateHealth(b)
    ns.UpdateRole(b)
    ns.UpdateLeader(b)
    ns.UpdateRaidIcon(b)
    ns.UpdateReady(b)
    ns.UpdateTarget(b)
    ns.UpdateThreat(b)
    ns.UpdateRange(b)
    ns.UpdateAuras(b)
end

function ns.UpdateAllButtons()
    if not ns.P then return end
    for _, b in ipairs(ns.buttons) do
        if b.unit and b:IsVisible() then ns.UpdateButton(b) end
    end
end

-------------------------------------------------------------------------------
-- Eventos por botón
-------------------------------------------------------------------------------
local auraDirty = {}

local function OnButtonEvent(b, event)
    ns.DiagEvent(event)
    if event == "UNIT_AURA" then
        auraDirty[b] = true
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH"
        or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
        ns.UpdateHealth(b)
    elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        -- solo sus barras: no tocar la de vida (cortaría su animación)
        ns.UpdatePrediction(b)
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        ns.UpdatePower(b)
    elseif event == "UNIT_NAME_UPDATE" then
        ns.UpdateName(b)
        ns.UpdateColors(b)
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
        ns.UpdateThreat(b)
    end
end

local function SetButtonUnit(b, unit)
    if b.unit == unit then return end
    b:UnregisterAllEvents()
    b.unit = unit
    if unit then
        for _, e in ipairs(UNIT_EVENTS) do
            pcall(b.RegisterUnitEvent, b, e, unit)
        end
        ns.UpdateButton(b)
    end
end

local function InitButton(header, name)
    local b = _G[name]
    if not b or b.mfInit then return end
    b.mfInit = true
    local isPet = header.isPet
    if not InCombatLockdown() then pcall(b.RegisterForClicks, b, "AnyUp") end
    ns.BuildVisuals(b)
    ns.LayoutButton(b, isPet)
    b:SetScript("OnEvent", OnButtonEvent)
    b:HookScript("OnAttributeChanged", function(self, attr, value)
        if attr == "unit" then SetButtonUnit(self, value) end
    end)
    b:HookScript("OnShow", function(self) if self.unit then ns.UpdateButton(self) end end)
    b:HookScript("OnEnter", function(self)
        if self.unit then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit(self.unit)
            GameTooltip:Show()
        end
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(ns.buttons, b)
    SetButtonUnit(b, b:GetAttribute("unit"))
end

-------------------------------------------------------------------------------
-- Cabeceras y anclas
-------------------------------------------------------------------------------
local INIT_SNIPPET = [[
    local header = self:GetParent()
    self:SetWidth(header:GetAttribute("mf-width"))
    self:SetHeight(header:GetAttribute("mf-height"))
    self:SetAttribute("*type1", "target")
    self:SetAttribute("*type2", "togglemenu")
    header:CallMethod("InitButton", self:GetName())
]]

local function CreateAnchor(name, label, posKey)
    local a = CreateFrame("Frame", name, UIParent)
    a:SetSize(10, 10)
    a:SetMovable(true)
    a:SetClampedToScreen(true)

    local handle = CreateFrame("Button", nil, a, "BackdropTemplate")
    handle:SetSize(170, 18)
    handle:SetPoint("BOTTOMLEFT", a, "TOPLEFT", 0, 2)
    handle:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    handle:SetBackdropColor(0.05, 0.3, 0.45, 0.9)
    handle:SetBackdropBorderColor(0.3, 0.8, 1, 1)
    handle.text = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    handle.text:SetPoint("CENTER")
    handle.label = label
    handle:RegisterForDrag("LeftButton")
    handle:RegisterForClicks("LeftButtonUp")
    handle:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self.dragged = true
        a:StartMoving()
    end)
    handle:SetScript("OnDragStop", function()
        a:StopMovingOrSizing()
        local p, _, rp, x, y = a:GetPoint(1)
        ns.P.pos[posKey] = { p, "UIParent", rp, x, y }
    end)
    -- clic (sin arrastrar): abrir las opciones, como /mf
    handle:SetScript("OnClick", function(self)
        if self.dragged then self.dragged = false return end
        if ns.OpenOptions then ns.OpenOptions() end
    end)
    handle:SetScript("OnMouseDown", function(self) self.dragged = false end)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("MendFrames")
        GameTooltip:AddLine("Arrastra para mover · Clic para abrir las opciones", 1, 1, 1)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    handle:Hide()
    a.handle = handle
    a.posKey = posKey
    return a
end

local GROUP_ORDERS = {
    GROUP = { "GROUP", "1,2,3,4,5,6,7,8" },
    ROLE  = { "ASSIGNEDROLE", "TANK,HEALER,DAMAGER,NONE" },
    CLASS = { "CLASS", "WARRIOR,PALADIN,PRIEST,DRUID,SHAMAN,ROGUE,MAGE,WARLOCK,HUNTER,DEATHKNIGHT,MONK,DEMONHUNTER,EVOKER" },
}

local function GroupFilter()
    local out = {}
    for i = 1, 8 do
        if ns.P.layout.groups[i] then out[#out + 1] = tostring(i) end
    end
    if #out == 0 then return "1,2,3,4,5,6,7,8" end
    return table.concat(out, ",")
end

local function SetHeaderLayout(h, isPet)
    local P = ns.P
    local L = P.layout
    local w, hh = L.width, L.height
    if isPet then w, hh = ns.PetSize() end
    h:SetAttribute("mf-width", w)
    h:SetAttribute("mf-height", hh)

    h:SetAttribute("showRaid", true)
    h:SetAttribute("showParty", L.showParty)
    h:SetAttribute("showPlayer", L.showPlayer)
    h:SetAttribute("showSolo", L.showSolo)

    if L.orientation == "horizontal" then
        h:SetAttribute("point", "LEFT")
        h:SetAttribute("xOffset", L.spacing)
        h:SetAttribute("yOffset", 0)
        h:SetAttribute("columnAnchorPoint", "TOP")
    else
        h:SetAttribute("point", "TOP")
        h:SetAttribute("xOffset", 0)
        h:SetAttribute("yOffset", -L.spacing)
        h:SetAttribute("columnAnchorPoint", "LEFT")
    end
    h:SetAttribute("columnSpacing", L.groupSpacing)
    h:SetAttribute("maxColumns", 8)
    h:SetAttribute("sortMethod", L.sortByName and "NAME" or "INDEX")
    h:SetAttribute("groupFilter", GroupFilter())

    if isPet then
        h:SetAttribute("unitsPerColumn", P.pets.perColumn)
        h:SetAttribute("filterOnPet", true)
        h:SetAttribute("useOwnerUnit", false)
    else
        h:SetAttribute("unitsPerColumn", 5)
        local go = GROUP_ORDERS[L.groupBy] or GROUP_ORDERS.GROUP
        h:SetAttribute("groupBy", go[1])
        h:SetAttribute("groupingOrder", go[2])
    end

    local i = 1
    local child = h:GetAttribute("child1")
    while child do
        child:SetSize(w, hh)
        if child.mfInit then ns.LayoutButton(child, isPet) end
        i = i + 1
        child = h:GetAttribute("child" .. i)
    end
end

local function CreateHeader(name, parent, template, isPet)
    local h = CreateFrame("Frame", name, parent, template)
    h.isPet = isPet
    h.InitButton = InitButton
    h:SetAttribute("template", "SecureUnitButtonTemplate")
    h:SetAttribute("initialConfigFunction", INIT_SNIPPET)
    SetHeaderLayout(h, isPet)
    h:SetPoint("TOPLEFT", parent, "TOPLEFT")
    return h
end

local function AnchorPets()
    local h = ns.petHeader
    h:ClearAllPoints()
    if ns.P.pets.attach then
        local gs = ns.P.layout.groupSpacing
        if ns.P.layout.orientation == "horizontal" then
            h:SetPoint("TOPLEFT", ns.header, "BOTTOMLEFT", 0, -gs)
        else
            h:SetPoint("TOPLEFT", ns.header, "TOPRIGHT", gs, 0)
        end
    else
        h:SetPoint("TOPLEFT", ns.petAnchor, "TOPLEFT")
    end
end

function ns.ApplyPositions()
    for _, a in ipairs({ ns.anchor, ns.petAnchor }) do
        local p = ns.P.pos[a.posKey]
        a:ClearAllPoints()
        a:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    end
end

local function UpdateHandles()
    local name = ns.activeName or "?"
    ns.anchor.handle.text:SetText(("MendFrames · %s"):format(name))
    ns.petAnchor.handle.text:SetText(("Mascotas · %s"):format(name))
    local unlocked = not ns.db.locked
    ns.anchor.handle:SetShown(unlocked)
    ns.petAnchor.handle:SetShown(unlocked and ns.P.pets.enabled and not ns.P.pets.attach)
end

-- Aplica todo el perfil activo (fuera de combate)
function ns.ApplyProfile()
    ns.RunOOC("profile", function()
        ns.CompileIndicators()
        ns.ApplyPositions()
        local scale = ns.P.layout.scale
        ns.anchor:SetScale(scale)
        ns.petAnchor:SetScale(scale)
        SetHeaderLayout(ns.header, false)
        SetHeaderLayout(ns.petHeader, true)
        AnchorPets()
        ns.header:Hide()
        ns.header:Show()
        ns.petHeader:Hide()
        if ns.P.pets.enabled then ns.petHeader:Show() end
        UpdateHandles()
        if ns.testing then ns.LayoutTest() end
        ns.UpdateAllButtons()
    end)
end
ns.ApplyLayout = ns.ApplyProfile

function ns.SetLocked(locked)
    if not locked and InCombatLockdown() then
        ns.Print("no se puede desbloquear en combate.")
        return
    end
    ns.db.locked = locked
    UpdateHandles()
    if not locked and not ns.testing and not IsInGroup() then
        ns.ToggleTest(true)
    end
    if ns.OnLockChanged then ns.OnLockChanged() end
end

-------------------------------------------------------------------------------
-- Eventos globales y temporizadores
-------------------------------------------------------------------------------
local gev = CreateFrame("Frame")
for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE",
    "PLAYER_ROLES_ASSIGNED", "UNIT_PET", "PARTY_LEADER_CHANGED",
    "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED" }) do
    pcall(gev.RegisterEvent, gev, e)
end
gev:SetScript("OnEvent", function(_, event)
    if not ns.header then return end
    ns.DiagEvent("global:" .. event)
    if event == "PLAYER_TARGET_CHANGED" then
        for _, b in ipairs(ns.buttons) do if b.unit then ns.UpdateTarget(b) end end
    elseif event == "RAID_TARGET_UPDATE" then
        for _, b in ipairs(ns.buttons) do if b.unit then ns.UpdateRaidIcon(b) end end
    elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" then
        ns.readyActive = true
        for _, b in ipairs(ns.buttons) do if b.unit then ns.UpdateReady(b) end end
    elseif event == "READY_CHECK_FINISHED" then
        C_Timer.After(6, function()
            ns.readyActive = false
            for _, b in ipairs(ns.buttons) do b.ready:Hide() end
        end)
    else
        ns.UpdateAllButtons()
    end
end)

local rangeElapsed = 0
gev:SetScript("OnUpdate", function(_, elapsed)
    for b in pairs(auraDirty) do
        auraDirty[b] = nil
        if b.unit and b:IsVisible() then ns.UpdateAuras(b) end
    end
    rangeElapsed = rangeElapsed + elapsed
    if rangeElapsed > 0.25 then
        rangeElapsed = 0
        for _, b in ipairs(ns.buttons) do
            if b.unit and b:IsVisible() then ns.UpdateRange(b) end
        end
    end
end)

-------------------------------------------------------------------------------
-- Creación
-------------------------------------------------------------------------------
function ns.CreateFrames()
    ns.CompileIndicators()
    ns.anchor = CreateAnchor("MendFramesAnchor", "MendFrames", "main")
    ns.petAnchor = CreateAnchor("MendFramesPetAnchor", "Mascotas", "pets")
    ns.ApplyPositions()
    ns.anchor:SetScale(ns.P.layout.scale)
    ns.petAnchor:SetScale(ns.P.layout.scale)

    ns.header = CreateHeader("MendFramesHeader", ns.anchor, "SecureGroupHeaderTemplate", false)
    ns.petHeader = CreateHeader("MendFramesPetHeader", ns.petAnchor, "SecureGroupPetHeaderTemplate", true)
    AnchorPets()
    ns.header:Show()
    if ns.P.pets.enabled then ns.petHeader:Show() end

    ns.SetLocked(ns.db.locked)
end

-------------------------------------------------------------------------------
-- Modo prueba
-------------------------------------------------------------------------------
local TEST_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "HUNTER", "WARLOCK", "PALADIN", "SHAMAN", "PRIEST" }
local TEST_NAMES = { "Thrall", "Jaina", "Uther", "Valeera", "Malfurion", "Rexxar", "Guldan", "Tirion", "Nobundo", "Anduin" }
local NUM_TEST_PETS = 4

local function NewTestButton(parent, isPet, i)
    local b = CreateFrame("Frame", nil, parent)
    ns.BuildVisuals(b)
    b.isPet = isPet
    b.testIndex = i
    table.insert(testButtons, b)
    return b
end

local function FillTest(b)
    local P = ns.P
    local B, T = P.bars, P.texts
    local i = b.testIndex
    local class = (not b.isPet) and TEST_CLASSES[(i - 1) % #TEST_CLASSES + 1] or nil
    ns.UpdateColors(b, class)

    b.name:SetText(b.isPet and ("Mascota " .. i) or TEST_NAMES[(i - 1) % #TEST_NAMES + 1])
    local hp = 0.35 + ((i * 37) % 65) / 100
    if i == 4 then hp = 1 end
    b.health:SetMinMaxValues(0, 10000)
    b.health:SetValue(hp * 10000)
    ns.UpdateBarColor(b, class, (i == 7) and 0 or hp)   -- para el degradado
    b.pred:SetMinMaxValues(0, 10000)
    b.pred:SetValue((i % 3 == 0 and B.showHealPred) and 1500 or 0)
    b.pred:SetShown(B.showHealPred)
    b.absorb:SetMinMaxValues(0, 10000)
    b.absorb:SetValue((i % 4 == 0 and B.showAbsorb) and 1000 or 0)
    b.absorb:SetShown(B.showAbsorb)

    local wantPower = B.showPower and not b.isPet
    if wantPower and B.powerOnlyMana and (class == "WARRIOR" or class == "ROGUE") then wantPower = false end
    AnchorHealth(b, wantPower)
    b.power:SetMinMaxValues(0, 100)
    b.power:SetValue(60)
    local pc = (class == "WARRIOR" and PowerBarColor and PowerBarColor.RAGE)
        or (class == "ROGUE" and PowerBarColor and PowerBarColor.ENERGY)
    if pc then b.power:SetStatusBarColor(pc.r, pc.g, pc.b) else b.power:SetStatusBarColor(0, 0.55, 1) end

    local dead = (i == 7)
    b.status:SetText((dead and T.status.show) and "Muerto" or "")
    if dead then
        b.hpText:SetText("")
        b.health:SetValue(0)
    else
        HealthText(b, nil, math.floor(hp * 10000), 10000)
    end
    b:SetAlpha(i % 9 == 0 and B.rangeAlpha or 1)

    b.hl:SetAlpha((B.targetHighlight and i == 3) and 1 or 0)
    b.aggro:SetShown(B.aggro and i == 1)

    local E = P.elements
    b.role:Hide()
    if E.role.show and not b.isPet and i <= 3 then
        pcall(b.role.SetAtlas, b.role, i == 1 and "roleicon-tiny-tank" or "roleicon-tiny-healer")
        b.role:Show()
    end
    b.leader:SetShown(E.leader.show and i == 1 and not b.isPet)
    b.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    b.raidIcon:SetShown(E.raidIcon.show and i == 2 and not b.isPet)
    if SetRaidTargetIconTexture then SetRaidTargetIconTexture(b.raidIcon, 8) end
    b.ready:SetShown(E.ready.show and i == 5 and not b.isPet)
    b.ready:SetTexture(READY_TEX.ready)

    ns.TestAuras(b, i)
end

local function PositionGrid(list, parent, w, h, perGroup, ox, oy)
    local L = ns.P.layout
    ox, oy = ox or 0, oy or 0
    for idx, b in ipairs(list) do
        local n = idx - 1
        local g, p = math.floor(n / perGroup), n % perGroup
        local x, y
        if L.orientation == "horizontal" then
            x = p * (w + L.spacing)
            y = -g * (h + L.groupSpacing)
        else
            x = g * (w + L.groupSpacing)
            y = -p * (h + L.spacing)
        end
        b:SetSize(w, h)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + ox, y + oy)
    end
end

function ns.LayoutTest()
    local P = ns.P
    local L = P.layout
    local count = ns.SIZE_TEST[ns.testSize or "raid20"] or 20
    local main, pets = {}, {}
    for _, b in ipairs(testButtons) do
        if b.isPet then
            pets[#pets + 1] = b
        elseif b.testIndex <= count then
            main[#main + 1] = b
        else
            b:Hide()
        end
    end
    for _, b in ipairs(main) do
        b:SetShown(ns.testing)
        ns.LayoutButton(b, false)
        FillTest(b)
    end
    for _, b in ipairs(pets) do
        b:SetShown(ns.testing and P.pets.enabled)
        ns.LayoutButton(b, true)
        FillTest(b)
    end
    PositionGrid(main, ns.anchor, L.width, L.height, 5)
    if P.pets.attach then
        local groups = math.ceil(#main / 5)
        local ox, oy = 0, 0
        if L.orientation == "horizontal" then
            oy = -groups * (L.height + L.groupSpacing)
        else
            ox = groups * (L.width + L.groupSpacing)
        end
        local pw, ph = ns.PetSize()
        PositionGrid(pets, ns.anchor, pw, ph, P.pets.perColumn, ox, oy)
    else
        local pw, ph = ns.PetSize()
        PositionGrid(pets, ns.petAnchor, pw, ph, P.pets.perColumn)
    end
end

-- force: true/false para fijar; size: party | raid10 | raid20 | raid40
function ns.ToggleTest(force, size)
    if size then ns.testSize = size end
    if force ~= nil then ns.testing = force else ns.testing = not ns.testing end
    ns.testSize = ns.testSize or "raid20"
    if ns.testing and #testButtons == 0 then
        for i = 1, 40 do NewTestButton(ns.anchor, false, i) end
        for i = 1, NUM_TEST_PETS do NewTestButton(ns.petAnchor, true, i) end
    end
    if not ns.testing then
        for _, b in ipairs(testButtons) do b:Hide() end
    end
    ns.header:SetAlpha(ns.testing and 0 or 1)
    ns.petHeader:SetAlpha(ns.testing and 0 or 1)
    -- el perfil activo depende del tamaño simulado
    ns.ActivateProfile(true)
    if ns.OnTestChanged then ns.OnTestChanged() end
end
