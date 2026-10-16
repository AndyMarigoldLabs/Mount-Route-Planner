-- Run from repository root: luajit tests/prerequisites.lua
-- Optional: pass the extracted MountRoutePlannerData directory to test released data.
local tests, failures = 0, 0
local runtimeRoot = arg[2] or "."
local function loadRuntime(path)
    local addon = MRP
    local loader = assert(loadfile(runtimeRoot .. "/" .. path))
    if arg[2] then MRP = nil end -- packaged files must use the addon namespace
    local ok, result = pcall(loader, "MountRoutePlanner", addon)
    MRP = addon
    assert(ok, result)
    return result
end
local function equal(actual, expected, message)
    assert(actual == expected, (message or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, fn)
    tests = tests + 1
    local ok, err = pcall(fn)
    if ok then print("PASS " .. name) else failures = failures + 1; print("FAIL " .. name .. ": " .. err) end
end

local completed, account, accepted, objectives, waypoints, collected, timers, frames
local standing, faction, combat, displayUpdates
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
format = string.format
FACTION_STANDING_LABEL7, FACTION_STANDING_LABEL8 = "Revered", "Exalted"
SlashCmdList = {}
function UnitFactionGroup() return faction end
function InCombatLockdown() return combat end
function CreateFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, fn) self.scripts[event] = fn end
    frames[#frames + 1] = frame
    return frame
end
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local function flush()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return completed[id] or false end,
    IsQuestFlaggedCompletedOnAccount = function(id) return account[id] or false end,
    IsOnQuest = function(id) return accepted[id] or false end,
    IsComplete = function(id) return objectives[id] or false end,
    GetTitleForQuestID = function() return nil end,
    GetNextWaypoint = function(id) if waypoints[id] then return unpack(waypoints[id]) end end,
}
C_Reputation = { GetFactionDataByID = function() return { name = "The Sons of Hodir", currentStanding = standing } end }
time = os.time
C_UnitAuras = { GetPlayerAuraBySpellID = function() return nil end }
Enum = { UIMapType = { Continent = 2 } }
C_Map = {
    GetMapInfo = function(id) return { mapID = id, mapType = id == 113 and 2 or 3, parentMapID = id == 113 and 0 or 113 } end,
    GetBestMapForUnit = function() return 120 end,
    GetPlayerMapPosition = function() return { x = 0.41, y = 0.86 } end,
    GetWorldPosFromMapPos = function(_, pos) return 1, pos end,
}
function CreateVector2D(x, y) return { x = x, y = y } end
function GetExpansionLevel() return 10 end

frames, timers = {}, {}
MRP = {}
loadRuntime("Locale/MRP_Locale.enUS.lua")
loadRuntime("MRP_Enums.lua")
loadRuntime("MRP_Util.lua")
loadRuntime("MRP_Prerequisites.lua")
loadRuntime("Data/MRP_PrerequisiteData.lua")
MRP.Data = { VERSION = 1, STEPS = {}, OPEN_WORLD = {}, DUNGEONS = {}, RAIDS = {}, WORLD_BOSSES = {} }
MRP.UI = { UpdateDisplay = function() displayUpdates = (displayUpdates or 0) + 1 end }
loadRuntime("MRP_Filter.lua")
loadRuntime("MRP_Route.lua")
loadRuntime("MRP_Core.lua")
local P, F, R = MRP.Prerequisites, MRP.Filter, MRP.Route
MRP.Util.GetMountInfoSafe = function(mount) return mount.name, 1, collected[mount.id] or false end

local function mount(id, itemID)
    return { id = id, itemId = itemID, name = "Mount " .. id, source = { allowedDifficultyIds = { -1 }, uiMapIds = { 120 }, mapId = 0 } }
