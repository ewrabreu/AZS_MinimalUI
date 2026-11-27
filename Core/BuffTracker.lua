local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, max, min = math.floor, math.max, math.min
local fmt, lower, find, match, gsub, sub, gmatch = string.format, string.lower, string.find, string.match, string.gsub, string.sub, string.gmatch
local tonumber, tostring, type, pairs, ipairs, pcall, select = tonumber, tostring, type, pairs, ipairs, pcall, select
local tsort = table.sort
local GetTime, GetSpellInfo, UnitBuff, UnitDebuff, UnitGUID, UnitName, UnitClass, UnitRace =
	GetTime, GetSpellInfo, UnitBuff, UnitDebuff, UnitGUID, UnitName, UnitClass, UnitRace
local GetSpellCooldown, GetInventoryItemCooldown, GetInventoryItemTexture, GetInventoryItemLink =
	GetSpellCooldown, GetInventoryItemCooldown, GetInventoryItemTexture, GetInventoryItemLink
local Wipe, ResolveIcon, GetSpellIcon = NS.Wipe, NS.ResolveIcon, NS.GetSpellIcon

local Tracker = {}
NS.BuffTracker = Tracker

Tracker.CAT_COLORS = {
	buff   = { 0.00, 0.85, 0.72, 0.90 },
	item   = { 1.00, 0.78, 0.24, 0.92 },
	talent = { 0.72, 0.45, 1.00, 0.92 },
	race   = { 1.00, 0.62, 0.20, 0.92 },
	debuff = { 0.95, 0.24, 0.28, 0.98 },
}

local RARITY_RGB = {
	[1] = { 0.12, 0.92, 0.20, 0.95 },
	[2] = { 0.18, 0.58, 1.00, 0.95 },
	[3] = { 0.74, 0.36, 1.00, 0.95 },
	[4] = { 1.00, 0.55, 0.12, 0.98 },
}
local RARITY_HEX = {
	[1] = "ff1eff00",
	[2] = "ff0070dd",
	[3] = "ffa335ee",
	[4] = "ffff8000",
}
local SLOT_LABELS = { ring = "Ring", trinket = "Trinket", amulet = "Amulet" }

function Tracker.GetCategoryColor(cat, rarity)
	if cat == "item" and rarity then
		local rc = RARITY_RGB[tonumber(rarity) or 0]
		if rc then return rc end
	end
	return Tracker.CAT_COLORS[cat] or Tracker.CAT_COLORS.buff
end

function Tracker.GetRarityHex(rarity)
	local genCol = _G.AZS_GEN and _G.AZS_GEN.rarityColor and _G.AZS_GEN.rarityColor[rarity]
	if genCol then return genCol end
	return RARITY_HEX[tonumber(rarity) or 0] or "ffffffff"
end

function Tracker.GetSlotLabel(slot)
	return SLOT_LABELS[slot] or "Item"
end

local function StripCooldownPhrases(low)
	local s = gsub(low, "once%s+every%s+%d+%.?%d*%s*s%a*", "")
	s = gsub(s, "every%s+%d+%.?%d*%s*s%a*", "")
	s = gsub(s, "a%s+cada%s+%d+%.?%d*%s*s%a*", "")
	s = gsub(s, "%d+%.?%d*%s*s%a*%s+cooldown", "")
	s = gsub(s, "%d+%.?%d*%s*s%a*%s+recarga", "")
	s = gsub(s, "cooldown:?%s*%d+%.?%d*%s*s%a*", "")
	s = gsub(s, "recarga:?%s*%d+%.?%d*%s*s%a*", "")
	return s
end

local function ParseDurationFromText(txt)
	if type(txt) ~= "string" or txt == "" then return nil end
	local low = StripCooldownPhrases(lower(txt))
	local n = match(low, "for%s+(%d+%.?%d*)%s*sec")
		or match(low, "for%s+(%d+%.?%d*)%s*s%A")
		or match(low, "for%s+(%d+%.?%d*)%s*s$")
		or match(low, "lasts%s+(%d+%.?%d*)%s*sec")
		or match(low, "lasts%s+(%d+%.?%d*)%s*s%A")
		or match(low, "lasts%s+(%d+%.?%d*)%s*s$")
		or match(low, "over%s+(%d+%.?%d*)%s*sec")
		or match(low, "over%s+(%d+%.?%d*)%s*s%A")
		or match(low, "over%s+(%d+%.?%d*)%s*s$")
		or match(low, "duration:?%s*(%d+%.?%d*)%s*s")
		or match(low, "(%d+%.?%d*)%s*s%a*%s+of%s+immun")
		or match(low, "(%d+%.?%d*)%s*s%a*%s+of%s+invinc")
		or match(low, "(%d+%.?%d*)%s*s%a*%s+of%s+invuln")
		or match(low, "(%d+%.?%d*)%s*s%a*%s+immun")
		or match(low, "(%d+%.?%d*)%s*s%a*%s+invinc")
		or match(low, "(%d+%.?%d*)%s*s%a*%s+invuln")
		or match(low, "por%s+(%d+%.?%d*)%s*seg")
		or match(low, "por%s+(%d+%.?%d*)%s*s%A")
		or match(low, "por%s+(%d+%.?%d*)%s*s$")
		or match(low, "durante%s+(%d+%.?%d*)%s*seg")
		or match(low, "durante%s+(%d+%.?%d*)%s*s%A")
		or match(low, "durante%s+(%d+%.?%d*)%s*s$")
		or match(low, "dura%a*%s*:?%s*(%d+%.?%d*)%s*s")
	if not n then

		n = match(low, "%((%d+%.?%d*)%s*s[ec%a]*%)")
			or match(low, "(%d+%.?%d*)%s*sec")
			or match(low, "(%d+%.?%d*)%s*seg")
	end
	local val = n and tonumber(n) or nil
	return (val and val > 0 and val <= 600) and val or nil
end

local function ParseCooldownFromText(txt)
	if type(txt) ~= "string" or txt == "" then return nil end
	local low = lower(txt)
	local n = match(low, "once%s+every%s+(%d+%.?%d*)%s*s")
		or match(low, "every%s+(%d+%.?%d*)%s*s")
		or match(low, "(%d+%.?%d*)%s*s%a*%s+cooldown")
		or match(low, "cooldown:?%s*(%d+%.?%d*)%s*s")
		or match(low, "a%s+cada%s+(%d+%.?%d*)%s*s")
		or match(low, "recarga:?%s*(%d+%.?%d*)%s*s")
		or match(low, "(%d+%.?%d*)%s*s%a*%s+cd")
	local val = n and tonumber(n) or nil
	return (val and val > 0) and val or nil
end

local function IconBase(icon)
	if type(icon) ~= "string" or icon == "" then return nil end
	local base = gsub(icon, "^.*\\", "")
	base = gsub(base, "^.*/", "")
	return lower(base)
end

local BUFF_KEYWORDS = {
	"buff", "shield", "escudo", "immun", "imun", "invinc", "invulner",
	"shout", "grito", "berserk", "fury", "furia", "bloodlust", "heroism",
	"wrath", "avatar", "reckless", "evasion", "cloak", "vanish", "sprint",
	"dash", "barkskin", "survival", "last_stand", "fortif", "barrier",
	"ward", "reflect", "absorb", "blessing", "bencao", "aura", "armor",
	"ice_block", "divine_shield", "divine_protection", "divine_intervention",
	"pain_suppression", "dispersion", "guardian", "sacred", "innervate",
	"arcane_power", "icy_veins", "combustion", "rapid_fire", "bestial",
	"metamorphosis", "avenging", "wings", "shadowmeld", "stoneform",
	"perception", "darkflight", "will_of_the_forsaken", "gift_of_the_naaru",
	"rocket_jump", "war_stomp", "arcane_torrent", "escape_artist", "quaking_palm",
	"blade_flurry", "adrenaline", "killing_spree", "death_wish", "sweeping",
	"icebound", "anti_magic", "anti-magic", "horn_of_winter", "horn of winter",
	"slice_and_dice", "slice and dice", "power_infusion", "power infusion", "pw_shield",
	"rockbiter", "empowerment", "thorns", "tigereye", "mana_tea", "storm_earth",
	"blur", "darkness", "demon_spikes", "demon spikes",
	"more damage for", "damage for", "speed for", "faster for", "of immunity",
	"damage reduction", "haste", "increases your", "grants ", "absorbs ",
}

