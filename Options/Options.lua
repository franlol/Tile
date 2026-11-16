-------------------------------------------------------------------------------
-- Tile - Options window (/tile), built with LibFlatyUI-1.0
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L
local UI = ns.UI

local win

local GOOD = { 0.42, 0.84, 0.42 }
local BAD = { 1, 0.35, 0.3 }
local GREY = { 0.6, 0.6, 0.6 }

-- Binding to the profile being edited (the window refreshes itself after
-- every change made with a control)
local function PB(path, after)
    return UI.Bind(ns.EP, path, function(v)
        if after then after(v) end
        ns.ProfileChanged()
    end)
end

-- After a change that no control reports (color picker, buttons)
local function Repaint()
    ns.ProfileChanged()
    UI.RefreshAll()
end

-------------------------------------------------------------------------------
-- Building blocks
-------------------------------------------------------------------------------
-- A card title in a list of controls: the controls after it, up to the next
-- one, go in its card. titleFn() (optional) changes the title on refresh.
local function Header(title, titleFn)
    return { isHeader = true, title = title, titleFn = titleFn }
end

-- Joins single controls and (nested) lists of controls into one list
local function Flat(items, out)
    out = out or {}
    for _, v in ipairs(items) do
        if v.GetObjectType or v.isHeader then
            out[#out + 1] = v
        else
            Flat(v, out)
        end
    end
    return out
end

-- Puts a list of titles and controls into cards of a page column
local function Cards(page, col, list)
    local card
    for _, w in ipairs(Flat(list)) do
        if w.isHeader then
            card = page:Add(col, UI.Card(page.content, w.title))
            card.showIf = w.showIf
            if w.titleFn then
                local cd = card
                table.insert(UI.widgets, { Refresh = function() cd.title:SetText(w.titleFn()) end })
            end
        else
            card:Add(w)
        end
    end
end

-- Same table for the same value, so a list keeps knowing its rows between
-- refreshes (selection, open groups, the row waiting to be removed)
local function Wrapper()
    local cache = {}
    return function(v)
        local w = cache[v]
        if not w then w = { value = v } cache[v] = w end
        return w
    end
end

local function Both(a, b)
    if not a then return b end
    if not b then return a end
    return function() return a() and b() end
end

-- Adds conditions to a control (keeping the ones it already has)
local function Cond(w, showIf, enableIf)
    w.showIf = Both(w.showIf, showIf)
    w.enableIf = Both(w.enableIf, enableIf)
    return w
end
local function All(list, showIf, enableIf)
    for _, w in ipairs(list) do Cond(w, showIf, enableIf) end
    return list
end

-- Controls with Tile's argument order
local function Slider(c, label, minV, maxV, step, fmt, get, set)
    return UI.Slider(c, label, minV, maxV, step, get, set, { format = fmt })
end
local function Swatch(c, label, getColor, onChange, alpha)
    return UI.Swatch(c, label, getColor, onChange or Repaint, { alpha = alpha })
end

local function TextColors()
    return { { "white", L["White"] }, { "class", L["Class color"] }, { "custom", L["Custom"] } }
end
-- Look of one part of an offline player's frame: as usual or a chosen color
-- (withClass: also the class color)
local function OfflineColor(c, key, label, withClass)
    local mode = "offline." .. key
    local choices = { { "usual", L["As usual"] } }
    if withClass then choices[#choices + 1] = { "class", L["Class color"] } end
    choices[#choices + 1] = { "custom", L["Custom"] }
    return {
        UI.Segmented(c, label, choices, PB(mode)),
        Cond(UI.Attach(Swatch(c, L["Color"], function() return UI.Bind(ns.EP, mode .. "Color")() end, nil, true)),
            nil, function() return UI.Bind(ns.EP, mode)() == "custom" end),
    }
end

local function BarColors()
    return { { "class", L["Class color"] }, { "custom", L["Single color"] }, { "gradient", L["By health"] } }
end
local function PowerColors()
    return { { "power", L["Resource color"] }, { "class", L["Class color"] }, { "custom", L["Single color"] } }
end

-------------------------------------------------------------------------------
-- Shared blocks: each kind of thing always has the same options,
-- with the same names and in the same order
--   Text:  Show · Font · Size · Outline · Color · Position (X, Y)
--   Icon:  Show · Size · Position (X, Y)
--   Bar:   Texture · Color (custom, brightness) · Opacity
-------------------------------------------------------------------------------
-- Position: anchor point and X/Y attached (same ranges everywhere)
local function PositionBlock(c, root, after, o)
    o = o or {}
    return {
        Cond(UI.Dropdown(c, L["Position"], UI.PointList, UI.Bind(root, "point", after)), o.showIf, o.enableIf),
        Cond(UI.Attach(Slider(c, "X", -80, 80, 1, UI.px, UI.Bind(root, "x", after))), o.showIf, o.enableIf),
        Cond(UI.Attach(Slider(c, "Y", -60, 60, 1, UI.px, UI.Bind(root, "y", after))), o.showIf, o.enableIf),
    }
end

-- Font and outline lists of a text: "General" first (false = the profile's
-- general one, set at the top of the Texts page)
local function GeneralFontList()
    local list = ns.FontList()
    table.insert(list, 1, { false, L["General font"], ns.EP().general.font })
    return list
end
local function GeneralOutlineList()
    local list = ns.OutlineList()
    table.insert(list, 1, { false, L["General"] })
    return list
end

-- Text. root() returns its style table.
-- o.show = { get, set } adds "Show"; o.extra, controls right after;
-- o.showIf / o.enableIf for the whole block (enableIf does not affect "Show");
-- o.showCheckIf, o.colorIf, o.positionIf for specific parts;
-- o.noColor: the text has no color of its own (no color controls at all).
local function TextBlock(c, root, after, o)
    o = o or {}
    local list = {}
    local function Add(w, showIf, enableIf)
        list[#list + 1] = Cond(w, Both(o.showIf, showIf), Both(o.enableIf, enableIf))
    end
    if o.show then
        list[#list + 1] = Cond(UI.Check(c, L["Show"], o.show[1], o.show[2]), Both(o.showIf, o.showCheckIf))
    end
    for _, w in ipairs(o.extra or {}) do Add(w) end
    local function B(k) return UI.Bind(root, k, after) end
    Add(UI.Dropdown(c, L["Font"], GeneralFontList, B("font")))
    Add(Slider(c, L["Size"], 6, 24, 1, UI.px, B("size")))
    Add(UI.Dropdown(c, L["Outline"], GeneralOutlineList, B("outline")))
    if not o.noColor then
        Add(UI.Segmented(c, L["Color"], TextColors(), B("colorMode")), o.colorIf)
        Add(UI.Attach(Swatch(c, L["Custom color"], function() return root().color end,
            function() if after then after() end UI.RefreshAll() end, true)),
            o.colorIf, function() return root().colorMode == "custom" end)
    end
    for _, w in ipairs(PositionBlock(c, root, after)) do Add(w, o.positionIf) end
    return list
end

-- Color of a bar: mode, custom color and brightness (the last two, attached)
local function BarColorBlock(c, modes, modeKey, customKey, brightKey)
    local function Mode() return UI.Bind(ns.EP, modeKey)() end
    return {
        UI.Segmented(c, L["Color"], modes(), PB(modeKey)),
        Cond(UI.Attach(Swatch(c, L["Custom color"], function() return UI.Bind(ns.EP, customKey)() end, nil, true)),
            nil, function() return Mode() == "custom" end),
        Cond(UI.Attach(Slider(c, L["Brightness"], 0.1, 1, 0.05, UI.pct, PB(brightKey))), nil,
            function() return Mode() ~= "custom" end),
    }
end

-- when the background search finds the ID of a name
ns.OnSpellResolved = function()
    if ns.testing and ns.LayoutTest then ns.LayoutTest() end
    if win and win:IsShown() then UI.RefreshAll() end
end

-------------------------------------------------------------------------------
-- Profiles
-- The profiles are a list: the selected row is the one you edit. Reset and
-- delete act on it, like every list with actions below it.
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

-- What test mode simulates (account settings, not saved in profiles):
-- a change redraws the test frames
local function PreviewBind(key)
    return UI.Bind(function() return ns.db.preview end, key, function()
        if ns.testing and ns.LayoutTest then ns.LayoutTest() end
    end)
end
local function PV(c, key, label) return UI.Check(c, label, PreviewBind(key)) end

local function BuildProfiles(container)
    local page = UI.Page(container, 2)
    local c = page.content

    -- Edits a profile (in test mode it is the one shown). Which profile each
    -- group size uses is only changed in "Profile per group size".
    local function Use(n)
        ns.SetEditName(n)
        ns.ActivateProfile()
    end
    local function Reassign(old, new)
        for _, chars in pairs(ns.db.chars) do
            for k, v in pairs(chars) do if v == old then chars[k] = new end end
        end
    end
    -- Group sizes of this character that use a profile
    local function UsedBy(name)
        local out = {}
        for _, key in ipairs(ns.SIZE_KEYS) do
            if ns.CharProfiles()[key] == name then out[#out + 1] = L[ns.SIZE_NAMES[key]] end
        end
        return out
    end

    local HELP = L["\"Create new\" starts with the default settings; \"Duplicate\" copies the selected profile. Default cannot be deleted or renamed."]
    local feedback = UI.Note(c, HELP)
    local function Say(text)
        feedback:SetText("|cff66e680" .. text .. "|r")
        UI.RefreshAll()
    end

    ---------------------------------------------------------------------------
    -- Profile being edited
    ---------------------------------------------------------------------------
    -- click = use it now (and edit it); x deletes it (not Default); where it was used, Default
    -- takes its place
    local Row = Wrapper()
    local profiles = UI.List(c, {
        items = function()
            local out = {}
            for i, o in ipairs(ProfileOptions()) do out[i] = Row(o[1]) end
            return out
        end,
        label = function(w) return w.value end,
        tag = function(w)
            if w.value == ns.activeName then return L["active"], ns.ACCENT end
        end,
        selected = function(w) return w.value == ns.EditedProfileName() end,
        onSelect = function(_, w) Use(w.value) end,
        canRemove = function(w) return w.value ~= "Default" end,
        onRemove = function(_, w)
            local old = w.value
            if old == "Default" then return end
            local used = #UsedBy(old) > 0
            local editing = old == ns.EditedProfileName()
            ns.db.profiles[old] = nil
            Reassign(old, "Default")
            if editing then ns.SetEditName(nil) end
            ns.ActivateProfile(true)
            Say(used and (L["\"%s\" deleted. Where it was used, Default is used now."]):format(old)
                or (L["\"%s\" deleted."]):format(old))
        end,
        rows = 6,
    })

    local actions = UI.Buttons(c, {
        { L["Reset"], function()
            local name = ns.EditedProfileName()
            ns.db.profiles[name] = ns.NewProfile()
            ns.ActivateProfile(true)
            ns.ProfileChanged()
            Say((L["\"%s\" is back to the default settings."]):format(name))
        end, "danger", L["Puts the selected profile back to the default settings."] },
    })
    UI.Confirm(actions.buttons[1], L["Sure?"])

    ---------------------------------------------------------------------------
    -- Create / duplicate / rename
    ---------------------------------------------------------------------------
    local nameRow = UI.Row(c, 34)
    local lbl = UI.Text(nameRow, L["Name"])
    lbl:SetPoint("TOPLEFT")
    local hint = UI.Text(nameRow, "", nil, { 1, 0.55, 0.3 })
    hint:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    hint:SetPoint("RIGHT", nameRow, "RIGHT")
    hint:SetJustifyH("RIGHT")
    hint:SetWordWrap(false)
    local nameBox = UI.EditBox(nameRow, 150)
    nameBox:SetPoint("TOPLEFT", 0, -14)
    nameBox:SetPoint("TOPRIGHT", 0, -14)
    local function Name() return nameBox:GetText():trim() end
    local function Done(n, msg)
        nameBox:SetText("")
        nameBox:ClearFocus()
        Use(n)
        Say(msg)
    end

    local create = UI.Buttons(c, {
        { L["Create new"], function()
            local n = Name()
            ns.db.profiles[n] = ns.NewProfile()
            Done(n, (L["\"%s\" created with the default settings."]):format(n))
        end },
        { L["Duplicate"], function()
            local n, from = Name(), ns.EditedProfileName()
            ns.db.profiles[n] = ns.DeepCopy(ns.EP())
            Done(n, (L["\"%s\" created as a copy of \"%s\"."]):format(n, from))
        end },
        { L["Rename"], function()
            local n, old = Name(), ns.EditedProfileName()
            ns.db.profiles[n] = ns.db.profiles[old]
            ns.db.profiles[old] = nil
            Reassign(old, n)
            if ns.activeName == old then ns.activeName = n end
            Done(n, (L["\"%s\" is now called \"%s\"."]):format(old, n))
        end },
    })
    -- the buttons are only enabled with a valid name
    local function Validate()
        local n = Name()
        local exists = n ~= "" and ns.db.profiles[n] ~= nil
        local ok = n ~= "" and not exists
        hint:SetText(exists and L["a profile with that name already exists"] or "")
        UI.SetEnabled(create.buttons[1], ok)
        UI.SetEnabled(create.buttons[2], ok)
        UI.SetEnabled(create.buttons[3], ok and ns.EditedProfileName() ~= "Default")
    end
    nameBox:SetScript("OnTextChanged", Validate)
    nameBox:SetScript("OnEnterPressed", nameBox.ClearFocus)
    create.Refresh = Validate
    table.insert(UI.widgets, create)

    ---------------------------------------------------------------------------
    local sizes = { Header(L["Profile per group size"]) }
    for _, key in ipairs(ns.SIZE_KEYS) do
        local dd = UI.Dropdown(c, L[ns.SIZE_NAMES[key]], ProfileOptions,
            function() return ns.CharProfiles()[key] end,
            function(v)
                ns.CharProfiles()[key] = v
                ns.ActivateProfile()
            end)
        local base = dd.Refresh
        dd.Refresh = function(self)
            base(self)
            local now = ns.RealSizeKey() == key
            dd.label:SetText(L[ns.SIZE_NAMES[key]] .. (now and ("  " .. ns.AccentText("· " .. L["your group now"])) or ""))
        end
        sizes[#sizes + 1] = dd
    end
    sizes[#sizes + 1] = UI.Note(c, L["This way you can have one layout for parties, another for ZG/AQ20 and another for 40-player raids. It switches automatically when you join or leave a group (in combat, it applies when combat ends)."])

    Cards(page, 1, {
        Header(L["Profile in use"]),
        profiles,
        actions,
        Header(L["Create or rename"]),
        nameRow,
        create,
        feedback,
    })
    -- share: the profile being edited as text, or a text pasted to import it
    local box = UI.CodeBox(c, 120)
    local status = UI.Note(c, "")
    local share = UI.Buttons(c, {
        { L["Export"], function()
            box.edit:SetText(ns.ExportProfile())
            box.edit:SetFocus()
            box.edit:HighlightText()
            status:SetText(L["Copied to the box: press Ctrl+C."])
            page:Layout()
        end, "accent" },
        { L["Import"], function()
            UI.Dialog(L["This replaces every setting of the profile being edited. Continue?"], L["Import"], function()
                local ok, err = ns.ImportProfile(box.edit:GetText())
                status:SetText(ok and ("|cff6bd66b" .. L["Profile imported."] .. "|r") or ("|cffff6b61" .. err .. "|r"))
                UI.RefreshAll()
                page:Layout()
            end)
        end },
    })

    Cards(page, 2, {
        sizes,
        Header(L["Share"]),
        box,
        share,
        status,
    })
end

-------------------------------------------------------------------------------
-- General: what test mode simulates and the account settings
-------------------------------------------------------------------------------
local function BuildGeneral(container)
    local page = UI.Page(container, 2)
    local c = page.content

    Cards(page, 1, {
        Header(L["Preview"]),
        UI.Dropdown(c, L["Simulate a group of"], {
            { "party", L["5 (party)"] }, { "raid10", L["10 (raid)"] }, { "raid20", L["20 (raid)"] }, { "raid40", L["40 (raid)"] },
        }, function() return ns.testSize or "raid20" end, function(v)
            -- the size changes, the profile being edited stays
            ns.SetEditName(ns.EditedProfileName())
            ns.ToggleTest(true, v)
        end),
        UI.Note(c, L["In test mode you always see the profile you are editing, with the number of players chosen here."]),
        PV(c, "range", L["Out of range"]),
        PV(c, "offline", L["Offline"]),
        PV(c, "dead", L["Dead / ghost"]),
        PV(c, "states", L["AFK, charmed, summon"]),
        PV(c, "threat", L["Threat"]),
        PV(c, "target", L["Target"]),
        PV(c, "icons", L["Status icons"]),
        PV(c, "ready", L["Ready check"]),
        PV(c, "heals", L["Incoming heals and shields"]),
        PV(c, "pets", L["Pets"]),
        PV(c, "indicators", L["Indicators"]),
        UI.Segmented(c, L["Missing health"], {
            { "mixed", L["Mixed"] }, { "full", L["Full"] }, { "low", L["Low"] },
        }, PreviewBind("health")),
    })
    Cards(page, 2, {
        Header(L["General"]),
        -- hiding applies at once; showing them again needs a reload
        UI.Check(c, L["Hide Blizzard party and raid frames"],
            function() return ns.db.hideBlizzard end,
            function(v) ns.db.hideBlizzard = v if v then ns.HideBlizzard() end end),
        UI.Check(c, L["Show the minimap button"],
            function() return not ns.db.minimap.hide end,
            function(v) ns.db.minimap.hide = not v ns.UpdateMinimapButton() end),
        UI.Segmented(c, L["Language"], ns.LANGUAGES,
            function() return ns.db.language end,
            function(v) ns.db.language = v end),
        -- only while something waits for a reload
        Cond(UI.Note(c, L["|cffff8c4dReload the interface to apply the changes.|r"]), ns.NeedsReload),
        Cond(UI.Buttons(c, { { L["Reload now"], ReloadUI } }), ns.NeedsReload),
    })
end

-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------
local function BuildLayout(container)
    local page = UI.Page(container, 2)
    local c = page.content
    local function petsOn() return ns.EP().pets.enabled end
    local function petSize() return petsOn() and not ns.EP().pets.sameSize end
    -- vertical: pets go in columns; horizontal: in rows
    local perCol = Slider(c, L["Pets per column"], 1, 10, 1, nil, PB("pets.perColumn"))
    local baseRefresh = perCol.Refresh
    perCol.Refresh = function(self)
        baseRefresh(self)
        perCol.label:SetText(ns.EP().layout.orientation == "horizontal" and L["Pets per row"] or L["Pets per column"])
    end

    local groups = {}
    for i = 1, 8 do groups[i] = { i, (L["Group %d"]):format(i) } end

    Cards(page, 1, {
        Header(L["Size"]),
        Slider(c, L["Width"], 30, 200, 1, UI.px, PB("layout.width")),
        Slider(c, L["Height"], 16, 100, 1, UI.px, PB("layout.height")),
        Slider(c, L["Scale"], 0.5, 2, 0.05, UI.pct, PB("layout.scale")),
        Slider(c, L["Spacing between players"], 0, 12, 1, UI.px, PB("layout.spacing")),
        Slider(c, L["Spacing between groups"], 0, 40, 1, UI.px, PB("layout.groupSpacing")),
        Header(L["Pets"]),
        UI.Check(c, L["Show"], PB("pets.enabled")),
        Cond(UI.Check(c, L["Attached to the raid, as one more group"], PB("pets.attach")), nil, petsOn),
        Cond(UI.Check(c, L["Same size as players"], PB("pets.sameSize")), nil, petsOn),
        Cond(UI.Attach(Slider(c, L["Width"], 30, 200, 1, UI.px, PB("pets.width"))), nil, petSize),
        Cond(UI.Attach(Slider(c, L["Height"], 12, 100, 1, UI.px, PB("pets.height"))), nil, petSize),
        Cond(perCol, nil, petsOn),
    })
    Cards(page, 2, {
        Header(L["Arrangement"]),
        UI.Segmented(c, L["Orientation"], {
            { "vertical", L["Vertical"] }, { "horizontal", L["Horizontal"] },
        }, PB("layout.orientation")),
        UI.Attach(UI.Note(c, L["Vertical: one column per group. Horizontal: one row per group."])),
        UI.Segmented(c, L["Group by"], {
            { "GROUP", L["Raid group"] }, { "ROLE", L["Role"] }, { "CLASS", L["Class"] },
        }, PB("layout.groupBy")),
        UI.Check(c, L["Sort by name within the group"], PB("layout.sortByName")),
        UI.Check(c, L["Show in party (not only in raid)"], PB("layout.showParty")),
        UI.Check(c, L["Show myself"], PB("layout.showPlayer")),
        UI.Check(c, L["Show when solo"], PB("layout.showSolo")),
        Header(L["Groups shown"]),
        UI.CheckGroup(c, nil, groups,
            function(i) return ns.EP().layout.groups[i] end,
            function(i, v) ns.EP().layout.groups[i] = v ns.ProfileChanged() end,
            { columns = 2 }),
    })
end

-------------------------------------------------------------------------------
-- Bars
-------------------------------------------------------------------------------
local function BuildBars(container)
    local page = UI.Page(container, 2)
    local c = page.content
    local function Col(path) return function() return UI.Bind(ns.EP, path)() end end
    local function On(path) return function() return UI.Bind(ns.EP, path)() and true or false end end
    local function Smooth(path)
        return Cond(UI.Check(c, ns.hasNativeSmooth and L["Smooth fill and drain"]
            or L["Smooth fill and drain (not available in this client)"], PB(path)), nil,
            function() return ns.hasNativeSmooth end)
    end
    local power = On("bars.showPower")

    Cards(page, 1, {
        Header(L["Health"]),
        UI.Dropdown(c, L["Texture"], ns.TextureList, PB("bars.healthTex")),
        Smooth("bars.smooth"),
        BarColorBlock(c, BarColors, "bars.healthColor", "bars.customColor", "bars.healthBrightness"),

        Header(L["Background (missing health)"]),
        UI.Dropdown(c, L["Texture"], ns.TextureList, PB("bars.bgTex")),
        BarColorBlock(c, BarColors, "bars.bgColor", "bars.bgCustom", "bars.bgBrightness"),
        Slider(c, L["Opacity"], 0, 1, 0.05, UI.pct, PB("bars.bgAlpha")),

        Header(L["Heals and shields"]),
        UI.Check(c, L["Incoming heals"], PB("bars.showHealPred")),
        Cond(UI.Attach(UI.Dropdown(c, L["Texture"], ns.TextureList, PB("bars.healPredTex"))), nil, On("bars.showHealPred")),
        Cond(UI.Attach(Swatch(c, L["Color"], Col("bars.healPredColor"), nil, true)), nil, On("bars.showHealPred")),
        UI.Check(c, L["Shields (absorb)"], PB("bars.showAbsorb")),
        Cond(UI.Attach(UI.Dropdown(c, L["Texture"], ns.TextureList, PB("bars.absorbTex"))), nil, On("bars.showAbsorb")),
        Cond(UI.Attach(Swatch(c, L["Color"], Col("bars.absorbColor"), nil, true)), nil, On("bars.showAbsorb")),
    })

    Cards(page, 2, {
        Header(L["Mana / energy / rage"]),
        UI.Check(c, L["Show"], PB("bars.showPower")),
        Cond(UI.Attach(UI.Check(c, L["Only for mana users"], PB("bars.powerOnlyMana"))), nil, power),
        Cond(UI.Dropdown(c, L["Texture"], ns.TextureList, PB("bars.powerTex")), nil, power),
        Cond(Smooth("bars.powerSmooth"), nil, power),
        All(BarColorBlock(c, PowerColors, "bars.powerColor", "bars.powerCustom", "bars.powerBrightness"), nil, power),
        Cond(Slider(c, L["Background opacity"], 0, 1, 0.05, UI.pct, PB("bars.powerBgAlpha")), nil, power),
        Cond(Slider(c, L["Height"], 1, 12, 1, UI.px, PB("bars.powerHeight")), nil, power),

        Header(L["Frame"]),
        Swatch(c, L["Border color"], Col("bars.borderColor"), nil, true),
        Slider(c, L["Out of range opacity"], 0.1, 1, 0.05, UI.pct, PB("bars.rangeAlpha")),

        Header(L["Highlights"]),
        UI.Check(c, L["Highlight my target"], PB("bars.targetHighlight")),
        Cond(UI.Attach(Swatch(c, L["Color"], Col("bars.targetColor"), nil, true)), nil, On("bars.targetHighlight")),
        UI.Check(c, L["Highlight on mouse over"], PB("bars.hoverHighlight")),
        Cond(UI.Attach(Swatch(c, L["Color"], Col("bars.hoverColor"), nil, true)), nil, On("bars.hoverHighlight")),
        UI.Check(c, L["Mark who has threat (aggro)"], PB("bars.aggro")),
        Cond(UI.Attach(Swatch(c, L["Color"], Col("bars.aggroColor"), nil, true)), nil, On("bars.aggro")),

        Header(L["Offline players"]),
        OfflineColor(c, "health", L["Health"]),
        OfflineColor(c, "power", L["Mana / energy / rage"]),
        OfflineColor(c, "name", L["Name"], true),
        Slider(c, L["Frame opacity"], 0.1, 1, 0.05, UI.pct, PB("offline.alpha")),
    })
end

-------------------------------------------------------------------------------
-- Texts
-------------------------------------------------------------------------------
local function TextSection(c, key, title, extra)
    local function root() return ns.EP().texts[key] end
    return {
        Header(title),
        TextBlock(c, root, ns.ProfileChanged, {
            show = { PB("texts." .. key .. ".show") },
            extra = extra,
            enableIf = function() return root().show end,
        }),
    }
end

local selState = "offline"   -- status text state being edited

local function BuildTexts(container)
    local page = UI.Page(container, 2)
    local c = page.content

    -- Status text: one look for every state, then the states in a list.
    -- Check box = on/off, drag = priority, click = its color below.
    local S = function() return ns.EP().texts.status end
    local STATES = ns.STATUS_STATES
    local function statusOn() return S().show end
    local function Sel() return STATES[selState] end

    local states = UI.List(c, {
        items = function() return S().order end,
        label = function(k) return L[STATES[k].text] end,
        off = function(k) return not S()[STATES[k].show] end,
        checked = function(k) return S()[STATES[k].show] and true or false end,
        onCheck = function(k, v) S()[STATES[k].show] = v Repaint() end,
        lead = "swatch",
        color = function(k)
            local col = S()[STATES[k].color]
            return { col.r, col.g, col.b }
        end,
        selected = function(k) return k == selState end,
        onSelect = function(_, k) selState = k end,
        onReorder = function(from, to)
            local order = S().order
            table.insert(order, to, table.remove(order, from))
            Repaint()
        end,
        rows = #S().order,
    })

    -- color of the selected state, named after it
    local stateColor = Swatch(c, L["Color"], function() return S()[Sel().color] end, nil, true)
    local baseRefresh = stateColor.Refresh
    stateColor.Refresh = function(self)
        baseRefresh(self)
        stateColor.label:SetText(("%s · %s"):format(L["Color"], L[Sel().text]))
    end

    -- what the selected state means, when its name is not enough
    local HINTS = {
        charm = "Mind controlled: they can attack you.",
        summon = "Pending, accepted or declined.",
    }
    local hint = UI.Note(c, "")
    hint.Refresh = function() hint:SetText(L[HINTS[selState] or ""]) end
    table.insert(UI.widgets, hint)

    local status = {
        Header(L["Status text"]),
        TextBlock(c, S, ns.ProfileChanged, {
            show = { PB("texts.status.show") },
            enableIf = statusOn,
            noColor = true,   -- each state has its own color
        }),
        Cond(UI.Note(c, L["States: drag to change the priority. When several apply, the top one shows."]), nil, statusOn),
        Cond(states, nil, statusOn),
        Cond(UI.Attach(stateColor), nil, statusOn),
        Cond(UI.Attach(hint), function() return HINTS[selState] ~= nil end, statusOn),
        UI.Note(c, L["Drinking and eating is an indicator (Indicators tab)."]),
    }

    Cards(page, 1, {
        -- what every text uses unless it picks its own (indicator texts too)
        Header(L["All texts"]),
        UI.Dropdown(c, L["Font"], ns.FontList, PB("general.font")),
        UI.Dropdown(c, L["Outline"], ns.OutlineList, PB("general.outline")),
        TextSection(c, "name", L["Name"], {
            UI.Check(c, L["With surname"], PB("texts.name.surname", function() ns.UpdateAllButtons() end)),
            Slider(c, L["Max width (% of the frame)"], 30, 100, 1, UI.percent, PB("texts.name.width")),
        }),
        TextSection(c, "health", L["Health text"], {
            UI.Dropdown(c, L["Format"], {
                { "deficit", L["Missing health (-1.2k)"] },
                { "percent", L["Percentage (85%)"] },
                { "current", L["Current health (3.4k)"] },
                { "both", L["Current / max"] },
            }, PB("texts.health.format")),
            UI.Check(c, L["Hide at full health"], PB("texts.health.hideFull")),
        }),
    })

    Cards(page, 2, status)
end

-------------------------------------------------------------------------------
-- Status icons
-------------------------------------------------------------------------------
local function ElementSection(c, key, title)
    local function root() return ns.EP().elements[key] end
    local function on() return root().show end
    local list = {
        Header(title),
        UI.Check(c, L["Show"], PB("elements." .. key .. ".show")),
    }
    -- the ready check icon only exists during the check: it has no "when"
    if key ~= "ready" then
        list[#list + 1] = Cond(UI.Attach(UI.Segmented(c, L["When"], {
            { "always", L["Always"] },
            { "ready", L["Ready checks"] },
            { "ooc", L["Out of combat"] },
        }, PB("elements." .. key .. ".when"))), nil, on)
    end
    local P = "elements." .. key .. "."
    local function bgOn() return on() and root().bg end
    local function borderOn() return on() and root().border end
    local function boxOn() return on() and (root().bg or root().border) end
    return {
        list,
        Cond(UI.Attach(UI.Segmented(c, L["Priority"], {
            { false, L["Below the indicators"] },
            { true, L["Above the indicators"] },
        }, PB(P .. "onTop"))), nil, on),
        Cond(Slider(c, L["Size"], 6, 40, 1, UI.px, PB(P .. "size")), nil, on),
        PositionBlock(c, root, ns.ProfileChanged, { enableIf = on }),
        Cond(UI.Check(c, L["Background"], PB(P .. "bg")), nil, on),
        Cond(UI.Attach(Swatch(c, L["Color"], function() return root().bgColor end, nil, true)), nil, bgOn),
        Cond(UI.Check(c, L["Border"], PB(P .. "border")), nil, on),
        Cond(UI.Attach(Swatch(c, L["Border color"], function() return root().borderColor end, nil, true)), nil, borderOn),
        Cond(UI.Attach(Slider(c, L["Thickness"], 1, 6, 1, UI.px, PB(P .. "borderSize"))), nil, borderOn),
        Cond(Slider(c, L["Padding"], 0, 8, 1, UI.px, PB(P .. "pad")), nil, boxOn),
    }
end

local function BuildElements(container)
    local page = UI.Page(container, 2)
    local c = page.content
    Cards(page, 1, {
        ElementSection(c, "role", L["Role icon"]),
        ElementSection(c, "raidIcon", L["Raid marker (skull, etc.)"]),
    })
    Cards(page, 2, {
        ElementSection(c, "leader", L["Leader / assistant"]),
        ElementSection(c, "ready", L["Ready check"]),
    })
end

-------------------------------------------------------------------------------
-- Indicators
-------------------------------------------------------------------------------
local selInd = 1
local KIND_LABEL = { aura = "", raiddebuff = "boss", debuffs = "debuffs", heal = "", threat = "" }
local TYPE_LABEL = { icon = "icon", icons = "icons", square = "square", bar = "bar", text = "text",
    border = "border", overlay = "tint" }

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
    if ns.IndicatorUnitSquare(ind) then return "square" end
    return ind.type
end

local IndChanged = ns.ProfileChanged

local function IB(path) return UI.Bind(Sel, path, IndChanged) end

local function BuildIndicators(container)
    local leftPage, rightPage = UI.Split(container, 250)

    ---------------------------------------------------------------------------
    -- Left: the indicators. Check box = on/off, click = edit, drag = order.
    ---------------------------------------------------------------------------
    local lc = leftPage.content
    local list = UI.List(lc, {
        items = Inds,
        label = function(d) return d.name end,
        off = function(d) return not d.enabled end,
        checked = function(d) return d.enabled and true or false end,
        onCheck = function(d, v) d.enabled = v IndChanged() end,
        lead = "swatch",
        color = function(d)
            if d.kind ~= "aura" and not ns.IndicatorUnitSquare(d) then return GREY end
            local col = d.color or { r = 1, g = 1, b = 1 }
            return { col.r, col.g, col.b }
        end,
        tag = function(d)
            local tag = KIND_LABEL[d.kind] ~= "" and KIND_LABEL[d.kind] or TYPE_LABEL[d.type] or ""
            return tag ~= "" and L[tag] or ""
        end,
        tagWidth = 60,
        selected = function(_, i) return i == selInd end,
        onSelect = function(i)
            selInd = i
            UI.CloseMenu()
        end,
        onReorder = function(from, to)
            local l = Inds()
            table.insert(l, to, table.remove(l, from))
            -- the edited indicator stays selected wherever it ends up
            if selInd == from then selInd = to
            elseif from < selInd and to >= selInd then selInd = selInd - 1
            elseif from > selInd and to <= selInd then selInd = selInd + 1 end
            IndChanged()
        end,
        -- built-in ones have no x: they are turned off with their box
        canRemove = function(d) return d.kind == "aura" end,
        onRemove = function(i)
            table.remove(Inds(), i)
            if i < selInd or selInd > #Inds() then selInd = math.max(1, selInd - 1) end
            IndChanged()
        end,
        rows = 18,
    })
    Cards(leftPage, 1, {
        Header(L["Indicators"]),
        list,
        UI.Buttons(lc, {
            { L["New"], function()
                local l = Inds()
                table.insert(l, ns.FixIndicator({ name = L["New indicator"] }))
                selInd = #l
                Repaint()
            end },
            { L["Presets"] .. "...", function() if ns.OpenCatalog then ns.OpenCatalog() end end },
        }),
        UI.Note(lc, L["Drag a row to change the order. Lower rows are drawn on top."]),
    })

    ---------------------------------------------------------------------------
    -- Right: the editor of the selected indicator
    ---------------------------------------------------------------------------
    local c = rightPage.content
    local function K() local s = Sel() return s and s.kind end
    local function T() local s = Sel() return s and EffType(s) end
    local function isAura() return K() == "aura" end
    -- frame border / tint over health: they cover the whole frame (no position or size)
    local function frameT() local t = T() return t == "border" or t == "overlay" end
    local function notDispel() return not frameT() end
    local function iconLike() local t = T() return t == "icon" or t == "icons" end
    local function rect() local t = T() return t == "square" or t == "bar" end
    local function iconsT() return T() == "icons" end
    -- incoming heal / threat count squares (unit data, not auras)
    local function unitSq() local s = Sel() return s and ns.IndicatorUnitSquare(s) end
    local function colored()
        local t = T()
        return unitSq() or (isAura() and (t == "square" or t == "bar" or t == "text"))
    end
    local function isMissing() local s = Sel() return isAura() and s.mode == "missing" end
    -- bar that measures shields or incoming heals: does not watch auras nor has time
    local function unitBar() return isAura() and ns.IndicatorUnitMeasure(Sel()) end
    local function watchAuras() return isAura() and not unitBar() end
    -- watches the spells in its list (not "the ones I can dispel")
    local function dispWatch() return watchAuras() and (Sel().watch == "dispellable" or Sel().watch == "debuffTypes") end
    local function listWatch() return watchAuras() and not dispWatch() end
    -- has a duration (it is not "missing" nor dispellable)
    local function timed()
        if unitSq() then return false end
        if T() == "bar" and (Sel().barMeasure or "time") ~= "time" then return false end
        if frameT() then return false end
        return notDispel() and not isMissing()
    end
    local function hasText() return timed() end
    -- border or tint that shows debuffs (the ones with a type)
    local function typeIconT() return frameT() and ns.IndicatorTyped(Sel()) end
    local function typeIconOn() return Sel().typeIcon end
    local function isBar() return T() == "bar" end

    -- W: shown for some indicator types only. WE: the same, and also greyed out
    -- (without moving) while a sub-option is off
    local function W(widget, cond) widget.showIf = cond return widget end
    local function WE(widget, show, enable) widget.showIf = show widget.enableIf = enable return widget end
    local function HeaderIf(title, cond) return W(Header(title), cond) end

    local nameIn = UI.Input(c, L["Name"], function() local s = Sel() return s and s.name end, function(t)
        local s = Sel()
        t = (t or ""):trim()
        if s and t ~= "" then s.name = t end
    end, { saveOnBlur = true })
    local customIn = UI.Input(c, L["Text"], function() local s = Sel() return s and s.customText end, function(t)
        local s = Sel()
        if s and t ~= s.customText then s.customText = t IndChanged() end
    end, { saveOnBlur = true })

    ---------------------------------------------------------------------------
    -- Spells the indicator watches: one list. Each spell is a row (box, icon,
    -- how many of its IDs count, x to remove) that opens to show its IDs
    -- (ranks), each with a box. Same as every grouped list with boxes: the
    -- spell box is all / some (dash) / none of its IDs.
    --   all ticked (the default): every ID counts, also ranks added later
    --   none: the spell is off (kept in the list, it does not count)
    ---------------------------------------------------------------------------
    local SpellHead, IDRow = Wrapper(), Wrapper()
    local GetSubtext = (C_Spell and C_Spell.GetSpellSubtext) or GetSpellSubtext

    local function SpellRows()
        local s = Sel()
        local out = {}
        for _, key in ipairs(s and s.spells or {}) do
            local h = SpellHead(key)
            h.header = true
            if h.closed == nil then h.closed = true end
            local all = ns.KeyIDs(key)
            h.leaf = #all <= 1   -- one ID (or still looking): nothing to choose
            out[#out + 1] = h
            if not h.closed and not h.leaf then
                for _, id in ipairs(all) do
                    local w = IDRow(id)
                    w.key = key
                    out[#out + 1] = w
                end
            end
        end
        return out
    end
    -- IDs of a spell that count ({ [id] = true }), how many, and of how many
    local function Counting(s, key)
        local all = ns.KeyIDs(key)
        local set, n = {}, 0
        if not ns.SpellOff(s, key) then
            local pick = ns.KeyRank(s, key)
            for _, id in ipairs(all) do
                if not pick or pick[id] then set[id] = true n = n + 1 end
            end
        end
        return set, n, #all
    end
    -- what the spell box shows: true (all), "partial" (some), false (off)
    local function SpellState(s, key)
        if ns.SpellOff(s, key) then return false end
        return ns.KeyRank(s, key) and "partial" or true
    end

    local spellList = UI.List(c, {
        items = SpellRows,
        richHeaders = true,
        label = function(w)
            if w.header then return (ns.SpellKeyInfo(w.value)) end
            local sub = GetSubtext and GetSubtext(w.value)
            return (sub and sub ~= "") and sub or ("ID " .. w.value)
        end,
        lead = "icon",
        icon = function(w)
            if w.header then return select(2, ns.SpellKeyInfo(w.value)) end
            return ns.GetSpellIcon(w.value)
        end,
        spell = function(w)
            if w.header then return ns.KeyIDs(w.value)[1] end
            return w.value
        end,
        secondary = function(w)
            if not w.header then return tostring(w.value) end
            local s = Sel()
            if ns.SpellOff(s, w.value) then return L["off"] end
            local _, n, total = Counting(s, w.value)
            if total == 0 then return L["looking up IDs..."] end
            if n < total then return (L["%d of %d IDs"]):format(n, total) end
            return total == 1 and "" or L["all IDs"]
        end,
        -- dimmed: a spell that is off, and the IDs that do not count
        off = function(w)
            local s = Sel()
            if w.header then return ns.SpellOff(s, w.value) end
            return not Counting(s, w.key)[w.value]
        end,
        checked = function(w)
            local s = Sel()
            if w.header then return SpellState(s, w.value) end
            return Counting(s, w.key)[w.value] and true or false
        end,
        onCheck = function(w, v)
            local s = Sel()
            if w.header then
                -- the spell box: all IDs (also later ranks) or off
                if v then s.ranks[w.value] = nil else s.ranks[w.value] = false end
            else
                local set, n, total = Counting(s, w.key)
                if (set[w.value] ~= nil) ~= v then n = n + (v and 1 or -1) end
                set[w.value] = v or nil
                -- none: off; every one: back to "all" (later ranks count too)
                if n == 0 then s.ranks[w.key] = false
                elseif n >= total then s.ranks[w.key] = nil
                else s.ranks[w.key] = set end
            end
            IndChanged()
        end,
        onToggle = function(h) h.closed = not h.closed end,
        canRemove = function(w) return w.header end,
        onRemove = function(_, w)
            local s = Sel()
            for i, key in ipairs(s.spells) do
                if key == w.value then table.remove(s.spells, i) break end
            end
            s.ranks[w.value] = nil
            IndChanged()
        end,
        empty = L["No spells yet: every buff counts."],
        rows = 8,
    })

    -- type a name or ID, Enter or the button adds it
    local addRow = UI.Row(c, 20)
    local addBox = UI.EditBox(addRow, 150)
    local addBtn = UI.Button(addRow, L["Add spell"], 100, 20, function()
        local key = ns.ParseSpellInput(addBox:GetText())
        if not key then return end
        table.insert(Sel().spells, key)
        addBox:SetText("")
        addBox:ClearFocus()
        Repaint()
    end)
    addBtn:SetPoint("TOPRIGHT")
    addBox:SetPoint("TOPLEFT")
    addBox:SetPoint("RIGHT", addBtn, "LEFT", -6, 0)
    addBox:SetScript("OnEnterPressed", function() addBtn:Click() end)

    ---------------------------------------------------------------------------
    -- Frame preview: it is a real frame (the same code as test mode) with the
    -- chosen indicator and all its options. It can be dragged: when dropped,
    -- the closest anchor point (of the 9) and the exact X/Y offset are picked.
    ---------------------------------------------------------------------------
    local SAMPLE_H = 110
    local posSample = UI.Row(c, SAMPLE_H + 18)
    local psBg = posSample:CreateTexture(nil, "BACKGROUND")
    psBg:SetPoint("TOPLEFT")
    psBg:SetPoint("TOPRIGHT")
    psBg:SetHeight(SAMPLE_H)
    psBg:SetColorTexture(0.03, 0.03, 0.04, 1)
    local psHint = UI.Text(posSample, "", nil, UI.theme.muted)
    psHint:SetPoint("BOTTOMLEFT", 0, 2)
    psHint:SetPoint("BOTTOMRIGHT", 0, 2)

    local pb = CreateFrame("Frame", nil, posSample)
    ns.BuildVisuals(pb)

    -- invisible handle over the chosen indicator (to drag it)
    local handle = CreateFrame("Button", nil, pb)
    handle:SetFrameLevel(pb:GetFrameLevel() + 400)
    handle.hl = handle:CreateTexture(nil, "HIGHLIGHT")
    handle.hl:SetAllPoints()
    handle.hl:SetColorTexture(1, 1, 1, 0.25)
    handle:RegisterForDrag("LeftButton")

    local function Round(v) return math.floor(v + 0.5) end
    local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

    -- Manual drag. The indicator itself (handle.w) follows the cursor, and
    -- the drop is worked out only from numbers taken at the start (its box
    -- inside pb) plus how far the cursor moved, all in pb's own scale, so it
    -- does not depend on frame geometry that may be re-laid out mid-drag.
    local drag
    local function CursorInPB()
        local x, y = GetCursorPosition()
        local sc = pb:GetEffectiveScale()
        return x / sc, y / sc
    end
    local function DragBox()
        local x, y = CursorInPB()
        return drag.left + x - drag.cx, drag.bottom + y - drag.cy
    end
    local function FollowCursor()
        if not drag then return end
        local l, b = DragBox()
        drag.w:ClearAllPoints()
        drag.w:SetPoint("BOTTOMLEFT", pb, "BOTTOMLEFT", l, b)
    end
    handle:SetScript("OnDragStart", function(self)
        local w = self.w
        if not w or not w:GetLeft() or not pb:GetLeft() then return end
        local cx, cy = CursorInPB()
        drag = {
            w = w, cx = cx, cy = cy,
            left = w:GetLeft() - pb:GetLeft(),
            bottom = w:GetBottom() - pb:GetBottom(),
            width = w:GetWidth(), height = w:GetHeight(),
        }
        self:SetScript("OnUpdate", FollowCursor)
        FollowCursor()
    end)
    handle:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        drag = nil
    end)
    handle:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if not drag then return end
        local l, b = DragBox()
        local W, H = drag.width, drag.height
        drag = nil
        local s = Sel()
        if not s then posSample.Refresh() return end
        local PW, PH = pb:GetWidth(), pb:GetHeight()
        -- third of the frame where the center lands -> anchor point
        local fx = (l + W / 2) / PW
        local fy = (b + H / 2) / PH
        local v = fy > 2 / 3 and "TOP" or (fy < 1 / 3 and "BOTTOM" or "")
        local h = fx < 1 / 3 and "LEFT" or (fx > 2 / 3 and "RIGHT" or "")
        local pt = v .. h
        if pt == "" then pt = "CENTER" end
        local x, y
        if h == "LEFT" then x = l
        elseif h == "RIGHT" then x = l + W - PW
        else x = l + W / 2 - PW / 2 end
        if v == "BOTTOM" then
            -- measured from above the resource bar (as the frames do)
            local off = 0
            if pb.area and pb.area:GetBottom() and pb:GetBottom() then
                off = pb.area:GetBottom() - pb:GetBottom()
            end
            y = b - off
        elseif v == "TOP" then y = b + H - PH
        else y = b + H / 2 - PH / 2 end
        s.point = pt
        s.x = Clamp(Round(x), -80, 80)
        s.y = Clamp(Round(y), -60, 60)
        Repaint()
    end)

    posSample.Refresh = function()
        if not ns.P then return end
        -- the preview frame always shows the profile being edited
        local LY = ns.EP().layout
        local W, H = LY.width, LY.height
        local z = math.min(3, (posSample:GetWidth() - 60) / W, (SAMPLE_H - 20) / H)
        pb:SetScale(math.max(0.2, z))
        pb:SetSize(W, H)
        pb:ClearAllPoints()
        pb:SetPoint("CENTER", psBg, "CENTER", 0, 0)
        -- only the indicator being edited
        ns.FillPreviewButton(pb, selInd, ns.EP())

        local s = Sel()
        local strip = s and s.type == "bar" and ns.STRIP_SIDE[s.span]
        local whole = s and (s.type == "border" or s.type == "overlay")
        local w = s and not whole and not strip and pb.ind and pb.ind[selInd]
        handle:ClearAllPoints()
        handle.w = w or nil
        if w then
            handle:SetAllPoints(w)
            handle:Show()
            psHint:SetText(L["Drag the indicator to place it wherever you want."])
        else
            handle:Hide()
            psHint:SetText("")
        end
    end
    -- the card gives it its width: the scale of the frame follows it
    posSample.OnWidth = function(w)
        if w ~= posSample.lastW then
            posSample.lastW = w
            posSample.Refresh()
        end
    end
    table.insert(UI.widgets, posSample)

    -- the colors per type are shared by every indicator: they live in the Colors page
    local function DispelButton()
        return UI.Buttons(c, { { L["Edit type colors"], function() win:Select("colors") end } })
    end

    local function sized() return rect() or iconLike() end
    local function borderT() local t = T() return notDispel() and t ~= "text" end
    local function borderOn() return Sel().showBorder ~= false end
    local function typedIcon() return iconLike() and ns.IndicatorTyped(Sel()) end
    local function typedFrame() return frameT() and ns.IndicatorTyped(Sel()) end
    local function byType() return Sel().dispelColor and true or false end
    -- where a color comes from: the debuff type or a chosen one (dispelColor)
    local function ColorSource() return { { true, L["By type"] }, { false, L["Custom"] } } end
    local function sweepT() local t = T() return timed() and (t == "icon" or t == "icons" or t == "square") end
    local function sweepOn() return Sel().swipe ~= false end

    local DISPEL_TYPES = {
        { "Magic", ns.DispelLabel("Magic", L["Magic"]) }, { "Curse", ns.DispelLabel("Curse", L["Curse"]) },
        { "Disease", ns.DispelLabel("Disease", L["Disease"]) }, { "Poison", ns.DispelLabel("Poison", L["Poison"]) },
    }

    Cards(rightPage, 1, {
        Header(L["Indicator"]),
        nameIn,
        W(UI.Dropdown(c, L["Type"], {
            { "square", L["Color square"] }, { "icon", L["Icon"] }, { "icons", L["Several icons"] },
            { "bar", L["Bar"] }, { "text", L["Text"] },
            { "border", L["Frame border"] }, { "overlay", L["Tint over health"] },
        }, function() return Sel().type end, function(v)
            -- each type starts with its own size and settings
            ns.SetIndicatorType(Sel(), v)
            IndChanged()
        end), isAura),
        W(UI.Attach(UI.Dropdown(c, L["What it measures"], {
            { "time", L["Aura time left"] },
            { "stacks", L["Aura stacks"] },
            { "absorb", L["Player shields (absorb)"] },
            { "heal", L["Player incoming heals"] },
        }, IB("barMeasure"))), function() return isAura() and isBar() end),
        W(UI.Attach(Slider(c, L["Max stacks"], 1, 20, 1, nil, IB("barMaxStacks"))),
            function() return isAura() and isBar() and Sel().barMeasure == "stacks" end),
        W(UI.Attach(UI.Note(c, L["Compared with their max health. It does not watch auras: it shows whenever there is something."])),
            unitBar),
        W(UI.Attach(UI.Dropdown(c, L["What it shows"], {
            { "time", L["Time left"] },
            { "custom", L["Custom text"] },
            { "name", L["Spell name"] },
            { "stacks", L["Stacks"] },
            { "caster", L["Who cast it"] },
        }, IB("textShow"))), function() return isAura() and T() == "text" end),
        W(UI.Attach(customIn), function() return isAura() and T() == "text" and Sel().textShow == "custom" end),

        HeaderIf(L["What it watches"], watchAuras),
        UI.Segmented(c, L["Watches"], {
            { "spells", L["Buff list"] },
            { "dispellable", L["I can dispel"] },
            { "debuffTypes", L["By type"] },
        }, IB("watch")),
        W(UI.Attach(UI.Note(c, L["The game decides which ones you can dispel (based on your class and talents)."])),
            function() return dispWatch() and Sel().watch == "dispellable" end),
        W(UI.Attach(UI.Note(c, L["Shows the checked types even if your class cannot dispel them."])),
            function() return dispWatch() and Sel().watch == "debuffTypes" end),
        W(UI.Attach(UI.CheckGroup(c, nil, DISPEL_TYPES,
            function(t) return Sel().dispelTypes[t] end,
            function(t, v) Sel().dispelTypes[t] = v IndChanged() end, { columns = 2 })), dispWatch),
        W(UI.Segmented(c, L["From whom"], { { "mine", L["Mine"] }, { "others", L["Others'"] }, { "any", L["Anyone"] } },
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
        W(UI.Segmented(c, L["Show when"], { { "present", L["Has it"] }, { "missing", L["Missing"] } }, IB("mode")), listWatch),
        W(UI.Attach(UI.Note(c, L["\"Missing\" only works out of combat: in combat the game does not let addons check which buffs a player has."])), isMissing),
        UI.Check(c, L["Only out of combat"], IB("onlyOOC")),

        HeaderIf(L["Spells"], listWatch),
        UI.Note(c, L["Buffs (by ID or name; any rank works). No spells = all buffs. The game decides the order."]),
        addRow,
        spellList,
        UI.Note(c, L["Untick a spell to turn it off without removing it. Open it to choose which of its IDs (ranks) count; all ticked: every ID, also ranks added later."]),

        HeaderIf(L["What it watches"], function() return K() == "raiddebuff" end),
        UI.Note(c, L["Shows the most important boss debuff on the player. The game decides which ones are boss debuffs."]),

        HeaderIf(L["What it watches"], function() return K() == "debuffs" end),
        UI.Check(c, L["Only the ones I can dispel"], IB("onlyDispellable")),

        HeaderIf(L["What it watches"], function() return K() == "heal" end),
        UI.Note(c, L["Lights up while someone casts a heal on the player."]),

        HeaderIf(L["What it watches"], function() return K() == "threat" end),
        UI.Note(c, L["How many enemies are attacking the player. Counts enemies with a nameplate and bosses."]),

        Header(L["Position and size"]),
        posSample,
        PositionBlock(c, Sel, IndChanged, { showIf = function()
            return notDispel() and not (isBar() and ns.STRIP_SIDE[Sel().span])
        end }),
        W(Slider(c, L["Width"], 1, 120, 1, UI.px, IB("width")), sized),
        W(UI.Attach(Slider(c, L["Height"], 1, 60, 1, UI.px, IB("height"))), sized),
        WE(UI.Attach(UI.Segmented(c, L["Image fit"], {
            { "crop", L["Crop"] },
            { "stretch", L["Stretch"] },
        }, IB("iconFit"))), iconLike, function() return Sel().width ~= Sel().height end),
        W(UI.Dropdown(c, L["Span"], {
            { "none", L["No (its own width and height)"] },
            { "width", L["Full width, over the frame"] },
            { "height", L["Full height, over the frame"] },
            { "stripTop", L["Own strip on top"] },
            { "stripBottom", L["Own strip at the bottom"] },
            { "stripLeft", L["Own strip on the left"] },
            { "stripRight", L["Own strip on the right"] },
        }, IB("span")), isBar),
        W(UI.Attach(UI.Note(c, L["With its own strip, the health bar shrinks to make room (like the mana bar). Top and bottom use the height; left and right, the width."])),
            function() return isBar() and ns.STRIP_SIDE[Sel().span] ~= nil end),
        W(UI.Segmented(c, L["Bar orientation"], { { "HORIZONTAL", L["Horizontal"] }, { "VERTICAL", L["Vertical"] } },
            IB("barOrient")), isBar),
        W(UI.Attach(UI.Check(c, L["Drain in reverse"], IB("barReverse"))), isBar),

        W(Slider(c, L["Max icons"], 1, 8, 1, nil, IB("max")), iconsT),
        W(UI.Dropdown(c, L["Grow towards"], { { "LEFT", L["Left"] }, { "RIGHT", L["Right"] }, { "UP", L["Top"] }, { "DOWN", L["Bottom"] } },
            IB("grow")), iconsT),
        W(Slider(c, L["Spacing between icons"], 0, 10, 1, UI.px, IB("spacing")), iconsT),

        HeaderIf(L["Frame border"], function() return T() == "border" end),
        Slider(c, L["Thickness"], 1, 6, 1, UI.px, IB("width")),
        UI.Check(c, L["Inside the frame"], IB("borderInside")),

        HeaderIf(L["Tint over health"], function() return T() == "overlay" end),
        UI.Segmented(c, L["Shape"], {
            { "up", L["Bottom up"] },
            { "down", L["Top down"] },
            { "solid", L["Solid"] },
        }, IB("tintShape")),
        Slider(c, L["Intensity"], 0.1, 1, 0.05, UI.pct, IB("overlayAlpha")),

        -- debuff border / tint: native type icon on top
        HeaderIf(L["Type icon"], typeIconT),
        UI.Check(c, ns.DispelLabel("Poison", L["Show the type icon"]), IB("typeIcon")),
        WE(Slider(c, L["Size"], 8, 32, 1, UI.px, IB("typeIconSize")), nil, typeIconOn),
        PositionBlock(c, function() return Sel().typeIconPos end, IndChanged, { enableIf = typeIconOn }),

        Header(L["Look"]),
        -- square, bar, text: their color
        W(Swatch(c, L["Color"], function() return Sel().color end, nil, true), colored),
        -- frame border / tint: color by type or a chosen one
        W(UI.Segmented(c, L["Color"], ColorSource(), IB("dispelColor")), typedFrame),
        WE(UI.Attach(DispelButton()), typedFrame, byType),
        WE(UI.Attach(Swatch(c, L["Custom color"], function() return Sel().color end, nil, true)),
            frameT, function() return not (typedFrame() and byType()) end),
        -- icons: one switch for the border, then where its color comes from
        W(UI.Check(c, L["Border"], IB("showBorder")), borderT),
        WE(UI.Attach(UI.Segmented(c, L["Color"], ColorSource(), IB("dispelColor"))), typedIcon, borderOn),
        WE(UI.Attach(DispelButton()), typedIcon, function() return borderOn() and byType() end),
        WE(UI.Attach(Swatch(c, L["Custom color"], function() return Sel().borderColor end, nil, true)),
            borderT, function() return borderOn() and not (typedIcon() and byType()) end),
        WE(UI.Attach(Slider(c, L["Border thickness"], 1, 4, 1, UI.px, IB("borderSize"))), borderT, borderOn),
        W(UI.Check(c, L["Time sweep"], IB("swipe")), sweepT),
        WE(UI.Attach(UI.Dropdown(c, L["Sweep style"], {
            { "clock", L["Clock"] },
            { "clockReverse", L["Reverse clock (fills up)"] },
            { "drainV", L["Vertical fill (bottom to top)"] },
            { "drainH", L["Horizontal fill (left to right)"] },
            { "bar", L["Thin bar at the bottom (grows)"] },
        }, function() return Sel().swipeStyle or "clock" end, function(v) Sel().swipeStyle = v IndChanged() end)),
            sweepT, sweepOn),
        WE(UI.Attach(Swatch(c, L["Sweep color"], function() return Sel().swipeColor end, nil, true)),
            sweepT, sweepOn),
        WE(UI.Attach(UI.Check(c, L["Spark"], IB("swipeSpark"))), sweepT, sweepOn),
        WE(UI.Attach(Swatch(c, L["Spark color"], function() return Sel().sparkColor end, nil, true)),
            sweepT, function() return sweepOn() and Sel().swipeSpark end),

        -- in the "Text" type, this is the text itself: it goes where the indicator is, with its color
        W(Header(L["Time text"], function() return T() == "text" and L["Text"] or L["Time text"] end),
            function() return hasText() or (isAura() and T() == "text") end),
        TextBlock(c, function() return Sel().timerText end, IndChanged, {
            show = { IB("timer") },
            showCheckIf = function() return T() ~= "text" end,
            enableIf = function() return T() == "text" or Sel().timer end,
            colorIf = function() return T() ~= "text" end,
            positionIf = function() return T() ~= "text" end,
        }),
        -- threat count: this is its number (always shown)
        W(Header(L["Stacks text"], function() return K() == "threat" and L["Number"] or L["Stacks text"] end),
            function() return hasText() or K() == "threat" end),
        TextBlock(c, function() return Sel().stacksText end, IndChanged, {
            show = { IB("stacks") },
            showCheckIf = function() return K() ~= "threat" end,
            enableIf = function() return Sel().stacks or K() == "threat" end,
            positionIf = function() return T() ~= "text" end,
        }),
    })
end

-------------------------------------------------------------------------------
-- Catalog. Left, the groups. Right, the chosen group: its spells by class
-- (tick the ones to add) and how to add them as indicators.
-------------------------------------------------------------------------------
local catGroup = "hots"
local catSel, catOrigin, catMode = {}, {}, {}

local function BuildCatalog(container)
    local leftPage, rightPage = UI.Split(container, 210)
    local c = rightPage.content
    local myClass = select(2, UnitClass("player"))

    local function Group() return ns.CatalogByKey[catGroup] end
    local function Sel(g)
        g = g or Group()
        if not catSel[g.key] then
            -- when a group is opened for the first time: the recommendations for my class
            catSel[g.key] = {}
            for _, e in ipairs(ns.CatalogRecommended(g, myClass)) do catSel[g.key][e] = true end
        end
        return catSel[g.key]
    end

    -- Left: the groups, one tile each (icon, name, kind, how many are checked)
    local TH, TGAP = 44, 6
    local TM, AC = UI.theme, UI.theme.accent
    local ACHEX = ("|cff%02x%02x%02x"):format(AC[1] * 255, AC[2] * 255, AC[3] * 255)
    local tiles = UI.Row(leftPage.content, #ns.Catalog * (TH + TGAP) - TGAP)
    tiles.buttons = {}
    local function PaintTile(b)
        local on = b.group.key == catGroup
        if on then
            b:SetBackdropColor(AC[1] * 0.25, AC[2] * 0.25, AC[3] * 0.25, 1)
            b:SetBackdropBorderColor(AC[1], AC[2], AC[3], 1)
        else
            b:SetBackdropColor(unpack(TM.field))
            if b:IsMouseOver() then b:SetBackdropBorderColor(AC[1], AC[2], AC[3], 0.6)
            else b:SetBackdropBorderColor(unpack(TM.border)) end
        end
        b.mark:SetShown(on)
        b.name:SetTextColor(unpack(on and TM.text or { 0.85, 0.85, 0.85 }))
    end
    for i, g in ipairs(ns.Catalog) do
        local b = CreateFrame("Button", nil, tiles, "BackdropTemplate")
        local y = -(i - 1) * (TH + TGAP)
        b:SetPoint("TOPLEFT", 0, y)
        b:SetPoint("TOPRIGHT", 0, y)
        b:SetHeight(TH)
        UI.Backdrop(b, TM.field, TM.border)
        b.group = g
        b.mark = b:CreateTexture(nil, "OVERLAY")
        b.mark:SetPoint("TOPLEFT", 1, -1)
        b.mark:SetPoint("BOTTOMLEFT", 1, 1)
        b.mark:SetWidth(3)
        b.mark:SetColorTexture(AC[1], AC[2], AC[3], 1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(28, 28)
        b.icon:SetPoint("LEFT", 10, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.name = UI.Text(b, L[g.name], TM.titleFont)
        b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, 0)
        b.name:SetPoint("RIGHT", -8, 0)
        b.name:SetWordWrap(false)
        b.kind = UI.Text(b, g.auraType == "HARMFUL" and L["debuffs"] or L["buffs"], TM.labelFont, TM.muted)
        b.kind:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 0)
        b.count = UI.Text(b, "", TM.labelFont, TM.muted)
        b.count:SetPoint("BOTTOM", b.icon, "BOTTOM", 0, 0)
        b.count:SetPoint("RIGHT", -8, 0)
        b.count:SetJustifyH("RIGHT")
        UI.Tip(b, L[g.name], L[g.desc])
        b:HookScript("OnEnter", PaintTile)
        b:HookScript("OnLeave", PaintTile)
        b:SetScript("OnClick", function()
            catGroup = g.key
            UI.RefreshAll()
        end)
        tiles.buttons[i] = b
    end
    tiles.Refresh = function()
        for _, b in ipairs(tiles.buttons) do
            local g = b.group
            b.icon:SetTexture(select(2, ns.SpellKeyInfo(g.icon)) or "Interface\\Icons\\INV_Misc_QuestionMark")
            local n, sel = 0, Sel(g)
            for _, e in ipairs(g.spells) do if sel[e] then n = n + 1 end end
            b.count:SetText(((n > 0) and (ACHEX .. n .. "|r") or "0") .. "/" .. #g.spells)
            PaintTile(b)
        end
    end
    table.insert(UI.widgets, tiles)
    Cards(leftPage, 1, {
        Header(L["Groups"]),
        tiles,
    })

    -- Right: what the group is for, then its spells
    local desc = UI.Note(c, "")
    desc.Refresh = function() desc:SetText(L[Group().desc]) end
    table.insert(UI.widgets, desc)

    -- one group per class, the class box checks all
    -- of its spells (a dash: some of them)
    local headers = {}   -- [group key .. class] = header row (keeps open/closed)
    local function Rows()
        local g = Group()
        local out = {}
        for _, class in ipairs(ns.CLASS_ORDER) do
            local entries = {}
            for _, e in ipairs(g.spells) do if e.class == class then entries[#entries + 1] = e end end
            if #entries > 0 then
                local hk = g.key .. class
                local h = headers[hk]
                if not h then h = { header = true, class = class } headers[hk] = h end
                h.entries = entries
                local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                local cname = ns.CLASS_NAMES[class] and L[ns.CLASS_NAMES[class]] or class
                if col then cname = ("|cff%02x%02x%02x%s|r"):format(col.r * 255, col.g * 255, col.b * 255, cname) end
                h.label = cname .. ((class == myClass) and ("  |cff888888(" .. L["your class"] .. ")|r") or "")
                local n = 0
                for _, e in ipairs(entries) do if Sel(g)[e] then n = n + 1 end end
                h.count = n .. "/" .. #entries
                out[#out + 1] = h
                if not h.closed then
                    for _, e in ipairs(entries) do out[#out + 1] = e end
                end
            end
        end
        return out
    end
    local spells = UI.List(c, {
        items = Rows,
        label = function(e) return (ns.SpellKeyInfo(ns.CatalogKey(e))) end,
        lead = "icon",
        icon = function(e) return select(2, ns.SpellKeyInfo(ns.CatalogKey(e))) end,
        spell = function(e) return ns.KeyIDs(ns.CatalogKey(e))[1] end,
        secondary = function(e) return e.note and L[e.note] or "" end,
        checked = function(d)
            local sel = Sel()
            if not d.header then return sel[d] and true or false end
            local n = 0
            for _, e in ipairs(d.entries) do if sel[e] then n = n + 1 end end
            if n == 0 then return false end
            return n == #d.entries or "partial"
        end,
        onCheck = function(d, v)
            local sel = Sel()
            if d.header then
                for _, e in ipairs(d.entries) do sel[e] = v or nil end
            else
                sel[d] = v or nil
            end
        end,
        onToggle = function(h) h.closed = not h.closed end,
        rows = 14,
    })
    local selButtons = UI.Buttons(c, {
        { L["Recommended"], function()
            local g = Group()
            wipe(Sel(g))
            for _, e in ipairs(ns.CatalogRecommended(g, myClass)) do Sel(g)[e] = true end
            UI.RefreshAll()
        end, nil, L["Checks only the spells recommended for your class."] },
        { L["Check all"], function()
            for _, e in ipairs(Group().spells) do Sel()[e] = true end
            UI.RefreshAll()
        end },
        { L["Uncheck all"], function()
            wipe(Sel())
            UI.RefreshAll()
        end },
    })

    -- Add: how, and the button
    local result = UI.Note(c, "")
    local wanted = false
    local addBtn = UI.Buttons(c, { { L["Add as indicator"], function()
        local g = Group()
        local entries = {}
        for _, e in ipairs(g.spells) do
            if Sel(g)[e] then table.insert(entries, e) end
        end
        if #entries == 0 then
            result:SetText(L["|cffff7755Check at least one spell.|r"])
            wanted = false
            UI.RefreshAll()
            return
        end
        local origin = catOrigin[g.key] or g.origin
        local mode = (g.auraType == "HELPFUL") and (catMode[g.key] or g.mode or "present") or "present"
        local new = ns.CatalogMakeIndicators(g, entries, origin, mode)
        local list = ns.EP().indicators
        local names = {}
        for _, ind in ipairs(new) do
            table.insert(list, ind)
            table.insert(names, (L["\"%s\""]):format(ind.name))
        end
        selInd = #list - #new + 1
        result:SetText((L["|cff55ff55Added:|r %s to profile %s. Move and adjust it in Indicators."]):format(
            table.concat(names, ", "), ns.EditedProfileName()))
        wanted = true
        Repaint()
    end, "accent" } })
    result.showIf = function() return (result.text:GetText() or "") ~= "" end
    local goBtn = UI.Buttons(c, { { L["See in Indicators"], function()
        if ns.OpenIndicators then ns.OpenIndicators() end
    end } })
    goBtn.showIf = function() return wanted end

    Cards(rightPage, 1, {
        Header(L[Group().name], function() return L[Group().name] end),
        desc,
        selButtons,
        spells,
        Header(L["Add as indicator"]),
        UI.Segmented(c, L["From whom"], {
            { "mine", L["Mine"] }, { "others", L["Others'"] }, { "any", L["Anyone"] },
        }, function() return catOrigin[catGroup] or Group().origin end, function(v) catOrigin[catGroup] = v end),
        Cond(UI.Segmented(c, L["Show when"], {
            { "present", L["Has it"] }, { "missing", L["Missing"] },
        }, function() return catMode[catGroup] or Group().mode or "present" end, function(v) catMode[catGroup] = v end),
            function() return Group().auraType == "HELPFUL" end),
        Cond(UI.Attach(UI.Note(c, L["\"Missing\" adds one warning per buff."])),
            function() return Group().auraType == "HELPFUL" end),
        addBtn,
        result,
        goBtn,
    })
end

-------------------------------------------------------------------------------
-- Instances: a guide of each instance's bosses and debuffs (read only)
-- Left, the instances by category. Right, the debuffs grouped by boss, with
-- the game's crowd control flag.
-------------------------------------------------------------------------------
local function BuildInstances(container)
    local leftPage, rightPage = UI.Split(container, 210)
    local selKey, picked
    local query = ""
    local Instance, Debuff = Wrapper(), Wrapper()

    local function IsHere(key)
        for _, k in ipairs(ns.CurrentInstanceKeys()) do
            if k == key then return true end
        end
        return false
    end

    -- until you pick one, follow the place where you are
    local catHeaders = {}
    local function CatHeader(cat)
        local h = catHeaders[cat]
        if not h then
            -- closed at first: every category except raids
            h = { header = true, cat = cat, closed = cat ~= "raid", off = cat == "unannounced" }
            catHeaders[cat] = h
        end
        return h
    end
    local function Follow()
        if picked then return end
        local here = ns.CurrentInstanceKeys()[1]
        if here then
            selKey = here
            CatHeader(ns.InstanceCategory(here)).closed = false
        end
        selKey = selKey or ns.InstanceOrder[1]
    end

    local function InstanceRows()
        Follow()
        local groups = {}
        for _, k in ipairs(ns.InstanceOrder) do
            local cat = ns.InstanceCategory(k)
            groups[cat] = groups[cat] or {}
            table.insert(groups[cat], k)
        end
        local out = {}
        for _, cat in ipairs(ns.INSTANCE_KINDS) do
            local list = groups[cat]
            if list and #list > 0 then
                local h = CatHeader(cat)
                h.label = L[ns.INSTANCE_KIND_NAMES[cat]]
                h.count = tostring(#list)
                out[#out + 1] = h
                if not h.closed then
                    for _, k in ipairs(list) do out[#out + 1] = Instance(k) end
                end
            end
        end
        return out
    end

    local function DebuffCount(key)
        local n = 0
        for _, b in ipairs(ns.Instances[key].bosses) do n = n + #b[2] end
        return n
    end

    local instList = UI.List(leftPage.content, {
        items = InstanceRows,
        label = function(w) return ns.Instances[w.value].name end,
        off = function(w) return ns.InstanceCategory(w.value) == "unannounced" end,
        lead = "dot",
        color = function(w) return IsHere(w.value) and GOOD or nil end,
        secondary = function(w) return tostring(DebuffCount(w.value)) end,
        selected = function(w) return w.value == selKey end,
        onSelect = function(_, w)
            selKey, picked = w.value, true
        end,
        onToggle = function(h) h.closed = not h.closed end,
        rows = 22,
    })
    Cards(leftPage, 1, {
        Header(L["Instances"]),
        instList,
        UI.Note(leftPage.content, L["Green dot: you are here."]),
    })

    -- Right: search and the debuffs of the chosen instance, by boss
    local function Matches(name, id)
        if query == "" then return true end
        local q = query:lower()
        if name and tostring(name):lower():find(q, 1, true) then return true end
        return id ~= nil and tostring(id):find(q, 1, true) ~= nil
    end

    local bossHeaders = {}   -- [instance .. "\n" .. boss] (open/closed this session)
    local function DebuffRows()
        local rows = {}
        local def = selKey and ns.Instances[selKey]
        for _, b in ipairs(def and def.bosses or {}) do
            local items = {}
            for _, key in ipairs(b[2]) do
                local name, _, id = ns.SpellKeyInfo(key)
                if Matches(name, id) then items[#items + 1] = Debuff(key) end
            end
            if #items > 0 or query == "" then
                local ck = tostring(selKey) .. "\n" .. b[1]
                local h = bossHeaders[ck]
                if not h then h = { header = true, label = b[1] } bossHeaders[ck] = h end
                -- a search opens every boss
                h.closed = h.userClosed and query == "" or false
                h.count = #items > 0 and ("(%d)"):format(#items) or L["(no known debuffs)"]
                rows[#rows + 1] = h
                if not h.closed then
                    for _, e in ipairs(items) do rows[#rows + 1] = e end
                end
            end
        end
        return rows
    end

    local rc = rightPage.content
    local search = UI.SearchBox(rc, L["Search by name or ID"], function(text)
        query = (text or ""):trim()
        UI.RefreshAll()
    end)
    local debuffList = UI.List(rc, {
        items = DebuffRows,
        label = function(w) return (ns.SpellKeyInfo(w.value)) end,
        lead = "icon",
        icon = function(w) return select(2, ns.SpellKeyInfo(w.value)) end,
        spell = function(w) return select(3, ns.SpellKeyInfo(w.value)) end,
        secondary = function(w) return tostring(select(3, ns.SpellKeyInfo(w.value)) or L["looking up..."]) end,
        tag = function(w)
            if ns.IsCrowdControlKey(w.value) then return L["Control"], BAD end
            return L["Debuff"]
        end,
        columns = { name = L["Debuff"], secondary = L["ID"], tag = L["Type"] },
        onToggle = function(h)
            h.userClosed = not h.userClosed
        end,
        empty = function()
            return query ~= "" and L["Nothing matches the search."] or L["No known bosses or debuffs yet."]
        end,
        rows = 17,
    })

    -- the card title is the instance
    local function Title()
        Follow()
        local def = selKey and ns.Instances[selKey]
        local unannounced = def and ns.InstanceCategory(selKey) == "unannounced"
        return def and (def.name .. (unannounced and ("  |cff888888(" .. L["not announced"] .. ")|r") or "")) or ""
    end

    Cards(rightPage, 1, {
        Header("", Title),
        search,
        debuffList,
        Header(L["How to read this guide"]),
        UI.Note(rc, L["The debuffs each boss puts on your group. In combat the game does not tell addons which debuff is which, so your frames show these like any other debuff: you recognise them by their icon."]),
        UI.Note(rc, "|cffff5a4d" .. L["Control"] .. "|r: " .. L["the game flags it as crowd control (stun, fear, sleep, mind control...)."]),
        UI.Note(rc, "|cffaaaaaa" .. L["Debuff"] .. "|r: " .. L["any other debuff."]),
    })
end

-------------------------------------------------------------------------------
-- Colors: the ones behind "class color", "resource color", "by health" and
-- "color by type", for the whole profile
-------------------------------------------------------------------------------
local COLOR_CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local function BuildColors(container)
    local page = UI.Page(container, 2)
    local c = page.content
    local function Col(group, key) return function() return ns.EP().colors[group][key] end end

    local classes = { Header(L["Classes"]) }
    for _, token in ipairs(COLOR_CLASSES) do
        classes[#classes + 1] = Swatch(c, L[ns.CLASS_NAMES[token]], Col("class", token))
    end
    classes[#classes + 1] = Swatch(c, L["Pets"], function() return ns.EP().colors.pet end)

    Cards(page, 1, {
        classes,
        Header(L["Resources"]),
        Swatch(c, L["Mana"], Col("power", "MANA")),
        Swatch(c, L["Rage"], Col("power", "RAGE")),
        Swatch(c, L["Energy"], Col("power", "ENERGY")),
    })

    -- the game draws the type colors without opacity: no opacity here
    local dispel = { Header(L["Debuff types"]) }
    for _, d in ipairs({
        { "Magic", L["Magic"] }, { "Curse", L["Curse"] }, { "Disease", L["Disease"] }, { "Poison", L["Poison"] },
        { "none", L["No type"] },
    }) do
        dispel[#dispel + 1] = Swatch(c, ns.DispelLabel(d[1], d[2], 22), function() return ns.EP().dispelColors[d[1]] end)
    end

    local reset = UI.Buttons(c, {
        { L["Reset every color"], function()
            local P, D = ns.EP(), ns.profileDefaults
            P.colors = ns.DeepCopy(D.colors)
            P.dispelColors = ns.DeepCopy(D.dispelColors)
            Repaint()
        end, "danger" },
    })
    UI.Confirm(reset.buttons[1], L["Sure?"])

    Cards(page, 2, {
        Header(L["Health gradient"]),
        Swatch(c, L["Low health"], Col("gradient", "low")),
        Swatch(c, L["Half health"], Col("gradient", "mid")),
        Swatch(c, L["Full health"], Col("gradient", "high")),
        dispel,
        Header(L["Reset"]),
        reset,
    })
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
local function CreateWindow()
    win = UI.Window({ name = "TileOptions", title = "Tile", version = ns.version,
        logo = "Interface\\AddOns\\Tile\\Media\\Icon", status = false })

    win:AddHeaderButton(L["Unlock"], function() ns.SetLocked(not ns.db.locked) end,
        function() return not ns.db.locked end)
    win:AddHeaderButton(L["Test mode"], function() ns.ToggleTest() end,
        function() return ns.testing end)

    win:AddNav("general", L["General"], BuildGeneral)
    win:AddNav("profiles", L["Profiles"], BuildProfiles)
    win:AddNav("layout", L["Layout"], BuildLayout)
    win:AddNav("bars", L["Bars"], BuildBars)
    win:AddNav("texts", L["Texts"], BuildTexts)
    win:AddNav("elements", L["Status icons"], BuildElements)
    win:AddNav("colors", L["Colors"], BuildColors)
    win:AddNav("indicators", L["Indicators"], BuildIndicators)
    win:AddNav("catalog", L["Presets"], BuildCatalog)
    win:AddNav("instances", L["Instances"], BuildInstances)

    UI.OnRefresh = function()
        win:SetSubtitle((L["editing: |cffffffff%s|r · active: |cffffffff%s|r"]):format(
            ns.EditedProfileName(), tostring(ns.activeName)))
    end

    ns.OpenIndicators = function() win:Select("indicators") end
    ns.OpenCatalog = function() win:Select("catalog") end
    local function Refresh() if win:IsShown() then UI.RefreshAll() end end
    ns.OnLockChanged = Refresh
    ns.OnTestChanged = Refresh
    ns.OnProfileChanged = Refresh
    win:Select("general")
end

-- Open (without closing it if it is already open)
function ns.OpenOptions()
    if win and win:IsShown() then return end
    ns.ToggleOptions()
end

function ns.ToggleOptions()
    if not win then
        CreateWindow()
        return
    end
    win:Toggle()
end
