local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, max, min, sin, tonumber, tostring, type, pcall = math.floor, math.max, math.min, math.sin, tonumber, tostring, type, pcall
local fmt, lower, gsub = string.format, string.lower, string.gsub
local UnitHealth, UnitHealthMax, UnitLevel, UnitBuff, GetSpellInfo = UnitHealth, UnitHealthMax, UnitLevel, UnitBuff, GetSpellInfo
local UnitExists, UnitName, UnitClass, UnitIsConnected, UnitIsDeadOrGhost, GetNumPartyMembers =
	UnitExists, UnitName, UnitClass, UnitIsConnected, UnitIsDeadOrGhost, GetNumPartyMembers
local COLORS, Wipe, SetText, GetSpellIcon, ResolveIcon, FormatNumber, FormatShortTime, GetClassRGB =
	NS.COLORS, NS.Wipe, NS.SetText, NS.GetSpellIcon, NS.ResolveIcon, NS.FormatNumber, NS.FormatShortTime, NS.GetClassRGB
local BT = NS.BuffTracker

local TEX_HEART_RED  = NS.Media("icon-heart-red")
local TEX_SKULL      = NS.Media("icon_skull")
local TEX_CLASSES    = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local TEX_STEED      = "Interface\\Icons\\Ability_Mount_RidingHorse"
local TEX_DASH       = "Interface\\Icons\\Ability_Rogue_Sprint"
local TEX_POWER      = "Interface\\Icons\\INV_Misc_Gem_Bloodstone_02"
local TEX_BLANK      = NS.OwnMedia("blank")

local PlayerHUD = CreateFrame("Frame", "AZS_MinUI_PlayerHUD", UIParent)
NS.RegisterMovableBox("PlayerHUD", "Center HUD", PlayerHUD)

local HP_BAR_W, HP_BAR_H, HP_CASE_W, HP_CASE_H = 236, 22, 438, 112
local MAX_PARTY = 4
local P_BAR_W, P_BAR_H, P_GAP_X, P_GAP_Y = 112, 14, 12, 8
local P_CASE_W, P_CASE_H = 208, 71

local PartyStrip = CreateFrame("Frame", nil, PlayerHUD)
PartyStrip:SetPoint("TOP", PlayerHUD, "TOP", 0, -4)
PartyStrip:SetSize(P_BAR_W * 2 + P_GAP_X, P_BAR_H * 2 + P_GAP_Y)

local XPBar = CreateFrame("StatusBar", nil, PlayerHUD)
XPBar:SetSize(204, 11)
XPBar:SetPoint("TOP", PlayerHUD, "TOP", 0, -50)
XPBar:SetStatusBarTexture(NS.Media("cast_bar"))
XPBar:SetStatusBarColor(COLORS.xp[1], COLORS.xp[2], COLORS.xp[3], 0.95)
XPBar:SetMinMaxValues(0, 100)
XPBar:SetValue(0)
XPBar.case = XPBar:CreateTexture(nil, "BACKGROUND")
XPBar.case:SetSize(350, 78)
XPBar.case:SetPoint("CENTER", XPBar, "CENTER", 1, -2)
XPBar.case:SetTexture(NS.Media("cast_back_spiked"))
XPBar.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
XPBar.glow = XPBar:CreateTexture(nil, "OVERLAY")
XPBar.glow:SetSize(350, 78)
XPBar.glow:SetPoint("CENTER", XPBar, "CENTER", 1, -2)
XPBar.glow:SetTexture(NS.Media("cast_back_outline"))
XPBar.glow:SetVertexColor(1.0, 0.86, 0.20, 0.95)
XPBar.glow:Hide()
XPBar.txt = NS.CreateFontText(XPBar, 0, "CENTER")
XPBar.txt:SetPoint("CENTER", XPBar, "CENTER", 0, 1)
XPBar.clickBtn = CreateFrame("Button", nil, XPBar)
XPBar.clickBtn:SetAllPoints(XPBar)
XPBar.clickBtn:SetFrameLevel(XPBar:GetFrameLevel() + 3)
XPBar.clickBtn:RegisterForClicks("LeftButtonUp")
XPBar.clickBtn:SetScript("OnClick", function()
	if type(_G.AZS_OpenStoredLevels) == "function" then pcall(_G.AZS_OpenStoredLevels) end
end)
XPBar.clickBtn:SetScript("OnEnter", function(self)
	if not (GameTooltip and self._sl and self._sl > 0) then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(fmt("Stored Upgrades: +%d", self._sl), 1.0, 0.88, 0.25)
	if self._rr and self._rr > 0 then
		GameTooltip:AddLine(fmt("Rerolls available: %d", self._rr), 0.78, 0.86, 0.94)
	end
	GameTooltip:AddLine("Press [T] or Click to claim your upgrade!", 0.40, 1.0, 0.65)
	GameTooltip:Show()
end)
XPBar.clickBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
XPBar.clickBtn:EnableMouse(false)

local HPBackFrame = CreateFrame("Frame", nil, PlayerHUD)
HPBackFrame:SetSize(HP_BAR_W, HP_BAR_H)
HPBackFrame:SetPoint("TOP", XPBar, "BOTTOM", 0, -10)

local HPBar = CreateFrame("StatusBar", nil, PlayerHUD)
HPBar:SetSize(HP_BAR_W, HP_BAR_H)
HPBar:SetPoint("CENTER", HPBackFrame, "CENTER", 0, 0)
HPBar:SetFrameLevel(HPBackFrame:GetFrameLevel() + 1)
HPBar:SetStatusBarTexture(NS.OwnMedia("hp_sym_bar"))
HPBar:SetStatusBarColor(COLORS.health[1], COLORS.health[2], COLORS.health[3], 1)
HPBar:SetMinMaxValues(0, 100)
HPBar:SetValue(100)
HPBar.threatGlow = HPBackFrame:CreateTexture(nil, "BACKGROUND")
HPBar.threatGlow:SetSize(HP_CASE_W, HP_CASE_H)
HPBar.threatGlow:SetPoint("CENTER", HPBar, "CENTER", 0, -1)
HPBar.threatGlow:SetTexture(NS.OwnMedia("hp_sym_case_glow"))
HPBar.threatGlow:SetVertexColor(1, 0.15, 0.15, 0.9)
HPBar.threatGlow:Hide()
HPBar.case = HPBackFrame:CreateTexture(nil, "ARTWORK")
HPBar.case:SetSize(HP_CASE_W, HP_CASE_H)
HPBar.case:SetPoint("CENTER", HPBar, "CENTER", 0, -1)
HPBar.case:SetTexture(NS.OwnMedia("hp_sym_case"))
HPBar.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)

local ShieldBar = CreateFrame("StatusBar", nil, HPBar)
ShieldBar:SetAllPoints(HPBar)
ShieldBar:SetFrameLevel(HPBar:GetFrameLevel() + 1)
ShieldBar:SetStatusBarTexture(NS.OwnMedia("hp_sym_bar"))
ShieldBar:SetStatusBarColor(COLORS.shield[1], COLORS.shield[2], COLORS.shield[3], 0.92)
ShieldBar:Hide()

