-- SHAMAN
-- ToDo: 
-- Offensive Purge
-- Ahnk
-- Totems: resistance, Windwall, Tremor, poison / disease cleaning, stoneclaw, grounding, healing stream, stoneskin for special aoe occations.
-- Current way checking for windfury totem doesnt work if I start using mana oils on shamans.
-- Natures swiftness / mana tide totem.
-- Dont always recast totems over healing, if healing is really needed do that first.
-- Keep internal totem-timers, and on ready check recast if needed. And maybe recast when no1 needs heals and they only have 10 sec left.
-- Implement chain heal calculator as well as a better way to know if I should cancel chain heal. Also downrank chainheal of effect is low, or re-calc with lower rank of chain heal.
--		anyhow just downrank chain heal if max rank isnt needed.
-- Make other characters report via communication their distances to other damaged units, and calculate chain heal effeciency that way.
-- Some sort of action while moving, NS + heal?

SPELL_ANCESTRAL_SPIRIT = "Ancestral Spirit(Rank 5)";
SPELL_LIGHTNING_SHIELD = "Lightning Shield(Rank 7)";
SPELL_MANA_SPRING_TOTEM = "Mana Spring Totem(Rank 4)";
SPELL_STRENGTH_OF_EARTH_TOTEM = "Strength of Earth Totem(Rank 4)";
SPELL_STONESKIN_TOTEM = "Stoneskin Totem(Rank 6)";
SPELL_WINDFURY_TOTEM = "Windfury Totem(Rank 3)";
SPELL_GRACE_OF_AIR_TOTEM = "Grace of Air Totem(Rank 2)";
SPELL_TRANQUIL_AIR_TOTEM = "Tranquil Air Totem";
SPELL_CHAIN_HEAL = "Chain Heal(Rank 3)";
SPELL_LESSER_HEALING_WAVE = "Lesser Healing Wave(Rank 6)";
SPELL_HEALING_WAVE = "Healing Wave(Rank 9)";
SPELL_HEALING_WAVE_DOWNRANKED = "Healing Wave(Rank 4)";
SPELL_CURE_POISON = "Cure Poison";
SPELL_CURE_DISEASE = "Cure Disease";
SPELL_TOTEM_RANGE_CHECKER = SPELL_CURE_POISON;

HEALVALUE_HEALING_WAVE = 2000;
HEALVALUE_HEALING_WAVE_DOWNRANKED = 500;
HEALVALUE_CHAIN_HEAL_1 = 900;
HEALVALUE_CHAIN_HEAL_2 = 550;
HEALVALUE_CHAIN_HEAL_3 = 400;
HEALVALUE_LESSER_HEALING_WAVE = 1200;

COEF_CHAIN_HEAL = 0.75; -- Percentage of maximum effect that can be estimated to cast it
MINIMUM_DAMAGE_FOR_CHAIN_HEAL = HEALVALUE_CHAIN_HEAL_3 * 0.75; -- Minimum damage a unit has to have taken for chain heal calc to consider them.

BUFF_LIGHTNING_SHIELD = "Interface\\Icons\\Spell_Nature_LightningShield";
BUFF_MANA_SPRING_TOTEM = "Interface\\Icons\\Spell_Nature_ManaRegenTotem";
BUFF_STRENGTH_OF_EARTH_TOTEM = "Interface\\Icons\\Spell_Nature_EarthBindTotem";
BUFF_STONESKIN_TOTEM = "Interface\\Icons\\Spell_Nature_StoneSkinTotem";
BUFF_TRANQUIL_AIR_TOTEM = "Interface\\Icons\\Spell_Nature_Brilliance";
BUFF_GRACE_OF_AIR_TOTEM = "Interface\\Icons\\Spell_Nature_InvisibilityTotem";

CASTTIME_HEALING_WAVE = 2.5;
CASTTIME_HEALING_WAVE_DOWNRANKED = 2.5;
CASTTIME_CHAIN_HEAL = 2.5;
CASTTIME_LESSER_HEALING_WAVE = 1.5;

-- Returns buff and spell of which earth totem best suits to be used.
function mhb_Shaman_GetEarthTotem()
	if mhb_GetNrOfValidPartyMembersByRole("MELEE", SPELL_TOTEM_RANGE_CHECKER) == 0 then
		return "none", "none";
	end
	return BUFF_STRENGTH_OF_EARTH_TOTEM, SPELL_STRENGTH_OF_EARTH_TOTEM;
end

