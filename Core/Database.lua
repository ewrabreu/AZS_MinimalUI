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
	if DB.ranges  then DB.ranges.enabled  = (mm.RangeRings == "minimal") end
	DB.showWorldPins  = (mm.WorldPins  == "minimal")
	DB.showSideDamage = (mm.DamageFeed == "minimal")
	DB.hideMinimap    = (mm.Minimap    ~= "original")
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

local BETA_BOX_TO_FLAG = { BetaRunPace = "runPace" }
function NS.IsBoxHidden(boxKey)
	local betaFlag = BETA_BOX_TO_FLAG[boxKey]
	if betaFlag and not (NS.DB and NS.DB.beta and NS.DB.beta[betaFlag]) then return true end
	local modKey = NS.BOX_TO_MODULE and NS.BOX_TO_MODULE[boxKey]
	if modKey and NS.GetModuleMode(modKey) ~= "minimal" then return true end
	return NS.DB and NS.DB.hiddenBoxes and NS.DB.hiddenBoxes[boxKey] == true
end

local LEGACY_BOX_MODS = { "TopBar", "BossBar", "PlayerHUD", "StoredBadge", "StatsPanel", "MeterPanel" }
local V26_BOXES = { "PartyFrames", "PartyMeter", "PlayerBuffs", "PartyBuffs" }

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
			mm.RangeRings = (DB.ranges and DB.ranges.enabled == false) and "off" or "minimal"
			mm.WorldPins  = (DB.showWorldPins == false) and "off" or "minimal"
			mm.DamageFeed = (DB.showSideDamage == false) and "off" or "minimal"
			mm.Minimap    = (DB.hideMinimap == false) and "original" or "off"
			mm.Chat       = (DB.hideChat == false) and "original" or "off"
			for i = 1, #LEGACY_BOX_MODS do
				local k = LEGACY_BOX_MODS[i]
				if DB.hiddenBoxes and DB.hiddenBoxes[k] then mm[k] = "off" end
			end
		end
		if prev < 26 then
			for i = 1, #V26_BOXES do local k = V26_BOXES[i]; boxes[k] = NS.DeepCopy(defBoxes[k]) end
		end
		if prev < 27 then boxes.LootPanel = NS.DeepCopy(defBoxes.LootPanel) end
		if prev < 28 then boxes.BetaRunPace = NS.DeepCopy(defBoxes.BetaRunPace) end
		if prev < 29 and boxes.PartyFrames then
			if (boxes.PartyFrames.alpha or 0) <= 0.01 then boxes.PartyFrames.alpha = DB.bgAlpha or 0.72 end
			boxes.PartyFrames.width, boxes.PartyFrames.height = 246, 142
		end
		if prev < 30 then
			boxes.BetaStatCaps, boxes.BetaCenterArcs = nil, nil
			if boxes.BetaRunPace then
				boxes.BetaRunPace.width  = max(boxes.BetaRunPace.width or 0, 258)
				boxes.BetaRunPace.height = max(boxes.BetaRunPace.height or 0, 236)
			else
				boxes.BetaRunPace = NS.DeepCopy(defBoxes.BetaRunPace)
			end
		end
		if prev < 31 and boxes.BetaRunPace then
			boxes.BetaRunPace.height = max(boxes.BetaRunPace.height or 0, 300)
		end
		if prev < 32 then
			boxes.CooldownBuffs = NS.DeepCopy(defBoxes.CooldownBuffs)
			if boxes.PlayerBuffs then boxes.PlayerBuffs.height = max(boxes.PlayerBuffs.height or 0, 126) end
			if boxes.PartyBuffs then
				boxes.PartyBuffs.width  = max(boxes.PartyBuffs.width or 0, 232)
				boxes.PartyBuffs.height = max(boxes.PartyBuffs.height or 0, 148)
			end
		end
		if prev < 33 and boxes.StatsPanel then
			boxes.StatsPanel.height = max(boxes.StatsPanel.height or 0, 272)
		end
		DB.layoutVersion = NS.LAYOUT_VERSION
	end
	NS.SyncLegacyFlagsFromModules()
	DB.locked = true
end

function NS.ResetAllToDefaults()
	_G.AZS_MinimalUI_DB = NS.CopyDefaults(NS.DEFAULTS, {})
	NS.DB = _G.AZS_MinimalUI_DB
	NS.SyncLegacyFlagsFromModules()
	NS.DB.locked = true
end
