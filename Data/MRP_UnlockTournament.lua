-- local _, MRP = ...
local P = MRP.Prerequisites
local Q, C, R = P.RequireQuest, P.RequireChain, P.RequireReputation
local evidence = "https://github.com/DFortun81/AllTheThings/blob/master/.contrib/.db/standard/06%20-%20Expansion%20Features/03%20-%20Wrath%20of%20the%20Lich%20King/Argent%20Tournament.lua"
local function loc(x, y) return { mapID = 118, x = x, y = y } end
local function quest(id, name, x, y, requires, tx, ty)
    return { questID = id, name = name, scope = "character", mapID = 118, x = x, y = y,
        requires = requires, turnIn = loc(tx or x, ty or y) }
end
local function check(id) local q = Q(id); q.checkOnly = true; return q end
local function sealQuest(q, item, count, name)
    q.progress = { type = "item", id = item, count = count }
    q.waitMessage = string.format("%s: collect %d %s from the Tournament dailies in Icecrown. Resume this quest when you have enough; daily resets may be needed.", q.name, count, name)
    q.note = q.waitMessage
    return q
end
local factions = {
    Alliance = { intro = 13667, mastery = { 13828, 13837, 13835 }, charge = 13672, challenge = 13679, x = 76.5, y = 19.4 },
    Horde = { intro = 13668, mastery = { 13829, 13839, 13838 }, charge = 13678, challenge = 13680, x = 76.3, y = 24.4 },
}
for faction, info in pairs(factions) do
    local intro = quest(info.intro, "The Argent Tournament", 69.6, 22.8, nil, info.x, info.y)
    local nodes, mastery = { intro }, { allOf = {} }
    local names = { "Mastery of Melee", "Mastery of the Charge", "Mastery of the Shield-Breaker" }
    local objectives = { loc(72.6, 19.2), loc(72.6, 18.8), loc(73.2, 19.2) }
    for i, id in ipairs(info.mastery) do
        local q = quest(id, names[i], info.x, info.y, Q(info.intro))
        q.objective = objectives[i]
        nodes[#nodes + 1] = q
        mastery.allOf[#mastery.allOf + 1] = Q(id)
    end
    nodes[#nodes + 1] = sealQuest(quest(info.charge, "Up To The Challenge", info.x, info.y, mastery), 45192, 15, "Aspirant's Seals")
    local challenge = quest(info.challenge, "The Aspirant's Challenge", info.x, info.y, Q(info.charge))
    challenge.objective = loc(71.4, 19.6)
    nodes[#nodes + 1] = challenge
    P:RegisterChain("argent.intro." .. faction, { evidence = evidence, requirements = Q(info.challenge), quests = nodes })
end

-- City, vendor NPC, reputation, home enrollment, later enrollment, charge,
-- challenge, first Champion Rises, quest giver coordinates, vendor coordinates.
P.tournamentCities = {
    { "Stormwind", 33307, 72, 13684, 13593, 13718, 13699, 13702, 76.6, 19.1, 76.4, 19.2, faction = "Alliance" },
    { "Ironforge", 33310, 47, 13685, 13703, 13714, 13713, 13732, 76.6, 19.5, 76.4, 19.4, faction = "Alliance" },
    { "Gnomeregan", 33650, 54, 13688, 13704, 13715, 13723, 13733, 76.5, 19.8, 76.4, 19.6, faction = "Alliance" },
    { "Darnassus", 33653, 69, 13689, 13706, 13717, 13725, 13735, 76.3, 19.0, 76.2, 19.2, faction = "Alliance" },
    { "Exodar", 33657, 930, 13690, 13705, 13716, 13724, 13734, 76.1, 19.1, 76.2, 19.2, faction = "Alliance" },
    { "Orgrimmar", 33553, 76, 13691, 13707, 13697, 13726, 13736, 76.5, 24.6, 76.4, 24.2, faction = "Horde" },
    { "Sen'jin", 33554, 530, 13693, 13708, 13719, 13727, 13737, 76.0, 24.5, 76.0, 24.4, faction = "Horde" },
    { "Thunder Bluff", 33556, 81, 13694, 13709, 13720, 13728, 13738, 76.2, 24.6, 76.2, 24.4, faction = "Horde" },
    { "Undercity", 33555, 68, 13695, 13710, 13721, 13729, 13739, 76.5, 24.2, 76.4, 24.0, faction = "Horde" },
    { "Silvermoon", 33557, 911, 13696, 13711, 13722, 13731, 13740, 76.5, 23.9, 76.2, 23.8, faction = "Horde" },
}
P.tournamentGoals, P.tournamentFirst = {}, {}
for faction in pairs(factions) do
    local first, champion, crusader = { anyOf = {} }, { anyOf = {} }, { allOf = { R(1106, 8) } }
    for _, city in ipairs(P.tournamentCities) do
        if city.faction == faction then
            city.completed = { anyOf = { check(city[7]), check(city[8]) } }
            first.anyOf[#first.anyOf + 1] = check(city[8])
            champion.anyOf[#champion.anyOf + 1] = city.completed
            crusader.allOf[#crusader.allOf + 1] = city.completed
            crusader.allOf[#crusader.allOf + 1] = R(city[3], 8)
        end
    end
    P.tournamentFirst[faction] = first
    P.tournamentGoals[faction] = { champion = champion, crusader = crusader }
end
for _, city in ipairs(P.tournamentCities) do
    local info = factions[city.faction]
    for _, mode in ipairs({ "home", "away" }) do
        local enrollment = mode == "home" and city[4] or city[5]
        local requirement = mode == "home" and C("argent.intro." .. city.faction) or P.tournamentFirst[city.faction]
        local enroll = quest(enrollment, "Valiant of " .. city[1], mode == "home" and info.x or city[9], mode == "home" and info.y or city[10], requirement, city[9], city[10])
        local charge = sealQuest(quest(city[6], "The Valiant's Charge - " .. city[1], city[9], city[10], Q(enrollment)), 44987, 25, "Valiant's Seals")
        local challenge = quest(city[7], "The Valiant's Challenge - " .. city[1], city[9], city[10], Q(city[6]))
        challenge.objective = loc(68.8, 20.4)
        P:RegisterChain("argent." .. mode .. "." .. city[1], { evidence = evidence, requirements = Q(city[7]), quests = { enroll, charge, challenge } })
    end
    P:RegisterChain("argent.first." .. city[1], { evidence = evidence, requirements = Q(city[8]), quests = {
        quest(city[8], "A Champion Rises - " .. city[1], city[9], city[10], C("argent.home." .. city[1])),
    } })
end

-- Only confirmed home-city mappings. Later races with unverified assignments
-- can still use observed enrollment/Champion progress; no guessed race fallback.
P.tournamentHome = { Human = "Stormwind", Dwarf = "Ironforge", Gnome = "Gnomeregan", NightElf = "Darnassus",
    Worgen = "Darnassus", Draenei = "Exodar", Orc = "Orgrimmar", Goblin = "Orgrimmar", Troll = "Sen'jin",
    Tauren = "Thunder Bluff", Scourge = "Undercity", BloodElf = "Silvermoon" }
local function provider(goal, faction, class)
    local goals = P.tournamentGoals[faction]
    local requirements = type(goal) == "table" and goal or (goals and goals[goal]) or { type = "unsupportedTournamentFaction" }
    return { requirements = requirements, unlockRequirement = P.tournamentPath or { type = "unsupportedTournamentEnrollment" } },
        { faction = faction, class = class }
end
for _, city in ipairs(P.tournamentCities) do
    P:RegisterBinding({ sourceType = "Vendor", npcID = city[2], get = function() return provider(city.completed, city.faction) end })
end
P:RegisterBinding({ sourceType = "Vendor", itemID = 45725, get = function()
    -- UnitFactionGroup also returns a localized name. Do not let Lua pass that
    -- extra return as provider's optional class restriction.
    local faction = UnitFactionGroup("player")
    return provider("champion", faction)
end })
for _, info in ipairs({ { 34881, "Alliance", 1094 }, { 34772, "Horde", 1124 } }) do
    P:RegisterBinding({ sourceType = "Vendor", npcID = info[1], get = function()
        local source, reward = provider("champion", info[2])
        reward.requirements = R(info[3], 8)
        return source, reward
    end })
end
P:RegisterBinding({ sourceType = "Vendor", npcID = 34885, get = function(_, mount)
    return provider("crusader", UnitFactionGroup("player"), mount.itemId == 47179 and "PALADIN" or nil)
end })
