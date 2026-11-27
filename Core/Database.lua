local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local max, tonumber, type = math.max, tonumber, type

local function IsModeAllowed(def, mode)
	if not (def and def.modes) then return false end
	for i = 1, #def.modes do
		if def.modes[i] == mode then return true end
	end
	return false
end

function NS.GetModuleMode(modKey)
	local def = NS.MODULE_BY_KEY and NS.MODULE_BY_KEY[modKey]
	local fallback = (def and def.defaultMode) or "minimal"
	if not (NS.DB and NS.DB.moduleModes) then return fallback end
	local m = NS.DB.moduleModes[modKey]
	return (def and IsModeAllowed(def, m)) and m or fallback
end

function NS.IsModuleMinimal(modKey) return NS.GetModuleMode(modKey) == "minimal" end
function NS.IsModuleOriginal(modKey) return NS.GetModuleMode(modKey) == "original" end

function NS.SyncLegacyFlagsFromModules()
	local DB = NS.DB
	if not DB then return end
	DB.moduleModes = DB.moduleModes or {}
	DB.hiddenBoxes = DB.hiddenBoxes or {}
	local mm = DB.moduleModes
	for i = 1, #NS.MODULE_DEFS do
		local def = NS.MODULE_DEFS[i]
		local mode = NS.GetModuleMode(def.key)
		mm[def.key] = mode
		local isMin = (mode == "minimal")
		if def.boxes then
			for j = 1, #def.boxes do
				local bKey = def.boxes[j]
				if not isMin then DB.hiddenBoxes[bKey] = true
				elseif def.key ~= "DamageFeed" then DB.hiddenBoxes[bKey] = false end
			end
		end
	end
	if DB.plates  then DB.plates.enabled  = (mm.Nameplates == "minimal") end
	if DB.compass then DB.compass.enabled = (mm.Compass    == "minimal") end
	DB.showWorldPins  = (mm.WorldPins  == "minimal")
	DB.showSideDamage = (mm.DamageFeed == "minimal")
	DB.hideMinimap    = (mm.Minimap    == "off")
	DB.hideChat       = (mm.Chat       ~= "original")
end

local function ApplyModuleChanges()
	if NS.SuppressNativeAndBlizzardUI then NS.SuppressNativeAndBlizzardUI() end
	if NS.RefreshAllLayouts then NS.RefreshAllLayouts() end
	if NS.Modules.Nameplates then NS.Modules.Nameplates.ScanAndUpdate() end
	if NS.Modules.WorldPins then NS.Modules.WorldPins.UpdateWorldProjection() end
	if NS.UpdateMinimalHUD then NS.UpdateMinimalHUD() end
	if NS.EditorHooks.SyncUI then NS.EditorHooks.SyncUI() end
end

function NS.SetModuleMode(modKey, mode, skipRefresh)
	if not NS.DB then NS.InitializeDB() end
	local def = NS.MODULE_BY_KEY and NS.MODULE_BY_KEY[modKey]
	if not (def and IsModeAllowed(def, mode)) then return end
	NS.DB.moduleModes[modKey] = mode
	if modKey == "DamageFeed" and mode == "minimal" then
		NS.DB.hiddenBoxes.DamageNormal = false
		NS.DB.hiddenBoxes.DamageCrit = false
	end
	NS.SyncLegacyFlagsFromModules()
	if not skipRefresh then ApplyModuleChanges() end
end

function NS.ApplyModulePreset(preset)
	if not NS.DB then NS.InitializeDB() end
	for i = 1, #NS.MODULE_DEFS do
		local def = NS.MODULE_DEFS[i]
		local target = "off"
		if preset == "minimal" then target = def.defaultMode
		elseif preset == "original" and IsModeAllowed(def, "original") then target = "original" end
		NS.SetModuleMode(def.key, target, true)
	end
	ApplyModuleChanges()
end

