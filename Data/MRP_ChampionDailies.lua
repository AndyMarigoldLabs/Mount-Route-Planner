-- Retail Champion's Seal sources. Only live offered/accepted quests become work.
-- local _, MRP = ...
local P = MRP.Prerequisites
local evidence = P.chains["argent.intro.Alliance"].evidence
local function check(id) return { type = "quest", id = id, scope = "character", checkOnly = true } end
local function q(id, name) return { questID = id, name = name } end
P.championProfiles, P.championExtraGroups = {}, {}
local function group(id, name, npc, x, y, faction, requires, quests, rotation)
    id = "argent.champion." .. id
    P:RegisterDailyGroup(id, { name = name, npcID = npc, mapID = 118, x = x, y = y,
        faction = faction, requires = requires, quests = quests, rotation = rotation,
        championSeals = true, evidence = evidence,
        note = "Earn Champion's Seals for your selected mounts. Choose and open a Champion's Purse when offered; unopened rewards are not spendable seals." })
    return id
end
for _, row in ipairs({
    { "Alliance", "other", 13794, 13790, 13789, 13861, 13682 },
    { "Horde", "other", 13794, 13811, 13810, 13862, 13809 },
    { "Alliance", "DEATHKNIGHT", 13795, 13793, 13791, 13864, 13788 },
    { "Horde", "DEATHKNIGHT", 13795, 13814, 13813, 13863, 13812 },
}) do
    local faction, class, introID = row[1], row[2], row[3]
    local dk = class == "DEATHKNIGHT"
    local key = faction .. "." .. class
    local first = { anyOf = { P.tournamentFirst[faction], check(introID) } }
    local intro = { questID = introID, name = dk and "The Scourgebane" or "Eadric the Pure", scope = "character",
        mapID = 118, x = 69.6, y = 22.8, requires = P.tournamentFirst[faction],
        turnIn = { mapID = 118, x = dk and 73.8 or 69.9, y = dk and 20 or 23.4 } }
    P:RegisterChain("argent.champion.intro." .. key, { evidence = evidence, requirements = P.RequireQuest(introID), quests = { intro } })
    local prefix = key .. "."
    P.championProfiles[key] = { introID = introID, intro = "argent.champion.intro." .. key,
        quests = { row[4], row[5], row[6], row[7] }, groups = {
            group(prefix .. "melee", dk and "Illyrie Nightfall" or "Luuri", dk and 33770 or 33771,
                dk and 73.6 or 69.8, dk and 20 or 23.3, faction, first, { q(row[4], "Among the Champions") }),
            group(prefix .. "field", dk and "Zor'be the Bloodletter" or "Cellian Daybreak", dk and 33769 or 33763,
                dk and 73.8 or 69.9, dk and 19.6 or 23.4, faction, first, { q(row[5], "Taking Battle to the Enemy") }),
            group(prefix .. "citadel", dk and "Crok Scourgebane" or "Eadric the Pure", dk and 33762 or 33759,
                dk and 73.8 or 69.9, dk and 20 or 23.4, faction, first, { q(row[6], "Battle Before the Citadel") }),
            group(prefix .. "threat", dk and "Crok Scourgebane" or "Eadric the Pure", dk and 33762 or 33759,
                dk and 73.8 or 69.9, dk and 20 or 23.4, faction,
                { allOf = { first, check(13664) } }, { q(row[7], "Threat from Above") }),
        } }
end

for _, row in ipairs({
    { "Alliance", 1094, 34880, 34912, 76.2, 19.6, { 14074, 14152, 14080, 14077, 14096 }, { 14076, 14090, 14112 } },
    { "Horde", 1124, 34771, 34914, 76.1, 24, { 14143, 14136, 14140, 14144, 14142 }, { 14092, 14141, 14145 } },
}) do
    local faction, ids, food = row[1], row[7], row[8]
    local exalted = { allOf = { P.tournamentFirst[faction], P.RequireReputation(row[2], 8) } }
    P.championExtraGroups[faction] = {
        group(faction .. ".exalted.rescue", faction == "Alliance" and "Narasi Snowdawn" or "Girana the Blooded",
            row[3], row[5], row[6], faction, exalted, {
                q(ids[1], "A Leg Up"), q(ids[2], "Rescue at Sea"), q(ids[3], "Stop the Aggressors"), q(ids[4], "The Light's Mercy"),
            }, true),
        group(faction .. ".exalted.kul", faction == "Alliance" and "Narasi Snowdawn - Kul" or "Girana the Blooded - Kul",
            row[3], row[5], row[6], faction, exalted, { q(ids[5], "You've Really Done It This Time, Kul") }),
        group(faction .. ".exalted.food", faction == "Alliance" and "Savinia Loresong" or "Tylos Dawnrunner",
            row[4], row[5], row[6], faction, exalted, {
                q(food[1], "Breakfast of Champions"), q(food[2], "Gormok Wants His Snobolds"), q(food[3], "What Do You Feed a Yeti, Anyway?"),
            }, true),
    }
end
-- Neutral quest IDs must be registered once. Resolve their gate for this character,
-- never from an account-wide Crusader achievement/title.
local crusaderGroups = {
    group("crusader.adelard", "High Crusader Adelard", 34882, 69.4, 23.1, nil, nil, {
        q(14105, "Deathspeaker Kharos"), q(14101, "Drottinn Hrothgar"), q(14102, "Mistcaller Yngvar"), q(14104, "Ornolf the Scarred"),
    }, true),
    group("crusader.silverdawn", "Crusader Silverdawn", 35094, 69.4, 23.1, nil, nil, {
        q(14107, "The Fate of the Fallen"), q(14108, "Get Kraken!"),
    }, true),
}
for _, id in ipairs(crusaderGroups) do
    P.dailyGroups[id].factionRequirements = {
        Alliance = P.tournamentGoals.Alliance.crusader, Horde = P.tournamentGoals.Horde.crusader,
    }
end
for _, groups in pairs(P.championExtraGroups) do for _, id in ipairs(crusaderGroups) do groups[#groups + 1] = id end end
