-------------------------------------------------------------------------------
-- MendFrames - Bandas
-- Jefes y orden: los del cliente (datos de ForeverDB.net, build 1.60.1.70862).
-- IDs comprobados en el cliente de Forever (foreverdb.net/spell/<ID>); un
-- debuff se reconoce también por los demás IDs con su mismo nombre.
-- Los que van por nombre se buscan en el cliente al entrar.
-------------------------------------------------------------------------------

local _, ns = ...
local R = ns.RegisterInstance

R(409, { name = "Molten Core", kind = "raid", bosses = {
    { "Lucifron", {
        [20604] = 5,  -- Dominate Mind (Flamewaker Protector)
        [19702] = 3,  -- Impending Doom
        [19703] = 3,  -- Lucifron's Curse
    } },
    { "Magmadar", {
        [19408] = 4,  -- Panic
        [19450] = 2,  -- Magma Spit
        [19428] = 2,  -- Conflagration
    } },
    { "Gehennas", {
        [19716] = 4,  -- Gehennas' Curse (-75% sanación)
        [19717] = 1,  -- Rain of Fire
    } },
    { "Garr", {
        [19496] = 2,  -- Magma Shackles
    } },
    { "Shazzrah", {
        [19713] = 3,  -- Shazzrah's Curse
    } },
    { "Baron Geddon", {
        [20475] = 5,  -- Living Bomb
        [19659] = 4,  -- Ignite Mana
    } },
    { "Sulfuron Harbinger", {
        [19780] = 2,  -- Hand of Ragnaros
        [19776] = 2,  -- Shadow Word: Pain (Flamewaker Priest)
        [20294] = 2,  -- Immolate
    } },
    { "Golemagg the Incinerator", {
        [13880] = 2,  -- Magma Splash
        [20228] = 2,  -- Pyroblast
    } },
    { "Majordomo Executus" },
    { "Ragnaros", {
        [20564] = 2,  -- Elemental Fire
    } },
    { "Trash", {
        [19369] = 3,  -- Ancient Despair (Ancient Core Hound)
        [19365] = 3,  -- Ancient Dread
        [19372] = 2,  -- Ancient Hysteria
        [19366] = 2,  -- Cauterizing Flames
        [19367] = 2,  -- Withering Heat
        [19771] = 2,  -- Serrated Bite (Core Hound)
        [19393] = 3,  -- Soul Burn (Firelord)
    } },
} })

R(249, { name = "Onyxia's Lair", kind = "raid", bosses = {
    { "Onyxia", {
        [22686] = 4,  -- Bellowing Roar
    } },
} })

R(469, { name = "Blackwing Lair", kind = "raid", bosses = {
    { "Razorgore the Untamed", {
        [23023] = 4,  -- Conflagration
    } },
    { "Vaelastrasz the Corrupt", {
        [18173] = 5,  -- Burning Adrenaline
    } },
    { "Broodlord Lashlayer", {
        [24573] = 3,  -- Mortal Strike
        [23331] = 2,  -- Blast Wave
    } },
    { "Firemaw", {
        [23341] = 2,  -- Flame Buffet
    } },
    { "Ebonroc", {
        [23340] = 4,  -- Shadow of Ebonroc
    } },
    { "Flamegor" },
    { "Chromaggus", {
        [23170] = 5,  -- Brood Affliction: Bronze
        [23310] = 4,  -- Time Lapse
        [23315] = 3,  -- Ignite Flesh
        [23155] = 3,  -- Brood Affliction: Red
        [23153] = 3,  -- Brood Affliction: Blue
        [23154] = 3,  -- Brood Affliction: Black
        [23169] = 3,  -- Brood Affliction: Green
        [23313] = 2,  -- Corrosive Acid
        [23187] = 2,  -- Frost Burn
    } },
    { "Nefarian", {
        [22667] = 5,  -- Shadow Command (Lord Victor Nefarius)
        [22687] = 4,  -- Veil of Shadow (-75% sanación)
        [23401] = 4,  -- Corrupted Healing (llamada de sacerdotes)
        [23603] = 4,  -- Wild Polymorph (llamada de magos)
        [22686] = 4,  -- Bellowing Roar
        [22678] = 3,  -- Fear (Lord Victor Nefarius)
        [22666] = 3,  -- Silence (Lord Victor Nefarius)
    } },
    { "Trash", {
        [22247] = 2,  -- Suppression Aura
    } },
} })

