local conf = {}

-- Configurable wire/network names for players that have these changed
--   in the game (e.g. via colorblind modes) or just don't like default names in lua env.
-- This changes descriptions in the guis as well.
conf.red_wire_name = 'red'
conf.green_wire_name = 'green'
function conf.get_wire_label(k) return conf[k..'_wire_name'] end

-- Interval between raising global alerts on lua errors, in ticks
conf.logic_alert_interval = 10 * 60

-- Thresholds for LED state indication
conf.led_sleep_min = 5 * 60 -- avoids flipping between sleep/run too often

-- Max number of old code snippets saved on each combinator
conf.code_history_limit = 200

-- entity.energy threshold when combinator shuts down
-- Full e-buffer of arithmetic combinator is 34.44, "red" level in UI is half of it
conf.energy_fail_level = 34.44 / 2
conf.energy_fail_delay = 2 * 60 -- when to re-check energy level

function conf.update_from_settings()
	local k_conf
	for _, k in ipairs{'red-wire-name', 'green-wire-name'} do
		k_conf = k:gsub('%-', '_')
		if conf[k_conf] == nil then error(('BUG - config key typo: %s'):format(k)) end
		conf[k_conf] = settings.startup[k].value
	end
end

return conf
