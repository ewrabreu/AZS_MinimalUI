local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local max, tonumber, tostring, type, pairs, pcall, select = math.max, tonumber, tostring, type, pairs, pcall, select
local lower, find = string.lower, string.find
local GetTime, WorldFrame = GetTime, WorldFrame
local COLORS, Wipe, SetText = NS.COLORS, NS.Wipe, NS.SetText

local SkinnedPlates, KnownUnitRankByName = {}, {}
local NonPlates = setmetatable({}, { __mode = "k" })
local lastWorldChildrenCount, lastFullScanTime, lastAppliedMode = -1, 0, nil

local PLATE_SIZES = {
	[1] = { normW = 46, normH = 4, eliteW = 64, eliteH = 5, bossW = 84,  bossH = 7 },
	[2] = { normW = 56, normH = 5, eliteW = 76, eliteH = 6, bossW = 100, bossH = 8 },
	[3] = { normW = 68, normH = 6, eliteW = 90, eliteH = 7, bossW = 118, bossH = 9 },
}

local function RefreshKnownUnitRanks()
	Wipe(KnownUnitRankByName)
	if type(_G.AZS_WorldUnits) == "function" then
		local ok, units = pcall(_G.AZS_WorldUnits, 1)
		if ok and type(units) == "table" then
			for i = 1, #units do
				local u = units[i]
				if u and u.alive and not u.player and u.name then
					local r = tonumber(u.rank) or 0
					local tier = (r == 3) and 3 or ((r == 2 or r == 4) and 2 or 1)
					if tier > (KnownUnitRankByName[u.name] or 0) then KnownUnitRankByName[u.name] = tier end
				end
			end
		end
	end
	if type(_G.AZS_LAIRS) == "table" then
		local lairs = _G.AZS_LAIRS
		for i = 1, #lairs do
			local l = lairs[i]
			if l and l.state == "awake" and l.name and (KnownUnitRankByName[l.name] or 0) < 2 then
				KnownUnitRankByName[l.name] = 2
			end
		end
	end
	if type(_G.AZS_UNITS) == "table" then
		local bosses = _G.AZS_UNITS
		for i = 1, #bosses do
			local b = bosses[i]
			if b and b.name then KnownUnitRankByName[b.name] = 3 end
		end
	end
end

local function IsBlizzardNameplate(frame)
	if not frame or frame._azsMinUI_Own or frame._azsMinUI or frame:GetObjectType() ~= "Frame" then return false end
	local name = frame:GetName()
	if name and not find(lower(name), "nameplate", 1, true) then return false end
	local children = { frame:GetChildren() }
	local statusBars = 0
	for i = 1, #children do
		local c = children[i]
		if c and c.GetObjectType and c:GetObjectType() == "StatusBar" then statusBars = statusBars + 1 end
	end
	if statusBars >= 2 then return true end
	local regions = { frame:GetRegions() }
	local hasFont, texCount = false, 0
	for i = 1, #regions do
		local r = regions[i]
		if r and r.GetObjectType then
			local otype = r:GetObjectType()
			if otype == "Texture" then
				texCount = texCount + 1
				local tex = r:GetTexture()
				if type(tex) == "string" then
					local low = lower(tex)
					if find(low, "nameplate", 1, true) or find(low, "targetingframe-flash", 1, true) or find(low, "targetingframe-skull", 1, true) then
						return true
					end
				end
			elseif otype == "FontString" then
				hasFont = true
			end
		end
	end
	return (statusBars == 1 and hasFont and texCount >= 2)
end

