local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, max, min, fmt, upper = math.floor, math.max, math.min, string.format, string.upper
local pairs, type = pairs, type
local Clamp, ApplyFlat = NS.Clamp, NS.ApplyFlatBackdrop
local FONTS, BOX_ORDER = NS.FONTS, NS.BOX_ORDER

local THEME = {
	winBg      = { 0.04, 0.05, 0.08, 0.97 },    winBorder  = { 0.20, 0.25, 0.34, 0.95 },
	sideBg     = { 0.025, 0.032, 0.052, 0.98 }, bodyBg     = { 0.055, 0.068, 0.100, 0.95 },
	cardBg     = { 0.075, 0.090, 0.130, 0.92 }, cardBorder = { 0.18, 0.22, 0.30, 0.85 },
	divider    = { 0.16, 0.20, 0.28, 0.80 },
	teal = { 0.00, 0.92, 0.78 }, gold = { 1.00, 0.82, 0.26 }, crimson = { 0.95, 0.30, 0.34 },
}
local BTN_STYLES = {
	teal = { bg = { 0.04, 0.19, 0.18, 0.94 }, bd = { 0.00, 0.80, 0.68, 0.85 } },
	gold = { bg = { 0.20, 0.15, 0.04, 0.92 }, bd = { 0.82, 0.64, 0.22, 0.85 } },
	red  = { bg = { 0.22, 0.06, 0.08, 0.92 }, bd = { 0.88, 0.28, 0.32, 0.85 } },
	cyan = { bg = { 0.04, 0.18, 0.22, 0.94 }, bd = { 0.16, 0.82, 0.92, 0.88 } },
}
local MODE_META = {
	minimal  = { label = "Minimal",  bg = { 0.05, 0.26, 0.23, 0.98 }, br = { 0.00, 0.92, 0.78, 1.0 }, txt = { 0.85, 1.00, 0.96 }, barCol = THEME.teal },
	original = { label = "Original", bg = { 0.28, 0.20, 0.04, 0.98 }, br = { 1.00, 0.80, 0.24, 1.0 }, txt = { 1.00, 0.93, 0.62 }, barCol = THEME.gold },
	off      = { label = "Both OFF", bg = { 0.26, 0.07, 0.09, 0.98 }, br = { 0.95, 0.30, 0.34, 1.0 }, txt = { 1.00, 0.68, 0.70 }, barCol = THEME.crimson },
}

local EditorUI = { selectedBoxIdx = 0, activePage = 1, built = false, refreshables = {}, navButtons = {}, pageWrappers = {} }

local AlignGrid = CreateFrame("Frame", "AZS_MinUI_AlignGrid", UIParent)
AlignGrid._azsMinUI = true
AlignGrid:SetAllPoints(UIParent)
AlignGrid:SetFrameStrata("BACKGROUND")
AlignGrid:EnableMouse(false)
AlignGrid:Hide()

local function BuildAlignGrid()
	if AlignGrid.built then return end
	AlignGrid.built = true
	local sw, sh = max(1024, floor(UIParent:GetWidth() or 1280)), max(768, floor(UIParent:GetHeight() or 720))
	local blank = NS.OwnMedia("blank")
	for offset = 64, floor(sw / 2), 64 do
		for sign = -1, 1, 2 do
			local line = AlignGrid:CreateTexture(nil, "BACKGROUND")
			line:SetTexture(blank); line:SetVertexColor(0.25, 0.88, 0.78, 0.11); line:SetWidth(1)
			line:SetPoint("TOP", AlignGrid, "TOP", sign * offset, 0)
			line:SetPoint("BOTTOM", AlignGrid, "BOTTOM", sign * offset, 0)
		end
	end
	for offset = 64, floor(sh / 2), 64 do
		for sign = -1, 1, 2 do
			local line = AlignGrid:CreateTexture(nil, "BACKGROUND")
			line:SetTexture(blank); line:SetVertexColor(0.25, 0.88, 0.78, 0.11); line:SetHeight(1)
			line:SetPoint("LEFT", AlignGrid, "LEFT", 0, sign * offset)
			line:SetPoint("RIGHT", AlignGrid, "RIGHT", 0, sign * offset)
		end
	end
	local cx = AlignGrid:CreateTexture(nil, "ARTWORK")
	cx:SetTexture(blank); cx:SetVertexColor(1.0, 0.82, 0.25, 0.34); cx:SetWidth(2)
	cx:SetPoint("TOP", AlignGrid, "TOP", 0, 0); cx:SetPoint("BOTTOM", AlignGrid, "BOTTOM", 0, 0)
	local cy = AlignGrid:CreateTexture(nil, "ARTWORK")
	cy:SetTexture(blank); cy:SetVertexColor(1.0, 0.82, 0.25, 0.34); cy:SetHeight(2)
	cy:SetPoint("LEFT", AlignGrid, "LEFT", 0, 0); cy:SetPoint("RIGHT", AlignGrid, "RIGHT", 0, 0)
end

local function UpdateAlignGridVisibility()
	if NS.DB and (not NS.DB.locked) and NS.DB.showGrid then BuildAlignGrid(); AlignGrid:Show() else AlignGrid:Hide() end
end

local function RefreshAllOverlays()
	local DB = NS.DB
	if not DB then return end
	local selKey = (EditorUI.selectedBoxIdx > 0 and BOX_ORDER[EditorUI.selectedBoxIdx]) and BOX_ORDER[EditorUI.selectedBoxIdx].key or nil
	for key, ov in pairs(NS.DragOverlays) do
		local cfg = DB.boxes and DB.boxes[key]
		local isSel, isHid = (selKey == key), NS.IsBoxHidden(key)
		if isHid then
			ov:SetBackdropColor(0.36, 0.08, 0.10, 0.50); ov:SetBackdropBorderColor(1.0, 0.32, 0.35, 0.95); ov.eyeBtn.txt:SetText("|cffff5555X|r")
		elseif isSel then
			ov:SetBackdropColor(0.34, 0.24, 0.05, 0.54); ov:SetBackdropBorderColor(1.0, 0.84, 0.28, 1.0); ov.eyeBtn.txt:SetText("|cff44ff88V|r")
		else
			ov:SetBackdropColor(0.0, 0.32, 0.30, 0.44); ov:SetBackdropBorderColor(0.0, 0.92, 0.78, 0.90); ov.eyeBtn.txt:SetText("|cff44ff88V|r")
		end
		local meta = (key == "Compass" and DB.compass) and fmt("Radius %dpx", DB.compass.radius or 152)
			or (cfg and fmt("%.0f%%  (%d, %d)", (cfg.scale or 1.0) * 100, cfg.x or 0, cfg.y or 0)) or ""
		local modKey = NS.BOX_TO_MODULE and NS.BOX_TO_MODULE[key]
		local modeTag = ""
		if modKey then
			local m = NS.GetModuleMode(modKey)
			if m == "original" then modeTag = " |cffffcc44[ORIGINAL]|r" elseif m == "off" or isHid then modeTag = " |cffff6666[OFF]|r" end
		elseif isHid then
			modeTag = " |cffff6666[HIDDEN]|r"
		end
		local titleCol = isSel and "|cffffea89" or "|cff00ffcc"
		if cfg and (cfg.height or 40) < 50 then
			ov.lbl:SetText(fmt("%s%s|r%s  |cffdddddd%s|r", titleCol, ov.boxTitle, modeTag, meta))
		else
			ov.lbl:SetText(fmt("%s%s|r%s\n|cffdddddd%s|r\n|cffaaaaaaCorner ↘ or Scroll to scale|r", titleCol, ov.boxTitle, modeTag, meta))
		end
	end
end

local function RefreshEditorControls()
	if not (NS.DB and EditorUI.built) then return end
	local list = EditorUI.refreshables
	for i = 1, #list do list[i]() end
end

function NS.SetUnlockState(unlocked)
	if not NS.DB then NS.InitializeDB() end
	NS.DB.locked = not unlocked
	for key, ov in pairs(NS.DragOverlays) do
		if unlocked then NS.MovableFrames[key]:Show(); ov:Show()
		else ov:Hide(); NS.RestoreBoxLayout(key, NS.MovableFrames[key]) end
	end
	UpdateAlignGridVisibility()
	RefreshAllOverlays()
	if NS.UpdateMinimalHUD then NS.UpdateMinimalHUD() end
	RefreshEditorControls()
end

local function OnBtnEnter(self)
	if self._hoverBorder then self:SetBackdropBorderColor(self._hoverBorder[1], self._hoverBorder[2], self._hoverBorder[3], 1.0)
	elseif not self._isActive then self:SetBackdropBorderColor(0.40, 0.48, 0.62, 0.95) end
end
local function OnBtnLeave(self)
	local rb = self._restBorder
	if rb then self:SetBackdropBorderColor(rb[1], rb[2], rb[3], rb[4] or 0.85) end
end
local function AttachHoverTint(btn) btn:SetScript("OnEnter", OnBtnEnter); btn:SetScript("OnLeave", OnBtnLeave) end
local function SetFlatBorder(f, r, g, b, a)
	a = a or 0.85
	local rb = f._restBorder
	if rb then rb[1], rb[2], rb[3], rb[4] = r, g, b, a else f._restBorder = { r, g, b, a } end
	f:SetBackdropBorderColor(r, g, b, a)
end
local function ApplyCardPanel(f, bg, bd)
	ApplyFlat(f, bg or THEME.cardBg, bd or THEME.cardBorder)
end

