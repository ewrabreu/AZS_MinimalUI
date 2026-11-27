local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local max, min, type, pcall, fmt = math.max, math.min, type, pcall, string.format
local COLORS, SetText = NS.COLORS, NS.SetText

local TEX_DARKNESS = "Interface\\Icons\\Spell_Shadow_NetherCloak"
local TEX_BLANK    = NS.OwnMedia("blank")

local ExtraFrame = CreateFrame("Button", "AZS_MinUI_ClassExtra", UIParent)
NS.RegisterMovableBox("ClassExtra", "Class Extra (Darkness)", ExtraFrame)
ExtraFrame:RegisterForClicks("LeftButtonUp")

ExtraFrame.icon = ExtraFrame:CreateTexture(nil, "ARTWORK")
ExtraFrame.icon:SetAllPoints(ExtraFrame)
ExtraFrame.icon:SetTexture(TEX_DARKNESS)
ExtraFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

ExtraFrame.cdOverlay = ExtraFrame:CreateTexture(nil, "OVERLAY")
ExtraFrame.cdOverlay:SetPoint("BOTTOMLEFT", ExtraFrame.icon, "BOTTOMLEFT", 0, 0)
ExtraFrame.cdOverlay:SetPoint("BOTTOMRIGHT", ExtraFrame.icon, "BOTTOMRIGHT", 0, 0)
ExtraFrame.cdOverlay:SetHeight(1)
ExtraFrame.cdOverlay:SetTexture(TEX_BLANK)
ExtraFrame.cdOverlay:SetVertexColor(0, 0, 0, 0.72)
ExtraFrame.cdOverlay:Hide()

ExtraFrame.txtLayer = CreateFrame("Frame", nil, ExtraFrame)
ExtraFrame.txtLayer:SetAllPoints(ExtraFrame)
ExtraFrame.txtLayer:SetFrameLevel(ExtraFrame:GetFrameLevel() + 4)
ExtraFrame.cdText = NS.CreateFontText(ExtraFrame.txtLayer, 2, "CENTER")
ExtraFrame.cdText:SetPoint("CENTER", ExtraFrame.txtLayer, "CENTER", 0, 0)
ExtraFrame.keyText = NS.CreateFontText(ExtraFrame.txtLayer, -2, "RIGHT")
ExtraFrame.keyText:SetPoint("TOPRIGHT", ExtraFrame.txtLayer, "TOPRIGHT", -3, -2)

ExtraFrame:SetScript("OnClick", function()
	if type(_G.AZS_Darkness) == "function" then pcall(_G.AZS_Darkness) end
end)
ExtraFrame:SetScript("OnEnter", function(self)
	if not GameTooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText("Path of Darkness", 0.76, 0.42, 1.0)
	local key = (type(_G.GetBindingKey) == "function" and _G.GetBindingKey("AZS_DARKNESS")) or "1"
	GameTooltip:AddLine("Click or press [" .. key .. "] to trigger Darkness.", 0.82, 0.88, 0.94)
	if self._on and self._left and self._left > 0.05 then
		GameTooltip:AddLine(fmt("Active: %.1fs remaining", self._left), 0.35, 1.0, 0.65)
	elseif self._cd and self._cd > 0.05 then
		GameTooltip:AddLine(fmt("Cooldown: %.1fs", self._cd), 1.0, 0.82, 0.25)
	else
		GameTooltip:AddLine("Status: Ready", 0.40, 1.0, 0.65)
	end
	GameTooltip:Show()
end)
ExtraFrame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
ExtraFrame:Hide()

local Mod = { frame = ExtraFrame }
function Mod.Update(ctx)
	if NS.GetModuleMode("ClassExtra") ~= "minimal" or NS.IsBoxHidden("ClassExtra") then
		if not ctx.isEditing and ExtraFrame:IsShown() then ExtraFrame:Hide() end
		if NS.GetModuleMode("ClassExtra") ~= "minimal" or not ctx.isEditing then return end
	end

	local has, ready, on, cd, cdmax, left = false, false, false, 0, 1, 0
	if type(_G.AZS_DarknessState) == "function" then
		local ok, h, r, o, c, cm, l = pcall(_G.AZS_DarknessState)
		if ok then has, ready, on, cd, cdmax, left = h, r, o, c or 0, cm or 1, l or 0 end
	end

	if not has and not ctx.isEditing then
		if ExtraFrame:IsShown() then ExtraFrame:Hide() end
		return
	end

	ExtraFrame:Show()
	ExtraFrame._on, ExtraFrame._cd, ExtraFrame._left = on, cd, left
	local bind = (type(_G.GetBindingKey) == "function" and _G.GetBindingKey("AZS_DARKNESS")) or "1"
	SetText(ExtraFrame.keyText, "|cffc4b5fd" .. bind .. "|r")

	if not has and ctx.isEditing then
		ExtraFrame.cdOverlay:Hide()
		ExtraFrame.icon:SetVertexColor(1, 1, 1, 1)
		SetText(ExtraFrame.cdText, "")
		return
	end

	if on and left > 0.05 then
		ExtraFrame.cdOverlay:Hide()
		ExtraFrame.icon:SetVertexColor(1, 1, 1, 1)
		SetText(ExtraFrame.cdText, fmt("|cff44ffaa%.1f|r", left))
	elseif cd > 0.05 and not ready then
		local h = max(1, ExtraFrame:GetHeight() or 46)
		ExtraFrame.cdOverlay:SetHeight(max(1, h * min(1.0, cd / max(0.5, cdmax))))
		ExtraFrame.cdOverlay:Show()
		ExtraFrame.icon:SetVertexColor(0.45, 0.45, 0.52, 1)
		SetText(ExtraFrame.cdText, fmt("|cffffd100%.1f|r", cd))
	else
		ExtraFrame.cdOverlay:Hide()
		ExtraFrame.icon:SetVertexColor(1, 1, 1, 1)
		SetText(ExtraFrame.cdText, "")
	end
end

NS.Modules.ClassExtra = Mod
