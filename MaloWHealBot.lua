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

------------------------------------------------------------------------------------
-- General Functions ---------------------------------------------------------------
------------------------------------------------------------------------------------
function mhb_Rebuff(buff, spell, rebuff)
	if rebuff == REBUFF_RAID then
		buffUnit = mhb_GetRebuffTarget(spell, buff, "none");
		if buffUnit ~= "none" then
			if mhb_TargetAndCast(buffUnit, spell) then return true; end
		end
	elseif rebuff == REBUFF_RAID_MANAUSERS then
		buffUnit = mhb_GetRebuffTarget(spell, buff, "HasMana");
		if buffUnit ~= "none" then
			if mhb_TargetAndCast(buffUnit, spell) then return true; end
		end	
	elseif rebuff == REBUFF_SELF then
		if not mhb_HasBuff("player", buff) then
			if mhb_TargetAndCast("player", spell) then return true; end
		end
	end
	return false;
end

function mhb_DrinkIfNeeded(percent)
	local didAction = false;
	local manaPercent = UnitMana("player") / UnitManaMax("player");
	if manaPercent < percent then
		mhb_Drink();
		didAction = true;
	end
	return didAction;
end

function mhb_Resurrect(spell)
	if mhb_IsCasting() == true then
		if currentSpell == spell then
			if not UnitIsDead(currentTarget) then
				mhb_StopCasting();
			end
		end
	end
	local deadUnit = mhb_GetDeadTarget(spell);
	if deadUnit ~= "none" then
		if mhb_TargetAndCast(deadUnit, spell) then return true; end
	end
	return false;
end

function mhb_RemoveBuffsForRebuff()
	local didAction = false;
	for i = 1, MAX_BUFFS do 
		local b = UnitBuff("player", i); 
		if b then 
			local duration = GetPlayerBuffTimeLeft(i - 1);
			-- Priest buffs
			if b == BUFF_POWER_WORD_FORTITUDE then
				if duration < TIME_TEN_MINUTES then
					CancelPlayerBuff(i - 1);
					didAction = true;
				end				
			elseif b == BUFF_DIVINE_SPIRIT then
				if duration < TIME_TEN_MINUTES then
					CancelPlayerBuff(i - 1);
					didAction = true;
				end				
			elseif b == BUFF_SHADOW_PROTECTION then
				if duration < TIME_EIGHT_MINUTES then
					CancelPlayerBuff(i - 1);
					didAction = true;
				end
			elseif b == BUFF_INNER_FIRE then
				if duration < TIME_EIGHT_MINUTES or GetPlayerBuffApplications(i - 1) < 20 then
					CancelPlayerBuff(i - 1);
					didAction = true;
				end
			elseif b == BUFF_LIGHTNING_SHIELD then
				if duration < TIME_EIGHT_MINUTES or GetPlayerBuffApplications(i - 1) < 3 then
					CancelPlayerBuff(i - 1);
					didAction = true;
				end
			end
		end 
	end
	return didAction;
end


------------------------------------------------------------------------------------
-- TargetSelectors -----------------------------------------------------------------
------------------------------------------------------------------------------------

-- Scans through the raid or party for the unit missing the most health.
function mhb_GetMostDamagedTarget(spell)
	local healTarget = 0;
	local missingHealthOfTarget = mhb_GetMissingHealth("player");
	members = mhb_GetNumPartyOrRaidMembers();
	for i = 1, members do 
		local unit = mhb_GetUnitFromPartyOrRaidIndex(i);
		local missingHealth = mhb_GetMissingHealth(unit); 
		if mhb_IsValidTarget(unit, spell) then 
			if missingHealth > missingHealthOfTarget then 
				missingHealthOfTarget = missingHealth;
				healTarget = i; 
			end 
		end 
	end 
	local healTargetUnit = mhb_GetUnitFromPartyOrRaidIndex(healTarget);
	-- Avoid selfhealing spirit of redemption
	if healTargetUnit == "player" and mhb_HasBuff("player", BUFF_SPIRIT_OF_REDEMPTION) then
		healTargetUnit = "none";
		missingHealthOfTarget = 0;
	end
	return healTargetUnit, missingHealthOfTarget;
