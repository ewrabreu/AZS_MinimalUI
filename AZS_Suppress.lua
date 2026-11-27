local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local type, pairs, pcall, select = type, pairs, pcall, select
local lower, find, sub, match = string.lower, string.find, string.sub, string.match
local min = math.min
local InCombatLockdown, UIParent, WorldFrame = InCombatLockdown, UIParent, WorldFrame

local HiddenParent = CreateFrame("Frame", "AZS_MinUI_HiddenParent")
HiddenParent._azsMinUI = true
HiddenParent:Hide()

local AZSUI_MODULE_MAP = {
	SurvivorsBossBar = "BossBar", SurvivorsTargetDebuffs = "BossBar", TargetFrame = "BossBar",
	ToTFrame = "BossBar", BossFrames = "BossBar", FocusFrame = "BossBar",
	PlayerFrame = "PlayerHUD", PlayerFrameAlternate = "PlayerHUD", PlayerCastBarFrame = "PlayerHUD",
	PlayerClassPowerFrame = "PlayerHUD", PetFrame = "PlayerHUD", SurvivorsPower = "PlayerHUD",
	ActionBars = "PlayerHUD", PetBar = "PlayerHUD", StanceBar = "PlayerHUD",
	ExtraActionButtons = "PlayerHUD", VehicleExit = "PlayerHUD", EncounterBar = "PlayerHUD",
	Info = "TopBar", PlayerStatusBars = "TopBar", UIWidgetTopCenter = "TopBar",
	UIWidgetBelowMinimap = "TopBar", Tracker = "TopBar", Durability = "TopBar", MirrorTimers = "TopBar",
	SurvivorsReviveBar = "StoredBadge",
	PartyFrames = "PlayerHUD", RaidFrame5 = "PlayerHUD", RaidFrame25 = "PlayerHUD",
	RaidFrame40 = "PlayerHUD", ArenaFrames = "PlayerHUD",
	Auras = "PlayerHUD", SurvivorsResources = "LootPanel",
	NamePlates = "Nameplates", NamePlatesClassic = "Nameplates", SurvivorsTombMarks = "Nameplates",
	Minimap = "Minimap",
}

local SplitCSV, SplitSet = NS.SplitCSV, NS.SplitSet
local EXACT_AZSUI_GROUPS = {
	PlayerHUD   = SplitCSV("UnitFramePlayer,UnitFramePlayerAlternate,UnitFramePlayerCastBar,UnitFramePlayerClassPower,UnitFramePet,SurvivorsPower,ActionBar1,ActionBar2,ActionBar3,ActionBar4,ActionBar5,ActionBar6,ActionBar7,ActionBar8,PetBar,StanceBar,VehicleExitButton,UnitFrameParty,UnitFrameRaid5,UnitFrameRaid25,UnitFrameRaid40,ArenaEnemyFrames"),
	BossBar     = SplitCSV("SurvivorsBossBar,UnitFrameTarget,UnitFrameTargetTarget,UnitFrameFocus,UnitFrameBoss1,UnitFrameBoss2,UnitFrameBoss3,UnitFrameBoss4,UnitFrameBoss5"),
	LootPanel   = { "SurvivorsResources" },
	StoredBadge = { "SurvivorsReviveBar" },
	TopBar      = SplitCSV("MinimapStatusButton,StatusTrackingBar,StatusTrackingBarBonusBar,TopCenterWidgets,BelowMinimapWidgets"),
}
for _, list in pairs(EXACT_AZSUI_GROUPS) do
	for i = 1, #list do list[i] = "AzerothSurvivors" .. list[i] end
end

