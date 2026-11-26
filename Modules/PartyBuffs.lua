local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, min, fmt, tconcat, tsort = math.floor, math.min, string.format, table.concat, table.sort
local lower = string.lower
local UnitExists, UnitName, UnitClass, GetNumPartyMembers = UnitExists, UnitName, UnitClass, GetNumPartyMembers
local Wipe, SetText, FormatShortTime, GetClassRGB, RGBToHex = NS.Wipe, NS.SetText, NS.FormatShortTime, NS.GetClassRGB, NS.RGBToHex
local BT = NS.BuffTracker

local PartyBuffsFrame = CreateFrame("Frame", "AZS_MinUI_PartyBuffs", UIParent)
NS.RegisterMovableBox("PartyBuffs", "Party Buffs", PartyBuffsFrame)

PartyBuffsFrame.header = NS.CreateFontText(PartyBuffsFrame, -1, "LEFT")
PartyBuffsFrame.header:SetPoint("TOPLEFT", PartyBuffsFrame, "TOPLEFT", 10, -8)
PartyBuffsFrame.header:SetText("|cff76e8d6PARTY BUFFS|r")
PartyBuffsFrame.sub = NS.CreateFontText(PartyBuffsFrame, -3, "RIGHT")
PartyBuffsFrame.sub:SetPoint("TOPRIGHT", PartyBuffsFrame, "TOPRIGHT", -10, -9)

local MAX_GROUPED, GROUPED_COLS = 18, 6
local GroupedSlots = {}
local function OnGroupedEnter(self)
	if not (GameTooltip and self._info) then return end
	local info = self._info
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if info.cat == "item" then
		GameTooltip:SetText(fmt("|c%s%s|r", BT.GetRarityHex(info.rarity), info.name or "Item"))
	elseif info.cat == "talent" then
		GameTooltip:SetText(info.name or "Talent", 0.80, 0.60, 1.00)
	elseif info.cat == "race" then
		GameTooltip:SetText(info.name or "Racial", 1.00, 0.76, 0.35)
	else
		GameTooltip:SetText(info.name or "Buff", 1, 0.92, 0.55)
	end
	if info.sub and info.sub ~= "" then GameTooltip:AddLine(info.sub, 0.62, 0.68, 0.78) end
	if info.text and info.text ~= "" then GameTooltip:AddLine(info.text, 0.92, 0.94, 0.98, true) end
	if info.minRem and info.minRem > 0 then
		GameTooltip:AddLine("Shortest remaining: " .. FormatShortTime(info.minRem, true), 0.35, 1.0, 0.72)
	end
	if info.holders and #info.holders > 0 then GameTooltip:AddLine("Active on: " .. tconcat(info.holders, ", "), 0.35, 1.0, 0.60, true) end
	if info.missing and #info.missing > 0 then GameTooltip:AddLine("Missing: " .. tconcat(info.missing, ", "), 0.65, 0.68, 0.74, true) end
	GameTooltip:Show()
end
local function HideTooltip() if GameTooltip then GameTooltip:Hide() end end

for i = 1, MAX_GROUPED do
	local col, row = (i - 1) % GROUPED_COLS, floor((i - 1) / GROUPED_COLS)
	local btn = CreateFrame("Button", nil, PartyBuffsFrame)
	btn:SetSize(26, 26)
	btn:SetPoint("TOPLEFT", PartyBuffsFrame, "TOPLEFT", 10 + col * 34, -26 - row * 38)
	btn.icon = btn:CreateTexture(nil, "ARTWORK")
	btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
	btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
	btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	btn.border = CreateFrame("Frame", nil, btn)
	btn.border:SetAllPoints()
	NS.ApplyFlatBackdrop(btn.border, nil, { 0.25, 0.78, 0.95, 0.90 }, true)
	btn.cov = NS.CreateFontText(btn.border, -3, "RIGHT")
	btn.cov:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
	btn.timer = NS.CreateFontText(btn.border, -3, "CENTER")
	btn.timer:SetPoint("TOP", btn, "BOTTOM", 0, -1)
	btn:SetScript("OnEnter", OnGroupedEnter)
	btn:SetScript("OnLeave", HideTooltip)
	btn:Hide()
	GroupedSlots[i] = btn
end