local function TextLooksLikeBuff(str)
	if type(str) ~= "string" or str == "" then return false end
	local low = lower(str)
	for i = 1, #BUFF_KEYWORDS do
		if find(low, BUFF_KEYWORDS[i], 1, true) then return true end
	end
	return false
end

local function IsTalentBuffWorthy(tal)
	if not tal then return false end
	if (tonumber(tal.ranks) or 1) <= 1 then return true end
	local txt = tal.text
	if type(txt) ~= "string" then return false end
	local low = lower(txt)
	return find(low, "buff", 1, true) ~= nil
		or find(low, "shield", 1, true) ~= nil
		or find(low, "shout", 1, true) ~= nil
		or find(low, "immun", 1, true) ~= nil
		or find(low, "every ", 1, true) ~= nil
		or find(low, "cooldown", 1, true) ~= nil
		or find(low, "while a shield", 1, true) ~= nil
end

local function FormatTalentText(tal, rank)
	local txt = tal.text or ""
	if tal.v ~= nil then
		local val = (tonumber(tal.v) or 0) * (tonumber(rank) or 1)
		local display = (val < 1 and val > 0) and (val * 100) or val
		local rounded = floor(display * 10 + 0.5) / 10
		local s = (rounded == floor(rounded)) and fmt("%d", rounded) or fmt("%.1f", rounded)
		txt = gsub(txt, "{v}", s)
	end
	return txt
end

local RacialByKey, RacialByLowerName, SpellGenByKey, genIndexed = {}, {}, {}, false
local function EnsureGenIndex()
	if genIndexed then return end
	local gen = _G.AZS_GEN
	if type(gen) ~= "table" then return end
	genIndexed = true
	if type(gen.races) == "table" then
		for i = 1, #gen.races do
			local r = gen.races[i]
			if type(r.racials) == "table" then
				for j = 1, #r.racials do
					local rac = r.racials[j]
					if rac.key then RacialByKey[rac.key] = rac end
					if rac.name then RacialByLowerName[lower(rac.name)] = rac end
				end
			end
		end
	end
	if type(gen.spells) == "table" then
		for _, list in pairs(gen.spells) do
			if type(list) == "table" then
				for i = 1, #list do
					local sp = list[i]
					if sp and sp.key then SpellGenByKey[sp.key] = sp end
				end
			end
		end
	end
end

local ScanTip = CreateFrame("GameTooltip", "AZS_MinUI_BuffScanTooltip", UIParent, "GameTooltipTemplate")
ScanTip:SetOwner(UIParent, "ANCHOR_NONE")
local ScannedTipIds, ScannedTipNames = {}, {}

local function ParseRemainingFromTooltipLines()
	local num = ScanTip:NumLines() or 0
	local descDur, liveRem
	for i = 2, min(num, 8) do
		local fs = _G["AZS_MinUI_BuffScanTooltipTextLeft" .. i]
		local txt = fs and fs:GetText()
		if type(txt) == "string" and txt ~= "" then
			local low = lower(txt)
			local remS = match(low, "^(%d+%.?%d*)%s*s[ec%a]*%s+remaining")
				or match(low, "^(%d+%.?%d*)%s*s[eg%a]*%s+restant")
			if remS then
				liveRem = tonumber(remS)
			else
				local remM = match(low, "^(%d+)%s*min%a*%s+remaining")
				if remM then liveRem = tonumber(remM) * 60 end
			end
			if not descDur then
				descDur = ParseDurationFromText(txt)
			end
		end
	end
	return descDur, liveRem
end

local ObservedBuffSpellIds = {}
local KnownDurById, KnownDurByName, KnownDurByIcon = {}, {}, {}
local KnownCdByName = {}
local ActiveAurasByGuid = {}
local ActiveAurasByName = {}
local CastTimesByKey = {}
local FirstSeenPlayerBuff = {}
local SpellCastTrack = {}

local function RecordKnownSpellMeta(id, name, txt, icon, forceDur)
	local dur = ParseDurationFromText(txt)
	local cd = ParseCooldownFromText(txt)
	local low = type(name) == "string" and name ~= "" and lower(name) or nil
	local lowIc = IconBase(icon)
	if dur and dur > 0 then
		if id and id > 0 and (forceDur or not KnownDurById[id]) then KnownDurById[id] = dur end
		if low and (forceDur or not KnownDurByName[low]) then KnownDurByName[low] = dur end
		if lowIc and (forceDur or not KnownDurByIcon[lowIc]) then KnownDurByIcon[lowIc] = dur end
	end
	if cd and cd > 0 and low and (forceDur or not KnownCdByName[low]) then
		KnownCdByName[low] = cd
	end
	return dur
end

local function ScanTooltipForSpell(sid, name, icon, unit, auraIndex)
	local low = type(name) == "string" and lower(name) or nil
	if sid and sid > 0 and ScannedTipIds[sid] then return KnownDurById[sid], nil end
	if (not sid or sid <= 0) and low and ScannedTipNames[low] then return KnownDurByName[low], nil end
	ScanTip:SetOwner(UIParent, "ANCHOR_NONE")
	ScanTip:ClearLines()
	local ok
	if unit and auraIndex then
		ok = pcall(ScanTip.SetUnitBuff, ScanTip, unit, auraIndex)
	elseif sid and sid > 0 then
		ok = pcall(ScanTip.SetHyperlink, ScanTip, "spell:" .. sid)
	end
	if not ok then return nil, nil end
	local descDur, liveRem = ParseRemainingFromTooltipLines()
	if sid and sid > 0 then ScannedTipIds[sid] = true end
	if low then ScannedTipNames[low] = true end
	if descDur and descDur > 0 then
		if sid and sid > 0 and not KnownDurById[sid] then KnownDurById[sid] = descDur end
		if low and not KnownDurByName[low] then KnownDurByName[low] = descDur end
		local lowIc = IconBase(icon)
		if lowIc and not KnownDurByIcon[lowIc] then KnownDurByIcon[lowIc] = descDur end
	end
	return descDur, liveRem
end

local function TrackUnitAura(guid, unitName, spellId, spellName, now, isApply)
	if not spellId or spellId <= 0 then return end
	local lowName = type(spellName) == "string" and lower(spellName) or nil
	if isApply then
		local dur = KnownDurById[spellId] or (lowName and KnownDurByName[lowName]) or 0
		if guid and guid ~= "" then
			local gTbl = ActiveAurasByGuid[guid]
			if not gTbl then gTbl = {}; ActiveAurasByGuid[guid] = gTbl end
			local rec = gTbl[spellId]
			if not rec then rec = {}; gTbl[spellId] = rec end
			rec.appliedAt, rec.dur, rec.name, rec.spellId = now, dur, spellName, spellId
			rec.icon = GetSpellIcon(spellId)
		end
		if unitName and unitName ~= "" then
			local nTbl = ActiveAurasByName[unitName]
			if not nTbl then nTbl = {}; ActiveAurasByName[unitName] = nTbl end
			local rec = nTbl[spellId]
			if not rec then rec = {}; nTbl[spellId] = rec end
			rec.appliedAt, rec.dur, rec.name, rec.spellId = now, dur, spellName, spellId
			rec.icon = GetSpellIcon(spellId)
		end
		if lowName then
			local pGuid = UnitGUID("player")
			if guid == pGuid or unitName == UnitName("player") then
				ObservedBuffSpellIds[spellId] = true
				CastTimesByKey[lowName] = now
			end
		end
	else
		if guid and ActiveAurasByGuid[guid] then ActiveAurasByGuid[guid][spellId] = nil end
		if unitName and ActiveAurasByName[unitName] then ActiveAurasByName[unitName][spellId] = nil end
	end
end

local EventFrame = CreateFrame("Frame", "AZS_MinUI_BuffTrackerEvents")
EventFrame._azsMinUI = true
EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

local lastAbilityReqAt = 0
function Tracker.MaybeRequestAbilities(now, inHub)
	if inHub then return end
	local ab = _G.AZS_ABILITIES
	if type(ab) == "table" and #ab > 0 then return end
	if (now - lastAbilityReqAt) < 4.0 then return end
	if type(_G.AZS_RequestAbilities) == "function" then
		lastAbilityReqAt = now
		pcall(_G.AZS_RequestAbilities)
	end
