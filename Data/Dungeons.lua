-------------------------------------------------------------------------------
-- MendFrames - Mazmorras e instancias de un jugador
-- Jefes y orden: los del cliente (datos de ForeverDB.net, build 1.60.1.70862);
-- el juego no los da (diario y buscador de grupos vacíos en Forever).
-- Debuffs por nombre (habilidades de Classic según ForeverDB): sus IDs se
-- buscan en el cliente al entrar. Solo los que dejan un debuff en el grupo.
-------------------------------------------------------------------------------

local _, ns = ...
local R = ns.RegisterInstance
local U = "unannounced"

R(389, { name = "Ragefire Chasm", kind = "dungeon", bosses = {
    { "Oggleflint" },
    { "Taragaman the Hungerer" },
    { "Jergosh the Invoker", { ["Immolate"] = 2, ["Curse of Weakness"] = 1 } },
    { "Bazzalan" },
} })

R(43, { name = "Wailing Caverns", kind = "dungeon", bosses = {
    { "Lady Anacondra", { ["Sleep"] = 4 } },
    { "Lord Cobrahn", { ["Druid's Slumber"] = 4 } },
    { "Kresh" },
    { "Lord Pythas", { ["Thunderclap"] = 1 } },
    { "Skum" },
    { "Lord Serpentis" },
    { "Verdan the Everliving" },
    { "Mutanus the Devourer", { ["Naralex's Nightmare"] = 4, ["Terrify"] = 4, ["Thundercrack"] = 2 } },
} })

R(36, { name = "Deadmines", kind = "dungeon", bosses = {
    { "Rhahk'Zor", { ["Rhahk'Zor Slam"] = 2 } },
    { "Sneed", { ["Disarm"] = 2 } },
    { "Miner Johnson", { ["Pierce Armor"] = 2 } },
    { "Gilnid", { ["Molten Metal"] = 3 } },
    { "Captain Greenskin", { ["Poisoned Harpoon"] = 3 } },
    { "Mr. Smite", { ["Smite Slam"] = 2 } },
    { "Cookie", { ["Acid Splash"] = 2 } },
    { "Edwin VanCleef" },
} })

R(33, { name = "Shadowfang Keep", kind = "dungeon", bosses = {
    { "Rethilgore" },
    { "Razorclaw the Butcher" },
    { "Baron Silverlaine", { ["Veil of Shadow"] = 4 } },
    { "Commander Springvale", { ["Hammer of Justice"] = 3 } },
    { "Odo the Blindwatcher" },
    { "Fenrus the Devourer" },
    { "Wolf Master Nandos" },
    { "Archmage Arugal", { ["Thundershock"] = 2 } },
} })

R(48, { name = "Blackfathom Deeps", kind = "dungeon", bosses = {
    { "Ghamoo-ra" },
    { "Lady Sarevess", { ["Slow"] = 3 } },
    { "Geilhast", { ["Net"] = 2 } },
    { "Lorgus Jett" },
    { "Old Serra'kis" },
    { "Twilight Lord Kelris", { ["Sleep"] = 4 } },
    { "Aku'mai", { ["Poison Cloud"] = 2 } },
} })

R(34, { name = "Stormwind Stockade", kind = "dungeon", bosses = {
    { "Targorr the Dread" },
    { "Kam Deepfury", { ["Shield Slam"] = 2 } },
    { "Hamhock" },
    { "Dextren Ward", { ["Intimidating Shout"] = 4 } },
    { "Bazil Thredd", { ["Smoke Bomb"] = 2 } },
} })

R(90, { name = "Gnomeregan", kind = "dungeon", bosses = {
    { "Viscous Fallout" },
    { "Electrocutioner 6000" },
    { "Crowd Pummeler 9-60" },
    { "Mekgineer Thermaplugg" },
    { "Grubbis" },
} })

R(47, { name = "Razorfen Kraul", kind = "dungeon", bosses = {
    { "Roogug" },
    { "Aggem Thorncurse" },
    { "Death Speaker Jargba", { ["Dominate Mind"] = 5 } },
    { "Overlord Ramtusk" },
    { "Agathelos the Raging", { ["Rampage"] = 2 } },
    { "Charlga Razorflank" },
} })