local MAX_ALLIES, ICONS_PER_ALLY = 4, 8
local AllyRows = {}
local function OnAllyIconEnter(self)
	if self._entry then BT.ShowEntryTooltip(self, "ANCHOR_RIGHT", self._entry, self._unit) end
end

for a = 1, MAX_ALLIES do
	local row = CreateFrame("Frame", nil, PartyBuffsFrame)
	row:SetHeight(24)
	row:SetPoint("TOPLEFT",  PartyBuffsFrame, "TOPLEFT",   10, -26 - (a - 1) * 28)
	row:SetPoint("TOPRIGHT", PartyBuffsFrame, "TOPRIGHT", -10, -26 - (a - 1) * 28)
	row.name = NS.CreateFontText(row, -2, "LEFT")
	row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.name:SetWidth(54)
	NS.SetNoWrap(row.name, 12)
	row.icons = {}
	for k = 1, ICONS_PER_ALLY do
		local ic = CreateFrame("Button", nil, row)
		ic:SetSize(18, 18)
		ic:SetPoint("LEFT", row.name, "RIGHT", 4 + (k - 1) * 20, 2)
		ic.tex = ic:CreateTexture(nil, "ARTWORK")
		ic.tex:SetPoint("TOPLEFT", ic, "TOPLEFT", 1, -1)
		ic.tex:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", -1, 1)
		ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic.border = CreateFrame("Frame", nil, ic)
		ic.border:SetAllPoints()
		NS.ApplyFlatBackdrop(ic.border, nil, { 0.25, 0.78, 0.95, 0.85 }, true)
		ic.timer = NS.CreateFontText(ic.border, -4, "CENTER")
		ic.timer:SetPoint("TOP", ic, "BOTTOM", 0, 0)
		ic:SetScript("OnEnter", OnAllyIconEnter)
		ic:SetScript("OnLeave", HideTooltip)
		ic:Hide()
		row.icons[k] = ic
	end
	row:Hide()
	AllyRows[a] = row
end

local PREVIEW_GROUPED = {
	{ cat = "buff",   name = "Heroism",          icon = "Interface\\Icons\\Ability_Shaman_Heroism",        count = 4, total = 4, minRem = 26,   holders = { "You", "Arthas", "Jaina", "Thrall" }, missing = {} },
	{ cat = "buff",   name = "Battle Shout",     icon = "Interface\\Icons\\Ability_Warrior_BattleShout",   count = 4, total = 4, minRem = 11.4, holders = { "You", "Arthas", "Jaina", "Thrall" }, missing = {} },
	{ cat = "item",   name = "Ring of Fury",     icon = "Interface\\Icons\\INV_Jewelry_Ring_36",           count = 2, total = 4, minRem = 0,    rarity = 3, sub = "Ring", text = "+12% Damage · Periodic crit burst.", holders = { "You", "Arthas" }, missing = { "Jaina", "Thrall" } },
	{ cat = "item",   name = "Amulet of Haste",  icon = "Interface\\Icons\\INV_Jewelry_Necklace_28",       count = 3, total = 4, minRem = 0,    rarity = 4, sub = "Amulet", text = "+15% Cooldown Reduction.", holders = { "You", "Jaina", "Thrall" }, missing = { "Arthas" } },
	{ cat = "race",   name = "Blood Fury",       icon = "Interface\\Icons\\Racial_Orc_BerserkerStrength",  count = 2, total = 4, minRem = 0,    sub = "Racial Buff", text = "Every 40 sec, +35% damage for 12 sec.", holders = { "You", "Thrall" }, missing = { "Arthas", "Jaina" } },
	{ cat = "talent", name = "Last Stand",       icon = "Interface\\Icons\\Spell_Holy_AshesToAshes",       count = 1, total = 4, minRem = 0,    sub = "Talent", text = "Cheat death every 90 sec.", holders = { "You" }, missing = { "Arthas", "Jaina", "Thrall" } },
}
local PREVIEW_ALLY_NAMES = { "Arthas", "Jaina", "Thrall" }
local PREVIEW_ALLY_ENTRIES = {
	{ cat = "buff", name = "Heroism",      icon = "Interface\\Icons\\Ability_Shaman_Heroism",       rem = 24, sub = "Active Buff" },
	{ cat = "item", name = "Ring of Fury", icon = "Interface\\Icons\\INV_Jewelry_Ring_36",          rem = 0,  rarity = 3, sub = "Ring", text = "+12% Damage." },
	{ cat = "race", name = "Blood Fury",   icon = "Interface\\Icons\\Racial_Orc_BerserkerStrength", rem = 0,  sub = "Racial Buff", text = "+35% damage for 12 sec." },
}

