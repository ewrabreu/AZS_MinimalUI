local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, pcall, type, tostring = math.floor, pcall, type, tostring
local COLORS, SetText = NS.COLORS, NS.SetText

local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local ROUND_MASK  = "Textures\\MinimapMask"

local BLIZZ_CLUTTER = {
	"MinimapBackdrop", "MinimapBorder", "MinimapBorderTop",
	"MinimapZoomIn", "MinimapZoomOut", "MinimapNorthTag",
	"MiniMapWorldMapButton", "MinimapZoneTextButton", "MinimapToggleButton",
	"MiniMapTracking", "GameTimeFrame", "TimeManagerClockButton",
	"MinimapCompassTexture", "MiniMapMailFrame", "MiniMapBattlefieldFrame",
	"MiniMapLFGFrame", "MiniMapInstanceDifficulty",
}

local MapBox = CreateFrame("Frame", "AZS_MinUI_Minimap", UIParent)
NS.RegisterMovableBox("Minimap", "Minimap", MapBox)
MapBox:EnableMouse(false)

local ZoneBar = CreateFrame("Frame", nil, MapBox)
ZoneBar:SetHeight(16)
ZoneBar:SetPoint("TOPLEFT", MapBox, "TOPLEFT", 2, -2)
ZoneBar:SetPoint("TOPRIGHT", MapBox, "TOPRIGHT", -2, -2)
ZoneBar:EnableMouse(false)
ZoneBar.txt = NS.CreateFontText(ZoneBar, -2, "CENTER")
ZoneBar.txt:SetPoint("LEFT", ZoneBar, "LEFT", 4, 0)
ZoneBar.txt:SetPoint("RIGHT", ZoneBar, "RIGHT", -4, 0)
NS.SetNoWrap(ZoneBar.txt, 14)

local origState, wheelHooked, appliedMode
local lastInnerW, lastInnerH = 0, 0

local function CaptureOriginalMinimap()
	local mm = _G.Minimap
	if origState or not mm then return end
	local p, rel, rp, x, y = mm:GetPoint(1)
	origState = {
		parent = mm:GetParent() or _G.MinimapCluster or UIParent,
		point = p or "CENTER",
		rel = rel or _G.MinimapCluster or UIParent,
		relPoint = rp or "CENTER",
		x = x or 0,
		y = y or 0,
		w = mm:GetWidth() or 140,
		h = mm:GetHeight() or 140,
		scale = mm:GetScale() or 1,
	}
end

local function SetClutterVisible(show)
	for i = 1, #BLIZZ_CLUTTER do
		local f = _G[BLIZZ_CLUTTER[i]]
		if f then
			if show then
				if f._azsMinUIHid then
					f._azsMinUIHid = nil
					if f.Show then pcall(f.Show, f) end
				end
			else
				if f.IsShown and f:IsShown() then f._azsMinUIHid = true end
				if f.Hide then pcall(f.Hide, f) end
			end
		end
	end
end

local function OnMinimapWheel(self, delta)
	if NS.GetModuleMode("Minimap") ~= "minimal" then return end
	local zoom = self:GetZoom() or 0
	local maxZ = (self.GetZoomLevels and (self:GetZoomLevels() - 1)) or 5
	if delta > 0 and zoom < maxZ then
		self:SetZoom(zoom + 1)
	elseif delta < 0 and zoom > 0 then
		self:SetZoom(zoom - 1)
	end
end

local function SyncMinimapSize()
	local mm = _G.Minimap
	if not mm then return end
	local w = floor((MapBox:GetWidth() or 176) + 0.5)
	local h = floor((MapBox:GetHeight() or 176) + 0.5)
	if w < 48 then w = 48 end
	if h < 48 then h = 48 end
	if w ~= lastInnerW or h ~= lastInnerH then
		lastInnerW, lastInnerH = w, h
		mm:SetSize(w, h)
	end
	ZoneBar:SetFrameLevel(mm:GetFrameLevel() + 8)
end

