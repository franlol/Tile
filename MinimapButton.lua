-------------------------------------------------------------------------------
-- Tile - Minimap button (LibDBIcon): click opens the options, drag moves it
-- around the minimap (saved for the whole account)
-------------------------------------------------------------------------------

local ADDON, ns = ...
local L = ns.L

local DBI = LibStub("LibDBIcon-1.0")

-- LibDBIcon's settings (minimapPos, hide, lock). Older versions saved the
-- position as "angle": same degrees, so it carries over as it is.
local function Settings()
    local m = ns.db.minimap
    if m.angle then
        m.minimapPos = m.angle
        m.angle = nil
    end
    return m
end

local broker = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON, {
    type = "launcher",
    icon = "Interface\\AddOns\\Tile\\Media\\IconRound",
    OnClick = function() ns.ToggleOptions() end,
    OnTooltipShow = function(tt)
        tt:AddDoubleLine("Tile", "v" .. ns.version, ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.5, 0.5, 0.5)
        tt:AddDoubleLine(L["Active profile"], ns.activeName or "?", 0.7, 0.7, 0.7, 1, 1, 1)
        tt:AddLine(" ")
        tt:AddDoubleLine(L["Click"], L["Open the options"], 1, 0.82, 0, 1, 1, 1)
    end,
})

-- Show or hide it as the options say
function ns.UpdateMinimapButton()
    DBI:Refresh(ADDON, Settings())
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if broker and not DBI:IsRegistered(ADDON) then
        DBI:Register(ADDON, broker, Settings())
    end
end)
