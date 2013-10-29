-- PRIEST
-- ToDo: 
-- Don't stop cast until the very 0.2 last sec (isCasting) unless there's another target that needs healing. Requires combat log parsing / event listening to know 
--		how long is left of the cast. NOT NESSESERIALY, ADD TIMERS AND USE GetTime() to check time left etc.
-- Renew: General GetTanks() function, and cast renew on them as soon as they take damage.
-- Dispel Magic offensive.
-- Flash heal
-- Instead of having to set options for fort buff if not improved, have some sort of communication between healers where they say if they have improved or not.
-- Spirit of redemption, if duration left of Spirit of Redemption is less than 2.8 sec only cast renews.
-- OOC, drink if your oom to buff, should happen automatically if spellcast returns fail if oom.

SPELL_GREATER_HEAL = "Greater Heal(Rank 4)";
SPELL_GREATER_HEAL_DOWNRANKED = "Greater Heal(Rank 1)";
SPELL_RENEW = "Renew(Rank 9)";
SPELL_HEAL_DOWNRANKED = "Heal(Rank 1)";
SPELL_POWER_WORD_SHIELD = "Power Word: Shield(Rank 10)";
SPELL_ID_POWER_WORD_SHIELD = 38;
SPELL_PRAYER_OF_HEALING = "Prayer of Healing(Rank 4)";
SPELL_USED_AS_POH_RANGE_CHECK = SPELL_HEAL_DOWNRANKED;
SPELL_POWER_WORD_FORTITUDE = "Power Word: Fortitude(Rank 6)";
SPELL_DIVINE_SPIRIT = "Divine Spirit(Rank 4)";
SPELL_INNER_FIRE = "Inner Fire(Rank 6)";
SPELL_SHADOW_PROTECTION = "Shadow Protection(Rank 3)";
SPELL_RESURRECTION = "Resurrection(Rank 5)";
SPELL_DISPEL_MAGIC = "Dispel Magic(Rank 2)";
SPELL_ABOLISH_DISEASE = "Abolish Disease";

BUFF_POWER_WORD_FORTITUDE = "Interface\\Icons\\Spell_Holy_WordFortitude";
BUFF_DIVINE_SPIRIT = "Interface\\Icons\\Spell_Holy_DivineSpirit";
BUFF_INNER_FIRE = "Interface\\Icons\\Spell_Holy_InnerFire";
BUFF_SHADOW_PROTECTION = "Interface\\Icons\\Spell_Shadow_AntiShadow";
BUFF_RENEW = "Interface\\Icons\\Spell_Holy_Renew";
BUFF_SPIRIT_OF_REDEMPTION = "Interface\\Icons\\Spell_Holy_GreaterHeal";
BUFF_ABOLISH_DISEASE = "Interface\\Icons\\Spell_Nature_NullifyDisease";
DEBUFF_WEAKENED_SOUL = "Interface\\Icons\\Spell_Holy_AshesToAshes";

HEALVALUE_GREATER_HEAL = 2400;	-- How much greater heal maxrank heals
HEALVALUE_GREATER_HEAL_DOWNRANKED = 1400; -- How much greater heal rank1 heals
HEALVALUE_HEAL_DOWNRANKED = 600; -- How much a rank 1 heal heals.
HEALVALUE_RENEW = 1400; -- How much a renew heals.
THRESHOLD_CURRENTHEALTH_POWERWORD_SHIELD = 1000; -- Amount of current health target needs to be at most at to cast power word shield on him.
THRESHOLD_MISSINGHEALTH_POWERWORD_SHIELD = 1000; -- Amount of missing health targets needs to have at least to cast power word shield on him. (to counter max-health-reducing effects)
HEALVALUE_PRAYER_OF_HEALING = 1200; -- How much prayer of healing heals on a single target.

COEF_PRAYER_OF_HEALING = 0.75	-- Multiplier for required amount of its full effect to be cast.
COEF_RENEW = 0.5 -- Multiplier for required amount of its full effect to be cast

skipImpFortCheck = false;

