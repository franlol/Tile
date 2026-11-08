-- Blizzard owns aura selection and visibility while aura reads are restricted.
local _, ns = ...
local FLAT = "Interface\\Buttons\\WHITE8X8"

-- The preview and native textures must use identical alpha assets.
function ns.DispelTintAsset(shape)
    if shape == "solid" then return FLAT end
    return "Interface\\AddOns\\MendFrames\\Media\\"
        .. (shape == "down" and "DispelGradientDown" or "DispelGradientUp")
end

function ns.ReleaseNativeIndicator(w)
    if w.nativeDispel then
        w.nativeDispel:Hide()
        w.nativeDispel:SetUnit("none")
        w.nativeDispel = nil
    end
    w.nativeAuraError = nil
end

function ns.BuildNativeDispel(b, w, cfg)
    if ns.IndicatorAuraPlan(cfg).route ~= "native-dispel" then return end
    local container
    local ok, err = pcall(function()
        container = CreateFrame("AuraContainer", nil, w:GetParent(), "CustomAuraContainerTemplate")
        container:Hide()
        container:SetSize(1, 1)
        container:SetPoint("CENTER", w, "CENTER")
        container:SetFrameLevel(w:GetFrameLevel())
        local colors = {}
        for _, kind in ipairs({ "Magic", "Curse", "Disease", "Poison", "None" }) do
            local r, g, blue
            if cfg.dispelColor then r, g, blue = ns.DispelColor(kind == "None" and "none" or kind)
            else r, g, blue = cfg.color.r, cfg.color.g, cfg.color.b end
            colors[kind] = CreateColor(r or 1, g or 0, blue or 0)
        end
        local excluded = {}
        for kind, enabled in pairs(cfg.dispelTypes) do
            if not enabled then excluded[kind] = true end
        end
        if not cfg.unknownType then excluded.None = true end
        local filter = cfg.watch == "debuffTypes" and "HARMFUL" or "HARMFUL|RAID"
        local candidates = { excludeDispelTypes = excluded }
        if cfg.watch == "debuffTypes" then
            -- Select by type inside Blizzard's secure code, regardless of class.
            -- Do not admit untyped damage debuffs just because their data is hidden.
            local included = {}
            for kind, enabled in pairs(cfg.dispelTypes) do
                if enabled then included[kind] = true end
            end
            candidates = { includeDispelTypes = included }
        end
        container:AddAuraSlot("dispel", filter, {
            candidateFilters = candidates,
            initializeFrame = function(button)
                button:SetSize(1, 1)
                button:SetPoint("TOPLEFT", w, "TOPLEFT")
                button:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT")
                button:EnableMouse(false)
                local function Register(tex)
                    button:AddDispelTypeTexture(tex, {
                        showAlways = true,
                        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                        customDispelColorMap = colors,
                    })
                end
                if cfg.type == "overlay" then
                    -- Native dispel updates replace vertex colors (and therefore
                    -- SetGradient). Keep opacity in the asset and a separate parent.
                    local tint = CreateFrame("Frame", nil, button)
                    tint:SetAllPoints()
                    tint:SetAlpha(cfg.overlayAlpha or 0.6)
                    local tex = tint:CreateTexture(nil, "OVERLAY")
                    tex:SetAllPoints()
                    tex:SetTexture(ns.DispelTintAsset(cfg.tintShape))
                    Register(tex)
                else
                    for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
                        local tex = button:CreateTexture(nil, "OVERLAY")
                        tex:SetTexture(FLAT)
                        local th = math.max(1, cfg.width or 2)
                        if edge == "TOP" or edge == "BOTTOM" then
                            tex:SetPoint(edge .. "LEFT")
                            tex:SetPoint(edge .. "RIGHT")
                            tex:SetHeight(th)
                        else
                            tex:SetPoint("TOP" .. edge)
                            tex:SetPoint("BOTTOM" .. edge)
                            tex:SetWidth(th)
                        end
                        Register(tex)
                    end
                end
                if cfg.typeIcon then
                    local icon = button:CreateTexture(nil, "OVERLAY", nil, 1)
                    local pos = cfg.typeIconPos or {}
                    icon:SetSize(cfg.typeIconSize or 14, cfg.typeIconSize or 14)
                    icon:SetPoint(pos.point or "CENTER", button, pos.point or "CENTER", pos.x or 0, pos.y or 0)
                    button:AddDispelTypeTexture(icon, {
                        style = Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset,
                        customDispelAssetMap = {
                            Magic = { asset = ns.DISPEL_ICONS.Magic },
                            Curse = { asset = ns.DISPEL_ICONS.Curse },
                            Disease = { asset = ns.DISPEL_ICONS.Disease },
                            Poison = { asset = ns.DISPEL_ICONS.Poison },
                        },
                    })
                end
            end,
        })
        container:SetUnit(b.unit or "none")
    end)
    if ok then w.nativeDispel = container
    else
        if container then container:Hide() container:SetUnit("none") end
        w.nativeAuraError = tostring(err)
        if ns.db then ns.db.nativeDispelError = tostring(err) end
        if not ns.nativeDispelWarned then
            ns.nativeDispelWarned = true
            ns.Print("No se pudo crear el indicador nativo de disipación: " .. tostring(err))
        end
    end
