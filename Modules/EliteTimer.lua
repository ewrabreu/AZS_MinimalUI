local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, max, min, sin = math.floor, math.max, math.min, math.sin
local tonumber, tostring, type, match, fmt = tonumber, tostring, type, string.match, string.format
local COLORS, Clamp, SetText, FormatTime = NS.COLORS, NS.Clamp, NS.SetText, NS.FormatTime

local TEX_ELITE = "Interface\\Icons\\Ability_Warrior_Rampage"
local TEX_LAIR  = "Interface\\Icons\\Spell_Shadow_Skull"
local TEX_AWAKE = "Interface\\Icons\\Ability_DualWield"

local EliteFrame = CreateFrame("Frame", "AZS_MinUI_EliteTimer", UIParent)
NS.RegisterMovableBox("EliteTimer", "Elite Spawn Timer", EliteFrame)

EliteFrame.icon = EliteFrame:CreateTexture(nil, "ARTWORK")
EliteFrame.icon:SetSize(16, 16)
EliteFrame.icon:SetPoint("TOPLEFT", EliteFrame, "TOPLEFT", 14, -10)
EliteFrame.icon:SetTexture(TEX_ELITE)
EliteFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
EliteFrame.header = NS.CreateFontText(EliteFrame, 0, "LEFT")
EliteFrame.header:SetPoint("LEFT", EliteFrame.icon, "RIGHT", 4, 0)
EliteFrame.header:SetText("|cff3b9effELITE SPAWN|r")
EliteFrame.counts = NS.CreateFontText(EliteFrame, -2, "RIGHT")
EliteFrame.counts:SetPoint("TOPRIGHT", EliteFrame, "TOPRIGHT", -14, -10)

local function CreateMeterStyleRow(parent, yOff, defaultIcon, barCol)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(25)
	row:SetPoint("TOPLEFT",  parent, "TOPLEFT",   14, yOff)
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, yOff)
	row.iconHolder = CreateFrame("Frame", nil, row)
	row.iconHolder:SetSize(18, 18)
	row.iconHolder:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon = row.iconHolder:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.icon:SetTexture(defaultIcon)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if row.icon.SetMask then row.icon:SetMask(NS.Media("actionbutton-mask-square")) end
	row._icon = defaultIcon
	row.val = NS.CreateFontText(row, 0, "RIGHT")
	row.val:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	row.name = NS.CreateFontText(row, 0, "LEFT")
	row.name:SetPoint("TOPLEFT", row.iconHolder, "TOPRIGHT", 7, 0)
	row.name:SetPoint("RIGHT", row.val, "LEFT", -6, 0)
	NS.SetNoWrap(row.name, 14)
	row.barFrame, row.bar, row.barBg = NS.CreateThinBar(row, 4, barCol)
	row.barFrame:SetPoint("BOTTOMLEFT",  row.iconHolder, "BOTTOMRIGHT", 7, 1)
	row.barFrame:SetPoint("BOTTOMRIGHT", row,            "BOTTOMRIGHT", 0, 1)
	return row
end

local MainRow = CreateMeterStyleRow(EliteFrame, -32, TEX_ELITE, COLORS.eliteBlue)

local MAX_LAIR_ROWS = 3
local LairRows = {}
for i = 1, MAX_LAIR_ROWS do
	local row = CreateMeterStyleRow(EliteFrame, -59 - (i - 1) * 27, TEX_LAIR, COLORS.rarePurple)
	row:Hide()
	LairRows[i] = row
end

local DEFAULT_INTERVAL = 45
local lastRunClock, lastTotalElites, lastSpawnAt, spawnInterval, spawnSamples = 0, -1, 0, DEFAULT_INTERVAL, 0
local LairMaxByIdx = {}

local function ResetTracker()
	lastTotalElites, lastSpawnAt, spawnInterval, spawnSamples = -1, 0, DEFAULT_INTERVAL, 0
	NS.Wipe(LairMaxByIdx)