end

EventFrame:SetScript("OnEvent", function(_, event, _, subEvent, srcGUID, srcName, _, destGUID, destName, _, spellId, spellName, _, auraType)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" or subEvent == "SPELL_AURA_APPLIED_DOSE" then
			if auraType == "BUFF" then
				TrackUnitAura(destGUID, destName, tonumber(spellId), spellName, GetTime(), true)
			end
		elseif subEvent == "SPELL_AURA_REMOVED" then
			if auraType == "BUFF" then
				TrackUnitAura(destGUID, destName, tonumber(spellId), spellName, GetTime(), false)
			end
		elseif subEvent == "SPELL_CAST_SUCCESS" then
			local pGuid = UnitGUID("player")
			if srcGUID == pGuid and type(spellName) == "string" and spellName ~= "" then
				CastTimesByKey[lower(spellName)] = GetTime()
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		Wipe(ActiveAurasByGuid); Wipe(ActiveAurasByName); Wipe(FirstSeenPlayerBuff)
		Wipe(CastTimesByKey); Wipe(SpellCastTrack); Wipe(ScannedTipIds); Wipe(ScannedTipNames)
		lastAbilityReqAt = 0
	end
end)

local lastSyncTick = -1
local AzsBuffRemById, AzsBuffRemByLowerName, AzsBuffRemByIcon, AzsBuffRemByKey = {}, {}, {}, {}
local SpellActById, SpellActByLowerName, SpellActByIcon = {}, {}, {}
local TimerByLowerName, TimerByIcon, TimerPool = {}, {}, {}

local function NormalizeServerLeft(rawLeft)
	local v = tonumber(rawLeft) or 0
	if v > 36000 then v = v / 1000 end
	return v
end

local function IndexBuffNamesAndIcon(sid, key, left, idMap, nameMap, iconMap, keyMap)
	if sid and sid > 0 then idMap[sid] = left end
	if key and key ~= "" and keyMap then keyMap[lower(key)] = left end
	local azsName = (sid and sid > 0 and type(_G.AZS_SpellName) == "function") and _G.AZS_SpellName(sid) or nil
	local wowName, _, wowIcon
	if sid and sid > 0 then wowName, _, wowIcon = GetSpellInfo(sid) end
	if type(azsName) == "string" and azsName ~= "" then nameMap[lower(azsName)] = left end
	if type(wowName) == "string" and wowName ~= "" then nameMap[lower(wowName)] = left end
	local genSp = key and SpellGenByKey[key]
	if genSp then
		if genSp.name and genSp.name ~= "" then nameMap[lower(genSp.name)] = left end
		local gIc = IconBase(genSp.icon)
		if gIc then iconMap[gIc] = left end
	end
	local wIc = IconBase(wowIcon)
	if wIc then iconMap[wIc] = left end
end

function Tracker.SyncTick(ctx)
	if ctx.tickId == lastSyncTick then return end
	lastSyncTick = ctx.tickId
	EnsureGenIndex()
	local now, runClock = ctx.now, ctx.runClock or 0
	Tracker.MaybeRequestAbilities(now, ctx.inHub)

	Wipe(AzsBuffRemById); Wipe(AzsBuffRemByLowerName); Wipe(AzsBuffRemByIcon); Wipe(AzsBuffRemByKey)
	local abuffs = _G.AZS_BUFFS
	if type(abuffs) == "table" and #abuffs > 0 then
		local updatedAt = tonumber(_G.AZS_BUFFS_UPDATED) or now
		local dt = max(0, now - updatedAt)
		for i = 1, #abuffs do
			local b = abuffs[i]
			local rawSpell = b and b.spell
			local sid = tonumber(rawSpell) or 0
			local skey = (sid == 0 and type(rawSpell) == "string" and rawSpell ~= "") and rawSpell or nil
			local left = NormalizeServerLeft(b and b.left) - dt
			if (sid > 0 or skey) and left > 0 then
				if sid > 0 then
					ObservedBuffSpellIds[sid] = true
					if not KnownDurById[sid] or left > KnownDurById[sid] then
						KnownDurById[sid] = floor(left * 10 + 0.5) / 10
					end
				end
				IndexBuffNamesAndIcon(sid, skey, left, AzsBuffRemById, AzsBuffRemByLowerName, AzsBuffRemByIcon, AzsBuffRemByKey)
			end
		end
	end

	Wipe(TimerByLowerName); Wipe(TimerByIcon)
	local timers = _G.AZS_TIMERS
	if type(timers) == "table" then
		for i = 1, #timers do
			local t = timers[i]
			if t and t.name then
				local rem = max(0, (tonumber(t.ready) or 0) - runClock)
				local dur = tonumber(t.wait) or 0
				local rec = TimerPool[i]
				if not rec then rec = {}; TimerPool[i] = rec end
				rec.name, rec.icon, rec.kind, rec.rem, rec.dur, rec.ready = t.name, t.icon, t.kind, rem, dur, (rem <= 0.05)
				TimerByLowerName[lower(t.name)] = rec
				local ic = IconBase(t.icon)
				if ic then TimerByIcon[ic] = rec end
			end
		end
	end

	Wipe(SpellActById); Wipe(SpellActByLowerName); Wipe(SpellActByIcon)
	local tips = _G.AZS_SPELLTIPS
	local spells = _G.AZS_SPELLS
	if type(spells) == "table" then
		local spAt = tonumber(_G.AZS_SPELLS_AT) or now
		local spDt = max(0, now - spAt)
		for i = 1, #spells do
			local s = spells[i]
			local sid = tonumber(s and s.spell) or 0
			local skey = s and s.key
			local genSp = skey and SpellGenByKey[skey]
			local tip = (type(tips) == "table" and skey) and tips[skey] or nil
			local wowName, _, wowIcon
			if sid > 0 then wowName, _, wowIcon = GetSpellInfo(sid) end
			local azsName = (sid > 0 and type(_G.AZS_SpellName) == "function") and _G.AZS_SpellName(sid) or nil
			local dispName = azsName or wowName or (genSp and genSp.name) or skey
			local dispIcon = wowIcon or (genSp and ResolveIcon(genSp.icon)) or GetSpellIcon(sid)

			local knownDur
			if tip and tip ~= "" then
				knownDur = RecordKnownSpellMeta(sid, dispName, tip, dispIcon, true)
				if wowName and wowName ~= dispName then RecordKnownSpellMeta(sid, wowName, tip, dispIcon, true) end
				if genSp and genSp.name and genSp.name ~= dispName then RecordKnownSpellMeta(sid, genSp.name, tip, dispIcon, true) end
			end
			if not knownDur then
				knownDur = (sid > 0 and KnownDurById[sid])
					or (dispName and KnownDurByName[lower(dispName)])
					or (IconBase(dispIcon) and KnownDurByIcon[IconBase(dispIcon)])
			end

			local isBuffSkill = (sid > 0 and ObservedBuffSpellIds[sid])
				or (skey and RacialByKey[skey] ~= nil)
				or TextLooksLikeBuff(skey)
				or TextLooksLikeBuff(dispName)
				or TextLooksLikeBuff(tip)

			if isBuffSkill then
				if (not knownDur) and sid > 0 and not ScannedTipIds[sid] then
					knownDur = ScanTooltipForSpell(sid, dispName, dispIcon)
				end
				local remCd = max(0, (tonumber(s.cd) or 0) - spDt)
				local cdMax = tonumber(s.cdmax) or 0
				local trackKey = skey or (sid > 0 and tostring(sid)) or dispName
				if trackKey then
					local tr = SpellCastTrack[trackKey]
					if not tr then tr = { lastCd = remCd }; SpellCastTrack[trackKey] = tr end

					if remCd > 0.5 and (tr.lastCd <= 0.5 or remCd > (tr.lastCd + 1.2)) then
						local elapsed = (cdMax > remCd) and (cdMax - remCd) or 0
						tr.castAt = now - elapsed
					end
					tr.lastCd, tr.cdMax, tr.sid, tr.name, tr.icon, tr.dur = remCd, cdMax, sid, dispName, dispIcon, knownDur or 0
					tr.tip = tip or ""
					local actRem = 0
					if knownDur and knownDur > 0 then
						if tr.castAt then
							actRem = max(0, (tr.castAt + knownDur) - now)
						elseif cdMax > knownDur and remCd > 0 then
							local elapsed = cdMax - remCd
							if elapsed >= 0 and elapsed < knownDur then
								actRem = knownDur - elapsed
							end
						end
					end
					tr.activeRem = actRem
					if actRem > 0 then
						IndexBuffNamesAndIcon(sid, skey, actRem, SpellActById, SpellActByLowerName, SpellActByIcon, nil)
					end
				end
			end
		end
	end

	local abilities = _G.AZS_ABILITIES
	if type(abilities) == "table" then
		for i = 1, #abilities do
			local a = abilities[i]
			if a then RecordKnownSpellMeta(tonumber(a.spell), a.name, a.text, a.icon, false) end
		end
	end
	local gear = _G.AZS_GEAR
	if type(gear) == "table" then
		for i = 1, #gear do
			local g = gear[i]
			if g then RecordKnownSpellMeta(nil, g.name, g.text, g.icon, false) end
		end
	end
	for _, rac in pairs(RacialByKey) do
		RecordKnownSpellMeta(nil, rac.name, rac.effect, rac.icon, false)
	end