local BLIZZ_GROUPS = {
	TopBar      = SplitCSV("ZoneTextFrame,SubZoneTextFrame"),
	BossBar     = SplitCSV("Boss1TargetFrame,Boss2TargetFrame,Boss3TargetFrame,Boss4TargetFrame"),
	PlayerHUD   = SplitCSV("MainMenuBar,MainMenuBarArtFrame,MainMenuExpBar,ReputationWatchBar,MainMenuMaxLevelBar0,MainMenuMaxLevelBar1,MainMenuMaxLevelBar2,MainMenuMaxLevelBar3,ExhaustionTick,MainMenuBarPerformanceBarFrame,BonusActionBarFrame,VehicleMenuBar,PossessBarFrame,VehicleSeatIndicator,MultiBarBottomLeft,MultiBarBottomRight,MultiBarRight,MultiBarLeft,ShapeshiftBarFrame,PetActionBarFrame,MainMenuBarBackpackButton,CharacterBag0Slot,CharacterBag1Slot,CharacterBag2Slot,CharacterBag3Slot,KeyRingButton,CharacterMicroButton,SpellbookMicroButton,TalentMicroButton,AchievementMicroButton,QuestLogMicroButton,SocialsMicroButton,PVPMicroButton,LFDMicroButton,MainMenuMicroButton,HelpMicroButton,PlayerFrame,PetFrame,TargetFrame,TargetFrameToT,FocusFrame,FocusFrameToT,ComboFrame,RuneFrame,TotemFrame,CastingBarFrame,PetCastingBarFrame,MirrorTimer1,MirrorTimer2,MirrorTimer3,WatchFrame,QuestWatchFrame,DurabilityFrame,PartyMemberFrame1,PartyMemberFrame2,PartyMemberFrame3,PartyMemberFrame4,BuffFrame,TemporaryEnchantFrame,ConsolidatedBuffs"),
}

local ALWAYS_SHOW_ON_RESTORE = SplitSet("PlayerFrame,MainMenuBar,MainMenuBarArtFrame,MainMenuExpBar,BuffFrame,MainMenuBarBackpackButton,CharacterMicroButton,SpellbookMicroButton,TalentMicroButton,AchievementMicroButton,QuestLogMicroButton,SocialsMicroButton,PVPMicroButton,LFDMicroButton,MainMenuMicroButton,HelpMicroButton")
local CHAT_FRAMES = SplitCSV("ChatFrame1,ChatFrame2,ChatFrame3,ChatFrame4,ChatFrame1Tab,ChatFrame2Tab,ChatFrame3Tab,ChatFrame4Tab,ChatFrameMenuButton,FriendsMicroButton,GeneralDockManager")
local SINGLE_KEYS = SplitCSV("frame,header,bar,anchor,button")
local LIST_KEYS   = SplitCSV("bars,units,rows,icons")
local SAFE_STRATA = SplitSet("HIGH,DIALOG,FULLSCREEN,FULLSCREEN_DIALOG,TOOLTIP")
local SAFE_NAME_PATTERNS = SplitCSV("azs_minui,micromenu,gamemenu,interfaceoptions,videooptions,audiooptions,keybinding,staticpopup,chatframe,minimap,tooltip,dropdown,characterframe,spellbook,talent,quest,worldmap,container,merchant,bankframe,mailframe,friendsframe,guildframe,macroframe,helpframe,uierrors,raidwarning,lfg,pvpframe,achievement,calendar,timemanager,screen,picker,choice,levelup,upgrade,shop,vendor,dialog,popup,modal,menu,options,config,edit,controller,mount,bag,alert,grouploot,lootframe,summary,reward,endrun,death,blizzard,movieframe,cinematic,worldstate,zonetext")
local AZSUI_NAME_PATTERNS = SplitCSV("^azerothsurvivors,^azsui,^azeriteui,^azerite,^ouf_azs,^ouf_azerite")

local function WantsModOriginal(modKey)
	if not NS.DB then return false end
	if modKey == "LootPanel" and NS.DB.loot and NS.DB.loot.keepNativeLoot then return false end
	return NS.GetModuleMode(modKey) == "original"
end

local OriginalParents, SuppressedFrames = {}, {}
local function SuppressBlizzardFrame(frameName)
	local f = _G[frameName]
	if not f or SuppressedFrames[f] then return end
	if InCombatLockdown() and f.IsProtected and f:IsProtected() then
		if f.SetAlpha then pcall(f.SetAlpha, f, 0) end
		return
	end
	if not OriginalParents[f] and f.GetParent then
		local ok, p = pcall(f.GetParent, f)
		OriginalParents[f] = (ok and p and p ~= HiddenParent) and p or UIParent
	end
	if f.SetParent then pcall(f.SetParent, f, HiddenParent) end
	if f.EnableMouse then pcall(f.EnableMouse, f, false) end
	SuppressedFrames[f] = true