local HPTextFrame = CreateFrame("Frame", nil, HPBar)
HPTextFrame:SetAllPoints(HPBar)
HPTextFrame:SetFrameLevel(HPBar:GetFrameLevel() + 2)
HPBar.leftText = NS.CreateFontText(HPTextFrame, 2, "LEFT")
HPBar.leftText:SetPoint("LEFT", HPBar, "LEFT", 10, 1)
HPBar.rightText = NS.CreateFontText(HPTextFrame, 2, "RIGHT")
HPBar.rightText:SetPoint("RIGHT", HPBar, "RIGHT", -10, 1)
HPBar.immuneText = NS.CreateFontText(HPTextFrame, 2, "CENTER")
HPBar.immuneText:SetPoint("CENTER", HPBar, "CENTER", 0, 1)
HPBar.immuneText:Hide()

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
ProcBar.txt = NS.CreateFontText(ProcBar, 0, "CENTER")
ProcBar.txt:SetPoint("CENTER", ProcBar, "CENTER", 0, 1)
ProcBar:Hide()

local function ApplyClassCrest(tex, cls)
	local coords = cls and _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[cls]
	if coords then
		tex:SetTexture(TEX_CLASSES)
		tex:SetTexCoord(coords[1] + 0.03, coords[2] - 0.03, coords[3] + 0.03, coords[4] - 0.03)
		return
	end
	local genCls = cls and _G.AZS_GEN and _G.AZS_GEN.classByToken and _G.AZS_GEN.classByToken[cls]
	if genCls and genCls.classIcon then
		tex:SetTexture(ResolveIcon(genCls.classIcon))
		tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		return
	end
	tex:SetTexture(TEX_HEART_RED)
	tex:SetTexCoord(0, 1, 0, 1)
end

local SQ_SIZE, SQ_GAP, SQ_STEP = 34, 4, 38
local ORB_SIZE, ORB_GAP = 54, 10
local NUM_SKILLS, NUM_ITEMS = 6, 5
local ACTION_W = (NUM_SKILLS * SQ_SIZE + (NUM_SKILLS - 1) * SQ_GAP) * 2 + ORB_SIZE + ORB_GAP * 2

local ActionRow = CreateFrame("Frame", nil, PlayerHUD)
ActionRow:SetPoint("TOP", HPBar, "BOTTOM", 0, -12)
ActionRow:SetSize(ACTION_W, ORB_SIZE)

local ClassOrb = CreateFrame("Frame", nil, ActionRow)
ClassOrb:SetSize(ORB_SIZE, ORB_SIZE)
ClassOrb:SetPoint("CENTER", ActionRow, "CENTER", 0, 0)
ClassOrb:EnableMouse(true)
ClassOrb.ring = NS.CreateActionRingButton(ClassOrb, ORB_SIZE)
ClassOrb.ring:SetPoint("CENTER", ClassOrb, "CENTER", 0, 0)
ClassOrb.lvlTxt = NS.CreateFontText(ClassOrb.ring.overlay, -2, "CENTER")
ClassOrb.lvlTxt:SetPoint("BOTTOM", ClassOrb, "BOTTOM", 0, -1)

ClassOrb:SetScript("OnEnter", function(self)
	if not GameTooltip then return end
	local locCls, cls = UnitClass("player")
	local r, g, b = GetClassRGB(cls)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(fmt("%s · %s", UnitName("player") or "Hero", locCls or cls or ""), r, g, b)
	GameTooltip:AddLine(fmt("Level %d", self._lvl or UnitLevel("player") or 1), 0.78, 0.85, 0.92)
	if BT and BT.GetAllPlayerTalents then
		local tals = BT.GetAllPlayerTalents()
		if #tals > 0 then
			local byTree, order = {}, {}
			for i = 1, #tals do
				local tn = tals[i].treeName
				if tn and tn ~= "" then
					if not byTree[tn] then byTree[tn] = 0; order[#order + 1] = tn end
					byTree[tn] = byTree[tn] + (tals[i].rank or 1)
				end
			end
			if #order > 0 then
				local parts = {}
				for i = 1, #order do parts[i] = fmt("%s (%d)", order[i], byTree[order[i]]) end
				GameTooltip:AddLine("Talents: " .. table.concat(parts, " · "), 0.78, 0.58, 1.0, true)
			end
		end
	end
	local powers = _G.AZS_POWERS
	if type(powers) == "table" and #powers > 0 then
		GameTooltip:AddLine(" ")
		for i = 1, #powers do
			local pw = powers[i]
			if pw and pw.name then
				GameTooltip:AddLine(pw.name, 1.0, 0.55, 0.12)
				if pw.text and pw.text ~= "" then GameTooltip:AddLine(pw.text, 0.86, 0.88, 0.92, true) end
			end
		end
	end
	GameTooltip:Show()
end)
ClassOrb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

local function CreateSquareSlot(parent, isButton)
	local f = CreateFrame(isButton and "Button" or "Frame", nil, parent)
	f:SetSize(SQ_SIZE, SQ_SIZE)
	f:EnableMouse(true)
	NS.ApplyFlatBackdrop(f, { 0.04, 0.05, 0.08, 0.88 }, { 0.24, 0.28, 0.36, 0.85 })
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
	f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.icon:Hide()
	f.cdOverlay = f:CreateTexture(nil, "OVERLAY")
	f.cdOverlay:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMLEFT", 0, 0)
	f.cdOverlay:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", 0, 0)
	f.cdOverlay:SetHeight(1)
	f.cdOverlay:SetTexture(TEX_BLANK)
	f.cdOverlay:SetVertexColor(0, 0, 0, 0.72)
	f.cdOverlay:Hide()
	f.auraBorder = NS.AttachAuraBorder(f, 10, 4)
	f.txtLayer = CreateFrame("Frame", nil, f)
	f.txtLayer:SetAllPoints(f)
	f.txtLayer:SetFrameLevel(f:GetFrameLevel() + 4)
	f.cdText = NS.CreateFontText(f.txtLayer, 0, "CENTER")
	f.cdText:SetPoint("CENTER", f.txtLayer, "CENTER", 0, 0)
	f.rankText = NS.CreateFontText(f.txtLayer, -2, "RIGHT")
	f.rankText:SetPoint("BOTTOMRIGHT", f.txtLayer, "BOTTOMRIGHT", -2, 2)
	return f
end

local function HideTooltip() if GameTooltip then GameTooltip:Hide() end end

local function ShowSpellTooltip(self)
	if not GameTooltip then return end
	local spellId, spellKey = self._spellId, self._spellKey
	if (not spellId or spellId <= 0) and (not spellKey or spellKey == "") then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	local tips = _G.AZS_SPELLTIPS
	local tipText = (type(tips) == "table" and spellKey) and tips[spellKey] or nil
	local spellName = (type(_G.AZS_SpellName) == "function" and spellId and _G.AZS_SpellName(spellId))
		or (spellId and GetSpellInfo(spellId))
		or tostring(spellKey or "Skill")
	local rank = self._spellRank or 1
	local cdMax = self._spellCdMax or 0
	local cd = self._spellCd or 0
	if type(tipText) == "string" and tipText ~= "" then
		GameTooltip:SetText(spellName, 1, 1, 1)
		GameTooltip:AddDoubleLine(
			fmt("Rank %d", rank),
			cdMax > 0 and fmt("Cooldown: %.1fs", cdMax) or "",
			0.65, 0.72, 0.80, 0.45, 0.88, 1.0
		)
		GameTooltip:AddLine(tipText, 1, 0.82, 0, true)
	else
		local setOk = false
		if spellId and spellId > 0 then
			setOk = pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. spellId)
		end
		if not setOk or (GameTooltip:NumLines() or 0) == 0 then
			GameTooltip:SetText(spellName, 1, 1, 1)
		end
		if cdMax > 0 then
			GameTooltip:AddDoubleLine(fmt("Rank %d", rank), fmt("Cooldown: %.1fs", cdMax), 0.65, 0.72, 0.80, 0.45, 0.88, 1.0)
		elseif rank > 0 then
			GameTooltip:AddLine(fmt("Rank %d", rank), 0.65, 0.72, 0.80)
		end
	end
	if cd > 0.05 then
		GameTooltip:AddLine(fmt("Ready in: %.1fs", cd), 1.0, 0.45, 0.45)
	end
	local meterLines = NS.GetMeterCached()
	if type(meterLines) == "table" then
		for i = 1, #meterLines do
			local row = meterLines[i]
			if row and ((spellId and tonumber(row.spell) == spellId) or (row.name and row.name == spellName)) then
				local dmg = tonumber(row.dmg) or 0
				if dmg > 0 then
					GameTooltip:AddLine(" ")
					GameTooltip:AddDoubleLine(
						fmt("DPS: %s (%.0f%%)", FormatNumber(row.dps), (tonumber(row.share) or 0) * 100),
						fmt("Total: %s", FormatNumber(dmg)),
						0.00, 0.92, 0.78, 0.82, 0.88, 0.95
					)
				end
				break
			end
		end
	end
	GameTooltip:Show()
