-------------------------------------------------------------------------------
-- MendFrames - Dungeons and solo instances
-- Bosses and order: the client ones (ForeverDB.net data, build 1.60.1.70862);
-- the game does not provide them (empty journal and group finder in Forever).
-- Debuffs by name (Classic abilities according to ForeverDB): their IDs are
-- looked up in the client. Only the ones that leave a debuff on the group.
-------------------------------------------------------------------------------

local _, ns = ...
local R = ns.RegisterInstance
local U = "unannounced"

R(389, { name = "Ragefire Chasm", kind = "dungeon", bosses = {
    { "Oggleflint" },
    { "Taragaman the Hungerer" },
    { "Jergosh the Invoker", { "Immolate", "Curse of Weakness" } },
    { "Bazzalan" }
} })

R(43, { name = "Wailing Caverns", kind = "dungeon", bosses = {
    { "Lady Anacondra", { "Sleep" } },
    { "Lord Cobrahn", { "Druid's Slumber" } },
    { "Kresh" },
    { "Lord Pythas", { "Thunderclap" } },
    { "Skum" },
    { "Lord Serpentis" },
    { "Verdan the Everliving" },
    { "Mutanus the Devourer", { "Naralex's Nightmare", "Terrify", "Thundercrack" } }
} })

R(36, { name = "Deadmines", kind = "dungeon", bosses = {
    { "Rhahk'Zor", { "Rhahk'Zor Slam" } },
    { "Sneed", { "Disarm" } },
    { "Miner Johnson", { "Pierce Armor" } },
    { "Gilnid", { "Molten Metal" } },
    { "Captain Greenskin", { "Poisoned Harpoon" } },
    { "Mr. Smite", { "Smite Slam" } },
    { "Cookie", { "Acid Splash" } },
    { "Edwin VanCleef" }
} })

R(33, { name = "Shadowfang Keep", kind = "dungeon", bosses = {
    { "Rethilgore" },
    { "Razorclaw the Butcher" },
    { "Baron Silverlaine", { "Veil of Shadow" } },
    { "Commander Springvale", { "Hammer of Justice" } },
    { "Odo the Blindwatcher" },
    { "Fenrus the Devourer" },
    { "Wolf Master Nandos" },
    { "Archmage Arugal", { "Thundershock" } }
} })

R(48, { name = "Blackfathom Deeps", kind = "dungeon", bosses = {
    { "Ghamoo-ra" },
    { "Lady Sarevess", { "Slow" } },
    { "Geilhast", { "Net" } },
    { "Lorgus Jett" },
    { "Old Serra'kis" },
    { "Twilight Lord Kelris", { "Sleep" } },
    { "Aku'mai", { "Poison Cloud" } }
} })

R(34, { name = "Stormwind Stockade", kind = "dungeon", bosses = {
    { "Targorr the Dread" },
    { "Kam Deepfury", { "Shield Slam" } },
    { "Hamhock" },
    { "Dextren Ward", { "Intimidating Shout" } },
    { "Bazil Thredd", { "Smoke Bomb" } }
} })

R(90, { name = "Gnomeregan", kind = "dungeon", bosses = {
    { "Viscous Fallout" },
    { "Electrocutioner 6000" },
    { "Crowd Pummeler 9-60" },
    { "Mekgineer Thermaplugg" },
    { "Grubbis" }
} })

R(47, { name = "Razorfen Kraul", kind = "dungeon", bosses = {
    { "Roogug" },
    { "Aggem Thorncurse" },
    { "Death Speaker Jargba", { "Dominate Mind" } },
    { "Overlord Ramtusk" },
    { "Agathelos the Raging", { "Rampage" } },
    { "Charlga Razorflank" }
} })

