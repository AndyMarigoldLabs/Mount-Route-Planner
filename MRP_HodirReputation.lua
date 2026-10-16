-- One character reputation target shared by all selected Lillehoff mammoths.
-- local _, MRP = ...
local P, L = MRP.Prerequisites, MRP.L
local baseAvailability = P.GetMountAvailability

function P:HodirFarmingEnabled()
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and MRP_CharacterSettings
        and MRP_CharacterSettings.includeHodirReputationFarming == true
end

function P:PrepareHodirTarget(steps)
    self.hodirTarget, self.hodirActions = nil, nil
    if not self:HodirFarmingEnabled() then return end
    local target = { count = 0, goals = {}, selections = {} }
    self.hodirTarget = target
    target.standing = MRP.Util.GetReputationRank(1119)
    for _, step in ipairs(steps) do
        local entry = MRP.Util.GetStepEntry(step)
        if step.source.type == "Vendor" and (step.source.npcID or (entry and entry.npcID)) == 32540 then
            local blocked = false
            for _, condition in ipairs(MRP.Util.GetStepConditions(step)) do
                if not condition.met and condition.type ~= "quest" and condition.type ~= "reputation" then blocked = true; break end
            end
            for _, mount in ipairs(step.mounts) do
                local reward = self.hodirMounts[mount.itemId]
                local _, _, collected = MRP.Util.GetMountInfoSafe(mount)
                if not blocked and reward and not collected and MRP_CharacterSettings.filter.collectedStates[collected]
                    and self:IsMountAllowed(step, mount) then
                    target.hasCandidates = true
                    if baseAvailability(self, step, mount).state ~= "unknown" then
                        local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(mount.itemId, true)
                        local selection = { rank = reward.requirements.standing, owned = type(count) == "number" and count > 0 }
                        target.selections[step.id] = target.selections[step.id] or {}
                        target.selections[step.id][mount.id] = selection
                        local goal = target.goals[mount.id] or { rank = selection.rank }
                        goal.owned = goal.owned or selection.owned
                        target.goals[mount.id] = goal
                    end
                end
            end
        end
    end
    for _, goal in pairs(target.goals) do
        if not goal.owned then
            target.count = target.count + 1
            target.rank = math.max(target.rank or 0, goal.rank)
        end
    end
    target.needed = target.rank ~= nil and target.standing ~= nil and target.standing < target.rank
end

function P:GetHodirTargetMessage()
    local target = self.hodirTarget
    if not target then return nil end
    if target.hasCandidates and not target.standing then return L["Sons of Hodir reputation is unavailable. Farming is paused until character reputation data loads."] end
    if not target.rank then return L["No unpurchased Lillehoff mammoths match your filters."] end
    local rank = target.rank == 8 and FACTION_STANDING_LABEL8 or FACTION_STANDING_LABEL7
    return string.format(L["Sons of Hodir target: %s for %d selected mammoths. Gold and vendor unlock requirements still apply."], rank, target.count)
end

function P:GetHodirActions()
    if self.hodirActions then return self.hodirActions end
    local access = MRP_CharacterSettings.hodirDailyAccess
    if type(access) ~= "table" then access = {}; MRP_CharacterSettings.hodirDailyAccess = access end
    for _, groupID in ipairs(self.hodirDailyGroups) do
        local group = self.dailyGroups[groupID]
        local offers = self.dailyResetAt and self.dailyOffers and self.dailyOffers[groupID]
        for _, q in ipairs(group.quests) do
            if (C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(q.questID))
                or self:IsDailyComplete(q.questID) == true or (offers and offers[q.questID]) then access[groupID] = true end
        end
    end
    local actions = self:ResolveDailyGroups(self.hodirDailyGroups)
    if #actions.quests == 0 and self:Evaluate(self.RequireChain("storm.hodir")) ~= true then
        actions.message = L["Unlock the Sons of Hodir on this character first. Enable prerequisite quest routing to follow the Storm Peaks chain."]
    end
    local copies = {}
    for _, q in ipairs(actions.quests) do
        local copy = MRP.Util.ShallowCopy(q)
        copy.hodirReputation = true
        copies[#copies + 1] = copy
    end
    actions.quests = copies
    self.hodirActions = actions
    return actions
end

function P:GetMountAvailability(step, mount)
    local status = baseAvailability(self, step, mount)
    local target = self:HodirFarmingEnabled() and self.hodirTarget
    local selection = target and target.selections[step.id] and target.selections[step.id][mount.id]
    if not selection or status.state == "unknown" then return status end
    if target.goals[mount.id].owned then
        return { state = "waiting", quests = {}, message = L["This mount item is already owned. Learn it to add it to your collection."] }
    end
    if target.standing and target.standing >= selection.rank then return status end
    local quests, message = {}, self:GetHodirTargetMessage()
    for _, q in ipairs(status.quests or {}) do quests[#quests + 1] = q end
    if status.message and status.message ~= "" then message = message .. "\n" .. status.message end
    if target.needed then
        local actions = self:GetHodirActions()
        for _, q in ipairs(actions.quests) do quests[#quests + 1] = q end
        if actions.message then message = message .. "\n" .. actions.message end
    end
    return { state = #quests > 0 and "actionable" or "waiting", quests = quests, quest = quests[1], message = message }
end

function P:SetHodirFarmingEnabled(value)
    MRP_CharacterSettings.includeHodirReputationFarming = value == true
    self:StartDailyResetWatch()
    MRP.Filter:Apply()
end

local shouldRouteQuest = P.ShouldRouteQuest
function P:ShouldRouteQuest(q)
    if q.hodirReputation then return self:HodirFarmingEnabled() end
    return shouldRouteQuest(self, q)
end
