local _, A = ...
local U = {items = {}, verdicts = {}, pending = {}, requested = {}, dirty = true,
    buttons = setmetatable({}, {__mode = "k"})}
A.Upgrades = U

-- Relative leveling weights, not raid/BiS simulations. Talent points choose
-- the hybrid's profile; before talents, use its usual solo-leveling profile.
local profiles = {
    hunter = {name = "Hunter", agi = 2, sta = .6, int = .3, spirit = .15, str = .1,
        ap = .5, rap = 1, crit = 12, hit = 12, armor = .01, rangedDPS = 8},
    rogue = {name = "Rogue", str = 1, agi = 2, sta = .6, spirit = .05,
        ap = .5, crit = 12, hit = 12, armor = .01, meleeDPS = 8},
    warrior = {name = "Warrior damage", str = 2, agi = 1, sta = .8, spirit = .2,
        ap = 1, crit = 12, hit = 12, armor = .02, meleeDPS = 8},
    paladin = {name = "Paladin damage", str = 1.8, agi = .6, sta = .8, int = .5, spirit = .3,
        ap = .5, crit = 8, hit = 8, armor = .02, meleeDPS = 7, spell = .3},
    shaman = {name = "Shaman melee", str = 1.5, agi = 1, sta = .7, int = .6, spirit = .3,
        ap = .5, crit = 8, hit = 8, armor = .02, meleeDPS = 7, spell = .4},
    feral = {name = "Druid feral", str = 1.5, agi = 1.7, sta = .9, int = .1,
        ap = .5, feralAP = .5, crit = 12, hit = 12, armor = .02},
    tank = {name = "Protection", str = .7, agi = 1.1, sta = 1.5, ap = .3, crit = 5, hit = 8,
        armor = .06, defense = 2, dodge = 10, parry = 10, block = 8, blockValue = 1, meleeDPS = 3},
    bear = {name = "Druid tank", str = 1, agi = 1.2, sta = 1.5, ap = .3, feralAP = .3,
        crit = 5, hit = 8, armor = .06, defense = 1, dodge = 10},
    caster = {name = "Caster damage", int = 1, sta = .5, spirit = .5, spell = 1,
        spellCrit = 8, spellHit = 10, mp5 = 2, armor = .005, wandDPS = .5},
    healer = {name = "Healing", int = 1, sta = .4, spirit = .8, spell = .8,
        healing = 1, spellCrit = 5, mp5 = 3, armor = .005},
}

local keys = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spirit", RESISTANCE0_NAME = "armor",
    ITEM_MOD_ARMOR_SHORT = "armor", ITEM_MOD_EXTRA_ARMOR_SHORT = "armor",
    ITEM_MOD_HEALTH_SHORT = "health", ITEM_MOD_MANA_SHORT = "mana",
    ITEM_MOD_ATTACK_POWER_SHORT = "ap", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "feralAP", ITEM_MOD_SPELL_POWER_SHORT = "spell",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "spell", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "healing",
    ITEM_MOD_CRIT_RATING_SHORT = "crit", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "crit", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "spellCrit",
    ITEM_MOD_HIT_RATING_SHORT = "hit", ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit",
    ITEM_MOD_HIT_RANGED_RATING_SHORT = "hit", ITEM_MOD_HIT_SPELL_RATING_SHORT = "spellHit",
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_POWER_REGEN0_SHORT = "mp5",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "defense", ITEM_MOD_DODGE_RATING_SHORT = "dodge",
    ITEM_MOD_PARRY_RATING_SHORT = "parry", ITEM_MOD_BLOCK_RATING_SHORT = "block",
    ITEM_MOD_BLOCK_VALUE_SHORT = "blockValue", ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
}
local slots = {
    INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3}, INVTYPE_CHEST = {5},
    INVTYPE_ROBE = {5}, INVTYPE_WAIST = {6}, INVTYPE_LEGS = {7}, INVTYPE_FEET = {8},
    INVTYPE_WRIST = {9}, INVTYPE_HAND = {10}, INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14},
    INVTYPE_CLOAK = {15}, INVTYPE_WEAPON = {16}, INVTYPE_WEAPONMAINHAND = {16},
    INVTYPE_2HWEAPON = {16}, INVTYPE_WEAPONOFFHAND = {17}, INVTYPE_SHIELD = {17}, INVTYPE_HOLDABLE = {17},
    INVTYPE_RANGED = {18}, INVTYPE_RANGEDRIGHT = {18}, INVTYPE_THROWN = {18}, INVTYPE_RELIC = {18},
}