-- Returns buff and spell of which air totem best suits to be used. Windfury if any melee, Grace of air if 2 hunters, otherwise tranquil air.
function mhb_Shaman_GetAirTotem()
	if mhb_GetNrOfValidPartyMembersByRole("MELEE", SPELL_TOTEM_RANGE_CHECKER) > 0 then
		return "none", SPELL_WINDFURY_TOTEM;
	end
	if mhb_GetNrOfValidPartyMembersByClass("HUNTER", SPELL_TOTEM_RANGE_CHECKER) > 1 then
		return BUFF_GRACE_OF_AIR_TOTEM, SPELL_GRACE_OF_AIR_TOTEM;
	end
	return BUFF_TRANQUIL_AIR_TOTEM, SPELL_TRANQUIL_AIR_TOTEM;
end

-- Calculate chainheal effect
function mhb_Shaman_GetChainHealEffect()			--------- TODO implement proper
	local meleeTargets = mhb_GetDamagedTargets(SPELL_CHAIN_HEAL, "MELEE", MINIMUM_DAMAGE_FOR_CHAIN_HEAL);
	local rangedTargets = mhb_GetDamagedTargets(SPELL_CHAIN_HEAL, "RANGED", MINIMUM_DAMAGE_FOR_CHAIN_HEAL);
	
	
	-- FIRST OFF, see if overall enough people in the group is damaged, if so then cast.
	-- without modifier
	-- 2.5 if 5 man
	-- 5 if 10 man
	-- 10 if 20 man
	-- 20 if 40 man
	
	-- with modifier
	-- 3 if 5 man
	-- 5 if 10 man
	-- 8 if 20 man
	-- 15 if 40 man
	
	local numRaidMembers = mhb_GetNumPartyOrRaidMembers();
	local modifier = 0;
	
	if numRaidMembers > 30 then
		modifier = 5;
	elseif numRaidMembers > 15 then
		modifier = 2;
	end
	
	local nrMelee = GetTableSize(meleeTargets);
	local nrRanged = GetTableSize(rangedTargets);
	local totalDamagedTargets = nrMelee + nrRanged;
	if totalDamagedTargets >= (numRaidMembers * 0.5) - modifier then
		local healTargetUnit, missingHealth = mhb_GetMostDamagedTarget(SPELL_HEALING_WAVE);
		return healTargetUnit, 1;
	end
	
	
	-- SECOND OFF, check melee dividually and cast specifically on them.
	if numRaidMembers < 8 then	-- 5man
		return "none", 0;
	elseif numRaidMembers < 15 then -- 10man
		if nrMelee >= 3 then
			-- get them sorted
			local nrOfMeleeLeft, meleeUnits, meleeMissingHealths = KeepXHighestValuePairs(meleeTargets, 1);
			if meleeMissingHealths[0] > HEALVALUE_CHAIN_HEAL_1 then
				return meleeUnits[0], 1;
			end
			-- TODO, else downrank chain heal.
		end	
	elseif numRaidMembers < 30 then -- 20man
		if nrMelee >= 4 then
			-- get them sorted
			local nrOfMeleeLeft, meleeUnits, meleeMissingHealths = KeepXHighestValuePairs(meleeTargets, 1);
			if meleeMissingHealths[0] > HEALVALUE_CHAIN_HEAL_1 then
				return meleeUnits[0], 1;
			end
			-- TODO, else downrank chain heal.
		end	
	else -- 40 man
		if nrMelee >= 6 then
			-- get them sorted
			local nrOfMeleeLeft, meleeUnits, meleeMissingHealths = KeepXHighestValuePairs(meleeTargets, 1);
			if meleeMissingHealths[0] > HEALVALUE_CHAIN_HEAL_1 then
				return meleeUnits[0], 1;
			end
			-- TODO, else downrank chain heal.
		end	
	end
	
	
	-- local nrOfMelee, meleeUnits, meleeMissingHealths = KeepXHighestValuePairs(meleeTargets, 3);
	-- local nrOfRanged, rangedUnits, rangedMissingHealths = KeepXHighestValuePairs(rangedTargets, 3);
	
	-- Actually dont just use the 3 highest, check with all of them, and then have a Chain Heal COEF with something like 1 or higher required, 
	-- Because the chances of only having 3 targets taken damage and chain heal healing all 3 are low, even with split calcs between melee / ranged.
	-- So count with each jump forking to 2 targets maybe when calcing effeciency, so that the effeciency calc will return 900 + 2*550 + 4*400 as max
	-- and then the effeciency becomes 3600 / 1850 = almost 2.0 as max then, so divide that by 2 when returning and you should get values between 0 and 1.
	-- And can then use a normal COEF of like 0.75 or so.
	
	
	-- HAX FIX
	-- local tot = GetTableSize(meleeTargets) + GetTableSize(rangedTargets);
	-- if tot > 4 then 
	-- 	local healTargetUnit, missingHealth = mhb_GetMostDamagedTarget(SPELL_HEALING_WAVE);
	-- 	return healTargetUnit, 5;
	-- end

	return "player", 0;
