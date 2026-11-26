local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, min = math.floor, math.min
local CancelUnitBuff, InCombatLockdown = CancelUnitBuff, InCombatLockdown
local SetText, FormatShortTime = NS.SetText, NS.FormatShortTime
local BT = NS.BuffTracker

local BuffsFrame = CreateFrame("Frame", "AZS_MinUI_PlayerBuffs", UIParent)
NS.RegisterMovableBox("PlayerBuffs", "Player Buffs", BuffsFrame)

local MAX_SLOTS, ICONS_PER_ROW = 32, 8
local ICON_SIZES = { 24, 28, 34 }
local BuffSlots, BuffList = {}, {}

local function OnSlotEnter(self)
	if self._entry then BT.ShowEntryTooltip(self, "ANCHOR_BOTTOMLEFT", self._entry, "player") end
end
local function OnSlotLeave() if GameTooltip then GameTooltip:Hide() end end
local function OnSlotClick(self, btn)
	local e = self._entry
	if btn == "RightButton" and e and e.auraIndex and (not e.isDebuff) and (not InCombatLockdown()) then
		CancelUnitBuff("player", e.auraIndex)
	end
end

for i = 1, MAX_SLOTS do
	local btn = CreateFrame("Button", nil, BuffsFrame)
	btn:SetSize(28, 28)
	btn:RegisterForClicks("RightButtonUp")
	btn.bg = btn:CreateTexture(nil, "BACKGROUND")
	btn.bg:SetAllPoints()
	btn.bg:SetTexture(NS.OwnMedia("blank"))
	btn.bg:SetVertexColor(0.03, 0.04, 0.06, 0.90)
	btn.icon = btn:CreateTexture(nil, "ARTWORK")
	btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
	btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
	btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	btn.border = CreateFrame("Frame", nil, btn)
	btn.border:SetAllPoints()
	NS.ApplyFlatBackdrop(btn.border, nil, { 0.00, 0.85, 0.72, 0.85 }, true)
	btn.stacks = NS.CreateFontText(btn.border, -2, "RIGHT")
	btn.stacks:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -1)
	btn.timer = NS.CreateFontText(btn.border, -3, "CENTER")
	btn.timer:SetPoint("TOP", btn, "BOTTOM", 0, -2)
	btn:SetScript("OnEnter", OnSlotEnter)
	btn:SetScript("OnLeave", OnSlotLeave)
	btn:SetScript("OnClick", OnSlotClick)
	btn:Hide()
	BuffSlots[i] = btn
end

local lastIconSz = -1
local function LayoutSlots(iconSz)
	if lastIconSz == iconSz then return end
	lastIconSz = iconSz
	local stepX, stepY = iconSz + 5, iconSz + 14
	for i = 1, MAX_SLOTS do
		local slot = BuffSlots[i]
		slot:SetSize(iconSz, iconSz)
		slot:ClearAllPoints()
		slot:SetPoint("TOPRIGHT", BuffsFrame, "TOPRIGHT", -((i - 1) % ICONS_PER_ROW) * stepX, -floor((i - 1) / ICONS_PER_ROW) * stepY)
	end
end

local function ApplySlot(slot, entry)
	slot._entry = entry
	local tex = entry.icon or NS.QUESTION_ICON
	if slot._tex ~= tex then slot._tex = tex; slot.icon:SetTexture(tex) end

	local borderKey = (entry.cat or "buff") .. ":" .. (entry.rarity or 0)
	if slot._borderKey ~= borderKey then
		slot._borderKey = borderKey
		local col = BT.GetCategoryColor(entry.cat, entry.rarity)
		slot.border:SetBackdropBorderColor(col[1], col[2], col[3], col[4] or 0.90)
	end

	local onCd = (entry.rem or 0) <= 0 and (entry.cdRem or 0) > 0.05
	if slot._dim ~= onCd then
		slot._dim = onCd
		if onCd then slot.icon:SetVertexColor(0.55, 0.55, 0.62, 1)
		else slot.icon:SetVertexColor(1, 1, 1, 1) end
	end

	local cnt = entry.count or 0
	if cnt > 1 or (entry.cat == "item" and cnt >= 1) then
		local colTag = (entry.cat == "debuff") and "|cffff8888" or (entry.cat == "item" and "|cff66eeff" or "|cffffea89")
		SetText(slot.stacks, colTag .. cnt .. "|r")
	else
		SetText(slot.stacks, "")
	end

	if entry.rem and entry.rem > 0 then
		SetText(slot.timer, FormatShortTime(entry.rem, true))
	elseif onCd then
		SetText(slot.timer, "|cffffcc44" .. FormatShortTime(entry.cdRem, false) .. "|r")
	else
		SetText(slot.timer, "")
	end
	slot:Show()
