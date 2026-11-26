local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local tonumber, type, fmt = tonumber, type, string.format
local COLORS, Clamp, SetText, GetSpellIcon = NS.COLORS, NS.Clamp, NS.SetText, NS.GetSpellIcon

local MeterPanel = CreateFrame("Frame", "AZS_MinUI_MeterPanel", UIParent)
NS.RegisterMovableBox("MeterPanel", "DPS Meter", MeterPanel)

MeterPanel.roleIcon = MeterPanel:CreateTexture(nil, "ARTWORK")
MeterPanel.roleIcon:SetSize(16, 16)
MeterPanel.roleIcon:SetPoint("TOPLEFT", MeterPanel, "TOPLEFT", 14, -12)
MeterPanel.roleIcon:SetTexture(NS.Media("grouprole-icons-dps"))
MeterPanel.header = NS.CreateFontText(MeterPanel, 0, "LEFT")
MeterPanel.header:SetPoint("LEFT", MeterPanel.roleIcon, "RIGHT", 4, 0)
MeterPanel.header:SetText("|cffffea89DPS METER|r")
MeterPanel.dpsTotal = NS.CreateFontText(MeterPanel, 0, "RIGHT")
MeterPanel.dpsTotal:SetPoint("TOPRIGHT", MeterPanel, "TOPRIGHT", -14, -12)

local NUM_METER_ROWS = 6
local MeterRows = {}
for i = 1, NUM_METER_ROWS do
	local row = CreateFrame("Frame", nil, MeterPanel)
	row:SetHeight(25)
	row:SetPoint("TOPLEFT",  MeterPanel, "TOPLEFT",   14, -36 - (i - 1) * 27)
	row:SetPoint("TOPRIGHT", MeterPanel, "TOPRIGHT", -14, -36 - (i - 1) * 27)
	row.iconHolder = CreateFrame("Frame", nil, row)
	row.iconHolder:SetSize(18, 18)
	row.iconHolder:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon = row.iconHolder:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if row.icon.SetMask then row.icon:SetMask(NS.Media("actionbutton-mask-square")) end
	row.iconBorder = NS.AttachAuraBorder(row.iconHolder, 8, 3)
	row.val = NS.CreateFontText(row, -2, "RIGHT")
	row.val:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	row.name = NS.CreateFontText(row, -2, "LEFT")
	row.name:SetPoint("TOPLEFT", row.iconHolder, "TOPRIGHT", 7, 0)
	row.name:SetPoint("RIGHT", row.val, "LEFT", -6, 0)
	NS.SetNoWrap(row.name, 12)
	row.barFrame, row.bar, row.barBg = NS.CreateThinBar(row, 4, COLORS.normal)
	row.barFrame:SetPoint("BOTTOMLEFT",  row.iconHolder, "BOTTOMRIGHT", 7, 1)
	row.barFrame:SetPoint("BOTTOMRIGHT", row,            "BOTTOMRIGHT", 0, 1)
	row:Hide()
	MeterRows[i] = row
end

local Mod = { frame = MeterPanel }
function Mod.Update(ctx)
	if NS.IsBoxHidden("MeterPanel") and not ctx.isEditing then return end
	local meterLines, totalDps = NS.GetMeterCached(ctx.tickId)
	SetText(MeterPanel.dpsTotal, "|cffffea89" .. NS.FormatNumber(totalDps) .. "/s|r")
	local hasTable = (type(meterLines) == "table")
	for i = 1, NUM_METER_ROWS do
		local row = MeterRows[i]
		local m = hasTable and meterLines[i] or nil
		if m then
			local icon = GetSpellIcon(m.spell)
			if row._icon ~= icon then row._icon = icon; row.icon:SetTexture(icon) end
			SetText(row.name, m.name or "Skill")
			local share = tonumber(m.share) or 0
			if share <= 1.0 and share > 0 then share = share * 100 end
			share = Clamp(share, 0, 100)
			SetText(row.val, fmt("%s/s |cffaaaaaa(%.0f%%)|r", NS.FormatNumber(m.dps or 0), share))
			row.bar:SetValue(share)
			row:Show()
		elseif row:IsShown() then
			row:Hide()
		end
	end
end

NS.Modules.MeterPanel = Mod
