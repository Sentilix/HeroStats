-- ==========================================
-- HeroStats - Core Engine (v0.6.0) - PART 1 & 2 (Global Variable Framework)
-- ==========================================

-- Configuration Constants
HEROSTATS_MAX_SAVED_SESSIONS = 20

HeroStats_CurrentActivePage = 0 
HeroStats_CurrentFightDuration = 0

-- Runtime cache objects
local playerGUID = UnitGUID("player")
local groupRosterCache = {}
local currentFilterMode = "ALL"
local _, playerClassFilename = UnitClass("player")

local HEALER_CLASSES = {
    ["PRIEST"] = true,
    ["PALADIN"] = true,
    ["DRUID"] = true,
    ["SHAMAN"] = true
}

-- Unified mana-user class identifier matrix for power tracking
local MANA_CLASSES = {
    ["PRIEST"] = true,
    ["DRUID"] = true,
    ["PALADIN"] = true,
    ["SHAMAN"] = true,
    ["MAGE"] = true,
    ["WARLOCK"] = true,
    ["HUNTER"] = true
}

local SPELL_CLASS_CACHE = {
    ["Healing Wave"] = "SHAMAN", ["Lesser Healing Wave"] = "SHAMAN", ["Chain Heal"] = "SHAMAN",
    ["Lesser Heal"] = "PRIEST", ["Heal"] = "PRIEST", ["Flash Heal"] = "PRIEST", ["Greater Heal"] = "PRIEST", ["Renew"] = "PRIEST", ["Prayer of Healing"] = "PRIEST", ["Power Word: Shield"] = "PRIEST",
    ["Healing Touch"] = "DRUID", ["Rejuvenation"] = "DRUID", ["Regrowth"] = "DRUID",
    ["Flash of Light"] = "PALADIN", ["Holy Light"] = "PALADIN"
}

local coreFrame = CreateFrame("Frame")
local timerFrame = CreateFrame("Frame")
local fightStartTime = 0

timerFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
timerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
timerFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- RESET AND START: Combat has initiated
        fightStartTime = GetTime()
        HeroStats_CurrentFightDuration = 0
        
        -- Start an independent on-update ticker to count seconds live
        self:SetScript("OnUpdate", function()
            if fightStartTime > 0 then
                HeroStats_CurrentFightDuration = GetTime() - fightStartTime
            end
        end)
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:SetScript("OnUpdate", nil)
        
        if fightStartTime > 0 then
            HeroStats_CurrentFightDuration = GetTime() - fightStartTime
            
            -- STAMP THE DURATION: Lock the precise seconds directly onto the active session data
            if HeroStatsSettings and HeroStatsSettings.sessions then
                local targetIdx = HeroStatsSettings.activeSessionIndex or #HeroStatsSettings.sessions
                local currentSession = HeroStatsSettings.sessions[targetIdx]
                if currentSession then
                    -- Save the fight duration cleanly inside this specific session container
                    currentSession.fightDuration = HeroStats_CurrentFightDuration
                end
            end
            
            -- Accumulate the total database time onto your Overall/Total data tracking layer
            if HeroStatsSettings and HeroStatsSettings.overallData then
                if not HeroStatsSettings.overallData.totalTime then HeroStatsSettings.overallData.totalTime = 0 end
                HeroStatsSettings.overallData.totalTime = HeroStatsSettings.overallData.totalTime + HeroStats_CurrentFightDuration
            end
        end
        fightStartTime = 0
        if coreFrame.RefreshStats then coreFrame.RefreshStats() end
    end
end)

function HeroStats_DumpTable(tbl, indent)
    if not tbl then print("HeroStats Dump: Table is nil") return end
    if type(tbl) ~= "table" then print("HeroStats Dump: Expected table, got " .. type(tbl)) return end
    
    indent = indent or ""
    for k, v in pairs(tbl) do
        local keyStr = tostring(k)
        if type(v) == "table" then
            print(indent .. "[" .. keyStr .. "] => (table):")
            HeroStats_DumpTable(v, indent .. "  ") -- Recursive call for sub-tables
        else
            print(indent .. "[" .. keyStr .. "] => " .. tostring(v))
        end
    end
end

-- Multi-Session Profile Factory: Securely fetches or creates data rows within any sub-table target
function HeroStats_GetOrCreateProfile(dataTable, guid, name, classToken)
    if not dataTable then return nil end
    if not dataTable[guid] then
        local unitToken = "player"
        local finalClass = classToken
        
        if guid ~= playerGUID then
            if IsInRaid() then
                for i = 1, GetNumGroupMembers() do
                    if UnitGUID("raid"..i) == guid then 
                        unitToken = "raid"..i 
                        -- SECURE BACKUP: If token is missing, query the engine live
                        if not finalClass then _, finalClass = UnitClass(unitToken) end
                        break 
                    end
                end
            else
                for i = 1, GetNumGroupMembers() - 1 do
                    if UnitGUID("party"..i) == guid then 
                        unitToken = "party"..i 
                        if not finalClass then _, finalClass = UnitClass(unitToken) end
                        break 
                    end
                end
            end
        else
            -- If it's the player, ensure we grab the correct class filename
            if not finalClass then _, finalClass = UnitClass("player") end
        end

        -- SECURE FALLBACK: Default to "UNKNOWN" instead of "SHAMAN" to prevent data pollution
        if not finalClass or finalClass == "" then
            finalClass = "UNKNOWN"
        end

        dataTable[guid] = {
            name = name,
            class = finalClass,
            effective = 0,
            overheal = 0,
            percent = 0,
            unitId = unitToken,
            manaUsed = 0,
            hpm = 0,
            deaths = 0,
            resurrects = 0,
            dispels = 0,
            buffs = 0,
            damageDone = 0,
            damageTaken = 0,
            manaGained = 0,
            damageDone = 0,
            damageTaken = 0,
            manaGained = 0,
            spellHeals = {},
            spellDamage = {},
            spellTaken = {},
            spellBuffs = {},
            spellMana = {}
        }

    end
    return dataTable[guid]
end

-- Helper interface to grab the active writing combat healer block
function HeroStats_GetActiveSessionHealers()
    if HeroStatsSettings and HeroStatsSettings.sessions and HeroStatsSettings.activeSessionIndex then
        local activeSession = HeroStatsSettings.sessions[HeroStatsSettings.activeSessionIndex]
        if activeSession then
            return activeSession.healers
        end
    end
    return nil
end

local function UpdateGroupRosterCache()
    table.wipe(groupRosterCache)
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")
    if playerName and playerClass then groupRosterCache[playerName] = playerClass end
    
    -- FIXED v1.0.0b2: Fixed-Width Raid Shield scans all 40 indices to prevent unit nil leaks during layout changes
    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i
            local name = UnitName(unit)
            if name then
                local _, classToken = UnitClass(unit)
                if classToken then groupRosterCache[name] = classToken end
            end
        end
    elseif IsInGroup() then
        -- Safe standard party mapping for 5-man dungeon groups
        local numParty = GetNumGroupMembers()
        for i = 1, (numParty - 1) do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name then
                local _, classToken = UnitClass(unit)
                if classToken then groupRosterCache[name] = classToken end
            end
        end
    end
end

-- ==========================================
-- HeroStats - Core Engine (v0.8.0) - PART 2 (Zero-Value Filter Refactor)
-- ==========================================

local sortedHealers = {}

