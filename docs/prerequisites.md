# Quest prerequisite routing

Enable **Include prerequisite quest chains** in `/mrp settings`, or run
`/mrp prerequisites on`. This is saved per character and defaults to off, including
when upgrading an existing character. `/mrp prerequisites off` removes unlock
quests immediately. `/mrp prerequisites status` lists known blocked mounts and
their remaining requirements. The Settings button **Show blocked mount
requirements** opens the same report.

**Include reputation and unlock seal dailies** in Settings, or `/mrp dailies on`,
also routes the daily progress described below. This separate per-character
option defaults to off and enables prerequisite chains when switched on.
`/mrp dailies off` removes daily progress while leaving the permanent chain
option enabled; `/mrp prerequisites off` suspends both. `/mrp dailies status`
reports whether daily routing is active and lists remaining mount requirements.

**Farm Champion's Seals for selected mounts**, or `/mrp championseals on`, is a
third per-character option, off by default. It routes purchase-currency dailies
independently of the two unlock options. `/mrp championseals off` removes those
farming stops; `/mrp championseals status` reports the shared budget and blocked
mounts. Turning prerequisite routing off does not disable this separate option.

**Farm Sons of Hodir reputation for selected mammoths**, or `/mrp hodir on`, is
another independent per-character option, off by default. `/mrp hodir off` removes
its farming and daily setup stops; `/mrp hodir status` shows the reputation target
and blocked mounts. It does not switch on any of the other three options.

Mount source filters select which mounts to pursue. Unlock quests inherit that
selection: enabling Vendors and disabling Quest rewards still allows the quests
needed for a selected vendor. Already collected and opposite-faction mounts do
not create unlock errands.

The route contains the ready unfinished quests for each selected locked source.
Shared quests appear once, with the mounts they unlock shown as rewards. Later
quests and locked vendors cannot be brought forward by geographical sorting or
manual Next. Turning in a quest replaces it with the next unfinished quest;
finishing the unlock adds eligible mount purchases back into the route. When
auto-advance is off, the completed quest stays selected until Next.

Navigation switches between the quest giver, active objective and turn-in.
Blizzard's active quest waypoint takes precedence over curated fallback
coordinates. Where neither exists, the panel explicitly directs the player to
the quest log without falling back to the locked vendor. Quest updates are
debounced and deferred during combat.

## Retail coverage: Storm Peaks

Lillehoff's supplement is keyed by NPC **32540**, not a localized name or generated step
number. It covers the 26-quest path from **They Took Our Men! (12843)** at K3 to
**Mending Fences (12915)** and **A Spark of Hope (12956)**. These two terminal flags
gate vendor access on the current character; completing them on an alt is not
treated as proof that the current character's phasing is unlocked.

The Refiner's Fire (12922) starts from **Slag Covered Metal (41556)**. Its acceptance
stop is the giants' drop area, with an instruction to loot and use the item.
Vehicle quests use native objective waypoints where available. Acceptance and
turn-in fallbacks are included for every quest. The chain's endpoint does not
promise a particular reputation rank: event bonuses and previous reputation
gains can change that.

| Mount item | Faction | Purchase requirement |
| --- | --- | --- |
| 43958, Ice Mammoth | Alliance | Sons of Hodir (1119), Revered (7) |
| 44080, Ice Mammoth | Horde | Sons of Hodir (1119), Revered (7) |
| 43961, Grand Ice Mammoth | Alliance | Sons of Hodir (1119), Exalted (8) |
| 44086, Grand Ice Mammoth | Horde | Sons of Hodir (1119), Exalted (8) |

Reputation does not prevent starting the unlock quests. After the unlock, a
character at Revered sees only the Ice Mammoth purchase. At Exalted the Grand Ice
Mammoth also becomes eligible. The separate Hodir farming option described below
routes reputation progress. Gold budgeting is not included.

## Sons of Hodir reputation farming

The shared target is **Revered (7)** when the selected uncollected, unpurchased
Lillehoff rewards only need Ice Mammoth, and **Exalted (8)** when any selected
reward needs Grand Ice Mammoth. Existing source, expansion, faction and collection
filters determine the selection. Duplicate mount listings share one goal. An
owned mount item in this character's bags or bank removes its goal before it is
learned. Changing filters, collecting mounts or buying items recalculates the
target. Opposite-faction rewards and sources with unknown gates do not create
farming errands.