end

-- Recast totems
function mhb_Shaman_RecastTotems()
	-- Water totem
	if mhb_Rebuff(BUFF_MANA_SPRING_TOTEM, SPELL_MANA_SPRING_TOTEM, REBUFF_SELF) then return true; end
	
	-- Earth totem
	local earthTotemBuff, earthTotemSpell = mhb_Shaman_GetEarthTotem();
	if earthTotemSpell ~= "none" then 
		if mhb_Rebuff(earthTotemBuff, earthTotemSpell, REBUFF_SELF) then return true; end 
	end
	
	-- Air totem
	local airTotemBuff, airTotemSpell = mhb_Shaman_GetAirTotem();
	if airTotemSpell == SPELL_GRACE_OF_AIR_TOTEM or airTotemSpell == SPELL_TRANQUIL_AIR_TOTEM then
		if mhb_Rebuff(airTotemBuff, airTotemSpell, REBUFF_SELF) then return true; end
	elseif airTotemSpell == SPELL_WINDFURY_TOTEM then
		if not GetWeaponEnchantInfo() then
			if mhb_TargetAndCast("player", airTotemSpell) then return true; end
		end
	end
	return false;
end

-- Checks if current casting heal should be cancelled. Returns true if it stopped casting
function mhb_Shaman_CheckStopCasting()
	if mhb_IsOnGCDIn(GCD_TIME_LEFT_BEFORE_CANCEL) then
		 return false; -- Do nothing, not worth interrupting a cast when on GCD, target may take dmg again before GCD is over.
	elseif currentSpell == SPELL_CHAIN_HEAL then
		local missingHealth = mhb_GetMissingHealth(currentTarget);
		if missingHealth < HEALVALUE_CHAIN_HEAL_1 * COEF_CANCEL_HEAL then		-- TODO better way to find out if I should cancel chain heal
			mhb_StopCasting();
			return true;
		end
	else
		if mhb_CancelHealIfGood(currentTarget, currentSpell) then
			return true;
		end
	end
	if not mhb_IsStillValidTarget(currentTarget) then
		mhb_StopCasting();
		return true;
	end
	return false;
end

-- Finds a new target to heal and starts casting.
function mhb_Shaman_StartNewHeal()
	-- cast chain heal if good choice.
	local chainHealTarget, chainHealEffect = mhb_Shaman_GetChainHealEffect();
	if chainHealEffect > COEF_CHAIN_HEAL then
		if mhb_TargetAndCast(chainHealTarget, SPELL_CHAIN_HEAL) then return true; end
	-- Otherwise just heal with heals.
	else
		local healTargetUnit, missingHealth = mhb_GetMostDamagedTarget(SPELL_HEALING_WAVE);
		if mhb_CastHealIfGood(SPELL_HEALING_WAVE, healTargetUnit) then
			return true;
		elseif mhb_CastHealIfGood(SPELL_HEALING_WAVE_DOWNRANKED, healTargetUnit) then
			return true;
		else
			return false;
		end
		-- Here we're currently moving so cast instant, shammys doesnt have isntans. NS + heal? TODO
	end
	return false;
end

-- Heal for shaman
function mhb_Shaman_Heal()
	-- Recalculate the healing coef depending on nr of healers in raid.
	mhb_RecalculateCoefAmountOfHealers(SPELL_HEALING_WAVE);
	
	-- If already casting, cancel cast if target has been healed enough already, or if target is no longer valid, after that start a new heal.
	if mhb_IsCasting() then
		if mhb_Shaman_CheckStopCasting() then
			if mhb_Shaman_StartNewHeal() then return true; end
		end
	-- Else find a new target to start casting a heal on.
	else
		if mhb_Shaman_StartNewHeal() then return true; end
	end
	return false;
end

