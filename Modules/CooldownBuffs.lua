local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local min, max, fmt = math.min, math.max, string.format
local SetText, FormatShortTime, Clamp = NS.SetText, NS.FormatShortTime, NS.Clamp
local BT = NS.BuffTracker

local CooldownsFrame = CreateFrame("Frame", "AZS_MinUI_CooldownBuffs", UIParent)
NS.RegisterMovableBox("CooldownBuffs", "Buff Cooldowns", CooldownsFrame)

CooldownsFrame.header = NS.CreateFontText(CooldownsFrame, -1, "LEFT")
CooldownsFrame.header:SetPoint("TOPLEFT", CooldownsFrame, "TOPLEFT", 10, -8)
CooldownsFrame.header:SetText("|cff76e8d6BUFF COOLDOWNS|r")
CooldownsFrame.sub = NS.CreateFontText(CooldownsFrame, -3, "RIGHT")
CooldownsFrame.sub:SetPoint("TOPRIGHT", CooldownsFrame, "TOPRIGHT", -10, -9)
CooldownsFrame.empty = NS.CreateFontText(CooldownsFrame, -2, "CENTER")
CooldownsFrame.empty:SetPoint("CENTER", CooldownsFrame, "CENTER", 0, -6)
CooldownsFrame.empty:SetText("|cff6e7b8eNo tracked buff cooldowns|r")
CooldownsFrame.empty:Hide()

local MAX_ROWS = 10
local Rows, CdList = {}, {}
local function OnRowEnter(self)
	if self._entry then BT.ShowEntryTooltip(self, "ANCHOR_RIGHT", self._entry, nil) end
end
local function OnRowLeave() if GameTooltip then GameTooltip:Hide() end end

for i = 1, MAX_ROWS do
	local row = CreateFrame("Button", nil, CooldownsFrame)
	row:SetHeight(20)
	row:SetPoint("TOPLEFT",  CooldownsFrame, "TOPLEFT",   10, -26 - (i - 1) * 21)
	row:SetPoint("TOPRIGHT", CooldownsFrame, "TOPRIGHT", -10, -26 - (i - 1) * 21)

	row.iconBox = CreateFrame("Frame", nil, row)
	row.iconBox:SetSize(18, 18)
	row.iconBox:SetPoint("LEFT", row, "LEFT", 0, 0)
	NS.ApplyFlatBackdrop(row.iconBox, { 0.04, 0.05, 0.07, 0.95 }, { 0.00, 0.85, 0.72, 0.90 })
	row.icon = row.iconBox:CreateTexture(nil, "ARTWORK")
	row.icon:SetPoint("TOPLEFT", row.iconBox, "TOPLEFT", 1, -1)
	row.icon:SetPoint("BOTTOMRIGHT", row.iconBox, "BOTTOMRIGHT", -1, 1)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.barBg = CreateFrame("Frame", nil, row)
	row.barBg:SetHeight(18)
	row.barBg:SetPoint("LEFT", row.iconBox, "RIGHT", 4, 0)
	row.barBg:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	NS.ApplyFlatBackdrop(row.barBg, { 0.05, 0.06, 0.09, 0.86 }, { 0.16, 0.20, 0.28, 0.75 })

	row.bar = CreateFrame("StatusBar", nil, row.barBg)
	row.bar:SetPoint("TOPLEFT", row.barBg, "TOPLEFT", 1, -1)
	row.bar:SetPoint("BOTTOMRIGHT", row.barBg, "BOTTOMRIGHT", -1, 1)
	row.bar:SetStatusBarTexture(NS.OwnMedia("bar_minimal"))
	row.bar:SetMinMaxValues(0, 100)
	row.bar:SetValue(0)

	row.name = NS.CreateFontText(row.bar, -2, "LEFT")
	row.name:SetPoint("LEFT", row.bar, "LEFT", 5, 0)
	row.name:SetPoint("RIGHT", row.bar, "RIGHT", -56, 0)
	NS.SetNoWrap(row.name, 14)

	row.time = NS.CreateFontText(row.bar, -2, "RIGHT")
	row.time:SetPoint("RIGHT", row.bar, "RIGHT", -5, 0)

	row:SetScript("OnEnter", OnRowEnter)
	row:SetScript("OnLeave", OnRowLeave)
	row:Hide()
	Rows[i] = row
end

local PREVIEW_COOLDOWNS = {
	{ name = "Blood Fury",     icon = "Interface\\Icons\\Racial_Orc_BerserkerStrength", cat = "race",   activeRem = 7.8, cdRem = 35, cdDur = 40, ready = false, sub = "Racial",  text = "Every 40 sec, +35% damage for 12 sec." },
	{ name = "Ring of Fury",   icon = "Interface\\Icons\\INV_Jewelry_Ring_36",          cat = "item",   activeRem = 0,   cdRem = 8.4, cdDur = 30, ready = false, rarity = 3, sub = "Ring", text = "Every 30 sec, +20% crit for 8 sec." },
	{ name = "Divine Shield",  icon = "Interface\\Icons\\Spell_Holy_DivineIntervention", cat = "buff",  activeRem = 0,   cdRem = 26,  cdDur = 60, ready = false, sub = "Skill",   text = "Grants immunity to all damage for 4 sec." },
	{ name = "Last Stand",     icon = "Interface\\Icons\\Spell_Holy_AshesToAshes",      cat = "talent", activeRem = 0,   cdRem = 54,  cdDur = 90, ready = false, sub = "Talent",  text = "Survive lethal damage once every 90 sec." },
	{ name = "Stoneform",      icon = "Interface\\Icons\\Spell_Shadow_UnholyStrength",  cat = "race",   activeRem = 0,   cdRem = 0,   cdDur = 30, ready = true,  sub = "Racial",  text = "Every 30 sec, shield absorbing 45% of max health." },
}