end

local function RestoreBlizzardFrame(frameName)
	local f = _G[frameName]
	if not f or not SuppressedFrames[f] then return end
	if InCombatLockdown() and f.IsProtected and f:IsProtected() then return end
	if f.SetParent then pcall(f.SetParent, f, OriginalParents[f] or UIParent) end
	if f.SetAlpha then pcall(f.SetAlpha, f, 1) end
	if f.EnableMouse then pcall(f.EnableMouse, f, true) end
	if ALWAYS_SHOW_ON_RESTORE[frameName] and f.Show then
		pcall(f.Show, f)
	else
		local partyIdx = match(frameName, "^PartyMemberFrame(%d)$")
		if partyIdx and UnitExists("party" .. partyIdx) and f.Show then pcall(f.Show, f) end
	end
	SuppressedFrames[f] = nil
end

local AZS_PART_TO_MODULE = {}
for i = 1, #NS.MODULE_DEFS do
	local def = NS.MODULE_DEFS[i]
	if def.azsParts then
		for j = 1, #def.azsParts do AZS_PART_TO_MODULE[def.azsParts[j]] = def.key end
	end
end

local applyingOurSuppress, azsHudHookInstalled = false, false
local function ShouldKeepAZSPart(part, modKey)
	if not NS.DB then return false end
	if part == "loot" and NS.DB.loot and NS.DB.loot.keepNativeLoot then return true end
	return NS.GetModuleMode(modKey) == "original"
end

function NS.EnsureAZSConflictBridge()
	if azsHudHookInstalled or type(_G.AZS_SetHudShown) ~= "function" then return end
	azsHudHookInstalled = true
	hooksecurefunc("AZS_SetHudShown", function(part, shown)
		if applyingOurSuppress or not shown then return end
		local modKey = AZS_PART_TO_MODULE[part]
		if modKey and NS.DB and not ShouldKeepAZSPart(part, modKey) then
			applyingOurSuppress = true
			pcall(_G.AZS_SetHudShown, part, false)
			applyingOurSuppress = false
		end
	end)
end

local AZSUI_Suppressed, PendingCombatSuppress, GuardedAZSModules = {}, {}, {}
local SafeFrameCache = setmetatable({}, { __mode = "k" })
local lastUIParentChildren = -1

local function IsOurOwnFrame(f)
	if not f or f == HiddenParent or f == UIParent or f == WorldFrame or f._azsMinUI then return true end
	local name = f.GetName and f:GetName()
	if type(name) == "string" and sub(name, 1, 10) == "AZS_MinUI_" then f._azsMinUI = true; return true end
	return false
end

local function SuppressTargetFrame(f, modKey, inCombat)
	if not f or type(f) ~= "table" or IsOurOwnFrame(f) or f == _G.Minimap or f == _G.MinimapCluster then return end
	if inCombat and f.IsProtected and f:IsProtected() then
		if not PendingCombatSuppress[f] then
			PendingCombatSuppress[f] = { modKey = modKey, origAlpha = (f.GetAlpha and f:GetAlpha()) or 1 }
		end
		if f.SetAlpha then pcall(f.SetAlpha, f, 0) end
		return
	end
	if AZSUI_Suppressed[f] then
		if f.GetParent and f:GetParent() ~= HiddenParent and f.SetParent then pcall(f.SetParent, f, HiddenParent) end
		if f.IsShown and f:IsShown() and f.Hide then pcall(f.Hide, f) end
		return
	end
	local hadUnitWatch = false
	if type(_G.UnitWatchRegistered) == "function" then
		local okW, reg = pcall(_G.UnitWatchRegistered, f)
		if okW and reg then hadUnitWatch = true end
	end
	if type(_G.UnregisterUnitWatch) == "function" then pcall(_G.UnregisterUnitWatch, f) end
	if type(_G.UnregisterStateDriver) == "function" then
		pcall(_G.UnregisterStateDriver, f, "vis")
		pcall(_G.UnregisterStateDriver, f, "visibility")
	end
	local origParent = (f.GetParent and f:GetParent()) or UIParent
	if origParent == HiddenParent then origParent = UIParent end
	local origAlpha = (PendingCombatSuppress[f] and PendingCombatSuppress[f].origAlpha) or (f.GetAlpha and f:GetAlpha()) or 1
	PendingCombatSuppress[f] = nil
	if f.SetParent then pcall(f.SetParent, f, HiddenParent) end
	if f.EnableMouse then pcall(f.EnableMouse, f, false) end
	if f.Hide then pcall(f.Hide, f) end
	if f.SetAlpha then pcall(f.SetAlpha, f, 0) end
	AZSUI_Suppressed[f] = { parent = origParent, modKey = modKey, origAlpha = origAlpha, wasUnitWatch = hadUnitWatch }