end

local SkillSlots = {}
for i = 1, NUM_SKILLS do
	local slot = CreateSquareSlot(ActionRow, false)
	local offsetFromOrb = ORB_SIZE * 0.5 + ORB_GAP + (NUM_SKILLS - i) * SQ_STEP + SQ_SIZE * 0.5
	slot:SetPoint("CENTER", ActionRow, "CENTER", -offsetFromOrb, 0)
	slot:SetScript("OnEnter", ShowSpellTooltip)
	slot:SetScript("OnLeave", HideTooltip)
	SkillSlots[i] = slot
end

local function ShowItemTooltip(self)
	if not GameTooltip or not self._gear then return end
	local g = self._gear
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	local hex = (BT and BT.GetRarityHex and BT.GetRarityHex(g.rarity)) or "ffffffff"
	GameTooltip:SetText(fmt("|c%s%s|r", hex, g.name or g.bonus or "Item"))
	local slotLbl = (BT and BT.GetSlotLabel and BT.GetSlotLabel(g.slot)) or tostring(g.slot or "Item")
	if g.slot == "amulet" and g.amount then
		slotLbl = slotLbl .. " · Rank " .. tostring(g.amount)
	end
	GameTooltip:AddLine(slotLbl, 0.65, 0.72, 0.80)
	if g.text and g.text ~= "" then
		GameTooltip:AddLine(gsub(g.text, " · ", "\n"), 1, 1, 1, true)
	end
	if self._cdRem and self._cdRem > 0.05 then
		GameTooltip:AddLine(fmt("Cooldown: %s", FormatShortTime(self._cdRem, true)), 1.0, 0.82, 0.25)
	end
	GameTooltip:Show()
end

local ItemSlots = {}
for i = 1, NUM_ITEMS do
	local slot = CreateSquareSlot(ActionRow, false)
	local offsetFromOrb = ORB_SIZE * 0.5 + ORB_GAP + (i - 1) * SQ_STEP + SQ_SIZE * 0.5
	slot:SetPoint("CENTER", ActionRow, "CENTER", offsetFromOrb, 0)
	slot:SetScript("OnEnter", ShowItemTooltip)
	slot:SetScript("OnLeave", HideTooltip)
	ItemSlots[i] = slot
end

local MountSlot = CreateSquareSlot(ActionRow, true)
MountSlot:SetPoint("CENTER", ActionRow, "CENTER", ORB_SIZE * 0.5 + ORB_GAP + NUM_ITEMS * SQ_STEP + SQ_SIZE * 0.5, 0)
MountSlot:RegisterForClicks("LeftButtonUp")
MountSlot.icon:SetTexture(TEX_STEED)
MountSlot.icon:Show()
MountSlot.chargesTxt = NS.CreateFontText(MountSlot.txtLayer, -2, "RIGHT")
MountSlot.chargesTxt:SetPoint("TOPRIGHT", MountSlot.txtLayer, "TOPRIGHT", -2, -1)
MountSlot.pips = {}
for p = 1, 4 do
	local pip = MountSlot.txtLayer:CreateTexture(nil, "OVERLAY")
	pip:SetSize(4, 4)
	pip:SetTexture(NS.OwnMedia("pin_diamond"))
	pip:Hide()
	MountSlot.pips[p] = pip
end
MountSlot:SetScript("OnClick", function()
	if type(_G.AZS_Dash) == "function" then pcall(_G.AZS_Dash) end
end)
MountSlot:SetScript("OnEnter", function(self)
	if not GameTooltip then return end
	local d = _G.AZS_DASH
	local isSteed = (not d) or (d.k == "steed")
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(isSteed and "Divine Steed (Mount)" or "Dash", 1, 0.88, 0.40)
	local n, m, rc = (d and tonumber(d.n)) or 0, (d and tonumber(d.m)) or 2, (d and tonumber(d.rc)) or 6
	GameTooltip:AddLine(fmt("Charges: %d / %d  (Recharge: %.1fs)", n, m, rc), 0.78, 0.86, 0.94)
	if self._rideRem and self._rideRem > 0.05 then
		GameTooltip:AddLine(fmt("Mounted: %.1fs remaining", self._rideRem), 0.35, 1.0, 0.65)
	elseif self._cdRem and self._cdRem > 0.05 then
		GameTooltip:AddLine(fmt("Next charge in: %.1fs", self._cdRem), 1.0, 0.82, 0.25)
	else
		GameTooltip:AddLine("Status: Ready (Shift or Click)", 0.40, 1.0, 0.65)
	end
	GameTooltip:Show()
end)
MountSlot:SetScript("OnLeave", HideTooltip)

local MAX_PASSIVES, PASSIVE_PER_ROW, PASSIVE_SIZE, PASSIVE_STEP = 14, 10, 32, 38
local PassiveRow = CreateFrame("Frame", nil, PlayerHUD)
PassiveRow:SetPoint("TOP", ActionRow, "BOTTOM", 0, -10)
PassiveRow:SetSize(PASSIVE_PER_ROW * PASSIVE_STEP, PASSIVE_STEP * 2)

