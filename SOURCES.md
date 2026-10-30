# Sources and compatibility

Original standalone addon code. No external libraries, artwork or other addon
code are bundled. The panel uses native game fonts, textures and tooltips.

Target checked locally: **WoW Classic Era 1.15.9.70576**, interface **11509**.
Other client flavors are not part of this installation.

XP reads mirror Blizzard's native experience bar: `UnitXP("player")`,
`UnitXPMax("player")` and `UnitLevel("player")`. The previous level's maximum
is cached before the bar rolls over. `GetTime()` measures online time only;
logout saves accumulated seconds, and login starts a new clock segment.
Each XP award is timestamped on that online clock. The recent counters sum
awards with `now - 60 < time <= now` and `now - 3600 < time <= now`.
They use fixed-length moving windows, with no startup extrapolation. Session
averages retain the original total-XP / elapsed-time calculation. The saved
award history contains at most the last hour; offline time advances neither
the windows nor the session averages.
Only local statistics and UI preferences are saved; no messages are sent.

Mob kills use `COMBAT_LOG_EVENT_UNFILTERED` with
`C_CombatLog.GetCurrentEventInfo` (legacy fallback when absent), correlating
`PARTY_KILL` and `UNIT_DIED` NPC GUIDs with `CHAT_MSG_COMBAT_XP_GAIN`.
The parser derives patterns from the client's `COMBATLOG_XPGAIN_*` strings,
including positional printf fields, and excludes unnamed/quest templates.
The named XP amount is used once; bonus fields are not added a second time.
Chat line IDs and NPC GUIDs suppress duplicates. A short correlation window
allows either event order; credited kills with no XP message settle to zero.

`UnitGUID`, `UnitName`, `UnitLevel` and `UnitIsDead` observe available units via
target/mouseover changes, party targets and nameplate add/remove events. Missing
or skull mob levels stay unknown. Character level is captured with the kill;
when XP precedes its combat event, the earlier observed character level is kept.
The latest 100 kills are saved per character. A separate last-60-second list
counts all credited kills regardless of that display limit, on the online clock.
The expanded UI reuses eight rows and supports mouse-wheel and button paging.
Its columns are `Mob`, `Lvl`, `XP@lvl`, `Time`, `XP/s` and `Respawn avg`: `75@7` combines XP and the
character's level. Saved kill records retain those fields separately, so
existing history keeps the original data.
Per-mob XP/s is derived at display time from `xp / killTime`, using the full
stored precision and displaying one decimal. Missing XP/time or a zero duration
produces `--`; zero XP with positive time produces `0.0`. No duplicate derived
value is persisted. The collapsed panel stays 332 pixels wide and expands to 408 pixels for the
additional column, with unchanged heights and row font sizes. The toggle keeps
its horizontal position while opening and closing the wider list.

Kill time uses the first allied `SWING_DAMAGE`, `RANGE_DAMAGE`, `SPELL_DAMAGE`,
`SPELL_PERIODIC_DAMAGE` or corresponding missed-attack timestamp for each NPC
GUID. The affiliation check includes the character, pet and group, matching
kill credit. Later attacks preserve the earliest timestamp. `PARTY_KILL` gives
a provisional endpoint and the first `UNIT_DIED` takes precedence. Damage events
delivered after the death notification can still complete the timing when their
combat timestamp precedes death. Both endpoints use the combat-log clock;
neither XP delivery nor the local update interval determines the duration.
Evade misses clear the pull timer. Inactive fights expire after 300 seconds.
Completed `killTime` values are saved per record; active combat clocks are
runtime-only, and unknown durations stay nil. The Clear action removes only
the displayed history and pending history packets, preserving active timers
and the separate rolling Kills/min window. Recent removed records stay marked
as suppressed during the correlation window for late GUID-based events.

Header input keeps the mouse-enabled title drag frame separate from the toggle
rectangle. The toggle uses a higher frame level than the drag frame. Styled
buttons explicitly enable mouse input and register `LeftButtonUp`; tests cover
the input regions and pointer event delivery as well as the click callbacks.

Bag values read `C_Container.GetContainerNumSlots`, `GetContainerItemInfo` and,
for incomplete slot data, `GetContainerItemID`, only for container IDs 0 to 4.
`C_Item.GetItemInfo` is queried with the exact item link and its eleventh return
value (`sellPrice`) is multiplied by `stackCount`. `hasNoValue` marks known
unsellable items. `C_Item.RequestLoadItemDataByID`, `GET_ITEM_INFO_RECEIVED`
and `ITEM_DATA_LOAD_RESULT` resolve cold data; requests are throttled to once
per item per five seconds. `BAG_UPDATE_DELAYED` schedules coalesced rescans.
The bag baseline is committed only after every carried item has a known price.

The player subtitle reads `UnitName("player")` and `UnitLevel("player")`;
`PLAYER_LEVEL_UP` supplies the new level while the unit API is settling.
It occupies the left header column and preserves the meter's existing sizes.

The independent `Upgrades.lua` module compares equipment from exact item links
against `GetInventoryItemLink` slots 1-19. `C_PlayerInfo.CanUseItem`,
`C_Item.IsEquippableItem` and required level gate eligibility. `GetItemStats`
(namespaced or global) supplies stats; a hidden native GameTooltip supplements
weapon DPS, armor and known English flat bonuses. Native DPS/armor format
strings are escaped as Lua patterns; replacement functions preserve numeric
capture percent signs. No visible tooltip is replaced.

