-------------------------------------------------------------------------------
-- MendFrames - Fuentes y texturas
-- Las de Blizzard siempre; si otro addon carga LibSharedMedia-3.0 se añaden
-- también todas las suyas.
-------------------------------------------------------------------------------

local _, ns = ...

local FONTS = {
    { "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
    { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "Skurri", "Fonts\\skurri.ttf" },
    { "Morpheus", "Fonts\\MORPHEUS.ttf" },
}

-- Texturas que trae el propio addon (carpeta Media)
local DARK = "Interface\\AddOns\\MendFrames\\Media\\Dark"
ns.TEX_DARK = DARK

local TEXTURES = {
    { "MendFrames · Oscura", DARK },
    { "Plano", "Interface\\Buttons\\WHITE8X8" },
    { "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
    { "Blizzard (banda)", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { "Blizzard (recurso)", "Interface\\RaidFrame\\Raid-Bar-Resource-Fill" },
    { "Brillo", "Interface\\TargetingFrame\\BarFill2" },
    { "Lisa", "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
}

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function Merge(base, mediaType)
    local out, seen = {}, {}
    for _, e in ipairs(base) do
        out[#out + 1] = { e[2], e[1] }
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

-- Registrar nuestras texturas en LibSharedMedia para que otros addons las usen
local function RegisterMedia()
    local lsm = LSM()
    if lsm then lsm:Register("statusbar", "MendFrames Dark", DARK) end
end
RegisterMedia()
local regFrame = CreateFrame("Frame")
regFrame:RegisterEvent("PLAYER_LOGIN")
regFrame:SetScript("OnEvent", RegisterMedia)

-- Listas { valor, etiqueta } para los desplegables.
-- En las fuentes, el 3er campo es la fuente con la que se pinta la etiqueta.
function ns.FontList()
    local list = Merge(FONTS, "font")
    for _, o in ipairs(list) do o[3] = o[1] end
    return list
end
-- En las texturas, el 4º campo es la textura que se enseña de muestra detrás
function ns.TextureList()
    local list = Merge(TEXTURES, "statusbar")
    for _, o in ipairs(list) do o[4] = o[1] end
    return list
end

ns.OUTLINES = {
    { "", "Sin contorno" },
    { "OUTLINE", "Contorno" },
    { "THICKOUTLINE", "Contorno grueso" },
    { "MONOCHROME", "Monocromo" },
    { "OUTLINE, MONOCHROME", "Contorno monocromo" },
}

-- Aplica una fuente; si la ruta no vale, usa la estándar
function ns.SetFont(fs, font, size, outline)
    outline = outline or ""
    local ok = pcall(fs.SetFont, fs, font or ns.FONT, size, outline)
    if not ok or not fs:GetFont() then
        fs:SetFont(STANDARD_TEXT_FONT, size, outline)
    end
end

-------------------------------------------------------------------------------
-- Estilo común de cualquier texto (nombre, vida, estado, tiempo, cargas):
-- { font, size, outline, colorMode = white|class|custom, color, point, x, y }
-------------------------------------------------------------------------------
-- dx, dy: ajuste extra (p. ej. para que el texto no se salga de un icono)
function ns.StyleText(fs, t, anchor, dx, dy)
    ns.SetFont(fs, t.font, t.size or 10, t.outline or "")
    fs:ClearAllPoints()
    local p = t.point or "CENTER"
    fs:SetPoint(p, anchor, p, (t.x or 0) + (dx or 0), (t.y or 0) + (dy or 0))
    fs:SetJustifyH(p:find("LEFT") and "LEFT" or (p:find("RIGHT") and "RIGHT" or "CENTER"))
end

-- r, g, b: color de clase de la unidad (si se conoce)
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

-- Color de clase de una unidad (si el juego lo deja leer)
function ns.ClassColorOf(unit)
    if not unit then return nil end
    local _, c = UnitClass(unit)
    c = ns.R and ns.R(c) or c
    local cc = c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]
    if cc then return cc.r, cc.g, cc.b end
    return nil
end
