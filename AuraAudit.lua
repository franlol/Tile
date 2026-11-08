-- Capability assessment shared by construction, options and diagnostics.
local _, ns = ...
local function Plan(route, detail, notes)
    return { route = route, detail = detail, notes = notes }
end

local function CustomStyle(cfg)
    if ns.StyleActive(cfg.hl) then return true end
    for _, style in pairs(cfg.spellStyles or {}) do
        if ns.StyleActive(style) then return true end
    end
    return false
end

function ns.IndicatorAuraPlan(cfg)
    if not cfg or not cfg.enabled then return Plan("disabled", "Desactivado.") end
    if cfg.kind == "aura" and cfg.type == "bar"
        and (cfg.barMeasure == "absorb" or cfg.barMeasure == "heal") then
        return Plan("unit", "Usa datos de la unidad; no depende de leer auras.")
    end
    if cfg.onlyOOC then return Plan("ooc", "Configurado para mostrarse solo fuera de combate.") end
    local typed = cfg.kind == "aura" and (cfg.watch == "dispellable" or cfg.watch == "debuffTypes")
    local route
    if typed and (cfg.type == "border" or cfg.type == "overlay") then
        if cfg.mode == "missing" then return Plan("legacy", "El modo «Le falta» no está adaptado al dibujo nativo.") end
        if CustomStyle(cfg) then return Plan("legacy", "El resaltado personalizado no está adaptado al dibujo nativo.") end
        if (cfg.showBelow or 0) > 0 or (cfg.warnAt or 0) > 0 then
            return Plan("legacy", "Los umbrales de tiempo no están adaptados al dibujo nativo.")
        end
        route = "native-dispel"
    elseif cfg.kind == "debuffs" then
        if #(cfg.blacklist or {}) > 0 then return Plan("legacy", "La lista negra por hechizo no está adaptada al dibujo nativo.") end
        local sweep = cfg.swipeStyle or "clock"
        if cfg.swipe ~= false and sweep ~= "clock" and sweep ~= "clockReverse" and sweep ~= "clockEdge" then
            return Plan("legacy", "Este estilo de barrido no está adaptado al dibujo nativo.")
        end
        if (cfg.showBelow or 0) > 0 or (cfg.warnAt or 0) > 0 then
            return Plan("legacy", "Los umbrales de tiempo no están adaptados al dibujo nativo.")
        end
        if CustomStyle(cfg) then return Plan("legacy", "El resaltado personalizado no está adaptado al dibujo nativo.") end
        route = "native-debuffs"
    elseif cfg.kind == "raiddebuff" then
        return Plan("legacy", "Selecciona debuffs por ID y prioridad; esa selección no está adaptada para auras restringidas.")
    else
        return Plan("legacy", "Este indicador de auras aún usa lecturas que el cliente puede bloquear en combate.")
    end
    if not Enum or not Enum.CustomAuraButtonDispelTypeTextureStyle or (route == "native-debuffs" and not AnchorUtil) then
        return Plan("legacy", "La API necesaria para el dibujo nativo no está disponible en este cliente.")
    end
    local notes = {}
    if route == "native-debuffs" then
        notes[#notes + 1] = "El orden lo decide el juego."
        if cfg.excludeClaimed then notes[#notes + 1] = "No se excluyen los debuffs mostrados por otros indicadores." end
        if (cfg.timer and cfg.timerText and cfg.timerText.colorMode == "class")
            or (cfg.stacks and cfg.stacksText and cfg.stacksText.colorMode == "class") then
            notes[#notes + 1] = "El color de clase en los textos nativos aún no está adaptado."
        end
        notes[#notes + 1] = "El tooltip de aura aún no está adaptado."
    end
    return Plan(route, "Usa el mismo dibujo nativo dentro y fuera de combate.", notes)
end

function ns.IndicatorAuraSummary(cfg)
    local p = ns.IndicatorAuraPlan(cfg)
    local text = p.detail
    if p.route == "legacy" then text = text .. " Puede ocultarse o dejar de actualizarse cuando el juego restringe las auras." end
    if p.notes and #p.notes > 0 then text = text .. " " .. table.concat(p.notes, " ") end
    return text
end

-- Records configuration and our own wrapper frames only; never reads a secret
-- aura or introspects a protected native slot.
function ns.AuditIndicators()
    local version, build = GetBuildInfo()
    local report = { version = 1, client = version, build = build, combat = InCombatLockdown() and true or false,
        activeProfile = ns.activeName, profiles = {}, runtime = {} }
    for name, profile in pairs(ns.db.profiles) do
        local rows = {}
        report.profiles[name] = rows
        for i, cfg in ipairs(profile.indicators or {}) do
            local p = ns.IndicatorAuraPlan(cfg)
            rows[i] = { name = cfg.name, route = p.route, detail = ns.IndicatorAuraSummary(cfg) }
            if name == ns.activeName then ns.Print(tostring(cfg.name) .. ": " .. rows[i].detail) end
        end
    end
    for _, b in ipairs(ns.buttons or {}) do
        if b.unit and b:IsVisible() then
            local rows = {}
            for _, c in ipairs(ns.compiled) do
                local w = b.ind and b.ind[c.index]
                if w then rows[#rows + 1] = { name = c.cfg.name, native = w.nativeDispel ~= nil,
                    error = w.nativeAuraError, route = w.auraRoute,
                    wrapperShown = w.nativeDispel and w.nativeDispel:IsShown() or false } end
            end
            report.runtime[#report.runtime + 1] = { unit = b.unit, indicators = rows }
        end
    end
    ns.db.indicatorAudit = report
    ns.Print("Auditoría guardada en memoria. /reload la escribe en SavedVariables; las pruebas visuales siguen siendo necesarias.")
end
