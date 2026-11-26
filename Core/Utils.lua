local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, max, min = math.floor, math.max, math.min
local fmt, find = string.format, string.find
local tonumber, type, pairs, pcall = tonumber, type, pairs, pcall
local GetSpellInfo = GetSpellInfo
local COLORS, FONTS = NS.COLORS, NS.FONTS
local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local mediaCache, ownMediaCache, spellIconCache = {}, {}, {}
function NS.Media(name)
	local p = mediaCache[name]
	if not p then p = NS.AZS_MEDIA .. name .. ".tga"; mediaCache[name] = p end
	return p
end
function NS.OwnMedia(name)
	local p = ownMediaCache[name]
	if not p then p = NS.OWN_MEDIA .. name .. ".tga"; ownMediaCache[name] = p end
	return p
end

NS.QUESTION_ICON = QUESTION_ICON
NS.Wipe = _G.wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
function NS.Clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
function NS.Round(v) return floor(v + 0.5) end
function NS.SplitCSV(str, dst)
	dst = dst or {}
	for w in string.gmatch(str, "[^,]+") do dst[#dst + 1] = w end
	return dst
end
function NS.SplitSet(str, prefix)
	local out = {}
	prefix = prefix or ""
	for w in string.gmatch(str, "[^,]+") do out[prefix .. w] = true end
	return out
end

function NS.PlayUISound(soundName)
	if type(_G.PlaySound) == "function" then pcall(_G.PlaySound, soundName) end
end

function NS.CopyDefaults(src, dst)
	if type(src) ~= "table" then return {} end
	if type(dst) ~= "table" then dst = {} end
	for k, v in pairs(src) do
		if type(v) == "table" then dst[k] = NS.CopyDefaults(v, dst[k])
		elseif dst[k] == nil or type(dst[k]) ~= type(v) then dst[k] = v end
	end
	return dst
end

function NS.DeepCopy(src)
	if type(src) ~= "table" then return src end
	local out = {}
	for k, v in pairs(src) do out[k] = NS.DeepCopy(v) end
	return out
end

function NS.GetFontPath()
	local idx = (NS.DB and NS.DB.fontIndex) or 1
	return (FONTS[idx] and FONTS[idx].path) or "Fonts\\FRIZQT__.TTF"
end

function NS.RefreshAllFonts()
	local path = NS.GetFontPath()
	local baseSize = (NS.DB and NS.DB.fontSize) or 11
	local list = NS.RegisteredFonts
	for i = 1, #list do
		local item = list[i]
		item.fs:SetFont(path, max(8, baseSize + item.delta), item.outline)
	end
end

function NS.SetText(fs, txt)
	if fs.__t ~= txt then fs.__t = txt; fs:SetText(txt) end
end

function NS.SetNoWrap(fs, h)
	if h then fs:SetHeight(h) end
	if fs.SetWordWrap then fs:SetWordWrap(false) end
end

function NS.FormatNumber(n)
	n = tonumber(n) or 0
	if n >= 1e18 then return fmt("%.2fQi", n / 1e18)
	elseif n >= 1e15 then return fmt("%.2fQa", n / 1e15)
	elseif n >= 1e12 then return fmt("%.2fT", n / 1e12)
	elseif n >= 1e9 then return fmt("%.2fB", n / 1e9)
	elseif n >= 1e6 then return fmt("%.2fM", n / 1e6)
	elseif n >= 1e3 then return fmt("%.1fK", n / 1e3)
	else return fmt("%.0f", n) end
end

function NS.FormatTime(sec)
	sec = tonumber(sec) or 0
	if sec < 0 then sec = 0 end
	return fmt("%d:%02d", floor(sec / 60), floor(sec % 60))
end

function NS.FormatShortTime(rem, tenthsUnder10)
	if not rem or rem <= 0 then return "" end
	if rem >= 3600 then return fmt("%dh", floor(rem / 3600 + 0.5))
	elseif rem >= 60 then return fmt("%dm", floor(rem / 60 + 0.5))
	elseif tenthsUnder10 and rem < 10 then return fmt("|cffff6666%.1f|r", rem)
	else return fmt("%ds", floor(rem + 0.5)) end
end

function NS.RGBToHex(r, g, b)
	return fmt("|cff%02x%02x%02x", floor(r * 255), floor(g * 255), floor(b * 255))
end

function NS.GetClassRGB(classToken, fr, fg, fb)
	local cc = classToken and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classToken]
	if cc then return cc.r, cc.g, cc.b end
	return fr or 0.72, fg or 0.78, fb or 0.88
end

