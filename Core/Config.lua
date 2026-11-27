local ADDON_NAME, NS = ...
if type(NS) ~= "table" then _G.AZS_MinimalUI_NS = _G.AZS_MinimalUI_NS or {}; NS = _G.AZS_MinimalUI_NS end
NS.ADDON_NAME     = ADDON_NAME or "AZS_MinimalUI"
NS.VERSION        = "3.6.0"
NS.LAYOUT_VERSION = 44
NS.AZS_MEDIA      = "Interface\\AddOns\\AzerothSurvivorsUI\\Assets\\"
NS.OWN_MEDIA      = "Interface\\AddOns\\AZS_MinimalUI\\Assets\\"

NS.COLORS = {
	ui           = { 0.86, 0.78, 0.62 },
	normal       = { 0.90, 0.70, 0.16 },
	highlight    = { 0.98, 0.98, 0.98 },
	title        = { 1.00, 0.92, 0.54 },
	accent       = { 0.96, 0.78, 0.24 },
	offwhite     = { 0.77, 0.77, 0.77 },
	gray         = { 0.50, 0.50, 0.50 },
	verydarkgray = { 0.27, 0.23, 0.19 },
	health       = { 0.92, 0.08, 0.18 },
	shield       = { 0.20, 0.62, 1.00 },
	xp           = { 0.62, 0.36, 0.96 },
	cast         = { 0.28, 0.92, 0.48 },
	bossPurple   = { 0.62, 0.32, 0.92 },
	crystalCase  = { 0.86, 0.78, 0.64 },
	eliteBlue    = { 0.25, 0.70, 0.98 },
	rarePurple   = { 0.72, 0.36, 1.00 },
	bossOrange   = { 0.98, 0.50, 0.14 },
	mobRed       = { 0.88, 0.18, 0.20 },
	bullet       = { 0.88, 0.74, 0.38 },
	barTrack     = { 0.09, 0.08, 0.06, 0.85 },
}

