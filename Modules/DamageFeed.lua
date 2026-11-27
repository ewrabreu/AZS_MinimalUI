local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local min, tonumber, type, pcall = math.min, tonumber, type, pcall
local tremove, tinsert, GetTime = table.remove, table.insert, GetTime
local SetText, GetSpellIcon, FormatNumber = NS.SetText, NS.GetSpellIcon, NS.FormatNumber

local DamageNormalBox = CreateFrame("Frame", "AZS_MinUI_DamageNormal", UIParent)
NS.RegisterMovableBox("DamageNormal", "Normal Damage (Left)", DamageNormalBox)
local DamageCritBox = CreateFrame("Frame", "AZS_MinUI_DamageCrit", UIParent)
NS.RegisterMovableBox("DamageCrit", "Crit Damage (Right)", DamageCritBox)

local MAX_FEED_LINES, FEED_DURATION = 6, 1.45
local function CreateFeedPool(parent, isCrit)
	local pool = {}
	local sz = isCrit and 19 or 15
	for i = 1, MAX_FEED_LINES do
		local f = CreateFrame("Frame", nil, parent)
		f:SetSize(isCrit and 160 or 145, isCrit and 23 or 19)
		f:SetPoint("BOTTOM", parent, "BOTTOM", 0, (i - 1) * (isCrit and 25 or 21))
		f.iconBox = CreateFrame("Frame", nil, f)
		f.iconBox:SetSize(sz, sz)
		f.iconBox:SetPoint(isCrit and "LEFT" or "RIGHT", f, isCrit and "LEFT" or "RIGHT", isCrit and 2 or -2, 0)
		f.icon = f.iconBox:CreateTexture(nil, "ARTWORK")
		f.icon:SetAllPoints()
		f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		f.txt = NS.CreateFontText(f, isCrit and 2 or 0, isCrit and "LEFT" or "RIGHT")
		f.txt:SetPoint(isCrit and "LEFT" or "RIGHT", f.iconBox, isCrit and "RIGHT" or "LEFT", isCrit and 6 or -6, 0)
		f:Hide()
		pool[i] = f
	end
	return pool
end

local NormalFeedSlots = CreateFeedPool(DamageNormalBox, false)
local CritFeedSlots   = CreateFeedPool(DamageCritBox, true)
local ActiveNormalEvents, ActiveCritEvents, EventPool = {}, {}, {}
local combatCursor, anyVisible = nil, false

local function FormatEventText(item)
	local numStr = FormatNumber(item.amount)
	if item.critical then
		local mult = (item.hits > 1) and (" |cffffcc66x" .. item.hits .. "|r") or ""
		item.text = (item.kind == "heal" and ("|cff44ff66+!" .. numStr .. "!|r") or ("|cffffb800!" .. numStr .. "!|r")) .. mult
	else
		local mult = (item.hits > 1) and (" |cffaaaaaax" .. item.hits .. "|r") or ""
		item.text = (item.kind == "heal" and ("|cff44ff66+" .. numStr .. "|r") or ("|cffe8f0ff" .. numStr .. "|r")) .. mult
	end
end

local function PruneExpiredEvents(list, now)
	for idx = #list, 1, -1 do
		if (now - list[idx].updatedAt) >= FEED_DURATION then
			EventPool[#EventPool + 1] = tremove(list, idx)
		end
	end
end

local function PushCombatEvent(list, ev, amt, now)
	for idx = 1, #list do
		local item = list[idx]
		if item.spellId == ev.spellId and item.kind == ev.kind and (now - item.updatedAt) < 0.28 then
			item.amount = item.amount + amt
			item.hits = item.hits + 1
			item.updatedAt = now
			FormatEventText(item)
			return
		end
	end
	local item = tremove(EventPool) or {}
	item.spellId, item.amount, item.kind, item.critical = ev.spellId, amt, ev.kind, ev.critical
	item.hits, item.updatedAt = 1, now
	item.icon = GetSpellIcon(ev.spellId)
	FormatEventText(item)
	tinsert(list, 1, item)
	while #list > MAX_FEED_LINES do EventPool[#EventPool + 1] = tremove(list) end
end

local function RenderFeed(slots, events, hide, now)
	local shown = false
	for i = 1, MAX_FEED_LINES do
		local slot = slots[i]
		local data = (not hide) and events[i] or nil
		if data then
			if slot._icon ~= data.icon then slot._icon = data.icon; slot.icon:SetTexture(data.icon) end
			SetText(slot.txt, data.text)
			slot:SetAlpha(min(1.0, (FEED_DURATION - (now - data.updatedAt)) / 0.45))
			slot:Show()
			shown = true
		elseif slot:IsShown() then
			slot:Hide()
		end
	end
	return shown
end

local Mod = { normalFrame = DamageNormalBox, critFrame = DamageCritBox }

function Mod.UpdateFast()
	local DB = NS.DB
	local hideNorm, hideCrit = NS.IsBoxHidden("DamageNormal"), NS.IsBoxHidden("DamageCrit")
	if not (DB and DB.showSideDamage) or (hideNorm and hideCrit) then
		if anyVisible then
			for i = 1, MAX_FEED_LINES do NormalFeedSlots[i]:Hide(); CritFeedSlots[i]:Hide() end
			anyVisible = false
		end
		return
	end
	local now = GetTime()
	if type(_G.AZS_GetCombatTextEvents) == "function" then
		local ok, res = pcall(_G.AZS_GetCombatTextEvents, combatCursor, 128)
		if ok and type(res) == "table" then
			combatCursor = res.cursor
			local evs = res.events
			if type(evs) == "table" then
				for i = 1, #evs do
					local ev = evs[i]
					local amt = ev and tonumber(ev.amount) or 0
					if amt > 0 then
						PushCombatEvent(ev.critical and ActiveCritEvents or ActiveNormalEvents, ev, amt, now)
					end
				end
			end
		end
	end
	PruneExpiredEvents(ActiveNormalEvents, now)
	PruneExpiredEvents(ActiveCritEvents, now)
	local s1 = RenderFeed(NormalFeedSlots, ActiveNormalEvents, hideNorm, now)
	local s2 = RenderFeed(CritFeedSlots, ActiveCritEvents, hideCrit, now)
	anyVisible = s1 or s2
end

NS.Modules.DamageFeed = Mod
