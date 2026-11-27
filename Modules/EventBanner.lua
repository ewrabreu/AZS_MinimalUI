local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local max, min, type, pcall, match, find, GetTime = math.max, math.min, type, pcall, string.match, string.find, GetTime
local COLORS, SetText = NS.COLORS, NS.SetText

local BannerFrame = CreateFrame("Frame", "AZS_MinUI_EventBanner", UIParent)
NS.RegisterMovableBox("EventBanner", "Event Banner", BannerFrame)
BannerFrame:EnableMouse(false)

local Pill = CreateFrame("Frame", nil, BannerFrame)
Pill:SetAllPoints(BannerFrame)

Pill.txt = NS.CreateFontText(Pill, 2, "CENTER")
Pill.txt:SetPoint("CENTER", Pill, "CENTER", 12, 0)
NS.SetNoWrap(Pill.txt, 22)

Pill.icon = Pill:CreateTexture(nil, "ARTWORK")
Pill.icon:SetSize(20, 20)
Pill.icon:SetPoint("RIGHT", Pill.txt, "LEFT", -6, 0)
Pill.icon:SetTexture(NS.Media("icon_badges_boss"))
Pill:Hide()

local activeText, activeKind, shownAt, showDuration = nil, nil, 0, 4.5
local hookedAZS = false

local KIND_STYLE = {
	boss  = { r = 1.00, g = 0.45, b = 0.14, icon = NS.Media("icon_badges_boss"),         hex = "|cffff9933" },
	rift  = { r = 0.76, g = 0.38, b = 1.00, icon = NS.Media("group-finder-eye-purple"),  hex = "|cffcc88ff" },
	event = { r = 0.00, g = 0.92, b = 0.78, icon = NS.OwnMedia("pin_diamond"),           hex = "|cff00ffcc" },
	info  = { r = 1.00, g = 0.84, b = 0.28, icon = NS.Media("icon_classification_boss"), hex = "|cffffea89" },
}

local function SyncKindTheme(th)
	if not (th and th.hex) then return end
	KIND_STYLE.boss.hex  = th.hex.boss or KIND_STYLE.boss.hex
	KIND_STYLE.rift.hex  = th.hex.rare or KIND_STYLE.rift.hex
	KIND_STYLE.event.hex = th.hex.accent or KIND_STYLE.event.hex
	KIND_STYLE.info.hex  = th.hex.title or KIND_STYLE.info.hex
end

local function TriggerBanner(msg)
	if type(msg) ~= "string" or msg == "" then return end
	if NS.GetModuleMode("EventBanner") ~= "minimal" then return end
	local text = match(msg, ";text=(.*)$") or msg
	local kind = match(msg, ";kind=([^;]*)") or (find(msg, ";kind=boss;", 1, true) and "boss" or "info")
	local name = match(msg, ";name=([^;]*)")
	if kind == "boss" and (not NS.DB or not NS.DB.banner or NS.DB.banner.playHorn ~= false) then
		if type(_G.AZS_BossHorn) == "function" then pcall(_G.AZS_BossHorn, name) end
	end
	if text and text ~= "" then
		activeText, activeKind, shownAt = text, kind, GetTime()
		showDuration = (kind == "boss") and 5.0 or 4.0
		local st = KIND_STYLE[kind] or KIND_STYLE.info
		Pill.icon:SetTexture(st.icon)
		SetText(Pill.txt, st.hex .. text .. "|r")
		Pill:SetAlpha(1.0)
		Pill:Show()
		BannerFrame:Show()
	end
end

local function EnsureHook()
	if hookedAZS then return end
	if type(_G.AZS) == "table" and type(_G.AZS.On) == "function" then
		hookedAZS = true
		_G.AZS.On("AZSBANNER", TriggerBanner)
	end
end
EnsureHook()

local Mod = { frame = BannerFrame }
function Mod.ApplyTheme(th) SyncKindTheme(th) end
function Mod.Update(ctx)
	EnsureHook()
	if NS.GetModuleMode("EventBanner") ~= "minimal" or NS.IsBoxHidden("EventBanner") then
		if not ctx.isEditing then
			Pill:Hide()
			if BannerFrame:IsShown() then BannerFrame:Hide() end
		end
		if NS.GetModuleMode("EventBanner") ~= "minimal" or not ctx.isEditing then return end
	end

	if activeText then
		local elapsed = ctx.now - shownAt
		if elapsed < showDuration then
			local alpha = 1.0
			if elapsed < 0.25 then alpha = elapsed / 0.25
			elseif elapsed > (showDuration - 0.8) then alpha = max(0, (showDuration - elapsed) / 0.8) end
			Pill:SetAlpha(min(1.0, alpha))
			Pill:Show()
			BannerFrame:Show()
			return
		end
		activeText = nil
	end

	if ctx.isEditing then
		local st = KIND_STYLE.boss
		Pill.icon:SetTexture(st.icon)
		SetText(Pill.txt, st.hex .. "Boss Approaches! (Banner Preview)|r")
		Pill:SetAlpha(1.0)
		Pill:Show()
		BannerFrame:Show()
	else
		Pill:Hide()
		if BannerFrame:IsShown() then BannerFrame:Hide() end
	end
end

NS.Modules.EventBanner = Mod
