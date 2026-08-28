-- ==========================================
-- HeroStats - Global Constants & Database
-- ==========================================

-- Unified 1-Based Data-Driven Page Routing Framework
HeroStats_Pages = {
    [1]  = { name = "DAMAGE_DONE",   title = "1. Damage Done" },
    [2]  = { name = "DMG_CRIT",      title = "2. Damage Crits" },
    [3]  = { name = "DAMAGE_TAKEN",  title = "3. Damage Taken" },
    [4]  = { name = "HEALING_DONE",  title = "4. Healing Done" },
    [5]  = { name = "HEAL_CRIT",     title = "5. Healing Crits" },
    [6]  = { name = "EFFICIENCY",    title = "6. Overhealing" },
    [7]  = { name = "MANA_EFF",      title = "7. Mana Efficiency" },
    [8]  = { name = "MANA_GAINED",   title = "8. Mana Gained" },
    [9]  = { name = "DISPELS",       title = "9. Dispels Done" },
    [10] = { name = "BUFFS",         title = "10. Buffs" },
    [11] = { name = "DEATHS",        title = "11. Deaths" },
    [12] = { name = "RESURRECTS",    title = "12. Resurrects Cast" },
    [13] = { name = "PERSONAL_DMG_RECORDS",  title = "13. Personal Damage Records" },
    [14] = { name = "PERSONAL_HEAL_RECORDS", title = "14. Personal Healing Records" }
}