local function api(name) return C_Item and C_Item[name] or _G[name] end
local function itemID(link) return tonumber(link and link:match("item:(%d+)")) end
local function request(link)
    local id = itemID(link)
    if not id then return end
    U.pending[id] = true
    local load = api("RequestLoadItemDataByID")
    if load and (not U.requested[id] or GetTime() - U.requested[id] >= 5) then
        U.requested[id] = GetTime(); load(id)
    end
end

function U.Profile()
    if U.profile then return U.profile end
    local _, class = UnitClass("player")
    local tree, most = 0, 0
    for i = 1, 3 do
        local points
        if type(GetTalentTabInfo) == "function" then
            local _, _, oldPoints, _, newPoints = GetTalentTabInfo(i)
            points = A.IsNumber(oldPoints) and oldPoints or newPoints
        elseif C_SpecializationInfo and type(C_SpecializationInfo.GetSpecializationInfo) == "function" then
            points = select(7, C_SpecializationInfo.GetSpecializationInfo(i))
        end
        if A.IsNumber(points) and points > most then tree, most = i, points end
    end
    local key = class and class:lower()
    if class == "WARRIOR" and tree == 3 or class == "PALADIN" and tree == 2 then key = "tank"
    elseif class == "PALADIN" and tree == 1 or class == "SHAMAN" and tree == 3 or
        class == "DRUID" and tree == 3 or class == "PRIEST" and (tree == 1 or tree == 2) then key = "healer"
    elseif class == "DRUID" then key = tree == 1 and "caster" or "feral"
    elseif class == "SHAMAN" and tree == 1 then key = "caster"
    elseif class == "MAGE" or class == "WARLOCK" or class == "PRIEST" then key = "caster" end
    local role = type(UnitGroupRolesAssigned) == "function" and UnitGroupRolesAssigned("player")
    if role == "TANK" then
        if class == "DRUID" then key = "bear"
        elseif class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN" then key = "tank" end
    elseif role == "HEALER" and (class == "PALADIN" or class == "SHAMAN" or class == "DRUID" or class == "PRIEST") then
        key = "healer"
    elseif role == "DAMAGER" then
        if class == "PRIEST" or class == "DRUID" and tree ~= 2 then key = "caster"
        elseif class == "WARRIOR" or class == "PALADIN" then key = class:lower()
        elseif class == "SHAMAN" then key = tree == 1 and "caster" or "shaman" end
    end
    U.profile = profiles[key]
    return U.profile
end

local function formatPattern(value)
    if type(value) ~= "string" then return end
    value = value:gsub("%%[%d%.%$]*[dfs]", "CLVLNUMBER")
    value = value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    return "^" .. value:gsub("CLVLNUMBER", function() return "([%d%.,]+)" end) .. "$"
end
local function textNumber(value) return value and tonumber((value:gsub(",", "."))) end
local function dpsWeight(item, slot)
    local profile = U.Profile()
    if not profile then return 0 end
    if slot == 18 then return item.subclassID == 19 and (profile.wandDPS or 0) or (profile.rangedDPS or 0) end
    return item.classID == 2 and (profile.meleeDPS or 0) * (slot == 17 and .5 or 1) or 0
end

