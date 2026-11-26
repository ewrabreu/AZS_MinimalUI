local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local sqrt, atan2, cos, sin, floor, pi = math.sqrt, math.atan2, math.cos, math.sin, math.floor, math.pi
local lower, find, fmt = string.lower, string.find, string.format
local type, tonumber, pcall, GetTime = type, tonumber, pcall, GetTime
local COLORS, SetText, RGBToHex = NS.COLORS, NS.SetText, NS.RGBToHex

local TEX_PLATE   = NS.Media("point_plate")
local TEX_DIAMOND = NS.Media("point_diamond")
local TEX_CRYSTAL = NS.Media("point_crystal")
local TEX_HEART   = NS.Media("icon-heart-red")
local TEX_HEARTH  = NS.Media("point_hearth")
local TEX_BOSS    = NS.Media("icon_badges_boss")
local PING_FILTER = { kinds = { "ping" } }

local CompassFrame = CreateFrame("Frame", "AZS_MinUI_Compass", UIParent)
NS.RegisterMovableBox("Compass", "360 Compass", CompassFrame)

local MAX_COMPASS_MARKS = 28
local CompassPool = {}
for i = 1, MAX_COMPASS_MARKS do
	local m = CreateFrame("Frame", nil, CompassFrame)
	m:SetSize(24, 24)
	m:SetFrameStrata("LOW")
	m.arrow = m:CreateTexture(nil, "BACKGROUND")
	m.arrow:SetSize(12, 12)
	m.arrow:SetTexture(NS.OwnMedia("pin_diamond"))
	m.bg = m:CreateTexture(nil, "BORDER")
	m.bg:SetSize(26, 26)
	m.bg:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.bg:SetTexture(TEX_DIAMOND)
	m.bg:SetVertexColor(COLORS.crystalCase[1], COLORS.crystalCase[2], COLORS.crystalCase[3], 0.95)
	m.icon = m:CreateTexture(nil, "ARTWORK")
	m.icon:SetSize(14, 14)
	m.icon:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.icon:SetTexture(TEX_CRYSTAL)
	m.dist = NS.CreateFontText(m, -3, "CENTER")
	m.dist:SetPoint("TOP", m, "BOTTOM", 0, -1)
	m:Hide()
	CompassPool[i] = m
end

local SpecialUnitCache = {}
local function ClassifySpecialWorldUnit(name)
	if type(name) ~= "string" or name == "" then return nil end
	local cached = SpecialUnitCache[name]
	if cached ~= nil then return cached or nil end
	local low = lower(name)
	local res = false
	if find(low, "portal", 1, true) or find(low, "fenda", 1, true) or find(low, "rift", 1, true) or find(low, "gate", 1, true) then
		res = "portal"
	elseif find(low, "totem", 1, true) or find(low, "shrine", 1, true) or find(low, "santu", 1, true)
		or find(low, "altar", 1, true) or find(low, "obelisk", 1, true) or find(low, "pylon", 1, true) then
		res = "totem"
	end
	SpecialUnitCache[name] = res
	return res or nil
end

local CompassTargets = {}
local lastVisibleCount = 0
local cPx, cPy, cPz, cSw, cSh, cProj, cOnlyOff, cCount

local function PushTarget(x, y, z, kind, label, r, g, b, bgTex, iconTex, pulse)
	if cCount >= MAX_COMPASS_MARKS or not x or not y then return end
	local dx, dy = x - cPx, y - cPy
	local d2 = dx * dx + dy * dy
	if d2 < 16 then return end
	if cOnlyOff and cProj and kind ~= "downed" then
		local ok, sx, sy, _, _, onScreen = pcall(cProj, x, y, z or cPz)
		if ok and sx and sy and onScreen ~= false and sx > 60 and sx < (cSw - 60) and sy > 70 and sy < (cSh - 70) then return end
	end
	cCount = cCount + 1
	local t = CompassTargets[cCount]
	if not t then t = {}; CompassTargets[cCount] = t end
	t.dx, t.dy, t.dist = dx, dy, sqrt(d2)
	t.label, t.r, t.g, t.b = label, r, g, b
	t.bgTex, t.iconTex, t.pulse = bgTex, iconTex, pulse
end

local Mod = { frame = CompassFrame }

