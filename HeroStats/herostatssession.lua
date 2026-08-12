-- ==========================================
-- HeroStats - Session Selection Window Frame (v0.6.0)
-- ==========================================

local sessionFrame = CreateFrame("Frame", "HeroStatsSessionFrame", UIParent)
sessionFrame:SetSize(220, 200) -- Expanded width to 220px to hold full zone names cleanly
sessionFrame:SetClampedToScreen(true)
sessionFrame:Hide() 

sessionFrame:SetFrameStrata("DIALOG")
sessionFrame:SetFrameLevel(100)
-- FIXED v1.0.0b2: Registers your session list frame globally into Blizzard's Escape-key window table
tinsert(UISpecialFrames, "HeroStatsSessionFrame")

local sfBg = sessionFrame:CreateTexture(nil, "BACKGROUND")
sfBg:SetAllPoints(sessionFrame)
sfBg:SetColorTexture(0, 0, 0, 0.85) 

local sfHeader = CreateFrame("Frame", nil, sessionFrame)
sfHeader:SetHeight(20)
sfHeader:SetPoint("TOPLEFT", sessionFrame, "TOPLEFT", 0, 0)
sfHeader:SetPoint("TOPRIGHT", sessionFrame, "TOPRIGHT", 0, 0)

local sfHeaderBg = sfHeader:CreateTexture(nil, "BACKGROUND")
sfHeaderBg:SetAllPoints(sfHeader)
sfHeaderBg:SetColorTexture(0.05, 0.1, 0.2, 1.0)

local sfHeaderText = sfHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sfHeaderText:SetPoint("LEFT", sfHeader, "LEFT", 6, 0)
sfHeaderText:SetText("Select Session")
sfHeaderText:SetTextColor(1, 1, 1, 1)

local sfClose = CreateFrame("Button", nil, sfHeader, "UIPanelCloseButton")
sfClose:SetSize(16, 16)
sfClose:SetPoint("RIGHT", sfHeader, "RIGHT", -2, 0)
sfClose:SetScript("OnClick", function() sessionFrame:Hide() end)

local sfScrollFrame = CreateFrame("ScrollFrame", "HeroStatsSFScrollFrame", sessionFrame, "UIPanelScrollFrameTemplate")
sfScrollFrame:SetPoint("TOPLEFT", sfHeader, "BOTTOMLEFT", 0, -2)
sfScrollFrame:SetPoint("BOTTOMRIGHT", sessionFrame, "BOTTOMRIGHT", -20, 4)

if HeroStatsSFScrollFrameScrollBar then
    local sfsb = HeroStatsSFScrollFrameScrollBar
    sfsb:ClearAllPoints()
    sfsb:SetPoint("TOPRIGHT", sessionFrame, "TOPRIGHT", -2, -24)
    sfsb:SetPoint("BOTTOMRIGHT", sessionFrame, "BOTTOMRIGHT", -2, 4)
    if HeroStatsSFScrollFrameScrollBarScrollUpButton then HeroStatsSFScrollFrameScrollBarScrollUpButton:Hide() end
    if HeroStatsSFScrollFrameScrollBarScrollDownButton then HeroStatsSFScrollFrameScrollBarScrollDownButton:Hide() end
end

local sfScrollChild = CreateFrame("Frame", nil, sfScrollFrame)
sfScrollFrame:SetScrollChild(sfScrollChild)
sfScrollChild:SetWidth(195) -- Expanded to fit the new 220px frame layout

local sessionButtonsCache = {}

local function CreateSessionRow(index)
    local button = CreateFrame("Button", nil, sfScrollChild)
    button:SetSize(195, 18)
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightTexture("Interface\\Buttons\\UI-ListboxHighlight")
    
    if index == 1 then
        button:SetPoint("TOPLEFT", sfScrollChild, "TOPLEFT", 2, -2)
    else
        button:SetPoint("TOPLEFT", sessionButtonsCache[index - 1], "BOTTOMLEFT", 0, -2)
    end
    
    local txt = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", button, "LEFT", 4, 0)
    txt:SetWidth(185)
    txt:SetJustifyH("LEFT")
    button.titleText = txt

    sessionButtonsCache[index] = button
    return button
end

function HeroStats_UpdateSessionListWindow()
    for _, btn in ipairs(sessionButtonsCache) do btn:Hide() end
    if not HeroStatsSettings then return end

    local rowIdx = 1

    -- Row 1: Overall Total selection slot
    local overallBtn = sessionButtonsCache[rowIdx] or CreateSessionRow(rowIdx)
    overallBtn.titleText:SetText("[Overall Total]")
    
    if HeroStatsSettings.selectedViewSessionID == -1 then
        overallBtn.titleText:SetTextColor(1.0, 0.82, 0.0, 1.0)
    else
        overallBtn.titleText:SetTextColor(1.0, 1.0, 1.0, 1.0)
    end
    
    overallBtn:SetScript("OnClick", function()
        HeroStatsSettings.selectedViewSessionID = -1 
        if HeroStats_RefreshCurrentPage then HeroStats_RefreshCurrentPage() end
        sessionFrame:Hide()
    end)
    overallBtn:Show()
    rowIdx = rowIdx + 1

    -- Rows 2..X: Historic sessions loop
    if HeroStatsSettings.sessions then
        for i = #HeroStatsSettings.sessions, 1, -1 do
            local sessionData = HeroStatsSettings.sessions[i]
            if sessionData then
                local btn = sessionButtonsCache[rowIdx] or CreateSessionRow(rowIdx)
                
                -- FIXED v0.10.0: Evaluate the live status flag before writing the label text
                local isCurrentLiveSlot = (i == HeroStatsSettings.activeSessionIndex)
                local displayName = sessionData.name or "Unknown"
                
                if isCurrentLiveSlot then
                    displayName = "Current session"
                end
                
                -- Outputs the precise uniform layout: "1: Current session"
                btn.titleText:SetText(sessionData.id .. ": " .. displayName)
                
                local isThisSelected = false
                
                if HeroStatsSettings.selectedViewSessionID == 0 and isCurrentLiveSlot then
                    isThisSelected = true
                elseif HeroStatsSettings.selectedViewSessionID == sessionData.id then
                    isThisSelected = true
                end
                
                if isThisSelected then
                    btn.titleText:SetTextColor(1.0, 0.82, 0.0, 1.0)
                else
                    btn.titleText:SetTextColor(1.0, 1.0, 1.0, 1.0)
                end
                
                btn:SetScript("OnClick", function()
                    if i == HeroStatsSettings.activeSessionIndex then
                        HeroStatsSettings.selectedViewSessionID = 0
                    else
                        HeroStatsSettings.selectedViewSessionID = sessionData.id
                    end
                    if HeroStats_RefreshCurrentPage then HeroStats_RefreshCurrentPage() end
                    sessionFrame:Hide()
                end)
                btn:Show()
                rowIdx = rowIdx + 1
            end
        end
    end

    sfScrollChild:SetHeight(rowIdx * 20)
end

function HeroStats_ToggleSessionWindow()
    if sessionFrame:IsShown() then
        sessionFrame:Hide()
    else
        local mainContainer = _G["HeroStatsContainer"]
        if mainContainer then
            sessionFrame:ClearAllPoints()
            sessionFrame:SetPoint("TOPLEFT", mainContainer, "TOPRIGHT", 4, 0)
            HeroStats_UpdateSessionListWindow()
            sessionFrame:Show()
        end
    end
end

-- end herostatssession.lua