local EditorFrame = CreateFrame("Frame", "AZS_MinUI_Editor", UIParent)
EditorFrame._azsMinUI = true
EditorFrame:SetSize(724, 512)
EditorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 18)
EditorFrame:SetFrameStrata("DIALOG")
EditorFrame:SetMovable(true)
EditorFrame:SetClampedToScreen(true)
EditorFrame:EnableMouse(true)
EditorFrame:RegisterForDrag("LeftButton")
EditorFrame:SetScript("OnDragStart", EditorFrame.StartMoving)
EditorFrame:SetScript("OnDragStop", EditorFrame.StopMovingOrSizing)
ApplyCardPanel(EditorFrame, THEME.winBg, THEME.winBorder)
EditorFrame:Hide()

if type(_G.UISpecialFrames) == "table" then
	local found = false
	for i = 1, #_G.UISpecialFrames do if _G.UISpecialFrames[i] == "AZS_MinUI_Editor" then found = true; break end end
	if not found then _G.UISpecialFrames[#_G.UISpecialFrames + 1] = "AZS_MinUI_Editor" end
end

local function ResetEntireUI()
	NS.ResetAllToDefaults()
	if NS.Modules.PlayerHUD then NS.Modules.PlayerHUD.ResetCache() end
	EditorUI.selectedBoxIdx = 0
	NS.SetUnlockState(false)
	NS.RefreshAllLayouts()
	NS.SuppressNativeAndBlizzardUI()
end

local SelectEditorPage, EnsureEditorBuilt

local NAV_PAGES = {
	{ id = 1, section = "MANAGEMENT", label = "Modules", title = "Module Manager",
	  subtitle = "Enable Minimal, restore the Original game UI, or turn both off independently.", icon = NS.OwnMedia("pin_diamond"),
	  badgeFn = function()
		local active = 0
		for i = 1, #NS.MODULE_DEFS do if NS.GetModuleMode(NS.MODULE_DEFS[i].key) ~= "off" then active = active + 1 end end
		return fmt("|cff00ffcc%d|r|cff667080/%d|r", active, #NS.MODULE_DEFS)
	  end },
	{ id = 2, label = "Layout & Boxes", title = "Layout, Scale & Positions",
	  subtitle = "Unlock to drag on screen, resize from the ↘ corner, or fine-tune below.", icon = NS.Media("config_button") },
	{ id = 3, section = "COMBAT & PARTY", label = "Combat & Plates", title = "Enemy Health, 3D Ranges & Damage",
	  subtitle = "Customize minimal nameplates, Elite/Boss rarities, range rings, and side damage feed.", icon = NS.Media("icon-combat") },
	{ id = 4, label = "Party & Buffs", title = "Party (HP & DPS) + Player & Party Buffs",
	  subtitle = "Configure party health frames, party DPS meter, and buff grids.", icon = NS.Media("grouprole-icons-dps") },
	{ id = 5, label = "Loot & Drops", title = "Monster Loot, Chests & Gold",
	  subtitle = "Track dropped armor/weapons, opened chests, and gold earned during the run.", icon = NS.Media("point_plate") },
	{ id = 6, label = "Compass & Map", title = "360° Compass & World Crystals",
	  subtitle = "Configure radar radius, off-screen mode, and filters for chests, lairs, and allies.", icon = NS.Media("group-finder-eye-green") },
	{ id = 7, section = "SYSTEM & LAB", label = "Fonts & General", title = "Typography, Gameplay & System",
	  subtitle = "Switch fonts live, adjust base font size, and manage sync and resets.", icon = NS.Media("point_crystal") },
	{ id = 8, label = "|cffc499ffBeta (Tactical)|r", title = "Run Pace & 5s Tactical Engine",
	  subtitle = "5s stand-still survival simulation, monster/stat/gear/talent analysis, and upgrade guide.", icon = NS.Media("point_gem"),
	  badgeFn = function() return (NS.DB and NS.DB.beta and NS.DB.beta.runPace) and "|cff00ffccON|r" or "|cff778899OFF|r" end },
}

EnsureEditorBuilt = function()
	if EditorUI.built then return end
	EditorUI.built = true
	local blank = NS.OwnMedia("blank")

	local topGlow = EditorFrame:CreateTexture(nil, "OVERLAY")
	topGlow:SetTexture(blank); topGlow:SetVertexColor(THEME.teal[1], THEME.teal[2], THEME.teal[3], 0.85); topGlow:SetHeight(2)
	topGlow:SetPoint("TOPLEFT", EditorFrame, "TOPLEFT", 1, -1); topGlow:SetPoint("TOPRIGHT", EditorFrame, "TOPRIGHT", -1, -1)

	local HeaderBar = CreateFrame("Frame", nil, EditorFrame)
	HeaderBar:SetHeight(46)
	HeaderBar:SetPoint("TOPLEFT", EditorFrame, "TOPLEFT", 1, -3); HeaderBar:SetPoint("TOPRIGHT", EditorFrame, "TOPRIGHT", -1, -3)

	local hdrDiv = EditorFrame:CreateTexture(nil, "ARTWORK")
	hdrDiv:SetTexture(blank); hdrDiv:SetVertexColor(THEME.divider[1], THEME.divider[2], THEME.divider[3], THEME.divider[4]); hdrDiv:SetHeight(1)
	hdrDiv:SetPoint("TOPLEFT", EditorFrame, "TOPLEFT", 1, -49); hdrDiv:SetPoint("TOPRIGHT", EditorFrame, "TOPRIGHT", -1, -49)

	local brandDot = HeaderBar:CreateTexture(nil, "ARTWORK")
	brandDot:SetSize(14, 14); brandDot:SetPoint("LEFT", HeaderBar, "LEFT", 16, 0)
	brandDot:SetTexture(NS.OwnMedia("pin_diamond")); brandDot:SetVertexColor(THEME.teal[1], THEME.teal[2], THEME.teal[3], 1.0)
	local brandTitle = NS.CreateFontText(HeaderBar, 2, "LEFT")
	brandTitle:SetPoint("LEFT", brandDot, "RIGHT", 8, 0); brandTitle:SetText("|cffffffffAZS Minimal UI|r")

	local verBadge = CreateFrame("Frame", nil, HeaderBar)
	verBadge:SetSize(82, 18); verBadge:SetPoint("LEFT", brandTitle, "RIGHT", 10, 0)
	ApplyCardPanel(verBadge, { 0.04, 0.16, 0.16, 0.90 }, { 0.00, 0.72, 0.62, 0.70 })
	verBadge.txt = NS.CreateFontText(verBadge, -3, "CENTER"); verBadge.txt:SetPoint("CENTER", 0, 0)
	verBadge.txt:SetText("|cff00ffccv" .. NS.VERSION .. " MOD|r")

	local closeBtn = CreateFrame("Button", nil, HeaderBar)
	closeBtn:SetSize(28, 26); closeBtn:SetPoint("RIGHT", HeaderBar, "RIGHT", -12, 0)
	ApplyCardPanel(closeBtn, { 0.18, 0.06, 0.08, 0.92 }, { 0.75, 0.25, 0.30, 0.85 })
	closeBtn._restBorder, closeBtn._hoverBorder = { 0.75, 0.25, 0.30, 0.85 }, { 1.0, 0.42, 0.45 }
	AttachHoverTint(closeBtn)
	closeBtn.txt = NS.CreateFontText(closeBtn, 0, "CENTER"); closeBtn.txt:SetPoint("CENTER", 0, 0); closeBtn.txt:SetText("|cffff6b6bX|r")
	closeBtn:SetScript("OnClick", function() NS.PlayUISound("igMainMenuClose"); EditorFrame:Hide() end)

	local hdrLock = CreateFrame("Button", nil, HeaderBar)
	hdrLock:SetSize(168, 26); hdrLock:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
	ApplyCardPanel(hdrLock); AttachHoverTint(hdrLock)
	hdrLock.txt = NS.CreateFontText(hdrLock, -1, "CENTER"); hdrLock.txt:SetPoint("CENTER", 0, 0)
	hdrLock:SetScript("OnClick", function()
		NS.PlayUISound(NS.DB.locked and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
		NS.SetUnlockState(NS.DB.locked)
	end)
	EditorUI.refreshables[#EditorUI.refreshables + 1] = function()
		if NS.DB.locked then
			hdrLock:SetBackdropColor(0.05, 0.20, 0.16, 0.94); SetFlatBorder(hdrLock, 0.12, 0.80, 0.62, 0.90)
			hdrLock.txt:SetText("|cff44ffaaUnlock & Move UI|r")
		else
			hdrLock:SetBackdropColor(0.32, 0.20, 0.04, 0.96); SetFlatBorder(hdrLock, 1.00, 0.78, 0.20, 1.00)
			hdrLock.txt:SetText("|cffffd84dEditing · Lock UI|r")
		end
	end

	local Sidebar = CreateFrame("Frame", nil, EditorFrame)
	Sidebar:SetPoint("TOPLEFT", EditorFrame, "TOPLEFT", 1, -50); Sidebar:SetPoint("BOTTOMLEFT", EditorFrame, "BOTTOMLEFT", 1, 1); Sidebar:SetWidth(188)
	Sidebar.bg = Sidebar:CreateTexture(nil, "BACKGROUND"); Sidebar.bg:SetAllPoints(); Sidebar.bg:SetTexture(blank)
	Sidebar.bg:SetVertexColor(THEME.sideBg[1], THEME.sideBg[2], THEME.sideBg[3], THEME.sideBg[4])

	local sideDiv = EditorFrame:CreateTexture(nil, "ARTWORK")
	sideDiv:SetTexture(blank); sideDiv:SetVertexColor(THEME.divider[1], THEME.divider[2], THEME.divider[3], THEME.divider[4]); sideDiv:SetWidth(1)
	sideDiv:SetPoint("TOPLEFT", Sidebar, "TOPRIGHT", 0, 0); sideDiv:SetPoint("BOTTOMLEFT", Sidebar, "BOTTOMRIGHT", 0, 0)

	local RightPane = CreateFrame("Frame", nil, EditorFrame)
	RightPane:SetPoint("TOPLEFT", Sidebar, "TOPRIGHT", 1, 0); RightPane:SetPoint("BOTTOMRIGHT", EditorFrame, "BOTTOMRIGHT", -1, 1)
	RightPane.bg = RightPane:CreateTexture(nil, "BACKGROUND"); RightPane.bg:SetAllPoints(); RightPane.bg:SetTexture(blank)
	RightPane.bg:SetVertexColor(THEME.bodyBg[1], THEME.bodyBg[2], THEME.bodyBg[3], THEME.bodyBg[4])

	local PageBanner = CreateFrame("Frame", nil, RightPane)
	PageBanner:SetHeight(52); PageBanner:SetPoint("TOPLEFT", RightPane, "TOPLEFT", 0, 0); PageBanner:SetPoint("TOPRIGHT", RightPane, "TOPRIGHT", 0, 0)
	local bannerTitle = NS.CreateFontText(PageBanner, 2, "LEFT"); bannerTitle:SetPoint("TOPLEFT", PageBanner, "TOPLEFT", 16, -9)
	local bannerSub = NS.CreateFontText(PageBanner, -2, "LEFT"); bannerSub:SetPoint("TOPLEFT", PageBanner, "TOPLEFT", 16, -29); bannerSub:SetPoint("RIGHT", PageBanner, "RIGHT", -16, 0)
	local bannerDiv = RightPane:CreateTexture(nil, "ARTWORK")
	bannerDiv:SetTexture(blank); bannerDiv:SetVertexColor(THEME.divider[1], THEME.divider[2], THEME.divider[3], 0.70); bannerDiv:SetHeight(1)
	bannerDiv:SetPoint("TOPLEFT", PageBanner, "BOTTOMLEFT", 12, 0); bannerDiv:SetPoint("TOPRIGHT", PageBanner, "BOTTOMRIGHT", -12, 0)

	local RightBody = CreateFrame("Frame", nil, RightPane)
	RightBody:SetPoint("TOPLEFT", PageBanner, "BOTTOMLEFT", 0, -1); RightBody:SetPoint("BOTTOMRIGHT", RightPane, "BOTTOMRIGHT", 0, 0)

	local function CreateScrollablePage(contentHeight)
		local wrap = CreateFrame("Frame", nil, RightBody)
		wrap:SetAllPoints(RightBody); wrap:Hide()
		local scroll = CreateFrame("ScrollFrame", nil, wrap)
		scroll:SetPoint("TOPLEFT", wrap, "TOPLEFT", 14, -10); scroll:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", -20, 10)
		scroll:EnableMouseWheel(true)
		local content = CreateFrame("Frame", nil, scroll)
		content:SetSize(498, max(380, contentHeight or 380))
		scroll:SetScrollChild(content)
		local track = CreateFrame("Frame", nil, wrap)
		track:SetWidth(6); track:SetPoint("TOPRIGHT", wrap, "TOPRIGHT", -7, -12); track:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", -7, 12)
		track.bg = track:CreateTexture(nil, "BACKGROUND"); track.bg:SetAllPoints(); track.bg:SetTexture(blank); track.bg:SetVertexColor(0.10, 0.13, 0.18, 0.75)
		local thumb = CreateFrame("Button", nil, track)
		thumb:SetSize(6, 48); thumb:SetPoint("TOP", track, "TOP", 0, 0)
		thumb.tex = thumb:CreateTexture(nil, "ARTWORK"); thumb.tex:SetAllPoints(); thumb.tex:SetTexture(blank); thumb.tex:SetVertexColor(0.00, 0.85, 0.72, 0.80)
		local curScroll = 0
		local function UpdateScroll()
			local viewH, contH = scroll:GetHeight() or 388, content:GetHeight() or 388
			local maxS = max(0, contH - viewH)
			if maxS <= 2 then curScroll = 0; scroll:SetVerticalScroll(0); track:Hide(); return end
			track:Show()
			curScroll = Clamp(curScroll, 0, maxS)
			scroll:SetVerticalScroll(curScroll)
			local trackH = max(40, track:GetHeight() or 380)
			local thumbH = max(28, floor(trackH * (viewH / contH)))
			thumb:SetHeight(thumbH)
			thumb:ClearAllPoints()
			thumb:SetPoint("TOP", track, "TOP", 0, -(curScroll / maxS) * max(1, trackH - thumbH))
		end
		scroll:SetScript("OnMouseWheel", function(_, delta)
			local maxS = max(0, (content:GetHeight() or 388) - (scroll:GetHeight() or 388))
			if maxS <= 2 then return end
			curScroll = Clamp(curScroll - delta * 42, 0, maxS)
			UpdateScroll()
		end)
		thumb:SetScript("OnMouseDown", function(self, btn)
			if btn ~= "LeftButton" then return end
			local _, startY = GetCursorPosition()
			local scale, startScroll = UIParent:GetEffectiveScale(), curScroll
			self:SetScript("OnUpdate", function()
				local _, nowY = GetCursorPosition()
				local maxS = max(1, (content:GetHeight() or 388) - (scroll:GetHeight() or 388))
				local travel = max(1, max(40, track:GetHeight() or 380) - thumb:GetHeight())
				curScroll = Clamp(startScroll + (((startY - nowY) / scale) / travel) * maxS, 0, maxS)
				UpdateScroll()
			end)
		end)
		local function StopDrag(self) self:SetScript("OnUpdate", nil) end
		thumb:SetScript("OnMouseUp", StopDrag); thumb:SetScript("OnHide", StopDrag)
		wrap:SetScript("OnShow", UpdateScroll)
		return wrap, content
	end

	SelectEditorPage = function(pageId)
		EditorUI.activePage = pageId
		local def = NAV_PAGES[pageId] or NAV_PAGES[1]
		bannerTitle:SetText("|cffffffff" .. def.title .. "|r")
		bannerSub:SetText("|cff8f9bad" .. def.subtitle .. "|r")
		for i = 1, #EditorUI.navButtons do
			local nb, isSel = EditorUI.navButtons[i], (i == pageId)
			nb._isActive = isSel
			if isSel then
				EditorUI.pageWrappers[i]:Show()
				nb:SetBackdropColor(0.08, 0.14, 0.18, 0.95); SetFlatBorder(nb, 0.00, 0.85, 0.72, 0.85)
				nb.accent:Show(); nb.txt:SetTextColor(1, 1, 1, 1)
			else
				EditorUI.pageWrappers[i]:Hide()
				nb:SetBackdropColor(0.035, 0.045, 0.072, 0.65); SetFlatBorder(nb, 0.10, 0.13, 0.19, 0.40)
				nb.accent:Hide(); nb.txt:SetTextColor(0.70, 0.75, 0.83, 1)
			end
		end
		RefreshEditorControls()
	end

	local curY = -10
	for i = 1, #NAV_PAGES do
		local def = NAV_PAGES[i]
		if def.section then
			if i > 1 then curY = curY - 7 end
			local secLbl = NS.CreateFontText(Sidebar, -3, "LEFT")
			secLbl:SetPoint("TOPLEFT", Sidebar, "TOPLEFT", 14, curY)
			secLbl:SetText("|cff607086" .. def.section .. "|r")
			curY = curY - 14
		end
		local btn = CreateFrame("Button", nil, Sidebar)
		btn:SetSize(168, 30); btn:SetPoint("TOPLEFT", Sidebar, "TOPLEFT", 10, curY)
		ApplyCardPanel(btn, { 0.04, 0.05, 0.08, 0.70 }, { 0.12, 0.15, 0.22, 0.50 }); AttachHoverTint(btn)
		btn.accent = btn:CreateTexture(nil, "OVERLAY")
		btn.accent:SetTexture(blank); btn.accent:SetVertexColor(THEME.teal[1], THEME.teal[2], THEME.teal[3], 1); btn.accent:SetWidth(3)
		btn.accent:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1); btn.accent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1); btn.accent:Hide()
		btn.icon = btn:CreateTexture(nil, "ARTWORK"); btn.icon:SetSize(14, 14); btn.icon:SetPoint("LEFT", btn, "LEFT", 11, 0); btn.icon:SetTexture(def.icon)
		btn.txt = NS.CreateFontText(btn, -1, "LEFT"); btn.txt:SetPoint("LEFT", btn.icon, "RIGHT", 8, 0); btn.txt:SetText(def.label)
		if def.badgeFn then
			btn.badge = NS.CreateFontText(btn, -3, "RIGHT"); btn.badge:SetPoint("RIGHT", btn, "RIGHT", -9, 0)
			local fn = def.badgeFn
			EditorUI.refreshables[#EditorUI.refreshables + 1] = function() btn.badge:SetText(fn()) end
		end
		btn:SetScript("OnClick", function() NS.PlayUISound("UChatScrollButton"); SelectEditorPage(i) end)
		EditorUI.navButtons[i] = btn
		curY = curY - 33
	end
	local sideFoot = CreateFrame("Frame", nil, Sidebar)
	sideFoot:SetPoint("BOTTOMLEFT", Sidebar, "BOTTOMLEFT", 10, 10); sideFoot:SetPoint("BOTTOMRIGHT", Sidebar, "BOTTOMRIGHT", -10, 10); sideFoot:SetHeight(58)
	ApplyCardPanel(sideFoot, { 0.045, 0.058, 0.090, 0.90 }, { 0.15, 0.19, 0.27, 0.70 })
	local footStatus = NS.CreateFontText(sideFoot, -2, "LEFT"); footStatus:SetPoint("TOPLEFT", sideFoot, "TOPLEFT", 9, -9)
	local footHint = NS.CreateFontText(sideFoot, -3, "LEFT"); footHint:SetPoint("BOTTOMLEFT", sideFoot, "BOTTOMLEFT", 9, 8)
	footHint:SetText("|cff708096/minui · ESC closes\nRight-click box to focus|r")
	EditorUI.refreshables[#EditorUI.refreshables + 1] = function()
		footStatus:SetText(NS.DB.locked and "|cff44ffaa●|r |cffe2e8f0Play Mode (Locked)|r" or "|cffffd100●|r |cffffea89Edit Mode Active|r")
	end

	local function AddSectionLabel(parent, x, y, text)
		local lbl = NS.CreateFontText(parent, -2, "LEFT")
		lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
		lbl:SetText("|cff76e8d6" .. upper(text) .. "|r")
		return lbl
	end
	local function AddActionBtn(parent, x, y, w, h, labelOrFn, onClickFn, styleOrFn)
		local btn = CreateFrame("Button", nil, parent)
		btn:SetSize(w, h); btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
		ApplyCardPanel(btn); AttachHoverTint(btn)
		btn.txt = NS.CreateFontText(btn, -1, "CENTER"); btn.txt:SetPoint("CENTER", 0, 0)
		local preset = type(styleOrFn) == "string" and BTN_STYLES[styleOrFn] or nil
		if type(labelOrFn) == "string" then btn.txt:SetText(labelOrFn) end
		if preset then
			btn:SetBackdropColor(preset.bg[1], preset.bg[2], preset.bg[3], preset.bg[4])
			SetFlatBorder(btn, preset.bd[1], preset.bd[2], preset.bd[3], preset.bd[4])
		end
		if type(labelOrFn) == "function" or type(styleOrFn) == "function" then
			EditorUI.refreshables[#EditorUI.refreshables + 1] = function()
				if type(labelOrFn) == "function" then btn.txt:SetText(labelOrFn()) end
				if type(styleOrFn) == "function" then styleOrFn(btn) end
			end
		end
		btn:SetScript("OnClick", function() NS.PlayUISound("UChatScrollButton"); onClickFn(); RefreshEditorControls() end)
		return btn
	end
	local function AddToggleRow(parent, x, y, w, label, getFn, setFn)
		local row = CreateFrame("Button", nil, parent)
		row:SetSize(w, 30); row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
		ApplyCardPanel(row); row._restBorder = { THEME.cardBorder[1], THEME.cardBorder[2], THEME.cardBorder[3], THEME.cardBorder[4] }; AttachHoverTint(row)
		local lbl = NS.CreateFontText(row, -1, "LEFT"); lbl:SetPoint("LEFT", row, "LEFT", 11, 0); lbl:SetPoint("RIGHT", row, "RIGHT", -64, 0)
		lbl:SetText("|cffe8edf5" .. label .. "|r")
		local track = CreateFrame("Frame", nil, row); track:SetSize(46, 17); track:SetPoint("RIGHT", row, "RIGHT", -9, 0); ApplyCardPanel(track)
		local knob = track:CreateTexture(nil, "OVERLAY"); knob:SetSize(13, 13); knob:SetTexture(blank)
		local stateTxt = NS.CreateFontText(track, -3, "CENTER")
		EditorUI.refreshables[#EditorUI.refreshables + 1] = function()
			local on = getFn() and true or false
			knob:ClearAllPoints(); stateTxt:ClearAllPoints()
			if on then
				track:SetBackdropColor(0.05, 0.42, 0.34, 0.96); track:SetBackdropBorderColor(0.00, 0.90, 0.74, 0.95)
				knob:SetPoint("RIGHT", track, "RIGHT", -2, 0); knob:SetVertexColor(0.95, 1, 0.98, 1)
				stateTxt:SetPoint("LEFT", track, "LEFT", 5, 0); stateTxt:SetText("|cffffffffON|r")
			else
				track:SetBackdropColor(0.11, 0.13, 0.18, 0.95); track:SetBackdropBorderColor(0.32, 0.36, 0.46, 0.85)
				knob:SetPoint("LEFT", track, "LEFT", 2, 0); knob:SetVertexColor(0.62, 0.68, 0.78, 1)
				stateTxt:SetPoint("RIGHT", track, "RIGHT", -4, 0); stateTxt:SetText("|cff8892a4OFF|r")
			end
		end
		row:SetScript("OnClick", function()
			local nv = not (getFn() and true or false)
			NS.PlayUISound(nv and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
			setFn(nv); RefreshEditorControls()
		end)
		return row
	end
	local function AddDBToggle(parent, x, y, w, label, tblKey, field, defaultTrue, afterFn)
		return AddToggleRow(parent, x, y, w, label,
			function()
				local t = tblKey and NS.DB[tblKey] or NS.DB
				if defaultTrue then return t and t[field] ~= false end
				return t and t[field]
			end,
			function(v)
				local t = NS.DB
				if tblKey then t[tblKey] = t[tblKey] or {}; t = t[tblKey] end
				t[field] = v
				if afterFn then afterFn(v) end
			end)
	end
	local function AddSliderRow(parent, x, y, w, labelOrFn, minV, maxV, step, getValFn, setValFn, formatFn)
		local card = CreateFrame("Frame", nil, parent)
		card:SetSize(w, 50); card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); ApplyCardPanel(card)
		local title = NS.CreateFontText(card, -1, "LEFT"); title:SetPoint("TOPLEFT", card, "TOPLEFT", 11, -7)
		if type(labelOrFn) == "string" then title:SetText(labelOrFn) end
		local valBadge = NS.CreateFontText(card, -1, "RIGHT"); valBadge:SetPoint("TOPRIGHT", card, "TOPRIGHT", -11, -7)
		local minusBtn = CreateFrame("Button", nil, card)
		minusBtn:SetSize(22, 18); minusBtn:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 9, 7)
		ApplyCardPanel(minusBtn, { 0.16, 0.08, 0.10, 0.92 }, { 0.55, 0.25, 0.30, 0.85 })
		minusBtn.txt = NS.CreateFontText(minusBtn, 0, "CENTER"); minusBtn.txt:SetPoint("CENTER", 0, 0); minusBtn.txt:SetText("|cffff8888-|r")
		local plusBtn = CreateFrame("Button", nil, card)
		plusBtn:SetSize(22, 18); plusBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -9, 7)
		ApplyCardPanel(plusBtn, { 0.06, 0.18, 0.14, 0.92 }, { 0.18, 0.65, 0.50, 0.85 })
		plusBtn.txt = NS.CreateFontText(plusBtn, 0, "CENTER"); plusBtn.txt:SetPoint("CENTER", 0, 0); plusBtn.txt:SetText("|cff55ffaa+|r")
		local slider = CreateFrame("Slider", nil, card)
		slider:SetOrientation("HORIZONTAL"); slider:SetPoint("LEFT", minusBtn, "RIGHT", 9, 0); slider:SetPoint("RIGHT", plusBtn, "LEFT", -9, 0)
		slider:SetHeight(16); slider:EnableMouse(true); slider:EnableMouseWheel(true)
		local barTex = NS.OwnMedia("bar_minimal")
		local groove = slider:CreateTexture(nil, "BACKGROUND"); groove:SetHeight(6); groove:SetPoint("LEFT", slider, "LEFT"); groove:SetPoint("RIGHT", slider, "RIGHT")
		groove:SetTexture(barTex); groove:SetVertexColor(0.11, 0.14, 0.20, 0.95)
		local fill = slider:CreateTexture(nil, "BORDER"); fill:SetHeight(6); fill:SetPoint("LEFT", groove, "LEFT"); fill:SetWidth(1)
		fill:SetTexture(barTex); fill:SetVertexColor(0.00, 0.88, 0.74, 0.95)
		slider:SetThumbTexture(NS.OwnMedia("pin_diamond"))
		local thumb = slider:GetThumbTexture()
		if thumb then thumb:SetSize(16, 16); thumb:SetVertexColor(1.0, 0.88, 0.35, 1.0) end
		slider:SetMinMaxValues(minV, maxV); slider:SetValueStep(step)
		local function UpdateVisuals(v)
			local frac = (maxV > minV) and Clamp((v - minV) / (maxV - minV), 0, 1) or 0
			local trackW = slider:GetWidth()
			fill:SetWidth(max(1, ((trackW and trackW > 10) and trackW or (w - 80)) * frac))
			if type(labelOrFn) == "function" then title:SetText(labelOrFn()) end
			valBadge:SetText("|cffffea89" .. formatFn(v) .. "|r")
		end
		local function ApplyValue(rawVal)
			local snapped = floor(Clamp(floor((rawVal / step) + 0.5) * step, minV, maxV) * 1000 + 0.5) / 1000
			setValFn(snapped); UpdateVisuals(snapped)
		end
		local function StepBy(delta, refresh)
			local nxt = Clamp((getValFn() or minV) + delta * step, minV, maxV)
			slider._updating = true; slider:SetValue(nxt); slider._updating = false
			ApplyValue(nxt)
			if refresh then RefreshEditorControls() end
		end
		slider:SetScript("OnValueChanged", function(self, value) if not self._updating then ApplyValue(value) end end)
		slider:SetScript("OnMouseWheel", function(_, delta) StepBy(delta, false) end)
		minusBtn:SetScript("OnClick", function() NS.PlayUISound("UChatScrollButton"); StepBy(-1, true) end)
		plusBtn:SetScript("OnClick", function() NS.PlayUISound("UChatScrollButton"); StepBy(1, true) end)
		EditorUI.refreshables[#EditorUI.refreshables + 1] = function()
			local cur = Clamp(getValFn() or minV, minV, maxV)
			slider._updating = true; slider:SetValue(cur); slider._updating = false
			UpdateVisuals(cur)
		end
		return card
	end
	local function AddChoiceRow(parent, x, y, w, label, options, getValFn, setValFn)
		local card = CreateFrame("Frame", nil, parent)
		card:SetSize(w, 32); card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); ApplyCardPanel(card)
		local lbl = NS.CreateFontText(card, -1, "LEFT"); lbl:SetPoint("LEFT", card, "LEFT", 11, 0); lbl:SetText("|cffe8edf5" .. label .. "|r")
		local count = #options
		local btnW = floor((min(246, w * 0.56) - (count - 1) * 4) / count)
		local btns = {}
		for i = 1, count do
			local opt = options[i]
			local b = CreateFrame("Button", nil, card)
			b:SetSize(btnW, 22); b:SetPoint("RIGHT", card, "RIGHT", -7 - (count - i) * (btnW + 4), 0)
			ApplyCardPanel(b); AttachHoverTint(b)
			b.txt = NS.CreateFontText(b, -2, "CENTER"); b.txt:SetPoint("CENTER", 0, 0); b.txt:SetText(opt.label)
			b:SetScript("OnClick", function() NS.PlayUISound("UChatScrollButton"); setValFn(opt.value); RefreshEditorControls() end)
			btns[i] = { btn = b, value = opt.value }
		end
		EditorUI.refreshables[#EditorUI.refreshables + 1] = function()
			local cur = getValFn()
			for i = 1, count do
				local b, isSel = btns[i].btn, (btns[i].value == cur)
				b._isActive = isSel
				if isSel then
					b:SetBackdropColor(0.06, 0.24, 0.22, 0.96); SetFlatBorder(b, 0.00, 0.90, 0.76, 1.0); b.txt:SetTextColor(0.95, 1, 0.98, 1)
				else
					b:SetBackdropColor(0.055, 0.068, 0.100, 0.90); SetFlatBorder(b, 0.20, 0.24, 0.34, 0.70); b.txt:SetTextColor(0.68, 0.74, 0.84, 1)
				end
			end
		end
		return card
	end
	local function AddDBChoice(parent, x, y, w, label, options, tblKey, field, defaultVal, afterFn)
		return AddChoiceRow(parent, x, y, w, label, options,
			function() local t = NS.DB[tblKey]; local v = t and t[field]; if v ~= nil then return v end return defaultVal end,
			function(v) NS.DB[tblKey] = NS.DB[tblKey] or {}; NS.DB[tblKey][field] = v; if afterFn then afterFn(v) end end)
	end
	local function AddModuleModeCard(parent, x, y, w, modDef, compact)
		local card = CreateFrame("Frame", nil, parent)
		card:SetSize(w, compact and 34 or 44); card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); ApplyCardPanel(card)
		local bar = card:CreateTexture(nil, "OVERLAY")
		bar:SetTexture(blank); bar:SetWidth(3); bar:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1); bar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 1, 1)
		local title = NS.CreateFontText(card, compact and -1 or 0, "LEFT")
		if compact then
			title:SetPoint("LEFT", card, "LEFT", 12, 0); title:SetText("|cffffffffMode: " .. modDef.label .. "|r")
		else
			title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -7); title:SetText("|cffffffff" .. modDef.label .. "|r")
			local sub = NS.CreateFontText(card, -3, "LEFT")
			sub:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 12, 7); sub:SetPoint("RIGHT", card, "RIGHT", -228, 0); sub:SetText("|cff8492a6" .. modDef.desc .. "|r")
		end
		local modes, count, btns, rightOff = modDef.modes, #modDef.modes, {}, -8
		for i = count, 1, -1 do
			local mKey = modes[i]
			local meta = MODE_META[mKey]
			local bw = (count == 3) and (mKey == "off" and 72 or 66) or 80
			local b = CreateFrame("Button", nil, card)
			b:SetSize(bw, 22); b:SetPoint("RIGHT", card, "RIGHT", rightOff, 0)
			ApplyCardPanel(b); AttachHoverTint(b)
			b.txt = NS.CreateFontText(b, -2, "CENTER"); b.txt:SetPoint("CENTER", 0, 0)
			b.txt:SetText((count == 2 and mKey == "off") and "Disabled" or meta.label)
			b:SetScript("OnClick", function()
				NS.PlayUISound(mKey == "off" and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOn")
				NS.SetModuleMode(modDef.key, mKey)
			end)
			btns[i] = { btn = b, mode = mKey, meta = meta }
			rightOff = rightOff - (bw + 4)
		end
		EditorUI.refreshables[#EditorUI.refreshables + 1] = function()
			local cur = NS.GetModuleMode(modDef.key)
			local cm = MODE_META[cur] or MODE_META.minimal
			bar:SetVertexColor(cm.barCol[1], cm.barCol[2], cm.barCol[3], 0.95)
			for i = 1, count do
				local item = btns[i]
				local b, isSel = item.btn, (item.mode == cur)
				b._isActive = isSel
				if isSel then
					local m = item.meta
					b:SetBackdropColor(m.bg[1], m.bg[2], m.bg[3], m.bg[4])
					SetFlatBorder(b, m.br[1], m.br[2], m.br[3], m.br[4])
					b.txt:SetTextColor(m.txt[1], m.txt[2], m.txt[3], 1)
				else
					b:SetBackdropColor(0.05, 0.06, 0.09, 0.88); SetFlatBorder(b, 0.18, 0.22, 0.30, 0.65); b.txt:SetTextColor(0.58, 0.64, 0.74, 1)
				end
			end
		end
		return card
	end
	local function AddInfoCard(parent, y, h, bg, bd, text)
		local c = CreateFrame("Frame", nil, parent)
		c:SetSize(498, h); c:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y); ApplyCardPanel(c, bg, bd)
		local t = NS.CreateFontText(c, -2, "LEFT")
		t:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -10); t:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -12, 8); t:SetText(text)
	end
	local function UpdateHUD() if NS.UpdateMinimalHUD then NS.UpdateMinimalHUD() end end
	local function UpdatePlates() if NS.Modules.Nameplates then NS.Modules.Nameplates.ScanAndUpdate() end end

	do
		local wrap, P = CreateScrollablePage(66 + #NS.MODULE_DEFS * 50 + 12)
		AddActionBtn(P, 0,   0, 162, 30, "|cff00ffccAll Minimal|r",  function() NS.ApplyModulePreset("minimal") end,  "teal")
		AddActionBtn(P, 168, 0, 162, 30, "|cffffcc44All Original|r", function() NS.ApplyModulePreset("original") end, "gold")
		AddActionBtn(P, 336, 0, 162, 30, "|cffff6b6bDisable All|r",  function() NS.ApplyModulePreset("off") end,      "red")
		local legend = NS.CreateFontText(P, -3, "LEFT"); legend:SetPoint("TOPLEFT", P, "TOPLEFT", 2, -38)
		legend:SetText("|cff00ffcc● Minimal|r enables our UI and hides original    |cffffcc44● Original|r restores game UI    |cffff5555● Both OFF|r disables both")
		for i = 1, #NS.MODULE_DEFS do AddModuleModeCard(P, 0, -58 - (i - 1) * 50, 498, NS.MODULE_DEFS[i], false) end
		EditorUI.pageWrappers[1] = wrap
	end

	do
		local wrap, P = CreateScrollablePage(490)
		AddActionBtn(P, 0, 0, 498, 32,
			function()
				return NS.DB.locked
					and "|cff44ffaaUNLOCK PANELS|r  |cffc8d2e0(Drag on screen or pull the ↘ corner to resize)|r"
					or  "|cffffd84dEDIT MODE ACTIVE|r  |cffffffffClick here to Lock and Save|r"
			end,
			function() NS.SetUnlockState(NS.DB.locked) end,
			function(btn)
				if NS.DB.locked then btn:SetBackdropColor(0.05, 0.19, 0.16, 0.94); SetFlatBorder(btn, 0.12, 0.82, 0.65, 0.90)
				else btn:SetBackdropColor(0.30, 0.20, 0.04, 0.96); SetFlatBorder(btn, 1.00, 0.78, 0.20, 1.00) end
			end)
		AddDBToggle(P, 0, -38, 245, "Alignment Grid", nil, "showGrid", false, UpdateAlignGridVisibility)
		AddDBToggle(P, 253, -38, 245, "Snap to Grid (8px)", nil, "snapToGrid", false)
		AddSectionLabel(P, 2, -78, "Select Box to Edit")

		local chipButtons = {}
		for c = 0, #BOX_ORDER do
			local col, row = c % 5, floor(c / 5)
			local cb = CreateFrame("Button", nil, P)
			cb:SetSize(95, 24); cb:SetPoint("TOPLEFT", P, "TOPLEFT", col * 100, -96 - row * 28)
			ApplyCardPanel(cb); AttachHoverTint(cb)
			cb.txt = NS.CreateFontText(cb, -2, "CENTER"); cb.txt:SetPoint("CENTER", 0, 0)
			cb.txt:SetText(c == 0 and "All" or BOX_ORDER[c].short)
			local idx = c
			cb:SetScript("OnClick", function()
				NS.PlayUISound("UChatScrollButton"); EditorUI.selectedBoxIdx = idx; RefreshAllOverlays(); RefreshEditorControls()
			end)
			chipButtons[c + 1] = { btn = cb, idx = idx }
		end
		EditorUI.refreshables[#EditorUI.refreshables + 1] = function()
			for i = 1, #chipButtons do
				local it = chipButtons[i]
				local isSel = (EditorUI.selectedBoxIdx == it.idx)
				local isHid = (it.idx > 0) and NS.IsBoxHidden(BOX_ORDER[it.idx].key)
				it.btn._isActive = isSel
				if isSel then it.btn:SetBackdropColor(0.06, 0.24, 0.22, 0.96); SetFlatBorder(it.btn, 0, 0.92, 0.78, 1); it.btn.txt:SetTextColor(0.95, 1, 0.98, 1)
				elseif isHid then it.btn:SetBackdropColor(0.20, 0.06, 0.08, 0.88); SetFlatBorder(it.btn, 0.80, 0.28, 0.32, 0.80); it.btn.txt:SetTextColor(1, 0.56, 0.58, 1)
				else it.btn:SetBackdropColor(THEME.cardBg[1], THEME.cardBg[2], THEME.cardBg[3], THEME.cardBg[4]); SetFlatBorder(it.btn, THEME.cardBorder[1], THEME.cardBorder[2], THEME.cardBorder[3], THEME.cardBorder[4]); it.btn.txt:SetTextColor(0.76, 0.82, 0.90, 1) end
			end
		end

		AddSliderRow(P, 0, -214, 498,
			function() return EditorUI.selectedBoxIdx == 0 and "|cffe2e8f0Global Scale (All Boxes)|r" or ("|cff00ffccScale:|r " .. BOX_ORDER[EditorUI.selectedBoxIdx].label) end,
			0.55, 1.80, 0.05,
			function()
				local k = EditorUI.selectedBoxIdx == 0 and "PlayerHUD" or BOX_ORDER[EditorUI.selectedBoxIdx].key
				return (NS.DB.boxes[k] and NS.DB.boxes[k].scale) or (EditorUI.selectedBoxIdx == 0 and 0.94 or 1.0)
			end,
			function(v)
				if EditorUI.selectedBoxIdx == 0 then for _, cfg in pairs(NS.DB.boxes) do cfg.scale = v end
				else NS.DB.boxes[BOX_ORDER[EditorUI.selectedBoxIdx].key].scale = v end
				NS.RefreshAllLayouts()
			end,
			function(v) return fmt("%.0f%%", v * 100) end)

		AddSliderRow(P, 0, -270, 498,
			function()
				if EditorUI.selectedBoxIdx == 0 then return "|cffe2e8f0Background & Border Opacity (Global)|r" end
				local info = BOX_ORDER[EditorUI.selectedBoxIdx]
				return (NS.BORDERLESS_BOXES[info.key] and "|cff00ffccOpacity:|r " or "|cff00ffccBackground Opacity:|r ") .. info.label
			end,
			0.00, 1.00, 0.05,
			function()
				if EditorUI.selectedBoxIdx == 0 then return NS.DB.bgAlpha or 0.72 end
				local k = BOX_ORDER[EditorUI.selectedBoxIdx].key
				if NS.BORDERLESS_BOXES[k] then return (NS.DB.boxes[k] and NS.DB.boxes[k].frameAlpha) or 1.0 end
				return (NS.DB.boxes[k] and NS.DB.boxes[k].alpha) or NS.DB.bgAlpha or 0.72
			end,
			function(v)
				if EditorUI.selectedBoxIdx == 0 then
					NS.DB.bgAlpha = v
					for k, cfg in pairs(NS.DB.boxes) do
						if not NS.BORDERLESS_BOXES[k] then
							cfg.alpha = (k == "StoredBadge") and ((v <= 0.01) and 0.0 or max(0.30, v)) or v
						end
					end
				else
					local k = BOX_ORDER[EditorUI.selectedBoxIdx].key
					if NS.BORDERLESS_BOXES[k] then NS.DB.boxes[k].frameAlpha = max(0.15, v) else NS.DB.boxes[k].alpha = v end
				end
				NS.RefreshAllLayouts()
			end,
			function(v) return fmt("%.0f%%", v * 100) end)

		local fineCard = CreateFrame("Frame", nil, P)
		fineCard:SetSize(498, 84); fineCard:SetPoint("TOPLEFT", P, "TOPLEFT", 0, -326); ApplyCardPanel(fineCard)
		local fineTitle = NS.CreateFontText(fineCard, -1, "LEFT"); fineTitle:SetPoint("TOPLEFT", fineCard, "TOPLEFT", 11, -8)
		local coordTxt  = NS.CreateFontText(fineCard, -2, "LEFT"); coordTxt:SetPoint("TOPLEFT", fineCard, "TOPLEFT", 11, -27)
		local hintShift = NS.CreateFontText(fineCard, -3, "LEFT"); hintShift:SetPoint("BOTTOMLEFT", fineCard, "BOTTOMLEFT", 11, 8)
		hintShift:SetText("|cff7f8ea3Click: 2px · Shift+Click: 12px|r")

		local dpad = { { "▲", 224, -8, 0, 1 }, { "◄", 194, -31, -1, 0 }, { "►", 254, -31, 1, 0 }, { "▼", 224, -54, 0, -1 } }
		for i = 1, 4 do
			local d = dpad[i]
			local b = CreateFrame("Button", nil, fineCard)
			b:SetSize(26, 21); b:SetPoint("TOPLEFT", fineCard, "TOPLEFT", d[2], d[3])
			ApplyCardPanel(b, { 0.09, 0.11, 0.16, 0.95 }, { 0.28, 0.34, 0.45, 0.85 }); AttachHoverTint(b)
			b.txt = NS.CreateFontText(b, -1, "CENTER"); b.txt:SetPoint("CENTER", 0, 0); b.txt:SetText("|cffffea89" .. d[1] .. "|r")
			b:SetScript("OnClick", function()
				NS.PlayUISound("UChatScrollButton")
				if EditorUI.selectedBoxIdx == 0 then return end
				local key = BOX_ORDER[EditorUI.selectedBoxIdx].key
				local cfg = NS.DB.boxes[key]
				if not cfg then return end
				local mult = IsShiftKeyDown() and 12 or 2
				cfg.x, cfg.y = (cfg.x or 0) + d[4] * mult, (cfg.y or 0) + d[5] * mult
				NS.RestoreBoxLayout(key, NS.MovableFrames[key]); RefreshAllOverlays(); RefreshEditorControls()
			end)
		end

		local visBtn = CreateFrame("Button", nil, fineCard)
		visBtn:SetSize(188, 28); visBtn:SetPoint("TOPRIGHT", fineCard, "TOPRIGHT", -10, -10); ApplyCardPanel(visBtn); AttachHoverTint(visBtn)
		visBtn.txt = NS.CreateFontText(visBtn, -2, "CENTER"); visBtn.txt:SetPoint("CENTER", 0, 0)
		visBtn:SetScript("OnClick", function()
			if EditorUI.selectedBoxIdx == 0 then return end
			local key = BOX_ORDER[EditorUI.selectedBoxIdx].key
			local modKey = NS.BOX_TO_MODULE and NS.BOX_TO_MODULE[key]
			local def = modKey and NS.MODULE_BY_KEY[modKey]
			if def and modKey ~= "DamageFeed" and def.modes and #def.modes > 0 then
				local cur, nxt = NS.GetModuleMode(modKey), def.modes[1]
				for i = 1, #def.modes do if def.modes[i] == cur then nxt = def.modes[(i % #def.modes) + 1]; break end end
				NS.PlayUISound(nxt == "off" and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOn")
				NS.SetModuleMode(modKey, nxt)
			else
				NS.DB.hiddenBoxes[key] = not NS.DB.hiddenBoxes[key]
				NS.PlayUISound(NS.DB.hiddenBoxes[key] and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOn")
				NS.RefreshAllLayouts(); UpdateHUD(); RefreshEditorControls()
			end
		end)

		local resetOneBtn = CreateFrame("Button", nil, fineCard)
		resetOneBtn:SetSize(188, 24); resetOneBtn:SetPoint("BOTTOMRIGHT", fineCard, "BOTTOMRIGHT", -10, 10)
		ApplyCardPanel(resetOneBtn, { 0.18, 0.14, 0.05, 0.90 }, { 0.72, 0.56, 0.22, 0.80 }); AttachHoverTint(resetOneBtn)
		resetOneBtn.txt = NS.CreateFontText(resetOneBtn, -2, "CENTER"); resetOneBtn.txt:SetPoint("CENTER", 0, 0)
		resetOneBtn:SetScript("OnClick", function()
			NS.PlayUISound("UChatScrollButton")
			if EditorUI.selectedBoxIdx == 0 then NS.DB.boxes = NS.DeepCopy(NS.DEFAULTS.boxes)
			else
				local key = BOX_ORDER[EditorUI.selectedBoxIdx].key
				NS.DB.boxes[key] = NS.DeepCopy(NS.DEFAULTS.boxes[key])
				local modKey = NS.BOX_TO_MODULE and NS.BOX_TO_MODULE[key]
				if modKey then NS.SetModuleMode(modKey, "minimal", true) end
				NS.DB.hiddenBoxes[key] = false
			end
			NS.SuppressNativeAndBlizzardUI(); NS.RefreshAllLayouts(); UpdateHUD(); RefreshEditorControls()
		end)

		EditorUI.refreshables[#EditorUI.refreshables + 1] = function()
			if EditorUI.selectedBoxIdx == 0 then
				fineTitle:SetText("|cffffea89Fine Adjustment (D-Pad)|r")
				coordTxt:SetText("|cff8892a4Select 1 box above\nor click it on screen|r")
				visBtn:SetBackdropColor(0.06, 0.07, 0.10, 0.70); SetFlatBorder(visBtn, 0.22, 0.25, 0.32, 0.55)
				visBtn.txt:SetText("|cff707c90Mode (Pick 1 box)|r"); resetOneBtn.txt:SetText("|cffffcc55Center All|r")
			else
				local info = BOX_ORDER[EditorUI.selectedBoxIdx]
				local cfg, modKey = NS.DB.boxes[info.key], NS.BOX_TO_MODULE and NS.BOX_TO_MODULE[info.key]
				local mode = modKey and NS.GetModuleMode(modKey) or (NS.IsBoxHidden(info.key) and "off" or "minimal")
				fineTitle:SetText("|cff00ffcc" .. info.label .. "|r")
				coordTxt:SetText(fmt("|cffffffffX:|r %d   |cffffffffY:|r %d\n|cff94a3b8Anchor: %s|r", cfg and cfg.x or 0, cfg and cfg.y or 0, cfg and cfg.point or "CENTER"))
				if mode == "minimal" and not NS.IsBoxHidden(info.key) then
					visBtn:SetBackdropColor(0.05, 0.24, 0.21, 0.95); SetFlatBorder(visBtn, 0, 0.90, 0.76, 0.95); visBtn.txt:SetText("|cff00ffccMINIMAL|r  |cffcccccc(Click: Cycle)|r")
				elseif mode == "original" then
					visBtn:SetBackdropColor(0.28, 0.20, 0.04, 0.95); SetFlatBorder(visBtn, 1, 0.80, 0.24, 0.95); visBtn.txt:SetText("|cffffcc44ORIGINAL|r  |cffcccccc(Click: Cycle)|r")
				else
					visBtn:SetBackdropColor(0.26, 0.07, 0.09, 0.95); SetFlatBorder(visBtn, 0.95, 0.32, 0.35, 0.95); visBtn.txt:SetText("|cffff6666BOTH OFF|r  |cffcccccc(Click: Enable)|r")
				end
				resetOneBtn.txt:SetText("|cffffcc55Reset " .. info.short .. "|r")
			end
		end

		AddActionBtn(P, 0, -418, 245, 28, "|cffffcc55Reset All Positions|r", function() NS.DB.boxes = NS.DeepCopy(NS.DEFAULTS.boxes); NS.RefreshAllLayouts() end, "gold")
		AddActionBtn(P, 253, -418, 245, 28, "|cffff6b6bReset Entire UI (Default)|r", ResetEntireUI, "red")
		local tip = NS.CreateFontText(P, -3, "CENTER"); tip:SetPoint("TOP", P, "TOP", 0, -454)
		tip:SetText("|cff8492a6Tip: While unlocked, pull the |cffffea89↘|r corner or |cffffea89Scroll|r over any box to resize!|r")
		EditorUI.pageWrappers[2] = wrap
	end

	do
		local wrap, P = CreateScrollablePage(430)
		AddSectionLabel(P, 2, 0, "Enemy Health Nameplates")
		AddModuleModeCard(P, 0, -18, 498, NS.MODULE_BY_KEY.Nameplates, true)
		AddDBChoice(P, 0, -58, 498, "Minimal Bar Size",
			{ { label = "Compact", value = 1 }, { label = "Medium", value = 2 }, { label = "Wide", value = 3 } }, "plates", "sizeMode", 2, UpdatePlates)
		AddDBToggle(P, 0, -96, 498, "Rarity Colors (|cff3b9effElite|r · |cffb866ffGuardian|r · |cffff8c1aBoss|r)", "plates", "colorRarityNames", false, UpdatePlates)
		AddDBToggle(P, 0, -132, 498, "Show Name on Normal Monsters", "plates", "showNormalNames", false, UpdatePlates)
		AddSectionLabel(P, 2, -176, "3D Skill Attack Ranges")
		AddModuleModeCard(P, 0, -194, 498, NS.MODULE_BY_KEY.RangeRings, true)
		AddSliderRow(P, 0, -234, 498, "|cffe2e8f03D Range Ring Opacity|r", 0.15, 0.90, 0.05,
			function() return NS.DB.ranges.alpha or 0.42 end, function(v) NS.DB.ranges.alpha = v end, function(v) return fmt("%.0f%%", v * 100) end)
		AddDBToggle(P, 0, -290, 245, "Skill Icon on Ring Edge", "ranges", "showEdgeIcon", false)
		AddDBToggle(P, 253, -290, 245, "Scale with 'Area' Stat", "ranges", "scaleWithArea", false)
		AddSectionLabel(P, 2, -334, "Damage Numbers (Side Feed vs Floating)")
		AddModuleModeCard(P, 0, -352, 498, NS.MODULE_BY_KEY.DamageFeed, true)
		EditorUI.pageWrappers[3] = wrap
	end

	do
		local wrap, P = CreateScrollablePage(640)
		AddSectionLabel(P, 2, 0, "Party Health (Ally HP & Revive)")
		AddModuleModeCard(P, 0, -18, 498, NS.MODULE_BY_KEY.PartyFrames, true)
		AddSectionLabel(P, 2, -64, "Party DPS Meter (Real-Time Ranking)")
		AddModuleModeCard(P, 0, -82, 498, NS.MODULE_BY_KEY.PartyMeter, true)
		AddDBToggle(P, 0, -122, 298, "Show Party DPS Meter even when Solo", "party", "showMeterWhenSolo", false, UpdateHUD)
		AddActionBtn(P, 306, -122, 192, 30, "|cffffcc55Reset Party DPS|r", function() if NS.Modules.PartyMeter then NS.Modules.PartyMeter.Reset() end end, "gold")
		AddSectionLabel(P, 2, -166, "Player Buffs & Debuffs")
		AddModuleModeCard(P, 0, -184, 498, NS.MODULE_BY_KEY.PlayerBuffs, true)
		AddDBChoice(P, 0, -224, 498, "Icon Size",
			{ { label = "Compact", value = 1 }, { label = "Medium", value = 2 }, { label = "Large", value = 3 } }, "buffs", "sizeMode", 2, UpdateHUD)
		AddDBToggle(P, 0, -262, 498, "Show Debuffs & Hexes (Red Border)", "buffs", "showDebuffs", true, UpdateHUD)
		AddDBToggle(P, 0, -298, 498, "Show Item Buffs (Rings, Trinkets, Amulets)", "buffs", "showItemBuffs", true, UpdateHUD)
		AddDBToggle(P, 0, -334, 498, "Show Pre-Match Talent & Race Buffs", "buffs", "showTalentRaceBuffs", true, UpdateHUD)
		AddSectionLabel(P, 2, -378, "Party Buffs")
		AddModuleModeCard(P, 0, -396, 498, NS.MODULE_BY_KEY.PartyBuffs, true)
		AddDBChoice(P, 0, -436, 498, "Display Style",
			{ { label = "Grouped (3/4)", value = 1 }, { label = "Per Ally", value = 2 } }, "buffs", "partyBuffMode", 1, UpdateHUD)
		AddDBToggle(P, 0, -474, 498, "Show Party Buffs even when Solo", "buffs", "showPartyBuffsWhenSolo", false, UpdateHUD)
		AddSectionLabel(P, 2, -518, "Buff Cooldowns (Next Activation Window)")
		AddModuleModeCard(P, 0, -536, 498, NS.MODULE_BY_KEY.CooldownBuffs, true)
		AddDBToggle(P, 0, -576, 498, "Show Ready Buffs (Not Currently on Cooldown)", "buffs", "showReadyCooldowns", true, UpdateHUD)
		EditorUI.pageWrappers[4] = wrap
	end

	do
		local wrap, P = CreateScrollablePage(380)
		AddSectionLabel(P, 2, 0, "Run Loot & Drops Panel")
		AddModuleModeCard(P, 0, -18, 498, NS.MODULE_BY_KEY.LootPanel, true)
		AddDBChoice(P, 0, -58, 498, "Minimum Drop Quality",
			{ { label = "All", value = 0 }, { label = "Green+", value = 2 }, { label = "Blue+", value = 3 }, { label = "Epic+", value = 4 } },
			"loot", "minQuality", 0, UpdateHUD)
		AddDBChoice(P, 0, -96, 498, "Drop Filter",
			{ { label = "Armor", value = "armor" }, { label = "Armor+Wpn", value = "gear" }, { label = "Gear+Jewel", value = "equip" }, { label = "All", value = "all" } },
			"loot", "filterMode", "armor", UpdateHUD)
		AddDBToggle(P, 0, -134, 498, "Auto-hide panel when there is no loot", "loot", "hideWhenEmpty", false, UpdateHUD)
		AddDBToggle(P, 0, -172, 498, "Also keep native Game Loot HUD (AZS) visible", "loot", "keepNativeLoot", false,
			function() if NS.SuppressNativeAndBlizzardUI then NS.SuppressNativeAndBlizzardUI() end; UpdateHUD() end)
		AddActionBtn(P, 0, -216, 498, 32, "|cffffcc55Reset Session Drops, Chests & Gold History|r",
			function() if NS.Modules.LootPanel then NS.Modules.LootPanel.Reset() end; UpdateHUD() end, "gold")
		AddInfoCard(P, -260, 66, { 0.045, 0.060, 0.092, 0.90 }, { 0.16, 0.20, 0.30, 0.70 },
			"|cff00ffccUsage Tip:|r Hover over any armor or item listed in the panel to inspect its full tooltip stats. Use |cffffea89Shift+Click|r to link the item in chat. History resets automatically when starting a new run.")
		EditorUI.pageWrappers[5] = wrap
	end

	do
		local wrap, P = CreateScrollablePage(390)
		AddSectionLabel(P, 2, 0, "360° Compass (Camera-Aligned)")
		AddModuleModeCard(P, 0, -18, 498, NS.MODULE_BY_KEY.Compass, true)
		AddSliderRow(P, 0, -58, 498, "|cffe2e8f0360° Compass Radius (Drag to resize)|r", 80, 260, 4,
			function() return NS.DB.compass.radius or 152 end,
			function(v) NS.DB.compass.radius = v; if NS.MovableFrames.Compass then NS.RestoreBoxLayout("Compass", NS.MovableFrames.Compass) end end,
			function(v) return fmt("%dpx", v) end)
		AddDBChoice(P, 0, -114, 498, "When to Show Arrows",
			{ { label = "Off-Screen Only", value = true }, { label = "All on Map", value = false } }, "compass", "onlyOffscreen", true)
		AddSectionLabel(P, 2, -160, "Tracking Filters")
		AddDBToggle(P, 0, -178, 245, "Chests (Normal & Boss)", "compass", "showChests", false)
		AddDBToggle(P, 253, -178, 245, "Lairs", "compass", "showLairs", false)
		AddDBToggle(P, 0, -214, 245, "Portals, Totems & Pings", "compass", "showPortalsTotems", false)
		AddDBToggle(P, 253, -214, 245, "Downed Allies", "compass", "showDowned", false)
		AddDBToggle(P, 0, -250, 245, "Active Bosses", "compass", "showBosses", false)
		AddToggleRow(P, 253, -250, 245, "3D World Crystals",
			function() return NS.GetModuleMode("WorldPins") == "minimal" end,
			function(v) NS.SetModuleMode("WorldPins", v and "minimal" or "off") end)
		AddSectionLabel(P, 2, -294, "Native WoW Minimap")
		AddModuleModeCard(P, 0, -312, 498, NS.MODULE_BY_KEY.Minimap, true)
		EditorUI.pageWrappers[6] = wrap
	end

	do
		local wrap, P = CreateScrollablePage(390)
		AddSectionLabel(P, 2, 0, "Font Style (Click to switch live)")
		local fontCards = {}
		for i = 1, #FONTS do
			local fc = CreateFrame("Button", nil, P)
			fc:SetSize(245, 34); fc:SetPoint("TOPLEFT", P, "TOPLEFT", ((i - 1) % 2) * 253, -18 - floor((i - 1) / 2) * 40)
			ApplyCardPanel(fc); AttachHoverTint(fc)
			local preview = fc:CreateFontString(nil, "OVERLAY")
			preview:SetFont(FONTS[i].path, 12, "OUTLINE"); preview:SetPoint("CENTER", fc, "CENTER", 0, 0); preview:SetText(FONTS[i].name)
			fc.preview = preview
			local idx = i
			fc:SetScript("OnClick", function() NS.PlayUISound("UChatScrollButton"); NS.DB.fontIndex = idx; NS.RefreshAllFonts(); RefreshEditorControls() end)
			fontCards[i] = fc
		end
		EditorUI.refreshables[#EditorUI.refreshables + 1] = function()
			local cur = NS.DB.fontIndex or 1
			for i = 1, #fontCards do
				local fc, isSel = fontCards[i], (i == cur)
				fc._isActive = isSel
				if isSel then fc:SetBackdropColor(0.06, 0.24, 0.22, 0.96); SetFlatBorder(fc, 0, 0.92, 0.78, 1); fc.preview:SetTextColor(0.95, 1, 0.96, 1)
				else fc:SetBackdropColor(THEME.cardBg[1], THEME.cardBg[2], THEME.cardBg[3], THEME.cardBg[4]); SetFlatBorder(fc, THEME.cardBorder[1], THEME.cardBorder[2], THEME.cardBorder[3], THEME.cardBorder[4]); fc.preview:SetTextColor(0.76, 0.82, 0.90, 1) end
			end
		end
		AddSliderRow(P, 0, -104, 498, "|cffe2e8f0Base Font Size (Live)|r", 9, 16, 1,
			function() return NS.DB.fontSize or 11 end, function(v) NS.DB.fontSize = v; NS.RefreshAllFonts() end, function(v) return fmt("%dpx", v) end)
		AddSectionLabel(P, 2, -168, "Gameplay & Chat Preferences")
		AddToggleRow(P, 0, -186, 498, "Store Level-Ups to open with [T]",
			function() return type(_G.AZS_IsStoringLevels) == "function" and _G.AZS_IsStoringLevels() or false end,
			function(v) if type(_G.AZS_SetStoringLevels) == "function" then _G.AZS_SetStoringLevels(v) end end)
		AddModuleModeCard(P, 0, -222, 498, NS.MODULE_BY_KEY.Chat, true)
		AddSectionLabel(P, 2, -270, "Sync & Maintenance")
		AddActionBtn(P, 0, -288, 498, 30, "|cff00ffccForce Server Sync (AZSCMD sync)|r",
			function() SendAddonMessage("AZSCMD", "sync", "PARTY") end, "cyan")
		AddActionBtn(P, 0, -326, 498, 30, "|cffff6b6bRestore All Default Settings|r", ResetEntireUI, "red")
		EditorUI.pageWrappers[7] = wrap
	end

	do
		local wrap, P = CreateScrollablePage(460)
		local function RefreshBeta() NS.RefreshAllLayouts(); UpdateHUD(); RefreshEditorControls() end
		AddSectionLabel(P, 2, 0, "Run Pace, Live Coach & Tactical Engine (ModulesBeta/RunPace.lua)")
		AddDBToggle(P, 0,   -20, 245, "Enable Pace & Tactical Panel",     "beta", "runPace", false, RefreshBeta)
		AddDBToggle(P, 253, -20, 245, "Enable 5s Tactical & Build Calc",  "beta", "tacticalAdvisor", true, RefreshBeta)
		AddDBToggle(P, 0,   -58, 245, "Show Post-Run Card on exit",       "beta", "showPostRunCard", true)
		AddDBToggle(P, 253, -58, 245, "Real-Time Coach (alerts)",         "beta", "coach", true, RefreshBeta)
		AddSliderRow(P, 0, -98, 498, "|cffc499ffStand-Still Simulation Window (Seconds)|r", 3, 10, 1,
			function() return (NS.DB.beta and NS.DB.beta.simSeconds) or 5 end,
			function(v) NS.DB.beta.simSeconds = v; RefreshBeta() end,
			function(v) return fmt("%ds standing", v) end)
		AddActionBtn(P, 0, -162, 245, 32, "|cff00ffccPreview Post-Run Card|r",
			function() if NS.BetaModules and NS.BetaModules.RunPace then NS.BetaModules.RunPace.ShowSummary(true) end end, "teal")
		AddActionBtn(P, 253, -162, 245, 32, "|cffffcc55Reset Saved Records (PB)|r",
			function() if NS.BetaModules and NS.BetaModules.RunPace then NS.BetaModules.RunPace.ResetPBs(); RefreshBeta() end end, "gold")
		AddDBToggle(P, 0, -210, 498, "Play sound on critical Coach alerts", "beta", "coachSound", true)
		AddInfoCard(P, -254, 166, { 0.055, 0.045, 0.095, 0.92 }, { 0.42, 0.30, 0.72, 0.75 },
			"|cff00ffccIntegrated Tactical Engine:|r\n"
			.. "• |cffffffffStand-Still Simulation (5s):|r Combines HP + Shields + Regen + Leech + Heals against real incoming damage (Combat Log) and live monster, elite, guardian, and boss pressure.\n"
			.. "• |cffffffffStat Priority:|r Computes true marginal gain across |cffff7777Damage|r, |cff66ccffDefense|r, |cff55ff88Health/Regen|r, and |cffffd100Cooldown (CDR)|r without recommending capped stats.\n"
			.. "• |cffffffffRecommended Skill:|r Analyzes your |cffc499ffTalent tree|r, equipped gear, and active skill DPS.\n"
			.. "• |cffffffffLive Coach:|r Up to 3 prioritized alerts: death danger, ground AoE, boss vs. survivability, pace/DPS drop, nearby chests and lairs, level-up, and downed ally.\n"
			.. "• |cff94a3b8Tip:|r Hover over the |cffffffff[B] Tact.|r panel to inspect the full calculation breakdown and Coach history.")
		EditorUI.pageWrappers[8] = wrap
	end
end

NS.EditorHooks.SelectBoxByKey = function(key, openEditor)
	for i = 1, #BOX_ORDER do if BOX_ORDER[i].key == key then EditorUI.selectedBoxIdx = i; break end end
	if openEditor then EnsureEditorBuilt(); SelectEditorPage(2); EditorFrame:Show() end
	RefreshAllOverlays(); RefreshEditorControls()
end
NS.EditorHooks.RefreshOverlays = RefreshAllOverlays
NS.EditorHooks.SyncUI = RefreshEditorControls
NS.EditorHooks.RefreshAll = function()
	NS.RefreshAllLayouts()
	if NS.UpdateMinimalHUD then NS.UpdateMinimalHUD() end
	RefreshEditorControls()
end

function NS.ToggleEditor()
	if not NS.DB then NS.InitializeDB() end
	if EditorFrame:IsShown() then
		NS.PlayUISound("igMainMenuClose"); EditorFrame:Hide()
	else
		NS.PlayUISound("igMainMenuOpen"); EnsureEditorBuilt(); SelectEditorPage(EditorUI.activePage); EditorFrame:Show()
	end
end

NS.Modules.Editor = { frame = EditorFrame }