R(189, { name = "Scarlet Monastery", kind = "dungeon", bosses = {
    { "Interrogator Vishas", { "Shadow Word: Pain" } },
    { "Bloodmage Thalnos" },
    { "Houndmaster Loksey" },
    { "Arcanist Doan", { "Polymorph", "Silence" } },
    { "Herod" },
    { "High Inquisitor Fairbanks", { "Fear", "Sleep", "Curse of Blood" } },
    { "High Inquisitor Whitemane", { "Dominate Mind", "Deep Sleep" } }
} })

R(129, { name = "Razorfen Downs", kind = "dungeon", bosses = {
    { "Tuten'kash", { "Curse of Tuten'kash" } },
    { "Plaguemaw the Rotting", { "Putrid Stench" } },
    { "Mordresh Fire Eye" },
    { "Ragglesnout", { "Dominate Mind", "Shadow Word: Pain" } },
    { "Glutton" },
    { "Amnennar the Coldbringer", { "Frost Nova", "Frostbolt" } }
} })

R(70, { name = "Uldaman", kind = "dungeon", bosses = {
    { "Revelosh" },
    { "The Lost Dwarves", { "Shield Slam" } },
    { "Ironaya" },
    { "Obsidian Sentinel" },
    { "Ancient Stone Keeper" },
    { "Galgann Firehammer", { "Amplify Flames", "Flame Lash" } },
    { "Grimlok", { "Shrink" } },
    { "Archaedas", { "Ground Tremor" } }
} })

R(209, { name = "Zul'Farrak", kind = "dungeon", bosses = {
    { "Hydromancer Velratha" },
    { "Gahz'rilla", { "Freeze Solid" } },
    { "Antu'sul" },
    { "Theka the Martyr", { "Fevered Plague" } },
    { "Witch Doctor Zum'rah" },
    { "Nekrum Gutchewer" },
    { "Shadowpriest Sezz'ziz", { "Psychic Scream" } },
    { "Chief Ukorz Sandscalp" }
} })

R(349, { name = "Maraudon", kind = "dungeon", bosses = {
    { "Noxxion" },
    { "Razorlash" },
    { "Tinkerer Gizlock", { "Goblin Dragon Gun" } },
    { "Lord Vyletongue", { "Smoke Bomb" } },
    { "Celebras the Cursed", { "Entangling Roots", "Twisted Tranquility" } },
    { "Landslide" },
    { "Rotgrip" },
    { "Princess Theradras", { "Repulsive Gaze" } }
} })

R(109, { name = "Sunken Temple", kind = "dungeon", bosses = {
    { "Atal'alarion", { "Ground Tremor" } },
    { "Avatar of Hakkar", { "Cause Insanity", "Curse of Tongues", "Lash" } },
    { "Shade of Eranikus", { "Deep Slumber" } },
    { "Hazzas" },
    { "Morphaz" },
    { "Weaver" },
    { "Dreamscythe" },
    { "Jammal'an the Prophet" }
} })

R(230, { name = "Blackrock Depths", kind = "dungeon", bosses = {
    { "High Interrogator Gerstahn", { "Psychic Scream", "Shadow Word: Pain" } },
    { "Lord Roccor", { "Flame Shock", "Ground Tremor" } },
    { "Houndmaster Grebmar" },
    { "Ring of Law" },
    { "Pyromancer Loregrain" },
    { "Lord Incendius" },
    { "Warder Stilgiss", { "Frost Nova", "Frostbolt" } },
    { "Fineous Darkvire" },
    { "Bael'Gar" },
    { "General Angerforge", { "Sunder Armor" } },
    { "Golem Lord Argelmach" },
    { "Hurley Blackbreath" },
    { "Phalanx" },
    { "Ribbly Screwspigot", { "Hamstring" } },
    { "Plugger Spazzring", { "Banish", "Immolate", "Curse of Tongues" } },
    { "The Vault" },
    { "Ambassador Flamelash" },
    { "The Seven", { "Mortal Strike", "Rupture", "Curse of Weakness" } },
    { "Magmus" },
    { "Princess Moira Bronzebeard" },
    { "Emperor Dagran Thaurissan", { "Hand of Thaurissan" } }
} })

