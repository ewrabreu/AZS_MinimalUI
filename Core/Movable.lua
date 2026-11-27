local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, fmt = math.floor, string.format
local Clamp, Round = NS.Clamp, NS.Round
local GetCursorPosition, pairs = GetCursorPosition, pairs

local OV_BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = NS.Media("border-glow"),
	tile = true, tileSize = 16, edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local MINI_BTN_BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = NS.Media("border-aura"),
	tile = true, tileSize = 8, edgeSize = 6,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local ALWAYS_TOGGLE_VIS = {
	TopBar = true, PlayerHUD = true, StatsPanel = true,
	MeterPanel = true, Compass = true, Minimap = true, EliteTimer = true,
}

local function CreateOverlayMiniBtn(ov, w, h, pt, ox, oy, levelOff, r, g, b, a, br, bg, bb, ba)
	local btn = CreateFrame("Button", nil, ov)
	btn:SetSize(w, h)
	btn:SetPoint(pt, ov, pt, ox, oy)
	btn:SetFrameLevel(ov:GetFrameLevel() + levelOff)
	btn:SetBackdrop(MINI_BTN_BACKDROP)
	btn:SetBackdropColor(r, g, b, a)
	btn:SetBackdropBorderColor(br, bg, bb, ba)
	btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	return btn
end

