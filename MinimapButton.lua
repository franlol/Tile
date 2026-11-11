-------------------------------------------------------------------------------
-- Tile - Minimap button: click opens the options, drag moves it around the
-- minimap (the angle is saved)
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local btn = CreateFrame("Button", "TileMinimapButton", Minimap)
btn:SetSize(31, 31)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:RegisterForClicks("AnyUp")
btn:RegisterForDrag("LeftButton")
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 7, -5)
icon:SetTexture("Interface\\AddOns\\Tile\\Media\\IconRound")

local border = btn:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local atan2 = math.atan2 or atan2

-- Place the button on the edge of the minimap at the saved angle
local function Place()
    local a = math.rad(ns.db.minimap.angle)
    local r = Minimap:GetWidth() / 2 + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

-- While dragging, follow the cursor around the minimap
local function FollowCursor()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    ns.db.minimap.angle = math.deg(atan2(cy / scale - my, cx / scale - mx))
    Place()
end

btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", FollowCursor)
    GameTooltip:Hide()
end)
btn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)
btn:SetScript("OnClick", function()
    ns.ToggleOptions()
end)
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine("Tile", "v" .. ns.version, ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.5, 0.5, 0.5)
    GameTooltip:AddDoubleLine(L["Active profile"], ns.activeName or "?", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L["Click"], L["Open the options"], 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Drag"], L["Move this button"], 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Show or hide it as the options say
function ns.UpdateMinimapButton()
    btn:SetShown(not ns.db.minimap.hide)
end

-- the saved angle is only known after the saved variables load
btn:RegisterEvent("PLAYER_LOGIN")
btn:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    Place()
    ns.UpdateMinimapButton()
end)