function NS.IsBoxHidden(boxKey)
	local modKey = NS.BOX_TO_MODULE and NS.BOX_TO_MODULE[boxKey]
	if modKey and NS.GetModuleMode(modKey) ~= "minimal" then return true end
	return NS.DB and NS.DB.hiddenBoxes and NS.DB.hiddenBoxes[boxKey] == true
end

local LEGACY_BOX_MODS = { "TopBar", "BossBar", "PlayerHUD", "StoredBadge", "StatsPanel", "MeterPanel" }

function NS.InitializeDB()
	local prev = (type(_G.AZS_MinimalUI_DB) == "table" and tonumber(_G.AZS_MinimalUI_DB.layoutVersion)) or 0
	_G.AZS_MinimalUI_DB = NS.CopyDefaults(NS.DEFAULTS, _G.AZS_MinimalUI_DB)
	local DB = _G.AZS_MinimalUI_DB
	NS.DB = DB
	if prev > 0 and prev < NS.LAYOUT_VERSION then
		local boxes, defBoxes = DB.boxes, NS.DEFAULTS.boxes
		if prev < 23 then
			DB.boxes = NS.DeepCopy(defBoxes)
			boxes = DB.boxes
		elseif prev < 24 then
			boxes.MeterPanel = NS.DeepCopy(defBoxes.MeterPanel)
			boxes.Compass = NS.DeepCopy(defBoxes.Compass)
		end
		if prev < 25 then
			local mm = DB.moduleModes
			mm.Nameplates = (DB.plates and DB.plates.enabled == false) and "off" or "minimal"
			mm.Compass    = (DB.compass and DB.compass.enabled == false) and "off" or "minimal"
			mm.WorldPins  = (DB.showWorldPins == false) and "off" or "minimal"
			mm.DamageFeed = (DB.showSideDamage == false) and "off" or "minimal"
			mm.Minimap    = (DB.hideMinimap == false) and "original" or "off"
			mm.Chat       = (DB.hideChat == false) and "original" or "off"
			for i = 1, #LEGACY_BOX_MODS do
				local k = LEGACY_BOX_MODS[i]
				if DB.hiddenBoxes and DB.hiddenBoxes[k] then mm[k] = "off" end
			end
		end
		if prev < 27 then boxes.LootPanel = NS.DeepCopy(defBoxes.LootPanel) end
		if prev < 30 then
			boxes.BetaStatCaps, boxes.BetaCenterArcs = nil, nil
		end
		if prev < 34 then
			boxes.PartyFrames, boxes.PartyBuffs, boxes.BetaRunPace = nil, nil, nil
			DB.beta, DB.betaPB = nil, nil
			if DB.moduleModes then
				DB.moduleModes.PartyFrames = nil
				DB.moduleModes.PartyBuffs = nil
			end
			if DB.buffs then
				DB.buffs.partyBuffMode = nil
				DB.buffs.showPartyBuffsWhenSolo = nil
			end
			boxes.EliteTimer = NS.DeepCopy(defBoxes.EliteTimer)
			if boxes.StatsPanel then boxes.StatsPanel.height = max(boxes.StatsPanel.height or 0, 288) end
			if boxes.MeterPanel then boxes.MeterPanel.height = max(boxes.MeterPanel.height or 0, 234) end
			if boxes.PlayerHUD then boxes.PlayerHUD.height = max(boxes.PlayerHUD.height or 0, 198) end
			if boxes.StoredBadge and boxes.StoredBadge.point == "BOTTOM" and (boxes.StoredBadge.y or 0) < 210 then
				boxes.StoredBadge.y = 218
			end
		end
		if prev < 36 then
			boxes.SquareMinimap = nil
			boxes.Minimap = NS.DeepCopy(defBoxes.Minimap)
			DB.minimap = NS.DeepCopy(NS.DEFAULTS.minimap)
			if DB.moduleModes then
				DB.moduleModes.SquareMinimap = nil
				DB.moduleModes.Minimap = "minimal"
			end
			if boxes.EliteTimer and boxes.EliteTimer.point == "TOPLEFT" and ((boxes.EliteTimer.y or 0) == -262 or (boxes.EliteTimer.y or 0) == -244) then
				boxes.EliteTimer.y = -238
			end
		end
		if prev < 37 then
			boxes.PlayerBuffs = nil
			if DB.moduleModes then DB.moduleModes.PlayerBuffs = nil end
			if boxes.PlayerHUD then
				boxes.PlayerHUD.width = max(boxes.PlayerHUD.width or 0, 512)
				boxes.PlayerHUD.height = max(boxes.PlayerHUD.height or 0, 236)
			end
			if boxes.StoredBadge and boxes.StoredBadge.point == "BOTTOM" and (boxes.StoredBadge.y or 0) < 240 then
				boxes.StoredBadge.y = 246
			end
			if boxes.CooldownBuffs and boxes.CooldownBuffs.point == "TOPRIGHT" and (boxes.CooldownBuffs.x or 0) == -286 then
				boxes.CooldownBuffs.x = -12
			end
		end
		if prev < 38 then
			if boxes.PlayerHUD then
				boxes.PlayerHUD.width = max(boxes.PlayerHUD.width or 0, 544)
				boxes.PlayerHUD.height = max(boxes.PlayerHUD.height or 0, 248)
			end
			if boxes.StoredBadge and boxes.StoredBadge.point == "BOTTOM" and (boxes.StoredBadge.y or 0) < 255 then
				boxes.StoredBadge.y = 260
			end
		end
		if prev < 39 then
			boxes.CooldownBuffs, boxes.PartyMeter = nil, nil
			DB.party, DB.buffs = nil, nil
			if DB.moduleModes then
				DB.moduleModes.CooldownBuffs = nil
				DB.moduleModes.PartyMeter = nil
			end
			if boxes.MeterPanel then
				boxes.MeterPanel.width = max(boxes.MeterPanel.width or 0, 262)
			end
		end
		if prev < 40 then
			DB.ranges = nil
			if DB.moduleModes then DB.moduleModes.RangeRings = nil end
		end
		if prev < 41 then
			boxes.RunObjectives   = NS.DeepCopy(defBoxes.RunObjectives)
			boxes.EventBanner     = NS.DeepCopy(defBoxes.EventBanner)
			boxes.ClassExtra      = NS.DeepCopy(defBoxes.ClassExtra)
			boxes.SummonTracker   = NS.DeepCopy(defBoxes.SummonTracker)
			boxes.HolidayCurrency = NS.DeepCopy(defBoxes.HolidayCurrency)
		end
		if prev < 42 then
			DB.bgAlpha, DB.borderAlpha = 0.00, 0.00
			for _, cfg in pairs(boxes) do
				if type(cfg) == "table" then cfg.alpha = 0.00 end
			end
		end
		if prev < 43 then
			DB.fontSize = 11
			if boxes.EliteTimer then
				boxes.EliteTimer.width = max(boxes.EliteTimer.width or 0, 236)
				boxes.EliteTimer.height = max(boxes.EliteTimer.height or 0, 138)
			end
			if boxes.LootPanel then
				boxes.LootPanel.height = max(boxes.LootPanel.height or 0, 208)
			end
		end
		if prev < 44 then
			if not (NS.THEMES and NS.THEMES[DB.theme]) then DB.theme = "classic" end
		end
		DB.layoutVersion = NS.LAYOUT_VERSION
	end
	NS.SyncLegacyFlagsFromModules()
	if NS.ApplyTheme then NS.ApplyTheme(DB.theme, true) end
	DB.locked = true
end

function NS.ResetAllToDefaults()
	_G.AZS_MinimalUI_DB = NS.CopyDefaults(NS.DEFAULTS, {})
	NS.DB = _G.AZS_MinimalUI_DB
	NS.SyncLegacyFlagsFromModules()
	if NS.ApplyTheme then NS.ApplyTheme(NS.DB.theme, true) end
	NS.DB.locked = true
end
