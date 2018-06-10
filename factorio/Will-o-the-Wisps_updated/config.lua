-- Initial config for the mod
-- Values here can be overidden via Mod Options menu

local conf = {}

local ticks_sec = 60
local ticks_gameday = 417 * ticks_sec

-- Disables aggression between wisps and player factions.
conf.peaceful_wisps = false
conf.peaceful_defences = false
conf.peaceful_spores = false

-- Max number of wisps on the map
conf.wisp_max_count = 1250

-- Damage parameters for the purple wisps prototypes
conf.wisp_purple_dmg = 1
conf.wisp_purple_area = 2

-- UV lights / detectors
conf.uv_dmg = 16
conf.uv_range = 12
conf.detection_range = 16
conf.detection_range_max = 128
conf.detection_range_signal = 'signal-R'

-- How long wisps stay around
-- Except in daylight (where wisp_ttl_expire_chance_func kills them)
--  and can vary due to wisp_ttl_jitter_sec and wisp_chance_func.
conf.wisp_ttl = {
	['wisp-purple']=120 * ticks_sec,
	['wisp-purple-harmless']=120 * ticks_sec,
	['wisp-yellow']=100 * ticks_sec,
	['wisp-red']=100 * ticks_sec }
conf.wisp_ttl_jitter = 40 * ticks_sec -- -40s to +40s

-- Misc other wisp parameters
conf.wisp_group_radius = {['wisp-yellow']=16, ['wisp-red']=6}
conf.wisp_group_min_ttl = 100
conf.wisp_red_damage_replication_chance = 0.2

-- Minimal darkness value when the wisps appearing (0-1).
-- Full daylight is darkness=0 (wisps at daytime), max ~0.85.
-- Also used to check for max uv level in uv expire.
conf.min_darkness = 0.05
conf.min_darkness_to_emit_light = 0.10

conf.wisp_chance_func = function(darkness, wisp)
	-- Used to roll whether new wisp should be spawned,
	--  and to have existing wisps' ttl not decrease on expire-check (see intervals below).
	return darkness > conf.min_darkness
		and math.random() < darkness - 0.40 end

-- Darkness drop step to +1 uv level and run wisp_uv_expire_chance.
-- See also: chart in darkness-wisp-expire-chart.html file
conf.wisp_uv_expire_step = 0.10
conf.wisp_uv_expire_jitter = 20 * ticks_sec -- instead of ttl=0

-- All wisp_uv_* chances only work with wisp_uv_expire_step value above
local wisp_uv_expire_exp = function(uv) return math.pow(1.3, 1 + uv * 0.08) - 1.3 end
local wisp_uv_expire_exp_bp = wisp_uv_expire_exp(6)
conf.wisp_uv_expire_chance_func = function(darkness, uv, wisp)
	-- When returns true, wisp's ttl will drop to 0 on expire_uv.
	-- Check is made per wisp each time when
	--  darkness drops by conf.wisp_daytime_expire_step
	--  or on every interval*step when <min_darkness.
	local chance
	if uv < 6 then chance = wisp_uv_expire_exp(uv)
	else chance = wisp_uv_expire_exp_bp + uv * 0.03 end
	return math.random() < chance
end

-- Applies to all wisps, runs on global uv level changes, not per-wisp
conf.wisp_uv_peace_chance_func = function(darkness, uv)
	return math.random() < (uv / 10) * 0.3
end


-- ---------- Map scanning/spawning parameters

-- wisp_forest_on_map_percent sets percentage of maximum wisp count,
--  after which they stop spawning in random forests on the map,
--  to leave some margin for spawning near player position and on death.
conf.wisp_forest_on_map_percent = 0.8
-- Min tree count on 3x3 chunk area to randomly spawn wisps there.
conf.wisp_forest_min_density = 300

-- Chances for which wisps rise from forests on their own
-- Sum should be in 0-1 range (<1 will mean some spawns skipped)
conf.wisp_forest_spawn_chance_purple = 0.50
conf.wisp_forest_spawn_chance_yellow = 0.07
conf.wisp_forest_spawn_chance_red = 0.01

-- How many wisps will try to spawn, subject to wisp_forest_spawn_chance_*
conf.wisp_forest_spawn_count = 3

-- Radius (tiles square) in which to spawn wisps near players.
-- Note: near_player and forest_on_map wisps are spawned independently.
conf.wisp_near_player_radius = 16
-- floor(tree-count * wisp_near_player_percent) = wisps
--  spawned near each player in wisp_near_player_radius.
-- E.g. 0.02 = 2 per each 100+ trees.
conf.wisp_near_player_percent = 0.01

