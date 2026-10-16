-- Repeatable progress is character-local and separate from permanent unlock flags.
-- local _, MRP = ...
local P, L = MRP.Prerequisites, MRP.L
P.dailyGroups, P.dailyQuests, P.sealDailyGroups = {}, {}, {}
local function onQuest(id) return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) end
local function enabled()
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and MRP_CharacterSettings
        and MRP_CharacterSettings.includePrerequisiteQuests and MRP_CharacterSettings.includePrerequisiteDailies
end

function P:RegisterDailyGroup(id, group)
    assert(not self.dailyGroups[id], "Duplicate daily group: " .. id)
    group.id = id
    self.dailyGroups[id] = group
    for _, q in ipairs(group.quests) do
        assert(not self.dailyQuests[q.questID], "Duplicate daily quest")
        q.daily, q.scope, q.dailyGroupID = true, "character", id
        q.mapID, q.x, q.y = group.mapID, group.x, group.y
        q.turnIn = { mapID = group.mapID, x = group.x, y = group.y }
        q.note = group.note
        self.dailyQuests[q.questID] = q
    end
end

-- Use the realm's actual reset boundary, never local midnight or elapsed 24 hours.
-- Saved completions only bridge event/API lag within that boundary. Live Blizzard
-- completion flags are still authoritative after login and are never cleared here.
function P:SyncDailyReset()
    if not MRP_CharacterSettings then return nil end
    local now = GetServerTime and GetServerTime()
    local seconds = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset and C_DateAndTime.GetSecondsUntilDailyReset()
    local valid = type(now) == "number" and now > 0 and type(seconds) == "number" and seconds > 0 and seconds < math.huge
    local state = MRP_CharacterSettings.prerequisiteDailyState
    local resetAt = valid and math.floor(now + seconds) or nil
    if type(state) ~= "table" or state.version ~= 1 or type(state.completed) ~= "table"
        or (state.resetAt ~= nil and (type(state.resetAt) ~= "number" or state.resetAt <= 0 or state.resetAt >= math.huge)) then
        state = { version = 1, completed = {} }
        MRP_CharacterSettings.prerequisiteDailyState = state
    end
    local expired = state.resetAt and type(now) == "number" and now >= state.resetAt
    local changed = expired or (resetAt and (not state.resetAt or math.abs(resetAt - state.resetAt) > 60))
    if changed then
        state.resetAt, state.completed, self.dailyOffers = resetAt, {}, {}
    end
    -- A missing reset API cannot validate cached observations, even before expiry.
    self.dailyResetAt = valid and state.resetAt or nil
    return changed
end

function P:IsDailyComplete(id)
    if onQuest(id) then return false end -- preserve quests carried across reset
    local q = self.dailyQuests[id]
    local offers = self.dailyResetAt and q and self.dailyOffers and self.dailyOffers[q.dailyGroupID]
    if offers and offers[id] then return false end -- a live offer beats a lagging completion flag
    local state = MRP_CharacterSettings and MRP_CharacterSettings.prerequisiteDailyState
    if self.dailyResetAt and state and state.completed[id] then return true end
    return self:IsQuestComplete(id, "character")
end

function P:IsRoutedQuestComplete(q)
    if q.dailyGroup then return false end -- a visit is not a completed quest
    if q.daily then return self:IsDailyComplete(q.questID) end
    return self:IsQuestComplete(q.questID, q.scope)
end

function P:CanRetainCompletedQuest(q)
    if q.dailyGroup then return false end
    if q.daily and (not enabled() or not self.dailyResetAt or q.dailyResetAt ~= self.dailyResetAt) then return false end
    return self:IsRoutedQuestComplete(q) == true
end

function P:CaptureDailyOffers()
    if not enabled() or not self.dailyResetAt or not (C_GossipInfo and C_GossipInfo.GetAvailableQuests) then return end
    local guid = UnitGUID and UnitGUID("npc")
    local npc = guid and tonumber(guid:match("%-(%d+)%-%x+$"))
    if not npc then return end
    local available = C_GossipInfo.GetAvailableQuests()
    if type(available) ~= "table" then return end
    local offered = {}
    for _, q in ipairs(available) do offered[q.questID] = true end
    self.dailyOffers = self.dailyOffers or {}
    for id, group in pairs(self.dailyGroups) do
        if group.npcID == npc then
            local snapshot = { full = true }
            for _, q in ipairs(group.quests) do
                if offered[q.questID] then
                    snapshot[q.questID] = true
                    MRP_CharacterSettings.prerequisiteDailyState.completed[q.questID] = nil
                end
            end
            self.dailyOffers[id] = snapshot
        end
    end
end