function NS.GetSpellIcon(spellId)
	local id = tonumber(spellId) or 0
	if id <= 0 then return QUESTION_ICON end
	local cached = spellIconCache[id]
	if cached then return cached end
	local _, _, icon = GetSpellInfo(id)
	if icon then spellIconCache[id] = icon; return icon end
	return QUESTION_ICON
end

function NS.ResolveIcon(icon, spellId)
	if type(icon) == "string" and icon ~= "" then
		if find(icon, "\\", 1, true) or find(icon, "/", 1, true) then return icon end
		return "Interface\\Icons\\" .. icon
	end
	return NS.GetSpellIcon(spellId)
end

function NS.GetLairs()
	return (type(_G.AZS_GetLairs) == "function" and _G.AZS_GetLairs()) or _G.AZS_LAIRS
end

local lastMeterTick, cachedMeterLines, cachedTotalDps = -1, nil, 0
function NS.GetMeterCached(tickId)
	if tickId and tickId == lastMeterTick then return cachedMeterLines, cachedTotalDps end
	local lines, totalDps
	if type(_G.AZS_GetMeter) == "function" then
		local ok, m, _, tdps = pcall(_G.AZS_GetMeter)
		if ok then lines, totalDps = m, tdps end
	end
	lines = lines or _G.AZS_METER
	if not totalDps and type(lines) == "table" then
		local sum = 0
		for i = 1, #lines do sum = sum + (tonumber(lines[i].dps) or 0) end
		totalDps = sum
	end
	totalDps = tonumber(totalDps) or 0
	if tickId then lastMeterTick, cachedMeterLines, cachedTotalDps = tickId, lines, totalDps end
	return lines, totalDps
end

function NS.GetCombatStats(stats, rs, caps)
	local cdr  = (rs and tonumber(rs.cdr))  or (stats and stats.cd   and floor((1 - tonumber(stats.cd)) * 100 + 0.5)) or 0
	local crit = (rs and tonumber(rs.crit)) or (stats and stats.crit and floor(tonumber(stats.crit) * 100 + 0.5)) or 0
	local red  = (rs and tonumber(rs.red))  or (stats and stats.arm  and floor(tonumber(stats.arm) * 100 + 0.5)) or 0
	local echo = (rs and tonumber(rs.echo)) or (stats and stats.echo and floor(tonumber(stats.echo) * 100 + 0.5)) or 0
	return cdr, crit, red, echo,
		(caps and tonumber(caps.cdr)) or 80,
		(caps and tonumber(caps.crit)) or 100,
		(caps and tonumber(caps.red)) or 75,
		(caps and tonumber(caps.echo)) or 100
end

local BLANK_TEX = NS.OwnMedia("blank")
NS.FLAT_BACKDROP = { bgFile = BLANK_TEX, edgeFile = BLANK_TEX, tile = false, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
NS.FLAT_BACKDROP_NOINSET = { bgFile = BLANK_TEX, edgeFile = BLANK_TEX, tile = false, edgeSize = 1 }
NS.FLAT_EDGE_BACKDROP = { edgeFile = BLANK_TEX, edgeSize = 1 }

function NS.ApplyFlatBackdrop(f, bg, bd, edgeOnly)
	f:SetBackdrop(edgeOnly and NS.FLAT_EDGE_BACKDROP or NS.FLAT_BACKDROP)
	if bg and not edgeOnly then f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 0.92) end
	if bd then f:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4] or 0.85) end
end

local TOOLTIP_BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = NS.Media("border-tooltip"),
	tile = true, tileSize = 16, edgeSize = 24,
	insets = { left = 6, right = 6, top = 8, bottom = 8 },
}
function NS.ApplyAzeriteTooltipBorder(f, bgAlpha, borderAlpha)
	local bga = (bgAlpha ~= nil) and bgAlpha or ((NS.DB and NS.DB.bgAlpha) or 0.72)
	local bda = (borderAlpha ~= nil) and borderAlpha or ((NS.DB and NS.DB.borderAlpha) or 0.95)
	if bga <= 0.01 then f:SetBackdrop(nil); return end
	f:SetBackdrop(TOOLTIP_BACKDROP)
	f:SetBackdropColor(0.04, 0.05, 0.07, bga)
	f:SetBackdropBorderColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], bda)
end