end

local function RestoreTargetFrame(f, info, inCombat)
	if not f or not info then return end
	if inCombat and f.IsProtected and f:IsProtected() then return end
	if f.SetParent then pcall(f.SetParent, f, info.parent or UIParent) end
	if f.SetAlpha then pcall(f.SetAlpha, f, info.origAlpha or 1) end
	if f.EnableMouse then pcall(f.EnableMouse, f, true) end
	if info.wasUnitWatch and type(_G.RegisterUnitWatch) == "function" then pcall(_G.RegisterUnitWatch, f)
	elseif f.Show then pcall(f.Show, f) end
	AZSUI_Suppressed[f] = nil
end

local cachedAZSUI
local function GetAzerothSurvivorsUI()
	if cachedAZSUI then return cachedAZSUI end
	local azsUI = _G.AzerothSurvivorsUI
	if type(azsUI) == "table" then cachedAZSUI = azsUI; return azsUI end
	if type(_G.LibStub) == "table" or type(_G.LibStub) == "function" then
		local ok, AceAddon = pcall(_G.LibStub, "AceAddon-3.0", true)
		if ok and type(AceAddon) == "table" and type(AceAddon.GetAddon) == "function" then
			local ok2, addon = pcall(AceAddon.GetAddon, AceAddon, "AzerothSurvivorsUI", true)
			if ok2 and type(addon) == "table" then cachedAZSUI = addon; return addon end
		end
	end
end

local function SuppressAZSModuleFrames(modObj, modKey, inCombat)
	if type(modObj) ~= "table" then return end
	if type(modObj.frame) == "table" and type(modObj.frame.driver) == "table" then
		pcall(modObj.frame.driver.SetScript, modObj.frame.driver, "OnUpdate", nil)
		pcall(modObj.frame.driver.Hide, modObj.frame.driver)
	end
	if type(modObj.KillsTimer) == "table" then
		pcall(modObj.KillsTimer.SetScript, modObj.KillsTimer, "OnUpdate", nil)
		pcall(modObj.KillsTimer.Hide, modObj.KillsTimer)
	end
	for i = 1, #SINGLE_KEYS do
		local f = modObj[SINGLE_KEYS[i]]
		if type(f) == "table" and f.GetObjectType then SuppressTargetFrame(f, modKey, inCombat) end
	end
	for i = 1, #LIST_KEYS do
		local tbl = modObj[LIST_KEYS[i]]
		if type(tbl) == "table" then
			for _, item in pairs(tbl) do
				if type(item) == "table" then
					if item.GetObjectType then SuppressTargetFrame(item, modKey, inCombat)
					elseif type(item.frame) == "table" and item.frame.GetObjectType then SuppressTargetFrame(item.frame, modKey, inCombat) end
				end
			end
		end
	end
	if type(modObj.marks) == "table" then
		for _, mark in pairs(modObj.marks) do
			if type(mark) == "table" and mark.Hide then pcall(mark.Hide, mark) end
		end
	end
end

