-- Shared, character-aware unlock graphs. Generated source records stay immutable.
-- local _, MRP = ...
local P = MRP.Prerequisites
P.chains, P.bindings = {}, {}

local function key(q) return (q.scope or "character") .. ":" .. (q.questID or q.id) end
local function onQuest(id) return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) end
local function result(state, message, quests, active) return { state = state, message = message, quests = quests or {}, active = active } end

function P:RegisterChain(id, chain)
    assert(not self.chains[id], "Duplicate unlock chain: " .. id)
    chain.nodes = {}
    for _, quest in ipairs(chain.quests or {}) do
        assert(not chain.nodes[key(quest)], "Duplicate quest in " .. id)
        chain.nodes[key(quest)] = quest
    end
    self.chains[id] = chain
end

function P:RegisterBinding(binding)
    assert(binding.sourceType and (binding.npcID or binding.itemID), "Unlock binding needs a stable source ID")
    self.bindings[#self.bindings + 1] = binding
end

function P:GetSupplement(step, mount)
    if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return nil end
    local entry = MRP.Util.GetStepEntry(step)
    for _, binding in ipairs(self.bindings) do
        if step.source.type == binding.sourceType
            and (not binding.npcID or binding.npcID == step.source.npcID or (entry and binding.npcID == entry.npcID))
            and (not binding.itemID or binding.itemID == mount.itemId) then
            if binding.get then return binding.get(step, mount) end
            return binding.source, binding.rewards and binding.rewards[mount.itemId]
        end
    end
end

-- Validation runs after all content modules load. Invalid graphs fail closed even
-- when the player's terminal flag happens to be set; they never become vendors.
function P:ValidateRegistry()
    local errors = {}
    local function validID(n) return type(n) == "number" and n > 0 and n == math.floor(n) end
    local function location(loc)
        return type(loc) == "table" and validID(loc.mapID) and type(loc.x) == "number" and type(loc.y) == "number"
            and loc.x >= 0 and loc.x <= 100 and loc.y >= 0 and loc.y <= 100
    end
    local visit
    visit = function(req, chain, stack, depth)
        assert(type(req) == "table" and depth < 64, "Malformed or too-deep requirement")
        if req.allOf or req.anyOf then
            assert(not (req.allOf and req.anyOf), "Ambiguous boolean requirement")
            local children = req.allOf or req.anyOf
            assert(type(children) == "table" and #children > 0, "Empty requirement")
            for _, child in ipairs(children) do visit(child, chain, stack, depth + 1) end
        elseif req.type == "chain" then
            local child = self.chains[req.id]
            assert(child, "Missing chain: " .. tostring(req.id))
            assert(not stack[child], "Unlock cycle")
            stack[child] = true
            visit(child.requirements, child, stack, depth + 1)
            stack[child] = nil
        elseif req.type == "quest" then
            assert(validID(req.id) and (req.scope == "character" or req.scope == "account"), "Invalid quest scope/ID")
            local node = chain.nodes[key(req)]
            if node then
                assert(not stack[node], "Quest dependency cycle")
                stack[node] = true
                if node.requires then visit(node.requires, chain, stack, depth + 1) end
                stack[node] = nil
            else
                assert(req.checkOnly, "Missing quest node: " .. req.id)
            end
        elseif req.type == "reputation" then
            assert(validID(req.factionID) and validID(req.standing) and req.standing <= 8, "Invalid reputation")
        elseif req.type == "item" then
            assert(validID(req.id) and validID(req.count), "Invalid item requirement")
        else
            error("Unsupported graph requirement: " .. tostring(req.type))
        end
    end
    for id, chain in pairs(self.chains) do
        local ok, err = pcall(function()
            assert(type(chain.evidence) == "string" and chain.evidence ~= "", "Missing evidence")
            for _, q in ipairs(chain.quests or {}) do
                assert(validID(q.questID) and (q.scope == "character" or q.scope == "account"), "Invalid quest")
                for _, phase in ipairs({ "accept", "objective", "turnIn" }) do
                    if q[phase] then assert(location(q[phase]), "Invalid " .. phase .. " location") end
                end
                if q.mapID or q.x or q.y then assert(location(q), "Invalid giver location") end
                if q.requires then visit(q.requires, chain, {}, 0) end
                if q.progress then visit(q.progress, chain, {}, 0) end
            end
            visit(chain.requirements, chain, { [chain] = true }, 0)
        end)
        chain.invalid = not ok or nil
        if not ok then errors[#errors + 1] = id .. ": " .. tostring(err) end
    end
    for id, group in pairs(self.dailyGroups or {}) do
        local ok, err = pcall(function()
            assert(type(group.evidence) == "string" and group.evidence ~= "", "Missing daily evidence")
            assert(validID(group.npcID) and location(group), "Invalid daily giver")
            assert(type(group.quests) == "table" and #group.quests > 0, "Empty daily group")
            for _, q in ipairs(group.quests) do
                assert(validID(q.questID) and q.scope == "character" and q.daily, "Invalid daily quest")
                assert(location(q.turnIn), "Invalid daily turn-in")
                if q.objective then assert(location(q.objective), "Invalid daily objective") end
            end
            local context = { nodes = {} }
            if group.requires then visit(group.requires, context, {}, 0) end
            if group.prepare then visit(group.prepare, context, {}, 0) end
            for _, requirement in pairs(group.factionRequirements or {}) do visit(requirement, context, {}, 0) end
        end)
        group.invalid = not ok or nil
        if not ok then errors[#errors + 1] = id .. ": " .. tostring(err) end
    end
    table.sort(errors)
    self.validationErrors = errors
    return #errors == 0, errors
end

-- Resolve only the ready frontier. Completed terminals bypass historical quests.
-- OR prefers an active alternative, then the first curated viable alternative.
function P:ResolveRequirement(req, chain, depth)
    depth = (depth or 0) + 1
    if depth > 64 or type(req) ~= "table" then return result("unknown", MRP.L["Prerequisite data is unknown."]) end
    local met = self:Evaluate(req)
    if met == true then return result("completed") end
    if req.type == "chain" then
        local child = self.chains[req.id]
        if not child or child.invalid then return result("unknown", MRP.L["Prerequisite data is unknown."]) end
        return self:ResolveRequirement(child.requirements, child, depth)
    elseif req.allOf then
        local actions, messages, unknown, active = {}, {}, false, false
        for _, child in ipairs(req.allOf) do
            local resolved = self:ResolveRequirement(child, chain, depth)
            if resolved.state == "unknown" then unknown = true end
            active = active or resolved.active
            for _, q in ipairs(resolved.quests) do actions[#actions + 1] = q end
            if resolved.message then messages[#messages + 1] = resolved.message end
        end
        return result(unknown and "unknown" or (#actions > 0 and "actionable" or "waiting"), table.concat(messages, "\n"), unknown and {} or actions, active)
    elseif req.anyOf then
        local candidates = {}
        for _, child in ipairs(req.anyOf) do
            local resolved = self:ResolveRequirement(child, chain, depth)
            candidates[#candidates + 1] = resolved
            if resolved.active then return resolved end
        end
        for _, candidate in ipairs(candidates) do if candidate.state == "actionable" then return candidate end end
        for _, candidate in ipairs(candidates) do if candidate.state == "waiting" then return candidate end end
        return candidates[1] or result("unknown", MRP.L["Prerequisite data is unknown."])
    elseif req.type == "quest" and chain then
        local quest = chain.nodes[key(req)]
        if quest then
            -- An accepted quest is direct evidence that its predecessors were met.
            if not onQuest(quest.questID) and quest.requires and self:Evaluate(quest.requires) ~= true then
                return self:ResolveRequirement(quest.requires, chain, depth)
            end
            if met == nil then return result("unknown", self:Describe(req)) end
            if onQuest(quest.questID) and quest.progress and not (C_QuestLog.IsComplete and C_QuestLog.IsComplete(quest.questID)) then
                local progress = self:Evaluate(quest.progress)
                if progress ~= true then
                    local dailies = progress == false and self.ResolveDailyProgress and self:ResolveDailyProgress(quest.progress, quest)
                    if dailies then
                        dailies.active = true
                        dailies.message = (quest.waitMessage or self:Describe(quest.progress)) .. (dailies.message and "\n" .. dailies.message or "")
                        return dailies
                    end
                    return result(progress == nil and "unknown" or "waiting", quest.waitMessage or self:Describe(quest.progress), nil, true)
                end
            end
            return result("actionable", nil, { quest }, onQuest(quest.questID))
        end
    end
    if met == false and self.ResolveDailyProgress then
        local dailies = self:ResolveDailyProgress(req)
        if dailies then return dailies end
    end
    return result(met == nil and "unknown" or "waiting", self:Describe(req))
end

-- Common constructors keep authored data explicit and compact.
P.RequireQuest = function(id) return { type = "quest", id = id, scope = "character" } end
P.RequireChain = function(id) return { type = "chain", id = id } end
P.RequireReputation = function(id, standing) return { type = "reputation", factionID = id, standing = standing } end
