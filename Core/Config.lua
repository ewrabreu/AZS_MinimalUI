local ADDON_NAME, NS = ...
if type(NS) ~= "table" then _G.AZS_MinimalUI_NS = _G.AZS_MinimalUI_NS or {}; NS = _G.AZS_MinimalUI_NS end
NS.ADDON_NAME     = ADDON_NAME or "AZS_MinimalUI"
NS.VERSION        = "3.5.0-beta"
NS.LAYOUT_VERSION = 33
NS.AZS_MEDIA      = "Interface\\AddOns\\AzerothSurvivorsUI\\Assets\\"
NS.OWN_MEDIA      = "Interface\\AddOns\\AZS_MinimalUI\\Assets\\"

NS.COLORS = {
	ui           = { 192/255, 192/255, 192/255 },
	normal       = { 229/255, 178/255,  38/255 },
	highlight    = { 250/255, 250/255, 250/255 },
	title        = { 255/255, 234/255, 137/255 },
	offwhite     = { 196/255, 196/255, 196/255 },
	gray         = { 128/255, 128/255, 128/255 },
	verydarkgray = {  69/255,  59/255,  49/255 },
	health       = { 245/255,   0/255,  45/255 },
	cast         = {  70/255, 255/255, 131/255 },
	bossPurple   = { 0.62,    0.32,    0.92    },
	crystalCase  = { 211/255, 200/255, 169/255 },
	eliteBlue    = { 0.25,    0.66,    1.00    },
	rarePurple   = { 0.72,    0.36,    1.00    },
	bossOrange   = { 1.00,    0.55,    0.12    },
	mobRed       = { 0.88,    0.18,    0.20    },
}

NS.RANGE_COLORS = {
	{ 1.00, 0.86, 0.35 }, { 0.35, 0.85, 1.00 }, { 0.78, 0.45, 1.00 }, { 0.35, 0.95, 0.55 },
	{ 1.00, 0.55, 0.22 }, { 1.00, 0.40, 0.65 }, { 0.65, 0.95, 0.30 }, { 0.55, 0.72, 1.00 },
}

NS.FONTS = {
	{ name = "Friz Quadrata (WoW)",  path = "Fonts\\FRIZQT__.TTF" },
	{ name = "Arial Narrow (Clean)", path = "Fonts\\ARIALN.TTF"   },
	{ name = "Morpheus (RPG)",       path = "Fonts\\MORPHEUS.TTF" },
	{ name = "Skurri (Combat)",      path = "Fonts\\SKURRI.TTF"   },
}

NS.SPELL_BASE_RANGE_BY_KEY = {
	holy_nova = 10, frost_nova = 10, arcane_explosion = 10, blast_wave = 10, dragons_breath = 10,
	cone_of_cold = 10, consecration = 8, divine_storm = 8, whirlwind = 8, thunder_clap = 8,
	cleave = 6, shockwave = 10, bladestorm = 8, fan_of_knives = 8, blade_flurry = 6,
	pestilence = 10, blood_boil = 10, death_and_decay = 10, howling_blast = -20, swipe = 8,
	starfall = 24, hurricane = 12, hellfire = 10, shadowfury = 12, rain_of_fire = 12,
	fire_nova = 10, magma_totem = 8, thunderstorm = 10, spinning_crane = 8, fists_of_fury = 7,
	explosive_trap = 10, volley = 14, psychic_scream = 8,
}

NS.AOE_NAME_PATTERNS = {
	{ "nova", 10 }, { "explos", 10 }, { "consagra", 8 }, { "consecrat", 8 },
	{ "redemoinho", 8 }, { "whirlwind", 8 }, { "trovoada", 8 }, { "thunder", 8 },
	{ "pestil", 10 }, { "leque", 8 }, { "fan of", 8 }, { "cutelada", 6 },
	{ "cleave", 6 }, { "golpe", 6 }, { "strike", 6 }, { "tempestade", 8 }, { "storm", 8 },
}

local M3 = { "minimal", "original", "off" }
local M2 = { "minimal", "off" }
local MO = { "original", "off" }

