-------------------------------------------------------------------------------
-- MendFrames - Debuffs de banda por defecto
-- Clave = ID de mapa de la instancia (GetInstanceInfo, 8º valor). 0 = global.
-- spells = { [spellID] = prioridad }  (mayor prioridad = se muestra antes)
--
-- Los IDs son los de Classic. Se comparan también por nombre, así que si
-- Forever usa otro rango/ID del mismo hechizo también se detecta. Lo que falte
-- se añade desde /mf > Debuffs de banda (el registrador apunta los debuffs
-- que ve en cada instancia para añadirlos con un clic).
-------------------------------------------------------------------------------

local _, ns = ...

ns.RaidDebuffs = {
    [0] = {
        name = "Global (todas las instancias)",
        spells = {},
    },

    [409] = {
        name = "Molten Core",
        spells = {
            [19702] = 3,  -- Impending Doom (Lucifron)
            [19703] = 4,  -- Lucifron's Curse
            [20604] = 8,  -- Dominate Mind (Flamewaker Protector)
            [19408] = 5,  -- Panic (Magmadar)
            [19428] = 3,  -- Conflagration (Magmadar)
            [19716] = 4,  -- Gehennas' Curse
            [19717] = 2,  -- Rain of Fire (Gehennas)
            [20475] = 9,  -- Living Bomb (Baron Geddon)
            [19659] = 4,  -- Ignite Mana (Baron Geddon)
            [19713] = 4,  -- Shazzrah's Curse
            [13880] = 3,  -- Magma Splash (Golemagg)
            [19776] = 3,  -- Shadow Word: Pain (Sulfuron adds)
            [20294] = 3,  -- Immolate (Sulfuron adds)
        },
    },

    [249] = {
        name = "Onyxia's Lair",
        spells = {
            [18431] = 6,  -- Bellowing Roar
            [18392] = 3,  -- Fireball
            [18435] = 2,  -- Flame Breath
        },
    },

    [469] = {
        name = "Blackwing Lair",
        spells = {
            [23023] = 4,  -- Conflagration (Razorgore / magos)
            [18173] = 9,  -- Burning Adrenaline (Vaelastrasz)
            [23340] = 6,  -- Shadow of Ebonroc
            [23341] = 3,  -- Flame Buffet (Firemaw)
            [22687] = 5,  -- Veil of Shadow (Nefarian)
            [22667] = 9,  -- Shadow Command (Nefarian)
            [23401] = 6,  -- Corrupted Healing (llamada de sacerdotes)
            [23310] = 7,  -- Time Lapse (Chromaggus)
            [23170] = 8,  -- Brood Affliction: Bronze
            [23155] = 4,  -- Brood Affliction: Red
            [23153] = 4,  -- Brood Affliction: Blue
            [23154] = 4,  -- Brood Affliction: Black
            [23169] = 4,  -- Brood Affliction: Green
            [24573] = 3,  -- Mortal Strike (Death Talon)
        },
    },

    [309] = {
        name = "Zul'Gurub",
        spells = {
            [23860] = 3,  -- Holy Fire (Venoxis)
            [24099] = 2,  -- Poison Bolt Volley
            [24111] = 3,  -- Corrosive Poison
            [24210] = 6,  -- Mark of Arlokk
            [24314] = 9,  -- Threatening Gaze (Mandokir)
            [24306] = 7,  -- Delusions of Jin'do
            [24324] = 3,  -- Blood Siphon (Hakkar)
            [24327] = 9,  -- Cause Insanity (Hakkar)
            [24328] = 7,  -- Corrupted Blood (Hakkar)
        },
    },

    [509] = {
        name = "Ruins of Ahn'Qiraj",
        spells = {
            [25646] = 4,  -- Mortal Wound (Kurinnaxx)
            [25725] = 8,  -- Paralyze (Ayamiss)
            [25189] = 5,  -- Enveloping Winds (Ossirian)
            [25195] = 3,  -- Curse of Tongues (Ossirian)
        },
    },

    [531] = {
        name = "Temple of Ahn'Qiraj",
        spells = {
            [785]   = 9,  -- True Fulfillment (Skeram)
            [26580] = 5,  -- Fear (Princess Yauj)
            [26050] = 4,  -- Acid Spit (Huhuran)
            [26180] = 6,  -- Wyvern Sting (Huhuran)
            [26053] = 3,  -- Noxious Poison (Huhuran)
            [25989] = 3,  -- Toxin (Viscidus)
            [25937] = 6,  -- Viscidus Freeze
            [26476] = 5,  -- Digestive Acid (C'Thun)
            [26044] = 4,  -- Mind Flay (C'Thun)
        },
    },

    [533] = {
        name = "Naxxramas",
        spells = {
            [28776] = 6,  -- Necrotic Poison (Maexxna)
            [28622] = 9,  -- Web Wrap (Maexxna)
            [28796] = 2,  -- Poison Bolt Volley (Faerlina)
            [29213] = 6,  -- Curse of the Plaguebringer (Noth)
            [29212] = 3,  -- Cripple (Noth)
            [29998] = 5,  -- Decrepit Fever (Heigan)
            [29204] = 2,  -- Inevitable Doom (Loatheb)
            [28169] = 9,  -- Mutating Injection (Grobbulus)
            [25646] = 4,  -- Mortal Wound (Gluth)
            [28059] = 6,  -- Positive Charge (Thaddius)
            [28084] = 6,  -- Negative Charge (Thaddius)
            [28832] = 3,  -- Mark of Korth'azz
            [28833] = 3,  -- Mark of Blaumeux
            [28834] = 3,  -- Mark of Mograine
            [28835] = 3,  -- Mark of Zeliek
            [28522] = 8,  -- Icebolt (Sapphiron)
            [27808] = 9,  -- Frost Blast (Kel'Thuzad)
            [27819] = 8,  -- Detonate Mana (Kel'Thuzad)
            [28410] = 9,  -- Chains of Kel'Thuzad
        },
    },
}

-- Orden en el desplegable de opciones
ns.RaidOrder = { 0, 409, 249, 469, 309, 509, 531, 533 }

-- Nombre visible de una instancia
function ns.InstanceName(key)
    local def = ns.RaidDebuffs[key]
    if def then return def.name end
    return (ns.db and ns.db.raid.names[key]) or ("Instancia " .. tostring(key))
end
