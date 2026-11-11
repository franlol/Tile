-------------------------------------------------------------------------------
-- Tile - Translations
--
-- The keys are the English texts: L["Some text"] returns that text in the
-- active language, or the key itself when there is no translation (English).
-- The language is chosen once the saved settings load (ns.SetLanguage), so L
-- must only be read at run time. Tables built while a file loads keep the
-- English key and translate it where it is shown (L[g.name]).
-------------------------------------------------------------------------------

local _, ns = ...

ns.translations = {}    -- [locale] = { [English text] = translated text }

-- Choices for the language option (English by default)
ns.LANGUAGES = { { "enUS", "English" }, { "esES", "Español" } }

local active

ns.L = setmetatable({}, {
    __index = function(_, key)
        return active and active[key] or key
    end,
})

-- lang: "enUS" or "esES" (anything else = English)
function ns.SetLanguage(lang)
    ns.language = ns.translations[lang] and lang or "enUS"
    active = ns.translations[lang]
end