function NS.RegisterMovableBox(key, title, frame)
	NS.MovableFrames[key] = frame
	frame._azsMinUI = true
	frame.boxKey = key
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)

	local ov = CreateFrame("Frame", nil, frame)
	ov._azsMinUI = true
	ov:SetAllPoints(frame)
	ov:SetFrameLevel(frame:GetFrameLevel() + 25)
	ov:SetBackdrop(OV_BACKDROP)
	ov:SetBackdropColor(0.0, 0.36, 0.32, 0.45)
	ov:SetBackdropBorderColor(0.0, 0.92, 0.78, 0.95)
	ov:EnableMouse(true)
	ov:EnableMouseWheel(true)
	ov:RegisterForDrag("LeftButton")
	ov.boxKey, ov.boxTitle = key, title

	local lbl = NS.CreateFontText(ov, -1, "CENTER")
	lbl:SetPoint("CENTER", ov, "CENTER", 0, 0)
	lbl:SetText("|cff00ffcc" .. title .. "|r")
	ov.lbl = lbl

	local eyeBtn = CreateOverlayMiniBtn(ov, 20, 18, "TOPRIGHT", -3, -3, 4, 0.05, 0.06, 0.09, 0.90, 0.65, 0.65, 0.70, 0.85)
	eyeBtn.txt = NS.CreateFontText(eyeBtn, -3, "CENTER")
	eyeBtn.txt:SetPoint("CENTER", 0, 0)
	eyeBtn.txt:SetText("|cff44ff66V|r")
	eyeBtn:SetScript("OnClick", function()
		local DB = NS.DB
		if not DB then return end
		local modKey = NS.BOX_TO_MODULE and NS.BOX_TO_MODULE[key]
		if modKey and modKey ~= "DamageFeed" then
			local nxt = (NS.GetModuleMode(modKey) == "minimal") and "off" or "minimal"
			NS.PlayUISound(nxt == "minimal" and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
			NS.SetModuleMode(modKey, nxt)
		else
			DB.hiddenBoxes[key] = not DB.hiddenBoxes[key]
			NS.PlayUISound(DB.hiddenBoxes[key] and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOn")
			if NS.EditorHooks.RefreshAll then NS.EditorHooks.RefreshAll() end
		end
		if NS.EditorHooks.SelectBoxByKey then NS.EditorHooks.SelectBoxByKey(key, false) end
	end)
	ov.eyeBtn = eyeBtn

	local grip = CreateOverlayMiniBtn(ov, 20, 20, "BOTTOMRIGHT", 2, -2, 5, 0.18, 0.14, 0.04, 0.95, 1.0, 0.82, 0.25, 1.0)
	grip.tex = grip:CreateTexture(nil, "ARTWORK")
	grip.tex:SetSize(11, 11)
	grip.tex:SetPoint("CENTER", 0, 0)
	grip.tex:SetTexture(NS.OwnMedia("pin_diamond"))
	grip.tex:SetVertexColor(1.0, 0.86, 0.32, 1.0)
	grip:SetScript("OnMouseDown", function(self, btn)
		local DB = NS.DB
		if btn ~= "LeftButton" or not DB or DB.locked then return end
		if NS.EditorHooks.SelectBoxByKey then NS.EditorHooks.SelectBoxByKey(key, false) end
		local cx, cy = GetCursorPosition()
		local uiScale = UIParent:GetEffectiveScale()
		local cfg = DB.boxes[key]
		local startScale = (cfg and cfg.scale) or 1.0
		local startRadius = (key == "Compass" and DB.compass and DB.compass.radius) or 152
		NS.PlayUISound("UChatScrollButton")
		self:SetScript("OnUpdate", function()
			local nx, ny = GetCursorPosition()
			local delta = ((nx - cx) - (ny - cy)) / uiScale * 0.5
			if key == "Compass" and DB.compass then
				local newR = Round(Clamp(startRadius + delta, 80, 260))
				if newR ~= DB.compass.radius then
					DB.compass.radius = newR
					local d = newR * 2 + 24
					frame:SetSize(d, d)
					lbl:SetText(fmt("|cffffea89%s|r\n|cff00ffccRadius: %dpx|r", title, newR))
					if NS.EditorHooks.SyncUI then NS.EditorHooks.SyncUI() end
				end
			elseif cfg then
				local newSc = floor(Clamp(startScale + delta / 160, 0.55, 1.80) * 100 + 0.5) / 100
				if newSc ~= cfg.scale then
					cfg.scale = newSc
					frame:SetScale(newSc)
					lbl:SetText(fmt("|cffffea89%s|r\n|cff00ffccScale: %.0f%%|r", title, newSc * 100))
					if NS.EditorHooks.SyncUI then NS.EditorHooks.SyncUI() end
				end
			end
		end)
	end)
	local function StopGripResize(self)
		self:SetScript("OnUpdate", nil)
		if NS.EditorHooks.RefreshOverlays then NS.EditorHooks.RefreshOverlays() end
		if NS.EditorHooks.SyncUI then NS.EditorHooks.SyncUI() end
	end
	grip:SetScript("OnMouseUp", StopGripResize)
	grip:SetScript("OnHide", StopGripResize)
	ov.grip = grip

	ov:SetScript("OnMouseUp", function(_, btn)
		if not NS.DB or NS.DB.locked then return end
		if NS.EditorHooks.SelectBoxByKey then NS.EditorHooks.SelectBoxByKey(key, btn == "RightButton") end
	end)
	ov:SetScript("OnMouseWheel", function(_, delta)
		local DB = NS.DB
		if not DB or DB.locked then return end
		if NS.EditorHooks.SelectBoxByKey then NS.EditorHooks.SelectBoxByKey(key, false) end
		if key == "Compass" and DB.compass then
			DB.compass.radius = Clamp((DB.compass.radius or 152) + delta * 8, 80, 260)
			local d = DB.compass.radius * 2 + 24
			frame:SetSize(d, d)
		elseif DB.boxes and DB.boxes[key] then
			local sc = floor(Clamp((DB.boxes[key].scale or 1.0) + delta * 0.05, 0.55, 1.80) * 100 + 0.5) / 100
			DB.boxes[key].scale = sc
			frame:SetScale(sc)
		end
		if NS.EditorHooks.RefreshOverlays then NS.EditorHooks.RefreshOverlays() end
		if NS.EditorHooks.SyncUI then NS.EditorHooks.SyncUI() end
	end)
	ov:SetScript("OnDragStart", function()
		if NS.DB and not NS.DB.locked then
			if NS.EditorHooks.SelectBoxByKey then NS.EditorHooks.SelectBoxByKey(key, false) end
			frame:StartMoving()
		end
	end)
	ov:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local p, _, rp, x, y = frame:GetPoint()
		local DB = NS.DB
		local cfg = DB and DB.boxes and DB.boxes[key]
		if cfg then
			if DB.snapToGrid then
				x, y = Round(x / 8) * 8, Round(y / 8) * 8
				frame:ClearAllPoints()
				frame:SetPoint(p, UIParent, rp, x, y)
			else
				x, y = Round(x), Round(y)
			end
			cfg.point, cfg.relPoint, cfg.x, cfg.y = p, rp, x, y
		end
		if NS.EditorHooks.RefreshOverlays then NS.EditorHooks.RefreshOverlays() end
		if NS.EditorHooks.SyncUI then NS.EditorHooks.SyncUI() end
	end)
	ov:Hide()
	NS.DragOverlays[key] = ov
end

function NS.RestoreBoxLayout(key, frame)
	local DB = NS.DB
	local cfg = DB and DB.boxes and DB.boxes[key]
	if not cfg then return end
	frame:ClearAllPoints()
	if key == "Compass" and DB.compass then
		local d = (DB.compass.radius or 152) * 2 + 24
		frame:SetSize(d, d)
	else
		frame:SetSize(cfg.width, cfg.height)
	end
	frame:SetScale(cfg.scale or 1.0)
	frame:SetPoint(cfg.point or "CENTER", UIParent, cfg.relPoint or "CENTER", cfg.x or 0, cfg.y or 0)
	if NS.BORDERLESS_BOXES[key] then
		frame:SetBackdrop(nil)
		frame:SetAlpha(Clamp(cfg.frameAlpha or 1.0, 0.15, 1.0))
	else
		frame:SetAlpha(1.0)
		local a = (cfg.alpha ~= nil) and cfg.alpha or DB.bgAlpha
		NS.ApplyAzeriteTooltipBorder(frame, a, (a and a > 0.01) and DB.borderAlpha or 0)
	end
	if ALWAYS_TOGGLE_VIS[key] then
		if NS.IsBoxHidden(key) and (not DB or DB.locked) then frame:Hide() else frame:Show() end
	end
end

function NS.RefreshAllLayouts()
	for key, frame in pairs(NS.MovableFrames) do NS.RestoreBoxLayout(key, frame) end
	NS.RefreshAllFonts()
	if NS.EditorHooks.RefreshOverlays then NS.EditorHooks.RefreshOverlays() end
end
