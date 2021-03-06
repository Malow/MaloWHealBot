-- PRIEST
-- ToDo: 
-- Renew: General GetTanks() function, and cast renew on them as soon as they take damage.
-- Dispel Magic offensive.
-- Flash heal
-- Instead of having to set options for fort buff if not improved, have some sort of communication between healers where they say if they have improved or not.
-- Spirit of redemption, if duration left of Spirit of Redemption is less than 2.8 sec only cast renews.
-- Spirit of redemption, didnt heal properly really.. Is it because IsUnitDead is then true, and it just tries to accept a ress and then returns?
-- When moving, if healTarget already has renew or cant be cast on, get a new target and renew that.

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
HEALVALUE_HEAL_DOWNRANKED = 500; -- How much a rank 1 heal heals.
HEALVALUE_RENEW = 1400; -- How much a renew heals.
HEALVALUE_PRAYER_OF_HEALING = 1200; -- How much prayer of healing heals on a single target.
THRESHOLD_CURRENTHEALTH_POWERWORD_SHIELD = 1000; -- Amount of current health target needs to be at most at to cast power word shield on him.
THRESHOLD_MISSINGHEALTH_POWERWORD_SHIELD = 1000; -- Amount of missing health targets needs to have at least to cast power word shield on him. (to counter max-health-reducing effects)

CASTTIME_GREATER_HEAL = 2.5;
CASTTIME_GREATER_HEAL_DOWNRANKED = 2.5;
CASTTIME_PRAYER_OF_HEALING = 3.0;
CASTTIME_HEAL_DOWNRANKED = 2.5;

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

-- Checks if current casting heal should be cancelled. Returns true if it stopped casting
function mhb_Priest_CheckStopCasting()
	if mhb_IsOnGCDIn(GCD_TIME_LEFT_BEFORE_CANCEL) then
		 return false; -- Do nothing, not worth interrupting a cast when on GCD, target may take dmg again before GCD is over.
	elseif currentSpell == SPELL_PRAYER_OF_HEALING then
		if mhb_Priest_GetPOHEffect() < COEF_PRAYER_OF_HEALING * COEF_CANCEL_HEAL then
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
function mhb_Priest_StartNewHeal()
	-- Power:word shield a target at low health.
	local shieldTargetUnit, healthOfTarget = mhb_GetLowestHealthTarget(SPELL_POWER_WORD_SHIELD);
	if healthOfTarget < THRESHOLD_CURRENTHEALTH_POWERWORD_SHIELD and 
				mhb_GetMissingHealth(shieldTargetUnit) > THRESHOLD_MISSINGHEALTH_POWERWORD_SHIELD and 
				mhb_Priest_CanCastPWS(shieldTargetUnit) then
		if mhb_TargetAndCast(shieldTargetUnit, SPELL_POWER_WORD_SHIELD) then return true; end
	-- Otherwise cast prayer of healing if good choice.
	elseif mhb_Priest_GetPOHEffect() > COEF_PRAYER_OF_HEALING then
		if mhb_TargetAndCast("player", SPELL_PRAYER_OF_HEALING) then return true; end
	-- Otherwise just heal with heals.
	else
		local healTargetUnit, missingHealth = mhb_GetMostDamagedTarget(SPELL_GREATER_HEAL);
		if mhb_CastHealIfGood(SPELL_GREATER_HEAL, healTargetUnit) then
			return true;
		elseif missingHealth > HEALVALUE_RENEW * COEF_RENEW and not mhb_HasBuff(healTargetUnit, BUFF_RENEW) then
			if mhb_TargetAndCast(healTargetUnit, SPELL_RENEW) then return true; end
		elseif mhb_CastHealIfGood(SPELL_GREATER_HEAL_DOWNRANKED, healTargetUnit) then
			return true;
		elseif mhb_CastHealIfGood(SPELL_HEAL_DOWNRANKED, healTargetUnit) then
			return true;
		else
			return false;
		end
		-- By now we should be casting if there's a target that needs heals, if we're not we're probably moving, so cast renew instead.
		if not mhb_IsCasting() and missingHealth > HEALVALUE_RENEW * COEF_RENEW and not mhb_HasBuff(healTargetUnit, BUFF_RENEW) then
			if mhb_TargetAndCast(healTargetUnit, SPELL_RENEW) then return true; end
		end
	end
	return false;
end