local CAT_PRIO = { buff = 1, item = 2, race = 3, talent = 4 }
local Units, UnitNames, BuffMap, BuffList, UnitBuffTmp, EntryPool = {}, {}, {}, {}, {}, {}
local function SortGroupedBuffs(a, b)
	local ta, tb = (a.minRem and a.minRem > 0) and 1 or 2, (b.minRem and b.minRem > 0) and 1 or 2
	if ta ~= tb then return ta < tb end
	if a.count ~= b.count then return a.count > b.count end
	local ca, cb = CAT_PRIO[a.cat] or 5, CAT_PRIO[b.cat] or 5
	if ca ~= cb then return ca < cb end
	return (a.name or "") < (b.name or "")
end

local Mod = { frame = PartyBuffsFrame }

function Mod.Update(ctx)
	if NS.GetModuleMode("PartyBuffs") ~= "minimal" then
		if not ctx.isEditing then PartyBuffsFrame:Hide() end
		return
	end
	local nParty = GetNumPartyMembers() or 0
	local cfg = (NS.DB and NS.DB.buffs) or NS.DEFAULTS.buffs
	if (nParty == 0 and not (cfg and cfg.showPartyBuffsWhenSolo) and not ctx.isEditing)
	or (NS.IsBoxHidden("PartyBuffs") and not ctx.isEditing) then
		if PartyBuffsFrame:IsShown() then PartyBuffsFrame:Hide() end
		return
	end
	PartyBuffsFrame:Show()
	local displayMode = (cfg and cfg.partyBuffMode) or 1

	if displayMode == 1 then
		for a = 1, MAX_ALLIES do AllyRows[a]:Hide() end
		SetText(PartyBuffsFrame.sub, "|cff8492a6Grouped|r")
		local list
		if ctx.isEditing and nParty == 0 then
			list = PREVIEW_GROUPED
		else
			Wipe(Units); Wipe(UnitNames); Wipe(BuffMap); Wipe(BuffList)
			Units[1] = "player"; UnitNames[1] = UnitName("player") or "player"
			local totalMembers = 1
			for i = 1, min(4, nParty) do
				local u = "party" .. i
				if UnitExists(u) then
					totalMembers = totalMembers + 1
					Units[totalMembers], UnitNames[totalMembers] = u, UnitName(u) or u
				end
			end
			local poolIdx = 0
			for uIdx = 1, totalMembers do
				local u, uName = Units[uIdx], UnitNames[uIdx]
				local uCount = BT.CollectUnitBuffs(ctx, u, cfg, UnitBuffTmp)
				for bIdx = 1, uCount do
					local b = UnitBuffTmp[bIdx]
					local bKey = lower(b.name or "")
					if bKey ~= "" then
						local entry = BuffMap[bKey]
						if not entry then
							poolIdx = poolIdx + 1
							entry = EntryPool[poolIdx]
							if not entry then
								entry = { holders = {}, holderMap = {}, missing = {} }
								EntryPool[poolIdx] = entry
							else
								Wipe(entry.holders); Wipe(entry.holderMap); Wipe(entry.missing)
							end
							entry.name, entry.icon, entry.cat, entry.rarity = b.name, b.icon, b.cat, b.rarity
							entry.sub, entry.text = b.sub, b.text
							entry.count, entry.total, entry.minRem = 0, totalMembers, nil
							BuffMap[bKey] = entry
							BuffList[#BuffList + 1] = entry
						end
						if not entry.holderMap[uName] then
							entry.count = entry.count + 1
							entry.holders[#entry.holders + 1] = uName
							entry.holderMap[uName] = true
						end
						if b.rem and b.rem > 0 and (not entry.minRem or b.rem < entry.minRem) then
							entry.minRem = b.rem
						end
						if b.cat == "buff" and entry.cat ~= "buff" then entry.cat = "buff" end
					end
				end
			end
			for i = 1, #BuffList do
				local e = BuffList[i]
				for uIdx = 1, totalMembers do
					local uName = UnitNames[uIdx]
					if not e.holderMap[uName] then e.missing[#e.missing + 1] = uName end
				end
			end
			tsort(BuffList, SortGroupedBuffs)
			list = BuffList
		end
		for i = 1, MAX_GROUPED do
			local slot, info = GroupedSlots[i], list[i]
			if info then
				slot._info = info
				local tex = info.icon or NS.QUESTION_ICON
				if slot._tex ~= tex then slot._tex = tex; slot.icon:SetTexture(tex) end
				local full = (info.count >= info.total)
				local bKey = (info.cat or "buff") .. ":" .. (info.rarity or 0) .. ":" .. (full and 1 or 0)
				if slot._bKey ~= bKey then
					slot._bKey = bKey
					if info.cat == "item" or info.cat == "talent" or info.cat == "race" then
						local col = BT.GetCategoryColor(info.cat, info.rarity)
						slot.border:SetBackdropBorderColor(col[1], col[2], col[3], col[4] or 0.92)
					elseif full then
						slot.border:SetBackdropBorderColor(0.00, 0.90, 0.74, 0.95)
					else
						slot.border:SetBackdropBorderColor(1.00, 0.78, 0.24, 0.92)
					end
				end
				SetText(slot.cov, fmt(full and "|cff44ffaa%d/%d|r" or "|cffffd100%d/%d|r", info.count, info.total))
				SetText(slot.timer, FormatShortTime(info.minRem, true))
				slot:Show()
			else
				slot._info = nil
				if slot:IsShown() then slot:Hide() end
			end
		end
	else
		for i = 1, MAX_GROUPED do GroupedSlots[i]:Hide() end
		SetText(PartyBuffsFrame.sub, "|cff8492a6Per Ally|r")
		if ctx.isEditing and nParty == 0 then
			for a = 1, MAX_ALLIES do
				local row, pName = AllyRows[a], PREVIEW_ALLY_NAMES[a]
				if pName then
					SetText(row.name, "|cffe2e8f0" .. pName .. "|r")
					for k = 1, ICONS_PER_ALLY do
						local ic, pe = row.icons[k], PREVIEW_ALLY_ENTRIES[k]
						if pe then
							ic._unit, ic._entry = nil, pe
							if ic._tex ~= pe.icon then ic._tex = pe.icon; ic.tex:SetTexture(pe.icon) end
							local col = BT.GetCategoryColor(pe.cat, pe.rarity)
							ic.border:SetBackdropBorderColor(col[1], col[2], col[3], col[4] or 0.90)
							SetText(ic.timer, FormatShortTime(pe.rem, false))
							ic:Show()
						else
							ic._entry = nil
							ic:Hide()
						end
					end
					row:Show()
				else
					row:Hide()
				end
			end
			return
		end
		local soloSelf = (nParty == 0 and cfg and cfg.showPartyBuffsWhenSolo)
		for a = 1, MAX_ALLIES do
			local row = AllyRows[a]
			local unit = (soloSelf and a == 1) and "player" or ((a <= nParty) and ("party" .. a) or nil)
			if unit and UnitExists(unit) then
				local _, cls = UnitClass(unit)
				local r, g, b = GetClassRGB(cls, 0.85, 0.88, 0.92)
				SetText(row.name, RGBToHex(r, g, b) .. (UnitName(unit) or ("Ally " .. a)) .. "|r")
				local uCount = BT.CollectUnitBuffs(ctx, unit, cfg, UnitBuffTmp)
				for k = 1, ICONS_PER_ALLY do
					local ic = row.icons[k]
					local entry = (k <= uCount) and UnitBuffTmp[k] or nil
					if entry then
						ic._unit, ic._entry = unit, entry
						local tex = entry.icon or NS.QUESTION_ICON
						if ic._tex ~= tex then ic._tex = tex; ic.tex:SetTexture(tex) end
						local bKey = (entry.cat or "buff") .. ":" .. (entry.rarity or 0)
						if ic._bKey ~= bKey then
							ic._bKey = bKey
							local col = BT.GetCategoryColor(entry.cat, entry.rarity)
							ic.border:SetBackdropBorderColor(col[1], col[2], col[3], col[4] or 0.90)
						end
						SetText(ic.timer, FormatShortTime(entry.rem, false))
						ic:Show()
					else
						ic._unit, ic._entry = nil, nil
						if ic:IsShown() then ic:Hide() end
					end
				end
				row:Show()
			elseif row:IsShown() then
				row:Hide()
			end
		end
	end
end

NS.Modules.PartyBuffs = Mod
