-- ==========================================
-- HeroStats - Slash Command Engine (v0.6.0 Upgrade)
-- ==========================================

-- CENTRAL PRINT FACTORY: Manages the custom cyan addon logo and formatting globally
function HeroStats_Print(msg)
    if msg then
        print("|cff00bcffHeroStats:|r " .. msg)
    end
end

local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")
commFrame:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == "HeroStatsComm" then
        local command, value = string.match(text, "([^:]+):([^:]+)")
        if command == "QUERY_VERSION" then
            -- FIXED v1.0.0b2: Dynamic TOC Version Fetcher eliminates hardcoded version leaks completely
            local currentVer = C_AddOns and C_AddOns.GetAddOnMetadata("HeroStats", "Version") or GetAddOnMetadata("HeroStats", "Version") or "1.0.0b2"
            
            -- Respond silently back to the sender with our dynamically fetched version token
            C_ChatInfo.SendAddonMessage("HeroStatsComm", "RESP_VERSION:" .. currentVer, "WHISPER", sender)
        elseif command == "RESP_VERSION" and value then
            local cleanSender = string.match(sender, "([^-]+)") or sender
            HeroStats_Print(cleanSender .. " is running version " .. value)
        end
    end
end)

-- Register the secure addon network prefix with the game engine
C_ChatInfo.RegisterAddonMessagePrefix("HeroStatsComm")

local function HeroStats_SlashCommandHandler(msg)
    -- Secure tokenize parser splitting arguments by blank spaces cleanly
    local cmd, arg = string.match(msg or "", "^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")
    
    if cmd == "" or cmd == "open" then
        if HeroStats_ShowMainWindow then
            HeroStats_ShowMainWindow()
        else
            HeroStats_Print("Error - UI engine not fully loaded yet.")
        end
        
    elseif cmd == "resetui" then
        if HeroStatsContainer and HeroStatsSettings then
            HeroStatsSettings.point = "CENTER"
            HeroStatsSettings.relativePoint = "CENTER"
            HeroStatsSettings.xOfs = 0
            HeroStatsSettings.yOfs = 0
            HeroStatsSettings.width = 200
            HeroStatsSettings.height = 110
            HeroStatsSettings.locked = false
            
            HeroStatsContainer:SetSize(HeroStatsSettings.width, HeroStatsSettings.height)
            HeroStatsContainer:ClearAllPoints()
            HeroStatsContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            
            if HeroStatsScrollFrameScrollBar then
                HeroStatsScrollFrameScrollBar:SetValue(0)
            end
            
            if HeroStats_UpdateLockVisuals then
                HeroStats_UpdateLockVisuals(false)
            end
            
            HeroStats_Print("Window layout position successfully reset to center screen and UNLOCKED.")
        end
        
    -- Direct configuration shortcut command utilizing the dynamic numeric ID bridge
    elseif cmd == "config" or cmd == "options" then
        -- FIXED v1.0.0b1: Anti-Taint Combat Shield prevents protected API crashes during fights
        if InCombatLockdown and InCombatLockdown() then
            if HeroStats_Print then
                HeroStats_Print("|cffff4d4dThe configuration screen cannot be opened in combat.")
            end
        else
            if Settings and Settings.OpenToCategory and HeroStats_ConfigCategoryID then
                -- Modern Era API pathing utilizing the verified internal number ID
                Settings.OpenToCategory(HeroStats_ConfigCategoryID)
            else
                -- Legacy engine fallback pathing
                InterfaceOptionsFrame_OpenToCategory("HeroStats")
            end
        end

        
    elseif cmd == "version" then
        HeroStats_Print("Querying group members for installed addon versions...")
        local targetChannel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or "INSTANCE_CHAT")
        if IsInGroup() or IsInRaid() then
            C_ChatInfo.SendAddonMessage("HeroStatsComm", "QUERY_VERSION:0", targetChannel)
        else
            local currentVersion = C_AddOns and C_AddOns.GetAddOnMetadata("HeroStats", "Version") or "(Unknown)"
            HeroStats_Print(UnitName("player") .. " is running version " .. currentVersion)
        end
        
    elseif cmd == "help" then
        print("|cff00bcff--- HeroStats Slash Commands Help ---|r")
        print("|cff00ff00/hs|r or |cff00ff00/hs open|r - Opens and shows the main meter window.")
        print("|cff00ff00/hs config|r - Opens the Blizzard Addon Options configuration panel directly.")
        print("|cff00ff00/hs resetui|r - Resets the window position back to the center of your screen.")
        print("|cff00ff00/hs version|r - Queries all group/raid members to check their addon versions.")
        print("|cff00ff00/hs help|r - Displays this command help overview layout screen.")
        print("|cff00bcff--------------------------------------|r")
        
    else
        HeroStats_Print("Unknown command. Type |cff00ff00/hs help|r to see all available features.")
    end
end

SLASH_HEROSTATS1 = "/herostats"
SlashCmdList["HEROSTATS"] = HeroStats_SlashCommandHandler

SLASH_HS1 = "/hs"
SlashCmdList["HS"] = HeroStats_SlashCommandHandler

-- end herostatscmd.lua
