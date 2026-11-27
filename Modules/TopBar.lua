local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, max, tonumber, tostring, fmt = math.floor, math.max, tonumber, tostring, string.format
local COLORS, SetText, FormatTime, FormatNumber = NS.COLORS, NS.SetText, NS.FormatTime, NS.FormatNumber

local TEX_EYE_GREEN  = NS.Media("group-finder-eye-green")
local TEX_EYE_ORANGE = NS.Media("group-finder-eye-orange")
local TEX_EYE_RED    = NS.Media("group-finder-eye-red")
local TEX_EYE_PURPLE = NS.Media("group-finder-eye-purple")
local TEX_BADGE_BOSS = NS.Media("icon_badges_boss")
local TEX_CLS_BOSS   = NS.Media("icon_classification_boss")
local TEX_CLS_GEN    = NS.Media("icon_classification_generic")
local TEX_SKULL      = NS.Media("icon_skull")

local TopBar = CreateFrame("Frame", "AZS_MinUI_TopBar", UIParent)
NS.RegisterMovableBox("TopBar", "Top Bar", TopBar)

TopBar.eyeIcon = TopBar:CreateTexture(nil, "ARTWORK")
TopBar.eyeIcon:SetSize(22, 22)
TopBar.eyeIcon:SetPoint("LEFT", TopBar, "LEFT", 12, 0)
TopBar.eyeIcon:SetTexture(TEX_EYE_GREEN)
TopBar.leftText = NS.CreateFontText(TopBar, 0, "LEFT")
TopBar.leftText:SetPoint("LEFT", TopBar.eyeIcon, "RIGHT", 6, 0)
TopBar.centerText = NS.CreateFontText(TopBar, 2, "CENTER")
TopBar.centerText:SetPoint("CENTER", TopBar, "CENTER", -45, 0)
TopBar.centerIcon = TopBar:CreateTexture(nil, "ARTWORK")
TopBar.centerIcon:SetSize(18, 18)
TopBar.centerIcon:SetPoint("RIGHT", TopBar.centerText, "LEFT", -5, 0)
TopBar.centerIcon:SetTexture(TEX_CLS_BOSS)

local ConfigBtn = CreateFrame("Button", "AZS_MinUI_ConfigBtn", TopBar)
ConfigBtn:SetSize(24, 24)
ConfigBtn:SetPoint("RIGHT", TopBar, "RIGHT", -10, 0)
ConfigBtn.tex = ConfigBtn:CreateTexture(nil, "ARTWORK")
ConfigBtn.tex:SetAllPoints()
ConfigBtn.tex:SetTexture(NS.Media("config_button"))
ConfigBtn.tex:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
ConfigBtn:SetHighlightTexture(NS.Media("config_button_bright"), "ADD")
ConfigBtn:SetScript("OnClick", function() if NS.ToggleEditor then NS.ToggleEditor() end end)

TopBar.rightText = NS.CreateFontText(TopBar, 0, "RIGHT")
TopBar.rightText:SetPoint("RIGHT", ConfigBtn, "LEFT", -8, 0)

local lastEyeTex, lastCenterTex
local function SetTex(texObj, path, isEye)
	if isEye then
		if lastEyeTex ~= path then lastEyeTex = path; texObj:SetTexture(path) end
	elseif lastCenterTex ~= path then
		lastCenterTex = path; texObj:SetTexture(path)
	end
end

local Mod = { frame = TopBar, configBtn = ConfigBtn }
function Mod.ApplyTheme()
	ConfigBtn.tex:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
