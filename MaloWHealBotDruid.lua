
-- TODO: rebuff motw only if you have improved or if there are no other druids or something.


SPELL_REJUVENATION = "Rejuvenation(Rank 1)";
SPELL_HEALING_TOUCH = "Healing Touch(Rank 1)";

BUFF_REJUVENATION = "Interface\\Icons\\Spell_Nature_Rejuvenation";
BUFF_MARK_OF_THE_WILD = "Interface\\Icons\\Spell_Nature_Regeneration";
SPELL_MARK_OF_THE_WILD = "Mark of the Wild(Rank 1)";
BUFF_THORNS = "Interface\\Icons\\Spell_Nature_Thorns";
SPELL_THORNS = "Thorns(Rank 1)";

HEALVALUE_REJUVENATION = 60;
HEALVALUE_HEALING_TOUCH = 100;

CASTTIME_HEALING_TOUCH = 2.0;


COEF_REJUVENATION = 1.0 -- Multiplier for required amount of its full effect to be cast


-- Checks if current casting heal should be cancelled. Returns true if it stopped casting
function mhb_Druid_CheckStopCasting()
	if mhb_IsOnGCDIn(GCD_TIME_LEFT_BEFORE_CANCEL) then
		 return false; -- Do nothing, not worth interrupting a cast when on GCD, target may take dmg again before GCD is over.
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
function mhb_Druid_StartNewHeal()
		local healTargetUnit, missingHealth = mhb_GetMostDamagedTarget(SPELL_GREATER_HEAL);
    if missingHealth > HEALVALUE_REJUVENATION * COEF_REJUVENATION and not mhb_HasBuff(healTargetUnit, BUFF_REJUVENATION) then
			if mhb_TargetAndCast(healTargetUnit, SPELL_REJUVENATION) then return true; end
		elseif mhb_CastHealIfGood(SPELL_HEALING_TOUCH, healTargetUnit) then
			return true;
		else
			return false;
		end
	return false;
end

-- Function for healing for druids
function mhb_Druid_Heal()
	-- Recalculate the healing coef depending on nr of healers in raid.
	mhb_RecalculateCoefAmountOfHealers(SPELL_HEALING_TOUCH);

	-- If already casting, cancel cast if target has been healed enough already, or if target is no longer valid, after that start a new heal.
	if mhb_IsCasting() then
		if mhb_Druid_CheckStopCasting() then
			if mhb_Druid_StartNewHeal() then return true; end
		end
	-- Else find a new target to start casting a heal on.
	else
		if mhb_Druid_StartNewHeal() then return true; end
	end
	return false;
end

-- Out of Combat for druid
function mhb_Druid_OOC()
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
	--if mhb_Druid_Dispel() then return; end
		
	-- Heal up raid
	if mhb_Druid_Heal() then return; end
	
	-- Rebuff Motw
	if mhb_Rebuff(BUFF_MARK_OF_THE_WILD, SPELL_MARK_OF_THE_WILD, REBUFF_RAID) then return; end
	
	--rebuff thorns
	if mhb_Rebuff(BUFF_THORNS, SPELL_THORNS, REBUFF_RAID_MANAUSERS) then return; end
	
	-- Drink up
	if mhb_DrinkIfNeeded(DRINK_AT_MANAPERCENT) then return; end
end

-- In combat for druid
function mhb_Druid_IC()	
  -- dispell
  
	if mhb_Druid_Heal() then return; end
end

-- Main for druid
function mhb_Druid(msg)
if mhb_IsInCombat("player") then
		mhb_Druid_IC();
	else
		mhb_Druid_OOC();
	end
end

-- Loads up druid
function mhb_Druid_Load()
	-- Set GCD check spell.
	GCD_CHECK_SPELL = 16; -- Rejuvenation(Rank 1)
	
	-- Set manacosts into table
	manaCostTable[SPELL_REJUVENATION] = 40;
	manaCostTable[SPELL_HEALING_TOUCH] = 55;
	
	-- Set heal values into table
	healValueTable[SPELL_REJUVENATION] = HEALVALUE_REJUVENATION;
	healValueTable[SPELL_HEALING_TOUCH] = HEALVALUE_HEALING_TOUCH;
	
	-- Set spellcast time table
	spellCastTimeTable[SPELL_HEALING_TOUCH] = CASTTIME_HEALING_TOUCH;
  

	-- Set reagentcosts into table
	
end