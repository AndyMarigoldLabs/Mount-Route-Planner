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
local serverNow, serverReset, resetKnown, resetTimers, gossipNPC, gossipQuests, detailQuest
local seals, currencyKnown
C_CurrencyInfo = { GetCurrencyInfo = function(id)
    equal(id, 241)
    if currencyKnown then return { quantity = seals, totalEarned = 99999, quantityEarnedThisWeek = 99999 } end
end }
function GetServerTime() return serverNow end
C_DateAndTime = { GetSecondsUntilDailyReset = function() return resetKnown and math.max(0, serverReset - serverNow) or nil end }
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
C_Timer.NewTimer = function(delay, callback)
    local timer = { delay = delay, callback = callback }
    function timer:Cancel() self.cancelled = true end
    resetTimers[#resetTimers + 1] = timer
    return timer
end
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
C_Reputation = { GetFactionDataByID = function(id)
    local rank = reputations[id] or standing
    local points = { -42000, -6000, -3000, 0, 3000, 9000, 21000, 42000 }
    return { name = "Faction " .. id, reaction = rank, currentStanding = points[rank] + 100 }
end }
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
loadRuntime("MRP_Dailies.lua")
loadRuntime("Data/MRP_PrerequisiteData.lua")
loadRuntime("Data/MRP_UnlockNetherwing.lua")
loadRuntime("Data/MRP_UnlockTournament.lua")
loadRuntime("Data/MRP_UnlockDailies.lua")
loadRuntime("Data/MRP_ChampionDailies.lua")
loadRuntime("Data/MRP_HodirDailies.lua")
loadRuntime("MRP_UnlockRouting.lua")
loadRuntime("MRP_ChampionSeals.lua")
loadRuntime("MRP_HodirReputation.lua")
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
    serverNow, serverReset, resetKnown, resetTimers = 10000, 20000, true, {}
    seals, currencyKnown = 0, true
    gossipNPC, gossipQuests, detailQuest = nil, {}, nil
    P.dailyTimer, P.dailyOffers, P.dailyResetAt = nil, {}, nil
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
    for _, step in ipairs(steps) do if step.prerequisiteQuest and step.prerequisiteQuest.questID then ids[step.prerequisiteQuest.questID] = true end end
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

-- Exercise daily loops through the same filter, events and timer as the addon.
local function dailySetup(kind)
    reset()
    UnitGUID = function() return gossipNPC and ("Creature-0-0-0-0-" .. gossipNPC .. "-0000000000") end
    C_GossipInfo = { GetAvailableQuests = function() return gossipQuests end }
    GetQuestID = function() return detailQuest end
    MRP_CharacterSettings.filter.sourceTypes.Quest = true
    MRP.Data.STEPS = { kind == "netherwing" and source(710, "Quest", nil, 32857) or source(711, "Vendor", 33307, 45125) }
    if kind == "netherwing" then completed[11014], completed[11019] = true, true
    else accepted[13672] = true end
    P:SetDailiesEnabled(true)
end
local function offer(groupID, ids)
    gossipNPC, gossipQuests = P.dailyGroups[groupID].npcID, {}
    for _, id in ipairs(ids) do gossipQuests[#gossipQuests + 1] = { questID = id } end
    frames[1].scripts.OnEvent(nil, "GOSSIP_SHOW"); flush()
    gossipNPC = nil
end
local function turnIn(id)
    accepted[id], objectives[id] = nil, nil
    frames[1].scripts.OnEvent(nil, "QUEST_TURNED_IN", id); flush()
end
local function nextDay()
    serverNow, serverReset = serverReset + 1, serverReset + 86400
    for id in pairs(P.dailyQuests) do completed[id] = nil end -- simulate the server's daily flags
    local timer = P.dailyTimer
    assert(timer and not timer.cancelled, "reset watch missing")
    timer.callback(); flush()
end
local function dailyChecks(route)
    local checks = {}
    for _, step in ipairs(route) do
        if step.prerequisiteQuest and step.prerequisiteQuest.dailyGroup then checks[step.prerequisiteQuest.dailyGroup] = step end
    end
    return checks
end

test("daily opt-in migrates off, enables the unlock path, and cancels its timer when disabled", function()
    reset(); equal(MRP_CharacterSettings.includePrerequisiteDailies, false)
    MRP_CharacterSettings.includePrerequisiteDailies = nil
    MRP.Core:InitializeSettings(); equal(MRP_CharacterSettings.includePrerequisiteDailies, false)
    dailySetup("netherwing")
    assert(MRP_CharacterSettings.includePrerequisiteQuests and P.dailyTimer)
    equal(#F.filteredSteps, 2)
    local timer = P.dailyTimer
    P:SetDailiesEnabled(false)
    equal(#F.filteredSteps, 0); assert(timer.cancelled)
    P:SetDailiesEnabled(true); timer = P.dailyTimer
    P:SetEnabled(false); assert(timer.cancelled); equal(#F.filteredSteps, 0)
end)

test("Netherwing dailies require service and route their own one-time prerequisites", function()
    dailySetup("netherwing"); completed[11019] = nil; F:Apply()
    local ids = questIDs(F.filteredSteps)
    assert(ids[11019]); assert(dailyChecks(F.filteredSteps)["netherwing.daily.crystals"])
    assert(not dailyChecks(F.filteredSteps)["netherwing.daily.yarzill"])
    completed[11014] = nil; completed[10870] = true; F:Apply()
    equal(#F.filteredSteps, 1); equal(currentQuest(), 11012)
end)

test("Netherwing rank promotions open the confirmed daily branches through Exalted", function()
    dailySetup("netherwing")
    completed[11053], reputations[1015] = true, 5; F:Apply()
    local ids = questIDs(F.filteredSteps)
    assert(ids[11075] and ids[11054]); equal(#F.filteredSteps, 4, "shared mines introduction appears once")
    completed[11075], completed[11054] = true, true; F:Apply()
    equal(#F.filteredSteps, 5)
    assert(not dailyChecks(F.filteredSteps)["netherwing.daily.portal"])
    completed[11084], reputations[1015] = true, 6; F:Apply(); equal(#F.filteredSteps, 6)
    completed[11092], reputations[1015] = true, 7; F:Apply(); equal(#F.filteredSteps, 6)
    reputations[1015] = 8; F:Apply(); equal(#F.filteredSteps, 1); equal(currentQuest(), 11107)
    completed[11107] = true; F:Apply(); equal(currentQuest(), 11108)
    completed[11108] = true; F:Apply(); equal(currentQuest(), 11111)
end)

test("daily visits deduplicate shared mount goals and preserve selected source attribution", function()
    dailySetup("netherwing")
    MRP.Data.STEPS[2] = source(712, "Quest", nil, 32862); F:Apply()
    equal(#F.filteredSteps, 2)
    for _, step in ipairs(F.filteredSteps) do
        equal(#step.mounts, 2); assert(step.targetStepIDs[710] and step.targetStepIDs[712])
        assert(not MRP.Core:ShouldSkipStep(step)); assert(not MRP.Core:IsEncounterDefeated(step.mounts[1], step.source))
        equal(P:GetNavigationEntry(step).mapID, 104)
    end
    collected[710], collected[712] = true, true; F:Apply(); equal(#F.filteredSteps, 0)
    collected[710], collected[712] = nil, nil
    F:SetSourceType("Quest", false); equal(#F.filteredSteps, 0)
end)

test("gossip resolves daily visits into only actually offered quests", function()
    dailySetup("netherwing")
    offer("netherwing.daily.yarzill", { 11035 })
    local ids = questIDs(F.filteredSteps)
    assert(ids[11035] and not ids[11020]); equal(#F.filteredSteps, 2)
    offer("netherwing.daily.crystals", {})
    equal(#F.filteredSteps, 1); equal(currentQuest(), 11035)
    -- A single quest detail proves only that quest, not a complete NPC list.
    P.dailyOffers = {}; detailQuest = 11020
    frames[1].scripts.OnEvent(nil, "QUEST_DETAIL"); flush()
    assert(questIDs(F.filteredSteps)[11020]); assert(dailyChecks(F.filteredSteps)["netherwing.daily.yarzill"])
end)

test("Aspirant weapon rotation never invents three simultaneous offers or a second weapon reward", function()
    dailySetup("tournament"); equal(#F.filteredSteps, 3)
    local group = "argent.daily.aspirant.Alliance.weapon"
    offer(group, { 13669 })
    local ids = questIDs(F.filteredSteps)
    assert(ids[13669] and not ids[13666] and not ids[13670])
    accepted[13669] = true; P:QueueRefresh(); flush()
    assert(questIDs(F.filteredSteps)[13669]); assert(not dailyChecks(F.filteredSteps)[group])
    turnIn(13669)
    equal(#F.filteredSteps, 2); assert(not dailyChecks(F.filteredSteps)[group])
    nextDay(); equal(#F.filteredSteps, 3)
    offer(group, { 13670 }); assert(questIDs(F.filteredSteps)[13670])
end)

test("daily objectives use native waypoints, turn-in fallback and no invented objective location", function()
    dailySetup("netherwing"); accepted[11035] = true
    waypoints[11035] = { 104, 0.72, 0.81 }; F:Apply()
    local q = P.dailyQuests[11035]
    local location, phase = P:GetQuestDestination(q)
    equal(phase, "objective"); equal(location.x, 72)
    waypoints[11035] = nil; equal(P:GetQuestDestination(q), nil)
    objectives[11035] = true
    location, phase = P:GetQuestDestination(q); equal(phase, "turnIn"); equal(location.x, 65.9)
    turnIn(11035); equal(P:GetQuestDestination(q), nil)
end)

test("completed dailies stay suppressed across reload, but expire after an offline reset", function()
    dailySetup("netherwing"); turnIn(11015)
    equal(completed[11015], nil, "test simulates a delayed Blizzard completion flag")
    P.dailyOffers, P.dailyResetAt = {}, nil -- session observations are not saved
    P:StartDailyResetWatch(); F:Apply()
    assert(not dailyChecks(F.filteredSteps)["netherwing.daily.crystals"])
    serverNow, serverReset = serverReset + 100000, serverReset + 172800 -- login more than a day later
    P.dailyOffers, P.dailyResetAt = {}, nil; P:StartDailyResetWatch(); F:Apply()
    assert(dailyChecks(F.filteredSteps)["netherwing.daily.crystals"])
    assert(completed[11014] and completed[11019], "permanent history survives")
    equal(MRP_CharacterSettings.prerequisiteDailyState.completed[11015], nil)
end)

test("online reset refreshes empty routes and expires positive and negative offers", function()
    dailySetup("netherwing")
    offer("netherwing.daily.crystals", { 11015 })
    offer("netherwing.daily.yarzill", {})
    turnIn(11015); equal(#F.filteredSteps, 0)
    equal(P.diagnostics[1].status.state, "waiting")
    nextDay(); equal(#F.filteredSteps, 2); equal(next(P.dailyOffers), nil)
    offer("netherwing.daily.crystals", { 11015 })
    nextDay(); assert(dailyChecks(F.filteredSteps)["netherwing.daily.crystals"])
end)

test("the reset watch defers UI work during combat and refreshes on regeneration", function()
    dailySetup("netherwing"); turnIn(11015); turnIn(11020); turnIn(11035)
    equal(#F.filteredSteps, 0)
    combat = true; nextDay(); equal(#F.filteredSteps, 0); assert(P.refreshAfterCombat)
    combat = false; frames[1].scripts.OnEvent(nil, "PLAYER_REGEN_ENABLED"); flush()
    equal(#F.filteredSteps, 2)
end)

test("accepted dailies survive reset and retain their objective or ready turn-in", function()
    dailySetup("tournament"); accepted[13669] = true; objectives[13669] = true; F:Apply()
    local oldID
    for _, step in ipairs(F.filteredSteps) do if step.prerequisiteQuest.questID == 13669 then oldID = step.id end end
    nextDay()
    local found
    for _, step in ipairs(F.filteredSteps) do
        if step.prerequisiteQuest.questID == 13669 then
            found = true; assert(step.id ~= oldID)
            local _, phase = P:GetQuestDestination(step.prerequisiteQuest); equal(phase, "turnIn")
        end
    end
    assert(found); assert(not dailyChecks(F.filteredSteps)["argent.daily.aspirant.Alliance.weapon"])
end)

test("auto-advance off retains today's completed daily but never yesterday's stop", function()
    dailySetup("netherwing"); offer("netherwing.daily.crystals", { 11015 })
    for i, step in ipairs(F.filteredSteps) do if step.prerequisiteQuest.questID == 11015 then MRP_CharacterSettings.currentStep = i end end
    MRP_CharacterSettings.autoAdvance = false
    local oldID = F:GetCurrentStep().id
    turnIn(11015); equal(F:GetCurrentStep().id, oldID); assert(MRP.Core:ShouldSkipStep(F:GetCurrentStep()))
    nextDay()
    for _, step in ipairs(F.filteredSteps) do assert(step.id ~= oldID) end
    assert(dailyChecks(F.filteredSteps)["netherwing.daily.crystals"])
end)

test("unknown reset APIs fail closed for new dailies but preserve accepted quests", function()
    dailySetup("netherwing"); resetKnown = false; accepted[11020] = true; F:Apply()
    equal(#F.filteredSteps, 1); equal(currentQuest(), 11020)
    accepted[11020] = nil; F:Apply(); equal(#F.filteredSteps, 0)
    assert(P.diagnostics[1].status.message:find("Daily reset time is unavailable", 1, true))
    resetKnown = true; P.dailyTimer.callback(); flush(); equal(#F.filteredSteps, 2)
end)

test("server clock drift is tolerated but changed reset schedules invalidate cached daily state", function()
    dailySetup("netherwing"); turnIn(11015)
    serverReset = serverReset + 1; F:Apply()
    assert(not dailyChecks(F.filteredSteps)["netherwing.daily.crystals"])
    serverReset = serverReset + 3600; F:Apply()
    assert(dailyChecks(F.filteredSteps)["netherwing.daily.crystals"])
    local state = MRP_CharacterSettings.prerequisiteDailyState
    state.resetAt = "invalid"; F:Apply(); equal(type(state.resetAt), "string")
    equal(type(MRP_CharacterSettings.prerequisiteDailyState.resetAt), "number")
end)

test("empty NPC snapshots are invalidated after permanent unlock and reputation changes", function()
    dailySetup("netherwing"); offer("netherwing.daily.yarzill", {})
    assert(not dailyChecks(F.filteredSteps)["netherwing.daily.yarzill"])
    frames[1].scripts.OnEvent(nil, "UPDATE_FACTION"); flush()
    assert(dailyChecks(F.filteredSteps)["netherwing.daily.yarzill"])
    offer("netherwing.daily.yarzill", {})
    frames[1].scripts.OnEvent(nil, "QUEST_TURNED_IN", 11053); flush()
    assert(dailyChecks(F.filteredSteps)["netherwing.daily.yarzill"])
end)

test("abandoning a daily returns to its giver without undoing unlocks", function()
    dailySetup("netherwing"); accepted[11020] = true; F:Apply(); assert(questIDs(F.filteredSteps)[11020])
    accepted[11020] = nil; frames[1].scripts.OnEvent(nil, "QUEST_REMOVED", 11020); flush()
    assert(dailyChecks(F.filteredSteps)["netherwing.daily.yarzill"]); assert(completed[11014])
end)

test("a seal threshold immediately stops gathering and resumes the actual charge", function()
    dailySetup("tournament"); accepted[13625] = true
    items[45192] = 15; frames[1].scripts.OnEvent(nil, "BAG_UPDATE_DELAYED"); flush()
    equal(#F.filteredSteps, 1); equal(currentQuest(), 13672)
    items[45192] = 0; objectives[13672] = true; F:Apply(); equal(currentQuest(), 13672)
end)

test("all faction and city seal loops finish across resets without offering another city's quests", function()
    local cases = {
        { faction = "Alliance", charge = 13672, item = 45192, target = 15, challenge = 13679 },
        { faction = "Horde", charge = 13678, item = 45192, target = 15, challenge = 13680 },
    }
    for _, city in ipairs(P.tournamentCities) do
        cases[#cases + 1] = { faction = city.faction, charge = city[6], item = 44987, target = 25, challenge = city[7], city = city }
    end
    for _, case in ipairs(cases) do
        dailySetup("tournament"); accepted = { [case.charge] = true }; faction = case.faction
        race = faction == "Alliance" and "Human" or "Orc"
        local city = case.city
        MRP.Data.STEPS = { source(711, "Vendor", city and city[2] or (faction == "Alliance" and 33307 or 33553), 1) }
        if city then completed[city[4]] = true end
        F:Apply()
        for day = 1, case.target / 5 do
            equal(#F.filteredSteps, 3, "three daily givers for the active charge")
            local groups = P.sealDailyGroups[case.charge]
            for _, id in ipairs(groups) do
                local g, offers = P.dailyGroups[id], {}
                equal(g.faction, case.faction)
                for i, q in ipairs(g.quests) do if not g.rotation or i == (day % 3 + 1) then offers[#offers + 1] = q.questID end end
                offer(id, offers)
                for _, questID in ipairs(offers) do
                    assert(questIDs(F.filteredSteps)[questID], "offered daily missing: " .. questID .. " charge " .. case.charge .. " day " .. day)
                    items[case.item] = (items[case.item] or 0) + (g.rotation and 2 or (id:find("reins", 1, true) and 2 or 1))
                    turnIn(questID)
                end
            end
            if day < case.target / 5 then equal(#F.filteredSteps, 0); nextDay() end
        end
        equal(items[case.item], case.target); equal(#F.filteredSteps, 1); equal(currentQuest(), case.charge)
        completed[case.charge], accepted[case.charge], items[case.item] = true, nil, 0
        F:Apply(); equal(currentQuest(), case.challenge)
        completed[case.challenge] = true; F:Apply()
        if city then equal(F:GetCurrentStep().source.type, "Vendor") end
    end
end)

test("current daily offers override lagging completion flags, including the old weapon rotation", function()
    dailySetup("tournament")
    completed[13666], completed[13669] = true, true
    offer("argent.daily.aspirant.Alliance.weapon", { 13669 })
    assert(questIDs(F.filteredSteps)[13669]); assert(not questIDs(F.filteredSteps)[13666])
    equal(P:GetQuestDestination(P.dailyQuests[13669]).mapID, 118)
    turnIn(13669); assert(not questIDs(F.filteredSteps)[13669])
end)

test("accepted Netherwing dailies do not replay their historical setup", function()
    dailySetup("netherwing"); completed[11019] = nil; accepted[11020] = true; F:Apply()
    assert(questIDs(F.filteredSteps)[11020]); assert(not questIDs(F.filteredSteps)[11019])
end)

test("multiple Tournament mount goals share dailies and account flags cannot finish them", function()
    dailySetup("tournament")
    MRP.Data.STEPS[2] = source(712, "Vendor", 33310, 1)
    MRP.Data.STEPS[3] = source(713, "Vendor", 33310, 45725)
    F:Apply(); equal(#F.filteredSteps, 3)
    for _, step in ipairs(F.filteredSteps) do equal(#step.mounts, 3) end
    account[13669] = true; offer("argent.daily.aspirant.Alliance.weapon", { 13669 })
    assert(questIDs(F.filteredSteps)[13669])
end)

test("daily turn-ins are isolated per character and live daily flags are respected after login", function()
    dailySetup("netherwing"); turnIn(11015)
    local firstCharacter = MRP_CharacterSettings
    dailySetup("netherwing"); assert(dailyChecks(F.filteredSteps)["netherwing.daily.crystals"])
    completed[11015] = true; F:Apply()
    assert(not dailyChecks(F.filteredSteps)["netherwing.daily.crystals"])
    equal(firstCharacter.prerequisiteDailyState.completed[11015], true)
    equal(MRP_CharacterSettings.prerequisiteDailyState.completed[11015], nil)
end)

test("daily metadata validation rejects bad givers and broken preparation chains", function()
    local group = P.dailyGroups["netherwing.daily.crystals"]
    local npc, preparation = group.npcID, group.prepare
    group.npcID = 0; equal(P:ValidateRegistry(), false); assert(group.invalid)
    group.npcID, group.prepare = npc, P.RequireChain("missing.daily.chain")
    equal(P:ValidateRegistry(), false)
    group.prepare = preparation; equal(P:ValidateRegistry(), true); equal(group.invalid, nil)
end)

test("daily opt-in cannot bypass class, faction, unknown source gates or change Classic routing", function()
    dailySetup("tournament"); MRP.Data.STEPS = { source(711, "Vendor", 34885, 47179) }; F:Apply(); equal(#F.filteredSteps, 0)
    MRP.Data.STEPS = { source(711, "Vendor", 33553, 1) }; F:Apply(); equal(#F.filteredSteps, 0)
    MRP.Data.STEPS = { source(711, "Vendor", 33307, 1) }; MRP.Data.STEPS[1].requirements = { type = "unknown" }
    F:Apply(); equal(#F.filteredSteps, 0)
    MRP.Data.STEPS[1].requirements = nil
    WOW_PROJECT_ID = 2; F:Apply(); equal(F:GetCurrentStep().source.type, "Vendor"); WOW_PROJECT_ID = 1
end)

local function pricedSource(stepID, npc, mountID, itemID, price)
    local step = source(stepID, "Vendor", npc, itemID)
    MRP.Data.OPEN_WORLD[step.source.name] = step.entry
    step.mounts[1].id = mountID
    step.mounts[1].source.cost = { type = "currency", currencyId = 241, amount = price }
    return step
end
local function championSetup(side, playerClass)
    dailySetup("tournament")
    P:SetDailiesEnabled(false); P:SetEnabled(false)
    accepted = {}
    faction, class = side or "Alliance", playerClass or "WARRIOR"
    race = faction == "Alliance" and "Human" or "Orc"
    completed[faction == "Alliance" and 13702 or 13736] = true
    completed[class == "DEATHKNIGHT" and 13795 or 13794] = true
    MRP.Data.STEPS = { pricedSource(900, faction == "Alliance" and 33307 or 33553, 294, faction == "Alliance" and 45125 or 45595, 100) }
    P:SetChampionFarmingEnabled(true)
end
local function championIDs()
    local ids = {}
    for _, step in ipairs(F.filteredSteps) do
        local q = step.prerequisiteQuest
        if q and q.championSeals then ids[q.questID or q.dailyGroup] = true end
    end
    return ids
end

test("Champion farming migrates off and operates independently of unlock daily toggles", function()
    reset(); equal(MRP_CharacterSettings.includeChampionSealFarming, false)
    MRP_CharacterSettings.includeChampionSealFarming = nil; MRP.Core:InitializeSettings()
    equal(MRP_CharacterSettings.includeChampionSealFarming, false)
    championSetup(); equal(MRP_CharacterSettings.includePrerequisiteQuests, false)
    equal(MRP_CharacterSettings.includePrerequisiteDailies, false); equal(#F.filteredSteps, 3)
    P:SetEnabled(false); equal(#F.filteredSteps, 3); assert(P.dailyTimer)
    local timer = P.dailyTimer; P:SetChampionFarmingEnabled(false)
    assert(timer.cancelled); equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().source.type, "Vendor")
end)

test("Champion budget sums seal components once per mount and excludes collected goals", function()
    championSetup()
    local duplicate = pricedSource(901, 33307, 294, 45125, 100)
    local mixed = pricedSource(902, 33307, 321, 46752, 999)
    mixed.mounts[1].source.costs = { { type = "gold", amount = 5000000 }, { type = "currency", currencyId = 241, amount = 5 } }
    MRP.Data.STEPS[2], MRP.Data.STEPS[3] = duplicate, mixed
    seals = 35; F:Apply()
    equal(P.championBudget.total, 105); equal(P.championBudget.count, 2); equal(P.championBudget.remaining, 70)
    equal(#F.filteredSteps, 3)
    for _, step in ipairs(F.filteredSteps) do
        equal(#step.mounts, 2); assert(step.targetStepIDs[900] and step.targetStepIDs[901] and step.targetStepIDs[902])
    end
    collected[294] = true; F:Apply(); equal(P.championBudget.total, 5); equal(P.championBudget.remaining, 0)
    equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().source.type, "Vendor")
    equal(mixed.mounts[1].source.cost.amount, 999, "source data is immutable")
end)

test("the lowest verified selected alternative determines the budget and destination", function()
    championSetup()
    MRP.Data.STEPS[2] = pricedSource(901, 33307, 294, 45125, 80)
    seals = 80; F:Apply()
    equal(P.championBudget.total, 80); equal(P.championBudget.count, 1)
    equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().id, 901)
end)

test("price or currency API uncertainty pauses farming without inventing a zero balance", function()
    championSetup(); currencyKnown = false; F:Apply()
    equal(P.championBudget.quantity, nil); equal(#F.filteredSteps, 0)
    assert(P:GetChampionBudgetMessage():find("balance is unavailable", 1, true))
    currencyKnown = true
    for _, bad in ipairs({ 0, -1, 1.5, "100" }) do
        MRP.Data.STEPS[1].mounts[1].source.cost.amount = bad; F:Apply()
        equal(P.championBudget.unknownCost, true); equal(#F.filteredSteps, 0)
    end
    MRP.Data.STEPS[1].mounts[1].source.cost = nil; F:Apply(); equal(#F.filteredSteps, 0)
    MRP.Data.STEPS[1].mounts[1].source.cost = { type = "currency", currencyId = 241, amount = 100 }
    F:Apply(); equal(#F.filteredSteps, 3); equal(P.championBudget.quantity, 0)
end)

test("currency gains stop farming exactly at the full selected budget and spending resumes it", function()
    championSetup(); seals = 99
    frames[1].scripts.OnEvent(nil, "CURRENCY_DISPLAY_UPDATE", 241); flush()
    equal(P.championBudget.remaining, 1); equal(#F.filteredSteps, 3)
    seals = 100; frames[1].scripts.OnEvent(nil, "CURRENCY_DISPLAY_UPDATE", 241); flush()
    equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().source.type, "Vendor")
    seals = 90; frames[1].scripts.OnEvent(nil, "CURRENCY_DISPLAY_UPDATE", 241); flush()
    equal(#F.filteredSteps, 3); equal(P.championBudget.remaining, 10)
end)

test("purchases recalculate the remaining goal before the mount is learned", function()
    championSetup()
    MRP.Data.STEPS[2] = pricedSource(901, 33307, 321, 46752, 5)
    seals = 105; F:Apply(); equal(P.championBudget.remaining, 0); equal(#F.filteredSteps, 2)
    seals, items[45125] = 5, 1
    frames[1].scripts.OnEvent(nil, "CURRENCY_DISPLAY_UPDATE", 241)
    frames[1].scripts.OnEvent(nil, "BAG_UPDATE_DELAYED"); flush()
    equal(P.championBudget.total, 5); equal(P.championBudget.remaining, 0)
    equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().mounts[1].id, 321)
    items[45125], collected[294] = nil, true
    frames[1].scripts.OnEvent(nil, "NEW_MOUNT_ADDED", 294); flush()
    equal(P.championBudget.total, 5)
    seals, items[46752] = 0, 1; frames[1].scripts.OnEvent(nil, "MERCHANT_UPDATE"); flush()
    equal(P.championBudget.count, 0); equal(#F.filteredSteps, 0)
end)

test("an owned item removes all alternative listings of the same mount from the budget", function()
    championSetup(); MRP.Data.STEPS[2] = pricedSource(901, 33307, 294, 99999, 100)
    items[99999] = 1; F:Apply(); equal(P.championBudget.total, 0); equal(#F.filteredSteps, 0)
end)

test("changing filters cancels orphan Champion farming and recalculates the goal", function()
    championSetup()
    F:SetSourceType("Vendor", false); equal(P.championBudget.total, 0); equal(#F.filteredSteps, 0)
    F:SetSourceType("Vendor", true); equal(P.championBudget.total, 100); equal(#F.filteredSteps, 3)
    collected[294] = true; F:Apply(); equal(P.championBudget.count, 0); equal(#F.filteredSteps, 0)
end)

test("Champion farming respects faction, Paladin restrictions and unknown source gates", function()
    championSetup()
    MRP.Data.STEPS[2] = pricedSource(901, 34885, 338, 47179, 100)
    MRP.Data.STEPS[3] = pricedSource(902, 33553, 300, 45595, 100)
    local unsupported = pricedSource(903, 33307, 321, 46752, 5)
    unsupported.requirements = { type = "unknown" }; MRP.Data.STEPS[4] = unsupported
    F:Apply(); equal(P.championBudget.total, 100); equal(P.championBudget.count, 1)
    class = "PALADIN"; F:Apply(); equal(P.championBudget.total, 200); equal(P.championBudget.count, 2)
    WOW_PROJECT_ID = 2; F:Apply(); equal(P.championBudget, nil); equal(next(championIDs()), nil); WOW_PROJECT_ID = 1
end)

test("all four faction and class variants use the correct core Champion daily IDs", function()
    for _, row in ipairs({
        { "Alliance", "WARRIOR", 13790, 13789, 13861, 13682 },
        { "Horde", "WARRIOR", 13811, 13810, 13862, 13809 },
        { "Alliance", "DEATHKNIGHT", 13793, 13791, 13864, 13788 },
        { "Horde", "DEATHKNIGHT", 13814, 13813, 13863, 13812 },
    }) do
        championSetup(row[1], row[2]); completed[13664] = true; F:Apply()
        equal(#F.filteredSteps, 4)
        for i = 3, 6 do
            local q = P.dailyQuests[row[i]]
            local g = P.dailyGroups[q.dailyGroupID]
            local offered = { row[i] }
            -- The citadel and Threat From Above share a gossip window.
            if i >= 5 then offered = { row[5], row[6] } end
            offer(g.id, offered)
        end
        local ids = questIDs(F.filteredSteps)
        equal(#F.filteredSteps, 4)
        for i = 3, 6 do assert(ids[row[i]], "wrong daily variant") end
    end
end)

test("Threat From Above requires its Black Knight unlock unless actually offered or accepted", function()
    championSetup()
    assert(not championIDs()["argent.champion.Alliance.other.threat"])
    offer("argent.champion.Alliance.other.citadel", { 13861 })
    assert(not questIDs(F.filteredSteps)[13682])
    accepted[13682] = true; F:Apply(); assert(questIDs(F.filteredSteps)[13682])
    accepted[13682] = nil; completed[13664] = true; F:Apply()
    offer("argent.champion.Alliance.other.threat", { 13861, 13682 }); assert(questIDs(F.filteredSteps)[13682])
end)

test("Champion and Exalted/Crusader access comes from this character, not account achievements", function()
    championSetup(); completed = {}; account[13702] = true; F:Apply()
    equal(#F.filteredSteps, 0); assert(P.diagnostics[1].status.message:find("Become a Champion", 1, true))
    completed[13702], completed[13794] = true, true; F:Apply(); equal(#F.filteredSteps, 3)
    reputations[1094] = 8; F:Apply(); equal(#F.filteredSteps, 6)
    for _, city in ipairs(P.tournamentCities) do if city.faction == "Alliance" then completed[city[7]], reputations[city[3]] = true, 8 end end
    reputations[1106] = 8; F:Apply(); equal(#F.filteredSteps, 8)
    completed[13713] = nil; F:Apply(); equal(#F.filteredSteps, 6)
end)

test("Exalted and Crusader rotating dailies route only offered alternatives", function()
    championSetup(); standing = 8
    for _, city in ipairs(P.tournamentCities) do if city.faction == "Alliance" then completed[city[7]] = true end end
    F:Apply()
    offer("argent.champion.Alliance.exalted.rescue", { 14080, 14096 })
    offer("argent.champion.Alliance.exalted.food", { 14112 })
    offer("argent.champion.crusader.adelard", { 14102 })
    offer("argent.champion.crusader.silverdawn", { 14108 })
    local ids = questIDs(F.filteredSteps)
    for _, id in ipairs({ 14080, 14096, 14112, 14102, 14108 }) do assert(ids[id]) end
    for _, id in ipairs({ 14074, 14152, 14077, 14076, 14090, 14105, 14101, 14104, 14107 }) do assert(not ids[id]) end
    turnIn(14102); assert(not championIDs()["argent.champion.crusader.adelard"])
    nextDay(); assert(championIDs()["argent.champion.crusader.adelard"])
end)

test("neutral Crusader dailies use the current faction's milestones", function()
    championSetup(); standing = 8
    for _, city in ipairs(P.tournamentCities) do if city.faction == "Horde" then completed[city[7]] = true end end
    F:Apply(); assert(not championIDs()["argent.champion.crusader.adelard"])
    for _, city in ipairs(P.tournamentCities) do if city.faction == "Alliance" then completed[city[7]] = true end end
    F:Apply(); assert(championIDs()["argent.champion.crusader.adelard"])
    reputations[72] = 7; F:Apply(); assert(not championIDs()["argent.champion.crusader.adelard"])
    -- An accepted quest is direct evidence even if old milestone flags are absent.
    accepted[14102] = true; F:Apply(); assert(questIDs(F.filteredSteps)[14102])
end)

test("skippable Champion introductions do not replay after actual daily access is observed", function()
    championSetup(); completed[13794] = nil; F:Apply(); assert(questIDs(F.filteredSteps)[13794])
    offer("argent.champion.Alliance.other.field", { 13789 })
    assert(not questIDs(F.filteredSteps)[13794]); equal(MRP_CharacterSettings.championDailyAccess["Alliance.other"], true)
    nextDay(); assert(not questIDs(F.filteredSteps)[13794])
    P.dailyOffers = {}; F:Apply(); assert(not questIDs(F.filteredSteps)[13794])
end)

test("the first Champion Rises handoff is routed before Champion seal dailies", function()
    championSetup(); completed[13702], completed[13794], completed[13699] = nil, nil, true
    F:Apply(); equal(#F.filteredSteps, 1); equal(currentQuest(), 13702)
    completed[13702] = true; F:Apply(); assert(questIDs(F.filteredSteps)[13794])
    assert(championIDs()["argent.champion.Alliance.other.melee"])
end)

test("seals do not bypass a selected vendor's reputation or city prerequisites", function()
    championSetup()
    MRP.Data.STEPS = { pricedSource(900, 34881, 329, 46813, 150) }
    F:Apply(); equal(#F.filteredSteps, 3)
    seals = 150; F:Apply(); equal(#F.filteredSteps, 0)
    reputations[1094] = 8; F:Apply(); equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().source.npcID, 34881)
end)

test("Champion farming spans daily resets until enough seals are actually credited", function()
    championSetup(); MRP.Data.STEPS[1].mounts[1].source.cost.amount = 5
    for day = 1, 2 do
        F:Apply()
        for _, id in ipairs({ 13790, 13789, 13861 }) do
            if P.championBudget.remaining > 0 then
                offer(P.dailyQuests[id].dailyGroupID, { id })
                accepted[id] = true; F:Apply(); assert(questIDs(F.filteredSteps)[id])
                turnIn(id)
                -- Quest turn-in/purse predictions must not credit currency.
                equal(P.championBudget.quantity, seals)
                seals = seals + 1
                frames[1].scripts.OnEvent(nil, "CURRENCY_DISPLAY_UPDATE", 241); flush()
            end
        end
        if day == 1 then equal(#F.filteredSteps, 0); nextDay(); equal(#F.filteredSteps, 3) end
    end
    equal(seals, 5); equal(P.championBudget.remaining, 0)
    equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().source.type, "Vendor")
    nextDay(); equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().source.type, "Vendor")
end)

test("Champion reset recovery retains carried quests and expires reload/offline completions", function()
    championSetup(); accepted[13789] = true; objectives[13789] = true; turnIn(13790)
    P.dailyOffers, P.dailyResetAt = {}, nil; P:StartDailyResetWatch(); F:Apply()
    assert(not championIDs()["argent.champion.Alliance.other.melee"])
    nextDay(); assert(championIDs()["argent.champion.Alliance.other.melee"])
    assert(questIDs(F.filteredSteps)[13789])
    local _, phase = P:GetQuestDestination(P.dailyQuests[13789]); equal(phase, "turnIn")
    turnIn(13790); serverNow, serverReset = serverReset + 100000, serverReset + 172800
    P.dailyOffers, P.dailyResetAt = {}, nil; P:StartDailyResetWatch(); F:Apply()
    assert(championIDs()["argent.champion.Alliance.other.melee"])
end)

test("Champion farming waits for an unknown reset while preserving accepted quest navigation", function()
    championSetup(); offer("argent.champion.Alliance.other.melee", { 13790 })
    accepted[13789] = true; waypoints[13789] = { 118, 0.45, 0.5 }
    resetKnown = false; F:Apply()
    equal(#F.filteredSteps, 1); equal(currentQuest(), 13789)
    local location, phase = P:GetQuestDestination(P.dailyQuests[13789])
    equal(phase, "objective"); equal(location.x, 45); equal(location.y, 50)
    P:StartDailyResetWatch(); equal(P.dailyTimer.delay, 60)
    -- Recovery beyond the boundary discards yesterday's cached offer.
    resetKnown = true; nextDay()
    assert(championIDs()["argent.champion.Alliance.other.melee"])
    assert(not questIDs(F.filteredSteps)[13790]); assert(questIDs(F.filteredSteps)[13789])
end)

test("reaching the seal budget drops completed farming stops even with auto-advance disabled", function()
    championSetup(); offer("argent.champion.Alliance.other.field", { 13789 })
    for i, step in ipairs(F.filteredSteps) do if step.prerequisiteQuest.questID == 13789 then MRP_CharacterSettings.currentStep = i end end
    MRP_CharacterSettings.autoAdvance = false
    turnIn(13789); equal(currentQuest(), 13789)
    seals = 100; frames[1].scripts.OnEvent(nil, "CURRENCY_DISPLAY_UPDATE", 241); flush()
    equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().source.type, "Vendor")
end)

test("Champion currency and reset refreshes defer during combat and resume automatically", function()
    championSetup(); combat = true; seals = 100
    frames[1].scripts.OnEvent(nil, "CURRENCY_DISPLAY_UPDATE", 241); flush()
    equal(#F.filteredSteps, 3); assert(P.refreshAfterCombat)
    combat = false; frames[1].scripts.OnEvent(nil, "PLAYER_REGEN_ENABLED"); flush()
    equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().source.type, "Vendor")
end)

if arg[1] then
    test("published Tournament prices produce the expected faction and Paladin budgets", function()
        local data = { Internal = {} }
        assert(loadfile(arg[1] .. "/Steps/Standard/MRPData_Steps.lua"))("MountRoutePlannerData", data)
        assert(loadfile(arg[1] .. "/Mounts/Standard/MRPData_Mounts.lua"))("MountRoutePlannerData", data)
        for _, side in ipairs({ "Alliance", "Horde" }) do
            championSetup(side)
            MRP.Data.STEPS, MRP.Data.OPEN_WORLD = data.Steps, data.openWorld
            MRP.Data.DUNGEONS, MRP.Data.RAIDS, MRP.Data.WORLD_BOSSES = data.dungeons, data.raids, data.worldBosses
            F:Apply()
            equal(P.championBudget.count, 14); equal(P.championBudget.total, 1025)
            class = "PALADIN"; F:Apply(); equal(P.championBudget.count, 15); equal(P.championBudget.total, 1125)
        end
    end)
end

local function hodirSetup(side, prepared)
    dailySetup("tournament"); P:SetDailiesEnabled(false); P:SetEnabled(false)
    accepted = {}; faction = side or "Alliance"
    unlocked(); standing = 5
    MRP.Data.STEPS = { vendor }
    if prepared ~= false then
        for _, id in ipairs({ 12924, 12966, 12967, 12975, 12976, 12985, 12987, 13001 }) do completed[id] = true end
    end
    P:SetHodirFarmingEnabled(true)
end
local function hodirCount()
    local count = 0
    for _, step in ipairs(F.filteredSteps) do if step.prerequisiteQuest and step.prerequisiteQuest.hodirReputation then count = count + 1 end end
    return count
end
local function hodirDetail(id)
    detailQuest = id; frames[1].scripts.OnEvent(nil, "QUEST_DETAIL"); flush(); detailQuest = nil
end

test("Hodir farming defaults off, migrates off and runs independently of other opt-ins", function()
    reset(); equal(MRP_CharacterSettings.includeHodirReputationFarming, false)
    MRP_CharacterSettings.includeHodirReputationFarming = nil; MRP.Core:InitializeSettings()
    equal(MRP_CharacterSettings.includeHodirReputationFarming, false)
    hodirSetup(); equal(hodirCount(), 3)
    equal(MRP_CharacterSettings.includePrerequisiteQuests, false)
    equal(MRP_CharacterSettings.includePrerequisiteDailies, false)
    equal(MRP_CharacterSettings.includeChampionSealFarming, false)
    P:SetEnabled(false); equal(hodirCount(), 3); assert(P.dailyTimer)
    local timer = P.dailyTimer; P:SetHodirFarmingEnabled(false)
    equal(hodirCount(), 0); assert(timer.cancelled)
end)

test("both factions choose Revered for Ice Mammoth and Exalted for Grand Ice Mammoth", function()
    for _, side in ipairs({ "Alliance", "Horde" }) do
        hodirSetup(side); equal(P.hodirTarget.rank, 8); equal(P.hodirTarget.count, 2)
        local ice, grand = side == "Alliance" and 259 or 258, side == "Alliance" and 289 or 288
        for _, step in ipairs(F.filteredSteps) do equal(#step.mounts, 2) end
        collected[grand] = true; F:Apply(); equal(P.hodirTarget.rank, 7); equal(P.hodirTarget.count, 1)
        standing = 7; frames[1].scripts.OnEvent(nil, "UPDATE_FACTION"); flush()
        equal(hodirCount(), 0); equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().mounts[1].id, ice)
        collected[grand] = nil; F:Apply(); equal(P.hodirTarget.rank, 8); equal(hodirCount(), 6)
        local purchases = 0
        for _, step in ipairs(F.filteredSteps) do if step.source.type == "Vendor" then purchases = purchases + 1; equal(step.mounts[1].id, ice) end end
        equal(purchases, 1)
        standing = 8; frames[1].scripts.OnEvent(nil, "UPDATE_FACTION"); flush()
        equal(hodirCount(), 0); equal(#F.filteredSteps, 1); equal(#F:GetCurrentStep().mounts, 2)
    end
end)

test("Hodir targets deduplicate listings and exclude purchased but unlearned mammoths", function()
    hodirSetup()
    local duplicate = source(905, "Vendor", 32540, 43961); duplicate.mounts[1].id = 289
    MRP.Data.STEPS[2] = duplicate; F:Apply()
    equal(P.hodirTarget.rank, 8); equal(P.hodirTarget.count, 2); equal(hodirCount(), 3)
    for _, step in ipairs(F.filteredSteps) do equal(#step.mounts, 2); assert(step.targetStepIDs[51] and step.targetStepIDs[905]) end
    items[43961] = 1; frames[1].scripts.OnEvent(nil, "BAG_UPDATE_DELAYED"); flush()
    equal(P.hodirTarget.rank, 7); equal(P.hodirTarget.count, 1)
    items[43958] = 1; F:Apply(); equal(P.hodirTarget.rank, nil); equal(#F.filteredSteps, 0)
end)

test("Hodir farming disappears when filters or collected mounts remove its goals", function()
    hodirSetup(); F:SetSourceType("Vendor", false); equal(hodirCount(), 0); equal(P.hodirTarget.count, 0)
    F:SetSourceType("Vendor", true); equal(hodirCount(), 3)
    collected[259], collected[289] = true, true; F:Apply(); equal(hodirCount(), 0)
    equal(P.hodirTarget.rank, nil)
end)

test("Hodir opt-in preserves source restrictions, unknown gates and Classic behavior", function()
    hodirSetup(); vendor.requirements = { type = "unsupported" }; F:Apply()
    equal(hodirCount(), 0); equal(P.hodirTarget.count, 0)
    vendor.requirements = nil; MRP.Data.OPEN_WORLD.Lillehoff.conditions = { "horde_only" }; F:Apply()
    equal(hodirCount(), 0); equal(P.hodirTarget.count, 0)
    MRP.Data.OPEN_WORLD.Lillehoff.conditions = nil
    WOW_PROJECT_ID = 2; F:Apply(); equal(P.hodirTarget, nil); equal(hodirCount(), 0); WOW_PROJECT_ID = 1
end)

test("Hodir rank data must be available and valid before creating reputation errands", function()
    hodirSetup(); local api = C_Reputation.GetFactionDataByID
    for _, bad in ipairs({ false, "5", 0, 9, 5.5 }) do
        C_Reputation.GetFactionDataByID = function() return { reaction = bad, currentStanding = 42000 } end
        F:Apply(); equal(P.hodirTarget.standing, nil); equal(hodirCount(), 0)
        assert(P:GetHodirTargetMessage():find("unavailable", 1, true))
    end
    C_Reputation.GetFactionDataByID = api; F:Apply(); equal(hodirCount(), 3)
end)

test("Hodir daily visits obey Neutral, Friendly, Honored and Revered gates", function()
    hodirSetup()
    for rank, count in pairs({ [4] = 2, [5] = 3, [6] = 5, [7] = 6, [8] = 0 }) do
        standing = rank; F:Apply(); equal(hodirCount(), count)
    end
    equal(P.dailyQuests[13559], nil); equal(P.dailyQuests[13421], nil, "repeatable turn-ins are not dailies")
end)

test("Retail reputation ranks use reaction, never the point total in currentStanding", function()
    hodirSetup(); local api = C_Reputation.GetFactionDataByID
    MRP.Data.OPEN_WORLD.Lillehoff.conditions = { "rep_1119_7" }
    C_Reputation.GetFactionDataByID = function() return { reaction = 5, currentStanding = 8999 } end
    F:Apply(); equal(P.hodirTarget.standing, 5); equal(hodirCount(), 3)
    equal(P:Evaluate(P.RequireReputation(1119, 7)), false)
    equal(MRP.Util.GetStepConditions(vendor)[1].met, false)
    C_Reputation.GetFactionDataByID = function() return { reaction = 8, currentStanding = 42000 } end
    F:Apply(); equal(hodirCount(), 0); equal(#F.filteredSteps, 1)
    equal(P:Evaluate(P.RequireReputation(1119, 8)), true)
    equal(MRP.Util.GetStepConditions(vendor)[1].met, true)
    C_Reputation.GetFactionDataByID = function() return { currentStanding = 42000 } end
    equal(P:Evaluate(P.RequireReputation(1119, 7)), nil)
    equal(MRP.Util.GetStepConditions(vendor)[1].met, false)
    C_Reputation.GetFactionDataByID = api
end)

test("Hodir initial phasing remains character-specific and separate from reputation opt-in", function()
    hodirSetup(nil, false); completed = {}; account[12915], account[12956] = true, true
    F:Apply(); equal(#F.filteredSteps, 0)
    assert(P.diagnostics[1].status.message:find("Unlock the Sons of Hodir", 1, true))
    P:SetEnabled(true); equal(currentQuest(), 12843)
    P:SetEnabled(false); standing = 8; F:Apply(); equal(#F.filteredSteps, 0, "Exalted cannot bypass phasing")
end)

test("Hodir anvil setup accepts the parent before child quests and turns it in afterward", function()
    hodirSetup(nil, false); equal(#F.filteredSteps, 1); equal(currentQuest(), 12924)
    accepted[12924] = true; frames[1].scripts.OnEvent(nil, "QUEST_ACCEPTED", 12924); flush()
    equal(#F.filteredSteps, 1); equal(currentQuest(), 12966)
    accepted[12924] = nil; frames[1].scripts.OnEvent(nil, "QUEST_REMOVED", 12924); flush()
    equal(currentQuest(), 12924, "abandoning parent restores acceptance")
    accepted[12924], accepted[12966] = true, true; F:Apply()
    completed[12966] = true; turnIn(12966); equal(currentQuest(), 12967)
    completed[12967], objectives[12924] = true, true; turnIn(12967)
    local ids = questIDs(F.filteredSteps)
    assert(ids[12924] and ids[12985]); assert(dailyChecks(F.filteredSteps)["storm.hodir.daily.cold"])
    local _, phase = P:GetQuestDestination(P.chains["storm.hodir.alliance"].nodes["character:12924"])
    equal(phase, "turnIn")
    completed[12924] = true; turnIn(12924); assert(questIDs(F.filteredSteps)[12975])
    completed[12975] = true; turnIn(12975); assert(questIDs(F.filteredSteps)[12976])
    completed[12976], completed[12985] = true, true; F:Apply(); assert(questIDs(F.filteredSteps)[12987])
    completed[12987] = true; F:Apply(); equal(hodirCount(), 3)
    standing = 6; frames[1].scripts.OnEvent(nil, "UPDATE_FACTION"); flush()
    assert(questIDs(F.filteredSteps)[13001]); assert(dailyChecks(F.filteredSteps)["storm.hodir.daily.spy"])
    completed[13001] = true; F:Apply(); equal(hodirCount(), 5)
    nextDay(); equal(hodirCount(), 5); assert(completed[12924] and completed[12967] and completed[13001])
end)

test("active-parent requirements never count account completion or persist fake completion", function()
    hodirSetup(nil, false)
    local req = P.chains["storm.hodir.anvil"].nodes["character:12966"].requires
    account[12924] = true; equal(P:Evaluate(req), false)
    accepted[12924] = true; equal(P:Evaluate(req), true); equal(P:IsQuestComplete(12924), false)
    accepted[12924] = nil; equal(P:Evaluate(req), false)
    req.scope = "account"; equal(P:Evaluate(req), nil); equal(P:ValidateRegistry(), false)
    req.scope = "character"; equal(P:ValidateRegistry(), true)
end)

test("Hodir object details confirm real offers and route objective and turn-in phases", function()
    hodirSetup(); hodirDetail(12981)
    assert(questIDs(F.filteredSteps)[12981]); assert(not dailyChecks(F.filteredSteps)["storm.hodir.daily.cold"])
    accepted[12981] = true; waypoints[12981] = { 120, 0.75, 0.5 }
    frames[1].scripts.OnEvent(nil, "QUEST_ACCEPTED", 12981); flush()
    local location, phase = P:GetQuestDestination(P.dailyQuests[12981]); equal(phase, "objective"); equal(location.x, 75)
    objectives[12981], waypoints[12981] = true, nil
    location, phase = P:GetQuestDestination(P.dailyQuests[12981]); equal(phase, "turnIn"); equal(location.x, 63.2)
    turnIn(12981); assert(not questIDs(F.filteredSteps)[12981]); assert(not dailyChecks(F.filteredSteps)["storm.hodir.daily.cold"])
    equal(MRP_CharacterSettings.prerequisiteDailyState.completed[12981], true)
end)

test("Hodir object gossip snapshots distinguish objects from NPCs and accept empty lists", function()
    hodirSetup(); local guid = UnitGUID
    UnitGUID = function() return "Creature-0-0-0-0-192071-0000000000" end
    gossipQuests = { { questID = 12981 } }; frames[1].scripts.OnEvent(nil, "GOSSIP_SHOW"); flush()
    assert(not questIDs(F.filteredSteps)[12981])
    UnitGUID = function() return "GameObject-0-0-0-0-192071-0000000000" end
    frames[1].scripts.OnEvent(nil, "GOSSIP_SHOW"); flush(); assert(questIDs(F.filteredSteps)[12981])
    gossipQuests = {}; frames[1].scripts.OnEvent(nil, "GOSSIP_SHOW"); flush()
    assert(not questIDs(F.filteredSteps)[12981]); assert(not dailyChecks(F.filteredSteps)["storm.hodir.daily.cold"])
    UnitGUID = guid; nextDay(); assert(dailyChecks(F.filteredSteps)["storm.hodir.daily.cold"])
end)

test("observed Hodir daily access skips only its own setup across resets and reloads", function()
    hodirSetup(nil, false); hodirDetail(12981)
    assert(questIDs(F.filteredSteps)[12981]); equal(MRP_CharacterSettings.hodirDailyAccess["storm.hodir.daily.cold"], true)
    equal(MRP_CharacterSettings.hodirDailyAccess["storm.hodir.daily.horn"], nil)
    nextDay(); assert(dailyChecks(F.filteredSteps)["storm.hodir.daily.cold"])
    assert(questIDs(F.filteredSteps)[12924], "other setup paths still need their own evidence")
    P.dailyOffers, P.dailyResetAt = {}, nil; P:StartDailyResetWatch(); F:Apply()
    assert(dailyChecks(F.filteredSteps)["storm.hodir.daily.cold"])
end)

test("available or accepted Hodir dailies take precedence over missing historical flags", function()
    hodirSetup(nil, false); completed[12915], completed[12956] = nil, nil
    accepted[12994] = true; F:Apply(); assert(questIDs(F.filteredSteps)[12994])
    hodirDetail(13046); assert(questIDs(F.filteredSteps)[13046])
    equal(#F.filteredSteps, 2); equal(P:IsQuestComplete(12915), false)
end)

test("Hodir daily completions expire at reset, with offline and reload recovery", function()
    hodirSetup(); turnIn(12981); turnIn(12977); turnIn(13006)
    equal(hodirCount(), 0); equal(P.hodirTarget.needed, true)
    P.dailyOffers, P.dailyResetAt = {}, nil; P:StartDailyResetWatch(); F:Apply(); equal(hodirCount(), 0)
    nextDay(); equal(hodirCount(), 3)
    turnIn(12981); serverNow, serverReset = serverReset + 100000, serverReset + 172800
    P.dailyOffers, P.dailyResetAt = {}, nil; P:StartDailyResetWatch(); F:Apply(); equal(hodirCount(), 3)
    assert(completed[12987], "permanent setup survived resets")
end)

test("Hodir farming preserves carried quests and suppresses stale offers when reset data is missing", function()
    hodirSetup(); hodirDetail(12981); accepted[12977], objectives[12977] = true, true
    resetKnown = false; F:Apply(); equal(hodirCount(), 1); equal(currentQuest(), 12977)
    local _, phase = P:GetQuestDestination(P.dailyQuests[12977]); equal(phase, "turnIn")
    resetKnown = true; nextDay(); equal(hodirCount(), 3)
    assert(questIDs(F.filteredSteps)[12977]); assert(not questIDs(F.filteredSteps)[12981])
end)

test("Hodir reputation targets advance only from actual reputation updates over multiple days", function()
    hodirSetup(); collected[289] = true; standing = 6; F:Apply()
    for day = 1, 2 do
        for _, id in ipairs({ 12981, 12977, 13006, 12994, 13003 }) do turnIn(id) end
        equal(P.hodirTarget.standing, 6); equal(hodirCount(), 0)
        if day == 1 then nextDay(); equal(hodirCount(), 5) end
    end
    standing = 7; frames[1].scripts.OnEvent(nil, "UPDATE_FACTION"); flush()
    equal(hodirCount(), 0); equal(#F.filteredSteps, 1); equal(F:GetCurrentStep().source.type, "Vendor")
    nextDay(); equal(hodirCount(), 0)
end)

test("reaching the Hodir target removes retained completed stops even with auto-advance off", function()
    hodirSetup(); collected[289] = true; hodirDetail(12981)
    for i, step in ipairs(F.filteredSteps) do if step.prerequisiteQuest.questID == 12981 then MRP_CharacterSettings.currentStep = i end end
    MRP_CharacterSettings.autoAdvance = false; turnIn(12981); equal(currentQuest(), 12981)
    standing = 7; frames[1].scripts.OnEvent(nil, "UPDATE_FACTION"); flush()
    equal(hodirCount(), 0); equal(F:GetCurrentStep().source.type, "Vendor")
end)

test("Hodir rank and reset events defer in combat and coexist with Champion farming", function()
    hodirSetup(); P:SetChampionFarmingEnabled(true); collected[289] = true; F:Apply()
    combat = true; standing = 7; frames[1].scripts.OnEvent(nil, "UPDATE_FACTION"); flush()
    equal(hodirCount(), 3); assert(P.refreshAfterCombat)
    combat = false; frames[1].scripts.OnEvent(nil, "PLAYER_REGEN_ENABLED"); flush(); equal(hodirCount(), 0)
    P:SetHodirFarmingEnabled(false); assert(P.dailyTimer)
    P:SetChampionFarmingEnabled(false); equal(P.dailyTimer, nil)
end)

test("daily metadata validates object identities without accepting ambiguous giver IDs", function()
    local group = P.dailyGroups["storm.hodir.daily.cold"]
    group.npcID = 192071; equal(P:ValidateRegistry(), false); assert(group.invalid)
    group.npcID = nil; local object = group.objectID; group.objectID = 0
    equal(P:ValidateRegistry(), false); group.objectID = object; equal(P:ValidateRegistry(), true)
end)

if arg[1] then
    test("published Lillehoff data selects each faction's correct reputation targets", function()
        local data = { Internal = {} }
        assert(loadfile(arg[1] .. "/Steps/Standard/MRPData_Steps.lua"))("MountRoutePlannerData", data)
        assert(loadfile(arg[1] .. "/Mounts/Standard/MRPData_Mounts.lua"))("MountRoutePlannerData", data)
        for _, side in ipairs({ "Alliance", "Horde" }) do
            hodirSetup(side)
            MRP.Data.STEPS, MRP.Data.OPEN_WORLD = data.Steps, data.openWorld
            MRP.Data.DUNGEONS, MRP.Data.RAIDS, MRP.Data.WORLD_BOSSES = data.dungeons, data.raids, data.worldBosses
            F:Apply(); equal(P.hodirTarget.rank, 8); equal(P.hodirTarget.count, 2); equal(hodirCount(), 3)
            local grandID
            for id, goal in pairs(P.hodirTarget.goals) do if goal.rank == 8 then grandID = id end end
            assert(grandID); collected[grandID] = true; F:Apply(); equal(P.hodirTarget.rank, 7)
        end
    end)
end

print(string.format("%d tests, %d failures", tests, failures))
os.exit(failures == 0 and 0 or 1)
