local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, max, min, tonumber, tostring, type, pairs, pcall = math.floor, math.max, math.min, tonumber, tostring, type, pairs, pcall
local lower, find, sub, match, gmatch, fmt = string.lower, string.find, string.sub, string.match, string.gmatch, string.format
local tinsert, tremove, GetTime = table.insert, table.remove, GetTime
local Wipe, SetText, RGBToHex, ApplyFlat, SetNoWrap = NS.Wipe, NS.SetText, NS.RGBToHex, NS.ApplyFlatBackdrop, NS.SetNoWrap

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

local DropHistory, RecentDedup, SeenServerDrops, BaselinedServerTables = {}, {}, {}, {}
local SeenLootAddonSync, DynamicLootGlobals = {}, {}
local MAX_HISTORY, MAX_DROP_ROWS = 40, 5
local totalItemsLooted, chestsLooted, sessionGoldFromChat, lastRunClock = 0, 0, 0, 0
local sessionStartMoney, wasInHub = nil, nil
local OwnedSnapA, OwnedSnapB, CurLinks = {}, {}, {}
local OwnedSnapshot, ownedKeyCount = nil, 0
local bagWarmupUntil, lastPeriodicBagCheck, globalsScanned, lateScanAt = 0, 0, false, 0
local KnownCX, KnownCY, CurCX, CurCY = {}, {}, {}, {}

local COLOR_HEX_TO_RARITY = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6 }
local FALLBACK_RARITY = {
	[0] = { 0.62, 0.62, 0.62 }, [1] = { 1.00, 1.00, 1.00 }, [2] = { 0.12, 1.00, 0.00 },
	[3] = { 0.00, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1.00, 0.50, 0.00 },
}
local SplitCSV, SplitSet = NS.SplitCSV, NS.SplitSet
local ARMOR_LOCS     = SplitSet("HEAD,SHOULDER,CHEST,ROBE,WRIST,HAND,WAIST,LEGS,FEET,CLOAK,SHIELD,BODY,TABARD", "INVTYPE_")
local WEAPON_LOCS    = SplitSet("WEAPON,2HWEAPON,WEAPONMAINHAND,WEAPONOFFHAND,HOLDABLE,RANGED,RANGEDRIGHT,THROWN,RELIC", "INVTYPE_")
local ACCESSORY_LOCS = SplitSet("FINGER,TRINKET,NECK", "INVTYPE_")
local ACCESSORY_KW   = SplitCSV("ring,anel,signet,band,loop,seal,aliança,alianca,trinket,berloque,talisman,talismã,talisma,idol,ícone,totem,insignia,insígnia,neck,pescoço,pescoco,amulet,amuleto,pendant,pingente,necklace,colar,choker,locket,medallion,medalhão,medalhao")
local ARMOR_SUB_KW   = SplitCSV("plate,placa,mail,malha,leather,couro,cloth,tecido,shield,escudo")
local ARMOR_KW       = SplitCSV("helm,elmo,hood,capuz,crown,coroa,cowl,mask,máscara,mascara,head,cabeça,cabeca,shoulder,ombro,pauldrons,omobreira,spaulders,mantle,manto,chest,peitoral,tunic,túnica,tunica,breastplate,couraça,couraca,robe,veste,hauberk,jerkin,torso,wrist,pulso,bracer,braçadeira,bracadeira,bindings,cuffs,vambraces,hand,mão,mao,glove,luva,gauntlet,manopla,grips,mitts,waist,cintura,belt,cinto,girdle,cord,cordão,cordao,sash,faixa,legs,pernas,leggings,calça,calca,legplates,greaves,grevas,pant,kilt,breeches,feet,pés,pes,boot,bota,sabatons,treads,slippers,sandals,stomp,cloak,capa,cape,shroud,drape,back,costas,shield,escudo,bulwark,aegis,buckler,plate,placas,mail,malha,leather,couro,cloth,tecido,armor,armadura")
local LOOT_PREFIX_KW = SplitCSV("loot,drop,item,gear,armor,armour,set,boss,stash,vault,cache,chest,reward,pickup,relic,equip,bag,unlock,claim,roll,trophy,piece,box,mail")
local GLOBAL_LOOT_KW = SplitCSV("loot,drop,item,gear,armor,stash,vault,set,reward,pickup,unlock")
local GLOBAL_SKIP_KW = SplitCSV("minimalui,minui,setting,sethud,seteditor,setontop")
local IGNORED_PREFIX = SplitSet("run,units,power,debuffs,tombs,revive,stats,meter,spells,chests,schedule,zone", "azs")
local RUN_LOOT_FIELDS = SplitCSV("loot,drops,items,gear,armor,stash,rewards")

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

