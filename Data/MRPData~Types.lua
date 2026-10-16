-- MRPData~Types.lua
-- local _, MRPData = ...

if not MRPData.Internal then return end

---@class BaseEntry
---@field x number the x coordinate of the entry
---@field y number the y coordinate of the entry
---@field mapName string the name of the map where the entry is located
---@field mapID number the uiMapID of the entry
---@field expansionLevel number the expansionLevel of the entry
---@field conditions string[]? an optional array of condition keys (faction, warfront, reputation, holiday, …)
---@field requirements AcquisitionRequirement? acquisition gates, independent of questID lockout tracking
---@field unlockSteps UnlockQuest[]? ordered quests that satisfy this entry's requirements

---@class AcquisitionRequirement
---@field type "quest"|"reputation"|"chain"|"item"? leaf requirement type
---@field id number|string? quest/item ID or stable chain key
---@field count number? carried item quantity (item requirements)
---@field checkOnly boolean? terminal quest flag with no authored action in this graph
---@field name string? fallback quest name
---@field scope "character"|"account"? quest completion scope (defaults to character)
---@field factionID number? reputation faction ID
---@field standing number? standard reputation rank (1-8)
---@field allOf AcquisitionRequirement[]? all child requirements must pass
---@field anyOf AcquisitionRequirement[]? at least one child requirement must pass

---@class QuestLocation
---@field mapID number UI map ID
---@field x number map percentage (0-100)
---@field y number map percentage (0-100)

---@class UnlockQuest : QuestLocation
---@field questID number? omitted for a daily quest-giver check
---@field name string? fallback quest name
---@field scope "character"|"account"? defaults to character
---@field faction "Alliance"|"Horde"? omit for both
---@field requires AcquisitionRequirement? dependency gate for this quest
---@field progress AcquisitionRequirement? gathering gate for an accepted quest
---@field waitMessage string? explains how to progress when gathering is incomplete
---@field accept QuestLocation? overrides the top-level quest-giver coordinates
---@field objective QuestLocation? fallback when Blizzard has no active waypoint
---@field turnIn QuestLocation? fallback for a finished quest awaiting turn-in
---@field note string? quest-specific instructions
---@field daily boolean? completion resets with the server daily boundary
---@field dailyGroupID string? authored daily group for this quest
---@field dailyGroup string? runtime visit to check the NPC's actual daily offers
---@field dailyResetAt number? server reset boundary attached to a runtime daily step

---@class DailyQuestGroup : QuestLocation
---@field id string stable group key
---@field name string quest giver or daily group label
---@field npcID number stable quest-giver identity
---@field evidence string reviewed source URL
---@field quests UnlockQuest[] verified candidates, not assumed simultaneous offers
---@field faction "Alliance"|"Horde"? omit for both
---@field requires AcquisitionRequirement? eligibility gate (does not initiate this path)
---@field prepare AcquisitionRequirement? one-time setup path after the eligibility gate
---@field rotation boolean? at most one alternative may be available/completed per reset
---@field note string? daily progress instructions
---@field invalid boolean? registry validation failed

---@class UnlockChain
---@field requirements AcquisitionRequirement terminal condition; satisfied terminals bypass history
---@field quests UnlockQuest[] graph nodes (dependencies explicitly declared)
---@field evidence string source URL for reviewed identifiers and dependencies
---@field nodes table<string, UnlockQuest> derived scope/quest-ID index
---@field invalid boolean? set by registry validation; invalid chains fail closed

---@class Dungeon : BaseEntry
---@field instanceId number the instanceID (mapID)
---@field availableDifficultyIds number[] the available difficultyIDs for the dungeon

---@class Raid : BaseEntry
---@field instanceId number the instanceID (mapID)
---@field availableDifficultyIds number[] the available difficultyIDs for the raid
---@field areaId number? the areaID of the raid

---@class WorldBoss : BaseEntry
---@field questID number the questID for the world boss completion tracking
---@field npcID number? the NPC ID for nearby detection and targeting
---@field targetName string? the exact targetable NPC name when it differs from the encounter/source name

---@class OpenWorld : BaseEntry
---@field questID number the questID for lockout tracking (0 = always farmable)
---@field mechanic string the mechanic type ("kill", "click", "interact")
---@field sourceType string? the source type ("Treasure", "Quest", "Vendor", etc.)
---@field npcID number? the NPC ID for targeting (nil or 0 for non-NPC sources)
---@field note string? an optional note about the source
---@field waypoints OpenWorldWaypoint[]? additional map locations to highlight
---@field routeType string? visualization type ("patrol" = connected route, "spawns" = individual markers)
---@field routes OpenWorldRoute[]? multiple patrol routes, each drawn in a distinct color

