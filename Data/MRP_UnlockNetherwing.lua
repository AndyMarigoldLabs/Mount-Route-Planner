-- local _, MRP = ...
local P = MRP.Prerequisites
local Q, C, R = P.RequireQuest, P.RequireChain, P.RequireReputation
local evidence = "https://github.com/DFortun81/AllTheThings/blob/master/.contrib/.db/standard/06%20-%20Expansion%20Features/02%20-%20Burning%20Crusade/Netherwing.lua"
local function loc(x, y, map) return { mapID = map or 104, x = x, y = y } end
local function quest(id, name, x, y, requires, tx, ty, map)
    return { questID = id, scope = "character", name = name, mapID = map or 104, x = x, y = y,
        requires = requires, turnIn = loc(tx or x, ty or y, map) }
end
local ally = { anyOf = { Q(10870), Q(10871) } }
local zuluhed = { anyOf = { Q(10866), Q(10872) } }
P:RegisterChain("netherwing.neutral", { evidence = "https://warcraft.wiki.gg/wiki/Ally_of_the_Netherwing_quest_chain",
    requirements = ally, quests = {
        quest(10804, "Kindness", 59.3, 58.7),
        quest(10811, "Seek Out Neltharaku", 59.3, 58.7, Q(10804), 61.9, 60),
        quest(10814, "Neltharaku's Tale", 61.9, 60, Q(10811)),
        quest(10836, "Infiltrating Dragonmaw Fortress", 61.9, 60, Q(10814)),
        quest(10837, "To Netherwing Ledge!", 61.9, 60, Q(10836)),
        quest(10854, "The Force of Neltharaku", 61.9, 60, Q(10837)),
        quest(10858, "Karynaku", 61.9, 60, Q(10854), 69.8, 61.4),
        quest(10866, "Zuluhed the Whacked", 69.8, 61.4, Q(10858)),
        quest(10872, "Zuluhed the Whacked", 69.8, 61.4, Q(10858)),
        quest(10870, "Ally of the Netherwing", 69.8, 61.4, zuluhed, 59.3, 58.7),
        quest(10871, "Ally of the Netherwing", 69.8, 61.4, zuluhed, 59.3, 58.7),
    },
})
P:RegisterChain("netherwing.service", { evidence = evidence, requirements = Q(11014), quests = {
    quest(11012, "Blood Oath of the Netherwing", 59.3, 58.7, C("netherwing.neutral")),
    quest(11013, "In Service of the Illidari", 59.3, 58.7, Q(11012), 66.2, 85.6),
    quest(11014, "Enter the Taskmaster", 66.2, 85.6, Q(11013), 66, 86.4),
} })
local function promotion(id, name, predecessor, rank)
    local q = quest(id, name, 66, 86.4, { allOf = { predecessor, R(1015, rank) } }, 66.2, 85.6)
    q.note = "Netherwing reputation is a separate requirement. Continue the Netherwing dailies or egg turn-ins when the next promotion is locked."
    return q
end
P:RegisterChain("netherwing.finale", { evidence = evidence, requirements = Q(11108), quests = {
    promotion(11053, "Rise, Overseer!", C("netherwing.service"), 5),
    promotion(11084, "Stand Tall, Captain!", Q(11053), 6),
    promotion(11092, "Hail, Commander!", Q(11084), 7),
    promotion(11107, "Bow to the Highlord", Q(11092), 8),
    quest(11108, "Lord Illidan Stormrage", 66.2, 85.6, Q(11107), 66.6, 16.8, nil),
} })
-- The finale ends at Barthamus in Shattrath, not at the Dragonmaw camp.
P.chains["netherwing.finale"].nodes["character:11108"].turnIn.mapID = 111

P.netherwingDrakes = {
    { item = 32857, quest = 11111, npc = 23463, name = "Onyxien", x = 67.6, y = 18.4 },
    { item = 32858, quest = 11112, npc = 23461, name = "Suraku", x = 66.8, y = 18.4 },
    { item = 32859, quest = 11109, npc = 23462, name = "Jorus", x = 67.8, y = 17.2 },
    { item = 32860, quest = 11110, npc = 23464, name = "Malfas", x = 67.8, y = 18.0 },
    { item = 32861, quest = 11114, npc = 23465, name = "Zoya", x = 66.6, y = 18.6 },
    { item = 32862, quest = 11113, npc = 23466, name = "Voranaku", x = 66.6, y = 17.8 },
}
local claimed = { anyOf = {} }
for _, drake in ipairs(P.netherwingDrakes) do
    local completed = Q(drake.quest); completed.checkOnly = true
    claimed.anyOf[#claimed.anyOf + 1] = completed
    local choice = quest(drake.quest, drake.name .. " - choose your Netherwing drake", drake.x, drake.y,
        { allOf = { C("netherwing.finale"), R(1015, 8) } }, nil, nil, 111)
    choice.note = "Choose one free Netherwing drake. The other colors can then be purchased from Drake Dealer Hurlunk."
    P:RegisterChain("netherwing.choice." .. drake.item, { evidence = evidence, requirements = Q(drake.quest), quests = { choice } })
end
P:RegisterChain("netherwing.claimed", { evidence = evidence, requirements = claimed, quests = {} })
local function provider(step)
    if step.source.type == "Quest" and P:Evaluate(C("netherwing.claimed")) == false then
        return { requirements = { allOf = { C("netherwing.finale"), R(1015, 8) } }, unlockRequirement = C("netherwing.finale") }
    end
    return { requirements = { allOf = { C("netherwing.claimed"), R(1015, 8) } },
        unlockRequirement = C("netherwing.choice." .. (P.netherwingChoice or 32857)) }
end
for _, drake in ipairs(P.netherwingDrakes) do
    P:RegisterBinding({ sourceType = "Quest", itemID = drake.item, get = provider })
end
P:RegisterBinding({ sourceType = "Vendor", npcID = 23489, get = provider })