end

-- Scans through the raid or party for the unit with the lowest current health.
function mhb_GetLowestHealthTarget(spell)
	local healTarget = 0;
	local healthOfTarget = UnitHealth("player");
	members = mhb_GetNumPartyOrRaidMembers();
	for i = 1, members do 
		local unit = mhb_GetUnitFromPartyOrRaidIndex(i);
		local health = UnitHealth(unit); 
		if mhb_IsValidTarget(unit, spell) then 
			if health < healthOfTarget then 
				healthOfTarget = health;
				healTarget = i; 
			end 
		end 
	end 
	local healTargetUnit = mhb_GetUnitFromPartyOrRaidIndex(healTarget);
	-- Avoid selfhealing spirit of redemption
	if healTargetUnit == "player" and mhb_HasBuff("player", BUFF_SPIRIT_OF_REDEMPTION) then
		healTargetUnit = "none";
		healthOfTarget = 10000;
	end
	return healTargetUnit, healthOfTarget;
end

-- Scans through the raid or party for a unit that doesn't have the buff, returns "none" if none is found.
function mhb_GetRebuffTarget(spell, buff, extraConstraint)
	local buffUnit = "none";
	members = mhb_GetNumPartyOrRaidMembers();
	for i = 0, members do 
		local unit = mhb_GetUnitFromPartyOrRaidIndex(i);
		if mhb_IsValidTarget(unit, spell) then 
			if not mhb_HasBuff(unit, buff) then 
				if extraConstraint == "HasMana" and not mhb_HasMana(unit) then
					-- Do nothing, target doesnt have mana so extraConstraint fail.
				else
					buffUnit = unit; 
					i = members;
				end
			end 
		end 
	end 
	return buffUnit;
end

-- Scans for a dead target
function mhb_GetDeadTarget(spell)
	local deadTarget = "none";
	members = mhb_GetNumPartyOrRaidMembers();
	for i = 0, members do 
		local unit = mhb_GetUnitFromPartyOrRaidIndex(i);
		if UnitIsDead(unit) and IsSpellInRange(spell, unit) then 
			deadTarget = unit;
			i = members;
		end 
	end 
	return deadTarget;
end

-- Scans for a target with a dispelable debuff
function mhb_GetDispelTarget(spell, dispelType, buff)
	local dispelTarget = "none";
	members = mhb_GetNumPartyOrRaidMembers();
	for i = 0, members do 
		local unit = mhb_GetUnitFromPartyOrRaidIndex(i);
		if mhb_IsValidTarget(unit, spell) then 
			if mhb_HasDebuffType(unit, dispelType) then
				if not mhb_HasBuff(unit, buff) then 
					dispelTarget = unit; 
					i = members;
				end
			end
		end
	end 
	return dispelTarget;
end

-- Returns a table of damaged raid members
function mhb_GetDamagedTargets(spell, melee, damageReq)
	local targets = {};
	members = mhb_GetNumPartyOrRaidMembers();
	for i = 0, members do 
		local unit = mhb_GetUnitFromPartyOrRaidIndex(i);
		local missingHealth = mhb_GetMissingHealth(unit); 
		if mhb_IsValidTarget(unit, spell) then 
			if missingHealth > damageReq then 
				if (melee and mhb_IsMelee(unit)) or (not melee and not mhb_IsMelee(unit)) then 
					targets[unit] = missingHealth;
				end
			end 
		end 
	end 
	return targets;
end

----------------------------------------------------------------------------------------------------
-- Utilities ---------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- Returns amount of party members based on role
function mhb_GetNrOfValidPartyMembersByRole(role, spell)
	local count = 0;
	for i = 1, GetNumPartyMembers() do
		if role == "MELEE" and mhb_IsMelee("party" .. i) and mhb_IsValidTarget("party" .. i, spell) then
			count = count + 1;
		end
	end
	return count;
