-------------------------------------------------------------------------------
-- Tile - Options look: a LibFlatyUI-1.0 instance with the Tile color, plus
-- the few helpers the pages share
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local UI = LibStub("LibFlatyUI-1.0"):New({ accent = ns.ACCENT })
ns.UI = UI

UI.OnChange = function() UI.RefreshAll() end

-- Texts the library shows on its own, in the active language
local STRINGS = {
    confirm = "Click again to confirm",
    search = "Search...",
    accept = "Accept",
    cancel = "Cancel",
}
UI.strings = setmetatable({}, { __index = function(_, key) return L[STRINGS[key]] end })

-- Marks a control as part of the one above: it sits right below it
function UI.Attach(w)
    w.sub = true
    return w
end

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
-- Common option lists and formats
-------------------------------------------------------------------------------
function UI.PointList()
    return {
        { "TOPLEFT", L["Top left"] }, { "TOP", L["Top"] }, { "TOPRIGHT", L["Top right"] },
        { "LEFT", L["Left"] }, { "CENTER", L["Center"] }, { "RIGHT", L["Right"] },
        { "BOTTOMLEFT", L["Bottom left"] }, { "BOTTOM", L["Bottom"] }, { "BOTTOMRIGHT", L["Bottom right"] },
    }
end

UI.percent = function(v) return v .. "%" end