local function WrapMethod(modObj, field, modKey, hideFrame)
	local orig = modObj[field]
	if type(orig) ~= "function" then return end
	modObj[field] = function(self, ...)
		if not WantsModOriginal(modKey) then
			if hideFrame and self.frame and self.frame.Hide then pcall(self.frame.Hide, self.frame) end
			return
		end
		return orig(self, ...)
	end
end

local function ClassifyUnitFrameMod(lowName)
	if find(lowName, "boss", 1, true) or find(lowName, "target", 1, true) or find(lowName, "focus", 1, true) then return "BossBar"
	elseif find(lowName, "resource", 1, true) or find(lowName, "currency", 1, true) then return "LootPanel"
	elseif find(lowName, "revive", 1, true) then return "StoredBadge"
	elseif find(lowName, "status", 1, true) or find(lowName, "widget", 1, true) then return "TopBar" end
	return "PlayerHUD"
end

local function GuardAndDisableAZSUIModules(inCombat, fullPass)
	local azsUI = GetAzerothSurvivorsUI()
	if not azsUI then return end
	if not inCombat and type(_G.AZS_SetEditorActionBarsHidden) == "function" then
		pcall(_G.AZS_SetEditorActionBarsHidden, not WantsModOriginal("PlayerHUD"))
	end
	for modName, modKey in pairs(AZSUI_MODULE_MAP) do
		local modObj
		if type(azsUI.GetModule) == "function" then
			local ok, m = pcall(azsUI.GetModule, azsUI, modName, true)
			if ok and type(m) == "table" then modObj = m end
		elseif type(azsUI.modules) == "table" then
			modObj = azsUI.modules[modName]
		end
		if modObj then
			local wantOrig = WantsModOriginal(modKey)
			if not wantOrig then
				local wasGuarded = GuardedAZSModules[modObj]
				if not wasGuarded then
					GuardedAZSModules[modObj] = true
					WrapMethod(modObj, "OnEnable", modKey, false)
					WrapMethod(modObj, "Update", modKey, true)
					WrapMethod(modObj, "UpdateBar", modKey, true)
					WrapMethod(modObj, "UpdateBars", modKey, false)
				end
				local isEn = type(modObj.IsEnabled) == "function" and modObj:IsEnabled()
				if fullPass or not wasGuarded or isEn then
					if type(modObj.SetEnabledState) == "function" then pcall(modObj.SetEnabledState, modObj, false) end
					if type(modObj.CancelAllTimers) == "function" then pcall(modObj.CancelAllTimers, modObj) end
					if type(modObj.UnregisterAllEvents) == "function" then pcall(modObj.UnregisterAllEvents, modObj) end
					if isEn and type(modObj.Disable) == "function" then pcall(modObj.Disable, modObj) end
					SuppressAZSModuleFrames(modObj, modKey, inCombat)
				end
			elseif fullPass then
				if type(modObj.SetEnabledState) == "function" then pcall(modObj.SetEnabledState, modObj, true) end
				if type(modObj.IsEnabled) == "function" and (not modObj:IsEnabled()) and type(modObj.Enable) == "function" then
					pcall(modObj.Enable, modObj)
				end
			end
		end
	end
	if type(azsUI.UnitFrames) == "table" then
		for uf in pairs(azsUI.UnitFrames) do
			if type(uf) == "table" and uf.GetObjectType then
				local uname = (uf.GetName and lower(uf:GetName() or "")) or ""
				local mKey = ClassifyUnitFrameMod(uname)
				if not WantsModOriginal(mKey) then SuppressTargetFrame(uf, mKey, inCombat) end
			end
		end
	end
end

local function IsSafeName(lowName)
	if not lowName or lowName == "" then return false end
	for i = 1, #SAFE_NAME_PATTERNS do
		if find(lowName, SAFE_NAME_PATTERNS[i], 1, true) then return true end
	end
	return false
end

local function MatchesAZSUIName(lowName)
	if not lowName or lowName == "" then return false end
	for i = 1, #AZSUI_NAME_PATTERNS do
		if find(lowName, AZSUI_NAME_PATTERNS[i]) then return true end
	end
	return false