function Mod.Update3D(projectFn, px, py, pz, pf, vx_x, vx_y, vy_x, vy_y)
	local cfg = NS.DB and NS.DB.compass
	if not cfg or not cfg.enabled or NS.IsBoxHidden("Compass") or not px then
		if lastVisibleCount > 0 then
			for i = 1, lastVisibleCount do CompassPool[i]:Hide() end
			lastVisibleCount = 0
		end
		return
	end
	cPx, cPy, cPz = px, py, pz
	cSw, cSh = UIParent:GetWidth(), UIParent:GetHeight()
	cProj = (type(projectFn) == "function") and projectFn or nil
	cOnlyOff = cfg.onlyOffscreen
	cCount = 0

	if cfg.showDowned and type(_G.AZS_GetDownedPartyMembers) == "function" then
		local ok, downed = pcall(_G.AZS_GetDownedPartyMembers)
		if ok and type(downed) == "table" then
			for i = 1, #downed do
				local d = downed[i]
				if d and d.positionAvailable and d.x and d.y then
					local pct = floor((tonumber(d.reviveShare) or 0) * 100)
					PushTarget(d.x, d.y, d.z or pz, "downed", (pct > 0) and (pct .. "%") or "REV", 1.0, 0.22, 0.28, TEX_PLATE, TEX_HEART, true)
				end
			end
		end
	end
	if cfg.showChests and type(_G.AZS_CHESTS) == "table" then
		local chests = _G.AZS_CHESTS
		for i = 1, #chests do
			local c = chests[i]
			if c and c.x and c.y then
				local isBoss = c.boss and tonumber(c.boss) == 1
				PushTarget(c.x, c.y, c.z or pz, "chest", nil, 1.0, isBoss and 0.50 or 0.88, isBoss and 0.12 or 0.22, TEX_PLATE, TEX_CRYSTAL, false)
			end
		end
	end
	if cfg.showLairs then
		local lairs = NS.GetLairs()
		if type(lairs) == "table" then
			for i = 1, #lairs do
				local l = lairs[i]
				if l and l.x and l.y then
					if l.state == "awake" then
						PushTarget(l.x, l.y, l.z or pz, "lair", nil, 1.0, 0.24, 0.24, TEX_DIAMOND, TEX_CRYSTAL, true)
					elseif l.state == "asleep" then
						PushTarget(l.x, l.y, l.z or pz, "lair", nil, 0.72, 0.38, 1.0, TEX_DIAMOND, TEX_CRYSTAL, false)
					end
				end
			end
		end
	end
	if (cfg.showBosses or cfg.showPortalsTotems) and type(_G.AZS_WorldUnits) == "function" then
		local ok, units = pcall(_G.AZS_WorldUnits, cfg.showPortalsTotems and 0 or 3)
		if ok and type(units) == "table" then
			for i = 1, #units do
				local u = units[i]
				if u and u.alive and not u.player and u.x and u.y then
					if cfg.showBosses and (tonumber(u.rank) or 0) >= 3 then
						PushTarget(u.x, u.y, u.z or pz, "boss", nil, COLORS.bossOrange[1], COLORS.bossOrange[2], COLORS.bossOrange[3], TEX_PLATE, TEX_BOSS, false)
					elseif cfg.showPortalsTotems and u.name then
						local spKind = ClassifySpecialWorldUnit(u.name)
						if spKind == "portal" then
							PushTarget(u.x, u.y, u.z or pz, "portal", "P", 0.25, 0.85, 1.0, TEX_PLATE, TEX_HEARTH, true)
						elseif spKind == "totem" then
							PushTarget(u.x, u.y, u.z or pz, "totem", "T", 0.25, 1.0, 0.65, TEX_DIAMOND, TEX_CRYSTAL, false)
						end
					end
				end
			end
		end
	end
	if cfg.showPortalsTotems and type(_G.AZS_GetWorldAnchors) == "function" then
		local ok, res = pcall(_G.AZS_GetWorldAnchors, PING_FILTER, nil, 8)
		if ok and type(res) == "table" and type(res.entries) == "table" then
			for i = 1, #res.entries do
				local e = res.entries[i]
				if e and e.x and e.y then
					PushTarget(e.x, e.y, e.z or pz, "ping", "!", 0.35, 0.95, 1.0, TEX_DIAMOND, TEX_HEARTH, true)
				end
			end
		end
	end

	local radius = cfg.radius or 152
	local pulseAlpha = 0.72 + 0.28 * sin(GetTime() * 6.5)
	local halfPi = pi * 0.5
	local pfBase = (pf or 0) - halfPi
	for i = 1, cCount do
		local t, m = CompassTargets[i], CompassPool[i]
		local ang
		if vx_x then
			local sx, sy = t.dx * vx_x + t.dy * vy_x, t.dx * vx_y + t.dy * vy_y
			ang = (sx ~= 0 or sy ~= 0) and atan2(sy, sx) or (atan2(t.dy, t.dx) - pfBase)
		else
			ang = atan2(t.dy, t.dx) - pfBase
		end
		local ca, sa = cos(ang), sin(ang)
		m:ClearAllPoints()
		m:SetPoint("CENTER", CompassFrame, "CENTER", ca * radius, sa * radius)
		m.arrow:ClearAllPoints()
		m.arrow:SetPoint("CENTER", m, "CENTER", ca * 14, sa * 14)
		m.arrow:SetVertexColor(t.r, t.g, t.b, 0.95)
		if m.arrow.SetRotation then m.arrow:SetRotation(ang) end
		if m._bgTex ~= t.bgTex then m._bgTex = t.bgTex; m.bg:SetTexture(t.bgTex) end
		if m._iconTex ~= t.iconTex then m._iconTex = t.iconTex; m.icon:SetTexture(t.iconTex) end
		m.icon:SetVertexColor(t.r, t.g, t.b, 1.0)
		local hex = RGBToHex(t.r, t.g, t.b)
		SetText(m.dist, t.label and fmt("%s%s %.0fm|r", hex, t.label, t.dist) or fmt("%s%.0fm|r", hex, t.dist))
		m:SetAlpha(t.pulse and pulseAlpha or 0.92)
		m:Show()
	end
	for i = cCount + 1, lastVisibleCount do CompassPool[i]:Hide() end
	lastVisibleCount = cCount
end

NS.Modules.Compass = Mod
