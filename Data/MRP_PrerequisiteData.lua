-- Curated Retail supplements for the separately generated source database.
-- local _, MRP = ...
-- IDs/locations: WoW-Pro's Retail Storm Peaks guide; unlocks: Warcraft Wiki's
-- Sons of Hodir chain; item/faction requirements: Wowhead. See docs/prerequisites.md.
-- Keep these separate from generated Data/Mounts and Data/Steps files.
local function location(x, y)
    if x then return { mapID = 120, x = x, y = y } end
end

-- questID, name, accept x/y, objective x/y, turn-in x/y
local rows = {
    {12843, "They Took Our Men!", 41.1, 86.1, 40.7, 72.6, 41.1, 86.1},
    {12846, "Leave No Goblin Behind", 41.1, 86.1, 42.8, 68.9, 42.8, 68.9},
    {12841, "The Crone's Bargain", 42.8, 68.9, 44.0, 69.8, 42.8, 68.9},
    {12905, "Mildred the Cruel", 42.8, 68.9, 44.4, 68.9, 44.4, 68.9},
    {12906, "Discipline", 44.4, 68.9, nil, nil, 44.4, 68.9},
    {12907, "Examples to be Made", 44.4, 68.9, 45.4, 69.1, 44.4, 68.9},
    {12908, "A Certain Prisoner", 44.4, 68.9, 42.8, 68.9, 42.8, 68.9},
    {12921, "A Change of Scenery", 42.8, 68.9, 47.4, 69.0, 47.4, 69.0},
    {12969, "Is That Your Goblin?", 47.4, 69.0, 48.2, 69.7, 47.4, 69.0},
    {12970, "The Hyldsmeet", 47.4, 69.0, 47.4, 69.0, 47.4, 69.0},
    {12971, "Taking on All Challengers", 47.4, 69.0, 49.19, 68.47, 47.4, 69.0},
    {12972, "You'll Need a Bear", 47.4, 69.0, 53.2, 65.7, 53.2, 65.7},
    {12851, "Bearly Hanging On", 53.2, 65.7, nil, nil, 53.2, 65.7},
    {12856, "Cold Hearted", 53.2, 65.7, 63, 63, 53.2, 65.7},
    {13063, "Deemed Worthy", 53.2, 65.7, 49.7, 71.7, 49.7, 71.7},
    {12900, "Making a Harness", 49.7, 71.7, 47, 75, 49.7, 71.7},
    {12983, "The Last of Her Kind", 49.7, 71.7, 54.75, 60.25, 49.7, 71.7},
    {12996, "The Warm-Up", 49.7, 71.7, 50.6, 67.6, 49.7, 71.7},
    {12997, "Into the Pit", 49.7, 71.7, 50, 65, 49.7, 71.7},
    {13061, "Prepare for Glory", 49.7, 71.7, 47.4, 69.0, 47.4, 69.0},
    {13062, "Lok'lira's Parting Gift", 47.4, 69.0, 50.8, 65.5, 50.8, 65.5},
    {12886, "The Drakkensryd", 50.8, 65.5, nil, nil, 33.4, 58.0},
    {13064, "Sibling Rivalry", 33.4, 58.0, 33.4, 58.0, 33.4, 58.0},
    {12915, "Mending Fences", 33.4, 58.0, 69, 59, 33.42, 57.93},
    {12922, "The Refiner's Fire", 69, 59, 77, 64, 77.1, 62.8},
    {12956, "A Spark of Hope", 77.1, 62.8, 33.42, 57.93, 33.42, 57.93},
}
local notes = {
    [12906] = "Use the Disciplining Rod on Exhausted Vrykul inside the mine.",
    [12851] = "Ride the bear beside Brijana and complete the vehicle objectives shown in your quest log.",
    [12886] = "Use the Hyldnir Harpoon between drakes, then reach Thorim at the Temple of Storms.",
    [12915] = "Defeat the Stormforged Iron Giants and Fjorn (77, 64). Keep Slag Covered Metal (item 41556); it starts The Refiner's Fire.",
    [12922] = "Loot Slag Covered Metal (item 41556) from Stormforged Iron Giants and use it to accept this quest. Collect Furious Sparks, then use Fjorn's Anvil.",
}
local chain = {}
for _, row in ipairs(rows) do
    chain[#chain + 1] = {
        questID = row[1], name = row[2], scope = "character",
        mapID = 120, x = row[3], y = row[4],
        objective = location(row[5], row[6]), turnIn = location(row[7], row[8]),
        note = notes[row[1]],
    }
end

local P = MRP.Prerequisites
local Q, C = P.RequireQuest, P.RequireChain
local evidence = "https://github.com/DFortun81/AllTheThings/blob/master/.contrib/.db/standard/02%20-%20Outdoor%20Zones/04%20Northrend/The%20Storm%20Peaks.lua"
local hyldnir, hodir = {}, {}
for index, quest in ipairs(chain) do
    if index > 1 then quest.requires = Q(chain[index - 1].questID) end
    if index <= 22 then hyldnir[#hyldnir + 1] = quest else hodir[#hodir + 1] = quest end
end
hodir[1].requires = C("storm.hyldnir")
-- The item-started Refiner's Fire can be done alongside Mending Fences.
hodir[3].requires = Q(13064)
P:RegisterChain("storm.hyldnir", { evidence = evidence, requirements = Q(12886), quests = hyldnir })
P:RegisterChain("storm.hodir", { evidence = evidence,
    requirements = { allOf = { Q(12915), Q(12956) } }, quests = hodir })
local crone = Q(12841); crone.checkOnly = true
P:RegisterChain("storm.gretta", { evidence = evidence,
    requirements = { allOf = { C("storm.hyldnir"), Q(12925) } },
    quests = { { questID = 12925, scope = "character", name = "Aberrations", requires = crone,
        mapID = 120, x = 48.4, y = 72.1, objective = location(23.1, 58.3), turnIn = location(48.4, 72.1),
        note = "Collect Frost Oil from Valkyrion Aspirants and use it on the eggs in the Blighted Pool. This unlocks the Aberrations daily in Gretta's rotation." } },
})
local lillehoff = {
    requirements = C("storm.hodir"),
    unlockSteps = chain,
}
local rewards = {
    [43958] = { faction = "Alliance", requirements = { type = "reputation", factionID = 1119, standing = 7 } },
    [44080] = { faction = "Horde", requirements = { type = "reputation", factionID = 1119, standing = 7 } },
    [43961] = { faction = "Alliance", requirements = { type = "reputation", factionID = 1119, standing = 8 } },
    [44086] = { faction = "Horde", requirements = { type = "reputation", factionID = 1119, standing = 8 } },
}

P:RegisterBinding({ sourceType = "Vendor", npcID = 32540, source = lillehoff, rewards = rewards })
P:RegisterBinding({ sourceType = "OpenWorld", itemID = 43962, source = { requirements = C("storm.gretta") } })
