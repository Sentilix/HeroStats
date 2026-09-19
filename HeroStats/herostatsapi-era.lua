-- ============================================================================
-- HeroStatsAPI - Era Specific Abstraction Layer Pipeline
-- ============================================================================
HeroStatsAPI = {}

-- CONTRACT IMPLEMENTATION: Era local realm identity mapper
function HeroStatsAPI.GetFullName(unit)
    if not unit then return "Unknown" end
    local name, realm = UnitName(unit)
    if not name or name == "" then return "Unknown" end
    
    if realm and realm ~= "" then
        return string.format("%s-%s", name, realm)
    end
    return name
end

-- CONTRACT IMPLEMENTATION: Era raw combat log unpacker baseline
function HeroStatsAPI.GetCombatLogInfo(...)
    -- Era requires the global Blizzard function to unpack the values
    return CombatLogGetCurrentEventInfo()
end

function HeroStatsAPI.RegisterCombatLog(frame)
    if frame and frame.RegisterEvent then
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end
