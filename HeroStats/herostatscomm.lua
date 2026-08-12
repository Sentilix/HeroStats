-- ==========================================
-- HeroStats - Communications & Reporting Engine (v0.10.2)
-- ==========================================

-- FIXED v1.0.0b1: File-level static constant cache optimizes memory by preventing table recreation on click
local HEROSTATS_VIEW_DISPLAY_NAMES = {
    ["DAMAGE_DONE"]         = "Damage Done",
    ["HEALING"]             = "Healing Done",
    ["HEALING_DONE"]        = "Healing Done",
    ["DMG_CRIT"]            = "Damage Crits",
    ["HEAL_CRIT"]           = "Healing Crits",
    ["DAMAGE_TAKEN"]        = "Damage Taken",
    ["DMG_TAKEN"]           = "Damage Taken",
    ["OVERHEALING"]         = "Overhealing",
    ["EFFICIENCY"]          = "Overhealing",
    ["MANA_EFF"]            = "Heal per Mana",
    ["MANA_GAINED"]         = "Mana Gained",
    ["DISPELS"]             = "Dispels",
    ["BUFFS"]               = "Applied Buffs",
    ["DEATHS"]              = "Fatal Damage Log",
    ["RESURRECTS"]          = "Resurrect Recipients",
    ["PERSONAL_DMG_RECORDS"] = "Personal Damage Records",
    ["PERSONAL_HEAL_RECORDS"] = "Personal Healing Records"
}

-- FIXED v1.0.0b1: Async chat queue engine handles all secure server channels via C_Timer to bypass Blizzard action blockades
function HeroStats_SendQueuedMessages(msgList, channel, isCustom, customNum)
    if not msgList or #msgList == 0 then return end

    -- FIXED v1.0.0b1: Completely eliminated instant firing loops for network channels to prevent UI Taint bans
    local index = 1
    local function SendNextLine()
        if index <= #msgList then
            local lineMsg = msgList[index]
            
            -- Dynamic channel router resolves custom channels, whispers, and standard network layers safely
            if isCustom and customNum then
                SendChatMessage(lineMsg, "CHANNEL", nil, customNum)
            elseif channel == "WHISPER" and customNum then
                -- Note: customNum contains the target player's name string forwarded from your popup layers
                SendChatMessage(lineMsg, "WHISPER", nil, customNum)
            else
                SendChatMessage(lineMsg, channel)
            end
            
            index = index + 1
            C_Timer.After(0.3, SendNextLine) -- Safe 300ms window bypasses Blizzard anti-spam shields flawlessly
        end
    end
    
    -- Fire the asynchronous serialization cascade pipeline instantly
    SendNextLine()
end

-- FIXED v1.0.0b1: Universal Network Channel Validator
function HeroStats_IsChannelAccessible(channel)
    if not channel then return false end
    
    if (channel == "RAID" and not IsInRaid()) or (channel == "PARTY" and not IsInGroup()) then
        return false
    end
    
    if channel == "GUILD" and not IsInGuild() then
        return false
    end
    
    return true
end

-- FIXED v1.0.0b1: Upgraded asynchronous damage reporter with native channel validation and local print short-circuiting
function HeroStats_Report_DamageDone(playerData, channel, isCustom, customNum, fightSeconds)
    if not playerData or not playerData.spellDamage then 
        print("No player data");
		return
    end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local dps = (fightSeconds > 0) and (playerData.damageDone / fightSeconds) or 0
    local formattedTotal = FormatDotNumber and FormatDotNumber(playerData.damageDone) or playerData.damageDone
    local headerMsg = string.format("HeroStats - Top Damage Done for %s: %s (%.0f DPS):", playerData.name or "Unknown", formattedTotal, dps)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.spellDamage) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local sharePct = (playerData.damageDone > 0) and ((s.amount / playerData.damageDone) * 100) or 0
        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amount) or s.amount
        local lineMsg = string.format("%d. %s: %s (%.1f%%)", i, s.name, formattedAmt, sharePct)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then 
                HeroStats_Print(rawMessage) -- Routes safely straight into your custom cyan branding factory
            end
        end
    else
        -- Native asynchronous packet management deployment framework for server channels
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end


