
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