end
local vendor
local function reset()
    completed, account, accepted, objectives, waypoints, collected, timers = {}, {}, {}, {}, {}, {}, {}
    standing, faction, combat, displayUpdates = 4, "Alliance", false, 0
    loadRuntime("MRP_CharacterSettings.lua")
    MRP_CharacterSettings.filter.sourceTypes.Vendor = true
    MRP_CharacterSettings.filter.holidays.none = true
    MRP_CharacterSettings.routeOrder = { 51 }
    MRP_Settings = {}
    P.ready, P.refreshPending, P.refreshAfterCombat = true, nil, nil
    vendor = { id = 51, expansion = 2, source = { name = "Lillehoff", type = "Vendor", npcID = 32540 },
        mounts = { mount(258, 44080), mount(259, 43958), mount(288, 44086), mount(289, 43961) } }
    MRP.Data.STEPS = { vendor }
    MRP.Data.OPEN_WORLD = { Lillehoff = { mapID = 120, x = 66, y = 61.5, npcID = 32540, questID = 0 } }
    F.filteredSteps = {}
end
local function enable() P:SetEnabled(true) end
local function unlocked() completed[12915], completed[12956] = true, true end
local function currentQuest() return F:GetCurrentStep().prerequisiteQuest.questID end

test("changed runtime files compile as Lua 5.1 and load in their addon namespace", function()
    for _, file in ipairs({ "MRP_UI.lua", "MRP_Map.lua", "MRP_Options.lua", "MRP_CharacterSettings.lua" }) do
        assert(loadfile(runtimeRoot .. "/" .. file))
    end
    equal(type(MRP.Prerequisites.ExpandSteps), "function")
end)

