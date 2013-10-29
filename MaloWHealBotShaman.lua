-- SHAMAN
-- ToDo: 
-- Offensive Purge
-- Ahnk
-- Totems: resistance, Windwall, Tremor, poison / disease cleaning, stoneclaw, grounding, healing stream, stoneskin for special aoe occations.
-- Current way checking for windfury totem doesnt work if I start using mana oils on shamans.
-- Natures swiftness / mana tide totem.
-- Dont always recast totems over healing, if healing is really needed do that first.
-- Keep internal totem-timers, and on ready check recast if needed.
-- Implement chain heal calculator as well as a better way to know if I should cancel chain heal. Also downrank chainheal of effect is low, or re-calc with lower rank of chain heal.
--		anyhow just downrank chain heal if max rank isnt needed.
-- Make other characters report via communication their distances to other damaged units, and calculate chain heal effeciency that way.
-- OOC, drink if your oom to buff, should happen automatically if spellcast returns fail if oom.

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
MINIMUM_DAMAGE_FOR_CHAIN_HEAL = 200; -- Minimum damage a unit has to have taken for chain heal calc to consider them.

BUFF_LIGHTNING_SHIELD = "Interface\\Icons\\Spell_Nature_LightningShield";
BUFF_MANA_SPRING_TOTEM = "Interface\\Icons\\Spell_Nature_ManaRegenTotem";
BUFF_STRENGTH_OF_EARTH_TOTEM = "Interface\\Icons\\Spell_Nature_EarthBindTotem";
BUFF_STONESKIN_TOTEM = "Interface\\Icons\\Spell_Nature_StoneSkinTotem";
BUFF_TRANQUIL_AIR_TOTEM = "Interface\\Icons\\Spell_Nature_Brilliance";
BUFF_GRACE_OF_AIR_TOTEM = "Interface\\Icons\\Spell_Nature_InvisibilityTotem";

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
	local meleeTargets = mhb_GetDamagedTargets(SPELL_CHAIN_HEAL, true, MINIMUM_DAMAGE_FOR_CHAIN_HEAL);
	local rangedTargets = mhb_GetDamagedTargets(SPELL_CHAIN_HEAL, false, MINIMUM_DAMAGE_FOR_CHAIN_HEAL);
	
	-- local nrOfMelee, meleeUnits, meleeMissingHealths = KeepXHighestValuePairs(meleeTargets, 3);
	-- local nrOfRanged, rangedUnits, rangedMissingHealths = KeepXHighestValuePairs(rangedTargets, 3);
	
	-- Actually dont just use the 3 highest, check with all of them, and then have a Chain Heal COEF with something like 1 or higher required, 
	-- Because the chances of only having 3 targets taken damage and chain heal healing all 3 are low, even with split calcs between melee / ranged.
	-- So count with each jump forking to 2 targets maybe when calcing effeciency, so that the effeciency calc will return 900 + 2*550 + 4*400 as max
	-- and then the effeciency becomes 3600 / 1850 = almost 2.0 as max then, so divide that by 2 when returning and you should get values between 0 and 1.
	-- And can then use a normal COEF of like 0.75 or so.
	
	
	-- HAX FIX
	local tot = GetTableSize(meleeTargets) + GetTableSize(rangedTargets);
	if tot > 4 then 
		local healTargetUnit, missingHealth = mhb_GetMostDamagedTarget(SPELL_HEALING_WAVE);
		return healTargetUnit, 5;
	end

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
			mhb_TargetAndCast("player", airTotemSpell);
			return true;
		end
	end
	return false;
end

-- Heal for shaman
function mhb_Shaman_Heal()
	local isHealing = true;
	-- If already casting, cancel cast if target has been healed enough already, or if target is no longer valid
	if mhb_IsCasting() then
		local missingHealth = mhb_GetMissingHealth(currentTarget);
		if mhb_IsOnGCDIn(GCD_TIME_LEFT_BEFORE_CANCEL) then
			 return; -- Do nothing, not worth interrupting a cast when on GCD, target may take dmg again before GCD is over.
		elseif currentSpell == SPELL_HEALING_WAVE then
			if missingHealth < HEALVALUE_HEALING_WAVE * COEF_CANCEL_HEAL then
				mhb_StopCasting();
			end
		elseif currentSpell == SPELL_HEALING_WAVE_DOWNRANKED then
			if missingHealth < HEALVALUE_HEALING_WAVE_DOWNRANKED * COEF_CANCEL_HEAL then
				mhb_StopCasting();
			end
		elseif currentSpell == SPELL_CHAIN_HEAL then
			if missingHealth < HEALVALUE_CHAIN_HEAL_1 * COEF_CANCEL_HEAL then		-- TODO better way to find out if I should cancel chain heal
				mhb_StopCasting();
			end
		end
		if not mhb_IsStillValidTarget(currentTarget) then
			mhb_StopCasting();
		end
	-- Else find a new target to start casting a heal on.
	else
		-- cast chain heal if good choice.
		local chainHealTarget, chainHealEffect = mhb_Shaman_GetChainHealEffect();
		if chainHealEffect > COEF_CHAIN_HEAL then
			mhb_TargetAndCast(chainHealTarget, SPELL_CHAIN_HEAL);
		-- Otherwise just heal with heals.
		else
			local healTargetUnit, missingHealth = mhb_GetMostDamagedTarget(SPELL_HEALING_WAVE);
			if missingHealth > HEALVALUE_HEALING_WAVE then
				mhb_TargetAndCast(healTargetUnit, SPELL_HEALING_WAVE);
			elseif missingHealth > 0 then
				mhb_TargetAndCast(healTargetUnit, SPELL_HEALING_WAVE_DOWNRANKED);
			else
				isHealing = false;
			end
		end
	end
	return isHealing;
end

-- Dispel for shamans
function mhb_Shaman_Dispel()
	-- Cure poison
	local dispelUnit = mhb_GetDispelTarget(SPELL_CURE_POISON, "Poison", "none")
	if dispelUnit ~= "none" then
		mhb_TargetAndCast(dispelUnit, SPELL_CURE_POISON);
		return true;
	end
	-- Cure Disease
	dispelUnit = mhb_GetDispelTarget(SPELL_CURE_DISEASE, "Disease", "none")
	if dispelUnit ~= "none" then
		mhb_TargetAndCast(dispelUnit, SPELL_CURE_DISEASE);
		return true;
	end
	
	return false;
end

-- Out of Combat for shamans
function mhb_Shaman_OOC()
	-- If dead accept ress
	if UnitIsDead("player") then AcceptResurrect() return; end
	
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