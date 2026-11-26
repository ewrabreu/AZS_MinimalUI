local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local max, min, tonumber, type, pairs, next, pcall = math.max, math.min, tonumber, type, pairs, next, pcall
local fmt, tsort, GetTime = string.format, table.sort, GetTime
local UnitExists, UnitGUID, UnitName, UnitClass, GetNumPartyMembers = UnitExists, UnitGUID, UnitName, UnitClass, GetNumPartyMembers
local COLORS, Wipe, SetText, GetClassRGB, RGBToHex = NS.COLORS, NS.Wipe, NS.SetText, NS.GetClassRGB, NS.RGBToHex

local PartyMeter = CreateFrame("Frame", "AZS_MinUI_PartyMeter", UIParent)
NS.RegisterMovableBox("PartyMeter", "Party DPS", PartyMeter)

PartyMeter.icon = PartyMeter:CreateTexture(nil, "ARTWORK")
PartyMeter.icon:SetSize(16, 16)
PartyMeter.icon:SetPoint("TOPLEFT", PartyMeter, "TOPLEFT", 12, -10)
PartyMeter.icon:SetTexture(NS.Media("grouprole-icons-dps"))
PartyMeter.header = NS.CreateFontText(PartyMeter, 0, "LEFT")
PartyMeter.header:SetPoint("LEFT", PartyMeter.icon, "RIGHT", 4, 0)
PartyMeter.header:SetText("|cffffea89PARTY DPS|r")

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

local function ResetPartyDamage()
	Wipe(DamageByGuid)
	combatStartTime = nil
	RefreshRosterMap()
end

local ResetBtn = NS.CreateResetButton(PartyMeter, "Reset Party DPS", ResetPartyDamage)
PartyMeter.totalDps = NS.CreateFontText(PartyMeter, -1, "RIGHT")
PartyMeter.totalDps:SetPoint("RIGHT", ResetBtn, "LEFT", -6, 0)

local MAX_PARTY_ROWS = 5
local MeterRows = {}
for i = 1, MAX_PARTY_ROWS do
	local row = CreateFrame("Frame", nil, PartyMeter)
	row:SetHeight(23)
	row:SetPoint("TOPLEFT",  PartyMeter, "TOPLEFT",   12, -32 - (i - 1) * 25)
	row:SetPoint("TOPRIGHT", PartyMeter, "TOPRIGHT", -12, -32 - (i - 1) * 25)
	row.val = NS.CreateFontText(row, -2, "RIGHT")
	row.val:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	row.name = NS.CreateFontText(row, -2, "LEFT")
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.name:SetPoint("RIGHT", row.val, "LEFT", -6, 0)
	NS.SetNoWrap(row.name, 12)
	row.barFrame, row.bar, row.barBg = NS.CreateThinBar(row, 5)
	row.barFrame:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 1)
	row.barFrame:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
	row:Hide()
	MeterRows[i] = row
end

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
	elseif event == "PLAYER_ENTERING_WORLD" then ResetPartyDamage(); return end
	if not sourceGUID or not NS.DB or NS.GetModuleMode("PartyMeter") ~= "minimal" then return end
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

local Entries, EntryPool = {}, {}
local function PushEntry(idx, name, dps, cls, isMe)
	local e = EntryPool[idx]
	if not e then e = {}; EntryPool[idx] = e end
	e.name, e.dps, e.class, e.isMe = name, dps, cls, isMe
	Entries[idx] = e
end
local function SortByDps(a, b) return (a.dps or 0) > (b.dps or 0) end

local PREVIEW_ENTRIES = {
	{ name = "You (Preview)", dps = 4820, class = "DEATHKNIGHT", isMe = true  },
	{ name = "Arthas",        dps = 3950, class = "PALADIN",     isMe = false },
	{ name = "Jaina",         dps = 3120, class = "MAGE",        isMe = false },
	{ name = "Thrall",        dps = 2460, class = "SHAMAN",      isMe = false },
}

