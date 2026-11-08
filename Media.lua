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

local TEXTURES = {
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

-- Listas { valor, etiqueta } para los desplegables
function ns.FontList() return Merge(FONTS, "font") end
function ns.TextureList() return Merge(TEXTURES, "statusbar") end

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
