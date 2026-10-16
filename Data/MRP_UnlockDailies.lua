-- Curated Retail daily loops. IDs/givers/prerequisites are from the evidence on
-- the corresponding permanent chains. Offers are verified at the NPC, not guessed.
-- local _, MRP = ...
local P = MRP.Prerequisites
local Q, C, R = P.RequireQuest, P.RequireChain, P.RequireReputation
local function check(id) local q = Q(id); q.checkOnly = true; return q end
local function daily(id, name) return { questID = id, name = name } end
local function preparation(id, questID, name, x, y, requires, tx, ty)
    P:RegisterChain(id, { evidence = P.chains["netherwing.service"].evidence, requirements = Q(questID), quests = {
        { questID = questID, name = name, scope = "character", mapID = 104, x = x, y = y,
            requires = requires, turnIn = { mapID = 104, x = tx or x, y = ty or y } },
    } })
end
preparation("netherwing.inside", 11019, "Your Friend on the Inside", 65.9, 86.4, C("netherwing.service"))
preparation("netherwing.mines", 11075, "The Netherwing Mines", 66, 86.4, check(11053), 63, 87.8)
preparation("netherwing.overseeing", 11054, "Overseeing and You: Making the Right Choices", 66.8, 86, check(11053))

P.netherwingDailyGroups = {}
local function netherwing(id, name, npc, x, y, requires, prepare, quests)
    id = "netherwing.daily." .. id
    P.netherwingDailyGroups[#P.netherwingDailyGroups + 1] = id
    P:RegisterDailyGroup(id, { name = name, npcID = npc, mapID = 104, x = x, y = y,
        evidence = P.chains["netherwing.service"].evidence, requires = requires, prepare = prepare, quests = quests,
        note = "Earn Netherwing reputation toward the next promotion. Complete available dailies, then return after the server daily reset. Egg turn-ins can also accelerate reputation." })
end
netherwing("crystals", "Taskmaster Varkule Dragonbreath", 23140, 66, 86.4, C("netherwing.service"), nil,
    { daily(11015, "Netherwing Crystals") })
netherwing("yarzill", "Yarzill the Merc", 23141, 65.9, 86.4, C("netherwing.service"), C("netherwing.inside"),
    { daily(11020, "A Slow Death"), daily(11035, "The Not-So-Friendly Skies...") })
local friendly = { allOf = { check(11053), R(1015, 5) } }
netherwing("cargo", "Mistress of the Mines", 23149, 63, 87.8, friendly, C("netherwing.mines"),
    { daily(11076, "Picking Up the Pieces...") })
netherwing("flayers", "Dragonmaw Foreman", 23376, 63.4, 87.4, friendly, C("netherwing.mines"),
    { daily(11077, "Dragons Are the Least of Our Problems") })
netherwing("booterang", "Chief Overseer Mudlump", 23291, 66.8, 86, friendly, C("netherwing.overseeing"),
    { daily(11055, "The Booterang: A Cure for the Common Worthless Peon") })
netherwing("portal", "Overlord Mor'ghor", 23139, 66.3, 85.6, { allOf = { check(11084), R(1015, 6) } }, nil,
    { daily(11086, "Disrupting the Twilight Portal") })
P.dailyQuests[11086].objective = { mapID = 107, x = 12, y = 40.6 }

local weaponNames = { "A Blade Fit for a Champion", "A Worthy Weapon", "The Edge of Winter" }
local function tournament(id, name, faction, npc, x, y, quests, rotation)
    P:RegisterDailyGroup(id, { name = name, npcID = npc, mapID = 118, x = x, y = y, faction = faction,
        evidence = P.chains["argent.intro." .. faction].evidence, quests = quests, rotation = rotation,
        note = "Collect seals for the active Tournament charge. Only today's offered weapon quest is routed. Use a tournament lance and mount for mounted combat." })
    return id
end
local function weapons(ids)
    local result = {}
    for i, id in ipairs(ids) do result[i] = daily(id, weaponNames[i]) end
    return result
end
for _, row in ipairs({
    { "Alliance", 13672, 33625, 76.5, 19.4, { 13666, 13669, 13670 }, 33646, 76.4, 19.4, 13671, 33647, 76.5, 19.5, 13625 },
    { "Horde", 13678, 33542, 76.3, 24.4, { 13673, 13674, 13675 }, 33658, 76.3, 24.3, 13676, 33659, 76.2, 24.4, 13677 },
}) do
    local prefix = "argent.daily.aspirant." .. row[1]
    P.sealDailyGroups[row[2]] = {
        tournament(prefix .. ".weapon", "Aspirant weapon daily", row[1], row[3], row[4], row[5], weapons(row[6]), true),
        tournament(prefix .. ".field", "Aspirant field training", row[1], row[7], row[8], row[9], { daily(row[10], "Training in the Field") }),
        tournament(prefix .. ".reins", "Aspirant mounted training", row[1], row[11], row[12], row[13], { daily(row[14], "Learning the Reins") }),
    }
end

-- City; weapon IDs/giver; field ID/giver/coordinates; melee/gates IDs/giver/coordinates.
-- Weapon giver coordinates match the city's charge giver in MRP_UnlockTournament.
local cities = {
    { "Stormwind", { 13603, 13600, 13616 }, 33225, 13592, 33222, 76.5, 19.1, 13665, 13847, 33223, 76.6, 19.2 },
    { "Ironforge", { 13741, 13742, 13743 }, 33312, 13744, 33315, 76.7, 19.4, 13745, 13851, 33309, 76.6, 19.6 },
    { "Gnomeregan", { 13746, 13747, 13748 }, 33335, 13749, 33648, 76.6, 19.8, 13750, 13852, 33649, 76.5, 19.9 },
    { "Darnassus", { 13757, 13758, 13759 }, 33592, 13760, 33652, 76.3, 19, 13761, 13855, 33654, 76.4, 19 },
    { "Exodar", { 13752, 13753, 13754 }, 33593, 13755, 33655, 76.1, 19.2, 13756, 13854, 33656, 76.1, 19.1 },
    { "Orgrimmar", { 13762, 13763, 13764 }, 33361, 13765, 33405, 76.5, 24.5, 13767, 13856, 33544, 76.4, 24.6 },
    { "Sen'jin", { 13768, 13769, 13770 }, 33372, 13771, 33540, 76, 24.6, 13772, 13857, 33545, 75.9, 24.4 },
    { "Thunder Bluff", { 13773, 13774, 13775 }, 33403, 13776, 33539, 76.3, 24.7, 13777, 13858, 33549, 76.1, 24.6 },
    { "Undercity", { 13778, 13779, 13780 }, 33373, 13781, 33541, 76.6, 24.1, 13782, 13860, 33547, 76.5, 24.3 },
    { "Silvermoon", { 13783, 13784, 13785 }, 33379, 13786, 33538, 76.4, 23.8, 13787, 13859, 33548, 76.5, 23.9 },
}
for _, row in ipairs(cities) do
    for _, city in ipairs(P.tournamentCities) do
        if row[1] == city[1] then
            local prefix, faction = "argent.daily.valiant." .. row[1], city.faction
            P.sealDailyGroups[city[6]] = {
                tournament(prefix .. ".weapon", row[1] .. " weapon daily", faction, row[3], city[9], city[10], weapons(row[2]), true),
                tournament(prefix .. ".field", row[1] .. " field training", faction, row[5], row[6], row[7], { daily(row[4], "A Valiant's Field Training") }),
                tournament(prefix .. ".mounted", row[1] .. " mounted dailies", faction, row[10], row[11], row[12], {
                    daily(row[8], "The Grand Melee"), daily(row[9], "At the Enemy's Gates"),
                }),
            }
        end
    end
end