NS.THEME_ORDER = { "classic", "tbc", "wotlk", "cataclysm" }
NS.THEMES = {
	classic = {
		key = "classic", name = "Classic", sub = "Azeroth · Forged Gold & Crimson",
		hex = { accent = "|cfff5c73d", title = "|cffffea89", normal = "|cffe6b329", elite = "|cff40b3fa", boss = "|cfffa8024", rare = "|cffb85cff", heal = "|cff47eb7a" },
		colors = {
			ui          = { 0.86, 0.78, 0.62 },
			normal      = { 0.90, 0.70, 0.16 },
			title       = { 1.00, 0.92, 0.54 },
			accent      = { 0.96, 0.78, 0.24 },
			health      = { 0.92, 0.08, 0.18 },
			shield      = { 0.20, 0.62, 1.00 },
			xp          = { 0.62, 0.36, 0.96 },
			cast        = { 0.28, 0.92, 0.48 },
			bossPurple  = { 0.62, 0.32, 0.92 },
			crystalCase = { 0.86, 0.78, 0.64 },
			eliteBlue   = { 0.25, 0.70, 0.98 },
			rarePurple  = { 0.72, 0.36, 1.00 },
			bossOrange  = { 0.98, 0.50, 0.14 },
			mobRed      = { 0.88, 0.18, 0.20 },
			bullet      = { 0.88, 0.74, 0.38 },
			barTrack    = { 0.09, 0.08, 0.06, 0.85 },
		},
		editor = {
			winBg        = { 0.045, 0.038, 0.030, 0.97 }, winBorder    = { 0.56, 0.44, 0.18, 0.95 },
			sideBg       = { 0.032, 0.026, 0.020, 0.98 }, bodyBg       = { 0.062, 0.052, 0.040, 0.95 },
			cardBg       = { 0.088, 0.074, 0.056, 0.92 }, cardBorder   = { 0.32, 0.26, 0.16, 0.85 },
			divider      = { 0.30, 0.24, 0.14, 0.80 },
			activeBg     = { 0.24, 0.18, 0.05, 0.96 },    activeBorder = { 0.96, 0.78, 0.24, 1.00 },
			swatches     = { { 0.96, 0.78, 0.24 }, { 0.92, 0.08, 0.18 }, { 0.86, 0.78, 0.62 } },
		},
	},
	tbc = {
		key = "tbc", name = "Burning Crusade", sub = "Outland · Fel Emerald & Nether",
		hex = { accent = "|cff33f570", title = "|cffb3ff9e", normal = "|cff38eb61", elite = "|cffb85cff", boss = "|cffe8c224", rare = "|cffcc4dff", heal = "|cff2ee8a6" },
		colors = {
			ui          = { 0.58, 0.84, 0.66 },
			normal      = { 0.22, 0.92, 0.38 },
			title       = { 0.70, 1.00, 0.62 },
			accent      = { 0.20, 0.96, 0.44 },
			health      = { 0.86, 0.12, 0.36 },
			shield      = { 0.18, 0.84, 0.96 },
			xp          = { 0.68, 0.24, 0.98 },
			cast        = { 0.18, 0.91, 0.65 },
			bossPurple  = { 0.76, 0.28, 1.00 },
			crystalCase = { 0.58, 0.88, 0.68 },
			eliteBlue   = { 0.72, 0.34, 1.00 },
			rarePurple  = { 0.82, 0.30, 1.00 },
			bossOrange  = { 0.91, 0.76, 0.14 },
			mobRed      = { 0.84, 0.18, 0.38 },
			bullet      = { 0.26, 0.92, 0.48 },
			barTrack    = { 0.05, 0.10, 0.07, 0.85 },
		},
		editor = {
			winBg        = { 0.025, 0.048, 0.036, 0.97 }, winBorder    = { 0.16, 0.62, 0.32, 0.95 },
			sideBg       = { 0.018, 0.034, 0.025, 0.98 }, bodyBg       = { 0.036, 0.066, 0.050, 0.95 },
			cardBg       = { 0.052, 0.095, 0.072, 0.92 }, cardBorder   = { 0.14, 0.34, 0.22, 0.85 },
			divider      = { 0.12, 0.30, 0.20, 0.80 },
			activeBg     = { 0.05, 0.25, 0.13, 0.96 },    activeBorder = { 0.20, 0.96, 0.44, 1.00 },
			swatches     = { { 0.20, 0.96, 0.44 }, { 0.68, 0.24, 0.98 }, { 0.58, 0.84, 0.66 } },
		},
	},
	wotlk = {
		key = "wotlk", name = "Lich King", sub = "Northrend · Frostmourne Ice & Steel",
		hex = { accent = "|cff4dd1ff", title = "|cffc7f0ff", normal = "|cff47c7ff", elite = "|cff8fb8ff", boss = "|cff996bff", rare = "|cff78aaff", heal = "|cff52ebb8" },
		colors = {
			ui          = { 0.68, 0.84, 0.96 },
			normal      = { 0.28, 0.78, 1.00 },
			title       = { 0.78, 0.94, 1.00 },
			accent      = { 0.30, 0.82, 1.00 },
			health      = { 0.84, 0.12, 0.28 },
			shield      = { 0.42, 0.92, 1.00 },
			xp          = { 0.24, 0.58, 0.98 },
			cast        = { 0.32, 0.92, 0.72 },
			bossPurple  = { 0.56, 0.40, 1.00 },
			crystalCase = { 0.72, 0.88, 0.98 },
			eliteBlue   = { 0.56, 0.72, 1.00 },
			rarePurple  = { 0.48, 0.68, 1.00 },
			bossOrange  = { 0.60, 0.42, 1.00 },
			mobRed      = { 0.76, 0.20, 0.34 },
			bullet      = { 0.45, 0.86, 1.00 },
			barTrack    = { 0.05, 0.08, 0.13, 0.85 },
		},
		editor = {
			winBg        = { 0.024, 0.038, 0.066, 0.97 }, winBorder    = { 0.22, 0.56, 0.78, 0.95 },
			sideBg       = { 0.016, 0.026, 0.048, 0.98 }, bodyBg       = { 0.036, 0.056, 0.092, 0.95 },
			cardBg       = { 0.052, 0.078, 0.128, 0.92 }, cardBorder   = { 0.16, 0.28, 0.42, 0.85 },
			divider      = { 0.14, 0.24, 0.38, 0.80 },
			activeBg     = { 0.05, 0.19, 0.30, 0.96 },    activeBorder = { 0.30, 0.82, 1.00, 1.00 },
			swatches     = { { 0.30, 0.82, 1.00 }, { 0.60, 0.42, 1.00 }, { 0.68, 0.84, 0.96 } },
		},
	},
	cataclysm = {
		key = "cataclysm", name = "Cataclysm", sub = "Shattering · Molten Magma & Ember",
		hex = { accent = "|cffff751a", title = "|cffffc76b", normal = "|cffff751a", elite = "|cffffb829", boss = "|cfff5291f", rare = "|cffff5238", heal = "|cff61e66b" },
		colors = {
			ui          = { 0.84, 0.58, 0.44 },
			normal      = { 1.00, 0.46, 0.10 },
			title       = { 1.00, 0.78, 0.42 },
			accent      = { 1.00, 0.46, 0.10 },
			health      = { 0.96, 0.20, 0.08 },
			shield      = { 0.28, 0.72, 1.00 },
			xp          = { 0.98, 0.42, 0.12 },
			cast        = { 0.38, 0.90, 0.42 },
			bossPurple  = { 0.92, 0.26, 0.18 },
			crystalCase = { 0.92, 0.64, 0.46 },
			eliteBlue   = { 1.00, 0.72, 0.16 },
			rarePurple  = { 1.00, 0.32, 0.22 },
			bossOrange  = { 0.96, 0.16, 0.12 },
			mobRed      = { 0.92, 0.22, 0.12 },
			bullet      = { 1.00, 0.56, 0.18 },
			barTrack    = { 0.12, 0.05, 0.04, 0.85 },
		},
		editor = {
			winBg        = { 0.055, 0.025, 0.020, 0.97 }, winBorder    = { 0.76, 0.34, 0.10, 0.95 },
			sideBg       = { 0.038, 0.018, 0.014, 0.98 }, bodyBg       = { 0.075, 0.034, 0.026, 0.95 },
			cardBg       = { 0.108, 0.048, 0.036, 0.92 }, cardBorder   = { 0.42, 0.19, 0.12, 0.85 },
			divider      = { 0.36, 0.16, 0.10, 0.80 },
			activeBg     = { 0.30, 0.12, 0.04, 0.96 },    activeBorder = { 1.00, 0.46, 0.10, 1.00 },
			swatches     = { { 1.00, 0.46, 0.10 }, { 1.00, 0.78, 0.42 }, { 0.84, 0.58, 0.44 } },
		},
	},
}
NS.ACTIVE_THEME = NS.THEMES.classic