-- FIXED v1.0.0b1: Upgraded asynchronous healing reporter with native channel validation and local print short-circuiting
function HeroStats_Report_HealingDone(playerData, channel, isCustom, customNum, fightSeconds)
    if not playerData or not playerData.spellHeals then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local hps = (fightSeconds > 0) and (playerData.effective / fightSeconds) or 0
    local formattedTotal = FormatDotNumber and FormatDotNumber(playerData.effective) or playerData.effective
    local headerMsg = string.format("HeroStats - Top Healing Done for %s: %s (%.0f HPS):", playerData.name or "Unknown", formattedTotal, hps)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, hData in pairs(playerData.spellHeals) do
        if hData.effective > 0 then 
            table.insert(sortedSpells, { name = spellName, amount = hData.effective, overheal = hData.overheal or 0 }) 
        end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local sharePct = (playerData.effective > 0) and ((s.amount / playerData.effective) * 100) or 0
        local totalSpellHeal = s.amount + s.overheal
        local ohPct = (totalSpellHeal > 0) and ((s.overheal / totalSpellHeal) * 100) or 0
        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amount) or s.amount
        local lineMsg = string.format("%d. %s: %s (%.1f%%) [OH: %.0f%%]", i, s.name, formattedAmt, sharePct, ohPct)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then 
                HeroStats_Print(rawMessage) -- Routes safely straight into your custom cyan branding factory
            end
        end
    else
        -- Native asynchronous packet management deployment framework for server channels
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b1: Upgraded asynchronous damage crits reporter with native channel validation and local print short-circuiting
function HeroStats_Report_DamageCrits(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellCrits then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Top Damage Crits for %s:", playerData.name or "Unknown")
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    local totalSessionCritDmg = 0
    for spellName, cr in pairs(playerData.spellCrits) do
        local totalCritDmg = cr.dmg or 0
        if totalCritDmg > 0 then
            table.insert(sortedSpells, { name = spellName, crits = cr.crits or 0, dmg = totalCritDmg })
            totalSessionCritDmg = totalSessionCritDmg + totalCritDmg
        end
    end
    table.sort(sortedSpells, function(a, b) return a.dmg > b.dmg end)
    if totalSessionCritDmg == 0 then totalSessionCritDmg = 1 end

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local spellCritSharePct = (s.dmg / totalSessionCritDmg) * 100
        local formattedDmg = FormatDotNumber and FormatDotNumber(s.dmg) or s.dmg
        local lineMsg = string.format("%d. %s: %s (%d crits) (%.1f%%)", i, s.name, formattedDmg, s.crits, spellCritSharePct)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b1: Upgraded asynchronous damage taken reporter with native channel validation and local print short-circuiting
function HeroStats_Report_DamageTaken(playerData, channel, isCustom, customNum, fightSeconds)
    if not playerData or not playerData.spellTaken then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local dtps = (fightSeconds > 0) and (playerData.damageTaken / fightSeconds) or 0
    local formattedTotal = FormatDotNumber and FormatDotNumber(playerData.damageTaken) or playerData.damageTaken
    local headerMsg = string.format("HeroStats - Top Damage Taken for %s: %s (%.0f DTPS):", playerData.name or "Unknown", formattedTotal, dtps)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.spellTaken) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end 
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local sharePct = (playerData.damageTaken > 0) and ((s.amount / playerData.damageTaken) * 100) or 0
        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amount) or s.amount
        local lineMsg = string.format("%d. %s: %s (%.1f%%)", i, s.name, formattedAmt, sharePct)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b1: Upgraded asynchronous healing crits reporter with native channel validation and local print short-circuiting