local auraBorderBackdrops = {}
function NS.AttachAuraBorder(parent, edgeSz, offset)
	edgeSz = edgeSz or 12
	offset = offset or 5
	local bd = auraBorderBackdrops[edgeSz]
	if not bd then bd = { edgeFile = NS.Media("border-aura"), edgeSize = edgeSz }; auraBorderBackdrops[edgeSz] = bd end
	local border = CreateFrame("Frame", nil, parent)
	border:SetBackdrop(bd)
	border:SetBackdropBorderColor(COLORS.verydarkgray[1], COLORS.verydarkgray[2], COLORS.verydarkgray[3], 1)
	border:SetPoint("TOPLEFT", parent, "TOPLEFT", -offset, offset)
	border:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", offset, -offset)
	border:SetFrameLevel(parent:GetFrameLevel() + 2)
	return border
end

function NS.CreateActionRingButton(parent, ringSize)
	local artSize, iconSize = 134.295081967 * ringSize / 64, 44 * ringSize / 64
	local item = CreateFrame("Frame", nil, parent)
	item:SetSize(ringSize, ringSize)
	item.iconSize = iconSize
	item.backdrop = item:CreateTexture(nil, "BACKGROUND")
	item.backdrop:SetSize(artSize, artSize)
	item.backdrop:SetPoint("CENTER", 0, 0)
	item.backdrop:SetTexture(NS.Media("actionbutton-backdrop"))
	item.backdrop:SetVertexColor(0.67, 0.67, 0.67, 1)
	item.icon = item:CreateTexture(nil, "BORDER")
	item.icon:SetSize(iconSize, iconSize)
	item.icon:SetPoint("CENTER", 0, 0)
	item.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if item.icon.SetMask then item.icon:SetMask(NS.Media("actionbutton-mask-circular")) end
	local overlay = CreateFrame("Frame", nil, item)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(item:GetFrameLevel() + 2)
	item.overlay = overlay
	item.border = overlay:CreateTexture(nil, "ARTWORK")
	item.border:SetSize(artSize, artSize)
	item.border:SetPoint("CENTER", 0, 0)
	item.border:SetTexture(NS.Media("actionbutton-border"))
	item.border:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 1)
	item.highlight = overlay:CreateTexture(nil, "OVERLAY")
	item.highlight:SetSize(artSize, artSize)
	item.highlight:SetPoint("CENTER", 0, 0)
	item.highlight:SetTexture(NS.Media("actionbutton-spellhighlight"))
	item.highlight:SetBlendMode("ADD")
	item.highlight:SetAlpha(0.55)
	item.highlight:Hide()
	return item, iconSize, artSize
end

function NS.CreateThinBar(parent, height, barCol)
	local bf = CreateFrame("Frame", nil, parent)
	bf:SetHeight(height or 4)
	local bg = bf:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(bf)
	bg:SetTexture(NS.OwnMedia("bar_minimal"))
	bg:SetVertexColor(0.08, 0.09, 0.12, 0.85)
	local bar = CreateFrame("StatusBar", nil, bf)
	bar:SetAllPoints(bf)
	bar:SetStatusBarTexture(NS.OwnMedia("bar_minimal"))
	if barCol then bar:SetStatusBarColor(barCol[1], barCol[2], barCol[3], barCol[4] or 0.95) end
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	return bf, bar, bg
end

function NS.CreateResetButton(parent, tooltipText, onClick)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(18, 16)
	btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)
	NS.ApplyFlatBackdrop(btn, { 0.10, 0.12, 0.16, 0.85 }, { 0.32, 0.38, 0.48, 0.80 })
	btn.txt = NS.CreateFontText(btn, -3, "CENTER")
	btn.txt:SetPoint("CENTER", 0, 0)
	btn.txt:SetText("|cffaaaaaaR|r")
	btn:SetScript("OnClick", function() NS.PlayUISound("UChatScrollButton"); onClick() end)
	btn:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(0.00, 0.92, 0.78, 1.0)
		if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(tooltipText, 1, 0.92, 0.55); GameTooltip:Show() end
	end)
	btn:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(0.32, 0.38, 0.48, 0.80)
		if GameTooltip then GameTooltip:Hide() end
	end)
	return btn
end

function NS.CreateFontText(parent, sizeDelta, align, outline)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	local baseSize = (NS.DB and NS.DB.fontSize) or 11
	local delta, out = sizeDelta or 0, outline or "OUTLINE"
	fs:SetFont(NS.GetFontPath(), max(8, baseSize + delta), out)
	fs:SetJustifyH(align or "LEFT")
	fs:SetShadowColor(0, 0, 0, 0.95)
	fs:SetShadowOffset(1, -1)
	NS.RegisteredFonts[#NS.RegisteredFonts + 1] = { fs = fs, delta = delta, outline = out }
	return fs
end