end
function Mod.Update(ctx)
	if NS.IsBoxHidden("TopBar") and not ctx.isEditing then return end
	local th = NS.ACTIVE_THEME
	local titleHex = (th and th.hex and th.hex.title) or "|cffffea89"
	local accHex   = (th and th.hex and th.hex.accent) or "|cffffd100"
	local bossHex  = (th and th.hex and th.hex.boss) or "|cffff8c1a"
	local rareHex  = (th and th.hex and th.hex.rare) or "|cffcc66ff"
	local zone, run = ctx.zone, ctx.run
	if not ctx.inHub and zone and run then
		local zname = zone.zname or zone.zone or "Azeroth"
		local diff = zone.diff or ("T" .. tostring(zone.dt or 0))
		local heroic = (tonumber(zone.heroic) or 0) > 0 and (" |cffff5555H" .. zone.heroic .. "|r") or ""
		SetText(TopBar.leftText, fmt("%s%s|r |cffbbbbbb[%s%s]|r  |cffffffff%s|r", titleHex, zname, diff, heroic, FormatTime(ctx.runClock)))

		local nbs, nbc, nb = run.nbs, tonumber(run.nbc) or 0, tonumber(run.nb) or -1
		local bossStatus, cTex
		if nbs == "up" then
			cTex, bossStatus = TEX_BADGE_BOSS, fmt("%sBOSS #%d ACTIVE|r", bossHex, nbc)
		elseif nbs == "known" then
			cTex = TEX_CLS_BOSS
			local bname = (run.nbn and run.nbn ~= "") and run.nbn or ("Boss #" .. nbc)
			if run.nbm == "rift" and run.rift ~= nil then
				bossStatus = fmt("%sRift %d%%|r · %s%s|r%s", rareHex, tonumber(run.rift) or 0, titleHex, bname, nb >= 0 and (" (" .. FormatTime(nb) .. ")") or "")
			elseif nb >= 0 then
				bossStatus = fmt("%s%s|r in |cffffffff%s|r", titleHex, bname, FormatTime(nb))
			else
				bossStatus = titleHex .. bname .. "|r"
			end
		elseif nbs == "unknown" then
			cTex = TEX_SKULL
			bossStatus = nb >= 0 and fmt("%sEndless #%d|r in |cffffffff%s|r", bossHex, nbc, FormatTime(nb)) or fmt("%sEndless #%d|r", bossHex, nbc)
		else
			cTex = TEX_CLS_GEN
			local left = tonumber(run.left) or -1
			bossStatus = left >= 0 and ("Final: |cffffffff" .. FormatTime(left) .. "|r") or (accHex .. tostring(run.ph or "In Run") .. "|r")
		end
		SetTex(TopBar.centerIcon, cTex, false)
		SetText(TopBar.centerText, bossStatus)

		local swarmPct = floor(((tonumber(run.en) or 0) / max(1, tonumber(run.enm) or 100)) * 100)
		local swarmColor, eyeTex = "|cff66ff88", TEX_EYE_GREEN
		if swarmPct >= 80 then swarmColor, eyeTex = "|cffff3333", TEX_EYE_RED
		elseif swarmPct >= 50 then swarmColor, eyeTex = "|cffffcc00", TEX_EYE_ORANGE end
		SetTex(TopBar.eyeIcon, eyeTex, true)
		SetText(TopBar.rightText, fmt("Horde: %s%d%%|r  Kills: |cffffffff%s|r %s(E:%d)|r  Gold: |cffffd700%s|r |cffaaaaaa(Cache:%s)|r",
			swarmColor, swarmPct, FormatNumber(run.kills), accHex, tonumber(run.ek) or 0, FormatNumber(run.gold), FormatNumber(run.cache)))
	else
		SetTex(TopBar.eyeIcon, TEX_EYE_PURPLE, true)
		SetTex(TopBar.centerIcon, TEX_BADGE_BOSS, false)
		local thName = (th and th.name) or "Classic"
		SetText(TopBar.leftText, fmt("%sAZS Minimal UI|r |cffaaaaaa(%s · v%s)|r", titleHex, thName, NS.VERSION))
		SetText(TopBar.centerText, "|cffdddddd90% Free Screen · 360° Compass · ARPG HUD|r")
		SetText(TopBar.rightText, accHex .. "/minui|r |cffaaaaaato edit|r")
	end
end

NS.Modules.TopBar = Mod
