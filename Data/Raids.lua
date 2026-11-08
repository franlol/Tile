-------------------------------------------------------------------------------
-- MendFrames - Raids
-- Bosses and order: the client ones (ForeverDB.net data, build 1.60.1.70862).
-- IDs checked in the Forever client (foreverdb.net/spell/<ID>).
-- Spells given by name are looked up in the client.
-- Reference only: the game does not let addons tell these debuffs apart in
-- combat (see the Instances page).
-------------------------------------------------------------------------------

local _, ns = ...
local R = ns.RegisterInstance

R(409, { name = "Molten Core", kind = "raid", bosses = {
    { "Lucifron", {
        20604,  -- Dominate Mind (Flamewaker Protector)
        19702,  -- Impending Doom
        19703,  -- Lucifron's Curse
    } },
    { "Magmadar", {
        19408,  -- Panic
        19450,  -- Magma Spit
        19428,  -- Conflagration
    } },
    { "Gehennas", {
        19716,  -- Gehennas' Curse (-75% healing)
        19717,  -- Rain of Fire
    } },
    { "Garr", {
        19496,  -- Magma Shackles
    } },
    { "Shazzrah", {
        19713,  -- Shazzrah's Curse
    } },
    { "Baron Geddon", {
        20475,  -- Living Bomb
        19659,  -- Ignite Mana
    } },
    { "Sulfuron Harbinger", {
        19780,  -- Hand of Ragnaros
        19776,  -- Shadow Word: Pain (Flamewaker Priest)
        20294,  -- Immolate
    } },
    { "Golemagg the Incinerator", {
        13880,  -- Magma Splash
        20228,  -- Pyroblast
    } },
    { "Majordomo Executus" },
    { "Ragnaros", {
        20564,  -- Elemental Fire
    } },
    { "Trash", {
        19369,  -- Ancient Despair (Ancient Core Hound)
        19365,  -- Ancient Dread
        19372,  -- Ancient Hysteria
        19366,  -- Cauterizing Flames
        19367,  -- Withering Heat
        19771,  -- Serrated Bite (Core Hound)
        19393,  -- Soul Burn (Firelord)
    } }
} })

R(249, { name = "Onyxia's Lair", kind = "raid", bosses = {
    { "Onyxia", {
        22686,  -- Bellowing Roar
    } }
} })

R(469, { name = "Blackwing Lair", kind = "raid", bosses = {
    { "Razorgore the Untamed", {
        23023,  -- Conflagration
    } },
    { "Vaelastrasz the Corrupt", {
        18173,  -- Burning Adrenaline
    } },
    { "Broodlord Lashlayer", {
        24573,  -- Mortal Strike
        23331,  -- Blast Wave
    } },
    { "Firemaw", {
        23341,  -- Flame Buffet
    } },
    { "Ebonroc", {
        23340,  -- Shadow of Ebonroc
    } },
    { "Flamegor" },
    { "Chromaggus", {
        23170,  -- Brood Affliction: Bronze
        23310,  -- Time Lapse
        23315,  -- Ignite Flesh
        23155,  -- Brood Affliction: Red
        23153,  -- Brood Affliction: Blue
        23154,  -- Brood Affliction: Black
        23169,  -- Brood Affliction: Green
        23313,  -- Corrosive Acid
        23187,  -- Frost Burn
    } },
    { "Nefarian", {
        22667,  -- Shadow Command (Lord Victor Nefarius)
        22687,  -- Veil of Shadow (-75% healing)
        23401,  -- Corrupted Healing (llamada de sacerdotes)
        23603,  -- Wild Polymorph (llamada de magos)
        22686,  -- Bellowing Roar
        22678,  -- Fear (Lord Victor Nefarius)
        22666,  -- Silence (Lord Victor Nefarius)
    } },
    { "Trash", {
        22247,  -- Suppression Aura
    } }
} })