R(189, { name = "Scarlet Monastery", kind = "dungeon", bosses = {
    { "Interrogator Vishas", { ["Shadow Word: Pain"] = 2 } },
    { "Bloodmage Thalnos" },
    { "Houndmaster Loksey" },
    { "Arcanist Doan", { ["Polymorph"] = 4, ["Silence"] = 3 } },
    { "Herod" },
    { "High Inquisitor Fairbanks", { ["Fear"] = 4, ["Sleep"] = 4, ["Curse of Blood"] = 2 } },
    { "High Inquisitor Whitemane", { ["Dominate Mind"] = 5, ["Deep Sleep"] = 4 } },
} })

R(129, { name = "Razorfen Downs", kind = "dungeon", bosses = {
    { "Tuten'kash", { ["Curse of Tuten'kash"] = 3 } },
    { "Plaguemaw the Rotting", { ["Putrid Stench"] = 2 } },
    { "Mordresh Fire Eye" },
    { "Ragglesnout", { ["Dominate Mind"] = 5, ["Shadow Word: Pain"] = 2 } },
    { "Glutton" },
    { "Amnennar the Coldbringer", { ["Frost Nova"] = 2, ["Frostbolt"] = 2 } },
} })

R(70, { name = "Uldaman", kind = "dungeon", bosses = {
    { "Revelosh" },
    { "The Lost Dwarves", { ["Shield Slam"] = 2 } },
    { "Ironaya" },
    { "Obsidian Sentinel" },
    { "Ancient Stone Keeper" },
    { "Galgann Firehammer", { ["Amplify Flames"] = 3, ["Flame Lash"] = 2 } },
    { "Grimlok", { ["Shrink"] = 2 } },
    { "Archaedas", { ["Ground Tremor"] = 2 } },
} })

R(209, { name = "Zul'Farrak", kind = "dungeon", bosses = {
    { "Hydromancer Velratha" },
    { "Gahz'rilla", { ["Freeze Solid"] = 4 } },
    { "Antu'sul" },
    { "Theka the Martyr", { ["Fevered Plague"] = 3 } },
    { "Witch Doctor Zum'rah" },
    { "Nekrum Gutchewer" },
    { "Shadowpriest Sezz'ziz", { ["Psychic Scream"] = 4 } },
    { "Chief Ukorz Sandscalp" },
} })

R(349, { name = "Maraudon", kind = "dungeon", bosses = {
    { "Noxxion" },
    { "Razorlash" },
    { "Tinkerer Gizlock", { ["Goblin Dragon Gun"] = 2 } },
    { "Lord Vyletongue", { ["Smoke Bomb"] = 2 } },
    { "Celebras the Cursed", { ["Entangling Roots"] = 2, ["Twisted Tranquility"] = 2 } },
    { "Landslide" },
    { "Rotgrip" },
    { "Princess Theradras", { ["Repulsive Gaze"] = 4 } },
} })

R(109, { name = "Sunken Temple", kind = "dungeon", bosses = {
    { "Atal'alarion", { ["Ground Tremor"] = 2 } },
    { "Avatar of Hakkar", { ["Cause Insanity"] = 5, ["Curse of Tongues"] = 2, ["Lash"] = 2 } },
    { "Shade of Eranikus", { ["Deep Slumber"] = 4 } },
    { "Hazzas" },
    { "Morphaz" },
    { "Weaver" },
    { "Dreamscythe" },
    { "Jammal'an the Prophet" },
} })

R(230, { name = "Blackrock Depths", kind = "dungeon", bosses = {
    { "High Interrogator Gerstahn", { ["Psychic Scream"] = 4, ["Shadow Word: Pain"] = 2 } },
    { "Lord Roccor", { ["Flame Shock"] = 2, ["Ground Tremor"] = 2 } },
    { "Houndmaster Grebmar" },
    { "Ring of Law" },
    { "Pyromancer Loregrain" },
    { "Lord Incendius" },
    { "Warder Stilgiss", { ["Frost Nova"] = 2, ["Frostbolt"] = 2 } },
    { "Fineous Darkvire" },
    { "Bael'Gar" },
    { "General Angerforge", { ["Sunder Armor"] = 2 } },
    { "Golem Lord Argelmach" },
    { "Hurley Blackbreath" },
    { "Phalanx" },
    { "Ribbly Screwspigot", { ["Hamstring"] = 1 } },
    { "Plugger Spazzring", { ["Banish"] = 3, ["Immolate"] = 2, ["Curse of Tongues"] = 2 } },
    { "The Vault" },
    { "Ambassador Flamelash" },
    { "The Seven", { ["Mortal Strike"] = 3, ["Rupture"] = 2, ["Curse of Weakness"] = 1 } },
    { "Magmus" },
    { "Princess Moira Bronzebeard" },
    { "Emperor Dagran Thaurissan", { ["Hand of Thaurissan"] = 3 } },
} })

