# Changelog - HeroStats v1.0.0b2

## [Changed]
* Changed Report default channel to be window warnings.

## [Fixed]
* Fixed some non-damage/healing spells appearing on meters; e.g. Conjure Water for a mage!
* Fixed hardcoded (wrong) version number being returned in /hs config - doh!
* Fixed Hunters being recorded on Death meters when feigning death!

# Changelog - HeroStats v1.0.0b1

## [Added]
* Added list of highest damage and healing abilities together with total cast count.
* Added damage (DoT) and healing (HoT) spells being shown as separate spells.
* Enforced `InCombatLockdown()` boundary shields on `/hs config` to block UI taint.

## [Changed]
* Report target channel can now be selected directly from header or tooltip bar.

# Changelog - HeroStats v0.10.1

## [Added]
- Added: Right-click drop-down menu on all player bars with a safe "Copy to chat" verification step.
- Added: "Officer Chat" integration added into the interface configuration options page, replaces "Yell".

## [Changed]
- Changed: Complete overhaul of the reporting engine � each tab now utilizes a dedicated, sandboxed function to eliminate cross-page data pollution.
- Changed: Upgraded all primary layout bars to Button frames to fully support modern patch-safe mouse clicks.

## [Fixed]
- Fixed: Resolved a critical title duplication bug that appended multiple "(Current)" strings to the header.
- Fixed: Smashed a fatal "nil value" crash on bar initialization caused by legacy click-registration APIs.
- Fixed: Repaired a data mismatch on the Mana Efficiency tab where HPM values were showing as 0.0.
- Fixed: Standardized the Mana Efficiency tooltip and chat output to always sort by highest HPM values.

# Changelog - HeroStats v0.10.0

## [Added]
- Added: New "Damage Crits" tab � check your offensive crit percentages.
- Added: New "Healing Crits" tab � check your defensive green crits.
- Added: Next-gen Tri-State filter button (None -> Healers -> Your Class) with instant bar updates.
- Added: The DoT-portion of a spell is now considered a separate damage entry.

## [Changed]
- Changed: Header text and icons refactored (Arcanite Ore for all classes, Holy Aura for healers).
- Changed: Fully opened meters for all classes � Mage and Warrior healing now tracks perfectly.
- Changed: Resurrection page upgraded to display the actual names of players brought back to life.
- Changed: Death page unlocked to capture fatalities for every single raid group member.
- Changed: Session selector cleaned up � the newest fight is now tagged as "Current session".

## [Fixed]
- Fixed: Added hard safety shields to completely block non-mana users from polluting the Mana Gained tab.
- Fixed: Blocked warriors and rogues from sneaking onto the Overhealing Efficiency leaderboards.

# Changelog - HeroStats v0.9.0

## [Added]
- Added: Numbers in front of names (1. Arne, 2. B�rge) on all bars.
- Added: Class colors on the player names inside tooltips.
- Added: Server names are now always glued onto the player names.
- Added: Extended tooltips to show a full Top 10 list instead of 8.

## [Changed]
- Changed: Renamed the entire addon from HealSmart to HeroStats.
- Changed: Overhealing page flipped to show "Efficiency" from highest to lowest.
- Changed: The fight timer now automatically saves the length of your old fights.
- Changed: Icon update (Report button is now a chat bubble, Settings is a note list).

# Changelog - HealSmart v0.8.0

## [Added]
- Added: Mana Gained page - tracking potions, infusions, runes, and Epiphany.

## [Changed]
- Changed: System refactored to a fully data-driven, 1-based text token layout.
- Changed: Tooltip values and percentages refactored.

## [Fixed]
- Fixed: Responsive `OnLeave` script to close tooltips instantly.

## v0.7.0
* **New Tracker Pages:** Added separate top lists for Dispels, Buffs, Deaths, and Resurrections.
* **Chat Report Button:** Added an icon to blast top statistics directly into /Raid or /Party chat.
* **Report Customization:** Added config options to change report lines (1-10) and target channels.
* **Group-Join Automation:** Choose to clear, keep, or ask to reset history when joining a new group.
* **Master Reset Button:** Added a simple header shortcut to wipe all night tracking data.

## v0.6.0
* **20 Fight History Logs:** The addon now automatically records and saves up to 20 individual fight sessions, tracking your stats continuously across a full dungeon or raid night.
* **Smart Auto-Naming:** New combat sessions are automatically named after the boss or area you pulled (e.g., "Onyxia (Onyxia's Lair)").
* **FIFO Memory Safety:** Added an automated rolling memory cap that smoothly deletes the oldest saved battle when you reach session number 21, preventing any performance bloat.
* **Taint-Free Session Frame:** Built a standalone popup selection window that rolls out cleanly on the right side of the main meter, keeping you 100% safe from Blizzard UI actionbar lockdown bugs.
* **Color-Coded Status Tracker:** The session selector now formats fights as "ID: Name", highlighting your active view in bright Yellow and unselected history slots in clean White.
* **Advanced Slash Options:** Upgraded the command matrix with `/hs help`, `/hs resetui` (which also centers and unlocks the layout), and a hidden version network pinger.
* **Blizzard Interface Panel:** Added full Blizzard Options menu integration. Typing `/hs config` now opens up a native slider panel allowing you to adjust your session history cap between 5 and 100 on the fly.