R(309, { name = "Zul'Gurub", kind = "raid", bosses = {
    { "High Priestess Jeklik", {
        23918,  -- Sonic Burst
        23952,  -- Shadow Word: Pain
        23953,  -- Mind Flay
    } },
    { "High Priest Venoxis", {
        23860,  -- Holy Fire
        23861,  -- Poison Cloud
    } },
    { "High Priestess Mar'li", {
        24110,  -- Enveloping Webs
        24300,  -- Drain Life
        24111,  -- Corrosive Poison
        24099,  -- Poison Bolt Volley
    } },
    { "Bloodlord Mandokir", {
        24314,  -- Threatening Gaze
        16856,  -- Mortal Strike
    } },
    { "Edge of Madness", {
        24664,  -- Sleep (Hazza'rah)
    } },
    { "High Priest Thekal", {
        22859,  -- Mortal Cleave
        21060,  -- Blind (Zealot Zath)
        24698,  -- Gouge
    } },
    { "Gahz'ranka" },
    { "High Priestess Arlokk", {
        24210,  -- Mark of Arlokk
    } },
    { "Jin'do the Hexxer", {
        24261,  -- Brain Wash (totem mind control)
        24306,  -- Delusions of Jin'do
        24053,  -- Hex
    } },
    { "Hakkar", {
        24178,  -- Will of Hakkar
        24327,  -- Cause Insanity
        24328,  -- Corrupted Blood
        24321,  -- Poisonous Blood
        24324,  -- Blood Siphon
    } }
} })

R(509, { name = "Ruins of Ahn'Qiraj", kind = "raid", bosses = {
    { "Kurinnaxx", {
        25646,  -- Mortal Wound
        25656,  -- Sand Trap
    } },
    { "General Rajaxx" },
    { "Moam", {
        25671,  -- Drain Mana
    } },
    { "Buru the Gorger" },
    { "Ayamiss the Hunter", {
        25725,  -- Paralyze
        25748,  -- Poison Stinger
        25749,  -- Stinger Spray
    } },
    { "Ossirian the Unscarred", {
        25189,  -- Enveloping Winds
        25195,  -- Curse of Tongues
    } }
} })

R(531, { name = "Ahn'Qiraj Temple", kind = "raid", bosses = {
    { "The Prophet Skeram", {
        785,  -- True Fulfillment
    } },
    { "Silithid Royalty", {
        26580,  -- Fear (Princess Yauj)
        25812,  -- Toxic Volley (Lord Kri)
    } },
    { "Battleguard Sartura", {
        25174,  -- Sundering Cleave
    } },
    { "Fankriss the Unyielding", {
        25646,  -- Mortal Wound
        720,  -- Entangle
    } },
    { "Viscidus", {
        25937,  -- Viscidus Freeze
        25991,  -- Poison Bolt Volley
        25989,  -- Toxin
    } },
    { "Princess Huhuran", {
        26180,  -- Wyvern Sting
        26050,  -- Acid Spit
        26053,  -- Noxious Poison
    } },
    { "Twin Emperors" },
    { "Ouro", {
        26102,  -- Sand Blast
    } },
    { "C'thun", {
        26476,  -- Digestive Acid
        26044,  -- Mind Flay
    } },
    { "Trash", {
        26556,  -- Plague (Anubisath Defender)
        26078,  -- Vekniss Catalyst
    } }
} })

R(533, { name = "Naxxramas", kind = "raid", bosses = {
    { "Anub'Rekhan", {
        28785,  -- Locust Swarm
    } },
    { "Grand Widow Faerlina", {
        28796,  -- Poison Bolt Volley
        28794,  -- Rain of Fire
    } },
    { "Maexxna", {
        28622,  -- Web Wrap
        28776,  -- Necrotic Poison
        29484,  -- Web Spray
    } },
    { "Noth the Plaguebringer", {
        29213,  -- Curse of the Plaguebringer
        29212,  -- Cripple
        29214,  -- Wrath of the Plaguebringer
    } },
    { "Heigan the Unclean", {
        29998,  -- Decrepit Fever
    } },
    { "Loatheb", {
        29204,  -- Inevitable Doom
        29201,  -- Corrupted Mind
    } },
    { "Instructor Razuvious" },
    { "Gothik the Harvester" },
    { "The Four Horsemen", {
        28832,  -- Mark of Korth'azz
        28833,  -- Mark of Blaumeux
        28834,  -- Mark of Mograine
        28835,  -- Mark of Zeliek
    } },
    { "Patchwerk" },
    { "Grobbulus", {
        28169,  -- Mutating Injection
    } },
    { "Gluth", {
        25646,  -- Mortal Wound
        29685,  -- Terrifying Roar
    } },
    { "Thaddius", {
        28059,  -- Positive Charge
        28084,  -- Negative Charge
    } },
    { "Sapphiron", {
        28522,  -- Icebolt
        28542,  -- Life Drain
    } },
    { "Kel'Thuzad", {
        28410,  -- Chains of Kel'Thuzad
        27808,  -- Frost Blast
        27819,  -- Detonate Mana
        28478,  -- Frostbolt
    } },
    { "Trash", {
        28431,  -- Poison Charge (Venom Stalker)
    } }
} })

-------------------------------------------------------------------------------
-- In the client, not announced for Forever (Classic abilities, by name)
-------------------------------------------------------------------------------
local U = "unannounced"

R(2789, { name = "The Tainted Scar", kind = "raid", status = U, bosses = {
    { "Lord Kazzak", {
        "Mark of Kazzak",
        "Twisted Reflection",
        "Capture Soul",
        "Void Bolt",
        "Thunderclap"
    } }
} })

R(2791, { name = "Storm Cliffs", kind = "raid", status = U, bosses = {
    { "Azuregos", {
        "Chill",
        "Manastorm",
        "Mark of Frost"
    } }
} })

R(2804, { name = "The Crystal Vale", kind = "raid", status = U, bosses = {
    { "Prince Thunderaan", {
        "Tendrils of Air",
        "Tears of the Wind Seeker"
    } }
} })

R(2832, { name = "Nightmare Grove", kind = "raid", status = U, bosses = {
    { "Emeriss", {
        "Volatile Infection",
        "Corruption of the Earth"
    } },
    { "Lethon" },
    { "Taerar", {
        22686,  -- Bellowing Roar
    } },
    { "Ysondre" },
    { "Comunes a los dragones", {
        "Sleep",           -- Dream Fog
        "Noxious Breath",
        "Mark of Nature"
    } }
} })

R(2856, { name = "Scarlet Enclave", kind = "raid", status = U, bosses = {
    { "Balnazzar" }, { "Beatrix" }, { "Beastmaster" }, { "Solistrasza" },
    { "Mason" }, { "Reborn Council" }, { "Lillian Voss" }, { "Caldoran" }
} })

R(169, { name = "Emerald Dream", kind = "raid", status = U })
