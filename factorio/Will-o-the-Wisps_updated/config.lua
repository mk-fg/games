-- Initial config for the mod
-- Values here can be overidden via Mod Options menu

-- --== "strict mode" hack to find local vars that are used globally, or without initialization ==-- --
-- This will apply to all scripts of the mod, so only need to set these handlers in one of them
-- Suggested by Pi-C, made by eradicator, incredibly useful to detect bugs and desyncs
setmetatable(_ENV, {
	__newindex = function(self, key, value)
		error('\n\n[ENV Error] Forbidden global *write*:\n'
			..serpent.line{key=key or '<nil>', value=value or '<nil>'}..'\n') end,
	__index = function(self, key)
		if key == 'game' then return end -- used in utils.log check
		error('\n\n[ENV Error] Forbidden global *read*:\n'
			..serpent.line{key=key or '<nil>'}..'\n') end })

local conf = {}

local ticks_sec = 60
local ticks_gameday = 417 * ticks_sec

-- Disables aggression between wisps and player factions.
conf.peaceful_wisps = false
conf.peaceful_defences = true
conf.peaceful_spores = false

-- Max number of wisps on the map
conf.wisp_death_retaliation_radius = 96

-- Max number of wisps on the map
conf.wisp_max_count = 1250

-- Damage parameters for the purple wisps prototypes
conf.wisp_purple_dmg = 1
conf.wisp_purple_area = 2

-- Aggression chance in most likely spawn zones via radicalize routine
-- Disabled by default (=0) for wisps to be less annoying
conf.wisp_aggression_factor = 0

-- Whether wisps attack biters and vice-versa.
-- Can cause red wisp numbers to go out of control.
conf.wisp_biter_aggression = false

-- Normally wisps become aggressive regardless
--  of what killed them, except the sun, as players are their only natural enemy.
-- This option adds a check for which "force" damage
--  came from, and whether it matches one of players.
conf.wisp_aggro_on_player_only = false

-- UV lamps
-- "limit" value is auto-adjusted from lamp entities, if ever seen higher,
--  not sure how to get it right from the start - how is it calculated? pls fix if you know how
conf.uv_lamp_energy_limit = 2844.45
conf.uv_lamp_energy_min = 0.2
conf.uv_lamp_range = 12

-- See also in control.lua for other parameters:
--  - uv_lamp_damage_func
--  - uv_lamp_spore_kill_chance_func
--  - uv_lamp_ttl_change_func

-- Detectors
conf.detection_range_default = 16
conf.detection_range_max = 128
conf.detection_range_signal = 'signal-R'

-- How long wisps stay around
-- Except in daylight (where wisp_ttl_expire_chance_func kills them)
--  and can vary due to wisp_ttl_jitter_sec and wisp_chance_func.
conf.wisp_ttl = {
	['wisp-purple']=120 * ticks_sec,
	['wisp-purple-harmless']=120 * ticks_sec,
	['wisp-green']=60 * ticks_sec,
	['wisp-yellow']=100 * ticks_sec,
	['wisp-red']=100 * ticks_sec }
conf.wisp_ttl_jitter = 40 * ticks_sec -- -40s to +40s

-- Misc other wisp parameters
conf.wisp_group_radius = {['wisp-yellow']=16, ['wisp-red']=6}
conf.wisp_group_min_ttl = 100
conf.wisp_red_damage_replication_chance = 0.2
conf.wisp_drone_ttl = 3 * 3600 * ticks_sec -- 3 hours

-- Minimal darkness value when the wisps appearing (0-1).
-- Full daylight is darkness=0 (wisps at daytime), max ~0.85.
-- Also used to check for max uv level in uv expire.
conf.min_darkness = 0.05
conf.min_darkness_to_emit_light = 0.10

-- See also in control.lua for other parameters: wisp_chance_func

-- Darkness drop step to +1 uv level and run wisp_uv_expire_chance.
-- See also: chart in doc/darkness-wisp-expire-chart.html file
conf.wisp_uv_expire_step = 0.10
conf.wisp_uv_expire_jitter = 20 * ticks_sec -- instead of ttl=0

--- See also in control.lua for other parameters:
--  - wisp_uv_expire_* funcs
--  - wisp_uv_peace_chance_func


-- ---------- Map scanning/spawning parameters

-- wisp_forest_on_map_percent sets percentage of maximum wisp count,
--  after which they stop spawning in random forests on the map,
--  to leave some margin for spawning near player position and on death.
conf.wisp_forest_on_map_percent = 0.8
-- Min tree count on 3x3 chunk area to randomly spawn wisps there.
conf.wisp_forest_min_density = 300

-- Sets how much normalized pollution value (0-1.0 range, with 1.0
--  being maximum from all forested chunks) factors into random pick.
-- Random weight for forest chunk is calculated as: 1 + p * pollution_factor
-- So if pollution_factor is 0, all forested chunks are equal,
--  and if it's <0 then wisps will be less likely to spawn in polluted areas.
conf.wisp_forest_spawn_pollution_factor = 100