R(309, { name = "Zul'Gurub", kind = "raid", bosses = {
    { "High Priestess Jeklik", {
        [23918] = 3,  -- Sonic Burst
        [23952] = 2,  -- Shadow Word: Pain
        [23953] = 2,  -- Mind Flay
    } },
    { "High Priest Venoxis", {
        [23860] = 3,  -- Holy Fire
        [23861] = 1,  -- Poison Cloud
    } },
    { "High Priestess Mar'li", {
        [24110] = 3,  -- Enveloping Webs
        [24300] = 3,  -- Drain Life
        [24111] = 2,  -- Corrosive Poison
        [24099] = 1,  -- Poison Bolt Volley
    } },
    { "Bloodlord Mandokir", {
        [24314] = 5,  -- Threatening Gaze
        [16856] = 3,  -- Mortal Strike
    } },
    { "Edge of Madness", {
        [24664] = 3,  -- Sleep (Hazza'rah)
    } },
    { "High Priest Thekal", {
        [22859] = 3,  -- Mortal Cleave
        [21060] = 3,  -- Blind (Zealot Zath)
        [24698] = 2,  -- Gouge
    } },
    { "Gahz'ranka" },
    { "High Priestess Arlokk", {
        [24210] = 4,  -- Mark of Arlokk
    } },
    { "Jin'do the Hexxer", {
        [24261] = 5,  -- Brain Wash (control mental del tótem)
        [24306] = 4,  -- Delusions of Jin'do
        [24053] = 4,  -- Hex
    } },
    { "Hakkar", {
        [24178] = 5,  -- Will of Hakkar
        [24327] = 5,  -- Cause Insanity
        [24328] = 4,  -- Corrupted Blood
        [24321] = 2,  -- Poisonous Blood
        [24324] = 2,  -- Blood Siphon
    } },
} })

R(509, { name = "Ruins of Ahn'Qiraj", kind = "raid", bosses = {
    { "Kurinnaxx", {
        [25646] = 3,  -- Mortal Wound
        [25656] = 2,  -- Sand Trap
    } },
    { "General Rajaxx" },
    { "Moam", {
        [25671] = 2,  -- Drain Mana
    } },
    { "Buru the Gorger" },
    { "Ayamiss the Hunter", {
        [25725] = 5,  -- Paralyze
        [25748] = 2,  -- Poison Stinger
        [25749] = 2,  -- Stinger Spray
    } },
    { "Ossirian the Unscarred", {
        [25189] = 3,  -- Enveloping Winds
        [25195] = 2,  -- Curse of Tongues
    } },
} })

R(531, { name = "Ahn'Qiraj Temple", kind = "raid", bosses = {
    { "The Prophet Skeram", {
        [785]   = 5,  -- True Fulfillment
    } },
    { "Silithid Royalty", {
        [26580] = 3,  -- Fear (Princess Yauj)
        [25812] = 2,  -- Toxic Volley (Lord Kri)
    } },
    { "Battleguard Sartura", {
        [25174] = 1,  -- Sundering Cleave
    } },
    { "Fankriss the Unyielding", {
        [25646] = 3,  -- Mortal Wound
        [720]   = 3,  -- Entangle
    } },
    { "Viscidus", {
        [25937] = 4,  -- Viscidus Freeze
        [25991] = 2,  -- Poison Bolt Volley
        [25989] = 2,  -- Toxin
    } },
    { "Princess Huhuran", {
        [26180] = 4,  -- Wyvern Sting
        [26050] = 3,  -- Acid Spit
        [26053] = 2,  -- Noxious Poison
    } },
    { "Twin Emperors" },
    { "Ouro", {
        [26102] = 3,  -- Sand Blast
    } },
    { "C'thun", {
        [26476] = 3,  -- Digestive Acid
        [26044] = 3,  -- Mind Flay
    } },
    { "Trash", {
        [26556] = 4,  -- Plague (Anubisath Defender)
        [26078] = 2,  -- Vekniss Catalyst
    } },
} })

R(533, { name = "Naxxramas", kind = "raid", bosses = {
    { "Anub'Rekhan", {
        [28785] = 3,  -- Locust Swarm
    } },
    { "Grand Widow Faerlina", {
        [28796] = 1,  -- Poison Bolt Volley
        [28794] = 1,  -- Rain of Fire
    } },
    { "Maexxna", {
        [28622] = 5,  -- Web Wrap
        [28776] = 4,  -- Necrotic Poison
        [29484] = 3,  -- Web Spray
    } },
    { "Noth the Plaguebringer", {
        [29213] = 4,  -- Curse of the Plaguebringer
        [29212] = 2,  -- Cripple
        [29214] = 2,  -- Wrath of the Plaguebringer
    } },
    { "Heigan the Unclean", {
        [29998] = 3,  -- Decrepit Fever
    } },
    { "Loatheb", {
        [29204] = 3,  -- Inevitable Doom
        [29201] = 2,  -- Corrupted Mind
    } },
    { "Instructor Razuvious" },
    { "Gothik the Harvester" },
    { "The Four Horsemen", {
        [28832] = 2,  -- Mark of Korth'azz
        [28833] = 2,  -- Mark of Blaumeux
        [28834] = 2,  -- Mark of Mograine
        [28835] = 2,  -- Mark of Zeliek
    } },
    { "Patchwerk" },
    { "Grobbulus", {
        [28169] = 5,  -- Mutating Injection
    } },
    { "Gluth", {
        [25646] = 3,  -- Mortal Wound
        [29685] = 3,  -- Terrifying Roar
    } },
    { "Thaddius", {
        [28059] = 4,  -- Positive Charge
        [28084] = 4,  -- Negative Charge
    } },
    { "Sapphiron", {
        [28522] = 5,  -- Icebolt
        [28542] = 4,  -- Life Drain
    } },
    { "Kel'Thuzad", {
        [28410] = 5,  -- Chains of Kel'Thuzad
        [27808] = 5,  -- Frost Blast
        [27819] = 5,  -- Detonate Mana
        [28478] = 2,  -- Frostbolt
    } },
    { "Trash", {
        [28431] = 2,  -- Poison Charge (Venom Stalker)
    } },
} })

-------------------------------------------------------------------------------
-- En el cliente, sin anunciar para Forever (habilidades de Classic, por nombre)
-------------------------------------------------------------------------------
local U = "unannounced"

R(2789, { name = "The Tainted Scar", kind = "raid", status = U, bosses = {
    { "Lord Kazzak", {
        ["Mark of Kazzak"] = 5,
        ["Twisted Reflection"] = 4,
        ["Capture Soul"] = 2,
        ["Void Bolt"] = 2,
        ["Thunderclap"] = 2,
    } },
} })

R(2791, { name = "Storm Cliffs", kind = "raid", status = U, bosses = {
    { "Azuregos", {
        ["Chill"] = 3,
        ["Manastorm"] = 2,
        ["Mark of Frost"] = 2,
    } },
} })

R(2804, { name = "The Crystal Vale", kind = "raid", status = U, bosses = {
    { "Prince Thunderaan", {
        ["Tendrils of Air"] = 3,
        ["Tears of the Wind Seeker"] = 2,
    } },
} })

R(2832, { name = "Nightmare Grove", kind = "raid", status = U, bosses = {
    { "Emeriss", {
        ["Volatile Infection"] = 4,
        ["Corruption of the Earth"] = 3,
    } },
    { "Lethon" },
    { "Taerar", {
        [22686] = 4,  -- Bellowing Roar
    } },
    { "Ysondre" },
    { "Comunes a los dragones", {
        ["Sleep"] = 4,           -- Dream Fog
        ["Noxious Breath"] = 3,
        ["Mark of Nature"] = 2,
    } },
} })

R(2856, { name = "Scarlet Enclave", kind = "raid", status = U, bosses = {
    { "Balnazzar" }, { "Beatrix" }, { "Beastmaster" }, { "Solistrasza" },
    { "Mason" }, { "Reborn Council" }, { "Lillian Voss" }, { "Caldoran" },
} })

R(169, { name = "Emerald Dream", kind = "raid", status = U })