end

function Tracker.ResolveAuraRemaining(unit, name, spellId, duration, expTime, now, icon, auraIndex)
	if duration and duration > 0 and expTime and expTime > now then
		local rem = expTime - now
		if spellId and spellId > 0 and (not KnownDurById[spellId] or duration > KnownDurById[spellId]) then
			KnownDurById[spellId] = duration
		end
		return rem
	end
	local sid = tonumber(spellId) or 0
	local lowName = type(name) == "string" and lower(name) or nil
	local lowIc = IconBase(icon)
	if unit == "player" then
		if sid > 0 and AzsBuffRemById[sid] then return AzsBuffRemById[sid] end
		if lowName and AzsBuffRemByLowerName[lowName] then return AzsBuffRemByLowerName[lowName] end
		if lowIc and AzsBuffRemByIcon[lowIc] then return AzsBuffRemByIcon[lowIc] end
		if sid > 0 and SpellActById[sid] then return SpellActById[sid] end
		if lowName and SpellActByLowerName[lowName] then return SpellActByLowerName[lowName] end
		if lowIc and SpellActByIcon[lowIc] then return SpellActByIcon[lowIc] end
	end

	local knownDur = (sid > 0 and KnownDurById[sid])
		or (lowName and KnownDurByName[lowName])
		or (lowIc and KnownDurByIcon[lowIc])
	if (not knownDur) and unit == "player" and auraIndex then
		local scannedDur, liveRem = ScanTooltipForSpell(sid, name, icon, unit, auraIndex)
		if liveRem and liveRem > 0 then return liveRem end
		knownDur = scannedDur
	end

	local guid = UnitGUID(unit)
	local uName = UnitName(unit)
	local rec = (guid and ActiveAurasByGuid[guid] and ActiveAurasByGuid[guid][sid])
		or (uName and ActiveAurasByName[uName] and ActiveAurasByName[uName][sid])
	if rec and knownDur and knownDur > 0 then
		local rem = (rec.appliedAt + knownDur) - now
		if rem > 0 then return rem end
	end
	if unit == "player" and lowName and knownDur and knownDur > 0 then
		local firstSeen = FirstSeenPlayerBuff[lowName]
		if not firstSeen then firstSeen = now; FirstSeenPlayerBuff[lowName] = now end
		local rem = (firstSeen + knownDur) - now
		if rem > 0 then return rem end
	end
	return 0
end

local function IsTalentActivatableOrCooldown(tal)
	if not tal then return false end
	local txt = tal.text
	if type(txt) ~= "string" or txt == "" then return false end
	local low = lower(txt)
	return find(low, "once every ", 1, true) ~= nil
		or find(low, "once a second", 1, true) ~= nil
		or find(low, "would kill you", 1, true) ~= nil
		or find(low, "drop below", 1, true) ~= nil
		or find(low, "when you die", 1, true) ~= nil
		or match(low, "every%s+%d+%.?%d*%s*s[ec]") ~= nil
		or match(low, "every%s+{v}th%s+") ~= nil
		or match(low, "every%s+%d+th%s+") ~= nil
		or match(low, "%d+%.?%d*%s*s[ec%a]*%s+cooldown") ~= nil
		or match(low, "cooldown:?%s*%d+%.?%d*%s*s") ~= nil
end

local cachedTalentKey, CachedAllTalents, CachedPlayerTalents, CachedActivatableTalents = "", {}, {}, {}
local function SortTalentsDesc(a, b)
	local aKey = (a.maxRank <= 1) and 1 or 0
	local bKey = (b.maxRank <= 1) and 1 or 0
	if aKey ~= bKey then return aKey > bKey end
	if a.treeIdx ~= b.treeIdx then return a.treeIdx < b.treeIdx end
	if a.row ~= b.row then return a.row < b.row end
	return a.idx < b.idx
end

