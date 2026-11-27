local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local tonumber, type, pcall, fmt = tonumber, type, pcall, string.format
local SetText, FormatNumber, RGBToHex = NS.SetText, NS.FormatNumber, NS.RGBToHex

local Pill = CreateFrame("Frame", "AZS_MinUI_HolidayCurrency", UIParent)
NS.RegisterMovableBox("HolidayCurrency", "Holiday Currency", Pill)
Pill:EnableMouse(true)

Pill.icon = Pill:CreateTexture(nil, "ARTWORK")
Pill.icon:SetSize(18, 18)
Pill.icon:SetPoint("LEFT", Pill, "LEFT", 10, 0)
Pill.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

Pill.val = NS.CreateFontText(Pill, 0, "RIGHT")
Pill.val:SetPoint("RIGHT", Pill, "RIGHT", -10, 0)

Pill.name = NS.CreateFontText(Pill, 0, "LEFT")
Pill.name:SetPoint("LEFT", Pill.icon, "RIGHT", 6, 0)
Pill.name:SetPoint("RIGHT", Pill.val, "LEFT", -6, 0)
NS.SetNoWrap(Pill.name, 14)

Pill:SetScript("OnEnter", function(self)
	if not (GameTooltip and self._name) then return end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText(self._name, self._r or 1, self._g or 0.7, self._b or 0.2)
	GameTooltip:AddLine("Holiday event currency collected this run.", 0.80, 0.86, 0.92)
	GameTooltip:Show()
end)
Pill:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
Pill:Hide()

local Mod = { frame = Pill }
function Mod.Update(ctx)
	if NS.GetModuleMode("HolidayCurrency") ~= "minimal" or NS.IsBoxHidden("HolidayCurrency") then
		if not ctx.isEditing and Pill:IsShown() then Pill:Hide() end
		if NS.GetModuleMode("HolidayCurrency") ~= "minimal" or not ctx.isEditing then return end
	end

	local ev = _G.AZS_EVENT
	local key = (type(ev) == "table" and ev.key and ev.key ~= "") and ev.key or nil
	local count = (type(ev) == "table" and tonumber(ev.n)) or 0
	local cName, cIcon, cRgb
	if key and type(_G.AZS_EventCurrency) == "function" then
		local ok, n, ic, rgb = pcall(_G.AZS_EventCurrency, key)
		if ok and n then cName, cIcon, cRgb = n, ic, rgb end
	end

	if not cName then
		if ctx.isEditing then
			Pill._name, Pill._r, Pill._g, Pill._b = "Holiday Currency", 1.0, 0.55, 0.15
			if Pill._icon ~= "Interface\\Icons\\Achievement_Halloween_Candy_01" then
				Pill._icon = "Interface\\Icons\\Achievement_Halloween_Candy_01"
				Pill.icon:SetTexture(Pill._icon)
			end
			SetText(Pill.name, "|cffff8c26Candy Corn|r")
			SetText(Pill.val, "|cffffffff+42|r")
			Pill:Show()
			return
		end
		if Pill:IsShown() then Pill:Hide() end
		return
	end

	local r, g, b = (cRgb and cRgb[1]) or 1.0, (cRgb and cRgb[2]) or 0.72, (cRgb and cRgb[3]) or 0.22
	Pill._name, Pill._r, Pill._g, Pill._b = cName, r, g, b
	if cIcon and Pill._icon ~= cIcon then Pill._icon = cIcon; Pill.icon:SetTexture(cIcon) end
	SetText(Pill.name, RGBToHex(r, g, b) .. cName .. "|r")
	SetText(Pill.val, fmt("|cffffffff+%s|r", FormatNumber(count)))
	Pill:Show()
end

NS.Modules.HolidayCurrency = Mod
