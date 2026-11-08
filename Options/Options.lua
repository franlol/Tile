-------------------------------------------------------------------------------
-- MendFrames - Ventana de opciones (/mf)
-------------------------------------------------------------------------------

local _, ns = ...
local UI = ns.UI
local ACCENT = UI.ACCENT

local win
local pages, navs = {}, {}
local COL1, COL2 = 10, 290

-- Enlace con el perfil que se está editando
local function PB(path, after)
    return UI.Bind(ns.EP, path, function(v)
        if after then after(v) end
        ns.ProfileChanged()
        UI.RefreshAll()
    end)
end

local function Refresh() UI.RefreshAll() end

-- cuando la búsqueda en segundo plano encuentra el ID de un nombre
ns.OnSpellResolved = function()
    if ns.testing and ns.LayoutTest then ns.LayoutTest() end
    if win and win:IsShown() then UI.RefreshAll() end
end

-------------------------------------------------------------------------------
-- Perfiles
-------------------------------------------------------------------------------
local function ProfileOptions()
    local out = {}
    for name in pairs(ns.db.profiles) do out[#out + 1] = { name, name } end
    table.sort(out, function(a, b)
        if a[1] == "Default" then return true end
        if b[1] == "Default" then return false end
        return a[1] < b[1]
    end)
    return out
end

local function BuildProfiles(p)
    local _, c = UI.ScrollPage(p)

    local activeNote = UI.Note(c, "", 520)
    local nameBox
    local function NameInput()
        local n = nameBox:GetText():trim()
        if n == "" then ns.Print("escribe un nombre para el perfil.") return nil end
        return n
    end
    local function Reassign(old, new)
        for _, chars in pairs(ns.db.chars) do
            for k, v in pairs(chars) do if v == old then chars[k] = new end end
        end
    end

    local actions = CreateFrame("Frame", nil, c)
    actions:SetSize(520, 46)
    local lbl = UI.Label(actions, "Nombre:")
    lbl:SetPoint("TOPLEFT", 0, -4)
    nameBox = UI.EditBox(actions, 170)
    nameBox:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    local function Btn(text, x, func)
        local b = UI.Button(actions, text, 80, 20, func)
        b:SetPoint("TOPLEFT", x, -26)
        return b
    end
    Btn("Nuevo", 0, function()
        local n = NameInput()
        if not n then return end
        if ns.db.profiles[n] then ns.Print("ya existe un perfil con ese nombre.") return end
        ns.db.profiles[n] = ns.NewProfile()
        ns.editName = n
        nameBox:SetText("")
        Refresh()
    end)
    Btn("Copiar", 86, function()
        local n = NameInput()
        if not n then return end
        if ns.db.profiles[n] then ns.Print("ya existe un perfil con ese nombre.") return end
        ns.db.profiles[n] = ns.DeepCopy(ns.EP())
        ns.editName = n
        nameBox:SetText("")
        Refresh()
    end)
    Btn("Renombrar", 172, function()
        local n = NameInput()
        local old = ns.EditedProfileName()
        if not n or n == old then return end
        if old == "Default" then ns.Print("el perfil Default no se puede renombrar (cópialo).") return end
        if ns.db.profiles[n] then ns.Print("ya existe un perfil con ese nombre.") return end
        ns.db.profiles[n] = ns.db.profiles[old]
        ns.db.profiles[old] = nil
        Reassign(old, n)
        ns.editName = n
        if ns.activeName == old then ns.activeName = n end
        nameBox:SetText("")
        Refresh()
    end)
    Btn("Borrar", 258, function()
        local old = ns.EditedProfileName()
        if old == "Default" then ns.Print("el perfil Default no se puede borrar.") return end
        ns.db.profiles[old] = nil
        Reassign(old, "Default")
        ns.editName = nil
        ns.ActivateProfile(true)
        Refresh()
    end)
    Btn("Restablecer", 344, function()
        local name = ns.EditedProfileName()
        ns.db.profiles[name] = ns.NewProfile()
        ns.ActivateProfile(true)
        ns.ProfileChanged()
        Refresh()
        ns.Print(("perfil '%s' restablecido."):format(name))
    end)

    local list = {
        UI.Header(c, "Perfil que estás editando"),
        UI.Dropdown(c, nil, ProfileOptions, ns.EditedProfileName, function(v)
            ns.editName = v
            Refresh()
        end),
        activeNote,
        actions,
        UI.Header(c, "Qué perfil usa este personaje según el grupo"),
    }
    for _, key in ipairs(ns.SIZE_KEYS) do
        list[#list + 1] = UI.Dropdown(c, ns.SIZE_NAMES[key], ProfileOptions,
            function() return ns.CharProfiles()[key] end,
            function(v)
                ns.CharProfiles()[key] = v
                ns.ActivateProfile()
                Refresh()
            end)
    end
    list[#list + 1] = UI.Note(c, "Así puedes tener un diseño para grupo, otro para ZG/AQ20 y otro para bandas de 40. El cambio es automático al entrar o salir de un grupo (si estás en combate, se aplica al salir).", 520)
    list[#list + 1] = UI.Header(c, "Vista previa")
    list[#list + 1] = UI.Dropdown(c, "Simular un grupo de", {
        { "party", "5 (grupo)" }, { "raid10", "10 (banda)" }, { "raid20", "20 (banda)" }, { "raid40", "40 (banda)" },
    }, function() return ns.testSize or "raid20" end, function(v)
        ns.ToggleTest(true, v)
        Refresh()
    end)
    list[#list + 1] = UI.Note(c, "El modo prueba muestra el perfil asignado a ese tamaño. Lo que cambies se ve al momento si editas ese mismo perfil.", 520)
    list[#list + 1] = UI.Header(c, "General")
    list[#list + 1] = UI.Check(c, "Ocultar marcos de grupo y banda de Blizzard (requiere /reload)",
        function() return ns.db.hideBlizzard end,
        function(v) ns.db.hideBlizzard = v ns.Print("se aplica tras /reload.") end)

    local st = UI.Stack(c, COL1, -6, list)
    UI.FitContent(c, { st })

    p.OnShow = function()
        activeNote.text:SetText(("Activo ahora: |cffffffff%s|r (%s). Si eliges otro, editas ese aunque no se esté viendo."):format(
            tostring(ns.activeName), ns.SIZE_NAMES[ns.SizeKey()] or "?"))
    end
end

-------------------------------------------------------------------------------
-- Diseño
-------------------------------------------------------------------------------
local function BuildLayout(p)
    local _, c = UI.ScrollPage(p)
    local function E(w, cond) w.enableIf = cond return w end
    local a = UI.Stack(c, COL1, -6, {
        UI.Header(c, "Tamaño"),
        UI.Slider(c, "Ancho", 30, 200, 1, nil, PB("layout.width")),
        UI.Slider(c, "Alto", 16, 100, 1, nil, PB("layout.height")),
        UI.Slider(c, "Escala", 0.5, 2, 0.05, UI.pct, PB("layout.scale")),
        UI.Slider(c, "Espacio entre jugadores", 0, 12, 1, nil, PB("layout.spacing")),
        UI.Slider(c, "Espacio entre grupos", 0, 40, 1, nil, PB("layout.groupSpacing")),
        UI.Header(c, "Mascotas"),
        UI.Check(c, "Mostrar mascotas", PB("pets.enabled")),
        UI.Check(c, "Pegadas a la banda, como un grupo más", PB("pets.attach")),
        UI.Check(c, "Mismo tamaño que los jugadores", PB("pets.sameSize")),
        UI.Attach(E(UI.Slider(c, "Ancho de mascota", 30, 200, 1, nil, PB("pets.width")),
            function() return not ns.EP().pets.sameSize end)),
        UI.Attach(E(UI.Slider(c, "Alto de mascota", 12, 100, 1, nil, PB("pets.height")),
            function() return not ns.EP().pets.sameSize end)),
        UI.Slider(c, "Mascotas por columna/fila", 1, 10, 1, nil, PB("pets.perColumn")),
    })
    local list = {
        UI.Header(c, "Organización"),
        UI.Dropdown(c, "Orientación", {
            { "vertical", "Vertical (cada grupo, una columna)" },
            { "horizontal", "Horizontal (cada grupo, una fila)" },
        }, PB("layout.orientation")),
        UI.Dropdown(c, "Agrupar por", {
            { "GROUP", "Grupo de banda" },
            { "ROLE", "Rol (tanque, sanador, daño)" },
            { "CLASS", "Clase" },
        }, PB("layout.groupBy")),
        UI.Check(c, "Ordenar por nombre dentro del grupo", PB("layout.sortByName")),
        UI.Check(c, "Mostrar en grupo (no solo en banda)", PB("layout.showParty")),
        UI.Check(c, "Mostrarme a mí", PB("layout.showPlayer")),
        UI.Check(c, "Mostrar estando solo", PB("layout.showSolo")),
        UI.Header(c, "Grupos que se muestran"),
    }
    for i = 1, 8 do
        list[#list + 1] = UI.Check(c, "Grupo " .. i, PB("layout.groups." .. i))
    end
    local b = UI.Stack(c, COL2, -6, list)
    UI.FitContent(c, { a, b })
end

-------------------------------------------------------------------------------
-- Barras
-------------------------------------------------------------------------------
local function BuildBars(p)
    local _, c = UI.ScrollPage(p)
    local function Col(path) return function() return UI.Bind(ns.EP, path)() end end
    local function E(w, cond) w.enableIf = cond return w end
    local barSwatch = UI.Attach(UI.Swatch(c, "Color de la barra", Col("bars.customColor"), ns.ProfileChanged))
    barSwatch.enableIf = function() return ns.EP().bars.healthColor == "custom" end
    local bgSwatch = UI.Attach(UI.Swatch(c, "Color del fondo", Col("bars.bgCustom"), ns.ProfileChanged))
    bgSwatch.enableIf = function() return ns.EP().bars.bgColor == "custom" end

    local a = UI.Stack(c, COL1, -6, {
        UI.Header(c, "Vida"),
        UI.Dropdown(c, "Textura de la vida", ns.TextureList, PB("bars.healthTex")),
        E(UI.Check(c, ns.hasNativeSmooth and "Llenado y vaciado suave"
            or "Llenado y vaciado suave (no disponible en este cliente)", PB("bars.smooth")),
            function() return ns.hasNativeSmooth end),
        UI.Attach(UI.Dropdown(c, "Color de la barra", {
            { "class", "Color de clase" },
            { "custom", "Un solo color" },
            { "gradient", "Degradado según la vida" },
        }, PB("bars.healthColor"))),
        barSwatch,
        E(UI.Attach(UI.Slider(c, "Brillo de la barra", 0.1, 1, 0.05, UI.pct, PB("bars.healthBrightness"))),
            function() return ns.EP().bars.healthColor ~= "custom" end),
        UI.Dropdown(c, "Textura del fondo (vida que falta)", ns.TextureList, PB("bars.bgTex")),
        UI.Attach(UI.Dropdown(c, "Color del fondo", {
            { "class", "Color de clase" },
            { "custom", "Un solo color" },
            { "gradient", "Degradado según la vida" },
        }, PB("bars.bgColor"))),
        bgSwatch,
        E(UI.Attach(UI.Slider(c, "Brillo del fondo", 0.1, 1, 0.05, UI.pct, PB("bars.bgBrightness"))),
            function() return ns.EP().bars.bgColor ~= "custom" end),
        UI.Slider(c, "Opacidad del fondo", 0, 1, 0.05, UI.pct, PB("bars.bgAlpha")),
        UI.Swatch(c, "Color del borde", Col("bars.borderColor"), ns.ProfileChanged, true),
        UI.Header(c, "Maná / energía / ira"),
        UI.Check(c, "Mostrar barra", PB("bars.showPower")),
        E(UI.Check(c, ns.hasNativeSmooth and "Llenado y vaciado suave"
            or "Llenado y vaciado suave (no disponible en este cliente)", PB("bars.powerSmooth")),
            function() return ns.hasNativeSmooth end),
        UI.Check(c, "Solo para quien usa maná", PB("bars.powerOnlyMana")),
        UI.Dropdown(c, "Textura", ns.TextureList, PB("bars.powerTex")),
        UI.Slider(c, "Alto", 1, 12, 1, nil, PB("bars.powerHeight")),
    })
    local b = UI.Stack(c, COL2, -6, {
        UI.Header(c, "Curación y escudos"),
        UI.Check(c, "Curación entrante", PB("bars.showHealPred")),
        UI.Attach(UI.Swatch(c, "Color de curación entrante", Col("bars.healPredColor"), ns.ProfileChanged, true)),
        UI.Check(c, "Escudos (absorción)", PB("bars.showAbsorb")),
        UI.Attach(UI.Swatch(c, "Color de escudos", Col("bars.absorbColor"), ns.ProfileChanged, true)),
        UI.Header(c, "Resaltados"),
        UI.Slider(c, "Opacidad fuera de rango", 0.1, 1, 0.05, UI.pct, PB("bars.rangeAlpha")),
        UI.Check(c, "Resaltar mi objetivo", PB("bars.targetHighlight")),
        UI.Attach(UI.Swatch(c, "Color del objetivo", Col("bars.targetColor"), ns.ProfileChanged, true)),
        UI.Check(c, "Marcar quien tiene amenaza (aggro)", PB("bars.aggro")),
        UI.Attach(UI.Swatch(c, "Color de amenaza", Col("bars.aggroColor"), ns.ProfileChanged, true)),
        UI.Header(c, "Tooltips"),
        UI.Dropdown(c, "Tooltip al pasar por un icono de aura", {
            { "always", "Siempre" }, { "ooc", "Solo fuera de combate" }, { "never", "Nunca" },
        }, PB("bars.auraTooltip")),
    })
    UI.FitContent(c, { a, b })
end

-------------------------------------------------------------------------------
-- Textos
-------------------------------------------------------------------------------
local function TextSection(c, key, title, extra)
    local base = "texts." .. key
    local function isCustom() return ns.EP().texts[key].colorMode == "custom" end
    local sw = UI.Attach(UI.Swatch(c, "Color", function() return ns.EP().texts[key].color end, ns.ProfileChanged))
    sw.enableIf = isCustom
    local list = {
        UI.Header(c, title),
        UI.Check(c, "Mostrar", PB(base .. ".show")),
    }
    for _, w in ipairs(extra or {}) do list[#list + 1] = w end
    for _, w in ipairs({
        UI.Dropdown(c, "Fuente", ns.FontList, PB(base .. ".font")),
        UI.Slider(c, "Tamaño", 6, 24, 1, nil, PB(base .. ".size")),
        UI.Dropdown(c, "Contorno", ns.OUTLINES, PB(base .. ".outline")),
        UI.Dropdown(c, "Color", {
            { "white", "Blanco" }, { "class", "Color de clase" }, { "custom", "Personalizado" },
        }, PB(base .. ".colorMode")),
        sw,
        UI.Dropdown(c, "Posición", UI.POINTS, PB(base .. ".point")),
        UI.Slider(c, "Desplazamiento X", -60, 60, 1, nil, PB(base .. ".x")),
        UI.Slider(c, "Desplazamiento Y", -40, 40, 1, nil, PB(base .. ".y")),
    }) do list[#list + 1] = w end
    return list
end

local function BuildTexts(p)
    local _, c = UI.ScrollPage(p)
    local nameList = TextSection(c, "name", "Nombre", {
        UI.Slider(c, "Ancho máximo (% del marco)", 30, 100, 1, function(v) return v .. "%" end, PB("texts.name.width")),
    })
    local statusList = TextSection(c, "status", "Estado (muerto, desconectado...)")
    for _, w in ipairs(statusList) do nameList[#nameList + 1] = w end
    local a = UI.Stack(c, COL1, -6, nameList)

    local b = UI.Stack(c, COL2, -6, TextSection(c, "health", "Texto de vida", {
        UI.Dropdown(c, "Formato", {
            { "none", "Ninguno" },
            { "deficit", "Vida que falta (-1.2k)" },
            { "percent", "Porcentaje (85%)" },
            { "current", "Vida actual (3.4k)" },
            { "both", "Actual / máxima" },
        }, PB("texts.health.format")),
        UI.Check(c, "Ocultar con la vida llena", PB("texts.health.hideFull")),
    }))
    UI.FitContent(c, { a, b })
end

-------------------------------------------------------------------------------
-- Iconos de estado
-------------------------------------------------------------------------------
local function ElementSection(c, key, title)
    local base = "elements." .. key
    return {
        UI.Header(c, title),
        UI.Check(c, "Mostrar", PB(base .. ".show")),
        UI.Dropdown(c, "Posición", UI.POINTS, PB(base .. ".point")),
        UI.Slider(c, "Desplazamiento X", -60, 60, 1, nil, PB(base .. ".x")),
        UI.Slider(c, "Desplazamiento Y", -40, 40, 1, nil, PB(base .. ".y")),
        UI.Slider(c, "Tamaño", 6, 40, 1, nil, PB(base .. ".size")),
    }
end

local function BuildElements(p)
    local _, c = UI.ScrollPage(p)
    local l1 = ElementSection(c, "role", "Icono de rol")
    for _, w in ipairs(ElementSection(c, "raidIcon", "Marca de banda (calavera, etc.)")) do l1[#l1 + 1] = w end
    local l2 = ElementSection(c, "leader", "Líder / ayudante")
    for _, w in ipairs(ElementSection(c, "ready", "Comprobación de listos")) do l2[#l2 + 1] = w end
    local a = UI.Stack(c, COL1, -6, l1)
    local b = UI.Stack(c, COL2, -6, l2)
    UI.FitContent(c, { a, b })
end

-------------------------------------------------------------------------------
-- Panel lateral de resaltado (único para todo)
-- Se abre con un "contexto":
--   title()      -> nombre, icono
--   sub          -> texto explicativo
--   load()       -> estilo guardado o nil
--   store(s)     -> guardar un estilo nuevo (excepciones)
--   clear()      -> quitar / restablecer
--   fallback()   -> estilo que se usa si no hay propio (el del indicador)
--   onChange()   -> tras cualquier cambio
--   preview      -> qué enseñar en el modo prueba
--   onClose()
-------------------------------------------------------------------------------
local side, sideCtx

local function St(create)
    if not sideCtx then return nil end
    local s = sideCtx.load()
    if not s and create then
        local base = sideCtx.fallback and sideCtx.fallback() or ns.STYLE_DEFAULTS
        s = ns.CopyDefaults(ns.STYLE_DEFAULTS, ns.DeepCopy(base))
        sideCtx.store(s)
    end
    return s
end

local function Shown()
    return St(false) or (sideCtx and sideCtx.fallback and sideCtx.fallback()) or ns.STYLE_DEFAULTS
end

local function SetPreview()
    ns.preview = sideCtx and sideCtx.preview or nil
    if ns.testing then ns.LayoutTest() end
end

local function CloseSide()
    if not sideCtx then return end
    local ctx = sideCtx
    sideCtx = nil
    side:Hide()
    SetPreview()
    if ctx.onClose then ctx.onClose() end
end

local function OpenSide(ctx)
    sideCtx = ctx
    side:Show()
    SetPreview()
    UI.RefreshAll()
end

local function BuildSide()
    side = CreateFrame("Frame", nil, win, "BackdropTemplate")
    side:SetSize(290, 600)
    side:SetPoint("TOPLEFT", win, "TOPRIGHT", 4, 0)
    UI.Backdrop(side, { 0.06, 0.06, 0.08, 0.97 }, { 0.2, 0.2, 0.25, 1 })
    side:EnableMouse(true)
    side:Hide()

    side.icon = side:CreateTexture(nil, "ARTWORK")
    side.icon:SetSize(24, 24)
    side.icon:SetPoint("TOPLEFT", 12, -12)
    side.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    side.title = UI.Label(side, "", "GameFontNormal")
    side.title:SetPoint("LEFT", side.icon, "RIGHT", 8, 0)
    side.title:SetWidth(210)
    side.title:SetWordWrap(false)
    side.sub = UI.Label(side, "")
    side.sub:SetPoint("TOPLEFT", 12, -42)
    side.sub:SetWidth(266)
    side.sub:SetTextColor(0.7, 0.7, 0.7)
    side.state = UI.Label(side, "")
    side.state:SetPoint("TOPLEFT", side.sub, "BOTTOMLEFT", 0, -4)
    side.state:SetWidth(266)
    local close = UI.Button(side, "X", 22, 20, CloseSide)
    close:SetPoint("TOPRIGHT", -8, -8)

    local holder = CreateFrame("Frame", nil, side)
    holder:SetPoint("TOPLEFT", 6, -96)
    holder:SetPoint("BOTTOMRIGHT", -6, 70)
    local _, c = UI.ScrollPage(holder)
    c:SetWidth(270)
    local function Changed()
        if sideCtx and sideCtx.onChange then sideCtx.onChange() end
        if ns.testing then ns.LayoutTest() end
        UI.RefreshAll()
    end
    local function SG(field)
        return function() return Shown()[field] end,
            function(v) St(true)[field] = v Changed() end
    end
    local function Col(field) return function() return Shown()[field] end end
    local function ColEdit(field) return function() return St(true)[field] end end
    local function V(field) return Shown()[field] end
    local function W(w, cond) w.showIf = cond return w end
    -- en el panel de resaltado todo son sub-opciones: se desactivan sin moverse
    local function E(w, cond) w.enableIf = cond return w end
    local function hasGlow() return sideCtx ~= nil and V("glow") ~= "none" end
    -- efectos con gráficos de Blizzard (tienen color original)
    local function blizzGlow()
        local g = sideCtx and V("glow")
        return g and g ~= "none" and g ~= "pixel" and g ~= "autocast"
    end

    -- aviso si este cliente no tiene el efecto elegido
    local fallbackNote = UI.Note(c, "", 260)
    fallbackNote.text:SetTextColor(1, 0.55, 0.3)
    fallbackNote.Refresh = function()
        local g = sideCtx and V("glow")
        -- siempre ocupa el mismo hueco, tenga aviso o no (sin saltos)
        fallbackNote:SetHeight(28)
        fallbackNote.text:SetText("")
        if not g or g == "none" then fallbackNote.active = false return end
        local probe = side.probe or CreateFrame("Frame", nil, side)
        side.probe = probe
        probe:SetSize(30, 30)
        probe:SetPoint("BOTTOM", side, "BOTTOM", 0, -100)
        probe:SetAlpha(0)
        local used = ns.Glow.Start(probe, g, nil, {})
        ns.Glow.Stop(probe)
        fallbackNote.active = used ~= g
        if fallbackNote.active then
            fallbackNote.text:SetText(("Este cliente no tiene «%s»; se verá como «%s»."):format(
                ns.Glow.NAMES[g] or g, used and ns.Glow.NAMES[used] or "nada"))
            fallbackNote:SetHeight(math.max(28, fallbackNote.text:GetStringHeight() + 2))
        end
    end
    table.insert(UI.widgets, fallbackNote)

    local st = UI.Stack(c, 6, -2, {
        UI.Header(c, "Brillo"),
        UI.Dropdown(c, "Tipo de brillo", ns.Glow.TYPES, SG("glow")),
        E(UI.Dropdown(c, "Dónde", { { "icon", "En el icono" }, { "frame", "En todo el marco" } }, SG("target")), hasGlow),
        E(UI.Check(c, "Usar el color original de Blizzard", SG("keepColor")), blizzGlow),
        E(UI.Attach(UI.Swatch(c, "Color del brillo", Col("color"), Changed, true, ColEdit("color"))),
            function() return hasGlow() and not (blizzGlow() and V("keepColor")) end),
        fallbackNote,
        E(UI.Slider(c, "Líneas", 4, 16, 1, nil, SG("lines")), function() return V("glow") == "pixel" end),
        E(UI.Slider(c, "Grosor", 1, 4, 1, nil, SG("thickness")), function() return V("glow") == "pixel" end),
        E(UI.Slider(c, "Grupos de chispas", 1, 8, 1, nil, SG("particles")), function() return V("glow") == "autocast" end),
        E(UI.Slider(c, "Tamaño del brillo", 0.5, 2.5, 0.05, UI.pct, SG("glowScale")), hasGlow),
        E(UI.Slider(c, "Velocidad", 0.05, 1, 0.05, function(v) return ("%d%%"):format(v * 400 + 0.5) end, SG("freq")),
            hasGlow),
        E(UI.Slider(c, "Desplazamiento X", -30, 30, 1, nil, SG("offsetX")), hasGlow),
        E(UI.Slider(c, "Desplazamiento Y", -30, 30, 1, nil, SG("offsetY")), hasGlow),

        UI.Header(c, "Marco"),
        UI.Check(c, "Borde de color en el marco", SG("border")),
        E(UI.Attach(UI.Swatch(c, "Color del borde", Col("borderColor"), Changed, true, ColEdit("borderColor"))),
            function() return V("border") end),
        UI.Check(c, "Teñir la barra de vida", SG("tint")),
        E(UI.Attach(UI.Swatch(c, "Color del tinte", Col("tintColor"), Changed, true, ColEdit("tintColor"))),
            function() return V("tint") end),

        UI.Header(c, "Elemento"),
        UI.Check(c, "Latido (parpadeo suave)", SG("pulse")),
        UI.Slider(c, "Tamaño", 0.5, 2.5, 0.05, UI.pct, SG("scale")),

        UI.Header(c, "Sonido"),
        UI.Dropdown(c, "Sonido al aparecer", ns.SOUNDS, SG("sound")),
        E(UI.Attach(UI.Check(c, "Solo si me lo ponen a mí", SG("soundOnlyMe"))), function() return V("sound") ~= "none" end),
    })

    local copy = UI.Button(side, "Copiar del indicador", 266, 22, function()
        if not (sideCtx and sideCtx.fallback) then return end
        local s = ns.CopyDefaults(ns.STYLE_DEFAULTS, ns.DeepCopy(sideCtx.fallback() or ns.STYLE_DEFAULTS))
        sideCtx.store(s)
        Changed()
    end)
    copy:SetPoint("BOTTOMLEFT", 12, 40)
    local test = UI.Button(side, "Probar sonido", 120, 22, function() ns.PlayAlert(V("sound"), true) end)
    test:SetPoint("BOTTOMLEFT", 12, 12)
    local reset = UI.Button(side, "", 140, 22, function()
        if sideCtx and sideCtx.clear then sideCtx.clear() end
        Changed()
    end)
    reset:SetPoint("BOTTOMRIGHT", -12, 12)

    side.Refresh = function()
        if not sideCtx then side:Hide() return end
        local name, icon = sideCtx.title()
        side.icon:SetTexture(icon or 134400)
        side.title:SetText(name or "")
        side.sub:SetText(sideCtx.sub or "")
        local own = sideCtx.load() ~= nil
        if sideCtx.fallback then
            copy:Show()
            reset.text:SetText("Quitar el propio")
            reset:SetShown(own)
            side.state:SetText(own and "|cff55ff55Tiene resaltado propio|r (sustituye al del indicador)."
                or "|cffaaaaaaAhora usa el del indicador.|r Cambia cualquier opción para crear uno propio.")
        else
            copy:Hide()
            reset.text:SetText("Restablecer")
            reset:Show()
            side.state:SetText("")
        end
        st:Layout()
        UI.FitContent(c, { st })
    end
end

-- Abrir el panel para el resaltado de un indicador
local function OpenIndicatorStyle(cfg)
    OpenSide({
        title = function()
            local _, icon = ns.SpellKeyInfo(cfg.spells[1])
            return cfg.name, icon
        end,
        sub = "Resaltado del indicador: se aplica siempre que se muestra, salvo en los hechizos que tengan uno propio.",
        load = function() return cfg.hl end,
        clear = function() cfg.hl = ns.DeepCopy(ns.STYLE_DEFAULTS) end,
        onChange = ns.ProfileChanged,
        preview = { cfg = cfg },
    })
end

-- Abrir el panel para la excepción de un hechizo dentro de un indicador
local function OpenSpellStyle(cfg, key)
    OpenSide({
        title = function() return ns.SpellKeyInfo(key) end,
        sub = ("Excepción dentro de «%s»."):format(cfg.name),
        load = function() return cfg.spellStyles[key] end,
        store = function(s) cfg.spellStyles[key] = s end,
        clear = function() cfg.spellStyles[key] = nil end,
        fallback = function() return cfg.hl end,
        onChange = ns.ProfileChanged,
        preview = { cfg = cfg, key = key },
    })
end

-- Indicador "Debuff de banda" del perfil editado
local function RaidIndicator()
    for _, ind in ipairs(ns.EP().indicators) do
        if ind.kind == "raiddebuff" then return ind end
    end
end

-------------------------------------------------------------------------------
-- Indicadores
-------------------------------------------------------------------------------
local selInd = 1
local KIND_LABEL = { aura = "", raiddebuff = "banda", debuffs = "debuffs", dispel = "disipar" }
local TYPE_LABEL = { icon = "icono", icons = "iconos", square = "cuadrado", bar = "barra", text = "texto",
    border = "borde", overlay = "tinte" }

local function Inds() return ns.EP().indicators end
local function Sel()
    local list = Inds()
    if selInd > #list then selInd = #list end
    if selInd < 1 then selInd = 1 end
    return list[selInd]
end

local function EffType(ind)
    if ind.kind == "raiddebuff" then return "icon" end
    if ind.kind == "debuffs" then return "icons" end
    return ind.type
end

local function IndChanged()
    ns.ProfileChanged()
    UI.RefreshAll()
end

local function IB(path) return UI.Bind(Sel, path, IndChanged) end

local function BuildIndicators(p)
    -- lista de la izquierda
    local left = CreateFrame("Frame", nil, p)
    left:SetPoint("TOPLEFT", 6, -4)
    left:SetSize(196, 520)
    local ROWS = 16
    local offset = 0
    local rows = {}
    local listBg = CreateFrame("Frame", nil, left, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT")
    listBg:SetSize(196, ROWS * 20 + 4)
    UI.Backdrop(listBg, { 0.04, 0.04, 0.05, 1 })
    listBg:EnableMouseWheel(true)

    local function RefreshList()
        local list = Inds()
        offset = math.max(0, math.min(offset, #list - ROWS))
        for i, row in ipairs(rows) do
            local idx = i + offset
            local ind = list[idx]
            row.idx = idx
            if ind then
                row.name:SetText(ind.name)
                row.name:SetTextColor(ind.enabled and 1 or 0.45, ind.enabled and 1 or 0.45, ind.enabled and 1 or 0.45)
                local tag = KIND_LABEL[ind.kind] ~= "" and KIND_LABEL[ind.kind] or TYPE_LABEL[ind.type] or ""
                row.tag:SetText(tag)
                local col = ind.color or { r = 1, g = 1, b = 1 }
                if ind.kind ~= "aura" then
                    row.swatch:SetColorTexture(0.6, 0.6, 0.6, 1)
                else
                    row.swatch:SetColorTexture(col.r, col.g, col.b, 1)
                end
                row.sel:SetShown(idx == selInd)
                row:Show()
            else
                row:Hide()
            end
        end
    end
    listBg:SetScript("OnMouseWheel", function(_, d)
        offset = math.max(0, offset - d)
        RefreshList()
    end)

    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, listBg)
        row:SetSize(192, 19)
        row:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 20)
        row.sel = row:CreateTexture(nil, "BACKGROUND")
        row.sel:SetAllPoints()
        row.sel:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.25)
        row.hl = row:CreateTexture(nil, "HIGHLIGHT")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(1, 1, 1, 0.08)
        row.swatch = row:CreateTexture(nil, "ARTWORK")
        row.swatch:SetSize(8, 8)
        row.swatch:SetPoint("LEFT", 4, 0)
        row.name = UI.Label(row, "")
        row.name:SetPoint("LEFT", 16, 0)
        row.name:SetWidth(120)
        row.name:SetWordWrap(false)
        row.tag = UI.Label(row, "")
        row.tag:SetPoint("RIGHT", -4, 0)
        row.tag:SetTextColor(0.55, 0.55, 0.55)
        row:SetScript("OnClick", function(self)
            selInd = self.idx
            UI.CloseMenu()
            CloseSide()
            UI.RefreshAll()
        end)
        rows[i] = row
    end

    local y = -(ROWS * 20 + 10)
    local function Btn(text, x, yy, w, func)
        local b = UI.Button(left, text, w, 20, func)
        b:SetPoint("TOPLEFT", x, yy)
        return b
    end
    Btn("Nuevo", 0, y, 62, function()
        local ind = ns.FixIndicator({ name = "Nuevo indicador" })
        local list = Inds()
        -- antes de los genéricos para que quede junto a los demás
        table.insert(list, ind)
        selInd = #list
        IndChanged()
    end)
    Btn("Borrar", 66, y, 62, function()
        local ind = Sel()
        if not ind then return end
        if ind.kind ~= "aura" then
            ns.Print("los indicadores integrados no se borran; desactívalos con la casilla 'Activo'.")
            return
        end
        table.remove(Inds(), selInd)
        IndChanged()
    end)
    Btn("^", 132, y, 30, function()
        local l = Inds()
        if selInd > 1 then l[selInd], l[selInd - 1] = l[selInd - 1], l[selInd] selInd = selInd - 1 IndChanged() end
    end)
    Btn("v", 166, y, 30, function()
        local l = Inds()
        if selInd < #l then l[selInd], l[selInd + 1] = l[selInd + 1], l[selInd] selInd = selInd + 1 IndChanged() end
    end)

    Btn("Añadir desde el catálogo...", 0, y - 28, 196, function()
        if ns.OpenCatalog then ns.OpenCatalog() end
    end)
    local hint = UI.Note(left, "El orden de la lista es el orden de dibujo: los de abajo quedan por encima.", 196)
    hint:SetPoint("TOPLEFT", 0, y - 56)

    -- editor de la derecha
    local right = CreateFrame("Frame", nil, p)
    right:SetPoint("TOPLEFT", 212, -4)
    right:SetPoint("BOTTOMRIGHT", -4, 4)
    local _, c = UI.ScrollPage(right)
    c:SetWidth(380)
    local function K() local s = Sel() return s and s.kind end
    local function T() local s = Sel() return s and EffType(s) end
    local function isAura() return K() == "aura" end
    local function notDispel() return K() ~= "dispel" end
    local function iconLike() local t = T() return t == "icon" or t == "icons" end
    local function rect() local t = T() return t == "square" or t == "bar" end
    local function iconsT() return T() == "icons" end
    local function colored() local t = T() return isAura() and (t == "square" or t == "bar" or t == "text") end
    local function isMissing() local s = Sel() return isAura() and s.mode == "missing" end
    -- tiene duración (no es "le falta" ni disipable)
    local function timed() return notDispel() and not isMissing() end
    local function hasText() return timed() end

    local function W(widget, cond) widget.showIf = cond return widget end
    -- WE: se ve según el tipo y se desactiva (sin moverse) según una sub-opción
    local function WE(widget, show, enable) widget.showIf = show widget.enableIf = enable return widget end

    -- nombre
    local nameW = CreateFrame("Frame", nil, c)
    nameW:SetSize(UI.W, 36)
    local nl = UI.Label(nameW, "Nombre")
    nl:SetPoint("TOPLEFT")
    local nameBox = UI.EditBox(nameW, UI.W)
    nameBox:SetPoint("TOPLEFT", 0, -14)
    local function SaveName()
        local s = Sel()
        local t = nameBox:GetText():trim()
        if s and t ~= "" and t ~= s.name then s.name = t RefreshList() end
    end
    nameBox:SetScript("OnEnterPressed", function(self) SaveName() self:ClearFocus() end)
    nameBox:SetScript("OnEditFocusLost", SaveName)
    nameW.Refresh = function() local s = Sel() nameBox:SetText(s and s.name or "") end
    table.insert(UI.widgets, nameW)

    -- lista de hechizos del indicador (field = "spells" o "blacklist")
    -- Cada hechizo puede desplegar sus IDs ("Ver IDs"). Sin ninguno marcado
    -- cuentan todos; si se marca alguno, solo los marcados.
    local MAXS = 12
    local expanded = {}   -- [indicador] = { [clave] = true }

    local function IsOpen(s, key) return expanded[s] and expanded[s][key] end

    local function SpellList(field, withHighlight, addLabel)
        local wdg = CreateFrame("Frame", nil, c)
        wdg:SetSize(360, 40)
        local rows, subPool = {}, {}

        -- casilla de un ID (fila sangrada)
        local function SubRow(n)
            local sr = subPool[n]
            if sr then return sr end
            sr = CreateFrame("Button", nil, wdg)
            sr:SetSize(300, 16)
            sr.box = CreateFrame("Frame", nil, sr, "BackdropTemplate")
            sr.box:SetSize(12, 12)
            sr.box:SetPoint("LEFT", 0, 0)
            UI.Backdrop(sr.box, { 0.05, 0.05, 0.06, 1 })
            sr.mark = sr.box:CreateTexture(nil, "OVERLAY")
            sr.mark:SetPoint("TOPLEFT", 2, -2)
            sr.mark:SetPoint("BOTTOMRIGHT", -2, 2)
            sr.mark:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
            sr.icon = sr:CreateTexture(nil, "ARTWORK")
            sr.icon:SetSize(14, 14)
            sr.icon:SetPoint("LEFT", 18, 0)
            sr.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            -- tooltip del hechizo solo sobre su icono
            UI.IconTip(sr, sr.icon, function() return sr.icon:IsShown() and sr.spellID end)
            sr.id = UI.Label(sr, "")
            sr.id:SetPoint("LEFT", 38, 0)
            sr.id:SetWidth(70)
            sr.sub = UI.Label(sr, "")
            sr.sub:SetPoint("LEFT", 112, 0)
            sr.sub:SetWidth(180)
            sr.sub:SetWordWrap(false)
            sr.sub:SetTextColor(0.55, 0.55, 0.55)
            sr.hl = sr:CreateTexture(nil, "HIGHLIGHT")
            sr.hl:SetAllPoints()
            sr.hl:SetColorTexture(1, 1, 1, 0.05)
            sr:SetScript("OnClick", function(self)
                if self.onClick then self.onClick() return end
                if not self.spellID then return end
                local s = Sel()
                local pick = s.ranks[self.key]
                if type(pick) ~= "table" then pick = {} s.ranks[self.key] = pick end
                pick[self.spellID] = (not pick[self.spellID]) or nil
                if not next(pick) then s.ranks[self.key] = nil end
                s.exact[self.key] = nil
                IndChanged()
            end)
            subPool[n] = sr
            return sr
        end

        for i = 1, MAXS do
            local r = CreateFrame("Frame", nil, wdg)
            r:SetSize(340, 18)
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(16, 16)
            r.icon:SetPoint("LEFT")
            r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            -- tooltip del hechizo solo sobre el icono
            UI.IconTip(r, r.icon, function() return r.tipID end)
            r.name = UI.Label(r, "")
            r.name:SetPoint("LEFT", 20, 0)
            r.name:SetWidth(108)
            r.name:SetWordWrap(false)
            r.ids = UI.Button(r, "Ver IDs", 76, 16, function()
                local s = Sel()
                local key = s[field][i]
                if key == nil then return end
                expanded[s] = expanded[s] or {}
                expanded[s][key] = (not expanded[s][key]) or nil
                UI.RefreshAll()
            end)
            r.ids:SetPoint("LEFT", 132, 0)
            if withHighlight then
                -- excepción de resaltado de este hechizo
                r.hl = UI.Button(r, "brillo", 44, 16, function()
                    local s = Sel()
                    if s and s[field][i] ~= nil then OpenSpellStyle(s, s[field][i]) end
                end)
                r.hl:SetPoint("LEFT", 218, 0)
            end
            r.up = UI.Button(r, "^", 16, 16, function()
                local l = Sel()[field]
                if i > 1 then l[i], l[i - 1] = l[i - 1], l[i] IndChanged() end
            end)
            r.up:SetPoint("LEFT", 270, 0)
            r.del = UI.Button(r, "x", 16, 16, function()
                local s = Sel()
                local key = table.remove(s[field], i)
                if withHighlight and key ~= nil then s.spellStyles[key] = nil end
                if key ~= nil then s.exact[key] = nil s.ranks[key] = nil end
                CloseSide()
                IndChanged()
            end)
            r.del:SetPoint("LEFT", 290, 0)
            rows[i] = r
        end

        local addBox = UI.EditBox(wdg, 200)
        local addBtn = UI.Button(wdg, addLabel or "Añadir hechizo", 110, 20, function()
            local key = ns.ParseSpellInput(addBox:GetText())
            if not key then return end
            local l = Sel()[field]
            if #l >= MAXS then ns.Print("máximo " .. MAXS .. " hechizos en la lista.") return end
            table.insert(l, key)
            addBox:SetText("")
            addBox:ClearFocus()
            IndChanged()
        end)
        addBtn:SetPoint("LEFT", addBox, "RIGHT", 4, 0)
        addBox:SetScript("OnEnterPressed", function() addBtn:Click() end)

        wdg.Refresh = function()
            local s = Sel()
            local l = s and s[field] or {}
            for _, sr in ipairs(subPool) do sr:Hide() end
            local y, used = 0, 0
            for i, r in ipairs(rows) do
                local key = l[i]
                if key then
                    local name, icon = ns.SpellKeyInfo(key)
                    local pick = ns.KeyRank(s, key)
                    local all = ns.KeyIDs(key)
                    r.icon:SetTexture(icon or 134400)
                    r.tipID = all[1]
                    -- el nombre avisa si hay IDs elegidos a mano
                    local n = 0
                    if pick then for _ in pairs(pick) do n = n + 1 end end
                    r.name:SetText(n > 0 and ("%s |cff4fc3f7(%d)|r"):format(name, n) or name)
                    local open = IsOpen(s, key)
                    r.ids.text:SetText(open and "Ocultar IDs" or "Ver IDs")
                    if r.hl then
                        local own = ns.StyleActive(s.spellStyles[key])
                        r.hl.text:SetTextColor(own and ACCENT[1] or 0.6, own and ACCENT[2] or 0.6, own and ACCENT[3] or 0.6)
                    end
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", 0, y)
                    r:Show()
                    y = y - 19
                    if open then
                        if #all == 0 then
                            used = used + 1
                            local sr = SubRow(used)
                            sr.key, sr.spellID = key, nil
                            sr.onClick = nil
                            sr.icon:Hide()
                            sr.box:Hide()
                            sr.id:SetWidth(200)
                            sr.id:SetText("buscando IDs...")
                            sr.sub:SetText("")
                            sr:EnableMouse(false)
                            sr:ClearAllPoints()
                            sr:SetPoint("TOPLEFT", 24, y)
                            sr:Show()
                            y = y - 17
                        end
                        for _, id in ipairs(all) do
                            used = used + 1
                            local sr = SubRow(used)
                            sr.key, sr.spellID, sr.onClick = key, id, nil
                            sr.box:Show()
                            sr:EnableMouse(true)
                            sr.mark:SetShown(pick and pick[id] or false)
                            sr.icon:SetTexture(ns.GetSpellIcon(id) or 134400)
                            sr.icon:Show()
                            sr.id:SetWidth(70)
                            sr.id:SetText(tostring(id))
                            sr.sub:SetText("")
                            sr:ClearAllPoints()
                            sr:SetPoint("TOPLEFT", 24, y)
                            sr:Show()
                            y = y - 17
                        end
                        if #all > 0 then
                            used = used + 1
                            local sr = SubRow(used)
                            sr.key, sr.spellID = key, nil
                            sr.onClick = nil
                            sr.icon:Hide()
                            sr.box:Hide()
                            sr:EnableMouse(false)
                            sr.id:SetText("")
                            sr.sub:SetText(n > 0 and "Solo cuentan los marcados." or "Ninguno marcado: cuentan todos.")
                            sr:ClearAllPoints()
                            sr:SetPoint("TOPLEFT", 24, y)
                            sr:Show()
                            y = y - 19
                        end
                    end
                else
                    r:Hide()
                end
            end
            addBox:ClearAllPoints()
            addBox:SetPoint("TOPLEFT", 0, y - 4)
            wdg:SetHeight(-y + 28)
        end
        table.insert(UI.widgets, wdg)
        return wdg
    end
    local spellsW = SpellList("spells", true)
    local blackW = SpellList("blacklist", false, "Ignorar")

    -- resumen del resaltado del indicador + botón para editarlo
    local hlSummary = UI.Note(c, "", 340)
    hlSummary.Refresh = function()
        local s = Sel()
        local hl = s and s.hl
        local parts = {}
        if hl then
            if hl.glow ~= "none" then parts[#parts + 1] = "brillo: " .. (ns.Glow.NAMES[hl.glow] or hl.glow) end
            if hl.border then parts[#parts + 1] = "borde" end
            if hl.tint then parts[#parts + 1] = "tinte" end
            if hl.pulse then parts[#parts + 1] = "latido" end
            if (hl.scale or 1) ~= 1 then parts[#parts + 1] = ("tamaño %d%%"):format(hl.scale * 100 + 0.5) end
            if hl.sound ~= "none" then parts[#parts + 1] = "sonido" end
        end
        hlSummary.text:SetText(#parts > 0 and ("Activo: " .. table.concat(parts, ", ")) or "Sin resaltado.")
        hlSummary:SetHeight(hlSummary.text:GetStringHeight() + 2)
    end
    table.insert(UI.widgets, hlSummary)
    local hlButton = CreateFrame("Frame", nil, c)
    hlButton:SetSize(340, 24)
    UI.Button(hlButton, "Editar resaltado del indicador", 220, 22, function()
        local s = Sel()
        if s then OpenIndicatorStyle(s) end
    end):SetPoint("LEFT")

    -- tamaño cuadrado (icono)
    local sizeW = UI.Slider(c, "Tamaño", 4, 50, 1, nil,
        function() local s = Sel() return s and s.width end,
        function(v) local s = Sel() s.width, s.height = v, v IndChanged() end)

    local st = UI.Stack(c, 4, -4, {
        UI.Header(c, "Indicador"),
        nameW,
        UI.Check(c, "Activo", IB("enabled")),
        W(UI.Dropdown(c, "Tipo", {
            { "square", "Cuadrado de color" }, { "icon", "Icono" }, { "icons", "Varios iconos" },
            { "bar", "Barra de tiempo" }, { "text", "Texto (tiempo restante)" },
        }, IB("type")), isAura),
        W(UI.Dropdown(c, "Tipo", { { "border", "Borde de color" }, { "overlay", "Tinte sobre la vida" } },
            IB("type")), function() return K() == "dispel" end),

        W(UI.Header(c, "Qué vigila"), isAura),
        W(UI.Dropdown(c, "Auras", { { "HELPFUL", "Bufos" }, { "HARMFUL", "Debufos" } }, IB("auraType")), isAura),
        W(UI.Dropdown(c, "De quién", { { "mine", "Solo las mías" }, { "others", "Solo las de los demás" }, { "any", "De cualquiera" } },
            function()
                local s = Sel()
                if s.others then return "others" end
                return s.mine and "mine" or "any"
            end,
            function(v)
                local s = Sel()
                s.mine = v == "mine"
                s.others = v == "others"
                IndChanged()
            end), isAura),
        W(UI.Dropdown(c, "Mostrar cuando", { { "present", "Lo tiene" }, { "missing", "Le falta" } }, IB("mode")), isAura),
        W(UI.Check(c, "Solo fuera de combate", IB("onlyOOC")), isAura),
        W(UI.Note(c, "Hechizos (por ID o nombre; vale cualquier rango). Sin hechizos = todas las auras de ese tipo. El orden decide cuál se ve primero.", 340), isAura),
        W(spellsW, isAura),

        W(UI.Header(c, "Qué vigila"), function() return K() == "raiddebuff" end),
        W(UI.Note(c, "Muestra el debuff de mayor prioridad de la lista de la instancia (pestaña Debuffs de banda).", 340),
            function() return K() == "raiddebuff" end),
        W(UI.Slider(c, "Mostrar solo si quedan menos de (s)", 0, 30, 1,
            function(v) return v == 0 and "siempre" or (v .. " s") end, IB("showBelow")), function() return isAura() and not isMissing() end),

        W(UI.Header(c, "Qué vigila"), function() return K() == "debuffs" or K() == "dispel" end),
        W(UI.Check(c, "Solo los que yo puedo disipar", IB("onlyDispellable")),
            function() return K() == "debuffs" or K() == "dispel" end),
        W(UI.Check(c, "No repetir los que ya muestra otro indicador", IB("excludeClaimed")),
            function() return K() == "debuffs" end),
        W(UI.Note(c, "Ignorar estos debuffs (lista negra):", 340), function() return K() == "debuffs" end),
        W(blackW, function() return K() == "debuffs" end),

        W(UI.Header(c, "Posición y tamaño"), notDispel),
        W(UI.Dropdown(c, "Punto de anclaje", UI.POINTS, IB("point")), notDispel),
        W(UI.Slider(c, "Desplazamiento X", -80, 80, 1, nil, IB("x")), notDispel),
        W(UI.Slider(c, "Desplazamiento Y", -60, 60, 1, nil, IB("y")), notDispel),
        W(sizeW, iconLike),
        W(UI.Slider(c, "Ancho", 1, 120, 1, nil, IB("width")), rect),
        W(UI.Slider(c, "Alto", 1, 60, 1, nil, IB("height")), rect),
        W(UI.Dropdown(c, "Orientación de la barra", { { "HORIZONTAL", "Horizontal" }, { "VERTICAL", "Vertical" } },
            IB("barOrient")), function() return T() == "bar" end),
        W(UI.Check(c, "Vaciar al revés", IB("barReverse")), function() return T() == "bar" end),
        W(UI.Slider(c, "Grosor del borde", 1, 6, 1, nil, IB("width")),
            function() return K() == "dispel" and T() == "border" end),
        W(UI.Slider(c, "Intensidad del tinte", 0.1, 1, 0.05, UI.pct, IB("overlayAlpha")),
            function() return K() == "dispel" and T() == "overlay" end),
        W(UI.Slider(c, "Máximo de iconos", 1, 8, 1, nil, IB("max")), iconsT),
        W(UI.Dropdown(c, "Crecen hacia", { { "LEFT", "Izquierda" }, { "RIGHT", "Derecha" }, { "UP", "Arriba" }, { "DOWN", "Abajo" } },
            IB("grow")), iconsT),
        W(UI.Slider(c, "Espacio entre iconos", 0, 10, 1, nil, IB("spacing")), iconsT),

        UI.Header(c, "Aspecto"),
        W(UI.Check(c, "Color según tipo (magia, veneno...)", IB("dispelColor")),
            function() return K() == "raiddebuff" or K() == "debuffs" or K() == "dispel" end),
        WE(UI.Attach(UI.Swatch(c, "Color", function() return Sel().color end, IndChanged, true)),
            function() return colored() or K() == "dispel" end,
            function() return colored() or not Sel().dispelColor end),
        W(UI.Check(c, "Borde negro", IB("showBorder")),
            function() local t = T() return notDispel() and t ~= "text" end),
        W(UI.Check(c, "Barrido del tiempo", IB("swipe")),
            function() local t = T() return timed() and (t == "icon" or t == "icons" or t == "square") end),
        W(UI.Slider(c, "Aviso con menos de (s)", 0, 15, 1,
            function(v) return v == 0 and "no" or (v .. " s") end, IB("warnAt")), timed),
        WE(UI.Attach(UI.Swatch(c, "Color de aviso (en iconos, el borde)", function() return Sel().warnColor end, IndChanged, true)),
            timed, function() return Sel().warnAt > 0 end),

        W(UI.Header(c, "Textos"), hasText),
        W(UI.Check(c, "Mostrar tiempo restante", IB("timer")), function() return hasText() and T() ~= "text" end),
        W(UI.Check(c, "Mostrar cargas", IB("stacks")), hasText),
        W(UI.Dropdown(c, "Fuente", ns.FontList, IB("font")), hasText),
        W(UI.Slider(c, "Tamaño del texto", 6, 24, 1, nil, IB("fontSize")), hasText),
        WE(UI.Dropdown(c, "Posición del tiempo", UI.POINTS, IB("timerPoint")),
            function() return hasText() and T() ~= "text" end, function() return Sel().timer end),
        WE(UI.Dropdown(c, "Posición de las cargas", UI.POINTS, IB("stacksPoint")),
            function() return hasText() and T() ~= "text" end, function() return Sel().stacks end),

        UI.Header(c, "Resaltado"),
        hlSummary,
        hlButton,
        W(UI.Note(c, "Excepciones: en la lista de hechizos, el botón «brillo» de cada uno le da un resaltado propio que sustituye a este.", 340), isAura),
        W(UI.Note(c, "Excepciones: en la pestaña «Debuffs de banda», haz clic en un debuff para darle un resaltado propio en esa instancia.", 340),
            function() return K() == "raiddebuff" end),
    })

    p.OnShow = function() end
    UI.OnRefreshIndicators = function()
        RefreshList()
        st:Layout()
        UI.FitContent(c, { st }, 40)
    end
end

-------------------------------------------------------------------------------
-- Catálogo: agrupación -> clases y hechizos -> añadir como indicador
-------------------------------------------------------------------------------
local catGroup = "hots"
local catSel, catOrigin, catMode = {}, {}, {}

-- casilla con icono y texto (para clases y hechizos)
local function Toggle(parent, width)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 20)
    b.box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.box:SetSize(14, 14)
    b.box:SetPoint("LEFT", 0, 0)
    UI.Backdrop(b.box, { 0.05, 0.05, 0.06, 1 })
    b.mark = b.box:CreateTexture(nil, "OVERLAY")
    b.mark:SetPoint("TOPLEFT", 3, -3)
    b.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    b.mark:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 20, 0)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.iconTip = UI.IconTip(b, b.icon, function() return b.icon:IsShown() and b.tipID end)
    b.text = UI.Label(b, "")
    b.text:SetWordWrap(false)
    b.note = UI.Label(b, "")
    b.note:SetTextColor(0.55, 0.55, 0.55)
    b.note:SetWordWrap(false)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.05)
    -- state: true, false o "partial"
    b.SetState = function(self, state)
        self.mark:SetShown(state and true or false)
        self.mark:SetAlpha(state == "partial" and 0.4 or 1)
    end
    b.SetContent = function(self, text, icon, note)
        self.text:ClearAllPoints()
        if icon then
            self.icon:SetTexture(icon)
            self.icon:Show()
            self.text:SetPoint("LEFT", 40, note and 5 or 0)
        else
            self.icon:Hide()
            self.text:SetPoint("LEFT", 20, 0)
        end
        self.text:SetWidth(self:GetWidth() - 44)
        self.text:SetText(text)
        self.note:ClearAllPoints()
        self.note:SetPoint("TOPLEFT", self.text, "BOTTOMLEFT", 0, -1)
        self.note:SetWidth(self:GetWidth() - 44)
        self.note:SetText(note or "")
        self.note:SetShown(note ~= nil)
    end
    return b
end

local function BuildCatalog(p)
    local _, c = UI.ScrollPage(p)
    c:SetWidth(590)
    local myClass = select(2, UnitClass("player"))
    local Rebuild

    local function Group() return ns.CatalogByKey[catGroup] end
    local function Sel(g)
        g = g or Group()
        if not catSel[g.key] then
            -- al abrir una agrupación por primera vez: lo recomendado para mi clase
            catSel[g.key] = {}
            for _, e in ipairs(ns.CatalogRecommended(g, myClass)) do catSel[g.key][e] = true end
        end
        return catSel[g.key]
    end

    -- 1. agrupación
    local h1 = UI.Header(c, "1. Agrupación")
    h1:SetWidth(570)
    local groupBtns = {}
    for i, g in ipairs(ns.Catalog) do
        local b = UI.Button(c, g.name, 186, 22, function()
            catGroup = g.key
            Rebuild()
        end)
        b.key = g.key
        groupBtns[i] = b
    end
    local desc = UI.Note(c, "", 570)
    desc.text:SetTextColor(0.75, 0.75, 0.75)

    -- 2. clases y hechizos
    local h2 = UI.Header(c, "2. Clases y hechizos")
    h2:SetWidth(570)
    local recBtn = UI.Button(c, "Recomendado para mi clase", 180, 20, function()
        local g = Group()
        wipe(Sel(g))
        for _, e in ipairs(ns.CatalogRecommended(g, myClass)) do Sel(g)[e] = true end
        Rebuild()
    end)
    local allBtn = UI.Button(c, "Marcar todo", 100, 20, function()
        for _, e in ipairs(Group().spells) do Sel()[e] = true end
        Rebuild()
    end)
    local noneBtn = UI.Button(c, "Quitar todo", 100, 20, function()
        wipe(Sel())
        Rebuild()
    end)
    local classPool, itemPool = {}, {}

    -- 3. añadir
    local h3 = UI.Header(c, "3. Añadir como indicador")
    h3:SetWidth(570)
    local originDD = UI.Dropdown(c, "De quién", {
        { "mine", "Solo los míos" }, { "others", "Solo los de los demás" }, { "any", "De cualquiera" },
    }, function() return catOrigin[catGroup] or Group().origin end, function(v) catOrigin[catGroup] = v end, 220)
    local modeDD = UI.Dropdown(c, "Mostrar cuando", {
        { "present", "Lo tiene" }, { "missing", "Le falta (un aviso por bufo)" },
    }, function() return catMode[catGroup] or Group().mode or "present" end, function(v) catMode[catGroup] = v end, 220)
    local result = UI.Note(c, "", 570)
    local goBtn = UI.Button(c, "Ver en Indicadores", 140, 22, function()
        if ns.OpenIndicators then ns.OpenIndicators() end
    end)
    goBtn:Hide()
    local addBtn = UI.Button(c, "Añadir como indicador", 220, 26, function()
        local g = Group()
        local entries = {}
        for _, e in ipairs(g.spells) do
            if Sel(g)[e] then table.insert(entries, e) end
        end
        if #entries == 0 then
            result.text:SetText("|cffff7755Marca al menos un hechizo en el paso 2.|r")
            goBtn:Hide()
            Rebuild()
            return
        end
        local origin = catOrigin[g.key] or g.origin
        local mode = (g.auraType == "HELPFUL") and (catMode[g.key] or g.mode or "present") or "present"
        local new = ns.CatalogMakeIndicators(g, entries, origin, mode)
        local list = ns.EP().indicators
        local names = {}
        for _, ind in ipairs(new) do
            table.insert(list, ind)
            table.insert(names, "«" .. ind.name .. "»")
        end
        selInd = #list - #new + 1
        ns.ProfileChanged()
        result.text:SetText(("|cff55ff55Añadido:|r %s al perfil %s. Muévelo y ajústalo en Indicadores."):format(
            table.concat(names, ", "), ns.EditedProfileName()))
        goBtn:Show()
        UI.RefreshAll()
    end)

    local function Place(f, x, y)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", c, "TOPLEFT", x, y)
        f:Show()
    end

    Rebuild = function()
        local g = Group()
        local sel = Sel(g)
        local y = -4

        Place(h1, 10, y)
        y = y - 26
        for i, b in ipairs(groupBtns) do
            local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
            Place(b, 10 + col * 192, y - row * 26)
            local on = b.key == catGroup
            b:SetBackdropColor(on and 0.12 or 0.15, on and 0.3 or 0.15, on and 0.42 or 0.18, 1)
        end
        y = y - math.ceil(#groupBtns / 3) * 26 - 4
        desc.text:SetText(g.desc .. "  |cff888888(" .. (g.auraType == "HARMFUL" and "debufos" or "bufos") .. ")|r")
        desc:SetHeight(desc.text:GetStringHeight() + 2)
        Place(desc, 10, y)
        y = y - desc:GetHeight() - 10

        Place(h2, 10, y)
        y = y - 28
        Place(recBtn, 10, y)
        Place(allBtn, 196, y)
        Place(noneBtn, 302, y)
        y = y - 28

        -- clases que aportan algo a esta agrupación
        for _, f in ipairs(classPool) do f:Hide() end
        for _, f in ipairs(itemPool) do f:Hide() end
        local ci, ii = 0, 0
        for _, class in ipairs(ns.CLASS_ORDER) do
            local entries = {}
            for _, e in ipairs(g.spells) do if e.class == class then table.insert(entries, e) end end
            if #entries > 0 then
                ci = ci + 1
                local ct = classPool[ci]
                if not ct then ct = Toggle(c, 570) classPool[ci] = ct end
                local n = 0
                for _, e in ipairs(entries) do if sel[e] then n = n + 1 end end
                local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                local cname = ns.CLASS_NAMES[class] or class
                if col then cname = ("|cff%02x%02x%02x%s|r"):format(col.r * 255, col.g * 255, col.b * 255, cname) end
                ct:SetContent(cname .. ((class == myClass) and "  |cff888888(tu clase)|r" or ""))
                ct:SetState(n == #entries or (n > 0 and "partial"))
                ct:SetScript("OnClick", function()
                    local all = n == #entries
                    for _, e in ipairs(entries) do sel[e] = (not all) or nil end
                    Rebuild()
                end)
                Place(ct, 10, y)
                y = y - 22
                for k, e in ipairs(entries) do
                    ii = ii + 1
                    local it = itemPool[ii]
                    if not it then it = Toggle(c, 270) it:SetHeight(30) itemPool[ii] = it end
                    local name, icon = ns.SpellKeyInfo(ns.CatalogKey(e))
                    it:SetContent(name, icon or 134400, e.note)
                    it:SetState(sel[e])
                    it:SetScript("OnClick", function()
                        sel[e] = (not sel[e]) or nil
                        Rebuild()
                    end)
                    it.tipID = ns.KeyIDs(ns.CatalogKey(e))[1]
                    local colI, row = (k - 1) % 2, math.floor((k - 1) / 2)
                    Place(it, 30 + colI * 280, y - row * 32)
                end
                y = y - math.ceil(#entries / 2) * 32 - 6
            end
        end

        y = y - 6
        Place(h3, 10, y)
        y = y - 28
        originDD.Refresh()
        Place(originDD, 10, y)
        if g.auraType == "HELPFUL" then
            modeDD.Refresh()
            Place(modeDD, 250, y)
        else
            modeDD:Hide()
        end
        y = y - 44
        Place(addBtn, 10, y)
        y = y - 34
        Place(result, 10, y)
        result:SetHeight(math.max(14, result.text:GetStringHeight() + 2))
        y = y - result:GetHeight() - 6
        if goBtn:IsShown() then
            Place(goBtn, 10, y)
            y = y - 28
        end
        c:SetHeight(-y + 20)
        if c.UpdateBar then c.UpdateBar() end
    end

    p.OnShow = function() Rebuild() end
end

-------------------------------------------------------------------------------
-- Debuffs de banda
-------------------------------------------------------------------------------
local selKey = 0
local listOffset, seenOffset = 0, 0
local LIST_ROWS, SEEN_ROWS = 12, 5

local function SortedList()
    local out = {}
    for id, e in pairs(ns.GetDebuffList(selKey)) do
        e.key = id
        e.name = ns.SpellKeyInfo(id)
        out[#out + 1] = e
    end
    table.sort(out, function(a, b)
        if a.prio ~= b.prio then return a.prio > b.prio end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

local function Custom(key)
    local c = ns.db.raid.custom[key]
    if not c then c = {} ns.db.raid.custom[key] = c end
    return c
end

local function InstanceOptions()
    local out, seen = {}, {}
    for _, k in ipairs(ns.RaidOrder) do
        out[#out + 1] = { k, ns.InstanceName(k) }
        seen[k] = true
    end
    local extra = {}
    for _, t in ipairs({ ns.db.raid.custom, ns.db.raid.seen, ns.db.raid.names }) do
        for k in pairs(t) do
            if not seen[k] then seen[k] = true extra[#extra + 1] = k end
        end
    end
    table.sort(extra)
    for _, k in ipairs(extra) do out[#out + 1] = { k, ns.InstanceName(k) } end
    return out
end

local selDebuff

local function BuildRaid(p)
    local RefreshRaid
    local function RaidChanged()
        ns.RebuildDebuffLookup()
        RefreshRaid()
    end

    -- clic en un debuff: abrir su excepción de resaltado en el panel lateral
    local function Select(key)
        if key == nil then
            selDebuff = nil
            CloseSide()
            if RefreshRaid then RefreshRaid() end
            return
        end
        local inst = selKey
        selDebuff = key
        OpenSide({
            title = function() return ns.SpellKeyInfo(key) end,
            sub = ("Excepción en %s: sustituye al resaltado del indicador «Debuff de banda»."):format(ns.InstanceName(inst)),
            load = function() return ns.GetDebuffStyle(inst, key) end,
            store = function(s)
                local t = ns.db.raid.styles[inst]
                if not t then t = {} ns.db.raid.styles[inst] = t end
                t[key] = s
            end,
            clear = function()
                local t = ns.db.raid.styles[inst]
                if t then t[key] = nil end
            end,
            fallback = function() local ind = RaidIndicator() return ind and ind.hl end,
            onChange = function() ns.RebuildDebuffLookup() RefreshRaid() end,
            preview = { raid = { inst = inst, key = key } },
            onClose = function()
                selDebuff = nil
                if RefreshRaid then RefreshRaid() end
            end,
        })
    end

    local dd = UI.Dropdown(p, "Instancia", InstanceOptions, function() return selKey end, function(v)
        selKey = v
        listOffset, seenOffset = 0, 0
        Select(nil)
        RefreshRaid()
    end, 230)
    dd:SetPoint("TOPLEFT", 12, -6)

    local cur = UI.Button(p, "Instancia actual", 110, 18, function()
        selKey = ns.instKey or 0
        listOffset, seenOffset = 0, 0
        Select(nil)
        dd.Refresh()
        RefreshRaid()
    end)
    cur:SetPoint("TOPLEFT", 250, -20)

    local rec = UI.Check(p, "Registrar debuffs nuevos",
        function() return ns.db.raid.recorder end, function(v) ns.db.raid.recorder = v end)
    rec:SetPoint("TOPLEFT", 372, -22)

    local hdr = UI.Label(p, "Debuff")
    hdr:SetPoint("TOPLEFT", 16, -48)
    hdr:SetTextColor(0.6, 0.6, 0.6)
    local hdr2 = UI.Label(p, "Prioridad     Activo")
    hdr2:SetPoint("TOPLEFT", 326, -48)
    hdr2:SetTextColor(0.6, 0.6, 0.6)
    local scrollInfo = UI.Label(p, "")
    scrollInfo:SetPoint("TOPRIGHT", -16, -48)
    scrollInfo:SetTextColor(0.6, 0.6, 0.6)

    local listArea = CreateFrame("Frame", nil, p)
    listArea:SetPoint("TOPLEFT", 12, -62)
    listArea:SetSize(570, LIST_ROWS * 20)
    listArea:EnableMouseWheel(true)
    listArea:SetScript("OnMouseWheel", function(_, d)
        listOffset = math.max(0, listOffset - d)
        RefreshRaid()
    end)

    local listRows = {}
    for i = 1, LIST_ROWS do
        local row = CreateFrame("Frame", nil, listArea)
        row:SetSize(570, 19)
        row:SetPoint("TOPLEFT", 4, -(i - 1) * 20)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
        row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.sel:SetAllPoints()
        row.sel:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.22)
        row.sel:Hide()
        -- clic en el nombre: abrir el resaltado
        row.click = CreateFrame("Button", nil, row)
        row.click:SetPoint("TOPLEFT")
        row.click:SetSize(306, 19)
        row.click.hl = row.click:CreateTexture(nil, "HIGHLIGHT")
        row.click.hl:SetAllPoints()
        row.click.hl:SetColorTexture(1, 1, 1, 0.07)
        row.click:SetScript("OnClick", function()
            if row.entry then Select(row.entry.key ~= selDebuff and row.entry.key or nil) end
        end)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(17, 17)
        row.icon:SetPoint("LEFT")
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        -- tooltip del hechizo solo sobre el icono
        local tip = UI.IconTip(row, row.icon, function()
            local key = row.entry and row.entry.key
            return key ~= nil and ns.KeyIDs(key)[1] or nil
        end)
        tip:SetFrameLevel(row.click:GetFrameLevel() + 2)
        row.name = UI.Label(row, "")
        row.name:SetPoint("LEFT", 22, 0)
        row.name:SetWidth(196)
        row.name:SetWordWrap(false)
        row.styled = row:CreateTexture(nil, "ARTWORK")
        row.styled:SetSize(8, 8)
        row.styled:SetPoint("LEFT", 226, 0)
        row.id = UI.Label(row, "")
        row.id:SetPoint("LEFT", 248, 0)
        row.id:SetTextColor(0.6, 0.6, 0.6)
        row.minus = UI.Button(row, "-", 16, 16, function()
            Custom(selKey)[row.entry.key] = math.max(1, row.entry.prio - 1)
            RaidChanged()
        end)
        row.minus:SetPoint("LEFT", 314, 0)
        row.prio = UI.Label(row, "")
        row.prio:SetPoint("LEFT", 336, 0)
        row.plus = UI.Button(row, "+", 16, 16, function()
            Custom(selKey)[row.entry.key] = math.min(20, row.entry.prio + 1)
            RaidChanged()
        end)
        row.plus:SetPoint("LEFT", 354, 0)
        row.toggle = CreateFrame("Button", nil, row, "BackdropTemplate")
        row.toggle:SetSize(14, 14)
        row.toggle:SetPoint("LEFT", 392, 0)
        UI.Backdrop(row.toggle, { 0.05, 0.05, 0.06, 1 })
        row.toggle.mark = row.toggle:CreateTexture(nil, "OVERLAY")
        row.toggle.mark:SetPoint("TOPLEFT", 3, -3)
        row.toggle.mark:SetPoint("BOTTOMRIGHT", -3, 3)
        row.toggle.mark:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        row.toggle:SetScript("OnClick", function()
            local dis = ns.db.raid.disabled[selKey]
            if not dis then dis = {} ns.db.raid.disabled[selKey] = dis end
            dis[row.entry.key] = (not dis[row.entry.key]) or nil
            RaidChanged()
        end)
        row.del = UI.Button(row, "", 80, 16, function()
            Custom(selKey)[row.entry.key] = nil
            RaidChanged()
        end)
        row.del:SetPoint("LEFT", 424, 0)
        listRows[i] = row
    end

    local y = -62 - LIST_ROWS * 20 - 10
    local addLbl = UI.Label(p, "Añadir debuff (ID o nombre exacto):")
    addLbl:SetPoint("TOPLEFT", 16, y)
    local e = UI.EditBox(p, 200)
    e:SetPoint("TOPLEFT", 16, y - 14)
    local prioLbl = UI.Label(p, "Prioridad")
    prioLbl:SetPoint("LEFT", e, "RIGHT", 8, 0)
    local pe = UI.EditBox(p, 34)
    pe:SetPoint("LEFT", prioLbl, "RIGHT", 4, 0)
    pe:SetText("5")
    pe:SetNumeric(true)
    local add = UI.Button(p, "Añadir", 70, 20, function()
        local key = ns.ParseSpellInput(e:GetText())
        if not key then return end
        Custom(selKey)[key] = math.max(1, tonumber(pe:GetText()) or 5)
        local disabled = ns.db.raid.disabled[selKey]
        if disabled then disabled[key] = nil end
        e:SetText("")
        e:ClearFocus()
        RaidChanged()
    end)
    add:SetPoint("LEFT", pe, "RIGHT", 8, 0)
    e:SetScript("OnEnterPressed", function() add:Click() end)

    y = y - 46
    local seenHdr = UI.Header(p, "Vistos en esta instancia (no están en la lista)")
    seenHdr:SetPoint("TOPLEFT", 16, y + 4)
    seenHdr:SetWidth(440)
    local clear = UI.Button(p, "Limpiar", 70, 18, function()
        ns.db.raid.seen[selKey] = nil
        RefreshRaid()
    end)
    clear:SetPoint("TOPRIGHT", -16, y + 2)

    local seenArea = CreateFrame("Frame", nil, p)
    seenArea:SetPoint("TOPLEFT", 12, y - 22)
    seenArea:SetSize(570, SEEN_ROWS * 20)
    seenArea:EnableMouseWheel(true)
    seenArea:SetScript("OnMouseWheel", function(_, d)
        seenOffset = math.max(0, seenOffset - d)
        RefreshRaid()
    end)
    local seenRows = {}
    for i = 1, SEEN_ROWS do
        local row = CreateFrame("Frame", nil, seenArea)
        row:SetSize(570, 19)
        row:SetPoint("TOPLEFT", 4, -(i - 1) * 20)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(17, 17)
        row.icon:SetPoint("LEFT")
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = UI.Label(row, "")
        row.name:SetPoint("LEFT", 22, 0)
        row.name:SetWidth(220)
        row.name:SetWordWrap(false)
        row.id = UI.Label(row, "")
        row.id:SetPoint("LEFT", 248, 0)
        row.id:SetTextColor(0.6, 0.6, 0.6)
        row.count = UI.Label(row, "")
        row.count:SetPoint("LEFT", 314, 0)
        row.count:SetTextColor(0.6, 0.6, 0.6)
        -- tooltip del hechizo solo sobre el icono
        UI.IconTip(row, row.icon, function() return row.spellID end)
        row.add = UI.Button(row, "Añadir", 70, 16, function()
            Custom(selKey)[row.spellID] = 5
            ns.db.raid.seen[selKey][row.spellID] = nil
            RaidChanged()
        end)
        row.add:SetPoint("LEFT", 424, 0)
        seenRows[i] = row
    end
    local seenEmpty = UI.Label(p, "Nada todavía. Entra en la instancia con el registrador activo: los debuffs que no\nestén en la lista aparecerán aquí (cuando el juego deje leerlos).")
    seenEmpty:SetPoint("TOPLEFT", 16, y - 26)
    seenEmpty:SetTextColor(0.6, 0.6, 0.6)

    RefreshRaid = function()
        local list = SortedList()
        listOffset = math.max(0, math.min(listOffset, #list - LIST_ROWS))
        for i, row in ipairs(listRows) do
            local en = list[i + listOffset]
            row.entry = en
            if en then
                local name, icon = ns.SpellKeyInfo(en.key)
                row.icon:SetTexture(icon or 134400)
                row.name:SetText(name)
                local g = en.disabled and 0.5 or 1
                row.name:SetTextColor(g, g, g)
                row.id:SetText(type(en.key) == "number" and en.key or (select(3, ns.SpellKeyInfo(en.key)) or "buscando..."))
                row.prio:SetText(en.prio)
                row.toggle.mark:SetShown(not en.disabled)
                row.sel:SetShown(en.key == selDebuff)
                local s = ns.GetDebuffStyle(selKey, en.key)
                local styled = s and (s.glow ~= "none" or s.border or s.tint or s.pulse or s.sound ~= "none" or s.scale ~= 1)
                if styled then
                    local c = (s.glow ~= "none" and s.color) or (s.border and s.borderColor) or (s.tint and s.tintColor) or { r = 1, g = 1, b = 1 }
                    row.styled:SetColorTexture(c.r, c.g, c.b, 1)
                    row.styled:Show()
                else
                    row.styled:Hide()
                end
                if en.custom then
                    row.del.text:SetText("Borrar")
                    row.del:Show()
                elseif en.changed then
                    row.del.text:SetText("Restaurar")
                    row.del:Show()
                else
                    row.del:Hide()
                end
                row:Show()
            else
                row:Hide()
            end
        end
        if #list > LIST_ROWS then
            scrollInfo:SetText(("%d-%d de %d (rueda)"):format(listOffset + 1, math.min(#list, listOffset + LIST_ROWS), #list))
        else
            scrollInfo:SetText(#list == 0 and "lista vacía" or (#list .. " debuffs"))
        end

        local seen = {}
        for id, s in pairs(ns.db.raid.seen[selKey] or {}) do
            seen[#seen + 1] = { id = id, name = s.name, icon = s.icon, count = s.count or 0 }
        end
        table.sort(seen, function(a, b) return a.count > b.count end)
        seenOffset = math.max(0, math.min(seenOffset, #seen - SEEN_ROWS))
        for i, row in ipairs(seenRows) do
            local s = seen[i + seenOffset]
            if s then
                row.spellID = s.id
                row.icon:SetTexture(s.icon or ns.GetSpellIcon(s.id) or 134400)
                row.name:SetText(s.name or ns.GetSpellName(s.id) or "?")
                row.id:SetText(s.id)
                row.count:SetText(s.count .. " veces")
                row:Show()
            else
                row:Hide()
            end
        end
        seenEmpty:SetShown(#seen == 0)
    end

    p.OnShow = function()
        dd.Refresh()
        RefreshRaid()
        if side:IsShown() then side.Refresh() end
    end
end

-------------------------------------------------------------------------------
-- Ventana
-------------------------------------------------------------------------------
local function SelectPage(i)
    UI.CloseMenu()
    CloseSide()
    for k, page in ipairs(pages) do
        page:SetShown(k == i)
        local on = k == i
        navs[k]:SetBackdropColor(on and 0.12 or 0.1, on and 0.3 or 0.1, on and 0.42 or 0.12, 1)
    end
    win.current = i
    if pages[i].OnShow then pages[i].OnShow() end
end

local function CreateWindow()
    win = CreateFrame("Frame", "MendFramesOptions", UIParent, "BackdropTemplate")
    win:SetSize(760, 600)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    UI.Backdrop(win, { 0.06, 0.06, 0.08, 0.97 }, { 0.2, 0.2, 0.25, 1 })
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetClampedToScreen(true)
    table.insert(UISpecialFrames, "MendFramesOptions")
    win:SetScript("OnHide", function()
        UI.CloseMenu()
        CloseSide()
    end)
    BuildSide()

    local title = UI.Label(win, "MendFrames  |cff888888v" .. ns.version .. "|r", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    win.profileLabel = UI.Label(win, "")
    win.profileLabel:SetPoint("LEFT", title, "RIGHT", 14, -1)
    win.profileLabel:SetTextColor(0.7, 0.7, 0.7)

    local close = UI.Button(win, "X", 22, 20, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", -8, -8)
    win.lockBtn = UI.Button(win, "", 100, 20, function() ns.SetLocked(not ns.db.locked) end)
    win.lockBtn:SetPoint("TOPRIGHT", close, "TOPLEFT", -6, 0)
    win.testBtn = UI.Button(win, "", 100, 20, function() ns.ToggleTest() end)
    win.testBtn:SetPoint("TOPRIGHT", win.lockBtn, "TOPLEFT", -6, 0)

    local names = { "Perfiles", "Diseño", "Barras", "Textos", "Iconos de estado", "Indicadores", "Catálogo", "Debuffs de banda" }
    local builders = { BuildProfiles, BuildLayout, BuildBars, BuildTexts, BuildElements, BuildIndicators, BuildCatalog, BuildRaid }
    for i, n in ipairs(names) do
        local nb = UI.Button(win, n, 130, 26, function() SelectPage(i) end)
        nb:SetPoint("TOPLEFT", 10, -44 - (i - 1) * 30)
        nb.text:ClearAllPoints()
        nb.text:SetPoint("LEFT", 10, 0)
        navs[i] = nb
        local page = CreateFrame("Frame", nil, win)
        page:SetPoint("TOPLEFT", 148, -44)
        page:SetPoint("BOTTOMRIGHT", -8, 8)
        builders[i](page)
        page:Hide()
        pages[i] = page
    end

    UI.OnRefresh = function()
        win.profileLabel:SetText(("editando: |cffffffff%s|r · activo: |cffffffff%s|r"):format(
            ns.EditedProfileName(), tostring(ns.activeName)))
        if UI.OnRefreshIndicators then UI.OnRefreshIndicators() end
        local cur = win.current and pages[win.current]
        if cur and cur.OnShow then cur.OnShow() end
        -- el panel de resaltado se abre desde varias páginas: recolocar y
        -- recalcular su altura (scroll) siempre que esté visible
        if side and side:IsShown() then side.Refresh() end
    end

    ns.OpenIndicators = function() SelectPage(6) end
    ns.OpenCatalog = function() SelectPage(7) end
    ns.OnLockChanged = function()
        win.lockBtn.text:SetText(ns.db.locked and "Desbloquear" or "Bloquear")
    end
    ns.OnTestChanged = function()
        win.testBtn.text:SetText(ns.testing and "Ocultar prueba" or "Modo prueba")
    end
    ns.OnProfileChanged = function()
        if win:IsShown() then UI.RefreshAll() end
    end
    ns.OnLockChanged()
    ns.OnTestChanged()
    SelectPage(1)
end

-- Abrir (sin cerrar si ya está abierta)
function ns.OpenOptions()
    if win and win:IsShown() then return end
    ns.ToggleOptions()
end

function ns.ToggleOptions()
    if not win then CreateWindow() end
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
        if not ns.testing and not IsInGroup() then ns.ToggleTest(true) end
        UI.RefreshAll()
    end
end