NS.MODULE_DEFS = {
	{ key = "TopBar",      label = "Top Bar",                    desc = "Clock, zone, Rift, horde, kills, and gold",                          modes = M3, defaultMode = "minimal",  boxes = { "TopBar" },                    azsParts = { "clock", "localClock", "tally", "banners" } },
	{ key = "BossBar",     label = "Boss Bars",                  desc = "Boss and Guardian health with debuffs and Enrage",                   modes = M3, defaultMode = "minimal",  boxes = { "BossBar" },                   azsParts = { "bosses" } },
	{ key = "PlayerHUD",   label = "Center HUD (HP / XP / Skills)", desc = "Health, shield, XP bar, proc, and skill rings",                   modes = M3, defaultMode = "minimal",  boxes = { "PlayerHUD" },                 azsParts = { "build" } },
	{ key = "StoredBadge", label = "Stored Levels [T] & Revive", desc = "Stored level-up badge and downed ally alert",                        modes = M3, defaultMode = "minimal",  boxes = { "StoredBadge" },               azsParts = { "levels", "revive" } },
	{ key = "StatsPanel",  label = "Stats Panel",                desc = "Survivability, CDR/Crit/Echo caps, and stats",                       modes = M2, defaultMode = "minimal",  boxes = { "StatsPanel" } },
	{ key = "MeterPanel",  label = "DPS Meter (Skills)",         desc = "Damage-per-second ranking of your abilities",                        modes = M3, defaultMode = "minimal",  boxes = { "MeterPanel" },                azsParts = { "meter" } },
	{ key = "PartyFrames", label = "Party Health",               desc = "Health, class color, and Revive bar for party allies",               modes = M3, defaultMode = "minimal",  boxes = { "PartyFrames" } },
	{ key = "PartyMeter",  label = "Party DPS Meter",            desc = "Real-time DPS ranking across all party members",                     modes = M2, defaultMode = "minimal",  boxes = { "PartyMeter" } },
	{ key = "PlayerBuffs",   label = "Player Buffs",               desc = "Player buffs, items, talents, racials, and debuffs with timers",     modes = M3, defaultMode = "minimal",  boxes = { "PlayerBuffs" } },
	{ key = "PartyBuffs",    label = "Party Buffs",                desc = "Group buffs, items, and racials (X/Y coverage or per-ally rows)",    modes = M2, defaultMode = "minimal",  boxes = { "PartyBuffs" } },
	{ key = "CooldownBuffs", label = "Buff Cooldowns",             desc = "Tracks when item, skill, talent, and race buffs activate again",     modes = M2, defaultMode = "minimal",  boxes = { "CooldownBuffs" } },
	{ key = "LootPanel",   label = "Loot & Drops",               desc = "Dropped armor/items, chest count, and run gold",                     modes = M3, defaultMode = "minimal",  boxes = { "LootPanel" },                 azsParts = { "loot" } },
	{ key = "DamageFeed",  label = "Damage Numbers",             desc = "Minimal: side feed · Original: WoW floating combat text",            modes = M3, defaultMode = "minimal",  boxes = { "DamageNormal", "DamageCrit" } },
	{ key = "Nameplates",  label = "Enemy Health (Nameplates)",  desc = "Minimal: clean bars + rarity · Original: WoW plates",                modes = M3, defaultMode = "minimal" },
	{ key = "Compass",     label = "360° Compass",               desc = "Radar for chests, lairs, portals, totems, and downed allies",        modes = M3, defaultMode = "minimal",  boxes = { "Compass" },                   azsParts = { "flag" } },
	{ key = "WorldPins",   label = "3D World Crystals",          desc = "Floating ground markers over visible chests and lairs",              modes = M2, defaultMode = "minimal" },
	{ key = "RangeRings",  label = "3D Attack Ranges",           desc = "Skill range rings on the ground with edge icons",                    modes = M2, defaultMode = "minimal" },
	{ key = "Minimap",     label = "Game Minimap",               desc = "Show the native WoW minimap or hide it completely",                  modes = MO, defaultMode = "off" },
	{ key = "Chat",        label = "Chat Window",                desc = "Show the native WoW chat or hide it for a clean screen",             modes = MO, defaultMode = "off" },
}

NS.MODULE_BY_KEY = {}
NS.BOX_TO_MODULE = {}
local defaultModes = {}
for i = 1, #NS.MODULE_DEFS do
	local def = NS.MODULE_DEFS[i]
	NS.MODULE_BY_KEY[def.key] = def
	defaultModes[def.key] = def.defaultMode
	if def.boxes then
		for j = 1, #def.boxes do NS.BOX_TO_MODULE[def.boxes[j]] = def.key end
	end
end

