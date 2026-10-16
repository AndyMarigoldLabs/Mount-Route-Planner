-- Runtime choices and navigation for the first curated Retail content packs.
-- local _, MRP = ...
local P = MRP.Prerequisites
local function onQuest(id) return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) end
local function npcID(step)
    local entry = MRP.Util.GetStepEntry(step)
    return step.source.npcID or (entry and entry.npcID)
end
local function isNetherwing(step, mount)
    if step.source.type ~= "Quest" and not (step.source.type == "Vendor" and npcID(step) == 23489) then return false end
    for _, drake in ipairs(P.netherwingDrakes) do if drake.item == mount.itemId then return true end end
    return false
end

function P:PrepareWaveContext(steps)
    self.netherwingChoice, self.tournamentPath = nil, nil
    if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end
    local goals, anyChampion, crusader = {}, false, false
    local faction = UnitFactionGroup("player")
    for _, step in ipairs(steps) do
        for _, mount in ipairs(step.mounts) do
            local _, _, collected = MRP.Util.GetMountInfoSafe(mount)
            if not collected and MRP_CharacterSettings.filter.collectedStates[collected] and self:IsMountAllowed(step, mount) then
                if isNetherwing(step, mount) then
                    self.netherwingChoice = math.min(self.netherwingChoice or mount.itemId, mount.itemId)
                end
                if step.source.type == "Vendor" then
                    local npc = npcID(step)
                    for _, city in ipairs(self.tournamentCities) do if city[2] == npc then goals[city[1]] = true end end
                    if mount.itemId == 45725 or npc == 34881 or npc == 34772 then anyChampion = true end
                    if npc == 34885 then crusader = true end
                end
            end
        end
    end
    for _, drake in ipairs(self.netherwingDrakes) do
        if onQuest(drake.quest) then self.netherwingChoice = drake.item; break end
    end
    if not self.tournamentGoals[faction] then return end
    local _, race = UnitRace("player")
    local homeName = self.tournamentHome[race]
    local home, active, enrolled, target, champion
    for _, city in ipairs(self.tournamentCities) do
        if city.faction == faction then
            local done = self:Evaluate(city.completed) == true
            if city[1] == homeName then home = city end
            -- Enrollment on this character is stronger evidence than a race mapping.
            if onQuest(city[4]) or self:IsQuestComplete(city[4]) then home = city end
            if done then champion = champion or city end
            if not done then
                if onQuest(city[4]) or onQuest(city[5]) or onQuest(city[6]) or onQuest(city[7]) then active = active or city end
                if self:IsQuestComplete(city[4]) or self:IsQuestComplete(city[5]) then enrolled = enrolled or city end
                if goals[city[1]] or crusader then target = target or city end
            end
        end
    end
    if not target and not anyChampion and not crusader and not next(goals) then return end
    if self:Evaluate(self.tournamentFirst[faction]) ~= true then
        -- Finish the first city's handoff before offering another city's enrollment.
        local first = champion or active or enrolled or home
        if first then self.tournamentPath = self.RequireChain("argent.first." .. first[1])
        elseif self:Evaluate(self.RequireChain("argent.intro." .. faction)) ~= true then
            self.tournamentPath = self.RequireChain("argent.intro." .. faction)
        end
    else
        target = active or enrolled or target
        if target then self.tournamentPath = self.RequireChain("argent.away." .. target[1]) end
    end
end

local grettaDailies = { 13422, 13423, 13424, 13425 }
local function grettaOffer()
    local guid = UnitGUID and UnitGUID("npc")
    if not guid or tonumber(guid:match("%-(%d+)%-%x+$")) ~= 29796
        or not (C_GossipInfo and C_GossipInfo.GetAvailableQuests) then return nil end
    for _, offer in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
        for _, id in ipairs(grettaDailies) do if offer.questID == id then return id end end
    end
