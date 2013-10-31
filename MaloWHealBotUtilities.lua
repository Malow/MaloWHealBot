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
-- Returns true if spellcast-start was successfull. Otherwise false.
-- Todo: Fix check against fail due to movement
-- Runing: try /sit and if ur sitting /stand and cast succeeds? If not solveable change the priest returns to do like if(castSpell) then cast TryCastRenew() return
-- WAIT, JUST AFTER CastSpellByName() do a isCasting() check, should work to see if said spell could be cast. Might not work due to lag tho.. UseIsInGCD for instants.
-- Guess I could check for GCD as well straight after CastSpellByName as a way to see if the spellcast succeeded, might be the easiest if it works.
-- All 3 solutions above is lag-prone, test them to see if any of them works.
function mhb_TargetAndCast(unit, spell)
	if not mhb_CanCastSpell(spell) then
		return false;
	end
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

-- returns the percent of mana of the unit
function mhb_GetManaPercent(unit)
	return UnitMana(unit) / UnitManaMax(unit);
end

-- Check if your drinking or not.
function mhb_IsDrinking()
	return mhb_HasBuff("player", BUFF_DRINKING);
end

-- Checks if ur currently drinking, if not then start drinking
function mhb_Drink()
	local noWater = true;
	if not mhb_IsDrinking() then
		local bag, slot = mhb_GetBagAndSlotForItem(ITEM_DRINK);
		if bag and slot then
			UseContainerItem(bag, slot);
			noWater = false;
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

-- Scens thorugh all bans and slots for item, uses it when finds it and returns bag, slot, if not found returns nil, nil.
function mhb_GetBagAndSlotForItem(item)
	for bag = 0, 4 do 
		for slot = 1, 16 do
			if item == GetContainerItemInfo(bag, slot) then
				return bag, slot;
			end
		end
	end
	return nil, nil;
end

-- Checks if you have enough mana and reagents for spell
function mhb_CanCastSpell(spell)
	if mhb_mhb_HasEnoughManaForSpell(spell) and mhb_HasEnoughReagentsForSpell(spell) then
		return true;
	end
	return false;
end

-- Table containting all SPELL's and their MANACOST's
manaCostTable = {};
-- Uses above table to get the manacost of a spell
function mhb_HasEnoughManaForSpell(spell)
	local cost = manaCostTable[spell];
	if cost then
		if cost > UnitMana("player") then
			return false;
		end	
		return true;
	end
	return false;
end

-- Table containing all SPELL's and their REAGENT's
reagentCastTable = {};
-- Uses above table to get the reagent of a spell
function mhb_HasEnoughReagentsForSpell(spell)
	local reagent = reagentCostTable[spell];
	if reagent then
		if mhb_GetBagAndSlotForItem(reagent) then
			return true;
		end	
		return false;
	end
	return true;
end












