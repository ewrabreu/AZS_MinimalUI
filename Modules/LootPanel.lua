local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, max, min, tonumber, tostring, type, pairs, pcall = math.floor, math.max, math.min, tonumber, tostring, type, pairs, pcall
local lower, find, sub, match, gmatch, rep, fmt = string.lower, string.find, string.sub, string.match, string.gmatch, string.rep, string.format
local tinsert, tremove, tconcat, GetTime, SendAddonMessage = table.insert, table.remove, table.concat, GetTime, SendAddonMessage
local Wipe, SetText, RGBToHex, SetNoWrap = NS.Wipe, NS.SetText, NS.RGBToHex, NS.SetNoWrap

local LootPanel = CreateFrame("Frame", "AZS_MinUI_LootPanel", UIParent)
NS.RegisterMovableBox("LootPanel", "Loot & Drops", LootPanel)

LootPanel.icon = LootPanel:CreateTexture(nil, "ARTWORK")
LootPanel.icon:SetSize(16, 16)
LootPanel.icon:SetPoint("TOPLEFT", LootPanel, "TOPLEFT", 12, -10)
LootPanel.icon:SetTexture(NS.Media("point_plate"))
LootPanel.icon:SetVertexColor(1.0, 0.85, 0.25, 1.0)
LootPanel.header = NS.CreateFontText(LootPanel, 0, "LEFT")
LootPanel.header:SetPoint("LEFT", LootPanel.icon, "RIGHT", 5, 0)
LootPanel.header:SetText("|cffffea89LOOT & DROPS|r")

local DropHistory, RecentDedup, SeenBagIds = {}, {}, {}
local MAX_HISTORY, MAX_DROP_ROWS = 48, 5
local totalItemsLooted, chestsLooted, sessionGoldFromChat, lastRunClock = 0, 0, 0, 0
local sessionStartMoney, wasInHub = nil, nil
local OwnedSnapA, OwnedSnapB, CurLinks = {}, {}, {}
local OwnedSnapshot, ownedKeyCount = nil, 0
local bagWarmupUntil, lastPeriodicBagCheck = 0, 0
local KnownCX, KnownCY, CurCX, CurCY = {}, {}, {}, {}

local COLOR_HEX_TO_RARITY = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6 }
local FALLBACK_RARITY = {
	[0] = { 0.85, 0.85, 0.85 }, [1] = { 0.12, 1.00, 0.00 }, [2] = { 0.00, 0.44, 0.87 },
	[3] = { 0.64, 0.21, 0.93 }, [4] = { 1.00, 0.50, 0.00 }, [5] = { 0.90, 0.75, 0.45 },
}
local SplitCSV, SplitSet = NS.SplitCSV, NS.SplitSet
local ARMOR_LOCS     = SplitSet("HEAD,SHOULDER,CHEST,ROBE,WRIST,HAND,WAIST,LEGS,FEET,CLOAK,SHIELD,BODY,TABARD", "INVTYPE_")
local WEAPON_LOCS    = SplitSet("WEAPON,2HWEAPON,WEAPONMAINHAND,WEAPONOFFHAND,HOLDABLE,RANGED,RANGEDRIGHT,THROWN,RELIC", "INVTYPE_")
local ACCESSORY_LOCS = SplitSet("FINGER,TRINKET,NECK", "INVTYPE_")
local ACCESSORY_KW   = SplitCSV("ring,anel,signet,band,loop,seal,trinket,berloque,talisman,idol,totem,insignia,neck,amulet,pendant,necklace,medallion")
local ARMOR_SUB_KW   = SplitCSV("plate,placa,mail,malha,leather,couro,cloth,tecido,shield,escudo")
local ARMOR_KW       = SplitCSV("helm,hood,crown,cowl,mask,head,shoulder,pauldrons,spaulders,mantle,chest,tunic,breastplate,robe,vest,wrist,bracer,bindings,cuffs,hand,glove,gauntlet,grips,waist,belt,girdle,sash,legs,leggings,legplates,greaves,pant,feet,boot,sabatons,treads,cloak,cape,back,shield,bulwark,aegis,armor")
local WEAPON_KW      = SplitCSV("sword,axe,mace,dagger,staff,wand,bow,gun,crossbow,polearm,spear,glaive,fist,blade,hammer,main hand,off hand,ranged,weapon")

local function HasAnyKW(str, list)
	if type(str) ~= "string" or str == "" then return false end
	local low = lower(str)
	for i = 1, #list do
		if find(low, list[i], 1, true) then return true end
	end
	return false
end

local function ExtractItemId(ref)
	if type(ref) == "number" then return ref end
	if type(ref) ~= "string" then return nil end
	return tonumber(match(ref, "item:(%d+)")) or tonumber(ref)
end

local function RarityFromLink(link)
	if type(link) ~= "string" then return nil end
	local hex = match(link, "|c%x%x(%x%x%x%x%x%x)")
	return hex and COLOR_HEX_TO_RARITY[lower(hex)] or nil
