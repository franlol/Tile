-------------------------------------------------------------------------------
-- MendFrames - Catálogo de hechizos por clase (WoW Forever)
--
-- Fuente: foreverdb.net (datos extraídos del cliente de Forever, nov. 2026).
-- Los hechizos de siempre conservan su ID de Classic (rango 1). Los nuevos de
-- Forever que vienen de talentos se guardan por nombre ("n:..."): el aura que
-- ponen puede tener otro ID que el talento, y el nombre vale para todos.
-- El cliente está en inglés, así que los nombres van en inglés.
--
-- Cada agrupación es de un solo tipo de aura (bufo o debufo). El "de quién"
-- (míos / de los demás / de cualquiera) se elige al añadirla.
-- family: hechizos equivalentes (p. ej. Fortaleza y Rezo de Fortaleza); en
-- modo "le falta" se crea un indicador por familia.
-------------------------------------------------------------------------------

local _, ns = ...

local function S(class, key, note, extra)
    local e = { class = class, note = note }
    if type(key) == "number" then e.id = key else e.name = key end
    if extra then for k, v in pairs(extra) do e[k] = v end end
    return e
end

ns.CLASS_NAMES.GENERAL = "General"

ns.Catalog = {
    {
        key = "hots",
        name = "HoTs y escudos",
        desc = "Curaciones en el tiempo y escudos sobre los aliados.",
        auraType = "HELPFUL",
        origin = "mine",
        defaults = { type = "icons", point = "TOPRIGHT", x = -2, y = -2, width = 11, height = 11,
            max = 4, grow = "LEFT", timer = false, swipe = true },
        spells = {
            S("PRIEST", 139, "HoT", { rec = true }),
            S("PRIEST", 17, "Escudo", { rec = true }),
            S("PRIEST", "Prayer of Mending", "Salta entre aliados (talento)", { rec = true }),
            S("PRIEST", "Divine Aegis", "Escudo tras crítico (talento)"),
            S("PRIEST", 14893, "Inspiración: armadura tras crítico"),
            S("DRUID", 774, "HoT", { rec = true }),
            S("DRUID", 8936, "Curación + HoT", { rec = true }),
            S("DRUID", "Wild Growth", "HoT de grupo (talento)", { rec = true }),
            S("SHAMAN", "Riptide", "HoT, mejora Sanación en cadena (talento)", { rec = true }),
            S("SHAMAN", 16177, "Fortaleza ancestral: armadura tras crítico"),
            S("SHAMAN", 29203, "Camino de sanación (acumulable)", { rec = true }),
            S("PALADIN", "Oath of Light", "Juramento de Luz (talento)", { rec = true }),
            S("PALADIN", "Light's Vigil", "Vigilia de la Luz (talento)"),
        },
    },
    {
        key = "defensives",
        name = "Defensivos",
        desc = "Reducciones de daño e inmunidades. Útil para saber cuándo un tanque o un jugador está protegido.",
        auraType = "HELPFUL",
        origin = "any",
        defaults = { type = "icons", point = "LEFT", x = 2, y = 0, width = 12, height = 12,
            max = 2, grow = "RIGHT", timer = true },
        spells = {
            S("WARRIOR", 871, "Muro de escudo", { rec = true }),
            S("WARRIOR", 12975, "Última carga", { rec = true }),
            S("WARRIOR", 2565, "Bloqueo con escudo"),
            S("PALADIN", 642, "Escudo divino", { rec = true }),
            S("PALADIN", 498, "Protección divina", { rec = true }),
            S("PALADIN", 1022, "Bendición de protección", { rec = true }),
            S("PALADIN", "Templar's Bulwark", "Baluarte templario: absorbe (talento)", { rec = true }),
            S("PALADIN", 6940, "Bendición de sacrificio"),
            S("DRUID", 22812, "Piel de corteza", { rec = true }),
            S("DRUID", 22842, "Regeneración frenética", { rec = true }),
            S("ROGUE", 5277, "Evasión", { rec = true }),
            S("HUNTER", 19263, "Disuasión", { rec = true }),
            S("MAGE", 11958, "Bloque de hielo", { rec = true }),
            S("MAGE", 11426, "Barrera de hielo"),
            S("MAGE", 1463, "Escudo de maná"),
            S("WARLOCK", 6229, "Resguardo de las Sombras"),
            S("PRIEST", 6346, "Resguardo contra el miedo"),
        },
    },
    {
        key = "raidbuffs",
        name = "Bufos de banda",
        desc = "Bufos largos de banda. Lo normal es añadirlos en modo «Le falta» y solo fuera de combate: se crea un aviso por cada bufo.",
        auraType = "HELPFUL",
        origin = "any",
        mode = "missing",
        defaults = { type = "square", point = "BOTTOMRIGHT", x = -2, y = 5, width = 6, height = 6,
            onlyOOC = true },
        spells = {
            S("PRIEST", 1243, "Fortaleza", { family = "fort", rec = true }),
            S("PRIEST", 21562, "Rezo de Fortaleza", { family = "fort", rec = true }),
            S("PRIEST", 14752, "Espíritu divino", { family = "spirit" }),
            S("PRIEST", 27681, "Rezo de Espíritu", { family = "spirit" }),
            S("PRIEST", 976, "Protección contra las Sombras", { family = "shadowprot" }),
            S("DRUID", 1126, "Marca de lo Salvaje", { family = "motw", rec = true }),
            S("DRUID", 21849, "Don de lo Salvaje", { family = "motw", rec = true }),
            S("DRUID", 467, "Espinas", { family = "thorns" }),
            S("MAGE", 1459, "Intelecto arcano", { family = "int", rec = true }),
            S("MAGE", 23028, "Luminosidad arcana", { family = "int", rec = true }),
            S("PALADIN", 20217, "Bendición de reyes", { family = "kings", rec = true }),
            S("PALADIN", 25898, "Bendición de reyes superior", { family = "kings", rec = true }),
            S("PALADIN", 19740, "Bendición de poderío", { family = "might" }),
            S("PALADIN", 25782, "Bendición de poderío superior", { family = "might" }),
            S("PALADIN", 19742, "Bendición de sabiduría", { family = "wisdom" }),
            S("PALADIN", 25894, "Bendición de sabiduría superior", { family = "wisdom" }),
            S("PALADIN", 1038, "Bendición de salvación", { family = "salv" }),
            S("PALADIN", 25895, "Bendición de salvación superior", { family = "salv" }),
            S("PALADIN", 19977, "Bendición de luz", { family = "light" }),
            S("WARRIOR", 6673, "Grito de batalla", { family = "shout" }),
        },
    },
    {
        key = "externals",
        name = "Potenciadores y utilidad",
        desc = "Bufos útiles que se ponen en otros jugadores.",
        auraType = "HELPFUL",
        origin = "any",
        defaults = { type = "icons", point = "RIGHT", x = -2, y = 0, width = 11, height = 11,
            max = 2, grow = "UP", timer = false },
        spells = {
            S("PRIEST", 10060, "Infusión de poder", { rec = true }),
            S("DRUID", 29166, "Estimular", { rec = true }),
            S("PALADIN", 1044, "Bendición de libertad", { rec = true }),
            S("WARLOCK", 20707, "Piedra de alma", { rec = true }),
        },
    },
}