end

-- A group, rather than multiple slots, gives each debuff exactly one icon.
-- Exact spell matching on harmful friendly auras is not available to addons
-- through the native container, so retain the old path for configured blacklists.
function ns.BuildNativeDebuffs(b, w, cfg)
    if ns.IndicatorAuraPlan(cfg).route ~= "native-debuffs" then return end
    local container
    local ok, err = pcall(function()
        container = CreateFrame("AuraContainer", nil, w:GetParent(), "CustomAuraContainerTemplate")
        container:Hide()
        container:SetFrameLevel(w:GetFrameLevel())
        container:SetPoint(cfg.point, w, cfg.point)
        container:SetFlowLayoutAnchorPoint(cfg.point)
        local vertical = cfg.grow == "UP" or cfg.grow == "DOWN"
        container:SetFlowLayoutAxis(vertical and AnchorUtil.FlowLayoutAxis.Vertical or AnchorUtil.FlowLayoutAxis.Horizontal)
        container:SetFlowLayoutGrowthDirection(
            cfg.grow == "LEFT" and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right,
            cfg.grow == "UP" and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
        local colors = { None = CreateColor(0, 0, 0) }
        for _, kind in ipairs({ "Magic", "Curse", "Disease", "Poison" }) do
            local r, g, blue = ns.DispelColor(kind)
            colors[kind] = CreateColor(r, g, blue)
        end
        container:AddAuraGroup("debuffs", cfg.onlyDispellable and "HARMFUL|RAID" or "HARMFUL", {
            maxFrameCount = cfg.max,
            layout = { elementSpacing = cfg.spacing, elementWidth = cfg.width, elementHeight = cfg.height },
            initializeFrame = function(button)
                button:SetSize(cfg.width, cfg.height)
                button:EnableMouse(false)
                local border = button:CreateTexture(nil, "BACKGROUND")
                border:SetPoint("TOPLEFT", -1, 1)
                border:SetPoint("BOTTOMRIGHT", 1, -1)
                border:SetColorTexture(0, 0, 0, 1)
                border:SetShown(cfg.showBorder ~= false)
                if cfg.dispelColor and cfg.showBorder ~= false then
                    button:AddDispelTypeTexture(border, {
                        showAlways = true,
                        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                        customDispelColorMap = colors,
                    })
                end
                local icon = button:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints()
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                button:SetIcon(icon)
                if cfg.swipe ~= false then
                    local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                    cd:SetAllPoints()
                    cd:SetReverse(cfg.swipeStyle ~= "clockReverse")
                    cd:SetDrawEdge(cfg.swipeStyle == "clockEdge")
                    cd:SetHideCountdownNumbers(true)
                    button:SetDurationCooldown(cd)
                end
                local top = CreateFrame("Frame", nil, button)
                top:SetAllPoints()
                top:SetFrameLevel(button:GetFrameLevel() + 5)
                if cfg.stacks then
                    local count = top:CreateFontString(nil, "OVERLAY")
                    local pos = cfg.stacksText.point or "BOTTOMRIGHT"
                    local dx = pos:find("RIGHT") and 2 or (pos:find("LEFT") and 1 or 0)
                    ns.StyleText(count, cfg.stacksText, button, dx, pos:find("TOP") and -1 or (pos:find("BOTTOM") and -1 or 0))
                    ns.ColorText(count, cfg.stacksText)
                    button:SetApplicationCount(count)
                end
                if cfg.timer then
                    local timer = top:CreateFontString(nil, "OVERLAY")
                    local pos = cfg.timerText.point or "CENTER"
                    local dx = pos:find("RIGHT") and 2 or (pos:find("LEFT") and 1 or 0)
                    ns.StyleText(timer, cfg.timerText, button, dx, pos:find("TOP") and -1 or (pos:find("BOTTOM") and -1 or 0))
                    ns.ColorText(timer, cfg.timerText)
                    button:SetDurationText(timer, {})
                end
            end,
        })
        container:SetUnit(b.unit or "none")
    end)
    if ok then w.nativeDispel = container
    else
        if container then container:Hide() container:SetUnit("none") end
        w.nativeAuraError = tostring(err)
        if ns.db then ns.db.nativeDispelError = tostring(err) end
        ns.Print("No se pudo crear la lista nativa de debuffs: " .. tostring(err))
    end
end

function ns.BuildNativeIndicator(b, w, cfg)
    ns.ReleaseNativeIndicator(w)
    local plan = ns.IndicatorAuraPlan(cfg)
    w.auraRoute = plan.route
    if plan.route == "native-dispel" or plan.route == "native-debuffs" then
        -- Groups allocate additional frames later. They must see the settings
        -- applied now, not edits queued while the player is in combat.
        local snapshot = ns.DeepCopy(cfg)
        if plan.route == "native-dispel" then ns.BuildNativeDispel(b, w, snapshot)
        else ns.BuildNativeDebuffs(b, w, snapshot) end
        if not w.nativeDispel then w.auraRoute = "legacy-error" end
    end
end

-- Never inspect the protected slot or its aura data; only our own container.
function ns.DiagnoseNativeDispel()
    local version, build = GetBuildInfo()
    ns.Print("Disipable: cliente " .. tostring(version) .. " / " .. tostring(build)
        .. "; API nativa: " .. tostring(Enum and Enum.CustomAuraButtonDispelTypeTextureStyle ~= nil))
    local count = 0
    for _, b in ipairs(ns.buttons or {}) do
        if b.unit and b:IsVisible() then
            for _, c in ipairs(ns.compiled or {}) do
                if c.dispellable or c.kind == "debuffs" then
                    local w = b.ind and b.ind[c.index]
                    local native = w and w.nativeDispel
                    count = count + 1
                    if count <= 3 then
                        ns.Print(tostring(b.unit) .. ": " .. tostring(c.cfg.name)
                            .. "; nativo=" .. tostring(native ~= nil)
                            .. "; visible=" .. tostring(native and native:IsVisible() or false)
                            .. "; solo fuera=" .. tostring(c.cfg.onlyOOC))
                    end
                end
            end
        end
    end
    ns.Print("Indicadores encontrados: " .. count .. "; combate=" .. tostring(InCombatLockdown())
        .. "; error=" .. tostring(ns.db and ns.db.nativeDispelError or "ninguno"))
end
