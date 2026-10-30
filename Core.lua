local addonName, A = ...
local frame = CreateFrame("Frame")
A.frame = frame
local sinceUpdate = 0

frame:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "ADDON_LOADED" then
        if unit ~= addonName then
            if A.db then A.Upgrades.HookBags() end
            return
        end
        A.Init()
        A.Mobs.Init()
        A.Upgrades.HookBags()
        SLASH_CLASSICLEVELING1 = "/clvl"
        SLASH_CLASSICLEVELING2 = "/classicleveling"
        SLASH_CLASSICLEVELING3 = "/cxp"
        SLASH_CLASSICLEVELING4 = "/classicxp"
        SlashCmdList.CLASSICLEVELING = A.Command
        return
    end
    if not A.db then return end
    if event == "PLAYER_ENTERING_WORLD" then
        A.Start()
        A.Mobs.ResetRespawnObservations()
        A.Bags.Scan()
        A.Upgrades.Invalidate()
        A.Upgrades.HookBags()
        A.Mobs.Scan()
        A.UI.Create()
        A.Sample()
        A.UI.Update()
        frame:SetScript("OnUpdate", function(_, elapsed)
            sinceUpdate = sinceUpdate + elapsed
            if sinceUpdate < 1 then return end
            sinceUpdate = sinceUpdate % 1
            A.Sample()
            A.Bags.Update()
            A.Upgrades.Update()
            A.Mobs.Tick()
            A.UI.Update()
        end)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        A.Mobs.ResetRespawnObservations()
        A.Mobs.Scan()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        A.SetCombat(event == "PLAYER_REGEN_DISABLED")
        A.UI.Update()
    elseif event == "PLAYER_XP_UPDATE" then
        if unit ~= "player" then return end
        A.Sample()
        A.UI.Update()
    elseif event == "PLAYER_LEVEL_UP" then
        if type(unit) == "number" then A.expectedLevel = math.max(A.expectedLevel or 0, unit) end
        A.Upgrades.Invalidate()
        A.UI.Update()
        -- The next update reads the settled XP bar, not the pre-level-up values.
    elseif event == "BAG_UPDATE_DELAYED" then A.Bags.dirty = true; A.Upgrades.Invalidate()
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        A.Bags.ItemLoaded(unit)
        A.Upgrades.ItemLoaded(unit)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "CHARACTER_POINTS_CHANGED" or
        event == "PLAYER_TALENT_UPDATE" or event == "SPELLS_CHANGED" or event == "SKILL_LINES_CHANGED" or
        event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then A.Upgrades.Invalidate()
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        local args = {...}
        if A.Mobs.XP(unit, args[10], args[11]) then A.UI.Update() end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if A.Mobs.Combat() then A.UI.Update() end
    elseif event == "PLAYER_TARGET_CHANGED" then A.Mobs.Observe("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then A.Mobs.Observe("mouseover")
    elseif event == "UNIT_TARGET" then A.Mobs.Observe(unit == "player" and "target" or unit .. "target")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        A.Mobs.plates[unit] = true; A.Mobs.Observe(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then A.Mobs.plates[unit] = nil
    elseif event == "PLAYER_LOGOUT" then
        A.Mobs.Tick(true)
        A.Save()
        frame:SetScript("OnUpdate", nil)
    end
end)

for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_LOGOUT",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "ZONE_CHANGED_NEW_AREA",
    "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT", "CHAT_MSG_COMBAT_XP_GAIN",
    "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "UNIT_TARGET",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_EQUIPMENT_CHANGED",
    "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED", "SKILL_LINES_CHANGED", "GROUP_ROSTER_UPDATE"}) do
    frame:RegisterEvent(event)
end
pcall(frame.RegisterEvent, frame, "PLAYER_ROLES_ASSIGNED")