end

-- Returns amount of party members based on class
function mhb_GetNrOfValidPartyMembersByClass(class, spell)
	local count = 0;
	for i = 1, GetNumPartyMembers() do
		if mhb_GetClass("party" .. i) == class and mhb_IsValidTarget("party" .. i, spell) then
			count = count + 1;
		end
	end
	return count;
end

-- returns a string in caps of which class unit is of.
function mhb_GetClass(unit)
	local _, playerClass = UnitClass(unit);
	return playerClass;
end

-- Checks if unit is a melee character.
function mhb_IsMelee(unit)
	return not mhb_HasMana(unit);
end

-- Checks if unit has mana as energy type.
function mhb_HasMana(unit)
	local playerClass = mhb_GetClass(unit);
	if playerClass == "MAGE" or playerClass == "PRIEST" or playerClass == "SHAMAN" or playerClass == "PALADIN" or playerClass == "WARLOCK" or playerClass == "HUNTER" or playerClass == "DRUID" then
		return true;
	else
		return false;
	end
end

-- Stops casting and sets currentSpell and currentTarget to defualt values.
function mhb_StopCasting()
	currentSpell = "none";
	currentTarget = "player";
	SpellStopCasting();
end

-- Sets currentSpell and currentTarget and then targets the currentTarget, and starts casting the spell on it.
-- NEEDS TO RETURN TRUE / FALSE. false if spellcast failed due to moving or oom.
-- http://www.wowwiki.com/API_IsUsableSpell?oldid=391020 for oom? Was added december, might not exist in 1.12
function mhb_TargetAndCast(unit, spell)
	currentTarget = unit;
	currentSpell = spell;
	TargetUnit(currentTarget);
	CastSpellByName(currentSpell);
	return true;
end

-- Returns true if you're currently casting an action that is on your actionbar in slot 7 to 12.
function mhb_IsCasting()
	local casting = false;
	for i = 7, 12 do 
		if IsCurrentAction(i) then
			casting = true;
		end
	end
	return casting;
end

-- Calculates missing health from maxhealth - current health
function mhb_GetMissingHealth(unit)
	local missingHealth = UnitHealthMax(unit) - UnitHealth(unit);
	return missingHealth;
end

-- Checks if target exists, is visible, is friendly and if it's dead or ghost, and if it has spirit of redemption buff
function mhb_IsStillValidTarget(unit)
	isValid = false; 
	if UnitExists(unit) and UnitIsVisible(unit) and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit) and not mhb_HasBuff(unit, BUFF_SPIRIT_OF_REDEMPTION) then
		isValid = true; 
	end 
	return isValid; 
end 

-- Checks if target exists, is visible, is friendly and if it's dead or ghost AND if it's in range of spell.
function mhb_IsValidTarget(unit, spell)
	isValid = false; 
	local inRange = 0
	if mhb_IsStillValidTarget(unit) then
		inRange = mhb_IsSpellInRange(spell, unit)
	end
	if inRange == 1 then
		isValid = true;
	end
	return isValid; 
end 

-- Returns number of members in your raid, if ur not in raid returns number of members in your party.
function mhb_GetNumPartyOrRaidMembers()
	local num = 0;
	if UnitInRaid("player") then
		num = GetNumRaidMembers();
	else
		num = GetNumPartyMembers();
	end
	return num;
end

-- If index is 0 returns "player", otherwise checks too see if you're in raid and returns "raid"+index, otherwise "party"+index
function mhb_GetUnitFromPartyOrRaidIndex(index)
	unit = "player";
	if index ~= 0 then
		if UnitInRaid("player") then
			unit = "raid" .. index;
		else
			unit = "party" .. index
		end
	end
	return unit;
end