local function GetRarityColor(rarity)
	if type(_G.GetItemQualityColor) == "function" then
		local r, g, b = _G.GetItemQualityColor(rarity or 1)
		if r and g and b then return r, g, b end
	end
	local c = FALLBACK_RARITY[rarity or 1] or FALLBACK_RARITY[1]
	return c[1], c[2], c[3]
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
	if type(itemType) == "string" then
		local lt = lower(itemType)
		if find(lt, "weapon", 1, true) or find(lt, "arma", 1, true) then return "weapon" end
	end
	if HasAnyKW(slotHint, ARMOR_KW) or HasAnyKW(itemName, ARMOR_KW) then return "armor" end
	return "other"
end

local function PopulateEntryMetadata(entry)
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
		if (itemId and itemId > 0 and ex.itemId == itemId) or (ex.name == guessedName and ex.link == normLink) then
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

local function PrefixLooksLikeLoot(lowPrefix)
	return sub(lowPrefix, 1, 3) == "azs" and HasAnyKW(lowPrefix, LOOT_PREFIX_KW)
end

local kvBuf = {}
local function ParseKeyValSegment(seg, sourceTag)
	local foundLink = false
	for itemLink in gmatch(seg, "(|c%x+|Hitem:[^|]+|h%[.-%]|h|r)") do RecordItemDrop(itemLink, 1, sourceTag); foundLink = true end
	if foundLink then return true end
	for bareLink in gmatch(seg, "(|Hitem:[^|]+|h%[.-%]|h)") do RecordItemDrop(bareLink, 1, sourceTag); foundLink = true end
	if foundLink then return true end
	Wipe(kvBuf)
	for k, v in gmatch(seg, "([%a_][%w_]*)%s*=%s*([^;\t|\n]+)") do kvBuf[lower(k)] = v end
	local itemId = tonumber(kvBuf.item or kvBuf.itemid or kvBuf.entry or kvBuf.id)
	local name = kvBuf.name or kvBuf.title or kvBuf.label
	if (itemId and itemId > 0) or (name and name ~= "") then
		RecordItemDrop(itemId or "item:0", tonumber(kvBuf.qty or kvBuf.count or kvBuf.stack or kvBuf.n) or 1, sourceTag,
			name, tonumber(kvBuf.rarity or kvBuf.quality or kvBuf.q), kvBuf.icon or kvBuf.tex or kvBuf.texture, kvBuf.slot or kvBuf.type or kvBuf.kind)
		return true
	end
	local p1, p2, p3, p4, p5 = match(seg, "^(%d+)[|\t]([^|\t]+)[|\t]?(%d*)[|\t]?([^|\t]*)[|\t]?(%d*)")
	if p1 and tonumber(p1) and tonumber(p1) > 10 then
		RecordItemDrop(tonumber(p1), tonumber(p5) or 1, sourceTag, p2, tonumber(p3), p4 ~= "" and p4 or nil)
		return true
	end
	return false
end