end

local PREVIEW_BUFFS = {
	{ cat = "buff",   name = "Divine Shield",    icon = "Interface\\Icons\\Spell_Holy_DivineIntervention", count = 0, rem = 4.2,  sub = "Active Buff",     text = "Grants immunity to all damage." },
	{ cat = "buff",   name = "Battle Shout",     icon = "Interface\\Icons\\Ability_Warrior_BattleShout",  count = 0, rem = 11.5, sub = "Active Buff",     text = "Increases damage dealt by 25%." },
	{ cat = "item",   name = "Darkmoon Ring",    icon = "Interface\\Icons\\INV_Jewelry_Ring_36",          count = 0, rem = 0,    cdRem = 14, cdDur = 30, rarity = 3, sub = "Ring", text = "+12% Damage · Every 30 sec, +20% crit for 8 sec." },
	{ cat = "item",   name = "Amulet of Power",  icon = "Interface\\Icons\\INV_Jewelry_Necklace_28",      count = 3, rem = 0,    rarity = 4, sub = "Amulet · Rank 3", text = "+18% Spell Damage and +10% Cooldown Reduction." },
	{ cat = "race",   name = "Blood Fury",       icon = "Interface\\Icons\\Racial_Orc_BerserkerStrength", count = 0, rem = 0,    cdRem = 22, cdDur = 40, sub = "Racial Buff", text = "Every 40 sec, +35% damage for 12 sec." },
	{ cat = "talent", name = "Last Stand",       icon = "Interface\\Icons\\Spell_Holy_AshesToAshes",      count = 0, rem = 0,    ready = true, cdDur = 90, sub = "Talent · Protection (1/1)", text = "Survive lethal damage once every 90 sec." },
	{ cat = "debuff", name = "Curse (Debuff)",   icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", count = 2, rem = 6.2,  isDebuff = true, sub = "Debuff", text = "Sample debuff preview." },
}

local Mod = { frame = BuffsFrame }
function Mod.Update(ctx)
	if NS.GetModuleMode("PlayerBuffs") ~= "minimal" or NS.IsBoxHidden("PlayerBuffs") then
		if not ctx.isEditing and BuffsFrame:IsShown() then BuffsFrame:Hide() end
		if NS.GetModuleMode("PlayerBuffs") ~= "minimal" or not ctx.isEditing then return end
	end
	BuffsFrame:Show()
	local cfg = (NS.DB and NS.DB.buffs) or NS.DEFAULTS.buffs
	LayoutSlots(ICON_SIZES[(cfg and cfg.sizeMode) or 2] or 28)

	local total = BT.CollectPlayerBuffs(ctx, cfg, BuffList)
	local shown = min(total, MAX_SLOTS)
	for i = 1, shown do
		ApplySlot(BuffSlots[i], BuffList[i])
	end
	if shown == 0 and ctx.isEditing then
		shown = min(#PREVIEW_BUFFS, MAX_SLOTS)
		for i = 1, shown do ApplySlot(BuffSlots[i], PREVIEW_BUFFS[i]) end
	end
	for i = shown + 1, MAX_SLOTS do
		BuffSlots[i]._entry = nil
		if BuffSlots[i]:IsShown() then BuffSlots[i]:Hide() end
	end
end

NS.Modules.PlayerBuffs = Mod
