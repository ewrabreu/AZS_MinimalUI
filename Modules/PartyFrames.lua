local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, max, sin, tonumber, type, pcall = math.floor, math.max, math.sin, tonumber, type, pcall
local fmt = string.format
local UnitExists, UnitName, UnitClass, UnitIsConnected, UnitIsDeadOrGhost = UnitExists, UnitName, UnitClass, UnitIsConnected, UnitIsDeadOrGhost
local UnitHealth, UnitHealthMax, GetNumPartyMembers = UnitHealth, UnitHealthMax, GetNumPartyMembers
local COLORS, Wipe, SetText, GetClassRGB, RGBToHex = NS.COLORS, NS.Wipe, NS.SetText, NS.GetClassRGB, NS.RGBToHex

local TEX_HEART = NS.Media("icon-heart-red")
local TEX_SKULL = NS.Media("icon_skull")
local TEX_CLASSES = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

local PartyContainer = CreateFrame("Frame", "AZS_MinUI_PartyFrames", UIParent)
NS.RegisterMovableBox("PartyFrames", "Party Health", PartyContainer)

PartyContainer.icon = PartyContainer:CreateTexture(nil, "ARTWORK")
PartyContainer.icon:SetSize(16, 16)
PartyContainer.icon:SetPoint("TOPLEFT", PartyContainer, "TOPLEFT", 12, -10)
PartyContainer.icon:SetTexture(TEX_HEART)
PartyContainer.header = NS.CreateFontText(PartyContainer, 0, "LEFT")
PartyContainer.header:SetPoint("LEFT", PartyContainer.icon, "RIGHT", 4, 0)
PartyContainer.header:SetText("|cffffea89PARTY HP|r")
PartyContainer.summaryTxt = NS.CreateFontText(PartyContainer, -1, "RIGHT")
PartyContainer.summaryTxt:SetPoint("TOPRIGHT", PartyContainer, "TOPRIGHT", -12, -11)

local MAX_PARTY = 4
local PartyRows = {}
local function OnRowEnter(self)
	if GameTooltip and self._unit and UnitExists(self._unit) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetUnit(self._unit); GameTooltip:Show()
	end
end
local function OnRowLeave() if GameTooltip then GameTooltip:Hide() end end

for i = 1, MAX_PARTY do
	local row = CreateFrame("Frame", nil, PartyContainer)
	row:SetHeight(24)
	row:SetPoint("TOPLEFT",  PartyContainer, "TOPLEFT",   12, -32 - (i - 1) * 26)
	row:SetPoint("TOPRIGHT", PartyContainer, "TOPRIGHT", -12, -32 - (i - 1) * 26)
	row:EnableMouse(true)
	row.iconHolder = CreateFrame("Frame", nil, row)
	row.iconHolder:SetSize(18, 18)
	row.iconHolder:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.iconBorder = row.iconHolder:CreateTexture(nil, "BACKGROUND")
	row.iconBorder:SetPoint("TOPLEFT", -1, 1)
	row.iconBorder:SetPoint("BOTTOMRIGHT", 1, -1)
	row.iconBorder:SetTexture(NS.OwnMedia("blank"))
	row.iconBorder:SetVertexColor(0.28, 0.30, 0.36, 0.65)
	row.icon = row.iconHolder:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints(row.iconHolder)
	row.val = NS.CreateFontText(row, -2, "RIGHT")
	row.val:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -1)
	row.name = NS.CreateFontText(row, -2, "LEFT")
	row.name:SetPoint("TOPLEFT", row.iconHolder, "TOPRIGHT", 7, -1)
	row.name:SetPoint("RIGHT", row.val, "LEFT", -6, 0)
	NS.SetNoWrap(row.name, 12)
	row.barFrame, row.bar, row.barBg = NS.CreateThinBar(row, 4)
	row.barFrame:SetPoint("BOTTOMLEFT",  row.iconHolder, "BOTTOMRIGHT", 7, 1)
	row.barFrame:SetPoint("BOTTOMRIGHT", row,            "BOTTOMRIGHT", 0, 1)
	row:SetScript("OnEnter", OnRowEnter)
	row:SetScript("OnLeave", OnRowLeave)
	row:Hide()
	PartyRows[i] = row
end

local function ApplyClassIcon(tex, classToken)
	local coords = classToken and _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[classToken]
	if coords then
		tex:SetTexture(TEX_CLASSES)
		tex:SetTexCoord(coords[1] + 0.02, coords[2] - 0.02, coords[3] + 0.02, coords[4] - 0.02)
	else
		tex:SetTexture(TEX_HEART)
		tex:SetTexCoord(0, 1, 0, 1)
	end
	tex:SetVertexColor(1, 1, 1, 1)
end

