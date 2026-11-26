local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local cos, sin, floor, min, pi = math.cos, math.sin, math.floor, math.min, math.pi
local lower, find = string.lower, string.find
local tonumber, tostring, type, GetSpellInfo = tonumber, tostring, type, GetSpellInfo
local RANGE_COLORS, SPELL_BASE_RANGE_BY_KEY, AOE_NAME_PATTERNS = NS.RANGE_COLORS, NS.SPELL_BASE_RANGE_BY_KEY, NS.AOE_NAME_PATTERNS
local Wipe = NS.Wipe

local MAX_RANGE_RINGS, DOTS_PER_RING = 8, 36
local FALLBACK_COL = { 1, 1, 1 }
local TWO_PI = 2 * pi

local COS_TBL, SIN_TBL = {}, {}
for d = 1, DOTS_PER_RING do
	local theta = (d - 1) * (TWO_PI / DOTS_PER_RING)
	COS_TBL[d], SIN_TBL[d] = cos(theta), sin(theta)
end

local RangeRingLayer = CreateFrame("Frame", "AZS_MinUI_RangeRings", UIParent)
RangeRingLayer._azsMinUI = true
RangeRingLayer:SetAllPoints(UIParent)
RangeRingLayer:SetFrameStrata("BACKGROUND")

local RangeRingPools = {}
for s = 1, MAX_RANGE_RINGS do
	local ring = { dots = {}, lastAlpha = -1 }
	local col = RANGE_COLORS[s] or FALLBACK_COL
	for d = 1, DOTS_PER_RING do
		local dot = RangeRingLayer:CreateTexture(nil, "ARTWORK")
		dot:SetSize(4, 4)
		dot:SetTexture(NS.OwnMedia("pin_diamond"))
		dot:SetVertexColor(col[1], col[2], col[3], 0.45)
		dot:Hide()
		ring.dots[d] = dot
	end
	local edgeBadge = CreateFrame("Frame", nil, RangeRingLayer)
	edgeBadge:SetSize(20, 20)
	edgeBadge:SetFrameLevel(RangeRingLayer:GetFrameLevel() + 2)
	edgeBadge.halo = edgeBadge:CreateTexture(nil, "BACKGROUND")
	edgeBadge.halo:SetSize(28, 28)
	edgeBadge.halo:SetPoint("CENTER", edgeBadge, "CENTER", 0, 0)
	edgeBadge.halo:SetTexture(NS.OwnMedia("glow"))
	edgeBadge.halo:SetVertexColor(col[1], col[2], col[3], 0.85)
	edgeBadge.icon = edgeBadge:CreateTexture(nil, "ARTWORK")
	edgeBadge.icon:SetSize(18, 18)
	edgeBadge.icon:SetPoint("CENTER", edgeBadge, "CENTER", 0, 0)
	edgeBadge.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if edgeBadge.icon.SetMask then edgeBadge.icon:SetMask(NS.Media("actionbutton-mask-circular")) end
	edgeBadge.ringBorder = edgeBadge:CreateTexture(nil, "OVERLAY")
	edgeBadge.ringBorder:SetSize(38, 38)
	edgeBadge.ringBorder:SetPoint("CENTER", edgeBadge, "CENTER", 0, 0)
	edgeBadge.ringBorder:SetTexture(NS.Media("actionbutton-border"))
	edgeBadge.ringBorder:SetVertexColor(col[1], col[2], col[3], 0.95)
	edgeBadge:Hide()
	ring.badge = edgeBadge
	RangeRingPools[s] = ring
end

local SpellRangeCache = {}
local function ResolveSpellRangeYards(sp)
	local spellId = tonumber(sp.spell) or 0
	local key = type(sp.key) == "string" and lower(sp.key) or ""
	local cKey = spellId .. ":" .. key
	local info = SpellRangeCache[cKey]
	if not info then
		local name, _, icon, _, _, _, _, _, maxRange = GetSpellInfo(spellId)
		local baseRange, isAoe = nil, false
		local preset = SPELL_BASE_RANGE_BY_KEY[key]
		if preset then
			baseRange = preset < 0 and -preset or preset
			isAoe = preset > 0
		elseif maxRange and tonumber(maxRange) and tonumber(maxRange) > 0 then
			baseRange = tonumber(maxRange)
			isAoe = (baseRange <= 12)
		else
			local lowName = lower(tostring(name or ""))
			for i = 1, #AOE_NAME_PATTERNS do
				if find(lowName, AOE_NAME_PATTERNS[i][1], 1, true) then
					baseRange, isAoe = AOE_NAME_PATTERNS[i][2], true
					break
				end
			end
		end
		if not baseRange or baseRange <= 0 then baseRange, isAoe = 8, true end
		info = { baseRange = baseRange, isAoe = isAoe, icon = icon or NS.QUESTION_ICON }
		if name or preset then SpellRangeCache[cKey] = info end
	end
	local radius = info.baseRange
	if info.isAoe and NS.DB and NS.DB.ranges and NS.DB.ranges.scaleWithArea then
		local areaMult = (_G.AZS_STATS and tonumber(_G.AZS_STATS.area)) or 1.0
		if areaMult > 0.1 then radius = radius * areaMult end
	end
	return radius, info.icon