-- Checks if you have improved fortitude specced
function mhb_Priest_HasImprovedFortitude()
	local has = false;
	local name, _, _, _, currRank, maxRank = GetTalentInfo(1,4);
	if name == "Improved Power Word: Fortitude" and currRank == maxRank then
		has = true;
	end	
	return has;
end

-- Checks if you have divine spirit
function mhb_Priest_HasDivineSpirit()
	local has = false;
	local name, _, _, _, currRank, maxRank = GetTalentInfo(1,13);
	if name == "Divine Spirit" and currRank == maxRank then
		has = true;
	end	
	return has;
end

-- Checks cooldown on PWS as well as weakened soul debuff.
function mhb_Priest_CanCastPWS(unit) -- Check CD and for weakened soul
	local canCast = true;
	local duration = mbh_GetCooldownLeft(SPELL_ID_POWER_WORD_SHIELD);
	if duration > 0 then
		canCast = false;
	end
	if mhb_HasDebuff(unit, DEBUFF_WEAKENED_SOUL) then
		canCast = false;
	end
	return canCast;
end

-- Checks through the party and adds missing healths together to calculate how much a POH would heal and then returns true/false depending on set COEF.
function mhb_Priest_GetPOHEffect()
	local totalHeal = mhb_GetMissingHealth("player");
	local num = GetNumPartyMembers();
	for i = 1, num do 
		if mhb_IsValidTarget("party" .. i, SPELL_USED_AS_POH_RANGE_CHECK) then
			local missingHealth = mhb_GetMissingHealth("party" .. i);
			if missingHealth > HEALVALUE_PRAYER_OF_HEALING then
				totalHeal = totalHeal + HEALVALUE_PRAYER_OF_HEALING;
			else
				totalHeal = totalHeal + missingHealth;
			end
		end
	end
	
	local effect = totalHeal / (HEALVALUE_PRAYER_OF_HEALING * 5);
	return effect;
end

-- Function for healing for priests
function mhb_Priest_Heal()
	local isHealing = true;
	-- If already casting, cancel cast if target has been healed enough already, or if target is no longer valid
	if mhb_IsCasting() then
		local missingHealth = mhb_GetMissingHealth(currentTarget);
		if mhb_IsOnGCDIn(GCD_TIME_LEFT_BEFORE_CANCEL) then
			 return; -- Do nothing, not worth interrupting a cast when on GCD, target may take dmg again before GCD is over.
		elseif currentSpell == SPELL_GREATER_HEAL then
			if missingHealth < HEALVALUE_GREATER_HEAL * COEF_CANCEL_HEAL then
				mhb_StopCasting();
			end
		elseif currentSpell == SPELL_GREATER_HEAL_DOWNRANKED then
			if missingHealth < HEALVALUE_GREATER_HEAL_DOWNRANKED * COEF_CANCEL_HEAL then
				mhb_StopCasting();
			end
		elseif currentSpell == SPELL_PRAYER_OF_HEALING then
			if mhb_Priest_GetPOHEffect() < COEF_PRAYER_OF_HEALING * COEF_CANCEL_HEAL then
				mhb_StopCasting();
			end
		elseif currentSpell == SPELL_HEAL_DOWNRANKED then
			if missingHealth == 0 then
				mhb_StopCasting();
			end
		end
		if not mhb_IsStillValidTarget(currentTarget) then
			mhb_StopCasting();
		end
	-- Else find a new target to start casting a heal on.
	else
		-- Power:word shield a target at low health.
		local shieldTargetUnit, healthOfTarget = mhb_GetLowestHealthTarget(SPELL_POWER_WORD_SHIELD);
		if healthOfTarget < THRESHOLD_CURRENTHEALTH_POWERWORD_SHIELD and 
					mhb_GetMissingHealth(shieldTargetUnit) > THRESHOLD_MISSINGHEALTH_POWERWORD_SHIELD and 
					mhb_Priest_CanCastPWS(shieldTargetUnit) then
			mhb_TargetAndCast(shieldTargetUnit, SPELL_POWER_WORD_SHIELD);
		-- Otherwise cast prayer of healing if good choice.
		elseif mhb_Priest_GetPOHEffect() > COEF_PRAYER_OF_HEALING then
			mhb_TargetAndCast("player", SPELL_PRAYER_OF_HEALING);
		-- Otherwise just heal with heals.
		else
			local healTargetUnit, missingHealth = mhb_GetMostDamagedTarget(SPELL_GREATER_HEAL);
			if missingHealth > HEALVALUE_GREATER_HEAL then
				mhb_TargetAndCast(healTargetUnit, SPELL_GREATER_HEAL);
			elseif missingHealth > HEALVALUE_GREATER_HEAL_DOWNRANKED then
				mhb_TargetAndCast(healTargetUnit, SPELL_GREATER_HEAL_DOWNRANKED);
			elseif missingHealth > 0 then
				mhb_TargetAndCast(healTargetUnit, SPELL_HEAL_DOWNRANKED);
			else
				isHealing = false;
			end
			-- By now we should be casting if there's a target that needs heals, if we're not we're probably moving, so cast renew instead.
			if not mhb_IsCasting() and missingHealth > HEALVALUE_RENEW * COEF_RENEW and not mhb_HasBuff(healTargetUnit, BUFF_RENEW) then
				mhb_TargetAndCast(healTargetUnit, SPELL_RENEW);
			end
		end
	end
	return isHealing;
