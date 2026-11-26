local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local tonumber, type, fmt = tonumber, type, string.format
local COLORS, SetText = NS.COLORS, NS.SetText

local StoredBadge = CreateFrame("Button", "AZS_MinUI_StoredBadge", UIParent)
NS.RegisterMovableBox("StoredBadge", "Stored Levels [T]", StoredBadge)
StoredBadge:EnableMouse(true)

StoredBadge.plate = StoredBadge:CreateTexture(nil, "ARTWORK")
StoredBadge.plate:SetSize(32, 32)
StoredBadge.plate:SetPoint("LEFT", StoredBadge, "LEFT", 8, 0)
StoredBadge.plate:SetTexture(NS.Media("point_plate"))
StoredBadge.plate:SetVertexColor(COLORS.crystalCase[1], COLORS.crystalCase[2], COLORS.crystalCase[3], 1)

StoredBadge.gem = StoredBadge:CreateTexture(nil, "OVERLAY")
StoredBadge.gem:SetSize(18, 18)
StoredBadge.gem:SetPoint("CENTER", StoredBadge.plate, "CENTER", 0, 0)
StoredBadge.gem:SetTexture(NS.Media("point_hearth"))
StoredBadge.gem:SetVertexColor(1.0, 0.82, 0.20, 1)

StoredBadge.txt = NS.CreateFontText(StoredBadge, 0, "LEFT")
StoredBadge.txt:SetPoint("LEFT", StoredBadge.plate, "RIGHT", 4, 0)
StoredBadge.txt:SetPoint("RIGHT", StoredBadge, "RIGHT", -10, 0)
StoredBadge:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
StoredBadge:SetScript("OnClick", function()
	if type(_G.AZS_OpenStoredLevels) == "function" then _G.AZS_OpenStoredLevels() end
end)
StoredBadge:Hide()

local lastRed = false
local Mod = { frame = StoredBadge }
function Mod.Update(ctx)
	local hidden = NS.IsBoxHidden("StoredBadge")
	local run, revive = ctx.run, _G.AZS_REVIVE
	local sl = (type(_G.AZS_GetStoredLevels) == "function" and tonumber(_G.AZS_GetStoredLevels())) or (run and tonumber(run.sl)) or 0
	if not hidden and revive and (tonumber(revive.down) or 0) > 0 then
		if not lastRed then lastRed = true; StoredBadge.gem:SetVertexColor(1.0, 0.20, 0.20, 1) end
		SetText(StoredBadge.txt, fmt("|cffff4444Ally Down! (%.0f%%)|r", (tonumber(revive.rshare) or 0) * 100))
		StoredBadge:Show()
	elseif not hidden and sl > 0 then
		if lastRed then lastRed = false; StoredBadge.gem:SetVertexColor(1.0, 0.82, 0.20, 1) end
		SetText(StoredBadge.txt, fmt("|cffffea89[T] +%d Levels|r |cffbbbbbb(RR:%d)|r", sl, (run and tonumber(run.rr)) or 0))
		StoredBadge:Show()
	elseif ctx.isEditing then
		if lastRed then lastRed = false; StoredBadge.gem:SetVertexColor(1.0, 0.82, 0.20, 1) end
		SetText(StoredBadge.txt, "|cffffea89[T] +3 Levels (Preview)|r")
		StoredBadge:Show()
	elseif StoredBadge:IsShown() then
		StoredBadge:Hide()
	end
end

NS.Modules.StoredBadge = Mod
