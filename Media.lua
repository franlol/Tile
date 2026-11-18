-------------------------------------------------------------------------------
-- Tile - Fonts and textures
-- From LibFlatyUI: its own ("Flaty: ..."), the game's, and LibSharedMedia's
-- when another addon loads it.
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L
local Flaty = LibStub("LibFlatyUI-1.0")

local FLAT = "Interface\\Buttons\\WHITE8X8"

-- Tile's own dark texture moved to the lib ("Flaty: Dark"): old profiles
-- still point to it
local OLD_DARK = "interface\\addons\\tile\\media\\dark"

-- A saved path ready to use; nil when the file's addon is not loaded (e.g.
-- a SharedMedia texture in a profile someone imported). Atlases pass through.
function ns.ResolveTexture(path)
    if type(path) == "string" and path:lower():gsub("/", "\\") == OLD_DARK then
        return Flaty.Media("statusbar", "Flaty: Dark")
    end
    return Flaty.ResolveMedia(path)
end

-- For dropdown getters: the saved value as the list knows it.
-- Takes and returns a getter, setter pair.
function ns.MediaPair(get, set)
    return function()
        local v = get()
        return v and ns.ResolveTexture(v) or v
    end, set
end

-- The game's names are translated here (the lib's are brand names)
local function Translated(list)
    for _, o in ipairs(list) do
        if not o[2]:find("^Flaty: ") then o[2] = L[o[2]] end
    end
    return list
end

-- { value, label, font } for the dropdowns
function ns.FontList()
    return Translated(Flaty.MediaList("font"))
end

-- { value, label, nil, sample }: bar textures, then backgrounds (a bar's
-- background can use either). "None" (value "none"): that part is not drawn.
function ns.TextureList()
    local list = Flaty.MediaList("statusbar", { none = true, noneLabel = "None" })
    local seen = {}
    for _, o in ipairs(list) do seen[o[1]] = true end
    for _, o in ipairs(Flaty.MediaList("background")) do
        if not seen[o[1]] then list[#list + 1] = o end
    end
    return Translated(list)
end

local function IsNone(path) return path == "none" or path == nil or path == "" end

-- Texture of a bar; with "None" the bar is still there but invisible
function ns.SetBarTexture(bar, path)
    local none = IsNone(path)
    bar:SetStatusBarTexture(not none and ns.ResolveTexture(path) or FLAT)
    local t = bar:GetStatusBarTexture()
    if t then t:SetAlpha(none and 0 or 1) end
end

-- Texture of a background (plain texture): an atlas or a file
function ns.SetBgTexture(tex, path)
    local none = IsNone(path)
    local p = not none and ns.ResolveTexture(path) or FLAT
    if not none and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(p) then
        tex:SetAtlas(p)
    else
        tex:SetTexture(p)
    end
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

-- Font and outline of a text style: its own, or the profile's general ones
-- (font = false / outline = false). An outline of "" is "No outline".
function ns.FontOf(t)
    local G = (ns.P and ns.P.general) or ns.profileDefaults.general
    local font = (t.font and t.font ~= "") and t.font or G.font
    local outline = t.outline
    if outline == nil or outline == false then outline = G.outline end
    return font, outline
end

-- Applies a font; if the path is not valid, uses the standard one
function ns.SetFont(fs, font, size, outline)
    outline = outline or ""
    local ok = pcall(fs.SetFont, fs, ns.ResolveTexture(font) or ns.FONT, size, outline)
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
    local font, outline = ns.FontOf(t)
    ns.SetFont(fs, font, t.size or 10, outline)
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

-- Class color of a unit (if the game lets us read it), from the Colors page.
-- Pets get their own color, like Blizzard's raid frames (not their owner's class).
function ns.ClassColorOf(unit, previewClass, isPet)
    local colors = ns.P and ns.P.colors
    if isPet then
        local pc = colors and colors.pet
        if pc then return pc.r, pc.g, pc.b end
        return 0, 0.8, 0.2
    end
    local c = previewClass
    if not c and unit then
        local _, class = UnitClass(unit)
        if ns.R then class = ns.R(class) end
        c = class
    end
    if not c then return nil end
    local cc = (colors and colors.class[c]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[c])
    if cc then return cc.r, cc.g, cc.b end
    return nil
end

-- Color of a resource (MANA, RAGE, ENERGY...), from the Colors page
function ns.PowerColorOf(token)
    local c = token and ((ns.P and ns.P.colors and ns.P.colors.power[token]) or (PowerBarColor and PowerBarColor[token]))
    if c then return c.r, c.g, c.b end
    return 0.3, 0.5, 1
end