local function ShowPassiveTooltip(self)
	local e = self._entry
	if not (GameTooltip and e) then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	if e.auraIndex then
		GameTooltip:SetUnitBuff("player", e.auraIndex)
	else
		local r, g, b = 1, 0.92, 0.55
		if e.cat == "talent" then r, g, b = 0.84, 0.64, 1.0
		elseif e.cat == "capstone" then r, g, b = 1.0, 0.84, 0.28
		elseif e.cat == "race" then r, g, b = 1.0, 0.72, 0.32
		elseif e.cat == "power" then r, g, b = 1.0, 0.55, 0.12
		elseif e.cat == "buff" then r, g, b = 0.25, 0.96, 0.84 end
		GameTooltip:SetText(e.name or "Passive", r, g, b)
		if e.sub and e.sub ~= "" then GameTooltip:AddLine(e.sub, 0.65, 0.72, 0.80) end
		if e.text and e.text ~= "" then GameTooltip:AddLine(e.text, 0.92, 0.94, 0.98, true) end
	end
	if e.rem and e.rem > 0 then
		GameTooltip:AddLine(fmt("Active: %s remaining", FormatShortTime(e.rem, true)), 0.35, 1.0, 0.65)
	elseif e.cdRem and e.cdRem > 0 then
		GameTooltip:AddLine(fmt("Cooldown: %s", FormatShortTime(e.cdRem, true)), 1.0, 0.82, 0.25)
	end
	GameTooltip:Show()
end

local PassiveOrbs = {}
for i = 1, MAX_PASSIVES do
	local orb = NS.CreateActionRingButton(PassiveRow, PASSIVE_SIZE)
	orb:EnableMouse(true)
	orb:SetScript("OnEnter", ShowPassiveTooltip)
	orb:SetScript("OnLeave", HideTooltip)
	orb.timerTxt = NS.CreateFontText(orb.overlay, 0, "CENTER")
	orb.timerTxt:SetPoint("CENTER", orb, "CENTER", 0, 0)
	orb.badgeTxt = NS.CreateFontText(orb.overlay, -2, "RIGHT")
	orb.badgeTxt:SetPoint("BOTTOMRIGHT", orb, "BOTTOMRIGHT", 0, 0)
	orb:Hide()
	PassiveOrbs[i] = orb
end

local PartyCards = {}
local function OnPartyCardEnter(self)
	if GameTooltip and self._unit and UnitExists(self._unit) then
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetUnit(self._unit)
		GameTooltip:Show()
	end
end

for i = 1, MAX_PARTY do
	local holder = CreateFrame("Frame", nil, PartyStrip)
	holder:SetSize(P_BAR_W, P_BAR_H)
	holder:EnableMouse(true)
	holder:SetScript("OnEnter", OnPartyCardEnter)
	holder:SetScript("OnLeave", HideTooltip)

	holder.threatGlow = holder:CreateTexture(nil, "BACKGROUND")
	holder.threatGlow:SetSize(P_CASE_W, P_CASE_H)
	holder.threatGlow:SetPoint("CENTER", holder, "CENTER", 0, -1)
	holder.threatGlow:SetTexture(NS.OwnMedia("hp_sym_case_glow"))
	holder.threatGlow:SetVertexColor(1, 0.15, 0.15, 0.90)
	holder.threatGlow:Hide()

	holder.case = holder:CreateTexture(nil, "ARTWORK")
	holder.case:SetSize(P_CASE_W, P_CASE_H)
	holder.case:SetPoint("CENTER", holder, "CENTER", 0, -1)
	holder.case:SetTexture(NS.OwnMedia("hp_sym_case"))
	holder.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)

	local bar = CreateFrame("StatusBar", nil, holder)
	bar:SetAllPoints(holder)
	bar:SetFrameLevel(holder:GetFrameLevel() + 1)
	bar:SetStatusBarTexture(NS.OwnMedia("hp_sym_bar"))
	bar:SetStatusBarColor(COLORS.health[1], COLORS.health[2], COLORS.health[3], 1)
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(100)
	holder.bar = bar

	local hl = bar:CreateTexture(nil, "OVERLAY")
	hl:SetAllPoints(bar)
	hl:SetTexture(NS.OwnMedia("hp_sym_bar_highlight"))
	hl:SetVertexColor(1, 1, 1, 0.18)
	holder.hl = hl

	local txtLayer = CreateFrame("Frame", nil, bar)
	txtLayer:SetAllPoints(bar)
	txtLayer:SetFrameLevel(bar:GetFrameLevel() + 2)

	holder.icon = txtLayer:CreateTexture(nil, "OVERLAY")
	holder.icon:SetSize(11, 11)
	holder.icon:SetPoint("LEFT", txtLayer, "LEFT", 4, 0)

	holder.val = NS.CreateFontText(txtLayer, -2, "RIGHT")
	holder.val:SetPoint("RIGHT", txtLayer, "RIGHT", -5, 0)

	holder.name = NS.CreateFontText(txtLayer, -2, "LEFT")
	holder.name:SetPoint("LEFT", holder.icon, "RIGHT", 3, 0)
	holder.name:SetPoint("RIGHT", holder.val, "LEFT", -3, 0)
	NS.SetNoWrap(holder.name, 14)

	holder:Hide()
	PartyCards[i] = holder
end

local function RenderMiniPartyCard(card, unit, name, cls, hp, hpm, connected, dead, revivePct, pulse)
	card._unit = unit
	local r, g, b = GetClassRGB(cls)
	SetText(card.name, "|cffffffff" .. name .. "|r")
	if not connected then
		ApplyClassCrest(card.icon, cls); card.icon:SetVertexColor(1, 1, 1, 1)
		card:SetAlpha(0.45)
		card.threatGlow:Hide()
		card.case:SetVertexColor(0.48, 0.50, 0.54, 1)
		card.bar:SetMinMaxValues(0, 100); card.bar:SetValue(0)
		SetText(card.val, "|cff999999OFF|r")
	elseif revivePct ~= nil then
		card:SetAlpha(1.0)
		card.threatGlow:SetVertexColor(1, 0.18, 0.22, pulse)
		card.threatGlow:Show()
		card.case:SetVertexColor(1.0, 0.42, 0.42, 1)
		card.icon:SetTexture(TEX_HEART_RED); card.icon:SetTexCoord(0, 1, 0, 1); card.icon:SetVertexColor(1, 0.28, 0.30, pulse)
		card.bar:SetMinMaxValues(0, 100); card.bar:SetValue(revivePct)
		card.bar:SetStatusBarColor(1.0, 0.26, 0.28, pulse)
		SetText(card.val, fmt("|cffffea89REV %d%%|r", revivePct))
	elseif dead then
		card:SetAlpha(0.68)
		card.threatGlow:Hide()
		card.case:SetVertexColor(0.68, 0.30, 0.32, 1)
		card.icon:SetTexture(TEX_SKULL); card.icon:SetTexCoord(0, 1, 0, 1); card.icon:SetVertexColor(0.95, 0.35, 0.35, 0.95)
		card.bar:SetMinMaxValues(0, 100); card.bar:SetValue(0)
		SetText(card.val, "|cffff5555DEAD|r")
	else
		local pct = (hp / hpm) * 100
		card:SetAlpha(1.0)
		ApplyClassCrest(card.icon, cls); card.icon:SetVertexColor(1, 1, 1, 1)
		card.bar:SetMinMaxValues(0, hpm); card.bar:SetValue(hp)
		if pct <= 35 then
			card.threatGlow:SetVertexColor(1, 0.15, 0.15, pulse)
			card.threatGlow:Show()
			card.case:SetVertexColor(1.0, 0.52, 0.52, 1)
			card.bar:SetStatusBarColor(COLORS.health[1], COLORS.health[2], COLORS.health[3], 1)
			SetText(card.val, fmt("|cffff6666%.0f%%|r", pct))
		else
			card.threatGlow:Hide()
			card.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
			card.bar:SetStatusBarColor(r, g, b, 0.95)
			SetText(card.val, fmt("|cfff0f4f8%.0f%%|r", pct))
		end
	end
	card:Show()