-- Classic Equip spells are often omitted by GetItemStats. These are flat
-- English tooltip bonuses; percentages are Classic percentages, not ratings.
local bonuses = {
    {"ap", "^Equip: Increases attack power by (%d+)%.$"},
    {"rap", "^Equip: Increases ranged attack power by (%d+)%.$"},
    {"feralAP", "^Equip: Increases attack power by (%d+) in Cat, Bear, and Dire Bear forms only%.$"},
    {"crit", "^Equip: Improves your chance to get a critical strike by ([%d%.]+)%%%.$"},
    {"hit", "^Equip: Improves your chance to hit by ([%d%.]+)%%%.$"},
    {"spellCrit", "^Equip: Improves your chance to get a critical strike with spells by ([%d%.]+)%%%.$"},
    {"spellHit", "^Equip: Improves your chance to hit with spells by ([%d%.]+)%%%.$"},
    {"spell", "^Equip: Increases damage and healing done by magical spells and effects by up to (%d+)%.$"},
    {"healing", "^Equip: Increases healing done by spells and effects by up to (%d+)%.$"},
    {"mp5", "^Equip: Restores (%d+) mana per 5 sec%.$"},
    {"defense", "^Equip: Increases defense by (%d+)%.$"},
    {"dodge", "^Equip: Increases your chance to dodge an attack by ([%d%.]+)%%%.$"},
    {"parry", "^Equip: Increases your chance to parry an attack by ([%d%.]+)%%%.$"},
    {"block", "^Equip: Increases your chance to block attacks with a shield by ([%d%.]+)%%%.$"},
    {"blockValue", "^Equip: Increases the block value of your shield by (%d+)%.$"},
}

local function tooltipStats(item)
    if not U.tooltip then U.tooltip = CreateFrame("GameTooltip", "ClassicLevelingScanTooltip", UIParent, "GameTooltipTemplate") end
    local tip = U.tooltip
    tip:SetOwner(UIParent, "ANCHOR_NONE"); tip:ClearLines()
    local ok = pcall(tip.SetHyperlink, tip, item.link)
    local dpsPattern, armorPattern = formatPattern(DPS_TEMPLATE), formatPattern(ARMOR_TEMPLATE)
    local bonus, primary = {}, {}
    local names = {Strength = "str", Agility = "agi", Stamina = "sta", Intellect = "int", Spirit = "spirit"}
    if ok then
        for i = 1, math.min(tip:NumLines() or 0, 100) do
            for _, side in ipairs({"Left", "Right"}) do
                local region = _G["ClassicLevelingScanTooltipText" .. side .. i]
                local text = region and region:GetText()
                if type(text) == "string" then
                    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    local dps = dpsPattern and textNumber(text:match(dpsPattern))
                    local armor = armorPattern and textNumber(text:match(armorPattern))
                    if dps then item.stats.dps = dps end
                    if armor and not item.stats.armor then item.stats.armor = armor end
                    local amount, name = text:match("^%+(%d+) (.-)$")
                    if amount and names[name] then primary[names[name]] = (primary[names[name]] or 0) + tonumber(amount) end
                    for _, rule in ipairs(bonuses) do
                        local amount = textNumber(text:match(rule[2]))
                        if amount then bonus[rule[1]] = (bonus[rule[1]] or 0) + amount; break end
                    end
                end
            end
        end
    end
    local loaded = ok and (tip:NumLines() or 0) > 0
    tip:Hide()
    for key, value in pairs(bonus) do item.stats[key] = math.max(item.stats[key] or 0, value) end
    for key, value in pairs(primary) do item.stats[key] = math.max(item.stats[key] or 0, value) end
    return loaded
end

