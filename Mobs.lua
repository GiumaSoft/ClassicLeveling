local _, A = ...
local M = {units = {}, plates = {}, deaths = {}, byGUID = {}, pending = {}, lines = {}, fights = {}, revision = 0}
A.Mobs = M
M.LIMIT = 100
M.RESPAWN_INTERVAL = 5
M.respawnPending, M.respawnSeen, M.respawnOrder, M.respawnBatch, M.respawnStats = {}, {}, {}, {}, {}
M.respawnSightings = {}

local function safe(value)
    return not (type(issecretvalue) == "function" and issecretvalue(value))
end
local function text(value)
    return safe(value) and type(value) == "string" and value ~= "" and value or nil
end
local function number(value)
    return safe(value) and A.IsNumber(value) and value or nil
end
local function level(value)
    value = number(value)
    return value and value >= 1 and value <= 255 and value % 1 == 0 and value or nil
end
local function npc(guid)
    return text(guid) and (guid:match("^Creature%-") or guid:match("^Vehicle%-"))
end
local function affiliated(guid, flags)
    flags = number(flags)
    if flags and flags % 8 ~= 0 then return true end
    return text(guid) and type(UnitGUID) == "function" and
        (guid == UnitGUID("player") or guid == UnitGUID("pet"))
end
local function playerLevel()
    return level(UnitLevel("player"))
