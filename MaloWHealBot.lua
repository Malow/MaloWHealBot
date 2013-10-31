-- Todo:
-- A function to calculate effectiveMissingHealth, that counts hots, to be used instead when looking to cancel spells as well as finding targets. 
--		Maybe value hots only to half of their heal left?
--
-- A way for healers to scan other healers in the raid and see what they are casting and on what and duration left, guesstimate how much they will 
-- 		heal for and calculate effectiveMissinghealth through that too.
--		
--	Potential problem with using IsCurrentAction() to check for isCasting() -> if IsCurrentAction() has lag the bot might get a target and start casting, and on
-- 		next iteration IsCurrentAction() is false due to lag, and it picks another target and starts casting on that, but the heal actually starts on the old target.
--		The StopCasting part is now failing cuz it thinks ur casting on another target. Also might give delay between stopping cast and starting new cast?
--
-- Outside /mhbready trigger, scan whisper, party and raid for "MHBREADY"?
--
-- Use CDs / racials
--
-- OnEvent SpellStart and SpellStop, use a global bool for IsCasting.
--
-- Line of Sight, implement some sort of blacklisting of targets that are LOS
--
-- Dispelling vs healing, have a priority next to each dispell, where 0 is blacklist (never dispell) and depending on priority and raid health etc. it chooses to dispell or heal.
--
--
-- TODAY:
-- Target has to have taken 500 dmg for healers to cast a heal at all.
--
-- Stop healing wave spam with shammys, make them save their mana more and use it for chain heals.
--
-- Do a HPM calc, and change healing accordingly. 
--
-- If a target is damaged 2500, and there are 3 other healers, dont cast a heal that heals for 2500, do a 1k heal instead, kinda. Make the priests renew more as well if it's good HPM.
--	The more healers in the raid the more you can count on healing coming from other sources as well.
--
-- Also could use some way to desync their castings so they dont all cast at the exact same time. Donno how though.. Initial delay on first spell cast when entering combat of 0 - 2 sec?
--
-- TargetAndCast: movement
--
-- Fill up manacost and reagent tables
-- 
--	Instead of scanning through all bags for reagent / water checks, do it once upon load, and keep temporary counters for the remaining amounts.
--



-- Static Global variables
COEF_CANCEL_HEAL = 0.8;
GCD_TIME_LEFT_BEFORE_CANCEL = 0.2;
DRINK_AT_MANAPERCENT = 0.75;
BUFF_DRINKING = "Interface\\Icons\\INV_Drink_07";
ITEM_DRINK = "Interface\\Icons\\INV_Potion_01";
MAX_BUFFS = 32;
MAX_DEBUFFS = 32;

REBUFF_SELF = "RebuffSelf";
REBUFF_RAID = "RebuffRaid";
REBUFF_RAID_MANAUSERS = "RebuffRaidManausers";

TIME_TEN_MINUTES = 600;
TIME_EIGHT_MINUTES = 480;

-- Global variables
currentTarget = "player";
currentSpell = "none";
GCD_CHECK_SPELL = 0;


-- Main
SlashCmdList["MHBCOMMAND"] = function(followTarget) 
	if followTarget ~= "" then
		FollowByName(followTarget, true);
	end
	
	local playerClass = mhb_GetClass("player");

	if playerClass == "PRIEST" then
		mhb_Priest();
	end
	if playerClass == "SHAMAN" then
		mhb_Shaman();
	end
end 
SLASH_MHBCOMMAND1 = "/mhb";

-- Ready Check
SlashCmdList["MHBREADYCOMMAND"] = function(msg) 
	local ready = true;
	-- Remove buffs that needs rebuff
	if mhb_RemoveBuffsForRebuff() then
		ready = false;
	end
	
	-- Drink up fully.
	if mhb_DrinkIfNeeded(1) then
		ready = false;
	end
	
	-- If not ready print in chat.
	if not ready then
		mhb_PrintInPartyOrRaid("I am NOT ready!");
	end
end 
SLASH_MHBREADYCOMMAND1 = "/mhbready";

-- setOption
SlashCmdList["MHBOPTIONCOMMAND"] = function(msg) 
	local playerClass = mhb_GetClass("player");

	if playerClass == "PRIEST" then
		mhb_Priest_SetOption(msg);
	end
end 
SLASH_MHBOPTIONCOMMAND1 = "/mhboption";

-- Register eventlistening, this gets called before globals are given values, so global values set here will be overridden by default values.
function mhb_OnLoad()
	local playerClass = mhb_GetClass("player");
	mhb_Print("MaloWHealBot loaded for class " .. playerClass);
	this:RegisterEvent("ADDON_LOADED");
end