function U.Read(link)
    if U.items[link] then return U.items[link] end
    local get = api("GetItemInfo")
    if not get then return end
    local name, _, _, _, required, _, _, _, equipLoc, _, _, classID, subclassID = get(link)
    if not name then request(link); return end
    local item = {link = link, id = itemID(link), required = required or 0, equipLoc = equipLoc,
        classID = classID, subclassID = subclassID, stats = {}}
    if slots[equipLoc] then
        local getStats = api("GetItemStats")
        local raw = getStats and getStats(link)
        for key, value in pairs(raw or {}) do
            local stat = keys[key]
            if stat and A.IsNumber(value) then item.stats[stat] = math.max(item.stats[stat] or 0, value) end
        end
        local tooltipLoaded = tooltipStats(item)
        if not raw and not tooltipLoaded then request(link); return end
        -- A weapon whose DPS has not loaded must not become a zero-score
        -- equipped baseline, nor may a better-stat candidate hide lost DPS.
        if dpsWeight(item, slots[equipLoc][1]) > 0 and not A.IsNumber(item.stats.dps) then request(link); return end
    end
    local unique, category = api("GetItemUniquenessByID"), api("GetItemUniqueness")
    if unique then item.unique, _, item.limit, item.category = unique(item.id) end
    if category then
        local id, maximum = category(link)
        if A.IsNumber(id) and id > 0 then item.category, item.limit = id, maximum end
    end
    if not A.IsNumber(item.category) or item.category <= 0 then item.category = nil end
    U.items[link] = item
    return item
end

function U.Score(item, slot)
    if not item then return 0 end
    local profile, total = U.Profile(), 0
    if not profile then return 0 end
    for key, value in pairs(item.stats) do
        if key ~= "dps" then total = total + value * (profile[key] or 0) end
    end
    total = total + (item.stats.health or 0) * (profile.sta or 0) / 10 +
        (item.stats.mana or 0) * (profile.int or 0) / 15
    total = total + (item.stats.dps or 0) * dpsWeight(item, slot)
    return total
end