function coreFrame.RefreshStats()
    local pageRecord = HeroStats_GetPageRecord(HeroStats_CurrentActivePage)
    local pageName = pageRecord.name
    local viewTitle = pageRecord.title

    -- Clear previous fight cache cleanly
    table.wipe(sortedHealers)
    
    -- CONSOLIDATED MASTER TRACKERS: Your original trusted variables + new extensions (NO DUPLICATES!)
    local topHealerAmount = 0
    local totalRaidEffective = 0 
    local topHPMValue = 0 
    local topDispelValue = 0
    local topDeathValue = 0
    local topRessValue = 0
    local topBuffsValue = 0
    local topDamageDoneValue = 0
    local topDamageTakenValue = 0
    local topManaGainedValue = 0
    local topDmgCritValue = 0
    local topHealCritValue = 0
    local topOverhealValue = 0

    local activeThreshold = HEROSTATS_MANA_THRESHOLD or 300
    if not IsInGroup() then activeThreshold = 0 end

    local dataSourceTable = nil
    local sessionLabel = "Current"
    local activeViewID = HeroStatsSettings and HeroStatsSettings.selectedViewSessionID or 0

    if activeViewID == -1 then
        dataSourceTable = HeroStatsSettings and HeroStatsSettings.overallData
        sessionLabel = "Total"
    else
        if HeroStatsSettings and HeroStatsSettings.sessions then
            local targetIdx = HeroStatsSettings.activeSessionIndex or 1
            if activeViewID > 0 then
                for idx, session in ipairs(HeroStatsSettings.sessions) do
                    if session.id == activeViewID then
                        targetIdx = idx
                        sessionLabel = "Fight #" .. session.id
                        break
                    end
                end
            end
            local sessionData = HeroStatsSettings.sessions[targetIdx]
            dataSourceTable = sessionData and sessionData.healers
        end
    end

    local baseTitle = pageRecord and pageRecord.title or "HeroStats"
    local viewTitle = ""

    if pageName == "PERSONAL_DMG_RECORDS" or pageName == "PERSONAL_HEAL_RECORDS" then
        viewTitle = baseTitle
    else
        viewTitle = string.format("%s (%s)", baseTitle, sessionLabel)
    end

    local activeFightSeconds = HeroStats_CurrentFightDuration or 0 -- Default fallback
    
    if activeViewID == -1 then
        -- If viewing Overall Total, pull the full accumulated historical time
        activeFightSeconds = HeroStatsSettings and HeroStatsSettings.overallData and HeroStatsSettings.overallData.totalTime or 0
    else
        if HeroStatsSettings and HeroStatsSettings.sessions then
            local targetIdx = HeroStatsSettings.activeSessionIndex or 1
            if activeViewID > 0 then
                for idx, session in ipairs(HeroStatsSettings.sessions) do
                    if session.id == activeViewID then
                        targetIdx = idx
                        break
                    end
                end
            end
            local sessionData = HeroStatsSettings.sessions[targetIdx]
            -- Pull the frozen historical seconds directly from this specific archived fight!
            activeFightSeconds = sessionData and sessionData.fightDuration or activeFightSeconds
        end
    end
    
    -- Safeguard to prevent division by zero or negative integers
    if activeFightSeconds < 1 then activeFightSeconds = 1 end
    
    -- Now export this local calibrated time out so your UI function can see it perfectly
    -- (We simply overwrite the global variable for this specific render tick frame)
    HeroStats_CurrentFightDuration_RenderOverride = activeFightSeconds

    -- TRI-STATE CONFIGURATION: Read state parameters right before parsing the loop
    local filterState = HeroStatsSettings and HeroStatsSettings.activeFilterState or 1
    local _, playerClassFilename = UnitClass("player")

    if dataSourceTable then
        for guid, data in pairs(dataSourceTable) do
            -- FIXED v0.10.0: INGRESS DATA SHIELD - Skip metadata strings/numbers inside the loop
            if data and type(data) == "table" and data.class then

                -- TRI-STATE ENGINE INGRESS GUARD (v0.10.0)
                local includePlayer = true
                
                if filterState == 2 then
                    -- State 2: Strictly filter out non-healing classes layout-wide
                    if not HEALER_CLASSES[data.class] then includePlayer = false end
                elseif filterState == 3 then
                    -- State 3: Strictly filter out classes that do not match the player
                    if data.class ~= playerClassFilename then includePlayer = false end
                end
                
                -- Hard structural restriction for Mana Efficiency
                if pageName == "MANA_EFF" and not HEALER_CLASSES[data.class] then
                    includePlayer = false
                end

                -- Only parse data and populate the UI if the player clears the filter state
                if includePlayer then
                    local total = data.effective + data.overheal
                    data.percent = (total > 0) and ((data.effective / total) * 100) or 0
                    data.manaUsed = data.manaUsed or 0
                    data.deaths = data.deaths or 0
                    data.resurrects = data.resurrects or 0
                    data.dispels = data.dispels or 0
                    data.buffs = data.buffs or 0
                    data.damageDone = data.damageDone or 0
                    data.damageTaken = data.damageTaken or 0
                    data.manaGained = data.manaGained or 0
                    data.dmgCritPct = data.dmgCritPct or 0
                    data.healCritPct = data.healCritPct or 0

                    -- Calculate and track factual HPM yields safely
                    if data.manaUsed > 0 then
                        data.hpm = data.effective / data.manaUsed
                        if data.manaUsed >= activeThreshold then
                            if data.hpm > topHPMValue then topHPMValue = data.hpm end
                        end
                    else
                        data.hpm = 0
                    end

                    -- Accumulate maximum thresholds inside your dataset loops
                    if data.damageDone > topDamageDoneValue then topDamageDoneValue = data.damageDone end
                    if data.damageTaken > topDamageTakenValue then topDamageTakenValue = data.damageTaken end
                    if data.buffs > topBuffsValue then topBuffsValue = data.buffs end
                    if data.manaGained > topManaGainedValue then topManaGainedValue = data.manaGained end
                    if data.dmgCritPct > topDmgCritValue then topDmgCritValue = data.dmgCritPct end
                    if data.healCritPct > topHealCritValue then topHealCritValue = data.healCritPct end
                    if HEALER_CLASSES[data.class] and data.percent > topOverhealValue then topOverhealValue = data.percent end

                    -- Inside your data loop right before the "if shouldInclude then" check:
                    -- FIXED v0.10.0: Live calculations for master critical strike percentage yields
                    local masterDmgHits = data.totalHits or 0
                    local masterDmgCrits = data.critHits or 0
                    data.dmgCritPct = (masterDmgHits > 0) and ((masterDmgCrits / masterDmgHits) * 100) or 0

                    local masterHealHits = data.totalHealHits or 0
                    local masterHealCrits = data.critHealHits or 0
                    data.healCritPct = (masterHealHits > 0) and ((masterHealCrits / masterHealHits) * 100) or 0

                    -- Pure data-driven token filter mapping gates (Expand your existing matrix)
                    local shouldInclude = false
                    if pageName == "HEALING_DONE" then
                        if (data.effective or 0) > 0 or (data.overheal or 0) > 0 then shouldInclude = true end
                    elseif pageName == "EFFICIENCY" then
                        -- FIXED v0.10.0: Restrict Overhealing Efficiency strictly to true healing classes
                        if HEALER_CLASSES[data.class] and ((data.effective or 0) > 0 or (data.overheal or 0) > 0) then 
                            shouldInclude = true 
                        end
                    elseif pageName == "MANA_EFF" then
                        -- FIXED v0.10.0: Restrict HPM calculations strictly to true healing classes
                        if HEALER_CLASSES[data.class] and ((data.effective or 0) > 0 or (data.overheal or 0) > 0) then 
                            shouldInclude = true 
                        end
					elseif pageName == "DMG_CRIT" then
                        -- FIXED v0.10.0: Only include players who have scored at least 1 damage critical hit
                        if masterDmgCrits > 0 then shouldInclude = true end
                    elseif pageName == "HEAL_CRIT" then
                        -- FIXED v0.10.0: Only include players who have scored at least 1 healing critical hit
                        if masterHealCrits > 0 then shouldInclude = true end
                    elseif pageName == "DISPELS" then
                        if (data.dispels or 0) > 0 then shouldInclude = true end
                    elseif pageName == "BUFFS" then
                        if (data.buffs or 0) > 0 then shouldInclude = true end
                    elseif pageName == "DEATHS" then
                        if (data.deaths or 0) > 0 then shouldInclude = true end
                    elseif pageName == "RESURRECTS" then
                        if (data.resurrects or 0) > 0 then shouldInclude = true end
                    elseif pageName == "DAMAGE_DONE" then
                        if (data.damageDone or 0) > 0 then shouldInclude = true end
                    elseif pageName == "DAMAGE_TAKEN" then
                        if (data.damageTaken or 0) > 0 then shouldInclude = true end
                    elseif pageName == "MANA_GAINED" then
                        if MANA_CLASSES[data.class] and (data.manaGained or 0) > 0 then 
                            shouldInclude = true 
                        end
                    elseif pageName == "PERSONAL_DMG_RECORDS" then
                        if HeroStatsSettings and HeroStatsSettings.personalDamageRecords then
                            -- FIXED v1.0.0b1: Expanded validation allows profiles to load safely based on career casts or ticks
                            for _, rec in pairs(HeroStatsSettings.personalDamageRecords) do
                                local hasRecordAmount = (rec.normal and (rec.normal.amount or 0) > 0) or (rec.crit and (rec.crit.amount or 0) > 0)
                                local hasActivityCounters = (rec.casts and rec.casts > 0) or (rec.ticks and rec.ticks > 0)
                                if hasRecordAmount or hasActivityCounters then
                                    shouldInclude = true
                                    break
                                end
                            end
                        end
                    elseif pageName == "PERSONAL_HEAL_RECORDS" then
                        if HeroStatsSettings and HeroStatsSettings.personalHealingRecords then
                            -- FIXED v1.0.0b1: Expanded validation allows profiles to load safely based on career casts or ticks
                            for _, rec in pairs(HeroStatsSettings.personalHealingRecords) do
                                local hasRecordAmount = (rec.normal and (rec.normal.amount or 0) > 0) or (rec.crit and (rec.crit.amount or 0) > 0)
                                local hasActivityCounters = (rec.casts and rec.casts > 0) or (rec.ticks and rec.ticks > 0)                                
                                if hasRecordAmount or hasActivityCounters then
                                    shouldInclude = true
                                    break
                                end
                            end
                        end
                    end

                    if shouldInclude then
                        table.insert(sortedHealers, data)
                        totalRaidEffective = totalRaidEffective + data.effective
                        if data.effective > topHealerAmount then topHealerAmount = data.effective end
                        if data.dispels > topDispelValue then topDispelValue = data.dispels end
                        if data.deaths > topDeathValue then topDeathValue = data.deaths end
                        if data.resurrects > topRessValue then topRessValue = data.resurrects end
                    end
                end
            end
        end
    end

    -- Render blank state if no dataset rows found (v0.8.0 Data-Driven Secured)
    if #sortedHealers == 0 then
        local pageTitle = baseTitle;
        if not (pageName == "PERSONAL_DMG_RECORDS" or pageName == "PERSONAL_HEAL_RECORDS") then
            pageTitle = pageTitle .. " (" .. sessionLabel .. ")"
        end
        if HeroStats_RenderTextMessage then HeroStats_RenderTextMessage(pageTitle, "") end
        return
    end

    -- FIXED v0.10.0: Symmetrical sorting logic for your two brand-new critical strike dashboards
    if pageName == "DAMAGE_DONE" then
        table.sort(sortedHealers, function(a, b) return (a.damageDone == b.damageDone) and (a.name < b.name) or (a.damageDone > b.damageDone) end)
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, topDamageDoneValue, "DAMAGE_DONE", 0, viewTitle) end
        
    elseif pageName == "DMG_CRIT" then
        table.sort(sortedHealers, function(a, b) return (a.dmgCritPct == b.dmgCritPct) and (a.name < b.name) or (a.dmgCritPct > b.dmgCritPct) end)
        local finalMax = (topDmgCritValue > 0) and topDmgCritValue or 100        
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, finalMax, "DMG_CRIT", 0, viewTitle) end

    elseif pageName == "DAMAGE_TAKEN" then
        table.sort(sortedHealers, function(a, b) return (a.damageTaken == b.damageTaken) and (a.name < b.name) or (a.damageTaken > b.damageTaken) end)
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, topDamageTakenValue, "DAMAGE_TAKEN", 0, viewTitle) end

    elseif pageName == "HEALING_DONE" then
        table.sort(sortedHealers, function(a, b) return (a.effective == b.effective) and (a.name < b.name) or (a.effective > b.effective) end)
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, topHealerAmount, "HEALING_DONE", totalRaidEffective, viewTitle) end
        
    elseif pageName == "HEAL_CRIT" then
        table.sort(sortedHealers, function(a, b) return (a.healCritPct == b.healCritPct) and (a.name < b.name) or (a.healCritPct > b.healCritPct) end)
        local finalMax = (topHealCritValue > 0) and topHealCritValue or 100
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, finalMax, "HEAL_CRIT", 0, viewTitle) end

    elseif pageName == "EFFICIENCY" then
        table.sort(sortedHealers, function(a, b) return (a.percent == b.percent) and (a.name < b.name) or (a.percent > b.percent) end)
        local finalMax = (topOverhealValue > 0) and topOverhealValue or 100
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, finalMax, "EFFICIENCY", 0, viewTitle) end
        
    elseif pageName == "MANA_EFF" then
        table.sort(sortedHealers, function(a, b) return (a.hpm == b.hpm) and (a.name < b.name) or (a.hpm > b.hpm) end)
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, topHPMValue, "MANA_EFF", 0, viewTitle) end
        
    elseif pageName == "MANA_GAINED" then
        table.sort(sortedHealers, function(a, b) return (a.manaGained == b.manaGained) and (a.name < b.name) or (a.manaGained > b.manaGained) end)
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, topManaGainedValue, "MANA_GAINED", 0, viewTitle) end

    elseif pageName == "DISPELS" then
        table.sort(sortedHealers, function(a, b) return (a.dispels == b.dispels) and (a.name < b.name) or (a.dispels > b.dispels) end)
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, topDispelValue, "DISPELS", 0, viewTitle) end
        
    elseif pageName == "BUFFS" then
        table.sort(sortedHealers, function(a, b) return (a.buffs == b.buffs) and (a.name < b.name) or (a.buffs > b.buffs) end)
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, topBuffsValue, "BUFFS", 0, viewTitle) end
        
    elseif pageName == "DEATHS" then
        table.sort(sortedHealers, function(a, b) return (a.deaths == b.deaths) and (a.name < b.name) or (a.deaths > b.deaths) end)
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, topDeathValue, "DEATHS", 0, viewTitle) end
        
    elseif pageName == "RESURRECTS" then
        table.sort(sortedHealers, function(a, b) return (a.resurrects == b.resurrects) and (a.name < b.name) or (a.resurrects > b.resurrects) end)
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(sortedHealers, topRessValue, "RESURRECTS", 0, viewTitle) end

    elseif pageName == "PERSONAL_DMG_RECORDS" then
        local recordList = {}
        local maxRecordValue = 1
        
        if HeroStatsSettings and HeroStatsSettings.personalDamageRecords then
            for spellName, rec in pairs(HeroStatsSettings.personalDamageRecords) do
                local totalCasts = rec.casts or 0
                local critCasts = rec.critCasts or 0
                local normalCasts = totalCasts - critCasts
                if normalCasts < 0 then normalCasts = 0 end -- Secure mathematical safeguard
                
                if rec.crit and (rec.crit.amount or 0) > 0 then
                    table.insert(recordList, {
                        name = spellName, amount = rec.crit.amount, isCrit = true,
                        target = rec.crit.target or "Unknown", date = rec.crit.date or "Unknown",
                        casts = critCasts, -- FIXED v1.0.0a3: Passes isolated critical strike count
                        class = playerClassFilename or "UNKNOWN",
                        ticks = rec.ticks or 0,       -- FIXED v1.0.0b1: Carries your lifetime DoT ticks safely into the bar elements!
                        critCasts = rec.critCasts or 0, -- FIXED v1.0.0b1: Carries your lifetime damage crits count safely too!
                    })
                    if rec.crit.amount > maxRecordValue then maxRecordValue = rec.crit.amount end
                end
                -- FIXED v1.0.0b1: Normal Record Ingress Shield carries ticks and critCasts into the dataset safely
                if rec.normal then
                    table.insert(recordList, {
                        name = spellName, 
                        amount = rec.normal.amount or 0, 
                        isCrit = false,
                        target = rec.normal.target or "Unknown", 
                        date = rec.normal.date or "Unknown",
                        casts = normalCasts,
                        ticks = rec.ticks or 0,       -- FIXED v1.0.0b1: Carries your lifetime DoT ticks safely into the bar elements!
                        critCasts = rec.critCasts or 0, -- FIXED v1.0.0b1: Carries your lifetime damage crits count safely too!
                        class = playerClassFilename or "UNKNOWN"
                    })
                    if rec.normal.amount and rec.normal.amount > maxRecordValue then 
                        maxRecordValue = rec.normal.amount 
                    end
                end
            end
            table.sort(recordList, function(a, b) return a.amount > b.amount end)
        end
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(recordList, maxRecordValue, "PERSONAL_DMG_RECORDS", 0, viewTitle) end

    elseif pageName == "PERSONAL_HEAL_RECORDS" then
        local recordList = {}
        local maxRecordValue = 1
        
        if HeroStatsSettings and HeroStatsSettings.personalHealingRecords then
            for spellName, rec in pairs(HeroStatsSettings.personalHealingRecords) do
                local totalCasts = rec.casts or 0
                local critCasts = rec.critCasts or 0
                local normalCasts = totalCasts - critCasts
                if normalCasts < 0 then normalCasts = 0 end
                
                if rec.crit and (rec.crit.amount or 0) > 0 then
                    table.insert(recordList, {
                        name = spellName, amount = rec.crit.amount, isCrit = true,
                        target = rec.crit.target or "Unknown", date = rec.crit.date or "Unknown",
                        casts = critCasts,
                        ticks = rec.ticks or 0,
                        critCasts = rec.critCasts or 0,
                        class = playerClassFilename or "UNKNOWN"
                    })
                    if rec.crit.amount > maxRecordValue then maxRecordValue = rec.crit.amount end
                end
                if rec.normal then
                    table.insert(recordList, {
                        name = spellName, amount = rec.normal.amount, isCrit = false,
                        target = rec.normal.target or "Unknown", date = rec.normal.date or "Unknown",
                        casts = normalCasts,
                        ticks = rec.ticks or 0,
                        critCasts = rec.critCasts or 0,
                        class = playerClassFilename or "UNKNOWN"
                    })
                    if rec.normal.amount > maxRecordValue then maxRecordValue = rec.normal.amount end
                end

            end
            table.sort(recordList, function(a, b) return a.amount > b.amount end)
        end
        if HeroStats_RenderRaidBars then HeroStats_RenderRaidBars(recordList, maxRecordValue, "PERSONAL_HEAL_RECORDS", 0, viewTitle) end
    end