function P:HandleDailyEvent(event, questID)
    if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE or not MRP_CharacterSettings then return end
    self:SyncDailyReset()
    local q = self.dailyQuests[questID]
    if event == "QUEST_TURNED_IN" and q and self.dailyResetAt then
        MRP_CharacterSettings.prerequisiteDailyState.completed[questID] = true
    end
    if self.dailyOffers and q then
        if event == "QUEST_REMOVED" then
            self.dailyOffers[q.dailyGroupID] = nil -- abandoning may restore this offer
        elseif event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" then
            local snapshot = self.dailyOffers[q.dailyGroupID]
            if snapshot then snapshot[questID] = nil end -- retain the NPC's other offers
        end
    end
    if event == "UPDATE_FACTION" or (event == "QUEST_TURNED_IN" and not q) then
        -- Promotions can open a previously empty quest list.
        self.dailyOffers = {}
    elseif event == "GOSSIP_SHOW" then
        self:CaptureDailyOffers()
    elseif event == "QUEST_DETAIL" and enabled() and self.dailyResetAt and GetQuestID then
        -- Some quest givers open a quest directly without a gossip list. A detail
        -- page proves this offer only; it says nothing about their other quests.
        local id = GetQuestID()
        local daily = self.dailyQuests[id]
        if daily then
            self.dailyOffers = self.dailyOffers or {}
            local snapshot = self.dailyOffers[daily.dailyGroupID] or {}
            snapshot[id] = true
            self.dailyOffers[daily.dailyGroupID] = snapshot
            MRP_CharacterSettings.prerequisiteDailyState.completed[id] = nil
        end
    end
end

function P:StartDailyResetWatch()
    if self.dailyTimer then self.dailyTimer:Cancel(); self.dailyTimer = nil end
    if not enabled() or not (C_Timer and C_Timer.NewTimer) then return end
    self:SyncDailyReset()
    local now = GetServerTime and GetServerTime()
    local delay = self.dailyResetAt and now and math.max(1, math.min(60, self.dailyResetAt - now + 1)) or 60
    self.dailyTimer = C_Timer.NewTimer(delay, function()
        self.dailyTimer = nil
        self:SyncDailyReset()
        -- Also re-read completion flags if the client updated them after the boundary.
        self:QueueRefresh()
        self:StartDailyResetWatch()
    end)
end

function P:SetDailiesEnabled(value)
    MRP_CharacterSettings.includePrerequisiteDailies = value == true
    if value then MRP_CharacterSettings.includePrerequisiteQuests = true end
    self:StartDailyResetWatch()
    MRP.Filter:Apply()
end

function P:ResolveDailyGroups(ids)
    local actions, unknown = {}, false
    for _, id in ipairs(ids) do
        local group = self.dailyGroups[id]
        if group and not group.invalid and (not group.faction or group.faction == UnitFactionGroup("player")) then
            local snapshot = self.dailyResetAt and self.dailyOffers and self.dailyOffers[id]
            local active, complete, offered = {}, false, false
            for _, q in ipairs(group.quests) do
                if onQuest(q.questID) then active[#active + 1] = q end
                complete = complete or self:IsDailyComplete(q.questID) == true
                offered = offered or (snapshot and snapshot[q.questID])
            end
            if #active > 0 then
                for _, q in ipairs(active) do actions[#actions + 1] = q end
            end
            local eligible = not group.requires or self:Evaluate(group.requires) == true
            if eligible and #active == 0 and group.prepare and self:Evaluate(group.prepare) ~= true then
                local prep = self:ResolveRequirement(group.prepare)
                unknown = unknown or prep.state == "unknown"
                for _, q in ipairs(prep.quests) do actions[#actions + 1] = q end
            elseif eligible and not (group.rotation and ((complete and not offered) or #active > 0)) then
                local unchecked = false
                for _, q in ipairs(group.quests) do
                    local done = self:IsDailyComplete(q.questID)
                    unknown = unknown or done == nil
                    if not onQuest(q.questID) and done == false then
                        if snapshot and snapshot[q.questID] then actions[#actions + 1] = q
                        elseif not snapshot or not snapshot.full then unchecked = true end
                    end
                end
                if unchecked and self.dailyResetAt then
                    actions[#actions + 1] = { dailyGroup = id, name = group.name,
                        mapID = group.mapID, x = group.x, y = group.y, note = group.note }
                end
            end
        elseif not group or group.invalid then
            unknown = true
        end
    end
    return { state = #actions > 0 and "actionable" or "waiting", quests = actions,
        message = #actions == 0 and (unknown and L["Daily availability could not be verified. Check the quest giver or quest log."] or (self.dailyResetAt
            and L["No eligible dailies remain available. Check again after the daily reset."]
            or L["Daily reset time is unavailable. Accepted quests can still be completed."])) or nil }
end

function P:ResolveDailyProgress(requirement, quest)
    if not enabled() then return nil end
    if quest and self.sealDailyGroups[quest.questID] then
        return self:ResolveDailyGroups(self.sealDailyGroups[quest.questID])
    elseif requirement.type == "reputation" and requirement.factionID == 1015
        and self:Evaluate(self.RequireChain("netherwing.service")) == true then
        return self:ResolveDailyGroups(self.netherwingDailyGroups)
    end
end
