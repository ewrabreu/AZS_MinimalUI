local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local tonumber, type, fmt = tonumber, type, string.format
local COLORS, SetText = NS.COLORS, NS.SetText

local StoredBadge = CreateFrame("Button", "AZS_MinUI_StoredBadge", UIParent)
NS.RegisterMovableBox("StoredBadge", "Revive Alert", StoredBadge)
StoredBadge:EnableMouse(true)

StoredBadge.txt = NS.CreateFontText(StoredBadge, 2, "CENTER")
StoredBadge.txt:SetPoint("CENTER", StoredBadge, "CENTER", 14, 0)

StoredBadge.plate = StoredBadge:CreateTexture(nil, "ARTWORK")
StoredBadge.plate:SetSize(28, 28)
StoredBadge.plate:SetPoint("RIGHT", StoredBadge.txt, "LEFT", -6, 0)
StoredBadge.plate:SetTexture(NS.Media("point_plate"))
StoredBadge.plate:SetVertexColor(COLORS.crystalCase[1], COLORS.crystalCase[2], COLORS.crystalCase[3], 1)

StoredBadge.gem = StoredBadge:CreateTexture(nil, "OVERLAY")
StoredBadge.gem:SetSize(16, 16)
StoredBadge.gem:SetPoint("CENTER", StoredBadge.plate, "CENTER", 0, 0)
StoredBadge.gem:SetTexture(NS.Media("point_hearth"))
StoredBadge.gem:SetVertexColor(1.0, 0.82, 0.20, 1)
StoredBadge:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
StoredBadge:SetScript("OnClick", function()
	if type(_G.AZS_OpenStoredLevels) == "function" then _G.AZS_OpenStoredLevels() end
end)
StoredBadge:Hide()

local lastRed = false
local Mod = { frame = StoredBadge }
function Mod.ApplyTheme()
	StoredBadge.plate:SetVertexColor(COLORS.crystalCase[1], COLORS.crystalCase[2], COLORS.crystalCase[3], 1)
end
function Mod.Update(ctx)
	local hidden = NS.IsBoxHidden("StoredBadge")
	local revive = _G.AZS_REVIVE
	if not hidden and revive and (tonumber(revive.down) or 0) > 0 then
		if not lastRed then lastRed = true; StoredBadge.gem:SetVertexColor(1.0, 0.20, 0.20, 1) end
		SetText(StoredBadge.txt, fmt("|cffff4444Ally Down! (%.0f%%)|r", (tonumber(revive.rshare) or 0) * 100))
		StoredBadge:Show()
	elseif ctx.isEditing then
		if not lastRed then lastRed = true; StoredBadge.gem:SetVertexColor(1.0, 0.20, 0.20, 1) end
		SetText(StoredBadge.txt, "|cffff6666Ally Down! (Revive Preview)|r")
		StoredBadge:Show()
	elseif StoredBadge:IsShown() then
		StoredBadge:Hide()
	end
end

NS.Modules.StoredBadge = Mod
