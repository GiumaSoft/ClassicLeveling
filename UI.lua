local _, A = ...
local U = {}
A.UI = U
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local WIDTH = 332
local INNER = WIDTH - 20
local MOB_WIDTH = 408
local MOB_INNER = MOB_WIDTH - 20

local function label(parent, size, text)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont(FONT, size, "")
    f:SetTextColor(.93, .91, .84)
    f:SetJustifyH("LEFT")
    f:SetText(text or "")
    return f
end

local function panel(kind, name, parent)
    local f = CreateFrame(kind, name, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetBackdrop({bgFile = WHITE, edgeFile = WHITE, edgeSize = 1})
    f:SetBackdropColor(.025, .025, .025, .94)
    f:SetBackdropBorderColor(.68, .52, .18, 1)
    return f
end

local function button(parent, text, x, callback)
    local b = panel("Button", nil, parent)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp")
    b:SetSize(69, 23)
    b:SetPoint("TOPRIGHT", x, -162)
    b.label = label(b, 11, text)
    b.label:SetPoint("CENTER")
    local highlight = b:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, .82, 0, .12)
    b:SetScript("OnClick", callback)
    return b
end

function U.Number(value)
    local text = string.format("%.0f", math.max(0, value))
    local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return result
end

function U.Time(seconds)
    seconds = math.floor(seconds)
    return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