The target and rank gates read the character's **`reaction`** from
`C_Reputation.GetFactionDataByID(1119)`. Retail's `currentStanding` field contains
reputation points, not a rank; the shared prerequisite and source-condition
checks now use `reaction` too. Missing or invalid rank data pauses farming. Quest
turn-ins do not predict reputation gains: `UPDATE_FACTION` and refreshes re-read
the real rank, including gains from other activities or bonuses.

At Revered, Ice Mammoth purchases become available while farming can continue
for selected Grand Ice Mammoths. At the highest required rank, all Hodir farming
stops disappear, including completed stops retained with auto-advance off. Gold
and the character's original vendor-phasing unlock remain necessary.

| Daily | Giver | Preparation and rank for a planned visit |
| --- | --- | --- |
| Hot and Cold (12981) | Fjorn's Anvil, object 192071 | Neutral; Battling the Elements (12967) |
| Hodir's Call (12977) | Hodir's Horn, object 192078 | Neutral; In Memoriam (12975), A Monument to the Fallen (12976) |
| A Viscous Cleaning (13006) | Hodir's Helm, object 192080 | Friendly; Forging a Head (12985), Placing Hodir's Helm (12987) |
| Spy Hunter (12994) | Frostworg Denmother, NPC 30294 | Honored |
| How to Slay Your Dragon (13003) | Hodir's Spear, object 192079 | Honored; Raising Hodir's Spear (13001) |
| Feeding Arngrim (13046) | Arngrim's frozen image, object 192524 | Revered |

The initial Storm Peaks faction unlock still uses `/mrp prerequisites on`.
Once that is complete, the Hodir option can route the daily setup quests itself.
The anvil path accepts **Forging an Alliance (12924)**, follows **You Can't Miss
Him (12966)** and **Battling the Elements (12967)**, then returns to Njormeld to
turn in the parent. This is an accept-before-child dependency, not a requirement
to finish the parent first. Horn and helm preparation share the anvil path; spear
preparation becomes available at Honored. Setup branches and dailies are shared
across the selected mammoths and disappear when no longer needed.

An object or NPC visit checks the current offer. Object `QUEST_DETAIL` events
confirm a daily even when no NPC unit GUID is exposed. Where a gossip list exists,
its object/NPC identity is matched and an empty list removes the visit for that
reset. Accepted quests follow native objective waypoints and return to the
correct object or NPC; missing objective coordinates defer to the quest log.
Actual offered or accepted dailies take precedence over missing historical
flags. Observed access to a daily's own setup path is saved per character to avoid
replaying that preparation after a reset or reload; it does not complete quests
or unlock other daily branches.

All six dailies use the shared server-reset handling described below. Their
completion expires across online/offline resets while permanent setup remains.
Carried quests keep their objective/turn-in state. With an unavailable reset
countdown, accepted quests remain routable but new daily visits wait. Relic of
Ulduar and Everfrost turn-ins are repeatable activities, not daily quests, and
are not generated or assigned daily lockouts by this option.

## Retail coverage: Gretta

The **White Polar Bear (43962)** shares the Hyldnir trunk through **The
Drakkensryd (12886)**, with **Aberrations (12925)** as a separate branch for
Gretta's daily rotation. It does not require the Sons of Hodir reputation or
Lillehoff's final quests. Aberrations and the remaining Hyldnir quests can be
ready together. The two Hodir end branches, Mending Fences and the item-started
Refiner's Fire, can also progress independently after Sibling Rivalry.

Gretta's path prepares the full rotation, rather than claiming that every daily
has the same minimum unlock. A daily actually offered by Gretta's gossip,
quest greeting or direct quest detail, or already accepted, is evidence of access and takes precedence over that
preparation path. The addon does not guess today's rotating quest from a calendar.
After completing one of 13422–13425, this source waits for the realm's daily reset.
It uses the same reset-scoped turn-in observations and offer snapshots as the
farming loops. A selected, uncollected polar bear keeps the reset watcher running
even with all farming opt-ins off. Permanent unlock progress stays separate.
Accepted dailies follow native waypoints, then Gretta for turn-in, including when
the completion API still reports an older completion.

## Retail coverage: Netherwing

All six drake items **32857–32862** share the Kindness introduction, the Neutral
handoff, the Dragonmaw service quests, and the Friendly/Honored/Revered/Exalted
promotions. The accepted or completed alternate versions of Zuluhed and Ally of
the Netherwing are recognized. Reputation shortfalls produce a waiting reason
unless daily routing is enabled; promotion quests remain gated by the actual rank.
Reputation dailies and egg gathering are not generated automatically.

