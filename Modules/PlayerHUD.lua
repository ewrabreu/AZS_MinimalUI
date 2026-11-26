local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local max, min, tonumber, tostring, type = math.max, math.min, tonumber, tostring, type
local fmt = string.format
local UnitHealth, UnitHealthMax, UnitLevel, GetSpellInfo = UnitHealth, UnitHealthMax, UnitLevel, GetSpellInfo
local COLORS, SetText, GetSpellIcon, FormatNumber = NS.COLORS, NS.SetText, NS.GetSpellIcon, NS.FormatNumber

local TEX_HEART_RED  = NS.Media("icon-heart-red")
local TEX_HEART_BLUE = NS.Media("icon-heart-blue")

local PlayerHUD = CreateFrame("Frame", "AZS_MinUI_PlayerHUD", UIParent)
NS.RegisterMovableBox("PlayerHUD", "Center HUD (HP/XP/Skills)", PlayerHUD)

local HP_BAR_W, HP_BAR_H, HP_CASE_W, HP_CASE_H = 236, 22, 438, 112
local HPBackFrame = CreateFrame("Frame", nil, PlayerHUD)
HPBackFrame:SetSize(HP_BAR_W, HP_BAR_H)
HPBackFrame:SetPoint("TOP", PlayerHUD, "TOP", 0, -10)

local HPBar = CreateFrame("StatusBar", nil, PlayerHUD)
HPBar:SetSize(HP_BAR_W, HP_BAR_H)
HPBar:SetPoint("CENTER", HPBackFrame, "CENTER", 0, 0)
HPBar:SetFrameLevel(HPBackFrame:GetFrameLevel() + 1)
HPBar:SetStatusBarTexture(NS.Media("hp_cap_bar"))
HPBar:SetStatusBarColor(COLORS.health[1], COLORS.health[2], COLORS.health[3], 1)
HPBar:SetMinMaxValues(0, 100)
HPBar:SetValue(100)
HPBar.threatGlow = HPBackFrame:CreateTexture(nil, "BACKGROUND")
HPBar.threatGlow:SetSize(HP_CASE_W, HP_CASE_H)
HPBar.threatGlow:SetPoint("CENTER", HPBar, "CENTER", 0, -1)
HPBar.threatGlow:SetTexture(NS.Media("hp_cap_case_glow"))
HPBar.threatGlow:SetVertexColor(1, 0.15, 0.15, 0.9)
HPBar.threatGlow:Hide()
HPBar.case = HPBackFrame:CreateTexture(nil, "ARTWORK")
HPBar.case:SetSize(HP_CASE_W, HP_CASE_H)
HPBar.case:SetPoint("CENTER", HPBar, "CENTER", 0, -1)
HPBar.case:SetTexture(NS.Media("hp_cap_case"))
HPBar.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)

local ShieldBar = CreateFrame("StatusBar", nil, HPBar)
ShieldBar:SetAllPoints(HPBar)
ShieldBar:SetFrameLevel(HPBar:GetFrameLevel() + 1)
ShieldBar:SetStatusBarTexture(NS.Media("hp_cap_bar_highlight"))
ShieldBar:SetStatusBarColor(0.35, 0.82, 1.0, 0.65)
ShieldBar:Hide()

local HPTextFrame = CreateFrame("Frame", nil, HPBar)
HPTextFrame:SetAllPoints(HPBar)
HPTextFrame:SetFrameLevel(HPBar:GetFrameLevel() + 2)
HPBar.heartIcon = HPTextFrame:CreateTexture(nil, "OVERLAY")
HPBar.heartIcon:SetSize(22, 22)
HPBar.heartIcon:SetPoint("RIGHT", HPBar, "LEFT", -6, 0)
HPBar.heartIcon:SetTexture(TEX_HEART_RED)
HPBar.leftText = NS.CreateFontText(HPTextFrame, 0, "LEFT")
HPBar.leftText:SetPoint("LEFT", HPBar, "LEFT", 10, 1)
HPBar.rightText = NS.CreateFontText(HPTextFrame, 0, "RIGHT")
HPBar.rightText:SetPoint("RIGHT", HPBar, "RIGHT", -10, 1)