end

function HeroStats_ChangePage(direction)
    local maxPages = #HeroStats_Pages
    HeroStats_CurrentActivePage = HeroStats_CurrentActivePage + direction
    
    if HeroStats_CurrentActivePage > maxPages then HeroStats_CurrentActivePage = 1 end
    if HeroStats_CurrentActivePage < 1 then HeroStats_CurrentActivePage = maxPages end
    
    if HeroStatsSettings then HeroStatsSettings.page = HeroStats_CurrentActivePage end
    HeroStats_RefreshCurrentPage()
end

function HeroStats_ToggleClassFilter()
    if currentFilterMode == "ALL" then currentFilterMode = "CLASS" else currentFilterMode = "ALL" end
    if coreFrame.RefreshStats then coreFrame.RefreshStats() end
    return currentFilterMode
end

-- ==========================================
-- HeroStats - Core Engine (v0.7.0) - PART 3A (Combat Log Parser - Part 1)
-- ==========================================

local isSessionActive = false      
local inTrueCombat = false         
local timeSinceCombatEnd = 0

-- Dynamic Cache tracking for major long-term raid buffs to filter out combat procs securely
local BUFF_WATCH_LIST = {
    ["Power Word: Fortitude"] = true, ["Prayer of Fortitude"] = true,
    ["Shadow Protection"] = true, ["Prayer of Shadow Protection"] = true,
    ["Divine Spirit"] = true, ["Prayer of Spirit"] = true,
    ["Arcane Intellect"] = true, ["Arcane Brilliance"] = true,
    ["Mark of the Wild"] = true, ["Gift of the Wild"] = true,
    ["Thorns"] = true,
    ["Blessing of Might"] = true, ["Greater Blessing of Might"] = true,
    ["Blessing of Wisdom"] = true, ["Greater Blessing of Wisdom"] = true,
    ["Blessing of Kings"] = true, ["Greater Blessing of Kings"] = true,
    ["Blessing of Light"] = true, ["Greater Blessing of Light"] = true,
    ["Blessing of Sanctuary"] = true, ["Greater Blessing of Sanctuary"] = true,
    ["Blessing of Salvation"] = true, ["Greater Blessing of Salvation"] = true
}

local function GetLiveSpellManaCost(spellID)
    if not spellID then return 0 end
    local costTable = GetSpellPowerCost(spellID)
    if costTable then
        for _, costInfo in ipairs(costTable) do
            if costInfo.type == 0 and costInfo.cost then return costInfo.cost end
        end
    end
    return 0
end

-- FIXED v1.0.0b2: Symmetrical Notification Engine with Solo-Group Fallback Protection
function HeroStats_TriggerRecordNotification(spellName, targetName, amountValue, isCrit, isDamage)
    if not HeroStatsSettings then return end
    
    local notifyMode = HeroStatsSettings.recordNotifyMode or 3
    
    -- MODE 1 SHIELD: If set to 1 (Silent Mode), we completely bypass the pipeline instantly
    if notifyMode > 1 then
        local actionStr = isHealing and "healed" or "hit"
        local typeStr = isHealing and "Healing" or "Damage"
        local critStr = isCrit and "Crit" or "Normal"
        local formattedAmt = FormatDotNumber and FormatDotNumber(amountValue) or amountValue
        
        -- FIXED v1.0.0b2: DATA SANITIZER LAYER (Washes inherited Blizzard UI Taint completely clean!)
        local msg = string.format("New %s %s Record! %s %s %s for %s!", 
            critStr, typeStr, spellName, actionStr, targetName or "Unknown", formattedAmt)
        
        -- INTERNET SHIELD: Force Mode 4 to morph into Mode 3 fallback if player is entirely solo
        if notifyMode == 4 and not IsInGroup() then
            notifyMode = 3
        end
        
        -- MODE 2: Traditional Local Chat Output & Audio Pings Only
        if notifyMode == 2 then
            if isCrit then 
                PlaySound(6674) 
                if HeroStats_Print then HeroStats_Print("|cffffd700" .. msg .. "|r") end
            else 
                PlaySound(1204) 
                if HeroStats_Print then HeroStats_Print("|cffb3b3b3" .. msg .. "|r") end
            end
            
        -- MODE 3: Heroic Screen Warning Alert Display Frame (Fading RaidNotice)
        elseif notifyMode == 3 then
            if RaidNotice_AddMessage and RaidWarningFrame then
                local colorTable = isCrit and { r = 1.0, g = 0.82, b = 0.0 } or { r = 0.75, g = 0.75, b = 0.75 }
                local fullScreenMsg = "HeroStats: " .. msg
                RaidNotice_AddMessage(RaidWarningFrame, fullScreenMsg, colorTable)
            end
            
        -- MODE 4: Group Announcement Instance Router (Guaranteed to be in a group here)
        elseif notifyMode == 4 then
            if isCrit then PlaySound(6674) else PlaySound(1204) end            
            -- Prefixes your clean addon brand identifier for group bl�re-chat text
            local groupMsg = "HeroStats: " .. msg
            local channel = IsInRaid() and "RAID" or "PARTY"
            SendChatMessage(groupMsg, channel)
        end
    end
end

-- =========================================================================
-- --- HeroStats - Core Engine (v0.8.0) - OnCombatLogEvent Pipeline ---
-- =========================================================================
local activeHealers = nil;