local function equipped(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return nil, true end
    local item = U.Read(link)
    return item, item ~= nil
end
local function canDualWield()
    local known = IsPlayerSpell or IsSpellKnown
    return type(known) == "function" and known(674) == true
end
local function allowedUnique(item, replacing)
    if not item.unique and not item.category then return true end
    local count = 0
    for slot = 1, 19 do
        if not replacing[slot] then
            local other, ready = equipped(slot)
            if not ready then return end
            if other and ((item.category and other.category == item.category) or (item.unique and other.id == item.id)) then
                count = count + 1
            end
        end
    end
    return count < (item.limit or 1)
end

function U.Evaluate(link)
    if U.verdicts[link] then return U.verdicts[link] end
    local item = U.Read(link)
    if not item then return end
    local verdict = {upgrade = false, profile = U.Profile() and U.Profile().name}
    local canUse = C_PlayerInfo and C_PlayerInfo.CanUseItem
    local equippable = api("IsEquippableItem")
    if not slots[item.equipLoc] or item.classID == 2 and item.subclassID == 20 or
        not verdict.profile or not canUse or not equippable or
        not item.id or item.required > (UnitLevel("player") or 0) or
        not equippable(link) or not canUse(item.id) then U.verdicts[link] = verdict; return verdict end
    local targets = slots[item.equipLoc]
    local main, ready = equipped(16)
    if not ready then return end
    if item.equipLoc == "INVTYPE_WEAPON" and canDualWield() and not (main and main.equipLoc == "INVTYPE_2HWEAPON") then
        targets = {16, 17}
    end
    for _, slot in ipairs(targets) do
        local valid = slot ~= 17 or not (main and main.equipLoc == "INVTYPE_2HWEAPON")
        if item.equipLoc == "INVTYPE_WEAPONOFFHAND" and not canDualWield() then valid = false end
        if valid then
            local current, loaded = equipped(slot)
            if not loaded then return end
            local replacing, old = {[slot] = true}, U.Score(current, slot)
            if item.equipLoc == "INVTYPE_2HWEAPON" then
                local offhand, loadedOff = equipped(17)
                if not loadedOff then return end
                replacing[17] = true; old = old + U.Score(offhand, 17)
            end
            local allowed = allowedUnique(item, replacing)
            if allowed == nil then return end
            local score = U.Score(item, slot)
            if allowed and score > old + .001 then
                verdict.upgrade, verdict.score, verdict.previous, verdict.slot = true, score, old, slot
                break
            end
        end
    end
    U.verdicts[link] = verdict
    return verdict
end

local function border(button)
    if button.ClassicLevelingUpgradeBorder then return button.ClassicLevelingUpgradeBorder end
    local frame = CreateFrame("Frame", nil, button)
    frame:EnableMouse(false); frame:SetAllPoints(button)
    for _, edge in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetColorTexture(.72, .22, 1, 1)
        if edge == "TOP" or edge == "BOTTOM" then
            texture:SetPoint(edge .. "LEFT"); texture:SetPoint(edge .. "RIGHT"); texture:SetHeight(2)
        else
            texture:SetPoint("TOP" .. edge); texture:SetPoint("BOTTOM" .. edge); texture:SetWidth(2)
        end
    end
    button.ClassicLevelingUpgradeBorder = frame
    return frame
end

function U.Paint(button, bag, link)
    local result
    if A.db and type(bag) == "number" and bag >= 0 and bag <= 4 and type(link) == "string" then result = U.Evaluate(link) end
    local frame = button.ClassicLevelingUpgradeBorder
    if result and result.upgrade then
        frame = frame or border(button)
        frame:SetFrameLevel(button:GetFrameLevel() + 2); frame:Show()
    elseif frame then frame:Hide() end
    button.ClassicLevelingUpgrade = result and result.upgrade and result or nil
end

local function refresh(button, source)
    local bag, link
    if source.better then
        local data = source.better.currentData
        if not source.better.isFreeSlot and not source.better.staticData and data and not data.isItemEmpty then
            bag = data.bagid; link = data.itemInfo and data.itemInfo.itemLink
        end
    else
        bag = source.container:GetID()
        local info = bag >= 0 and bag <= 4 and C_Container.GetContainerItemInfo(bag, button:GetID())
        link = info and info.hyperlink
    end
    U.Paint(button, bag, link)
end

function U.NativeContainer(frame)
    local name = frame:GetName()
    if not name then return end
    for i = 1, frame.size or 0 do
        local button = _G[name .. "Item" .. i]
        if button then
            local source = {container = frame}; U.buttons[button] = source
            refresh(button, source)
        end
    end
end

function U.HookBags()
    if type(hooksecurefunc) ~= "function" then return end
    if not U.nativeHooked and type(ContainerFrame_Update) == "function" then
        hooksecurefunc("ContainerFrame_Update", U.NativeContainer); U.nativeHooked = true
    end
    if U.betterHooked or not LibStub then return end
    local ace = LibStub("AceAddon-3.0", true)
    local addon = ace and ace:GetAddon("BetterBags", true)
    local module = addon and addon:GetModule("ItemFrame", true)
    local proto = module and module.itemProto
    if not proto or type(proto.FinishItemDraw) ~= "function" or type(proto.ResetVisuals) ~= "function" then return end
    hooksecurefunc(proto, "FinishItemDraw", function(item)
        local button = item.button
        if not button then return end
        local source = {better = item}; U.buttons[button] = source; refresh(button, source)
    end)
    hooksecurefunc(proto, "ResetVisuals", function(item)
        if item.button then U.buttons[item.button] = nil; U.Paint(item.button) end
    end)
    U.betterHooked = true
end

function U.Invalidate()
    U.items, U.verdicts, U.pending, U.profile, U.dirty = {}, {}, {}, nil, true
end
function U.ItemLoaded(id)
    if U.pending[id] then U.Invalidate() end
end
function U.Update()
    if not U.dirty and not next(U.pending) then return end
    if next(U.pending) then U.items, U.verdicts = {}, {} end
    U.pending, U.dirty = {}, false
    for button, source in pairs(U.buttons) do
        if button:IsShown() then refresh(button, source) end
    end
end