-- Dispel for shamans
function mhb_Shaman_Dispel()
	-- Cure poison
	local dispelUnit = mhb_GetDispelTarget(SPELL_CURE_POISON, "Poison", "none")
	if dispelUnit ~= "none" then
		if mhb_TargetAndCast(dispelUnit, SPELL_CURE_POISON) then return true; end
	end
	-- Cure Disease
	dispelUnit = mhb_GetDispelTarget(SPELL_CURE_DISEASE, "Disease", "none")
	if dispelUnit ~= "none" then
		if mhb_TargetAndCast(dispelUnit, SPELL_CURE_DISEASE) then return true; end
	end
	
	return false;
end

-- Out of Combat for shamans
function mhb_Shaman_OOC()
	-- If dead accept ress
	if UnitIsDead("player") then AcceptResurrect() return; end
	
	-- check if you're drikning, if so continue drinking untill full or buff wears off.
	if mhb_IsDrinking() then 
		if mhb_GetManaPercent("player") > 0.95 then
			SitOrStand();
		else
			return;
		end
	end
	
	-- Dispell
	if mhb_Shaman_Dispel() then return; end
	
	-- Ress dead people
	if mhb_Resurrect(SPELL_ANCESTRAL_SPIRIT) then return; end
	
	-- Heal up raid
	if mhb_Shaman_Heal() then return; end
	
	if mhb_Shaman_RecastTotems() then return end;
	
	-- Rebuff Lightning shield
	if mhb_Rebuff(BUFF_LIGHTNING_SHIELD, SPELL_LIGHTNING_SHIELD, REBUFF_SELF) then return; end
	
	-- Drink up
	if mhb_DrinkIfNeeded(DRINK_AT_MANAPERCENT) then return; end
end

-- In combat for shamans
function mhb_Shaman_IC()
	if mhb_Shaman_Dispel() then return end;

	if mhb_Shaman_RecastTotems() then return end;
	
	if mhb_Shaman_Heal() then return end;
end

-- Main for shaman
function mhb_Shaman()
	if mhb_IsInCombat("player") then
		mhb_Shaman_IC();
	else
		mhb_Shaman_OOC();
	end
end

-- Loads up shaman
function mhb_Shaman_Load()
	-- Set GCD check spell.
	GCD_CHECK_SPELL = 129; -- Healing Wave(Rank 1)
	
	-- Set manacosts into table
	manaCostTable[SPELL_ANCESTRAL_SPIRIT] = 1368;
	manaCostTable[SPELL_LIGHTNING_SHIELD] = 370;
	manaCostTable[SPELL_MANA_SPRING_TOTEM] = 75;
	manaCostTable[SPELL_STRENGTH_OF_EARTH_TOTEM] = 168;
	manaCostTable[SPELL_STONESKIN_TOTEM] = 157;
	manaCostTable[SPELL_WINDFURY_TOTEM] = 187;
	manaCostTable[SPELL_GRACE_OF_AIR_TOTEM] = 187;
	manaCostTable[SPELL_TRANQUIL_AIR_TOTEM] = 90;
	manaCostTable[SPELL_CHAIN_HEAL] = 384;
	manaCostTable[SPELL_LESSER_HEALING_WAVE] = 361;
	manaCostTable[SPELL_HEALING_WAVE] = 532;
	manaCostTable[SPELL_HEALING_WAVE_DOWNRANKED] = 147;
	manaCostTable[SPELL_CURE_POISON] = 136;
	manaCostTable[SPELL_CURE_DISEASE] = 136;
	
	-- Set heal values into table
	healValueTable[SPELL_HEALING_WAVE] = HEALVALUE_HEALING_WAVE;
	healValueTable[SPELL_HEALING_WAVE_DOWNRANKED] = HEALVALUE_HEALING_WAVE_DOWNRANKED;
	healValueTable[SPELL_LESSER_HEALING_WAVE] = HEALVALUE_LESSER_HEALING_WAVE;
	healValueTable[SPELL_CHAIN_HEAL] = HEALVALUE_CHAIN_HEAL_1 + HEALVALUE_CHAIN_HEAL_2 + HEALVALUE_CHAIN_HEAL_3;
	
	-- Set spellcast time table
	spellCastTimeTable[SPELL_HEALING_WAVE] = CASTTIME_HEALING_WAVE;
	spellCastTimeTable[SPELL_HEALING_WAVE_DOWNRANKED] = CASTTIME_HEALING_WAVE_DOWNRANKED;
	spellCastTimeTable[SPELL_LESSER_HEALING_WAVE] = CASTTIME_LESSER_HEALING_WAVE;
	spellCastTimeTable[SPELL_CHAIN_HEAL] = CASTTIME_CHAIN_HEAL;

	-- Set reagentcosts into table

end