ns.CatalogByKey = {}
for _, g in ipairs(ns.Catalog) do ns.CatalogByKey[g.key] = g end

-- Clave de hechizo (para las listas de los indicadores)
function ns.CatalogKey(e)
    return e.id or ("n:" .. e.name)
end

ns.ORIGIN_LABEL = { mine = "míos", others = "de otros", any = "todos" }

-- Crea indicadores a partir de una agrupación.
-- entries: entradas elegidas · origin: mine | others | any · mode: present | missing
-- Devuelve la lista de indicadores nuevos (uno, o uno por familia si "le falta").
function ns.CatalogMakeIndicators(g, entries, origin, mode)
    local out = {}
    local function Make(name, list)
        local ind = ns.DeepCopy(g.defaults)
        ind.name = name
        ind.kind = "aura"
        ind.mine = origin == "mine"
        ind.others = origin == "others"
        ind.mode = mode
        ind.spells = {}
        for _, e in ipairs(list) do table.insert(ind.spells, ns.CatalogKey(e)) end
        if mode == "missing" then
            ind.type = (ind.type == "icons") and "icon" or ind.type
            ind.onlyOOC = true
        end
        table.insert(out, ns.FixIndicator(ind))
    end
    if mode == "missing" then
        -- un aviso por familia de bufos
        local fams, order = {}, {}
        for _, e in ipairs(entries) do
            local f = e.family or ns.CatalogKey(e)
            if not fams[f] then fams[f] = {} table.insert(order, f) end
            table.insert(fams[f], e)
        end
        for i, f in ipairs(order) do
            local first = fams[f][1]
            Make(("Falta: %s"):format(first.note), fams[f])
            -- que no se pisen: uno al lado del otro
            out[i].x = (out[i].x or 0) - (i - 1) * ((out[i].width or 6) + 2)
        end
    else
        Make(("%s · %s"):format(g.name, ns.ORIGIN_LABEL[origin] or origin), entries)
    end
    return out
end

-- Entradas recomendadas de una agrupación para una clase
function ns.CatalogRecommended(g, class)
    local out = {}
    for _, e in ipairs(g.spells) do
        if e.rec and (e.class == class or e.class == "GENERAL") then table.insert(out, e) end
    end
    return out
end
