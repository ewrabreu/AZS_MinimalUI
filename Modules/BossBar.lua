local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local max, tonumber, type, pcall = math.max, tonumber, type, pcall
local fmt = string.format
local COLORS, SetText, ResolveIcon = NS.COLORS, NS.SetText, NS.ResolveIcon

local BossContainer = CreateFrame("Frame", "AZS_MinUI_BossBar", UIParent)
NS.RegisterMovableBox("BossBar", "Boss Bars", BossContainer)

local BOSS_BAR_W, BOSS_BAR_H, BOSS_CASE_W, BOSS_CASE_H = 234, 17, 306, 84
local TEX_BADGE_BOSS = NS.Media("icon_badges_boss")
local TEX_BADGE_RARE = NS.Media("icon_classification_rare")
local BossRows = {}

for i = 1, 3 do
	local holder = CreateFrame("Frame", nil, BossContainer)
	holder:SetSize(BOSS_CASE_W, 32)
	holder:SetPoint("TOP", BossContainer, "TOP", 0, -(i - 1) * 34)
	local caseFrame = CreateFrame("Frame", nil, holder)
	caseFrame:SetAllPoints(holder)
	local bar = CreateFrame("StatusBar", nil, holder)
	bar:SetSize(BOSS_BAR_W, BOSS_BAR_H)
	bar:SetPoint("CENTER", holder, "CENTER", 0, 0)
	bar:SetFrameLevel(caseFrame:GetFrameLevel() + 1)
	bar:SetStatusBarTexture(NS.Media("hp_boss_bar"))
	bar:SetStatusBarColor(COLORS.bossOrange[1], COLORS.bossOrange[2], COLORS.bossOrange[3], 1)
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(100)
	local case = caseFrame:CreateTexture(nil, "ARTWORK")
	case:SetSize(BOSS_CASE_W, BOSS_CASE_H)
	case:SetPoint("CENTER", bar, "CENTER", 0, 0)
	case:SetTexture(NS.Media("hp_boss_case"))
	case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
	local glow = caseFrame:CreateTexture(nil, "BACKGROUND")
	glow:SetSize(BOSS_CASE_W, BOSS_CASE_H)
	glow:SetPoint("CENTER", bar, "CENTER", 0, 0)
	glow:SetTexture(NS.Media("hp_boss_case_glow"))
	glow:SetVertexColor(1.0, 0.2, 0.2, 0.9)
	glow:Hide()
	local overlay = CreateFrame("Frame", nil, bar)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(bar:GetFrameLevel() + 2)
	local badge = overlay:CreateTexture(nil, "OVERLAY")
	badge:SetSize(24, 24)
	badge:SetPoint("RIGHT", bar, "LEFT", -3, 0)
	badge:SetTexture(TEX_BADGE_BOSS)
	local hpText = NS.CreateFontText(overlay, 2, "RIGHT")
	hpText:SetPoint("RIGHT", bar, "RIGHT", -8, 1)
	local nameText = NS.CreateFontText(overlay, 2, "LEFT")
	nameText:SetPoint("LEFT", bar, "LEFT", 8, 1)
	nameText:SetPoint("RIGHT", hpText, "LEFT", -6, 0)
	NS.SetNoWrap(nameText, 16)
	local debuffs = {}
	for d = 1, 5 do
		local df = CreateFrame("Frame", nil, overlay)
		df:SetSize(16, 16)
		df:SetPoint("LEFT", bar, "RIGHT", 8 + (d - 1) * 19, 0)
		df.tex = df:CreateTexture(nil, "ARTWORK")
		df.tex:SetAllPoints()
		df.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		df:Hide()
		debuffs[d] = df
	end
	holder.bar, holder.case, holder.glow, holder.badge = bar, case, glow, badge
	holder.nameText, holder.hpText, holder.debuffs = nameText, hpText, debuffs
	holder:Hide()
	BossRows[i] = holder
end

local BossData, BossIsGuard = {}, {}
local Mod = { frame = BossContainer }