local Mod = { frame = PartyMeter, Reset = ResetPartyDamage }

function Mod.Update(ctx)
	if NS.GetModuleMode("PartyMeter") ~= "minimal" then
		if not ctx.isEditing then PartyMeter:Hide() end
		return
	end
	local runClock = ctx.runClock or 0
	if runClock > 0 and lastRunClock > 5 and runClock < 3 then ResetPartyDamage() end
	lastRunClock = runClock
	local nParty = GetNumPartyMembers() or 0
	local cfg = (NS.DB and NS.DB.party) or NS.DEFAULTS.party
	if (nParty == 0 and not (cfg and cfg.showMeterWhenSolo) and not ctx.isEditing)
	or (NS.IsBoxHidden("PartyMeter") and not ctx.isEditing) then
		if PartyMeter:IsShown() then PartyMeter:Hide() end
		return
	end
	PartyMeter:Show()

	local list
	if ctx.isEditing and nParty == 0 then
		list = PREVIEW_ENTRIES
	else
		Wipe(Entries)
		local raw
		if type(_G.AZS_GetPartyMeter) == "function" then
			local ok, res = pcall(_G.AZS_GetPartyMeter)
			if ok and type(res) == "table" and #res > 0 then raw = res end
		elseif type(_G.AZS_PARTY_METER) == "table" and #_G.AZS_PARTY_METER > 0 then
			raw = _G.AZS_PARTY_METER
		end
		local count = 0
		if raw then
			local myName = UnitName("player")
			for i = 1, #raw do
				local item = raw[i]
				if item and (tonumber(item.dps) or tonumber(item.dmg) or 0) >= 0 then
					count = count + 1
					PushEntry(count, item.name or ("Ally " .. i), tonumber(item.dps) or 0, item.class, item.name == myName)
				end
			end
		end
		if count == 0 then
			if not next(RosterGuids) then RefreshRosterMap() end
			local elapsed = combatStartTime and max(1.0, ctx.now - combatStartTime) or max(1.0, runClock)
			local playerGuid = UnitGUID("player")
			local _, myServerDps = NS.GetMeterCached(ctx.tickId)
			for guid in pairs(RosterGuids) do
				local dps = (DamageByGuid[guid] or 0) / elapsed
				if guid == playerGuid and myServerDps and myServerDps > dps then dps = myServerDps end
				count = count + 1
				PushEntry(count, NameByGuid[guid] or "Ally", dps, ClassByGuid[guid], guid == playerGuid)
			end
		end
		tsort(Entries, SortByDps)
		list = Entries
	end

	local totalDps, topDps = 0, 0
	for i = 1, #list do
		local d = list[i].dps or 0
		totalDps = totalDps + d
		if d > topDps then topDps = d end
	end
	SetText(PartyMeter.totalDps, "|cffffea89" .. NS.FormatNumber(totalDps) .. "/s|r")
	for i = 1, MAX_PARTY_ROWS do
		local row, e = MeterRows[i], list[i]
		if e then
			local r, g, b = GetClassRGB(e.class, COLORS.normal[1], COLORS.normal[2], COLORS.normal[3])
			local share = (totalDps > 0) and ((e.dps / totalDps) * 100) or 0
			SetText(row.name, fmt("|cff8892a4%d.|r %s%s|r", i, RGBToHex(r, g, b), e.name or "Ally"))
			SetText(row.val, fmt("%s/s |cff94a3b8(%.0f%%)|r", NS.FormatNumber(e.dps or 0), share))
			row.bar:SetStatusBarColor(r, g, b, e.isMe and 1.0 or 0.85)
			row.bar:SetValue((topDps > 0) and ((e.dps / topDps) * 100) or 0)
			row:Show()
		elseif row:IsShown() then
			row:Hide()
		end
	end
end

NS.Modules.PartyMeter = Mod