local CAT_NAME_HEX = {
	buff   = "|cffe2f8f5",
	item   = "|cffffe299",
	talent = "|cffd8b8ff",
	race   = "|cffffcc88",
}

local function ApplyRow(row, entry)
	row._entry = entry
	local tex = entry.icon or NS.QUESTION_ICON
	if row._tex ~= tex then row._tex = tex; row.icon:SetTexture(tex) end

	local bKey = (entry.cat or "buff") .. ":" .. (entry.rarity or 0)
	if row._bKey ~= bKey then
		row._bKey = bKey
		local col = BT.GetCategoryColor(entry.cat, entry.rarity)
		row.iconBox:SetBackdropBorderColor(col[1], col[2], col[3], col[4] or 0.90)
	end

	local nameCol = CAT_NAME_HEX[entry.cat] or "|cffe2e8f0"
	SetText(row.name, nameCol .. (entry.name or "Buff") .. "|r")

	local state
	if entry.activeRem and entry.activeRem > 0 then
		state = 1
		local maxD = max(entry.activeRem, (entry.cdDur and entry.cdDur > 0 and min(entry.cdDur, 15)) or 10)
		row.bar:SetValue(Clamp((entry.activeRem / maxD) * 100, 4, 100))
		SetText(row.time, "|cff44ffaaACT " .. FormatShortTime(entry.activeRem, true) .. "|r")
	elseif entry.cdRem and entry.cdRem > 0.05 then
		state = (entry.cdRem < 5) and 2 or 3
		local pct = (entry.cdDur and entry.cdDur > 0) and Clamp(((entry.cdDur - entry.cdRem) / entry.cdDur) * 100, 3, 100) or 35
		row.bar:SetValue(pct)
		SetText(row.time, (entry.cdRem < 5 and "|cffffcc44" or "|cffe2e8f0") .. FormatShortTime(entry.cdRem, true) .. "|r")
	else
		state = 4
		row.bar:SetValue(100)
		SetText(row.time, "|cff55ee99READY|r")
	end

	if row._state ~= state then
		row._state = state
		if state == 1 then
			row.bar:SetStatusBarColor(0.06, 0.78, 0.62, 0.50)
			row.barBg:SetBackdropBorderColor(0.00, 0.88, 0.72, 0.88)
			row.icon:SetVertexColor(1, 1, 1, 1)
		elseif state == 2 then
			row.bar:SetStatusBarColor(0.95, 0.68, 0.16, 0.44)
			row.barBg:SetBackdropBorderColor(0.95, 0.72, 0.22, 0.80)
			row.icon:SetVertexColor(0.85, 0.85, 0.90, 1)
		elseif state == 3 then
			row.bar:SetStatusBarColor(0.24, 0.56, 0.88, 0.38)
			row.barBg:SetBackdropBorderColor(0.22, 0.30, 0.44, 0.75)
			row.icon:SetVertexColor(0.65, 0.68, 0.74, 1)
		else
			row.bar:SetStatusBarColor(0.14, 0.62, 0.40, 0.28)
			row.barBg:SetBackdropBorderColor(0.20, 0.62, 0.44, 0.70)
			row.icon:SetVertexColor(1, 1, 1, 1)
		end
	end
	row:Show()
end

local Mod = { frame = CooldownsFrame }
function Mod.Update(ctx)
	if NS.GetModuleMode("CooldownBuffs") ~= "minimal" or NS.IsBoxHidden("CooldownBuffs") then
		if not ctx.isEditing and CooldownsFrame:IsShown() then CooldownsFrame:Hide() end
		if NS.GetModuleMode("CooldownBuffs") ~= "minimal" or not ctx.isEditing then return end
	end
	CooldownsFrame:Show()

	local cfg = (NS.DB and NS.DB.buffs) or NS.DEFAULTS.buffs
	local count = BT.CollectCooldowns(ctx, cfg, CdList)
	local list = CdList
	if count == 0 and ctx.isEditing then
		list = PREVIEW_COOLDOWNS
		count = #PREVIEW_COOLDOWNS
	end

	local nAct, nCd, nRdy = 0, 0, 0
	for i = 1, count do
		local e = list[i]
		if e.activeRem and e.activeRem > 0 then nAct = nAct + 1
		elseif e.cdRem and e.cdRem > 0.05 then nCd = nCd + 1
		else nRdy = nRdy + 1 end
	end
	if count > 0 then
		if nAct > 0 then SetText(CooldownsFrame.sub, fmt("|cff44ffaa%d ACT|r · |cffffd100%d CD|r · |cff66ee99%d RDY|r", nAct, nCd, nRdy))
		else SetText(CooldownsFrame.sub, fmt("|cffffd100%d CD|r · |cff66ee99%d RDY|r", nCd, nRdy)) end
		CooldownsFrame.empty:Hide()
	else
		SetText(CooldownsFrame.sub, "|cff8492a60 tracked|r")
		CooldownsFrame.empty:Show()
	end

	local shown = min(count, MAX_ROWS)
	for i = 1, shown do ApplyRow(Rows[i], list[i]) end
	for i = shown + 1, MAX_ROWS do
		Rows[i]._entry = nil
		if Rows[i]:IsShown() then Rows[i]:Hide() end
	end
end

NS.Modules.CooldownBuffs = Mod
