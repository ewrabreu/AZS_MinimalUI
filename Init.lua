local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local type, pcall, tonumber, tostring = type, pcall, tonumber, tostring
local GetTime, SendAddonMessage, lower = GetTime, SendAddonMessage, string.lower

local UPDATE_ORDER = {
	"TopBar", "EventBanner", "BossBar", "PlayerHUD", "ClassExtra", "SummonTracker",
	"StoredBadge", "StatsPanel", "MeterPanel", "LootPanel", "RunObjectives",
	"HolidayCurrency", "Minimap", "EliteTimer", "Nameplates",
}
local SharedCtx, tickId = {}, 0

function NS.UpdateMinimalHUD()
	if not NS.DB then return end
	tickId = tickId + 1
	local zone, run = _G.AZS_ZONE, _G.AZS_RUN
	SharedCtx.tickId    = tickId
	SharedCtx.now       = GetTime()
	SharedCtx.zone      = zone
	SharedCtx.run       = run
	SharedCtx.inHub     = (not run) or (zone and tonumber(zone.hub) == 1) or false
	SharedCtx.runClock  = (type(_G.AZS_GetRunTime) == "function" and tonumber(_G.AZS_GetRunTime())) or (run and tonumber(run.t)) or 0
	SharedCtx.stats     = _G.AZS_STATS
	SharedCtx.runStats  = _G.AZS_RUNSTATS
	SharedCtx.caps      = (type(_G.AZS_GetStatCaps) == "function" and _G.AZS_GetStatCaps()) or _G.AZS_CAPS
	SharedCtx.isEditing = (not NS.DB.locked)
	SharedCtx.hpPct     = 100
	local M = NS.Modules
	for i = 1, #UPDATE_ORDER do
		local mod = M[UPDATE_ORDER[i]]
		if mod then mod.Update(SharedCtx) end
	end
end

SLASH_AZSMINIMALUI1 = "/minui"
SLASH_AZSMINIMALUI2 = "/azsui"
SlashCmdList["AZSMINIMALUI"] = function(msg)
	if not NS.DB then NS.InitializeDB() end
	msg = lower(tostring(msg or ""))
	if msg == "lock" then
		if NS.SetUnlockState then NS.SetUnlockState(false) end
	elseif msg == "unlock" or msg == "move" then
		if NS.SetUnlockState then NS.SetUnlockState(true) end
	elseif msg == "sync" then
		SendAddonMessage("AZSCMD", "sync", "PARTY")
	elseif msg == "suppress" or msg == "clean" then
		if NS.SuppressNativeAndBlizzardUI then NS.SuppressNativeAndBlizzardUI() end
	elseif msg == "classic" or msg == "tbc" or msg == "wotlk" or msg == "cataclysm" then
		if NS.ApplyTheme then NS.ApplyTheme(msg) end
	elseif string.sub(msg, 1, 6) == "theme " then
		local t = string.sub(msg, 7)
		if t == "bc" or t == "burning crusade" then t = "tbc"
		elseif t == "lk" or t == "lich king" then t = "wotlk"
		elseif t == "cata" then t = "cataclysm" end
		if NS.THEMES and NS.THEMES[t] and NS.ApplyTheme then NS.ApplyTheme(t) end
	else
		if NS.ToggleEditor then NS.ToggleEditor() end
	end
end

local MainDriver = CreateFrame("Frame", "AZS_MinUI_MainDriver")
MainDriver._azsMinUI = true
MainDriver:RegisterEvent("ADDON_LOADED")
MainDriver:RegisterEvent("PLAYER_LOGIN")
MainDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
MainDriver:RegisterEvent("PLAYER_REGEN_ENABLED")

local elapsedAccum, fastAccum, suppressSweepAccum, postLoginSuppress = 0, 0, 0, 0

MainDriver:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == NS.ADDON_NAME then
			NS.InitializeDB()
			if NS.ApplyTheme then NS.ApplyTheme(NS.DB.theme, true) end
			NS.RefreshAllLayouts()
			NS.SuppressNativeAndBlizzardUI()
		elseif (arg1 == "AzerothSurvivorsUI" or arg1 == "AzerothSurvivors") and NS.DB then
			NS.SuppressNativeAndBlizzardUI()
			postLoginSuppress = 1.5
		end
	elseif event == "PLAYER_LOGIN" then
		if not NS.DB then NS.InitializeDB() end
		NS.SuppressNativeAndBlizzardUI()
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not NS.DB then NS.InitializeDB() end
		if NS.SetUnlockState then NS.SetUnlockState(false) end
		NS.RefreshAllLayouts()
		NS.SuppressNativeAndBlizzardUI()
		postLoginSuppress = 1.5
		if type(_G.AZS_SetOnTopOfScreens) == "function" then
			if NS.MovableFrames.TopBar then pcall(_G.AZS_SetOnTopOfScreens, NS.MovableFrames.TopBar, true) end
			if NS.MovableFrames.StatsPanel then pcall(_G.AZS_SetOnTopOfScreens, NS.MovableFrames.StatsPanel, true) end
		end
		SendAddonMessage("AZSCMD", "sync", "PARTY")
		NS.UpdateMinimalHUD()
	elseif event == "PLAYER_REGEN_ENABLED" then
		NS.SuppressNativeAndBlizzardUI()
	end
end)

MainDriver:SetScript("OnUpdate", function(_, elapsed)
	if not NS.DB then return end
	elapsedAccum = elapsedAccum + elapsed
	fastAccum = fastAccum + elapsed
	suppressSweepAccum = suppressSweepAccum + elapsed
	if postLoginSuppress > 0 then
		postLoginSuppress = postLoginSuppress - elapsed
		if postLoginSuppress <= 0 then NS.SuppressNativeAndBlizzardUI() end
	end
	if suppressSweepAccum >= 1.0 then
		suppressSweepAccum = 0
		if NS.ScanAndSuppressAZSUIFrames then NS.ScanAndSuppressAZSUIFrames(false) end
	end
	if fastAccum >= 0.033 then
		fastAccum = 0
		local M = NS.Modules
		if M.DamageFeed then M.DamageFeed.UpdateFast() end
		if M.Nameplates then M.Nameplates.ScanAndUpdate() end
		if M.WorldPins and (GetTime() - (M.WorldPins.lastProjectedTime or 0)) > 0.25 then
			M.WorldPins.UpdateWorldProjection()
		end
	end
	if elapsedAccum >= 0.10 then
		elapsedAccum = 0
		NS.UpdateMinimalHUD()
	end
end)
