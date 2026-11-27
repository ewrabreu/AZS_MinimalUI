local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local max, min, tonumber, tostring, type, pairs, next, pcall = math.max, math.min, tonumber, tostring, type, pairs, next, pcall
local find, sub, fmt, tsort, GetTime = string.find, string.sub, string.format, table.sort, GetTime
local UnitExists, UnitGUID, UnitName, UnitClass, GetNumPartyMembers, SendAddonMessage =
	UnitExists, UnitGUID, UnitName, UnitClass, GetNumPartyMembers, SendAddonMessage
local COLORS, Clamp, Wipe, SetText, GetSpellIcon, ResolveIcon, FormatNumber, GetClassRGB, RGBToHex =
	NS.COLORS, NS.Clamp, NS.Wipe, NS.SetText, NS.GetSpellIcon, NS.ResolveIcon, NS.FormatNumber, NS.GetClassRGB, NS.RGBToHex

local TEX_CLASSES = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

local MeterPanel = CreateFrame("Frame", "AZS_MinUI_MeterPanel", UIParent)
NS.RegisterMovableBox("MeterPanel", "Damage Meter", MeterPanel)

MeterPanel.roleIcon = MeterPanel:CreateTexture(nil, "ARTWORK")
MeterPanel.roleIcon:SetSize(16, 16)
MeterPanel.roleIcon:SetPoint("TOPLEFT", MeterPanel, "TOPLEFT", 14, -10)
MeterPanel.roleIcon:SetTexture(NS.Media("grouprole-icons-dps"))
MeterPanel.header = NS.CreateFontText(MeterPanel, 0, "LEFT")
MeterPanel.header:SetPoint("LEFT", MeterPanel.roleIcon, "RIGHT", 4, 0)
MeterPanel.header:SetText("|cffffea89DAMAGE|r")

local DamageByGuid, NameByGuid, ClassByGuid, PetToOwnerGuid, RosterGuids = {}, {}, {}, {}, {}
local combatStartTime, lastRunClock = nil, 0

local function RegisterUnit(unit, petUnit)
	if not UnitExists(unit) then return end
	local guid = UnitGUID(unit)
	if not guid then return end
	RosterGuids[guid] = true
	NameByGuid[guid] = UnitName(unit) or NameByGuid[guid] or "Ally"
	local _, cls = UnitClass(unit)
	if cls then ClassByGuid[guid] = cls end
	if petUnit and UnitExists(petUnit) then
		local pGuid = UnitGUID(petUnit)
		if pGuid then PetToOwnerGuid[pGuid] = guid end
	end
end

local function RefreshRosterMap()
	Wipe(RosterGuids); Wipe(PetToOwnerGuid)
	RegisterUnit("player", "pet")
	for i = 1, min(4, GetNumPartyMembers() or 0) do RegisterUnit("party" .. i, "partypet" .. i) end
end

local function ResetLocalMeter()
	Wipe(DamageByGuid)
	combatStartTime = nil
	RefreshRosterMap()
	SendAddonMessage("AZSMREQ", "full", "PARTY")
end

local ResetBtn = NS.CreateResetButton(MeterPanel, "Sync / Reset Damage Meter", ResetLocalMeter)
MeterPanel.dpsTotal = NS.CreateFontText(MeterPanel, 0, "RIGHT")
MeterPanel.dpsTotal:SetPoint("RIGHT", ResetBtn, "LEFT", -6, 0)

local TAB_DEFS = {
	{ id = 1, label = "DPS",   barCol = COLORS.normal,     headerCol = "|cffffea89" },
	{ id = 2, label = "Total", barCol = COLORS.eliteBlue,  headerCol = "|cff66ddff" },
	{ id = 3, label = "Party", barCol = COLORS.accent,     headerCol = "|cff00ffcc" },
	{ id = 4, label = "Boss",  barCol = COLORS.bossOrange, headerCol = "|cffff9933" },
	{ id = 5, label = "Heal",  barCol = COLORS.cast,       headerCol = "|cff55ff88" },
}
local TabButtons = {}
local activeTab = 1

