local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local ceil, max, min, abs, sin, tonumber, type, gmatch, fmt = math.ceil, math.max, math.min, math.abs, math.sin, tonumber, type, string.gmatch, string.format
local COLORS, SetText, FormatTime = NS.COLORS, NS.SetText, NS.FormatTime

local AFFIX_META = {
	Bolstering = { icon = "Interface\\Icons\\Spell_Nature_Strength",     desc = "A slain enemy empowers nearby enemies." },
	Sanguine   = { icon = "Interface\\Icons\\Spell_Shadow_LifeDrain",    desc = "A slain elite leaves a pool that heals enemies." },
	Explosive  = { icon = "Interface\\Icons\\Spell_Fire_SelfDestruct",   desc = "Explosive orbs appear; destroy them before they burst." },
}
local HEX_META = {
	frenzy  = { name = "Frenzy",    icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",  desc = "Cursed Chest Hex: enemies move %d%% faster." },
	surge   = { name = "Surge",     icon = "Interface\\Icons\\Spell_Shadow_AuraOfDarkness", desc = "Cursed Chest Hex: the horde spawns faster and thicker." },
	frailty = { name = "Frailty",   icon = "Interface\\Icons\\Spell_Shadow_FingerOfDeath",  desc = "Cursed Chest Hex: you take %d%% more damage." },
	wither  = { name = "Withering", icon = "Interface\\Icons\\Ability_Warrior_SavageBlow",  desc = "Cursed Chest Hex: your healing is reduced by %d%%." },
}
local TEX_KEY_HELD = "Interface\\Icons\\INV_Misc_Key_14"
local TEX_KEY_BOSS = "Interface\\Icons\\INV_Misc_Key_13"
local TEX_DIAMOND  = NS.OwnMedia("pin_diamond")

local Panel = CreateFrame("Frame", "AZS_MinUI_RunObjectives", UIParent)
NS.RegisterMovableBox("RunObjectives", "Affixes, Hexes & Bosses", Panel)

Panel.header = NS.CreateFontText(Panel, 0, "LEFT")
Panel.header:SetPoint("TOPLEFT", Panel, "TOPLEFT", 12, -10)
Panel.header:SetText("|cffffea89OBJECTIVES|r")
Panel.sub = NS.CreateFontText(Panel, -2, "RIGHT")
Panel.sub:SetPoint("TOPRIGHT", Panel, "TOPRIGHT", -12, -11)

local function OnBadgeEnter(self)
	if not (GameTooltip and self._tipTitle) then return end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText(self._tipTitle, self._tr or 1, self._tg or 0.9, self._tb or 0.4)
	if self._tipDesc and self._tipDesc ~= "" then GameTooltip:AddLine(self._tipDesc, 0.85, 0.90, 0.96, true) end
	GameTooltip:Show()
end
local function OnBadgeLeave() if GameTooltip then GameTooltip:Hide() end end

local MAX_BADGES, BADGE_SZ, BADGE_GAP = 7, 24, 5
local Badges = {}
for i = 1, MAX_BADGES do
	local b = CreateFrame("Frame", nil, Panel)
	b:SetSize(BADGE_SZ, BADGE_SZ)
	b:SetPoint("TOPLEFT", Panel, "TOPLEFT", 12 + (i - 1) * (BADGE_SZ + BADGE_GAP), -28)
	b:EnableMouse(true)
	b:SetScript("OnEnter", OnBadgeEnter)
	b:SetScript("OnLeave", OnBadgeLeave)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints(b)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.txt = NS.CreateFontText(b, -2, "CENTER")
	b.txt:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:Hide()
	Badges[i] = b
end

local MAX_BOSS_ROWS = 5
local BossRows = {}
for i = 1, MAX_BOSS_ROWS do
	local row = CreateFrame("Frame", nil, Panel)
	row:SetHeight(16)
	row:SetPoint("TOPLEFT", Panel, "TOPLEFT", 12, -58 - (i - 1) * 17)
	row:SetPoint("TOPRIGHT", Panel, "TOPRIGHT", -12, -58 - (i - 1) * 17)
	row.dot = row:CreateTexture(nil, "ARTWORK")
	row.dot:SetSize(8, 8)
	row.dot:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.dot:SetTexture(TEX_DIAMOND)
	row.stateTxt = NS.CreateFontText(row, -2, "RIGHT")
	row.stateTxt:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.name = NS.CreateFontText(row, 0, "LEFT")
	row.name:SetPoint("LEFT", row.dot, "RIGHT", 6, 0)
	row.name:SetPoint("RIGHT", row.stateTxt, "LEFT", -6, 0)
	NS.SetNoWrap(row.name, 14)
	row:Hide()
	BossRows[i] = row
end

local function SetBadge(idx, tex, text, title, desc, tr, tg, tb, alpha)
	if idx > MAX_BADGES then return end
	local b = Badges[idx]
	if b._tex ~= tex then b._tex = tex; b.icon:SetTexture(tex) end
	SetText(b.txt, text or "")
	b._tipTitle, b._tipDesc, b._tr, b._tg, b._tb = title, desc, tr, tg, tb
	b:SetAlpha(alpha or 1.0)
	b:Show()
end

local lastRowOffsetY = -58
local function SetBossRowTop(topY)
	if lastRowOffsetY == topY then return end
	lastRowOffsetY = topY
	for i = 1, MAX_BOSS_ROWS do
		local row = BossRows[i]
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", Panel, "TOPLEFT", 12, topY - (i - 1) * 17)
		row:SetPoint("TOPRIGHT", Panel, "TOPRIGHT", -12, topY - (i - 1) * 17)
	end
end

local Mod = { frame = Panel }
function Mod.Update(ctx)
	if NS.GetModuleMode("RunObjectives") ~= "minimal" or NS.IsBoxHidden("RunObjectives") then
		if not ctx.isEditing and Panel:IsShown() then Panel:Hide() end
		if NS.GetModuleMode("RunObjectives") ~= "minimal" or not ctx.isEditing then return end
	end

	local badgeCount = 0
	local runClock = ctx.runClock or 0
	local zone = ctx.zone

	if not ctx.inHub and zone and type(zone.affixes) == "string" and zone.affixes ~= "" then
		for af in gmatch(zone.affixes, "[^,]+") do
			if badgeCount < MAX_BADGES then
				badgeCount = badgeCount + 1
				local meta = AFFIX_META[af]
				SetBadge(badgeCount, (meta and meta.icon) or NS.QUESTION_ICON, "",
					af, (meta and meta.desc) or "Weekly Heroic Affix", 1.0, 0.78, 0.30, 1.0)
			end
		end
	end

	if not ctx.inHub and type(_G.AZS_HEXES) == "table" then
		local hexes = _G.AZS_HEXES
		for i = 1, #hexes do
			local hx = hexes[i]
			local left = hx and ((tonumber(hx["until"]) or 0) - runClock) or 0
			if left > 0 and badgeCount < MAX_BADGES then
				local meta = HEX_META[hx.key]
				if meta then
					badgeCount = badgeCount + 1
					local pct = tonumber(hx.pct) or 0
					local desc = (pct > 0 and (hx.key ~= "surge")) and fmt(meta.desc, pct) or meta.desc
					local alpha = left < 5 and (0.55 + 0.45 * abs(sin(ctx.now * 6.0))) or 1.0
					SetBadge(badgeCount, meta.icon, fmt("|cffff99ff%d|r", ceil(left)),
						meta.name, fmt("%s\nRemaining: %ds", desc, ceil(left)), 0.82, 0.48, 1.0, alpha)
				end
			end
		end
	end

	if not ctx.inHub and type(_G.AZS_KEYS) == "table" then
		local keys = _G.AZS_KEYS
		for i = 1, #keys do
			local k = keys[i]
			if k and badgeCount < MAX_BADGES then
				local isBoss = (k.kind == "boss")
				local left = (tonumber(k["until"]) or 0) - runClock
				if not isBoss or left > 0 then
					badgeCount = badgeCount + 1
					if isBoss then
						SetBadge(badgeCount, TEX_KEY_BOSS, "|cffffcc55" .. FormatTime(left) .. "|r",
							"Key Boss Active", "Slay the key guardian before the timer expires!", 1.0, 0.60, 0.20, 1.0)
					else
						SetBadge(badgeCount, TEX_KEY_HELD, "|cff55ff88OK|r",
							"Dungeon Key Held", "Opens a locked door in this arena.", 1.0, 0.88, 0.35, 1.0)
					end
				end
			end
		end
	end

	local sched = (not ctx.inHub and type(_G.AZS_SCHEDULE) == "table") and _G.AZS_SCHEDULE or nil
	local bossCount = sched and min(MAX_BOSS_ROWS, #sched) or 0

	if badgeCount == 0 and bossCount == 0 then
		if ctx.isEditing then
			Panel:Show()
			SetText(Panel.sub, "|cff8892a4Preview|r")
			SetBadge(1, AFFIX_META.Bolstering.icon, "", "Bolstering", AFFIX_META.Bolstering.desc, 1, 0.78, 0.3, 1)
			SetBadge(2, HEX_META.frenzy.icon, "|cffff99ff18|r", "Frenzy", "Cursed Chest Hex preview", 0.82, 0.48, 1, 1)
			SetBadge(3, TEX_KEY_HELD, "|cff55ff88OK|r", "Dungeon Key", "Key preview", 1, 0.88, 0.35, 1)
			for i = 4, MAX_BADGES do Badges[i]:Hide() end
			SetBossRowTop(-58)
			local sample = { { "Hogger", "dead" }, { "Lord Godfrey", "up" }, { "Final Boss", "due" } }
			for i = 1, MAX_BOSS_ROWS do
				local r = BossRows[i]
				local s = sample[i]
				if s then
					if s[2] == "dead" then
						r.dot:SetVertexColor(0.35, 0.92, 0.45, 1); SetText(r.name, "|cff70b878" .. s[1] .. "|r"); SetText(r.stateTxt, "|cff55ff88DONE|r")
					elseif s[2] == "up" then
						r.dot:SetVertexColor(1.0, 0.55, 0.14, 1); SetText(r.name, "|cffff9933" .. s[1] .. "|r"); SetText(r.stateTxt, "|cffff6633UP|r")
					else
						r.dot:SetVertexColor(0.38, 0.44, 0.54, 0.9); SetText(r.name, "|cff94a3b8" .. s[1] .. "|r"); SetText(r.stateTxt, "|cff6e7c91DUE|r")
					end
					r:Show()
				else
					r:Hide()
				end
			end
			return
		end
		if Panel:IsShown() then Panel:Hide() end
		return
	end

	Panel:Show()
	for i = badgeCount + 1, MAX_BADGES do if Badges[i]:IsShown() then Badges[i]:Hide() end end
	SetBossRowTop(badgeCount > 0 and -58 or -28)

	local doneCnt = 0
	for i = 1, bossCount do
		if sched[i] and sched[i].state == "dead" then doneCnt = doneCnt + 1 end
	end
	SetText(Panel.sub, bossCount > 0 and fmt("|cff94a3b8%d/%d|r", doneCnt, bossCount) or "")

	for i = 1, MAX_BOSS_ROWS do
		local r = BossRows[i]
		local b = (i <= bossCount) and sched[i] or nil
		if b then
			local bName = (b.name and b.name ~= "") and b.name or ("Boss #" .. i)
			if b.state == "dead" then
				r.dot:SetVertexColor(0.35, 0.92, 0.45, 1)
				SetText(r.name, "|cff70b878" .. bName .. "|r")
				SetText(r.stateTxt, "|cff55ff88DONE|r")
			elseif b.state == "up" then
				r.dot:SetVertexColor(1.0, 0.55, 0.14, 1)
				SetText(r.name, "|cffff9933" .. bName .. "|r")
				SetText(r.stateTxt, "|cffff5533ACTIVE|r")
			else
				local isFinal = (b.final == "1" or b.final == true)
				r.dot:SetVertexColor(isFinal and 0.95 or 0.38, isFinal and 0.78 or 0.44, isFinal and 0.25 or 0.54, 0.9)
				SetText(r.name, (isFinal and "|cffffea89" or "|cff94a3b8") .. bName .. "|r")
				local atSec = tonumber(b.at)
				SetText(r.stateTxt, (atSec and atSec > runClock) and ("|cff6e7c91" .. FormatTime(atSec - runClock) .. "|r") or "|cff6e7c91DUE|r")
			end
			r:Show()
		elseif r:IsShown() then
			r:Hide()
		end
	end
end

function Mod.ApplyTheme(th)
	Panel.header:SetText(((th and th.hex and th.hex.title) or "|cffffea89") .. "OBJECTIVES|r")
end

NS.Modules.RunObjectives = Mod
