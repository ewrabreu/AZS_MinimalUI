local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local tonumber, tostring, type, pcall, fmt = tonumber, tostring, type, pcall, string.format
local SetText, ResolveIcon, FormatShortTime = NS.SetText, NS.ResolveIcon, NS.FormatShortTime

local MAX_SLOTS, SLOT_SZ, SLOT_GAP = 6, 30, 6
local Strip = CreateFrame("Frame", "AZS_MinUI_SummonTracker", UIParent)
NS.RegisterMovableBox("SummonTracker", "Pets & Totems", Strip)
Strip:EnableMouse(false)

local function OnSlotEnter(self)
	if not (GameTooltip and self._tipTitle) then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(self._tipTitle, self._tr or 0.78, self._tg or 0.55, self._tb or 1.0)
	if self._tipSub and self._tipSub ~= "" then GameTooltip:AddLine(self._tipSub, 0.82, 0.88, 0.94) end
	GameTooltip:Show()
end
local function OnSlotLeave() if GameTooltip then GameTooltip:Hide() end end

local Slots = {}
for i = 1, MAX_SLOTS do
	local f = CreateFrame("Frame", nil, Strip)
	f:SetSize(SLOT_SZ, SLOT_SZ)
	f:EnableMouse(true)
	f:SetScript("OnEnter", OnSlotEnter)
	f:SetScript("OnLeave", OnSlotLeave)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetAllPoints(f)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.txtLayer = CreateFrame("Frame", nil, f)
	f.txtLayer:SetAllPoints(f)
	f.txtLayer:SetFrameLevel(f:GetFrameLevel() + 4)
	f.timerTxt = NS.CreateFontText(f.txtLayer, -2, "CENTER")
	f.timerTxt:SetPoint("CENTER", f.txtLayer, "CENTER", 0, 0)
	f.cntTxt = NS.CreateFontText(f.txtLayer, -2, "RIGHT")
	f.cntTxt:SetPoint("BOTTOMRIGHT", f.txtLayer, "BOTTOMRIGHT", -2, 1)
	f:Hide()
	Slots[i] = f
end

local lastLayoutCount = -1
local function LayoutSlots(count)
	if count == lastLayoutCount then return end
	lastLayoutCount = count
	if count <= 0 then return end
	local totalW = count * SLOT_SZ + (count - 1) * SLOT_GAP
	local startX = -totalW * 0.5 + SLOT_SZ * 0.5
	for i = 1, count do
		local f = Slots[i]
		f:ClearAllPoints()
		f:SetPoint("CENTER", Strip, "CENTER", startX + (i - 1) * (SLOT_SZ + SLOT_GAP), 0)
	end
end

local function SetSlot(idx, icon, countTxt, rem, br, bg, bb, title, sub)
	local f = Slots[idx]
	if f._icon ~= icon then f._icon = icon; f.icon:SetTexture(icon) end
	SetText(f.cntTxt, countTxt or "")
	SetText(f.timerTxt, (rem and rem > 0) and ("|cff55ffbb" .. FormatShortTime(rem, true) .. "|r") or "")
	f._tipTitle, f._tipSub, f._tr, f._tg, f._tb = title, sub, br, bg, bb
	f:Show()
end

local Mod = { frame = Strip }
function Mod.Update(ctx)
	if NS.GetModuleMode("SummonTracker") ~= "minimal" or NS.IsBoxHidden("SummonTracker") then
		if not ctx.isEditing and Strip:IsShown() then Strip:Hide() end
		if NS.GetModuleMode("SummonTracker") ~= "minimal" or not ctx.isEditing then return end
	end

	local n = 0
	if not ctx.inHub and type(_G.AZS_GetSummonGroups) == "function" then
		local ok, groups = pcall(_G.AZS_GetSummonGroups)
		if ok and type(groups) == "table" then
			for i = 1, #groups do
				if n >= MAX_SLOTS then break end
				local g = groups[i]
				if g and (tonumber(g.count) or 0) > 0 then
					n = n + 1
					local cnt = tonumber(g.count) or 1
					local rem = tonumber(g.remaining) or 0
					local sub = (g.permanent and g.permanent > 0 and rem <= 0)
						and fmt("Active Summons: %d (Permanent)", cnt)
						or fmt("Active Summons: %d%s", cnt, rem > 0 and fmt(" · Next expires: %.0fs", rem) or "")
					SetSlot(n, ResolveIcon(g.icon), "|cffffea89x" .. tostring(cnt) .. "|r", rem,
						0.76, 0.45, 1.0, g.name or g.key or "Summon", sub)
				end
			end
		end
	end

	if not ctx.inHub and type(_G.AZS_GetTotems) == "function" then
		local ok, totems = pcall(_G.AZS_GetTotems)
		if ok and type(totems) == "table" then
			for i = 1, #totems do
				if n >= MAX_SLOTS then break end
				local t = totems[i]
				if t and (tonumber(t.count) or 0) > 0 then
					n = n + 1
					local cnt, cap = tonumber(t.count) or 1, tonumber(t.cap) or 1
					local rem = tonumber(t.remaining) or 0
					local cTxt = cap > 1 and fmt("|cff66ddff%d/%d|r", cnt, cap) or fmt("|cff66ddff%d|r", cnt)
					SetSlot(n, ResolveIcon(t.icon, t.spell), cTxt, rem,
						0.18, 0.78, 1.0, t.name or t.key or "Totem",
						fmt("Active Totems: %d/%d%s", cnt, cap, rem > 0 and fmt(" · %.0fs left", rem) or ""))
				end
			end
		end
	end

	if n == 0 then
		if ctx.isEditing then
			Strip:Show()
			LayoutSlots(2)
			SetSlot(1, "Interface\\Icons\\Spell_Shadow_SummonImp", "|cffffea89x3|r", 14, 0.76, 0.45, 1.0, "Summons (Preview)", "Active pets & summons")
			SetSlot(2, "Interface\\Icons\\Spell_Fire_SearingTotem", "|cff66ddff1/2|r", 22, 0.18, 0.78, 1.0, "Totems (Preview)", "Active totems")
			for i = 3, MAX_SLOTS do Slots[i]:Hide() end
			return
		end
		if Strip:IsShown() then Strip:Hide() end
		return
	end

	Strip:Show()
	LayoutSlots(n)
	for i = n + 1, MAX_SLOTS do if Slots[i]:IsShown() then Slots[i]:Hide() end end
end

NS.Modules.SummonTracker = Mod