local lineBuf = {}
local function HandleAddonMessage(prefix, msg)
	if type(prefix) ~= "string" or type(msg) ~= "string" or msg == "" then return end
	local lowPrefix = lower(prefix)
	if IGNORED_PREFIX[lowPrefix] then
		if find(msg, "|Hitem:", 1, true) then ParseKeyValSegment(msg, "addon") end
		return
	end
	if PrefixLooksLikeLoot(lowPrefix) or find(msg, "|Hitem:", 1, true) then
		if GetTime() < bagWarmupUntil then SeenLootAddonSync[lowPrefix] = true; return end
		Wipe(lineBuf)
		for line in gmatch(msg, "[^\r\n]+") do lineBuf[#lineBuf + 1] = line end
		if #lineBuf >= 3 and not SeenLootAddonSync[lowPrefix] then SeenLootAddonSync[lowPrefix] = true; return end
		SeenLootAddonSync[lowPrefix] = true
		for i = 1, #lineBuf do ParseKeyValSegment(lineBuf[i], "addon") end
	end
end

local function ConsumeServerLootTable(raw, tagPrefix, now)
	if type(raw) ~= "table" then return end
	local isBaseline = (not BaselinedServerTables[tagPrefix]) or (now < bagWarmupUntil)
	for i = 1, #raw do
		local d = raw[i]
		if type(d) == "table" then
			local itemRef, name = d.link or d.itemLink or d.item or d.itemId or d.entry or d.id, d.name or d.title
			if itemRef or name then
				local sKey = tagPrefix .. ":" .. tostring(d.uid or d.guid or d.ts or (tostring(itemRef or name) .. ":" .. i))
				if not SeenServerDrops[sKey] then
					SeenServerDrops[sKey] = true
					if not isBaseline then
						RecordItemDrop(itemRef or "item:0", tonumber(d.qty or d.count or d.stack or 1) or 1, "api",
							name, tonumber(d.rarity or d.quality or d.q), d.icon or d.texture, d.slot)
					end
				end
			end
		elseif type(d) == "string" and find(d, "|Hitem:", 1, true) then
			local sKey = tagPrefix .. ":str:" .. i .. ":" .. d
			if not SeenServerDrops[sKey] then
				SeenServerDrops[sKey] = true
				if not isBaseline then RecordItemDrop(d, 1, "api") end
			end
		end
	end
	if now >= bagWarmupUntil then BaselinedServerTables[tagPrefix] = true end
end

local function RefreshDynamicLootGlobals()
	Wipe(DynamicLootGlobals)
	for k, v in pairs(_G) do
		if type(k) == "string" and sub(k, 1, 4) == "AZS_" and (type(v) == "table" or type(v) == "function") then
			if HasAnyKW(k, GLOBAL_LOOT_KW) and not HasAnyKW(k, GLOBAL_SKIP_KW) then
				DynamicLootGlobals[k] = (type(v) == "function" and find(lower(k), "get", 1, true) ~= nil) and "fn" or (type(v) == "table" and "tbl" or nil)
			end
		end
	end
	globalsScanned = true
end

local function PollServerLootTables(run, now)
	if not globalsScanned or (lateScanAt > 0 and now >= lateScanAt) then
		lateScanAt = 0
		RefreshDynamicLootGlobals()
	end
	for k, kind in pairs(DynamicLootGlobals) do
		local v = _G[k]
		if kind == "tbl" and type(v) == "table" then
			ConsumeServerLootTable(v, k, now)
		elseif kind == "fn" and type(v) == "function" then
			local ok, res = pcall(v)
			if ok and type(res) == "table" then ConsumeServerLootTable(res, k, now) end
		end
	end
	if type(run) == "table" then
		for i = 1, #RUN_LOOT_FIELDS do
			local f = RUN_LOOT_FIELDS[i]
			if type(run[f]) == "table" then ConsumeServerLootTable(run[f], "run." .. f, now) end
		end
	end
end

local function ResetLootHistory(warmupSeconds)
	Wipe(DropHistory); Wipe(KnownCX); Wipe(KnownCY); Wipe(RecentDedup); Wipe(SeenServerDrops); Wipe(BaselinedServerTables)
	totalItemsLooted, chestsLooted, sessionGoldFromChat = 0, 0, 0
	sessionStartMoney = GetMoney and GetMoney() or 0
	if warmupSeconds and warmupSeconds > 0 then bagWarmupUntil = max(bagWarmupUntil, GetTime() + warmupSeconds) end
	InitOwnedSnapshot()
end

local ResetBtn = NS.CreateResetButton(LootPanel, "Reset Loot History", function()
	ResetLootHistory()
	if NS.UpdateMinimalHUD then NS.UpdateMinimalHUD() end
end)
LootPanel.countTxt = NS.CreateFontText(LootPanel, -2, "RIGHT")
LootPanel.countTxt:SetPoint("RIGHT", ResetBtn, "LEFT", -6, 0)

local SummaryBar = CreateFrame("Frame", nil, LootPanel)
SummaryBar:SetHeight(24)
SummaryBar:SetPoint("TOPLEFT",  LootPanel, "TOPLEFT",   10, -30)
SummaryBar:SetPoint("TOPRIGHT", LootPanel, "TOPRIGHT", -10, -30)
local PILL_BG, PILL_BD = { 0.05, 0.06, 0.09, 0.90 }, { 0.22, 0.26, 0.35, 0.85 }
local function MakeSummaryPill(anchor, w, tex, r, g, b)
	local p = CreateFrame("Frame", nil, SummaryBar)
	p:SetSize(w, 22)
	p:SetPoint(anchor, SummaryBar, anchor, 0, 0)
	ApplyFlat(p, PILL_BG, PILL_BD)
	p.dot = p:CreateTexture(nil, "ARTWORK")
	p.dot:SetSize(12, 12)
	p.dot:SetPoint("LEFT", p, "LEFT", 6, 0)
	p.dot:SetTexture(tex)
	p.dot:SetVertexColor(r, g, b, 1.0)
	p.txt = NS.CreateFontText(p, -2, "LEFT")
	p.txt:SetPoint("LEFT", p.dot, "RIGHT", 4, 0)
	p.txt:SetPoint("RIGHT", p, "RIGHT", -5, 0)
	SetNoWrap(p.txt)
	return p
end
local ChestPill = MakeSummaryPill("LEFT",  108, NS.Media("point_crystal"),  1.0, 0.82, 0.22)
local GoldPill  = MakeSummaryPill("RIGHT", 114, NS.OwnMedia("pin_diamond"), 1.0, 0.84, 0.10)

local DropRows = {}
local ROW_BG, ROW_BD = { 0.05, 0.06, 0.09, 0.78 }, { 0.16, 0.19, 0.26, 0.70 }
local function OnDropEnter(self)
	self:SetBackdropBorderColor(0.00, 0.92, 0.78, 0.95)
	if not GameTooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	if self._link and find(self._link, "item:", 1, true) and not find(self._link, "item:0", 1, true) then
		pcall(GameTooltip.SetHyperlink, GameTooltip, self._link)
		GameTooltip:Show()
	elseif self._previewName then
		GameTooltip:SetText(self._previewName, self._pr or 1, self._pg or 0.9, self._pb or 0.5)
		if self._previewSub then GameTooltip:AddLine(self._previewSub, 0.72, 0.76, 0.84) end
		GameTooltip:Show()
	end
end
local function OnDropLeave(self)
	self:SetBackdropBorderColor(0.16, 0.19, 0.26, 0.70)
	if GameTooltip then GameTooltip:Hide() end
end
local function OnDropClick(self)
	if self._link and IsShiftKeyDown() and type(_G.ChatEdit_InsertLink) == "function" then _G.ChatEdit_InsertLink(self._link) end
end

for i = 1, MAX_DROP_ROWS do
	local row = CreateFrame("Button", nil, LootPanel)
	row:SetHeight(24)
	row:SetPoint("TOPLEFT",  LootPanel, "TOPLEFT",   10, -58 - (i - 1) * 26)
	row:SetPoint("TOPRIGHT", LootPanel, "TOPRIGHT", -10, -58 - (i - 1) * 26)
	ApplyFlat(row, ROW_BG, ROW_BD)
	row.iconBox = CreateFrame("Frame", nil, row)
	row.iconBox:SetSize(20, 20)
	row.iconBox:SetPoint("LEFT", row, "LEFT", 3, 0)
	ApplyFlat(row.iconBox, nil, { 0.6, 0.6, 0.6, 0.9 }, true)
	row.icon = row.iconBox:CreateTexture(nil, "ARTWORK")
	row.icon:SetPoint("TOPLEFT", row.iconBox, "TOPLEFT", 1, -1)
	row.icon:SetPoint("BOTTOMRIGHT", row.iconBox, "BOTTOMRIGHT", -1, 1)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.qtyTxt = NS.CreateFontText(row, -2, "RIGHT")
	row.qtyTxt:SetPoint("TOPRIGHT", row, "TOPRIGHT", -5, -2)
	row.nameTxt = NS.CreateFontText(row, -2, "LEFT")
	row.nameTxt:SetPoint("TOPLEFT", row.iconBox, "TOPRIGHT", 6, -1)
	row.nameTxt:SetPoint("RIGHT", row.qtyTxt, "LEFT", -4, 0)
	SetNoWrap(row.nameTxt, 11)
	row.subTxt = NS.CreateFontText(row, -3, "LEFT")
	row.subTxt:SetPoint("BOTTOMLEFT", row.iconBox, "BOTTOMRIGHT", 6, 1)
	row.subTxt:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	SetNoWrap(row.subTxt, 10)
	row:SetScript("OnEnter", OnDropEnter)
	row:SetScript("OnLeave", OnDropLeave)
	row:SetScript("OnClick", OnDropClick)
	row:Hide()
	DropRows[i] = row
end

local EmptyHint = NS.CreateFontText(LootPanel, -2, "CENTER")
EmptyHint:SetPoint("CENTER", LootPanel, "CENTER", 0, -24)
EmptyHint:SetText("|cff6e7c91Waiting for boss armor drops...|r")
EmptyHint:Hide()

local function TrackChestPickups()
	local chests = _G.AZS_CHESTS
	if type(chests) ~= "table" then return end
	local px, py
	if type(_G.AZS_UnitWorldPosition) == "function" then
		local ok, ux, uy = pcall(_G.AZS_UnitWorldPosition, "player")
		if ok and ux and uy then px, py = ux, uy end
	elseif type(_G.AZS_RUN) == "table" and _G.AZS_RUN.px and _G.AZS_RUN.py then
		px, py = tonumber(_G.AZS_RUN.px), tonumber(_G.AZS_RUN.py)
	end
	Wipe(CurCX); Wipe(CurCY)
	for i = 1, #chests do
		local c = chests[i]
		if c and c.x and c.y then
			local key = c.id or (floor(c.x * 2 + 0.5) .. ":" .. floor(c.y * 2 + 0.5))
			CurCX[key], CurCY[key] = c.x, c.y
		end
	end
	if px and py then
		for key, kx in pairs(KnownCX) do
			if not CurCX[key] then
				local dx, dy = kx - px, KnownCY[key] - py
				if (dx * dx + dy * dy) <= 400 then chestsLooted = chestsLooted + 1 end
			end
		end
	end
	KnownCX, CurCX = CurCX, KnownCX
	KnownCY, CurCY = CurCY, KnownCY
end

local function IsOtherPartyMemberLoot(msg)
	local nParty = GetNumPartyMembers and (GetNumPartyMembers() or 0) or 0
	for i = 1, min(4, nParty) do
		local pName = UnitName("party" .. i)
		if pName and pName ~= "" and sub(msg, 1, #pName) == pName then return true end
	end
	return false
end

local function ExtractLinksFromChat(msg, sourceTag)
	local foundAny = false
	for itemLink, tail in gmatch(msg, "(|c%x+|Hitem:[^|]+|h%[.-%]|h|r)(%s*[xX]?%d*)") do
		RecordItemDrop(itemLink, tonumber(match(tail or "", "[xX](%d+)")) or 1, sourceTag)
		foundAny = true
	end
	if not foundAny then
		for bareLink in gmatch(msg, "(|Hitem:[^|]+|h%[.-%]|h)") do RecordItemDrop(bareLink, 1, sourceTag) end
	end
end

local LootDriver = CreateFrame("Frame")
LootDriver._azsMinUI = true
LootDriver:RegisterEvent("CHAT_MSG_LOOT")
LootDriver:RegisterEvent("CHAT_MSG_MONEY")
LootDriver:RegisterEvent("CHAT_MSG_SYSTEM")
LootDriver:RegisterEvent("CHAT_MSG_OPENING")
LootDriver:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
LootDriver:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
LootDriver:RegisterEvent("CHAT_MSG_ADDON")
LootDriver:RegisterEvent("BAG_UPDATE")
LootDriver:RegisterEvent("UNIT_INVENTORY_CHANGED")
LootDriver:RegisterEvent("LOOT_OPENED")
LootDriver:RegisterEvent("START_LOOT_ROLL")
LootDriver:RegisterEvent("PLAYER_ENTERING_WORLD")
LootDriver:SetScript("OnEvent", function(_, event, arg1, arg2)
	if event == "PLAYER_ENTERING_WORLD" then
		if not sessionStartMoney and GetMoney then sessionStartMoney = GetMoney() end
		local now = GetTime()
		bagWarmupUntil, globalsScanned, lateScanAt = now + 3.5, false, now + 5.0
		Wipe(BaselinedServerTables)
		InitOwnedSnapshot()
	elseif event == "BAG_UPDATE" then
		DiffOwnedAndRecord()
	elseif event == "UNIT_INVENTORY_CHANGED" then
		if arg1 == "player" then DiffOwnedAndRecord() end
	elseif event == "CHAT_MSG_ADDON" then
		HandleAddonMessage(arg1, arg2)
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
			if find(low, "baú", 1, true) or find(low, "bau ", 1, true) or find(low, "chest", 1, true) or find(low, "tesouro", 1, true) then
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
			if (find(low, "baú", 1, true) or find(low, "chest", 1, true))
			and (find(low, "abriu", 1, true) or find(low, "pegou", 1, true) or find(low, "opened", 1, true) or find(low, "collected", 1, true)) then
				chestsLooted = chestsLooted + 1
			end
		end
	end
end)

local PREVIEW_DROPS = {
	{ name = "Runic Guardian Breastplate", rarity = 4, icon = "Interface\\Icons\\INV_Chest_Plate21",  slotLabel = "Chest · Plate (iLvl 245)",    qty = 1 },
	{ name = "Shadowrift Pauldrons",       rarity = 4, icon = "Interface\\Icons\\INV_Shoulder_119",   slotLabel = "Shoulder · Plate (iLvl 251)", qty = 1 },
	{ name = "Frostbound Rift Helm",       rarity = 3, icon = "Interface\\Icons\\INV_Helmet_148",     slotLabel = "Head · Mail (iLvl 219)",      qty = 1 },
	{ name = "Spectral Step Greaves",      rarity = 3, icon = "Interface\\Icons\\INV_Boots_Chain_13", slotLabel = "Feet · Mail (iLvl 213)",      qty = 1 },
}

local function ItemMatchesFilter(item, filterMode, minQuality)
	if (item.rarity or 1) < minQuality then return false end
	if filterMode == "all" then return true end
	local cat = item.category or "other"
	if filterMode == "armor" then return cat == "armor" or (item.needsInfo and cat ~= "other" and cat ~= "accessory")
	elseif filterMode == "gear" then return cat == "armor" or cat == "weapon" or (item.needsInfo and cat ~= "accessory")
	elseif filterMode == "equip" then return item.isEquip or item.needsInfo end
	return true
end

local function RenderDropRow(row, item, isLive, now)
	local r, g, b = GetRarityColor(item.rarity)
	row._link = isLive and item.link or nil
	row._previewName, row._previewSub = item.name, item.slotLabel
	row._pr, row._pg, row._pb = r, g, b
	if row._icon ~= item.icon then row._icon = item.icon; row.icon:SetTexture(item.icon) end
	row.iconBox:SetBackdropBorderColor(r, g, b, 0.95)
	SetText(row.nameTxt, RGBToHex(r, g, b) .. item.name .. "|r")
	SetText(row.subTxt, "|cff8492a6" .. item.slotLabel .. "|r")
	SetText(row.qtyTxt, item.qty > 1 and ("|cffffea89x" .. item.qty .. "|r") or "")
	if isLive then
		if (now - (item.updatedAt or 0)) < 2.0 then row:SetBackdropBorderColor(r, g, b, 0.90)
		else row:SetBackdropBorderColor(0.16, 0.19, 0.26, 0.70) end
	end
	row:Show()
end

local Filtered = {}
local Mod = { frame = LootPanel, Reset = ResetLootHistory }

function Mod.Update(ctx)
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
	PollServerLootTables(run, now)
	for i = 1, #DropHistory do
		if DropHistory[i].needsInfo then PopulateEntryMetadata(DropHistory[i]) end
	end

	local cfg = (NS.DB and NS.DB.loot) or NS.DEFAULTS.loot
	local filterMode = (cfg and cfg.filterMode) or (cfg and cfg.equipOnly and "equip") or "armor"
	local minQuality = (cfg and cfg.minQuality) or 0
	local runGold = run and tonumber(run.gold)
	local displayGold
	if runGold and runGold >= 0 and not inHub then
		displayGold = runGold
	else
		local curMoney = GetMoney and GetMoney() or 0
		local deltaGold = (sessionStartMoney and curMoney > sessionStartMoney) and floor((curMoney - sessionStartMoney) / 10000) or 0
		displayGold = max(deltaGold, sessionGoldFromChat)
	end
	local serverChests = (run and (tonumber(run.chests) or tonumber(run.chestsOpened) or tonumber(run.co))) or 0
	local displayChests = max(serverChests, chestsLooted)

	if ctx.isEditing and #DropHistory == 0 then
		LootPanel:Show()
		EmptyHint:Hide()
		SetText(ChestPill.txt, "|cffb0bccdChests:|r |cffffea894|r")
		SetText(GoldPill.txt, "|cffb0bccdGold:|r |cffffd7001.2k|r")
		SetText(LootPanel.countTxt, "|cff94a3b84 armor|r")
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
		if ItemMatchesFilter(item, filterMode, minQuality) then
			matchedTotalQty = matchedTotalQty + (tonumber(item.qty) or 1)
			if #Filtered < MAX_DROP_ROWS then Filtered[#Filtered + 1] = item end
		end
	end
	if cfg and cfg.hideWhenEmpty and #Filtered == 0 and displayChests == 0 and displayGold == 0 and not ctx.isEditing then
		if LootPanel:IsShown() then LootPanel:Hide() end
		return
	end
	LootPanel:Show()
	SetText(ChestPill.txt, fmt("|cffb0bccdChests:|r |cffffea89%d|r", displayChests))
	SetText(GoldPill.txt, fmt("|cffb0bccdGold:|r |cffffd700%s|r", NS.FormatNumber(displayGold)))
	SetText(LootPanel.countTxt, fmt("|cff94a3b8%d %s|r", matchedTotalQty, filterMode == "armor" and "armor" or "drops"))
	if #Filtered == 0 then
		SetText(EmptyHint, filterMode == "armor" and "|cff6e7c91Waiting for boss armor drops...|r" or "|cff6e7c91Waiting for monster drops...|r")
		EmptyHint:Show()
	else
		EmptyHint:Hide()
	end
	for i = 1, MAX_DROP_ROWS do
		local row, item = DropRows[i], Filtered[i]
		if item then RenderDropRow(row, item, true, now)
		else row._link, row._previewName = nil, nil; if row:IsShown() then row:Hide() end end
	end
end

NS.Modules.LootPanel = Mod
