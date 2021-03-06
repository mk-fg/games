local conf = {}

-- Ticks between updating combinaror values.
-- 60 will mean 1/s on 1x speed.
conf.ticks_between_updates = 60

-- Ticks between running full-scan of the map for power-meter-combinator entities.
-- nil - disabled, should be unnecessary.
conf.ticks_between_rescan = nil

-- Radius in which to locate closest electric pole for connected grid stats.
conf.pole_radius = 16

-- Signal to emit for total kW of power produced since last update.
conf.sig_kw_total = 'virtual.signal-W'

-- Aggregate signal (sum) to emit for non-item
--  power-generating entities, which can't be used as signals themselves.
conf.sig_kw_other = 'virtual.signal-O'

-- Enable this for various utils.log() messages from code to
--  go to factorio logging (stdout by default) instead of nowhere.
-- conf.debug_log = true

function conf.update_from_settings()
	conf.ticks_between_updates = settings.startup['signal-update-interval'].value
end

return conf
