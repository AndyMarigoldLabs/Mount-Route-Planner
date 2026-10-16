-- Retail Sons of Hodir daily sources and their permanent preparation paths.
-- local _, MRP = ...
local P = MRP.Prerequisites
local Q, C, R = P.RequireQuest, P.RequireChain, P.RequireReputation
local evidence = P.chains["storm.hodir"].evidence
local function loc(x, y) return { mapID = 120, x = x, y = y } end
local function quest(id, name, x, y, requires, tx, ty)
    return { questID = id, name = name, scope = "character", mapID = 120, x = x, y = y,
        requires = requires, turnIn = loc(tx or x, ty or y) }
end
local started = Q(12924); started.allowActive = true
local forging = quest(12924, "Forging an Alliance", 33.4, 58, C("storm.hodir"), 63.2, 63.2)
-- Accept the parent, do Jokkum/Njormeld's child quests, then turn in the parent.
-- Requiring the parent's completion before its children would deadlock this path.
forging.progress = Q(12967)
forging.note = "Accept Forging an Alliance, then help King Jokkum and Njormeld bring the anvil to Dun Niffelem before turning it in."
local anvil = {
    forging,
    quest(12966, "You Can't Miss Him", 65.4, 60.1, started, 75.4, 63.6),
    quest(12967, "Battling the Elements", 75.4, 63.6, Q(12966)),
}
anvil[3].note = "Use Snorri to complete the vehicle objectives, then return to Njormeld at Fjorn's Anvil."
P:RegisterChain("storm.hodir.anvil", { evidence = evidence, requirements = Q(12967), quests = anvil })
P:RegisterChain("storm.hodir.alliance", { evidence = evidence, requirements = Q(12924), quests = anvil })
P:RegisterChain("storm.hodir.horn", { evidence = evidence, requirements = Q(12976), quests = {
    quest(12975, "In Memoriam", 65.4, 60.1, C("storm.hodir.alliance")),
    quest(12976, "A Monument to the Fallen", 65.4, 60.1, Q(12975), 63.2, 63.2),
} })
P:RegisterChain("storm.hodir.helm", { evidence = evidence, requirements = Q(12987), quests = {
    quest(12985, "Forging a Head", 63.2, 63.2, { allOf = { C("storm.hodir.anvil"), R(1119, 5) } }),
    quest(12987, "Placing Hodir's Helm", 63.2, 63.2, Q(12985)),
} })
P:RegisterChain("storm.hodir.spear", { evidence = evidence, requirements = Q(13001), quests = {
    quest(13001, "Raising Hodir's Spear", 64.8, 59.1, { allOf = { C("storm.hodir"), R(1119, 6) } }),
} })

P.hodirDailyGroups = {}
-- Object givers are intentionally distinct from NPC IDs. QUEST_DETAIL also
-- confirms offers when clicking an object does not expose an "npc" unit GUID.
for _, row in ipairs({
    { "cold", 12981, "Hot and Cold", "Fjorn's Anvil", "objectID", 192071, 63.2, 63, 4, "anvil" },
    { "horn", 12977, "Hodir's Call", "Hodir's Horn", "objectID", 192078, 64.1, 64.7, 4, "horn" },
    { "helm", 13006, "A Viscous Cleaning", "Hodir's Helm", "objectID", 192080, 64.2, 59.6, 5, "helm" },
    { "spy", 12994, "Spy Hunter", "Frostworg Denmother", "npcID", 30294, 63.5, 59.7, 6 },
    { "spear", 13003, "How to Slay Your Dragon", "Hodir's Spear", "objectID", 192079, 65, 60.9, 6, "spear" },
    { "feeding", 13046, "Feeding Arngrim", "Arngrim the Insatiable", "objectID", 192524, 67.5, 60, 7 },
}) do
    local id = "storm.hodir.daily." .. row[1]
    P:RegisterDailyGroup(id, { name = row[4], [row[5]] = row[6], mapID = 120, x = row[7], y = row[8],
        requires = { allOf = { C("storm.hodir"), R(1119, row[9]) } },
        prepare = row[10] and C("storm.hodir." .. row[10]),
        quests = { { questID = row[2], name = row[3] } }, hodirReputation = true, evidence = evidence,
        note = "Earn Sons of Hodir reputation for the selected mammoths. Interact with this quest giver or object to check today's daily; follow the quest log for objectives." })
    P.hodirDailyGroups[#P.hodirDailyGroups + 1] = id
end
