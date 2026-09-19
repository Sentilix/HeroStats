-- ============================================================================
-- HeroStatsAPI - Forever Specific Focused UNIT_COMBAT Ingress Pipeline
-- ============================================================================
HeroStatsAPI = {}

function HeroStatsAPI.GetFullName(unit)
    if not unit then return "Unknown" end
    local name, realm = UnitName(unit)
    if not name or name == "" then return "Unknown" end
    if not realm or realm == "" then realm = "Forever" end
    return string.format("%s-%s", name, realm)
end

function HeroStatsAPI.GetCombatLogInfo(...)
    return ...
end

-- LOCAL CACHE DATA STRUCTURES: Dual-aligned state machines for multi-queue syncing
local spellCastCache = {}      -- Damage track: Stores spell names
local combatHealAmountCache = {} -- Healing track: Stores raw heal values

function HeroStatsAPI.RegisterCombatLog(frame)
    local localCombatFrame = CreateFrame("Frame")
    localCombatFrame:RegisterEvent("UNIT_COMBAT")
    localCombatFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    
    localCombatFrame:SetScript("OnEvent", function(self, event, unitToken, arg1, arg2, arg3, arg4)
        if type(unitToken) ~= "string" then return end
        
        -- ============================================================================
        -- CODESLUSE A: SPELLCAST SUCCESS (Fires first for Damage, but LAST for Healing)
        -- ============================================================================
        if event == "UNIT_SPELLCAST_SUCCEEDED" and unitToken == "player" then
            local spellID = tonumber(arg2) or 0
            local spellName = "Heal"
            
            if spellID > 0 and C_Spell and C_Spell.GetSpellInfo then
                local spellInfo = C_Spell.GetSpellInfo(spellID)
                if spellInfo and spellInfo.name then
                    spellName = spellInfo.name
                end
            end
            
            local timestamp = GetTime()
            local sourceGUID = UnitGUID("player") or "UnknownGUID"
            local sourceName = HeroStatsAPI.GetFullName("player")

            -- TRACK 1: HEALING CLOSURE LINK (UNIT_COMBAT arrived first)
            local waitingHeal = combatHealAmountCache["player"]
            if waitingHeal then
                combatHealAmountCache["player"] = nil
                
                if HeroStatsAPI.OnCombatLogEvent then
                    -- 1. FIRST: Force-ignite the profile assembly and mana registry cleanly!
                    HeroStatsAPI.OnCombatLogEvent(
                        timestamp, "SPELL_CAST_SUCCESS", false, 
                        sourceGUID, sourceName, 0, 0, 
                        sourceGUID, sourceName, 0, 0, 
                        spellID, spellName, 1, nil, false
                    )
                    
                    -- 2. SECOND: Deliver the factual numerical healing payload data immediately after!
                    HeroStatsAPI.OnCombatLogEvent(
                        waitingHeal.timestamp, "SPELL_HEAL", false, 
                        sourceGUID, sourceName, 0, 0, 
                        sourceGUID, sourceName, 0, 0, 
                        waitingHeal.amount, spellName, waitingHeal.schoolMask, nil, waitingHeal.isCriticalHit
                    )
                end
            else
                -- TRACK 2: DAMAGE SIGNATURE PREPARATION (UNIT_COMBAT arrives second)
                spellCastCache["player"] = spellName
                
                -- Force-trigger the cast success profile handler for damage pre-emptively!
                if HeroStatsAPI.OnCombatLogEvent then
                    HeroStatsAPI.OnCombatLogEvent(
                        timestamp, "SPELL_CAST_SUCCESS", false, 
                        sourceGUID, sourceName, 0, 0, 
                        sourceGUID, sourceName, 0, 0, 
                        spellID, spellName, 1, nil, false
                    )
                end
            end
            
        -- ============================================================================
        -- CODESLUSE B: UNIT COMBAT (Fires LAST for Damage, but FIRST for Healing)
        -- ============================================================================
        elseif event == "UNIT_COMBAT" then
            if unitToken == "target" or unitToken == "player" then
                local action = arg1
                local flag = arg2
                local amount = tonumber(arg3) or 0
                local schoolMask = arg4 or 1
                
                if action == "WOUND" or action == "HEAL" then
                    local isCriticalHit = (flag == "CRITICAL")
                    local timestamp = GetTime()
                    
                    -- ============================================================================
                    -- FIXED v2.0.0: PRE-EMPTIVE SESSION IGNITION INGRESS
                    -- COMMENT: Runs a tight 100ms delayed timer on your first pull to guarantee UnitName("target") populates in RAM flawlessly before the session names lock down
                    -- ============================================================================
                    if HeroStatsSettings and not InCombatLockdown() then
                        if HeroStats_CreateNewSession then
                            C_Timer.After(0.100, function()
                                HeroStats_CreateNewSession()
                            end)
                        end
                    end
                    
                    -- CASE B1: FACTUAL HEALING (Arrived before the spellcast name)
                    if action == "HEAL" then
                        combatHealAmountCache["player"] = {
                            amount = amount,
                            schoolMask = schoolMask,
                            isCriticalHit = isCriticalHit,
                            timestamp = timestamp
                        }
                        
                    -- CASE B2: FACTUAL DAMAGE (Arrived after the spellcast name was prepared)
                    elseif action == "WOUND" and unitToken == "target" then
                        local pairedSpell = spellCastCache["player"]
                        local subEvent = "SPELL_DAMAGE"
                        
                        if pairedSpell and pairedSpell ~= "" then
                            C_Timer.After(0.100, function() spellCastCache["player"] = nil end)
                        else
                            pairedSpell = "Melee"
                            subEvent = "SWING_DAMAGE"
                        end
                        
                        local sourceGUID = UnitGUID("player") or "UnknownGUID"
                        local sourceName = HeroStatsAPI.GetFullName("player")
                        local destGUID = UnitGUID(unitToken) or sourceGUID
                        local destName = HeroStatsAPI.GetFullName(unitToken)
                        
                        if HeroStatsAPI.OnCombatLogEvent then
                            HeroStatsAPI.OnCombatLogEvent(
                                timestamp, subEvent, false, 
                                sourceGUID, sourceName, 0, 0, 
                                destGUID, destName, 0, 0, 
                                amount, pairedSpell, schoolMask, nil, isCriticalHit
                            )
                        end
                    end
                end
            end
        end
    end)
end