end

local lastPartyLayout = -1
local function LayoutPartyCards(count)
	if lastPartyLayout == count then return end
	lastPartyLayout = count
	if count <= 0 then return end
	local cols = (count == 1) and 1 or 2
	for i = 1, count do
		local c = PartyCards[i]
		local row = floor((i - 1) / cols)
		local col = (i - 1) % cols
		local inRow = (row == 0) and min(cols, count) or (count - cols)
		local rowW = inRow * P_BAR_W + (inRow - 1) * P_GAP_X
		local x = -rowW * 0.5 + P_BAR_W * 0.5 + col * (P_BAR_W + P_GAP_X)
		c:ClearAllPoints()
		c:SetPoint("BOTTOM", PartyStrip, "BOTTOM", x, row * (P_BAR_H + P_GAP_Y))
	end
end

local DownedByName = {}
local PREVIEW_ALLIES = {
	{ name = "Arthas",   class = "PALADIN", hp = 1420, hpm = 1500 },
	{ name = "Jaina",    class = "MAGE",    hp = 310,  hpm = 1120 },
	{ name = "Thrall",   class = "SHAMAN",  hp = 1280, hpm = 1350 },
	{ name = "Sylvanas", class = "HUNTER",  hp = 960,  hpm = 1100 },
}
local PREVIEW_PASSIVES = {
	{ cat = "race",     name = "Racial Passive",   icon = "Interface\\Icons\\Spell_Holy_DivineSpirit", sub = "Class / Race Passive", text = "Active passive bonus." },
	{ cat = "capstone", name = "Capstone Talent",  icon = "Interface\\Icons\\Ability_Whirlwind",       sub = "Capstone · 1/1",       text = "Signature specialization capstone." },
	{ cat = "talent",   name = "Core Talent",      icon = "Interface\\Icons\\Ability_CriticalStrike",  sub = "Talent · 5/5",         badge = "5", text = "Chosen class talent." },
	{ cat = "talent",   name = "Utility Talent",   icon = "Interface\\Icons\\Spell_Nature_EnchantArmor", sub = "Talent · 3/3",       badge = "3", text = "Chosen class talent." },
}

local lastProcVisible, lastHasShield, lastPipMax, lastClassToken, lastPassiveCount, lastStoredReady, lastImmune = nil, nil, -1, nil, -1, false, false
local function UpdateAnchors(hasProc)
	if lastProcVisible == hasProc then return end
	lastProcVisible = hasProc
	local spacing = (NS.DB and NS.DB.xpBarSpacing) or 12
	ActionRow:ClearAllPoints()
	if hasProc then
		ProcBar:Show()
		ActionRow:SetPoint("TOP", ProcBar, "BOTTOM", 0, -spacing)
	else
		ProcBar:Hide()
		ActionRow:SetPoint("TOP", HPBar, "BOTTOM", 0, -spacing)
	end
end

local function UpdateClassOrb(lvl)
	local _, cls = UnitClass("player")
	if cls ~= lastClassToken then
		lastClassToken = cls
		ApplyClassCrest(ClassOrb.ring.icon, cls)
		local r, g, b = GetClassRGB(cls)
		ClassOrb.ring.border:SetVertexColor(r * 0.55 + 0.45, g * 0.55 + 0.45, b * 0.55 + 0.45, 1)
		ClassOrb.ring.highlight:SetVertexColor(r, g, b, 0.55)
		ClassOrb.ring.highlight:Show()
	end
	ClassOrb._lvl = lvl
	SetText(ClassOrb.lvlTxt, fmt("|cffffea89%d|r", lvl))
end

local function UpdateMountSlot(ctx)
	local d = _G.AZS_DASH
	local showLive = type(d) == "table" and d.seen and (tonumber(d.off) or 0) ~= 1
	local isSteed = (not showLive) or (d.k == "steed")
	local tex = isSteed and TEX_STEED or TEX_DASH
	if MountSlot._tex ~= tex then MountSlot._tex = tex; MountSlot.icon:SetTexture(tex) end

	local n, m, rc, cdRem, rideRem
	if showLive then
		n = tonumber(d.n) or 0
		m = max(1, min(4, tonumber(d.m) or 2))
		rc = max(0.5, tonumber(d.rc) or 6)
		local ph = ctx.run and ctx.run.ph
		local paused = (ph == "paused" or ph == "choosing")
		local elapsed = paused and 0 or max(0, ctx.now - (tonumber(d.at) or ctx.now))
		cdRem = (n < m) and max(0, (tonumber(d.cd) or 0) - elapsed) or 0
		rideRem = isSteed and max(0, (tonumber(d.rd) or 0) - elapsed) or 0
		MountSlot:SetAlpha(1.0)
	elseif ctx.isEditing then
		n, m, rc, cdRem, rideRem = 1, 2, 6, 3.2, 0
		MountSlot:SetAlpha(1.0)
	else
		n, m, rc, cdRem, rideRem = 0, 2, 6, 0, 0
		MountSlot:SetAlpha(0.50)
	end
	MountSlot._cdRem, MountSlot._rideRem = cdRem, rideRem

	if lastPipMax ~= m then
		lastPipMax = m
		local step = 6
		local startX = -(m - 1) * step * 0.5
		for p = 1, 4 do
			local pip = MountSlot.pips[p]
			if p <= m then
				pip:ClearAllPoints()
				pip:SetPoint("BOTTOM", MountSlot.txtLayer, "BOTTOM", startX + (p - 1) * step, 2)
				pip:Show()
			else
				pip:Hide()
			end
		end
	end
	for p = 1, m do
		local pip = MountSlot.pips[p]
		if p <= n then pip:SetVertexColor(1.0, 0.84, 0.25, 1.0)
		else pip:SetVertexColor(0.24, 0.27, 0.34, 0.80) end
	end

	SetText(MountSlot.chargesTxt, (showLive or ctx.isEditing) and fmt(n > 0 and "|cffffea89%d|r" or "|cffff5555%d|r", n) or "")
	if rideRem > 0.05 then
		MountSlot.cdOverlay:Hide()
		MountSlot.icon:SetVertexColor(1, 1, 1, 1)
		MountSlot.auraBorder:SetBackdropBorderColor(0.20, 0.95, 0.72, 1.0)
		SetText(MountSlot.cdText, fmt("|cff44ffaa%.1f|r", rideRem))
	elseif cdRem > 0.05 then
		local frac = min(1.0, cdRem / rc)
		MountSlot.cdOverlay:SetHeight(max(1, (SQ_SIZE - 4) * frac))
		MountSlot.cdOverlay:Show()
		if n > 0 then
			MountSlot.icon:SetVertexColor(0.95, 0.95, 0.95, 1)
			MountSlot.auraBorder:SetBackdropBorderColor(1.0, 0.80, 0.28, 0.95)
		else
			MountSlot.icon:SetVertexColor(0.45, 0.45, 0.50, 1)
			MountSlot.auraBorder:SetBackdropBorderColor(0.42, 0.36, 0.28, 0.80)
		end
		SetText(MountSlot.cdText, fmt("|cffffd100%.1f|r", cdRem))
	else
		MountSlot.cdOverlay:Hide()
		MountSlot.icon:SetVertexColor(1, 1, 1, 1)
		MountSlot.auraBorder:SetBackdropBorderColor(showLive and 1.0 or 0.45, showLive and 0.82 or 0.42, showLive and 0.30 or 0.38, 0.92)
		SetText(MountSlot.cdText, "")
	end
