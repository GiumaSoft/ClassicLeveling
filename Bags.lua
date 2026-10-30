local _, A = ...
local B = {dirty = true, requested = {}, pendingIDs = {}}
A.Bags = B

local function request(id)
    if not A.IsNumber(id) or id < 1 or id % 1 ~= 0 then return end
    B.pendingIDs[id] = true
    local load = C_Item and C_Item.RequestLoadItemDataByID
    if type(load) ~= "function" then return end
    local now = GetTime()
    if B.requested[id] and now - B.requested[id] < 5 then return end
    B.requested[id] = now
    load(id)
end

local function price(info)
    if info.hasNoValue then return 0 end
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    local link = info.hyperlink
    if type(get) == "function" and type(link) == "string" and link ~= "" then
        local name, _, _, _, _, _, _, _, _, _, sellPrice = get(link)
        if name and A.IsNumber(sellPrice) and sellPrice % 1 == 0 then return sellPrice end
    end
    request(info.itemID)
end

function B.Scan()
    local state = {value = 0, stacks = 0, items = 0, pending = 0}
    B.pendingIDs = {}
    local container = C_Container
    if not container or type(container.GetContainerNumSlots) ~= "function" or
        type(container.GetContainerItemInfo) ~= "function" then state.pending = 1
    else
        -- Era backpack and the four equipped bags only, including ammo bags.
        for bag = 0, 4 do
            local slots = container.GetContainerNumSlots(bag)
            if not A.IsNumber(slots) or slots % 1 ~= 0 or (bag == 0 and slots == 0) then
                state.pending = state.pending + 1
            else
                for slot = 1, slots do
                    local info = container.GetContainerItemInfo(bag, slot)
                    if type(info) == "table" then
                        state.stacks = state.stacks + 1
                        if A.IsNumber(info.stackCount) and info.stackCount > 0 and info.stackCount % 1 == 0 then
                            state.items = state.items + info.stackCount
                            local unitPrice = price(info)
                            if unitPrice then state.value = state.value + unitPrice * info.stackCount
                            else state.pending = state.pending + 1 end
                        else state.pending = state.pending + 1; request(info.itemID) end
                    elseif type(container.GetContainerItemID) == "function" then
                        local id = container.GetContainerItemID(bag, slot)
                        if id then state.pending = state.pending + 1; request(id) end
                    end
                end
            end
        end
    end
    if state.pending == 0 and A.db.bagBaseline == nil then A.db.bagBaseline = state.value end
    B.state, B.dirty = state, false
end

function B.Update()
    if B.dirty or (B.state and B.state.pending > 0) then B.Scan() end
end

function B.Reset()
    A.db.bagBaseline = nil
    B.Scan()
end

function B.ItemLoaded(id)
    if B.pendingIDs[id] then B.dirty = true end
end

function B.Change()
    if B.state and B.state.pending == 0 and A.db.bagBaseline ~= nil then
        return B.state.value - A.db.bagBaseline
    end
end
