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
local standing, faction, combat, displayUpdates, race, class, reputations, items
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
format = string.format
FACTION_STANDING_LABEL7, FACTION_STANDING_LABEL8 = "Revered", "Exalted"
SlashCmdList = {}
function UnitFactionGroup() return faction end
function UnitRace() return race, race end
function UnitClass() return class, class end
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
C_Reputation = { GetFactionDataByID = function(id) return { name = "Faction " .. id, currentStanding = reputations[id] or standing } end }
C_Item = { GetItemCount = function(id) return items[id] or 0 end }
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
loadRuntime("MRP_Unlocks.lua")
loadRuntime("Data/MRP_PrerequisiteData.lua")
loadRuntime("Data/MRP_UnlockNetherwing.lua")
loadRuntime("Data/MRP_UnlockTournament.lua")
loadRuntime("MRP_UnlockRouting.lua")
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
    race, class, reputations, items = "Human", "WARRIOR", {}, {}
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

test("all 26 Hodir quests advance through ready dependencies without exposing the vendor", function()
    reset(); standing = 8; enable()
    local provider = P:GetSupplement(vendor, vendor.mounts[2])
    equal(#provider.unlockSteps, 26)
    local visited = {}
    for _ = 1, 26 do
        local id = currentQuest()
        assert(not visited[id], "quest repeated")
        visited[id], completed[id] = true, true
        P:QueueRefresh(); flush()
    end
    for _, quest in ipairs(provider.unlockSteps) do assert(visited[quest.questID]) end
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
    enable()
    local missing
    for _, step in ipairs(F.filteredSteps) do if step.prerequisiteQuest.questID == 888 then missing = step end end
    assert(missing)
    equal(R:GetStepEntry(missing), nil)
    equal(missing.source.type, "Quest")
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

local function source(id, kind, npc, item)
    return { id = id, expansion = 2, source = { name = "Source " .. id, type = kind, npcID = npc },
        entry = { mapID = 118, x = 70, y = 20, npcID = npc, questID = 0 }, mounts = { mount(id, item) } }
end
local function expand(steps)
    MRP_CharacterSettings.includePrerequisiteQuests = true
    return P:ExpandSteps(steps)
end
local function questIDs(steps)
    local ids = {}
    for _, step in ipairs(steps) do if step.prerequisiteQuest then ids[step.prerequisiteQuest.questID] = true end end
    return ids
end

test("all curated graphs validate", function()
    local ok, errors = P:ValidateRegistry()
    assert(ok, table.concat(errors, "\n"))
end)

test("Storm Peaks trunk is shared by the polar bear and both mammoths", function()
    reset()
    local bear = source(500, "OpenWorld", nil, 43962)
    local route = expand({ bear, vendor })
    equal(#route, 1); equal(route[1].prerequisiteQuest.questID, 12843)
    equal(#route[1].mounts, 3)
    assert(route[1].targetStepIDs[500] and route[1].targetStepIDs[51])
    equal(#vendor.mounts, 4)
end)

test("Gretta and Hodir have distinct terminal branches", function()
    reset(); completed[12886], completed[12925] = true, true
    local bear = source(500, "OpenWorld", nil, 43962)
    local route = expand({ bear, vendor })
    equal(#route, 2)
    assert(questIDs(route)[13064], "Hodir still needs Sibling Rivalry")
    equal(P:GetMountAvailability(bear, bear.mounts[1]).state, "available")
    reset(); unlocked(); standing = 8
    route = expand({ bear, vendor })
    assert(questIDs(route)[12843], "Hodir flags do not fabricate Gretta progress")
end)

test("Gretta's Aberrations branch and Hyldnir continuation can be ready together", function()
    reset(); completed[12843], completed[12846], completed[12841] = true, true, true
    local route = expand({ source(500, "OpenWorld", nil, 43962) })
    local ids = questIDs(route)
    equal(#route, 2); assert(ids[12925] and ids[12905])
end)

test("a live Gretta offer bypasses rotation preparation, but not unknown declared gates", function()
    reset()
    local bear = source(500, "OpenWorld", nil, 43962)
    UnitGUID = function() return "Creature-0-1-571-1-29796-0000000001" end
    C_GossipInfo = { GetAvailableQuests = function() return { { questID = 13423 } } end }
    local route = expand({ bear })
    equal(#route, 1); equal(route[1].acquisitionQuest.questID, 13423)
    equal(P:GetNavigationEntry(route[1]).x, 50.8)
    bear.requirements = { type = "unknownGate" }
    equal(#expand({ bear }), 0)
    equal(P.diagnostics[1].status.state, "unknown")
    bear.requirements = nil
    UnitGUID = function() return "Creature-0-1-571-1-12345-0000000001" end
    equal(expand({ bear })[1].prerequisiteQuest.questID, 12843)
    UnitGUID, C_GossipInfo = nil, nil
end)

test("Gretta uses an active daily and waits after turn-in without erasing permanent unlocks", function()
    reset()
    local bear = source(500, "OpenWorld", nil, 43962)
    accepted[13423], waypoints[13423] = true, { 120, 0.5, 0.7 }
    local route = expand({ bear })
    equal(#route, 1); equal(P:GetNavigationEntry(route[1]).y, 70)
    accepted[13423], completed[13423] = nil, true
    equal(#expand({ bear }), 0)
    equal(P.diagnostics[1].status.state, "waiting")
    completed[12886], completed[12925], completed[13423] = true, true, nil -- game reports next reset
    equal(#expand({ bear }), 1)
    assert(completed[12886])
end)

local function drakeSources()
    local sources = {}
    for i, drake in ipairs(P.netherwingDrakes) do sources[i] = source(600 + i, "Quest", nil, drake.item) end
    return sources
end
test("six Netherwing rewards share Kindness and never expose final NPCs early", function()
    reset()
    local route = expand(drakeSources())
    equal(#route, 1); equal(route[1].prerequisiteQuest.questID, 10804)
    equal(#route[1].mounts, 6); equal(P:GetNavigationEntry(route[1]).mapID, 104)
end)

test("Netherwing alternate quest flags resume at service, not Kindness", function()
    reset(); completed[10871] = true
    local route = expand(drakeSources())
    equal(#route, 1); equal(route[1].prerequisiteQuest.questID, 11012)
end)

test("Netherwing rank gates stop unavailable promotions and resume at the right rank", function()
    reset(); completed[11014] = true
    equal(#expand(drakeSources()), 0)
    equal(P.diagnostics[1].status.state, "waiting")
    reputations[1015] = 5
    local route = expand(drakeSources())
    equal(#route, 1); equal(route[1].prerequisiteQuest.questID, 11053)
    completed[11053] = true
    equal(#expand(drakeSources()), 0)
    reputations[1015], completed[11084], completed[11092] = 8, true, true
    equal(expand(drakeSources())[1].prerequisiteQuest.questID, 11107)
end)

test("Netherwing selects one free drake in Shattrath, preferring the accepted choice", function()
    reset(); completed[11108], reputations[1015] = true, 8
    local route = expand(drakeSources())
    equal(#route, 1); equal(route[1].prerequisiteQuest.questID, 11111)
    equal(P:GetNavigationEntry(route[1]).mapID, 111)
    accepted[11113] = true
    route = expand(drakeSources())
    equal(#route, 1); equal(route[1].prerequisiteQuest.questID, 11113)
end)

test("claimed Netherwing choice redirects other colors to one Hurlunk vendor stop", function()
    reset(); completed[11111], reputations[1015], collected[601] = true, 8, true
    local originals = drakeSources()
    local route = expand(originals)
    equal(#route, 1); equal(route[1].source.npcID, 23489); equal(#route[1].mounts, 5)
    equal(P:GetNavigationEntry(route[1]).mapID, 104)
    equal(route[1].mounts[1].source.cost.amount, 2000000)
    equal(originals[2].source.type, "Quest"); equal(originals[2].mounts[1].source.cost, nil)
    equal(MRP.Core:ShouldSkipStep(route[1]), false)
end)

test("uncollected Netherwing goal alone chooses its own free reward", function()
    reset(); completed[11108], reputations[1015] = true, 8
    local route = expand({ source(700, "Quest", nil, 32861) })
    equal(route[1].prerequisiteQuest.questID, 11114)
end)

test("ready Netherwing reward works without opt-in and merges with a vendor unlock goal", function()
    reset(); completed[11108], reputations[1015] = true, 8
    local questSource = source(700, "Quest", nil, 32861)
    local route = P:ExpandSteps({ questSource })
    equal(#route, 1); equal(route[1].prerequisiteQuest.questID, 11114)
    local dealer = source(701, "Vendor", 23489, 32861)
    route = expand({ questSource, dealer })
    equal(#route, 1); equal(#route[1].mounts, 2)
    assert(route[1].targetStepIDs[700] and route[1].targetStepIDs[701])
end)

test("OR retains an accepted alternative while it waits for items", function()
    reset()
    local Q = P.RequireQuest
    P:RegisterChain("test.choice", { evidence = "test", requirements = { anyOf = { Q(90001), Q(90002) } }, quests = {
        { questID = 90001, scope = "character", mapID = 120, x = 1, y = 2 },
        { questID = 90002, scope = "character", mapID = 120, x = 3, y = 4, progress = { type = "item", id = 45192, count = 15 } },
    } })
    accepted[90002] = true
    local resolved = P:ResolveRequirement(P.RequireChain("test.choice"))
    equal(resolved.state, "waiting"); equal(#resolved.quests, 0)
    items[45192] = 15
    resolved = P:ResolveRequirement(P.RequireChain("test.choice"))
    equal(resolved.quests[1].questID, 90002)
    completed[90001] = true
    equal(P:ResolveRequirement(P.RequireChain("test.choice")).state, "completed")
    P.chains["test.choice"] = nil
end)

test("Tournament factions each share their intro across city vendors", function()
    for _, side in ipairs({ { "Alliance", "Human", 33307, 33310, 13667 }, { "Horde", "Orc", 33553, 33554, 13668 } }) do
        reset(); faction, race = side[1], side[2]
        local route = expand({ source(701, "Vendor", side[3], 1), source(702, "Vendor", side[4], 2) })
        equal(#route, 1); equal(route[1].prerequisiteQuest.questID, side[5]); equal(#route[1].mounts, 2)
    end
end)

test("Tournament AND prerequisites expose all three mastery quests, not the seal hand-in", function()
    reset(); completed[13667] = true
    local route = expand({ source(701, "Vendor", 33307, 45125) })
    local ids = questIDs(route)
    equal(#route, 3); assert(ids[13828] and ids[13837] and ids[13835]); assert(not ids[13672])
end)

test("Aspirant and Valiant seals wait while gathering and never count as permanent unlocks", function()
    reset(); completed[13828], completed[13837], completed[13835] = true, true, true
    local sources = { source(701, "Vendor", 33307, 45125) }
    equal(expand(sources)[1].prerequisiteQuest.questID, 13672)
    accepted[13672] = true
    equal(#expand(sources), 0); equal(P.diagnostics[1].status.state, "waiting")
    items[45192] = 15
    equal(expand(sources)[1].prerequisiteQuest.questID, 13672)
    completed[13672], accepted[13672], items[45192] = true, nil, 0
    equal(expand(sources)[1].prerequisiteQuest.questID, 13679)
    completed[13684], accepted[13718] = true, true
    equal(#expand(sources), 0)
    items[44987] = 25
    equal(expand(sources)[1].prerequisiteQuest.questID, 13718)
end)

test("bag updates resume a waiting seal turn-in through the actual filter/event path", function()
    reset(); completed[13828], completed[13837], completed[13835], accepted[13672] = true, true, true, true
    MRP.Data.STEPS = { source(701, "Vendor", 33307, 45125) }
    enable(); equal(#F.filteredSteps, 0)
    items[45192] = 15
    local warnings = 0
    MRP.UI.ShowPathfindingWarnings = function() warnings = warnings + 1 end
    frames[1].scripts.OnEvent(nil, "BAG_UPDATE_DELAYED"); flush()
    equal(currentQuest(), 13672)
    equal(warnings, 1, "existing bag-event behavior still runs")
end)

test("fresh home-city paths finish for both factions without missing or repeated prerequisites", function()
    for _, side in ipairs({ { "Alliance", "Human", 33307, 45125 }, { "Horde", "Orc", 33553, 45595 } }) do
        reset(); faction, race = side[1], side[2]
        local sources, visited, finished = { source(701, "Vendor", side[3], side[4]) }, {}, false
        for _ = 1, 20 do
            local route = expand(sources)
            assert(#route > 0, "chain unexpectedly blocked")
            if not route[1].prerequisiteQuest then finished = true; break end
            local q = route[1].prerequisiteQuest
            assert(not visited[q.questID], "repeated quest")
            visited[q.questID], completed[q.questID] = true, true
        end
        assert(finished, "never reached city vendor")
    end
end)

test("all five Crusader cities progress sequentially from a fresh character", function()
    reset(); standing = 8
    local sources, visited, finished = { source(701, "Vendor", 34885, 47180) }, {}, false
    for _ = 1, 40 do
        local route = expand(sources)
        assert(#route > 0, "Crusader path blocked")
        if not route[1].prerequisiteQuest then finished = true; break end
        local id = route[1].prerequisiteQuest.questID
        assert(not visited[id], "repeated city quest")
        visited[id], completed[id] = true, true
    end
    assert(finished)
    for _, city in ipairs(P.tournamentCities) do
        if city.faction == faction then assert(visited[city[7]], city[1] .. " was skipped") end
    end
end)

test("each Tournament city flag unlocks only that city's vendor", function()
    for _, city in ipairs(P.tournamentCities) do
        reset(); faction = city.faction; completed[city[7]] = true
        local sources = {}
        for i, other in ipairs(P.tournamentCities) do sources[#sources + 1] = source(800 + i, "Vendor", other[2], 800 + i) end
        local route, vendors = expand(sources), 0
        for _, step in ipairs(route) do
            if step.source.type == "Vendor" then vendors = vendors + 1; equal(step.source.npcID, city[2]) end
        end
        equal(vendors, 1)
    end
end)

test("an active Tournament city finishes before another selected city starts", function()
    reset(); completed[13702], completed[13703], accepted[13714] = true, true, true
    local sources = { source(701, "Vendor", 33653, 45591) } -- Darnassus selected, Ironforge active
    equal(#expand(sources), 0, "wait for active Ironforge seals")
    items[44987] = 25
    equal(expand(sources)[1].prerequisiteQuest.questID, 13714)
    completed[13713], accepted[13714] = true, nil
    equal(expand(sources)[1].prerequisiteQuest.questID, 13706)
end)

test("Crusader goals share a single city path and keep all six reputation gates", function()
    reset(); completed[13702] = true
    local crusader = source(701, "Vendor", 34885, 47180)
    local route = expand({ crusader })
    equal(#route, 1); equal(route[1].prerequisiteQuest.questID, 13703)
    for _, city in ipairs(P.tournamentCities) do if city.faction == faction then completed[city[7]], reputations[city[3]] = true, 8 end end
    equal(#expand({ crusader }), 0)
    reputations[1106] = 8
    equal(expand({ crusader })[1].source.npcID, 34885)
    reputations[47] = 7
    equal(#expand({ crusader }), 0)
end)

test("Argent Charger class restriction does not hide the Warhorse or create warrior errands", function()
    reset()
    local crusader = source(701, "Vendor", 34885, 47179)
    equal(#expand({ crusader }), 0)
    crusader.mounts[2] = mount(702, 47180)
    local route = expand({ crusader })
    equal(#route[1].mounts, 1); equal(route[1].mounts[1].itemId, 47180)
    class = "PALADIN"
    route = expand({ crusader }); equal(#route[1].mounts, 2)
end)

test("Silver Covenant and Sunreaver mounts require a champion and their own Exalted rank", function()
    for _, side in ipairs({ { "Alliance", "Human", 34881, 1094, 13702, 46815 }, { "Horde", "Orc", 34772, 1124, 13736, 46816 } }) do
        reset(); faction, race = side[1], side[2]
        local sources = { source(701, "Vendor", side[3], side[6]) }
        equal(#expand(sources), 1, "low rep must not block intro quests")
        completed[side[5]] = true
        equal(#expand(sources), 0)
        reputations[side[4]] = 8
        equal(expand(sources)[1].source.npcID, side[3])
    end
end)

test("Argent Hippogryph uses an unlocked city vendor rather than the generic coordinates", function()
    reset(); completed[13713] = true
    local route = expand({ source(701, "Vendor", nil, 45725) })
    equal(#route, 1); equal(P:GetNavigationEntry(route[1]).npcID, 33310)
end)

test("account achievements and quest flags cannot grant Tournament character eligibility", function()
    reset(); standing = 8
    for _, city in ipairs(P.tournamentCities) do account[city[7]], account[city[8]] = true, true end
    local route = expand({ source(701, "Vendor", 34885, 47180) })
    equal(route[1].prerequisiteQuest.questID, 13667)
end)

test("unverified race enrollment is held without blocking confirmed existing progress", function()
    reset(); race = "UnverifiedRace"
    local sources = { source(701, "Vendor", 33307, 45125) }
    equal(expand(sources)[1].prerequisiteQuest.questID, 13667)
    completed[13679] = true
    equal(#expand(sources), 0); equal(P.diagnostics[1].status.state, "unknown")
    completed[13699] = true
    equal(#expand(sources), 1)
end)

test("Retail bindings do not change Classic routing or unrelated sources", function()
    reset()
    WOW_PROJECT_ID = 2
    equal(#expand({ vendor }), 1)
    equal(P:GetMountAvailability(vendor, vendor.mounts[2]).unverified, true)
    WOW_PROJECT_ID = WOW_PROJECT_MAINLINE
    local unrelated = source(900, "Vendor", 999999, 999999)
    equal(#expand({ unrelated }), 1)
    equal(P:GetMountAvailability(unrelated, unrelated.mounts[1]).unverified, true)
end)

test("characters without a faction do not get an invented Tournament path", function()
    reset(); faction, race = "Neutral", "Pandaren"
    equal(#expand({ source(701, "Vendor", 34885, 47180) }), 0)
    equal(P.diagnostics[1].status.state, "unknown")
end)

test("unknown APIs and invalid graphs fail closed; cycles, missing refs and bad coordinates are rejected", function()
    reset()
    local saved = C_Item
    C_Item = nil
    equal(P:Evaluate({ type = "item", id = 45192, count = 15 }), nil)
    C_Item = saved
    local Q = P.RequireQuest
    P:RegisterChain("test.cycle", { evidence = "test", requirements = Q(90001), quests = {
        { questID = 90001, scope = "character", requires = Q(90002) },
        { questID = 90002, scope = "character", requires = Q(90001) },
    } })
    P:RegisterChain("test.missing", { evidence = "test", requirements = P.RequireChain("missing"), quests = {} })
    P:RegisterChain("test.location", { evidence = "test", requirements = Q(90003), quests = {
        { questID = 90003, scope = "character", mapID = 120, x = 150, y = 20 },
    } })
    local ok, errors = P:ValidateRegistry()
    equal(ok, false); equal(#errors, 3)
    completed[90001] = true
    equal(P:Evaluate(P.RequireChain("test.cycle")), nil)
    P.chains["test.cycle"], P.chains["test.missing"], P.chains["test.location"] = nil, nil, nil
    assert(P:ValidateRegistry())
end)

if arg[1] then
    test("published data binds every first-wave source by stable identity", function()
        reset()
        local data = { Internal = {} }
        assert(loadfile(arg[1] .. "/Steps/Standard/MRPData_Steps.lua"))("MountRoutePlannerData", data)
        assert(loadfile(arg[1] .. "/Mounts/Standard/MRPData_Mounts.lua"))("MountRoutePlannerData", data)
        MRP.Data.OPEN_WORLD = data.openWorld
        local npcs = { [32540] = true, [34881] = true, [34772] = true, [34885] = true }
        for _, city in ipairs(P.tournamentCities) do npcs[city[2]] = true end
        local items = { [43962] = true, [45725] = true }
        for _, drake in ipairs(P.netherwingDrakes) do items[drake.item] = true end
        for _, step in ipairs(data.Steps) do
            for _, mount in ipairs(step.mounts) do
                if npcs[step.source.npcID] or items[mount.itemId] then
                    assert(P:GetSupplement(step, mount), step.source.name .. " has no binding")
                    if step.source.npcID then npcs[step.source.npcID] = nil end
                    items[mount.itemId] = nil
                end
            end
        end
        equal(next(npcs), nil); equal(next(items), nil)
    end)
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
