-- Quest prerequisites are acquisition requirements, not source kill/loot lockouts.
-- local _, MRP = ...
local L = MRP.L
local Prerequisites = {}
MRP.Prerequisites = Prerequisites

local function validID(id)
    return type(id) == "number" and id > 0 and id == math.floor(id)
end

function Prerequisites:IsQuestComplete(id, scope)
    if not validID(id) or (scope and scope ~= "character" and scope ~= "account") then return nil end
    local api = C_QuestLog and (scope == "account" and C_QuestLog.IsQuestFlaggedCompletedOnAccount or C_QuestLog.IsQuestFlaggedCompleted)
    -- Never substitute character progress for an unavailable account-wide API.
    if scope == "account" and not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompletedOnAccount) then return nil end
    if not api then return nil end
    return api(id)
end

function Prerequisites:GetQuestName(quest)
    if quest.dailyGroup then return quest.name end
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(quest.questID or quest.id)
    return title or quest.name or string.format(L["Quest %d"], quest.questID or quest.id)
end

-- Tri-state evaluation: nil means unsupported or unreliable data/API availability.
function Prerequisites:Evaluate(requirement, depth)
    depth = (depth or 0) + 1
    if type(requirement) ~= "table" or depth > 32 then return nil end
    if requirement.allOf or requirement.anyOf then
        local children = requirement.allOf or requirement.anyOf
        if type(children) ~= "table" or #children == 0 then return nil end
        local unknown = false
        for _, child in ipairs(children) do
            local met = self:Evaluate(child, depth)
            if requirement.allOf and met == false then return false end
            if requirement.anyOf and met == true then return true end
            if met == nil then unknown = true end
        end
        if unknown then return nil end
        return requirement.allOf ~= nil
    elseif requirement.type == "chain" then
        local chain = self.chains and self.chains[requirement.id]
        if not chain or chain.invalid then return nil end
        return self:Evaluate(chain.requirements, depth)
    elseif requirement.type == "item" then
        if not validID(requirement.id) or not validID(requirement.count) or not (C_Item and C_Item.GetItemCount) then return nil end
        local count = C_Item.GetItemCount(requirement.id, false)
        if type(count) ~= "number" then return nil end
        return count >= requirement.count
    elseif requirement.type == "quest" then
        return self:IsQuestComplete(requirement.id, requirement.scope)
    elseif requirement.type == "reputation" then
        if not validID(requirement.factionID) or not validID(requirement.standing) or requirement.standing > 8 then return nil end
        if not (C_Reputation and C_Reputation.GetFactionDataByID) then return nil end
        local data = C_Reputation.GetFactionDataByID(requirement.factionID)
        return data ~= nil and data.currentStanding ~= nil and data.currentStanding >= requirement.standing
    end
    return nil
end

