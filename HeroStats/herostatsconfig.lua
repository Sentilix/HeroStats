-- ==========================================
-- HeroStats - Interface Options Config Panel (v1.0.0b1)
-- ==========================================

local configPanel = CreateFrame("Frame", "HeroStatsConfigPanel", UIParent)
configPanel.name = "HeroStats"

local addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("HeroStats", "Version") or "Unknown"

-- Create Credits Header Text
local creditsText = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
local addonAuthor = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("HeroStats", "Author") or "mimma @ EU-Pyrewood Village"
creditsText:SetPoint("TOPLEFT", 16, -6)
creditsText:SetText("HeroStats v" .. addonVersion .. " - by " .. addonAuthor)
creditsText:SetTextColor(0.75, 0.75, 0.75, 1.0)

-- Create Title Layout Text
local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", creditsText, "BOTTOMLEFT", 0, -14)
title:SetText("HeroStats Configuration")

local subText = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subText:SetText("Customize your multi-session layout behaviors and history limits below.")


-- ==========================================
-- ROW 1: GROUP JOIN BEHAVIOR (LEFT) & MAX SAVED SESSIONS (RIGHT)
-- ==========================================

-- Left Column: Group Join Behavior Label
local groupLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
groupLabel:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -30)
groupLabel:SetText("When joining a new Group or Raid:")
groupLabel:SetTextColor(1.0, 0.82, 0.0, 1.0) -- Symmetrical Gold Header

-- Helper to generate group radio buttons with crisp white text labels
local function CreateRadioButton(name, text, yOffset)
    local cb = CreateFrame("CheckButton", name, configPanel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", groupLabel, "BOTTOMLEFT", 0, yOffset)
    local cbText = _G[cb:GetName() .. "Text"]
    if cbText then 
        cbText:SetText(text) 
        cbText:SetTextColor(1.0, 1.0, 1.0, 1.0)
    end
    return cb
end

local cbDelete = CreateRadioButton("HeroStatsCBDelete", "Automatically clear all history", -10)
local cbKeep   = CreateRadioButton("HeroStatsCBKeep", "Keep history and accumulate data", -35)
local cbAsk    = CreateRadioButton("HeroStatsCBAsk", "Prompt me with a popup dialog", -60)

-- Right Column: Max Saved Sessions Slider (Shifted 300px right)
local slider = CreateFrame("Slider", "HeroStatsSessionSlider", configPanel, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 300, -45)
slider:SetMinMaxValues(5, 100)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)

local sliderLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sliderLabel:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
sliderLabel:SetText("Max Saved Sessions:")
sliderLabel:SetTextColor(1.0, 0.82, 0.0, 1.0)

local lowText = _G[slider:GetName() .. "Low"]
if lowText then lowText:SetText("5") end

local highText = _G[slider:GetName() .. "High"]
if highText then highText:SetText("100") end

local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)


-- ==========================================
-- RADIO CORE LOGIC & INITIAL SYNCHRONIZATION
-- ==========================================

local function SyncGroupRadioButtons(selectedMode)
    cbDelete:SetChecked(selectedMode == 1)
    cbKeep:SetChecked(selectedMode == 2)
    cbAsk:SetChecked(selectedMode == 3)
    if HeroStatsSettings then HeroStatsSettings.groupJoinBehavior = selectedMode end
end

cbDelete:SetScript("OnClick", function() SyncGroupRadioButtons(1) end)
cbKeep:SetScript("OnClick", function() SyncGroupRadioButtons(2) end)
cbAsk:SetScript("OnClick", function() SyncGroupRadioButtons(3) end)

slider:SetScript("OnValueChanged", function(self, value)
    local roundedValue = math.floor(value + 0.5)
    valueText:SetText(tostring(roundedValue))
    if HeroStatsSettings then
        HeroStatsSettings.maxSessionsLimit = roundedValue
        HEROSTATS_MAX_SAVED_SESSIONS = roundedValue
    end
end)


