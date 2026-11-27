local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, tonumber, type, pcall, fmt, GetTime = math.floor, tonumber, type, pcall, string.format, GetTime
local COLORS, SetText = NS.COLORS, NS.SetText

local TEX_PLATE   = NS.Media("point_plate")
local TEX_DIAMOND = NS.Media("point_diamond")
local MAX_WORLD_PINS = 24
local WorldPinPool = {}
for i = 1, MAX_WORLD_PINS do
	local pin = CreateFrame("Frame", "AZS_MinUI_WorldPin" .. i, UIParent)
	pin._azsMinUI = true
	pin:SetSize(34, 34)
	pin:SetFrameStrata("LOW")
	pin.case = pin:CreateTexture(nil, "BACKGROUND")
	pin.case:SetSize(34, 34)
	pin.case:SetPoint("CENTER", pin, "CENTER", 0, 0)
	pin.case:SetTexture(TEX_DIAMOND)
	pin.case:SetVertexColor(COLORS.crystalCase[1], COLORS.crystalCase[2], COLORS.crystalCase[3], 1)
	pin.gem = pin:CreateTexture(nil, "ARTWORK")
	pin.gem:SetSize(10, 14)
	pin.gem:SetPoint("CENTER", pin.case, "CENTER", 0, 0)
	pin.gem:SetTexture(NS.Media("point_crystal"))
	pin.txt = NS.CreateFontText(pin, 0, "LEFT")
	pin.txt:SetPoint("LEFT", pin.case, "RIGHT", -2, 0)
	pin:Hide()
	WorldPinPool[i] = pin
end

local function GetPlayerAndCameraBasis(projectFn)
	local px, py, pz, pf
	if type(_G.AZS_UnitWorldPosition) == "function" then
		local ok, ux, uy, uz = pcall(_G.AZS_UnitWorldPosition, "player")
		if ok and ux and uy and uz then px, py, pz = ux, uy, uz end
	end
	if not px and type(_G.AZS_GetPlayerPosition) == "function" then
		local ok, pos = pcall(_G.AZS_GetPlayerPosition)
		if ok and type(pos) == "table" and pos.x and pos.y then px, py, pz, pf = pos.x, pos.y, pos.z or 0, pos.facing end
	end
	if not px and type(_G.AZS_RUN) == "table" and _G.AZS_RUN.px and _G.AZS_RUN.py then
		px, py, pz, pf = tonumber(_G.AZS_RUN.px), tonumber(_G.AZS_RUN.py), 0, tonumber(_G.AZS_RUN.pf) or 0
	end
	if not px then return nil end
	pz = tonumber(pz) or 0
	local vx_x, vx_y, vy_x, vy_y
	if type(projectFn) == "function" then
		local ok0, cx, cy = pcall(projectFn, px, py, pz)
		local ok1, x1, y1 = pcall(projectFn, px + 2.0, py, pz)
		local ok2, x2, y2 = pcall(projectFn, px, py + 2.0, pz)
		if ok0 and ok1 and ok2 and cx and cy and x1 and y1 and x2 and y2 then
			vx_x, vx_y, vy_x, vy_y = x1 - cx, y1 - cy, x2 - cx, y2 - cy
		end
	end
	return px, py, pz, pf or 0, vx_x, vx_y, vy_x, vy_y
end

local lastPinCount = 0
local Mod = { lastProjectedTime = 0 }