end

local Mod = { frame = EliteFrame }

function Mod.Update(ctx)
	if NS.GetModuleMode("EliteTimer") ~= "minimal" or NS.IsBoxHidden("EliteTimer") then
		if not ctx.isEditing and EliteFrame:IsShown() then EliteFrame:Hide() end
		if NS.GetModuleMode("EliteTimer") ~= "minimal" or not ctx.isEditing then return end
	end
	EliteFrame:Show()

	local run, runClock = ctx.run, ctx.runClock or 0
	if ctx.inHub or (lastRunClock > 5 and runClock < 3) then
		ResetTracker()
	end
	lastRunClock = runClock

	if ctx.inHub and ctx.isEditing then
		SetText(EliteFrame.counts, "|cff3b9eff2|r · |cff94a3b811|r")
		MainRow.bar:SetValue(68)
		MainRow.bar:SetStatusBarColor(COLORS.eliteBlue[1], COLORS.eliteBlue[2], COLORS.eliteBlue[3], 0.95)
		SetText(MainRow.name, "|cffe2e8f0Next Elite Wave|r")
		SetText(MainRow.val, "|cffffea890:14|r")
		local lr = LairRows[1]
		if lr._icon ~= TEX_LAIR then lr._icon = TEX_LAIR; lr.icon:SetTexture(TEX_LAIR) end
		lr.bar:SetValue(54)
		lr.bar:SetStatusBarColor(COLORS.rarePurple[1], COLORS.rarePurple[2], COLORS.rarePurple[3], 0.95)
		SetText(lr.name, "|cffc4b5fdGuardian Lair #1|r")
		SetText(lr.val, "|cffffd1000:28|r")
		lr:Show()
		for i = 2, MAX_LAIR_ROWS do LairRows[i]:Hide() end
		return
	end

	local alive = (run and tonumber(run.el)) or 0
	local slain = (run and tonumber(run.ek)) or 0
	local totalSeen = alive + slain

	if not ctx.inHub and runClock > 0 then
		if lastTotalElites < 0 then
			lastTotalElites = totalSeen
			lastSpawnAt = (totalSeen > 0) and runClock or 0
		elseif totalSeen > lastTotalElites then
			local delta = runClock - lastSpawnAt
			if lastSpawnAt > 0 and delta >= 15 and delta <= 120 then
				if spawnSamples == 0 then spawnInterval = delta
				else spawnInterval = spawnInterval * 0.65 + delta * 0.35 end
				spawnSamples = spawnSamples + 1
			elseif lastSpawnAt == 0 and runClock >= 15 and runClock <= 90 then
				spawnInterval = runClock
			end
			lastSpawnAt = runClock
			lastTotalElites = totalSeen
		end
	end

	local hunted, goal = run and run.hunt and match(tostring(run.hunt), "^(%d+),(%d+)$")
	if hunted and tonumber(goal) and tonumber(goal) > 0 then
		SetText(EliteFrame.counts, fmt("|cff3b9eff%d|r · |cff66ff99%s/%s|r", alive, hunted, goal))
	else
		SetText(EliteFrame.counts, fmt("|cff3b9eff%d|r · |cff94a3b8%d|r", alive, slain))
	end

	if ctx.inHub then
		MainRow.bar:SetValue(0)
		MainRow.bar:SetStatusBarColor(COLORS.eliteBlue[1], COLORS.eliteBlue[2], COLORS.eliteBlue[3], 0.95)
		SetText(MainRow.name, "|cff8492a6Waiting for run...|r")
		SetText(MainRow.val, "|cff6e7c91--|r")
	else
		local baseAt = lastSpawnAt
		local elapsed = max(0, runClock - baseAt)
		local rem = spawnInterval - elapsed
		if rem <= 0 then
			local cycles = floor(elapsed / max(15, spawnInterval))
			rem = max(0, (cycles + 1) * spawnInterval - elapsed)
		end
		local pct = Clamp(((spawnInterval - rem) / max(1, spawnInterval)) * 100, 2, 100)
		MainRow.bar:SetValue(pct)
		local imminent = rem <= 5
		if imminent then
			local pulse = 0.65 + 0.35 * sin(ctx.now * 8.0)
			MainRow.bar:SetStatusBarColor(COLORS.bossOrange[1], COLORS.bossOrange[2], COLORS.bossOrange[3], pulse)
			SetText(MainRow.name, "|cffffd100Elite Incoming!|r")
			SetText(MainRow.val, fmt("|cffff5555%.1fs|r", rem))
		else
			MainRow.bar:SetStatusBarColor(COLORS.eliteBlue[1], COLORS.eliteBlue[2], COLORS.eliteBlue[3], 0.95)
			SetText(MainRow.name, spawnSamples > 0 and "|cffe2e8f0Next Elite Wave|r" or "|cffcbd5e1Next Elite|r")
			SetText(MainRow.val, "|cffffea89" .. FormatTime(rem) .. "|r")
		end
	end

	local shown = 0
	local lairs = NS.GetLairs()
	if type(lairs) == "table" and not ctx.inHub then
		for i = 1, #lairs do
			if shown >= MAX_LAIR_ROWS then break end
			local l = lairs[i]
			local left = l and tonumber(l.left) or 0
			local lKey = l and (l.index or i) or i
			if l and l.state == "empty" and left > 0 then
				shown = shown + 1
				local row = LairRows[shown]
				if not LairMaxByIdx[lKey] or left > LairMaxByIdx[lKey] then LairMaxByIdx[lKey] = left end
				local maxLeft = max(1, LairMaxByIdx[lKey] or left)
				local pct = Clamp(((maxLeft - left) / maxLeft) * 100, 4, 100)
				if row._icon ~= TEX_LAIR then row._icon = TEX_LAIR; row.icon:SetTexture(TEX_LAIR) end
				row.bar:SetValue(pct)
				row.bar:SetStatusBarColor(COLORS.rarePurple[1], COLORS.rarePurple[2], COLORS.rarePurple[3], 0.95)
				SetText(row.name, "|cffc4b5fd" .. (l.name and l.name ~= "" and l.name or ("Lair #" .. tostring(l.index or shown))) .. "|r")
				SetText(row.val, "|cffffd100" .. FormatTime(left) .. "|r")
				row:Show()
			elseif l and l.state == "awake" then
				shown = shown + 1
				local row = LairRows[shown]
				LairMaxByIdx[lKey] = nil
				if row._icon ~= TEX_AWAKE then row._icon = TEX_AWAKE; row.icon:SetTexture(TEX_AWAKE) end
				row.bar:SetValue(100)
				row.bar:SetStatusBarColor(COLORS.mobRed[1], COLORS.mobRed[2], COLORS.mobRed[3], 0.95)
				SetText(row.name, "|cffff9999" .. (l.name and l.name ~= "" and l.name or "Guardian") .. "|r")
				SetText(row.val, "|cffff4444AWAKE|r")
				row:Show()
			end
		end
	end
	for i = shown + 1, MAX_LAIR_ROWS do
		if LairRows[i]:IsShown() then LairRows[i]:Hide() end
	end
end

function Mod.ApplyTheme(th)
	local trk = COLORS.barTrack
	EliteFrame.header:SetText(((th and th.hex and th.hex.accent) or "|cff3b9eff") .. "ELITE SPAWN|r")
	if trk then MainRow.barBg:SetVertexColor(trk[1], trk[2], trk[3], trk[4] or 0.85) end
	for i = 1, MAX_LAIR_ROWS do
		if trk then LairRows[i].barBg:SetVertexColor(trk[1], trk[2], trk[3], trk[4] or 0.85) end
	end
end

NS.Modules.EliteTimer = Mod