-- Returns true if said spell is in range to unit. NEEDS autoself cast off.
function mhb_IsSpellInRange(spell, unit)
	local can = false;
	ClearTarget(); 
	CastSpellByName(spell, false);
	if SpellCanTargetUnit(unit) then
		can = true;
	end
	SpellStopTargeting();
	return can;
end

-- Returns true or false depending on if you're on GCD in X amount of seconds.
function mhb_IsOnGCDIn(timeToCheck)
	local gcd = false;
	local cdLeft = mbh_GetCooldownLeft(GCD_CHECK_SPELL);
	if cdLeft > timeToCheck then
		gcd = true;
	end
	return gcd;
end

-- Checks if unit is in combat.
function mhb_IsInCombat(unit)
	local combat = false;
	if UnitAffectingCombat(unit) then
		combat = true;
	end
	return combat;
end

-- Checks if unit has a debuff of type
function mhb_HasDebuffType(unit, debuffType)
	local has = false;
	for i = 1, MAX_DEBUFFS do
		local _, _, debuffDispelType = UnitDebuff(unit, i);
		if debuffDispelType == debuffType then
			has = true;
			i = MAX_DEBUFFS;
		end
	end
	return has;
end

-- Checks if unit has debuff
function mhb_HasDebuff(unit, debuff)
	local has = false;
	for i = 1, MAX_DEBUFFS do
		local d = UnitDebuff("player", i);
		if d and d == debuff then
			has = true;
		end
	end
	return has;
end

-- Checks if unit has buff
function mhb_HasBuff(unit, buff)
	local has = false;
	for i = 1, MAX_BUFFS do
		local b = UnitBuff(unit, i);
		if b and b == buff then
			has = true;
		end
	end
	return has;
end

-- Checks if ur currently drinking, if not then start drinking
function mhb_Drink()
	local noWater = true;
	if not mhb_HasBuff("player", BUFF_DRINKING) then
		for i = 1, 16 do 
			if ITEM_DRINK == GetContainerItemInfo(0, i) then
				UseContainerItem(0, i);
				noWater = false;
			end
		end
	else
		noWater = false;
	end
	if noWater then
		mhb_Print("No water found in first backpack!");
	end
end

-- Returns how long cooldown is left of spell
function mbh_GetCooldownLeft(spellId)
	local coolDownLeft = 0;
	local start, duration = GetSpellCooldown(spellId, "BOOKTYPE_SPELL"); 
	if duration ~= 0 then 
		coolDownLeft = duration - (GetTime() - start); 
	end
	return coolDownLeft;
end

-- Prints message in chatbox
function mhb_Print(msg)
	ChatFrame1:AddMessage(msg);
end

-- Prints a message in party or raid.
function mhb_PrintInPartyOrRaid(msg)
	if UnitInRaid("player") then
		SendChatMessage(msg, "RAID");
	else
		SendChatMessage(msg, "PARTY");
	end
end

----------------------------------------------------------------------------------------------------
-- Lua extensions ----------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- Returns the size of a table
function GetTableSize(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end

-- Returns the pair with the highest value in a table, requires <String, Double> table.
function GetHighestValuePairAndRemoveIt(t)
	local finkey = "none";
	local finvalue = 0;
	for key, value in pairs(t) do 
		if value > finvalue then
			finvalue = value;
			finkey = key;
		end
	end
	t[finkey] = nil;
	return finkey, finvalue;
end

-- Keeps the 3 highest value-pairs in a <String, Double> table. Returns how many entries are in the new tables as well as 2 new array-tables ordered.
function KeepXHighestValuePairs(t, x)
	local newkeys = {};
	local newvalues = {};
	local nrOf = x;
	if GetTableSize(t) < x then
		nrOf = GetTableSize(t);
	end
	for i = 1, nrOf do
		local key, value = GetHighestValuePairAndRemoveIt(t);
		table.insert(newkeys, key)
		table.insert(newvalues, value)
	end
	return nrOf, newkeys, newvalues;
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




















