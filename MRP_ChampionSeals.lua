-- Plan one shared purchase budget, using only this character's spendable seals.
-- local _, MRP = ...
local P, L = MRP.Prerequisites, MRP.L
local baseAvailability = P.GetMountAvailability
local function whole(n) return type(n) == "number" and n >= 0 and n < math.huge and n == math.floor(n) end

function P:ChampionFarmingEnabled()
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and MRP_CharacterSettings and MRP_CharacterSettings.includeChampionSealFarming == true
end

function P:IsTournamentPurchase(step, mount)
    if step.source.type ~= "Vendor" then return false end
    if mount.itemId == 45725 then return true end
    local entry = MRP.Util.GetStepEntry(step)
    local npc = step.source.npcID or (entry and entry.npcID)
    if npc == 34881 or npc == 34772 or npc == 34885 then return true end
    for _, city in ipairs(self.tournamentCities) do if npc == city[2] then return true end end
    return false
end

function P:GetChampionSealCost(mount)
    local costs = mount.source.costs or (mount.source.cost and { mount.source.cost })
    if type(costs) ~= "table" or #costs == 0 then return nil end
    local total = 0
    for _, cost in ipairs(costs) do
        if type(cost) ~= "table" then return nil end
        if cost.type == "currency" and cost.currencyId == 241 then
            if not whole(cost.amount) or cost.amount == 0 then return nil end
            total = total + cost.amount
        end
    end
    return total > 0 and total or nil
end

function P:PrepareChampionBudget(steps)
    self.championBudget, self.championActions = nil, nil
    if not self:ChampionFarmingEnabled() then return end
    local budget = { total = 0, count = 0, goals = {}, selections = {} }
    self.championBudget = budget
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(241)
    budget.quantity = info and whole(info.quantity) and info.quantity or nil
    for _, step in ipairs(steps) do
        local blocked = false
        for _, condition in ipairs(MRP.Util.GetStepConditions(step)) do
            if not condition.met and condition.type ~= "quest" and condition.type ~= "reputation" then blocked = true; break end
        end
        for _, mount in ipairs(step.mounts) do
            local _, _, collected = MRP.Util.GetMountInfoSafe(mount)
            if not blocked and not collected and MRP_CharacterSettings.filter.collectedStates[collected]
                and self:IsTournamentPurchase(step, mount) and self:IsMountAllowed(step, mount) then
                local status = baseAvailability(self, step, mount)
                -- Unknown acquisition gates never create farming errands.
                if status.state ~= "unknown" then
                    local owned = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(mount.itemId, true)
                    local selection = { owned = type(owned) == "number" and owned > 0, cost = self:GetChampionSealCost(mount) }
                    budget.selections[step.id] = budget.selections[step.id] or {}
                    budget.selections[step.id][mount.id] = selection
                    local goal = budget.goals[mount.id]
                    if not goal then goal = {}; budget.goals[mount.id] = goal end
                    goal.owned = goal.owned or selection.owned
                    -- Multiple vendor listings are alternatives for one mount.
                    if selection.cost then goal.cost = math.min(goal.cost or selection.cost, selection.cost) end
                end
            end
        end
    end
    for _, goal in pairs(budget.goals) do
        if not goal.owned then
            budget.count = budget.count + 1
            if goal.cost then budget.total = budget.total + goal.cost else budget.unknownCost = true end
        end
    end
    if budget.quantity and not budget.unknownCost then budget.remaining = math.max(0, budget.total - budget.quantity) end
end

function P:GetChampionBudgetMessage()
    local b = self.championBudget
    if not b then return nil end
    if b.unknownCost then return L["A selected mount's Champion's Seal price is unknown. Farming is paused until its price can be verified."] end
    if b.count == 0 then return L["No unpurchased Champion's Seal mounts match your filters."] end
    if b.quantity == nil then return L["Champion's Seal balance is unavailable. Farming is paused until the currency data loads."] end
    return string.format(L["Champion's Seals: %d / %d for %d selected mounts (%d more). Gold and other purchase requirements still apply."],
        b.quantity, b.total, b.count, b.remaining)
end