function Mod.Update(ctx)
	local isEditing = ctx.isEditing
	if NS.IsBoxHidden("BossBar") and not isEditing then
		if BossContainer:IsShown() then BossContainer:Hide() end
		return
	end
	local count = 0
	if type(_G.AZS_GetBosses) == "function" then
		local ok, b = pcall(_G.AZS_GetBosses)
		if ok and type(b) == "table" then
			for i = 1, #b do
				if count >= 3 then break end
				count = count + 1
				BossData[count], BossIsGuard[count] = b[i], false
			end
		end
	elseif type(_G.AZS_UNITS) == "table" then
		local u = _G.AZS_UNITS
		for i = 1, #u do
			if count >= 3 then break end
			count = count + 1
			BossData[count], BossIsGuard[count] = u[i], false
		end
	end
	if count < 3 and type(_G.AZS_GetGuardians) == "function" then
		local ok, g = pcall(_G.AZS_GetGuardians)
		if ok and type(g) == "table" then
			for i = 1, #g do
				if count >= 3 then break end
				if g[i] and g[i].awake then
					count = count + 1
					BossData[count], BossIsGuard[count] = g[i], true
				end
			end
		end
	end

	if count == 0 and not isEditing then
		if BossContainer:IsShown() then BossContainer:Hide() end
		return
	end
	BossContainer:Show()

	for i = 1, 3 do
		local row = BossRows[i]
		local b = (i <= count) and BossData[i] or nil
		if b then
			local isGuard = BossIsGuard[i]
			local hp = tonumber(b.hp) or 0
			local hpm = max(1, tonumber(b.hpm) or 1)
			row.bar:SetMinMaxValues(0, hpm)
			row.bar:SetValue(hp)
			local enraged = (b.enraged == true) or (tonumber(b.state) == 1)
			local state = enraged and 3 or (isGuard and 2 or 1)
			if row._state ~= state then
				row._state = state
				if state == 3 then
					row.bar:SetStatusBarColor(0.95, 0.12, 0.18, 1)
					row.glow:Show()
				elseif state == 2 then
					row.bar:SetStatusBarColor(COLORS.rarePurple[1], COLORS.rarePurple[2], COLORS.rarePurple[3], 1)
					row.glow:Hide()
				else
					row.bar:SetStatusBarColor(COLORS.bossOrange[1], COLORS.bossOrange[2], COLORS.bossOrange[3], 1)
					row.glow:Hide()
				end
			end
			local badgeTex = isGuard and TEX_BADGE_RARE or TEX_BADGE_BOSS
			if row._badgeTex ~= badgeTex then row._badgeTex = badgeTex; row.badge:SetTexture(badgeTex) end
			SetText(row.nameText, (enraged and "|cffff3333[ENRAGE] |r" or "") .. (isGuard and "|cffb866ff" or "|cffff8c1a") .. (b.name or "Boss") .. "|r")
			SetText(row.hpText, fmt("%s (%.0f%%)", NS.FormatNumber(hp), (hp / hpm) * 100))
			local dbs = b.debuffs
			if not dbs and b.id and type(_G.AZS_GetDebuffs) == "function" then
				local ok, res = pcall(_G.AZS_GetDebuffs, b.id)
				if ok then dbs = res end
			end
			for d = 1, 5 do
				local df = row.debuffs[d]
				local di = dbs and dbs[d]
				if di then
					local tex = ResolveIcon(di.icon, di.spell)
					if df._tex ~= tex then df._tex = tex; df.tex:SetTexture(tex) end
					df:Show()
				else
					df:Hide()
				end
			end
			row:Show()
		elseif isEditing and i == 1 then
			row.bar:SetMinMaxValues(0, 100)
			row.bar:SetValue(72)
			if row._state ~= 1 then
				row._state = 1
				row.bar:SetStatusBarColor(COLORS.bossOrange[1], COLORS.bossOrange[2], COLORS.bossOrange[3], 1)
				row.glow:Hide()
			end
			SetText(row.nameText, "|cffff8c1aSample Boss (Edit Mode)|r")
			SetText(row.hpText, "720K (72%)")
			for d = 1, 5 do row.debuffs[d]:Hide() end
			row:Show()
		else
			row:Hide()
		end
	end
end

function Mod.ApplyTheme()
	for i = 1, 3 do
		local row = BossRows[i]
		row._state = nil
		row.case:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
		row.bar:SetStatusBarColor(COLORS.bossOrange[1], COLORS.bossOrange[2], COLORS.bossOrange[3], 1)
	end
end

NS.Modules.BossBar = Mod