end

local function PathIsAZSUI(texPath)
	if type(texPath) ~= "string" or texPath == "" then return false end
	local low = lower(texPath)
	return find(low, "azerothsurvivorsui", 1, true) ~= nil or find(low, "azeriteui", 1, true) ~= nil
end

local FrameFingerprint
local function CheckRegions(i, limit, ...)
	if i > limit then return false end
	local r = select(i, ...)
	if r and r.GetObjectType then
		local otype = r:GetObjectType()
		if otype == "Texture" and r.GetTexture and PathIsAZSUI(r:GetTexture()) then return true
		elseif otype == "FontString" and r.GetText then
			local txt = r:GetText()
			if type(txt) == "string" and txt ~= "" then
				local low = lower(txt)
				if find(low, "approaches", 1, true) or find(low, "se aproxima", 1, true) then return true end
			end
		end
	end
	return CheckRegions(i + 1, limit, ...)
end

local function CheckChildren(depth, i, limit, ...)
	if i > limit then return false end
	if FrameFingerprint(select(i, ...), depth) then return true end
	return CheckChildren(depth, i + 1, limit, ...)
end

FrameFingerprint = function(frame, depth)
	if not frame then return false end
	if frame.GetBackdrop then
		local ok, bd = pcall(frame.GetBackdrop, frame)
		if ok and type(bd) == "table" and (PathIsAZSUI(bd.bgFile) or PathIsAZSUI(bd.edgeFile)) then return true end
	end
	if frame.GetRegions then
		local n = frame:GetNumRegions()
		if n > 0 and CheckRegions(1, min(n, 32), frame:GetRegions()) then return true end
	end
	if depth < 2 and frame.GetChildren then
		local n = frame:GetNumChildren()
		if n > 0 and CheckChildren(depth + 1, 1, min(n, 18), frame:GetChildren()) then return true end
	end
	return false
end

local function InspectUIParentChild(f, inCombat, sw, sh)
	if not f or AZSUI_Suppressed[f] or SafeFrameCache[f] then return end
	if IsOurOwnFrame(f) then SafeFrameCache[f] = true; return end
	local strata = (f.GetFrameStrata and f:GetFrameStrata()) or "MEDIUM"
	if SAFE_STRATA[strata] then SafeFrameCache[f] = true; return end
	local rawName = f.GetName and f:GetName()
	local lowName = type(rawName) == "string" and lower(rawName) or ""
	if IsSafeName(lowName) then SafeFrameCache[f] = true; return end
	if MatchesAZSUIName(lowName) then
		local modKey = ClassifyUnitFrameMod(lowName)
		if not WantsModOriginal(modKey) then SuppressTargetFrame(f, modKey, inCombat) end
		return
	end
	local w, h = (f.GetWidth and f:GetWidth()) or 0, (f.GetHeight and f:GetHeight()) or 0
	local cx, cy = f:GetCenter()
	local isFull = (w >= sw * 0.72 and h >= sh * 0.72)
	local isCorner = (w > 0 and h > 0 and w <= 56 and h <= 56 and cx and cy and cx > (sw - 440) and cy < 110)
	if not isFull and not isCorner and (w >= 1 or h >= 12) then
		if FrameFingerprint(f, 0) then
			local modKey = ClassifyUnitFrameMod(lowName)
			if not WantsModOriginal(modKey) then SuppressTargetFrame(f, modKey, inCombat) end
		elseif f.IsShown and f:IsShown() then
			SafeFrameCache[f] = true
		end
	end
end

local function WalkChildren(inCombat, sw, sh, i, n, ...)
	if i > n then return end
	InspectUIParentChild(select(i, ...), inCombat, sw, sh)
	return WalkChildren(inCombat, sw, sh, i + 1, n, ...)
end

local function WalkUIParentFallback(inCombat, fullPass)
	local n = UIParent:GetNumChildren()
	if not fullPass and n == lastUIParentChildren then return end
	lastUIParentChildren = n
	if n > 0 then WalkChildren(inCombat, UIParent:GetWidth() or 1920, UIParent:GetHeight() or 1080, 1, n, UIParent:GetChildren()) end