end
local function literal(value)
    return (value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

-- Build patterns from the client's localized printf templates. Positional
-- placeholders and numbers in NPC names must not be mistaken for the XP gain.
local function pattern(template)
    local parts, fields, nextField, i = {"^"}, {}, 1, 1
    while i <= #template do
        local tail = template:sub(i)
        local token, index, kind = tail:match("^(%%(%d+)%$([sd]))")
        if not token then
            token, kind = tail:match("^(%%([sd]))")
            if token then index = nextField; nextField = nextField + 1 end
        end
        if token then
            fields[#fields + 1] = {index = tonumber(index), kind = kind}
            parts[#parts + 1] = kind == "s" and "(.-)" or "([%d%.,%s]+)"
            i = i + #token
        elseif tail:sub(1, 2) == "%%" then
            parts[#parts + 1] = "%%"; i = i + 2
        else parts[#parts + 1] = literal(template:sub(i, i)); i = i + 1 end
    end
    local nameField, xpField
    for n, field in ipairs(fields) do
        if field.index == 1 and field.kind == "s" then nameField = n end
        if field.index == 2 and field.kind == "d" then xpField = n end
    end
    if nameField and xpField then
        return {value = table.concat(parts) .. "$", name = nameField, xp = xpField}
    end
end

function M.ResetRespawnObservations()
    -- Travel and reload must not become samples of waiting for a respawn.
    M.respawnPending, M.respawnSeen, M.respawnOrder = {}, {}, {}
    M.respawnSightings = {}
    M.respawnUpdatedAt = GetTime()
    M.respawnStartedAt = M.respawnUpdatedAt
end

local function rememberAppearance(guid, dead)
    local previous = M.respawnSeen[guid]
    if previous == nil then
        M.respawnOrder[#M.respawnOrder + 1] = guid
        if #M.respawnOrder > 1000 then M.respawnSeen[table.remove(M.respawnOrder, 1)] = nil end
    end
    M.respawnSeen[guid] = dead
    return previous
end

local function sampleRespawn(name, seconds)
    local batch = M.respawnBatch[name] or {total = 0, count = 0}
    local total = batch.total + seconds
    if number(total) then
        batch.total, batch.count = total, batch.count + 1
        M.respawnBatch[name] = batch
    end
end

local function observeRespawn(guid, name, dead)
    local previous = rememberAppearance(guid, dead)
    if dead or previous == false then return end
    local now = GetTime()
    for i, kill in ipairs(M.respawnPending) do
        if kill.name == name and now >= kill.when then
            table.remove(M.respawnPending, i)
            sampleRespawn(name, now - kill.when)
            return
        end
    end
    M.respawnSightings[#M.respawnSightings + 1] = {name = name, when = now}
    if #M.respawnSightings > 1000 then table.remove(M.respawnSightings, 1) end
end

local function awaitRespawn(node)
    -- Match kills and new living sightings FIFO by name, regardless of level.
    if node.when < (M.respawnStartedAt or 0) then return end
    if node.guid then rememberAppearance(node.guid, M.respawnSeen[node.guid] or false) end
    -- XP-backed rows settle after a short correlation delay. Keep public
    -- sightings that happened after the XP notice but before that row existed.
    if GetTime() > node.when then
        for i, sighting in ipairs(M.respawnSightings) do
            if sighting.name == node.name and sighting.when > node.when then
                table.remove(M.respawnSightings, i)
                sampleRespawn(node.name, sighting.when - node.when)
                return
            end
        end
    end
    M.respawnPending[#M.respawnPending + 1] = {name = node.name, when = node.when}
    if #M.respawnPending > M.LIMIT then table.remove(M.respawnPending, 1) end
end

function M.UpdateRespawns(flush)
    local now = GetTime()
    if not flush and now - (M.respawnUpdatedAt or now) < M.RESPAWN_INTERVAL then return end
    local elapsed = now - (M.respawnUpdatedAt or now)
    M.respawnUpdatedAt = flush and now or (now - elapsed % M.RESPAWN_INTERVAL)
    for name, batch in pairs(M.respawnBatch) do
        local stat = M.respawnStats[name] or {name = name, total = 0, count = 0}
        local total = stat.total + batch.total
        if number(total) then
            stat.total, stat.count = total, stat.count + batch.count
            for i, existing in ipairs(A.db.respawns) do
                if existing == stat then table.remove(A.db.respawns, i); break end
            end
            table.insert(A.db.respawns, 1, stat)
            M.respawnStats[name] = stat
            if #A.db.respawns > M.LIMIT then
                local removed = table.remove(A.db.respawns)
                M.respawnStats[removed.name] = nil
            end
            M.revision = M.revision + 1
        end
    end
    M.respawnBatch = {}
end

function M.RespawnAverage(name)
    local stat = M.respawnStats[name]
    if stat then return stat.total / stat.count, stat.count end
    return nil, 0
end

function M.Init()
    local db, kills, times = A.db, {}, {}
    local respawns = {}
    M.respawnStats, M.respawnBatch = {}, {}
    if type(db.respawns) == "table" then
        for _, stat in ipairs(db.respawns) do
            if type(stat) == "table" and text(stat.name) and number(stat.total) and
                number(stat.count) and stat.count >= 1 and stat.count % 1 == 0 and not M.respawnStats[stat.name] then
                local saved = {name = stat.name, total = stat.total, count = stat.count}
                respawns[#respawns + 1], M.respawnStats[stat.name] = saved, saved
                if #respawns == M.LIMIT then break end
            end
        end
    end
    db.respawns = respawns
    M.ResetRespawnObservations()
    if type(db.kills) == "table" then
        for _, kill in ipairs(db.kills) do
            if type(kill) == "table" and text(kill.name) and level(kill.playerLevel) and
                number(kill.at) and kill.at <= db.seconds and number(kill.xp) and kill.xp % 1 == 0 then
                kills[#kills + 1] = {name = kill.name, mobLevel = level(kill.mobLevel),
                    playerLevel = kill.playerLevel, xp = kill.xp, at = kill.at, killTime = number(kill.killTime)}
                if #kills == M.LIMIT then break end
            end
        end
    end
    if type(db.killTimes) == "table" then
        for _, at in ipairs(db.killTimes) do
            if number(at) and at <= db.seconds and at > db.seconds - 60 then times[#times + 1] = at end
        end
        table.sort(times)
    end
    db.kills, db.killTimes, db.mobExpanded = kills, times, db.mobExpanded == true
    M.patterns = {}
    for key, template in pairs(_G) do
        if type(key) == "string" and key:match("^COMBATLOG_XPGAIN_") and
            not key:find("UNNAMED", 1, true) and not key:find("QUEST", 1, true) and text(template) then
            local compiled = pattern(template)
            if compiled then M.patterns[#M.patterns + 1] = compiled end
        end
    end
end

function M.Parse(message)
    message = text(message)
    if not message then return end
    message = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for _, compiled in ipairs(M.patterns) do
        local captures = {message:match(compiled.value)}
        if captures[compiled.name] and captures[compiled.xp] then
            local name = captures[compiled.name]:match("^%s*(.-)%s*$")
            local xp = tonumber((captures[compiled.xp]:gsub("%D", "")))
            if name ~= "" and number(xp) then return name, xp end
        end
    end
end

function M.Observe(unit)
    if type(UnitGUID) ~= "function" or type(UnitName) ~= "function" then return end
    local guid = UnitGUID(unit)
    if not npc(guid) then return end
    local name = text(UnitName(unit))
    if not name then return end
    local old = M.units[guid]
    local dead = type(UnitIsDead) == "function" and UnitIsDead(unit)
    M.units[guid] = {name = name, mobLevel = level(UnitLevel(unit)) or (old and old.mobLevel),
        dead = safe(dead) and dead == true, seen = GetTime()}
    if type(UnitIsDead) == "function" and safe(dead) and type(dead) == "boolean" then
        observeRespawn(guid, name, dead)
    end
end

function M.Scan()
    M.Observe("target"); M.Observe("mouseover")
    for i = 1, 4 do M.Observe("party" .. i .. "target") end
    for unit in pairs(M.plates) do M.Observe(unit) end
end

local function record(node)
    if node.suppressed then return end
    if node.record then return node.record end
    local kill = {name = node.name, mobLevel = node.mobLevel, playerLevel = node.playerLevel,
        xp = nil, at = node.onlineAt, killTime = node.killTime}
    node.record = kill
    local index = 1
    while A.db.kills[index] and A.db.kills[index].at > kill.at do index = index + 1 end
    table.insert(A.db.kills, index, kill)
    if #A.db.kills > M.LIMIT then table.remove(A.db.kills) end
    A.db.killTimes[#A.db.killTimes + 1] = node.onlineAt
    awaitRespawn(node)
    M.revision = M.revision + 1
    return kill
end

local function apply(node, packet)
    if node.suppressed then node.claimed = true; return end
    local kill = record(node)
    kill.xp = packet.xp
    kill.mobLevel = node.mobLevel
    kill.playerLevel = node.playerLevel and packet.playerLevel and math.min(node.playerLevel, packet.playerLevel)
        or node.playerLevel or packet.playerLevel
    node.claimed = true
    M.revision = M.revision + 1
end

local attacks = {SWING_DAMAGE = true, SWING_MISSED = true, RANGE_DAMAGE = true, RANGE_MISSED = true,
    SPELL_DAMAGE = true, SPELL_MISSED = true, SPELL_PERIODIC_DAMAGE = true, SPELL_PERIODIC_MISSED = true}

local function updateTiming(node)
    if node.attackStart and node.deathStamp and node.deathStamp >= node.attackStart then
        node.killTime = node.deathStamp - node.attackStart
        if node.record and node.record.killTime ~= node.killTime then
            node.record.killTime = node.killTime; M.revision = M.revision + 1
        end
    end
end

local function attack(guid, stamp, now)
    local node = M.byGUID[guid]
    if node and node.deathStamp then
        -- A killing blow can be delivered after its death notification.
        if stamp <= node.deathStamp then
            node.attackStart = math.min(node.attackStart or stamp, stamp)
            updateTiming(node)
        end
        return
    end
    local fight = M.fights[guid]
    if not fight then M.fights[guid] = {started = stamp, seen = now}
    else fight.started = math.min(fight.started, stamp); fight.seen = now end
end

local function find(packet)
    if packet.guid then
        local node = M.byGUID[packet.guid]
        if node and not node.claimed then return node end
        return
    end
    -- Prefer a credited kill over unrelated nearby deaths with the same name.
    for _, node in ipairs(M.deaths) do
        if node.record and not node.suppressed and not node.claimed and not node.noXP and node.name == packet.name and math.abs(node.when - packet.when) <= 5 then return node end
    end
    local candidate
    for _, node in ipairs(M.deaths) do
        if not node.suppressed and not node.claimed and not node.noXP and node.name == packet.name and math.abs(node.when - packet.when) <= 5 then
            if candidate then return end
            candidate = node
        end
    end
    return candidate
end

local function matchPending()
    local i = 1
    while i <= #M.pending do
        local packet = M.pending[i]
        local node = find(packet)
        if node then apply(node, packet); table.remove(M.pending, i)
        else i = i + 1 end
    end
end

function M.Combat()
    if not A.startedAt then return end
    local get = C_CombatLog and C_CombatLog.GetCurrentEventInfo or CombatLogGetCurrentEventInfo
    if type(get) ~= "function" then return end
    local ok, timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaid, guid, name,
        destFlags, destRaid, extra1, extra2, extra3, extra4 = pcall(get)
    if not ok or not text(event) or not npc(guid) then return end
    local before = M.revision
    local now, stamp = GetTime(), number(timestamp)
    if attacks[event] then
        local miss = event == "SWING_MISSED" and text(extra1) or text(extra4)
        if event:match("_MISSED$") and miss == "EVADE" then M.fights[guid] = nil
        elseif stamp and affiliated(sourceGUID, sourceFlags) then attack(guid, stamp, now) end
        return before ~= M.revision
    end
    if (event ~= "PARTY_KILL" and event ~= "UNIT_DIED") or not text(name) then return end
    M.Scan()
    local node = M.byGUID[guid]
    if not node then
        -- XP messages can precede the combat event. Adopt an unmatched fallback
        -- row rather than counting the same kill twice when the event arrives.
        for _, candidate in ipairs(M.deaths) do
            if not candidate.suppressed and not candidate.guid and candidate.name == name and now - candidate.when <= 5 then node = candidate; break end
        end
        node = node or {name = name, when = now, onlineAt = A.Elapsed(), playerLevel = playerLevel()}
        if not node.guid then
            node.guid = guid
            M.byGUID[guid] = node
            local present = false
            for _, candidate in ipairs(M.deaths) do if candidate == node then present = true; break end end
            if not present then M.deaths[#M.deaths + 1] = node end
        end
    end
    local seen = M.units[guid]
    node.mobLevel = seen and seen.mobLevel or node.mobLevel
    if node.record and node.record.mobLevel ~= node.mobLevel then
        node.record.mobLevel = node.mobLevel; M.revision = M.revision + 1
    end
    local fight = M.fights[guid]
    if fight then node.attackStart = math.min(node.attackStart or fight.started, fight.started) end
    M.fights[guid] = nil
    if stamp and (not node.deathStamp or (event == "UNIT_DIED" and node.deathEvent ~= "UNIT_DIED")) then
        node.deathStamp, node.deathEvent = stamp, event
    end
    updateTiming(node)
    if event == "PARTY_KILL" and affiliated(sourceGUID, sourceFlags) and node.playerLevel then record(node) end
    matchPending()
    return before ~= M.revision
end

function M.XP(message, lineID, guid)
    if not A.startedAt then return end
    local name, xp = M.Parse(message)
    if not name then return end
    local now = GetTime()
    lineID = number(lineID)
    if lineID and lineID > 0 then
        if M.lines[lineID] then return end
        M.lines[lineID] = now
    end
    M.Scan()
    local packet = {name = name, xp = xp, guid = npc(guid) and guid or nil,
        playerLevel = playerLevel(), when = now, onlineAt = A.Elapsed()}
    if packet.guid and M.byGUID[packet.guid] and M.byGUID[packet.guid].claimed then return end
    local node = find(packet)
    if node then apply(node, packet)
    else M.pending[#M.pending + 1] = packet end
    return true
end

function M.Rate()
    local cutoff, times = A.Elapsed() - 60, A.db.killTimes
    local kept = 0
    for i = 1, #times do
        if times[i] > cutoff then kept = kept + 1; times[kept] = times[i] end
    end
    for i = #times, kept + 1, -1 do times[i] = nil end
    return kept
end

function M.Tick(flush)
    M.Scan()
    matchPending()
    local now = GetTime()
    local i = 1
    while i <= #M.pending do
        local packet = M.pending[i]
        if flush or now - packet.when >= 2 then
            local seen
            if packet.guid then seen = M.units[packet.guid] end
            if not seen then
                local matches = 0
                for _, candidate in pairs(M.units) do
                    if candidate.name == packet.name and candidate.dead and now - candidate.seen <= 5 then
                        seen, matches = candidate, matches + 1
                    end
                end
                if matches ~= 1 then seen = nil end
            end
            local node = {guid = packet.guid, name = packet.name, when = packet.when,
                onlineAt = packet.onlineAt, mobLevel = seen and seen.mobLevel, playerLevel = packet.playerLevel}
            M.deaths[#M.deaths + 1] = node
            if node.guid then M.byGUID[node.guid] = node end
            apply(node, packet)
            table.remove(M.pending, i)
        else i = i + 1 end
    end
    for i = #M.deaths, 1, -1 do
        local node = M.deaths[i]
        if node.record and node.record.xp == nil and (flush or now - node.when >= 2) then
            node.record.xp = 0; node.noXP = true; M.revision = M.revision + 1
        end
        if now - node.when > 10 then
            if node.guid then M.byGUID[node.guid] = nil end
            table.remove(M.deaths, i)
        end
    end
    for guid, seen in pairs(M.units) do if now - seen.seen > 180 then M.units[guid] = nil end end
    for id, at in pairs(M.lines) do if now - at > 10 then M.lines[id] = nil end end
    for guid, fight in pairs(M.fights) do if now - fight.seen > 300 then M.fights[guid] = nil end end
    for i = #M.respawnSightings, 1, -1 do
        if now - M.respawnSightings[i].when > 5 then table.remove(M.respawnSightings, i) end
    end
    M.UpdateRespawns(flush)
    M.Rate()
end

function M.ClearHistory()
    A.db.kills, M.pending = {}, {}
    -- Keep recent kill identities so late XP/death events cannot restore rows
    -- that have just been cleared. Active fights and Kills/min keep running.
    for _, node in ipairs(M.deaths) do node.suppressed = true end
    M.revision = M.revision + 1
end

function M.Reset()
    A.db.kills, A.db.killTimes = {}, {}
    A.db.respawns, M.respawnStats, M.respawnBatch = {}, {}, {}
    M.ResetRespawnObservations()
    M.deaths, M.byGUID, M.pending = {}, {}, {}
    M.fights = {}
    M.revision = M.revision + 1
end