local function RenderPartyRow(row, unit, name, cls, hp, hpm, connected, dead, revivePct, pulse)
	row._unit = unit
	local r, g, b = GetClassRGB(cls)
	SetText(row.name, RGBToHex(r, g, b) .. name .. "|r")
	if not connected then
		ApplyClassIcon(row.icon, cls)
		row:SetAlpha(0.48)
		row.bar:SetMinMaxValues(0, 100)
		row.bar:SetValue(0)
		SetText(row.val, "|cff888888OFFLINE|r")
	elseif revivePct ~= nil then
		row:SetAlpha(1.0)
		row.icon:SetTexture(TEX_HEART)
		row.icon:SetTexCoord(0, 1, 0, 1)
		row.icon:SetVertexColor(1.0, 0.25, 0.28, pulse)
		row.bar:SetMinMaxValues(0, 100)
		row.bar:SetValue(revivePct)
		row.bar:SetStatusBarColor(1.0, 0.28, 0.28, pulse)
		SetText(row.val, fmt("|cffff4444DOWNED|r |cff94a3b8(Rev %d%%)|r", revivePct))
	elseif dead then
		row:SetAlpha(0.72)
		row.icon:SetTexture(TEX_SKULL)
		row.icon:SetTexCoord(0, 1, 0, 1)
		row.icon:SetVertexColor(0.95, 0.35, 0.35, 0.95)
		row.bar:SetMinMaxValues(0, 100)
		row.bar:SetValue(0)
		SetText(row.val, "|cffff5555DEAD|r |cff94a3b8(0%)|r")
	else
		local pct = (hp / hpm) * 100
		row:SetAlpha(1.0)
		ApplyClassIcon(row.icon, cls)
		row.bar:SetMinMaxValues(0, hpm)
		row.bar:SetValue(hp)
		if pct <= 35 then
			row.bar:SetStatusBarColor(COLORS.health[1], COLORS.health[2], COLORS.health[3], pulse)
			SetText(row.val, fmt("|cffff4444%s|r |cff94a3b8(%.0f%%)|r", NS.FormatNumber(hp), pct))
		else
			row.bar:SetStatusBarColor(r, g, b, 0.92)
			SetText(row.val, fmt("%s |cff94a3b8(%.0f%%)|r", NS.FormatNumber(hp), pct))
		end
	end
	row:Show()
end

local DownedByName = {}
local PREVIEW_ALLIES = {
	{ name = "Arthas",   class = "PALADIN", hp = 1420, hpm = 1500 },
	{ name = "Jaina",    class = "MAGE",    hp = 310,  hpm = 1120 },
	{ name = "Thrall",   class = "SHAMAN",  hp = 0,    hpm = 1350, revivePct = 55 },
	{ name = "Sylvanas", class = "HUNTER",  hp = 1090, hpm = 1240 },
}

local Mod = { frame = PartyContainer }

function Mod.Update(ctx)
	if NS.GetModuleMode("PartyFrames") ~= "minimal" then
		if not ctx.isEditing then PartyContainer:Hide() end
		return
	end
	local nParty = GetNumPartyMembers() or 0
	if (nParty == 0 and not ctx.isEditing) or (NS.IsBoxHidden("PartyFrames") and not ctx.isEditing) then
		if PartyContainer:IsShown() then PartyContainer:Hide() end
		return
	end
	PartyContainer:Show()
	local pulse = 0.55 + 0.45 * sin(ctx.now * 6.0)

	if ctx.isEditing and nParty == 0 then
		SetText(PartyContainer.summaryTxt, "|cffff55551 downed|r |cff94a3b8(4)|r")
		for i = 1, MAX_PARTY do
			local p = PREVIEW_ALLIES[i]
			if p then RenderPartyRow(PartyRows[i], nil, p.name, p.class, p.hp, p.hpm, true, false, p.revivePct, pulse)
			else PartyRows[i]:Hide() end
		end
		return
	end

	Wipe(DownedByName)
	if type(_G.AZS_GetDownedPartyMembers) == "function" then
		local ok, list = pcall(_G.AZS_GetDownedPartyMembers)
		if ok and type(list) == "table" then
			for i = 1, #list do
				local d = list[i]
				if d and d.name then DownedByName[d.name] = d end
			end
		end
	end

	local aliveCount, downedCount, totalCount = 0, 0, 0
	for i = 1, MAX_PARTY do
		local row, unit = PartyRows[i], "party" .. i
		if i <= nParty and UnitExists(unit) then
			totalCount = totalCount + 1
			local name = UnitName(unit) or ("Ally " .. i)
			local _, cls = UnitClass(unit)
			local connected = UnitIsConnected(unit)
			local dead = UnitIsDeadOrGhost(unit)
			local downedInfo = DownedByName[name]
			local revPct = downedInfo and floor((tonumber(downedInfo.reviveShare) or 0) * 100) or nil
			if connected then
				if revPct or dead then downedCount = downedCount + 1 else aliveCount = aliveCount + 1 end
			end
			RenderPartyRow(row, unit, name, cls, UnitHealth(unit) or 0, max(1, UnitHealthMax(unit) or 1), connected, dead, revPct, pulse)
		else
			row._unit = nil
			if row:IsShown() then row:Hide() end
		end
	end

	if downedCount > 0 then
		SetText(PartyContainer.summaryTxt, fmt("|cffff4444%d downed|r |cff94a3b8(%d/%d)|r", downedCount, aliveCount, totalCount))
	else
		SetText(PartyContainer.summaryTxt, fmt("|cff66ff88%d/%d alive|r", aliveCount, totalCount))
	end
end

NS.Modules.PartyFrames = Mod