end

-- Dispel for priests
function mhb_Priest_Dispel()
	-- Dispel Magic
	local dispelUnit = mhb_GetDispelTarget(SPELL_DISPEL_MAGIC, "Magic", "none")
	if dispelUnit ~= "none" then
		mhb_TargetAndCast(dispelUnit, SPELL_DISPEL_MAGIC);
		return true;
	end
	-- Abolish Disease
	dispelUnit = mhb_GetDispelTarget(SPELL_ABOLISH_DISEASE, "Disease", BUFF_ABOLISH_DISEASE)
	if dispelUnit ~= "none" then
		mhb_TargetAndCast(dispelUnit, SPELL_ABOLISH_DISEASE);
		return true;
	end
	
	return false;
end

-- Out of Combat for priest
function mhb_Priest_OOC()
	-- If dead accept ress
	if UnitIsDead("player") then AcceptResurrect() return; end
	
	-- Dispell
	if mhb_Priest_Dispel() then return; end
	
	-- Ress dead people
	if mhb_Resurrect(SPELL_RESURRECTION) then return; end
	
	-- Heal up raid
	if mhb_Priest_Heal() then return; end
	
	-- Rebuff Fortitude if you have improved.
	if skipImpFortCheck or mhb_Priest_HasImprovedFortitude() then
		if mhb_Rebuff(BUFF_POWER_WORD_FORTITUDE, SPELL_POWER_WORD_FORTITUDE, REBUFF_RAID) then return; end
	end
	
	--rebuff Divine Spirit if you have it
	if mhb_Priest_HasDivineSpirit() then
		if mhb_Rebuff(BUFF_DIVINE_SPIRIT, SPELL_DIVINE_SPIRIT, REBUFF_RAID_MANAUSERS) then return; end
	end
	
	-- Rebuff Shadow protection
	if mhb_Rebuff(BUFF_SHADOW_PROTECTION, SPELL_SHADOW_PROTECTION, REBUFF_RAID) then return; end
	
	-- Rebuff Inner fire
	if mhb_Rebuff(BUFF_INNER_FIRE, SPELL_INNER_FIRE, REBUFF_SELF) then return; end
	
	-- Drink up
	if mhb_DrinkIfNeeded(DRINK_AT_MANAPERCENT) then return; end
end

-- In combat for priests
function mhb_Priest_IC()
	if mhb_Priest_Dispel() then return; end
	
	if mhb_Priest_Heal() then return; end
end

-- Main for priest
function mhb_Priest(msg)
	if mhb_HasBuff("player", BUFF_SPIRIT_OF_REDEMPTION) then
		mhb_Priest_Heal();
	elseif mhb_IsInCombat("player") then
		mhb_Priest_IC();
	else
		mhb_Priest_OOC();
	end
end

-- Set option for priest
function mhb_Priest_SetOption(msg)
	if msg == "skipImpFortCheck true" then
		skipImpFortCheck = true;
	elseif msg == "skipImpFortCheck false" then
		skipImpFortCheck = false;
	end
end