end

local DrawnRadii, ringsVisible = {}, false
local function HideRing(ring)
	if ring.dotsShown then
		for d = 1, DOTS_PER_RING do ring.dots[d]:Hide() end
		ring.dotsShown = false
	end
	if ring.badge:IsShown() then ring.badge:Hide() end
end

local Mod = { frame = RangeRingLayer }

function Mod.Update3D(projectFn, px, py, pz)
	local cfg, spells, zone = NS.DB and NS.DB.ranges, _G.AZS_SPELLS, _G.AZS_ZONE
	if not cfg or not cfg.enabled or not px or type(projectFn) ~= "function"
	or type(spells) ~= "table" or #spells == 0 or (zone and tonumber(zone.hub) == 1) then
		if ringsVisible then
			for s = 1, MAX_RANGE_RINGS do HideRing(RangeRingPools[s]) end
			ringsVisible = false
		end
		return
	end
	ringsVisible = true
	Wipe(DrawnRadii)
	local activeCount = min(MAX_RANGE_RINGS, #spells)
	local ringAlpha = cfg.alpha or 0.42
	local maxYards = cfg.maxDrawYards or 42
	local zGround = (pz or 0) + 0.15

	for s = 1, MAX_RANGE_RINGS do
		local ring = RangeRingPools[s]
		local sp = (s <= activeCount) and spells[s] or nil
		if sp then
			local radius, icon = ResolveSpellRangeYards(sp)
			if radius > maxYards then radius = maxYards end
			local col = RANGE_COLORS[s] or FALLBACK_COL
			local bucket = floor(radius * 2 + 0.5)
			if not DrawnRadii[bucket] then
				DrawnRadii[bucket] = true
				local updateAlpha = (ring.lastAlpha ~= ringAlpha)
				ring.lastAlpha = ringAlpha
				local dots = ring.dots
				for d = 1, DOTS_PER_RING do
					local dot = dots[d]
					local sx, sy, _, _, onScreen = projectFn(px + COS_TBL[d] * radius, py + SIN_TBL[d] * radius, zGround)
					if sx and sy and onScreen ~= false then
						dot:ClearAllPoints()
						dot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx, sy)
						if updateAlpha then dot:SetVertexColor(col[1], col[2], col[3], ringAlpha) end
						dot:Show()
					else
						dot:Hide()
					end
				end
				ring.dotsShown = true
			elseif ring.dotsShown then
				for d = 1, DOTS_PER_RING do ring.dots[d]:Hide() end
				ring.dotsShown = false
			end
			if cfg.showEdgeIcon then
				local ang = ((s - 1) / activeCount) * TWO_PI + 0.45
				local sx, sy, _, _, onScreen = projectFn(px + cos(ang) * radius, py + sin(ang) * radius, zGround + 0.25)
				if not (sx and sy and onScreen ~= false) then
					ang = ang + pi
					sx, sy, _, _, onScreen = projectFn(px + cos(ang) * radius, py + sin(ang) * radius, zGround + 0.25)
				end
				if sx and sy and onScreen ~= false then
					ring.badge:ClearAllPoints()
					ring.badge:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx, sy)
					if ring._icon ~= icon then ring._icon = icon; ring.badge.icon:SetTexture(icon) end
					ring.badge:SetAlpha(((tonumber(sp.cd) or 0) > 0.1) and 0.55 or 0.95)
					ring.badge:Show()
				else
					ring.badge:Hide()
				end
			else
				ring.badge:Hide()
			end
		else
			HideRing(ring)
		end
	end
end

NS.Modules.RangeRings = Mod