local function NukeBlizzardVisuals(d)
	if d.isNuked then return end
	if d.origHpBar then
		d.origHpBar:SetAlpha(0)
		d.origHpBar:SetStatusBarTexture("")
		for i = 1, #d.hpRegs do d.hpRegs[i]:SetAlpha(0) end
	end
	if d.origCastBar then d.origCastBar:SetAlpha(0); d.origCastBar:Hide() end
	if d.origName then d.origName:SetAlpha(0); d.origName:SetHeight(0.001) end
	if d.origLevel then d.origLevel:SetAlpha(0); d.origLevel:SetHeight(0.001) end
	if d.bossIcon then d.bossIcon:SetAlpha(0); d.bossIcon:SetSize(0.001, 0.001) end
	if d.stateIcon then d.stateIcon:SetAlpha(0); d.stateIcon:SetSize(0.001, 0.001) end
	for i = 1, #d.nukedTextures do
		local tex = d.nukedTextures[i].tex
		tex:SetTexture(nil); tex:SetAlpha(0); tex:Hide()
	end
	d.isRestored, d.isNuked = false, true
end

local function RestoreBlizzardVisuals(d)
	if d.bar then d.bar:Hide() end
	if d.isRestored then return end
	if d.origHpBar then
		d.origHpBar:SetAlpha(1)
		d.origHpBar:SetStatusBarTexture(d.origHpTex or "Interface\\TargetingFrame\\UI-StatusBar")
		for i = 1, #d.hpRegs do d.hpRegs[i]:SetAlpha(1) end
	end
	if d.origCastBar then d.origCastBar:SetAlpha(1) end
	if d.origName then d.origName:SetAlpha(1); d.origName:SetHeight(d.origNameH or 14) end
	if d.origLevel then d.origLevel:SetAlpha(1); d.origLevel:SetHeight(d.origLevelH or 12) end
	if d.bossIcon then d.bossIcon:SetAlpha(1); d.bossIcon:SetSize(d.bossW or 16, d.bossH or 16) end
	if d.stateIcon then d.stateIcon:SetAlpha(1); d.stateIcon:SetSize(d.stateW or 16, d.stateH or 16) end
	for i = 1, #d.nukedTextures do
		local item = d.nukedTextures[i]
		if item.path then item.tex:SetTexture(item.path) end
		if item.w and item.h and item.w > 0.1 and item.h > 0.1 then item.tex:SetSize(item.w, item.h) end
		item.tex:SetAlpha(1); item.tex:Show()
	end
	d.isRestored, d.isNuked = true, false
end

local function SyncBarValues(d)
	if not (d and d.origHpBar and d.bar) then return end
	local minV, maxV = d.origHpBar:GetMinMaxValues()
	d.bar:SetMinMaxValues(minV or 0, maxV or 100)
	d.bar:SetValue(d.origHpBar:GetValue() or 0)
end

local function UpdateSkinnedPlate(plate)
	local d = SkinnedPlates[plate]
	if not d then return end
	local mode = NS.GetModuleMode("Nameplates")
	if mode == "original" then RestoreBlizzardVisuals(d); return
	elseif mode == "off" then NukeBlizzardVisuals(d); d.bar:Hide(); return end

	NukeBlizzardVisuals(d)
	if not plate:IsShown() then d.bar:Hide(); return end
	local DB = NS.DB
	local cfg = (DB and DB.plates) or NS.DEFAULTS.plates
	d.bar:Show()
	local sz = PLATE_SIZES[cfg.sizeMode or 2] or PLATE_SIZES[2]
	local rawName = (d.origName and d.origName:GetText()) or ""
	local tier = KnownUnitRankByName[rawName] or 0
	if tier == 0 then
		if d.bossIcon and d.bossIcon:IsShown() then tier = 3
		elseif d.stateIcon and d.stateIcon:IsShown() then
			tier = find(lower(tostring(d.stateIcon:GetTexture() or "")), "rare", 1, true) and 2 or 1
		end
	end

	local w, h, showName, fontDelta = sz.normW, sz.normH, cfg.showNormalNames, -2
	local barCol, nameCol = COLORS.mobRed, nil
	if tier >= 3 then
		w, h, showName, fontDelta = sz.bossW, sz.bossH, true, 0
		if cfg.colorRarityNames then barCol, nameCol = COLORS.bossOrange, COLORS.bossOrange end
	elseif tier == 2 then
		w, h, showName, fontDelta = sz.eliteW, sz.eliteH, true, -1
		if cfg.colorRarityNames then barCol, nameCol = COLORS.rarePurple, COLORS.rarePurple end
	elseif tier == 1 then
		w, h, showName, fontDelta = sz.eliteW, sz.eliteH, true, -1
		if cfg.colorRarityNames then barCol, nameCol = COLORS.eliteBlue, COLORS.eliteBlue end
	end

	if d.lastW ~= w or d.lastH ~= h then d.bar:SetSize(w, h); d.lastW, d.lastH = w, h end
	if d.lastBarCol ~= barCol then d.lastBarCol = barCol; d.bar:SetStatusBarColor(barCol[1], barCol[2], barCol[3], 0.96) end
	if showName and rawName ~= "" then
		local fontPath = NS.GetFontPath()
		local fontSize = max(8, ((DB and DB.fontSize) or 11) + fontDelta)
		if d.lastFontPath ~= fontPath or d.lastFontSize ~= fontSize then
			d.nameLabel:SetFont(fontPath, fontSize, "OUTLINE")
			d.lastFontPath, d.lastFontSize = fontPath, fontSize
		end
		if d.lastNameCol ~= nameCol then
			d.lastNameCol = nameCol
			if nameCol then d.nameLabel:SetTextColor(nameCol[1], nameCol[2], nameCol[3], 1)
			else d.nameLabel:SetTextColor(0.90, 0.90, 0.90, 1) end
		end
		SetText(d.nameLabel, rawName)
		d.nameLabel:Show()
	else
		d.nameLabel:Hide()
	end
