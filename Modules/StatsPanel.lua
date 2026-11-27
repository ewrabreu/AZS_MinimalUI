local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, max, min, tonumber, fmt = math.floor, math.max, math.min, tonumber, string.format
local COLORS, Clamp, SetText = NS.COLORS, NS.Clamp, NS.SetText

local StatsPanel = CreateFrame("Frame", "AZS_MinUI_StatsPanel", UIParent)
NS.RegisterMovableBox("StatsPanel", "Stats & Caps", StatsPanel)

StatsPanel.combatIcon = StatsPanel:CreateTexture(nil, "ARTWORK")
StatsPanel.combatIcon:SetSize(20, 20)
StatsPanel.combatIcon:SetPoint("TOPLEFT", StatsPanel, "TOPLEFT", 10, -10)
StatsPanel.combatIcon:SetTexture(NS.Media("icon-combat"))
StatsPanel.combatIcon:SetVertexColor(COLORS.ui[1], COLORS.ui[2], COLORS.ui[3], 0.9)
StatsPanel.header = NS.CreateFontText(StatsPanel, 0, "LEFT")
StatsPanel.header:SetPoint("LEFT", StatsPanel.combatIcon, "RIGHT", 4, 0)
StatsPanel.header:SetText("|cffffea89STATS|r")

local STAT_LABELS = {
	"Survivability", "All Damage", "Cooldown (CDR)", "Crit Chance", "Crit Multi",
	"Damage Red.", "Echo (Double)", "Area", "Targets", "Move Speed",
	"Regen/Leech", "Pickup", "XP / Gold", "Luck", "Account Gold",
}
local LUCK_ROW, GOLD_ROW = 14, 15
local StatVals, StatRows = {}, {}
for i = 1, #STAT_LABELS do
	local row = CreateFrame("Frame", nil, StatsPanel)
	row:SetHeight(15)
	row:SetPoint("TOPLEFT",  StatsPanel, "TOPLEFT",   12, -33 - (i - 1) * 16)
	row:SetPoint("TOPRIGHT", StatsPanel, "TOPRIGHT", -12, -33 - (i - 1) * 16)
	row.bullet = row:CreateTexture(nil, "ARTWORK")
	row.bullet:SetSize(8, 8)
	row.bullet:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.bullet:SetTexture(NS.Media("point_gem"))
	if i == GOLD_ROW then row.bullet:SetVertexColor(1.00, 0.82, 0.22, 0.95)
	elseif i == LUCK_ROW then row.bullet:SetVertexColor(0.32, 0.95, 0.78, 0.95)
	else row.bullet:SetVertexColor(0.75, 0.70, 0.55, 0.85) end
	row.val = NS.CreateFontText(row, 0, "RIGHT")
	row.val:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.lbl = NS.CreateFontText(row, 0, "LEFT")
	row.lbl:SetPoint("LEFT", row.bullet, "RIGHT", 4, 0)
	row.lbl:SetPoint("RIGHT", row.val, "LEFT", -4, 0)
	NS.SetNoWrap(row.lbl, 14)
	local lblCol = (i == GOLD_ROW and "|cffffea89") or (i == LUCK_ROW and "|cff66ffcc") or "|cffcccccc"
	row.lbl:SetText(lblCol .. STAT_LABELS[i] .. "|r")
	StatVals[i] = row.val
	StatRows[i] = row
end

local lastAcctGold, lastRunGold, lastCacheCost, lastRunClock = 0, 0, 0, 0
local GoldRow = StatRows[GOLD_ROW]
GoldRow:EnableMouse(true)
GoldRow:SetScript("OnEnter", function(self)
	if not GameTooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText("Run Gold Breakdown", 1, 0.92, 0.55)
	local gpm = (lastRunClock >= 10) and floor((lastAcctGold / lastRunClock) * 60 + 0.5) or 0
	GameTooltip:AddDoubleLine("Account Gold Earned:", fmt("%d", lastAcctGold), 1, 0.85, 0.25, 1, 0.92, 0.45)
	if gpm > 0 then
		GameTooltip:AddDoubleLine("Account Gold / min:", fmt("%d/m", gpm), 0.75, 0.80, 0.88, 0.45, 1, 0.65)
	end
	GameTooltip:AddDoubleLine("Run Gold (Chests/Reroll):", fmt("%d", lastRunGold), 0.75, 0.80, 0.88, 1, 1, 1)
	if lastCacheCost > 0 then
		GameTooltip:AddDoubleLine("Next Cache Cost:", fmt("%d", lastCacheCost), 0.75, 0.80, 0.88, 0.85, 0.85, 0.85)
	end
	GameTooltip:Show()
end)
GoldRow:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

local function FormatCapStat(val, cap)
	return (val >= cap and cap > 0) and fmt("|cffffd100%d%% MAX|r", val) or fmt("|cffffffff%d%%|r|cff888888/%d%%|r", val, cap)
end

local function FormatGoldAmt(n)
	if n >= 100000 then return NS.FormatNumber(n) end
	return fmt("%d", floor(n + 0.5))