function HeroStats_Report_HealingCrits(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellHealCrits then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Top Healing Crits for %s:", playerData.name or "Unknown")
    table.insert(msgQueue, headerMsg)

    local sortedHeals = {}
    local totalSessionCritHeal = 0
    for spellName, cr in pairs(playerData.spellHealCrits) do
        local totalCritHeal = cr.amt or 0
        if totalCritHeal > 0 then
            table.insert(sortedHeals, { name = spellName, crits = cr.crits or 0, amt = totalCritHeal })
            totalSessionCritHeal = totalSessionCritHeal + totalCritHeal
        end
    end
    table.sort(sortedHeals, function(a, b) return a.amt > b.amt end)
    if totalSessionCritHeal == 0 then totalSessionCritHeal = 1 end

    for i = 1, math.min(5, #sortedHeals) do
        local h = sortedHeals[i]
        local spellCritSharePct = (h.amt / totalSessionCritHeal) * 100
        local formattedHeal = FormatDotNumber and FormatDotNumber(h.amt) or h.amt
        local lineMsg = string.format("%d. %s: %s (%d crits) (%.1f%%)", i, h.name, formattedHeal, h.crits, spellCritSharePct)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b1: Upgraded asynchronous efficiency reporter with native channel validation and local print short-circuiting
function HeroStats_Report_Efficiency(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellHeals then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Overhealing Breakdown for %s (%.1f%% Efficiency):", playerData.name or "Unknown", playerData.percent or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, hData in pairs(playerData.spellHeals) do
        local total = (hData.effective or 0) + (hData.overheal or 0)
        if total > 0 then 
            table.insert(sortedSpells, { name = spellName, effective = hData.effective or 0, overheal = hData.overheal or 0, total = total }) 
        end
    end
    table.sort(sortedSpells, function(a, b) return b.overheal > a.overheal end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local spellEffPct = (s.total > 0) and ((s.effective / s.total) * 100) or 0
        local formattedOH = FormatDotNumber and FormatDotNumber(s.overheal) or s.overheal
        local lineMsg = string.format("%d. %s: %s Overheal (Ability Eff: %.1f%%)", i, s.name, formattedOH, spellEffPct)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b1: Upgraded asynchronous mana efficiency reporter with native channel validation and local print short-circuiting
function HeroStats_Report_ManaEff(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellMana then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Heal per Mana for %s (%.1f HPM):", playerData.name or "Unknown", playerData.hpm or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, mData in pairs(playerData.spellMana) do
        local mUsed = mData.manaUsed or 0
        if mUsed > 0 then
            local trueEffective = mData.effective or 0
            if trueEffective == 0 and playerData.spellHeals and playerData.spellHeals[spellName] then
                trueEffective = playerData.spellHeals[spellName].effective or 0
            end
            local spellHPM = trueEffective / mUsed
            table.insert(sortedSpells, { name = spellName, hpm = spellHPM, used = mUsed })
        end
    end
    table.sort(sortedSpells, function(a, b) return a.hpm > b.hpm end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local formattedMana = FormatDotNumber and FormatDotNumber(s.used) or s.used
        local lineMsg = string.format("%d. %s %s mana (%.1f HPM)", i, s.name, formattedMana, s.hpm)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b1: Upgraded asynchronous mana gained reporter with native channel validation and local print short-circuiting
function HeroStats_Report_ManaGained(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellManaGained then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local formattedTotal = FormatDotNumber and FormatDotNumber(playerData.manaGained) or playerData.manaGained
    local headerMsg = string.format("HeroStats - Mana Gained Breakdown for %s: %s total mana:", playerData.name or "Unknown", formattedTotal)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.spellManaGained) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local formattedAmt = FormatDotNumber and FormatDotNumber(s.amount) or s.amount
        local lineMsg = string.format("%d. %s: +%s mana", i, s.name, formattedAmt)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b1: Upgraded asynchronous dispels reporter with native channel validation and local print short-circuiting
function HeroStats_Report_Dispels(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellDispels then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Dispels Breakdown for %s (%d total):", playerData.name or "Unknown", playerData.dispels or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.spellDispels) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local lineMsg = string.format("%d. %s: %d dispels", i, s.name, s.amount)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b1: Upgraded asynchronous buffs reporter with native channel validation and local print short-circuiting
function HeroStats_Report_Buffs(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.spellBuffs then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Applied Buffs Breakdown for %s (%d total):", playerData.name or "Unknown", playerData.buffs or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.spellBuffs) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local lineMsg = string.format("%d. %s: %d casts", i, s.name, s.amount)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b1: Upgraded asynchronous deaths reporter with native channel validation and local print short-circuiting
function HeroStats_Report_Deaths(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.deathCauses then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Fatal Damage Log for %s (%d deaths):", playerData.name or "Unknown", playerData.deaths or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for spellName, amt in pairs(playerData.deathCauses) do
        if amt > 0 then table.insert(sortedSpells, { name = spellName, amount = amt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local lineMsg = string.format("%d. %s: %d fatalities", i, s.name, s.amount)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b1: Upgraded asynchronous resurrects reporter with native channel validation and local print short-circuiting
function HeroStats_Report_Resurrects(playerData, channel, isCustom, customNum)
    if not playerData or not playerData.resRecipients then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}
    local headerMsg = string.format("HeroStats - Resurrect Recipients for %s (%d casted):", playerData.name or "Unknown", playerData.resurrects or 0)
    table.insert(msgQueue, headerMsg)

    local sortedSpells = {}
    for targetName, rData in pairs(playerData.resRecipients) do
        local tAmt = type(rData) == "table" and rData.amount or rData
        if tAmt > 0 then table.insert(sortedSpells, { name = targetName, amount = tAmt }) end
    end
    table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

    for i = 1, math.min(5, #sortedSpells) do
        local s = sortedSpells[i]
        local lineMsg = string.format("%d. %s: Brought back %d times", i, s.name, s.amount)
        table.insert(msgQueue, lineMsg)
    end
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b2: Global asynchronous reporter function for Personal Damage Records museum (Page 13)
function HeroStats_Report_PersonalDamage(recordData, channel, isCustom, customNum)
    if not recordData then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}

    -- FIXED v1.0.0b2: Robust Sub-Table Fallback Router extracts valid historic values dynamically
    local maxNormal = (recordData.normal and type(recordData.normal) == "table") and (recordData.normal.amount or 0) or 0
    local maxCrit = (recordData.crit and type(recordData.crit) == "table") and (recordData.crit.amount or 0) or 0
    local trueRecordAmount = recordData.amount or math.max(maxNormal, maxCrit)
    
    -- Determine current record context safely based on master amount ceilings
    local finalIsCrit = recordData.isCrit or (maxCrit >= maxNormal and maxCrit > 0)
    local critStr = finalIsCrit and "Critical Strike" or "Normal Hit"
    
    -- Dynamically map target, date, and activity labels under a secure nil-shield
    local recordTarget = recordData.target or (finalIsCrit and recordData.crit and recordData.crit.target) or (recordData.normal and recordData.normal.target) or "Unknown"
    local recordDate = recordData.date or (finalIsCrit and recordData.crit and recordData.crit.date) or (recordData.normal and recordData.normal.date) or "Unknown"
    
    -- Detect if this is an isolated periodic DoT block to resolve the correct metric label
    local isPeriodicSpell = string.find(recordData.name or "", "%([HD]oT%)")
    local counterLabel = isPeriodicSpell and "Total Ticks" or "Total Casts"
    local finalCounterVal = isPeriodicSpell and (recordData.ticks or 0) or (recordData.casts or 0)

    local formattedAmt = FormatDotNumber and FormatDotNumber(trueRecordAmount) or trueRecordAmount
    
    -- Compile a beautiful, high-value milestone header layout
    local headerMsg = string.format("HeroStats - Damage Record for %s: %s!", recordData.name or "Unknown", tostring(formattedAmt))
    table.insert(msgQueue, headerMsg)
    
    -- Compile detailed statistical layout bullet points containing targets and isolated career casts
    local line1 = string.format("- Max Value: %s (%s)", tostring(formattedAmt), critStr)
    local line2 = string.format("- Target: %s", tostring(recordTarget))
    local line3 = string.format("- Date: %s", tostring(recordDate))
    local line4 = string.format("- %s: %d", counterLabel, finalCounterVal)
    
    table.insert(msgQueue, line1)
    table.insert(msgQueue, line2)
    table.insert(msgQueue, line3)
    table.insert(msgQueue, line4)
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b2: Global asynchronous reporter function for Personal Healing Records (Page 14)
function HeroStats_Report_PersonalHealing(recordData, channel, isCustom, customNum)
    if not recordData then return end
    
    -- FIXED v1.0.0b1: Dynamic Channel Validation Interceptor routes into mock LOCAL state safely
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
        isCustom = false
    end
    
    local msgQueue = {}

    -- FIXED v1.0.0b2: Robust Sub-Table Fallback Router extracts valid historic values dynamically
    local maxNormal = (recordData.normal and type(recordData.normal) == "table") and (recordData.normal.amount or 0) or 0
    local maxCrit = (recordData.crit and type(recordData.crit) == "table") and (recordData.crit.amount or 0) or 0
    local trueRecordAmount = recordData.amount or math.max(maxNormal, maxCrit)
    
    -- Determine current record context safely based on master amount ceilings
    local finalIsCrit = recordData.isCrit or (maxCrit >= maxNormal and maxCrit > 0)
    local critStr = finalIsCrit and "Critical Heal" or "Normal Heal"
    
    -- Dynamically map target, date, and activity labels under a secure nil-shield
    local recordTarget = recordData.target or (finalIsCrit and recordData.crit and recordData.crit.target) or (recordData.normal and recordData.normal.target) or "Unknown"
    local recordDate = recordData.date or (finalIsCrit and recordData.crit and recordData.crit.date) or (recordData.normal and recordData.normal.date) or "Unknown"
    
    -- Detect if this is an isolated periodic HoT block to resolve the correct metric label
    local isPeriodicSpell = string.find(recordData.name or "", "%([HD]oT%)")
    local counterLabel = isPeriodicSpell and "Total Ticks" or "Total Casts"
    local finalCounterVal = isPeriodicSpell and (recordData.ticks or 0) or (recordData.casts or 0)

    local formattedAmt = FormatDotNumber and FormatDotNumber(trueRecordAmount) or trueRecordAmount
    
    -- Compile a beautiful, high-value milestone header layout
    local headerMsg = string.format("HeroStats - Healing Record for %s: %s!", recordData.name or "Unknown", tostring(formattedAmt))
    table.insert(msgQueue, headerMsg)
    
    -- Compile detailed statistical layout bullet points containing targets and isolated career casts
    local line1 = string.format("- Max Value: %s (%s)", tostring(formattedAmt), critStr)
    local line2 = string.format("- Target: %s", tostring(recordTarget))
    local line3 = string.format("- Date: %s", tostring(recordDate))
    local line4 = string.format("- %s: %d", counterLabel, finalCounterVal)
    
    table.insert(msgQueue, line1)
    table.insert(msgQueue, line2)
    table.insert(msgQueue, line3)
    table.insert(msgQueue, line4)
    
    -- PIPELINE RESOLUTION BLOCK: Short-circuits asynchronous engine if channel evaluates to LOCAL
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, isCustom, customNum)
        end
    end
end

-- FIXED v1.0.0b1: Universal Asynchronous Page Overview Reporter (Main Header Bar Engine)
function HeroStats_Report_ActivePageOverview(masterSession, viewType, fightSeconds, targetChannel)
    if not masterSession then return end

    -- Dynamically reads the channel passed from the menu selection with a safe network lock
    local channel = targetChannel or "LOCAL"
    if not HeroStats_IsChannelAccessible or not HeroStats_IsChannelAccessible(channel) then
        channel = "LOCAL"
    end

    -- Maps the core player data directly from the universal .healers raid array table
    local sourceData = nil
    if viewType == "PERSONAL_DMG_RECORDS" or viewType == "PERSONAL_HEAL_RECORDS" then
        sourceData = masterSession -- Museums map records directly
    else
        -- COMBAT SESSIONS: Everything logs cleanly inside the master healers pool
        sourceData = masterSession.healers
    end

    if not sourceData then 
        return 
    end

    local msgQueue = {}    
    -- FIXED v1.0.0b1: Dynamically extracts the true fightDuration from database logs if fightSeconds lands as nil
    local duration = masterSession.fightDuration or fightSeconds or 1
    if duration <= 0 then duration = 1 end

    -- Pack and prepare individual player blocks or records into sorting slots cleanly
    local sortedList = {}
    for pNameOrGuid, pData in pairs(sourceData) do
        if pData and type(pData) == "table" then
            local item = {}
            -- Inherit all player metrics dynamically
            for k, v in pairs(pData) do item[k] = v end
            -- Enforce clean fallback display strings for player names
            item.name = item.name or pData.name or pNameOrGuid
            
            -- Enforces perfect structural alignment across ALL views using 'item' context exclusively
            if viewType == "HEALING" or viewType == "HEALING_DONE" then 
                item.sortAmount = item.effective or 0
            elseif viewType == "HEAL_CRIT" then 
                item.sortAmount = item.healCritPct or 0
            elseif viewType == "OVERHEALING" or viewType == "EFFICIENCY" then 
                item.sortAmount = item.percent or 100
            elseif viewType == "MANA_EFF" then 
                item.sortAmount = item.hpm or 0
            elseif viewType == "MANA_GAINED" then 
                item.sortAmount = item.manaGained or 0
            elseif viewType == "DAMAGE_DONE" then 
                item.sortAmount = item.damageDone or 0
            elseif viewType == "DMG_CRIT" then 
                item.sortAmount = item.dmgCritPct or 0
            elseif viewType == "DAMAGE_TAKEN" or viewType == "DMG_TAKEN" then 
                item.sortAmount = item.damageTaken or 0
            elseif viewType == "DISPELS" then 
                item.sortAmount = item.dispels or 0
            elseif viewType == "BUFFS" then 
                item.sortAmount = item.buffs or 0
            elseif viewType == "DEATHS" then 
                item.sortAmount = item.deaths or 0
            elseif viewType == "RESURRECTS" then 
                item.sortAmount = item.resurrects or 0
            end

            table.insert(sortedList, item)
        end
    end

    -- EMPTY PAGE SHORT-CIRCUIT: If the sorted list contains zero data, exit silently
    if #sortedList == 0 then
        return 
    end

    -- Sorter maps cleanly onto descending ranks
    table.sort(sortedList, function(a, b)
        if viewType == "OVERHEALING" or viewType == "EFFICIENCY" then
            return (a.sortAmount or 100) < (b.sortAmount or 100) -- Lower percentage = higher efficiency ranking
        elseif viewType == "PERSONAL_DMG_RECORDS" or viewType == "PERSONAL_HEAL_RECORDS" then
            local aNormal = (a.normal and type(a.normal) == "table") and (a.normal.amount or 0) or 0
            local aCrit = (a.crit and type(a.crit) == "table") and (a.crit.amount or 0) or 0
            local aMax = math.max(aNormal, aCrit)
            
            local bNormal = (b.normal and type(b.normal) == "table") and (b.normal.amount or 0) or 0
            local bCrit = (b.crit and type(b.crit) == "table") and (b.crit.amount or 0) or 0
            local bMax = math.max(bNormal, bCrit)
            
            return aMax > bMax
        else
            return (a.sortAmount or 0) > (b.sortAmount or 0)
        end
    end)

    -- Headline is dynamically compiled and injected ONLY when data is guaranteed to exist
    local cleanViewName = HEROSTATS_VIEW_DISPLAY_NAMES[viewType] or viewType
    local fightIdStr = masterSession.id and (" #" .. tostring(masterSession.id)) or ""
    local fightNameStr = (masterSession.name and masterSession.name ~= "") and (" [" .. tostring(masterSession.name) .. "]") or ""
    local headerTitle = string.format("HeroStats%s%s - %s", fightIdStr, fightNameStr, cleanViewName)
    
    if viewType == "PERSONAL_DMG_RECORDS" or viewType == "PERSONAL_HEAL_RECORDS" then
        headerTitle = string.format("HeroStats - Lifetime Records - %s", cleanViewName)
    end
    table.insert(msgQueue, headerTitle)

    -- Compile top 5 report data strings inside loop using the validated data pointer
    for i = 1, math.min(5, #sortedList) do
        local data = sortedList[i]
        local valueText = "0"

        if viewType == "HEALING" or viewType == "HEALING_DONE" then
            local formattedAmt = FormatDotNumber and FormatDotNumber(data.effective) or data.effective
            valueText = string.format("%s (%.0f HPS)", formattedAmt, (data.effective or 0) / duration)
        elseif viewType == "HEAL_CRIT" then
            valueText = string.format("%.1f%% Crit", data.healCritPct or 0)
        elseif viewType == "OVERHEALING" or viewType == "EFFICIENCY" then
            valueText = string.format("%.1f%% Efficiency", data.percent or 0)
        elseif viewType == "MANA_EFF" then
            valueText = string.format("%.1f HPM", data.hpm or 0)
        elseif viewType == "MANA_GAINED" then
            local formattedAmt = FormatDotNumber and FormatDotNumber(data.manaGained) or data.manaGained
            valueText = string.format("%s mana", formattedAmt)
        elseif viewType == "DAMAGE_DONE" then
            local formattedAmt = FormatDotNumber and FormatDotNumber(data.damageDone) or data.damageDone
            valueText = string.format("%s (%.0f DPS)", formattedAmt, (data.damageDone or 0) / duration)
        elseif viewType == "DMG_CRIT" then
            valueText = string.format("%.1f%% Crit", data.dmgCritPct or 0)
        elseif viewType == "DAMAGE_TAKEN" or viewType == "DMG_TAKEN" then
            local formattedAmt = FormatDotNumber and FormatDotNumber(data.damageTaken) or data.damageTaken
            valueText = string.format("%s (%.0f DTPS)", formattedAmt, (data.damageTaken or 0) / duration)
        elseif viewType == "DISPELS" then valueText = string.format("%d Dispels", data.dispels or 0)
        elseif viewType == "BUFFS" then valueText = string.format("%d Buffs", data.buffs or 0)
        elseif viewType == "DEATHS" then valueText = string.format("%d Deaths", data.deaths or 0)
        elseif viewType == "RESURRECTS" then valueText = string.format("%d Resses", data.resurrects or 0)
        elseif viewType == "PERSONAL_DMG_RECORDS" or viewType == "PERSONAL_HEAL_RECORDS" then
            local maxNormal = (data.normal and type(data.normal) == "table") and (data.normal.amount or 0) or 0
            local maxCrit = (data.crit and type(data.crit) == "table") and (data.crit.amount or 0) or 0
            local maxLifetimeRecord = math.max(maxNormal, maxCrit)
            
            -- FIXED v1.0.0b1: Dynamic Counter Resolver injects your true casts/ticks directly into the chat stream!
            local isPeriodicBar = string.find(data.name or "", "%(HoT%)") or string.find(data.name or "", "%(DoT%)")
            local activityLabel = isPeriodicBar and "Ticks" or "Casts"
            local activityCount = isPeriodicBar and (data.ticks or 0) or (data.casts or 0)
            
            if maxLifetimeRecord > 0 then
                local suffixStr = (maxCrit >= maxNormal) and "Crit" or "Normal"
                local finalAmt = FormatDotNumber and FormatDotNumber(maxLifetimeRecord) or maxLifetimeRecord
                
                valueText = string.format("%s (%s) [%d %s]", tostring(finalAmt), suffixStr, activityCount, activityLabel)
            else
                valueText = string.format("[%d %s]", activityCount, activityLabel)
            end
        end

        local lineMsg = string.format("%d. %s: %s", i, data.name or "Unknown", valueText)
        table.insert(msgQueue, lineMsg)
    end

    -- Pipeline execution short-circuits safely to local prints
    if channel == "LOCAL" then
        for _, rawMessage in ipairs(msgQueue) do
            if HeroStats_Print then HeroStats_Print(rawMessage) end
        end
    else
        if HeroStats_SendQueuedMessages then
            HeroStats_SendQueuedMessages(msgQueue, channel, false, nil)
        end
    end
end

-- end herostatscomm.lua