end

local function UpdateItemSlots()
	local gear = _G.AZS_GEAR
	local hasGear = type(gear) == "table"
	for i = 1, NUM_ITEMS do
		local slot = ItemSlots[i]
		local g = hasGear and gear[i] or nil
		if g then
			slot._gear = g
			local icon = ResolveIcon(g.icon)
			if slot._icon ~= icon then slot._icon = icon; slot.icon:SetTexture(icon) end
			slot.icon:Show()
			local col = (BT and BT.GetCategoryColor and BT.GetCategoryColor("item", g.rarity)) or COLORS.normal
			slot.auraBorder:SetBackdropBorderColor(col[1], col[2], col[3], 0.95)
			slot:SetAlpha(1.0)
			SetText(slot.rankText, (g.slot == "amulet" and g.amount) and ("|cffffea89" .. tostring(g.amount) .. "|r") or "")
			local tInfo = BT and BT.GetTimerFor and BT.GetTimerFor(g.name or g.bonus, g.icon)
			local cdRem = (tInfo and not tInfo.ready and tInfo.rem and tInfo.rem > 0.05) and tInfo.rem or 0
			slot._cdRem = cdRem
			if cdRem > 0.05 then
				local dur = (tInfo and tInfo.dur and tInfo.dur > 0) and tInfo.dur or 15
				slot.cdOverlay:SetHeight(max(1, (SQ_SIZE - 4) * min(1.0, cdRem / dur)))
				slot.cdOverlay:Show()
				slot.icon:SetVertexColor(0.55, 0.55, 0.60, 1)
				SetText(slot.cdText, FormatShortTime(cdRem, true))
			else
				slot.cdOverlay:Hide()
				slot.icon:SetVertexColor(1, 1, 1, 1)
				SetText(slot.cdText, "")
			end
		else
			slot._gear, slot._cdRem = nil, 0
			slot.icon:Hide()
			slot.cdOverlay:Hide()
			slot.auraBorder:SetBackdropBorderColor(COLORS.verydarkgray[1], COLORS.verydarkgray[2], COLORS.verydarkgray[3], 0.65)
			slot:SetAlpha(0.42)
			SetText(slot.cdText, "")
			SetText(slot.rankText, "")
		end
	end
end

local PassivePool, SeenPassive, TempRacials = {}, {}, {}
local function AcquirePassive(idx)
	local e = PassivePool[idx]
	if not e then e = {}; PassivePool[idx] = e end
	e.cat, e.name, e.icon, e.sub, e.text, e.badge, e.rem, e.cdRem, e.auraIndex = nil, nil, nil, nil, nil, nil, 0, 0, nil
	return e
end

local function LayoutPassiveOrbs(count)
	if count == lastPassiveCount then return end
	lastPassiveCount = count
	if count <= 0 then return end
	for i = 1, count do
		local orb = PassiveOrbs[i]
		local row = floor((i - 1) / PASSIVE_PER_ROW)
		local col = (i - 1) % PASSIVE_PER_ROW
		local inRow = (row == 0) and min(PASSIVE_PER_ROW, count) or min(PASSIVE_PER_ROW, count - row * PASSIVE_PER_ROW)
		local rowW = inRow * PASSIVE_SIZE + (inRow - 1) * (PASSIVE_STEP - PASSIVE_SIZE)
		local x = -rowW * 0.5 + PASSIVE_SIZE * 0.5 + col * PASSIVE_STEP
		orb:ClearAllPoints()
		orb:SetPoint("TOP", PassiveRow, "TOP", x, -row * PASSIVE_STEP)
	end
end