test("fresh and migrated characters must opt in", function()
    reset()
    equal(MRP_CharacterSettings.includePrerequisiteQuests, false)
    MRP_CharacterSettings.includePrerequisiteQuests = nil
    MRP.Core:InitializeSettings()
    equal(MRP_CharacterSettings.includePrerequisiteQuests, false)
    F:Apply()
    equal(#F.filteredSteps, 0)
    equal(#P.diagnostics, 2)
end)

test("Lillehoff routes to K3 once for both Alliance mounts, despite low reputation", function()
    reset(); enable()
    equal(#F.filteredSteps, 1)
    equal(currentQuest(), 12843)
    equal(#F:GetCurrentStep().mounts, 2)
    local loc = R:GetStepEntry(F:GetCurrentStep())
    equal(loc.mapID, 120); equal(loc.x, 41.1); equal(loc.y, 86.1)
    equal(MRP.Core:ShouldSkipStep(F:GetCurrentStep()), false)
    equal(MRP.Data.OPEN_WORLD.Lillehoff.x, 66, "source data stays immutable")
    equal(#vendor.mounts, 4)
end)

test("Horde uses the same chain and only its own mammoths", function()
    reset(); faction = "Horde"; enable()
    equal(#F:GetCurrentStep().mounts, 2)
    equal(F:GetCurrentStep().mounts[1].itemId, 44080)
    equal(F:GetCurrentStep().mounts[2].itemId, 44086)
end)

test("all 26 quests advance in order and never expose an unfinished vendor", function()
    reset(); standing = 8; enable()
    local provider = P:GetSupplement(vendor, vendor.mounts[2])
    equal(#provider.unlockSteps, 26)
    for _, quest in ipairs(provider.unlockSteps) do
        equal(currentQuest(), quest.questID)
        completed[quest.questID] = true
        P:QueueRefresh(); flush()
    end
    equal(F:GetCurrentStep().source.type, "Vendor")
    equal(F:GetCurrentStep().id, 51)
    equal(R:GetStepEntry(F:GetCurrentStep()).x, 66)
end)

test("partially complete chain resumes at its first missing quest", function()
    reset(); completed[12843], completed[12846] = true, true; enable()
    equal(currentQuest(), 12841)
end)

test("terminal unlock flags supersede old chain history", function()
    reset(); unlocked(); standing = 8; enable()
    equal(#F.filteredSteps, 1)
    equal(F:GetCurrentStep().source.type, "Vendor")
end)

test("quest turn-in and reputation are independent purchase gates", function()
    reset(); unlocked(); enable()
    equal(#F.filteredSteps, 0)
    standing = 7; P:QueueRefresh(); flush()
    equal(#F:GetCurrentStep().mounts, 1)
    equal(F:GetCurrentStep().mounts[1].itemId, 43958)
    standing = 8; P:QueueRefresh(); flush()
    equal(#F:GetCurrentStep().mounts, 2)
end)

test("account completion never unlocks character-specific Lillehoff phasing", function()
    reset(); account[12915], account[12956], standing = true, true, 8; enable()
    equal(currentQuest(), 12843)
    equal(P:Evaluate({ type = "quest", id = 12956, scope = "account" }), true)
    local api = C_QuestLog.IsQuestFlaggedCompletedOnAccount
    C_QuestLog.IsQuestFlaggedCompletedOnAccount = nil
    equal(P:Evaluate({ type = "quest", id = 12956, scope = "account" }), nil)
    C_QuestLog.IsQuestFlaggedCompletedOnAccount = api
end)

test("objective completion is not turn-in; live waypoints override giver coordinates", function()
    reset(); enable()
    accepted[12843], objectives[12843] = true, true
    waypoints[12843] = { 121, 0.25, 0.75 }
    P:QueueRefresh(); flush()
    equal(currentQuest(), 12843)
    local loc, phase = P:GetNavigationEntry(F:GetCurrentStep())
    equal(loc.mapID, 121); equal(loc.x, 25); equal(loc.y, 75); equal(phase, "turnIn")
    equal(MRP.Core:ShouldSkipStep(F:GetCurrentStep()), false)
    waypoints[12843] = nil
    loc = P:GetNavigationEntry(F:GetCurrentStep())
    equal(loc.x, 41.1)
end)

test("navigation identity changes between quest stages and successive quests at one NPC", function()
    reset(); enable()
    local quest = F:GetCurrentStep().prerequisiteQuest
    local giver = P:GetQuestDestination(quest)
    accepted[12843], objectives[12843] = true, true
    local turnIn = P:GetQuestDestination(quest)
    equal(giver.x, turnIn.x)
    assert(giver.navigationKey ~= turnIn.navigationKey)
    completed[12843] = true; P:QueueRefresh(); flush()
    local nextGiver = P:GetNavigationEntry(F:GetCurrentStep())
    equal(nextGiver.x, giver.x)
    assert(nextGiver.navigationKey ~= giver.navigationKey)
end)

test("abandoned quests return to the giver and missing objective data never points to vendor", function()
    reset(); enable(); accepted[12843] = true
    equal(P:GetNavigationEntry(F:GetCurrentStep()).x, 40.7)
    accepted[12843] = nil
    equal(P:GetNavigationEntry(F:GetCurrentStep()).x, 41.1)
    local q = { questID = 999, mapID = 120, x = 20, y = 20 }
    accepted[999] = true
    equal(P:GetQuestDestination(q), nil)
    waypoints[999] = { 120, -1, 0.5 }
    equal(P:GetQuestDestination(q), nil)
end)

test("auto-advance off retains the completed stop until manual Next", function()
    reset(); enable(); MRP_CharacterSettings.autoAdvance = false
    completed[12843] = true; P:QueueRefresh(); flush()
    equal(currentQuest(), 12843)
    local loc, phase = P:GetNavigationEntry(F:GetCurrentStep())
    equal(loc, nil); equal(phase, "completed")
    equal(#F.filteredSteps, 2)
    P:QueueRefresh(); flush(); equal(#F.filteredSteps, 2)
    MRP.Core:NextStep(); equal(currentQuest(), 12846)
end)

test("quest event bursts coalesce and combat refresh waits for regeneration", function()
    reset(); enable()
    for _ = 1, 20 do P:QueueRefresh() end
    equal(#timers, 1)
    combat = true; completed[12843] = true; flush()
    equal(currentQuest(), 12843)
    equal(P.refreshAfterCombat, true)
    combat = false
    frames[1].scripts.OnEvent(nil, "PLAYER_REGEN_ENABLED"); flush()
    equal(currentQuest(), 12846)
    equal(frames[1].events.QUEST_TURNED_IN, true)
    equal(frames[1].events.QUEST_LOG_UPDATE, true)
end)

test("filters and collection remove orphan unlock steps", function()
    reset(); enable()
    MRP_CharacterSettings.filter.sourceTypes.Quest = false
    F:Apply(); equal(#F.filteredSteps, 1, "Vendor filter controls its unlocks")
    MRP_CharacterSettings.filter.sourceTypes.Vendor = false
    F:Apply(); equal(#F.filteredSteps, 0)
    MRP_CharacterSettings.filter.sourceTypes.Vendor = true
    collected[259], collected[289] = true, true
    F:Apply(); equal(#F.filteredSteps, 0)
end)

test("toggle off removes unlocks immediately; unlocked vendors need no opt-in", function()
    reset(); enable(); P:SetEnabled(false); equal(#F.filteredSteps, 0)
    unlocked(); standing = 8; F:Apply(); equal(F:GetCurrentStep().source.type, "Vendor")
end)

test("boolean requirements and unsupported metadata fail safely", function()
    reset()
    local q = { type = "quest", id = 10 }
    equal(P:Evaluate({ allOf = { q, { type = "unknown" } } }), false)
    equal(P:Evaluate({ anyOf = { q, { type = "unknown" } } }), nil)
    completed[10] = true
    equal(P:Evaluate({ anyOf = { q, { type = "unknown" } } }), true)
    equal(P:Evaluate({ allOf = { q, { type = "unknown" } } }), nil)
    equal(P:Evaluate({ type = "quest", id = "10" }), nil)
    equal(P:Evaluate({ type = "quest", id = 10, scope = "warband-ish" }), nil)
    local cyclic = {}; cyclic.allOf = { cyclic }
    equal(P:Evaluate(cyclic), nil)
end)

test("legacy quest condition keys are enforced, unknown conditions are not satisfied", function()
    reset()
    MRP.Data.OPEN_WORLD.Lillehoff.conditions = { "quest_123" }
    equal(MRP.Util.AreStepConditionsMet(vendor), false)
    completed[123] = true; equal(MRP.Util.AreStepConditionsMet(vendor), true)
    MRP.Data.OPEN_WORLD.Lillehoff.conditions = { "quest_account_124" }
    account[124] = true; equal(MRP.Util.AreStepConditionsMet(vendor), true)
    MRP.Data.OPEN_WORLD.Lillehoff.conditions = { "not_implemented" }
    equal(MRP.Util.AreStepConditionsMet(vendor), false)
end)

test("geography orders actionable quest locations, not locked vendor coordinates", function()
    reset(); enable()
    local near = F:GetCurrentStep()
    local distant = { id = 60, expansion = 2, source = { type = "Vendor", name = "Distant" }, mounts = { mount(1, 1) },
        entry = { mapID = 120, x = 90, y = 10 } }
    local ordered = R:OrderSteps({ distant, near })
    equal(ordered[1].id, near.id)
    MRP.Data.STEPS[#MRP.Data.STEPS + 1] = distant
    F:Apply(); R:Calculate()
    equal(F.filteredSteps[1].id, near.id)
    equal(R:IsRouteValid(), true)
end)

test("unannotated sources remain usable but explicitly unverified", function()
    reset(); vendor.source.npcID = 999; MRP.Data.OPEN_WORLD.Lillehoff.npcID = 999
    F:Apply(); equal(#F.filteredSteps, 1)
    equal(P:GetMountAvailability(vendor, vendor.mounts[1]).state, "unknown")
    equal(P:GetMountAvailability(vendor, vendor.mounts[1]).unverified, true)
end)

test("a shared quest across different sources appears only once", function()
    reset()
    local entry = { mapID = 120, x = 20, y = 30,
        requirements = { type = "quest", id = 12843 },
        unlockSteps = { { questID = 12843, mapID = 120, x = 41.1, y = 86.1 } } }
    local second = { id = 60, source = { type = "Vendor", name = "Other" }, expansion = 2, mounts = { mount(99, 99) }, entry = entry }
    MRP.Data.STEPS[#MRP.Data.STEPS + 1] = second
    enable()
    equal(#F.filteredSteps, 1)
    equal(#F:GetCurrentStep().mounts, 3)
    equal(F:GetCurrentStep().targetStepIDs[51], true)
    equal(F:GetCurrentStep().targetStepIDs[60], true)
end)

test("unknown declared requirements never turn into available vendor stops", function()
    reset()
    MRP.Data.OPEN_WORLD.Lillehoff.requirements = { type = "unimplemented" }
    enable(); equal(#F.filteredSteps, 0)
    equal(P.diagnostics[1].status.state, "unknown")
end)

test("a known incomplete quest without coordinates stays a quest and never routes to its vendor", function()
    reset()
    local provider = MRP.Data.OPEN_WORLD.Lillehoff
    provider.requirements = { type = "quest", id = 888 }
    provider.unlockSteps = { { questID = 888, name = "Unknown location" } }
    enable(); equal(currentQuest(), 888)
    equal(R:GetStepEntry(F:GetCurrentStep()), nil)
    equal(F:GetCurrentStep().source.type, "Quest")
end)

test("other source restrictions still block unlock errands", function()
    reset()
    MRP.Data.OPEN_WORLD.Lillehoff.conditions = { "horde_only" }
    enable(); equal(#F.filteredSteps, 0)
    reset()
    MRP.Data.OPEN_WORLD.Lillehoff.conditions = { "future_unknown_condition" }
    enable(); equal(#F.filteredSteps, 0)
end)

test("legacy reputation does not prevent working on the vendor unlock", function()
    reset()
    MRP.Data.OPEN_WORLD.Lillehoff.conditions = { "rep_1119_7" }
    enable(); equal(currentQuest(), 12843)
    unlocked(); F:Apply(); equal(#F.filteredSteps, 0)
    standing = 7; F:Apply(); equal(#F:GetCurrentStep().mounts, 1)
end)

test("unrelated completion and route recalculation preserve the selected objective", function()
    reset(); enable()
    local currentID = F:GetCurrentStep().id
    completed[123456] = true; P:QueueRefresh(); flush()
    equal(F:GetCurrentStep().id, currentID)
    R:Calculate(); equal(currentQuest(), 12843)
end)

if arg[1] then
    test("published Retail dataset: Lillehoff supplement applies without modifying generated records", function()
        reset()
        local data = { Internal = {} }
        assert(loadfile(arg[1] .. "/Steps/Standard/MRPData_Steps.lua"))("MountRoutePlannerData", data)
        assert(loadfile(arg[1] .. "/Mounts/Standard/MRPData_Mounts.lua"))("MountRoutePlannerData", data)
        local found
        for _, step in ipairs(data.Steps) do if step.source.npcID == 32540 then found = step; break end end
        assert(found, "release must contain Lillehoff")
        MRP.Data.STEPS, MRP.Data.OPEN_WORLD = { found }, data.openWorld
        enable(); equal(currentQuest(), 12843); equal(#F:GetCurrentStep().mounts, 2)
        unlocked(); standing = 7; F:Apply(); equal(#F:GetCurrentStep().mounts, 1)
        equal(F:GetCurrentStep().mounts[1].itemId, 43958)
        equal(#found.mounts, 4)
    end)
    test("entire published Retail dataset can be filtered and routed with prerequisites enabled", function()
        reset()
        local data = { Internal = {} }
        assert(loadfile(arg[1] .. "/Steps/Standard/MRPData_Steps.lua"))("MountRoutePlannerData", data)
        assert(loadfile(arg[1] .. "/Mounts/Standard/MRPData_Mounts.lua"))("MountRoutePlannerData", data)
        MRP.Data.STEPS, MRP.Data.OPEN_WORLD = data.Steps, data.openWorld
        MRP.Data.DUNGEONS, MRP.Data.RAIDS, MRP.Data.WORLD_BOSSES = data.dungeons, data.raids, data.worldBosses
        MRP.Holidays = { IsHolidayEventActive = function() return true end }
        MRP.Core:InitializeSettings()
        enable(); R:Calculate()
        assert(#F.filteredSteps > 100, "ordinary mount sources should remain present")
        local questCount, vendorCount = 0, 0
        for _, step in ipairs(F.filteredSteps) do
            if step.prerequisiteQuest and step.prerequisiteQuest.questID == 12843 then questCount = questCount + 1 end
            if step.source.npcID == 32540 then vendorCount = vendorCount + 1 end
        end
        equal(questCount, 1); equal(vendorCount, 0)
        equal(R:IsRouteValid(), true)
    end)
end

print(string.format("%d tests, %d failures", tests, failures))
os.exit(failures == 0 and 0 or 1)
