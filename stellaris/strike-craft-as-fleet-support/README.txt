Makes strike craft more useful in a multipurpose fleet support role.
For Stellaris 2.0-2.1, compatible with most other mods, can be added/removed at any time, disables acheivements.

Rebalances strike craft (bombers) to be useful against all ships types, but best against none, with focus on hull damage and finishing-off weakened targets.
They can now effectively chase and hit corvettes (550 speed vs 200-350 of corvettes, fast turn rate), and have increased damage output to threaten heavy ships as well.
Scouts renamed to Defensive Fighter Wing which have more limited range and interceptor/point-defence focus.

Does not touch any technologies or adds anything new, just stats of existing ship modules.
Heavily inspired by [url=steamcommunity.com/sharedfiles/filedetails/?id=1316898175]SD's Better Strike Craft 2[/url] and [url=steamcommunity.com/sharedfiles/filedetails/?id=1348070082]Stellaris StrikeCraft Overhaul[/url] mods.

Tested in same-cost fleet engagements with all ship classes and tiers (see below for how to do it easily), and pretty happy wrt how it works in all scenarios.


[h1]Rationale[/h1]

In base 2.0.4, hangars of strike craft are useless, loosing badly to all weapons and ship types.
Plus focus there is clearly on countering heavy ships with increased armor damage, slow speed and poor maneuverability.

Terrible agility seem to be main contributing factor to crippled damage output - bombers waste too much time closing in, chasing stuff, switching targets, and can't stay within their firing range most of the time.
All the while there are already large/extra-large weapons as an obvious big-vs-big ship counter, which don't have all the finicky qualities of bombers and are not affected by PD either.

Most other strike craft rebalance mods seem to buff strike craft to make carriers win against other ship classes if there's no point-defence to shoot them down - a best-choice weapon unless countered.

This mod aims to make them more powerful too, but still loose to dedicated heavy ship designs (e.g. torpedo boats, heavy artillery), and be vulnerable to point-defence, but to a lesser extent than missiles.

Focus is instead on good versatility against everything for carrier designs, making them a good choice for resilient support capital ship role.

I.e. can protect heavy-gun cruisers/battleships against corvettes, as well as contribute to any fleet standoffs just fine, but to a much lesser extent than dedicated counters would.
Fast autocannon corvettes would still work better to get rid of heavy shields/hulls, torpedo boats would fare better against massive armor and big ships, and small-gun/good-tracking destroyers would still be better against corvettes.

Some mods that add ship AI with "Hit & Run" (keep distance) tactic can be good for dedicated long-range hangar/missile ships, keeping them out of harm's way, but can also be overpowered for fast carrier-only fleets.


[h1]Technical Details[/h1]

Compatibility-wise, mod overwrites single "common/component_templates/00_strike_craft.txt" file, so is only incompatible with other mods that change default strike craft ship modules (note - big mods like NSC tend to do that), while mods only adding new hangars should be perfectly fine.

It does not change any technologies or adds anything new, only changing existing ship modules/behaviors, so can be added to an existing game at any time, applying its effects, or removed to revert back to vanilla hangar module/craft stats/behaviors.

License: [url=https://en.wikipedia.org/wiki/WTFPL]WTFPL[/url]

[b]Specific changes to bombers are:[/b]

[list]
[*]Agility - speed/acceleration/rotation is up to 550 / 2 / 0.5 vs vanilla 300-400 / 0.5 / 0.1 - have to be at least ~2x to stick to target ships effectively.

[*]Whole wing launch is now near-instant, craft no longer get released slowly one-by-one.

[*]Firepower - fixed 10-20 damage for all bombers, dps scaled via cooldown value only. 1.5x armor damage bonus replaced by 1.3x hull. Tracking is balanced to fight roughly on-par/win vs general-purpose corvettes of the same tech level (they're no torpedo boats though).

[*]Resilience - balanced for mixing-in flaks to be more effective than just big guns to kill carriers faster, evasion roughly same so that sentinels are less useful than flaks.

[*]Range - 2x for bombers, halved for scouts (PD wing) - but it does not affect engagement start range, only how far bombers will try to stay from the host ship during battle.

[*]Red laser sounds/animations swapped to autocannons for bombers, but not scouts - mostly cosmetic (less visual noise) and also helps to differentiate the two.
[/list]

[b]Scout Wing[/b] changed to point-defence-focused "Defensive Fighter Wing", which should stay with the fleet, have much lower range, use point_defence weapon, but have higher evasion/resilience.

One side effect of increased bomber range is that Starbase Defence Platforms with hangars are more useful, as strike craft from there can fight alongside defensive fleets in the system, which often fly out of reach of other immobile weapons.

[b]To test how all these work in actual combat:[/b]

[list]
[*]Start new game.

[*]Open console (~ [tilde] key), and use following commands there: "ai" (disables AI), "research_all_technologies", "instant_build", "pp" (adds ton of minerals).
Would highly recommend using tab completion (type first command letters, press tab key) and console history (up/down keys). More info on [url=stellaris.paradoxwikis.com/Console_commands]Stellaris wiki[/url].

[*]In Ship Designer (F10), create ships for fleets to pit against each other (all techs unlocked, use "show obsolete components" checkbox to make more early-game-tier ships) and build fleets on the shipyard (instant due to "instant_build").
Usually fleets of the same naval capacity and roughly same tech should cost roughly the same and are likely to face each other in actual wars.

[*]Move fleets to any neighbor system ("tweakergui instant_move" can help), put them at a distance, use "attackallfleets" command in console and order them to attack each other, observe the results.
[/list]

Note that such "testing stuff" game can be saved with pre-built fleets in positions to repeat same battle configuration(s) with e.g. different mods, mod versions and tweaks.

When changing any mod values (requires unpacking the mod from zip), use console command "reload stats" to load new 00_strike_craft.txt stats and "reload behaviors" to reload scafs_strike_craft.txt (behaviors file) without restarting the game.

If you'll find a scenario where hangars shouldn't be as weak/powerful as they are, do leave a comment please, ideally with ship counts and their configuration, so it'd be easily to reproduce same engagement here.

[b]Known issues:[/b]

New description text for Defensive Fighter Wing does not get picked-up from localization file, unlike the name. Can't figure out why, but one left over from Scout Wing is basically correct anyway.


[h1]Links[/h1]

- [url=steamcommunity.com/sharedfiles/filedetails/?id=1364691606]Picket Bow Parity[/url] mod - fixes imbalanced picket bow section on destroyers, making them into a great picket ship (as they should be!) to counter strike craft.

- [url=steamcommunity.com/sharedfiles/filedetails/?id=1359009066]Furaigon's Battleship Variety[/url] mod - more balanced choices for battleship sections with unique models for each shipset, restored from earlier game version models.

- [url=steamcommunity.com/sharedfiles/filedetails/?id=1366378205]Ship Behavior fix and Sniper, H&R tactic[/url] mod - provides good non-intrusive "keep distance" ship-ai module (among others) to keep carriers at the back. Can be a huge buff to fast missile/carrier fleets though, so use responsibly.