-- ==========================================
-- ROW 2: PERSONAL RECORDS NOTIFICATIONS (LEFT COLUMN)
-- ==========================================

-- Create Section Label Layout anchored cleanly under Row 1's radio buttons
local notifyLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
notifyLabel:SetPoint("TOPLEFT", groupLabel, "BOTTOMLEFT", 0, -95)
notifyLabel:SetText("Personal Record Alerts & Pings:")
notifyLabel:SetTextColor(1.0, 0.82, 0.0, 1.0)

-- 1. RADIO BUTTON: MUTE ALL (Mode 1)
local cbRecNone = CreateFrame("CheckButton", "HeroStats_RadioRecNone", configPanel, "InterfaceOptionsCheckButtonTemplate")
cbRecNone:SetPoint("TOPLEFT", notifyLabel, "BOTTOMLEFT", 0, -10)
local textNone = _G[cbRecNone:GetName() .. "Text"]
if textNone then
    textNone:SetText("Mute All Alerts (Silent Mode)")
    textNone:SetTextColor(1.0, 1.0, 1.0, 1.0)
end

-- 2. RADIO BUTTON: LOCAL CHAT ALERTS (Mode 2)
local cbRecLocal = CreateFrame("CheckButton", "HeroStats_RadioRecLocal", configPanel, "InterfaceOptionsCheckButtonTemplate")
cbRecLocal:SetPoint("TOPLEFT", cbRecNone, "BOTTOMLEFT", 0, -8)
local textLocal = _G[cbRecLocal:GetName() .. "Text"]
if textLocal then
    textLocal:SetText("Local chat only")
    textLocal:SetTextColor(1.0, 1.0, 1.0, 1.0)
end

-- 3. RADIO BUTTON: SCREEN WARNING ALERTS (Mode 3)
local cbRecScreen = CreateFrame("CheckButton", "HeroStats_RadioRecScreen", configPanel, "InterfaceOptionsCheckButtonTemplate")
cbRecScreen:SetPoint("TOPLEFT", cbRecLocal, "BOTTOMLEFT", 0, -8)
local textScreen = _G[cbRecScreen:GetName() .. "Text"]
if textScreen then
    textScreen:SetText("Screen Warning Alert Display")
    textScreen:SetTextColor(1.0, 1.0, 1.0, 1.0)
end

-- 4. RADIO BUTTON: GROUP ANNOUNCE (Mode 4)
local cbRecGroup = CreateFrame("CheckButton", "HeroStats_RadioRecGroup", configPanel, "InterfaceOptionsCheckButtonTemplate")
cbRecGroup:SetPoint("TOPLEFT", cbRecScreen, "BOTTOMLEFT", 0, -8)
local textGroup = _G[cbRecGroup:GetName() .. "Text"]
if textGroup then
    textGroup:SetText("Announce to Active Raid/Party Chat")
    textGroup:SetTextColor(1.0, 1.0, 1.0, 1.0)
end


-- ==========================================
-- RADIO ENGINE & DATABASE SYNCHRONIZATION
-- ==========================================

-- Helper function to toggle the record radio state visually and save dynamically
local function HeroStats_UpdateNotificationRadioButtons(activeMode)
    if HeroStatsSettings then
        HeroStatsSettings.recordNotifyMode = activeMode
    end
    
    if cbRecNone then cbRecNone:SetChecked(activeMode == 1) end
    if cbRecLocal then cbRecLocal:SetChecked(activeMode == 2) end
    if cbRecScreen then cbRecScreen:SetChecked(activeMode == 3) end
    if cbRecGroup then cbRecGroup:SetChecked(activeMode == 4) end
end

cbRecNone:SetScript("OnClick", function()
    HeroStats_UpdateNotificationRadioButtons(1)
    PlaySound(856)
end)