local function UpdatePassiveCircles(ctx)
	Wipe(SeenPassive)
	local n = 0
	local now = ctx.now

	local pbuffs = _G.AZS_PLAYER_BUFFS
	if type(pbuffs) == "table" and #pbuffs > 0 then
		local runClock = ctx.runClock or 0
		for i = 1, #pbuffs do
			if n >= MAX_PASSIVES then break end
			local pb = pbuffs[i]
			if pb and pb.name then
				local rem = (tonumber(pb.ends) or 0) - runClock
				if rem > 0 or (tonumber(pb.duration) or 0) <= 0 then
					local low = lower(pb.name)
					if not SeenPassive[low] then
						SeenPassive[low] = true
						n = n + 1
						local e = AcquirePassive(n)
						e.cat, e.name = "buff", pb.name
						e.icon = ResolveIcon(pb.icon)
						e.sub = "Active Class Effect"
						e.rem = rem > 0 and rem or 0
						local st = tonumber(pb.stacks) or 0
						e.badge = st > 1 and tostring(st) or nil
					end
				end
			end
		end
	end

	for i = 1, 24 do
		if n >= MAX_PASSIVES then break end
		local bName, _, icon, count, _, duration, expTime, _, _, _, spellId = UnitBuff("player", i)
		if not bName then break end
		local low = lower(bName)
		if not SeenPassive[low] then
			SeenPassive[low] = true
			local rem = (BT and BT.ResolveAuraRemaining)
				and BT.ResolveAuraRemaining("player", bName, tonumber(spellId) or 0, duration, expTime, now, icon, i)
				or ((expTime and expTime > now) and (expTime - now) or 0)
			n = n + 1
			local e = AcquirePassive(n)
			e.cat, e.name, e.icon, e.auraIndex = "buff", bName, icon, i
			e.rem = rem
			e.badge = (count and count > 1) and tostring(count) or nil
		end
	end

	if BT and BT.GetUnitRacials then
		local racials = BT.GetUnitRacials("player", TempRacials)
		for i = 1, #racials do
			if n >= MAX_PASSIVES then break end
			local r = racials[i]
			local low = lower(r.name or "")
			if low ~= "" and not SeenPassive[low] then
				SeenPassive[low] = true
				local tInfo = BT.GetTimerFor and BT.GetTimerFor(r.name, r.icon)
				n = n + 1
				local e = AcquirePassive(n)
				e.cat, e.name, e.icon = "race", r.name, r.icon
				e.sub, e.text = "Racial Passive / Ability", r.text
				if tInfo and not tInfo.ready and tInfo.rem and tInfo.rem > 0 then e.cdRem = tInfo.rem end
			end
		end
	end

	local powers = _G.AZS_POWERS
	if type(powers) == "table" then
		for i = 1, #powers do
			if n >= MAX_PASSIVES then break end
			local pw = powers[i]
			if pw and pw.name then
				local low = lower(pw.name)
				if not SeenPassive[low] then
					SeenPassive[low] = true
					n = n + 1
					local e = AcquirePassive(n)
					e.cat, e.name, e.icon = "power", pw.name, TEX_POWER
					e.sub, e.text = "Legendary Power", pw.text or ""
				end
			end
		end
	end

	if BT and BT.GetPlayerActivatableTalents then
		local tals = BT.GetPlayerActivatableTalents()
		for i = 1, #tals do
			if n >= MAX_PASSIVES then break end
			local t = tals[i]
			local low = lower(t.name or "")
			if low ~= "" and not SeenPassive[low] then
				SeenPassive[low] = true
				local tInfo = BT.GetTimerFor and BT.GetTimerFor(t.name, t.icon)
				n = n + 1
				local e = AcquirePassive(n)
				e.cat = (t.maxRank <= 1) and "capstone" or "talent"
				e.name, e.icon = t.name, t.icon
				e.sub = fmt("%s · %d/%d", t.treeName ~= "" and t.treeName or "Talent", t.rank, t.maxRank)
				e.text = t.text
				e.badge = (t.maxRank > 1) and tostring(t.rank) or nil
				if tInfo and not tInfo.ready and tInfo.rem and tInfo.rem > 0 then e.cdRem = tInfo.rem end
			end
		end
	end

	if n == 0 and ctx.isEditing then
		for i = 1, #PREVIEW_PASSIVES do
			local pr = PREVIEW_PASSIVES[i]
			n = n + 1
			local e = AcquirePassive(n)
			e.cat, e.name, e.icon, e.sub, e.text, e.badge = pr.cat, pr.name, pr.icon, pr.sub, pr.text, pr.badge
		end
	end

	LayoutPassiveOrbs(n)
	for i = 1, n do
		local orb = PassiveOrbs[i]
		local e = PassivePool[i]
		orb._entry = e
		if orb._icon ~= e.icon then orb._icon = e.icon; orb.icon:SetTexture(e.icon or NS.QUESTION_ICON) end
		if e.cat == "buff" then
			orb.border:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1.0)
			orb.highlight:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.65)
			orb.highlight:Show()
		elseif e.cat == "capstone" then
			orb.border:SetVertexColor(1.00, 0.84, 0.28, 1.0)
			orb.highlight:SetVertexColor(1.00, 0.84, 0.28, 0.55)
			orb.highlight:Show()
		elseif e.cat == "race" then
			orb.border:SetVertexColor(1.00, 0.64, 0.24, 1.0)
			orb.highlight:Hide()
		elseif e.cat == "power" then
			orb.border:SetVertexColor(1.00, 0.52, 0.14, 1.0)
			orb.highlight:SetVertexColor(1.00, 0.52, 0.14, 0.50)
			orb.highlight:Show()
		else
			orb.border:SetVertexColor(0.76, 0.52, 1.00, 0.95)
			orb.highlight:Hide()
		end
		if e.rem and e.rem > 0 then
			orb.icon:SetVertexColor(1, 1, 1, 1)
			SetText(orb.timerTxt, "|cff55ffbb" .. FormatShortTime(e.rem, true) .. "|r")
		elseif e.cdRem and e.cdRem > 0 then
			orb.icon:SetVertexColor(0.45, 0.45, 0.50, 1)
			SetText(orb.timerTxt, "|cffffd100" .. FormatShortTime(e.cdRem, true) .. "|r")
		else
			orb.icon:SetVertexColor(1, 1, 1, 1)
			SetText(orb.timerTxt, "")
		end
		SetText(orb.badgeTxt, e.badge and ("|cffffea89" .. e.badge .. "|r") or "")
		orb:Show()
	end
	for i = n + 1, MAX_PASSIVES do
		PassiveOrbs[i]._entry = nil
		if PassiveOrbs[i]:IsShown() then PassiveOrbs[i]:Hide() end
	end
end

