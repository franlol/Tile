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

-- Tras cambiar algo del perfil editado desde un bloque común
local function PAfter()
    ns.ProfileChanged()
    UI.RefreshAll()
end

-------------------------------------------------------------------------------
-- Bloques comunes: cada tipo de cosa tiene siempre las mismas opciones,
-- con los mismos nombres y en el mismo orden
--   Texto:  Mostrar · Fuente · Tamaño · Contorno · Color · Posición (X, Y)
--   Icono:  Mostrar · Tamaño · Posición (X, Y)
--   Barra:  Textura · Color (propio, brillo) · Opacidad
-------------------------------------------------------------------------------

-- Une controles sueltos y listas de controles en una sola lista
local function Flat(items)
    local out = {}
    for _, v in ipairs(items) do
        if v.GetObjectType then
            out[#out + 1] = v
        else
            for _, w in ipairs(v) do out[#out + 1] = w end
        end
    end
    return out
end

local function Both(a, b)
    if not a then return b end
    if not b then return a end
    return function() return a() and b() end
end

-- Añade condiciones a un control (sin perder las que ya tenga)
local function Cond(w, showIf, enableIf)
    w.showIf = Both(w.showIf, showIf)
    w.enableIf = Both(w.enableIf, enableIf)
    return w
end
local function All(list, showIf, enableIf)
    for _, w in ipairs(list) do Cond(w, showIf, enableIf) end
    return list
end

local TEXT_COLORS = { { "white", "Blanco" }, { "class", "Color de clase" }, { "custom", "Personalizado" } }
local BAR_COLORS = {
    { "class", "Color de clase" }, { "custom", "Un solo color" }, { "gradient", "Degradado según la vida" },
}
local POWER_COLORS = {
    { "power", "Color del recurso" }, { "class", "Color de clase" }, { "custom", "Un solo color" },
}

-- Posición: punto de anclaje y X/Y pegados (mismos rangos en todas partes)
local function PositionBlock(c, root, after, o)
    o = o or {}
    return {
        Cond(UI.Dropdown(c, "Posición", UI.POINTS, UI.Bind(root, "point", after)), o.showIf, o.enableIf),
        Cond(UI.Attach(UI.Slider(c, "X", -80, 80, 1, nil, UI.Bind(root, "x", after))), o.showIf, o.enableIf),
        Cond(UI.Attach(UI.Slider(c, "Y", -60, 60, 1, nil, UI.Bind(root, "y", after))), o.showIf, o.enableIf),
    }
end

-- Texto. root() devuelve su tabla de estilo.
-- o.show = { get, set } añade «Mostrar»; o.extra, controles justo después;
-- o.showIf / o.enableIf para todo el bloque (enableIf no afecta a «Mostrar»);
-- o.showCheckIf, o.colorIf, o.positionIf para partes concretas.
local function TextBlock(c, root, after, o)
    o = o or {}
    local list = {}
    local function Add(w, showIf, enableIf)
        list[#list + 1] = Cond(w, Both(o.showIf, showIf), Both(o.enableIf, enableIf))
    end
    if o.show then
        list[#list + 1] = Cond(UI.Check(c, "Mostrar", o.show[1], o.show[2]), Both(o.showIf, o.showCheckIf))
    end
    for _, w in ipairs(o.extra or {}) do Add(w) end
    local function B(k) return UI.Bind(root, k, after) end
    Add(UI.Dropdown(c, "Fuente", ns.FontList, B("font")))
    Add(UI.Slider(c, "Tamaño", 6, 24, 1, nil, B("size")))
    Add(UI.Dropdown(c, "Contorno", ns.OUTLINES, B("outline")))
    Add(UI.Dropdown(c, "Color", TEXT_COLORS, B("colorMode")), o.colorIf)
    Add(UI.Attach(UI.Swatch(c, "Color personalizado", function() return root().color end,
        function() if after then after() end end, true)),
        o.colorIf, function() return root().colorMode == "custom" end)
    for _, w in ipairs(PositionBlock(c, root, after)) do Add(w, o.positionIf) end
    return list
end

-- Color de una barra: modo, color propio y brillo (los dos últimos, pegados)
local function BarColorBlock(c, modes, modeKey, customKey, brightKey)
    local function Mode() return UI.Bind(ns.EP, modeKey)() end
    return {
        UI.Dropdown(c, "Color", modes, PB(modeKey)),
        Cond(UI.Attach(UI.Swatch(c, "Color personalizado", function() return UI.Bind(ns.EP, customKey)() end,
            ns.ProfileChanged, true)), nil, function() return Mode() == "custom" end),
        Cond(UI.Attach(UI.Slider(c, "Brillo", 0.1, 1, 0.05, UI.pct, PB(brightKey))), nil,
            function() return Mode() ~= "custom" end),
    }
end

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

    -- Cambia el perfil que se edita (en modo prueba, también el que se ve)
    local function SetEdit(n)
        ns.editName = n
        ns.ActivateProfile()
        Refresh()
    end
    local function Reassign(old, new)
        for _, chars in pairs(ns.db.chars) do
            for k, v in pairs(chars) do if v == old then chars[k] = new end end
        end
    end
    -- Tamaños de grupo de este personaje que usan un perfil
    local function UsedBy(name)
        local out = {}
        for _, key in ipairs(ns.SIZE_KEYS) do
            if ns.CharProfiles()[key] == name then out[#out + 1] = ns.SIZE_NAMES[key] end
        end
        return out
    end

    local function ConfirmButton(parent, text, w, func)
        return UI.Confirm(UI.Button(parent, text, w, 20, func))
    end

    ---------------------------------------------------------------------------
    -- Perfil que se edita
    ---------------------------------------------------------------------------
    local editDD = UI.Dropdown(c, nil, ProfileOptions, ns.EditedProfileName, SetEdit)

    local feedback -- se crea más abajo
    local function Say(text)
        feedback.text:SetText(text)
        feedback.text:SetTextColor(0.4, 0.9, 0.5)
        feedback:SetHeight(feedback.text:GetStringHeight() + 2)
        Refresh() -- recolocar: el mensaje puede ocupar otra altura
    end

    local resetBtn = ConfirmButton(editDD, "Restablecer", 90, function()
        local name = ns.EditedProfileName()
        ns.db.profiles[name] = ns.NewProfile()
        ns.ActivateProfile(true)
        ns.ProfileChanged()
        Refresh()
        Say(("«%s» ha vuelto a los ajustes por defecto."):format(name))
    end)
    resetBtn:SetPoint("LEFT", editDD.button, "RIGHT", 6, 0)
    local deleteBtn = ConfirmButton(editDD, "Borrar", 70, function()
        local old = ns.EditedProfileName()
        if old == "Default" then return end
        local used = #UsedBy(old) > 0
        ns.db.profiles[old] = nil
        Reassign(old, "Default")
        ns.editName = nil
        ns.ActivateProfile(true)
        Refresh()
        Say(used and ("«%s» borrado. Donde se usaba, ahora se usa Default."):format(old)
            or ("«%s» borrado."):format(old))
    end)
    deleteBtn:SetPoint("LEFT", resetBtn, "RIGHT", 6, 0)

    local usage = UI.Note(c, "", 520)
    usage.Refresh = function()
        local name = ns.EditedProfileName()
        local used = UsedBy(name)
        if #used > 0 then
            usage.text:SetText("Lo usa este personaje en: |cffffffff" .. table.concat(used, ", ") .. "|r.")
        else
            usage.text:SetText("|cffff8c4dNingún tamaño de grupo lo usa todavía.|r Asígnalo abajo para que se vea en juego (en modo prueba ya lo ves).")
        end
        usage:SetHeight(usage.text:GetStringHeight() + 2)
        UI.SetEnabled(deleteBtn, name ~= "Default")
    end
    table.insert(UI.widgets, usage)

    ---------------------------------------------------------------------------
    -- Crear / duplicar / renombrar
    ---------------------------------------------------------------------------
    local actions = CreateFrame("Frame", nil, c)
    actions:SetSize(520, 48)
    local lbl = UI.Label(actions, "Nombre:")
    lbl:SetPoint("TOPLEFT", 0, -4)
    local nameBox = UI.EditBox(actions, 170)
    nameBox:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    local hint = UI.Label(actions, "")
    hint:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    hint:SetTextColor(1, 0.55, 0.3)

    local function Btn(text, x, func)
        local b = UI.Button(actions, text, 100, 20, func)
        b:SetPoint("TOPLEFT", x, -28)
        return b
    end
    local function Name() return nameBox:GetText():trim() end
    local function Done(n, msg)
        nameBox:SetText("")
        nameBox:ClearFocus()
        SetEdit(n)
        Say(msg)
    end
    local newBtn = Btn("Crear nuevo", 0, function()
        local n = Name()
        ns.db.profiles[n] = ns.NewProfile()
        Done(n, ("«%s» creado con los ajustes por defecto."):format(n))
    end)
    local dupBtn = Btn("Duplicar", 106, function()
        local n, from = Name(), ns.EditedProfileName()
        ns.db.profiles[n] = ns.DeepCopy(ns.EP())
        Done(n, ("«%s» creado como copia de «%s»."):format(n, from))
    end)
    local renBtn = Btn("Renombrar", 212, function()
        local n, old = Name(), ns.EditedProfileName()
        ns.db.profiles[n] = ns.db.profiles[old]
        ns.db.profiles[old] = nil
        Reassign(old, n)
        if ns.activeName == old then ns.activeName = n end
        Done(n, ("«%s» ahora se llama «%s»."):format(old, n))
    end)

    -- los botones solo se activan con un nombre válido
    local function Validate()
        local n = Name()
        local exists = n ~= "" and ns.db.profiles[n] ~= nil
        local ok = n ~= "" and not exists
        hint:SetText(exists and "ya existe un perfil con ese nombre" or "")
        UI.SetEnabled(newBtn, ok)
        UI.SetEnabled(dupBtn, ok)
        UI.SetEnabled(renBtn, ok and ns.EditedProfileName() ~= "Default")
    end
    nameBox:SetScript("OnTextChanged", Validate)
    nameBox:SetScript("OnEnterPressed", nameBox.ClearFocus)
    actions.Refresh = Validate
    table.insert(UI.widgets, actions)

    feedback = UI.Note(c, "«Crear nuevo» empieza con los ajustes por defecto; «Duplicar» copia el perfil que editas. Default no se puede borrar ni renombrar.", 520)

    ---------------------------------------------------------------------------
    local list = {
        UI.Header(c, "Perfil que estás editando"),
        editDD,
        UI.Attach(usage),
        UI.Header(c, "Crear o renombrar"),
        actions,
        UI.Attach(feedback),
        UI.Header(c, "Qué perfil usa este personaje según el grupo"),
    }
    for _, key in ipairs(ns.SIZE_KEYS) do
        local dd = UI.Dropdown(c, ns.SIZE_NAMES[key], ProfileOptions,
            function() return ns.CharProfiles()[key] end,
            function(v)
                ns.CharProfiles()[key] = v
                ns.ActivateProfile()
                Refresh()
            end)
        local edit = UI.Button(dd, "Editar", 70, 18, function() SetEdit(ns.CharProfiles()[key]) end)
        edit:SetPoint("LEFT", dd.button, "RIGHT", 6, 0)
        local base = dd.Refresh
        dd.Refresh = function(self)
            base(self)
            local now = ns.RealSizeKey() == key
            dd.label:SetText(ns.SIZE_NAMES[key] .. (now and "  |cff4fc3f7· tu grupo ahora|r" or ""))
            UI.SetEnabled(edit, ns.CharProfiles()[key] ~= ns.EditedProfileName())
        end
        list[#list + 1] = dd
    end
    list[#list + 1] = UI.Note(c, "Así puedes tener un diseño para grupo, otro para ZG/AQ20 y otro para bandas de 40. El cambio es automático al entrar o salir de un grupo (si estás en combate, se aplica al salir).", 520)
    list[#list + 1] = UI.Header(c, "Vista previa")
    list[#list + 1] = UI.Dropdown(c, "Simular un grupo de", {
        { "party", "5 (grupo)" }, { "raid10", "10 (banda)" }, { "raid20", "20 (banda)" }, { "raid40", "40 (banda)" },
    }, function() return ns.testSize or "raid20" end, function(v)
        -- simular un tamaño enseña (y edita) el perfil asignado a ese tamaño
        ns.editName = ns.CharProfiles()[v]
        ns.ToggleTest(true, v)
        Refresh()
    end)
    list[#list + 1] = UI.Note(c, "En modo prueba siempre ves el perfil que estás editando, con el número de jugadores que elijas aquí.", 520)
    list[#list + 1] = UI.Header(c, "General")
    list[#list + 1] = UI.Check(c, "Ocultar marcos de grupo y banda de Blizzard (requiere /reload)",
        function() return ns.db.hideBlizzard end,
        function(v) ns.db.hideBlizzard = v ns.Print("se aplica tras /reload.") end)

    local st = UI.Stack(c, COL1, -6, list)
    UI.FitContent(c, { st })

    p.OnShow = function()
        st:Layout()
        UI.FitContent(c, { st })
    end
end

-------------------------------------------------------------------------------
-- Diseño
-------------------------------------------------------------------------------
local function BuildLayout(p)
    local _, c = UI.ScrollPage(p)
    local function E(w, cond) w.enableIf = cond return w end
    local function petsOn() return ns.EP().pets.enabled end
    -- en vertical las mascotas van en columnas; en horizontal, en filas
    local perCol = UI.Slider(c, "Mascotas por columna", 1, 10, 1, nil, PB("pets.perColumn"))
    local baseRefresh = perCol.Refresh
    perCol.Refresh = function(self)
        baseRefresh(self)
        perCol.label:SetText(ns.EP().layout.orientation == "horizontal" and "Mascotas por fila" or "Mascotas por columna")
    end
    local a = UI.Stack(c, COL1, -6, {
        UI.Header(c, "Tamaño"),
        UI.Slider(c, "Ancho", 30, 200, 1, nil, PB("layout.width")),
        UI.Slider(c, "Alto", 16, 100, 1, nil, PB("layout.height")),
        UI.Slider(c, "Escala", 0.5, 2, 0.05, UI.pct, PB("layout.scale")),
        UI.Slider(c, "Espacio entre jugadores", 0, 12, 1, nil, PB("layout.spacing")),
        UI.Slider(c, "Espacio entre grupos", 0, 40, 1, nil, PB("layout.groupSpacing")),
        UI.Header(c, "Mascotas"),
        UI.Check(c, "Mostrar", PB("pets.enabled")),
        E(UI.Check(c, "Pegadas a la banda, como un grupo más", PB("pets.attach")), petsOn),
        E(UI.Check(c, "Mismo tamaño que los jugadores", PB("pets.sameSize")), petsOn),
        UI.Attach(E(UI.Slider(c, "Ancho", 30, 200, 1, nil, PB("pets.width")),
            function() return petsOn() and not ns.EP().pets.sameSize end)),
        UI.Attach(E(UI.Slider(c, "Alto", 12, 100, 1, nil, PB("pets.height")),
            function() return petsOn() and not ns.EP().pets.sameSize end)),
        E(perCol, petsOn),
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
    local function On(path) return function() return UI.Bind(ns.EP, path)() and true or false end end
    local function Smooth(path)
        return Cond(UI.Check(c, ns.hasNativeSmooth and "Llenado y vaciado suave"
            or "Llenado y vaciado suave (no disponible en este cliente)", PB(path)), nil,
            function() return ns.hasNativeSmooth end)
    end
    local power = On("bars.showPower")

    local a = UI.Stack(c, COL1, -6, Flat({
        UI.Header(c, "Vida"),
        UI.Dropdown(c, "Textura", ns.TextureList, PB("bars.healthTex")),
        Smooth("bars.smooth"),
        BarColorBlock(c, BAR_COLORS, "bars.healthColor", "bars.customColor", "bars.healthBrightness"),

        UI.Header(c, "Fondo (vida que falta)"),
        UI.Dropdown(c, "Textura", ns.TextureList, PB("bars.bgTex")),
        BarColorBlock(c, BAR_COLORS, "bars.bgColor", "bars.bgCustom", "bars.bgBrightness"),
        UI.Slider(c, "Opacidad", 0, 1, 0.05, UI.pct, PB("bars.bgAlpha")),

        UI.Header(c, "Curación y escudos"),
        UI.Check(c, "Curación entrante", PB("bars.showHealPred")),
        Cond(UI.Attach(UI.Dropdown(c, "Textura", ns.TextureList, PB("bars.healPredTex"))), nil, On("bars.showHealPred")),
        Cond(UI.Attach(UI.Swatch(c, "Color", Col("bars.healPredColor"), ns.ProfileChanged, true)), nil,
            On("bars.showHealPred")),
        UI.Check(c, "Escudos (absorción)", PB("bars.showAbsorb")),
        Cond(UI.Attach(UI.Dropdown(c, "Textura", ns.TextureList, PB("bars.absorbTex"))), nil, On("bars.showAbsorb")),
        Cond(UI.Attach(UI.Swatch(c, "Color", Col("bars.absorbColor"), ns.ProfileChanged, true)), nil,
            On("bars.showAbsorb")),
    }))

    local b = UI.Stack(c, COL2, -6, Flat({
        UI.Header(c, "Maná / energía / ira"),
        UI.Check(c, "Mostrar", PB("bars.showPower")),
        Cond(UI.Attach(UI.Check(c, "Solo para quien usa maná", PB("bars.powerOnlyMana"))), nil, power),
        Cond(UI.Dropdown(c, "Textura", ns.TextureList, PB("bars.powerTex")), nil, power),
        Cond(Smooth("bars.powerSmooth"), nil, power),
        All(BarColorBlock(c, POWER_COLORS, "bars.powerColor", "bars.powerCustom", "bars.powerBrightness"), nil, power),
        Cond(UI.Slider(c, "Opacidad del fondo", 0, 1, 0.05, UI.pct, PB("bars.powerBgAlpha")), nil, power),
        Cond(UI.Slider(c, "Alto", 1, 12, 1, nil, PB("bars.powerHeight")), nil, power),

        UI.Header(c, "Marco"),
        UI.Swatch(c, "Color del borde", Col("bars.borderColor"), ns.ProfileChanged, true),
        UI.Slider(c, "Opacidad fuera de rango", 0.1, 1, 0.05, UI.pct, PB("bars.rangeAlpha")),

        UI.Header(c, "Resaltados"),
        UI.Check(c, "Resaltar mi objetivo", PB("bars.targetHighlight")),
        Cond(UI.Attach(UI.Swatch(c, "Color", Col("bars.targetColor"), ns.ProfileChanged, true)), nil,
            On("bars.targetHighlight")),
        UI.Check(c, "Marcar quien tiene amenaza (aggro)", PB("bars.aggro")),
        Cond(UI.Attach(UI.Swatch(c, "Color", Col("bars.aggroColor"), ns.ProfileChanged, true)), nil, On("bars.aggro")),

        UI.Header(c, "Tooltips"),
        UI.Dropdown(c, "Tooltip al pasar por un icono de aura", {
            { "always", "Siempre" }, { "ooc", "Solo fuera de combate" }, { "never", "Nunca" },
        }, PB("bars.auraTooltip")),
    }))
    UI.FitContent(c, { a, b })
end

-------------------------------------------------------------------------------
-- Textos
-------------------------------------------------------------------------------
local function TextSection(c, key, title, extra)
    local function root() return ns.EP().texts[key] end
    return Flat({
        UI.Header(c, title),
        TextBlock(c, root, PAfter, {
            show = { PB("texts." .. key .. ".show") },
            extra = extra,
            enableIf = function() return root().show end,
        }),
    })
end

local function BuildTexts(p)
    local _, c = UI.ScrollPage(p)
    local nameList = TextSection(c, "name", "Nombre", {
        UI.Check(c, "Con apellido", PB("texts.name.surname", function() ns.UpdateAllButtons() end)),
        UI.Slider(c, "Ancho máximo (% del marco)", 30, 100, 1, function(v) return v .. "%" end, PB("texts.name.width")),
    })
    for _, w in ipairs(TextSection(c, "status", "Texto de estado")) do nameList[#nameList + 1] = w end
    local a = UI.Stack(c, COL1, -6, nameList)

    -- avisos que salen en el texto de estado, cada uno con su color
    local S = function() return ns.EP().texts.status end
    local function statusOn() return S().show end
    local alerts = {
        UI.Header(c, "Qué muestra el texto de estado"),
        Cond(UI.Note(c, "Siempre: «Desconectado», «Muerto» y «Fantasma». Además, los que actives (si hay varios, sale el primero):", UI.W), nil, statusOn),
    }
    for _, st in ipairs({
        { "showRes", "resColor", "«Resucitando»", "Le están lanzando un resucitar." },
        { "showCharm", "charmColor", "«Controlado»", "Bajo control mental: puede atacaros." },
        { "showSummon", "summonColor", "«Invocación»", "Tiene una invocación pendiente, aceptada o rechazada." },
        { "showAFK", "afkColor", "«Ausente»", "Está ausente (AFK)." },
    }) do
        local function on() return statusOn() and S()[st[1]] end
        alerts[#alerts + 1] = Cond(UI.Check(c, st[3], PB("texts.status." .. st[1])), nil, statusOn)
        alerts[#alerts + 1] = Cond(UI.Attach(UI.Note(c, st[4], UI.W - 20)), nil, statusOn)
        alerts[#alerts + 1] = Cond(UI.Attach(UI.Swatch(c, "Color", function() return S()[st[2]] end, PAfter, true)), nil, on)
    end
    alerts[#alerts + 1] = UI.Note(c, "Usan la fuente, el tamaño y la posición del texto de estado. Beber y comer es un indicador (pestaña Indicadores).", UI.W)
    for _, w in ipairs(TextSection(c, "health", "Texto de vida", {
        UI.Dropdown(c, "Formato", {
            { "none", "Ninguno" },
            { "deficit", "Vida que falta (-1.2k)" },
            { "percent", "Porcentaje (85%)" },
            { "current", "Vida actual (3.4k)" },
            { "both", "Actual / máxima" },
        }, PB("texts.health.format")),
        UI.Check(c, "Ocultar con la vida llena", PB("texts.health.hideFull")),
    })) do alerts[#alerts + 1] = w end
    local b = UI.Stack(c, COL2, -6, alerts)
    UI.FitContent(c, { a, b })
end

-------------------------------------------------------------------------------
-- Iconos de estado
-------------------------------------------------------------------------------
local function ElementSection(c, key, title)
    local function root() return ns.EP().elements[key] end
    local function on() return root().show end
    local list = {
        UI.Header(c, title),
        UI.Check(c, "Mostrar", PB("elements." .. key .. ".show")),
    }
    -- el de listos solo existe durante la comprobación: no tiene «cuándo»
    if key ~= "ready" then
        list[#list + 1] = Cond(UI.Attach(UI.Dropdown(c, "Cuándo", {
            { "always", "Siempre" },
            { "ready", "Solo en la comprobación de listos" },
            { "ooc", "Solo fuera de combate" },
        }, PB("elements." .. key .. ".when"))), nil, on)
    end
    return Flat({
        list,
        Cond(UI.Check(c, "Por encima de los indicadores", PB("elements." .. key .. ".onTop")), nil, on),
        Cond(UI.Slider(c, "Tamaño", 6, 40, 1, nil, PB("elements." .. key .. ".size")), nil, on),
        PositionBlock(c, root, PAfter, { enableIf = on }),
    })
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
    c:SetWidth(262)
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
    local fallbackNote = UI.Note(c, "", 230)
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

    -- Debuff de banda (solo si el contexto trae «debuff»): prioridad, activo,
    -- jefe y borrar / restaurar. ctx.debuff = { get(campo), set(campo, v),
    -- bosses(), removeLabel(), remove(), exists() }
    local function D() return sideCtx and sideCtx.debuff end
    local function isDeb() return D() ~= nil end
    local function DG(field)
        return function() local d = D() return d and d.get(field) end,
            function(v) local d = D() if d then d.set(field, v) Changed() end end
    end
    local debDel = UI.Confirm(UI.Button(c, "", UI.W, 20, function()
        local d = D()
        if d then d.remove() end
    end))
    debDel.Refresh = function()
        local d = D()
        if d and not debDel.armed then debDel.text:SetText(d.removeLabel() or "") end
    end
    table.insert(UI.widgets, debDel)

    local st = UI.Stack(c, 6, -2, {
        W(UI.Header(c, "Debuff"), isDeb),
        W(UI.Slider(c, "Prioridad (5 = se ve antes)", 1, ns.PRIO_MAX, 1, nil, DG("prio")), isDeb),
        W(UI.Check(c, "Activo", DG("enabled")), isDeb),
        W(UI.Dropdown(c, "Jefe", function() local d = D() return d and d.bosses() or {} end, DG("boss")),
            function() local d = D() return d ~= nil and #d.bosses() > 1 end),
        W(debDel, function() local d = D() return d ~= nil and d.removeLabel() ~= nil end),

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
        E(UI.Attach(UI.Slider(c, "Desplazamiento Y", -30, 30, 1, nil, SG("offsetY"))), hasGlow),

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
    local reset = UI.Confirm(UI.Button(side, "", 140, 22, function()
        if sideCtx and sideCtx.clear then sideCtx.clear() end
        Changed()
    end))
    reset:SetPoint("BOTTOMRIGHT", -12, 12)

    side.Refresh = function()
        if not sideCtx then side:Hide() return end
        -- el debuff se ha borrado: no queda nada que editar
        if sideCtx.debuff and not sideCtx.debuff.exists() then CloseSide() return end
        local name, icon = sideCtx.title()
        side.icon:SetTexture(icon or 134400)
        side.title:SetText(name or "")
        side.sub:SetText(sideCtx.sub or "")
        local own = sideCtx.load() ~= nil
        if sideCtx.fallback then
            copy:Show()
            if not reset.armed then reset.text:SetText("Quitar el propio") end
            reset:SetShown(own)
            side.state:SetText(own and "|cff55ff55Tiene resaltado propio|r (sustituye al del indicador)."
                or "|cffaaaaaaAhora usa el del indicador.|r Cambia cualquier opción para crear uno propio.")
        else
            copy:Hide()
            if not reset.armed then reset.text:SetText("Restablecer") end
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
local KIND_LABEL = { aura = "", raiddebuff = "banda", debuffs = "debuffs" }
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
    left:SetPoint("BOTTOMLEFT", 6, 4)
    left:SetWidth(196)
    -- la lista llega hasta abajo: caben tantas filas como deja el espacio
    -- que ocupan los botones y la nota de debajo
    local leftH = math.max(200, (p:GetHeight() or 548) - 8)
    local BELOW = 96
    local ROWS = math.max(8, math.floor((leftH - BELOW - 4) / 20))
    local offset = 0
    local rows = {}
    local listBg = CreateFrame("Frame", nil, left, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT")
    listBg:SetSize(196, ROWS * 20 + 4)
    UI.Backdrop(listBg, { 0.04, 0.04, 0.05, 1 })
    listBg:EnableMouseWheel(true)
    local RefreshList
    local listBar = UI.ScrollBar(listBg, function(v) offset = v RefreshList() end)
    listBar:SetPoint("TOPRIGHT", -3, -3)
    listBar:SetPoint("BOTTOMRIGHT", -3, 3)

    RefreshList = function()
        local list = Inds()
        offset = math.max(0, math.min(offset, #list - ROWS))
        listBar:SetRange(#list - ROWS, #list > 0 and ROWS / #list or 1)
        listBar:SetPos(offset)
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
        row:SetSize(180, 19)
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
        row.name:SetWidth(108)
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
    local delInd = Btn("Borrar", 66, y, 62, function()
        local ind = Sel()
        if not ind then return end
        if ind.kind ~= "aura" then
            ns.Print("los indicadores integrados no se borran; desactívalos con la casilla 'Activo'.")
            return
        end
        table.remove(Inds(), selInd)
        IndChanged()
    end)
    UI.Confirm(delInd)
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
    c:SetWidth(370)
    local function K() local s = Sel() return s and s.kind end
    local function T() local s = Sel() return s and EffType(s) end
    local function isAura() return K() == "aura" end
    -- borde del marco / tinte sobre la vida: cubren el marco entero (sin posición ni tamaño)
    local function frameT() local t = T() return t == "border" or t == "overlay" end
    local function notDispel() return not frameT() end
    local function iconLike() local t = T() return t == "icon" or t == "icons" end
    local function rect() local t = T() return t == "square" or t == "bar" end
    local function iconsT() return T() == "icons" end
    local function colored() local t = T() return isAura() and (t == "square" or t == "bar" or t == "text") end
    local function isMissing() local s = Sel() return isAura() and s.mode == "missing" end
    -- tiene duración (no es "le falta" ni disipable)
    -- barra que mide escudos o curación entrante: no vigila auras ni tiene tiempo
    local function unitBar() return isAura() and ns.IndicatorUnitMeasure(Sel()) end
    local function watchAuras() return isAura() and not unitBar() end
    -- vigila los hechizos de su lista (no «los que puedo disipar»)
    local function dispWatch() return watchAuras() and (Sel().watch == "dispellable" or Sel().watch == "debuffTypes") end
    local function listWatch() return watchAuras() and not dispWatch() end
    local function timed()
        if T() == "bar" and (Sel().barMeasure or "time") ~= "time" then return false end
        if frameT() then return false end
        return notDispel() and not isMissing()
    end
    local function hasText() return timed() end
    -- borde o tinte que enseña debuffs (los que tienen tipo)
    local function typeIconT()
        local s = Sel()
        return frameT() and (K() ~= "aura" or s.watch == "dispellable" or s.watch == "debuffTypes" or s.auraType == "HARMFUL")
    end
    local function typeIconOn() return Sel().typeIcon end

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

    -- texto propio del tipo «Texto»
    local customW = CreateFrame("Frame", nil, c)
    customW:SetSize(UI.W, 36)
    local cl = UI.Label(customW, "Texto")
    cl:SetPoint("TOPLEFT")
    local customBox = UI.EditBox(customW, UI.W)
    customBox:SetPoint("TOPLEFT", 0, -14)
    local function SaveCustom()
        local s = Sel()
        local t = customBox:GetText()
        if s and t ~= s.customText then s.customText = t IndChanged() end
    end
    customBox:SetScript("OnEnterPressed", function(self) SaveCustom() self:ClearFocus() end)
    customBox:SetScript("OnEditFocusLost", SaveCustom)
    customW.Refresh = function()
        local s = Sel()
        if not customBox:HasFocus() then customBox:SetText(s and s.customText or "") end
    end
    table.insert(UI.widgets, customW)

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
            r.del = UI.Confirm(UI.Button(r, "x", 16, 16, function()
                local s = Sel()
                local key = table.remove(s[field], i)
                if withHighlight and key ~= nil then s.spellStyles[key] = nil end
                if key ~= nil then s.exact[key] = nil s.ranks[key] = nil end
                CloseSide()
                IndChanged()
            end), "?")
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

    ---------------------------------------------------------------------------
    -- Muestra del marco: es un marco de verdad (el mismo código que el modo
    -- prueba) con todos los indicadores del perfil a la vez y todas sus
    -- opciones. El indicador elegido se puede arrastrar: al soltarlo se elige
    -- el punto de anclaje más cercano (de los 9) y el desplazamiento X/Y exacto.
    ---------------------------------------------------------------------------
    local SAMPLE_W, SAMPLE_H = 340, 110
    local posSample = CreateFrame("Frame", nil, c)
    posSample:SetSize(SAMPLE_W, SAMPLE_H + 22)
    local psBg = posSample:CreateTexture(nil, "BACKGROUND")
    psBg:SetPoint("TOPLEFT")
    psBg:SetPoint("TOPRIGHT")
    psBg:SetHeight(SAMPLE_H)
    psBg:SetColorTexture(0.03, 0.03, 0.04, 1)
    local psHint = UI.Label(posSample, "Arrastra el indicador para colocarlo donde quieras.")
    psHint:SetPoint("BOTTOMLEFT", 0, 2)
    psHint:SetWidth(SAMPLE_W)
    psHint:SetTextColor(0.65, 0.65, 0.65)

    local pb = CreateFrame("Frame", nil, posSample)
    ns.BuildVisuals(pb)

    -- asa invisible encima del indicador elegido (para arrastrarlo)
    local handle = CreateFrame("Button", nil, pb)
    handle:SetFrameLevel(pb:GetFrameLevel() + 400)
    handle.hl = handle:CreateTexture(nil, "HIGHLIGHT")
    handle.hl:SetAllPoints()
    handle.hl:SetColorTexture(1, 1, 1, 0.25)
    handle:SetMovable(true)
    handle:RegisterForDrag("LeftButton")

    local function PX(f, pt)
        if pt:find("LEFT") then return f:GetLeft() end
        if pt:find("RIGHT") then return f:GetRight() end
        return (f:GetLeft() + f:GetRight()) / 2
    end
    local function PY(f, pt)
        if pt:find("TOP") then return f:GetTop() end
        if pt:find("BOTTOM") then return f:GetBottom() end
        return (f:GetTop() + f:GetBottom()) / 2
    end
    local function Round(v) return math.floor(v + 0.5) end
    local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

    handle:SetScript("OnDragStart", function(self) self:StartMoving() end)
    handle:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local s = Sel()
        if not s then return end
        -- tercio del marco en el que cae el centro -> punto de anclaje
        local cx = (self:GetLeft() + self:GetRight()) / 2
        local cy = (self:GetTop() + self:GetBottom()) / 2
        local fx = (cx - pb:GetLeft()) / pb:GetWidth()
        local fy = (cy - pb:GetBottom()) / pb:GetHeight()
        local v = fy > 2 / 3 and "TOP" or (fy < 1 / 3 and "BOTTOM" or "")
        local h = fx < 1 / 3 and "LEFT" or (fx > 2 / 3 and "RIGHT" or "")
        local pt = v .. h
        if pt == "" then pt = "CENTER" end
        s.point = pt
        s.x = Clamp(Round(PX(self, pt) - PX(pb, pt)), -80, 80)
        s.y = Clamp(Round(PY(self, pt) - PY(pb, pt)), -60, 60)
        IndChanged()
    end)

    posSample.Refresh = function()
        if not ns.P then return end
        -- el marco de muestra usa el perfil que se está viendo; si editas otro,
        -- se avisa (en modo prueba, el que se ve es siempre el que editas)
        local same = ns.EditedProfileName() == ns.activeName
        local L = ns.P.layout
        local W, H = L.width, L.height
        local z = math.min(3, (SAMPLE_W - 60) / W, (SAMPLE_H - 20) / H)
        pb:SetScale(z)
        pb:SetSize(W, H)
        pb:ClearAllPoints()
        pb:SetPoint("CENTER", psBg, "CENTER", 0, 0)
        -- solo el indicador que se edita (si es del perfil que se ve)
        ns.FillPreviewButton(pb, same and selInd or nil)

        local s = Sel()
        local strip = s and s.type == "bar" and ns.STRIP_SIDE[s.span]
        local whole = s and (s.type == "border" or s.type == "overlay")
        local w = same and s and not whole and not strip and pb.ind and pb.ind[selInd]
        handle:ClearAllPoints()
        if w then
            handle:SetAllPoints(w)
            handle:Show()
            psHint:SetText("Arrastra el indicador para colocarlo donde quieras.")
        else
            handle:Hide()
            psHint:SetText(same and "" or ("Se ve el perfil activo («%s»). Activa el modo prueba para ver el que editas.")
                :format(tostring(ns.activeName)))
        end
    end
    table.insert(UI.widgets, posSample)

    -- colores por tipo (comunes a todos los indicadores del perfil)
    local function DispelSwatches()
        local function typed()
            if K() == "raiddebuff" or K() == "debuffs" then return true end
            local s = Sel()
            return isAura() and (s.watch == "dispellable" or s.watch == "debuffTypes" or s.auraType == "HARMFUL") and (frameT() or iconLike())
        end
        local function on() return Sel().dispelColor end
        local list = {}
        for _, d in ipairs({
            { "Magic", "Magia" }, { "Curse", "Maldición" }, { "Disease", "Enfermedad" }, { "Poison", "Veneno" },
            { "none", "Sin tipo (borde y tinte)" },
        }) do
            list[#list + 1] = WE(UI.Attach(UI.Swatch(c, ns.DispelLabel(d[1], d[2]), function() return ns.EP().dispelColors[d[1]] end,
                IndChanged)), function() return typed() and (d[1] ~= "none" or frameT()) end, on)
        end
        list[#list + 1] = WE(UI.Attach(UI.Note(c, "Son los mismos para todos los indicadores del perfil. Si el juego oculta el tipo del debuff (puede pasar en combate o en instancias), el icono queda con borde negro y el borde o el tinte usan «Sin tipo».", 340)),
            typed, on)
        return list
    end

    local auraSupport = UI.Attach(UI.Note(c, "", 340))
    auraSupport.Refresh = function(self)
        self.text:SetText(ns.IndicatorAuraSummary(Sel()))
        self:SetHeight(self.text:GetStringHeight() + 2)
    end
    table.insert(UI.widgets, auraSupport)
    local st = UI.Stack(c, 4, -4, Flat({
        UI.Header(c, "Indicador"),
        nameW,
        UI.Check(c, "Activo", IB("enabled")),
        auraSupport,
        W(UI.Dropdown(c, "Tipo", {
            { "square", "Cuadrado de color" }, { "icon", "Icono" }, { "icons", "Varios iconos" },
            { "bar", "Barra" }, { "text", "Texto" },
            { "border", "Borde del marco" }, { "overlay", "Tinte sobre la vida" },
        }, IB("type")), isAura),
        W(UI.Attach(UI.Dropdown(c, "Qué mide", {
            { "time", "Tiempo restante del aura" },
            { "stacks", "Cargas del aura" },
            { "absorb", "Escudos del jugador (absorción)" },
            { "heal", "Curación entrante del jugador" },
        }, IB("barMeasure"))), function() return isAura() and T() == "bar" end),
        W(UI.Attach(UI.Slider(c, "Máximo de cargas", 1, 20, 1, nil, IB("barMaxStacks"))),
            function() return isAura() and T() == "bar" and Sel().barMeasure == "stacks" end),
        W(UI.Attach(UI.Note(c, "Se compara con su vida máxima. No vigila auras: se ve siempre que haya algo.", 340)),
            unitBar),
        W(UI.Attach(UI.Dropdown(c, "Qué muestra", {
            { "time", "Tiempo restante" },
            { "custom", "Un texto propio" },
            { "name", "Nombre del hechizo" },
            { "stacks", "Cargas" },
            { "caster", "Quién lo lanzó" },
        }, IB("textShow"))), function() return isAura() and T() == "text" end),
        W(UI.Attach(customW), function() return isAura() and T() == "text" and Sel().textShow == "custom" end),
        W(UI.Attach(UI.Slider(c, "Máximo de letras", 0, 20, 1, function(v) return v == 0 and "todas" or tostring(v) end,
            IB("nameLetters"))), function() return isAura() and T() == "text" and Sel().textShow == "name" end),

        W(UI.Header(c, "Qué vigila"), watchAuras),
        W(UI.Dropdown(c, "Vigila", {
            { "spells", "Los hechizos de su lista" },
            { "dispellable", "Los debuffs que puedo disipar" },
            { "debuffTypes", "Debuffs por tipo (cualquier clase)" },
        }, IB("watch")), watchAuras),
        W(UI.Attach(UI.Note(c, "El juego decide cuáles puedes disipar tú (según tu clase y talentos).", 340)), function() return dispWatch() and Sel().watch == "dispellable" end),
        W(UI.Attach(UI.Note(c, "Muestra los tipos marcados aunque tu clase no pueda disiparlos. En combate, el borde y el tinte los dibuja el sistema nativo del juego.", 340)), function() return dispWatch() and Sel().watch == "debuffTypes" end),
        W(UI.Attach(UI.Check(c, ns.DispelLabel("Magic", "Magia"), IB("dispelTypes.Magic"))), dispWatch),
        W(UI.Attach(UI.Check(c, ns.DispelLabel("Curse", "Maldición"), IB("dispelTypes.Curse"))), dispWatch),
        W(UI.Attach(UI.Check(c, ns.DispelLabel("Disease", "Enfermedad"), IB("dispelTypes.Disease"))), dispWatch),
        W(UI.Attach(UI.Check(c, ns.DispelLabel("Poison", "Veneno"), IB("dispelTypes.Poison"))), dispWatch),
        W(UI.Check(c, "Si el juego oculta el tipo, mostrarlo igualmente", IB("unknownType")), function() return dispWatch() and Sel().watch == "dispellable" end),
        W(UI.Attach(UI.Note(c, "En combate o en instancias el juego puede ocultar el tipo del debuff. Activado: se muestra (con el color «Sin tipo»). Desactivado: no se muestra.", 340)), function() return dispWatch() and Sel().watch == "dispellable" end),
        W(UI.Dropdown(c, "Auras", { { "HELPFUL", "Bufos" }, { "HARMFUL", "Debufos" } }, IB("auraType")), listWatch),
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
            end), listWatch),
        W(UI.Dropdown(c, "Mostrar cuando", { { "present", "Lo tiene" }, { "missing", "Le falta" } }, IB("mode")), listWatch),
        W(UI.Check(c, "Solo fuera de combate", IB("onlyOOC")), watchAuras),
        W(UI.Note(c, "Hechizos (por ID o nombre; vale cualquier rango). Sin hechizos = todas las auras de ese tipo. El orden decide cuál se ve primero.", 340), listWatch),
        W(spellsW, listWatch),

        W(UI.Header(c, "Qué vigila"), function() return K() == "raiddebuff" end),
        W(UI.Note(c, "Muestra el debuff de mayor prioridad de la lista de la instancia (pestaña Debuffs de banda).", 340),
            function() return K() == "raiddebuff" end),
        W(UI.Slider(c, "Mostrar solo si quedan menos de (s)", 0, 30, 1,
            function(v) return v == 0 and "siempre" or (v .. " s") end, IB("showBelow")), function() return isAura() and not isMissing() end),

        W(UI.Header(c, "Qué vigila"), function() return K() == "debuffs" end),
        W(UI.Check(c, "Solo los que yo puedo disipar", IB("onlyDispellable")),
            function() return K() == "debuffs" end),
        W(UI.Check(c, "No repetir los que ya muestra otro indicador", IB("excludeClaimed")),
            function() return K() == "debuffs" end),
        W(UI.Note(c, "Ignorar estos debuffs (lista negra):", 340), function() return K() == "debuffs" end),
        W(blackW, function() return K() == "debuffs" end),

        UI.Header(c, "Posición y tamaño"),
        posSample,
        PositionBlock(c, Sel, IndChanged, { showIf = function()
            return notDispel() and not (T() == "bar" and ns.STRIP_SIDE[Sel().span])
        end }),
        W(sizeW, iconLike),
        W(UI.Slider(c, "Ancho", 1, 120, 1, nil, IB("width")), rect),
        W(UI.Attach(UI.Slider(c, "Alto", 1, 60, 1, nil, IB("height"))), rect),
        W(UI.Dropdown(c, "Ocupar", {
            { "none", "No (su ancho y alto)" },
            { "width", "Todo el ancho, encima del marco" },
            { "height", "Todo el alto, encima del marco" },
            { "stripTop", "Franja propia arriba" },
            { "stripBottom", "Franja propia abajo" },
            { "stripLeft", "Franja propia a la izquierda" },
            { "stripRight", "Franja propia a la derecha" },
        }, IB("span")), function() return T() == "bar" end),
        W(UI.Attach(UI.Note(c, "Con franja propia, la vida se acorta para dejarle sitio (como la barra de maná). Arriba y abajo usan el alto; izquierda y derecha, el ancho.", 340)),
            function() return T() == "bar" and ns.STRIP_SIDE[Sel().span] ~= nil end),
        W(UI.Dropdown(c, "Orientación de la barra", { { "HORIZONTAL", "Horizontal" }, { "VERTICAL", "Vertical" } },
            IB("barOrient")), function() return T() == "bar" end),
        W(UI.Attach(UI.Check(c, "Vaciar al revés", IB("barReverse"))), function() return T() == "bar" end),

        W(UI.Slider(c, "Máximo de iconos", 1, 8, 1, nil, IB("max")), iconsT),
        W(UI.Dropdown(c, "Crecen hacia", { { "LEFT", "Izquierda" }, { "RIGHT", "Derecha" }, { "UP", "Arriba" }, { "DOWN", "Abajo" } },
            IB("grow")), iconsT),
        W(UI.Slider(c, "Espacio entre iconos", 0, 10, 1, nil, IB("spacing")), iconsT),

        W(UI.Header(c, "Borde del marco"), function() return T() == "border" end),
        W(UI.Slider(c, "Grosor", 1, 6, 1, nil, IB("width")), function() return T() == "border" end),
        W(UI.Check(c, "Por dentro del marco", IB("borderInside")), function() return T() == "border" end),
        W(UI.Header(c, "Tinte sobre la vida"), function() return T() == "overlay" end),
        W(UI.Dropdown(c, "Forma", {
            { "up", "Degradado de abajo arriba" },
            { "down", "Degradado de arriba abajo" },
            { "solid", "Liso" },
        }, IB("tintShape")), function() return T() == "overlay" end),
        W(UI.Slider(c, "Intensidad", 0.1, 1, 0.05, UI.pct, IB("overlayAlpha")), function() return T() == "overlay" end),

        -- borde / tinte de debuffs: icono nativo del tipo encima
        W(UI.Header(c, "Icono del tipo"), typeIconT),
        W(UI.Check(c, ns.DispelLabel("Poison", "Mostrar el icono del tipo"), IB("typeIcon")), typeIconT),
        WE(UI.Slider(c, "Tamaño", 8, 32, 1, nil, IB("typeIconSize")), typeIconT, typeIconOn),
        PositionBlock(c, function() return Sel().typeIconPos end, IndChanged, { showIf = typeIconT, enableIf = typeIconOn }),

        UI.Header(c, "Aspecto"),
        W(UI.Check(c, "Color según tipo (magia, veneno...)", IB("dispelColor")), function()
            if K() == "raiddebuff" or K() == "debuffs" then return true end
            local s = Sel()
            return isAura() and (s.watch == "dispellable" or s.watch == "debuffTypes" or s.auraType == "HARMFUL") and (frameT() or iconLike())
        end),
        DispelSwatches(),
        WE(UI.Attach(UI.Swatch(c, "Color", function() return Sel().color end, IndChanged, true)),
            function() return colored() or frameT() end,
            function() return colored() or not Sel().dispelColor end),
        W(UI.Check(c, "Borde negro", IB("showBorder")),
            function() local t = T() return notDispel() and t ~= "text" end),
        W(UI.Check(c, "Barrido del tiempo", IB("swipe")),
            function() local t = T() return timed() and (t == "icon" or t == "icons" or t == "square") end),
        WE(UI.Attach(UI.Dropdown(c, "Estilo del barrido", {
            { "clock", "Reloj" },
            { "clockReverse", "Reloj inverso (se llena)" },
            { "clockEdge", "Reloj con borde" },
            { "drainV", "Llenado vertical (de abajo arriba)" },
            { "drainH", "Llenado horizontal (de izquierda a derecha)" },
            { "bar", "Barra fina abajo (crece)" },
        }, function() return Sel().swipeStyle or "clock" end, function(v) Sel().swipeStyle = v IndChanged() end)),
            function() local t = T() return timed() and (t == "icon" or t == "icons" or t == "square") end,
            function() return Sel().swipe ~= false end),
        W(UI.Slider(c, "Aviso con menos de (s)", 0, 15, 1,
            function(v) return v == 0 and "no" or (v .. " s") end, IB("warnAt")), timed),
        WE(UI.Attach(UI.Swatch(c, "Color de aviso (en iconos, el borde)", function() return Sel().warnColor end, IndChanged, true)),
            timed, function() return Sel().warnAt > 0 end),

        -- en el tipo «Texto», este es el propio texto: va donde el indicador y con su color
        W(UI.Header(c, "Texto del tiempo"), function() return hasText() and T() ~= "text" end),
        W(UI.Header(c, "Texto"), function() return isAura() and T() == "text" end),
        TextBlock(c, function() return Sel().timerText end, IndChanged, {
            show = { IB("timer") },
            showCheckIf = function() return T() ~= "text" end,
            showIf = function() return hasText() or (isAura() and T() == "text") end,
            enableIf = function() return T() == "text" or Sel().timer end,
            colorIf = function() return T() ~= "text" end,
            positionIf = function() return T() ~= "text" end,
        }),
        W(UI.Header(c, "Texto de las cargas"), hasText),
        TextBlock(c, function() return Sel().stacksText end, IndChanged, {
            show = { IB("stacks") },
            showIf = hasText,
            enableIf = function() return Sel().stacks end,
            positionIf = function() return T() ~= "text" end,
        }),

        UI.Header(c, "Resaltado"),
        hlSummary,
        hlButton,
        W(UI.Note(c, "Excepciones: en la lista de hechizos, el botón «brillo» de cada uno le da un resaltado propio que sustituye a este.", 340), isAura),
        W(UI.Note(c, "Excepciones: en la pestaña «Debuffs de banda», haz clic en un debuff para darle un resaltado propio en esa instancia.", 340),
            function() return K() == "raiddebuff" end),
    }))

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
-- Izquierda, las instancias. Derecha, dos pestañas: «Lista» (agrupada por
-- jefe) y «Vistos» (lo que ha apuntado el registrador). Clic en un debuff:
-- panel lateral con prioridad, activo, jefe y resaltado.
-------------------------------------------------------------------------------
local selKey, picked = 0, false
local raidTab = "list"
local listOffset, seenOffset, instOffset = 0, 0, 0
local LIST_ROWS, INST_ROWS = 21, 25
local NEW_PRIO = 3
local OTHERS = "Otros / sin jefe"
local PLUS_TEX = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS_TEX = "Interface\\Buttons\\UI-MinusButton-Up"
local collapsed = {}      -- [instancia .. "\n" .. jefe] = true (solo esta sesión)
local query = ""
local showIgnored = false
local selDebuff

-- Tabla de la base de datos por instancia (creada si hace falta)
local function RaidT(field, key)
    local t = ns.db.raid[field][key]
    if not t then t = {} ns.db.raid[field][key] = t end
    return t
end

local function Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function KeyID(key)
    if type(key) == "number" then return key end
    return (select(3, ns.SpellKeyInfo(key)))
end

-- ¿Coincide con la búsqueda? (nombre o ID)
local function Matches(name, id)
    if query == "" then return true end
    local q = query:lower()
    if name and tostring(name):lower():find(q, 1, true) then return true end
    return id ~= nil and tostring(id):find(q, 1, true) ~= nil
end

-- Cambios de un debuff --------------------------------------------------------
local function SetPrio(inst, key, prio)
    local e = ns.GetDebuffList(inst)[key]
    if not e then return end
    prio = math.max(1, math.min(ns.PRIO_MAX, prio))
    -- igual que el de fábrica: no hace falta guardarlo
    if e.default and prio == e.defPrio then
        local c = ns.db.raid.custom[inst]
        if c then c[key] = nil end
    else
        RaidT("custom", inst)[key] = prio
    end
end

-- boss = nombre del jefe, o "" para «Otros / sin jefe»
local function SetBoss(inst, key, boss)
    local e = ns.GetDebuffList(inst)[key]
    if not e then return end
    local b = (boss ~= "" and boss) or nil
    if b == e.defBoss or (not e.default and b == nil) then
        local t = ns.db.raid.boss[inst]
        if t then t[key] = nil end
    else
        RaidT("boss", inst)[key] = b or false
    end
end

local function SetEnabled(inst, key, on)
    RaidT("disabled", inst)[key] = (not on) or nil
end

-- Borra uno propio, o devuelve uno de fábrica a su prioridad y jefe
local function RemoveDebuff(inst, key)
    local e = ns.GetDebuffList(inst)[key]
    if not e then return end
    for _, f in ipairs({ "custom", "boss" }) do
        local t = ns.db.raid[f][inst]
        if t then t[key] = nil end
    end
    if e.custom then
        for _, f in ipairs({ "disabled", "styles" }) do
            local t = ns.db.raid[f][inst]
            if t then t[key] = nil end
        end
    end
end

-- Añade un debuff a la lista (o lo reactiva si ya estaba)
local function AddDebuff(inst, key)
    if not ns.GetDebuffList(inst)[key] then RaidT("custom", inst)[key] = NEW_PRIO end
    local d = ns.db.raid.disabled[inst]
    if d then d[key] = nil end
    if type(key) == "number" then
        for _, f in ipairs({ "seen", "ignored" }) do
            local t = ns.db.raid[f][inst]
            if t then t[key] = nil end
        end
    end
end

-- Filas de cada lista ---------------------------------------------------------
-- Categoría de una clave en la lista de instancias
local function CategoryOf(key)
    local def = ns.RaidDebuffs[key]
    if not def then return "other" end
    if def.kind == "global" then return "global" end
    if def.status == "unannounced" then return "unannounced" end
    return def.kind
end

-- plegadas al empezar: todas menos las bandas (y la de la instancia elegida)
local catClosed = { dungeon = true, solo = true, world = true, zone = true, unannounced = true }

-- Filas: { cat, label, n, closed } (título de categoría) o { key }
local function InstanceRows()
    local groups, known = {}, {}
    for _, k in ipairs(ns.RaidOrder) do
        local cat = CategoryOf(k)
        groups[cat] = groups[cat] or {}
        table.insert(groups[cat], k)
        known[k] = true
    end
    -- instancias que el juego ha dado y no están en los datos
    local extra = {}
    for _, f in ipairs({ "custom", "seen", "names", "ignored", "boss", "learned" }) do
        for k in pairs(ns.db.raid[f]) do
            if not known[k] then known[k] = true extra[#extra + 1] = k end
        end
    end
    table.sort(extra, function(a, b) return ns.InstanceName(a) < ns.InstanceName(b) end)
    groups.other = extra

    local out = {}
    for _, k in ipairs(groups.global or {}) do out[#out + 1] = { key = k } end
    local order = {}
    for _, kind in ipairs(ns.KINDS) do order[#order + 1] = kind end
    order[#order + 1] = "unannounced"
    order[#order + 1] = "other"
    for _, cat in ipairs(order) do
        local list = groups[cat]
        if list and #list > 0 then
            local closed = catClosed[cat] and CategoryOf(selKey) ~= cat
            out[#out + 1] = { cat = cat, label = ns.KIND_NAMES[cat] or cat, n = #list, closed = closed }
            if not closed then
                for _, k in ipairs(list) do out[#out + 1] = { key = k } end
            end
        end
    end
    return out
end

-- ¿Estás ahí ahora? (instancia actual o jefe del mundo de tu zona)
local function IsHere(key)
    if ns.inInstance and key == ns.instKey then return true end
    for _, k in ipairs(ns.zoneKeys or {}) do
        if k == key then return true end
    end
    return false
end

-- Lista agrupada por jefe: filas { header = jefe, n, ck, closed } o entradas
local function ListRows()
    local bosses = ns.InstanceBosses(selKey)
    local groups, byBoss = {}, {}
    for _, b in ipairs(bosses) do
        local g = { boss = b, items = {} }
        groups[#groups + 1] = g
        byBoss[b] = g
    end
    local other = { items = {} }
    groups[#groups + 1] = other
    local total = 0
    for key, e in pairs(ns.GetDebuffList(selKey)) do
        total = total + 1
        e.key = key
        e.name = ns.SpellKeyInfo(key)
        e.id = KeyID(key)
        if Matches(e.name, e.id) then
            local g = (e.boss and byBoss[e.boss]) or other
            g.items[#g.items + 1] = e
        end
    end
    local rows = {}
    local grouped = #bosses > 0
    for _, g in ipairs(groups) do
        if #g.items > 0 then
            table.sort(g.items, function(a, b)
                if a.prio ~= b.prio then return a.prio > b.prio end
                return tostring(a.name) < tostring(b.name)
            end)
            local ck = tostring(selKey) .. "\n" .. (g.boss or "")
            -- buscando, todo abierto
            local closed = grouped and collapsed[ck] and query == "" or false
            if grouped then
                rows[#rows + 1] = { header = g.boss or OTHERS, n = #g.items, ck = ck, closed = closed }
            end
            if not closed then
                for _, e in ipairs(g.items) do rows[#rows + 1] = e end
            end
        end
    end
    return rows, total
end

local function SeenRows()
    local out = {}
    local function Add(t, ignored)
        for id, s in pairs(t or {}) do
            local name = s.name or ns.GetSpellName(id)
            if Matches(name, id) then
                out[#out + 1] = { id = id, name = name, icon = s.icon, count = s.count or 0, boss = s.boss, ignored = ignored }
            end
        end
    end
    Add(ns.db.raid.seen[selKey], false)
    if showIgnored then Add(ns.db.raid.ignored[selKey], true) end
    table.sort(out, function(a, b)
        if a.ignored ~= b.ignored then return not a.ignored end
        if a.count ~= b.count then return a.count > b.count end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

-- Página ----------------------------------------------------------------------
local function BuildRaid(p)
    local RefreshRaid
    local function RaidChanged()
        ns.RebuildDebuffLookup()
        UI.RefreshAll() -- esta página y el panel lateral, si está abierto
    end

    -- clic en un debuff: abrir su panel lateral
    local function Select(key)
        if key == nil then
            selDebuff = nil
            CloseSide()
            if RefreshRaid then RefreshRaid() end
            return
        end
        local inst = selKey
        selDebuff = key
        local function E() return ns.GetDebuffList(inst)[key] end
        OpenSide({
            title = function() return ns.SpellKeyInfo(key) end,
            sub = ("Debuff de banda en %s. Su resaltado propio sustituye al del indicador «Debuff de banda»."):format(ns.InstanceName(inst)),
            debuff = {
                exists = function() return E() ~= nil end,
                get = function(f)
                    local e = E()
                    if not e then return nil end
                    if f == "prio" then return e.prio end
                    if f == "enabled" then return not e.disabled end
                    if f == "boss" then return e.boss or "" end
                end,
                set = function(f, v)
                    if f == "prio" then SetPrio(inst, key, v)
                    elseif f == "enabled" then SetEnabled(inst, key, v)
                    elseif f == "boss" then SetBoss(inst, key, v) end
                end,
                bosses = function()
                    local out = {}
                    for _, b in ipairs(ns.InstanceBosses(inst)) do out[#out + 1] = { b, b } end
                    out[#out + 1] = { "", OTHERS }
                    return out
                end,
                removeLabel = function()
                    local e = E()
                    if not e then return nil end
                    if e.custom then return "Borrar de la lista" end
                    if e.changed then return "Restaurar prioridad y jefe" end
                end,
                remove = function()
                    local e = E()
                    local wasCustom = e and e.custom
                    RemoveDebuff(inst, key)
                    if wasCustom then Select(nil) end
                    RaidChanged()
                end,
            },
            load = function() return ns.GetDebuffStyle(inst, key) end,
            store = function(s) RaidT("styles", inst)[key] = s end,
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

    local function SelectInstance(k)
        selKey, picked = k, true
        listOffset, seenOffset = 0, 0
        Select(nil)
    end

    local function Wheel(frame, fn)
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function(_, d) fn(d) RefreshRaid() end)
    end

    ---------------------------------------------------------------------------
    -- Izquierda: instancias
    ---------------------------------------------------------------------------
    local left = CreateFrame("Frame", nil, p, "BackdropTemplate")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(176)
    UI.Backdrop(left, { 0.095, 0.095, 0.118, 1 }, { 0.19, 0.19, 0.235, 1 })
    local lt = UI.Label(left, "Instancias", "GameFontNormal")
    lt:SetPoint("TOPLEFT", 10, -8)
    lt:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

    local instArea = CreateFrame("Frame", nil, left)
    instArea:SetPoint("TOPLEFT", 4, -28)
    instArea:SetSize(168, INST_ROWS * 20)
    Wheel(instArea, function(d) instOffset = math.max(0, instOffset - d) end)
    local instBar = UI.ScrollBar(instArea, function(v) instOffset = v RefreshRaid() end)
    instBar:SetPoint("TOPRIGHT", 0, 0)
    instBar:SetPoint("BOTTOMRIGHT", 0, 0)

    local instRows = {}
    for i = 1, INST_ROWS do
        local r = CreateFrame("Button", nil, instArea)
        r:SetSize(156, 19)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
        r.sel = r:CreateTexture(nil, "BACKGROUND")
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.22)
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(1, 1, 1, 0.07)
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetSize(6, 6)
        r.dot:SetPoint("LEFT", 4, 0)
        r.dot:SetColorTexture(0.3, 0.9, 0.4, 1)
        -- +/- de las categorías
        r.exp = r:CreateTexture(nil, "ARTWORK")
        r.exp:SetSize(12, 12)
        r.exp:SetPoint("LEFT", 0, 0)
        r.name = UI.Label(r, "")
        r.name:SetPoint("LEFT", 14, 0)
        r.name:SetWidth(116)
        r.name:SetWordWrap(false)
        r.count = UI.Label(r, "")
        r.count:SetPoint("RIGHT", -4, 0)
        r.count:SetTextColor(0.6, 0.6, 0.6)
        r:SetScript("OnClick", function(self)
            if self.cat then
                -- plegar / desplegar la categoría (la de la elegida no se pliega)
                catClosed[self.cat] = not self.closed
                if catClosed[self.cat] and CategoryOf(selKey) == self.cat then catClosed[self.cat] = false end
                RefreshRaid()
            elseif self.key ~= nil then
                SelectInstance(self.key)
            end
        end)
        r:SetScript("OnEnter", function(self)
            if self.key == nil or not IsHere(self.key) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Estás aquí")
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        instRows[i] = r
    end

    ---------------------------------------------------------------------------
    -- Derecha: cabecera, pestañas y búsqueda
    ---------------------------------------------------------------------------
    local right = CreateFrame("Frame", nil, p)
    right:SetPoint("TOPLEFT", 186, 0)
    right:SetPoint("BOTTOMRIGHT")

    local title = UI.Label(right, "", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 2, -4)
    title:SetWidth(250)
    title:SetWordWrap(false)

    local tabSeen = UI.Button(right, "", 84, 20, function() raidTab = "seen" RefreshRaid() end)
    tabSeen:SetPoint("TOPRIGHT", 0, -2)
    local tabList = UI.Button(right, "Lista", 64, 20, function() raidTab = "list" RefreshRaid() end)
    tabList:SetPoint("RIGHT", tabSeen, "LEFT", -4, 0)

    local search = UI.EditBox(right, 230)
    search:SetPoint("TOPLEFT", 0, -30)
    local ph = UI.Label(search, "Buscar, o un ID / nombre para añadir")
    ph:SetPoint("LEFT", 6, 0)
    ph:SetTextColor(0.45, 0.45, 0.45)
    search:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        ph:SetShown(txt == "")
        query = txt:trim()
        listOffset, seenOffset = 0, 0
        RefreshRaid()
    end)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    local clearQ = UI.Button(right, "x", 20, 20, function()
        search:SetText("")
        search:ClearFocus()
    end)
    clearQ:SetPoint("LEFT", search, "RIGHT", 4, 0)
    local add = UI.Button(right, "+ Añadir", 80, 20, function()
        local key = ns.ParseSpellInput(search:GetText())
        if not key then return end
        AddDebuff(selKey, key)
        search:SetText("")
        search:ClearFocus()
        raidTab = "list"
        ns.RebuildDebuffLookup()
        Select(key) -- abre el panel para ponerle jefe y prioridad
    end)
    add:SetPoint("LEFT", clearQ, "RIGHT", 6, 0)

    local function ColLabel(text, x)
        local l = UI.Label(right, text)
        l:SetPoint("TOPLEFT", x, -58)
        l:SetTextColor(0.6, 0.6, 0.6)
        return l
    end
    local scrollInfo = UI.Label(right, "")
    scrollInfo:SetPoint("TOPRIGHT", -14, -58)
    scrollInfo:SetTextColor(0.6, 0.6, 0.6)

    local emptyText = UI.Label(right, "")
    emptyText:SetPoint("TOPLEFT", 4, -78)
    emptyText:SetWidth(400)
    emptyText:SetTextColor(0.6, 0.6, 0.6)

    -- aviso: el juego oculta los IDs aquí
    local warn = UI.Label(right, "")
    warn:SetPoint("TOPLEFT", 0, -72 - LIST_ROWS * 20 - 8)
    warn:SetWidth(418)
    warn:SetTextColor(1, 0.55, 0.3)

    ---------------------------------------------------------------------------
    -- Pestaña «Lista»
    ---------------------------------------------------------------------------
    local listCols = { ColLabel("Debuff", 38), ColLabel("ID", 192), ColLabel("Prioridad", 258), ColLabel("Activo", 326) }

    local listArea = CreateFrame("Frame", nil, right)
    listArea:SetPoint("TOPLEFT", 0, -72)
    listArea:SetSize(418, LIST_ROWS * 20)
    Wheel(listArea, function(d) listOffset = math.max(0, listOffset - d) end)
    local listBar = UI.ScrollBar(listArea, function(v) listOffset = v RefreshRaid() end)
    listBar:SetPoint("TOPRIGHT", -2, 0)
    listBar:SetPoint("BOTTOMRIGHT", -2, 0)

    local listRows = {}
    for i = 1, LIST_ROWS do
        local row = CreateFrame("Frame", nil, listArea)
        row:SetSize(406, 19)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.sel:SetAllPoints()
        row.sel:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.22)
        row.sel:Hide()

        -- clic: plegar el jefe, o abrir el panel del debuff
        row.click = CreateFrame("Button", nil, row)
        row.click:SetPoint("TOPLEFT")
        row.click:SetHeight(19)
        row.click.hl = row.click:CreateTexture(nil, "HIGHLIGHT")
        row.click.hl:SetAllPoints()
        row.click.hl:SetColorTexture(1, 1, 1, 0.07)
        row.click:SetScript("OnClick", function()
            local d = row.data
            if not d then return end
            if d.header then
                collapsed[d.ck] = (not collapsed[d.ck]) or nil
                RefreshRaid()
            else
                Select(d.key ~= selDebuff and d.key or nil)
            end
        end)

        -- fila de jefe
        row.h = CreateFrame("Frame", nil, row)
        row.h:SetAllPoints()
        row.exp = row.h:CreateTexture(nil, "ARTWORK")
        row.exp:SetSize(14, 14)
        row.exp:SetPoint("LEFT", 2, 0)
        row.hname = UI.Label(row.h, "", "GameFontNormal")
        row.hname:SetPoint("LEFT", 20, 0)
        row.hname:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
        row.hcount = UI.Label(row.h, "")
        row.hcount:SetPoint("LEFT", row.hname, "RIGHT", 6, 0)
        row.hcount:SetTextColor(0.6, 0.6, 0.6)

        -- fila de debuff (por encima del clic, para sus botones)
        row.e = CreateFrame("Frame", nil, row)
        row.e:SetAllPoints()
        row.e:SetFrameLevel(row.click:GetFrameLevel() + 1)
        row.icon = row.e:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(17, 17)
        row.icon:SetPoint("LEFT", 16, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        UI.IconTip(row.e, row.icon, function() return row.data and row.data.id end)
        row.name = UI.Label(row.e, "")
        row.name:SetPoint("LEFT", 38, 0)
        row.name:SetWidth(150)
        row.name:SetWordWrap(false)
        row.id = UI.Label(row.e, "")
        row.id:SetPoint("LEFT", 192, 0)
        row.id:SetTextColor(0.6, 0.6, 0.6)
        -- prioridad: un cuadro por nivel; clic en uno = esa prioridad
        row.sq = {}
        for k = 1, ns.PRIO_MAX do
            local b = CreateFrame("Button", nil, row.e)
            b:SetSize(10, 10)
            b:SetPoint("LEFT", 258 + (k - 1) * 12, 0)
            b.t = b:CreateTexture(nil, "ARTWORK")
            b.t:SetAllPoints()
            b:SetScript("OnClick", function()
                if row.data and not row.data.header then
                    SetPrio(selKey, row.data.key, k)
                    RaidChanged()
                end
            end)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(("Prioridad %d"):format(k))
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.sq[k] = b
        end
        row.toggle = CreateFrame("Button", nil, row.e, "BackdropTemplate")
        row.toggle:SetSize(14, 14)
        row.toggle:SetPoint("LEFT", 334, 0)
        UI.Backdrop(row.toggle, { 0.05, 0.05, 0.06, 1 })
        row.toggle.mark = row.toggle:CreateTexture(nil, "OVERLAY")
        row.toggle.mark:SetPoint("TOPLEFT", 3, -3)
        row.toggle.mark:SetPoint("BOTTOMRIGHT", -3, 3)
        row.toggle.mark:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        row.toggle:SetScript("OnClick", function()
            local d = row.data
            if d and not d.header then
                SetEnabled(selKey, d.key, d.disabled)
                RaidChanged()
            end
        end)
        -- punto de color: tiene resaltado propio
        row.styled = row.e:CreateTexture(nil, "ARTWORK")
        row.styled:SetSize(8, 8)
        row.styled:SetPoint("LEFT", 362, 0)
        listRows[i] = row
    end

    ---------------------------------------------------------------------------
    -- Pestaña «Vistos»
    ---------------------------------------------------------------------------
    local seenCols = { ColLabel("Debuff", 22), ColLabel("ID", 166), ColLabel("Veces · jefe", 214) }
    local clear = UI.Confirm(UI.Button(right, "Limpiar vistos", 90, 16, function()
        ns.db.raid.seen[selKey] = nil
        seenOffset = 0
        RefreshRaid()
    end))
    clear:SetPoint("TOPRIGHT", -14, -54)

    local seenArea = CreateFrame("Frame", nil, right)
    seenArea:SetPoint("TOPLEFT", 0, -72)
    seenArea:SetSize(418, LIST_ROWS * 20)
    Wheel(seenArea, function(d) seenOffset = math.max(0, seenOffset - d) end)
    local seenBar = UI.ScrollBar(seenArea, function(v) seenOffset = v RefreshRaid() end)
    seenBar:SetPoint("TOPRIGHT", -2, 0)
    seenBar:SetPoint("BOTTOMRIGHT", -2, 0)

    local seenRows = {}
    for i = 1, LIST_ROWS do
        local row = CreateFrame("Frame", nil, seenArea)
        row:SetSize(406, 19)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(17, 17)
        row.icon:SetPoint("LEFT")
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        UI.IconTip(row, row.icon, function() return row.data and row.data.id end)
        row.name = UI.Label(row, "")
        row.name:SetPoint("LEFT", 22, 0)
        row.name:SetWidth(140)
        row.name:SetWordWrap(false)
        row.id = UI.Label(row, "")
        row.id:SetPoint("LEFT", 166, 0)
        row.id:SetTextColor(0.6, 0.6, 0.6)
        row.count = UI.Label(row, "")
        row.count:SetPoint("LEFT", 214, 0)
        row.count:SetWidth(78)
        row.count:SetWordWrap(false)
        row.count:SetTextColor(0.6, 0.6, 0.6)
        row.add = UI.Button(row, "Añadir", 52, 16, function()
            local id = row.data and row.data.id
            if not id then return end
            local boss = row.data.boss
            AddDebuff(selKey, id)
            -- el jefe que dio el juego al verlo
            if boss then SetBoss(selKey, id, boss) end
            ns.RebuildDebuffLookup()
            Select(id) -- abre el panel para ponerle jefe y prioridad
        end)
        row.add:SetPoint("LEFT", 296, 0)
        -- Ignorar (no vuelve a salir) / Recuperar
        row.ign = UI.Button(row, "", 54, 16, function()
            local d = row.data
            if not d then return end
            local from, to = "seen", "ignored"
            if d.ignored then from, to = "ignored", "seen" end
            local src = ns.db.raid[from][selKey]
            local s = src and src[d.id]
            if src then src[d.id] = nil end
            RaidT(to, selKey)[d.id] = s or { name = d.name, icon = d.icon, count = d.count }
            RefreshRaid()
        end)
        row.ign:SetPoint("LEFT", 352, 0)
        seenRows[i] = row
    end

    local rec = UI.Check(right, "Registrar debuffs nuevos",
        function() return ns.db.raid.recorder end, function(v) ns.db.raid.recorder = v RefreshRaid() end)
    rec:SetPoint("TOPLEFT", 0, -72 - LIST_ROWS * 20 - 30)
    local ign = UI.Check(right, "Mostrar ignorados",
        function() return showIgnored end, function(v) showIgnored = v seenOffset = 0 RefreshRaid() end)
    ign:SetPoint("TOPLEFT", 200, -72 - LIST_ROWS * 20 - 30)

    ---------------------------------------------------------------------------
    -- Refresco
    ---------------------------------------------------------------------------
    local function Scroll(bar, offset, n)
        offset = math.max(0, math.min(offset, n - LIST_ROWS))
        bar:SetRange(n - LIST_ROWS, n > 0 and LIST_ROWS / n or 1)
        bar:SetPos(offset)
        if n > LIST_ROWS then
            scrollInfo:SetText(("%d-%d de %d"):format(offset + 1, math.min(n, offset + LIST_ROWS), n))
        else
            scrollInfo:SetText("")
        end
        return offset
    end

    local function RefreshInstances()
        local rows = InstanceRows()
        instOffset = math.max(0, math.min(instOffset, #rows - INST_ROWS))
        instBar:SetRange(#rows - INST_ROWS, #rows > 0 and INST_ROWS / #rows or 1)
        instBar:SetPos(instOffset)
        for i, r in ipairs(instRows) do
            local d = rows[i + instOffset]
            r.key = d and d.key
            r.cat = d and d.cat
            r.closed = d and d.closed
            if not d then
                r:Hide()
            elseif d.cat then
                r.exp:SetTexture(d.closed and PLUS_TEX or MINUS_TEX)
                r.exp:Show()
                r.name:SetText(d.label)
                if d.cat == "unannounced" or d.cat == "other" then
                    r.name:SetTextColor(0.55, 0.55, 0.55)
                else
                    r.name:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
                end
                r.count:SetText(d.n)
                r.sel:Hide()
                r.dot:Hide()
                r:Show()
            else
                r.exp:Hide()
                r.name:SetText(d.key == 0 and "Global" or ns.InstanceName(d.key))
                local g = CategoryOf(d.key) == "unannounced" and 0.6 or 1
                r.name:SetTextColor(g, g, g)
                r.count:SetText(Count(ns.GetDebuffList(d.key)))
                r.sel:SetShown(d.key == selKey)
                r.dot:SetShown(IsHere(d.key))
                r:Show()
            end
        end
    end

    local function RefreshList()
        local rows, total = ListRows()
        listOffset = Scroll(listBar, listOffset, #rows)
        for i, row in ipairs(listRows) do
            local d = rows[i + listOffset]
            row.data = d
            if not d then
                row:Hide()
            elseif d.header then
                row.h:Show()
                row.e:Hide()
                row.click:SetWidth(406)
                row.bg:SetColorTexture(1, 1, 1, 0.06)
                row.sel:Hide()
                row.exp:SetTexture(d.closed and PLUS_TEX or MINUS_TEX)
                row.hname:SetText(d.header)
                row.hcount:SetText(("(%d)"):format(d.n))
                row:Show()
            else
                row.h:Hide()
                row.e:Show()
                row.click:SetWidth(250)
                row.bg:SetColorTexture(1, 1, 1, 0)
                local _, icon = ns.SpellKeyInfo(d.key)
                row.icon:SetTexture(icon or 134400)
                row.name:SetText(d.name)
                local g = d.disabled and 0.5 or 1
                row.name:SetTextColor(g, g, g)
                row.id:SetText(d.id or "buscando...")
                for k, b in ipairs(row.sq) do
                    if k <= d.prio then
                        b.t:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], d.disabled and 0.35 or 1)
                    else
                        b.t:SetColorTexture(0.2, 0.2, 0.24, 1)
                    end
                end
                row.toggle.mark:SetShown(not d.disabled)
                row.sel:SetShown(d.key == selDebuff)
                local s = ns.GetDebuffStyle(selKey, d.key)
                local styled = s and (s.glow ~= "none" or s.border or s.tint or s.pulse or s.sound ~= "none" or s.scale ~= 1)
                if styled then
                    local c = (s.glow ~= "none" and s.color) or (s.border and s.borderColor) or (s.tint and s.tintColor) or { r = 1, g = 1, b = 1 }
                    row.styled:SetColorTexture(c.r, c.g, c.b, 1)
                    row.styled:Show()
                else
                    row.styled:Hide()
                end
                row:Show()
            end
        end
        if #rows == 0 then
            emptyText:SetText(total == 0 and "Lista vacía. Escribe un ID o nombre arriba y pulsa «+ Añadir»."
                or "Nada coincide con la búsqueda.")
        else
            emptyText:SetText("")
        end
    end

    local function RefreshSeen()
        local rows = SeenRows()
        seenOffset = Scroll(seenBar, seenOffset, #rows)
        for i, row in ipairs(seenRows) do
            local d = rows[i + seenOffset]
            row.data = d
            if d then
                row.icon:SetTexture(d.icon or ns.GetSpellIcon(d.id) or 134400)
                row.name:SetText(d.name or "?")
                local g = d.ignored and 0.5 or 1
                row.name:SetTextColor(g, g, g)
                row.id:SetText(d.id)
                local n = d.count == 1 and "1 vez" or (d.count .. " veces")
                row.count:SetText(d.boss and (n .. " · " .. d.boss) or n)
                row.ign.text:SetText(d.ignored and "Recuperar" or "Ignorar")
                row:Show()
            else
                row:Hide()
            end
        end
        if #rows > 0 then
            emptyText:SetText("")
        elseif query ~= "" then
            emptyText:SetText("Nada coincide con la búsqueda.")
        elseif not ns.db.raid.recorder then
            emptyText:SetText("El registrador está apagado: actívalo abajo para apuntar los debuffs nuevos.")
        else
            emptyText:SetText("Nada todavía. Entra en la instancia con el registrador activo: los debuffs que\nno estén en la lista aparecerán aquí (si el juego deja leerlos).")
        end
    end

    local function Tab(b, on)
        b:SetBackdropColor(on and 0.12 or 0.15, on and 0.3 or 0.15, on and 0.42 or 0.18, 1)
    end

    RefreshRaid = function()
        RefreshInstances()
        title:SetText(ns.InstanceName(selKey) .. (CategoryOf(selKey) == "unannounced" and "  |cff888888(sin anunciar)|r" or ""))
        local nSeen = Count(ns.db.raid.seen[selKey])
        tabSeen.text:SetText(nSeen > 0 and ("Vistos (%d)"):format(nSeen) or "Vistos")
        local isList = raidTab == "list"
        Tab(tabList, isList)
        Tab(tabSeen, not isList)
        listArea:SetShown(isList)
        for _, l in ipairs(listCols) do l:SetShown(isList) end
        seenArea:SetShown(not isList)
        for _, l in ipairs(seenCols) do l:SetShown(not isList) end
        clear:SetShown(not isList and nSeen > 0)
        rec:SetShown(not isList)
        ign:SetShown(not isList)
        if isList then RefreshList() else RefreshSeen() end
        -- con «Limpiar» a la vista, el contador de scroll se aparta
        scrollInfo:ClearAllPoints()
        scrollInfo:SetPoint("TOPRIGHT", clear:IsShown() and -110 or -14, -58)
        add:SetEnabled(query ~= "")
        add:SetAlpha(query ~= "" and 1 or 0.4)
        clearQ:SetShown(query ~= "")
        local hidden = ns.inInstance and ns.raidSecret and (selKey == ns.instKey or selKey == 0)
        warn:SetText(hidden and "Aviso: en esta instancia el juego oculta los IDs de algunos debuffs. Esos no se pueden detectar ni registrar." or "")
    end

    p.OnShow = function()
        -- hasta que elijas una, se sigue la instancia en la que estás
        if not picked then selKey = (ns.inInstance and ns.instKey) or (ns.zoneKeys and ns.zoneKeys[1]) or 0 end
        rec.Refresh()
        ign.Refresh()
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

    local names = { "Perfiles", "Diseño", "Barras", "Textos", "Iconos de estado", "Indicadores", "Catálogo", "Debuffs de instancia" }
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
    if not win then
        CreateWindow()
        win:Hide() -- CreateFrame la deja visible: sin esto el primer /mf la cerraba
    end
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
        if not ns.testing and not IsInGroup() then ns.ToggleTest(true) end
        UI.RefreshAll()
    end
end
