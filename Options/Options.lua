-------------------------------------------------------------------------------
-- MendFrames - Options window (/mf)
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L
local UI = ns.UI
local ACCENT = UI.ACCENT

local win
local pages, navs = {}, {}
local COL1, COL2 = 10, 290

-- Binding to the profile being edited
local function PB(path, after)
    return UI.Bind(ns.EP, path, function(v)
        if after then after(v) end
        ns.ProfileChanged()
        UI.RefreshAll()
    end)
end

local function Refresh() UI.RefreshAll() end

-- After changing something of the edited profile from a shared block
local function PAfter()
    ns.ProfileChanged()
    UI.RefreshAll()
end

-------------------------------------------------------------------------------
-- Shared blocks: each kind of thing always has the same options,
-- with the same names and in the same order
--   Text:  Show · Font · Size · Outline · Color · Position (X, Y)
--   Icon:  Show · Size · Position (X, Y)
--   Bar:   Texture · Color (custom, brightness) · Opacity
-------------------------------------------------------------------------------

-- Joins single controls and lists of controls into one list
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

local function TextColors()
    return { { "white", L["White"] }, { "class", L["Class color"] }, { "custom", L["Custom"] } }
end
local function BarColors()
    return { { "class", L["Class color"] }, { "custom", L["Single color"] }, { "gradient", L["Gradient by health"] } }
end
local function PowerColors()
    return { { "power", L["Resource color"] }, { "class", L["Class color"] }, { "custom", L["Single color"] } }
end

-- Position: anchor point and X/Y attached (same ranges everywhere)
local function PositionBlock(c, root, after, o)
    o = o or {}
    return {
        Cond(UI.Dropdown(c, L["Position"], UI.PointList, UI.Bind(root, "point", after)), o.showIf, o.enableIf),
        Cond(UI.Attach(UI.Slider(c, "X", -80, 80, 1, nil, UI.Bind(root, "x", after))), o.showIf, o.enableIf),
        Cond(UI.Attach(UI.Slider(c, "Y", -60, 60, 1, nil, UI.Bind(root, "y", after))), o.showIf, o.enableIf),
    }
end

-- Text. root() returns its style table.
-- o.show = { get, set } adds "Show"; o.extra, controls right after;
-- o.showIf / o.enableIf for the whole block (enableIf does not affect "Show");
-- o.showCheckIf, o.colorIf, o.positionIf for specific parts.
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
    Add(UI.Dropdown(c, L["Font"], ns.FontList, B("font")))
    Add(UI.Slider(c, L["Size"], 6, 24, 1, nil, B("size")))
    Add(UI.Dropdown(c, L["Outline"], ns.OutlineList, B("outline")))
    Add(UI.Dropdown(c, L["Color"], TextColors, B("colorMode")), o.colorIf)
    Add(UI.Attach(UI.Swatch(c, L["Custom color"], function() return root().color end,
        function() if after then after() end end, true)),
        o.colorIf, function() return root().colorMode == "custom" end)
    for _, w in ipairs(PositionBlock(c, root, after)) do Add(w, o.positionIf) end
    return list
end

