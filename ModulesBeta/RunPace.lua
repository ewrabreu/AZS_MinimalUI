local _, NS = ...
if type(NS) ~= "table" then NS = _G.AZS_MinimalUI_NS end
local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt
local fmt, lower, find, sub, gmatch = string.format, string.lower, string.find, string.sub, string.gmatch
local tonumber, tostring, type, pairs, pcall, tsort, tremove = tonumber, tostring, type, pairs, pcall, table.sort, table.remove
local GetTime, UnitClass, UnitHealth, UnitHealthMax, UnitArmor, UnitGUID, GetSpellInfo, GetItemInfo = GetTime, UnitClass, UnitHealth, UnitHealthMax, UnitArmor, UnitGUID, GetSpellInfo, GetItemInfo
local Wipe, SetTxt, NoWrap, ApplyFlat = NS.Wipe, NS.SetText, NS.SetNoWrap, NS.ApplyFlatBackdrop
local TICK, HN = 0.25, 90

local function num(v, d) return tonumber(v) or d or 0 end
local function Short(s, n)
	s = tostring(s or "?")
	if #s <= n then return s end
	s = sub(s, 1, n - 1)
	while #s > 0 do
		local b = s:byte(#s)
		if b < 128 then break end
		s = sub(s, 1, #s - 1)
		if b >= 192 then break end
	end
	return s .. "."
end
local function Label(parent, size, align, pt, rel, relPt, x, y)
	local fs = NS.CreateFontText(parent, size, align)
	fs:SetPoint(pt, rel, relPt, x, y)
	return fs
end
local function Vis(f, on) if on then f:Show() else f:Hide() end end
local SplitCSV = NS.SplitCSV

local Panel = CreateFrame("Frame", "AZS_MinUI_BetaRunPace", UIParent)
NS.RegisterMovableBox("BetaRunPace", "[Beta] Pace & Tactical", Panel)
Panel:EnableMouse(true)
Panel.icon = Panel:CreateTexture(nil, "ARTWORK")
Panel.icon:SetSize(15, 15); Panel.icon:SetPoint("TOPLEFT", Panel, "TOPLEFT", 10, -9)
Panel.icon:SetTexture(NS.Media("icon-combat")); Panel.icon:SetVertexColor(0.75, 0.55, 1.0, 1.0)
Panel.header = Label(Panel, 0, "LEFT", "LEFT", Panel.icon, "RIGHT", 5, 0)
Panel.header:SetText("|cffd2b4ffPACE & COACH|r")
Panel.pbBadge = Label(Panel, -3, "RIGHT", "TOPRIGHT", Panel, "TOPRIGHT", -10, -10)

local Banner = CreateFrame("Frame", nil, Panel)
Banner:SetHeight(24)
Banner:SetPoint("TOPLEFT", Panel, "TOPLEFT", 9, -29); Banner:SetPoint("TOPRIGHT", Panel, "TOPRIGHT", -9, -29)
Banner:SetBackdrop(NS.FLAT_BACKDROP_NOINSET)
Banner:SetBackdropColor(0.05, 0.16, 0.10, 0.90); Banner:SetBackdropBorderColor(0.18, 0.78, 0.45, 0.85)
Banner.left = Label(Banner, -1, "LEFT", "LEFT", Banner, "LEFT", 7, 0)
Banner.right = Label(Banner, -2, "RIGHT", "RIGHT", Banner, "RIGHT", -7, 0)
Banner.left:SetPoint("RIGHT", Banner.right, "LEFT", -4, 0)
NoWrap(Banner.left, 14)

local function MakeRows(n)
	local rows = {}
	for i = 1, n do
		local row = CreateFrame("Frame", nil, Panel); row:SetHeight(16)
		row.val = Label(row, -2, "RIGHT", "RIGHT", row, "RIGHT", 0, 0)
		row.lbl = Label(row, -2, "LEFT", "LEFT", row, "LEFT", 0, 0)
		row.lbl:SetPoint("RIGHT", row.val, "LEFT", -4, 0)
		NoWrap(row.lbl, 14)
		rows[i] = row
	end
	return rows
end
local function PlaceRows(rows, y0, step)
	for i = 1, #rows do
		local y = y0 - (i - 1) * step
		rows[i]:ClearAllPoints()
		rows[i]:SetPoint("TOPLEFT", Panel, "TOPLEFT", 10, y); rows[i]:SetPoint("TOPRIGHT", Panel, "TOPRIGHT", -10, y)
	end
end
local function Divider(a)
	local d = Panel:CreateTexture(nil, "ARTWORK"); d:SetHeight(1); d:SetTexture(NS.OwnMedia("blank")); d:SetVertexColor(0.45, 0.36, 0.70, a or 0.40)
	return d
end
local function PlaceDiv(d, y) d:ClearAllPoints(); d:SetPoint("TOPLEFT", Panel, "TOPLEFT", 10, y); d:SetPoint("TOPRIGHT", Panel, "TOPRIGHT", -10, y) end

local TacRows, PaceRows = MakeRows(4), MakeRows(4)
local TacDiv, CoachDiv = Divider(), Divider(0.55)
PlaceDiv(TacDiv, -133); PlaceRows(TacRows, -58, 18)

local CoachLbl = NS.CreateFontText(Panel, -3, "LEFT"); CoachLbl:SetText("|cffb088ffLIVE COACH|r")
local CoachRows = {}
for i = 1, 3 do
	local row = CreateFrame("Frame", nil, Panel); row:SetHeight(16)
	row.bar = row:CreateTexture(nil, "ARTWORK"); row.bar:SetTexture(NS.OwnMedia("blank")); row.bar:SetWidth(2)
	row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1); row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
	row.txt = Label(row, -2, "LEFT", "LEFT", row, "LEFT", 7, 0); row.txt:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	NoWrap(row.txt, 14)
	CoachRows[i] = row
end
local Hint = Label(Panel, -3, "CENTER", "BOTTOM", Panel, "BOTTOM", 0, 6)
Hint:SetText("|cff6e7c94Hover for full tactical breakdown|r")

local layoutKey
local function Layout(tac, coach)
	local key = (tac and 1 or 0) + (coach and 2 or 0)
	if layoutKey == key then return end
	layoutKey = key
	local y = tac and -140 or -32
	PlaceRows(PaceRows, y, 18)
	local cy = y - 76
	PlaceDiv(CoachDiv, cy)
	CoachLbl:ClearAllPoints(); CoachLbl:SetPoint("TOPLEFT", Panel, "TOPLEFT", 10, cy - 3)
	for i = 1, 3 do
		local r = CoachRows[i]
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", Panel, "TOPLEFT", 10, cy - 15 - (i - 1) * 17)
		r:SetPoint("TOPRIGHT", Panel, "TOPRIGHT", -10, cy - 15 - (i - 1) * 17)
		Vis(r, coach)
	end
	Vis(CoachDiv, coach); Vis(CoachLbl, coach); Vis(Banner, tac); Vis(TacDiv, tac); Vis(Hint, tac)
	for i = 1, 4 do Vis(TacRows[i], tac) end
end

local Card = CreateFrame("Frame", "AZS_MinUI_BetaRunSummary", UIParent)
Card._azsMinUI = true
Card:SetSize(356, 330); Card:SetPoint("CENTER", UIParent, "CENTER", 0, 46); Card:SetFrameStrata("DIALOG")
Card:EnableMouse(true); Card:SetMovable(true); Card:RegisterForDrag("LeftButton")
Card:SetScript("OnDragStart", Card.StartMoving); Card:SetScript("OnDragStop", Card.StopMovingOrSizing)
ApplyFlat(Card, { 0.035, 0.042, 0.068, 0.96 }, { 0.45, 0.34, 0.85, 0.95 })
Card:Hide()
Card.topGlow = Card:CreateTexture(nil, "OVERLAY"); Card.topGlow:SetHeight(2)
Card.topGlow:SetPoint("TOPLEFT", Card, "TOPLEFT", 1, -1); Card.topGlow:SetPoint("TOPRIGHT", Card, "TOPRIGHT", -1, -1)
Card.topGlow:SetTexture(NS.OwnMedia("blank")); Card.topGlow:SetVertexColor(0.00, 0.92, 0.78, 0.95)
Card.title = Label(Card, 2, "LEFT", "TOPLEFT", Card, "TOPLEFT", 16, -14); Card.title:SetText("|cffffea89RUN SUMMARY|r  |cffb088ff[BETA]|r")
Card.zoneSub = Label(Card, -2, "LEFT", "TOPLEFT", Card.title, "BOTTOMLEFT", 0, -3)
local CloseBtn = CreateFrame("Button", nil, Card)
CloseBtn:SetSize(22, 22); CloseBtn:SetPoint("TOPRIGHT", Card, "TOPRIGHT", -10, -10)
CloseBtn:SetBackdrop(NS.FLAT_BACKDROP_NOINSET); CloseBtn:SetBackdropColor(0.16, 0.06, 0.08, 0.90); CloseBtn:SetBackdropBorderColor(0.65, 0.22, 0.28, 0.90)
CloseBtn.txt = Label(CloseBtn, -1, "CENTER", "CENTER", CloseBtn, "CENTER", 0, 0); CloseBtn.txt:SetText("|cffff7777X|r")
CloseBtn:SetScript("OnClick", function() NS.PlayUISound("igMainMenuClose"); Card:Hide() end)

local SUM_LABELS = { "Time Survived", "Peak DPS", "Total Kills", "Gold Earned", "Level Reached", "MVP Skill", "Top Threat", "Time at Risk" }
local SumRows = {}
for i = 1, 8 do
	local r = CreateFrame("Frame", nil, Card); r:SetHeight(24)
	r:SetPoint("TOPLEFT", Card, "TOPLEFT", 14, -56 - (i - 1) * 28); r:SetPoint("TOPRIGHT", Card, "TOPRIGHT", -14, -56 - (i - 1) * 28)
	r:SetBackdrop(NS.FLAT_BACKDROP_NOINSET); r:SetBackdropColor(0.055, 0.068, 0.105, 0.90); r:SetBackdropBorderColor(0.15, 0.19, 0.28, 0.80)
	r.lbl = Label(r, -1, "LEFT", "LEFT", r, "LEFT", 10, 0); r.lbl:SetText("|cffb8c4d4" .. SUM_LABELS[i] .. "|r")
	r.val = Label(r, -1, "RIGHT", "RIGHT", r, "RIGHT", -10, 0)
	SumRows[i] = r
end
local SumFooter = Label(Card, -2, "LEFT", "BOTTOMLEFT", Card, "BOTTOMLEFT", 16, 10)
SumFooter:SetPoint("BOTTOMRIGHT", Card, "BOTTOMRIGHT", -16, 10); SumFooter:SetHeight(40); SumFooter:SetJustifyV("BOTTOM")

local TREE_KW_STR = {
	blood         = "blood,sangue,heart,death strike,vampir,rune,boil,worm,drain,leech,pestil",
	frost         = "frost,gelo,gelid,icy,howl,blizz,cone,nova,chill,lance,oblit,winter,remorse,glacial",
	unholy        = "unholy,profan,plague,praga,pestil,ghoul,carni,disease,doenca,death coil,scourge,corpse,gargoyle,defile,decay",
	fire          = "fire,fogo,pyro,flame,chama,burn,queim,scorch,living bomb,ignite,combust,blast,meteor,inferno,dragon",
	arcane        = "arcane,arcano,missile,barrage,explos,nova,orb,surge,mana,mirror",
	arms          = "mortal,bladestorm,tempest,rend,cleave,execute,overpower,sweep,slam,shockwave,strike",
	fury          = "whirl,redemoin,bloodthirst,rampage,cleave,heroic,reckless,slam,raging,execute",
	protection    = "shield,escudo,thunder,trovao,shockwave,revenge,devastate,consecr,avenger,hammer,martelo,reflect,block,bulwark",
	holy          = "holy,sagr,smite,punic,nova,consecr,shock,light,luz,heal,cura,flash,penance,judg,julg",
	discipline    = "penance,smite,shield,escudo,barrier,nova,word,palavra,mend,ward,pain",
	retribution   = "crusader,storm,tempest,judg,julg,consecr,hammer,martelo,exorc,wrath,ira,seal,divine",
	shadow        = "shadow,sombr,mind,mente,flay,blast,pain,dor,plague,praga,vampir,sear,void,fiend",
	affliction    = "corrupt,agony,agon,curse,mald,drain,dren,haunt,seed,semente,unstable,shadow,soul,alma",
	demonology    = "fel,demon,imp,metam,immol,shadowflame,hand,guard,soul,incin,hellfire",
	destruction   = "chaos,caos,incin,conflag,immol,rain,chuva,shadowfury,burn,fire,fogo,soul fire",
	elemental     = "lightn,relamp,chain,cadeia,lava,shock,choque,thunder,trovao,earth,terra,flame,totem,magma,fire nova",
	enhancement   = "storm,tempest,lava,wind,vento,shock,choque,feral,wolf,lobo,magma,fire nova,lightn,totem",
	restoration   = "riptide,chain,heal,cura,rejuv,wild,tranq,earth,shield,escudo,totem,bloom,nourish",
	balance       = "star,estrel,moon,lua,wrath,ira,hurricane,furac,typhoon,tufao,swarm,enxame,solar,lunar,sun",
	feral         = "swipe,patada,shred,rake,rip,mangle,maul,thrash,feroc,bite,claw,bleed,sangr",
	assassination = "mutil,enven,poison,venen,rupt,fan,leque,garrote,deadly,vendetta",
	combat        = "blade,lamin,flurry,sinister,evisc,killing,spree,fan,leque,slice,cleave",
	subtlety      = "ambush,backstab,hemorrh,shadow,sombr,evisc,fan,leque,dance,bleed",
	beast         = "kill command,bestial,pet,multi,volley,chuva,arcane,steady,serpent,cobra,trap,armad",
	marksmanship  = "aimed,chimera,multi,volley,barrage,steady,arcane,kill shot,pierc,silenc",
	survival      = "explos,black arrow,flecha,trap,armad,serpent,multi,volley,fire,poison,venen",
}
local AOE_KW = SplitCSV("pestil,nova,blizz,whirl,redemoin,consecr,thunder,trovao,cleave,chain,cadeia,volley,multi,rain,chuva,hurricane,furac,starfall,fan,leque,swipe,patada,boil,decay,defile,explos,storm,tempest,howl,cone,barrage,living bomb,seed,hellfire,magma,shockwave,sweep,flurry,sear,typhoon,tufao,trap,armad,meteor,flame,chama")
local DEF_KW = SplitCSV("shield,escudo,barrier,barreira,ward,proteg,armor,armad,heal,cura,mend,rejuv,renew,flash,light,luz,vampir,drain,dren,siphon,blood,sangue,death strike,leech,absorb,shell,ice block,barkskin,totem,earth,penance,holy")
local TREE_PAT_KEYS, TREE_PAT_VALS = {}, {}
for k, v in gmatch("blood=blood,sang=blood,frost=frost,gelo=frost,gél=frost,unholy=unholy,profan=unholy,fire=fire,fogo=fire,arcan=arcane,arms=arms,armas=arms,fury=fury,fúr=fury,furia=fury,prot=protection,holy=holy,sagr=holy,disc=discipline,retr=retribution,shadow=shadow,sombr=shadow,affl=affliction,supl=affliction,demo=demonology,destr=destruction,elem=elemental,enhan=enhancement,aperf=enhancement,rest=restoration,balan=balance,equil=balance,feral=feral,assas=assassination,comb=combat,subt=subtlety,sutil=subtlety,beast=beast,fera=beast,marks=marksmanship,precis=marksmanship,surv=survival,sobrev=survival", "([^,=]+)=([^,]+)") do
	local n = #TREE_PAT_KEYS + 1
	TREE_PAT_KEYS[n], TREE_PAT_VALS[n] = k, v
end
local STOP_WORDS = NS.SplitSet("improved,mastery,enhanced,greater")

local function TreeKey(name)
	local low = lower(tostring(name or ""))
	for i = 1, #TREE_PAT_KEYS do if find(low, TREE_PAT_KEYS[i], 1, true) then return TREE_PAT_VALS[i] end end
	return low
end
local function MatchAny(low, list)
	if not low or low == "" or not list then return false end
	for i = 1, #list do if find(low, list[i], 1, true) then return true end end
	return false
end

local KEYS = { "t", "v", "s", "n", "p" }
local function NewLog() return { t = {}, v = {}, s = {}, n = {}, p = {}, h = 1, e = 0 } end
local function LogPush(L, t, v, s, n, p) local e = L.e + 1; L.e = e; L.t[e], L.v[e], L.s[e], L.n[e], L.p[e] = t, v, s, n, p end
local function LogPrune(L, cutoff)
	local T, h, e = L.t, L.h, L.e
	while h <= e and T[h] < cutoff do h = h + 1 end
	if h > 96 then
		local cnt = e - h + 1
		for k = 1, 5 do
			local a = L[KEYS[k]]
			for i = 1, cnt do a[i] = a[h + i - 1] end
			for i = cnt + 1, e do a[i] = nil end
		end
		L.h, L.e = 1, cnt
	else L.h = h end
end
local function LogClear(L) L.h, L.e = 1, 0 end

local seen, agg, aggP, names = {}, {}, {}, {}
local function WinSum(L, now, win)
	local c, T, V, Sr, tot, n = now - win, L.t, L.v, L.s, 0, 0
	Wipe(seen)
	for i = L.h, L.e do
		if T[i] >= c then
			tot = tot + V[i]
			local s = Sr[i]
			if s and not seen[s] then seen[s] = true; n = n + 1 end
		end
	end
	return tot, n
end

local S = {
	dmg = NewLog(), heal = NewLog(), loss = NewLog(),
	xpRate = 0, pDirty = true, pT = 0, pVer = 0, tickT = 0, skillT = 0,
	h = { n = 0, t = 0, k = {}, d = {}, g = {} },
	runDmg = {}, runDmgSum = 0, boss = {},
	profile = {
		classToken = "", className = "", primaryTree = "General", primaryPts = 0, totalPts = 0,
		treeSummary = "-", keywords = {}, topTalents = {}, gearCount = 0, avgIlvl = 0,
		gearArmor = 0, gearStamina = 0, gearOffense = 0, gearDefRatio = 0.5,
	},
	skB1 = {}, skB2 = {},
}
local R = { mobs = {}, gains = {}, caps = {} }
local C = { act = {}, list = {}, hist = {}, logT = {}, snd = -99 }
local Cur = { p = {}, t = {}, s = {} }
local SEV = { crit = { 1.0, 0.27, 0.27 }, warn = { 1.0, 0.72, 0.20 }, info = { 0.40, 0.70, 1.0 }, good = { 0.30, 1.0, 0.55 } }
local function Say(id, prio, sev, text) Cur.p[id], Cur.t[id], Cur.s[id] = prio, text, sev end

local nameC, lowC, aoeC, defC, tmC = {}, {}, {}, {}, {}
local tabPts, kwSeen, statBuf, byNameBuf = {}, {}, {}, {}
local function SortTalents(a, b) return a.rank > b.rank end

local function ScanProfile(force, now)
	if (not force) and (not S.pDirty) and (now - S.pT < 4.0) then return S.profile end
	S.pDirty, S.pT, S.pVer = false, now, S.pVer + 1
	Wipe(tmC); Wipe(tabPts); Wipe(kwSeen)
	local p = S.profile
	p.className, p.classToken = UnitClass("player")
	p.className, p.classToken = p.className or "", p.classToken or ""
	p.primaryTree, p.primaryPts, p.totalPts = "General", 0, 0
	Wipe(p.keywords); Wipe(p.topTalents)
	local numTabs = (type(GetNumTalentTabs) == "function" and GetNumTalentTabs()) or 0
	for tab = 1, numTabs do
		local name, _, spent = GetTalentTabInfo(tab)
		local pts = num(spent)
		tabPts[tab] = pts
		p.totalPts = p.totalPts + pts
		if pts > p.primaryPts and name and name ~= "" then p.primaryPts, p.primaryTree = pts, name end
		if pts > 0 and type(GetNumTalents) == "function" and type(GetTalentInfo) == "function" then
			for idx = 1, (GetNumTalents(tab) or 0) do
				local tName, _, _, _, rank = GetTalentInfo(tab, idx)
				local r = num(rank)
				if r > 0 and tName and tName ~= "" then p.topTalents[#p.topTalents + 1] = { name = tName, rank = r } end
			end
		end
	end
	p.treeSummary = (numTabs >= 3) and fmt("%d/%d/%d", tabPts[1] or 0, tabPts[2] or 0, tabPts[3] or 0) or tostring(p.totalPts)
	local kwStr = TREE_KW_STR[TreeKey(p.primaryTree)]
	if kwStr then
		for w in gmatch(kwStr, "[^,]+") do
			if #w >= 4 and not kwSeen[w] then kwSeen[w] = true; p.keywords[#p.keywords + 1] = w end
		end
	end
	tsort(p.topTalents, SortTalents)
	for i = 1, min(12, #p.topTalents) do
		for word in gmatch(lower(p.topTalents[i].name), "[a-z]+") do
			if #word >= 4 and not STOP_WORDS[word] and not kwSeen[word] then kwSeen[word] = true; p.keywords[#p.keywords + 1] = word end
		end
	end
	local eq, ilvl, gArmor, gStam, gOff = 0, 0, 0, 0, 0
	for slot = 1, 19 do
		local link = (slot ~= 4 and slot ~= 19) and GetInventoryItemLink("player", slot)
		if link then
			local _, _, _, il = GetItemInfo(link)
			local nIl = num(il)
			if nIl > 0 then eq, ilvl = eq + 1, ilvl + nIl end
			if type(GetItemStats) == "function" then
				Wipe(statBuf)
				local ok, st = pcall(GetItemStats, link, statBuf)
				if ok and type(st) == "table" then
					gArmor = gArmor + num(st.RESISTANCE0_NAME, num(st.ITEM_MOD_ARMOR_SHORT))
					gStam = gStam + num(st.ITEM_MOD_STAMINA_SHORT)
					gOff = gOff + num(st.ITEM_MOD_SPELL_POWER_SHORT) + num(st.ITEM_MOD_ATTACK_POWER_SHORT) * 0.55
						+ num(st.ITEM_MOD_STRENGTH_SHORT) + num(st.ITEM_MOD_AGILITY_SHORT) + num(st.ITEM_MOD_INTELLECT_SHORT)
						+ num(st.ITEM_MOD_CRIT_RATING_SHORT) + num(st.ITEM_MOD_HASTE_RATING_SHORT)
				end
			end
		end
	end
	local _, effArmor = UnitArmor("player")
	gArmor = max(gArmor, num(effArmor))
	p.gearCount, p.avgIlvl = eq, (eq > 0) and floor(ilvl / eq + 0.5) or 0
	p.gearArmor, p.gearStamina, p.gearOffense = gArmor, gStam, gOff
	local defW = gStam * 1.4 + gArmor * 0.08
	p.gearDefRatio = (defW + gOff > 1) and (defW / (defW + gOff)) or 0.50
	return p
end

local SPELLDMG = { SPELL_DAMAGE = false, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = false, DAMAGE_SHIELD = false, SPELL_BUILDING_DAMAGE = false }
local function RecordDmg(now, amt, src, name, periodic)
	if amt <= 0 then return end
	LogPush(S.dmg, now, amt, src, name, periodic)
	S.lastHitT = now
	S.runDmg[name] = (S.runDmg[name] or 0) + amt
	S.runDmgSum = S.runDmgSum + amt
end

local Driver = CreateFrame("Frame", "AZS_MinUI_BetaRunPaceDriver")
Driver._azsMinUI = true
Driver:RegisterEvent("PLAYER_ENTERING_WORLD")
Driver:RegisterEvent("PLAYER_TALENT_UPDATE")
Driver:RegisterEvent("CHARACTER_POINTS_CHANGED")
Driver:RegisterEvent("UNIT_INVENTORY_CHANGED")
Driver:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
Driver:SetScript("OnEvent", function(_, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subevent, srcGUID, _, _, destGUID, _, _, a9, a10, _, a12, a13 = ...
		local me = S.guid or UnitGUID("player"); S.guid = me
		if not me or destGUID ~= me or not S.inRun then return end
		local now = GetTime()
		if subevent == "SWING_DAMAGE" then RecordDmg(now, num(a9), srcGUID, "Melee", false)
		elseif SPELLDMG[subevent] ~= nil then RecordDmg(now, num(a12), srcGUID, tostring(a10 or "?"), SPELLDMG[subevent])
		elseif subevent == "ENVIRONMENTAL_DAMAGE" then RecordDmg(now, num(a10), "env", "Environment", true)
		elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
			local eff = max(0, num(a12) - num(a13))
			if eff > 0 then LogPush(S.heal, now, eff) end
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		S.guid, S.pDirty = UnitGUID("player"), true
	elseif event == "UNIT_INVENTORY_CHANGED" then
		if ... == "player" then S.pDirty = true end
	else
		S.pDirty = true
	end
end)

local function GetZoneKey(zone)
	return ((zone and (zone.zname or zone.zone)) or "Azeroth") .. " [" .. ((zone and (zone.diff or ("T" .. tostring(zone.dt or 0)))) or "Normal") .. "]"
end

local function ReadMeter(tickId)
	local lines, totalDps = NS.GetMeterCached(tickId)
	Wipe(byNameBuf)
	local mvpName, mvpDps = "-", 0
	if type(lines) == "table" then
		for i = 1, #lines do
			local d, nm = num(lines[i].dps), tostring(lines[i].name or "Skill")
			byNameBuf[lower(nm)] = d
			if d > mvpDps then mvpDps, mvpName = d, nm end
		end
	end
	return totalDps, mvpName, mvpDps, byNameBuf
end

local function GetPos(run)
	if type(_G.AZS_GetPlayerPosition) == "function" then
		local ok, p = pcall(_G.AZS_GetPlayerPosition)
		if ok and type(p) == "table" and tonumber(p.x) and tonumber(p.y) then return tonumber(p.x), tonumber(p.y) end
	end
	if run and tonumber(run.px) and tonumber(run.py) then return tonumber(run.px), tonumber(run.py) end
end

local function UpdateMotion(now, x, y)
	if not x then S.speed, S.moving, S.px = nil, nil, nil; return end
	if S.px then
		local dt = now - S.pt
		if dt > 0.05 then
			local dx, dy = x - S.px, y - S.py
			local sp = sqrt(dx * dx + dy * dy) / dt
			if sp > 60 then sp = S.speed or 0 end
			S.speed = S.speed and (S.speed * 0.5 + sp * 0.5) or sp
			S.moving = S.speed > 1.5
		end
	end
	S.px, S.py, S.pt = x, y, now
end

local function Nearest(list, x, y, onlyAwake)
	if type(list) ~= "table" or not x then return nil end
	local best
	for i = 1, #list do
		local c = list[i]
		if type(c) == "table" and tonumber(c.x) and tonumber(c.y) and (not onlyAwake or c.state == "awake") then
			local dx, dy = c.x - x, c.y - y
			local d = dx * dx + dy * dy
			if not best or d < best then best = d end
		end
	end
	return best and sqrt(best)
end

local function HistPush(now, kills, dps, gold)
	local h = S.h
	if now - h.t < 1 then return end
	h.t, h.n = now, h.n + 1
	local i = h.n % HN + 1
	h.k[i], h.d[i], h.g[i] = kills, dps, gold
end
local function HAt(arr, back) local m = S.h.n - back; return m >= 1 and arr[m % HN + 1] or nil end
local function Rate(arr, span) local b = min(span, S.h.n - 1); return b >= 8 and ((HAt(arr, 0) - HAt(arr, b)) * 60 / b) or nil end
local function Avg(arr, from, to)
	local s, c = 0, 0
	for b = from, to do local v = HAt(arr, b); if v then s, c = s + v, c + 1 end end
	return (c > 0) and (s / c) or nil, c
end

local function TopSources(now, win)
	local L, c, tot = S.dmg, now - win, 0
	Wipe(agg); Wipe(aggP); Wipe(names)
	for i = L.h, L.e do
		if L.t[i] >= c then
			local n = L.n[i] or "?"
			if not agg[n] then names[#names + 1] = n end
			agg[n] = (agg[n] or 0) + L.v[i]
			if L.p[i] then aggP[n] = (aggP[n] or 0) + 1 end
			tot = tot + L.v[i]
		end
	end
	local best
	for i = 1, #names do if not best or agg[names[i]] > agg[best] then best = names[i] end end
	if best and tot > 0 then
		S.tn, S.tp, S.tk, S.tdps = best, floor(agg[best] / tot * 100 + 0.5), aggP[best] or 0, agg[best] / win
		local sec, secV = nil, 0
		for i = 1, #names do
			local n = names[i]
			if n ~= best and agg[n] > secV then sec, secV = n, agg[n] end
		end
		S.tn2, S.tp2 = sec, sec and floor(secV / tot * 100 + 0.5) or 0
	else
		S.tn, S.tp, S.tk, S.tdps, S.tn2, S.tp2 = nil, 0, 0, 0, nil, 0
	end
end

local function Monsters(run, zone, runClock, redPct, M)
	local en, enm = num(run and run.en), max(1, num(run and run.enm, 100))
	local el = (run and (tonumber(run.el) or tonumber(run.ela))) or 0
	local ga = num(run and run.ga)
	local bossCount, finalBoss, bossHp, B = 0, false, 0, S.boss
	B.hp, B.hpm, B.name = 0, 0, nil
	if type(_G.AZS_UNITS) == "table" then
		local units = _G.AZS_UNITS
		for i = 1, #units do
			local u = units[i]
			local uhp = type(u) == "table" and num(u.hp) or 0
			if uhp > 0 then
				bossCount, bossHp = bossCount + 1, bossHp + uhp
				if u.kind == "final" then finalBoss = true end
				if uhp > B.hp then B.hp, B.hpm, B.name = uhp, num(u.hpm, num(u.maxhp, num(u.hpmax))), u.name end
			end
		end
	end
	if bossCount == 0 and run and run.nbs == "up" then bossCount = 1 end
	local hpm = max(100, (run and tonumber(run.hpm)) or UnitHealthMax("player") or 500)
	local base = max(10, hpm * 0.022) * (1.0 + (runClock / 300.0) * 0.85) * (1.0 + num(zone and zone.dt) * 0.28) * ((zone and tonumber(zone.heroic) == 1) and 1.35 or 1.0)
	local raw = (min(en, 12) + max(0, en - 12) * 0.22) * base + el * base * 2.6 + ga * base * 3.4 + bossCount * base * (finalBoss and 7.5 or 5.2)
	M.en, M.enm, M.swarmRatio, M.elites, M.guardians = en, enm, en / enm, el, ga
	M.bosses, M.finalBoss, M.bossHpTotal = bossCount, finalBoss, bossHp
	M.modelMitigatedDps = raw * max(0.10, 1.0 - redPct / 100.0)
end

local function PutSkill(t, nm, rank, reason, score, share, dps)
	t.name, t.rank, t.reason, t.score, t.share, t.dps = nm, rank, reason, score, share, dps
end

local function AdviseSkill(spells, byName, totalDps, profile, M, danger)
	if type(spells) ~= "table" or #spells == 0 then S.skLabel, S.skReason, S.sk2, S.idleSkill = "Waiting for Skill", "Pick 1st skill", nil, nil; return end
	local b1, b2 = S.skB1, S.skB2
	b1.score, b2.score, b1.name, b2.name, S.idleSkill = -1e9, -1e9, nil, nil, nil
	for i = 1, #spells do
		local sp = spells[i]
		local id = tonumber(sp.spell) or tonumber(sp.id) or 0
		local key = (id > 0) and id or tostring(sp.name or ("Skill #" .. i))
		local nm, low = nameC[key], lowC[key]
		if not nm then nm = (id > 0 and GetSpellInfo(id)) or tostring(sp.name or ("Skill #" .. i)); low = lower(nm); nameC[key], lowC[key] = nm, low end
		local rank = max(1, tonumber(sp.rank) or tonumber(sp.r) or 1)
		local cdmax = tonumber(sp.cdmax) or tonumber(sp.cd) or 0
		local sdps = byName[low] or 0
		local share = (totalDps > 1) and (sdps / totalDps) or 0
		if sdps <= 0 and totalDps > 150 and not S.idleSkill then S.idleSkill = nm end
		local tm = tmC[low]; if tm == nil then tm = MatchAny(low, S.profile.keywords); tmC[low] = tm end
		local isAoe = aoeC[low]; if isAoe == nil then isAoe = MatchAny(low, AOE_KW); aoeC[low] = isAoe end
		local isDef = defC[low]; if isDef == nil then isDef = MatchAny(low, DEF_KW); defC[low] = isDef end
		local score, reason = 15, "Scaling"
		if tm then score, reason = score + 38, "Talent " .. profile.primaryTree end
		if share >= 0.30 then score = score + 26; if not tm then reason = fmt("Carry %.0f%% DPS", share * 100) end
		elseif share >= 0.12 then score = score + 16
		elseif rank <= 2 and tm then score, reason = score + 14, "Low Rank + Talent" end
		score = score - min(14, (rank - 1) * 2.2)
		if danger and isDef then score, reason = score + 34, "Survivability"
		elseif M.swarmRatio >= 0.50 and isAoe then score = score + 22; if not tm then reason = "Horde Clear (AoE)" end
		elseif M.bosses > 0 and share >= 0.25 then score = score + 18; if not tm then reason = "Boss DPS" end end
		if cdmax >= 1.5 and cdmax <= 12 then score = score + 8 end
		if score > b1.score then
			PutSkill(b2, b1.name, b1.rank, b1.reason, b1.score, b1.share, b1.dps)
			PutSkill(b1, nm, rank, reason, score, share, sdps)
		elseif score > b2.score then
			PutSkill(b2, nm, rank, reason, score, share, sdps)
		end
	end
	S.skLabel, S.skReason = fmt("%s R%d", Short(b1.name, 16), b1.rank), b1.reason
	S.sk2 = b2.name and fmt("%s R%d (%s)", b2.name, b2.rank, b2.reason) or nil
end

local function Gain(cur, step, room, floorV)
	return room > 0 and (((1 - cur / 100) / max(floorV, 1 - (cur + min(step, room)) / 100)) - 1) or 0
end

local function Report(ctx, runClock, curDps, byName, now)
	local cfg = (NS.DB and NS.DB.beta) or {}
	local simSec = NS.Clamp(num(cfg.simSeconds, 5), 3, 10)
	local run, stats = ctx.run, ctx.stats
	local curHp = (run and tonumber(run.hp)) or UnitHealth("player") or 100
	local maxHp = max(1, (run and tonumber(run.hpm)) or UnitHealthMax("player") or 100)
	local shield = num(run and run.sh) + num(run and run.bsh)
	local pool = curHp + shield
	if S.pool and (now - S.poolT) <= 1.2 and S.pool - pool > 0.5 then LogPush(S.loss, now, S.pool - pool); S.lastHitT = now end
	S.pool, S.poolT = pool, now
	local cdrPct, critPct, redPct, echoPct, capCdr, capCrit, capRed, capEcho = NS.GetCombatStats(stats, ctx.runStats, ctx.caps)
	local dmgMult, cmMult, areaMult = num(stats and stats.dmg, 1.0), num(stats and stats.cm, 1.50), num(stats and stats.area, 1.0)
	local regVal, lchFrac = num(stats and stats.reg), num(stats and stats.lch)
	LogPrune(S.dmg, now - 10); LogPrune(S.heal, now - 5); LogPrune(S.loss, now - 5)
	local clDmg, attackers = WinSum(S.dmg, now, 5)
	local realInDps = max(clDmg / 5, (WinSum(S.loss, now, 5)) / 5)
	local realInHps = (WinSum(S.heal, now, 5)) / 5
	TopSources(now, 8)
	local M = R.mobs
	Monsters(run, ctx.zone, runClock, redPct, M)
	local profile = ScanProfile(false, now)
	local stationary = 0
	if realInDps > 0.5 or M.en > 0 or M.elites > 0 or M.bosses > 0 then
		stationary = max(realInDps * ((M.en > 0 or M.bosses > 0) and 1.18 or 1.0), M.modelMitigatedDps * ((realInDps > 1) and 0.85 or 0.65))
	end
	local leech = curDps * lchFrac
	local sustain = regVal + leech + realInHps
	local net = stationary - sustain
	local projected = pool - net * simSec
	local projPct, ttk = projected / maxHp * 100, (net > 0.1) and (pool / net) or 999
	local code, text, br, bg, bb
	if ttk <= simSec then
		code, text, br, bg, bb = "DIE", fmt("|cffff4444DIES IN %.1fs|r |cffffaaaa(STANDING)|r", max(0.1, ttk)), 0.85, 0.16, 0.20
	elseif projected < maxHp * 0.35 or ttk <= simSec * 1.7 then
		code, text, br, bg, bb = "RISK", fmt("|cffffcc33RISK %ds|r |cffffee99(%.0f%% left)|r", simSec, max(1, projPct)), 0.90, 0.62, 0.12
	else
		code, br, bg, bb = "SAFE", 0.16, 0.78, 0.45
		text = (projected >= maxHp) and fmt("|cff33ff88SAFE %ds|r |cff88ffbb(100%%+)|r", simSec) or fmt("|cff33ff88SAFE %ds|r |cff88ffbb(%.0f%% HP)|r", simSec, max(1, projPct))
	end
	local redRoom, cdrRoom, critRoom, echoRoom = max(0, capRed - redPct), max(0, capCdr - cdrPct), max(0, capCrit - critPct), max(0, capEcho - echoPct)
	local defGain = Gain(redPct, 5, redRoom, 0.05)
	local hpGain = 0.15 + ((curHp / maxHp < 0.55) and 0.08 or 0) + ((sustain < stationary * 0.30) and 0.07 or 0) + ((redRoom <= 3) and 0.14 or 0)
	local cdrGain = Gain(cdrPct, 5, cdrRoom, 0.10)
	local cmExtra = max(0.1, cmMult - 1.0)
	local critStep, echoStep = min(5, critRoom), min(5, echoRoom)
	local critGain = (critStep > 0) and ((critStep / 100) * cmExtra / (1 + critPct / 100 * cmExtra)) or 0
	local echoGain = (echoStep > 0) and ((echoStep / 100) / (1 + echoPct / 100)) or 0
	local areaBonus = (M.swarmRatio >= 0.55 and areaMult < 1.8) and 0.09 or 0.03
	local offSub, offGain = "All Damage", 0.10 / max(1.0, dmgMult)
	if critGain > offGain then offGain, offSub = critGain, fmt("Crit (%d%%)", critPct) end
	if echoGain > offGain then offGain, offSub = echoGain, fmt("Echo (%d%%)", echoPct) end
	if areaBonus > offGain then offGain, offSub = areaBonus, "Area (AoE)" end

	local tag, subT, color, why
	if code == "DIE" or (code == "RISK" and ttk <= simSec * 1.4) then
		if defGain >= hpGain * 0.65 and redRoom >= 3 then
			tag, subT, color, why = "DEFENSE", fmt("Red. %d/%d%%", redPct, capRed), "|cff55ccff", fmt("Standing still dies in %.1fs; +5%% Reduction adds +%.1f%% EHP", ttk, defGain * 100)
		else
			subT = (curDps > 200 and lchFrac < 0.02) and "HP / Leech" or "HP / Regen"
			tag, color = "HEALTH", "|cff44ff88"
			why = (redRoom <= 3) and "Reduction near cap — scale Max HP, Regen, and Leech" or fmt("Low pool vs %.0f/s incoming; prioritize %s", stationary, subT)
		end
	elseif code == "RISK" or (profile.gearDefRatio < 0.30 and M.bosses > 0) then
		if cdrGain >= 0.11 and cdrRoom >= 5 then
			tag, subT, color, why = "COOLDOWN (CD)", fmt("CDR %d/%d%%", cdrPct, capCdr), "|cffffd100", fmt("+5%% CDR adds +%.1f%% damage and heal/shield cycles", cdrGain * 100)
		elseif defGain >= hpGain * 0.65 and redRoom >= 3 then
			tag, subT, color, why = "DEFENSE", fmt("Red. %d/%d%%", redPct, capRed), "|cff55ccff", "Tight margin; Reduction stabilizes against elites/bosses"
		else
			tag, subT, color, why = "HEALTH", "HP / Regen", "|cff44ff88", "Boost HP/Regen to handle incoming damage spikes"
		end
	elseif cdrGain > offGain * 1.05 and cdrRoom >= 4 then
		tag, subT, color, why = "COOLDOWN (CD)", fmt("CDR %d/%d%%", cdrPct, capCdr), "|cffffd100", fmt("+5%% CDR (+%.1f%% DPS) beats %s (+%.1f%%)", cdrGain * 100, offSub, offGain * 100)
	else
		tag, subT, color, why = "DAMAGE", offSub, "|cffff7766", fmt("Safe for %ds; %s gives the best gain (+%.1f%% DPS)", simSec, offSub, offGain * 100)
	end

	if now - S.skillT >= 1.5 then S.skillT = now; AdviseSkill(_G.AZS_SPELLS, byName, curDps, profile, M, code ~= "SAFE") end
	R.simSec, R.statusCode, R.bannerText, R.bR, R.bG, R.bB = simSec, code, text, br, bg, bb
	R.curHp, R.maxHp, R.shield, R.pool = curHp, maxHp, shield, pool
	R.realInDps, R.modelInDps, R.stationary = realInDps, M.modelMitigatedDps, stationary
	R.sustain, R.regVal, R.leech, R.realInHps = sustain, regVal, leech, realInHps
	R.net, R.projected, R.projPct, R.ttk, R.attackers = net, projected, projPct, ttk, attackers
	R.profile, R.focusTag, R.focusSub, R.focusColor, R.focusReason = profile, tag, subT, color, why
	R.skLabel, R.skReason, R.sk2 = S.skLabel, S.skReason, S.sk2
	local g, c = R.gains, R.caps
	g.def, g.hp, g.cdr, g.off, g.offSub = defGain * 100, hpGain * 100, cdrGain * 100, offGain * 100, offSub
	c.red, c.capRed, c.cdr, c.capCdr, c.crit, c.capCrit, c.echo, c.capEcho = redPct, capRed, cdrPct, capCdr, critPct, capCrit, echoPct, capEcho
	return R
end

local function RunCoach(now, runClock, curDps, ar, pb, lvl, etaSec, run)
	local M, st = R.mobs, R.statusCode
	local pct, known, moving, hit = R.pool / R.maxHp * 100, S.speed ~= nil, S.moving, R.realInDps > 1
	local hot = S.lastHitT and (now - S.lastHitT) < 4
	if st == "DIE" and hot then
		Say("die", 100, "crit", fmt("|cffff4444[!]|r Dies in %.1fs - %s", max(0.1, R.ttk), known and (moving and "keep kiting away" or "move now!") or "retreat!"))
	elseif st == "RISK" and hot then
		Say("risk", 88, "warn", fmt("|cffffbb33[!]|r High pressure: ~%d%% left in %ds", max(1, floor(R.projPct)), R.simSec))
	elseif st ~= "SAFE" then
		Say("risk", 35, "info", fmt("|cff88aaff[~]|r If standing now: ~%d%% in %ds (keep kiting)", max(0, floor(R.projPct)), R.simSec))
	end
	if pct < 30 and hit then Say("lowhp", 92, "crit", fmt("|cffff4444[!]|r Critical HP (%d%%) - retreat/heal", floor(pct))) end
	local lives = run and tonumber(run.lives)
	if lives and S.lives and lives < S.lives then S.lostT = now end
	S.lives = lives or S.lives
	if S.lostT and now - S.lostT < 6 then Say("life", 95, "crit", fmt("|cffff4444[!]|r Life lost! %d remaining", S.lives or 0)) end
	if S.tn and S.tp >= 35 and hit then Say("threat", 62, "info", fmt("|cffff9966[~]|r Top damage: %s (%d%%)", Short(S.tn, 18), S.tp)) end
	if S.tn and S.tk >= 3 and known and not moving and S.tdps >= R.maxHp * 0.02 then
		Say("avoid", 80, "crit", fmt("|cffff7744[!]|r Leave ground AoE: %s (%s/s)", Short(S.tn, 14), NS.FormatNumber(S.tdps)))
	end
	if known and not moving and M.en >= 6 and hit and st ~= "SAFE" then Say("still", 72, "warn", "|cffffbb33[!]|r Standing under fire - move (kite)") end
	local rv = _G.AZS_REVIVE
	if rv and num(rv.down) > 0 then
		Say("rev", 85, "warn", (st == "SAFE") and fmt("|cff55ff99[+]|r Ally downed! Revive (%.0f%%)", num(rv.rshare) * 100) or "|cff55ff99[+]|r Ally downed - kite horde first")
	end
	local B = S.boss
	if M.bosses > 0 and B.hp > 0 then
		local tk = B.hp / max(1, curDps)
		local lose = st ~= "SAFE" and R.ttk < 60 and tk > R.ttk
		Say("boss", lose and 82 or 64, lose and "warn" or "info", fmt("|cffff8822[B]|r %s %s - dies %s%s",
			Short(B.name or "Boss", 12), B.hpm > 0 and fmt("%d%%", floor(B.hp / B.hpm * 100)) or "", tk > 600 and ">10m" or ("~" .. floor(tk) .. "s"), lose and " (you die first!)" or ""))
	end
	if (M.elites > 0 or M.guardians > 0) and st ~= "SAFE" then Say("elite", 66, "warn", fmt("|cff4499ff[E]|r Elite/Guardian active (%dE %dG): pop CDs", M.elites, M.guardians)) end
	if M.en > 0 and M.swarmRatio >= 0.75 then Say("swarm", 58, "warn", fmt("|cffffcc66[H]|r Full horde %d/%d - AoE & circle kite", M.en, M.enm)) end
	if st ~= "DIE" and hit and R.sustain < R.realInDps * 0.15 and pct < 60 then Say("regen", 46, "warn", "|cff44ff88[v]|r Low sustain - prioritize Regen/Leech") end
	local kAll, k30 = ar.kills / max(0.05, runClock / 60), Rate(S.h.k, 30)
	if k30 and runClock > 60 and kAll > 5 then
		local ch = k30 / kAll - 1
		if ch <= -0.35 then Say("pace", 54, "warn", fmt("|cffffcc66[R]|r Pace dropped %d%% - engage more mobs", -ch * 100))
		elseif ch >= 0.30 then Say("pace", 22, "good", fmt("|cff55ff99[R]|r Pace +%d%% above your average", ch * 100)) end
	end
	local pbK = pb and pb.kpm
	if pbK and pbK > 0 and runClock > 90 then
		local ratio = kAll / pbK
		if ratio < 0.8 then Say("pbpace", 40, "info", fmt("|cffffcc66[R]|r Kills %d/min vs PB %d/min", kAll, pbK))
		elseif ratio >= 1.1 then Say("pbpace", 21, "good", fmt("|cff55ff99[R]|r Ahead of PB kill pace (+%d%%)", (ratio - 1) * 100)) end
	end
	local rec, cr = Avg(S.h.d, 0, 4)
	local prev, cp = Avg(S.h.d, 5, 19)
	if rec and prev and cr >= 3 and cp >= 8 and prev > 30 and rec < prev * 0.6 and (M.en > 0 or M.bosses > 0) then
		Say("dpsdrop", 50, "warn", fmt("|cffffcc66[D]|r DPS dropped %d%% - out of range / on CD?", (1 - rec / prev) * 100))
	end
	if M.en == 0 and M.bosses == 0 then S.emptyT = S.emptyT or now else S.emptyT = nil end
	if S.emptyT and now - S.emptyT > 6 and runClock > 15 then Say("idle", 45, "info", fmt("|cff88aaff[?]|r %ds with no enemies - push forward", now - S.emptyT)) end
	if st == "SAFE" then
		if S.nc and S.nc <= 60 then Say("chest", 38, "good", fmt("|cffffd700[$]|r Chest %dm away - grab it now", S.nc)) end
		if S.nl and S.nl <= 60 then Say("lair", 36, "info", fmt("|cffcc99ff[C]|r Awake lair %dm away", S.nl)) end
	end
	if S.lvlT and now - S.lvlT < 10 and R.skLabel then Say("lvl", 70, "good", fmt("|cff55ff99[+]|r Level %d! Up: %s", lvl, R.skLabel)) end
	Say("focus", 30, "info", fmt("|cff88aaff[^]|r Upgrade: %s%s|r (%s)", R.focusColor, R.focusTag, R.focusSub))
	if S.idleSkill and runClock > 45 then Say("idleskill", 20, "info", fmt("|cff88aaff[?]|r Zero damage: %s - check range/target", Short(S.idleSkill, 18))) end
	if etaSec and etaSec <= 20 then Say("eta", 12, "good", fmt("|cffcc99ff[+]|r Next level in ~%ds", etaSec)) end
end

local function CoachCommit(now, runClock, snd)
	local A, h = C.act, C.hist
	for id, pr in pairs(Cur.p) do
		local a = A[id]
		if not a then
			a = { first = now }; A[id] = a
			if pr >= 55 and now - (C.logT[id] or -99) > 15 then
				C.logT[id] = now; h[#h + 1] = { t = runClock, text = Cur.t[id] }
				if #h > 8 then tremove(h, 1) end
			end
			if snd and pr >= 85 and now - C.snd > 6 then C.snd = now; NS.PlayUISound("RaidWarning") end
		end
		a.prio, a.text, a.sev, a.seen = pr, Cur.t[id], Cur.s[id], now
	end
	Wipe(Cur.p)
	local L = C.list; Wipe(L)
	for id, a in pairs(A) do
		if now - a.seen > 1.25 then A[id] = nil
		else
			local i = #L + 1; L[i] = a
			while i > 1 and (L[i - 1].prio < a.prio or (L[i - 1].prio == a.prio and L[i - 1].first > a.first)) do
				L[i], L[i - 1] = L[i - 1], a; i = i - 1
			end
		end
	end
end

local function FillThreat(ar)
	local best, bv = nil, 0
	for n, v in pairs(S.runDmg) do if v > bv then best, bv = n, v end end
	ar.threat, ar.threatPct = best, (S.runDmgSum > 0) and (bv / S.runDmgSum * 100) or 0
end

local function FinalTip(ar, pbKpm)
	local d = max(1, ar.duration)
	if ar.riskSec / d > 0.25 then return fmt("You spent %d%% of the run at risk: invest in Defense and Health.", ar.riskSec / d * 100) end
	if ar.near >= 3 then return fmt("%d near-deaths: use cooldowns and move before the horde closes in.", ar.near) end
	if pbKpm and pbKpm > 0 and ar.kpm < pbKpm * 0.85 then return "Pace below your record: stay mobile alongside incoming hordes." end
	if ar.threat and ar.threatPct >= 40 then return fmt("%s dealt %d%% of your damage taken: build defenses against it.", Short(ar.threat, 18), ar.threatPct) end
	return "Great run! Keep scaling DPS and CDR to beat your personal bests."
end

local function RenderSummary(snap, pb, isDemo)
	local function Tag(new) return new and " |cff00ffcc[NEW PB!]|r" or "" end
	Card.zoneSub:SetText("|cff88a0bb" .. snap.zoneKey .. (isDemo and " · Simulation" or "") .. "|r")
	SumRows[1].val:SetText("|cffffffff" .. NS.FormatTime(snap.duration) .. "|r")
	SumRows[2].val:SetText("|cffffea89" .. NS.FormatNumber(snap.peakDps) .. "/s|r" .. Tag(snap.peakDps > (pb.peakDps or 0)))
	SumRows[3].val:SetText("|cffffffff" .. NS.FormatNumber(snap.kills) .. "|r |cff94a3b8(" .. fmt("%.0f/min", snap.kpm) .. ")|r" .. Tag(snap.kills > (pb.kills or 0)))
	SumRows[4].val:SetText("|cffffd700" .. NS.FormatNumber(snap.gold) .. "|r |cff94a3b8(" .. fmt("%.0f/min", snap.gpm) .. ")|r" .. Tag(snap.gold > (pb.gold or 0)))
	SumRows[5].val:SetText("|cffcc99ffLv " .. tostring(snap.lvl) .. "|r" .. Tag(snap.lvl > (pb.lvl or 0)))
	SumRows[6].val:SetText("|cff44ffdd" .. tostring(snap.mvpName) .. "|r |cff94a3b8(" .. NS.FormatNumber(snap.mvpDps) .. "/s)|r")
	SumRows[7].val:SetText("|cffff9966" .. Short(snap.threat or "-", 16) .. "|r |cff94a3b8(" .. fmt("%.0f%%", snap.threatPct or 0) .. ")|r")
	SumRows[8].val:SetText(fmt("|cffffcc66%.0f%%|r |cff94a3b8(%d near-deaths · min %d%% HP)|r", snap.riskSec / max(1, snap.duration) * 100, snap.near, snap.minPct))
	SumFooter:SetText("|cffffd100Coach:|r |cffdfe6f0" .. FinalTip(snap, pb.kpm) .. "|r\n|cff7f8ea3Records are saved automatically per zone and difficulty.|r")
	NS.PlayUISound("ReadyCheck"); Card:Show()
end

local function ResetLive()
	LogClear(S.dmg); LogClear(S.heal); LogClear(S.loss)
	Wipe(S.runDmg); Wipe(C.act); Wipe(C.hist); Wipe(C.logT); Wipe(Cur.p)
	S.runDmgSum, S.pool, S.xpT, S.xpRate, S.px, S.speed, S.moving = 0, nil, nil, 0, nil, nil, nil
	S.emptyT, S.lostT, S.lives, S.lastLvl, S.lvlT, S.prevSt, S.lastHitT = nil, nil, nil, nil, nil, nil, nil
	S.h.n, S.h.t = 0, 0
end

local function FinalizeRun()
	local ar = S.activeRun
	if not ar or ar.duration < 20 then S.activeRun = nil; return end
	NS.DB.betaPB = NS.DB.betaPB or {}
	local prev = NS.DB.betaPB[ar.zoneKey] or {}
	local before = { peakDps = prev.peakDps or 0, kills = prev.kills or 0, gold = prev.gold or 0, lvl = prev.lvl or 0, kpm = prev.kpm or 0 }
	local mins = max(0.1, ar.duration / 60.0)
	ar.kpm, ar.gpm = ar.kills / mins, ar.gold / mins
	FillThreat(ar)
	prev.peakDps, prev.kills = max(prev.peakDps or 0, ar.peakDps), max(prev.kills or 0, ar.kills)
	prev.gold, prev.lvl = max(prev.gold or 0, ar.gold), max(prev.lvl or 0, ar.lvl)
	prev.kpm = max(prev.kpm or 0, (ar.duration >= 60) and ar.kpm or 0)
	prev.runs = (prev.runs or 0) + 1
	NS.DB.betaPB[ar.zoneKey] = prev
	local cfg = NS.DB.beta
	if cfg and cfg.runPace and cfg.showPostRunCard ~= false then RenderSummary(ar, before, false) end
	S.activeRun = nil; ResetLive()
end

local function Row2(l, r, rr, rg, rb, lr, lg, lb) GameTooltip:AddDoubleLine(l, r, lr or 0.75, lg or 0.80, lb or 0.88, rr or 1, rg or 1, rb or 1) end
local lastTip = 0
local function ShowTip()
	local r = S.rep
	if not r then return end
	lastTip = GetTime()
	GameTooltip:SetOwner(Panel, "ANCHOR_RIGHT"); GameTooltip:ClearLines()
	GameTooltip:AddLine("Coach & " .. r.simSec .. "s Stand-Still Simulation", 0.82, 0.70, 1.00)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("1. Stand-Still Simulation (" .. r.simSec .. "s)", 0.00, 0.92, 0.78)
	Row2("  Current Pool (HP + Shield):", fmt("%s (+%s)", NS.FormatNumber(r.curHp), NS.FormatNumber(r.shield)))
	Row2("  Damage Taken (Real / Model):", fmt("%.0f/s  |  %.0f/s", r.realInDps, r.modelInDps), 1.0, 0.55, 0.55)
	Row2("  Sustain (Regen+Leech+Heal):", fmt("+%.0f/s (%.0f+%.0f+%.0f)", r.sustain, r.regVal, r.leech, r.realInHps), 0.40, 1.0, 0.65)
	local drain = r.net > 0
	Row2("  Net Standing Balance:", drain and fmt("-%.0f/s (Dies in %.1fs)", r.net, min(99.9, r.ttk)) or fmt("+%.0f/s (Sustainable)", -r.net), drain and 1 or 0.4, drain and 0.45 or 1, 0.45)
	local m = r.mobs
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("2. Monster Pressure", 1.0, 0.78, 0.35)
	Row2("  Horde / Elites / Guardians / Boss:", fmt("%d/%d · %dE · %dG · %dB", m.en, m.enm, m.elites, m.guardians, m.bosses), 1, 0.90, 0.60)
	if r.attackers > 0 then Row2("  Enemies hitting you (5s):", tostring(r.attackers), 1, 0.55, 0.45) end
	if S.tn then
		Row2("  Top damage source (8s):", fmt("%s (%d%%)", Short(S.tn, 20), S.tp), 1, 0.60, 0.45)
		if S.tn2 then Row2("  2nd source:", fmt("%s (%d%%)", Short(S.tn2, 20), S.tp2), 0.90, 0.60, 0.50, 0.65, 0.70, 0.78) end
	end
	local ar = S.activeRun
	if ar then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("3. Run Pace", 0.55, 0.85, 1.0)
		local k30 = Rate(S.h.k, 30)
		Row2("  Kills/min (30s / avg):", fmt("%s / %.0f", k30 and fmt("%.0f", k30) or "--", ar.kills / max(0.05, ar.duration / 60)))
		local pb = NS.DB and NS.DB.betaPB and NS.DB.betaPB[ar.zoneKey]
		if pb and (pb.kpm or 0) > 0 then Row2("  PB kill pace (kills/min):", fmt("%.0f", pb.kpm), 1, 0.92, 0.50) end
		Row2("  Time at risk / near-deaths:", fmt("%ds / %d", ar.riskSec, ar.near), 1, 0.80, 0.40)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("4. Upgrade Recommendation", 0.98, 0.88, 0.42)
	Row2("  Priority:", r.focusColor .. r.focusTag .. " (" .. r.focusSub .. ")|r")
	GameTooltip:AddLine("  " .. r.focusReason, 0.85, 0.88, 0.94, true)
	Row2("  Marginals (+1 step):", fmt("Def +%.1f%% | CDR +%.1f%% | %s +%.1f%%", r.gains.def, r.gains.cdr, r.gains.offSub, r.gains.off), 0.90, 0.92, 0.96, 0.65, 0.70, 0.78)
	local p = r.profile
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("5. Talents, Gear & Ideal Skill", 0.78, 0.62, 1.0)
	Row2("  Primary Tree:", fmt("%s (%s) · iLvl %d", p.primaryTree, p.treeSummary, p.avgIlvl), 0.85, 0.75, 1.0)
	Row2("  Recommended Skill Up:", fmt("%s (%s)", r.skLabel or "-", r.skReason or "-"), 0.0, 1.0, 0.82)
	if r.sk2 then Row2("  2nd Skill Option:", r.sk2, 0.78, 0.84, 0.90, 0.60, 0.65, 0.75) end
	if C.list[1] then
		GameTooltip:AddLine(" "); GameTooltip:AddLine("6. Live Coach", 0.70, 0.55, 1.0)
		for i = 1, #C.list do GameTooltip:AddLine("  " .. C.list[i].text, 1, 1, 1, true) end
	end
	local h = C.hist
	if #h > 0 then
		GameTooltip:AddLine(" "); GameTooltip:AddLine("7. Coach History", 0.60, 0.65, 0.75)
		for i = #h, max(1, #h - 4), -1 do GameTooltip:AddLine("  " .. NS.FormatTime(h[i].t) .. "  " .. h[i].text, 0.85, 0.88, 0.94, true) end
	end
	GameTooltip:Show()
end
Panel:SetScript("OnEnter", function() S.hover = true; ShowTip() end)
Panel:SetScript("OnLeave", function() S.hover = false; GameTooltip:Hide() end)

local DEMO_SNAP = {
	zoneKey = "Deepholm [Normal]", duration = 492, peakDps = 1840, kills = 612, kpm = 74.6, gold = 340, gpm = 41.4, lvl = 24,
	mvpName = "Pestilence", mvpDps = 920, threat = "Fire Nova", threatPct = 38, riskSec = 96, near = 2, minPct = 12,
}
local DEMO_PB = { peakDps = 1420, kills = 580, gold = 390, lvl = 22, kpm = 80 }
local EDIT_DEMO_COACH = {
	{ "crit", "|cffff4444[!]|r Dies in 2.8s - move now!" },
	{ "warn", "|cffffcc66[R]|r Pace dropped 38% - engage more mobs" },
	{ "good", "|cff55ff99[+]|r Level 24! Up: Pestilence R2" },
}

local Mod = { frame = Panel, summaryFrame = Card }
function Mod.ShowSummary(isDemo)
	if isDemo or not S.activeRun then RenderSummary(DEMO_SNAP, DEMO_PB, true)
	else
		local ar = S.activeRun
		local mins = max(0.1, ar.duration / 60.0)
		ar.kpm, ar.gpm = ar.kills / mins, ar.gold / mins
		FillThreat(ar)
		RenderSummary(ar, (NS.DB and NS.DB.betaPB and NS.DB.betaPB[ar.zoneKey]) or {}, false)
	end
end
function Mod.ResetPBs() if NS.DB then NS.DB.betaPB = {} end; S.activeRun = nil end

local function SetRow(rows, i, lbl, val) SetTxt(rows[i].lbl, "|cffb0bccd" .. lbl .. "|r"); SetTxt(rows[i].val, val) end
local function RenderEditPreview(coach)
	Layout(true, coach)
	SetTxt(Panel.pbBadge, "|cff00ffccPB +14%|r")
	if S.bannerCode ~= "DEMO" then
		S.bannerCode = "DEMO"
		Banner:SetBackdropColor(0.24, 0.05, 0.07, 0.92); Banner:SetBackdropBorderColor(0.88, 0.18, 0.22, 0.90)
	end
	SetTxt(Banner.left, "|cffff4444DIES IN 2.8s|r |cffffaaaa(STANDING)|r"); SetTxt(Banner.right, "|cffff7777-64/s|r")
	SetRow(TacRows, 1, "Upgrade", "|cff55ccffDEFENSE|r |cff8aa4bd(Red 30/60%)|r")
	SetRow(TacRows, 2, "Up Skill", "|cff00ffccPestilence R2|r")
	SetRow(TacRows, 3, "Threat", "|cffffffff14m|r |cff4499ff1E|r |cffff88221B|r |cffff6666(98/s)|r")
	SetRow(TacRows, 4, "Talent", "|cffd2b4ffUnholy (31)|r |cff8899aa· iLvl 219|r")
	SetRow(PaceRows, 1, "Kills / min", "|cffffffff74/min|r")
	SetRow(PaceRows, 2, "Gold / min", "|cffffd70042/min|r")
	SetRow(PaceRows, 3, "Next Level", "|cffcc99ff~19s|r")
	SetRow(PaceRows, 4, "Peak DPS", "|cffffea891.8K/s|r")
	if coach then
		for i = 1, 3 do
			local c = SEV[EDIT_DEMO_COACH[i][1]]
			CoachRows[i].bar:SetVertexColor(c[1], c[2], c[3], 0.95)
			SetTxt(CoachRows[i].txt, EDIT_DEMO_COACH[i][2])
		end
	end
	Panel:Show()
end

function Mod.Update(ctx)
	local cfg = NS.DB and NS.DB.beta
	if not (cfg and cfg.runPace) or NS.IsBoxHidden("BetaRunPace") then
		if not ctx.isEditing and Panel:IsShown() then Panel:Hide() end
		if not (cfg and cfg.runPace) or not ctx.isEditing then return end
	end
	local run, zone, coachOn = ctx.run, ctx.zone, cfg.coach ~= false
	if ctx.inHub then
		S.inRun = false
		if S.activeRun then FinalizeRun() end
		if S.live then S.live = false; ResetLive() end
		if ctx.isEditing then RenderEditPreview(coachOn) elseif Panel:IsShown() then Panel:Hide() end
		return
	end
	local now = ctx.now
	if now - S.tickT < TICK and Panel:IsShown() then return end
	local dt = min(1, now - S.tickT)
	S.tickT, S.inRun, S.live = now, true, true
	local runClock, zKey = ctx.runClock or 0, GetZoneKey(zone)
	if S.activeRun and S.activeRun.duration > 20 and runClock < 3 then FinalizeRun() end
	if not S.activeRun then
		S.activeRun = { zoneKey = zKey, duration = 0, peakDps = 0, kills = 0, gold = 0, lvl = 1, mvpName = "-", mvpDps = 0, riskSec = 0, near = 0, minPct = 100 }
		ResetLive(); S.pDirty = true
	end
	local ar = S.activeRun
	local kills, gold, lvl = num(run.kills), num(run.gold), num(run.lvl, 1)
	local xp, xpn = num(run.xp), max(1, num(run.xpn, 100))
	local curDps, mvpName, mvpDps, byName = ReadMeter(ctx.tickId)
	ar.zoneKey, ar.duration = zKey, max(ar.duration, runClock)
	ar.kills, ar.gold, ar.lvl = max(ar.kills, kills), max(ar.gold, gold), max(ar.lvl, lvl)
	if curDps > ar.peakDps then ar.peakDps = curDps end
	if mvpDps >= ar.mvpDps and mvpName ~= "-" then ar.mvpName, ar.mvpDps = mvpName, mvpDps end
	if S.lastLvl and lvl > S.lastLvl then S.lvlT = now end
	S.lastLvl = lvl
	HistPush(now, kills, curDps, gold)
	local px, py = GetPos(run)
	UpdateMotion(now, px, py)
	S.nc, S.nl = Nearest(_G.AZS_CHESTS, px, py, false), Nearest(NS.GetLairs(), px, py, true)
	if S.xpT then
		local d = now - S.xpT
		if d >= 1.5 then
			local dxp = (lvl > S.xpL) and (xp + max(0, S.xpN - S.xpV)) or (xp - S.xpV)
			if dxp >= 0 then
				local inst = dxp / d
				S.xpRate = (S.xpRate > 0) and (S.xpRate * 0.65 + inst * 0.35) or inst
			end
			S.xpT, S.xpV, S.xpN, S.xpL = now, xp, xpn, lvl
		end
	else
		S.xpT, S.xpV, S.xpN, S.xpL = now, xp, xpn, lvl
	end
	local mins = max(0.05, runClock / 60.0)
	local etaStr, etaSec = "--", nil
	if S.xpRate > 0.5 then
		etaSec = max(1, floor((xpn - xp) / S.xpRate))
		etaStr = (etaSec > 600) and ">10m" or ("~" .. NS.FormatTime(etaSec))
	end
	local pb = NS.DB and NS.DB.betaPB and NS.DB.betaPB[zKey]
	local pbDps = (pb and pb.peakDps) or 0
	SetTxt(Panel.pbBadge, (pbDps > 0 and ar.peakDps > pbDps) and "|cff00ffccNEW PB!|r"
		or (pbDps > 0 and fmt("|cff94a3b8PB %s/s|r", NS.FormatNumber(pbDps)) or "|cffb088ff1ST RUN|r"))

	local tac = (cfg.tacticalAdvisor ~= false)
	Layout(tac, coachOn)
	if tac or coachOn then
		local rep = Report(ctx, runClock, curDps, byName, now)
		S.rep = rep
		local code, hot = rep.statusCode, S.lastHitT and (now - S.lastHitT) < 4
		if code ~= "SAFE" and hot then ar.riskSec = ar.riskSec + dt end
		if code == "DIE" and hot and S.prevSt ~= "DIE" and now - (S.dieT or -99) > 8 then ar.near, S.dieT = ar.near + 1, now end
		S.prevSt = code
		ar.minPct = min(ar.minPct, max(0, rep.pool / rep.maxHp * 100))
		if coachOn then
			RunCoach(now, runClock, curDps, ar, pb, lvl, etaSec, run)
			CoachCommit(now, runClock, cfg.coachSound ~= false)
			for i = 1, 3 do
				local row, a = CoachRows[i], C.list[i]
				if a then
					local c = SEV[a.sev] or SEV.info
					row.bar:SetVertexColor(c[1], c[2], c[3], 0.95)
					SetTxt(row.txt, a.text)
				else
					row.bar:SetVertexColor(0.25, 0.28, 0.36, 0.5)
					SetTxt(row.txt, (i == 1) and "|cff6e7c94All clear - no active alerts|r" or "")
				end
			end
		end
		if tac then
			if S.bannerCode ~= code then
				S.bannerCode = code
				Banner:SetBackdropColor(rep.bR * 0.25, rep.bG * 0.25, rep.bB * 0.25, 0.92)
				Banner:SetBackdropBorderColor(rep.bR, rep.bG, rep.bB, 0.90)
			end
			SetTxt(Banner.left, rep.bannerText)
			SetTxt(Banner.right, (rep.net > 0.5) and fmt("|cffff6666-%s/s|r", NS.FormatNumber(rep.net))
				or (rep.net < -0.5) and fmt("|cff55ff99+%s/s|r", NS.FormatNumber(-rep.net)) or "|cff94a3b80/s|r")
			SetRow(TacRows, 1, "Upgrade", fmt("%s%s|r |cff8aa4bd(%s)|r", rep.focusColor, rep.focusTag, rep.focusSub))
			SetRow(TacRows, 2, "Up Skill", fmt("|cff00ffcc%s|r", rep.skLabel or "-"))
			local m = rep.mobs
			local th = fmt("|cffffffff%dm|r", m.en)
			if m.elites > 0 then th = th .. fmt(" |cff4499ff%dE|r", m.elites) end
			if m.guardians > 0 then th = th .. fmt(" |cffb866ff%dG|r", m.guardians) end
			if m.bosses > 0 then th = th .. fmt(" |cffff8822%dB|r", m.bosses) end
			SetRow(TacRows, 3, "Threat", th .. fmt(" |cffff7777(%s/s)|r", NS.FormatNumber(rep.stationary)))
			local p = rep.profile
			SetRow(TacRows, 4, "Talent", fmt("|cffd2b4ff%s (%d)|r%s", p.primaryTree, p.primaryPts, p.avgIlvl > 0 and (" |cff8899aa· iLvl " .. p.avgIlvl .. "|r") or ""))
		end
	end
	SetRow(PaceRows, 1, "Kills / min", fmt("|cffffffff%.0f/min|r", kills / mins))
	SetRow(PaceRows, 2, "Gold / min", fmt("|cffffd700%.0f/min|r", gold / mins))
	SetRow(PaceRows, 3, "Next Level", "|cffcc99ff" .. etaStr .. "|r")
	SetRow(PaceRows, 4, "Peak DPS", "|cffffea89" .. NS.FormatNumber(ar.peakDps) .. "/s|r")
	Panel:Show()
	if S.hover and now - lastTip >= 0.5 then ShowTip() end
end

NS.BetaModules.RunPace = Mod