function P:GetChampionActions()
    if self.championActions then return self.championActions end
    local faction = UnitFactionGroup("player")
    local _, class = UnitClass("player")
    local key = faction .. "." .. (class == "DEATHKNIGHT" and class or "other")
    local profile = self.championProfiles[key]
    local actions = { state = "waiting", quests = {} }
    self.championActions = actions
    if not profile then return actions end
    local first = self:Evaluate(self.tournamentFirst[faction]) == true
    local introDone = self:IsQuestComplete(profile.introID, "character") == true
    local access = MRP_CharacterSettings.championDailyAccess
    if type(access) ~= "table" then access = {} end
    MRP_CharacterSettings.championDailyAccess = access
    for _, id in ipairs(profile.quests) do
        local q = self.dailyQuests[id]
        local offers = self.dailyResetAt and self.dailyOffers and self.dailyOffers[q.dailyGroupID]
        if (C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id))
            or self:IsDailyComplete(id) == true or (offers and offers[id]) then access[key] = true end
    end
    if not first and not introDone and not access[key] then
        if self:Evaluate(self.tournamentGoals[faction].champion) == true and self.tournamentPath then
            actions = self:ResolveRequirement(self.tournamentPath) -- first Champion Rises handoff
        else
            actions.message = L["Become a Champion on this character first. Enable prerequisite quest routing to follow the Tournament unlocks."]
        end
    else
        local groups = {}
        for _, id in ipairs(profile.groups) do groups[#groups + 1] = id end
        for _, id in ipairs(self.championExtraGroups[faction]) do groups[#groups + 1] = id end
        actions = self:ResolveDailyGroups(groups)
        -- These handoffs can be skipped in-game. Observed access to any core
        -- Champion daily is permanent evidence to stop replaying a breadcrumb.
        if not introDone and not access[key] then
            local intro = self:ResolveRequirement(self.RequireChain(profile.intro))
            for _, q in ipairs(intro.quests) do actions.quests[#actions.quests + 1] = q end
        end
    end
    local copies = {}
    for _, q in ipairs(actions.quests) do
        local copy = MRP.Util.ShallowCopy(q)
        copy.championSeals = true
        copies[#copies + 1] = copy
    end
    actions.quests = copies
    if #copies > 0 then actions.state = "actionable" end
    self.championActions = actions
    return actions
end

function P:GetMountAvailability(step, mount)
    local status = baseAvailability(self, step, mount)
    local b = self:ChampionFarmingEnabled() and self.championBudget
    local selection = b and b.selections[step.id] and b.selections[step.id][mount.id]
    if not selection or status.state == "unknown" then return status end
    local goal = b.goals[mount.id]
    if selection.owned or (goal and goal.owned) then
        return { state = "waiting", quests = {}, message = L["This mount item is already owned. Learn it to add it to your collection."] }
    end
    -- Prefer the cheapest selected listing; do not send a funded budget to a
    -- more expensive duplicate or a listing whose price is unknown.
    if goal and goal.cost and selection.cost ~= goal.cost then
        return { state = "waiting", quests = {}, message = L["Another selected listing supplies this mount for fewer verified Champion's Seals."] }
    end
    if b.remaining == 0 then return status end
    local quests = {}
    for _, q in ipairs(status.quests or {}) do quests[#quests + 1] = q end
    local message = self:GetChampionBudgetMessage()
    if status.message and status.message ~= "" then message = message .. "\n" .. status.message end
    if b.remaining and b.remaining > 0 then
        local farm = self:GetChampionActions()
        for _, q in ipairs(farm.quests) do quests[#quests + 1] = q end
        if farm.message then message = message .. "\n" .. farm.message end
    end
    return { state = #quests > 0 and "actionable" or "waiting", quests = quests, quest = quests[1], message = message }
end

function P:SetChampionFarmingEnabled(value)
    MRP_CharacterSettings.includeChampionSealFarming = value == true
    self:StartDailyResetWatch()
    MRP.Filter:Apply()
end

function P:ShouldRouteQuest(q)
    if q.championSeals then return self:ChampionFarmingEnabled() end
    return MRP_CharacterSettings.includePrerequisiteQuests
end