function Mod.UpdateWorldProjection()
	Mod.lastProjectedTime = GetTime()
	local projectFn = _G.AZS_ProjectWorldPoint or _G.AZS_WorldToScreen
	local pinIdx = 0
	if NS.DB and NS.DB.showWorldPins and type(projectFn) == "function" then
		local chests = _G.AZS_CHESTS
		if type(chests) == "table" then
			for i = 1, #chests do
				local c = chests[i]
				if c and c.x and c.y and c.z and pinIdx < MAX_WORLD_PINS then
					local sx, sy, depth, _, onScreen = projectFn(c.x, c.y, c.z + 1.4)
					if sx and sy and onScreen ~= false then
						pinIdx = pinIdx + 1
						local pin = WorldPinPool[pinIdx]
						pin:ClearAllPoints()
						pin:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx, sy)
						local distStr = depth and fmt(" %.0fm", depth) or ""
						if pin._caseTex ~= TEX_PLATE then pin._caseTex = TEX_PLATE; pin.case:SetTexture(TEX_PLATE) end
						local kind = tonumber(c.kind) or ((tonumber(c.boss) == 1) and 1 or 0)
						if kind == 1 then
							pin.gem:SetVertexColor(1.0, 0.45, 0.10, 1.0)
							SetText(pin.txt, "|cffff8800Boss Chest" .. distStr .. "|r")
						elseif kind == 2 then
							pin.gem:SetVertexColor(0.78, 0.30, 1.00, 1.0)
							SetText(pin.txt, "|cffcc66ffCursed Chest" .. distStr .. "|r")
						else
							pin.gem:SetVertexColor(1.0, 0.85, 0.20, 1.0)
							SetText(pin.txt, "|cffffea89Chest" .. distStr .. "|r")
						end
						pin:Show()
					end
				end
			end
		end
		local lairs = NS.GetLairs()
		if type(lairs) == "table" then
			for i = 1, #lairs do
				local l = lairs[i]
				if l and l.x and l.y and l.z and pinIdx < MAX_WORLD_PINS then
					local sx, sy, depth, _, onScreen = projectFn(l.x, l.y, l.z + 2.2)
					if sx and sy and onScreen ~= false then
						local pin = WorldPinPool[pinIdx + 1]
						local distStr = depth and fmt(" %.0fm", depth) or ""
						local valid = false
						if l.state == "awake" then
							local hpm = tonumber(l.hpm)
							local hpPct = (hpm and hpm > 0) and floor((tonumber(l.hp) or 0) / hpm * 100) or 100
							pin.gem:SetVertexColor(1.0, 0.20, 0.20, 1.0)
							SetText(pin.txt, "|cffff4444Lair " .. hpPct .. "%" .. distStr .. "|r")
							valid = true
						elseif l.state == "asleep" then
							pin.gem:SetVertexColor(0.68, 0.38, 1.0, 1.0)
							SetText(pin.txt, "|cffb880ffLair" .. distStr .. "|r")
							valid = true
						elseif l.state == "empty" and (tonumber(l.left) or 0) > 0 then
							pin.gem:SetVertexColor(0.5, 0.55, 0.6, 0.8)
							SetText(pin.txt, "|cff999999Lair " .. NS.FormatTime(l.left) .. "|r")
							valid = true
						end
						if valid then
							pinIdx = pinIdx + 1
							pin:ClearAllPoints()
							pin:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx, sy)
							if pin._caseTex ~= TEX_DIAMOND then pin._caseTex = TEX_DIAMOND; pin.case:SetTexture(TEX_DIAMOND) end
							pin:Show()
						end
					end
				end
			end
		end
	end
	for i = pinIdx + 1, lastPinCount do WorldPinPool[i]:Hide() end
	lastPinCount = pinIdx
	local px, py, pz, pf, vx_x, vx_y, vy_x, vy_y = GetPlayerAndCameraBasis(projectFn)
	if NS.Modules.Compass then NS.Modules.Compass.Update3D(projectFn, px, py, pz, pf, vx_x, vx_y, vy_x, vy_y) end
end

local prevOnWorldProjected = _G.AZS_OnWorldProjected
_G.AZS_OnWorldProjected = function(...)
	if type(prevOnWorldProjected) == "function" then pcall(prevOnWorldProjected, ...) end
	if NS.DB then Mod.UpdateWorldProjection() end
end

function Mod.ApplyTheme()
	for i = 1, MAX_WORLD_PINS do
		WorldPinPool[i].case:SetVertexColor(COLORS.crystalCase[1], COLORS.crystalCase[2], COLORS.crystalCase[3], 1)
	end
end

NS.Modules.WorldPins = Mod