local function UpdateMiniParty(ctx)
	local nParty = GetNumPartyMembers() or 0
	if nParty == 0 and not ctx.isEditing then
		if PartyStrip:IsShown() then PartyStrip:Hide() end
		return
	end
	PartyStrip:Show()
	local pulse = 0.55 + 0.45 * sin(ctx.now * 6.0)
	if nParty == 0 and ctx.isEditing then
		LayoutPartyCards(#PREVIEW_ALLIES)
		for i = 1, MAX_PARTY do
			local p = PREVIEW_ALLIES[i]
			if p then RenderMiniPartyCard(PartyCards[i], nil, p.name, p.class, p.hp, p.hpm, true, false, nil, pulse)
			else PartyCards[i]:Hide() end
		end
		return
	end

	Wipe(DownedByName)
	if type(_G.AZS_GetDownedPartyMembers) == "function" then
		local ok, list = pcall(_G.AZS_GetDownedPartyMembers)
		if ok and type(list) == "table" then
			for i = 1, #list do
				local d = list[i]
				if d and d.name then DownedByName[d.name] = d end
			end
		end
	end

	local shown = 0
	for i = 1, min(MAX_PARTY, nParty) do
		local unit = "party" .. i
		if UnitExists(unit) then
			shown = shown + 1
			local name = UnitName(unit) or ("Ally " .. i)
			local _, cls = UnitClass(unit)
			local connected = UnitIsConnected(unit)
			local dead = UnitIsDeadOrGhost(unit)
			local downedInfo = DownedByName[name]
			local revPct = downedInfo and floor((tonumber(downedInfo.reviveShare) or 0) * 100) or nil
			RenderMiniPartyCard(PartyCards[shown], unit, name, cls, UnitHealth(unit) or 0, max(1, UnitHealthMax(unit) or 1), connected, dead, revPct, pulse)
		end
	end
	LayoutPartyCards(shown)
	for i = shown + 1, MAX_PARTY do
		PartyCards[i]._unit = nil
		if PartyCards[i]:IsShown() then PartyCards[i]:Hide() end
	end
end

local Mod = { frame = PlayerHUD }
function Mod.ResetCache() lastProcVisible, lastHasShield, lastPipMax, lastPartyLayout, lastClassToken, lastPassiveCount, lastStoredReady, lastImmune = nil, nil, -1, -1, nil, -1, false, false end

function Mod.ApplyTheme()
	HPBar:SetStatusBarColor(COLORS.health[1], COLORS.health[2], COLORS.health[3], 1)
	HPBar.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
	ShieldBar:SetStatusBarColor(COLORS.shield[1], COLORS.shield[2], COLORS.shield[3], 0.92)
	XPBar:SetStatusBarColor(COLORS.xp[1], COLORS.xp[2], COLORS.xp[3], 0.95)
	XPBar.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
	ProcBar:SetStatusBarColor(COLORS.normal[1], COLORS.normal[2], COLORS.normal[3], 0.95)
	ProcBar.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
	for i = 1, MAX_PARTY do
		PartyCards[i].case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
	end
	Mod.ResetCache()
end

function Mod.Update(ctx)
	local run, stats = ctx.run, ctx.stats
	local hp  = (run and tonumber(run.hp)) or UnitHealth("player") or 100
	local hpm = max(1, (run and tonumber(run.hpm)) or UnitHealthMax("player") or 100)
	local hpPct = (hp / hpm) * 100
	ctx.hpPct = hpPct
	if NS.IsBoxHidden("PlayerHUD") and not ctx.isEditing then return end

	if BT and BT.SyncTick then BT.SyncTick(ctx) end

	local totalShield = ((run and tonumber(run.sh)) or 0) + ((run and tonumber(run.bsh)) or 0)
	local isImmune, immRem = false, 0
	if BT and BT.GetPlayerImmunityRemaining then
		isImmune, immRem = BT.GetPlayerImmunityRemaining(ctx)
	end

	local hasShield = (not isImmune) and (totalShield > 0)
	if lastHasShield ~= hasShield then
		lastHasShield = hasShield
		if hasShield then
			ShieldBar:Show()
			if not isImmune then HPBar.case:SetVertexColor(0.52, 0.84, 1.0, 1.0) end
		else
			ShieldBar:Hide()
			if not isImmune then HPBar.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1) end
		end
	end

	if isImmune then
		local immPulse = 0.55 + 0.35 * sin(ctx.now * 6.5)
		HPBar:SetMinMaxValues(0, 100)
		HPBar:SetValue(100)
		HPBar.threatGlow:SetVertexColor(0.15, 0.95, 0.42, immPulse)
		HPBar.threatGlow:Show()
		if not lastImmune then
			lastImmune = true
			HPBar:SetStatusBarColor(0.14, 0.90, 0.36, 1.0)
			HPBar.case:SetVertexColor(0.55, 1.0, 0.68, 1.0)
			HPBar.leftText:Hide()
			HPBar.rightText:Hide()
			HPBar.immuneText:Show()
		end
		if immRem and immRem > 0.05 then
			SetText(HPBar.immuneText, fmt("|cffffffffIMMUNE|r |cffb8ffca(%.1fs)|r", immRem))
		else
			SetText(HPBar.immuneText, "|cffffffffIMMUNE|r")
		end
	else
		if lastImmune then
			lastImmune = false
			HPBar:SetStatusBarColor(COLORS.health[1], COLORS.health[2], COLORS.health[3], 1)
			if hasShield then
				HPBar.case:SetVertexColor(0.52, 0.84, 1.0, 1.0)
			else
				HPBar.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
			end
			HPBar.threatGlow:SetVertexColor(1, 0.15, 0.15, 0.9)
			HPBar.immuneText:Hide()
			HPBar.leftText:Show()
			HPBar.rightText:Show()
		end
		HPBar:SetMinMaxValues(0, hpm)
		HPBar:SetValue(hp)
		if hpPct <= 35 then HPBar.threatGlow:Show() else HPBar.threatGlow:Hide() end
		if hasShield then
			ShieldBar:SetMinMaxValues(0, hpm)
			ShieldBar:SetValue(min(hpm, totalShield))
			SetText(HPBar.leftText, fmt("%s |cff9be2ff(+%s)|r", FormatNumber(hp), FormatNumber(totalShield)))
		else
			SetText(HPBar.leftText, fmt("%s / %s", FormatNumber(hp), FormatNumber(hpm)))
		end
		local lives = (run and tonumber(run.lives)) or (stats and tonumber(stats.liv)) or 0
		SetText(HPBar.rightText, lives > 0 and fmt("|cffffea89%dx|r %.0f%%", lives, hpPct) or fmt("%.0f%%", hpPct))
	end

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
	local sl = (type(_G.AZS_GetStoredLevels) == "function" and tonumber(_G.AZS_GetStoredLevels())) or (run and tonumber(run.sl)) or 0
	local hasStored = sl > 0
	XPBar.clickBtn._sl = sl
	XPBar.clickBtn._rr = (run and tonumber(run.rr)) or 0
	if hasStored then
		local pulse = 0.52 + 0.48 * sin(ctx.now * 6.5)
		XPBar:SetMinMaxValues(0, 100)
		XPBar:SetValue(100)
		XPBar:SetStatusBarColor(1.0, 0.84, 0.14, pulse)
		XPBar.glow:SetAlpha(pulse)
		if not lastStoredReady then
			lastStoredReady = true
			XPBar.case:SetVertexColor(1.0, 0.86, 0.30, 1.0)
			XPBar.glow:Show()
			XPBar.clickBtn:EnableMouse(true)
		end
		SetText(XPBar.txt, fmt("|cffffffff[T] +%d Ready!|r |cffffea89(Item / Skill)|r", sl))
	else
		if lastStoredReady then
			lastStoredReady = false
			XPBar:SetStatusBarColor(COLORS.xp[1], COLORS.xp[2], COLORS.xp[3], 0.95)
			XPBar.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
			XPBar.glow:Hide()
			XPBar.clickBtn:EnableMouse(false)
		end
		XPBar:SetMinMaxValues(0, xpn)
		XPBar:SetValue(xp)
		SetText(XPBar.txt, fmt("Level %d  (%.0f%%)", lvl, (xp / xpn) * 100))
	end

	UpdateClassOrb(lvl)

	local spells = _G.AZS_SPELLS
	local hasSpells = (type(spells) == "table")
	for i = 1, NUM_SKILLS do
		local slot = SkillSlots[i]
		local sp = hasSpells and spells[i] or nil
		if sp then
			local icon = GetSpellIcon(sp.spell)
			if slot._icon ~= icon then slot._icon = icon; slot.icon:SetTexture(icon) end
			slot.icon:Show()
			local rank = tonumber(sp.rank) or 1
			local cd = tonumber(sp.cd) or 0
			local cdMax = tonumber(sp.cdmax) or 0
			slot._spellKey, slot._spellId, slot._spellRank, slot._spellCd, slot._spellCdMax = sp.key, tonumber(sp.spell), rank, cd, cdMax
			slot:SetAlpha(1.0)
			SetText(slot.rankText, "|cffffea89" .. tostring(rank) .. "|r")
			if cd > 0.05 then
				local frac = min(1.0, cd / max(0.1, cdMax > 0 and cdMax or 1))
				slot.cdOverlay:SetHeight(max(1, (SQ_SIZE - 4) * frac))
				slot.cdOverlay:Show()
				slot.icon:SetVertexColor(0.50, 0.50, 0.55, 1)
				slot.auraBorder:SetBackdropBorderColor(0.35, 0.38, 0.46, 0.85)
				SetText(slot.cdText, fmt("%.1f", cd))
			else
				slot.cdOverlay:Hide()
				slot.icon:SetVertexColor(1, 1, 1, 1)
				slot.auraBorder:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.92)
				SetText(slot.cdText, "")
			end
			if GameTooltip and GameTooltip:IsOwned(slot) and (ctx.tickId % 5 == 0) then
				ShowSpellTooltip(slot)
			end
		else
			slot._spellKey, slot._spellId = nil, nil
			slot.icon:Hide()
			slot.cdOverlay:Hide()
			slot.auraBorder:SetBackdropBorderColor(COLORS.verydarkgray[1], COLORS.verydarkgray[2], COLORS.verydarkgray[3], 0.65)
			slot:SetAlpha(0.42)
			SetText(slot.cdText, "")
			SetText(slot.rankText, "")
		end
	end

	UpdateItemSlots()
	UpdateMountSlot(ctx)
	UpdatePassiveCircles(ctx)
	UpdateMiniParty(ctx)
end

NS.Modules.PlayerHUD = Mod