function U.SessionTime(seconds)
    seconds = math.floor(seconds)
    return string.format("%dh %dm %ds", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

function U.KillTime(seconds)
    return A.IsNumber(seconds) and string.format("%.1fs", seconds) or "--"
end

function U.RespawnTime(seconds)
    return A.IsNumber(seconds) and (U.Number(math.floor(seconds + .5)) .. "s") or "--"
end

function U.XPPerSecond(xp, seconds)
    if not A.IsNumber(xp) or not A.IsNumber(seconds) or seconds <= 0 then return "--" end
    local rate = xp / seconds
    return A.IsNumber(rate) and string.format("%.1f", rate) or "--"
end

function U.Money(copper, signed)
    local prefix = signed and (copper > 0 and "+" or copper < 0 and "-" or "") or ""
    copper = math.floor(math.abs(copper))
    return prefix .. "|cffffd100" .. U.Number(math.floor(copper / 10000)) .. "g|r " ..
        "|cffc7c7cf" .. math.floor(copper / 100) % 100 .. "s|r " ..
        "|cffeda55f" .. copper % 100 .. "c|r"
end

function U.Place()
    local f = U.panel
    f:ClearAllPoints()
    if A.db.position then
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", A.db.position.x, A.db.position.y)
    else f:SetPoint("CENTER", UIParent, "CENTER", 0, -130) end
end

function U.ScrollMobs(delta)
    local maximum = math.max(0, #A.db.kills - 8)
    U.mobOffset = math.max(0, math.min(maximum, (U.mobOffset or 0) + delta))
    U.mobRevision = nil
    U.RefreshMobs()
end

function U.ToggleMobs()
    A.db.mobExpanded = not A.db.mobExpanded
    U.RefreshMobs()
end

function U.CreateMobs()
    U.mobOffset, U.mobRows = 0, {}
    U.mobToggle = button(U.panel, "Kills/min: 0 [+]", -10, U.ToggleMobs)
    U.mobToggle:SetSize(110, 20)
    U.mobToggle:SetFrameLevel(U.anchor:GetFrameLevel() + 1)
    U.mobToggle:ClearAllPoints(); U.mobToggle:SetPoint("TOPLEFT", WIDTH - 119, -2)
    U.mobToggle.label:SetFont(FONT, 10, "")
    U.mobToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Mob kills")
        GameTooltip:AddLine("Kills/min counts kills in the last 60 seconds of online time.", 1, 1, 1, true)
        GameTooltip:AddLine("Click to expand or collapse the last " .. A.Mobs.LIMIT .. " kills.", .8, .8, .8, true)
        GameTooltip:AddLine("XP@lvl: 75@7 means 75 XP received at character level 7.", .8, .8, .8, true)
        GameTooltip:AddLine("Time: first recorded hit or miss to the mob's death, including pet and group attacks.", .8, .8, .8, true)
        GameTooltip:AddLine("XP/s: XP received divided by that mob's kill time.", .8, .8, .8, true)
        GameTooltip:AddLine("Respawn avg: mean wait from a kill to a newly observed living mob with the same name, at any level.", .8, .8, .8, true)
        GameTooltip:AddLine("Respawn averages refresh every 5 seconds; they are observed estimates.", .8, .8, .8, true)
        GameTooltip:Show()
    end)
    U.mobToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local p = CreateFrame("Frame", nil, U.panel)
    U.mobPanel = p
    p:SetSize(MOB_WIDTH, 198); p:SetPoint("TOPLEFT", 0, -200)
    local divider = p:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(.68, .52, .18, .35)
    divider:SetPoint("TOPLEFT", 10, 0); divider:SetSize(MOB_INNER, 1)
    local mob = label(p, 10, "Mob"); mob:SetPoint("TOPLEFT", 10, -10)
    for _, column in ipairs({{"Lvl", -240, 26}, {"XP@lvl", -178, 54}, {"Time", -134, 36},
        {"XP/s", -86, 40}, {"Respawn avg", -10, 68}}) do
        local t = label(p, 9, column[1]); t:SetPoint("TOPRIGHT", column[2], -10)
        t:SetWidth(column[3]); t:SetJustifyH("RIGHT")
    end
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, delta) U.ScrollMobs(-delta * 3) end)
    for i = 1, 8 do
        local row = CreateFrame("Button", nil, p)
        U.mobRows[i] = row
        row:SetSize(MOB_INNER, 18); row:SetPoint("TOPLEFT", 10, -26 - (i - 1) * 18)
        local background = row:CreateTexture(nil, "BACKGROUND"); background:SetAllPoints()
        background:SetColorTexture(.45, .36, .18, i % 2 == 0 and .10 or .03)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT"); highlight:SetAllPoints()
        highlight:SetColorTexture(1, .82, 0, .10)
        row.nameText = label(row, 10, ""); row.nameText:SetPoint("LEFT", 0, 0)
        row.nameText:SetWidth(124); row.nameText:SetWordWrap(false)
        for _, column in ipairs({{"mobLevel", -230, 26}, {"xp", -168, 54}, {"killTime", -124, 36},
            {"xpPerSecond", -76, 40}, {"respawn", 0, 68}}) do
            local t = label(row, 10, ""); row[column[1]] = t
            t:SetPoint("RIGHT", column[2], 0); t:SetWidth(column[3]); t:SetJustifyH("RIGHT")
        end
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta) U.ScrollMobs(-delta * 3) end)
        row:SetScript("OnEnter", function(self)
            local kill = self.kill
            if not kill then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(kill.name)
            GameTooltip:AddLine("Mob level: " .. (kill.mobLevel or "?"), 1, 1, 1)
            GameTooltip:AddLine("XP received: " .. (kill.xp ~= nil and U.Number(kill.xp) or "..."), 1, 1, 1)
            GameTooltip:AddLine("Your level at kill: " .. (kill.playerLevel or "?"), 1, 1, 1)
            GameTooltip:AddLine("Kill time: " .. U.KillTime(kill.killTime), 1, 1, 1)
            GameTooltip:AddLine("XP/s: " .. U.XPPerSecond(kill.xp, kill.killTime), 1, 1, 1)
            local average, samples = A.Mobs.RespawnAverage(kill.name)
            GameTooltip:AddLine("Respawn avg: " .. U.RespawnTime(average) .. " (" .. samples .. " samples)", 1, 1, 1)
            GameTooltip:AddLine("Grouped by name only, regardless of mob level. Updated every 5 seconds.", .8, .8, .8, true)
            if not average then GameTooltip:AddLine("Observe a living mob with this name after a kill to collect a sample.", .8, .8, .8, true) end
            GameTooltip:AddLine("Recorded at " .. U.Time(kill.at) .. " since Reset", .7, .7, .7)
            if not kill.mobLevel then GameTooltip:AddLine("The mob's level was not available from a visible unit.", .8, .8, .8, true) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    U.mobEmpty = label(p, 11, "No kills yet. Kill a mob to start tracking.")
    U.mobEmpty:SetPoint("TOPLEFT", 10, -32); U.mobEmpty:SetWidth(MOB_INNER)
    U.mobPage = label(p, 9, ""); U.mobPage:SetPoint("TOPLEFT", 10, -179); U.mobPage:SetWidth(183)
    U.mobClear = button(p, "Clear", -90, function()
        A.Mobs.ClearHistory(); U.mobOffset = 0; U.RefreshMobs()
    end)
    U.mobClear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Clear mob list")
        GameTooltip:AddLine("XP, bag values and Kills/min continue.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    U.mobClear:SetScript("OnLeave", function() GameTooltip:Hide() end)
    U.mobUp = button(p, "Up", -51, function() U.ScrollMobs(-8) end)
    U.mobDown = button(p, "Down", -10, function() U.ScrollMobs(8) end)
    for _, entry in ipairs({{U.mobClear, -90, 40}, {U.mobUp, -51, 34}, {U.mobDown, -10, 34}}) do
        local b = entry[1]; b:SetSize(entry[3], 19); b:ClearAllPoints(); b:SetPoint("TOPRIGHT", entry[2], -174)
        b.label:SetFont(FONT, 10, "")
    end
end

function U.RefreshMobs()
    if not U.mobPanel then return end
    local expanded = A.db.mobExpanded
    U.mobToggle.label:SetText("Kills/min: " .. A.Mobs.Rate() .. (expanded and " [-]" or " [+]"))
    U.mobPanel:SetShown(expanded)
    if U.mobExpanded ~= expanded then
        if U.mobExpanded ~= nil or expanded then
            local left, top = U.panel:GetLeft(), U.panel:GetTop()
            U.panel:SetSize(expanded and MOB_WIDTH or WIDTH, expanded and 400 or 195)
            if left and top then
                U.panel:ClearAllPoints()
                U.panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left - UIParent:GetLeft(), top - UIParent:GetTop())
            end
        end
        U.mobExpanded, U.mobRevision = expanded, nil
    end
    if U.mobRevision == A.Mobs.revision then return end
    U.mobRevision = A.Mobs.revision
    local kills, count = A.db.kills, #A.db.kills
    U.mobOffset = math.min(U.mobOffset, math.max(0, count - 8))
    for i, row in ipairs(U.mobRows) do
        local kill = kills[U.mobOffset + i]
        row.kill = kill; row:SetShown(kill ~= nil)
        if kill then
            row.nameText:SetText(kill.name)
            row.mobLevel:SetText(kill.mobLevel or "?")
            row.xp:SetText((kill.xp ~= nil and U.Number(kill.xp) or "...") .. "@" .. (kill.playerLevel or "?"))
            row.killTime:SetText(U.KillTime(kill.killTime))
            row.xpPerSecond:SetText(U.XPPerSecond(kill.xp, kill.killTime))
            row.respawn:SetText(U.RespawnTime(A.Mobs.RespawnAverage(kill.name)))
        end
    end
    U.mobEmpty:SetShown(count == 0)
    U.mobPage:SetText(count == 0 and ("0 / " .. A.Mobs.LIMIT) or
        ((U.mobOffset + 1) .. "-" .. math.min(count, U.mobOffset + 8) .. " / " .. count .. "  (mouse wheel)"))
    U.mobUp:SetShown(count > 8); U.mobDown:SetShown(count > 8)
end

function U.Create()
    if U.panel then return end
    local f = panel("Frame", "ClassicLevelingPanel", UIParent)
    U.panel = f
    f:SetSize(WIDTH, 195)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    U.Place()

    U.anchor = CreateFrame("Frame", nil, f)
    U.anchor:SetPoint("TOPLEFT", 1, -1)
    U.anchor:SetWidth(WIDTH - 127)
    U.anchor:SetHeight(35)
    U.anchor:EnableMouse(true)
    U.anchor:RegisterForDrag("LeftButton")
    U.anchor:SetScript("OnDragStart", function() if not A.db.locked then f:StartMoving() end end)
    U.anchor:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local x, y = f:GetLeft() - UIParent:GetLeft(), f:GetTop() - UIParent:GetTop()
        A.db.position = {x = x, y = y}
        U.Place()
    end)
    U.anchor:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("ClassicLeveling")
        GameTooltip:AddLine("XP/min: XP earned in the last 60 seconds.", 1, 1, 1, true)
        GameTooltip:AddLine("XP/min values refresh every 5 seconds.", .8, .8, .8, true)
        GameTooltip:AddLine("XP/hr: XP earned in the last 60 minutes.", 1, 1, 1, true)
        GameTooltip:AddLine("Avg: average rates since Reset, including all XP sources.", .8, .8, .8, true)
        GameTooltip:AddLine("Time includes idle time while online; offline time is excluded.", .8, .8, .8, true)
        GameTooltip:AddLine("Combat counts time while your character is in combat; Total counts all online time since Reset.", .8, .8, .8, true)
        GameTooltip:AddLine("Bags (sell value): vendor sell price x quantity in your backpack and bags.", 1, 1, 1, true)
        GameTooltip:AddLine("Bag count: stacks / total item quantity.", .8, .8, .8, true)
        GameTooltip:AddLine(A.db.locked and "Click Unlock to move this panel." or "Drag the title to move this panel.", 1, .82, 0, true)
        GameTooltip:Show()
    end)
    U.anchor:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local title = label(U.anchor, 13, "ClassicLeveling")
    title:SetPoint("TOPLEFT", 9, -3)
    title:SetTextColor(1, .82, 0)
    U.character = label(U.anchor, 10, "")
    U.character:SetPoint("TOPLEFT", 9, -19)
    U.character:SetWidth(145)
    U.character:SetWordWrap(false)

    local recent = label(f, 10, "Recent")
    recent:SetPoint("TOPRIGHT", -91, -29)
    recent:SetWidth(78)
    recent:SetJustifyH("RIGHT")
    local average = label(f, 10, "Average")
    average:SetPoint("TOPRIGHT", -10, -29)
    average:SetWidth(78)
    average:SetJustifyH("RIGHT")
    local minute = label(f, 11, "XP/min (60s)")
    minute:SetPoint("TOPLEFT", 10, -47)
    local hour = label(f, 11, "XP/hr (60m)")
    hour:SetPoint("TOPLEFT", 10, -70)
    U.minute = label(f, 16, "0")
    U.minute:SetPoint("TOPRIGHT", -91, -43)
    U.minute:SetWidth(78)
    U.minute:SetJustifyH("RIGHT")
    U.hour = label(f, 16, "0")
    U.hour:SetPoint("TOPRIGHT", -91, -66)
    U.hour:SetWidth(78)
    U.hour:SetJustifyH("RIGHT")
    U.averageMinute = label(f, 14, "0")
    U.averageMinute:SetPoint("TOPRIGHT", -10, -45)
    U.averageMinute:SetWidth(78)
    U.averageMinute:SetJustifyH("RIGHT")
    U.averageHour = label(f, 14, "0")
    U.averageHour:SetPoint("TOPRIGHT", -10, -68)
    U.averageHour:SetWidth(78)
    U.averageHour:SetJustifyH("RIGHT")
    U.total = label(f, 11, "")
    U.total:SetPoint("TOPLEFT", 10, -92)
    U.total:SetWidth(220)
    local bagDivider = f:CreateTexture(nil, "ARTWORK")
    bagDivider:SetColorTexture(.68, .52, .18, .35)
    bagDivider:SetPoint("TOPLEFT", 10, -130)
    bagDivider:SetSize(INNER, 1)
    U.bagLabel = label(f, 11, "Bags (sell value):")
    U.bagLabel:SetPoint("TOPLEFT", 10, -141)
    U.bagLabel:SetWidth(118)
    U.bagValue = label(f, 15, "Loading...")
    U.bagValue:SetPoint("TOPRIGHT", -10, -137)
    U.bagValue:SetWidth(186)
    U.bagValue:SetJustifyH("RIGHT")
    U.bagStatus = label(f, 9, "")
    U.bagStatus:SetPoint("TOPLEFT", 10, -170)
    U.bagStatus:SetWidth(158)
    U.time = label(f, 11, "Combat 0h 0m 0s | Total 0h 0m 0s")
    U.time:SetPoint("TOPLEFT", 10, -111)
    U.time:SetWidth(INNER)
    U.time:SetTextColor(.7, .7, .7)
    U.lock = button(f, "Lock", -88, function() A.SetLocked(not A.db.locked) end)
    U.reset = button(f, "Reset", -12, A.Reset)
    U.CreateMobs()