end

local function SkinBlizzardNameplate(plate)
	if SkinnedPlates[plate] then return end
	local origHpBar, origCastBar
	local children = { plate:GetChildren() }
	for i = 1, #children do
		local c = children[i]
		if c and c.GetObjectType and c:GetObjectType() == "StatusBar" then
			if not origHpBar then origHpBar = c elseif not origCastBar then origCastBar = c end
		end
	end
	if not origHpBar then return end
	local origHpTexObj = origHpBar:GetStatusBarTexture()
	local origHpTex = (origHpTexObj and origHpTexObj:GetTexture()) or "Interface\\TargetingFrame\\UI-StatusBar"
	local hpRegs, rawHpRegs = {}, { origHpBar:GetRegions() }
	for i = 1, #rawHpRegs do
		if rawHpRegs[i] and rawHpRegs[i].SetAlpha then hpRegs[#hpRegs + 1] = rawHpRegs[i] end
	end
	local regions = { plate:GetRegions() }
	local origName, origLevel, bossIcon, stateIcon, origNameH, origLevelH, bossW, bossH, stateW, stateH
	local nukedTextures = {}
	for i = 1, #regions do
		local reg = regions[i]
		if reg and reg.GetObjectType then
			local otype = reg:GetObjectType()
			if otype == "Texture" then
				local rawTex = reg:GetTexture()
				local low = lower(tostring(rawTex or ""))
				local rw, rh = reg:GetSize()
				if find(low, "skull", 1, true) then
					bossIcon, bossW, bossH = reg, rw, rh
				elseif find(low, "elite", 1, true) or find(low, "rare", 1, true) or find(low, "dragon", 1, true) then
					stateIcon, stateW, stateH = reg, rw, rh
				elseif not find(low, "raidtargeting", 1, true) then
					nukedTextures[#nukedTextures + 1] = { tex = reg, path = rawTex, w = rw, h = rh }
				end
			elseif otype == "FontString" then
				if not origName then origName, origNameH = reg, reg:GetHeight()
				elseif not origLevel then origLevel, origLevelH = reg, reg:GetHeight() end
			end
		end
	end
	if origCastBar and origCastBar.HookScript then
		origCastBar:HookScript("OnShow", function(self)
			if NS.GetModuleMode("Nameplates") ~= "original" then self:SetAlpha(0); self:Hide() end
		end)
	end
	local bar = CreateFrame("StatusBar", nil, plate)
	bar._azsMinUI_Own = true
	bar:SetPoint("CENTER", plate, "CENTER", 0, -2)
	bar:SetSize(56, 5)
	bar:SetStatusBarTexture(NS.OwnMedia("bar_minimal"))
	bar:SetStatusBarColor(COLORS.mobRed[1], COLORS.mobRed[2], COLORS.mobRed[3], 0.96)
	local border = bar:CreateTexture(nil, "BACKGROUND")
	border:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
	border:SetTexture(NS.OwnMedia("blank"))
	border:SetVertexColor(0.02, 0.02, 0.04, 0.92)
	local bg = bar:CreateTexture(nil, "BORDER")
	bg:SetAllPoints(bar)
	bg:SetTexture(NS.OwnMedia("bar_minimal"))
	bg:SetVertexColor(0.08, 0.09, 0.12, 0.85)
	local nameLabel = bar:CreateFontString(nil, "OVERLAY")
	nameLabel:SetPoint("BOTTOM", bar, "TOP", 0, 3)
	nameLabel:SetJustifyH("CENTER")
	nameLabel:SetShadowColor(0, 0, 0, 0.95)
	nameLabel:SetShadowOffset(1, -1)
	nameLabel:SetFont(NS.GetFontPath(), 10, "OUTLINE")
	local data = {
		origHpBar = origHpBar, origHpTex = origHpTex, hpRegs = hpRegs, origCastBar = origCastBar,
		origName = origName, origNameH = origNameH, origLevel = origLevel, origLevelH = origLevelH,
		bossIcon = bossIcon, bossW = bossW, bossH = bossH, stateIcon = stateIcon, stateW = stateW, stateH = stateH,
		nukedTextures = nukedTextures, bar = bar, nameLabel = nameLabel, isRestored = false, isNuked = false,
	}
	SkinnedPlates[plate] = data
	if origHpBar.HookScript then
		origHpBar:HookScript("OnValueChanged", function() SyncBarValues(data) end)
		origHpBar:HookScript("OnMinMaxChanged", function() SyncBarValues(data) end)
	end
	if plate.HookScript then
		plate:HookScript("OnShow", function(self) data.isNuked = false; SyncBarValues(data); UpdateSkinnedPlate(self) end)
		plate:HookScript("OnHide", function() bar:Hide() end)
	end
	SyncBarValues(data)
	UpdateSkinnedPlate(plate)
end

local function ScanWorldChildren(i, n, ...)
	if i > n then return end
	local child = select(i, ...)
	if child and not SkinnedPlates[child] and not NonPlates[child] then
		if IsBlizzardNameplate(child) then SkinBlizzardNameplate(child) else NonPlates[child] = true end
	end
	return ScanWorldChildren(i + 1, n, ...)
end

local Mod = {}
function Mod.ScanAndUpdate()
	local mode = NS.GetModuleMode("Nameplates")
	if mode == "original" then
		if lastAppliedMode ~= "original" then
			lastAppliedMode = "original"
			for _, d in pairs(SkinnedPlates) do RestoreBlizzardVisuals(d) end
		end
		return
	elseif mode == "off" then
		if lastAppliedMode ~= "off" then
			lastAppliedMode = "off"
			for _, d in pairs(SkinnedPlates) do NukeBlizzardVisuals(d); if d.bar then d.bar:Hide() end end
		end
		return
	end
	lastAppliedMode = "minimal"
	local now = GetTime()
	local numChildren = WorldFrame:GetNumChildren()
	if numChildren ~= lastWorldChildrenCount or (now - lastFullScanTime) >= 0.35 then
		lastWorldChildrenCount, lastFullScanTime = numChildren, now
		if numChildren > 0 then ScanWorldChildren(1, numChildren, WorldFrame:GetChildren()) end
	end
	for plate in pairs(SkinnedPlates) do
		if plate:IsShown() then UpdateSkinnedPlate(plate) end
	end
end

function Mod.Update()
	if NS.GetModuleMode("Nameplates") == "minimal" then RefreshKnownUnitRanks() end
end

NS.Modules.Nameplates = Mod