The finale leads to **one** free drake quest in **Shattrath (map 111)**. An already
accepted choice wins; otherwise the first selected uncollected item by item ID is
the suggested choice. The player still accepts and turns in the quest manually.
The ready reward quest remains available when prerequisite opt-in is off.

Once any free choice is completed on this character, remaining selected colors
converge on one **Drake Dealer Hurlunk (23489)** stop in **Shadowmoon Valley
(map 104)**. The runtime overlay corrects the generated Shattrath reward rows'
old camp coordinates and does not modify the generated records. Hurlunk requires
Exalted; the old generated Revered condition cannot override that requirement.

## Retail coverage: Argent Tournament

Faction introductions and all three parallel mastery quests lead to the
Aspirant seal quest and challenge. The first city is chosen from a confirmed
home-city mapping or this character's actual enrollment. After the first
Champion Rises handoff, subsequent city branches reuse the same resolver.
An active city is finished before another starts. Otherwise selected goals are
considered in the curated city order; selecting Crusader rewards adds all five
cities of the current faction, while selecting one city vendor does not.

| Source | Unlock | Additional mount gate |
| --- | --- | --- |
| Stormwind, Ironforge, Gnomeregan, Darnassus, Exodar quartermasters | That city's Valiant's Challenge / Champion milestone | Alliance |
| Orgrimmar, Sen'jin, Thunder Bluff, Undercity, Silvermoon quartermasters | That city's Valiant's Challenge / Champion milestone | Horde |
| Argent Hippogryph, item 45725 | Any city Champion | Uses an actually unlocked city vendor's coordinates |
| Hiren Loresong, NPC 34881 | Any Alliance city Champion | Silver Covenant (1094), Exalted |
| Vasarin Redmorn, NPC 34772 | Any Horde city Champion | Sunreavers (1124), Exalted |
| Dame Evniki Kapsalis, NPC 34885 | All five faction city Champions; all five cities and Argent Crusade (1106) Exalted | Argent Charger (47179): Paladin; Argent Warhorse (47180): all classes |

Character quest flags and character reputation establish these milestones;
account-wide achievement completion is not used as proof of vendor access.
Champion's Seal prices are purchase requirements. The separate farming option
below can route available dailies to fund those purchases.

An accepted **Up To The Challenge** waits for **15 Aspirant's Seals (45192)**;
an accepted **Valiant's Charge** waits for **25 Valiant's Seals (44987)**. The
diagnostic explains that Tournament dailies and resets may be needed. Carried
item counts or quest objective completion restore the turn-in action, and bag
updates refresh the route. With daily routing enabled, those gathering waits
expand into the active charge's daily quest givers, offered quests, objectives
and turn-ins. Once the required seals are carried, or the charge's objectives
are complete, gathering stops and the charge resumes.

## Opt-in daily loops and reset behavior

Netherwing supports seven profession-independent dailies, enough to progress
from Neutral to Exalted without an optional profession or Aldor/Scryer branch:

| Gate | Daily quests | One-time setup routed when needed |
| --- | --- | --- |
| Dragonmaw service | Netherwing Crystals (11015) | Enter the Taskmaster in the main chain |
| Dragonmaw service | A Slow Death (11020), The Not-So-Friendly Skies (11035) | Your Friend on the Inside (11019) |
| Friendly and Rise, Overseer! | Picking Up the Pieces (11076), Dragons Are the Least of Our Problems (11077) | The Netherwing Mines (11075), shared once |
| Friendly and Rise, Overseer! | The Booterang (11055) | Overseeing and You (11054) |
| Honored and Stand Tall, Captain! | Disrupting the Twilight Portal (11086) | None beyond the promotion |

These quests continue at higher ranks until the next promotion is available;
at Exalted, the route switches to the finale and free drake choice. Egg turn-ins,
profession dailies, races and Aldor/Scryer defense quests are optional accelerators
and are not generated by this loop. Egg turn-ins are repeatable, not daily, and
are deliberately not assigned a daily lockout.

Tournament coverage includes both factions' Aspirant dailies and all ten cities'
Valiant dailies: the rotating weapon quest, field training, mounted training or
Grand Melee, and At the Enemy's Gates for Valiants. Only the currently accepted
charge generates seal dailies; accepting it first also proves that this character
has reached that stage. Shared mount goals reuse the same daily stops. Completing
a city's charge/challenge advances through the existing city selection logic.
Champion's Seals (currency 241) use the separate farming option below. City,
Argent Crusade, Silver Covenant and Sunreaver reputation grinds are not generated
automatically. Vendor access and purchase affordability remain distinct.