Relative leveling weights are original heuristics, selected by class and the
game's assigned group role, falling back to the dominant talent tree. Current
five-value, older three-value and namespaced talent APIs are handled separately.
Feral and bear profiles exclude weapon DPS; Hunter separates ranged DPS from
melee stat sticks. Scores include an offhand lost to a two-handed replacement,
with trained Dual Wield required for offhand weapons. `GetItemUniqueness` returns
category and maximum; `GetItemUniquenessByID` separately returns unique status
and category metadata. Restrictions are counted against the resulting equipped
set, allowing a category member to replace another without adding a duplicate.
Uncached data is retried without turning an unknown equipped score into zero.
Effect/proc/set simulation and raid stat caps are outside this heuristic.

Secure post-hooks observe `ContainerFrame_Update` and the installed BetterBags
0.8.10 `ItemFrame.itemProto.FinishItemDraw`/`ResetVisuals` methods. FinishItemDraw
also runs on its cached fast path. Only bag IDs 0-4 receive highlights; native
buttons use their actual GetID slot, and BetterBags uses current displayed item
data. Each highlight is a separate mouse-disabled child frame with four purple
edges; existing quality textures, item scripts and click handling are preserved.
Item/score caches reset on relevant inventory, data-load, level, skill, role
and talent changes. Idle ticks perform no rescans when nothing is dirty.
No BetterBags source files are changed or bundled.

`ClassicLevelingDB` is saved per character. On first use, `C_AddOns.LoadAddOn`
loads the data-only `ClassicXPTracker` helper, declared LoadOnDemand, to read
that character's old `ClassicXPTrackerDB`. The new profile takes precedence
on subsequent logins. This avoids depending on a manual copy of SavedVariables
files while the old client session may still be running.

Blizzard UI source mirror, `Gethe/wow-ui-source`, `classic_era`, checked
2026-10-30, pinned revision `4192ac60067fc55566182291bc67c85dd9b6794d`:

- [Native XP reads and events](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_ActionBar/Shared/ExpBar.lua)
- [Classic XP bar overrides](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_ActionBar/Classic/ExpBarOverrides.lua)
- [Player XP/level event signatures](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Container APIs, item information and bag events](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua)
- [Item prices, data loading and cache events](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)
- [Addon loading API](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua)
- [Combat log API and events](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogDocumentation.lua)
- [Combat XP chat event payload](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)
- [Classic combat log event field usage](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_CombatLog/Classic/Blizzard_CombatLog.lua)
- [Button click registration](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleButtonAPIDocumentation.lua)
- [Frame input and stacking APIs](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua)
- [Native item usability](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerInfoDocumentation.lua)
- [Classic bag button/slot updates](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_UIPanels_Game/Classic/ContainerFrame_Shared.lua)
- [Modern talent information and update event](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua)
- [Equipment/character-point events](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/PaperDollInfoDocumentation.lua)
- [Skill update event](https://github.com/Gethe/wow-ui-source/blob/4192ac60067fc55566182291bc67c85dd9b6794d/Interface/AddOns/Blizzard_APIDocumentationGenerated/SkillInfoDocumentation.lua)

Development files outside the addon folder:

- `tools/classicleveling/test_addon.py`: Lua 5.1 behavioral checks.
- `tools/classicleveling/wow_mock.lua`: explicit XP, bag, cache and frame fixtures.
- `tools/classicxptracker/test_addon.py`: compatibility test entrypoint.
- `tmp/classicleveling/api/sources.json`: reference URLs and SHA-256 hashes.
- `tmp/classicleveling/installation.json`: installed and archived file hashes.

Tests simulate the client. They do not establish live-client verification.


Session Combat uses PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED and initializes
from the readable UnitAffectingCombat("player") state. It does not require combat
log access. combatSeconds is saved alongside total seconds; both clocks exclude
offline time, and active combat is restarted at Reset. Older profiles retain
Total with Combat starting at zero. The displayed bag counter is now only
Bags (sell value); the legacy bag-baseline field remains readable for profile
compatibility but has no visible change counter.


Respawn means use the exact readable NPC name as their only grouping key.
Credited kill times enter a bounded FIFO; the first newly observed living GUID
with that name consumes one wait, including mobs at other levels. Public dead to
alive transitions also qualify. Known living GUIDs suppress repeated observations;
up to 1000 identities are retained per area. A five-second public-sighting cache
handles XP-backed kills whose rows settle after their first reappearance.
Samples publish every five seconds into saved total/count records, capped at
100 names. Travel/login clears unfinished waits and observed identities. Clear
preserves learned means; Reset clears means as well. Protected identities are
never inspected or reconstructed. The observations estimate availability, not a
server-provided spawn time.

Both displayed XP/min columns have a separate five-second refresh cadence.
Actual XP awards and 60-second-window calculations stay immediate; Reset forces
the visible counters to zero immediately. Delayed frames retain the cadence's
phase. Shared client behavior passes 15 differential scenarios.

Respawn averages are displayed in rounded whole seconds, e.g. 135s, in both the column and tooltip.