---@class OpenWorldRoute
---@field waypoints OpenWorldWaypoint[] ordered waypoints forming this patrol route

---@class OpenWorldWaypoint
---@field x number the x coordinate (0-100 map percent)
---@field y number the y coordinate (0-100 map percent)
---@field mapID number? optional mapID if different from the main entry's mapID

---@class JournalEncounter
---@field id number the encounterID
---@field name string the encounter name
---@field instanceId number the instanceID of the encounter
---@field uiMapId number the uiMapID of the encounter

---@class DungeonEncounter
---@field id number the encounterID
---@field name string the encounter name
---@field mapId number the mapID of the encounter

---@class SpecialEncounter
---@field name string the name of the special encounter

---@class MountCost
---@field type string the cost type ("currency", "gold", "item")
---@field amount number the amount of the cost
---@field currencyId number? the currencyID if the cost type is "currency"
---@field itemId number? the itemID if the cost type is "item"

---@class QuestSource
---@field questID number the questID of the source
---@field name string the name of the quest source
---@field x number? the x coordinate of the quest source
---@field y number? the y coordinate of the quest source
---@field mapID number? the uiMapID of the quest source

---@class MountSource
---@field requirements AcquisitionRequirement? requirements specific to this mount
---@field unlockSteps UnlockQuest[]? ordered unlock quests for this mount
---@field mapId number the mapID of the source
---@field uiMapIds number[] the uiMapIDs of the source
---@field allowedDifficultyIds number[] the allowed difficulty IDs for the source
---@field relevantDifficultyIds number[]? the relevant difficulty IDs for the source
---@field note string? an optional note for the source
---@field bonusRoll boolean? whether the source can be bonus rolled
---@field factionMask number? the faction mask for the source
---@field mechanic string? the open world mechanic type ("kill", "click", "interact")
---@field journalEncounter JournalEncounter? the journal encounter details
---@field dungeonEncounter DungeonEncounter? the dungeon encounter details
---@field specialEncounter SpecialEncounter? the special encounter details
---@field cost MountCost? the cost details of the mount
---@field costs MountCost[]? the cost details array of the mount
---@field questChain QuestSource[]? the quest chain details if the mount is obtained through a questline

---@class Mount
---@field id number the mountID
---@field name string the name of the mount
---@field icon number the icon texture ID of the mount
---@field itemId number the itemID of the mount
---@field spellId number the spellID of the mount
---@field source MountSource the source details of the mount

---@class StepSource
---@field prerequisiteQuest UnlockQuest? present only on runtime prerequisite steps
---@field runtimeEntry BaseEntry? location/lockout metadata for a runtime source replacement
---@field type FilterSourceType the type of the source
---@field name string the name of the source
---@field npcID number? the npcID used for nearby detection when available
---@field targetName string? the exact targetable NPC name when it differs from the source/encounter name

---@class Step
---@field id number|string the stepID (runtime prerequisite IDs are strings)
---@field requirements AcquisitionRequirement? additional source requirements
---@field unlockSteps UnlockQuest[]? ordered unlock quests
---@field prerequisiteQuest UnlockQuest? current prerequisite, if this is a runtime quest stop
---@field acquisitionQuest UnlockQuest? active repeatable reward quest, not permanent unlock progress
---@field runtimeLocation boolean? re-order using current location instead of the saved source position
---@field unlockRequirement AcquisitionRequirement? actionable path independent of purchase gates
---@field targetStepIDs table<number, boolean>? source steps unlocked by this quest
---@field entry BaseEntry? runtime location; not written into generated source tables
---@field mounts Mount[] the list of mounts in this step
---@field source StepSource the source details of the step
---@field expansion number the expansion of the step

---@class MRPDataAPI
---@field VERSION number the version of the API
---@field DUNGEONS { [string]: Dungeon } a table mapping dungeon names to their data
---@field RAIDS { [string]: Raid } a table mapping raid names to their data
---@field WORLD_BOSSES { [string]: WorldBoss } a table mapping world boss names to their data
---@field OPEN_WORLD { [string]: OpenWorld } a table mapping open world event names to their data
---@field STEPS Step[] a table mapping step names to their data