## Champion's Seal purchase farming

The budget includes uncollected Tournament mounts selected by the existing
source, expansion, faction and collection filters. It covers the city vendors,
Argent Hippogryph, Hiren/Vasarin and Dame Evniki, respecting faction and Paladin
restrictions. Unknown source requirements do not create farming errands.

Each mount journal ID counts once. Duplicate vendor listings share the cheapest
verified selected seal price and its destination; a more expensive or unpriced
alternative is withheld. Already purchased items in this character's bags or
bank remove that mount from the budget even before it is learned. Mixed prices
include only currency 241: gold and other costs still have to be paid separately.
For example, a 100-seal mount and a mount costing 5 seals plus gold create a
105-seal target. With 35 seals, the route farms the remaining 70.

Only `C_CurrencyInfo.GetCurrencyInfo(241).quantity` counts as spendable balance.
Lifetime earnings, another character's currency, predicted quest rewards and
unopened Champion's Purses do not count. Missing currency data or a goal without
any verified seal price pauses farming and explains why. Prices come from the
selected published mount records; generated data is never mutated.

All selected mounts share the same daily stops. Farming stops when the current
balance covers their combined budget, then eligible vendors return to the route.
Currency, bag, merchant and collection events recalculate the remainder. Buying
one mount lowers both the balance and the target; spending seals elsewhere can
restart farming. Reaching the target removes farming stops even with auto-advance
disabled. Unmet city or reputation unlocks continue to block their vendors.

| Daily group | Access used to plan a quest-giver visit |
| --- | --- |
| Among the Champions, Taking Battle to the Enemy, Battle Before the Citadel | This character's first Champion Rises or Champion introduction |
| Threat from Above | Core Champion access plus The Black Knight's Fall (13664) |
| Narasi/Girana's rescue rotation and separate Kul daily; Savinia/Tylos's food rotation | First Champion Rises plus Silver Covenant/Sunreavers Exalted |
| High Crusader Adelard and Crusader Silverdawn rotations | This character's five city Champions and city/Argent Crusade Exalted requirements |

The four Alliance/Horde and Death Knight/other-class core quest variants use
their own IDs and givers. The first Champion Rises handoff and the Eadric/Crok
introductions are routed when needed. Actual core daily access is remembered on
this character so a skipped introduction is not repeatedly offered. A character
who has not become a Champion is directed to enable the prerequisite options.
Account-wide titles and achievements do not establish daily access.

Eligible NPC visits resolve into their actual offered quests. Accepted quests
and live offers can prove access even when historical flags are absent. Rotations
are never guessed; Kul's daily is independent of the rescue rotation. The Black
Knight chain, extra reputation grinds, dungeon farming and item-started optional
quests are not added. Currency earned through any of those activities still
counts toward the budget.

## Availability and daily resets

An unvisited NPC appears as **Daily quest giver**, not as a promise that every
candidate is available. The gossip or quest greeting list resolves the visit into
the quests actually offered. A directly opened quest detail also confirms that
single offer. No calendar-based rotation is assumed. An empty list from an identified giver removes the visit
for this reset; interacting with the NPC again, completing a permanent unlock,
or changing reputation rechecks availability. Accepted quests use native
objective waypoints and curated turn-in coordinates. Where objective waypoints
are unavailable, the panel points to the quest log instead of inventing a location.

Quest greetings use `GetNumAvailableQuests()` / `GetAvailableQuestInfo(index)`
and the `questnpc` unit, separately from `C_GossipInfo` and the `npc` unit. When
an object exposes no unit GUID, listed quest IDs prove only those offers; an
empty anonymous list cannot remove a different giver's visit. Observing a known
offer does not enable any farming option.

The reset boundary comes from `GetServerTime()` plus
`C_DateAndTime.GetSecondsUntilDailyReset()`. A cancellable timer checks at most
once per minute, and sooner at the boundary. Reload/login and world-entry events
also reconcile state. Character-local observed turn-ins expire at that boundary;
offer snapshots are session-only and expire with it. Blizzard's current daily
completion flags are re-read, and a currently accepted or offered quest takes
precedence if those flags lag behind the reset. Game flags are never overwritten.
Permanent quest flags, reputation and carried seals are not reset. Accepted quests survive a
reset and keep their objective/turn-in phase; yesterday's completed UI stop is
not retained even with auto-advance off. Refreshes defer during combat.