local function PaintTabs()
	for i = 1, #TabButtons do
		local b = TabButtons[i]
		local sel = (i == activeTab)
		if sel then
			local c = TAB_DEFS[i].barCol
			b.line:SetVertexColor(c[1], c[2], c[3], 0.95)
			b.line:Show()
			b.txt:SetTextColor(1, 1, 1, 1)
		else
			b.line:Hide()
			b.txt:SetTextColor(0.58, 0.64, 0.74, 1)
		end
	end
end

local TAB_W, TAB_GAP = 45, 2
for i = 1, #TAB_DEFS do
	local def = TAB_DEFS[i]
	local b = CreateFrame("Button", nil, MeterPanel)
	b:SetSize(TAB_W, 17)
	b:SetPoint("TOPLEFT", MeterPanel, "TOPLEFT", 14 + (i - 1) * (TAB_W + TAB_GAP), -30)
	b.line = b:CreateTexture(nil, "OVERLAY")
	b.line:SetTexture(NS.OwnMedia("blank"))
	b.line:SetHeight(2)
	b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 0)
	b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 0)
	b.line:Hide()
	b.txt = NS.CreateFontText(b, -2, "CENTER")
	b.txt:SetPoint("CENTER", 0, 1)
	b.txt:SetText(def.label)
	local idx = i
	b:SetScript("OnClick", function()
		NS.PlayUISound("UChatScrollButton")
		activeTab = idx
		if NS.DB then NS.DB.meterTab = idx end
		PaintTabs()
		if NS.UpdateMinimalHUD then NS.UpdateMinimalHUD() end
	end)
	TabButtons[i] = b
end
PaintTabs()

MeterPanel.empty = NS.CreateFontText(MeterPanel, -2, "CENTER")
MeterPanel.empty:SetPoint("CENTER", MeterPanel, "CENTER", 0, -18)
MeterPanel.empty:Hide()

