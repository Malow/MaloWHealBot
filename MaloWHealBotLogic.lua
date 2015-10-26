
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
	local manaPercent = mhb_GetManaPercent("player");
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
			elseif b == BUFF_MARK_OF_THE_WILD then
				if duration < TIME_TEN_MINUTES then
					CancelPlayerBuff(i - 1);
					didAction = true;
				end
			elseif b == BUFF_THORNS then
				if duration < TIME_EIGHT_MINUTES then
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
function mhb_GetDamagedTargets(spell, role, damageReq)
	local targets = {};
	members = mhb_GetNumPartyOrRaidMembers();
	for i = 0, members do 
		local unit = mhb_GetUnitFromPartyOrRaidIndex(i);
		local missingHealth = mhb_GetMissingHealth(unit); 
		if mhb_IsValidTarget(unit, spell) then 
			if missingHealth > damageReq then 
				if (role == "MELEE" and mhb_IsMelee(unit)) or (role == "RANGED" and mhb_IsRanged(unit)) then 
					targets[unit] = missingHealth;
				end
			end 
		end 
	end 
	return targets;
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
	return true;
end

-- Table containing all SPELL's and their REAGENT's
reagentCostTable = {};
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

-- Recalculates healing coef depending on how many healers in raid.
function mhb_RecalculateCoefAmountOfHealers(spell)
	local nrOfHealers = mhb_GetNrOfValidRaidMembersByRole("HEALER", spell);
	-- Makes the coef 1 when it's only you, and 2 when there's 20 other healers. Linear scaling between.
	COEF_AMOUNT_OF_HEALERS = 1 + (nrOfHealers - 1) / 20;
end

-- table used for heal values
healValueTable = {};
-- logic for deciding to cast a basic single-target heal depending on missinghealth, heal value, and coefs.
function mhb_CastHealIfGood(spell, target)
	local healValue = healValueTable[spell];
	if not healValue then return false; end
	
	local missingHealth = mhb_GetMissingHealth(target);
	if missingHealth > healValue * COEF_AMOUNT_OF_HEALERS then
		if mhb_TargetAndCast(target, spell) then return true; end
	end
	return false;
end

-- Checks if the current heal would be overheal or not
function mhb_IsCurrentHealGood(target, healValue)
	local missingHealth = mhb_GetMissingHealth(target);
	if missingHealth < healValue * COEF_CANCEL_HEAL * COEF_AMOUNT_OF_HEALERS then
		return false;
	end
	return true;
end

-- table used for spellcast times
spellCastTimeTable = {};
-- logic for deciding if a a basic single-target heal currently being cast should be interrupted on missinghealth, heal value, and coefs.
function mhb_CancelHealIfGood(target, spell)
	local healValue = healValueTable[spell];
	if healValue == nil then return false; end
	
	local spellCastTime = spellCastTimeTable[spell];
	if spellCastTime == nil then spellCastTime = 0; end
	
	local timeLeftOfCast = spellCastTime - mhb_GetTimeSinceCastStart();
	
	-- if we have time left before our heal finishes
	if timeLeftOfCast > STOP_CASTING_TIME then 	
		local newTarget, newMissingHealth = mhb_GetMostDamagedTarget(spell);
		-- if the best healing target is the current one, just continue the cast
		if newTarget == target then 
			return false; 
		else
			-- If another target is better, and it's damaged over 2k, and our current heal is bad, then stop casting it
			if newMissingHealth > 2000 and not mhb_IsCurrentHealGood(target, healValue) then
				mhb_StopCasting();
				return true;
			end
		end
	-- else we have to make a decision if we should stop it or let it hit.
	else	
		if not mhb_IsCurrentHealGood(target, healValue) then
			mhb_StopCasting();
			return true;
		end
	end	
	return false;
end








