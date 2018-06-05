-- Initial config for the mod
-- Values here can be overidden via Mod Options menu

local conf = {}

local time_gameday = 417 -- seconds
local time_sec = 60


-- Disables aggression between wisps and player factions.
conf.peaceful_wisps = false
conf.peaceful_defences = false
conf.peaceful_spores = false

-- Minimal darkness value when the wisps appearing (0-1).
-- Chances of wisps appearing increase in reverse to this value.
-- Full daylight is 0 (wisps at daytime), max darkness is ~0.85.
conf.min_darkness = 0.05
conf.min_darkness_to_emit_light = 0.10

conf.wisp_chance_func = function(darkness, wisp)
	-- Used to roll whether new wisp should be spawned,
	--  and to have existing wisps' ttl not decrease on expire-check (see intervals below).
	return darkness > conf.min_darkness
		and math.random() < darkness - 0.40 end

conf.wisp_ttl_expire_chance_func = function(darkness, wisp)
	-- When true, wisp's ttl will drop to 0 on expire-check
	-- Check is made each "expire" interval * step, chances add up exponentially
	-- Picked from basic exponent chart, too lazy to fit some curve to these
	local chance
	if darkness < 0.30 then chance = 0.02
	elseif darkness < 0.20 then chance = 0.04
	elseif darkness < 0.10 then chance = 0.07
	elseif darkness < 0.08 then chance = 0.10
	elseif darkness < 0.05 then chance = 0.15 end
	return chance and math.random() < chance end

conf.wisp_peace_chance_func = function(darkness)
	-- Applies to all wisps
	if darkness >= conf.min_darkness
		then return conf.wisp_ttl_expire_chance_func(darkness) end
	return 0.3
end

-- Max number of wisps on the map
conf.wisp_max_count = 1250

-- Damage parameters for the purple wisps
conf.wisp_purple_dmg = 1
conf.wisp_purple_area = 2

-- Disable glow of the purple wisps to increase performance (set to false)
conf.wisp_spore_emit_light = true

-- Dynamic lights can be annoying and a performance hit as well
-- conf.wisp_lights_diverse = true
conf.wisp_lights_dynamic = false

-- These values will affect number of the wisps which rise from forests on their own
-- All values should be in 0-1 range, and sum up to <=1 (<1 will mean more rare spawns)
-- Defaults: purple=80%, yellow=9%, red=0.5%
conf.wisp_purple_spawn_chance = 0.80
conf.wisp_yellow_spawn_chance = 0.09
conf.wisp_red_spawn_chance = 0.005

---- Skip the agreesive state of the wisps after every 12 minutes of night
---- Default value: 12 = (fake_day_mult + 1) * fake_night_len
---- (this works even if fake_day_mode = false)
conf.reset_aggression_at_night = true


-- UV lights / detectors parameters

conf.uv_dmg = 16
conf.uv_range = 12

conf.detection_range = 16


-- Misc other constants

conf.wisp_ttl_purple = 120 * time_sec
conf.wisp_ttl_yellow = 100 * time_sec
conf.wisp_ttl_jitter_sec = 40 * time_sec -- -40;+40

conf.sabotage_range = 3

conf.zones_attempts = 3
conf.zones_forest_distance = 12
conf.zones_chunk_update_interval = 3 * time_gameday

-- wisp_percent_in_random_forests sets percentage of maximus wisp count,
--  after which they stop spawning in random forests on the map,
--  to leave some margin for spawning near player position.
conf.wisp_percent_in_random_forests = 0.8
conf.wisp_replication_chance = 0.2

conf.forest_count_with_wisps = 7
conf.forest_min_density = 200
conf.forest_wisp_percent = 0.02


-- debug_log file path: %user-dir%/script-output/Will-o-the-wisps_updated/debug.log
-- To find %user-dir% see https://wiki.factorio.com/Application_directory#User_data_directory

conf.debug_log = true


-- Intervals don't really have to be primes, but it might help to
--  space them out on ticks more evenly, to minimize clashes/backlog.
---  3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67,
---  71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137,
---  139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199
--- 211  223 227 229 233 239 241 251 257 263 269 271 277 281
--- 283  293 307 311 313 317 331 337 347 349 353

conf.intervals = {
	tactics=97, spawn=317, zones=11*time_sec,
	detectors=47, light=3, uv=53, expire=59 }
conf.work_steps = {detectors=4, light=2, uv=5, expire=3}

-- wisp_light_anim_speed should be low enough for light to stay around until next update.
-- animation_speed=1 is "display light for 1 tick only"
-- Formula here:
-- Note: used in prototypes only, so re-read on factorio restart, not savegame load!
conf.wisp_light_anim_speed = 1 / (conf.intervals['light'] * conf.work_steps['light'] + 1)

conf.work_limit_per_tick = 1 -- max 1 task function to run per tick


return conf