end
local getAvailability = P.GetMountAvailability
function P:GetMountAvailability(step, mount)
    local status = getAvailability(self, step, mount)
    if status.state == "unknown" then return status end
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and step.source.type == "Quest" and isNetherwing(step, mount)
        and self:Evaluate(self.RequireChain("netherwing.claimed")) == false
        and self:Evaluate(self.RequireChain("netherwing.finale")) == true
        and self.netherwingChoice and mount.itemId ~= self.netherwingChoice then
        return { state = "waiting", quests = {}, message = MRP.L["Choose one free Netherwing drake first. Remaining colors are purchased from Hurlunk."] }
    end
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and mount.itemId == 43962 and step.source.type == "OpenWorld" then
        local curated = self:GetSupplement(step, mount)
        for _, provider in ipairs(self:GetProviders(step, mount)) do
            if provider ~= curated and self:Evaluate(provider.requirements) ~= true then return status end
        end
        if grettaOffer() then return { state = "available", message = "" } end
        for _, id in ipairs(grettaDailies) do
            if onQuest(id) then return { state = "available", message = "" } end
        end
        for _, id in ipairs(grettaDailies) do
            if self:IsQuestComplete(id) then
                return { state = "waiting", message = MRP.L["Gretta's daily is complete for this reset. Check again after the daily reset."], quests = {} }
            end
        end
    end
    return status
end

local function copyMounts(step, note, cost)
    local mounts = {}
    for _, mount in ipairs(step.mounts) do
        local copy = MRP.Util.ShallowCopy(mount)
        copy.source = MRP.Util.ShallowCopy(mount.source)
        copy.source.note = note
        if cost then copy.source.cost, copy.source.costs = cost, nil end
        mounts[#mounts + 1] = copy
    end
    step.mounts = mounts
end

function P:GetRouteOverride(step)
    if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return step end
    local first = step.mounts[1]
    if first and step.source.type == "Quest" and isNetherwing(step, first)
        and self:Evaluate(self.RequireChain("netherwing.claimed")) == false then
        local chain = self.chains["netherwing.choice." .. first.itemId]
        -- Once the unlock is done, the reward quest is usable even with opt-in off.
        return self:MakeQuestStep(chain.quests[1], step, first)
    end
    if first and isNetherwing(step, first) and self:Evaluate(self.RequireChain("netherwing.claimed")) == true then
        step.targetStepIDs = { [step.id] = true }
        step.id = "unlock-source:vendor:23489"
        step.source = { type = "Vendor", name = "Drake Dealer Hurlunk", npcID = 23489 }
        step.entry = { mapID = 104, x = 65.6, y = 85.9, npcID = 23489, questID = 0 }
        step.source.runtimeEntry = step.entry
        step.runtimeLocation = true
        copyMounts(step, "Your free Netherwing drake has been claimed. Buy remaining colors from Hurlunk.", { type = "gold", amount = 2000000 })
        for _, mount in ipairs(step.mounts) do mount.source.specialEncounter = { name = step.source.name } end
    elseif first and first.itemId == 45725 and step.source.type == "Vendor" then
        -- The generated row has a generic camp location. Use an unlocked vendor.
        for _, city in ipairs(self.tournamentCities) do
            if city.faction == UnitFactionGroup("player") and self:Evaluate(city.completed) == true then
                step.entry = { mapID = 118, x = city[11], y = city[12], npcID = city[2], questID = 0 }
                step.runtimeLocation = true
                break
            end
        end
    elseif first and first.itemId == 43962 and step.source.type == "OpenWorld" then
        step.entry = MRP.Util.ShallowCopy(MRP.Util.GetStepEntry(step) or {})
        step.entry.mapID, step.entry.x, step.entry.y, step.entry.npcID = 120, 50.8, 65.6, 29796
        step.runtimeLocation = true
        for _, id in ipairs(grettaDailies) do
            if onQuest(id) then
                step.acquisitionQuest = { questID = id, scope = "character", turnIn = { mapID = 120, x = 50.8, y = 65.6 } }
                break
            end
        end
        local offer = grettaOffer()
        if offer and not step.acquisitionQuest then
            step.acquisitionQuest = { questID = offer, scope = "character", mapID = 120, x = 50.8, y = 65.6,
                turnIn = { mapID = 120, x = 50.8, y = 65.6 } }
        end
        copyMounts(step, "Check Gretta for today's rotating daily. Hyldnir Spoils is its reward; the bag is not an object to click in the village.")
    end
    return step
end

P:ValidateRegistry()