function Prerequisites:Describe(requirement, depth)
    depth = (depth or 0) + 1
    if type(requirement) ~= "table" or depth > 32 then return L["Prerequisite data is unknown."] end
    if requirement.allOf or requirement.anyOf then
        local parts = {}
        local children = requirement.allOf or requirement.anyOf
        if type(children) ~= "table" then return L["Prerequisite data is unknown."] end
        for _, child in ipairs(children) do
            if self:Evaluate(child) ~= true then parts[#parts + 1] = self:Describe(child, depth) end
        end
        return table.concat(parts, requirement.anyOf and L[" OR "] or "; ")
    elseif requirement.type == "chain" then
        local chain = self.chains and self.chains[requirement.id]
        return chain and self:Describe(chain.requirements, depth) or L["Prerequisite data is unknown."]
    elseif requirement.type == "item" and validID(requirement.id) and validID(requirement.count) then
        return string.format(L["Collect %d of item %d."], requirement.count, requirement.id)
    elseif requirement.type == "quest" and validID(requirement.id) then
        return string.format(L["Complete %s (%d)."], self:GetQuestName(requirement), requirement.id)
    elseif requirement.type == "reputation" and validID(requirement.factionID) and validID(requirement.standing) then
        return MRP.Core:GetConditionMessage("rep_" .. requirement.factionID .. "_" .. requirement.standing)
    end
    return L["Prerequisite data is unknown."]
end

local function validLocation(loc)
    return type(loc) == "table" and validID(loc.mapID)
        and type(loc.x) == "number" and loc.x >= 0 and loc.x <= 100
        and type(loc.y) == "number" and loc.y >= 0 and loc.y <= 100
end

function Prerequisites:GetQuestDestination(quest)
    if quest.dailyGroup then
        local loc = MRP.Util.ShallowCopy(quest)
        loc.navigationKey = "daily-check:" .. quest.dailyGroup .. ":" .. tostring(quest.dailyResetAt)
        return loc, "check"
    end
    if self:IsRoutedQuestComplete(quest) == true then return nil, "completed" end
    local onQuest = C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(quest.questID)
    local phase = onQuest and "objective" or "accept"
    if onQuest and C_QuestLog.IsComplete and C_QuestLog.IsComplete(quest.questID) then phase = "turnIn" end
    local navigationKey = (quest.scope or "character") .. ":" .. quest.questID .. ":" .. phase
    if quest.daily then navigationKey = navigationKey .. ":" .. tostring(quest.dailyResetAt) end
    -- Blizzard's waypoint follows objectives/turn-in and can point across maps.
    if onQuest and C_QuestLog.GetNextWaypoint then
        local mapID, x, y = C_QuestLog.GetNextWaypoint(quest.questID)
        if type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            local loc = { mapID = mapID, x = x * 100, y = y * 100 }
            if validLocation(loc) then loc.navigationKey = navigationKey; return loc, phase end
        end
    end
    local loc = quest[phase] or (phase == "accept" and quest)
    if validLocation(loc) then
        loc = MRP.Util.ShallowCopy(loc)
        loc.navigationKey = navigationKey
        return loc, phase
    end
    -- An accepted quest without objective data must not send the player back to its giver.
    return nil, phase
end

-- Source requirements and mount requirements are additive. This matters for vendors
-- with several mounts at different reputation ranks.
function Prerequisites:GetProviders(step, mount)
    local providers = {}
    local function add(provider)
        if provider and (provider.requirements ~= nil or provider.unlockSteps ~= nil) then
            providers[#providers + 1] = provider
        end
    end
    add(MRP.Util.GetStepEntry(step))
    add(step)
    add(mount.source)
    local raw = MRP.Util.GetStepEntry(step)
    for _, key in ipairs(raw and raw.conditions or {}) do
        local accountID = key:match("^quest_account_(%d+)$")
        local id = accountID or key:match("^quest_(%d+)$")
        if id then
            add({ requirements = { type = "quest", id = tonumber(id), scope = accountID and "account" or "character" } })
        elseif key:find("^quest_") then
            add({ requirements = false })
        elseif key:find("^rep_") then
            local factionID, rank = key:match("^rep_(%d+)_(%d+)$")
            add({ requirements = { type = "reputation", factionID = tonumber(factionID), standing = tonumber(rank) } })
        end
    end
    if self.GetSupplement then
        local source, reward = self:GetSupplement(step, mount)
        add(source)
        add(reward)
    end
    return providers
end

function Prerequisites:IsMountAllowed(step, mount)
    if MRP.Core and not MRP.Core:IsMountFactionAllowed(mount) then return false end
    if self.GetSupplement then
        local _, reward = self:GetSupplement(step, mount)
        if reward and reward.faction and reward.faction ~= UnitFactionGroup("player") then return false end
        if reward and reward.class then
            local _, class = UnitClass("player")
            if class ~= reward.class then return false end
        end
    end
    return true
end

function Prerequisites:GetMountAvailability(step, mount)
    local providers = self:GetProviders(step, mount)
    if #providers == 0 then return { state = "unknown", unverified = true } end
    local state, messages, nextQuests = "available", {}, {}
    for _, provider in ipairs(providers) do
        local met = self:Evaluate(provider.requirements)
        if met ~= true then
            state = met == nil and "unknown" or (state ~= "unknown" and "locked" or state)
            messages[#messages + 1] = self:Describe(provider.requirements)
            if met == false and (provider.unlockRequirement or provider.requirements.type == "chain") then
                local resolved = self:ResolveRequirement(provider.unlockRequirement or provider.requirements)
                if resolved.state == "unknown" then state = "unknown" end
                if resolved.message and resolved.message ~= "" then messages[#messages + 1] = resolved.message end
                for _, quest in ipairs(resolved.quests) do nextQuests[#nextQuests + 1] = quest end
            elseif met == false and type(provider.unlockSteps) == "table" then
                for _, quest in ipairs(provider.unlockSteps) do
                    if type(quest) ~= "table" or not validID(quest.questID) then
                        state = "unknown"
                        break
                    end
                    if not quest.faction or quest.faction == UnitFactionGroup("player") then
                        local complete = self:IsQuestComplete(quest.questID, quest.scope)
                        if complete == nil then state = "unknown"; break end
                        if not complete then
                            -- Explicit dependencies support forks and quests accepted in
                            -- parallel; otherwise the list is a strictly ordered chain.
                            if not quest.requires or self:Evaluate(quest.requires) == true then
                                nextQuests[#nextQuests + 1] = quest
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    if state == "unknown" then nextQuests = {} end
    if state == "locked" then state = #nextQuests == 0 and "waiting" or "actionable" end
    return { state = state, quest = nextQuests[1], quests = nextQuests, message = table.concat(messages, "\n") }
end

function Prerequisites:MakeQuestStep(quest, parent, mount)
    if quest.daily or quest.dailyGroup then
        quest = MRP.Util.ShallowCopy(quest)
        quest.dailyResetAt = self.dailyResetAt
    end
    local entry = self:GetQuestDestination(quest)
    local questName = self:GetQuestName(quest)
    local reward = MRP.Util.ShallowCopy(mount)
    reward.source = {
        allowedDifficultyIds = { -1 }, relevantDifficultyIds = { -1 },
        uiMapIds = { entry and entry.mapID or quest.mapID }, mapId = 0,
        specialEncounter = { name = questName }, note = quest.note,
        factionMask = mount.source.factionMask,
    }
    return {
        id = quest.dailyGroup and ("daily-check:" .. quest.dailyGroup .. ":" .. tostring(self.dailyResetAt))
            or ((quest.daily and "daily:" or "prerequisite:") .. (quest.scope or "character") .. ":" .. quest.questID
                .. (quest.daily and (":" .. tostring(self.dailyResetAt)) or "")),
        source = { type = MRP.FilterSourceType.Quest, name = questName, prerequisiteQuest = quest },
        expansion = parent.expansion, mounts = { reward }, prerequisiteQuest = quest,
        targetStepIDs = { [parent.id] = true }, entry = entry or {},
    }
end

-- Only ready prerequisite quests of each selected source enter the route.
-- Locked vendors are withheld, so geography can never put one before its unlock.
function Prerequisites:ExpandSteps(steps)
    self:SyncDailyReset()
    if self.PrepareWaveContext then self:PrepareWaveContext(steps) end
    local result, quests, diagnostics = {}, {}, {}
    for _, step in ipairs(steps) do
        local available = {}
        local sourceBlock
        for _, condition in ipairs(MRP.Util.GetStepConditions(step)) do
            if not condition.met and condition.type ~= "quest" and condition.type ~= "reputation" then
                sourceBlock = condition.message
                break
            end
        end
        for _, mount in ipairs(step.mounts) do
            local _, _, collected = MRP.Util.GetMountInfoSafe(mount)
            if MRP_CharacterSettings.filter.collectedStates[collected] and self:IsMountAllowed(step, mount) then
                local status = self:GetMountAvailability(step, mount)
                if sourceBlock then status = { state = "locked", message = sourceBlock } end
                if status.state == "available" or status.unverified then
                    available[#available + 1] = mount
                else
                    diagnostics[#diagnostics + 1] = { step = step, mount = mount, status = status }
                    if MRP_CharacterSettings.includePrerequisiteQuests and not collected then
                        for _, quest in ipairs(status.quests or {}) do
                            local planned = self:MakeQuestStep(quest, step, mount)
                            if not quests[planned.id] then
                                quests[planned.id] = planned
                                result[#result + 1] = planned
                            else
                                local existing = quests[planned.id]
                                existing.targetStepIDs[step.id] = true
                                local found = false
                                for _, reward in ipairs(existing.mounts) do if reward.id == mount.id then found = true; break end end
                                if not found then existing.mounts[#existing.mounts + 1] = planned.mounts[1] end
                            end
                        end
                    end
                end
            end
        end
        if #available > 0 then
            local copy = MRP.Util.ShallowCopy(step)
            copy.mounts = available
            if self.GetRouteOverride then copy = self:GetRouteOverride(copy) end
            result[#result + 1] = copy
        end
    end
    -- Alternate acquisition rows can converge on the same vendor after a choice.
    local merged, byID = {}, {}
    for _, step in ipairs(result) do
        local existing = byID[step.id]
        if existing then
            for id in pairs(step.targetStepIDs or {}) do
                existing.targetStepIDs = existing.targetStepIDs or {}
                existing.targetStepIDs[id] = true
            end
            for _, reward in ipairs(step.mounts) do
                local found = false
                for _, old in ipairs(existing.mounts) do if old.id == reward.id then found = true; break end end
                if not found then existing.mounts[#existing.mounts + 1] = reward end
            end
        else
            byID[step.id] = step
            merged[#merged + 1] = step
        end
    end
    self.diagnostics = diagnostics
    return merged
end

function Prerequisites:GetNavigationEntry(step)
    if step.prerequisiteQuest then return self:GetQuestDestination(step.prerequisiteQuest) end
    if step.acquisitionQuest then return self:GetQuestDestination(step.acquisitionQuest) end
    local entry = MRP.Util.GetStepEntry(step)
    -- Existing quest-reward chains use the same resolver on the panel and map.
    if entry and step.source.type == MRP.FilterSourceType.Quest then
        local chain = step.mounts[1] and step.mounts[1].source.questChain
        for _, quest in ipairs(chain or {}) do
            if self:IsQuestComplete(quest.questID, quest.scope) ~= true then
                local loc = self:GetQuestDestination(quest)
                if loc then return loc end
                break
            end
        end
    end
    return entry
end

function Prerequisites:SetEnabled(enabled)
    MRP_CharacterSettings.includePrerequisiteQuests = enabled == true
    self:StartDailyResetWatch()
    MRP.Filter:Apply()
end

function Prerequisites:PrintStatus()
    local count = 0
    for _, blocked in ipairs(self.diagnostics or {}) do
        count = count + 1
        print("|cffffcc00[MRP]|r " .. blocked.mount.name .. " (" .. blocked.step.source.name .. "): " .. blocked.status.message)
    end
    if count == 0 then print(L["No known blocked mount sources match your filters."]) end
    print(L["Sources without prerequisite data are unverified. Enable prerequisite quests in Settings to route known unlocks."])
end

function Prerequisites:QueueRefresh()
    if not self.ready or self.refreshPending then return end
    self.refreshPending = true
    C_Timer.After(0.2, function()
        self.refreshPending = nil
        if InCombatLockdown() then self.refreshAfterCombat = true; return end
        self.refreshAfterCombat = nil
        MRP.Filter:Apply(false, true)
    end)
end