-- Function for healing for priests
function mhb_Priest_Heal()
	-- Recalculate the healing coef depending on nr of healers in raid.
	mhb_RecalculateCoefAmountOfHealers(SPELL_GREATER_HEAL);

	-- If already casting, cancel cast if target has been healed enough already, or if target is no longer valid, after that start a new heal.
	if mhb_IsCasting() then
		if mhb_Priest_CheckStopCasting() then
			if mhb_Priest_StartNewHeal() then return true; end
		end
	-- Else find a new target to start casting a heal on.
	else
		if mhb_Priest_StartNewHeal() then return true; end
	end
	return false;
end

-- Dispel for priests
function mhb_Priest_Dispel()
	-- Dispel Magic
	local dispelUnit = mhb_GetDispelTarget(SPELL_DISPEL_MAGIC, "Magic", "none")
	if dispelUnit ~= "none" then
		if mhb_TargetAndCast(dispelUnit, SPELL_DISPEL_MAGIC) then return true; end
	end
	-- Abolish Disease
	dispelUnit = mhb_GetDispelTarget(SPELL_ABOLISH_DISEASE, "Disease", BUFF_ABOLISH_DISEASE)
	if dispelUnit ~= "none" then
		if mhb_TargetAndCast(dispelUnit, SPELL_ABOLISH_DISEASE) then return true; end
	end
	
	return false;
end

-- Out of Combat for priest
function mhb_Priest_OOC()
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

-- Loads up priest
function mhb_Priest_Load()
	-- Set GCD check spell.
	GCD_CHECK_SPELL = 76; -- Renew(Rank 1)
	
	-- Set manacosts into table
	manaCostTable[SPELL_GREATER_HEAL] = 556;
	manaCostTable[SPELL_GREATER_HEAL_DOWNRANKED] = 314;
	manaCostTable[SPELL_RENEW] = 365;
	manaCostTable[SPELL_HEAL_DOWNRANKED] = 131;
	manaCostTable[SPELL_POWER_WORD_SHIELD] = 500;
	manaCostTable[SPELL_PRAYER_OF_HEALING] = 824;
	manaCostTable[SPELL_POWER_WORD_FORTITUDE] = 1695;
	manaCostTable[SPELL_DIVINE_SPIRIT] = 873;
	manaCostTable[SPELL_INNER_FIRE] = 315;
	manaCostTable[SPELL_SHADOW_PROTECTION] = 650;
	manaCostTable[SPELL_RESURRECTION] = 1077;
	manaCostTable[SPELL_DISPEL_MAGIC] = 258;
	manaCostTable[SPELL_ABOLISH_DISEASE] = 215;
	
	-- Set heal values into table
	healValueTable[SPELL_GREATER_HEAL] = HEALVALUE_GREATER_HEAL;
	healValueTable[SPELL_GREATER_HEAL_DOWNRANKED] = HEALVALUE_GREATER_HEAL_DOWNRANKED;
	healValueTable[SPELL_HEAL_DOWNRANKED] = HEALVALUE_HEAL_DOWNRANKED;
	healValueTable[SPELL_RENEW] = HEALVALUE_RENEW;
	healValueTable[SPELL_PRAYER_OF_HEALING] = HEALVALUE_PRAYER_OF_HEALING;
	
	-- Set spellcast time table
	spellCastTimeTable[SPELL_GREATER_HEAL_DOWNRANKED] = CASTTIME_GREATER_HEAL_DOWNRANKED;
	spellCastTimeTable[SPELL_GREATER_HEAL] = CASTTIME_GREATER_HEAL;
	spellCastTimeTable[SPELL_PRAYER_OF_HEALING] = CASTTIME_PRAYER_OF_HEALING;
	spellCastTimeTable[SPELL_HEAL_DOWNRANKED] = CASTTIME_HEAL_DOWNRANKED;

	-- Set reagentcosts into table
	
end

-- Set option for priest
function mhb_Priest_SetOption(msg)
	if msg == "skipImpFortCheck true" then
		skipImpFortCheck = true;
	elseif msg == "skipImpFortCheck false" then
		skipImpFortCheck = false;
	end
	
	-- quick cmds:
	if msg == "fort" then
		skipImpFortCheck = not skipImpFortCheck;
		if skipImpFortCheck then
			mhb_Print("true");	
		else
			mhb_Print("false");	
		end
		
	end
end