HeroStats_SpellCostDB = {
    -- --- PRIEST ---
    -- Flash Heal
    [2061] = { class = "PRIEST", cost = 125 }, -- Rank 1
    [9472] = { class = "PRIEST", cost = 155 }, -- Rank 2
    [9473] = { class = "PRIEST", cost = 185 }, -- Rank 3
    [9474] = { class = "PRIEST", cost = 215 }, -- Rank 4
    [10915] = { class = "PRIEST", cost = 250 }, -- Rank 5
    [10916] = { class = "PRIEST", cost = 290 }, -- Rank 6
    [10917] = { class = "PRIEST", cost = 340 }, -- Rank 7

    -- Lesser Heal
    [2050] = { class = "PRIEST", cost = 30 },  -- Rank 1
    [2052] = { class = "PRIEST", cost = 45 },  -- Rank 2
    [2053] = { class = "PRIEST", cost = 60 },  -- Rank 3

    -- Heal
    [2054] = { class = "PRIEST", cost = 90 },  -- Rank 1
    [2055] = { class = "PRIEST", cost = 115 }, -- Rank 2
    [6063] = { class = "PRIEST", cost = 155 }, -- Rank 3
    [6064] = { class = "PRIEST", cost = 205 }, -- Rank 4

    -- Greater Heal
    [2060] = { class = "PRIEST", cost = 370 }, -- Rank 1
    [10963] = { class = "PRIEST", cost = 425 }, -- Rank 2
    [10964] = { class = "PRIEST", cost = 485 }, -- Rank 3
    [10965] = { class = "PRIEST", cost = 545 }, -- Rank 4
    [25314] = { class = "PRIEST", cost = 610 }, -- Rank 5

    -- Renew
    [139] = { class = "PRIEST", cost = 30 },   -- Rank 1
    [6074] = { class = "PRIEST", cost = 65 },  -- Rank 2
    [6075] = { class = "PRIEST", cost = 105 }, -- Rank 3
    [6076] = { class = "PRIEST", cost = 140 }, -- Rank 4
    [6077] = { class = "PRIEST", cost = 175 }, -- Rank 5
    [6078] = { class = "PRIEST", cost = 215 }, -- Rank 6
    [10927] = { class = "PRIEST", cost = 250 }, -- Rank 7
    [10928] = { class = "PRIEST", cost = 295 }, -- Rank 8
    [10929] = { class = "PRIEST", cost = 340 }, -- Rank 9
    [25315] = { class = "PRIEST", cost = 385 }, -- Rank 10

    -- Prayer of Healing
    [596] = { class = "PRIEST", cost = 410 },  -- Rank 1
    [996] = { class = "PRIEST", cost = 545 },  -- Rank 2
    [10960] = { class = "PRIEST", cost = 705 }, -- Rank 3
    [10961] = { class = "PRIEST", cost = 860 }, -- Rank 4
    [25316] = { class = "PRIEST", cost = 1030 }, -- Rank 5

    -- Power Word: Shield
    [17] = { class = "PRIEST", cost = 45 },    -- Rank 1
    [592] = { class = "PRIEST", cost = 75 },   -- Rank 2
    [600] = { class = "PRIEST", cost = 105 },  -- Rank 3
    [3747] = { class = "PRIEST", cost = 135 }, -- Rank 4
    [6065] = { class = "PRIEST", cost = 175 }, -- Rank 5
    [6066] = { class = "PRIEST", cost = 215 }, -- Rank 6
    [10898] = { class = "PRIEST", cost = 250 }, -- Rank 7
    [10899] = { class = "PRIEST", cost = 295 }, -- Rank 8
    [10901] = { class = "PRIEST", cost = 340 }, -- Rank 9
    [25218] = { class = "PRIEST", cost = 390 }, -- Rank 10

    -- Desperate Prayer (Human/Dwarf Racial)
    [13908] = { class = "PRIEST", cost = 0 },  -- Rank 1
    [19277] = { class = "PRIEST", cost = 0 },  -- Rank 2
    [19281] = { class = "PRIEST", cost = 0 },  -- Rank 3
    [19282] = { class = "PRIEST", cost = 0 },  -- Rank 4
    [19283] = { class = "PRIEST", cost = 0 },  -- Rank 5
    [19284] = { class = "PRIEST", cost = 0 },  -- Rank 6
    [25437] = { class = "PRIEST", cost = 0 },  -- Rank 7

    -- --- SHAMAN ---
    -- Healing Wave
    [331] = { class = "SHAMAN", cost = 25 },   -- Rank 1
    [332] = { class = "SHAMAN", cost = 45 },   -- Rank 2
    [333] = { class = "SHAMAN", cost = 70 },   -- Rank 3
    [271] = { class = "SHAMAN", cost = 110 },  -- Rank 4
    [272] = { class = "SHAMAN", cost = 155 },  -- Rank 5
    [547] = { class = "SHAMAN", cost = 200 },  -- Rank 6
    [913] = { class = "SHAMAN", cost = 260 },  -- Rank 7
    [939] = { class = "SHAMAN", cost = 320 },  -- Rank 8
    [959] = { class = "SHAMAN", cost = 380 },  -- Rank 9
    [10395] = { class = "SHAMAN", cost = 440 }, -- Rank 10

    -- Lesser Healing Wave
    [8004] = { class = "SHAMAN", cost = 105 }, -- Rank 1
    [8008] = { class = "SHAMAN", cost = 145 }, -- Rank 2
    [8010] = { class = "SHAMAN", cost = 185 }, -- Rank 3
    [10466] = { class = "SHAMAN", cost = 235 }, -- Rank 4
    [10467] = { class = "SHAMAN", cost = 285 }, -- Rank 5
    [10468] = { class = "SHAMAN", cost = 340 }, -- Rank 6

    -- Chain Heal
    [1064] = { class = "SHAMAN", cost = 260 },  -- Rank 1
    [10622] = { class = "SHAMAN", cost = 315 }, -- Rank 2
    [10623] = { class = "SHAMAN", cost = 405 }, -- Rank 3

    -- --- DRUID ---
    -- Healing Touch
    [5185] = { class = "DRUID",  cost = 25 },   -- Rank 1
    [5186] = { class = "DRUID",  cost = 40 },   -- Rank 2
    [5187] = { class = "DRUID",  cost = 70 },   -- Rank 3
    [5188] = { class = "DRUID",  cost = 110 },  -- Rank 4
    [5189] = { class = "DRUID",  cost = 185 },  -- Rank 5
    [6778] = { class = "DRUID",  cost = 270 },  -- Rank 6
    [8903] = { class = "DRUID",  cost = 355 },  -- Rank 7
    [9812] = { class = "DRUID",  cost = 450 },  -- Rank 8
    [9813] = { class = "DRUID",  cost = 555 },  -- Rank 9
    [25297] = { class = "DRUID",  cost = 680 }, -- Rank 10
    [25299] = { class = "DRUID",  cost = 800 }, -- Rank 11

    -- Rejuvenation
    [774] = { class = "DRUID",  cost = 25 },    -- Rank 1
    [1058] = { class = "DRUID",  cost = 40 },   -- Rank 2
    [1430] = { class = "DRUID",  cost = 75 },   -- Rank 3
    [2090] = { class = "DRUID",  cost = 105 },  -- Rank 4
    [2091] = { class = "DRUID",  cost = 135 },  -- Rank 5
    [3627] = { class = "DRUID",  cost = 160 },  -- Rank 6
    [8910] = { class = "DRUID",  cost = 195 },  -- Rank 7
    [9839] = { class = "DRUID",  cost = 235 },  -- Rank 8
    [9840] = { class = "DRUID",  cost = 280 },  -- Rank 9
    [9841] = { class = "DRUID",  cost = 325 },  -- Rank 10
    [25298] = { class = "DRUID",  cost = 375 }, -- Rank 11

    -- Regrowth
    [8936] = { class = "DRUID",  cost = 120 },  -- Rank 1
    [8938] = { class = "DRUID",  cost = 165 },  -- Rank 2
    [8939] = { class = "DRUID",  cost = 210 },  -- Rank 3
    [8940] = { class = "DRUID",  cost = 265 },  -- Rank 4
    [8941] = { class = "DRUID",  cost = 320 },  -- Rank 5
    [9750] = { class = "DRUID",  cost = 380 },  -- Rank 6
    [9856] = { class = "DRUID",  cost = 450 },  -- Rank 7
    [9857] = { class = "DRUID",  cost = 525 },  -- Rank 8
    [25299] = { class = "DRUID",  cost = 615 }, -- Rank 9

    -- Tranquility
    [740] = { class = "DRUID",  cost = 410 },   -- Rank 1
    [8918] = { class = "DRUID",  cost = 535 },  -- Rank 2
    [9862] = { class = "DRUID",  cost = 680 },  -- Rank 3
    [9863] = { class = "DRUID",  cost = 845 },  -- Rank 4

    -- Swiftmend (Restoration Talent instant heal)
    [18562] = { class = "DRUID", cost = 200 }, -- Base talent spell ID cost

    -- --- PALADIN ---
    -- Flash of Light
    [19750] = { class = "PALADIN", cost = 35 }, -- Rank 1
    [19939] = { class = "PALADIN", cost = 50 }, -- Rank 2
    [19940] = { class = "PALADIN", cost = 70 }, -- Rank 3
    [19941] = { class = "PALADIN", cost = 90 }, -- Rank 4
    [19942] = { class = "PALADIN", cost = 115 }, -- Rank 5
    [19943] = { class = "PALADIN", cost = 140 }, -- Rank 6

    -- Holy Light
    [635] = { class = "PALADIN", cost = 35 },   -- Rank 1
    [639] = { class = "PALADIN", cost = 60 },   -- Rank 2
    [647] = { class = "PALADIN", cost = 90 },   -- Rank 3
    [1026] = { class = "PALADIN", cost = 140 },  -- Rank 4
    [1042] = { class = "PALADIN", cost = 190 },  -- Rank 5
    [3472] = { class = "PALADIN", cost = 275 },  -- Rank 6
    [10328] = { class = "PALADIN", cost = 365 }, -- Rank 7
    [10329] = { class = "PALADIN", cost = 465 }, -- Rank 8
    [25292] = { class = "PALADIN", cost = 580 }, -- Rank 9

    -- Holy Shock (Holy Talent damage/heal component)
    [20473] = { class = "PALADIN", cost = 225 }, -- Rank 1
    [20929] = { class = "PALADIN", cost = 275 }, -- Rank 2
    [20930] = { class = "PALADIN", cost = 325 }  -- Rank 3
}


-- Global lookup utility to retrieve the factual page record configuration
function HeroStats_GetPageRecord(pageIndex)
    if not pageIndex then pageIndex = HeroStats_CurrentActivePage or 1 end
    
    -- Fallback safety boundaries
    if pageIndex < 1 then pageIndex = 1 end
    
    return HeroStats_Pages[pageIndex] or HeroStats_Pages[1]
end

-- herostatsdb.lua