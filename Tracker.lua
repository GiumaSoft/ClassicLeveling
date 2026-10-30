local _, A = ...
_G.ClassicLeveling = A
A.version = "1.6.2"

local function number(value)
    return type(value) == "number" and value == value and value >= 0 and value < math.huge
end
A.IsNumber = number

local function progress()
    local xp, maximum, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    if not number(xp) or not number(maximum) or not number(level) or level < 1 then return end
    if maximum > 0 and xp > maximum then return end
    return {xp = xp, maximum = maximum, level = level}
end

function A.Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100ClassicLeveling:|r " .. message)
    end
end

function A.Init()
    if A.db then return end
    local db = type(ClassicLevelingDB) == "table" and ClassicLevelingDB or nil
    if not db then
        -- SavedVariables are loaded by addon folder name. Load the data-only
        -- old folder once to import the character's latest saved XP counters.
        if type(ClassicXPTrackerDB) ~= "table" then
            local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
            if type(load) == "function" then pcall(load, "ClassicXPTracker") end
        end
        if type(ClassicXPTrackerDB) == "table" then
            db, A.migratedLegacy = ClassicXPTrackerDB, true
        else db = {} end
    end
    db.xp = number(db.xp) and math.floor(db.xp) or 0
    db.seconds = number(db.seconds) and db.seconds or 0
    db.combatSeconds = number(db.combatSeconds) and math.min(db.combatSeconds, db.seconds) or 0
    db.locked = db.locked == true
    db.hidden = db.hidden == true
    db.bagBaseline = number(db.bagBaseline) and math.floor(db.bagBaseline) or nil
    -- Recent awards use the same online clock as the saved session averages.
    -- Existing 1.0 totals remain intact; no recent awards are invented for them.
    local history = {}
    if type(db.history) == "table" then
        for _, award in ipairs(db.history) do
            if type(award) == "table" and number(award.at) and number(award.xp) and
                award.xp > 0 and award.xp % 1 == 0 and award.at > db.seconds - 3600 and
                award.at <= db.seconds then
                history[#history + 1] = {at = award.at, xp = award.xp}
            end
        end
        table.sort(history, function(a, b) return a.at < b.at end)
    end
    db.history = history
    if type(db.position) ~= "table" or type(db.position.x) ~= "number" or
        type(db.position.y) ~= "number" or not number(math.abs(db.position.x)) or
        not number(math.abs(db.position.y)) then db.position = nil end
    ClassicLevelingDB, A.db = db, db
end

function A.Start()
    if A.startedAt then return end
    A.last = progress()
    A.expectedLevel = nil
    A.startedAt = GetTime()
    local combat = type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player")
    if not (type(issecretvalue) == "function" and issecretvalue(combat)) then A.SetCombat(combat == true) end
end

-- XP is read from the player's bar, so kills, quests, exploration and rested
-- bonuses use the actual amount awarded, without parsing localized chat.
function A.Sample()
    if not A.startedAt then return end
    local current = progress()
    if not current then return end
    local previous = A.last
    if not previous then A.last = current; return end

    local level = math.max(previous.level, current.level)
    if current.maximum == previous.maximum then
        -- PLAYER_LEVEL_UP can arrive before UnitXP/UnitXPMax have updated.
        -- Wait for the new bar instead of consuming the old XP a second time.
        if level > previous.level or (A.expectedLevel or 0) > previous.level then return end
        if current.xp < previous.xp then return end
    elseif previous.maximum > 0 then
        -- The new bar can arrive before UnitLevel reflects the new level.
        level = math.max(level, previous.level + 1)
    end

    local gained = current.xp - previous.xp
    if level > previous.level then gained = gained + previous.maximum end
    if gained < 0 then return end
    A.db.xp = A.db.xp + gained
    if gained > 0 then
        local history, now = A.db.history, A.Elapsed()
        local last = history[#history]
        if last and last.at == now then last.xp = last.xp + gained
        else history[#history + 1] = {at = now, xp = gained} end
    end
    current.level = level
    A.last = current
end

function A.Elapsed()
    return A.db.seconds + (A.startedAt and math.max(0, GetTime() - A.startedAt) or 0)
end

function A.CombatElapsed()
    local seconds = A.db.combatSeconds + (A.combatStartedAt and math.max(0, GetTime() - A.combatStartedAt) or 0)
    return math.min(seconds, A.Elapsed())
end

function A.SetCombat(active)
    if not A.startedAt then return end
    if active then
        if not A.combatStartedAt then A.combatStartedAt = GetTime() end
    elseif A.combatStartedAt then
        A.db.combatSeconds = A.CombatElapsed()
        A.combatStartedAt = nil
    end
end

function A.Stats()
    local seconds = A.Elapsed()
    local perMinute = seconds > 0 and A.db.xp * 60 / seconds or 0
    local recentMinute, recentHour = A.RollingXP()
    return A.db.xp, seconds, perMinute, perMinute * 60, recentMinute, recentHour
end

function A.RollingXP()
    local now, history = A.Elapsed(), A.db.history
    local minute, hour, first = 0, 0, 1
    for i = #history, 1, -1 do
        local award = history[i]
        if award.at <= now - 3600 then first = i + 1; break end
        hour = hour + award.xp
        if award.at > now - 60 then minute = minute + award.xp end
    end
    -- Only the last hour is retained, in a dense array that can be saved.
    if first > 1 then
        local count = #history
        for i = first, count do history[i - first + 1] = history[i] end
        for i = count - first + 2, count do history[i] = nil end
    end
    return minute, hour
end

function A.Reset()
    A.db.xp, A.db.seconds, A.db.combatSeconds = 0, 0, 0
    A.db.history = {}
    A.last, A.expectedLevel = progress(), nil
    if A.startedAt then A.startedAt = GetTime() end
    if A.combatStartedAt then A.combatStartedAt = GetTime() end
    A.Bags.Reset()
    A.Mobs.Reset()
    A.UI.Update(true)
end

function A.Save()
    if not A.startedAt then return end
    A.Sample()
    A.RollingXP()
    A.db.combatSeconds = A.CombatElapsed()
    A.db.seconds = A.Elapsed()
    A.startedAt, A.combatStartedAt = nil, nil
end

function A.SetLocked(locked)
    A.db.locked = locked == true
    if A.UI.panel then A.UI.panel:StopMovingOrSizing() end
    A.UI.Update()
end

function A.SetVisible(visible)
    A.db.hidden = not visible
    A.UI.Update()
end

function A.Command(text)
    local command = (text or ""):match("^%s*(.-)%s*$"):lower()
    if command == "" then A.SetVisible(A.db.hidden)
    elseif command == "show" then A.SetVisible(true)
    elseif command == "hide" then A.SetVisible(false)
    elseif command == "reset" then A.Reset(); A.Print("XP, kills and session timers reset.")
    elseif command == "lock" then A.SetLocked(true)
    elseif command == "unlock" then A.SetLocked(false)
    elseif command == "center" then
        A.db.position = nil
        A.SetVisible(true)
        A.UI.Place()
    else
        A.Print("/clvl: show/hide. /clvl reset: reset XP, kill history and session timers.")
        A.Print("/clvl lock | unlock | center. /cxp remains available.")
    end
end