local ProcBar = CreateFrame("StatusBar", nil, PlayerHUD)
ProcBar:SetSize(176, 10)
ProcBar:SetPoint("TOP", HPBar, "BOTTOM", 0, -10)
ProcBar:SetFrameLevel(HPBar:GetFrameLevel() + 1)
ProcBar:SetStatusBarTexture(NS.Media("cast_bar"))
ProcBar:SetStatusBarColor(COLORS.normal[1], COLORS.normal[2], COLORS.normal[3], 0.95)
ProcBar:SetMinMaxValues(0, 1)
ProcBar:SetValue(0)
ProcBar.case = ProcBar:CreateTexture(nil, "BACKGROUND")
ProcBar.case:SetSize(303, 76)
ProcBar.case:SetPoint("CENTER", ProcBar, "CENTER", 1, -1)
ProcBar.case:SetTexture(NS.Media("cast_back"))
ProcBar.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
ProcBar.outline = ProcBar:CreateTexture(nil, "OVERLAY")
ProcBar.outline:SetSize(303, 76)
ProcBar.outline:SetPoint("CENTER", ProcBar, "CENTER", 1, -1)
ProcBar.outline:SetTexture(NS.Media("cast_back_outline"))
ProcBar.outline:SetVertexColor(1.0, 0.88, 0.45, 0.85)
ProcBar.outline:Hide()
ProcBar.txt = NS.CreateFontText(ProcBar, -2, "CENTER")
ProcBar.txt:SetPoint("CENTER", ProcBar, "CENTER", 0, 1)
ProcBar:Hide()

local XPBar = CreateFrame("StatusBar", nil, PlayerHUD)
XPBar:SetSize(204, 11)
XPBar:SetPoint("TOP", HPBar, "BOTTOM", 0, -12)
XPBar:SetFrameLevel(HPBar:GetFrameLevel() + 1)
XPBar:SetStatusBarTexture(NS.Media("cast_bar"))
XPBar:SetStatusBarColor(0.62, 0.35, 0.98, 0.95)
XPBar:SetMinMaxValues(0, 100)
XPBar:SetValue(0)
XPBar.case = XPBar:CreateTexture(nil, "BACKGROUND")
XPBar.case:SetSize(350, 78)
XPBar.case:SetPoint("CENTER", XPBar, "CENTER", 1, -2)
XPBar.case:SetTexture(NS.Media("cast_back_spiked"))
XPBar.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
XPBar.txt = NS.CreateFontText(XPBar, -2, "CENTER")
XPBar.txt:SetPoint("CENTER", XPBar, "CENTER", 0, 1)

local MAX_SPELL_SLOTS, RING_SIZE, RING_STEP = 8, 34, 38
local SpellRow = CreateFrame("Frame", nil, PlayerHUD)
SpellRow:SetPoint("TOP", XPBar, "BOTTOM", 0, -16)
SpellRow:SetSize(MAX_SPELL_SLOTS * RING_STEP, RING_SIZE)
local SpellSlots = {}
for i = 1, MAX_SPELL_SLOTS do
	local btn, iconSz = NS.CreateActionRingButton(SpellRow, RING_SIZE)
	btn:SetPoint("CENTER", SpellRow, "CENTER", 0, 0)
	btn.cdOverlay = btn:CreateTexture(nil, "ARTWORK")
	btn.cdOverlay:SetPoint("BOTTOM", btn.icon, "BOTTOM", 0, 0)
	btn.cdOverlay:SetSize(iconSz, 0.1)
	btn.cdOverlay:SetTexture(NS.Media("blank"))
	btn.cdOverlay:SetVertexColor(0, 0, 0, 0.72)
	if btn.cdOverlay.SetMask then btn.cdOverlay:SetMask(NS.Media("actionbutton-mask-circular")) end
	btn.cdOverlay:Hide()
	btn.cdText = NS.CreateFontText(btn.overlay, -1, "CENTER")
	btn.cdText:SetPoint("CENTER", btn, "CENTER", 0, 0)
	btn.rankText = NS.CreateFontText(btn.overlay, -2, "RIGHT")
	btn.rankText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
	btn:Hide()
	SpellSlots[i] = btn
end

local lastProcVisible, lastSpellCount, lastHasShield = nil, -1, nil
local function UpdateAnchors(hasProc)
	if lastProcVisible == hasProc then return end
	lastProcVisible = hasProc
	local spacing = (NS.DB and NS.DB.xpBarSpacing) or 12
	XPBar:ClearAllPoints()
	if hasProc then
		ProcBar:Show()
		XPBar:SetPoint("TOP", ProcBar, "BOTTOM", 0, -spacing)
	else
		ProcBar:Hide()
		XPBar:SetPoint("TOP", HPBar, "BOTTOM", 0, -(spacing + 2))
	end
end

local Mod = { frame = PlayerHUD }
function Mod.ResetCache() lastProcVisible, lastSpellCount, lastHasShield = nil, -1, nil end

