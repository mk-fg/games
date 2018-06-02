local config = {}
local SEC = 60
local MIN = 3600

-- Minimal darkness value when the wisps appearing (0; 1)
config.MIN_DARKNESS = 0.05

-- Max number of wisps on the map
config.MAX_WISPS_COUNT = 1250

-- Damage parameters for the purple wisps
config.CORROSION_DMG = 1
config.CORROSION_AREA = 2

-- Disable glow of the purple wisps to increase performance (set to false)
config.PURPLE_WISPS_EMIT_LIGHT = true

-- These values affect on number of the wisps which spontaneously rise from forests [0; 1]
-- (Default: purple - 90% / yellow - 5% / red - 0.1%)
config.PURPLE_SPAWN_CHANCE = 0.9
---- this chance applied only if Purple was not spawned
config.YELLOW_SPAWN_CHANCE = 0.5
---- this chance applied only if Purple and Yellow were not spawned
config.RED_SPAWN_CHANCE = 0.02

----------------------------------------------------------
-- options for modifications with long night
----------------------------------------------------------
-- Override the day/night cycle for mods with long night:
---- the wisps will be active for ETERNAL_NIGHT: 3 minutes
---- every FAKE_DAY_MULT * ETERNAL_NIGHT: 9 minutes
---- (i.e. 3 min of nigth and 9 min of fake day by default)
config.FAKE_DAY_MODE = true
config.ETERNAL_NIGHT = 3 *MIN
config.FAKE_DAY_MULT = 3

---- Skip the agreesive state of the wisps after every 12 minutes of night
---- Default val.: 12 = (FAKE_DAY_MULT + 1) * ETERNAL_NIGHT
---- (this works even if FAKE_DAY_MODE = false)
config.SKIP_AGRESSION_AT_NIGHT = true

return config