--  SPELL_CAST_SUCCESS - processed both IN and OUT of combat)
local function OnEvent_SPELL_CAST_SUCCESS(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local _, spellName, _, amount = select(12, CombatLogGetCurrentEventInfo())
    if not amount then return; end;

    local cleanSourceName = sourceName and string.match(sourceName, "([^-]+)") or "Unknown"
    local healerClass = groupRosterCache[cleanSourceName]

    if sourceGUID == playerGUID and not healerClass then _, healerClass = UnitClass("player") end
    healerClass = healerClass or "UNKNOWN"

    local isCasterGroupMember = (sourceGUID == playerGUID) or
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

    if isCasterGroupMember and sourceName and spellName then
        local spellID = select(12, CombatLogGetCurrentEventInfo())
        local fullSpellName = spellName
            
        if spellID and C_Spell and C_Spell.GetSpellSubtext then
            local rankText = C_Spell.GetSpellSubtext(spellID)
            if rankText and rankText ~= "" then
                fullSpellName = string.format("%s (%s)", spellName, rankText)
            end
        end

        if spellID and C_Spell and C_Spell.GetSpellPowerCost then
            local costTable = C_Spell.GetSpellPowerCost(spellID)
            local costInfo = costTable and costTable[1]
            local actualCost = costInfo and costInfo.cost or 0
            local isHealingSpell = SPELL_CLASS_CACHE[spellName] or (spellName == "Power Word: Shield")

            if actualCost > 0 and isHealingSpell then
                local healer = HeroStats_GetOrCreateProfile(activeHealers, sourceGUID, cleanSourceName, healerClass)
                
                -- FIXED: Now safely locked inside the healing-filter wall!
                healer.manaUsed = (healer.manaUsed or 0) + actualCost

                if not healer.spellMana then healer.spellMana = {} end
                if not healer.spellMana[fullSpellName] then
                    healer.spellMana[fullSpellName] = { manaUsed = 0, effective = 0 }
                end
                healer.spellMana[fullSpellName].manaUsed = healer.spellMana[fullSpellName].manaUsed + actualCost

                -- FIXED v1.0.0b1: MUSEUM CAREER CASTS INCREMENT ENGINE (Captures the physical cast instantly!)
                if HeroStatsSettings and HeroStatsSettings.personalHealingRecords then
                    -- FIXED v1.0.0b1: Strip ranks from the manual cast string BEFORE creating the database entry!
                    local cleanRecordSpellName = string.gsub(fullSpellName, "%s*%(Rank%s+%d+%)", "")
                    cleanRecordSpellName = string.trim and string.trim(cleanRecordSpellName) or cleanRecordSpellName:match("^%s*(.-)%s*$")

                    local museumTable = HeroStatsSettings.personalHealingRecords
                    
                    if not museumTable[cleanRecordSpellName] then
                        museumTable[cleanRecordSpellName] = {
                            name = cleanRecordSpellName,
                            casts = 0,
                            critCasts = 0,
                            ticks = 0,
                            normal = { amount = 0, target = "None", date = "None" },
                            crit = { amount = 0, target = "None", date = "None" }
                        }
                    end
                    
                    museumTable[cleanRecordSpellName].casts = (museumTable[cleanRecordSpellName].casts or 0) + 1
                end
            end
        end

        -- FIXED v1.0.0b1: INDEPENDENT OFFENSIVE CAREER CASTS SHIELD FOR LIFE-MUSEUM
        local isKnownHealOrBuff = SPELL_CLASS_CACHE[spellName] or BUFF_WATCH_LIST[spellName] or (spellName == "Power Word: Shield")
        
        -- EXCLUSIVE DAMAGE INTERCEPTOR: Opens ONLY for true offensive player casts
        if sourceGUID == playerGUID and not isHealingSpell and not isKnownHealOrBuff and HeroStatsSettings then
            -- Clean and strip ranks seamlessly from the manual damage cast string before writing to DB
            local cleanRecordSpellName = string.gsub(fullSpellName, "%s*%(Rank%s+%d+%)", "")
            cleanRecordSpellName = string.trim and string.trim(cleanRecordSpellName) or cleanRecordSpellName:match("^%s*(.-)%s*$")

            local dmgMuseum = HeroStatsSettings.personalDamageRecords
            if not dmgMuseum then HeroStatsSettings.personalDamageRecords = {} dmgMuseum = HeroStatsSettings.personalDamageRecords end
            
            if not dmgMuseum[cleanRecordSpellName] then
                dmgMuseum[cleanRecordSpellName] = {
                    name = cleanRecordSpellName,
                    casts = 0,
                    critCasts = 0,
                    ticks = 0,
                    normal = { amount = 0, target = "None", date = "None" },
                    crit = { amount = 0, target = "None", date = "None" }
                }
            end
            
            -- Increments your offensive career casts counter instantly under total isolation!
            dmgMuseum[cleanRecordSpellName].casts = (dmgMuseum[cleanRecordSpellName].casts or 0) + 1
        end

        -- Run buff watchlist check
        if BUFF_WATCH_LIST[spellName] then
            local healer = HeroStats_GetOrCreateProfile(activeHealers, sourceGUID, cleanSourceName, healerClass)
            healer.buffs = (healer.buffs or 0) + 1
            if not healer.spellBuffs then healer.spellBuffs = {} end
            healer.spellBuffs[spellName] = (healer.spellBuffs[spellName] or 0) + 1

            if HeroStatsSettings and HeroStatsSettings.overallData then
                local overallHealer = HeroStats_GetOrCreateProfile(HeroStatsSettings.overallData, sourceGUID, cleanSourceName, healerClass)
                overallHealer.buffs = (overallHealer.buffs or 0) + 1
                if not overallHealer.spellBuffs then overallHealer.spellBuffs = {} end
                overallHealer.spellBuffs[spellName] = (overallHealer.spellBuffs[spellName] or 0) + 1
            end
        end

        coreFrame.RefreshStats()
    end
end;

-- STANDARD DAMAGE DONE & DAMAGE TAKEN MOTORS (v0.10.0 - Perfect DoT Suffix Placement)
local function OnEvent_DAMAGE(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local amount = 0
    local spellName = "Melee"
    local spellID = nil
    local spellModifier = nil

    -- Explicit single-line selections prevents multi-assignment variables from bleeding into each other
    if eventType == "SWING_DAMAGE" then
        amount = select(12, CombatLogGetCurrentEventInfo()) or 0
        spellName = "Melee"
    else
        -- For all SPELL and PERIODIC (DoT) hits:
        spellID, spellName, _, amount = select(12, CombatLogGetCurrentEventInfo())

        spellName = spellName or "Unknown Spell"
        amount = amount or 0
        
        -- Intercept DoT variants cleanly before processing databases
        if eventType == "SPELL_PERIODIC_DAMAGE" then
            spellModifier = " (DoT)"
        end
    end

    if amount > 0 then
        -- A: DAMAGE DONE DETECTION (Who is dealing damage?)
        local isSourceGroupMember = (sourceGUID == playerGUID) or
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isSourceGroupMember and sourceName and not string.find(sourceGUID, "^Pet-") then
            local cleanSourceName = string.match(sourceName, "([^-]+)")
            local sourceClass = groupRosterCache[cleanSourceName] or "UNKNOWN"
                
            local fullSpellName = spellName or "Unknown"
                
            if eventType == "SWING_DAMAGE" then 
                fullSpellName = "Melee" 
            elseif spellID and spellName and C_Spell and C_Spell.GetSpellSubtext then
                local rankText = C_Spell.GetSpellSubtext(spellID)
                if rankText and rankText ~= "" then
                    fullSpellName = string.format("%s (%s)", spellName, rankText)
                end
            end

            -- FIXED v0.10.0: Perfect visual alignment for your Top 10 lists!
            -- Example output: "Fireball (Rank 11) (DoT)"
            if fullSpellName and spellModifier then 
                fullSpellName = fullSpellName .. spellModifier 
            end
                
            -- Inside your A: DAMAGE DONE DETECTION block, right after profile.damageDone accumulation:
            local profile = HeroStats_GetOrCreateProfile(activeHealers, sourceGUID, cleanSourceName, sourceClass)
            profile.damageDone = profile.damageDone + amount
                
            -- FIXED v0.10.0: Extract the unique critical strike flags based on hit types
            local isCrit = false
            if eventType == "SWING_DAMAGE" then
                isCrit = select(18, CombatLogGetCurrentEventInfo())
            else
                isCrit = select(21, CombatLogGetCurrentEventInfo())
            end

            -- FIXED v1.0.0b1: PERSONAL DAMAGE RECORD ENGINE (Advanced Rank-Stripper & DoT Isolation Symmetri)
            if sourceGUID == playerGUID and fullSpellName then
                -- FIXED v1.0.0b1: Advanced Rank-Stripper eliminates (Rank X) string patterns while preserving (DoT) tokens perfectly
                local cleanRecordSpellName = string.gsub(fullSpellName, "%s*%(Rank%s+%d+%)", "")
                
                -- Enforces a razor-sharp trim to wipe out any stray whitespace artifacts safely
                cleanRecordSpellName = string.trim and string.trim(cleanRecordSpellName) or cleanRecordSpellName:match("^%s*(.-)%s*$")

                if not HeroStatsSettings.personalDamageRecords then HeroStatsSettings.personalDamageRecords = {} end
                if not HeroStatsSettings.personalDamageRecords[cleanRecordSpellName] then
                    HeroStatsSettings.personalDamageRecords[cleanRecordSpellName] = {
                        name = cleanRecordSpellName, -- Safely embeds the un-ranked master name string (with or without DoT)
                        casts = 0,
                        critCasts = 0, 
                        ticks = 0, -- Dedicated field isolates and tracks lifetime periodic ticks flawlessly
                        normal = { amount = 0, target = "None", date = "None" },
                        crit = { amount = 0, target = "None", date = "None" }
                    }
                end

                local rec = HeroStatsSettings.personalDamageRecords[cleanRecordSpellName]
                
                -- FIXED v1.0.0b1: Ticks counter is incremented EXCLUSIVELY under periodic events from this engine
                local isPeriodicTick = (eventType == "SPELL_PERIODIC_DAMAGE")
                if isPeriodicTick then
                    rec.ticks = (rec.ticks or 0) + 1
                end
            
                local isNewRecord = false
                local isCritRecord = false
                local currentAmount = amount or 0

                if isCrit then
                    rec.critCasts = (rec.critCasts or 0) + 1 -- Increment your single extra crit field!
                
                    if currentAmount > (rec.crit.amount or 0) then
                        rec.crit.amount = currentAmount
                        rec.crit.target = destName or "Unknown"
                        rec.crit.date = date("%d/%m/%Y")
                        isNewRecord = true
                        isCritRecord = true
                    end
                else
                    if currentAmount > (rec.normal.amount or 0) then
                        rec.normal.amount = currentAmount
                        rec.normal.target = destName or "Unknown"
                        rec.normal.date = date("%d/%m/%Y")
                        isNewRecord = true
                    end
                end

                if isNewRecord then
                    HeroStats_TriggerRecordNotification(cleanRecordSpellName, destName, currentAmount, isCritRecord, false) 
                end
            end

            -- Accumulate master totals for your new Damage Crits tab layout
            profile.totalHits = (profile.totalHits or 0) + 1
            if isCrit then
                profile.critHits = (profile.critHits or 0) + 1
                profile.critDamage = (profile.critDamage or 0) + amount
            end

            if fullSpellName then
                if not profile.spellDamage then profile.spellDamage = {} end
                profile.spellDamage[fullSpellName] = (profile.spellDamage[fullSpellName] or 0) + amount
                
                if not profile.spellCrits then profile.spellCrits = {} end
                if not profile.spellCrits[fullSpellName] then
                    profile.spellCrits[fullSpellName] = { hits = 0, crits = 0, dmg = 0 }
                end
                profile.spellCrits[fullSpellName].hits = (profile.spellCrits[fullSpellName].hits or 0) + 1
                if isCrit then
                    profile.spellCrits[fullSpellName].crits = (profile.spellCrits[fullSpellName].crits or 0) + 1
                    profile.spellCrits[fullSpellName].dmg = (profile.spellCrits[fullSpellName].dmg or 0) + amount
                end
            end
                
            -- Synchronize flawlessly onto the master Overall database layers
            if HeroStatsSettings and HeroStatsSettings.overallData then
                local overallProfile = HeroStats_GetOrCreateProfile(HeroStatsSettings.overallData, sourceGUID, cleanSourceName, sourceClass)
                overallProfile.damageDone = overallProfile.damageDone + amount
                
                overallProfile.totalHits = (overallProfile.totalHits or 0) + 1
                if isCrit then
                    overallProfile.critHits = (overallProfile.critHits or 0) + 1
                    overallProfile.critDamage = (overallProfile.critDamage or 0) + amount
                end
                    
                if fullSpellName then
                    if not overallProfile.spellDamage then overallProfile.spellDamage = {} end
                    overallProfile.spellDamage[fullSpellName] = (overallProfile.spellDamage[fullSpellName] or 0) + amount
                    
                    if not overallProfile.spellCrits then overallProfile.spellCrits = {} end
                    if not overallProfile.spellCrits[fullSpellName] then
                        overallProfile.spellCrits[fullSpellName] = { hits = 0, crits = 0, dmg = 0  }
                    end
                    overallProfile.spellCrits[fullSpellName].hits = overallProfile.spellCrits[fullSpellName].hits + 1
                    if isCrit then
                        overallProfile.spellCrits[fullSpellName].crits = overallProfile.spellCrits[fullSpellName].crits + 1
                        overallProfile.spellCrits[fullSpellName].dmg = overallProfile.spellCrits[fullSpellName].dmg + amount
                    end
                end
            end
            coreFrame.RefreshStats()
        end

        -- DAMAGE TAKEN DETECTION (Who is taking damage?)
        local isDestGroupMember = (destGUID == playerGUID) or
                                    (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                    (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                    (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isDestGroupMember and destName and not string.find(destGUID, "^Pet-") then
            local cleanDestName = string.match(destName, "([^-]+)")
            local destClass = groupRosterCache[cleanDestName] or "UNKNOWN"
                
            -- FIXED v0.10.0: Append modifier directly to your current spell label 
            -- so monster DoTs are also displayed with flawless formatting!
            local currentSpellLabel = spellName or "Melee"
            if currentSpellLabel ~= "Melee" and spellModifier then
                currentSpellLabel = currentSpellLabel .. spellModifier
            end
                
            local cleanSourceName = sourceName and string.match(sourceName, "([^-]+)") or "Environment"
            local combinedSourceKey = string.format("%s - %s", cleanSourceName, currentSpellLabel)

            -- v0.8.0: Detect Blizzard Damage School Bitmasks to determine text coloring
            local schoolColor = "physical"
            if eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "RANGE_DAMAGE" then
                local schoolBit = select(14, CombatLogGetCurrentEventInfo())
                if schoolBit == 2 then schoolColor = "holy"
                elseif schoolBit == 4 then schoolColor = "fire"
                elseif schoolBit == 8 then schoolColor = "nature"
                elseif schoolBit == 16 then schoolColor = "frost"
                elseif schoolBit == 32 then schoolColor = "shadow"
                elseif schoolBit == 64 then schoolColor = "arcane" end
            end
                
            -- Manual override for Poison spells based on string context matching
            if currentSpellLabel and (string.find(string.lower(currentSpellLabel), "poison") or string.find(string.lower(currentSpellLabel), "toxin")) then
                schoolColor = "poison"
            end

            local profile = HeroStats_GetOrCreateProfile(activeHealers, destGUID, cleanDestName, destClass)
            profile.damageTaken = profile.damageTaken + amount

            -- Secure multidimensional sub-table writing for current session matrix
            if not profile.spellTaken then profile.spellTaken = {} end
            if not profile.spellTaken[combinedSourceKey] then
                profile.spellTaken[combinedSourceKey] = { amt = 0, color = schoolColor }
            end
            profile.spellTaken[combinedSourceKey].amt = profile.spellTaken[combinedSourceKey].amt + amount
                
            if HeroStatsSettings and HeroStatsSettings.overallData then
                local overallProfile = HeroStats_GetOrCreateProfile(HeroStatsSettings.overallData, destGUID, cleanDestName, destClass)
                overallProfile.damageTaken = overallProfile.damageTaken + amount
                    
                if not overallProfile.spellTaken then overallProfile.spellTaken = {} end
                if not overallProfile.spellTaken[combinedSourceKey] then
                    overallProfile.spellTaken[combinedSourceKey] = { amt = 0, color = schoolColor }
                end
                overallProfile.spellTaken[combinedSourceKey].amt = overallProfile.spellTaken[combinedSourceKey].amt + amount
            end
            coreFrame.RefreshStats()
        end
    end;
end;

--  DIRECT HEALS & HOTS (v1.0.0b1 - Upgraded HoT Name-Grafting & History Cast Shields)
local function OnEvent_HEAL(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local spellID, spellName = select(12, CombatLogGetCurrentEventInfo())
    local _, _, _, amount, overheal = select(12, CombatLogGetCurrentEventInfo())
        
    overheal = overheal or 0
    amount = amount or 0
    local effective = amount - overheal
    if effective < 0 then effective = 0 end

    local isGroupMember = (sourceGUID == playerGUID) or
                            (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                            (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                            (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

    if isGroupMember and sourceName then
        local cleanName = string.match(sourceName, "([^-]+)")
        local classFilename = groupRosterCache[cleanName] or SPELL_CLASS_CACHE[spellName]

        if classFilename then
            -- Extract the healing critical strike boolean flag from argument 18
            local isHealCrit = select(18, CombatLogGetCurrentEventInfo())

            local healer = HeroStats_GetOrCreateProfile(activeHealers, sourceGUID, cleanName, classFilename)
            healer.effective = healer.effective + effective
            healer.overheal = healer.overheal + overheal
                
            -- FIXED v1.0.0b2: Crusader Shield auto-blocks fake Rogue/Warrior procs from polluting the Healing Crits engine
            local isTrueHealerClass = (classFilename == "PRIEST") or (classFilename == "DRUID") or (classFilename == "PALADIN") or (classFilename == "SHAMAN")
            
            if isTrueHealerClass then
                -- Accumulate master hits and crits ONLY for verified healing archetypes
                healer.totalHealHits = (healer.totalHealHits or 0) + 1
                if isHealCrit then
                    healer.critHealHits = (healer.critHealHits or 0) + 1
                    healer.critHealAmt = (healer.critHealAmt or 0) + effective
                end
            end
                
            -- Accumulate master hits and crits for your new Healing Crits page
            healer.totalHealHits = (healer.totalHealHits or 0) + 1
            if isHealCrit then
                healer.critHealHits = (healer.critHealHits or 0) + 1
                healer.critHealAmt = (healer.critHealAmt or 0) + effective
            end

            -- 1. FIRST: Execute your existing Dynamic Rank Compiler to build the master token string
            local fullSpellName = spellName
            if spellID and spellName and C_Spell and C_Spell.GetSpellSubtext then
                local rankText = C_Spell.GetSpellSubtext(spellID)
                if rankText and rankText ~= "" then
                    fullSpellName = string.format("%s (%s)", spellName, rankText)
                end
            end

            -- FIXED v1.0.0b1: INTERCEPTOR INGRESS GRAFTING
            -- Appends the HoT marker suffix inside the event stream if it is a periodic tick
            local isPeriodicTick = (eventType == "SPELL_PERIODIC_HEAL")
            if isPeriodicTick then
                fullSpellName = fullSpellName .. " (HoT)"
            end

            -- 2. SECOND: Run your isolated Personal Healing Record engine using your freshly built fullSpellName!
            if sourceGUID == playerGUID and fullSpellName then
                -- FIXED v1.0.0b1: Advanced Rank-Stripper eliminates (Rank X) string patterns while preserving tokens perfectly
                local cleanRecordSpellName = string.gsub(fullSpellName, "%s*%(Rank%s+%d+%)", "")
                
                -- Enforces a razor-sharp trim to wipe out any stray whitespace artifacts safely
                cleanRecordSpellName = string.trim and string.trim(cleanRecordSpellName) or cleanRecordSpellName:match("^%s*(.-)%s*$")

                -- REMOVED: "if isPeriodicTick then cleanRecordSpellName = cleanRecordSpellName .. ' (HoT)' end"
                -- This removal permanently kills the double (HoT) (HoT) artifact!

                if not HeroStatsSettings.personalHealingRecords then HeroStatsSettings.personalHealingRecords = {} end
                if not HeroStatsSettings.personalHealingRecords[cleanRecordSpellName] then
                    HeroStatsSettings.personalHealingRecords[cleanRecordSpellName] = {
                        name = cleanRecordSpellName,
                        casts = 0,
                        critCasts = 0, 
                        ticks = 0,
                        normal = { amount = 0, target = "None", date = "None" },
                        crit = { amount = 0, target = "None", date = "None" }
                    }
                end

                local rec = HeroStatsSettings.personalHealingRecords[cleanRecordSpellName]

                if isPeriodicTick then
                    rec.ticks = (rec.ticks or 0) + 1
                end
            
                local isNewRecord = false
                local isCritRecord = false
                local currentHeal = effective or 0

                if isHealCrit then
                    rec.critCasts = (rec.critCasts or 0) + 1 
                
                    if currentHeal > (rec.crit.amount or 0) then
                        rec.crit.amount = currentHeal
                        rec.crit.target = destName or "Unknown"
                        rec.crit.date = date("%d/%m/%Y")
                        isNewRecord = true
                        isCritRecord = true
                    end
                else
                    if currentHeal > (rec.normal.amount or 0) then
                        rec.normal.amount = currentHeal
                        rec.normal.target = destName or "Unknown"
                        rec.normal.date = date("%d/%m/%Y")
                        isNewRecord = true
                    end
                end

                -- Invokes the unified record notification engine cleanly via single line
                if isNewRecord then
                    HeroStats_TriggerRecordNotification(cleanRecordSpellName, destName, currentHeal, isCritRecord, true)
                end
            end

            -- Update internal session tracking tables for bars and reports
            if fullSpellName then
                if not healer.spellHeals then healer.spellHeals = {} end
                if not healer.spellHeals[fullSpellName] then 
                    healer.spellHeals[fullSpellName] = { effective = 0, overheal = 0, amt = 0 } 
                end
                healer.spellHeals[fullSpellName].effective = healer.spellHeals[fullSpellName].effective + effective
                healer.spellHeals[fullSpellName].overheal = healer.spellHeals[fullSpellName].overheal + overheal
                
                if not healer.spellHealCrits then healer.spellHealCrits = {} end
                if not healer.spellHealCrits[fullSpellName] then
                    healer.spellHealCrits[fullSpellName] = { hits = 0, crits = 0, amt = 0 }
                end
                healer.spellHealCrits[fullSpellName].hits = healer.spellHealCrits[fullSpellName].hits + 1
                if isHealCrit then
                    healer.spellHealCrits[fullSpellName].crits = healer.spellHealCrits[fullSpellName].crits + 1
                    healer.spellHealCrits[fullSpellName].amt = healer.spellHealCrits[fullSpellName].amt + effective
                end
            end

            if HeroStatsSettings and HeroStatsSettings.overallData then
                local overallHealer = HeroStats_GetOrCreateProfile(HeroStatsSettings.overallData, sourceGUID, cleanName, classFilename)
                overallHealer.effective = overallHealer.effective + effective
                overallHealer.overheal = overallHealer.overheal + overheal
                    
                overallHealer.totalHealHits = (overallHealer.totalHealHits or 0) + 1
                if isHealCrit then
                    overallHealer.critHealHits = (overallHealer.critHealHits or 0) + 1
                end

                if fullSpellName then
                    if not overallHealer.spellHeals then overallHealer.spellHeals = {} end
                    if not overallHealer.spellHeals[fullSpellName] then 
                        overallHealer.spellHeals[fullSpellName] = { effective = 0, overheal = 0 } 
                    end
                    overallHealer.spellHeals[fullSpellName].effective = overallHealer.spellHeals[fullSpellName].effective + effective
                    overallHealer.spellHeals[fullSpellName].overheal = overallHealer.spellHeals[fullSpellName].overheal + overheal
                    
                    if not overallHealer.spellHealCrits then overallHealer.spellHealCrits = {} end
                    if not overallHealer.spellHealCrits[fullSpellName] then
                        overallHealer.spellHealCrits[fullSpellName] = { hits = 0, crits = 0 }
                    end
                    overallHealer.spellHealCrits[fullSpellName].hits = overallHealer.spellHealCrits[fullSpellName].hits + 1
                    if isHealCrit then
                        overallHealer.spellHealCrits[fullSpellName].crits = overallHealer.spellHealCrits[fullSpellName].crits + 1
                    end
                end
            end
            coreFrame.RefreshStats()
        end
    end
end

--  DETECT REFLECTED SHIELDS & THORNS (v0.8.0 - Factual Source Routing Locked)
local function OnEvent_SHIELD(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local _, _, _, sourceGUID, sourceName, sourceFlags, _, _, _, _ = CombatLogGetCurrentEventInfo()
    local amount = select(15, CombatLogGetCurrentEventInfo()) or 0

    if amount > 0 then
        local isPlayerSelf = (sourceGUID == playerGUID)
        local isSourceGroupMember = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                    (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if (isPlayerSelf or isSourceGroupMember) and sourceName then
            local cleanSourceName = string.match(sourceName, "([^-]+)")
                
            local sourceClass = groupRosterCache[cleanSourceName]
            if isPlayerSelf and not sourceClass then
                _, sourceClass = UnitClass("player")
            end
                
            sourceClass = sourceClass or "UNKNOWN"

            local spellID, spellName = select(12, CombatLogGetCurrentEventInfo())
            local fullSpellName = spellName or "Damage Shield"
                    
            if spellID and spellName and C_Spell and C_Spell.GetSpellSubtext then
                local rankText = C_Spell.GetSpellSubtext(spellID)
                if rankText and rankText ~= "" then
                    fullSpellName = string.format("%s (%s)", spellName, rankText)
                end
            end
                    
            local profile = HeroStats_GetOrCreateProfile(activeHealers, sourceGUID, cleanSourceName, sourceClass)
            profile.damageDone = profile.damageDone + amount
                    
            if fullSpellName then
                if not profile.spellDamage then profile.spellDamage = {} end
                profile.spellDamage[fullSpellName] = (profile.spellDamage[fullSpellName] or 0) + amount
            end
                    
            if HeroStatsSettings and HeroStatsSettings.overallData then
                local overallProfile = HeroStats_GetOrCreateProfile(HeroStatsSettings.overallData, sourceGUID, cleanSourceName, sourceClass)
                overallProfile.damageDone = overallProfile.damageDone + amount
                        
                if fullSpellName then
                    if not overallProfile.spellDamage then overallProfile.spellDamage = {} end
                    overallProfile.spellDamage[fullSpellName] = (overallProfile.spellDamage[fullSpellName] or 0) + amount
                end
            end
            coreFrame.RefreshStats()
        end
    end
end;

--  SHIELDS & ABSORBS
local function OnEvent_ABSORBED(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local allArgs = { CombatLogGetCurrentEventInfo() }
    local shieldCasterGUID, shieldCasterName, shieldCasterFlags, shieldAbsorbAmount, absorbSpellName
        
    local numArgs = #allArgs
    if numArgs >= 19 then
        absorbSpellName = allArgs[numArgs - 2]
        shieldCasterGUID = allArgs[numArgs - 7]
        shieldCasterName = allArgs[numArgs - 6]
        shieldCasterFlags = allArgs[numArgs - 5]
        shieldAbsorbAmount = allArgs[numArgs]
    end

    if absorbSpellName == "Power Word: Shield" and shieldCasterGUID and shieldAbsorbAmount and shieldCasterGUID ~= "" and shieldCasterName then
        local isGroupMember = (shieldCasterGUID == playerGUID) or
                                (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                (bit.band(shieldCasterFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isGroupMember then
            local cleanName = string.match(shieldCasterName, "([^-]+)")
            local healer = HeroStats_GetOrCreateProfile(activeHealers, shieldCasterGUID, cleanName, "PRIEST")
            healer.effective = healer.effective + shieldAbsorbAmount
                
            -- NEW v0.8.0: Aggregate Shield absorption abilities dynamically in current session
            if not healer.spellHeals then healer.spellHeals = {} end
            if not healer.spellHeals[absorbSpellName] then 
                healer.spellHeals[absorbSpellName] = { effective = 0, overheal = 0 } 
            end
            healer.spellHeals[absorbSpellName].effective = healer.spellHeals[absorbSpellName].effective + shieldAbsorbAmount

            if HeroStatsSettings and HeroStatsSettings.overallData then
                local overallHealer = HeroStats_GetOrCreateProfile(HeroStatsSettings.overallData, shieldCasterGUID, cleanName, "PRIEST")
                overallHealer.effective = overallHealer.effective + shieldAbsorbAmount
                    
                -- Also aggregate into the overall night master totals safely
                if not overallHealer.spellHeals then overallHealer.spellHeals = {} end
                if not overallHealer.spellHeals[absorbSpellName] then 
                    overallHealer.spellHeals[absorbSpellName] = { effective = 0, overheal = 0 } 
                end
                overallHealer.spellHeals[absorbSpellName].effective = overallHealer.spellHeals[absorbSpellName].effective + shieldAbsorbAmount
            end
            coreFrame.RefreshStats()
        end
    end
end;

--  RAID DEATH WATCH ENGINE (Runs out-of-combat! - v0.10.0 Opened for All Classes)
local function OnEvent_UNIT_DIED(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)

    local isTargetGroupMember = (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

    -- Ensure we only track player deaths inside our own raid group, excluding pets and monsters
    if isTargetGroupMember and destName and not string.find(destGUID, "^Pet-") then
        local cleanDestName = string.match(destName, "([^-]+)")
        -- Fetch the true class armor type from your live roster group cache
        local targetClass = groupRosterCache[cleanDestName] or "UNKNOWN"
            
        -- FIXED v1.0.0b2: Hunter Feign Death Validation Shield scans unit auras to intercept fake logs
        local isFakeHunterDeath = false
        if targetClass == "HUNTER" then
            -- In WoW Classic/Era, group members can often be queried directly via their clean character name
            for i = 1, 40 do
                local buffName = UnitBuff(cleanDestName, i)
                if not buffName then break end
                if buffName == "Feign Death" then
                    isFakeHunterDeath = true
                    break
                end
            end
        end

        -- MASTER INGRESS BARRIER: Only registers the event if the unit is genuinely dead
        if not isFakeHunterDeath then
            local sessionHealers = HeroStats_GetActiveSessionHealers()
            if sessionHealers then
                local healer = HeroStats_GetOrCreateProfile(sessionHealers, destGUID, cleanDestName, targetClass)
                healer.deaths = (healer.deaths or 0) + 1
                    
                -- Accumulate cumulatively inside the master Overall database sheet
                if HeroStatsSettings and HeroStatsSettings.overallData then
                    local overallHealer = HeroStats_GetOrCreateProfile(HeroStatsSettings.overallData, destGUID, cleanDestName, targetClass)
                    overallHealer.deaths = (overallHealer.deaths or 0) + 1
                end
                if coreFrame.RefreshStats then coreFrame.RefreshStats() end
            end
        end
    end
end;

--  DISPEL TRACKING ENGINE (Runs out-of-combat!)
local function OnEvent_DISPELL(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local isCasterGroupMember = (sourceGUID == playerGUID) or
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

    if isCasterGroupMember and sourceName then
        local cleanSourceName = string.match(sourceName, "([^-]+)")
        local healerClass = groupRosterCache[cleanSourceName]
        if sourceGUID == playerGUID and not healerClass then _, healerClass = UnitClass("player") end
        healerClass = healerClass or "UNKNOWN"
            
        local sessionHealers = HeroStats_GetActiveSessionHealers()
        if sessionHealers then
            local healer = HeroStats_GetOrCreateProfile(sessionHealers, sourceGUID, cleanSourceName, healerClass)
                
            -- Update master totals
            healer.dispels = (healer.dispels or 0) + 1
                
            -- NEW v0.8.0: Fetch your own dispel ability name safely from the engine
            local _, dispelSpellName = select(12, CombatLogGetCurrentEventInfo())
            if dispelSpellName then
                if not healer.spellDispels then healer.spellDispels = {} end
                healer.spellDispels[dispelSpellName] = (healer.spellDispels[dispelSpellName] or 0) + 1
            end
                    
            if HeroStatsSettings and HeroStatsSettings.overallData then
                local overallHealer = HeroStats_GetOrCreateProfile(HeroStatsSettings.overallData, sourceGUID, cleanSourceName, healerClass)
                overallHealer.dispels = (overallHealer.dispels or 0) + 1
                    
                if dispelSpellName then
                    if not overallHealer.spellDispels then overallHealer.spellDispels = {} end
                    overallHealer.spellDispels[dispelSpellName] = (overallHealer.spellDispels[dispelSpellName] or 0) + 1
                end
            end
            coreFrame.RefreshStats()
        end
    end
end;

--  RESURRECTION TRACKING ENGINE (v0.10.0 - Recipient Tracking Enabled)
local function OnEvent_RESURRECT(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local isCasterGroupMember = (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                (bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

    if isCasterGroupMember and sourceName then
        local cleanSourceName = string.match(sourceName, "([^-]+)")
        local sourceClass = groupRosterCache[cleanSourceName]
        if sourceGUID == playerGUID and not sourceClass then _, sourceClass = UnitClass("player") end
        sourceClass = sourceClass or "UNKNOWN"
            
        local sessionHealers = HeroStats_GetActiveSessionHealers()
        if sessionHealers then
            local healer = HeroStats_GetOrCreateProfile(sessionHealers, sourceGUID, cleanSourceName, sourceClass)
            
            -- Accumulate your master resurrection total count
            healer.resurrects = (healer.resurrects or 0) + 1
                
            local cleanDestName = destName and string.match(destName, "([^-]+)")
            if cleanDestName then
                if not healer.resRecipients then healer.resRecipients = {} end
                
                -- FIXED v0.10.1: Extract recipient class string from live group cache before writing data layers
                local targetClass = groupRosterCache[cleanDestName] or "UNKNOWN"
                if targetClass == "UNKNOWN" then
                    local _, cFilename = UnitClass(cleanDestName)
                    targetClass = cFilename or "UNKNOWN"
                end

                -- Convert your legacy flat counter matrix into an independent multi-dimensional sub-table
                if not healer.resRecipients[cleanDestName] then
                    healer.resRecipients[cleanDestName] = { amount = 0, class = targetClass }
                end
                healer.resRecipients[cleanDestName].amount = healer.resRecipients[cleanDestName].amount + 1
            end
                
            -- Synchronize flawlessly onto the master Overall database layers
            if HeroStatsSettings and HeroStatsSettings.overallData then
                local overallHealer = HeroStats_GetOrCreateProfile(HeroStatsSettings.overallData, sourceGUID, cleanSourceName, sourceClass)
                overallHealer.resurrects = (overallHealer.resurrects or 0) + 1
                
                if cleanDestName then
                    if not overallHealer.resRecipients then overallHealer.resRecipients = {} end
                    
                    -- Re-fetch or recycle target parameters for the global database archive
                    local targetClass = groupRosterCache[cleanDestName] or "UNKNOWN"
                    if targetClass == "UNKNOWN" then
                        local _, cFilename = UnitClass(cleanDestName)
                        targetClass = cFilename or "UNKNOWN"
                    end

                    if not overallHealer.resRecipients[cleanDestName] then
                        overallHealer.resRecipients[cleanDestName] = { amount = 0, class = targetClass }
                    end
                    overallHealer.resRecipients[cleanDestName].amount = overallHealer.resRecipients[cleanDestName].amount + 1
                end
            end
            if coreFrame.RefreshStats then coreFrame.RefreshStats() end
        end
    end
end;



--  DETECT MANA GAINED EFFECTS (v0.8.0 - Potions, Innervate, Mana Tide)
local function OnEvent_MANAGAINS(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local spellID, spellName = select(12, CombatLogGetCurrentEventInfo())
    local amount, powerType = select(15, CombatLogGetCurrentEventInfo()) -- Amount is arg 15, PowerType is arg 16
        
    -- Inside your OnEvent_MANAGAINS sub-function:
    local cleanSourceName = string.match(sourceName, "([^-]+)")
    local sourceClass = groupRosterCache[cleanSourceName]
    if sourceGUID == playerGUID and not sourceClass then _, sourceClass = UnitClass("player") end
    sourceClass = sourceClass or "UNKNOWN"

    if not MANA_CLASSES[sourceClass] then 
        return 
    end

    amount = tonumber(amount) or 0
    powerType = tonumber(powerType) or 0 -- 0 is the universal Blizzard enum token for Mana

    if amount > 0 and powerType == 0 and destName and not string.find(destGUID, "^Pet-") then
        local isDestGroupMember = (destGUID == playerGUID) or
                                  (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0) or 
                                  (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0) or 
                                  (bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) ~= 0)

        if isDestGroupMember then
            local cleanDestName = string.match(destName, "([^-]+)")
            local destClass = groupRosterCache[cleanDestName]
            if destGUID == playerGUID and not destClass then _, destClass = UnitClass("player") end
            destClass = destClass or "UNKNOWN"

            local sessionHealers = HeroStats_GetActiveSessionHealers()
            if sessionHealers then
                local profile = HeroStats_GetOrCreateProfile(sessionHealers, destGUID, cleanDestName, destClass)
                profile.manaGained = (profile.manaGained or 0) + amount
                    
                if spellName then
                    if not profile.spellManaGained then profile.spellManaGained = {} end
                    profile.spellManaGained[spellName] = (profile.spellManaGained[spellName] or 0) + amount
                end

                if HeroStatsSettings and HeroStatsSettings.overallData then
                    local overallProfile = HeroStats_GetOrCreateProfile(HeroStatsSettings.overallData, destGUID, cleanDestName, destClass)
                    overallProfile.manaGained = (overallProfile.manaGained or 0) + amount
                        
                    if spellName then
                        if not overallProfile.spellManaGained then overallProfile.spellManaGained = {} end
                        overallProfile.spellManaGained[spellName] = (overallProfile.spellManaGained[spellName] or 0) + amount
                    end
                end
                coreFrame.RefreshStats()
            end
        end
    end
end;

--  DETECT COMPACT AURA PROCS (v0.8.0 - Tier 3 Epiphany Engine Secured)
local function OnEvent_AURA(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)

    if destGUID == playerGUID then
        local _, buffName = select(12, CombatLogGetCurrentEventInfo())
        
        if buffName == "Epiphany" then
            -- SAFETY GATE: Only log the 500 mana if a valid fight session dataset is actively running!
            local sessionHealers = HeroStats_GetActiveSessionHealers()
            if sessionHealers then
                local _, playerClass = UnitClass("player")
                local healer = HeroStats_GetOrCreateProfile(sessionHealers, playerGUID, "Unknown", playerClass or "UNKNOWN")
                
                healer.manaGained = (healer.manaGained or 0) + 500
                if not healer.spellManaGained then healer.spellManaGained = {} end
                healer.spellManaGained["Epiphany"] = (healer.spellManaGained["Epiphany"] or 0) + 500
                
                if HeroStatsSettings and HeroStatsSettings.overallData then
                    local overallHealer = HeroStats_GetOrCreateProfile(HeroStatsSettings.overallData, playerGUID, "Unknown", playerClass or "UNKNOWN")
                    overallHealer.manaGained = (overallHealer.manaGained or 0) + 500
                    if not overallHealer.spellManaGained then overallHealer.spellManaGained = {} end
                    overallHealer.spellManaGained["Epiphany"] = (overallHealer.spellManaGained["Epiphany"] or 0) + 500
                end
                if coreFrame.RefreshStats then coreFrame.RefreshStats() end
            end
        end
    end
end;

local function OnCombatLogEvent()
    -- Fetch the active writing sub-table for the current active fight session
    activeHealers = HeroStats_GetActiveSessionHealers()
    if not activeHealers then return end

    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    if eventType == "SPELL_CAST_SUCCESS" then
	    OnEvent_SPELL_CAST_SUCCESS(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);

	elseif eventType == "UNIT_DIED" then
        OnEvent_UNIT_DIED(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);

    elseif eventType == "SPELL_DISPEL" then
        OnEvent_DISPELL(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);
	
    elseif eventType == "SPELL_RESURRECT" then
        OnEvent_RESURRECT(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);

    elseif eventType == "SPELL_AURA_APPLIED" then
        OnEvent_AURA(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);
		
	--  The next events only applies in combat, so bail out if not:
	elseif isSessionActive then
        if (eventType == "SWING_DAMAGE" or eventType == "SPELL_DAMAGE" or eventType == "RANGE_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE") then
            OnEvent_DAMAGE(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);

        elseif (eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL") then
            OnEvent_HEAL(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);

        elseif eventType == "DAMAGE_SHIELD" then
            OnEvent_SHIELD(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);
		
        elseif eventType == "SPELL_ABSORBED" then
            OnEvent_ABSORBED(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);		

        elseif eventType == "SPELL_ENERGIZE" then
            OnEvent_MANAGAINS(eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags);
        end; 
    end;
end

-- ==========================================
-- HeroStats - Core Engine (v0.6.0) - PART 3B
-- ==========================================

-- NEW SESSION GENERATOR PIPELINE: Runs securely when pulling threat / entering combat
local function HeroStats_CreateNewSession()
    if not HeroStatsSettings or not HeroStatsSettings.sessions then return end
    
    HeroStatsSettings.activeSessionID = (HeroStatsSettings.activeSessionID or 0) + 1
    
    local zoneName = GetZoneText() or "Unknown Area"
    local encounterName = UnitName("target") or "Trash Mob"
    local sessionName = encounterName .. " (" .. zoneName .. ")"
    
    local newSessionBlock = {
        id = HeroStatsSettings.activeSessionID,
        name = sessionName,
        healers = {}
    }
    
    table.insert(HeroStatsSettings.sessions, newSessionBlock)
    HeroStatsSettings.activeSessionIndex = #HeroStatsSettings.sessions
    
    -- FIFO REMOVAL BARRIER: Delete oldest session if inventory list hits 21 slots
    if #HeroStatsSettings.sessions > HEROSTATS_MAX_SAVED_SESSIONS then
        table.remove(HeroStatsSettings.sessions, 1)
        HeroStatsSettings.activeSessionIndex = #HeroStatsSettings.sessions
    end
end

coreFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
coreFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
coreFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
coreFrame:RegisterEvent("GROUP_ROSTER_UPDATE")   
coreFrame:RegisterEvent("PLAYER_ENTERING_WORLD") 

coreFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inTrueCombat = true
        timeSinceCombatEnd = 0
        -- FIXED v0.8.0: Reset the precise fight duration clock on pull
        HeroStats_CurrentFightDuration = 0
        if not isSessionActive then
            HeroStats_CreateNewSession()
            isSessionActive = true
            coreFrame.RefreshStats()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inTrueCombat = false
        timeSinceCombatEnd = 0
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        UpdateGroupRosterCache()
        
        local currentlyInGroup = IsInGroup() or IsInRaid()
        if currentlyInGroup and not wasInGroupLastCheck then
            if HeroStatsSettings and HeroStatsSettings.groupJoinBehavior then
                local behavior = HeroStatsSettings.groupJoinBehavior
                if behavior == 1 then
                    HeroStats_ExecuteMasterWipeData()
                    if HeroStats_Print then HeroStats_Print("Automatically cleared history due to group join settings.") end
                elseif behavior == 3 then
                    StaticPopup_Show("HEROSTATS_GROUP_JOIN_PROMPT")
                end
            end
        end
        wasInGroupLastCheck = currentlyInGroup
    end
end)

UpdateGroupRosterCache()

-- Inside your existing OnUpdate frame ticker loop, add this check:
local totalElapsed = 0
coreFrame:SetScript("OnUpdate", function(self, elapsed)
    if inTrueCombat then
        totalElapsed = totalElapsed + elapsed
        -- Every time 1 full second passes, tick the master combat clock up by 1
        if totalElapsed >= 1 then
            HeroStats_CurrentFightDuration = (HeroStats_CurrentFightDuration or 0) + 1
            totalElapsed = 0
            
            -- Live update bars while fighting so DPS/HPS changes in real-time
            if coreFrame.RefreshStats then coreFrame.RefreshStats() end
        end
    end
    
    if isSessionActive and not inTrueCombat then
        timeSinceCombatEnd = timeSinceCombatEnd + elapsed
        if timeSinceCombatEnd >= HEROSTATS_OUT_OF_COMBAT_GRACE then
            isSessionActive = false
            -- Combat fully finalized, stats are safely written inside SavedVariables array
        end
    end
end)

-- ==========================================
-- HeroStats - Core Engine (v0.6.0 Multi-Session) - PART 4
-- ==========================================

-- Global initialization interface running across layout load hooks
function HeroStats_SetInitialPage(savedPage)
    HeroStats_CurrentActivePage = savedPage
    
    -- Structure validation: Ensure multi-session databases exist upon login
    if HeroStatsSettings then
        if not HeroStatsSettings.sessions then
            HeroStatsSettings.sessions = {}
        end
        if not HeroStatsSettings.activeSessionID then
            HeroStatsSettings.activeSessionID = 0
        end
        if not HeroStatsSettings.activeSessionIndex then
            HeroStatsSettings.activeSessionIndex = 1
        end
        if not HeroStatsSettings.overallData then
            HeroStatsSettings.overallData = {}
        end
        
        -- Create a baseline starter session block if the history log is completely empty
        if #HeroStatsSettings.sessions == 0 then
            local zoneName = GetZoneText() or "Azeroth"
            HeroStatsSettings.activeSessionID = 1
            HeroStatsSettings.sessions[1] = {
                id = 1,
                name = "Startup Session (" .. zoneName .. ")",
                healers = {}
            }
            HeroStatsSettings.activeSessionIndex = 1
        end
    end
    
    -- Refresh display metrics instantly
    if coreFrame.RefreshStats then coreFrame.RefreshStats() end
end

function HeroStats_RefreshCurrentPage()
    if coreFrame.RefreshStats then coreFrame.RefreshStats() end
end


-- ==========================================
-- HeroStats - Core Engine (v0.7.0) - PART 4A (Reset & Group Popups)
-- ==========================================

-- NEW MASTER WIPE ENGINE: Complete hard-reset of all cached data arrays and night totals
function HeroStats_ExecuteMasterWipeData()
    if not HeroStatsSettings then return end
    
    -- 1. Purge all structural data pipelines permanently
    HeroStatsSettings.sessions = {}
    HeroStatsSettings.overallData = {}
    HeroStatsSettings.activeSessionID = 1
    HeroStatsSettings.activeSessionIndex = 1
    
    -- 2. Build a fresh baseline starter fight block to prevent empty array nil crashes
    local zoneName = GetZoneText() or "Azeroth"
    HeroStatsSettings.sessions[1] = {
        id = 1,
        name = "Startup Session (" .. zoneName .. ")",
        healers = {}
    }
    
    -- 3. Reset the global display viewport back to show the fresh current fight slot
    HeroStats_SelectedViewSessionID = 0
    
    -- 4. Flush the main window canvas completely and redraw the empty state
    if HeroStats_ClearDisplay then HeroStats_ClearDisplay() end
    if coreFrame and coreFrame.RefreshStats then coreFrame.RefreshStats() end
    
    -- 5. Force update the historic session dropdown window cache if it happens to be open
    if HeroStats_UpdateSessionListWindow then HeroStats_UpdateSessionListWindow() end
    
    if HeroStats_Print then
        HeroStats_Print("All Combat log and totals have been successfully wiped.")
    end
end

-- NEW: Official Blizzard Static Popup Specification for automated Group Join promptings
StaticPopupDialogs["HEROSTATS_GROUP_JOIN_PROMPT"] = {
    text = "You have joined a new Group or Raid. Do you want to wipe your previous fight history?",
    button1 = "Yes, Start Fresh",
    button2 = "No, Keep Data",
    OnAccept = function()
        HeroStats_ExecuteMasterWipeData()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- global callback bridge enabling the UI loader ticker to query background states
HeroStats_SetInitialPage(HeroStatsSettings and HeroStatsSettings.page or 0)

-- ==========================================
-- HeroStats - Core Engine (v0.7.0) - PART 3B (Group-Join Listener)
-- ==========================================

-- Runtime guard flag to track your previous grouping state across checks securely
local wasInGroupLastCheck = false

coreFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inTrueCombat = true
        timeSinceCombatEnd = 0
        if not isSessionActive then
            HeroStats_CreateNewSession()
            isSessionActive = true
            coreFrame.RefreshStats()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inTrueCombat = false
        timeSinceCombatEnd = 0
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        UpdateGroupRosterCache()
        
        -- NEW AUTOMATED GROUP JOIN ENGINE
        local currentlyInGroup = IsInGroup() or IsInRaid()
        
        -- Trigger point: Fires ONLY when transitioning from solo player to group member
        if currentlyInGroup and not wasInGroupLastCheck then
            if HeroStatsSettings and HeroStatsSettings.groupJoinBehavior then
                local behavior = HeroStatsSettings.groupJoinBehavior
                
                if behavior == 1 then
                    -- Option 1: Hard wipe instantly without prompting
                    HeroStats_ExecuteMasterWipeData()
                    if HeroStats_Print then HeroStats_Print("Automatically cleared history due to group join settings.") end
                elseif behavior == 2 then
                    -- Option 2: Keep data silently and do absolutely nothing
                elseif behavior == 3 then
                    -- Option 3: Fire Blizzards popup confirmation window framework
                    StaticPopup_Show("HEROSTATS_GROUP_JOIN_PROMPT")
                end
            end
        end
        
        -- Update the state tracking flag for the next event loop check
        wasInGroupLastCheck = currentlyInGroup
    end
end)

UpdateGroupRosterCache()

-- ==========================================
-- HeroStats - Core Engine (v0.7.0 Chat Exporter)
-- ==========================================

function HeroStats_ReportCurrentPageToChat()
    if not sortedHealers or #sortedHealers == 0 then return end
    if not HeroStatsSettings then return end

    local mode = HeroStatsSettings.reportChannelMode or 1
    local channelType = "SAY"
    local channelNum = nil
    local isSoloWhisperLoop = false

    if mode == 1 then
        -- FIXED AUTO ROUTING: Only use official party/raid lines if actively grouped, else fallback to local prints
        if IsInRaid() then 
            channelType = "RAID"
        elseif IsInGroup() then 
            channelType = "PARTY"
        else 
            isSoloWhisperLoop = true 
        end
    elseif mode == 2 then channelType = "SAY"
    elseif mode == 3 then channelType = "YELL"
    elseif mode == 4 then channelType = "GUILD"
    elseif mode == 5 then 
        channelType = "CHANNEL" 
        channelNum = HeroStatsSettings.reportCustomChannelNum or 1
    end

    local maxLines = HeroStatsSettings.reportLinesLimit or 5
    local linesToPost = math.min(maxLines, #sortedHealers)
    if linesToPost <= 0 then return end

    -- FIXED v0.8.0: Data-driven title extraction safely mapped via your 1-based lookupFramework
    local pageRecord = HeroStats_GetPageRecord(HeroStats_CurrentActivePage)
    local baseTitle = pageRecord and pageRecord.title or "HeroStats"
    local pageName = pageRecord and pageRecord.name;
    
    -- Execute Text Outputs
    if isSoloWhisperLoop then
        if HeroStats_Print then HeroStats_Print("=== " .. baseTitle .. " ===") end
    else
        SendChatMessage("=== HeroStats: " .. baseTitle .. " ===", channelType, nil, channelNum)
    end

    for i = 1, linesToPost do
        local data = sortedHealers[i]
        if data then
            local lineMessage = ""
            
            -- Pure data-driven token mapping for perfect chat reports
            if pageName == "HEALING_DONE" then
                local formattedAmt = FormatDotNumber and FormatDotNumber(data.effective) or data.effective
                lineMessage = string.format("%d. %s - %s Effective Healing", i, data.name, formattedAmt)
            elseif pageName == "EFFICIENCY" then
                lineMessage = string.format("%d. %s - %.1f%% Healing Efficiency", i, data.name, data.percent)
            elseif pageName == "MANA_EFF" then
                lineMessage = string.format("%d. %s - %.1f HPM", i, data.name, data.hpm)
            elseif pageName == "DISPELS" then
                lineMessage = string.format("%d. %s - %d Dispels", i, data.name, data.dispels)
            elseif pageName == "BUFFS" then
                lineMessage = string.format("%d. %s - %d Buffs", i, data.name, data.buffs)
            elseif pageName == "DEATHS" then
                lineMessage = string.format("%d. %s - %d Deaths", i, data.name, data.deaths)
            elseif pageName == "RESURRECTS" then
                lineMessage = string.format("%d. %s - %d Resurrects", i, data.name, data.resurrects)
            elseif pageName == "DAMAGE_DONE" then
                local formattedAmt = FormatDotNumber and FormatDotNumber(data.damageDone) or data.damageDone
                lineMessage = string.format("%d. %s - %s Damage Done", i, data.name, formattedAmt)
            elseif pageName == "DAMAGE_TAKEN" then
                local formattedAmt = FormatDotNumber and FormatDotNumber(data.damageTaken) or data.damageTaken
                lineMessage = string.format("%d. %s - %s Damage Taken", i, data.name, formattedAmt)
            elseif pageName == "MANA_GAINED" then
                local formattedAmt = FormatDotNumber and FormatDotNumber(data.manaGained) or data.manaGained
                lineMessage = string.format("%d. %s - %s Mana Gained", i, data.name, formattedAmt)
            end

            if lineMessage ~= "" then
                if isSoloWhisperLoop then
                    if HeroStats_Print then HeroStats_Print(lineMessage) end
                else
                    SendChatMessage(lineMessage, channelType, nil, channelNum)
                end
            end
        end
    end
end

-- FIXED v1.0.0b3: Central Unit Aura Registration Hook
-- COMMENT: Registers the critical Blizzard aura update event directly to your custom focus frame
if FokusEraFrame then
    FokusEraFrame:RegisterEvent("UNIT_AURA")
    
    -- Dynamically hook into your frame's existing event processor cleanly
    local originalOnEvent = FokusEraFrame:GetScript("OnEvent")
    FokusEraFrame:SetScript("OnEvent", function(self, event, unit, ...)
        if event == "UNIT_AURA" then
            -- ERA COMPATIBILITY INTERCEPTOR: Since 'focus' unit doesn't exist natively,
            -- we check if the updated unit token matches the player name string we are currently tracking!
            if unit and UnitName(unit) == lastActiveFocusName then
                -- TRIGGER REFRESH: Invoke your addon's own master update function here!
                if FokusEra_UpdateAuras then
                    FokusEra_UpdateAuras()
                elseif FokusEra_UpdateFrame then
                    FokusEra_UpdateFrame()
                end
            end
        elseif originalOnEvent then
            -- Fallback safely to your addon's original event routing pipeline
            originalOnEvent(self, event, unit, ...)
        end
    end)
end

-- FIXED v0.10.0: Global API bridge to retrieve the local frame object securely
function HeroStats_GetCoreFrame()
    return coreFrame
end

-- end herostatscore.lua