function Mod.Update(ctx)
	local run, stats = ctx.run, ctx.stats
	local hp  = (run and tonumber(run.hp)) or UnitHealth("player") or 100
	local hpm = max(1, (run and tonumber(run.hpm)) or UnitHealthMax("player") or 100)
	local hpPct = (hp / hpm) * 100
	ctx.hpPct = hpPct
	if NS.IsBoxHidden("PlayerHUD") and not ctx.isEditing then return end

	local totalShield = ((run and tonumber(run.sh)) or 0) + ((run and tonumber(run.bsh)) or 0)
	HPBar:SetMinMaxValues(0, hpm)
	HPBar:SetValue(hp)
	if hpPct <= 35 then HPBar.threatGlow:Show() else HPBar.threatGlow:Hide() end

	local hasShield = totalShield > 0
	if lastHasShield ~= hasShield then
		lastHasShield = hasShield
		HPBar.heartIcon:SetTexture(hasShield and TEX_HEART_BLUE or TEX_HEART_RED)
		if hasShield then ShieldBar:Show() else ShieldBar:Hide() end
	end
	if hasShield then
		ShieldBar:SetMinMaxValues(0, hpm)
		ShieldBar:SetValue(min(hpm, totalShield))
		SetText(HPBar.leftText, fmt("%s |cff66ccff(+%s)|r", FormatNumber(hp), FormatNumber(totalShield)))
	else
		SetText(HPBar.leftText, fmt("%s / %s", FormatNumber(hp), FormatNumber(hpm)))
	end

	local lives = (run and tonumber(run.lives)) or (stats and tonumber(stats.liv)) or 0
	SetText(HPBar.rightText, lives > 0 and fmt("|cffffea89%dx|r %.0f%%", lives, hpPct) or fmt("%.0f%%", hpPct))

	local pm = run and tonumber(run.pm)
	local hasProc = (run and run.proc and pm and pm > 0) and true or false
	UpdateAnchors(hasProc)
	if hasProc then
		local pv = tonumber(run.pv) or 0
		ProcBar:SetMinMaxValues(0, pm)
		ProcBar:SetValue(pv)
		SetText(ProcBar.txt, fmt("%s: %d/%d", GetSpellInfo(tonumber(run.proc) or 0) or tostring(run.proc), pv, pm))
		if pv >= pm then ProcBar.outline:Show() else ProcBar.outline:Hide() end
	end

	local xp  = (run and tonumber(run.xp)) or 0
	local xpn = max(1, (run and tonumber(run.xpn)) or 100)
	local lvl = (run and tonumber(run.lvl)) or UnitLevel("player") or 1
	XPBar:SetMinMaxValues(0, xpn)
	XPBar:SetValue(xp)
	SetText(XPBar.txt, fmt("Level %d  (%.0f%%)", lvl, (xp / xpn) * 100))

	local spells = _G.AZS_SPELLS
	local hasSpells = (type(spells) == "table")
	local activeCount = hasSpells and min(MAX_SPELL_SLOTS, #spells) or 0
	if activeCount ~= lastSpellCount then
		lastSpellCount = activeCount
		local totalW = max(RING_SIZE, (activeCount - 1) * RING_STEP + RING_SIZE)
		local startX = -totalW * 0.5 + RING_SIZE * 0.5
		for i = 1, activeCount do
			local slot = SpellSlots[i]
			slot:ClearAllPoints()
			slot:SetPoint("CENTER", SpellRow, "CENTER", startX + (i - 1) * RING_STEP, 0)
		end
	end
	for i = 1, MAX_SPELL_SLOTS do
		local slot = SpellSlots[i]
		local sp = hasSpells and spells[i] or nil
		if sp then
			local icon = GetSpellIcon(sp.spell)
			if slot._icon ~= icon then slot._icon = icon; slot.icon:SetTexture(icon) end
			SetText(slot.rankText, "|cffffea89" .. tostring(sp.rank or 1) .. "|r")
			local cd = tonumber(sp.cd) or 0
			if cd > 0.05 then
				local frac = min(1.0, cd / max(0.1, tonumber(sp.cdmax) or 1))
				slot.cdOverlay:SetHeight(max(1, (slot.iconSize or 23) * frac))
				slot.cdOverlay:Show()
				SetText(slot.cdText, fmt("%.1f", cd))
				slot.highlight:Hide()
			else
				slot.cdOverlay:Hide()
				SetText(slot.cdText, "")
				slot.highlight:Show()
			end
			slot:Show()
		elseif slot:IsShown() then
			slot:Hide()
		end
	end
end

NS.Modules.PlayerHUD = Mod