R(229, { name = "Blackrock Spire", kind = "dungeon", bosses = {
    { "Highlord Omokk" },
    { "Shadow Hunter Vosh'gajin", { ["Curse of Blood"] = 2 } },
    { "War Master Voone", { ["Mortal Strike"] = 3, ["Snap Kick"] = 2 } },
    { "Mother Smolderweb", { ["Mother's Milk"] = 3 } },
    { "Urok Doomhowl", { ["Intimidating Roar"] = 4, ["Rend"] = 2 } },
    { "Quartermaster Zigris", { ["Stun Bomb"] = 2, ["Hooked Net"] = 2 } },
    { "Halycon" },
    { "Gizrul the Slavener", { ["Infected Bite"] = 3 } },
    { "Overlord Wyrmthalak" },
    { "Pyroguard Emberseer", { ["Flame Buffet"] = 2, ["Pyroblast"] = 2 } },
    { "Warchief Rend Blackhand" },
    { "The Beast", { ["Terrifying Roar"] = 4 } },
    { "General Drakkisath", { ["Pierce Armor"] = 2 } },
    { "Lord Valthalak" },
} })

R(429, { name = "Dire Maul", kind = "dungeon", bosses = {
    { "Zevrim Thornhoof", { ["Intense Pain"] = 2 } },
    { "Hydrospawn", { ["Submersion"] = 1 } },
    { "Lethtendris", { ["Curse of Thorns"] = 2, ["Immolate"] = 2, ["Curse of Tongues"] = 2 } },
    { "Pusillin" },
    { "Alzzin the Wildshaper", { ["Mangle"] = 2, ["Disarm"] = 2 } },
    { "Tendris Warpwood", { ["Entangle"] = 2 } },
    { "Illyanna Ravenoak", { ["Concussive Shot"] = 1 } },
    { "Magister Kalendris", { ["Dominate Mind"] = 5, ["Mind Flay"] = 2, ["Shadow Word: Pain"] = 2 } },
    { "Immol'thar", { ["Infected Bite"] = 3 } },
    { "Prince Tortheldrin" },
    { "Guard Mol'dar" },
    { "Stomper Kreeg" },
    { "Guard Fengus" },
    { "Guard Slip'kik" },
    { "Captain Kromcrush", { ["Intimidating Shout"] = 4, ["Mortal Cleave"] = 3 } },
    { "Cho'Rush the Observer", { ["Psychic Scream"] = 4, ["Frost Nova"] = 2 } },
    { "King Gordok", { ["Mortal Strike"] = 3, ["Sunder Armor"] = 2 } },
    { "Lord Hel'nurath", { ["Veil of Shadow"] = 4, ["Sleep"] = 4 } },
    { "Tsu'zee", { ["Blind"] = 3 } },
} })

R(289, { name = "Scholomance", kind = "dungeon", bosses = {
    { "Kirtonos", { ["Dominate Mind"] = 5, ["Curse of Tongues"] = 2, ["Pierce Armor"] = 2, ["Disarm"] = 2 } },
    { "Jandice Barov", { ["Banish"] = 3, ["Curse of Blood"] = 2 } },
    { "Rattlegore" },
    { "Marduk Blackpool" },
    { "Vectus" },
    { "Kormok" },
    { "Ras Frostwhisperer", { ["Freeze"] = 4, ["Fear"] = 4, ["Frostbolt Volley"] = 2, ["Chill Nova"] = 2 } },
    { "Instructor Malicia", { ["Corruption"] = 2, ["Slow"] = 2 } },
    { "Doctor Theolen Krastinov", { ["Rend"] = 2, ["Backhand"] = 2 } },
    { "Lorekeeper Polkelt", { ["Volatile Infection"] = 4, ["Corrosive Acid"] = 2, ["Noxious Catalyst"] = 1 } },
    { "The Ravenian" },
    { "Lord Alexei Barov", { ["Veil of Shadow"] = 4 } },
    { "Lady Illucia Barov", { ["Silence"] = 3, ["Curse of Agony"] = 2 } },
    { "Darkmaster Gandling", { ["Curse of the Darkmaster"] = 3 } },
} })