function Tracker.GetAllPlayerTalents()
	local _, cls = UnitClass("player")
	if not cls then return CachedAllTalents end
	local trees = _G.AZS_TALENT_TREES and _G.AZS_TALENT_TREES[cls]
	if type(trees) ~= "table" then return CachedAllTalents end
	if RegisterCVar then pcall(RegisterCVar, "azsTalents" .. cls, "") end
	local ok, saved = pcall(GetCVar, "azsTalents" .. cls)
	saved = (ok and type(saved) == "string") and saved or ""
	local cacheKey = cls .. ":" .. saved
	if cacheKey == cachedTalentKey then return CachedAllTalents end
	cachedTalentKey = cacheKey
	Wipe(CachedAllTalents)
	Wipe(CachedPlayerTalents)
	Wipe(CachedActivatableTalents)
	if saved == "" then return CachedAllTalents end

	local parsed
	if type(_G.AZS_TALENT_BUILD) == "table" and type(_G.AZS_TALENT_BUILD.parse) == "function" then
		local okP, res = pcall(_G.AZS_TALENT_BUILD.parse, cls, saved)
		if okP and type(res) == "table" then parsed = res end
	end

	if parsed then
		for treeIdx = 1, #trees do
			local tree = trees[treeIdx]
			local rlist = parsed[treeIdx]
			if type(tree) == "table" and type(rlist) == "table" then
				for idx = 1, #tree do
					local rank = tonumber(rlist[idx]) or 0
					local tal = tree[idx]
					if rank > 0 and tal then
						local desc = FormatTalentText(tal, rank)
						RecordKnownSpellMeta(nil, tal.name, desc)
						local rec = {
							key = tal.key,
							name = tal.name or tal.key or "Talent",
							icon = ResolveIcon(tal.icon),
							rank = rank,
							maxRank = tal.ranks or 1,
							row = tal.row or 0,
							treeIdx = treeIdx,
							idx = idx,
							treeName = tree.name or "",
							text = desc,
							buffWorthy = IsTalentBuffWorthy(tal),
							activatable = IsTalentActivatableOrCooldown(tal),
						}
						CachedAllTalents[#CachedAllTalents + 1] = rec
						if rec.buffWorthy then CachedPlayerTalents[#CachedPlayerTalents + 1] = rec end
						if rec.activatable then CachedActivatableTalents[#CachedActivatableTalents + 1] = rec end
					end
				end
			end
		end
	else
		local treeIdx = 1
		for part in gmatch(saved .. "-", "([^-]*)-") do
			local tree = trees[treeIdx]
			if type(tree) == "table" then
				for idx = 1, #part do
					local rank = tonumber(sub(part, idx, idx)) or 0
					local tal = tree[idx]
					if rank > 0 and tal then
						local desc = FormatTalentText(tal, rank)
						RecordKnownSpellMeta(nil, tal.name, desc)
						local rec = {
							key = tal.key,
							name = tal.name or tal.key or "Talent",
							icon = ResolveIcon(tal.icon),
							rank = rank,
							maxRank = tal.ranks or 1,
							row = tal.row or 0,
							treeIdx = treeIdx,
							idx = idx,
							treeName = tree.name or "",
							text = desc,
							buffWorthy = IsTalentBuffWorthy(tal),
							activatable = IsTalentActivatableOrCooldown(tal),
						}
						CachedAllTalents[#CachedAllTalents + 1] = rec
						if rec.buffWorthy then CachedPlayerTalents[#CachedPlayerTalents + 1] = rec end
						if rec.activatable then CachedActivatableTalents[#CachedActivatableTalents + 1] = rec end
					end
				end
			end
			treeIdx = treeIdx + 1
		end
	end
	if #CachedAllTalents > 1 then tsort(CachedAllTalents, SortTalentsDesc) end
	if #CachedActivatableTalents > 1 then tsort(CachedActivatableTalents, SortTalentsDesc) end
	return CachedAllTalents
end

function Tracker.GetPlayerTalentBuffs()
	Tracker.GetAllPlayerTalents()
	return CachedPlayerTalents
end

function Tracker.GetPlayerActivatableTalents()
	Tracker.GetAllPlayerTalents()
	return CachedActivatableTalents
end

local PlayerRacialsCache, RacialSeen, RacialPool = {}, {}, {}
function Tracker.GetUnitRacials(unit, out)
	out = out or PlayerRacialsCache
	Wipe(out); Wipe(RacialSeen)
	EnsureGenIndex()
	local idx = 0
	if unit == "player" then
		local ab = _G.AZS_ABILITIES
		if type(ab) == "table" and #ab > 0 then
			for i = 1, #ab do
				local a = ab[i]
				if a and (a.kind == "racial" or (a.key and RacialByKey[a.key])) then
					local rac = a.key and RacialByKey[a.key]
					local rName = a.name or (rac and rac.name) or a.key
					local low = lower(rName or "")
					if low ~= "" and not RacialSeen[low] then
						RacialSeen[low] = true
						idx = idx + 1
						local rec = RacialPool[idx]
						if not rec then rec = {}; RacialPool[idx] = rec end
						rec.key, rec.name = a.key, rName
						rec.icon = ResolveIcon(a.icon or (rac and rac.icon), a.spell)
						rec.spellId = tonumber(a.spell)
						rec.text = (a.text and a.text ~= "" and a.text) or (rac and rac.effect) or ""
						rec.cd, rec.cdmax = tonumber(a.cd) or 0, tonumber(a.cdmax) or 0
						out[idx] = rec
					end
				end
			end
		end
	end
	if idx == 0 then
		local _, raceToken = UnitRace(unit)
		local rInfo = raceToken and _G.AZS_GEN and _G.AZS_GEN.raceByToken and _G.AZS_GEN.raceByToken[string.upper(raceToken)]
		if rInfo and type(rInfo.racials) == "table" then
			for i = 1, #rInfo.racials do
				local rac = rInfo.racials[i]
				idx = idx + 1
				local rec = RacialPool[idx]
				if not rec then rec = {}; RacialPool[idx] = rec end
				rec.key, rec.name, rec.icon, rec.spellId = rac.key, rac.name or rac.key, ResolveIcon(rac.icon), nil
				rec.text, rec.cd, rec.cdmax = rac.effect or "", 0, 0
				out[idx] = rec
			end
		end
	end
	return out
end

local function AcquireEntry(pool, idx)
	local e = pool[idx]
	if not e then e = {}; pool[idx] = e end
	e.cat, e.name, e.icon, e.count, e.rem, e.dur = nil, nil, nil, 0, 0, 0
	e.auraIndex, e.isDebuff, e.spellId, e.rarity, e.sub, e.text, e.cdRem, e.cdDur, e.ready =
		nil, false, nil, nil, nil, nil, 0, 0, nil
	return e
end

local PlayerPool, SeenPlayerName, SeenPlayerId, TempRacials, ActiveNowNames = {}, {}, {}, {}, {}
local SHIELD_NOT_IMMUNITY = {
	"power word: shield", "pw_shield", "ice barrier", "ice_barrier",
	"anti-magic shell", "anti_magic", "sacred shield", "sacred_shield",
	"holy shield", "holy_shield", "shield wall", "shield_wall",
	"lightning shield", "lightning_shield", "stoneform", "shield slam",
	"shield_slam", "bone shield", "mana shield", "barkskin",
	"fortifying brew", "icebound", "bell shield",
}
local IMMUNITY_NAME_PATTERNS = {
	"divine shield", "divine_shield", "ice block", "ice_block",
	"cloak of shadows", "cloak_of_shadows", "dispersion",
	"divine intervention", "divine_intervention", "netherwalk",
	"deterrence", "aspect of the turtle", "shadowmeld",
	"will of the forsaken", "will_of_the_forsaken", "rocket jump",
	"rocket_jump", "cheat death", "cheat_death", "celestial fortune",
	"bm_celestial_fortune", "last resort", "vg_last_resort",
	"untouchable", "invulnerab", "invincib",
}
local IMMUNITY_TIP_PATTERNS = {
	"of immunity", "immune to all", "immune to damage",
	"cannot take damage", "nothing can touch you", "untouchable",
	"invulnerab", "invincib",
}

local function TextIsShieldNotImmunity(str)
	if type(str) ~= "string" or str == "" then return false end
	local low = lower(str)
	if find(low, "divine shield", 1, true) or find(low, "divine_shield", 1, true) then return false end
	for i = 1, #SHIELD_NOT_IMMUNITY do
		if find(low, SHIELD_NOT_IMMUNITY[i], 1, true) then return true end
	end
	return false
end

local function TextIsImmunity(str, isTip)
	if type(str) ~= "string" or str == "" then return false end
	if TextIsShieldNotImmunity(str) then return false end
	local low = lower(str)
	if find(low, "invincible", 1, true) and find(low, "mount", 1, true) then return false end
	local pats = isTip and IMMUNITY_TIP_PATTERNS or IMMUNITY_NAME_PATTERNS
	for i = 1, #pats do
		if find(low, pats[i], 1, true) then return true end
	end
	return false
end

function Tracker.GetPlayerImmunityRemaining(ctx)
	Tracker.SyncTick(ctx)
	local now, runClock = ctx.now, ctx.runClock or 0
	local isImm, bestRem = false, 0

	for i = 1, 32 do
		local bName, _, icon, _, _, duration, expTime, _, _, _, spellId = UnitBuff("player", i)
		if not bName then break end
		local sid = tonumber(spellId) or 0
		if TextIsImmunity(bName, false) then
			isImm = true
			local rem = Tracker.ResolveAuraRemaining("player", bName, sid, duration, expTime, now, icon, i)
			if rem > bestRem then bestRem = rem end
		end
	end

	local pbuffs = _G.AZS_PLAYER_BUFFS
	if type(pbuffs) == "table" then
		for i = 1, #pbuffs do
			local pb = pbuffs[i]
			if pb and not TextIsShieldNotImmunity(pb.name) and not TextIsShieldNotImmunity(pb.key)
			and (TextIsImmunity(pb.name, false) or TextIsImmunity(pb.key, false)) then
				local rem = (tonumber(pb.ends) or 0) - runClock
				if rem > 0 or (tonumber(pb.duration) or 0) <= 0 then
					isImm = true
					if rem > bestRem then bestRem = rem end
				end
			end
		end
	end

	local abuffs = _G.AZS_BUFFS
	if type(abuffs) == "table" and #abuffs > 0 then
		local dt = max(0, now - (tonumber(_G.AZS_BUFFS_UPDATED) or now))
		for i = 1, #abuffs do
			local b = abuffs[i]
			local rawSpell = b and b.spell
			local sid = tonumber(rawSpell) or 0
			local rem = NormalizeServerLeft(b and b.left) - dt
			if rem > 0 then
				local sname = (sid > 0 and ((type(_G.AZS_SpellName) == "function" and _G.AZS_SpellName(sid)) or GetSpellInfo(sid)))
					or (type(rawSpell) == "string" and rawSpell) or nil
				if TextIsImmunity(sname, false) then
					isImm = true
					if rem > bestRem then bestRem = rem end
				end
			end
		end
	end

	for _, tr in pairs(SpellCastTrack) do
		if tr.activeRem and tr.activeRem > 0 then
			if not TextIsShieldNotImmunity(tr.name) and not TextIsShieldNotImmunity(tr.key)
			and (TextIsImmunity(tr.name, false) or TextIsImmunity(tr.key, false) or TextIsImmunity(tr.tip, true)) then
				isImm = true
				if tr.activeRem > bestRem then bestRem = tr.activeRem end
			end
		end
	end

	return isImm, bestRem
end

local function GetTimerFor(name, icon)
	local low = type(name) == "string" and lower(name) or nil
	if low and TimerByLowerName[low] then return TimerByLowerName[low] end
	local lowIc = type(icon) == "string" and lower(gsub(icon, "^Interface\\Icons\\", "")) or nil
	if lowIc and TimerByIcon[lowIc] then return TimerByIcon[lowIc] end
	return nil
end
Tracker.GetTimerFor = GetTimerFor

function Tracker.CollectPlayerBuffs(ctx, cfg, out)
	Tracker.SyncTick(ctx)
	Wipe(out); Wipe(SeenPlayerName); Wipe(SeenPlayerId); Wipe(ActiveNowNames)
	local now, runClock = ctx.now, ctx.runClock or 0
	local n = 0

	for i = 1, 32 do
		local bName, _, icon, count, _, duration, expTime, _, _, _, spellId = UnitBuff("player", i)
		if not bName then break end
		local sid = tonumber(spellId) or 0
		local low = lower(bName)
		ActiveNowNames[low] = true
		if sid > 0 then ObservedBuffSpellIds[sid] = true; SeenPlayerId[sid] = true end
		SeenPlayerName[low] = true
		local rem = Tracker.ResolveAuraRemaining("player", bName, sid, duration, expTime, now, icon, i)
		n = n + 1
		local e = AcquireEntry(PlayerPool, n)
		e.cat, e.name, e.icon, e.count, e.rem = "buff", bName, icon, count or 0, rem
		e.auraIndex, e.isDebuff, e.spellId = i, false, sid > 0 and sid or nil
		out[n] = e
	end

	for k in pairs(FirstSeenPlayerBuff) do
		if not ActiveNowNames[k] then FirstSeenPlayerBuff[k] = nil end
	end

	local abuffs = _G.AZS_BUFFS
	if type(abuffs) == "table" and #abuffs > 0 then
		local updatedAt = tonumber(_G.AZS_BUFFS_UPDATED) or now
		local dt = max(0, now - updatedAt)
		for i = 1, #abuffs do
			local b = abuffs[i]
			local rawSpell = b and b.spell
			local sid = tonumber(rawSpell) or 0
			local skey = (sid == 0 and type(rawSpell) == "string" and rawSpell ~= "") and rawSpell or nil
			local rem = NormalizeServerLeft(b and b.left) - dt
			if (sid > 0 or skey) and rem > 0 and (sid == 0 or not SeenPlayerId[sid]) then
				local genSp = skey and SpellGenByKey[skey]
				local sname = (sid > 0 and ((type(_G.AZS_SpellName) == "function" and _G.AZS_SpellName(sid)) or GetSpellInfo(sid)))
					or (genSp and genSp.name) or skey or ("Buff #" .. sid)
				local low = lower(sname)
				if not SeenPlayerName[low] then
					if sid > 0 then SeenPlayerId[sid] = true end
					SeenPlayerName[low] = true
					n = n + 1
					local e = AcquireEntry(PlayerPool, n)
					e.cat, e.name, e.rem, e.spellId = "buff", sname, rem, sid > 0 and sid or nil
					e.icon = (sid > 0 and GetSpellIcon(sid)) or (genSp and ResolveIcon(genSp.icon)) or NS.QUESTION_ICON
					e.sub = "Active Buff"
					out[n] = e
				end
			end
		end
	end

	for _, tr in pairs(SpellCastTrack) do
		if tr.activeRem and tr.activeRem > 0 and tr.name then
			local low = lower(tr.name)
			if (not tr.sid or tr.sid <= 0 or not SeenPlayerId[tr.sid]) and not SeenPlayerName[low] then
				if tr.sid and tr.sid > 0 then SeenPlayerId[tr.sid] = true end
				SeenPlayerName[low] = true
				n = n + 1
				local e = AcquireEntry(PlayerPool, n)
				e.cat, e.name, e.icon, e.rem, e.spellId = "buff", tr.name, tr.icon or NS.QUESTION_ICON, tr.activeRem, tr.sid > 0 and tr.sid or nil
				e.sub = "Active Skill Buff"
				e.text = tr.tip
				out[n] = e
			end
		end
	end

	if not cfg or cfg.showItemBuffs ~= false then
		local gear = _G.AZS_GEAR
		if type(gear) == "table" then
			for i = 1, #gear do
				local g = gear[i]
				if g then
					local gName = g.name or g.bonus or Tracker.GetSlotLabel(g.slot)
					local low = lower(gName)
					if not SeenPlayerName[low] then
						SeenPlayerName[low] = true
						local tInfo = GetTimerFor(gName, g.icon)
						n = n + 1
						local e = AcquireEntry(PlayerPool, n)
						e.cat = "item"
						e.name = gName
						e.icon = ResolveIcon(g.icon)
						e.rarity = tonumber(g.rarity) or 1
						e.count = (g.slot == "amulet" and tonumber(g.amount)) or 0
						e.sub = Tracker.GetSlotLabel(g.slot) .. (g.slot == "amulet" and g.amount and (" · Rank " .. g.amount) or "")
						e.text = g.text and gsub(g.text, " · ", "\n") or ""
						if tInfo then
							e.cdRem, e.cdDur, e.ready = tInfo.rem, tInfo.dur, tInfo.ready
						end
						out[n] = e
					end
				end
			end
		end
	end

	if not cfg or cfg.showTalentRaceBuffs ~= false then

		local racials = Tracker.GetUnitRacials("player", TempRacials)
		for i = 1, #racials do
			local r = racials[i]
			local low = lower(r.name or "")
			if low ~= "" and not SeenPlayerName[low] then
				SeenPlayerName[low] = true
				local tInfo = GetTimerFor(r.name, r.icon)
				n = n + 1
				local e = AcquireEntry(PlayerPool, n)
				e.cat, e.name, e.icon, e.spellId = "race", r.name, r.icon, r.spellId
				e.sub = "Racial Buff"
				e.text = r.text
				if tInfo then e.cdRem, e.cdDur, e.ready = tInfo.rem, tInfo.dur, tInfo.ready end
				out[n] = e
			end
		end

		local ab = _G.AZS_ABILITIES
		if type(ab) == "table" then
			for i = 1, #ab do
				local a = ab[i]
				if a and a.passive and a.kind ~= "racial" then
					local aName = a.name or a.key or "Passive"
					local low = lower(aName)
					if not SeenPlayerName[low] then
						SeenPlayerName[low] = true
						local tInfo = GetTimerFor(aName, a.icon)
						n = n + 1
						local e = AcquireEntry(PlayerPool, n)
						e.cat, e.name, e.icon, e.spellId = "talent", aName, ResolveIcon(a.icon, a.spell), tonumber(a.spell)
						e.sub = "Talent / Passive"
						e.text = a.text or ""
						if tInfo then e.cdRem, e.cdDur, e.ready = tInfo.rem, tInfo.dur, tInfo.ready end
						out[n] = e
					end
				end
			end
		end

		local talents = Tracker.GetPlayerTalentBuffs()
		for i = 1, #talents do
			local t = talents[i]
			local low = lower(t.name or "")
			if low ~= "" and not SeenPlayerName[low] then
				SeenPlayerName[low] = true
				local tInfo = GetTimerFor(t.name, t.icon)
				n = n + 1
				local e = AcquireEntry(PlayerPool, n)
				e.cat, e.name, e.icon = "talent", t.name, t.icon
				e.count = (t.maxRank > 1) and t.rank or 0
				e.sub = fmt("Talent · %s (%d/%d)", t.treeName, t.rank, t.maxRank)
				e.text = t.text
				if tInfo then e.cdRem, e.cdDur, e.ready = tInfo.rem, tInfo.dur, tInfo.ready end
				out[n] = e
			end
		end
	end

	if not cfg or cfg.showDebuffs ~= false then
		for i = 1, 16 do
			local dName, _, icon, count, _, duration, expTime, _, _, _, spellId = UnitDebuff("player", i)
			if not dName then break end
			local rem = (duration and duration > 0 and expTime) and max(0, expTime - now) or 0
			n = n + 1
			local e = AcquireEntry(PlayerPool, n)
			e.cat, e.name, e.icon, e.count, e.rem = "debuff", dName, icon, count or 0, rem
			e.auraIndex, e.isDebuff, e.spellId = i, true, tonumber(spellId)
			out[n] = e
		end
		local hexes = _G.AZS_HEXES
		if type(hexes) == "table" then
			for i = 1, #hexes do
				local h = hexes[i]
				local untilT = tonumber(h and h["until"]) or 0
				local rem = untilT - runClock
				if rem > 0 then
					n = n + 1
					local e = AcquireEntry(PlayerPool, n)
					e.cat, e.name, e.icon, e.rem = "debuff", "Hex: " .. tostring(h.key or "Curse"), "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", rem
					e.isDebuff, e.sub = true, "Cursed Chest Hex"
					e.text = h.pct and fmt("Active hex effect (%s%%).", tostring(h.pct)) or "Active cursed chest hex."
					out[n] = e
				end
			end
		end
	end

	return n
end

local CdPool, SeenCdName = {}, {}
local function KindToCat(kind, name)
	local k = lower(tostring(kind or ""))
	if find(k, "ring", 1, true) or find(k, "trinket", 1, true) or find(k, "amulet", 1, true)
	or find(k, "gear", 1, true) or find(k, "jewel", 1, true) or find(k, "item", 1, true) then
		return "item"
	elseif find(k, "rac", 1, true) or (name and RacialByLowerName[lower(name)]) then
		return "race"
	elseif find(k, "tal", 1, true) or find(k, "perk", 1, true) or find(k, "pass", 1, true) then
		return "talent"
	end
	return "buff"
end

local function SortCooldowns(a, b)

	local sa = (a.activeRem > 0) and 1 or ((a.cdRem > 0.05) and 2 or 3)
	local sb = (b.activeRem > 0) and 1 or ((b.cdRem > 0.05) and 2 or 3)
	if sa ~= sb then return sa < sb end
	if sa == 1 then
		if a.activeRem ~= b.activeRem then return a.activeRem < b.activeRem end
	elseif sa == 2 then
		if a.cdRem ~= b.cdRem then return a.cdRem < b.cdRem end
	end
	return (a.name or "") < (b.name or "")
end

local function FindActiveRemByNameOrId(name, spellId, icon)
	if spellId and spellId > 0 then
		if AzsBuffRemById[spellId] then return AzsBuffRemById[spellId] end
		if SpellActById[spellId] then return SpellActById[spellId] end
	end
	local low = type(name) == "string" and lower(name) or nil
	if low then
		if AzsBuffRemByLowerName[low] then return AzsBuffRemByLowerName[low] end
		if SpellActByLowerName[low] then return SpellActByLowerName[low] end
	end
	local lowIc = IconBase(icon)
	if lowIc then
		if AzsBuffRemByIcon[lowIc] then return AzsBuffRemByIcon[lowIc] end
		if SpellActByIcon[lowIc] then return SpellActByIcon[lowIc] end
	end
	if low or (spellId and spellId > 0) then
		for i = 1, 32 do
			local bName, _, bIcon, _, _, duration, expTime, _, _, _, sid = UnitBuff("player", i)
			if not bName then break end
			if (spellId and spellId > 0 and tonumber(sid) == spellId)
			or (low and lower(bName) == low)
			or (lowIc and IconBase(bIcon) == lowIc) then
				local rem = Tracker.ResolveAuraRemaining("player", bName, sid, duration, expTime, GetTime(), bIcon, i)
				return rem > 0 and rem or 0
			end
		end
	end
	return 0
end

local function PushCooldown(out, n, name, icon, cat, cdRem, cdDur, activeRem, sub, text, rarity, spellId)
	local low = lower(name or "")
	if low == "" or SeenCdName[low] then return n end
	SeenCdName[low] = true
	n = n + 1
	local e = CdPool[n]
	if not e then e = {}; CdPool[n] = e end
	e.name = name
	e.icon = icon or NS.QUESTION_ICON
	e.cat = cat or "buff"
	e.cdRem = max(0, cdRem or 0)
	e.cdDur = max(0, cdDur or 0)
	e.activeRem = max(0, activeRem or 0)
	e.ready = (e.cdRem <= 0.05 and e.activeRem <= 0)
	e.sub = sub or ""
	e.text = text or ""
	e.rarity = rarity
	e.spellId = spellId
	out[n] = e
	return n
end

local EQUIP_JEWEL_SLOTS = { 2, 11, 12, 13, 14 }
local GearByLowerName = {}

function Tracker.CollectCooldowns(ctx, cfg, out)
	Tracker.SyncTick(ctx)
	Wipe(out); Wipe(SeenCdName); Wipe(GearByLowerName)
	local now, runClock = ctx.now, ctx.runClock or 0
	local showReady = not cfg or cfg.showReadyCooldowns ~= false
	local n = 0

	if type(_G.AZS_GEAR) == "table" then
		for i = 1, #_G.AZS_GEAR do
			local g = _G.AZS_GEAR[i]
			if g and g.name then GearByLowerName[lower(g.name)] = g end
		end
	end

	local timers = _G.AZS_TIMERS
	if type(timers) == "table" then
		for i = 1, #timers do
			local t = timers[i]
			if t and t.name then
				local rem = max(0, (tonumber(t.ready) or 0) - runClock)
				local dur = tonumber(t.wait) or 0
				local actRem = FindActiveRemByNameOrId(t.name, nil, t.icon)
				if showReady or rem > 0.05 or actRem > 0 then
					local g = GearByLowerName[lower(t.name)]
					local cat = g and "item" or KindToCat(t.kind, t.name)
					local rac = RacialByLowerName[lower(t.name)]
					local subTxt = g and Tracker.GetSlotLabel(g.slot) or (rac and "Racial") or (t.kind and t.kind ~= "" and t.kind) or "Timer"
					local desc = (g and g.text and gsub(g.text, " · ", "\n")) or (rac and rac.effect) or ""
					n = PushCooldown(out, n, t.name, ResolveIcon(t.icon), cat, rem, dur, actRem, subTxt, desc, g and tonumber(g.rarity), nil)
				end
			end
		end
	end

	local spells = _G.AZS_SPELLS
	if type(spells) == "table" then
		local updatedAt = tonumber(_G.AZS_SPELLS_AT) or now
		local dt = max(0, now - updatedAt)
		local tips = _G.AZS_SPELLTIPS
		for i = 1, #spells do
			local s = spells[i]
			local sid = tonumber(s and s.spell) or 0
			if sid > 0 then
				local sname = (type(_G.AZS_SpellName) == "function" and _G.AZS_SpellName(sid)) or GetSpellInfo(sid) or s.key or ("Spell #" .. sid)
				local tip = (tips and s.key) and tips[s.key] or ""
				local isBuffSkill = ObservedBuffSpellIds[sid]
					or (s.key and RacialByKey[s.key] ~= nil)
					or TextLooksLikeBuff(s.key)
					or TextLooksLikeBuff(sname)
					or TextLooksLikeBuff(tip)
				if isBuffSkill then
					local cdMax = tonumber(s.cdmax) or tonumber(s.cd) or 0
					local rem = max(0, (tonumber(s.cd) or 0) - dt)
					local actRem = FindActiveRemByNameOrId(sname, sid, GetSpellIcon(sid))
					if (cdMax > 0 or rem > 0 or actRem > 0) and (showReady or rem > 0.05 or actRem > 0) then
						local cat = (s.key and RacialByKey[s.key]) and "race" or "buff"
						local subTxt = (cat == "race") and "Racial Skill" or fmt("Skill · Rank %d", tonumber(s.rank) or 1)
						n = PushCooldown(out, n, sname, GetSpellIcon(sid), cat, rem, cdMax, actRem, subTxt, tip, nil, sid)
					end
				end
			end
		end
	end

	local ab = _G.AZS_ABILITIES
	if type(ab) == "table" then
		local updatedAt = tonumber(_G.AZS_ABILITIES_UPDATED) or now
		local dt = max(0, now - updatedAt)
		for i = 1, #ab do
			local a = ab[i]
			if a and a.name then
				local sid = tonumber(a.spell) or 0
				local cdMax = tonumber(a.cdmax) or tonumber(a.cd) or ParseCooldownFromText(a.text) or 0
				local rem = max(0, (tonumber(a.cd) or 0) - dt)
				if rem <= 0 and cdMax > 0 then
					local lastCast = CastTimesByKey[lower(a.name)]
					if lastCast then rem = max(0, (lastCast + cdMax) - now) end
				end
				local isRelevant = (a.kind == "racial") or (a.key and RacialByKey[a.key] ~= nil)
					or ObservedBuffSpellIds[sid] or TextLooksLikeBuff(a.name) or TextLooksLikeBuff(a.text)
				if isRelevant and (cdMax > 0 or rem > 0) then
					local actRem = FindActiveRemByNameOrId(a.name, sid, a.icon)
					if showReady or rem > 0.05 or actRem > 0 then
						local cat = (a.kind == "racial" or (a.key and RacialByKey[a.key])) and "race" or (a.passive and "talent" or "buff")
						n = PushCooldown(out, n, a.name, ResolveIcon(a.icon, sid), cat, rem, cdMax, actRem,
							cat == "race" and "Racial" or (cat == "talent" and "Talent" or "Ability"), a.text or "", nil, sid > 0 and sid or nil)
					end
				end
			end
		end
	end

	local racials = Tracker.GetUnitRacials("player", TempRacials)
	for i = 1, #racials do
		local r = racials[i]
		local cdDur = ParseCooldownFromText(r.text)
		if cdDur and cdDur > 0 then
			local lastCast = CastTimesByKey[lower(r.name or "")]
			local rem = lastCast and max(0, (lastCast + cdDur) - now) or 0
			local actRem = FindActiveRemByNameOrId(r.name, r.spellId, r.icon)
			if showReady or rem > 0.05 or actRem > 0 then
				n = PushCooldown(out, n, r.name, r.icon, "race", rem, cdDur, actRem, "Racial", r.text, nil, r.spellId)
			end
		end
	end

	if type(_G.AZS_GEAR) == "table" then
		for i = 1, #_G.AZS_GEAR do
			local g = _G.AZS_GEAR[i]
			local cdDur = g and ParseCooldownFromText(g.text)
			if cdDur and cdDur > 0 then
				local gName = g.name or g.bonus or Tracker.GetSlotLabel(g.slot)
				local lastCast = CastTimesByKey[lower(gName)]
				local rem = lastCast and max(0, (lastCast + cdDur) - now) or 0
				local actRem = FindActiveRemByNameOrId(gName, nil, g.icon)
				if showReady or rem > 0.05 or actRem > 0 then
					n = PushCooldown(out, n, gName, ResolveIcon(g.icon), "item", rem, cdDur, actRem,
						Tracker.GetSlotLabel(g.slot), g.text and gsub(g.text, " · ", "\n") or "", tonumber(g.rarity), nil)
				end
			end
		end
	end

	local talents = Tracker.GetPlayerTalentBuffs()
	for i = 1, #talents do
		local t = talents[i]
		local cdDur = ParseCooldownFromText(t.text)
		if cdDur and cdDur > 0 then
			local lastCast = CastTimesByKey[lower(t.name or "")]
			local rem = lastCast and max(0, (lastCast + cdDur) - now) or 0
			local actRem = FindActiveRemByNameOrId(t.name, nil)
			if showReady or rem > 0.05 or actRem > 0 then
				n = PushCooldown(out, n, t.name, t.icon, "talent", rem, cdDur, actRem,
					"Talent · " .. t.treeName, t.text, nil, nil)
			end
		end
	end

	for i = 1, #EQUIP_JEWEL_SLOTS do
		local slotId = EQUIP_JEWEL_SLOTS[i]
		local start, dur, enable = GetInventoryItemCooldown("player", slotId)
		if enable == 1 and start and start > 0 and dur and dur > 1.5 then
			local rem = (start + dur) - now
			if rem > 0.05 then
				local link = GetInventoryItemLink("player", slotId)
				local itemName = (link and match(link, "%[(.-)%]")) or ("Equipped Item #" .. slotId)
				local tex = GetInventoryItemTexture("player", slotId)
				n = PushCooldown(out, n, itemName, tex, "item", rem, dur, 0, "Equipped Item", "Item on cooldown.", nil, nil)
			end
		end
	end

	for sid in pairs(ObservedBuffSpellIds) do
		local start, dur, enable = GetSpellCooldown(sid)
		if enable == 1 and start and start > 0 and dur and dur > 1.5 then
			local rem = (start + dur) - now
			if rem > 0.05 then
				local sname = GetSpellInfo(sid)
				if sname then
					local actRem = FindActiveRemByNameOrId(sname, sid, GetSpellIcon(sid))
					n = PushCooldown(out, n, sname, GetSpellIcon(sid), "buff", rem, dur, actRem, "Skill", "", nil, sid)
				end
			end
		end
	end

	tsort(out, SortCooldowns)
	return n
end

function Tracker.ShowEntryTooltip(owner, anchor, entry, unit)
	if not (GameTooltip and entry) then return end
	GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
	if entry.auraIndex and unit then
		if entry.isDebuff then GameTooltip:SetUnitDebuff(unit, entry.auraIndex)
		else GameTooltip:SetUnitBuff(unit, entry.auraIndex) end
		if entry.rem and entry.rem > 0 then
			GameTooltip:AddLine(fmt("Time remaining: %s", NS.FormatShortTime(entry.rem, true)), 0.35, 1.0, 0.72)
		end
		GameTooltip:Show()
		return
	end
	if entry.cat == "item" then
		GameTooltip:SetText(fmt("|c%s%s|r", Tracker.GetRarityHex(entry.rarity), entry.name or "Item"))
	elseif entry.cat == "talent" then
		GameTooltip:SetText(entry.name or "Talent", 0.80, 0.60, 1.00)
	elseif entry.cat == "race" then
		GameTooltip:SetText(entry.name or "Racial", 1.00, 0.76, 0.35)
	elseif entry.cat == "debuff" then
		GameTooltip:SetText(entry.name or "Debuff", 1.00, 0.35, 0.35)
	else
		GameTooltip:SetText(entry.name or "Buff", 1.00, 0.92, 0.55)
	end
	if entry.sub and entry.sub ~= "" then
		GameTooltip:AddLine(entry.sub, 0.62, 0.68, 0.78)
	end
	if entry.text and entry.text ~= "" then
		GameTooltip:AddLine(entry.text, 0.92, 0.94, 0.98, true)
	elseif entry.spellId and entry.spellId > 0 then
		local tips = _G.AZS_SPELLTIPS
		local spells = _G.AZS_SPELLS
		if type(tips) == "table" and type(spells) == "table" then
			for i = 1, #spells do
				local s = spells[i]
				if tonumber(s.spell) == entry.spellId and s.key and tips[s.key] then
					GameTooltip:AddLine(tips[s.key], 1.0, 0.86, 0.35, true)
					break
				end
			end
		end
	end
	if entry.activeRem and entry.activeRem > 0 then
		GameTooltip:AddLine(fmt("Active: %s remaining", NS.FormatShortTime(entry.activeRem, true)), 0.35, 1.0, 0.65)
	elseif entry.rem and entry.rem > 0 then
		GameTooltip:AddLine(fmt("Remaining: %s", NS.FormatShortTime(entry.rem, true)), 0.35, 1.0, 0.65)
	end
	if entry.cdRem and entry.cdRem > 0.05 then
		local cdStr = entry.cdDur and entry.cdDur > 0
			and fmt("Next activation: %s (of %ds CD)", NS.FormatShortTime(entry.cdRem, true), floor(entry.cdDur + 0.5))
			or fmt("Next activation: %s", NS.FormatShortTime(entry.cdRem, true))
		GameTooltip:AddLine(cdStr, 1.0, 0.82, 0.25)
	elseif entry.ready then
		GameTooltip:AddLine(entry.cdDur and entry.cdDur > 0 and fmt("Status: Ready (%ds CD)", floor(entry.cdDur + 0.5)) or "Status: Ready", 0.40, 1.0, 0.60)
	end
	GameTooltip:Show()
end