R(229, { name = "Blackrock Spire", kind = "dungeon", bosses = {
    { "Highlord Omokk" },
    { "Shadow Hunter Vosh'gajin", { "Curse of Blood" } },
    { "War Master Voone", { "Mortal Strike", "Snap Kick" } },
    { "Mother Smolderweb", { "Mother's Milk" } },
    { "Urok Doomhowl", { "Intimidating Roar", "Rend" } },
    { "Quartermaster Zigris", { "Stun Bomb", "Hooked Net" } },
    { "Halycon" },
    { "Gizrul the Slavener", { "Infected Bite" } },
    { "Overlord Wyrmthalak" },
    { "Pyroguard Emberseer", { "Flame Buffet", "Pyroblast" } },
    { "Warchief Rend Blackhand" },
    { "The Beast", { "Terrifying Roar" } },
    { "General Drakkisath", { "Pierce Armor" } },
    { "Lord Valthalak" }
} })

R(429, { name = "Dire Maul", kind = "dungeon", bosses = {
    { "Zevrim Thornhoof", { "Intense Pain" } },
    { "Hydrospawn", { "Submersion" } },
    { "Lethtendris", { "Curse of Thorns", "Immolate", "Curse of Tongues" } },
    { "Pusillin" },
    { "Alzzin the Wildshaper", { "Mangle", "Disarm" } },
    { "Tendris Warpwood", { "Entangle" } },
    { "Illyanna Ravenoak", { "Concussive Shot" } },
    { "Magister Kalendris", { "Dominate Mind", "Mind Flay", "Shadow Word: Pain" } },
    { "Immol'thar", { "Infected Bite" } },
    { "Prince Tortheldrin" },
    { "Guard Mol'dar" },
    { "Stomper Kreeg" },
    { "Guard Fengus" },
    { "Guard Slip'kik" },
    { "Captain Kromcrush", { "Intimidating Shout", "Mortal Cleave" } },
    { "Cho'Rush the Observer", { "Psychic Scream", "Frost Nova" } },
    { "King Gordok", { "Mortal Strike", "Sunder Armor" } },
    { "Lord Hel'nurath", { "Veil of Shadow", "Sleep" } },
    { "Tsu'zee", { "Blind" } }
} })

R(289, { name = "Scholomance", kind = "dungeon", bosses = {
    { "Kirtonos", { "Dominate Mind", "Curse of Tongues", "Pierce Armor", "Disarm" } },
    { "Jandice Barov", { "Banish", "Curse of Blood" } },
    { "Rattlegore" },
    { "Marduk Blackpool" },
    { "Vectus" },
    { "Kormok" },
    { "Ras Frostwhisperer", { "Freeze", "Fear", "Frostbolt Volley", "Chill Nova" } },
    { "Instructor Malicia", { "Corruption", "Slow" } },
    { "Doctor Theolen Krastinov", { "Rend", "Backhand" } },
    { "Lorekeeper Polkelt", { "Volatile Infection", "Corrosive Acid", "Noxious Catalyst" } },
    { "The Ravenian" },
    { "Lord Alexei Barov", { "Veil of Shadow" } },
    { "Lady Illucia Barov", { "Silence", "Curse of Agony" } },
    { "Darkmaster Gandling", { "Curse of the Darkmaster" } }
} })