-- Color of a bar: mode, custom color and brightness (the last two, attached)
local function BarColorBlock(c, modes, modeKey, customKey, brightKey)
    local function Mode() return UI.Bind(ns.EP, modeKey)() end
    return {
        UI.Dropdown(c, L["Color"], modes, PB(modeKey)),
        Cond(UI.Attach(UI.Swatch(c, L["Custom color"], function() return UI.Bind(ns.EP, customKey)() end,
            ns.ProfileChanged, true)), nil, function() return Mode() == "custom" end),
        Cond(UI.Attach(UI.Slider(c, L["Brightness"], 0.1, 1, 0.05, UI.pct, PB(brightKey))), nil,
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

    -- Changes the profile being edited (in test mode, also the one shown)
    local function SetEdit(n)
        ns.SetEditName(n)
        ns.ActivateProfile()
        Refresh()
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

    local function ConfirmButton(parent, text, w, func)
        return UI.Confirm(UI.Button(parent, text, w, 20, func))
    end

    ---------------------------------------------------------------------------
    -- Profile being edited
    ---------------------------------------------------------------------------
    local editDD = UI.Dropdown(c, nil, ProfileOptions, ns.EditedProfileName, SetEdit)

    local feedback -- created further down
    local function Say(text)
        feedback.text:SetText(text)
        feedback.text:SetTextColor(0.4, 0.9, 0.5)
        feedback:SetHeight(feedback.text:GetStringHeight() + 2)
        Refresh() -- relayout: the message can take a different height
    end

    local resetBtn = ConfirmButton(editDD, L["Reset"], 90, function()
        local name = ns.EditedProfileName()
        ns.db.profiles[name] = ns.NewProfile()
        ns.ActivateProfile(true)
        ns.ProfileChanged()
        Refresh()
        Say((L["\"%s\" is back to the default settings."]):format(name))
    end)
    resetBtn:SetPoint("LEFT", editDD.button, "RIGHT", 6, 0)
    local deleteBtn = ConfirmButton(editDD, L["Delete"], 70, function()
        local old = ns.EditedProfileName()
        if old == "Default" then return end
        local used = #UsedBy(old) > 0
        ns.db.profiles[old] = nil
        Reassign(old, "Default")
        ns.SetEditName(nil)
        ns.ActivateProfile(true)
        Refresh()
        Say(used and (L["\"%s\" deleted. Where it was used, Default is used now."]):format(old)
            or (L["\"%s\" deleted."]):format(old))
    end)
    deleteBtn:SetPoint("LEFT", resetBtn, "RIGHT", 6, 0)

    local usage = UI.Note(c, "", 520)
    usage.Refresh = function()
        local name = ns.EditedProfileName()
        local used = UsedBy(name)
        if #used > 0 then
            usage.text:SetText((L["Used by this character in: %s."]):format("|cffffffff" .. table.concat(used, ", ") .. "|r"))
        else
            usage.text:SetText(L["|cffff8c4dNo group size uses it yet.|r Assign it below to see it in game (in test mode you already see it)."])
        end
        usage:SetHeight(usage.text:GetStringHeight() + 2)
        UI.SetEnabled(deleteBtn, name ~= "Default")
    end
    table.insert(UI.widgets, usage)

    ---------------------------------------------------------------------------
    -- Create / duplicate / rename
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
    local newBtn = Btn(L["Create new"], 0, function()
        local n = Name()
        ns.db.profiles[n] = ns.NewProfile()
        Done(n, (L["\"%s\" created with the default settings."]):format(n))
    end)
    local dupBtn = Btn(L["Duplicate"], 106, function()
        local n, from = Name(), ns.EditedProfileName()
        ns.db.profiles[n] = ns.DeepCopy(ns.EP())
        Done(n, (L["\"%s\" created as a copy of \"%s\"."]):format(n, from))
    end)
    local renBtn = Btn(L["Rename"], 212, function()
        local n, old = Name(), ns.EditedProfileName()
        ns.db.profiles[n] = ns.db.profiles[old]
        ns.db.profiles[old] = nil
        Reassign(old, n)
        if ns.activeName == old then ns.activeName = n end
        Done(n, (L["\"%s\" is now called \"%s\"."]):format(old, n))
    end)

    -- the buttons are only enabled with a valid name
    local function Validate()
        local n = Name()
        local exists = n ~= "" and ns.db.profiles[n] ~= nil
        local ok = n ~= "" and not exists
        hint:SetText(exists and L["a profile with that name already exists"] or "")
        UI.SetEnabled(newBtn, ok)
        UI.SetEnabled(dupBtn, ok)
        UI.SetEnabled(renBtn, ok and ns.EditedProfileName() ~= "Default")
    end
    nameBox:SetScript("OnTextChanged", Validate)
    nameBox:SetScript("OnEnterPressed", nameBox.ClearFocus)
    actions.Refresh = Validate
    table.insert(UI.widgets, actions)

    feedback = UI.Note(c, L["\"Create new\" starts with the default settings; \"Duplicate\" copies the profile you are editing. Default cannot be deleted or renamed."], 520)

    ---------------------------------------------------------------------------
    local list = {
        UI.Header(c, L["Profile you are editing"]),
        editDD,
        UI.Attach(usage),
        UI.Header(c, L["Create or rename"]),
        actions,
        UI.Attach(feedback),
        UI.Header(c, L["Which profile this character uses for each group size"]),
    }
    for _, key in ipairs(ns.SIZE_KEYS) do
        local dd = UI.Dropdown(c, L[ns.SIZE_NAMES[key]], ProfileOptions,
            function() return ns.CharProfiles()[key] end,
            function(v)
                ns.CharProfiles()[key] = v
                ns.ActivateProfile()
                Refresh()
            end)
        local edit = UI.Button(dd, L["Edit"], 70, 18, function() SetEdit(ns.CharProfiles()[key]) end)
        edit:SetPoint("LEFT", dd.button, "RIGHT", 6, 0)
        local base = dd.Refresh
        dd.Refresh = function(self)
            base(self)
            local now = ns.RealSizeKey() == key
            dd.label:SetText(L[ns.SIZE_NAMES[key]] .. (now and ("  |cff4fc3f7· " .. L["your group now"] .. "|r") or ""))
            UI.SetEnabled(edit, ns.CharProfiles()[key] ~= ns.EditedProfileName())
        end
        list[#list + 1] = dd
    end
    list[#list + 1] = UI.Note(c, L["This way you can have one layout for parties, another for ZG/AQ20 and another for 40-player raids. It switches automatically when you join or leave a group (in combat, it applies when combat ends)."], 520)
    list[#list + 1] = UI.Header(c, L["Preview"])
    list[#list + 1] = UI.Dropdown(c, L["Simulate a group of"], {
        { "party", L["5 (party)"] }, { "raid10", L["10 (raid)"] }, { "raid20", L["20 (raid)"] }, { "raid40", L["40 (raid)"] },
    }, function() return ns.testSize or "raid20" end, function(v)
        -- simulating a size shows (and edits) the profile assigned to that size
        ns.SetEditName(ns.CharProfiles()[v])
        ns.ToggleTest(true, v)
        Refresh()
    end)
    list[#list + 1] = UI.Note(c, L["In test mode you always see the profile you are editing, with the number of players chosen here."], 520)
    list[#list + 1] = UI.Header(c, "General")
    list[#list + 1] = UI.Check(c, L["Hide Blizzard party and raid frames (requires /reload)"],
        function() return ns.db.hideBlizzard end,
        function(v) ns.db.hideBlizzard = v ns.Print(L["applies after /reload."]) end)
    list[#list + 1] = UI.Dropdown(c, L["Language (requires /reload)"], ns.LANGUAGES,
        function() return ns.db.language end,
        function(v) ns.db.language = v ns.Print(L["applies after /reload."]) end)

    local st = UI.Stack(c, COL1, -6, list)
    UI.FitContent(c, { st })

    p.OnShow = function()
        st:Layout()
        UI.FitContent(c, { st })
    end
end

-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------
local function BuildLayout(p)
    local _, c = UI.ScrollPage(p)
    local function E(w, cond) w.enableIf = cond return w end
    local function petsOn() return ns.EP().pets.enabled end
    -- vertical: pets go in columns; horizontal: in rows
    local perCol = UI.Slider(c, L["Pets per column"], 1, 10, 1, nil, PB("pets.perColumn"))
    local baseRefresh = perCol.Refresh
    perCol.Refresh = function(self)
        baseRefresh(self)
        perCol.label:SetText(ns.EP().layout.orientation == "horizontal" and L["Pets per row"] or L["Pets per column"])
    end
    local a = UI.Stack(c, COL1, -6, {
        UI.Header(c, L["Size"]),
        UI.Slider(c, L["Width"], 30, 200, 1, nil, PB("layout.width")),
        UI.Slider(c, L["Height"], 16, 100, 1, nil, PB("layout.height")),
        UI.Slider(c, L["Scale"], 0.5, 2, 0.05, UI.pct, PB("layout.scale")),
        UI.Slider(c, L["Spacing between players"], 0, 12, 1, nil, PB("layout.spacing")),
        UI.Slider(c, L["Spacing between groups"], 0, 40, 1, nil, PB("layout.groupSpacing")),
        UI.Header(c, L["Pets"]),
        UI.Check(c, L["Show"], PB("pets.enabled")),
        E(UI.Check(c, L["Attached to the raid, as one more group"], PB("pets.attach")), petsOn),
        E(UI.Check(c, L["Same size as players"], PB("pets.sameSize")), petsOn),
        UI.Attach(E(UI.Slider(c, L["Width"], 30, 200, 1, nil, PB("pets.width")),
            function() return petsOn() and not ns.EP().pets.sameSize end)),
        UI.Attach(E(UI.Slider(c, L["Height"], 12, 100, 1, nil, PB("pets.height")),
            function() return petsOn() and not ns.EP().pets.sameSize end)),
        E(perCol, petsOn),
    })
    local list = {
        UI.Header(c, L["Arrangement"]),
        UI.Dropdown(c, L["Orientation"], {
            { "vertical", L["Vertical (one column per group)"] },
            { "horizontal", L["Horizontal (one row per group)"] },
        }, PB("layout.orientation")),
        UI.Dropdown(c, L["Group by"], {
            { "GROUP", L["Raid group"] },
            { "ROLE", L["Role (tank, healer, damage)"] },
            { "CLASS", L["Class"] },
        }, PB("layout.groupBy")),
        UI.Check(c, L["Sort by name within the group"], PB("layout.sortByName")),
        UI.Check(c, L["Show in party (not only in raid)"], PB("layout.showParty")),
        UI.Check(c, L["Show myself"], PB("layout.showPlayer")),
        UI.Check(c, L["Show when solo"], PB("layout.showSolo")),
        UI.Header(c, L["Groups shown"]),
    }
    for i = 1, 8 do
        list[#list + 1] = UI.Check(c, (L["Group %d"]):format(i), PB("layout.groups." .. i))
    end
    local b = UI.Stack(c, COL2, -6, list)
    UI.FitContent(c, { a, b })
end

-------------------------------------------------------------------------------
-- Bars
-------------------------------------------------------------------------------
local function BuildBars(p)
    local _, c = UI.ScrollPage(p)
    local function Col(path) return function() return UI.Bind(ns.EP, path)() end end
    local function On(path) return function() return UI.Bind(ns.EP, path)() and true or false end end
    local function Smooth(path)
        return Cond(UI.Check(c, ns.hasNativeSmooth and L["Smooth fill and drain"]
            or L["Smooth fill and drain (not available in this client)"], PB(path)), nil,
            function() return ns.hasNativeSmooth end)
    end
    local power = On("bars.showPower")

    local a = UI.Stack(c, COL1, -6, Flat({
        UI.Header(c, L["Health"]),
        UI.Dropdown(c, L["Texture"], ns.TextureList, PB("bars.healthTex")),
        Smooth("bars.smooth"),
        BarColorBlock(c, BarColors, "bars.healthColor", "bars.customColor", "bars.healthBrightness"),

        UI.Header(c, L["Background (missing health)"]),
        UI.Dropdown(c, L["Texture"], ns.TextureList, PB("bars.bgTex")),
        BarColorBlock(c, BarColors, "bars.bgColor", "bars.bgCustom", "bars.bgBrightness"),
        UI.Slider(c, L["Opacity"], 0, 1, 0.05, UI.pct, PB("bars.bgAlpha")),

        UI.Header(c, L["Heals and shields"]),
        UI.Check(c, L["Incoming heals"], PB("bars.showHealPred")),
        Cond(UI.Attach(UI.Dropdown(c, L["Texture"], ns.TextureList, PB("bars.healPredTex"))), nil, On("bars.showHealPred")),
        Cond(UI.Attach(UI.Swatch(c, L["Color"], Col("bars.healPredColor"), ns.ProfileChanged, true)), nil,
            On("bars.showHealPred")),
        UI.Check(c, L["Shields (absorb)"], PB("bars.showAbsorb")),
        Cond(UI.Attach(UI.Dropdown(c, L["Texture"], ns.TextureList, PB("bars.absorbTex"))), nil, On("bars.showAbsorb")),
        Cond(UI.Attach(UI.Swatch(c, L["Color"], Col("bars.absorbColor"), ns.ProfileChanged, true)), nil,
            On("bars.showAbsorb")),
    }))

    local b = UI.Stack(c, COL2, -6, Flat({
        UI.Header(c, L["Mana / energy / rage"]),
        UI.Check(c, L["Show"], PB("bars.showPower")),
        Cond(UI.Attach(UI.Check(c, L["Only for mana users"], PB("bars.powerOnlyMana"))), nil, power),
        Cond(UI.Dropdown(c, L["Texture"], ns.TextureList, PB("bars.powerTex")), nil, power),
        Cond(Smooth("bars.powerSmooth"), nil, power),
        All(BarColorBlock(c, PowerColors, "bars.powerColor", "bars.powerCustom", "bars.powerBrightness"), nil, power),
        Cond(UI.Slider(c, L["Background opacity"], 0, 1, 0.05, UI.pct, PB("bars.powerBgAlpha")), nil, power),
        Cond(UI.Slider(c, L["Height"], 1, 12, 1, nil, PB("bars.powerHeight")), nil, power),

        UI.Header(c, L["Frame"]),
        UI.Swatch(c, L["Border color"], Col("bars.borderColor"), ns.ProfileChanged, true),
        UI.Slider(c, L["Out of range opacity"], 0.1, 1, 0.05, UI.pct, PB("bars.rangeAlpha")),

        UI.Header(c, L["Highlights"]),
        UI.Check(c, L["Highlight my target"], PB("bars.targetHighlight")),
        Cond(UI.Attach(UI.Swatch(c, L["Color"], Col("bars.targetColor"), ns.ProfileChanged, true)), nil,
            On("bars.targetHighlight")),
        UI.Check(c, L["Mark who has threat (aggro)"], PB("bars.aggro")),
        Cond(UI.Attach(UI.Swatch(c, L["Color"], Col("bars.aggroColor"), ns.ProfileChanged, true)), nil, On("bars.aggro")),
    }))
    UI.FitContent(c, { a, b })
end

-------------------------------------------------------------------------------
-- Texts
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
    local nameList = TextSection(c, "name", L["Name"], {
        UI.Check(c, L["With surname"], PB("texts.name.surname", function() ns.UpdateAllButtons() end)),
        UI.Slider(c, L["Max width (% of the frame)"], 30, 100, 1, function(v) return v .. "%" end, PB("texts.name.width")),
    })
    for _, w in ipairs(TextSection(c, "status", L["Status text"])) do nameList[#nameList + 1] = w end
    local a = UI.Stack(c, COL1, -6, nameList)

    -- warnings shown in the status text, each one with its color
    local S = function() return ns.EP().texts.status end
    local function statusOn() return S().show end
    local alerts = {
        UI.Header(c, L["What the status text shows"]),
        Cond(UI.Note(c, L["Always: \"Offline\", \"Dead\" and \"Ghost\". Plus the ones you enable (if there are several, the first one shows):"], UI.W), nil, statusOn),
    }
    for _, st in ipairs({
        { "showRes", "resColor", L["\"Resurrecting\""], L["Someone is casting a resurrection on them."] },
        { "showCharm", "charmColor", L["\"Charmed\""], L["Mind controlled: they can attack you."] },
        { "showSummon", "summonColor", L["\"Summon\""], L["They have a pending, accepted or declined summon."] },
        { "showAFK", "afkColor", L["\"AFK\""], L["They are away (AFK)."] },
    }) do
        local function on() return statusOn() and S()[st[1]] end
        alerts[#alerts + 1] = Cond(UI.Check(c, st[3], PB("texts.status." .. st[1])), nil, statusOn)
        alerts[#alerts + 1] = Cond(UI.Attach(UI.Note(c, st[4], UI.W - 20)), nil, statusOn)
        alerts[#alerts + 1] = Cond(UI.Attach(UI.Swatch(c, L["Color"], function() return S()[st[2]] end, PAfter, true)), nil, on)
    end
    alerts[#alerts + 1] = UI.Note(c, L["They use the font, size and position of the status text. Drinking and eating is an indicator (Indicators tab)."], UI.W)
    for _, w in ipairs(TextSection(c, "health", L["Health text"], {
        UI.Dropdown(c, L["Format"], {
            { "none", L["No text"] },
            { "deficit", L["Missing health (-1.2k)"] },
            { "percent", L["Percentage (85%)"] },
            { "current", L["Current health (3.4k)"] },
            { "both", L["Current / max"] },
        }, PB("texts.health.format")),
        UI.Check(c, L["Hide at full health"], PB("texts.health.hideFull")),
    })) do alerts[#alerts + 1] = w end
    local b = UI.Stack(c, COL2, -6, alerts)
    UI.FitContent(c, { a, b })
end

-------------------------------------------------------------------------------
-- Status icons
-------------------------------------------------------------------------------
local function ElementSection(c, key, title)
    local function root() return ns.EP().elements[key] end
    local function on() return root().show end
    local list = {
        UI.Header(c, title),
        UI.Check(c, L["Show"], PB("elements." .. key .. ".show")),
    }
    -- the ready check icon only exists during the check: it has no "when"
    if key ~= "ready" then
        list[#list + 1] = Cond(UI.Attach(UI.Dropdown(c, L["When"], {
            { "always", L["Always"] },
            { "ready", L["Only during ready checks"] },
            { "ooc", L["Only out of combat"] },
        }, PB("elements." .. key .. ".when"))), nil, on)
    end
    return Flat({
        list,
        Cond(UI.Check(c, L["Above the indicators"], PB("elements." .. key .. ".onTop")), nil, on),
        Cond(UI.Slider(c, L["Size"], 6, 40, 1, nil, PB("elements." .. key .. ".size")), nil, on),
        PositionBlock(c, root, PAfter, { enableIf = on }),
    })
end

local function BuildElements(p)
    local _, c = UI.ScrollPage(p)
    local l1 = ElementSection(c, "role", L["Role icon"])
    for _, w in ipairs(ElementSection(c, "raidIcon", L["Raid marker (skull, etc.)"])) do l1[#l1 + 1] = w end
    local l2 = ElementSection(c, "leader", L["Leader / assistant"])
    for _, w in ipairs(ElementSection(c, "ready", L["Ready check"])) do l2[#l2 + 1] = w end
    local a = UI.Stack(c, COL1, -6, l1)
    local b = UI.Stack(c, COL2, -6, l2)
    UI.FitContent(c, { a, b })
end

-------------------------------------------------------------------------------
-- Indicators
-------------------------------------------------------------------------------
local selInd = 1
local KIND_LABEL = { aura = "", raiddebuff = "boss", debuffs = "debuffs" }
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
    return ind.type
end

local function IndChanged()
    ns.ProfileChanged()
    UI.RefreshAll()
end

local function IB(path) return UI.Bind(Sel, path, IndChanged) end

local function BuildIndicators(p)
    -- list on the left
    local left = CreateFrame("Frame", nil, p)
    left:SetPoint("TOPLEFT", 6, -4)
    left:SetPoint("BOTTOMLEFT", 6, 4)
    left:SetWidth(196)
    -- the list reaches the bottom: as many rows fit as the space left by the
    -- buttons and the note below
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
                tag = tag ~= "" and L[tag] or ""
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
    Btn(L["New"], 0, y, 62, function()
        local ind = ns.FixIndicator({ name = L["New indicator"] })
        local list = Inds()
        -- before the generic ones so it sits next to the others
        table.insert(list, ind)
        selInd = #list
        IndChanged()
    end)
    local delInd = Btn(L["Delete"], 66, y, 62, function()
        local ind = Sel()
        if not ind then return end
        if ind.kind ~= "aura" then
            ns.Print(L["built-in indicators cannot be deleted; turn them off with the 'Enabled' box."])
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

    Btn(L["Add from the catalog..."], 0, y - 28, 196, function()
        if ns.OpenCatalog then ns.OpenCatalog() end
    end)
    local hint = UI.Note(left, L["The list order is the drawing order: the ones below are drawn on top."], 196)
    hint:SetPoint("TOPLEFT", 0, y - 56)

    -- editor on the right
    local right = CreateFrame("Frame", nil, p)
    right:SetPoint("TOPLEFT", 212, -4)
    right:SetPoint("BOTTOMRIGHT", -4, 4)
    local _, c = UI.ScrollPage(right)
    c:SetWidth(370)
    local function K() local s = Sel() return s and s.kind end
    local function T() local s = Sel() return s and EffType(s) end
    local function isAura() return K() == "aura" end
    -- frame border / tint over health: they cover the whole frame (no position or size)
    local function frameT() local t = T() return t == "border" or t == "overlay" end
    local function notDispel() return not frameT() end
    local function iconLike() local t = T() return t == "icon" or t == "icons" end
    local function rect() local t = T() return t == "square" or t == "bar" end
    local function iconsT() return T() == "icons" end
    local function colored() local t = T() return isAura() and (t == "square" or t == "bar" or t == "text") end
    local function isMissing() local s = Sel() return isAura() and s.mode == "missing" end
    -- has a duration (it is not "missing" nor dispellable)
    -- bar that measures shields or incoming heals: does not watch auras nor has time
    local function unitBar() return isAura() and ns.IndicatorUnitMeasure(Sel()) end
    local function watchAuras() return isAura() and not unitBar() end
    -- watches the spells in its list (not "the ones I can dispel")
    local function dispWatch() return watchAuras() and (Sel().watch == "dispellable" or Sel().watch == "debuffTypes") end
    local function listWatch() return watchAuras() and not dispWatch() end
    local function timed()
        if T() == "bar" and (Sel().barMeasure or "time") ~= "time" then return false end
        if frameT() then return false end
        return notDispel() and not isMissing()
    end
    local function hasText() return timed() end
    -- border or tint that shows debuffs (the ones with a type)
    local function typeIconT() return frameT() and ns.IndicatorTyped(Sel()) end
    local function typeIconOn() return Sel().typeIcon end

    local function W(widget, cond) widget.showIf = cond return widget end
    -- WE: shown based on the type and disabled (without moving) based on a sub-option
    local function WE(widget, show, enable) widget.showIf = show widget.enableIf = enable return widget end

    -- name
    local nameW = CreateFrame("Frame", nil, c)
    nameW:SetSize(UI.W, 36)
    local nl = UI.Label(nameW, L["Name"])
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

    -- custom text of the "Text" type
    local customW = CreateFrame("Frame", nil, c)
    customW:SetSize(UI.W, 36)
    local cl = UI.Label(customW, L["Text"])
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

    -- buff list of the indicator
    -- Each spell can expand its IDs ("Show IDs"). With none checked they all
    -- count; if some are checked, only those.
    local MAXS = 12
    local expanded = {}   -- [indicator] = { [key] = true }

    local function IsOpen(s, key) return expanded[s] and expanded[s][key] end

    local function SpellList(field, addLabel)
        local wdg = CreateFrame("Frame", nil, c)
        wdg:SetSize(360, 40)
        local rows, subPool = {}, {}

        -- checkbox for one ID (indented row)
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
            -- spell tooltip only over its icon
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
            -- spell tooltip only over the icon
            UI.IconTip(r, r.icon, function() return r.tipID end)
            r.name = UI.Label(r, "")
            r.name:SetPoint("LEFT", 20, 0)
            r.name:SetWidth(108)
            r.name:SetWordWrap(false)
            r.ids = UI.Button(r, L["Show IDs"], 76, 16, function()
                local s = Sel()
                local key = s[field][i]
                if key == nil then return end
                expanded[s] = expanded[s] or {}
                expanded[s][key] = (not expanded[s][key]) or nil
                UI.RefreshAll()
            end)
            r.ids:SetPoint("LEFT", 132, 0)
            r.del = UI.Confirm(UI.Button(r, "x", 16, 16, function()
                local s = Sel()
                local key = table.remove(s[field], i)
                if key ~= nil then s.ranks[key] = nil end
                IndChanged()
            end), "?")
            r.del:SetPoint("LEFT", 290, 0)
            rows[i] = r
        end

        local addBox = UI.EditBox(wdg, 200)
        local addBtn = UI.Button(wdg, addLabel or L["Add spell"], 110, 20, function()
            local key = ns.ParseSpellInput(addBox:GetText())
            if not key then return end
            local l = Sel()[field]
            if #l >= MAXS then ns.Print((L["at most %d spells in the list."]):format(MAXS)) return end
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
                    -- the name warns when there are IDs chosen by hand
                    local n = 0
                    if pick then for _ in pairs(pick) do n = n + 1 end end
                    r.name:SetText(n > 0 and ("%s |cff4fc3f7(%d)|r"):format(name, n) or name)
                    local open = IsOpen(s, key)
                    r.ids.text:SetText(open and L["Hide IDs"] or L["Show IDs"])
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
                            sr.id:SetText(L["looking up IDs..."])
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
                            sr.sub:SetText(n > 0 and L["Only the checked ones count."] or L["None checked: all of them count."])
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
    local spellsW = SpellList("spells")

    -- square size (icon)
    local sizeW = UI.Slider(c, L["Size"], 4, 50, 1, nil,
        function() local s = Sel() return s and s.width end,
        function(v) local s = Sel() s.width, s.height = v, v IndChanged() end)

    ---------------------------------------------------------------------------
    -- Frame preview: it is a real frame (the same code as test mode) with every
    -- indicator of the profile at once and all their options. The chosen
    -- indicator can be dragged: when dropped, the closest anchor point (of the 9)
    -- and the exact X/Y offset are picked.
    ---------------------------------------------------------------------------
    local SAMPLE_W, SAMPLE_H = 340, 110
    local posSample = CreateFrame("Frame", nil, c)
    posSample:SetSize(SAMPLE_W, SAMPLE_H + 22)
    local psBg = posSample:CreateTexture(nil, "BACKGROUND")
    psBg:SetPoint("TOPLEFT")
    psBg:SetPoint("TOPRIGHT")
    psBg:SetHeight(SAMPLE_H)
    psBg:SetColorTexture(0.03, 0.03, 0.04, 1)
    local psHint = UI.Label(posSample, L["Drag the indicator to place it wherever you want."])
    psHint:SetPoint("BOTTOMLEFT", 0, 2)
    psHint:SetWidth(SAMPLE_W)
    psHint:SetTextColor(0.65, 0.65, 0.65)

    local pb = CreateFrame("Frame", nil, posSample)
    ns.BuildVisuals(pb)

    -- invisible handle over the chosen indicator (to drag it)
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
        -- third of the frame where the center lands -> anchor point
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
        -- the preview frame always shows the profile being edited
        local LY = ns.EP().layout
        local W, H = LY.width, LY.height
        local z = math.min(3, (SAMPLE_W - 60) / W, (SAMPLE_H - 20) / H)
        pb:SetScale(z)
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
        if w then
            handle:SetAllPoints(w)
            handle:Show()
            psHint:SetText(L["Drag the indicator to place it wherever you want."])
        else
            handle:Hide()
            psHint:SetText("")
        end
    end
    table.insert(UI.widgets, posSample)

    -- colors per type (shared by every indicator of the profile)
    local function DispelSwatches()
        local function typed() return ns.IndicatorTyped(Sel()) and (frameT() or iconLike()) end
        local function on() return Sel().dispelColor end
        local list = {}
        for _, d in ipairs({
            { "Magic", L["Magic"] }, { "Curse", L["Curse"] }, { "Disease", L["Disease"] }, { "Poison", L["Poison"] },
            { "none", L["No type (border and tint)"] },
        }) do
            list[#list + 1] = WE(UI.Attach(UI.Swatch(c, ns.DispelLabel(d[1], d[2]), function() return ns.EP().dispelColors[d[1]] end,
                IndChanged)), function() return typed() and (d[1] ~= "none" or frameT()) end, on)
        end
        list[#list + 1] = WE(UI.Attach(UI.Note(c, L["They are the same for every indicator in the profile. \"No type\" is for debuffs that have no type."], 340)),
            typed, on)
        return list
    end

    local st = UI.Stack(c, 4, -4, Flat({
        UI.Header(c, L["Indicator"]),
        nameW,
        UI.Check(c, L["Enabled"], IB("enabled")),
        W(UI.Dropdown(c, L["Type"], {
            { "square", L["Color square"] }, { "icon", L["Icon"] }, { "icons", L["Several icons"] },
            { "bar", L["Bar"] }, { "text", L["Text"] },
            { "border", L["Frame border"] }, { "overlay", L["Tint over health"] },
        }, IB("type")), isAura),
        W(UI.Attach(UI.Dropdown(c, L["What it measures"], {
            { "time", L["Aura time left"] },
            { "stacks", L["Aura stacks"] },
            { "absorb", L["Player shields (absorb)"] },
            { "heal", L["Player incoming heals"] },
        }, IB("barMeasure"))), function() return isAura() and T() == "bar" end),
        W(UI.Attach(UI.Slider(c, L["Max stacks"], 1, 20, 1, nil, IB("barMaxStacks"))),
            function() return isAura() and T() == "bar" and Sel().barMeasure == "stacks" end),
        W(UI.Attach(UI.Note(c, L["Compared with their max health. It does not watch auras: it shows whenever there is something."], 340)),
            unitBar),
        W(UI.Attach(UI.Dropdown(c, L["What it shows"], {
            { "time", L["Time left"] },
            { "custom", L["Custom text"] },
            { "name", L["Spell name"] },
            { "stacks", L["Stacks"] },
            { "caster", L["Who cast it"] },
        }, IB("textShow"))), function() return isAura() and T() == "text" end),
        W(UI.Attach(customW), function() return isAura() and T() == "text" and Sel().textShow == "custom" end),

        W(UI.Header(c, L["What it watches"]), watchAuras),
        W(UI.Dropdown(c, L["Watches"], {
            { "spells", L["The buffs in its list"] },
            { "dispellable", L["Debuffs I can dispel"] },
            { "debuffTypes", L["Debuffs by type (any class)"] },
        }, IB("watch")), watchAuras),
        W(UI.Attach(UI.Note(c, L["The game decides which ones you can dispel (based on your class and talents)."], 340)), function() return dispWatch() and Sel().watch == "dispellable" end),
        W(UI.Attach(UI.Note(c, L["Shows the checked types even if your class cannot dispel them."], 340)), function() return dispWatch() and Sel().watch == "debuffTypes" end),
        W(UI.Attach(UI.Check(c, ns.DispelLabel("Magic", L["Magic"]), IB("dispelTypes.Magic"))), dispWatch),
        W(UI.Attach(UI.Check(c, ns.DispelLabel("Curse", L["Curse"]), IB("dispelTypes.Curse"))), dispWatch),
        W(UI.Attach(UI.Check(c, ns.DispelLabel("Disease", L["Disease"]), IB("dispelTypes.Disease"))), dispWatch),
        W(UI.Attach(UI.Check(c, ns.DispelLabel("Poison", L["Poison"]), IB("dispelTypes.Poison"))), dispWatch),
        W(UI.Dropdown(c, L["From whom"], { { "mine", L["Only mine"] }, { "others", L["Only others'"] }, { "any", L["From anyone"] } },
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
        W(UI.Dropdown(c, L["Show when"], { { "present", L["Has it"] }, { "missing", L["Missing"] } }, IB("mode")), listWatch),
        W(UI.Attach(UI.Note(c, L["\"Missing\" only works out of combat: in combat the game does not let addons check which buffs a player has."], 340)), isMissing),
        W(UI.Check(c, L["Only out of combat"], IB("onlyOOC")), watchAuras),
        W(UI.Note(c, L["Buffs (by ID or name; any rank works). No spells = all buffs. The game decides the order."], 340), listWatch),
        W(spellsW, listWatch),

        W(UI.Header(c, L["What it watches"]), function() return K() == "raiddebuff" end),
        W(UI.Note(c, L["Shows the most important boss debuff on the player. The game decides which ones are boss debuffs."], 340),
            function() return K() == "raiddebuff" end),

        W(UI.Header(c, L["What it watches"]), function() return K() == "debuffs" end),
        W(UI.Check(c, L["Only the ones I can dispel"], IB("onlyDispellable")),
            function() return K() == "debuffs" end),

        UI.Header(c, L["Position and size"]),
        posSample,
        PositionBlock(c, Sel, IndChanged, { showIf = function()
            return notDispel() and not (T() == "bar" and ns.STRIP_SIDE[Sel().span])
        end }),
        W(sizeW, iconLike),
        W(UI.Slider(c, L["Width"], 1, 120, 1, nil, IB("width")), rect),
        W(UI.Attach(UI.Slider(c, L["Height"], 1, 60, 1, nil, IB("height"))), rect),
        W(UI.Dropdown(c, L["Span"], {
            { "none", L["No (its own width and height)"] },
            { "width", L["Full width, over the frame"] },
            { "height", L["Full height, over the frame"] },
            { "stripTop", L["Own strip on top"] },
            { "stripBottom", L["Own strip at the bottom"] },
            { "stripLeft", L["Own strip on the left"] },
            { "stripRight", L["Own strip on the right"] },
        }, IB("span")), function() return T() == "bar" end),
        W(UI.Attach(UI.Note(c, L["With its own strip, the health bar shrinks to make room (like the mana bar). Top and bottom use the height; left and right, the width."], 340)),
            function() return T() == "bar" and ns.STRIP_SIDE[Sel().span] ~= nil end),
        W(UI.Dropdown(c, L["Bar orientation"], { { "HORIZONTAL", "Horizontal" }, { "VERTICAL", "Vertical" } },
            IB("barOrient")), function() return T() == "bar" end),
        W(UI.Attach(UI.Check(c, L["Drain in reverse"], IB("barReverse"))), function() return T() == "bar" end),

        W(UI.Slider(c, L["Max icons"], 1, 8, 1, nil, IB("max")), iconsT),
        W(UI.Dropdown(c, L["Grow towards"], { { "LEFT", L["Left"] }, { "RIGHT", L["Right"] }, { "UP", L["Top"] }, { "DOWN", L["Bottom"] } },
            IB("grow")), iconsT),
        W(UI.Slider(c, L["Spacing between icons"], 0, 10, 1, nil, IB("spacing")), iconsT),

        W(UI.Header(c, L["Frame border"]), function() return T() == "border" end),
        W(UI.Slider(c, L["Thickness"], 1, 6, 1, nil, IB("width")), function() return T() == "border" end),
        W(UI.Check(c, L["Inside the frame"], IB("borderInside")), function() return T() == "border" end),
        W(UI.Header(c, L["Tint over health"]), function() return T() == "overlay" end),
        W(UI.Dropdown(c, L["Shape"], {
            { "up", L["Gradient from bottom to top"] },
            { "down", L["Gradient from top to bottom"] },
            { "solid", L["Solid"] },
        }, IB("tintShape")), function() return T() == "overlay" end),
        W(UI.Slider(c, L["Intensity"], 0.1, 1, 0.05, UI.pct, IB("overlayAlpha")), function() return T() == "overlay" end),

        -- debuff border / tint: native type icon on top
        W(UI.Header(c, L["Type icon"]), typeIconT),
        W(UI.Check(c, ns.DispelLabel("Poison", L["Show the type icon"]), IB("typeIcon")), typeIconT),
        WE(UI.Slider(c, L["Size"], 8, 32, 1, nil, IB("typeIconSize")), typeIconT, typeIconOn),
        PositionBlock(c, function() return Sel().typeIconPos end, IndChanged, { showIf = typeIconT, enableIf = typeIconOn }),

        UI.Header(c, L["Look"]),
        W(UI.Check(c, L["Color by type (magic, poison...)"], IB("dispelColor")), function()
            return ns.IndicatorTyped(Sel()) and (frameT() or iconLike())
        end),
        DispelSwatches(),
        WE(UI.Attach(UI.Swatch(c, L["Color"], function() return Sel().color end, IndChanged, true)),
            function() return colored() or frameT() end,
            function() return colored() or not Sel().dispelColor end),
        W(UI.Check(c, L["Black border"], IB("showBorder")),
            function() local t = T() return notDispel() and t ~= "text" end),
        W(UI.Check(c, L["Time sweep"], IB("swipe")),
            function() local t = T() return timed() and (t == "icon" or t == "icons" or t == "square") end),
        WE(UI.Attach(UI.Dropdown(c, L["Sweep style"], {
            { "clock", L["Clock"] },
            { "clockReverse", L["Reverse clock (fills up)"] },
            { "clockEdge", L["Clock with edge"] },
            { "drainV", L["Vertical fill (bottom to top)"] },
            { "drainH", L["Horizontal fill (left to right)"] },
            { "bar", L["Thin bar at the bottom (grows)"] },
        }, function() return Sel().swipeStyle or "clock" end, function(v) Sel().swipeStyle = v IndChanged() end)),
            function() local t = T() return timed() and (t == "icon" or t == "icons" or t == "square") end,
            function() return Sel().swipe ~= false end),

        -- in the "Text" type, this is the text itself: it goes where the indicator is, with its color
        W(UI.Header(c, L["Time text"]), function() return hasText() and T() ~= "text" end),
        W(UI.Header(c, L["Text"]), function() return isAura() and T() == "text" end),
        TextBlock(c, function() return Sel().timerText end, IndChanged, {
            show = { IB("timer") },
            showCheckIf = function() return T() ~= "text" end,
            showIf = function() return hasText() or (isAura() and T() == "text") end,
            enableIf = function() return T() == "text" or Sel().timer end,
            colorIf = function() return T() ~= "text" end,
            positionIf = function() return T() ~= "text" end,
        }),
        W(UI.Header(c, L["Stacks text"]), hasText),
        TextBlock(c, function() return Sel().stacksText end, IndChanged, {
            show = { IB("stacks") },
            showIf = hasText,
            enableIf = function() return Sel().stacks end,
            positionIf = function() return T() ~= "text" end,
        }),
    }))

    p.OnShow = function() end
    UI.OnRefreshIndicators = function()
        RefreshList()
        st:Layout()
        UI.FitContent(c, { st }, 40)
    end
end

-------------------------------------------------------------------------------
-- Catalog: group -> classes and spells -> add as indicator
-------------------------------------------------------------------------------
local catGroup = "hots"
local catSel, catOrigin, catMode = {}, {}, {}

-- checkbox with icon and text (for classes and spells)
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
    -- state: true, false or "partial"
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
    local W = 550   -- width of the wide blocks inside each card
    local myClass = select(2, UnitClass("player"))
    local Rebuild, st

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

    -- A plain block for the stack: its children are placed by Rebuild
    local function Block(h)
        local f = CreateFrame("Frame", nil, c)
        f:SetSize(W, h or 20)
        return f
    end

    -- 1. group
    local groupGrid = Block()
    local groupBtns = {}
    for i, g in ipairs(ns.Catalog) do
        local b = UI.Button(groupGrid, L[g.name], 178, 22, function()
            catGroup = g.key
            Rebuild()
        end)
        b.key = g.key
        groupBtns[i] = b
    end
    local desc = UI.Note(c, "", W)

    -- 2. classes and spells
    local selRow = Block(20)
    local recBtn = UI.Button(selRow, L["Recommended for my class"], 180, 20, function()
        local g = Group()
        wipe(Sel(g))
        for _, e in ipairs(ns.CatalogRecommended(g, myClass)) do Sel(g)[e] = true end
        Rebuild()
    end)
    recBtn:SetPoint("TOPLEFT")
    local allBtn = UI.Button(selRow, L["Check all"], 100, 20, function()
        for _, e in ipairs(Group().spells) do Sel()[e] = true end
        Rebuild()
    end)
    allBtn:SetPoint("LEFT", recBtn, "RIGHT", 6, 0)
    local noneBtn = UI.Button(selRow, L["Uncheck all"], 100, 20, function()
        wipe(Sel())
        Rebuild()
    end)
    noneBtn:SetPoint("LEFT", allBtn, "RIGHT", 6, 0)
    local spells = Block()
    local classPool, itemPool = {}, {}

    -- 3. add
    local originDD = UI.Dropdown(c, L["From whom"], {
        { "mine", L["Mine only"] }, { "others", L["Others' only"] }, { "any", L["From anyone"] },
    }, function() return catOrigin[catGroup] or Group().origin end, function(v) catOrigin[catGroup] = v end)
    local modeDD = UI.Dropdown(c, L["Show when"], {
        { "present", L["Has it"] }, { "missing", L["Missing (one warning per buff)"] },
    }, function() return catMode[catGroup] or Group().mode or "present" end, function(v) catMode[catGroup] = v end)
    modeDD.showIf = function() return Group().auraType == "HELPFUL" end
    local result = UI.Note(c, "", W)
    local goBtn = UI.Button(c, L["See in Indicators"], 140, 22, function()
        if ns.OpenIndicators then ns.OpenIndicators() end
    end)
    goBtn.showIf = function() return goBtn.wanted end
    local addBtn = UI.Button(c, L["Add as indicator"], 220, 26, function()
        local g = Group()
        local entries = {}
        for _, e in ipairs(g.spells) do
            if Sel(g)[e] then table.insert(entries, e) end
        end
        if #entries == 0 then
            result.text:SetText(L["|cffff7755Check at least one spell in step 2.|r"])
            goBtn.wanted = false
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
            table.insert(names, (L["\"%s\""]):format(ind.name))
        end
        selInd = #list - #new + 1
        ns.ProfileChanged()
        result.text:SetText((L["|cff55ff55Added:|r %s to profile %s. Move and adjust it in Indicators."]):format(
            table.concat(names, ", "), ns.EditedProfileName()))
        goBtn.wanted = true
        UI.RefreshAll()
    end)
    result.showIf = function() return (result.text:GetText() or "") ~= "" end

    -- Same cards as every other page: one per step
    st = UI.Stack(c, COL1, -6, {
        UI.Header(c, L["1. Group"]),
        groupGrid,
        desc,
        UI.Header(c, L["2. Classes and spells"]),
        selRow,
        spells,
        UI.Header(c, L["3. Add as indicator"]),
        originDD,
        modeDD,
        addBtn,
        result,
        goBtn,
    })

    local function Place(f, parent, x, y)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        f:Show()
    end

    Rebuild = function()
        local g = Group()
        local sel = Sel(g)

        -- group buttons, three per row
        for i, b in ipairs(groupBtns) do
            local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
            Place(b, groupGrid, col * 186, -row * 26)
            local on = b.key == catGroup
            b:SetBackdropColor(on and 0.12 or 0.15, on and 0.3 or 0.15, on and 0.42 or 0.18, 1)
        end
        groupGrid:SetHeight(math.ceil(#groupBtns / 3) * 26 - 4)
        desc.text:SetText(L[g.desc] .. "  |cff888888(" .. (g.auraType == "HARMFUL" and L["debuffs"] or L["buffs"]) .. ")|r")
        desc:SetHeight(desc.text:GetStringHeight() + 2)

        -- classes that bring something to this group, each with its spells
        for _, f in ipairs(classPool) do f:Hide() end
        for _, f in ipairs(itemPool) do f:Hide() end
        local ci, ii, y = 0, 0, 0
        for _, class in ipairs(ns.CLASS_ORDER) do
            local entries = {}
            for _, e in ipairs(g.spells) do if e.class == class then table.insert(entries, e) end end
            if #entries > 0 then
                ci = ci + 1
                local ct = classPool[ci]
                if not ct then ct = Toggle(spells, W) classPool[ci] = ct end
                local n = 0
                for _, e in ipairs(entries) do if sel[e] then n = n + 1 end end
                local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                local cname = ns.CLASS_NAMES[class] and L[ns.CLASS_NAMES[class]] or class
                if col then cname = ("|cff%02x%02x%02x%s|r"):format(col.r * 255, col.g * 255, col.b * 255, cname) end
                ct:SetContent(cname .. ((class == myClass) and ("  |cff888888(" .. L["your class"] .. ")|r") or ""))
                ct:SetState(n == #entries or (n > 0 and "partial"))
                ct:SetScript("OnClick", function()
                    local all = n == #entries
                    for _, e in ipairs(entries) do sel[e] = (not all) or nil end
                    Rebuild()
                end)
                Place(ct, spells, 0, y)
                y = y - 22
                for k, e in ipairs(entries) do
                    ii = ii + 1
                    local it = itemPool[ii]
                    if not it then it = Toggle(spells, 262) it:SetHeight(30) itemPool[ii] = it end
                    local name, icon = ns.SpellKeyInfo(ns.CatalogKey(e))
                    it:SetContent(name, icon or 134400, e.note and L[e.note])
                    it:SetState(sel[e])
                    it:SetScript("OnClick", function()
                        sel[e] = (not sel[e]) or nil
                        Rebuild()
                    end)
                    it.tipID = ns.KeyIDs(ns.CatalogKey(e))[1]
                    local colI, row = (k - 1) % 2, math.floor((k - 1) / 2)
                    Place(it, spells, 20 + colI * 268, y - row * 32)
                end
                y = y - math.ceil(#entries / 2) * 32 - 6
            end
        end
        spells:SetHeight(math.max(1, -y - 6))

        originDD.Refresh()
        modeDD.Refresh()
        result:SetHeight(math.max(14, result.text:GetStringHeight() + 2))
        st:Layout()
        UI.FitContent(c, { st })
    end

    p.OnShow = function() Rebuild() end
end

-------------------------------------------------------------------------------
-- Instances: a guide of each instance's bosses and debuffs (read only)
-- Left, the instances by category. Right, the debuffs grouped by boss, with
-- the game's crowd control flag.
-------------------------------------------------------------------------------
local LIST_ROWS, INST_ROWS = 17, 25
local PLUS_TEX = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS_TEX = "Interface\\Buttons\\UI-MinusButton-Up"

local function BuildInstances(p)
    local selKey, picked
    local listOffset, instOffset = 0, 0
    local query = ""
    local collapsed = {}   -- [instance .. "\n" .. boss] = true (this session only)
    -- collapsed at first: every category except raids (and the one you are in)
    local catClosed = { dungeon = true, solo = true, world = true, zone = true, unannounced = true }
    local Refresh

    local function IsHere(key)
        for _, k in ipairs(ns.CurrentInstanceKeys()) do
            if k == key then return true end
        end
        return false
    end

    local function Matches(name, id)
        if query == "" then return true end
        local q = query:lower()
        if name and tostring(name):lower():find(q, 1, true) then return true end
        return id ~= nil and tostring(id):find(q, 1, true) ~= nil
    end

    -- Rows: { cat, label, n, closed } (category title) or { key }
    local function InstanceRows()
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
                local closed = catClosed[cat] or false
                out[#out + 1] = { cat = cat, label = L[ns.INSTANCE_KIND_NAMES[cat]], n = #list, closed = closed }
                if not closed then
                    for _, k in ipairs(list) do out[#out + 1] = { key = k } end
                end
            end
        end
        return out
    end

    -- Rows: { header = boss, n, ck, closed } or { key, name, id }
    local function ListRows()
        local rows = {}
        local def = selKey and ns.Instances[selKey]
        for _, b in ipairs(def and def.bosses or {}) do
            local items = {}
            for _, key in ipairs(b[2]) do
                local name, _, id = ns.SpellKeyInfo(key)
                if Matches(name, id) then items[#items + 1] = { key = key, name = name, id = id } end
            end
            if #items > 0 or query == "" then
                local ck = tostring(selKey) .. "\n" .. b[1]
                local closed = collapsed[ck] and query == "" or false
                rows[#rows + 1] = { header = b[1], n = #items, ck = ck, closed = closed }
                if not closed then
                    for _, e in ipairs(items) do rows[#rows + 1] = e end
                end
            end
        end
        return rows
    end

    local function Wheel(frame, fn)
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function(_, d) fn(d) Refresh() end)
    end

    ---------------------------------------------------------------------------
    -- Left: instances
    ---------------------------------------------------------------------------
    local left = CreateFrame("Frame", nil, p, "BackdropTemplate")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(176)
    UI.Backdrop(left, { 0.095, 0.095, 0.118, 1 }, { 0.19, 0.19, 0.235, 1 })
    local lt = UI.Label(left, L["Instances"], "GameFontNormal")
    lt:SetPoint("TOPLEFT", 10, -8)
    lt:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

    local instArea = CreateFrame("Frame", nil, left)
    instArea:SetPoint("TOPLEFT", 4, -28)
    instArea:SetSize(168, INST_ROWS * 20)
    Wheel(instArea, function(d) instOffset = math.max(0, instOffset - d) end)
    local instBar = UI.ScrollBar(instArea, function(v) instOffset = v Refresh() end)
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
        -- green dot: you are here
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetSize(6, 6)
        r.dot:SetPoint("LEFT", 4, 0)
        r.dot:SetColorTexture(0.3, 0.9, 0.4, 1)
        -- +/- of the categories
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
                -- collapse / expand the category
                catClosed[self.cat] = not self.closed
            elseif self.key ~= nil then
                selKey, picked = self.key, true
                listOffset = 0
            end
            Refresh()
        end)
        r:SetScript("OnEnter", function(self)
            if self.key == nil or not IsHere(self.key) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["You are here"])
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        instRows[i] = r
    end

    ---------------------------------------------------------------------------
    -- Right: title, search and the list
    ---------------------------------------------------------------------------
    local right = CreateFrame("Frame", nil, p)
    right:SetPoint("TOPLEFT", 186, 0)
    right:SetPoint("BOTTOMRIGHT")

    local title = UI.Label(right, "", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 2, -4)
    title:SetWidth(400)
    title:SetWordWrap(false)

    local search = UI.EditBox(right, 230)
    search:SetPoint("TOPLEFT", 0, -30)
    local ph = UI.Label(search, L["Search by name or ID"])
    ph:SetPoint("LEFT", 6, 0)
    ph:SetTextColor(0.45, 0.45, 0.45)
    search:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        ph:SetShown(txt == "")
        query = txt:trim()
        listOffset = 0
        Refresh()
    end)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    local clearQ = UI.Button(right, "x", 20, 20, function()
        search:SetText("")
        search:ClearFocus()
    end)
    clearQ:SetPoint("LEFT", search, "RIGHT", 4, 0)

    local function ColLabel(text, x)
        local l = UI.Label(right, text)
        l:SetPoint("TOPLEFT", x, -58)
        l:SetTextColor(0.6, 0.6, 0.6)
        return l
    end
    ColLabel(L["Debuff"], 38)
    ColLabel(L["ID"], 252)
    ColLabel(L["Type"], 318)
    local scrollInfo = UI.Label(right, "")
    scrollInfo:SetPoint("TOPRIGHT", -14, -58)
    scrollInfo:SetTextColor(0.6, 0.6, 0.6)

    local emptyText = UI.Label(right, "")
    emptyText:SetPoint("TOPLEFT", 4, -78)
    emptyText:SetWidth(400)
    emptyText:SetTextColor(0.6, 0.6, 0.6)

    local listArea = CreateFrame("Frame", nil, right)
    listArea:SetPoint("TOPLEFT", 0, -72)
    listArea:SetSize(418, LIST_ROWS * 20)
    Wheel(listArea, function(d) listOffset = math.max(0, listOffset - d) end)
    local listBar = UI.ScrollBar(listArea, function(v) listOffset = v Refresh() end)
    listBar:SetPoint("TOPRIGHT", -2, 0)
    listBar:SetPoint("BOTTOMRIGHT", -2, 0)

    local listRows = {}
    for i = 1, LIST_ROWS do
        local row = CreateFrame("Button", nil, listArea)
        row:SetSize(406, 19)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        -- click on a boss: collapse / expand it
        row:SetScript("OnClick", function(self)
            local d = self.data
            if d and d.header then
                collapsed[d.ck] = (not collapsed[d.ck]) or nil
                Refresh()
            end
        end)

        -- boss row
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

        -- debuff row
        row.e = CreateFrame("Frame", nil, row)
        row.e:SetAllPoints()
        row.icon = row.e:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(17, 17)
        row.icon:SetPoint("LEFT", 16, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        UI.IconTip(row.e, row.icon, function() return row.data and row.data.id end)
        row.name = UI.Label(row.e, "")
        row.name:SetPoint("LEFT", 38, 0)
        row.name:SetWidth(208)
        row.name:SetWordWrap(false)
        row.id = UI.Label(row.e, "")
        row.id:SetPoint("LEFT", 252, 0)
        row.id:SetTextColor(0.6, 0.6, 0.6)
        row.tag = UI.Label(row.e, "")
        row.tag:SetPoint("LEFT", 318, 0)
        listRows[i] = row
    end

    -- how to read the guide
    local noteTitle = UI.Label(right, L["How to read this guide"], "GameFontNormal")
    noteTitle:SetPoint("TOPLEFT", 0, -72 - LIST_ROWS * 20 - 12)
    noteTitle:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    local note = UI.Label(right, table.concat({
        L["The debuffs each boss puts on your group. In combat the game does not tell addons which debuff is which, so your frames show these like any other debuff: you recognise them by their icon."],
        "",
        "|cffff5a4d" .. L["Control"] .. "|r: " .. L["the game flags it as crowd control (stun, fear, sleep, mind control...)."],
        "|cffaaaaaa" .. L["Debuff"] .. "|r: " .. L["any other debuff."],
    }, "\n"))
    note:SetPoint("TOPLEFT", noteTitle, "BOTTOMLEFT", 0, -6)
    note:SetWidth(418)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.75, 0.75, 0.75)

    ---------------------------------------------------------------------------
    -- Refresh
    ---------------------------------------------------------------------------
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
                if d.cat == "unannounced" then
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
                r.name:SetText(ns.Instances[d.key].name)
                local g = ns.InstanceCategory(d.key) == "unannounced" and 0.6 or 1
                r.name:SetTextColor(g, g, g)
                local n = 0
                for _, b in ipairs(ns.Instances[d.key].bosses) do n = n + #b[2] end
                r.count:SetText(n)
                r.sel:SetShown(d.key == selKey)
                r.dot:SetShown(IsHere(d.key))
                r:Show()
            end
        end
    end

    local function RefreshList()
        local rows = ListRows()
        listOffset = math.max(0, math.min(listOffset, #rows - LIST_ROWS))
        listBar:SetRange(#rows - LIST_ROWS, #rows > 0 and LIST_ROWS / #rows or 1)
        listBar:SetPos(listOffset)
        if #rows > LIST_ROWS then
            scrollInfo:SetText((L["%d-%d of %d"]):format(listOffset + 1, math.min(#rows, listOffset + LIST_ROWS), #rows))
        else
            scrollInfo:SetText("")
        end
        for i, row in ipairs(listRows) do
            local d = rows[i + listOffset]
            row.data = d
            if not d then
                row:Hide()
            elseif d.header then
                row.h:Show()
                row.e:Hide()
                row.bg:SetColorTexture(1, 1, 1, 0.06)
                row.exp:SetTexture(d.closed and PLUS_TEX or MINUS_TEX)
                row.exp:SetShown(d.n > 0)
                row.hname:SetText(d.header)
                row.hcount:SetText(d.n > 0 and ("(%d)"):format(d.n) or L["(no known debuffs)"])
                row:Show()
            else
                row.h:Hide()
                row.e:Show()
                row.bg:SetColorTexture(1, 1, 1, 0)
                local _, icon = ns.SpellKeyInfo(d.key)
                row.icon:SetTexture(icon or 134400)
                row.name:SetText(d.name)
                row.id:SetText(d.id or L["looking up..."])
                if ns.IsCrowdControlKey(d.key) then
                    row.tag:SetText(L["Control"])
                    row.tag:SetTextColor(1, 0.35, 0.3)
                else
                    row.tag:SetText(L["Debuff"])
                    row.tag:SetTextColor(0.6, 0.6, 0.6)
                end
                row:Show()
            end
        end
        if #rows == 0 then
            emptyText:SetText(query ~= "" and L["Nothing matches the search."] or L["No known bosses or debuffs yet."])
        else
            emptyText:SetText("")
        end
    end

    Refresh = function()
        RefreshInstances()
        local def = selKey and ns.Instances[selKey]
        local unannounced = def and ns.InstanceCategory(selKey) == "unannounced"
        title:SetText(def and (def.name .. (unannounced and ("  |cff888888(" .. L["not announced"] .. ")|r") or "")) or "")
        clearQ:SetShown(query ~= "")
        RefreshList()
    end

    p.OnShow = function()
        -- until you pick one, follow the place where you are
        if not picked then
            local here = ns.CurrentInstanceKeys()[1]
            if here then
                selKey = here
                catClosed[ns.InstanceCategory(here)] = false
            end
            selKey = selKey or ns.InstanceOrder[1]
        end
        Refresh()
    end
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
local function SelectPage(i)
    UI.CloseMenu()
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
    win:SetScript("OnHide", function() UI.CloseMenu() end)

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

    local names = { L["Profiles"], L["Layout"], L["Bars"], L["Texts"], L["Status icons"], L["Indicators"], L["Catalog"], L["Instances"] }
    local builders = { BuildProfiles, BuildLayout, BuildBars, BuildTexts, BuildElements, BuildIndicators, BuildCatalog, BuildInstances }
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
        win.profileLabel:SetText((L["editing: |cffffffff%s|r · active: |cffffffff%s|r"]):format(
            ns.EditedProfileName(), tostring(ns.activeName)))
        if UI.OnRefreshIndicators then UI.OnRefreshIndicators() end
        local cur = win.current and pages[win.current]
        if cur and cur.OnShow then cur.OnShow() end
    end

    ns.OpenIndicators = function() SelectPage(6) end
    ns.OpenCatalog = function() SelectPage(7) end
    ns.OnLockChanged = function()
        win.lockBtn.text:SetText(ns.db.locked and L["Unlock"] or L["Lock"])
    end
    ns.OnTestChanged = function()
        win.testBtn.text:SetText(ns.testing and L["Hide test"] or L["Test mode"])
    end
    ns.OnProfileChanged = function()
        if win:IsShown() then UI.RefreshAll() end
    end
    ns.OnLockChanged()
    ns.OnTestChanged()
    SelectPage(1)
end

-- Open (without closing it if it is already open)
function ns.OpenOptions()
    if win and win:IsShown() then return end
    ns.ToggleOptions()
end

function ns.ToggleOptions()
    if not win then
        CreateWindow()
        win:Hide() -- CreateFrame leaves it visible: without this the first /mf closed it
    end
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
        UI.RefreshAll()
    end
end
