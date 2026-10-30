# ClassicLeveling 1.4.0

A combined XP, bag-value and kill meter with equipment upgrade highlights for
**WoW Classic Era 1.15.9** (interface 11509).
The interface and messages are in English.

The compact panel is 332 x 195 pixels, widened by 48 pixels to fit per-mob XP/s.
Recent XP and session averages share two rows, with 16-point recent values and
14-point averages. Bag amounts use a 15-point font. All counters remain visible.
The expandable kill history increases the height to 400 pixels when open.
Your character's actual name and level appear directly below the title, for
example **Osobo lv. 5**. The level updates automatically when leveling up.

The XP table shows **Recent** and **Average** columns:

- **XP/min (60s)**: actual XP earned in the last 60 seconds of online time.
- **XP/hr (60m)**: actual XP earned in the last 60 minutes of online time.
- **Average**: XP/min and XP/hr averages since the last **Reset**: total XP gained
  divided by online elapsed time, multiplied by 60 or 3600.

The recent counters use moving windows and expire awards as they age out.
They use the full 60-second / 60-minute windows from the start. For example,
earning 100 XP after 10 seconds shows 100 XP/min and 100 XP/hr. The session
averages at that point show 600 XP/min and 36,000 XP/hr.
An award exactly 60 seconds old is excluded from XP/min; an award exactly
3600 seconds old is excluded from XP/hr. Values are rounded to whole XP.

**Session XP** and elapsed time remain visible below the rates. Idle time while
online counts; offline time does not. All counters use the same online clock.

Every actual increase to the player's XP bar counts, including kills, quests,
exploration and rested bonuses. Pet XP is excluded. Level-ups preserve the
remaining XP from the previous level, including the final level-up to level 60.
Duplicate events and zone changes do not award XP a second time.

Totals, elapsed time and the recent award history survive `/reload` and logout,
separately for each character, until **Reset**. Only the last hour of awards is
retained. Position, visibility and lock state are also saved. The timer begins
when entering the game and updates once per second.

## Bag value

- **Bags (vendor)** sums each carried item's native vendor sell price
  multiplied by its quantity, displayed in gold, silver and copper.
- **Bag change** is the current bag value minus its value at the
  last Reset. Positive values show more value being carried; selling, consuming,
  equipping or moving items out of the bags lowers this counter.
- The first complete scan establishes the initial baseline. Both the baseline
  and the XP counters are saved per character.

Scope: backpack and the contents of the four equipped bags, including ammo
bags. Bank contents and equipped gear are outside this total. The displayed
valuation uses vendor prices; auction prices and wallet gold are separate.
Unsellable items contribute zero.

Prices are loaded from the client. While item data is pending, `>=` marks the
known subtotal, the pending count is shown, and the bag change is `--`.
The initial/reset baseline waits for a complete scan so a delayed price is
never mistaken for newly gained value. Sorting and splitting stacks preserve
the total. Changes update within about one second.

## Equipment upgrades in bags

A **purple border** marks a carried, currently usable piece of equipment with
a higher estimated leveling score than what you are wearing in a compatible
slot. It works with the native Classic bags and the installed BetterBags
0.8.10, including its reused buttons and cached redraws. BetterBags is optional;
no other addon is required or modified. Bank items are not highlighted.

The score uses statistics useful to your class and role, plus weapon DPS when
relevant. A group role supplied by the game takes precedence; otherwise the
dominant talent tree chooses the profile. Untalented characters use a solo
leveling profile. Hybrid profiles cover damage, healing, Protection and feral
Druid; a Druid assigned Tank uses a separate bear profile. Hunter melee weapons
are stat sticks, while ranged DPS matters. Feral profiles ignore base weapon
DPS. Cosmetic items, bags, ammunition and fishing poles are excluded.

Requirements use the client's equip/use checks, including the current character
level. Rings and trinkets are compared with both slots, respecting unique and
unique-equipped category limits. Two-handed weapons include the lost offhand's
score. Offhand weapons require trained Dual Wield and cannot be added beside
a two-hander. Missing equipped-item data waits for loading instead of becoming
an empty slot. Exact links retain random suffixes and enchants.

These are **leveling estimates**, using relative weights rather than item level
or rarity. Procs, on-use effects, set bonuses, school-specific spell bonuses,
resistances, stat caps, weapon speed and ability rotations are not modeled.
Native item stats work independently of locale; supplemental flat Equip-bonus
and primary-stat tooltip parsing supports English. The source lists all weights.
Highlights refresh after equipment, bag, level, role, talent and skill changes,
and continue while the ClassicLeveling meter is hidden. Borders do not take
mouse input. Neither gear nor character talents are changed automatically.

## Mob kills and kills per minute

The **Kills/min** button in the title bar is always visible. It counts credited
kills in the last **60 seconds of online time**, including kills that award zero
XP. It uses a complete moving window from the start, with no extrapolation.
Idle online time ages kills out; offline time is excluded, as for the XP windows.

Click **[+]** to expand **Mob kills**, and **[-]** to collapse it. Drag the title
on the left to move the panel. The table shows:

