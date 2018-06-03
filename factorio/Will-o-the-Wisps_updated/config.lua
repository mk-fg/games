-- Initial config for the mod
-- Values here can be overidden via Mod Options menu

local conf = {}

-- Note: all *_interval values are in ticks
local time_gameday = 417 -- seconds
local time_sec = 60
local time_min = 3600


-- Disables aggression between wisps and player factions.
conf.peaceful_wisps = false
conf.peaceful_defences = false
conf.peaceful_spores = false

-- Minimal darkness value when the wisps appearing (0; 1)
-- Chances of wisps appearing increase in reverse to this value.
-- Full daylight is 0 (wisps at daytime), max darkness is ~0.85.
conf.min_darkness = 0.05

-- Max number of wisps on the map
conf.wisp_max_count = 1250

-- Damage parameters for the purple wisps
conf.wisp_purple_dmg = 1
conf.wisp_purple_area = 2

-- Disable glow of the purple wisps to increase performance (set to false)
conf.wisp_spore_emit_light = true

-- These values will affect number of the wisps which rise from forests on their own
-- All values should be in 0-1 range, and sum up to <=1 (<1 will mean more rare spawns)
-- Defaults: purple=80%, yellow=9%, red=0.5%
conf.wisp_purple_spawn_chance = 0.80
conf.wisp_yellow_spawn_chance = 0.09
conf.wisp_red_spawn_chance = 0.005

-- Experimental features
conf.experimental = false

----------------------------------------------------------
-- options for long night mods
----------------------------------------------------------
-- Override the day/night cycle for mods with long night:
---- the wisps will be active for fake_night_len: 3 minutes
---- every fake_day_mult * fake_night_len: 9 minutes
---- (i.e. 3 min of nigth and 9 min of fake day by default)

conf.time_fake_day_mode = true
conf.time_fake_day_mult = 3
conf.time_fake_night_len = 3 * time_min

---- Skip the agreesive state of the wisps after every 12 minutes of night
---- Default value: 12 = (fake_day_mult + 1) * fake_night_len
---- (this works even if fake_day_mode = false)
conf.reset_aggression_at_night = true


-- UV lights / detectors parameters

conf.uv_check_interval = 53
conf.uv_check_fragm = 7
conf.uv_dmg = 16
conf.uv_range = 12

conf.detection_range = 16
conf.detection_interval = 47
conf.detection_fragm = 3


-- Misc other constants

conf.wisp_spawn_interval = 317

conf.wisp_ttl_purple = 120 * time_sec
conf.wisp_ttl_yellow = 100 * time_sec
conf.wisp_ttl_jitter_sec = 40 * time_sec -- -40;+40

conf.wisp_light_interval = 2
conf.wisp_light_fragm = 3

conf.targeting_interval = 11 * time_sec
conf.tactical_interval = 97
conf.sabotage_interval = 107
conf.sabotage_range = 3

conf.targeting_attempts = 3
conf.targeting_forest_distance = 12
conf.targeting_chunk_update_interval = 3 * time_gameday

conf.wisp_wandering_percent = 0.8
conf.wisp_replication_chance = 0.2

conf.forest_count_with_wisps = 7
conf.forest_min_density = 200
conf.forest_wisp_percent = 0.02

conf.ttl_check_interval = 37
conf.ttl_check_fragm = 3
conf.gc_fragm = 5


-- debug_log file path: %user-dir%/script-output/Will-o-the-wisps_updated/debug.log
-- To find %user-dir% see https://wiki.factorio.com/Application_directory#User_data_directory

conf.debug_log = true


return conf