## v0.5.0
* **Sleek Graphical Header:** Replaced all old text buttons (like `[ALL]`) with official WoW graphic icons for a much cleaner, built-in look.
* **Smart Mini-Gear Lock:** Added a custom settings gear next to the arrows. It shines gold when locked and tints to a cool rust-orange when unlocked, letting you know instantly if the window can be moved.
* **Pro Item Filtering:** The class filter button now uses a beautiful rainbow Arcanite Bar to show all healers, and instantly swaps to your own official class spell icon (like the Priest Stamina buff cross) when viewing just your own class.
* **No-Shift Dragging:** Removed the annoying requirement to hold down `Shift` to move the meter. If the window is unlocked, you can now simply click and drag it anywhere on your screen instantly.
* **Window Close Button [X]:** Added a standard Blizzard close button in the top right corner so you can hide the meter whenever you need a clean screen.
* **Slash Commands (`/hs` & `/healsmart`):** Created a dedicated command engine. Typing `/hs`, `/hs open`, or `/healsmart` in chat now securely wakes up the main window and pops it back onto your screen if you hid it.
* **Clean Button Layout:** Rearranged the button order in the header to feel much more intuitive, grouping navigation arrows together and putting system settings nicely on the right.
* **Helpful Button Tooltips:** Added native game tooltips to every single button in the header. Hovering your mouse over any icon now instantly tells you exactly what it does (e.g., "Lock or Unlock Frame").
* **Pixel-Perfect Alignment:** Adjusted button borders, micro-textures, and the scrollbar height to ensure no icons are clipped or squished, keeping the layout perfectly symmetrical.

## v0.4.0
* **Sleek New Pages:** Added `<` and `>` arrow buttons in the top right. You can now flip through multiple stat screens like a pro without opening any extra windows.
* **Page 0 (Welcome Screen):** A clean home screen that says welcome and shows a quick guide when you don't have any active combat data yet.
* **Page 1 (Healing Done):** Your classic healing meter. Shows exactly how much raw HP you pumped out, formatted with dots for big numbers, plus your percentage share of the raid's total healing (e.g., "12.450 - 24.5%").
* **Page 2 (Heal vs Overheal):** The ultimate accuracy tracker. Shows exactly how much of your healing actually hit the target versus how much was wasted into thin air (e.g., "8.200 / 10.000 - 80%").
* **Page 3 (Mana Efficiency):** The brainiac screen. Shows exactly how much healing you get out of every single mana point spent (HPM). Perfect for seeing who is spamming uselessly and who is playing smart.
* **Smart Auto-Save:** The addon now remembers exactly where you dragged the window, how big you resized it, and what page you were looking at. No more resetting every time you log out or type /reload.
* **Fight Memory:** It now saves the numbers from your very last battle, so your bars and stats don't disappear when you disconnect or load into a new zone.
* **Text Layer Fix:** Fixed an annoying bug where the colored class bars would slide over and block the healer names when the bars got more than 75% full. Text now floats perfectly on top at all times.
* **Pure Healing Mana:** Refactored the mana tracker to ONLY count real healing spells and shields. Spamming Lightning Bolts, offensive dots, or drinking mana potions will no longer mess up your HPM score.
* **Instant Solo Testing:** The addon automatically drops the group mana limit to zero when you are solo, meaning you can test your spells and see your HPM instantly on low level characters or when fighting a random mob.
* **No More Load Glitches:** Added a clean 1-second startup delay that lets your game load in fully before refreshing the bars, removing all weird visual bugs when logging in.

## v0.3.0
* **Raid Support:** The addon now automatically shows bars for all active healers in your group or raid, using their real class colors (white for Priests, navy blue for Shamans, etc.).
* **Live Sorting:** Ranks all healers on the fly during combat. The healer with the best efficiency is always pinned right at the top of the list.
* **Smooth Scrolling & Resizing:** Added a clean scroll frame so you can scroll through large raids, plus a drag-handle in the bottom right corner to resize the window exactly how you want it.
* **Class Filter Button:** Added a rapid `[ALL]` / `[MINE]` button in the header. One click lets you toggle between seeing every healer in the raid or just the ones playing your own class.
* **Zero Black Bars Bug:** Built a fast group-roster cache system that remembers everyone's class the second they join. This completely fixes the annoying bug where healer bars would randomly turn black or gray during chaotic pulls.
* **Rock-Solid Shields:** Rewrote the combat log parser to perfectly track *Power Word: Shield* absorbs, even if a monster hits you with magic spells or you are standing far away from the casting Priest.

## v0.2.0
* **Smart combat tracking:** The addon now automatically activates when you enter combat and freezes your numbers when the fight ends.
* **Boss-friendly timer:** If you leave and re-enter combat within 5 seconds (e.g., during boss phase transitions), the measurement continues seamlessly in the same session.
* **Shield support:** Precise tracking for *Power Word: Shield*. Damage absorbed by your shields is now correctly counted as effective healing.
* **New sleek design:** The window height has been reduced to 16 pixels to take up minimal space on your screen.
* **Simplified text:** Now displays only your raw efficiency percentage (e.g., "85%"), or "--%" if you haven't healed in combat yet.

## v0.1.0
* **Initial release:** Simple status bar showing your effective healing versus your overhealing.
* **Movable window:** Hold `Shift` and drag the bar with your left mouse button to position it anywhere on your screen.