end

function U.Update(force)
    if not U.panel then return end
    U.character:SetText((UnitName("player") or "Player") .. " lv. " ..
        math.max(UnitLevel("player") or 0, A.expectedLevel or 0))
    local xp, seconds, averageMinute, averageHour, minute, hour = A.Stats()
    local now = GetTime()
    if force or not U.minuteUpdatedAt or now - U.minuteUpdatedAt >= 5 then
        U.minute:SetText(U.Number(minute))
        U.averageMinute:SetText(U.Number(averageMinute))
        local elapsed = now - (U.minuteUpdatedAt or now)
        U.minuteUpdatedAt = (force or not U.minuteUpdatedAt) and now or (now - elapsed % 5)
    end
    U.hour:SetText(U.Number(hour))
    U.averageHour:SetText(U.Number(averageHour))
    U.total:SetText("Session XP: " .. U.Number(xp))
    local bags = A.Bags.state
    if bags then
        U.bagValue:SetText((bags.pending > 0 and ">= " or "") .. U.Money(bags.value))
        U.bagStatus:SetText(bags.pending > 0 and ("Loading: " .. bags.pending) or
            (bags.stacks .. " stacks / " .. U.Number(bags.items)))
    end
    U.time:SetText("Combat " .. U.SessionTime(A.CombatElapsed()) .. " | Total " .. U.SessionTime(seconds))
    U.lock.label:SetText(A.db.locked and "Unlock" or "Lock")
    U.panel:SetShown(not A.db.hidden)
    U.RefreshMobs()
end