R(329, { name = "Stratholme", kind = "dungeon", bosses = {
    { "Hearthsinger Forresten", { "Enchanting Lullaby" } },
    { "Timmy the Cruel" },
    { "Malor the Zealous", { "Head Crack", "Ground Smash" } },
    { "Cannon Master Willey" },
    { "Archivist Galford", { "Burning Winds", "Pyroblast" } },
    { "Balnazzar" },
    { "The Unforgiven", { "Frost Nova" } },
    { "Baroness Anastari", { "Possess", "Banshee Curse", "Silence" } },
    { "Nerub'enkan", { "Encasing Webs", "Pierce Armor" } },
    { "Maleki the Pallid", { "Ice Tomb", "Frostbolt" } },
    { "Magistrate Barthilas" },
    { "Ramstein the Gorger" },
    { "Baron Rivendare", { "Mortal Strike" } },
    { "Black Guard Swordsmith" },
    { "Crimson Hammersmith", { "Bone Smelt" } },
    { "Ezra Grimm" },
    { "Postmaster Malown", { "Fear", "Curse of Tongues", "Backhand", "Curse of Weakness" } },
    { "Skul", { "Frost Shock" } },
    { "Stonespine", { "Vicious Rend" } }
} })

-------------------------------------------------------------------------------
-- New in Forever (no known abilities yet)
-------------------------------------------------------------------------------
R(2959, { name = "City of Dalaran", kind = "dungeon", bosses = {
    { "Arcane Anomaly" }, { "Fel Ancient" }, { "Mana Devourer" }, { "Mana Elemental" },
    { "Unstable Sentinel" }, { "Lyn the Ignored" }, { "Atrexis the Grave Knight" },
    { "Mana Wraith" }, { "Shade of the Archmage" }
} })

R(2998, { name = "Excavation Site: Wetlands", kind = "dungeon", bosses = {
    { "Saltspine" }, { "Shadetooth" }, { "Highland Horror" }, { "Relic Guardian" }
} })

R(2999, { name = "Ruins of Lordaeron", kind = "dungeon", bosses = {
    { "Witherfang" }, { "The Abandoned" }, { "The Butcher" }, { "Lordaeron Captain" },
    { "Viktor the Vile" }, { "Bjork" }, { "Rath'mael" }
} })

R(3065, { name = "The Hall of Thanes", kind = "dungeon", bosses = {
    { "Faldrim Anvilmar", { "Anvilmar's Curse" } },
    { "Infurnus" }, { "Plunder" }, { "Durgen Dirgehammer" }
} })

R(3109, { name = "Manor Mistmantle", kind = "dungeon" })

-------------------------------------------------------------------------------
-- In the client, not announced for Forever
-------------------------------------------------------------------------------
R(2784, { name = "Demon Fall Canyon", kind = "dungeon", status = U, bosses = {
    { "Grimroot" }, { "Destructor's Wraith" }, { "Zilbagob" }, { "Pyranis" },
    { "Diathorus the Seeker", { "Drain Life" } },
    { "Hellscream's Phantom" }, { "Azgaloth" }
} })

R(2875, { name = "Karazhan Crypts", kind = "dungeon", status = U, bosses = {
    { "Harbinger of Sin" }, { "Creeping Malison" }, { "Three Little Wolves" },
    { "Dark Rider", { "Lash of the Dark Rider" } },
    { "Kharon" }, { "Unk'omon" }, { "Hans and Greta" }, { "The Ugly Goblin" },
    { "Kaigy Maryla" }, { "Sairuh Maryla" }, { "Barian Maryla" }
} })

R(2720, { name = "The Searing Basin", kind = "dungeon", status = U, bosses = { { "Testwerk" } } })
R(2807, { name = "Burning of Andorhal", kind = "dungeon", status = U })
R(269, { name = "Caverns of Time", kind = "dungeon", status = U })
R(2853, { name = "Deadwind Pass", kind = "dungeon", status = U })
R(2806, { name = "Shadow Hold", kind = "dungeon", status = U })
R(2817, { name = "Starfall Barrow Den", kind = "dungeon", status = U })
R(2902, { name = "The Scarab Dais", kind = "dungeon", status = U })

R(2921, { name = "Naxxramas (solo)", kind = "solo", status = U, bosses = {
    { "Spirit of Mograine", { "Mark of Mograine" } }
} })
