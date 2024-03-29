local conf = {}

-- Ticks between updating *some* combinaror values. 60 will mean 1/s on 1x speed.
-- Note that this value is effectively should be multiplied.
--  by ticks_update_steps below for the actual time between *all* combinaror values.
conf.ticks_between_updates = 12

-- How many steps to split each update workload into.
-- This is a multiplier for "ticks_between_updates" value.
conf.ticks_update_steps = 10

-- Ticks between running full-scan of the map for sentinel-combinator entities.
-- nil - disabled, should be unnecessary.
conf.ticks_between_rescan = nil

-- Radius in which to locate closest radar (tiles).
conf.radar_radius = 8

-- Radius in which to scan for biters by default (tiles).
conf.default_scan_range = 32
conf.max_scan_range = 32 * 32

-- Whether to use slower "find_entities" scan to detect spawners and worms.
conf.scan_other = false

-- Signal to emit for total number of biters.
conf.sig_biter_total = 'virtual.signal-bds-total'
-- Signal to emit for other force=enemy entities.
conf.sig_biter_other = 'virtual.signal-bds-other'

-- Signal to handle as range setting.
conf.sig_range = 'virtual.signal-R'
-- Signal to test alarms.
conf.sig_alarm_test = 'virtual.signal-T'

-- Enable this for various utils.log() messages from code to
--  go to factorio logging (stdout by default) instead of nowhere.
-- conf.debug_log = true

function conf.update_from_settings()
	conf.ticks_between_updates = settings.startup['bds-signal-update-interval'].value
	conf.ticks_update_steps = settings.startup['bds-signal-update-steps'].value
	for _, k in ipairs{'default-scan-range', 'max-scan-range', 'scan-other'}
		do conf[k:gsub('-', '_')] = settings.startup['bds-'..k].value end
end

return conf