When reset time cannot be read, new daily visits wait while accepted quests
remain routable. The timer retries. This avoids inventing a local midnight or a
24-hour period based on when a player last completed a quest. Server schedule
changes invalidate observations; small countdown rounding differences do not.

## Retail API audit (2026-10-16)

The prerequisite resolver, daily loops, farming targets, collection helper,
quest navigation and event dispatch were checked against Blizzard's Retail UI
source and generated API declarations, mirrored at
[`b9be9379719047977fca4dba1bb1d9988e8840b3`](https://github.com/Gethe/wow-ui-source/tree/b9be9379719047977fca4dba1bb1d9988e8840b3).

Confirmed issues fixed:

- The Argent Hippogryph binding passed both `UnitFactionGroup` returns into a
  helper. Lua treated the localized faction name as a class restriction, hiding
  the mount from eligible characters and omitting its 150-seal cost from farming
  targets. The binding now passes only the invariant faction tag.
- Missing mount journal data fell through to spellbook presence and item counts.
  Retail now uses only the journal's collection flag; an unlearned item or an
  unknown override spell cannot mark a mount collected. The purchase planners
  still handle bought-but-unlearned items separately. Missing journal results
  retain the normal uncollected fallback until journal data is available.
- `QUEST_GREETING` was unhandled. Daily offers now use the greeting's fifth
  `GetAvailableQuestInfo` return and `questnpc`, rather than a stale gossip list.
  Positive offers work even when an object has no unit GUID.
- Gretta's acquisition quests bypassed the daily resolver. A lagging completion
  flag could remove navigation for an accepted or offered daily, direct offers
  were missed, and reset refresh depended on unrelated events. Her four dailies
  now share the offer, turn-in and reset handling used by the farming loops.

Verified API contracts:

| API | Verified interpretation |
| --- | --- |
| Unit identity | Faction uses return 1; race/class use invariant return 2. Multi-return faction values must not flow into an optional class argument. |
| `GetMountInfoByID` | Collection is return 11; interior nil fields, usability and active state do not change it. The API may return nothing. |
| `GetFactionDataByID` | `reaction` is rank 1–8; `currentStanding` is points (fixed in the preceding Hodir change). |
| `GetCurrencyInfo` | `quantity` is spendable balance; lifetime earnings and tracking fields are not a purchase budget. Missing data pauses farming. |
| `C_Item.GetItemCount` | Carried quest seals exclude banks and charges. Purchase targets include personal bank items, excluding account-bank items. Ownership does not imply learned collection. |
| `C_QuestLog` completion | Objective completion, character turn-in and account turn-in remain separate. Missing account APIs never fall back to character flags. |
| `GetNextWaypoint` | Returns map ID plus normalized x/y, or nothing; coordinates are converted once, with curated turn-in and quest-log fallbacks. |
| Quest/currency events | Retail `QUEST_ACCEPTED` supplies a single quest ID. Turn-in XP/money and removal's replay flag are ignored. Nullable currency event fields trigger a fresh balance read. |
| Daily reset | Server timestamp plus reset countdown defines the boundary; no local date, midnight or elapsed 24-hour assumption. |

The tests call the real collection helper using all 13 journal returns, separate
gossip/greeting fixtures, localized versus invariant race/class names, full
currency records and item counts that honor the API's location flags. New cases
cover both factions' Hippogryph eligibility and budgets, missing journal data,
empty and anonymous greetings, event arguments,
Gretta's stale flags, direct offers, reset recovery and watcher cancellation.
The regressions reproduce the pre-fix failures, including two existing integration
failures exposed by the two-return faction fixture. The full suite has 140
passing tests when supplied with the published data. These are contract fixtures,
not captures from a running Retail client.

Primary API references: [mount journal](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/MountJournalDocumentation.lua),
[spellbook](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua),
[items](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua),
[gossip](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/GossipInfoDocumentation.lua),
[Retail QuestFrame](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua),
and [unit identity](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua).

## Deliberately excluded / needs in-game verification

Other audited families and unresolved source/phase gates are not in these packs.
Unverified Tournament home-city assignments (including newer races without a
confirmed mapping) do not get a guessed city. They can follow the shared intro;
after that the resolver waits for actual enrollment evidence. Existing completed
city milestones still work. Faction-change migration behavior needs a Retail
playthrough; account-wide achievements are not substituted for missing flags.

Historical sources disagree about the earliest availability of individual
Gretta dailies. Those minimum flags are not asserted as a universal gate: the
curated path prepares the full rotation and live offered/accepted quests can
bypass it. Remote daily availability, NPC phasing, moving quest givers and
vehicle objectives still need in-game verification. Unknown objective locations
use the native quest log, never the locked vendor's position.

Evidence checked on 2026-10-16:

- [Sons of Hodir quest chain](https://warcraft.wiki.gg/wiki/The_Sons_of_Hodir_quest_chain): quest progression and faction unlock.
- [WoW-Pro Retail Storm Peaks reference](https://github.com/Ludovicus-Maior/WoW-Pro-Guides/blob/master/WoWPro_Leveling/Retail/Alliance/WOTLK_Storm_Peaks.lua): quest IDs and acceptance/objective/turn-in coordinates. Only factual identifiers and coordinates were used; guidance text in the supplement is newly written.
- [Ice Mammoth](https://www.wowhead.com/item=44080/reins-of-the-ice-mammoth) and [Grand Ice Mammoth](https://www.wowhead.com/item=43961/reins-of-the-grand-ice-mammoth): purchase ranks and item factions.
- [Upstream v2.4.5 data](https://github.com/Deathwing/Mount-Route-Planner/releases/tag/v2.4.5): NPC and four mount-item mappings, verified by an integration test against the released archive.
- [Blizzard QuestLog API declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua): completion scope, quest status and waypoint signatures.
- [Blizzard DateAndTime API declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/DateAndTimeDocumentation.lua): server daily-reset countdown.
- [Blizzard CurrencyInfo API declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/CurrencyInfoDocumentation.lua): spendable balance and currency update events.
- [Blizzard Reputation API declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ReputationInfoDocumentation.lua) and [Retail reputation panel](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ReputationFrame.lua): `reaction` for rank; `currentStanding` for points.
- [ALL THE THINGS: Storm Peaks](https://github.com/DFortun81/AllTheThings/blob/master/.contrib/.db/standard/02%20-%20Outdoor%20Zones/04%20Northrend/The%20Storm%20Peaks.lua): Gretta's daily IDs and Aberrations branch.
- The same Storm Peaks reference supplies Hodir daily IDs, object/NPC identities, preparation dependencies and reputation gates. The [WoW-Pro Retail quest sequence](https://github.com/Ludovicus-Maior/WoW-Pro-Guides/blob/master/WoWPro_Leveling/Retail/Alliance/WOTLK_Storm_Peaks.lua) confirms the nested Forging an Alliance path and setup turn-in locations.
- [Back to the Pit progression](https://warcraft.wiki.gg/wiki/Back_to_the_Pit) and [Retail Gretta rotation report](https://us.forums.blizzard.com/en/wow/t/gretta-the-arbiter/1396163): separate daily unlocks and rotation.
- [ALL THE THINGS: Netherwing](https://github.com/DFortun81/AllTheThings/blob/master/.contrib/.db/standard/06%20-%20Expansion%20Features/02%20-%20Burning%20Crusade/Netherwing.lua), [Shadowmoon Valley](https://github.com/DFortun81/AllTheThings/blob/master/.contrib/.db/standard/02%20-%20Outdoor%20Zones/03%20Outland/Shadowmoon%20Valley.lua) and [WoW-Pro Netherwing reference](https://www.wow-pro.com/neutral-netherdrake/): factual quest IDs, alternatives, reputation gates and coordinates.
- [Warcraft Mounts: Netherwing choice](https://www.warcraftmounts.com/mounts/veridiannetherwingdrake): one free reward and other colors sold by Hurlunk.
- [ALL THE THINGS: Argent Tournament](https://github.com/DFortun81/AllTheThings/blob/master/.contrib/.db/standard/06%20-%20Expansion%20Features/03%20-%20Wrath%20of%20the%20Lich%20King/Argent%20Tournament.lua): factual quest, item, vendor, faction and class identifiers and coordinates.
- [Champion's Seal](https://www.wowhead.com/currency=241/champions-seal) and [The Fate of the Fallen](https://warcraft.wiki.gg/wiki/The_Fate_Of_The_Fallen): purchase currency and additional Champion daily rewards.
- [Championing the Argent Tournament](https://www.wowhead.com/guide/world-events/championing-the-argent-tournament), [Crusader requirements](https://warcraft.wiki.gg/wiki/Exalted_Argent_Champion_of_the_Alliance) and [Argent Charger](https://warcraft.wiki.gg/wiki/Argent_Charger): distinct city, reputation and Paladin restrictions.
- [Blizzard GossipInfo declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/GossipInfoDocumentation.lua): live quest offers; no quest acceptance or turn-in is automated.

This supplement has automated verification, but still requires an in-game Retail
playthrough to verify current NPC phasing and vehicle quest behavior. Other
sources without prerequisite metadata retain legacy routing and display an
**unverified** notice. Missing metadata does not mean a source is confirmed
unlocked. Unknown declared requirement types fail closed.

## Adding sources

New curated content uses `RegisterChain` and `RegisterBinding`. A chain has a
stable key, an evidence URL, a terminal `requirements` expression and explicit
`quests` with `requires` edges. Source bindings use NPC ID plus source type, or
mount item ID plus source type where the generated record has no NPC ID. Chain
references reuse shared paths without copying generated rows. Source and
mount-specific requirements remain additive.

Validation checks scopes, IDs, supported graph predicates, missing chain/node
references, dependency cycles and coordinate ranges. An external quest flag
without a local action must explicitly use `checkOnly`. Invalid chains fail
closed. AND dependencies expose independent ready branches; OR chooses a
satisfied branch, then an active branch (including one waiting on items), then
the first curated actionable alternative. Completed terminal flags bypass old
quest history. Evaluation is bounded to prevent recursive data from hanging.

The resolver reports available, actionable, waiting, locked (external source
restrictions), or unknown. Only actionable prerequisite nodes enter the route.
Waiting reasons appear in `/mrp prerequisites status`. No progress is fabricated
when an API or declared requirement is unsupported. Unannotated sources retain
legacy routing with the existing unverified notice.

An optional provider `unlockRequirement` chooses the actionable graph separately
from its source/purchase requirements. Tournament scheduling uses this to finish
the current city before opening the next selected city. It is recalculated from
character progress and current filters, not saved as fake quest completion.

Legacy ordered metadata remains supported:

`requirements` and `unlockSteps` may be attached to a source entry, a step, or a
mount's `source`. All attached providers apply together. The checked-in
`Data/MRP_PrerequisiteData.lua` can supply supplements for generated data without
mutating it. The published generator is private; generated mount/source files
are intentionally not checked into this fork.

```lua
requirements = {
    allOf = {
        { type = "quest", id = 12915 },
        { type = "quest", id = 12956, scope = "character" },
    },
},
unlockSteps = {
    -- Include every required quest in dependency order, not just the endpoints.
    { questID = 12843, name = "They Took Our Men!", mapID = 120, x = 41.1, y = 86.1,
      objective = { mapID = 120, x = 40.7, y = 72.6 },
      turnIn = { mapID = 120, x = 41.1, y = 86.1 } },
    -- ...the rest of the verified chain...
},
```

Supported leaf types are `quest` (`id`, optional `scope`), `reputation`
(`factionID`, `standing`, standard ranks 1-8), `chain` (stable `id`), and `item`
(`id`, `count`, carried quantity). `allOf` and `anyOf` compose these.
An explicit account-scoped quest uses `IsQuestFlaggedCompletedOnAccount`; if that
API is absent its state is unknown. Reputation renown/paragon systems require a
future evaluator and must not be encoded as standard ranks.

A character-scoped quest predicate can set `allowActive = true` when acceptance,
rather than completion, opens a child quest. This reads the current quest log
or completed flag without saving synthetic completion. An accepted quest's
`progress` can reference a child quest/chain needed before its turn-in; Forging
an Alliance uses this to route the anvil subquests. Ordinary quest requirements
still require completion, and `allowActive` is rejected for account scope.
Daily groups use exactly one of `npcID` or `objectID` for their giver.

An unlock quest may have `faction` and `requires` metadata. Lists are evaluated in
order, skipping quests for the other faction. The first unfinished applicable
quest must satisfy its explicit dependencies before being offered. `anyOf`
supports alternative eligibility, but authors must supply the appropriate ordered
unlock path; this feature does not discover or optimize arbitrary campaign trees.

`quest_<id>` and `quest_account_<id>` legacy condition strings are also enforced.
They require separate ordered unlock metadata to generate a quest route. Existing
`entry.questID` remains a source completion/lockout field and is never interpreted
as a prerequisite.

## Testing and local build

Run `luajit tests/prerequisites.lua` from the repository root. Tests cover shared
branches, individual city and mount unlocks, the two factions, class restrictions,
choice behavior, waits, character/account scope, invalid graphs, filters and
waypoints. Daily tests cover shared stops, rotating offers, all twelve faction/city
seal loops over multiple resets, rank progression, completion persistence, offline
and online reset recovery, carried quests, auto-advance, missing APIs and combat
deferral. Champion farming tests cover shared budgets, mixed gold/seal prices,
alternative listings, item ownership, unknown prices/balances, purchases, all
four core quest variants, Exalted/Crusader gates and rotations, and stopping at
the goal across multiple reset periods. Hodir tests cover both factions' rank
targets, collected and owned items, shared setup branches, parent/child quest
acceptance, object offer detection, reputation API fields, and daily recovery
with missing reset data, offline periods, carried quests and combat. To include the
published-data regression, append an extracted `MountRoutePlannerData` directory:

```powershell
luajit tests/prerequisites.lua playground/release-data/MountRoutePlannerData
```

For a local test build, download **MountRoutePlanner_Bundled.zip** from upstream
v2.4.5, then run:

```powershell
./scripts/build-dev.ps1 -BaseZip ./playground/MountRoutePlanner_Bundled.zip
```

The script checks the upstream archive's SHA256, overlays the changed runtime
files, handles addon namespaces and development markers, adds the new TOC entries,
and produces `dist/MountRoutePlanner-quest-dev.zip`. It retains all four dependency
folders, does not modify an installed game, and does not upload a release. The
upstream license and attribution remain intact.

For in-game verification, back up the existing addon folders and install the four
folders from this local archive into Retail's `Interface/AddOns`. Enable all four
addons, log in, and run `/mrp prerequisites on`. Test on a character that has not
unlocked Lillehoff and on one with the unlock completed. Confirm K3 guidance,
quest acceptance/objective/turn-in transitions, resume after `/reload`, item-started
quest guidance, auto-advance on/off, map pins and TomTom/native waypoints, and the
Revered versus Exalted purchases. Then verify:

- Gretta alone and alongside Lillehoff, a live daily offered before the full
  preparation path, gossip versus quest greeting versus direct detail, active
  daily objectives/turn-in with stale completion flags, and the next daily reset
  with the farming opt-ins off.
- Netherwing before Neutral, at each promotion boundary, the flight to Shattrath,
  one free choice, and the Hurlunk destination for remaining colors.
- `/mrp dailies on` while below Friendly and after each promotion; visit Yarzill
  and the Taskmaster, then the mines and Mudlump after their setup quests. Check
  empty gossip and quest greeting lists, an offered daily, and a directly opened
  quest detail. Verify object greetings with no exposed unit GUID as well.
- Both Tournament factions: three mastery quests, seal waits across a reset,
  one city Champion, a second city with the first still active, and all five
  Crusader milestones. Compare Paladin Charger eligibility with another class.
- Aspirant and Valiant daily loops: verify today's weapon choice, accept all
  offered dailies, complete objectives and turn-ins, and reach 15/25 carried
  seals. Test a reset while online, a reload before reset, a login after reset,
  a quest carried across reset, and a completed stop with auto-advance off.
- `/mrp championseals on` with both unlock options off, then together with them.
  Select multiple Tournament mount sources and confirm their shared target.
  Check both factions and Death Knight givers, Threat from Above access, and
  Exalted/Crusader rotations including Kul alongside the rescue quest. Confirm
  that opening purses changes the balance, reaching the target restores eligible
  vendors, and buying an item removes its cost before learning it. Test spending
  on something else, deselecting vendors, reload/offline/online resets, a carried
  daily, and reaching the target with auto-advance off.
- `/mrp hodir on` with the original faction unlock incomplete, then complete.
  Test the anvil's nested parent/child path, horn/helm preparation and Honored
  spear setup. Check object clicks that open a quest directly, the Denmother's
  gossip, empty offers, active objectives and each giver's turn-in. Select Ice
  Mammoth alone, Grand Ice Mammoth alone and both; verify that Revered stops the
  Ice-only route while Exalted stops the shared route. Verify bought-but-unlearned
  items, reputation gains from other activities, reset/reload/login recovery,
  missing reset data, carried quests and stopping with auto-advance disabled.

UI/localized text and actual NPC availability cannot be established by the mocked
Lua tests. For packaged-file verification, pass the expanded addon directory as
the second test argument after the data directory; this also checks release
namespace handling for every new module.