-- Chances for which wisps rise from forests on their own
-- Sum should be in 0-1 range (<1 will mean some spawns skipped)
conf.wisp_forest_spawn_chance_purple = 0.50
conf.wisp_forest_spawn_chance_yellow = 0.07
conf.wisp_forest_spawn_chance_green = 0.02
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
conf.chunk_rescan_spread_interval = 3 * ticks_gameday
-- Alien flora do not grow back in base game, but in case of mods...
conf.chunk_rescan_tree_growth_interval = 8 * ticks_gameday
-- Jitter to spread stuff out naturally by randomness
conf.chunk_rescan_jitter = 5 * 60 * ticks_sec

-- Code can mostly handle multiple surfaces, but why bother
conf.surface_name = 'nauvis'


-- ---------- Parameters for wisps visiting player

local c = {}
conf.congregate = c

c.entity = 'wisp-green'
c.chance_factor = 5 -- chance = wisp_forest_spawn_chance_green * chance_factor
c.group_size = 16 -- affected by wisp_chance_func
c.group_size_min_factor = 0.3 -- actual group-size is random(group_size * min_factor, group_size)
c.source_pollution_factor = 500 -- pollution_factor for spawning visiting group
c.dst_chunk_radius = 10 -- distance in chunks to scan for destination
c.dst_find_building_radius = 16 -- radius to pick target building in from dst pos
c.dst_arrival_radius = 16 -- when group is that close, assign new dst
c.dst_arrival_ticks = 3000 -- ticks before assigning new dst
c.dst_next_building_radius = 128 -- radius to pick target building in from dst pos


-- ---------- Performance stuff

-- Intervals are for on_nth_tick handler, ideally should be primes (less collisions).
-- Must not be on the same tick.

conf.intervals = {
	spawn_near_players=107, spawn_on_map=113,
	pacify=311, tactics=97, radicalize=3613,
	congregate=3607, recongregate=353,
	detectors=47, uv=31, expire_ttl=73, expire_uv=61 }
conf.work_steps = {
	recongregate=5, detectors=4, uv=4, expire_ttl=8, expire_uv=5 }

-- Chunks are checked for pollution/player spread during daytime only, can ~10k chunks
-- Interval formula: (ticks_gameday * 0.6) / work_steps
conf.work_steps.zones_spread = 666
conf.intervals.zones_spread = 79

-- Scan "spread" areas for trees.
-- Much more difficult as it does find_entities_filtered instead of just pollution level probe.
-- Takes 1.89s to scan 682 chunks finding 243 forests here - almost 3ms per scan!
conf.work_steps.zones_forest = 600
conf.intervals.zones_forest = 89


-- ---------- Lighing effects

-- Light to attach to wisp entity is picked at random on creation from per-entity sub-list.
-- Missing/empty entity table here will mean "no light from this wisp".
-- Lights can be made dynamic (change over time, flicker, rotate, etc),
--  but for wisps only slow changes make sense - constant lights look best.
-- Default sprite is 300px "utility/light_medium" (tile is 32px), if not specified explicitly.
-- Special key "size" will be translated to "scale" via "scale = size / 9.375" (default sprite).

conf.light_defaults = {
	sprite='utility/light_medium',
	minimum_darkness=conf.min_darkness_to_emit_light }
conf.light_aliases = {['wisp-purple-harmless']='wisp-purple'}

conf.light_entities = {
	['wisp-yellow']={
		{intensity=0.5, size=5},
		{intensity=0.7, size=6, color={r=0.95, g=0.84, b=0.1}},
		{intensity=0.4, size=12, color={r=0.7, g=0.5, b=0.3, a=0.7}},
		{intensity=0.6, size=7, color={r=0.8, g=0.7, b=0.1, a=0.8}}
	},
	['wisp-green']={
		{intensity=0.7, size=7, color={r=0.01, g=0.91, b=0.5}},
		{intensity=0.4, size=11, color={r=0.27, g=0.73, b=0.16, a=0.7}},
		{intensity=0.6, size=9, color={r=0.32, g=0.95, b=0.55, a=0.8}}
	},
	['wisp-red']={
		{intensity=0.5, size=5},
		{intensity=0.3, size=7, color={r=0.95, g=0.0, b=0.8}},
		{intensity=0.2, size=12, color={r=0.95, g=0.0, b=0.3}}
	},
	['wisp-purple']={
		{intensity=0.7, size=5, color={r=0.30, g=0.24, b=1.0, a=0.5}},
		{intensity=0.4, size=11, color={r=0.36, g=0.15, b=0.82, a=0.8}},
		{intensity=0.6, size=7, color={r=0.40, g=0.05, b=0.80, a=0.6}},
		{intensity=0.5, size=3, color={r=0.15, g=0.02, b=0.88, a=0.7}}
	},
	['wisp-drone-blue']={
		{intensity=0.7, size=110, color={r=0, g=1.0, b=0.95, a=0.7}},
	},
	['wisp-detector']={
		{intensity=0.3, size=7, color={r=0.95, g=0.0, b=0.8}},
	},
}


-- ---------- Testing hacks

-- Locations for "/wisp incidents" console command
conf.incident_track_max = 300
conf.incident_track_timeout = 8 * 60 * ticks_sec

-- use print() instead of log() for shorter prefix
conf.debug_log_direct = true

-- Enable this for various utils.log() messages from code to
--  go to factorio logging (stdout by default) instead of nowhere.
-- conf.debug_log = true


return conf