-- How often to update chunk players/pollution spread
conf.chunk_rescan_spread_interval = 1 * ticks_gameday
-- Alien flora do not grow back in base game, but in case of mods...
conf.chunk_rescan_tree_growth_interval = 4 * ticks_gameday
-- Jitter to spread stuff out naturally by randomness
conf.chunk_rescan_jitter = 5 * 60 * ticks_sec

-- Code can mostly handle multiple surfaces, but why bother
conf.surface_name = 'nauvis'


-- ---------- Performance stuff

-- Intervals don't really have to be primes, but it might help to
--  space them out on ticks more evenly, to minimize clashes/backlog.
-- Spreading workload as thinly as possible is probably the best option.
---  3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67,
---  71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137,
---  139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199
--- 211  223 227 229 233 239 241 251 257 263 269 271 277 281
--- 283  293 307 311 313 317 331 337 347 349 353

conf.intervals = {
	spawn_near_players=107, spawn_on_map=113, pacify=311, tactics=97,
	detectors=47, light=3, light_detectors=17, uv=53, expire_ttl=73, expire_uv=61 }
conf.work_steps = {
	detectors=4, light=2, light_detectors=4, uv=5, expire_ttl=8, expire_uv=5 }

-- Chunks are checked for pollution/player spread during daytime only, can ~10k chunks
-- Interval formula: (ticks_gameday * 0.6) / work_steps
conf.work_steps.zones_spread = 666
conf.intervals.zones_spread = 23 -- ~1 day-time for 10k chunks scan at 666 steps

-- Scan "spread" areas for trees.
-- Much more difficult as it does find_entities_filtered instead of just pollution level probe.
-- Takes 1.89s to scan 682 chunks finding 243 forests here - almost 3ms per scan!
conf.work_steps.zones_forest = 600
conf.intervals.zones_forest = 29 -- ~1 day-time for 3k chunks scan at 600 steps

conf.work_limit_per_tick = 20


-- ---------- Lighing effects

-- wisp_light_anim_speed should be low enough for light to stay around until next update.
-- animation_speed=1 is "display light for 1 tick only"
-- Note: used in prototypes only, so re-read on factorio restart, not savegame load!
conf.wisp_light_anim_speed = 1 / (conf.intervals.light * conf.work_steps.light + 1)

-- Light from wisp trapped in a detector device
conf.wisp_light_anim_speed_detector = 1
	/ (conf.intervals.light_detectors * conf.work_steps.light_detectors * 3)

-- Disables light for wisps that are about to expire
conf.wisp_light_min_ttl = conf.intervals.expire_ttl

-- Missing entity info here will mean "no light from this wisp"
conf.wisp_light_entities = {
	['wisp-yellow']={
		{intensity=0.5, size=5},
		{intensity=0.7, size=6, color={r=0.95, g=0.84, b=0.1}},
		{intensity=0.4, size=12, color={r=0.7, g=0.5, b=0.3, a=0.7}},
		{intensity=0.6, size=7, color={r=0.8, g=0.7, b=0.1, a=0.8}}
	},
	['wisp-red']={
		{intensity=0.5, size=5},
		{intensity=0.3, size=7, color={r=0.95, g=0.0, b=0.8}},
		{intensity=0.2, size=12, color={r=0.95, g=0.0, b=0.3}}
	},
	['wisp-purple']={ -- light from these can be disabled to increase performance
		{intensity=0.7, size=5, color={r=0.30, g=0.24, b=1.0, a=0.5}},
		{intensity=0.4, size=11, color={r=0.36, g=0.15, b=0.82, a=0.8}},
		{intensity=0.6, size=7, color={r=0.40, g=0.05, b=0.80, a=0.6}},
		{intensity=0.5, size=3, color={r=0.15, g=0.02, b=0.88, a=0.7}}
	},
}
conf.wisp_light_name_fmt = '%s-light-%02d'
conf.wisp_light_aliases = {['wisp-purple-harmless']='wisp-purple'}
conf.wisp_light_counts = {}
for wisp_name, light_info_list in pairs(conf.wisp_light_entities) do
	conf.wisp_light_counts[wisp_name] = #light_info_list end
conf.wisp_light_counts['wisp-detector'] = 1


-- ---------- Testing hacks

-- debug_log file path: %user-dir%/script-output/Will-o-the-wisps_updated/debug.log
-- To find %user-dir% see https://wiki.factorio.com/Application_directory#User_data_directory

-- conf.debug_log = true

-- conf.work_steps.zones_spread = 1
-- conf.work_steps.zones_forest = 1
-- conf.intervals.zones_spread = 173
-- conf.intervals.zones_forest = 173

-- conf.wisp_forest_spawn_chance_purple = 0.01
-- conf.wisp_forest_spawn_chance_yellow = 0.70
-- conf.wisp_forest_spawn_chance_red = 0.10


return conf