end

function NS.ScanAndSuppressAZSUIFrames(fullPass)
	local inCombat = InCombatLockdown()
	if not inCombat then
		for f, pInfo in pairs(PendingCombatSuppress) do
			if not WantsModOriginal(pInfo.modKey) then SuppressTargetFrame(f, pInfo.modKey, false)
			else
				if f.SetAlpha then pcall(f.SetAlpha, f, pInfo.origAlpha or 1) end
				PendingCombatSuppress[f] = nil
			end
		end
	end
	for f, info in pairs(AZSUI_Suppressed) do
		if WantsModOriginal(info.modKey) then RestoreTargetFrame(f, info, inCombat) end
	end
	GuardAndDisableAZSUIModules(inCombat, fullPass ~= false)
	for modKey, list in pairs(EXACT_AZSUI_GROUPS) do
		if not WantsModOriginal(modKey) then
			for i = 1, #list do
				local f = _G[list[i]]
				if f then SuppressTargetFrame(f, modKey, inCombat) end
			end
		end
	end
	WalkUIParentFallback(inCombat, fullPass ~= false)
end

GuardAndDisableAZSUIModules(false, true)

function NS.ApplyNameplateCVar()
	local mode = NS.GetModuleMode("Nameplates")
	if mode == "minimal" or mode == "original" then
		if type(_G.ShowNameplates) == "function" then pcall(_G.ShowNameplates) end
		if type(_G.SetCVar) == "function" then pcall(_G.SetCVar, "nameplateShowEnemies", "1"); pcall(_G.SetCVar, "nameplateShowFriends", "0") end
	else
		if type(_G.HideNameplates) == "function" then pcall(_G.HideNameplates) end
		if type(_G.SetCVar) == "function" then pcall(_G.SetCVar, "nameplateShowEnemies", "0") end
	end
end

function NS.SuppressNativeAndBlizzardUI()
	NS.EnsureAZSConflictBridge()
	applyingOurSuppress = true
	for i = 1, #NS.MODULE_DEFS do
		local def = NS.MODULE_DEFS[i]
		local wantOriginal = (NS.GetModuleMode(def.key) == "original")
		if def.azsParts and type(_G.AZS_SetHudShown) == "function" then
			for j = 1, #def.azsParts do
				local part = def.azsParts[j]
				local keepPart = ShouldKeepAZSPart(part, def.key)
				if type(_G.AZS_IsHudShown) ~= "function" or _G.AZS_IsHudShown(part) ~= keepPart then
					pcall(_G.AZS_SetHudShown, part, keepPart)
				end
			end
		end
		local bGroup = BLIZZ_GROUPS[def.key]
		if bGroup then
			for j = 1, #bGroup do
				if wantOriginal then RestoreBlizzardFrame(bGroup[j]) else SuppressBlizzardFrame(bGroup[j]) end
			end
		end
	end
	applyingOurSuppress = false
	NS.ScanAndSuppressAZSUIFrames(true)
	if type(_G.SetCVar) == "function" then
		local dmgOrig = (NS.GetModuleMode("DamageFeed") == "original") and "1" or "0"
		pcall(_G.SetCVar, "CombatDamage", dmgOrig)
		pcall(_G.SetCVar, "CombatHealing", dmgOrig)
	end
	if NS.Modules.Minimap and NS.Modules.Minimap.ApplyMode then
		NS.Modules.Minimap.ApplyMode()
	elseif _G.MinimapCluster then
		if NS.GetModuleMode("Minimap") == "original" then _G.MinimapCluster:Show() else _G.MinimapCluster:Hide() end
	end
	local showChat = (NS.GetModuleMode("Chat") == "original")
	for i = 1, #CHAT_FRAMES do
		local cf = _G[CHAT_FRAMES[i]]
		if cf then cf:SetAlpha(showChat and 1 or 0); cf:EnableMouse(showChat) end
	end
	NS.ApplyNameplateCVar()
end