end

local function GetItemColor(rarity, setName, isAzsItem)
	if isAzsItem and type(_G.AZS_ItemRgb) == "function" then
		local ok, r, g, b = pcall(_G.AZS_ItemRgb, rarity, setName)
		if ok and r and g and b then return r, g, b end
	end
	if not isAzsItem and type(_G.GetItemQualityColor) == "function" then
		local r, g, b = _G.GetItemQualityColor(rarity or 1)
		if r and g and b then return r, g, b end
	end
	if setName and setName ~= "" then return 0.15, 0.95, 0.45 end
	local c = FALLBACK_RARITY[tonumber(rarity) or 0] or FALLBACK_RARITY[0]
	return c[1], c[2], c[3]
end

local function FormatAzsAffixes(stats, sep)
	if type(stats) ~= "string" or stats == "" then return "" end
	if type(_G.AZS_AffixText) == "function" then
		local ok, txt = pcall(_G.AZS_AffixText, stats, sep or "\n", "|cff4dff66")
		if ok and type(txt) == "string" then return txt end
	end
	local out = {}
	for s in gmatch(stats, "[^%^]+") do
		local mark = sub(s, 1, 1)
		if mark == "!" then out[#out + 1] = "|cffffc94d★ " .. sub(s, 2) .. "|r"
		elseif mark == "#" then out[#out + 1] = "|cffff8822" .. sub(s, 2) .. "|r"
		else out[#out + 1] = "|cff4dff66" .. s .. "|r" end
	end
	return tconcat(out, sep or "\n")
end

local function ClassifyItemCategory(itemType, itemSubType, equipLoc, itemName, slotHint)
	if type(equipLoc) == "string" and equipLoc ~= "" then
		if ACCESSORY_LOCS[equipLoc] then return "accessory" end
		if ARMOR_LOCS[equipLoc] then return "armor" end
		if WEAPON_LOCS[equipLoc] then return "weapon" end
		if equipLoc == "INVTYPE_BAG" then return "other" end
	end
	if HasAnyKW(itemSubType, ACCESSORY_KW) or HasAnyKW(slotHint, ACCESSORY_KW) or HasAnyKW(itemName, ACCESSORY_KW) then return "accessory" end
	if HasAnyKW(itemSubType, ARMOR_SUB_KW) then return "armor" end
	if HasAnyKW(slotHint, WEAPON_KW) or HasAnyKW(itemName, WEAPON_KW) then return "weapon" end
	if type(itemType) == "string" then
		local lt = lower(itemType)
		if find(lt, "weapon", 1, true) or find(lt, "arma", 1, true) then return "weapon" end
	end
	if HasAnyKW(slotHint, ARMOR_KW) or HasAnyKW(itemName, ARMOR_KW) then return "armor" end
	return "other"
end

local function PopulateEntryMetadata(entry)
	if entry.isAzsItem then
		entry.category = ClassifyItemCategory(nil, nil, nil, entry.name, entry.slotName or entry.slotLabel)
		entry.isEquip = true
		entry.needsInfo = false
		return
	end
	local query = (entry.link and not find(entry.link, "item:0", 1, true)) and entry.link or (entry.itemId and entry.itemId > 0 and entry.itemId)
	if not query then
		entry.category = ClassifyItemCategory(nil, nil, nil, entry.name, entry.slotLabel)
		entry.isEquip = (entry.category ~= "other")
		entry.needsInfo = false
		return
	end
	local itemName, link, rarity, iLvl, _, itemType, itemSubType, _, equipLoc, icon = GetItemInfo(query)
	if itemName then
		entry.name = itemName
		if link then entry.link = link end
		entry.rarity = rarity or entry.rarity or 1
		entry.ilvl = iLvl or entry.ilvl or 0
		entry.icon = icon or entry.icon or NS.QUESTION_ICON
		entry.equipLoc = equipLoc or ""
		entry.category = ClassifyItemCategory(itemType, itemSubType, equipLoc, itemName, entry.slotLabel)
		entry.isEquip = (entry.category ~= "other")
		local slotLabel
		if type(equipLoc) == "string" and equipLoc ~= "" and type(_G[equipLoc]) == "string" then
			slotLabel = _G[equipLoc]
			if itemSubType and itemSubType ~= "" and itemSubType ~= slotLabel then slotLabel = slotLabel .. " · " .. itemSubType end
		else
			slotLabel = (itemSubType and itemSubType ~= "" and itemSubType) or (itemType and itemType ~= "" and itemType) or entry.slotLabel or "Loot"
		end
		if entry.isEquip and iLvl and iLvl > 0 then slotLabel = slotLabel .. " (iLvl " .. iLvl .. ")" end
		entry.slotLabel, entry.needsInfo = slotLabel, false
	else
		entry.category = ClassifyItemCategory(nil, nil, nil, entry.name, entry.slotLabel)
		entry.isEquip = (entry.category ~= "other")
		entry.needsInfo = true
	end
end

local function RecordAzsItem(f, sourceTag, bagId, onGround)
	if type(f) ~= "table" then return end
	local name = tostring(f.name or "")
	if name == "" then return end
	local now = GetTime()
	local rarity = tonumber(f.rarity) or 0
	local ilvl = tonumber(f.ilvl) or 0
	local stars = tonumber(f.stars) or 0
	local setName = (f.set and f.set ~= "" and tostring(f.set)) or nil
	local isUpgrade = (tonumber(f.up) == 1 or f.up == "1")
	local unusable = (tonumber(f.use) == 0 or f.use == "0")
	local stats = tostring(f.stats or "")
	local slotName = (type(_G.AZS_SlotName) == "function" and f.slot ~= nil and _G.AZS_SlotName(f.slot)) or (f.kind and tostring(f.kind)) or ""
	local what = (type(_G.AZS_ItemWhat) == "function" and _G.AZS_ItemWhat(rarity, setName)) or ""
	local subParts = {}
	if slotName ~= "" then subParts[#subParts + 1] = slotName elseif what ~= "" then subParts[#subParts + 1] = what end
	if ilvl > 0 then subParts[#subParts + 1] = "iLvl " .. ilvl end
	if setName then subParts[#subParts + 1] = setName end
	local slotLabel = (#subParts > 0) and tconcat(subParts, " · ") or "0.8.0 Gear"
	local dedupKey = bagId and ("bag:" .. tostring(bagId)) or ("azs:" .. name .. ":" .. ilvl .. ":" .. stats)

	for idx = 1, #DropHistory do
		local ex = DropHistory[idx]
		if (bagId and ex.bagId == bagId) or (ex.isAzsItem and ex.name == name and ex.ilvl == ilvl and ex.stats == stats and (now - (ex.updatedAt or 0)) < 180) then
			ex.onGround = onGround and true or false
			if not onGround then ex.bagId = nil end
			ex.updatedAt = now
			if isUpgrade then ex.isUpgrade = true end
			if idx > 1 and not onGround then tremove(DropHistory, idx); tinsert(DropHistory, 1, ex) end
			return
		end
	end

	local prev = RecentDedup[dedupKey]
	if prev and (now - prev.t) < 2.0 and prev.src == sourceTag then return end
	RecentDedup[dedupKey] = { t = now, src = sourceTag }

	totalItemsLooted = totalItemsLooted + 1
	local entry = {
		isAzsItem = true,
		bagId = bagId,
		onGround = onGround and true or false,
		name = name,
		rarity = rarity,
		ilvl = ilvl,
		stars = stars,
		setName = setName,
		isUpgrade = isUpgrade,
		unusable = unusable,
		stats = stats,
		slotName = slotName,
		slotLabel = slotLabel,
		what = what,
		icon = NS.ResolveIcon(f.icon, 0),
		category = ClassifyItemCategory(nil, nil, nil, name, slotName),
		isEquip = true,
		source = sourceTag,
		qty = 1,
		updatedAt = now,
		needsInfo = false,
	}
	tinsert(DropHistory, 1, entry)
	while #DropHistory > MAX_HISTORY do tremove(DropHistory) end
end

local function RecordItemDrop(itemLinkOrId, qty, sourceTag, fallbackName, fallbackRarity, fallbackIcon, fallbackSlot)
	if not itemLinkOrId and not fallbackName then return end
	qty = max(1, tonumber(qty) or 1)
	local itemId = ExtractItemId(itemLinkOrId)
	local normLink = (type(itemLinkOrId) == "string" and find(itemLinkOrId, "item:", 1, true)) and itemLinkOrId or ("item:" .. tostring(itemId or 0))
	local dedupKey = (itemId and itemId > 0) and tostring(itemId) or (fallbackName or normLink)
	local now = GetTime()
	local prev = RecentDedup[dedupKey]
	if prev and sourceTag and prev.src ~= sourceTag and (now - prev.t) < ((prev.src == "lootwin") and 6.0 or 2.0) then return end
	if prev then prev.t, prev.src = now, sourceTag or "any" else RecentDedup[dedupKey] = { t = now, src = sourceTag or "any" } end

	local guessedName = fallbackName or (type(normLink) == "string" and match(normLink, "%[(.-)%]")) or ("Item #" .. tostring(itemId or "?"))
	totalItemsLooted = totalItemsLooted + qty
	for idx = 1, #DropHistory do
		local ex = DropHistory[idx]
		if (not ex.isAzsItem) and ((itemId and itemId > 0 and ex.itemId == itemId) or (ex.name == guessedName and ex.link == normLink)) then
			ex.qty, ex.updatedAt = ex.qty + qty, now
			if ex.needsInfo then PopulateEntryMetadata(ex) end
			if idx > 1 then tremove(DropHistory, idx); tinsert(DropHistory, 1, ex) end
			return
		end
	end
	local entry = {
		itemId = itemId, name = guessedName, link = normLink,
		rarity = tonumber(fallbackRarity) or RarityFromLink(normLink) or 1,
		icon = NS.ResolveIcon(fallbackIcon, 0),
		slotLabel = fallbackSlot or "Loot", equipLoc = "",
		category = ClassifyItemCategory(nil, nil, nil, guessedName, fallbackSlot),
		isEquip = false, source = sourceTag or "any", qty = qty, updatedAt = now,
		needsInfo = (itemId ~= nil and itemId > 0),
	}
	PopulateEntryMetadata(entry)
	tinsert(DropHistory, 1, entry)
	while #DropHistory > MAX_HISTORY do tremove(DropHistory) end
end

local function CountAllOwned(dstCounts)
	Wipe(dstCounts); Wipe(CurLinks)
	local uniqueKeys = 0
	if type(_G.GetContainerNumSlots) == "function" then
		for bag = 0, 4 do
			local slots = _G.GetContainerNumSlots(bag) or 0
			for slot = 1, slots do
				local link = _G.GetContainerItemLink(bag, slot)
				if link then
					local _, cnt = _G.GetContainerItemInfo(bag, slot)
					local key = ExtractItemId(link) or link
					if not dstCounts[key] then uniqueKeys = uniqueKeys + 1 end
					dstCounts[key] = (dstCounts[key] or 0) + (tonumber(cnt) or 1)
					CurLinks[key] = link
				end
			end
		end
	end
	if type(_G.GetInventoryItemLink) == "function" then
		for slot = 1, 19 do
			local link = _G.GetInventoryItemLink("player", slot)
			if link then
				local key = ExtractItemId(link) or link
				if not dstCounts[key] then uniqueKeys = uniqueKeys + 1 end
				dstCounts[key] = (dstCounts[key] or 0) + 1
				CurLinks[key] = link
			end
		end
	end
	return uniqueKeys
end

local function InitOwnedSnapshot()
	ownedKeyCount = CountAllOwned(OwnedSnapA)
	OwnedSnapshot = OwnedSnapA
end

local function DiffOwnedAndRecord()
	local nextBuf = (OwnedSnapshot == OwnedSnapA) and OwnedSnapB or OwnedSnapA
	local curUnique = CountAllOwned(nextBuf)
	local now = GetTime()
	if not OwnedSnapshot or now < bagWarmupUntil or (ownedKeyCount == 0 and curUnique >= 3) then
		OwnedSnapshot, ownedKeyCount = nextBuf, curUnique
		return
	end
	for key, newQty in pairs(nextBuf) do
		local oldQty = OwnedSnapshot[key] or 0
		if newQty > oldQty then RecordItemDrop(CurLinks[key], newQty - oldQty, "bag") end
	end
	OwnedSnapshot, ownedKeyCount = nextBuf, curUnique
end

local function SyncGroundLootBags()
	local bags = _G.AZS_BAGS
	local groundCount = 0
	Wipe(SeenBagIds)
	if type(bags) == "table" then
		for i = 1, #bags do
			local b = bags[i]
			if b and b.id and b.name then
				groundCount = groundCount + 1
				SeenBagIds[b.id] = true
				RecordAzsItem(b, "ground", b.id, true)
			end
		end
	end
	for i = 1, #DropHistory do
		local e = DropHistory[i]
		if e.onGround and e.bagId and not SeenBagIds[e.bagId] then
			e.onGround = false
			e.bagId = nil
		end
	end
	return groundCount
end

local function TrackChestPickups()
	local chests = _G.AZS_CHESTS
	if type(chests) ~= "table" then return end
	local curN, knownN = 0, #KnownCX
	for i = 1, #chests do
		local c = chests[i]
		if c and c.x and c.y then curN = curN + 1; CurCX[curN], CurCY[curN] = c.x, c.y end
	end
	if knownN > 0 and curN < knownN then
		for i = 1, knownN do
			local kx, ky, found = KnownCX[i], KnownCY[i], false
			for j = 1, curN do
				local dx, dy = CurCX[j] - kx, CurCY[j] - ky
				if (dx * dx + dy * dy) < 9 then found = true; break end
			end
			if not found then chestsLooted = chestsLooted + 1 end
		end
	end
	for i = 1, curN do KnownCX[i], KnownCY[i] = CurCX[i], CurCY[i] end
	for i = curN + 1, knownN do KnownCX[i], KnownCY[i] = nil, nil end
end

local function ExtractLinksFromChat(msg, sourceTag)
	if type(msg) ~= "string" or not find(msg, "|Hitem:", 1, true) then return end
	for itemLink, tail in gmatch(msg, "(|c%x+|Hitem:[^|]+|h%[.-%]|h|r)(%s*[xX]?%d*)") do
		RecordItemDrop(itemLink, tonumber(match(tail or "", "%d+")) or 1, sourceTag)
	end
end

local function IsOtherPartyMemberLoot(msg)
	local low = lower(msg)
	if find(low, "^you receive", 1) or find(low, "^você recebe", 1) or find(low, "^voce recebe", 1)
	or find(low, "^you won", 1) or find(low, "^você venceu", 1) or find(low, "^you create", 1) or find(low, "^você cria", 1) then return false end
	return find(low, "receives loot", 1, true) ~= nil or find(low, "recebe saque", 1, true) ~= nil
		or find(low, "recebe o item", 1, true) ~= nil or find(low, "receives item", 1, true) ~= nil
		or find(low, "won:", 1, true) ~= nil
end

local function ResetLootHistory(warmupSecs)
	Wipe(DropHistory); Wipe(RecentDedup); Wipe(SeenBagIds)
	totalItemsLooted, chestsLooted, sessionGoldFromChat = 0, 0, 0
	if GetMoney then sessionStartMoney = GetMoney() end
	bagWarmupUntil = GetTime() + (warmupSecs or 2.0)
	InitOwnedSnapshot()
end

NS.CreateResetButton(LootPanel, "Reset Drops, Chests & Gold History", function() ResetLootHistory(0.5) end)
LootPanel.countTxt = NS.CreateFontText(LootPanel, -2, "RIGHT")
LootPanel.countTxt:SetPoint("RIGHT", LootPanel, "TOPRIGHT", -32, -18)

local function MakeStatPill(leftOff, rightOff, dotCol)
	local p = CreateFrame("Frame", nil, LootPanel)
	p:SetHeight(20)
	p:SetPoint("TOPLEFT",  LootPanel, "TOPLEFT",  leftOff,  -30)
	p:SetPoint("TOPRIGHT", LootPanel, "TOPRIGHT", rightOff, -30)
	p.dot = p:CreateTexture(nil, "ARTWORK")
	p.dot:SetSize(7, 7); p.dot:SetPoint("LEFT", p, "LEFT", 2, 0)
	p.dot:SetTexture(NS.OwnMedia("pin_diamond"))
	p.dot:SetVertexColor(dotCol[1], dotCol[2], dotCol[3], 1)
	p.txt = NS.CreateFontText(p, -2, "LEFT")
	p.txt:SetPoint("LEFT", p.dot, "RIGHT", 4, 0); p.txt:SetPoint("RIGHT", p, "RIGHT", -2, 0)
	SetNoWrap(p.txt, 14)
	return p
end

local ChestPill  = MakeStatPill(12, -162, NS.COLORS.accent)
local GroundPill = MakeStatPill(90, -88,  NS.COLORS.rarePurple)
local GoldPill   = MakeStatPill(164, -12, NS.COLORS.title)

local EmptyHint = NS.CreateFontText(LootPanel, -2, "CENTER")
EmptyHint:SetPoint("CENTER", LootPanel, "CENTER", 0, -24)
EmptyHint:SetText("|cff6e7c91Waiting for 0.8.0 drops...|r")

local DropRows = {}
local function OnDropRowEnter(self)
	local e = self._entry
	if not (GameTooltip and e) then return end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	if e.isAzsItem then
		local r, g, b = GetItemColor(e.rarity, e.setName, true)
		local starStr = (e.stars and e.stars > 0) and ("  |cffffd100" .. rep("★", min(3, e.stars)) .. "|r") or ""
		GameTooltip:SetText((e.name or "Item") .. starStr, r, g, b)
		GameTooltip:AddLine(e.slotLabel or "", 0.68, 0.74, 0.84)
		if e.isUpgrade then
			GameTooltip:AddLine("▲ Upgrade over equipped", 0.28, 1.0, 0.35)
		elseif e.unusable then
			GameTooltip:AddLine("✕ Not for your class", 1.0, 0.35, 0.32)
		end
		if e.stats and e.stats ~= "" then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(FormatAzsAffixes(e.stats, "\n"), 0.35, 1.0, 0.35, true)
		end
		if e.onGround and e.bagId then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("On ground — Click or press [F] nearby to Pick Up", 1.0, 0.84, 0.28)
		end
		GameTooltip:Show()
	elseif e.link and not find(e.link, "item:0", 1, true) then
		local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, e.link)
		if ok then GameTooltip:Show() end
	else
		GameTooltip:SetText(e.name or "Loot", self._pr or 1, self._pg or 0.92, self._pb or 0.55)
		if e.slotLabel then GameTooltip:AddLine(e.slotLabel, 0.70, 0.76, 0.84) end
		GameTooltip:Show()
	end
end
local function OnDropRowLeave()
	if GameTooltip then GameTooltip:Hide() end
end
local function OnDropRowClick(self)
	local e = self._entry
	if not e then return end
	if e.onGround and e.bagId then
		SendAddonMessage("AZSCMD", "pickup " .. tostring(e.bagId), "PARTY")
		return
	end
	if IsShiftKeyDown() and e.link and not find(e.link, "item:0", 1, true) and type(_G.ChatEdit_InsertLink) == "function" then
		_G.ChatEdit_InsertLink(e.link)
	end
end

for i = 1, MAX_DROP_ROWS do
	local row = CreateFrame("Button", nil, LootPanel)
	row:SetHeight(28)
	row:SetPoint("TOPLEFT",  LootPanel, "TOPLEFT",   12, -55 - (i - 1) * 29)
	row:SetPoint("TOPRIGHT", LootPanel, "TOPRIGHT", -12, -55 - (i - 1) * 29)
	row.iconBox = CreateFrame("Frame", nil, row)
	row.iconBox:SetSize(22, 22); row.iconBox:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon = row.iconBox:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints(row.iconBox); row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.badgeTxt = NS.CreateFontText(row, -2, "RIGHT")
	row.badgeTxt:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -1)
	row.nameTxt = NS.CreateFontText(row, 0, "LEFT")
	row.nameTxt:SetPoint("TOPLEFT", row.iconBox, "TOPRIGHT", 6, -1); row.nameTxt:SetPoint("RIGHT", row.badgeTxt, "LEFT", -3, 0)
	SetNoWrap(row.nameTxt, 14)
	row.subTxt = NS.CreateFontText(row, -2, "LEFT")
	row.subTxt:SetPoint("BOTTOMLEFT", row.iconBox, "BOTTOMRIGHT", 6, 0); row.subTxt:SetPoint("RIGHT", row, "RIGHT", -5, 0)
	SetNoWrap(row.subTxt, 14)
	row:SetScript("OnEnter", OnDropRowEnter)
	row:SetScript("OnLeave", OnDropRowLeave)
	row:SetScript("OnClick", OnDropRowClick)
	row:Hide()
	DropRows[i] = row
end

local azsLootHooked = false
local function EnsureAzsLootHook()
	if azsLootHooked then return end
	if type(_G.AZS) == "table" and type(_G.AZS.On) == "function" then
		azsLootHooked = true
		_G.AZS.On("AZSLOOT", function(msg)
			if type(_G.AZS_Fields) == "function" then
				RecordAzsItem(_G.AZS_Fields(msg or ""), "azsloot", nil, false)
			end
		end)
	end
end

local LootDriver = CreateFrame("Frame", "AZS_MinUI_LootDriver")
LootDriver._azsMinUI = true
LootDriver:RegisterEvent("CHAT_MSG_LOOT")
LootDriver:RegisterEvent("CHAT_MSG_MONEY")
LootDriver:RegisterEvent("CHAT_MSG_SYSTEM")
LootDriver:RegisterEvent("CHAT_MSG_ADDON")
LootDriver:RegisterEvent("BAG_UPDATE")
LootDriver:RegisterEvent("UNIT_INVENTORY_CHANGED")
LootDriver:RegisterEvent("LOOT_OPENED")
LootDriver:RegisterEvent("START_LOOT_ROLL")
LootDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
LootDriver:SetScript("OnEvent", function(_, event, arg1, arg2)
	if event == "PLAYER_ENTERING_WORLD" then
		EnsureAzsLootHook()
		if not sessionStartMoney and GetMoney then sessionStartMoney = GetMoney() end
		bagWarmupUntil = GetTime() + 3.5
		InitOwnedSnapshot()
	elseif event == "BAG_UPDATE" then
		DiffOwnedAndRecord()
	elseif event == "UNIT_INVENTORY_CHANGED" then
		if arg1 == "player" then DiffOwnedAndRecord() end
	elseif event == "CHAT_MSG_ADDON" then
		if arg1 == "AZSLOOT" and not azsLootHooked and type(arg2) == "string" and arg2 ~= "" then
			local f = {}
			for k, v in gmatch(arg2, "(%w+)=([^;]*)") do f[k] = tonumber(v) or v end
			RecordAzsItem(f, "azsloot", nil, false)
		end
	elseif event == "START_LOOT_ROLL" then
		if arg1 and type(_G.GetLootRollItemLink) == "function" then
			local link = _G.GetLootRollItemLink(arg1)
			local tex, name, count, quality
			if type(_G.GetLootRollItemInfo) == "function" then tex, name, count, quality = _G.GetLootRollItemInfo(arg1) end
			if link or name then RecordItemDrop(link or "item:0", tonumber(count) or 1, "roll", name, quality, tex, "Boss Drop") end
		end
	elseif event == "LOOT_OPENED" then
		if type(_G.GetNumLootItems) == "function" and type(_G.GetLootSlotLink) == "function" then
			for slot = 1, (_G.GetNumLootItems() or 0) do
				local link = _G.GetLootSlotLink(slot)
				if link then local _, _, qty = _G.GetLootSlotInfo(slot); RecordItemDrop(link, tonumber(qty) or 1, "lootwin") end
			end
		end
	elseif type(arg1) == "string" and arg1 ~= "" then
		local low = lower(arg1)
		if event == "CHAT_MSG_LOOT" then
			if IsOtherPartyMemberLoot(arg1) or find(low, "passou", 1, true) or find(low, "passed on", 1, true)
			or find(low, "rolou", 1, true) or find(low, "rolled ", 1, true) then return end
			ExtractLinksFromChat(arg1, "chat")
			if find(low, "baú", 1, true) or find(low, "chest", 1, true) or find(low, "tesouro", 1, true) then
				chestsLooted = chestsLooted + 1
			end
		elseif event == "CHAT_MSG_MONEY" then
			local g = tonumber(match(arg1, "(%d+)%s*[Oo]uro")) or tonumber(match(arg1, "(%d+)%s*[Gg]old")) or 0
			if g > 0 then sessionGoldFromChat = sessionGoldFromChat + g end
		else
			if not (find(low, "vend", 1, true) or find(low, "sold", 1, true) or find(low, "destru", 1, true)
			or find(low, "destroy", 1, true) or find(low, "remov", 1, true)) then
				ExtractLinksFromChat(arg1, "sys")
			end
		end
	end
end)

local PREVIEW_DROPS = {
	{ isAzsItem = true, name = "Frostforged Breastplate", rarity = 4, ilvl = 245, stars = 3, isUpgrade = true,  onGround = true, icon = "Interface\\Icons\\INV_Chest_Plate04",  slotLabel = "Chest · iLvl 245", stats = "+18% Damage^!+6% Crit Chance^#Spells echo on crit.", qty = 1 },
	{ isAzsItem = true, name = "Valor Pauldrons",         rarity = 3, ilvl = 232, stars = 2, setName = "Valor", isUpgrade = true, icon = "Interface\\Icons\\INV_Shoulder_119",   slotLabel = "Shoulder · iLvl 232 · Valor", stats = "+12% Max Health^!+4% Damage Reduction", qty = 1 },
	{ isAzsItem = true, name = "Runic Rift Helm",         rarity = 2, ilvl = 219, stars = 1, icon = "Interface\\Icons\\INV_Helmet_148",     slotLabel = "Head · iLvl 219", stats = "+8% Cooldown Reduction", qty = 1 },
	{ isAzsItem = true, name = "Ashen Stride Boots",      rarity = 1, ilvl = 205, stars = 0, unusable = true,   icon = "Interface\\Icons\\INV_Boots_Chain_13", slotLabel = "Feet · iLvl 205", stats = "+10% Move Speed", qty = 1 },
}

local function ItemMatchesFilter(item, filterMode, minQuality, upgradesOnly)
	if upgradesOnly and not item.isUpgrade then return false end
	local effRar = item.isAzsItem and ((tonumber(item.rarity) or 0) + 1) or (tonumber(item.rarity) or 1)
	if item.setName then effRar = max(effRar, 4) end
	if effRar < minQuality then return false end
	if filterMode == "all" then return true end
	local cat = item.category or "other"
	if filterMode == "armor" then return cat == "armor" or (item.needsInfo and cat ~= "other" and cat ~= "accessory")
	elseif filterMode == "gear" then return cat == "armor" or cat == "weapon" or (item.needsInfo and cat ~= "accessory")
	elseif filterMode == "equip" then return item.isEquip or item.needsInfo end
	return true
end

local function RenderDropRow(row, item)
	local r, g, b = GetItemColor(item.rarity, item.setName, item.isAzsItem)
	row._entry = item
	row._pr, row._pg, row._pb = r, g, b
	if row._icon ~= item.icon then row._icon = item.icon; row.icon:SetTexture(item.icon) end

	local starPrefix = (item.stars and item.stars > 0) and ("|cffffd100" .. rep("★", min(3, item.stars)) .. "|r ") or ""
	SetText(row.nameTxt, starPrefix .. RGBToHex(r, g, b) .. (item.name or "Loot") .. "|r")

	local sub = item.slotLabel or ""
	if item.onGround then sub = "|cffc499ff[GROUND]|r " .. sub end
	SetText(row.subTxt, "|cff8492a6" .. sub .. "|r")

	local badge = ""
	if item.isUpgrade then badge = "|cff33ff55▲UP|r"
	elseif item.unusable then badge = "|cffff5555✕|r"
	elseif item.setName then badge = "|cff44ffaaSET|r"
	elseif item.qty and item.qty > 1 then badge = "|cffffea89x" .. item.qty .. "|r" end
	SetText(row.badgeTxt, badge)
	row:Show()
end

local Filtered = {}
local Mod = { frame = LootPanel, Reset = ResetLootHistory }

function Mod.Update(ctx)
	EnsureAzsLootHook()
	if NS.GetModuleMode("LootPanel") ~= "minimal" or NS.IsBoxHidden("LootPanel") then
		if not ctx.isEditing and LootPanel:IsShown() then LootPanel:Hide() end
		if NS.GetModuleMode("LootPanel") ~= "minimal" or not ctx.isEditing then return end
	end
	local run, inHub, runClock, now = ctx.run, ctx.inHub, ctx.runClock or 0, ctx.now
	if wasInHub == true and not inHub then ResetLootHistory(2.0) end
	wasInHub = inHub
	if runClock > 0 and lastRunClock > 5 and runClock < 3 then ResetLootHistory(1.5) end
	lastRunClock = runClock

	if (now - lastPeriodicBagCheck) >= 3.0 then lastPeriodicBagCheck = now; DiffOwnedAndRecord() end
	TrackChestPickups()
	local groundCount = SyncGroundLootBags()
	for i = 1, #DropHistory do
		if DropHistory[i].needsInfo then PopulateEntryMetadata(DropHistory[i]) end
	end

	local cfg = (NS.DB and NS.DB.loot) or NS.DEFAULTS.loot
	local filterMode = (cfg and cfg.filterMode) or (cfg and cfg.equipOnly and "equip") or "armor"
	local minQuality = (cfg and cfg.minQuality) or 0
	local upgradesOnly = (cfg and cfg.upgradesOnly) and true or false
	local runGold = run and tonumber(run.gold)
	local displayGold
	if runGold and runGold >= 0 and not inHub then
		displayGold = runGold
	else
		local curMoney = GetMoney and GetMoney() or 0
		local deltaGold = (sessionStartMoney and curMoney > sessionStartMoney) and floor((curMoney - sessionStartMoney) / 10000) or 0
		displayGold = max(deltaGold, sessionGoldFromChat)
	end
	local serverChests = (run and (tonumber(run.ca) or tonumber(run.chests) or tonumber(run.co))) or 0
	local displayChests = max(serverChests, chestsLooted)

	if ctx.isEditing and #DropHistory == 0 then
		LootPanel:Show()
		EmptyHint:Hide()
		SetText(ChestPill.txt, "|cffb0bccdCh:|r |cffffea894|r")
		SetText(GroundPill.txt, "|cffb0bccdBag:|r |cffc499ff2|r")
		SetText(GoldPill.txt, "|cffb0bccdG:|r |cffffd7001.2K|r")
		SetText(LootPanel.countTxt, "|cff94a3b84 drops|r")
		for i = 1, MAX_DROP_ROWS do
			local p = PREVIEW_DROPS[i]
			if p then RenderDropRow(DropRows[i], p, false, now) else DropRows[i]:Hide() end
		end
		return
	end

	Wipe(Filtered)
	local matchedTotalQty = 0
	for i = 1, #DropHistory do
		local item = DropHistory[i]
		if ItemMatchesFilter(item, filterMode, minQuality, upgradesOnly) then
			matchedTotalQty = matchedTotalQty + (tonumber(item.qty) or 1)
			if #Filtered < MAX_DROP_ROWS then Filtered[#Filtered + 1] = item end
		end
	end
	if cfg and cfg.hideWhenEmpty and #Filtered == 0 and displayChests == 0 and displayGold == 0 and groundCount == 0 and not ctx.isEditing then
		if LootPanel:IsShown() then LootPanel:Hide() end
		return
	end
	LootPanel:Show()
	SetText(ChestPill.txt, fmt("|cffb0bccdCh:|r |cffffea89%d|r", displayChests))
	SetText(GroundPill.txt, fmt("|cffb0bccdBag:|r %s%d|r", groundCount > 0 and "|cffc499ff" or "|cff8492a6", groundCount))
	SetText(GoldPill.txt, fmt("|cffb0bccdG:|r |cffffd700%s|r", NS.FormatNumber(displayGold)))
	SetText(LootPanel.countTxt, fmt("|cff94a3b8%d %s|r", matchedTotalQty, upgradesOnly and "upgrades" or (filterMode == "armor" and "armor" or "drops")))
	if #Filtered == 0 then
		SetText(EmptyHint, upgradesOnly and "|cff6e7c91Waiting for upgrade drops...|r" or "|cff6e7c91Waiting for 0.8.0 drops...|r")
		EmptyHint:Show()
	else
		EmptyHint:Hide()
	end
	for i = 1, MAX_DROP_ROWS do
		local row, item = DropRows[i], Filtered[i]
		if item then RenderDropRow(row, item, true, now)
		else row._entry = nil; if row:IsShown() then row:Hide() end end
	end
end

function Mod.ApplyTheme(th)
	local C = NS.COLORS
	LootPanel.icon:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1.0)
	LootPanel.header:SetText(((th and th.hex and th.hex.title) or "|cffffea89") .. "LOOT & DROPS|r")
	ChestPill.dot:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
	GroundPill.dot:SetVertexColor(C.rarePurple[1], C.rarePurple[2], C.rarePurple[3], 1)
	GoldPill.dot:SetVertexColor(C.title[1], C.title[2], C.title[3], 1)
end

NS.Modules.LootPanel = Mod