NS.FONTS = {
	{ name = "Friz Quadrata (WoW)",  path = "Fonts\\FRIZQT__.TTF" },
	{ name = "Arial Narrow (Clean)", path = "Fonts\\ARIALN.TTF"   },
	{ name = "Morpheus (RPG)",       path = "Fonts\\MORPHEUS.TTF" },
	{ name = "Skurri (Combat)",      path = "Fonts\\SKURRI.TTF"   },
}

local M3 = { "minimal", "original", "off" }
local M2 = { "minimal", "off" }
local MO = { "original", "off" }

NS.MODULE_DEFS = {
	{ key = "TopBar",          label = "Top Bar",                      desc = "Clock, zone, Rift, horde, kills, and gold",                             modes = M3, defaultMode = "minimal",  boxes = { "TopBar" },                    azsParts = { "clock", "localClock", "tally" } },
	{ key = "EventBanner",     label = "Event Banner & Boss Horn",     desc = "Minimal alerts for bosses, rifts & events + boss horn audio",           modes = M3, defaultMode = "minimal",  boxes = { "EventBanner" },               azsParts = { "banners" } },
	{ key = "BossBar",         label = "Boss Bars",                    desc = "Boss and Guardian health with debuffs and Enrage",                      modes = M3, defaultMode = "minimal",  boxes = { "BossBar" },                   azsParts = { "bosses" } },
	{ key = "PlayerHUD",       label = "Center HUD (ARPG Bar)",        desc = "Party/Player HP, XP, class orb, 6 skills, 5 items, mount & passives",   modes = M3, defaultMode = "minimal",  boxes = { "PlayerHUD" },                 azsParts = { "build" } },
	{ key = "ClassExtra",      label = "Class Extra (Darkness)",       desc = "Rogue Path of Darkness active button, cooldown & duration",             modes = M2, defaultMode = "minimal",  boxes = { "ClassExtra" } },
	{ key = "SummonTracker",   label = "Pets, Summons & Totems",       desc = "Live counts and durations for active summons and totems",               modes = M2, defaultMode = "minimal",  boxes = { "SummonTracker" } },
	{ key = "StoredBadge",     label = "Revive Alert (Ally Down)",     desc = "Downed ally revive banner (Stored Levels flash on XP Bar)",             modes = M3, defaultMode = "minimal",  boxes = { "StoredBadge" },               azsParts = { "levels", "revive" } },
	{ key = "StatsPanel",      label = "Stats Panel",                  desc = "Survivability, caps, Luck, Account Gold, and stats",                    modes = M2, defaultMode = "minimal",  boxes = { "StatsPanel" } },
	{ key = "MeterPanel",      label = "Damage & Heal Meter (5 Tabs)", desc = "DPS, Total, Party Total, Boss DPS per player, and Healing",             modes = M3, defaultMode = "minimal",  boxes = { "MeterPanel" },                azsParts = { "meter" } },
	{ key = "LootPanel",       label = "Loot & Drops (0.8.0)",         desc = "Stars, Sets, Upgrades, ground sacks, chests, and run gold",             modes = M3, defaultMode = "minimal",  boxes = { "LootPanel" },                 azsParts = { "loot" } },
	{ key = "RunObjectives",   label = "Affixes, Hexes & Bosses",      desc = "Heroic affixes, Cursed Chest hexes, dungeon keys & boss checklist",     modes = M2, defaultMode = "minimal",  boxes = { "RunObjectives" } },
	{ key = "HolidayCurrency", label = "Holiday Event Currency",       desc = "Tracks active seasonal festival currency collected during the run",     modes = M2, defaultMode = "minimal",  boxes = { "HolidayCurrency" } },
	{ key = "EliteTimer",      label = "Elite Spawn Timer",            desc = "Tracks elite wave countdowns and Lair Guardian respawns",               modes = M2, defaultMode = "minimal",  boxes = { "EliteTimer" } },
	{ key = "DamageFeed",      label = "Damage Numbers",               desc = "Minimal: side feed · Original: WoW floating combat text",               modes = M3, defaultMode = "minimal",  boxes = { "DamageNormal", "DamageCrit" } },
	{ key = "Nameplates",      label = "Enemy Health (Nameplates)",    desc = "Minimal: clean bars + rarity · Original: WoW plates",                   modes = M3, defaultMode = "minimal" },
	{ key = "Compass",         label = "360° Compass",                 desc = "Radar for chests, lairs, portals, totems, and downed allies",           modes = M3, defaultMode = "minimal",  boxes = { "Compass" },                   azsParts = { "flag" } },
	{ key = "WorldPins",       label = "3D World Crystals",            desc = "Floating ground markers over chests (normal/boss/cursed) & lairs",      modes = M2, defaultMode = "minimal" },
	{ key = "Minimap",         label = "Minimap",                      desc = "WoW minimap framed with Minimal UI borders, Original, or Off",          modes = M3, defaultMode = "minimal",  boxes = { "Minimap" } },
	{ key = "Chat",            label = "Chat Window",                  desc = "Show the native WoW chat or hide it for a clean screen",                modes = MO, defaultMode = "off" },
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
	{ key = "TopBar",          label = "Top Bar",                short = "TopBar"   },
	{ key = "EventBanner",     label = "Event Banner",           short = "Banner"   },
	{ key = "BossBar",         label = "Boss Bars",              short = "Boss"     },
	{ key = "PlayerHUD",       label = "Center HUD",             short = "HUD"      },
	{ key = "ClassExtra",      label = "Class Extra (Darkness)", short = "Darkness" },
	{ key = "SummonTracker",   label = "Pets & Totems",          short = "Summons"  },
	{ key = "StoredBadge",     label = "Revive Alert",           short = "Revive"   },
	{ key = "StatsPanel",      label = "Stats Panel",            short = "Stats"    },
	{ key = "MeterPanel",      label = "Damage Meter (5 Tabs)",  short = "Damage"   },
	{ key = "LootPanel",       label = "Loot & Drops",           short = "Loot"     },
	{ key = "RunObjectives",   label = "Affixes & Bosses",       short = "Affixes"  },
	{ key = "HolidayCurrency", label = "Holiday Currency",       short = "Holiday"  },
	{ key = "Minimap",         label = "Minimap",                short = "Minimap"  },
	{ key = "EliteTimer",      label = "Elite Spawn Timer",      short = "Elites"   },
	{ key = "DamageNormal",    label = "Normal Damage (Left)",   short = "Dmg L"    },
	{ key = "DamageCrit",      label = "Crit Damage (Right)",    short = "Dmg R"    },
	{ key = "Compass",         label = "360 Compass",            short = "Compass"  },
}

