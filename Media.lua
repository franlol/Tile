-------------------------------------------------------------------------------
-- Tile - Fonts and textures
-- Blizzard's are always there; if another addon loads LibSharedMedia-3.0,
-- all of its ones are added too.
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local FONTS = {
    { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "Skurri", "Fonts\\skurri.ttf" },
    { "Morpheus", "Fonts\\MORPHEUS.ttf" },
}

-- Textures shipped with the addon (Media folder)
local DARK = "Interface\\AddOns\\Tile\\Media\\Dark"

local TEXTURES = {
    { "Tile · Dark", DARK },
    { "Flat", "Interface\\Buttons\\WHITE8X8" },
    { "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
    { "Blizzard (raid)", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { "Blizzard (resource)", "Interface\\RaidFrame\\Raid-Bar-Resource-Fill" },
    { "Gloss", "Interface\\TargetingFrame\\BarFill2" },
    { "Smooth", "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
}

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function Merge(base, mediaType)
    local out, seen = {}, {}
    for _, e in ipairs(base) do
        out[#out + 1] = { e[2], L[e[1]] }
        seen[e[2]:lower()] = true
    end
    local lsm = LSM()
    if lsm then
        local extra = {}
        for name, path in pairs(lsm:HashTable(mediaType)) do
            if type(path) == "string" and not seen[path:lower()] then
                seen[path:lower()] = true
                extra[#extra + 1] = { path, name }
            end
        end
        table.sort(extra, function(a, b) return a[2] < b[2] end)
        for _, e in ipairs(extra) do out[#out + 1] = e end
    end
    return out
end

-- Register our textures in LibSharedMedia so other addons can use them
local function RegisterMedia()
    local lsm = LSM()
    if lsm then lsm:Register("statusbar", "Tile Dark", DARK) end
end
RegisterMedia()
local regFrame = CreateFrame("Frame")
regFrame:RegisterEvent("PLAYER_LOGIN")
regFrame:SetScript("OnEvent", RegisterMedia)

-- { value, label } lists for the dropdowns.
-- For fonts, the 3rd field is the font used to draw the label.
function ns.FontList()
    local list = Merge(FONTS, "font")
    for _, o in ipairs(list) do o[3] = o[1] end
    return list
end
-- For textures, the 4th field is the texture shown as a sample behind it
-- "None" (value "none"): that part is not drawn
function ns.TextureList()
    local list = Merge(TEXTURES, "statusbar")
    for _, o in ipairs(list) do o[4] = o[1] end
    table.insert(list, 1, { "none", L["None"] })
    return list
end

local FLAT = "Interface\\Buttons\\WHITE8X8"

-- Texture of a bar; with "None" the bar is still there but invisible
function ns.SetBarTexture(bar, path)
    local none = path == "none" or path == nil or path == ""
    bar:SetStatusBarTexture(none and FLAT or path)
    local t = bar:GetStatusBarTexture()
    if t then t:SetAlpha(none and 0 or 1) end
end

-- Texture of a background (plain texture)
function ns.SetBgTexture(tex, path)
    local none = path == "none" or path == nil or path == ""
    tex:SetTexture(none and FLAT or path)
    tex:SetShown(not none)
end

function ns.OutlineList()
    return {
        { "", L["No outline"] },
        { "OUTLINE", L["Outline"] },
        { "THICKOUTLINE", L["Thick outline"] },
        { "MONOCHROME", L["Monochrome"] },
        { "OUTLINE, MONOCHROME", L["Monochrome outline"] },
    }
end

-- Applies a font; if the path is not valid, uses the standard one
function ns.SetFont(fs, font, size, outline)
    outline = outline or ""
    local ok = pcall(fs.SetFont, fs, font or ns.FONT, size, outline)
    if not ok or not fs:GetFont() then
        fs:SetFont(STANDARD_TEXT_FONT, size, outline)
    end
end

-------------------------------------------------------------------------------
-- Common style of any text (name, health, status, time, stacks):
-- { font, size, outline, colorMode = white|class|custom, color, point, x, y }
-------------------------------------------------------------------------------
-- dx, dy: extra offset (e.g. so the text does not stick out of an icon)
function ns.StyleText(fs, t, anchor, dx, dy)
    ns.SetFont(fs, t.font, t.size or 10, t.outline or "")
    fs:ClearAllPoints()
    local p = t.point or "CENTER"
    fs:SetPoint(p, anchor, p, (t.x or 0) + (dx or 0), (t.y or 0) + (dy or 0))
    fs:SetJustifyH(p:find("LEFT") and "LEFT" or (p:find("RIGHT") and "RIGHT" or "CENTER"))
end

-- r, g, b: class color of the unit (if known)
function ns.ColorText(fs, t, r, g, b)
    if t.colorMode == "class" and r then
        fs:SetTextColor(r, g, b, 1)
    elseif t.colorMode == "custom" and t.color then
        local c = t.color
        fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
    else
        fs:SetTextColor(1, 1, 1, 1)
    end
end

-- Pets get a fixed green, like Blizzard's raid frames (not their owner's class)
local PET_COLOR = { r = 0, g = 0.8, b = 0.2 }

-- Class color of a unit (if the game lets us read it); pets use PET_COLOR
function ns.ClassColorOf(unit, previewClass, isPet)
    if isPet then return PET_COLOR.r, PET_COLOR.g, PET_COLOR.b end
    local c = previewClass
    if not c and unit then
        local _, class = UnitClass(unit)
        if ns.R then class = ns.R(class) end
        c = class
    end
    local cc = c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]
    if cc then return cc.r, cc.g, cc.b end
    return nil
end