-- load class specific stuff.
function mhb_AfterLoad()
	local playerClass = mhb_GetClass("player");
	if playerClass == "PRIEST" then
		GCD_CHECK_SPELL = 76; -- Renew(Rank 1)
	end
	if playerClass == "SHAMAN" then
		GCD_CHECK_SPELL = 129; -- Healing Wave(Rank 1)
	end
	
	-- Disable autoself cast to make the mhb_IsSpellInRange checker work.
	SetCVar("autoSelfCast", 0);
end

--	this:RegisterEvent("SPELLCAST_START");
--	this:RegisterEvent("SPELLCAST_STOP");
--	this:RegisterEvent("SPELLCAST_FAILED");
--	this:RegisterEvent("SPELLCAST_INTERRUPTED");
--	this:RegisterEvent("SPELLCAST_DELAYED");
--	this:RegisterEvent("SPELLCAST_CHANNEL_START");
--	this:RegisterEvent("SPELLCAST_CHANNEL_UPDATE");

-- This gets called by outside when events that Ive registered for happens.
function mhb_OnEvent()
	if event == "ADDON_LOADED" then
		mhb_AfterLoad();
	end
end



-- 1.12 API: http://www.wowwiki.com/World_of_Warcraft_API?oldid=263854
-- Range checker for PoH: http://www.wowwiki.com/API_CheckInteractDistance
-- to find out if ur oom: http://www.wowwiki.com/API_IsUsableSpell
-- spell cooldown: http://www.wowwiki.com/API_GetSpellCooldown?oldid=26192 OR http://www.wowwiki.com/API_GetSpellCooldown?direction=next&oldid=101273/ http://www.wowwiki.com/API_GetActionCooldown
-- buffs: http://www.wowwiki.com/API_GetPlayerBuff / http://www.wowwiki.com/API_GetPlayerBuffName / http://www.wowwiki.com/API_GetPlayerBuffTimeLeft / http://www.wowwiki.com/API_UnitBuff / http://www.wowwiki.com/API_UnitDebuff
-- get time to calc with durations etc: http://www.wowwiki.com/API_GetTime
-- Buffname list: http://www.wowwiki.com/index.php?title=Queriable_buff_effects&oldid=277417


	



-- In game macros:
-- List all buffs and debuffs:
-- /run for i = 1, 32 do local b = UnitBuff("player", i); if b then ChatFrame1:AddMessage("Buff: " .. b); end local d = UnitDebuff("player", i); if d then ChatFrame1:AddMessage("Debuff: " .. d); end end
--
-- List all spells you know and their IDs:
-- /run for i = 1, 1000 do local s = GetSpellName(i, "BOOKTYPE_SPELL"); if s then ChatFrame1:AddMessage(i .. " - " .. s); end end
--
-- Get cooldown left for spellid:
-- /run local s, d = GetSpellCooldown(76, "BOOKTYPE_SPELL"); if d ~= 0 then c = d - (GetTime() - s); ChatFrame1:AddMessage(c); else ChatFrame1:AddMessage("0"); end
-- 
-- Print which is your current action:
-- /run for i = 1, 1000 do if IsCurrentAction(i) then ChatFrame1:AddMessage(i .. " is current action"); end end






-- tons of macros: http://www.wow-one.com/forum/topic/14546-warrior-tanking-macro-priest-heal-multiboxing-macro/page__hl__%2Bbuff+%2Bduration__fromsearch__1

--/run 
--	a = UseAction a(43)a(44)a(45)a(46)U=IsAutoRepeatAction ub=UnitBuff ud=UnitDebuff WS="WHISPER" ue=UnitExists uf=UnitIsFriend 
---	GAC=GetActionCooldown gt=GetTime sc1,sc2,sc3,sc4,sc5,sc6,tg12,tg34,tg56=0,0,0,0,0,0,0,0,0 bsT=105 saT=23 hmsT=12
--
--/run UIErrorsFrame:Hide() UIErrorsFrame:Clear() c=CastSpellByName u=IsCurrentAction s=SpellStopCasting um=UnitMana UM=UnitManaMax 
--	m=SendChatMessage uh=UnitHealth UH=UnitHealthMax p="player" t="target" d=CheckInteractDistance PT="Kokkolarp"
--
--/run 
--	sc6 = GetTime()
---	local qwe = 0 
	--if qwe == 1 then 
	--	CastSpellByName("Hamstring")
	--end 
--	a(33)
--	tg56 = sc6-sc5 
--	if UnitExists(t) and not UnitIsFriend(p, t) and CheckInteractDistance(t, 3) and x1 == 0 and (hmsD == 0 or tg56 > hmsT) and um(p) >= 10 then 
--		sc5 = GetTime()
--		CastSpellByName(hms)
--	end




