NS.BORDERLESS_BOXES = {
	BossBar = true, PlayerHUD = true, EventBanner = true, ClassExtra = true, SummonTracker = true,
	DamageNormal = true, DamageCrit = true, Compass = true,
}

local function Box(pt, x, y, sc, w, h, a)
	return { point = pt, relPoint = pt, x = x, y = y, scale = sc, width = w, height = h, alpha = a }
end

NS.DEFAULTS = {
	layoutVersion = NS.LAYOUT_VERSION,
	locked = true, showGrid = true, snapToGrid = true,
	theme = "classic",
	fontIndex = 1, fontSize = 11, bgAlpha = 0.00, borderAlpha = 0.00,
	hideMinimap = false, hideChat = true, showWorldPins = true, showSideDamage = true,
	xpBarSpacing = 12,
	meterTab = 1,
	moduleModes = defaultModes,
	banner  = { playHorn = true },
	loot    = { filterMode = "armor", minQuality = 0, equipOnly = false, upgradesOnly = false, hideWhenEmpty = false, keepNativeLoot = false },
	minimap = { showZoneName = true },
	plates  = { enabled = true, sizeMode = 2, showNormalNames = false, colorRarityNames = true },
	compass = { enabled = true, radius = 152, onlyOffscreen = true, showChests = true, showLairs = true, showPortalsTotems = true, showDowned = true, showBosses = true },
	hiddenBoxes = {},
	boxes = {
		TopBar          = Box("TOP",         0,    -4,   0.95, 1160, 42,  0.00),
		EventBanner     = Box("TOP",         0,    -156, 0.96, 440,  40,  0.00),
		BossBar         = Box("TOP",         0,    -54,  0.88, 320,  100, 0.00),
		PlayerHUD       = Box("BOTTOM",      0,    14,   0.96, 544,  248, 0.00),
		ClassExtra      = Box("BOTTOM",      298,  104,  0.96, 46,   46,  0.00),
		SummonTracker   = Box("BOTTOM",      -298, 104,  0.96, 212,  36,  0.00),
		StoredBadge     = Box("BOTTOM",      0,    260,  0.95, 236,  40,  0.00),
		StatsPanel      = Box("LEFT",        8,    -30,  0.92, 212,  288, 0.00),
		MeterPanel      = Box("RIGHT",       -8,   20,   0.92, 262,  234, 0.00),
		LootPanel       = Box("BOTTOMRIGHT", -10,  22,   0.92, 246,  208, 0.00),
		RunObjectives   = Box("TOPRIGHT",    -12,  -54,  0.92, 226,  148, 0.00),
		HolidayCurrency = Box("TOPRIGHT",    -12,  -208, 0.92, 174,  30,  0.00),
		Minimap         = Box("TOPLEFT",     10,   -54,  0.95, 176,  176, 0.00),
		EliteTimer      = Box("TOPLEFT",     10,   -238, 0.92, 236,  138, 0.00),
		DamageNormal    = Box("CENTER",      -215, 20,   0.95, 150,  140, 0.00),
		DamageCrit      = Box("CENTER",      215,  20,   0.95, 165,  155, 0.00),
		Compass         = Box("CENTER",      0,    10,   1.00, 320,  320, 0.00),
	},
}

NS.Modules         = {}
NS.MovableFrames   = {}
NS.DragOverlays    = {}
NS.RegisteredFonts = {}
NS.EditorHooks     = {}
NS.DB              = nil