local function ApplyMinimalMinimap()
	local mm = _G.Minimap
	if not mm then return end
	CaptureOriginalMinimap()
	if _G.MinimapCluster then _G.MinimapCluster:Hide() end
	SetClutterVisible(false)
	mm:SetParent(MapBox)
	mm:ClearAllPoints()
	mm:SetPoint("CENTER", MapBox, "CENTER", 0, 0)
	mm:SetScale(1)
	mm:SetAlpha(1)
	if mm.SetMaskTexture then pcall(mm.SetMaskTexture, mm, SQUARE_MASK) end
	if mm.SetBlipTexture then pcall(mm.SetBlipTexture, mm, "Interface\\Minimap\\ObjectIcons") end
	mm:EnableMouseWheel(true)
	if not wheelHooked then
		wheelHooked = true
		mm:HookScript("OnMouseWheel", OnMinimapWheel)
	end
	lastInnerW, lastInnerH = 0, 0
	SyncMinimapSize()
	mm:Show()
	MapBox:Show()
end

local function RestoreOriginalMinimap()
	local mm = _G.Minimap
	MapBox:Hide()
	if mm and origState then
		mm:SetParent(origState.parent)
		mm:ClearAllPoints()
		mm:SetPoint(origState.point, origState.rel, origState.relPoint, origState.x, origState.y)
		mm:SetSize(origState.w, origState.h)
		mm:SetScale(origState.scale)
		if mm.SetMaskTexture then pcall(mm.SetMaskTexture, mm, ROUND_MASK) end
		mm:Show()
	end
	SetClutterVisible(true)
	if _G.MinimapCluster then _G.MinimapCluster:Show() end
end

local function HideAllMinimap()
	local mm = _G.Minimap
	MapBox:Hide()
	if mm then mm:Hide() end
	if _G.MinimapCluster then _G.MinimapCluster:Hide() end
end

local Mod = { frame = MapBox }

function Mod.ApplyMode()
	local mode = NS.GetModuleMode("Minimap")
	local hidden = (mode == "minimal" and NS.IsBoxHidden("Minimap") and NS.DB and NS.DB.locked)
	if mode == "minimal" and not hidden then
		appliedMode = "minimal"
		ApplyMinimalMinimap()
	elseif mode == "original" then
		appliedMode = "original"
		RestoreOriginalMinimap()
	else
		appliedMode = "off"
		HideAllMinimap()
	end
end

function Mod.Update(ctx)
	local mode = NS.GetModuleMode("Minimap")
	local wantMinimal = (mode == "minimal") and ((not NS.IsBoxHidden("Minimap")) or ctx.isEditing)
	if wantMinimal then
		local mm = _G.Minimap
		if appliedMode ~= "minimal" or (mm and mm:GetParent() ~= MapBox) then
			appliedMode = "minimal"
			ApplyMinimalMinimap()
		else
			if not MapBox:IsShown() then MapBox:Show() end
			if mm and not mm:IsShown() then mm:Show() end
			if _G.MinimapCluster and _G.MinimapCluster:IsShown() then _G.MinimapCluster:Hide() end
			SyncMinimapSize()
		end
		local cfg = (NS.DB and NS.DB.minimap) or NS.DEFAULTS.minimap
		if cfg and cfg.showZoneName ~= false then
			local zone = ctx.zone
			local zName = (zone and (zone.zname or zone.zone))
				or (type(_G.GetMinimapZoneText) == "function" and _G.GetMinimapZoneText())
				or (type(_G.GetZoneText) == "function" and _G.GetZoneText())
				or ""
			if zName ~= "" then
				SetText(ZoneBar.txt, "|cffe6eef8" .. tostring(zName) .. "|r")
				if not ZoneBar:IsShown() then ZoneBar:Show() end
			elseif ZoneBar:IsShown() then
				ZoneBar:Hide()
			end
		elseif ZoneBar:IsShown() then
			ZoneBar:Hide()
		end
	elseif mode == "original" then
		if appliedMode ~= "original" then
			appliedMode = "original"
			RestoreOriginalMinimap()
		end
	else
		if appliedMode ~= "off" then
			appliedMode = "off"
			HideAllMinimap()
		end
	end
end

NS.Modules.Minimap = Mod