- **Mob**: creature name, with the full name in its mouseover tooltip.
- **Lvl**: the observed mob level.
- **XP@lvl**: the actual XP awarded, followed by the character's level at the
  kill. For example, `75@7` means **75 XP received at character level 7**.
  Bonuses already included in the game's XP message are part of that amount.
- **Time**: seconds from the first recorded hit or attempted hit to the mob's
  death, including attacks from the character, pet and group. A first miss starts
  the timer too. Preparatory spell casts and marks do not start it.
- **XP/s**: XP received divided by that mob's kill time, displayed to one decimal
  place. It uses the full stored duration, before rounding the Time display.
  Pending XP, missing duration and zero-duration kills show **--**. Zero XP with
  a positive measured duration shows **0.0**.

Example row: `Boar | 8 | 75@7 | 12.5s | 6.0`. The mob was level 8, awarded 75 XP
to a level-7 character and took 12.5 seconds to kill, yielding 6.0 XP/s. The
tooltip also displays XP and character level separately. While the XP message
is pending, the value appears as `...@7`. Existing records with a measured kill
time also display XP/s automatically.

Times use combat-log timestamps, independently of XP-message delays, and are
tracked separately for each creature GUID. The first death event provides the
initial time; `UNIT_DIED` supplies the final endpoint when available. An evade
discards the previous pull. Inactive unfinished timers expire after five minutes.
Missing attack/death endpoints and older saved rows display **--**, rather than
an estimated duration. New measured durations are saved with each kill.

The latest 100 kills are saved per character, newest first. Existing longer
histories are trimmed to the newest 100 records when loaded. The expanded view
shows eight rows; use the mouse wheel or **Up / Down** to browse older rows.
The history limit does not limit Kills/min: all kills in the window count.
The open/closed state is saved. **Clear**, in the expanded panel, removes the mob
list and pending list entries. XP, bag values, elapsed time, Kills/min and current
combat timers continue. **Reset** clears the history, Kills/min and active timers
alongside the other session counters.

Kill credit comes from the combat log for the character, pet and group.
Localized combat-XP messages supply the XP amount and confirm XP-bearing kills
when combat-log context is unavailable. Death and XP events are correlated to
avoid counting the same kill twice. A newly killed mob briefly shows `...` while
waiting for its XP message, then zero if no award arrives. Quest and exploration
messages do not create kill rows. The main XP counters continue using the XP bar.

Mob levels are observed from the target, mouseover, nameplates and party targets.
An unavailable or skull level is shown as **?**; it is never estimated from the
creature's name. The tooltip includes the full row and the online time of the kill.

Version 1.4 adds a new equipment module. **Restart Classic Era** after installing
this update to load the complete file list. Existing XP counters, bag baseline,
kill history and other settings are preserved; only the newest 100 kills remain.

## Upgrade from ClassicXPTracker

**Restart Classic Era** after this rename so it discovers `ClassicLeveling`.
XP totals, elapsed time, recent windows, position, visibility and lock state
are imported automatically for each character on first use.

The package includes a small `ClassicXPTracker` folder marked **Legacy XP
import**. It loads saved XP data only when the character has no ClassicLeveling
profile; it creates no panel or commands. Keep it enabled for the import.
ClassicLeveling provides the single combined panel. The `/cxp` and `/classicxp`
commands remain available.

## Controls

- Drag the title to move the panel while unlocked.
- **Lock / Unlock** prevents or allows dragging.
- **Reset** clears recent windows, session averages and total XP, restarts the
  timer, clears kills and Kills/min, and sets the bag baseline to the current
  complete valuation.
- `/clvl` or `/classicleveling`: toggle visibility. Tracking continues while hidden.
- `/clvl show` / `/clvl hide`: show or hide the panel.
- `/clvl reset`: start a new count for XP, bag changes and kills.
- `/clvl lock` / `/clvl unlock`: control dragging.
- `/clvl center`: recover the panel at its default position.
- `/clvl help`: list commands.

Install the folders from the release in `Interface/AddOns` and restart Classic
Era. No third-party libraries or minimap button are required.

## Validation

The test suite executes the installed Lua files under Lua 5.1 with simulated
Classic Era XP APIs and UI frames. It checks moving-window boundaries, startup,
expiry without new XP, session averages, migration, level-ups and event order,
resets, logout/reload persistence, offline time, and the actual UI callbacks.
It also checks vendor prices, quantities, variants, sorting, pending item data,
bag baselines and the import from ClassicXPTracker. Kill checks cover localized
message parsing, levels, pet/group credit, event order, duplicate suppression,
zero-XP kills, the one-minute window, saved history, expansion and scrolling.
Header input checks also exercise pointer routing past the draggable title,
left-button release and repeated open/close clicks.
Timing checks cover multiple targets, first misses, pet/group attacks, clock
domains, event order, evades, zero-duration kills, persistence and the Clear
button's separation from the session counters and active combat timers.
Equipment checks cover useful stats versus item level, current requirements,
paired/unique slots, two-handed and dual-wield layouts, relevant weapon DPS,
role/talent changes, English flat bonuses, item-cache misses and native/BetterBags
button reuse. The player line is checked across level-up event timing and Reset.
Live-client behavior and appearance still require an in-game check.
