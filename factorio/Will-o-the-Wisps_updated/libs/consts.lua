local const = {}

-- Experimental features
const.EXPERIMANTAL = false

-- Timing
local GAMEDAY = 417 --sec
local SEC = 60
local MIN = 3600

--  3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67,
--  71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137,
--  139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199
-- 211	223 227	229	233	239	241	251	257	263	269	271	277	281
-- 283	293	307	311	313	317	331	337	347	349	353


const.EMIT_LIGHT_PERIOD = 2
const.EMIT_LIGHT_FRAGM = 3

const.TTL_CHECK_PERIOD = 37
const.TTL_CHECK_FRAGM = 3

const.GC_FRAGM = 5

const.UV_CHECK_PERIOD = 53
const.UV_CHECK_FRAGM = 7

const.DETECTION_PERIOD = 47
const.DETECTION_FRAGM = 3

const.SPAWN_PERIOD = 317

const.TARGETING_PERIOD = 11 *SEC
const.TACTICAL_PERIOD = 97
const.SABOTAGE_PERIOD = 107
const.SABOTAGE_RANGE = 3

const.PURPLE_TTL = 120 *SEC
const.YELLOW_TTL = 100 *SEC
const.TTL_DEVIATION = 40 *SEC -- -40;+40


-- targeting
const.ATTEMPTS = 3
const.TTU = 3 *GAMEDAY
const.NEAR_PLAYER = 12

const.WANDERING_WISP_PERCENT = 0.8
const.FORESTS_WITH_WISPS = 7
const.FOREST_MIN_DENSITY = 200
const.FOREST_WISP_PERCENT = 0.02
const.REPLICATION_CHANCE = 0.2

-- UV lights / detectors parameters
const.UV_DMG = 16
const.UV_RANGE = 12
const.DTCT_RANGE = 16


return const
