-- Uses the real Media, Frames and Indicators modules, including FillTest.
local colorTests = 0
local function colorCheck(value, message)
    assert(value, message)
    colorTests = colorTests + 1
end
local function sameColor(got, want)
    return got and got[1] == want.r and got[2] == want.g and got[3] == want.b
end
RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
UnitClass = function(unit) if unit == "unknown" then return "Hidden", { secret = true } end return "Hunter", "HUNTER" end
UnitName = function() return "Test Hunter" end
ns.SpellKeyInfo = function() return "Test spell", 42 end
ns.GetSpellName = function() return "Test spell" end
local function prepare(c)
    ns.P = ns.DeepCopy(ns.profileDefaults)
    ns.P.texts.name.colorMode = "class"
    ns.P.indicators = { c }
    ns.compiled = { { index = 1, cfg = c, kind = c.kind, byID = {}, byName = {}, any = true,
        dispellable = c.watch == "debuffTypes" or c.watch == "dispellable" } }
end
local c = cfg { kind = "aura", type = "icons", spells = { 123 }, max = 1, timer = true }
c.timerText.colorMode, c.stacksText.colorMode = "class", "class"
prepare(c)
local preview = object()
ns.BuildVisuals(preview)
ns.FillPreviewButton(preview, 1)
local icon = preview.ind[1].icons[1]
local hunter = RAID_CLASS_COLORS.HUNTER
colorCheck(preview.testClass == "HUNTER", "The player sample was assigned a different class")
colorCheck(sameColor(preview.health.barColor, hunter), "Preview health does not use the player's class")
colorCheck(sameColor(preview.name.textColor, hunter), "Preview name has inconsistent class color")
colorCheck(sameColor(icon.timerText.textColor, hunter), "Preview timer lost the simulated class")
colorCheck(sameColor(icon.count.textColor, hunter), "Preview stacks lost the simulated class")
-- Each test row uses its own simulated class rather than always using player.
preview.testClass = "WARRIOR"
ns.TestAuras(preview, 1, true)
colorCheck(sameColor(icon.timerText.textColor, RAID_CLASS_COLORS.WARRIOR), "Simulated warrior timer used the player's class")
colorCheck(sameColor(icon.count.textColor, RAID_CLASS_COLORS.WARRIOR), "Simulated warrior stacks used the player's class")
preview.isPet = true
ns.TestAuras(preview, 1, true)
colorCheck(sameColor(icon.count.textColor, { r = 0.25, g = 0.75, b = 0.3 }), "Pet frame and indicator colors differ")
preview.isPet = false
c.timerText.colorMode = "white"
c.stacksText.colorMode, c.stacksText.color = "custom", { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }
ns.FillPreviewButton(preview, 1)
icon = preview.ind[1].icons[1]
colorCheck(sameColor(icon.timerText.textColor, { r = 1, g = 1, b = 1 }), "Switching from class to white retained stale class color")
colorCheck(sameColor(icon.count.textColor, c.stacksText.color) and icon.count.textColor[4] == 0.4, "Custom color or alpha was replaced")
-- Real-unit colors use the same resolver, but never inherit a preview class.
local real = object()
real.wtype, real.timerText, real.count = "icon", object(), object()
c.timerText.colorMode, c.stacksText.colorMode = "class", "class"
ns.ShowAura(real, "player", { name = "Test", icon = 42, applications = 2 }, c)
colorCheck(sameColor(real.timerText.textColor, hunter) and sameColor(real.count.textColor, hunter), "Real-unit class color differs")
colorCheck(ns.ClassColorOf("unknown") == nil, "Secret class token was restored after being sanitized")
colorCheck(ns.ClassColorOf(nil) == nil, "No-unit color query should not invent a class")
-- Poison-only indicators must render a poison sample instead of disappearing.
local poison = cfg { kind = "aura", watch = "debuffTypes", type = "overlay", dispelTypes = { Magic = false, Curse = false, Disease = false, Poison = true } }
prepare(poison)
ns.FillPreviewButton(preview, 1)
local overlay = preview.ind[1]
colorCheck(overlay.shown, "Poison-only indicator was missing from the preview")
colorCheck(overlay.typeIcon.texture == ns.DISPEL_ICONS.Poison, "Preview showed a different dispel type")
-- Also exercise the missing-aura text path with a simulated class context.
local missingCfg = cfg { type = "square", mode = "missing", spells = { 123 } }
missingCfg.stacksText.colorMode = "class"
local missingWidget = object()
missingWidget.wtype, missingWidget.count, missingWidget.previewClass = "square", object(), "WARRIOR"
ns.ShowMissing(missingWidget, missingCfg)
colorCheck(sameColor(missingWidget.count.textColor, RAID_CLASS_COLORS.WARRIOR), "Missing-aura path lost the preview color")
print("PASS: " .. colorTests .. " preview/real color consistency assertions")