R(329, { name = "Stratholme", kind = "dungeon", bosses = {
    { "Hearthsinger Forresten", { ["Enchanting Lullaby"] = 4 } },
    { "Timmy the Cruel" },
    { "Malor the Zealous", { ["Head Crack"] = 2, ["Ground Smash"] = 2 } },
    { "Cannon Master Willey" },
    { "Archivist Galford", { ["Burning Winds"] = 3, ["Pyroblast"] = 2 } },
    { "Balnazzar" },
    { "The Unforgiven", { ["Frost Nova"] = 2 } },
    { "Baroness Anastari", { ["Possess"] = 5, ["Banshee Curse"] = 3, ["Silence"] = 3 } },
    { "Nerub'enkan", { ["Encasing Webs"] = 3, ["Pierce Armor"] = 2 } },
    { "Maleki the Pallid", { ["Ice Tomb"] = 4, ["Frostbolt"] = 2 } },
    { "Magistrate Barthilas" },
    { "Ramstein the Gorger" },
    { "Baron Rivendare", { ["Mortal Strike"] = 3 } },
    { "Black Guard Swordsmith" },
    { "Crimson Hammersmith", { ["Bone Smelt"] = 2 } },
    { "Ezra Grimm" },
    { "Postmaster Malown", { ["Fear"] = 4, ["Curse of Tongues"] = 2, ["Backhand"] = 2, ["Curse of Weakness"] = 1 } },
    { "Skul", { ["Frost Shock"] = 2 } },
    { "Stonespine", { ["Vicious Rend"] = 2 } },
} })

-------------------------------------------------------------------------------
-- Nuevas de Forever (sin habilidades conocidas todavía: el registrador las apunta)
-------------------------------------------------------------------------------
R(2959, { name = "City of Dalaran", kind = "dungeon", bosses = {
    { "Arcane Anomaly" }, { "Fel Ancient" }, { "Mana Devourer" }, { "Mana Elemental" },
    { "Unstable Sentinel" }, { "Lyn the Ignored" }, { "Atrexis the Grave Knight" },
    { "Mana Wraith" }, { "Shade of the Archmage" },
} })

R(2998, { name = "Excavation Site: Wetlands", kind = "dungeon", bosses = {
    { "Saltspine" }, { "Shadetooth" }, { "Highland Horror" }, { "Relic Guardian" },
} })

R(2999, { name = "Ruins of Lordaeron", kind = "dungeon", bosses = {
    { "Witherfang" }, { "The Abandoned" }, { "The Butcher" }, { "Lordaeron Captain" },
    { "Viktor the Vile" }, { "Bjork" }, { "Rath'mael" },
} })

R(3065, { name = "The Hall of Thanes", kind = "dungeon", bosses = {
    { "Faldrim Anvilmar", { ["Anvilmar's Curse"] = 3 } },
    { "Infurnus" }, { "Plunder" }, { "Durgen Dirgehammer" },
} })

R(3109, { name = "Manor Mistmantle", kind = "dungeon" })

-------------------------------------------------------------------------------
-- En el cliente, sin anunciar para Forever
-------------------------------------------------------------------------------
R(2784, { name = "Demon Fall Canyon", kind = "dungeon", status = U, bosses = {
    { "Grimroot" }, { "Destructor's Wraith" }, { "Zilbagob" }, { "Pyranis" },
    { "Diathorus the Seeker", { ["Drain Life"] = 2 } },
    { "Hellscream's Phantom" }, { "Azgaloth" },
} })

R(2875, { name = "Karazhan Crypts", kind = "dungeon", status = U, bosses = {
    { "Harbinger of Sin" }, { "Creeping Malison" }, { "Three Little Wolves" },
    { "Dark Rider", { ["Lash of the Dark Rider"] = 2 } },
    { "Kharon" }, { "Unk'omon" }, { "Hans and Greta" }, { "The Ugly Goblin" },
    { "Kaigy Maryla" }, { "Sairuh Maryla" }, { "Barian Maryla" },
} })

R(2720, { name = "The Searing Basin", kind = "dungeon", status = U, bosses = { { "Testwerk" } } })
R(2807, { name = "Burning of Andorhal", kind = "dungeon", status = U })
R(269, { name = "Caverns of Time", kind = "dungeon", status = U })
R(2853, { name = "Deadwind Pass", kind = "dungeon", status = U })
R(2806, { name = "Shadow Hold", kind = "dungeon", status = U })
R(2817, { name = "Starfall Barrow Den", kind = "dungeon", status = U })
R(2902, { name = "The Scarab Dais", kind = "dungeon", status = U })

R(2921, { name = "Naxxramas (1 jugador)", kind = "solo", status = U, bosses = {
    { "Spirit of Mograine", { ["Mark of Mograine"] = 2 } },
} })