local function OnRowEnter(self)
	local e = self._entry
	if not (GameTooltip and e) then return end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	if e.isHero then
		local r, g, b = GetClassRGB(e.class, 1, 0.92, 0.55)
		GameTooltip:SetText(e.name or "Player", r, g, b)
		GameTooltip:AddDoubleLine("DPS", FormatNumber(e.dps or 0) .. "/s", 0.70, 0.76, 0.84, 1, 0.92, 0.55)
		GameTooltip:AddDoubleLine("Total Damage", FormatNumber(e.dmg or 0), 0.70, 0.76, 0.84, 0.95, 0.98, 1)
		if type(e.spells) == "table" and #e.spells > 0 then
			GameTooltip:AddLine(" ")
			for j = 1, min(5, #e.spells) do
				local sp = e.spells[j]
				if sp then
					GameTooltip:AddDoubleLine(
						sp.name or "Skill",
						FormatNumber(sp.dmg or 0) .. (sp.dps and sp.dps > 0 and (" (" .. FormatNumber(sp.dps) .. "/s)") or ""),
						0.85, 0.88, 0.94, 0.65, 0.90, 0.98
					)
				end
			end
		end
	else
		GameTooltip:SetText(e.name or "Skill", 1, 0.92, 0.55)
		GameTooltip:AddDoubleLine("DPS", FormatNumber(e.dps or 0) .. "/s", 0.70, 0.76, 0.84, 1, 0.92, 0.55)
		GameTooltip:AddDoubleLine("Total Damage", FormatNumber(e.dmg or 0), 0.70, 0.76, 0.84, 0.95, 0.98, 1)
	end
	GameTooltip:Show()
end
local function OnRowLeave() if GameTooltip then GameTooltip:Hide() end end

local NUM_METER_ROWS = 6
local MeterRows = {}
for i = 1, NUM_METER_ROWS do
	local row = CreateFrame("Frame", nil, MeterPanel)
	row:SetHeight(25)
	row:SetPoint("TOPLEFT",  MeterPanel, "TOPLEFT",   14, -52 - (i - 1) * 27)
	row:SetPoint("TOPRIGHT", MeterPanel, "TOPRIGHT", -14, -52 - (i - 1) * 27)
	row:EnableMouse(true)
	row:SetScript("OnEnter", OnRowEnter)
	row:SetScript("OnLeave", OnRowLeave)
	row.iconHolder = CreateFrame("Frame", nil, row)
	row.iconHolder:SetSize(18, 18)
	row.iconHolder:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon = row.iconHolder:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if row.icon.SetMask then row.icon:SetMask(NS.Media("actionbutton-mask-square")) end
	row.val = NS.CreateFontText(row, 0, "RIGHT")
	row.val:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	row.name = NS.CreateFontText(row, 0, "LEFT")
	row.name:SetPoint("TOPLEFT", row.iconHolder, "TOPRIGHT", 7, 0)
	row.name:SetPoint("RIGHT", row.val, "LEFT", -6, 0)
	NS.SetNoWrap(row.name, 14)
	row.barFrame, row.bar, row.barBg = NS.CreateThinBar(row, 4, COLORS.normal)
	row.barFrame:SetPoint("BOTTOMLEFT",  row.iconHolder, "BOTTOMRIGHT", 7, 1)
	row.barFrame:SetPoint("BOTTOMRIGHT", row,            "BOTTOMRIGHT", 0, 1)
	row:Hide()
	MeterRows[i] = row
end

local CLASS_TOKEN_BY_ID = {
	[1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE",
	[5] = "PRIEST", [6] = "DEATHKNIGHT", [7] = "SHAMAN", [8] = "MAGE",
	[9] = "WARLOCK", [11] = "DRUID", [12] = "MONK", [13] = "DEMONHUNTER",
}
local function ResolveClassToken(rawClass, heroName)
	local id = tonumber(rawClass)
	if id then
		local gen = _G.AZS_GEN and _G.AZS_GEN.classById and _G.AZS_GEN.classById[id]
		if gen and gen.token then return gen.token end
		if CLASS_TOKEN_BY_ID[id] then return CLASS_TOKEN_BY_ID[id] end
	elseif type(rawClass) == "string" and rawClass ~= "" then
		return string.upper(rawClass)
	end
	if heroName then
		if heroName == UnitName("player") then local _, c = UnitClass("player"); return c end
		for i = 1, min(4, GetNumPartyMembers() or 0) do
			local u = "party" .. i
			if UnitExists(u) and UnitName(u) == heroName then
				local _, c = UnitClass(u)
				return c
			end
		end
	end
	return nil
end

local function ApplyClassRowIcon(row, cls)
	local coords = cls and _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[cls]
	if coords then
		if row._icon ~= TEX_CLASSES then row._icon = TEX_CLASSES; row.icon:SetTexture(TEX_CLASSES) end
		row.icon:SetTexCoord(coords[1] + 0.03, coords[2] - 0.03, coords[3] + 0.03, coords[4] - 0.03)
		return
	end
	local genCls = cls and _G.AZS_GEN and _G.AZS_GEN.classByToken and _G.AZS_GEN.classByToken[cls]
	local path = (genCls and genCls.classIcon) and ResolveIcon(genCls.classIcon) or NS.Media("grouprole-icons-dps")
	if row._icon ~= path then row._icon = path; row.icon:SetTexture(path) end
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local GROUP_FIELDS = { "name", "dmg", "dps", "share", "proc", "spell", "class", "iconSpell" }
local GroupPartyRaw, GroupBossRaw, GroupHealRaw = {}, {}, {}
local azsMeterHooked = false

local function TryHookAZSGroupMeters()
	if azsMeterHooked then return end
	if type(_G.AZS) == "table" and type(_G.AZS.On) == "function" and type(_G.AZS_List) == "function" then
		azsMeterHooked = true
		_G.AZS.On("AZSGROUP", function(msg)
			GroupPartyRaw = _G.AZS_List(msg or "", GROUP_FIELDS) or {}
		end)
		_G.AZS.On("AZSGROUPBOSS", function(msg)
			GroupBossRaw = _G.AZS_List(msg or "", GROUP_FIELDS) or {}
		end)
		_G.AZS.On("AZSGROUPHEAL", function(msg)
			GroupHealRaw = _G.AZS_List(msg or "", GROUP_FIELDS) or {}
		end)
	end
end
TryHookAZSGroupMeters()

local SPELL_DMG_EVENTS = {
	RANGE_DAMAGE = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true,
	DAMAGE_SHIELD = true, DAMAGE_SPLIT = true,
}
local LogFrame = CreateFrame("Frame")
LogFrame._azsMinUI = true
LogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
LogFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
LogFrame:RegisterEvent("UNIT_PET")
LogFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
LogFrame:SetScript("OnEvent", function(_, event, _, subEvent, sourceGUID, sourceName, _, _, _, _, arg9, _, _, arg12)
	if event == "PARTY_MEMBERS_CHANGED" or event == "UNIT_PET" then RefreshRosterMap(); return
	elseif event == "PLAYER_ENTERING_WORLD" then
		TryHookAZSGroupMeters()
		Wipe(DamageByGuid); combatStartTime = nil
		RefreshRosterMap()
		SendAddonMessage("AZSMREQ", "full", "PARTY")
		return
	end
	if not sourceGUID or not NS.DB or NS.GetModuleMode("MeterPanel") ~= "minimal" then return end
	local amount = (subEvent == "SWING_DAMAGE") and tonumber(arg9) or (SPELL_DMG_EVENTS[subEvent] and tonumber(arg12)) or nil
	if not amount or amount <= 0 then return end
	local ownerGuid = PetToOwnerGuid[sourceGUID] or sourceGUID
	if not RosterGuids[ownerGuid] then
		RefreshRosterMap()
		ownerGuid = PetToOwnerGuid[sourceGUID] or sourceGUID
		if not RosterGuids[ownerGuid] then return end
	end
	if not combatStartTime then combatStartTime = GetTime() end
	DamageByGuid[ownerGuid] = (DamageByGuid[ownerGuid] or 0) + amount
	if not NameByGuid[ownerGuid] and sourceName then NameByGuid[ownerGuid] = sourceName end
end)

local SortedBuf, HeroPool, HeroByName, SpellRowPool = {}, {}, {}, {}
local function SortByDps(a, b)
	local ad, bd = tonumber(a.dps) or 0, tonumber(b.dps) or 0
	if ad ~= bd then return ad > bd end
	return (tonumber(a.dmg) or 0) > (tonumber(b.dmg) or 0)
end
local function SortByDmg(a, b)
	local ad, bd = tonumber(a.dmg) or 0, tonumber(b.dmg) or 0
	if ad ~= bd then return ad > bd end
	return (tonumber(a.dps) or 0) > (tonumber(b.dps) or 0)
end

local function AcquireHero(idx)
	local h = HeroPool[idx]
	if not h then h = { spells = {} }; HeroPool[idx] = h
	else Wipe(h.spells) end
	h.isHero, h.name, h.dmg, h.dps, h.class, h.isMe = true, "", 0, 0, nil, false
	return h
end

local function AggregateGroupRows(rawList, out)
	Wipe(out); Wipe(HeroByName)
	if type(rawList) ~= "table" or #rawList == 0 then return 0, 0 end
	local myName = UnitName("player")
	local count, spIdx, totalDps, totalDmg = 0, 0, 0, 0
	for i = 1, #rawList do
		local r = rawList[i]
		if r and r.name then
			local dmg = tonumber(r.dmg) or 0
			local dps = tonumber(r.dps) or 0
			if dmg > 0 or dps > 0 then
				local at = find(r.name, ": ", 1, true)
				local who = at and sub(r.name, 1, at - 1) or r.name
				local spName = at and sub(r.name, at + 2) or r.name
				local h = HeroByName[who]
				if not h then
					count = count + 1
					h = AcquireHero(count)
					h.name = who
					h.class = ResolveClassToken(r.class, who)
					h.isMe = (who == myName)
					HeroByName[who] = h
					out[count] = h
				end
				h.dmg = h.dmg + dmg
				h.dps = h.dps + dps
				totalDmg = totalDmg + dmg
				totalDps = totalDps + dps
				spIdx = spIdx + 1
				local sr = SpellRowPool[spIdx]
				if not sr then sr = {}; SpellRowPool[spIdx] = sr end
				sr.name, sr.dmg, sr.dps = spName, dmg, dps
				h.spells[#h.spells + 1] = sr
			end
		end
	end
	for i = 1, count do
		if #out[i].spells > 1 then tsort(out[i].spells, SortByDmg) end
	end
	return totalDps, totalDmg
end

local PREVIEW_HEROES = {
	{ isHero = true, name = "You (Preview)", dps = 4820, dmg = 842000, class = "DEATHKNIGHT", isMe = true  },
	{ isHero = true, name = "Arthas",        dps = 3950, dmg = 691000, class = "PALADIN",     isMe = false },
	{ isHero = true, name = "Jaina",         dps = 3120, dmg = 546000, class = "MAGE",        isMe = false },
	{ isHero = true, name = "Thrall",        dps = 2460, dmg = 430000, class = "SHAMAN",      isMe = false },
}

local function BuildPartyHeroData(ctx, out)
	local totalDps, totalDmg = AggregateGroupRows(GroupPartyRaw, out)
	if #out > 0 then return totalDps, totalDmg end

	Wipe(out)
	if not next(RosterGuids) then RefreshRosterMap() end
	local elapsed = combatStartTime and max(1.0, ctx.now - combatStartTime) or max(1.0, ctx.runClock or 1)
	local playerGuid = UnitGUID("player")
	local myLines, myServerDps = NS.GetMeterCached(ctx.tickId)
	local myServerDmg = 0
	if type(myLines) == "table" then
		for i = 1, #myLines do myServerDmg = myServerDmg + (tonumber(myLines[i].dmg) or 0) end
	end
	local count = 0
	for guid in pairs(RosterGuids) do
		local dmg = DamageByGuid[guid] or 0
		local dps = dmg / elapsed
		if guid == playerGuid then
			if myServerDps and myServerDps > dps then dps = myServerDps end
			if myServerDmg > dmg then dmg = myServerDmg end
		end
		if dmg > 0 or dps > 0 then
			count = count + 1
			local h = AcquireHero(count)
			h.name = NameByGuid[guid] or "Ally"
			h.class = ClassByGuid[guid]
			h.dmg = dmg
			h.dps = dps
			h.isMe = (guid == playerGuid)
			out[count] = h
			totalDps = totalDps + dps
			totalDmg = totalDmg + dmg
		end
	end
	return totalDps, totalDmg
end

local function BuildBossHeroData(out)
	local totalDps, totalDmg = AggregateGroupRows(GroupBossRaw, out)
	if #out > 0 then return totalDps, totalDmg end

	Wipe(out)
	local lines
	if type(_G.AZS_GetBossMeter) == "function" then
		local ok, m = pcall(_G.AZS_GetBossMeter)
		if ok then lines = m end
	end
	lines = lines or _G.AZS_BOSSMETER
	if type(lines) ~= "table" or #lines == 0 then return 0, 0 end

	local sumDmg, sumDps, spIdx = 0, 0, 0
	local h = AcquireHero(1)
	h.name = UnitName("player") or "You"
	local _, cls = UnitClass("player")
	h.class = cls
	h.isMe = true
	for i = 1, #lines do
		local m = lines[i]
		if m then
			local d = tonumber(m.dmg) or 0
			local r = tonumber(m.dps) or 0
			sumDmg = sumDmg + d
			sumDps = sumDps + r
			if d > 0 or r > 0 then
				spIdx = spIdx + 1
				local sr = SpellRowPool[spIdx]
				if not sr then sr = {}; SpellRowPool[spIdx] = sr end
				sr.name, sr.dmg, sr.dps = m.name or "Skill", d, r
				h.spells[#h.spells + 1] = sr
			end
		end
	end
	if sumDmg > 0 or sumDps > 0 then
		h.dmg, h.dps = sumDmg, sumDps
		if #h.spells > 1 then tsort(h.spells, SortByDmg) end
		out[1] = h
		return sumDps, sumDmg
	end
	return 0, 0
end

local function BuildHealData(out)
	local totalHps, totalHeal = AggregateGroupRows(GroupHealRaw, out)
	if #out > 0 then return totalHps, totalHeal, true end

	Wipe(out)
	local lines
	if type(_G.AZS_GetHealing) == "function" then
		local ok, m = pcall(_G.AZS_GetHealing)
		if ok then lines = m end
	end
	lines = lines or _G.AZS_HEALING
	if type(lines) ~= "table" or #lines == 0 then return 0, 0, false end

	local sumHeal, sumHps = 0, 0
	for i = 1, #lines do
		local m = lines[i]
		if m then
			out[#out + 1] = m
			sumHeal = sumHeal + (tonumber(m.dmg) or 0)
			sumHps = sumHps + (tonumber(m.dps) or 0)
		end
	end
	return sumHps, sumHeal, false
end

local lastSyncedTab = -1
local Mod = { frame = MeterPanel, Reset = ResetLocalMeter }
function Mod.Update(ctx)
	if NS.IsBoxHidden("MeterPanel") and not ctx.isEditing then return end
	TryHookAZSGroupMeters()

	local runClock = ctx.runClock or 0
	if runClock > 0 and lastRunClock > 5 and runClock < 3 then
		Wipe(DamageByGuid); combatStartTime = nil
		Wipe(GroupPartyRaw); Wipe(GroupBossRaw); Wipe(GroupHealRaw)
	end
	lastRunClock = runClock

	local savedTab = (NS.DB and tonumber(NS.DB.meterTab)) or 1
	if savedTab >= 1 and savedTab <= #TAB_DEFS and savedTab ~= activeTab then
		activeTab = savedTab
	end
	if lastSyncedTab ~= activeTab then
		lastSyncedTab = activeTab
		PaintTabs()
	end

	local isHeroTab = (activeTab == 3 or activeTab == 4)
	local totalHeaderVal, barDenom = 0, 1
	Wipe(SortedBuf)

	if activeTab == 1 or activeTab == 2 then
		local rawLines, totalDps = NS.GetMeterCached(ctx.tickId)
		local totalDmg = 0
		if type(rawLines) == "table" then
			for i = 1, #rawLines do
				local m = rawLines[i]
				if m then
					SortedBuf[#SortedBuf + 1] = m
					totalDmg = totalDmg + (tonumber(m.dmg) or 0)
				end
			end
		end
		if #SortedBuf > 1 then tsort(SortedBuf, activeTab == 1 and SortByDps or SortByDmg) end
		totalHeaderVal = (activeTab == 1) and totalDps or totalDmg
		barDenom = max(1, totalHeaderVal)
	elseif activeTab == 3 then
		local _, tDmg = BuildPartyHeroData(ctx, SortedBuf)
		if #SortedBuf == 0 and ctx.isEditing then
			for i = 1, #PREVIEW_HEROES do SortedBuf[i] = PREVIEW_HEROES[i]; tDmg = tDmg + PREVIEW_HEROES[i].dmg end
		end
		if #SortedBuf > 1 then tsort(SortedBuf, SortByDmg) end
		totalHeaderVal = tDmg
		barDenom = max(1, (SortedBuf[1] and (tonumber(SortedBuf[1].dmg) or 0)) or 1)
	elseif activeTab == 4 then
		local tDps = BuildBossHeroData(SortedBuf)
		if #SortedBuf == 0 and ctx.isEditing then
			for i = 1, #PREVIEW_HEROES do SortedBuf[i] = PREVIEW_HEROES[i]; tDps = tDps + PREVIEW_HEROES[i].dps end
		end
		if #SortedBuf > 1 then tsort(SortedBuf, SortByDps) end
		totalHeaderVal = tDps
		barDenom = max(1, (SortedBuf[1] and (tonumber(SortedBuf[1].dps) or 0)) or 1)
	else
		local _, tHeal, heroMode = BuildHealData(SortedBuf)
		isHeroTab = heroMode
		if #SortedBuf == 0 and ctx.isEditing then
			isHeroTab = true
			for i = 1, #PREVIEW_HEROES do SortedBuf[i] = PREVIEW_HEROES[i]; tHeal = tHeal + PREVIEW_HEROES[i].dmg end
		end
		if #SortedBuf > 1 then tsort(SortedBuf, SortByDmg) end
		totalHeaderVal = tHeal
		barDenom = max(1, (SortedBuf[1] and (tonumber(SortedBuf[1].dmg) or 0)) or 1)
	end

	local tabDef = TAB_DEFS[activeTab]
	if activeTab == 2 or activeTab == 3 or activeTab == 5 then
		SetText(MeterPanel.dpsTotal, tabDef.headerCol .. FormatNumber(totalHeaderVal) .. "|r")
	else
		SetText(MeterPanel.dpsTotal, tabDef.headerCol .. FormatNumber(totalHeaderVal) .. "/s|r")
	end

	if #SortedBuf == 0 then
		local msg = activeTab == 4 and "|cff6e7c91No boss damage yet|r"
			or (activeTab == 5 and "|cff6e7c91No healing yet|r"
			or (activeTab == 3 and "|cff6e7c91Waiting for party combat...|r" or "|cff6e7c91Waiting for combat...|r"))
		SetText(MeterPanel.empty, msg)
		MeterPanel.empty:Show()
	else
		MeterPanel.empty:Hide()
	end

	local c = tabDef.barCol
	for i = 1, NUM_METER_ROWS do
		local row = MeterRows[i]
		local e = SortedBuf[i]
		if e then
			row._entry = e
			if isHeroTab then
				ApplyClassRowIcon(row, e.class)
				local r, g, b = GetClassRGB(e.class, c[1], c[2], c[3])
				local isTotal = (activeTab == 3 or activeTab == 5)
				local val = isTotal and (tonumber(e.dmg) or 0) or (tonumber(e.dps) or 0)
				local share = (totalHeaderVal > 0) and Clamp((val / totalHeaderVal) * 100, 0, 100) or 0
				SetText(row.name, fmt("|cff8892a4%d.|r %s%s|r", i, RGBToHex(r, g, b), e.name or "Ally"))
				SetText(row.val, fmt(isTotal and "%s |cffaaaaaa(%.0f%%)|r" or "%s/s |cffaaaaaa(%.0f%%)|r", FormatNumber(val), share))
				row.bar:SetStatusBarColor(r, g, b, e.isMe and 1.0 or 0.85)
				row.bar:SetValue(Clamp((val / barDenom) * 100, 0, 100))
			else
				local icon = GetSpellIcon(e.spell)
				if row._icon ~= icon then row._icon = icon; row.icon:SetTexture(icon) end
				row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				SetText(row.name, e.name or "Skill")
				local val = (activeTab == 1) and (tonumber(e.dps) or 0) or (tonumber(e.dmg) or 0)
				local share = tonumber(e.share)
				if not share or share <= 0 then
					share = (val / barDenom) * 100
				elseif share <= 1.0 then
					share = share * 100
				end
				share = Clamp(share, 0, 100)
				SetText(row.val, fmt(activeTab == 1 and "%s/s |cffaaaaaa(%.0f%%)|r" or "%s |cffaaaaaa(%.0f%%)|r", FormatNumber(val), share))
				row.bar:SetStatusBarColor(c[1], c[2], c[3], 0.95)
				row.bar:SetValue(share)
			end
			row:Show()
		else
			row._entry = nil
			if row:IsShown() then row:Hide() end
		end
	end
end

function Mod.ApplyTheme(th)
	if th and th.hex then
		MeterPanel.header:SetText((th.hex.title or "|cffffea89") .. "DAMAGE|r")
		TAB_DEFS[1].headerCol = th.hex.title  or TAB_DEFS[1].headerCol
		TAB_DEFS[2].headerCol = th.hex.elite  or TAB_DEFS[2].headerCol
		TAB_DEFS[3].headerCol = th.hex.accent or TAB_DEFS[3].headerCol
		TAB_DEFS[4].headerCol = th.hex.boss   or TAB_DEFS[4].headerCol
		TAB_DEFS[5].headerCol = th.hex.heal   or TAB_DEFS[5].headerCol
	end
	local trk = COLORS.barTrack
	for i = 1, NUM_METER_ROWS do
		if trk then MeterRows[i].barBg:SetVertexColor(trk[1], trk[2], trk[3], trk[4] or 0.85) end
	end
	PaintTabs()
end

NS.Modules.MeterPanel = Mod