cbRecLocal:SetScript("OnClick", function()
    HeroStats_UpdateNotificationRadioButtons(2)
    PlaySound(856)
end)

cbRecScreen:SetScript("OnClick", function()
    HeroStats_UpdateNotificationRadioButtons(3)
    PlaySound(856)
end)

cbRecGroup:SetScript("OnClick", function()
    HeroStats_UpdateNotificationRadioButtons(4)
    PlaySound(856)
end)

-- ON-SHOW PIPELINE: Read database state dynamically when opening options panel
local function HeroStats_RefreshRadioVisuals()
    if not HeroStatsSettings then return end
    local currentMode = HeroStatsSettings.recordNotifyMode or 3
    HeroStats_UpdateNotificationRadioButtons(currentMode)
end

configPanel:HookScript("OnShow", HeroStats_RefreshRadioVisuals)


-- ==========================================
-- BLIZZARD INTERFACE REGISTRATION PIPELINE
-- ==========================================

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(configPanel, configPanel.name)
    Settings.RegisterAddOnCategory(category)
    HeroStats_ConfigCategoryID = category:GetID()
else
    InterfaceOptions_AddCategory(configPanel)
end


-- ==========================================
-- RESET ENGINE & EMERGENCY PURGE MODULE
-- ==========================================

local btnResetRecords = CreateFrame("Button", "HeroStatsResetRecordsButton", configPanel, "UIPanelButtonTemplate")
btnResetRecords:SetSize(160, 24)
btnResetRecords:SetPoint("TOPLEFT", cbRecGroup, "BOTTOMLEFT", 0, -40)
btnResetRecords:SetText("Reset Personal Records")

StaticPopupDialogs["HEROSTATS_PURGE_RECORDS_CONFIRM"] = {
    text = "WARNING: Are you sure you want to permanently reset ALL your historical personal Damage and Healing records?",
    button1 = "Yes, Purge My Records",
    button2 = "No, Cancel",
    OnAccept = function()
        if HeroStatsSettings then
            HeroStatsSettings.personalDamageRecords = {}
            HeroStatsSettings.personalHealingRecords = {}
            if HeroStats_Print then
                HeroStats_Print("Your historical personal Damage and Healing records have been completely reset.")
            end
            if coreFrame and coreFrame.RefreshStats then 
                coreFrame.RefreshStats() 
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

btnResetRecords:SetScript("OnClick", function()
    StaticPopup_Show("HEROSTATS_PURGE_RECORDS_CONFIRM")
end)


-- ==========================================
-- SYSTEM ONBOARDING FRAME LOADER
-- ==========================================

local configLoader = CreateFrame("Frame")
configLoader:RegisterEvent("ADDON_LOADED")
configLoader:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HeroStats" then
        if HeroStatsSettings then
            HeroStatsSettings.activeFilterState = HeroStatsSettings.activeFilterState or 1
            if not HeroStatsSettings.maxSessionsLimit then HeroStatsSettings.maxSessionsLimit = 20 end
            if not HeroStatsSettings.groupJoinBehavior then HeroStatsSettings.groupJoinBehavior = 3 end
            if not HeroStatsSettings.personalDamageRecords then HeroStatsSettings.personalDamageRecords = {} end
            if not HeroStatsSettings.personalHealingRecords then HeroStatsSettings.personalHealingRecords = {} end
            if not HeroStatsSettings.recordNotifyMode then HeroStatsSettings.recordNotifyMode = 2 end

            slider:SetValue(HeroStatsSettings.maxSessionsLimit)
            HEROSTATS_MAX_SAVED_SESSIONS = HeroStatsSettings.maxSessionsLimit
            
            if SyncGroupRadioButtons then SyncGroupRadioButtons(HeroStatsSettings.groupJoinBehavior) end
            if HeroStats_RefreshRadioVisuals then HeroStats_RefreshRadioVisuals() end
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- end herostatsconfig.lua