end

local Mod = { frame = StatsPanel }
function Mod.Update(ctx)
	if NS.IsBoxHidden("StatsPanel") and not ctx.isEditing then return end
	local run, stats, rs, hpPct = ctx.run, ctx.stats, ctx.runStats, ctx.hpPct or 100
	local cdrPct, critPct, redPct, echoPct, capCdr, capCrit, capRed, capEcho = NS.GetCombatStats(stats, rs, ctx.caps)
	local dmgMult = (stats and tonumber(stats.dmg)) or 1.0
	local cmPct   = (stats and stats.cm   and floor(tonumber(stats.cm) * 100 + 0.5)) or 150
	local areaPct = (stats and stats.area and floor((tonumber(stats.area) - 1) * 100 + 0.5)) or 0
	local spdPct  = (stats and stats.spd  and floor((tonumber(stats.spd) - 1) * 100 + 0.5)) or 0
	local ehpFactor = 1.0 / max(0.10, 1.0 - (redPct / 100.0))
	local enm = run and tonumber(run.enm)
	local hordePressure = (enm and enm > 0) and ((tonumber(run.en) or 0) / enm) or 0
	local elitePenalty = min(0.35, ((run and tonumber(run.el)) or 0) * 0.03)
	local survScore = Clamp(floor((hpPct * 0.55 + min(45, ehpFactor * 18)) * (1.0 - hordePressure * 0.35 - elitePenalty)), 0, 100)
	local survColor = (survScore >= 70) and "|cff44ff66" or ((survScore >= 40) and "|cffffcc00" or "|cffff3333")

	local luckPct = (rs and tonumber(rs.luck)) or nil
	if not luckPct and stats and stats.luck then
		local rawL = tonumber(stats.luck) or 0
		luckPct = (rawL > 0 and rawL <= 3.0) and floor((rawL - 1) * 100 + 0.5) or floor(rawL + 0.5)
	end
	luckPct = max(0, floor((luckPct or 0) + 0.5))

	SetText(StatVals[1],  fmt("%s%d%% (%.1fx)|r", survColor, survScore, ehpFactor))
	SetText(StatVals[2],  fmt("|cffffffff+%.0f%%|r", (dmgMult - 1) * 100))
	SetText(StatVals[3],  FormatCapStat(cdrPct, capCdr))
	SetText(StatVals[4],  FormatCapStat(critPct, capCrit))
	SetText(StatVals[5],  fmt("|cffffffff%d%%|r", cmPct))
	SetText(StatVals[6],  FormatCapStat(redPct, capRed))
	SetText(StatVals[7],  FormatCapStat(echoPct, capEcho))
	SetText(StatVals[8],  fmt("|cffffffff+%d%%|r", areaPct))
	SetText(StatVals[9],  fmt("|cffffffff+%d|r", (stats and tonumber(stats.cnt)) or 0))
	SetText(StatVals[10], fmt("|cffffffff+%d%%|r", spdPct))
	SetText(StatVals[11], fmt("|cff66ff88%.1f|r |cffaaaaaa(%.1f%%)|r", (stats and tonumber(stats.reg)) or 0, (stats and stats.lch and (tonumber(stats.lch) * 100)) or 0))
	SetText(StatVals[12], fmt("|cffffffff%.1fm|r", (stats and tonumber(stats.pick)) or 0))
	SetText(StatVals[13], fmt("|cffcc99ff+%.0f%%|r/|cffffd700+%.0f%%|r", (((stats and tonumber(stats.xp)) or 1) - 1) * 100, (((stats and tonumber(stats.gold)) or 1) - 1) * 100))
	SetText(StatVals[14], fmt("|cff66ffcc+%d%%|r", luckPct))

	local acctGold = (run and tonumber(run.gt)) or 0
	local runGold  = (run and tonumber(run.gold)) or 0
	lastAcctGold, lastRunGold = acctGold, runGold
	lastCacheCost, lastRunClock = (run and tonumber(run.cache)) or 0, ctx.runClock or 0
	if ctx.inHub and acctGold == 0 then
		SetText(StatVals[15], "|cff888888-|r")
	else
		SetText(StatVals[15], "|cffffd700+" .. FormatGoldAmt(acctGold) .. "g|r")
	end
end

function Mod.ApplyTheme(th)
	local titleHex = (th and th.hex and th.hex.title) or "|cffffea89"
	StatsPanel.combatIcon:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.95)
	StatsPanel.header:SetText(titleHex .. "STATS|r")
	for i = 1, #StatRows do
		local row = StatRows[i]
		if i == GOLD_ROW then row.bullet:SetVertexColor(COLORS.title[1], COLORS.title[2], COLORS.title[3], 0.95)
		elseif i == LUCK_ROW then row.bullet:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.95)
		else row.bullet:SetVertexColor(COLORS.bullet[1], COLORS.bullet[2], COLORS.bullet[3], 0.85) end
	end
end

NS.Modules.StatsPanel = Mod