NS.BOX_ORDER = {
	{ key = "TopBar",       label = "Top Bar",                short = "TopBar"    },
	{ key = "BossBar",      label = "Boss Bars",              short = "Boss"      },
	{ key = "PlayerHUD",    label = "Center HUD",             short = "HUD"       },
	{ key = "StoredBadge",  label = "Stored Levels [T]",      short = "Levels"    },
	{ key = "StatsPanel",   label = "Stats Panel",            short = "Stats"     },
	{ key = "MeterPanel",   label = "DPS Meter (Skills)",     short = "DPS"       },
	{ key = "PartyFrames",  label = "Party Health",           short = "Party HP"  },
	{ key = "PartyMeter",   label = "Party DPS",              short = "Party DPS" },
	{ key = "PlayerBuffs",   label = "Player Buffs",           short = "Buffs"     },
	{ key = "PartyBuffs",    label = "Party Buffs",            short = "Grp Buffs" },
	{ key = "CooldownBuffs", label = "Buff Cooldowns",         short = "Buff CD"   },
	{ key = "LootPanel",    label = "Loot & Drops",           short = "Loot"      },
	{ key = "DamageNormal", label = "Normal Damage (Left)",   short = "Dmg L"     },
	{ key = "DamageCrit",   label = "Crit Damage (Right)",    short = "Dmg R"     },
	{ key = "Compass",      label = "360 Compass",            short = "Compass"   },
	{ key = "BetaRunPace",  label = "[Beta] Pace & Tactical", short = "[B] Tact." },
}

NS.BORDERLESS_BOXES = {
	BossBar = true, PlayerHUD = true, PlayerBuffs = true,
	DamageNormal = true, DamageCrit = true, Compass = true,
}

local function Box(pt, x, y, sc, w, h, a)
	return { point = pt, relPoint = pt, x = x, y = y, scale = sc, width = w, height = h, alpha = a }
end

NS.DEFAULTS = {
	layoutVersion = NS.LAYOUT_VERSION,
	locked = true, showGrid = true, snapToGrid = true,
	fontIndex = 1, fontSize = 11, bgAlpha = 0.72, borderAlpha = 0.95,
	hideMinimap = true, hideChat = true, showWorldPins = true, showSideDamage = true,
	xpBarSpacing = 12,
	moduleModes = defaultModes,
	party   = { showMeterWhenSolo = false },
	buffs   = { sizeMode = 2, showDebuffs = true, showItemBuffs = true, showTalentRaceBuffs = true, showReadyCooldowns = true, partyBuffMode = 1, showPartyBuffsWhenSolo = false },
	loot    = { filterMode = "armor", minQuality = 0, equipOnly = false, hideWhenEmpty = false, keepNativeLoot = false },
	plates  = { enabled = true, sizeMode = 2, showNormalNames = false, colorRarityNames = true },
	compass = { enabled = true, radius = 152, onlyOffscreen = true, showChests = true, showLairs = true, showPortalsTotems = true, showDowned = true, showBosses = true },
	ranges  = { enabled = true, alpha = 0.42, showEdgeIcon = true, scaleWithArea = true, maxDrawYards = 42 },
	beta    = { runPace = true, tacticalAdvisor = true, showPostRunCard = true, simSeconds = 5, coach = true, coachSound = true },
	betaPB  = {},
	hiddenBoxes = {},
	boxes = {
		TopBar       = Box("TOP",         0,    -4,   0.95, 1160, 42,  0.78),
		BossBar      = Box("TOP",         0,    -54,  0.88, 320,  100, 0.00),
		PlayerHUD    = Box("BOTTOM",      0,    18,   0.94, 340,  148, 0.00),
		StoredBadge  = Box("BOTTOM",      0,    172,  0.95, 236,  40,  0.82),
		StatsPanel   = Box("LEFT",        8,    -30,  0.92, 212,  272, 0.72),
		MeterPanel   = Box("RIGHT",       -8,   65,   0.92, 246,  212, 0.72),
		PartyFrames  = Box("TOPLEFT",     10,   -54,  0.92, 246,  142, 0.72),
		PartyMeter   = Box("RIGHT",       -8,   -135, 0.92, 246,  162, 0.72),
		PlayerBuffs   = Box("TOPRIGHT",    -12,  -54,  1.00, 264,  126, 0.00),
		PartyBuffs    = Box("TOPLEFT",     10,   -214, 0.94, 232,  148, 0.72),
		CooldownBuffs = Box("TOPRIGHT",    -286, -54,  0.92, 236,  242, 0.72),
		LootPanel    = Box("BOTTOMRIGHT", -10,  22,   0.92, 246,  192, 0.72),
		DamageNormal = Box("CENTER",      -215, 20,   0.95, 150,  140, 0.00),
		DamageCrit   = Box("CENTER",      215,  20,   0.95, 165,  155, 0.00),
		Compass      = Box("CENTER",      0,    10,   1.00, 320,  320, 0.00),
		BetaRunPace  = Box("BOTTOMLEFT",  10,   14,   0.92, 258,  300, 0.76),
	},
}

NS.Modules         = {}
NS.BetaModules     = {}
NS.MovableFrames   = {}
NS.DragOverlays    = {}
NS.RegisteredFonts = {}
NS.EditorHooks     = {}
NS.DB              = nil
