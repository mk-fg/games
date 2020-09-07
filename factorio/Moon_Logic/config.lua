local conf = {}

-- Configurable wire/network names for players that have these changed
--   in the game (e.g. via colorblind modes) or just don't like default names in lua env.
-- This changes descriptions in the guis as well.
conf.red_wire_name = 'red'
conf.green_wire_name = 'green'
function conf.get_wire_label(k) return conf[k..'_wire_name'] end

-- Interval between updating signal table in the main GUI
conf.gui_signals_update_interval = 1

-- Interval between raising global alerts on lua errors, in ticks
conf.logic_alert_interval = 10 * 60

-- Thresholds for LED state indication
conf.led_sleep_min = 5 * 60 -- avoids flipping between sleep/run too often

-- Max number of old code snippets saved on each combinator
conf.code_history_enabled = true
conf.code_history_limit = 200
conf.code_tooltip_lines = 30 -- to avoid tooltip on preset button getting too long

-- entity.energy threshold when combinator shuts down
-- Full e-buffer of arithmetic combinator is 34.44, "red" level in UI is half of it
conf.energy_fail_level = 34.44 / 2
conf.energy_fail_delay = 2 * 60 -- when to re-check energy level

-- Size of lua environment window
conf.gui_vars_line_px = 500
conf.gui_vars_line_len_max = 80
conf.gui_vars_serpent_opts = {metatostring=true, nocode=true}


function conf.update_from_settings()
	local k_conf
	for _, k in ipairs{
			'red-wire-name', 'green-wire-name',
			'gui-signals-update-interval' } do
		k_conf = k:gsub('%-', '_')
		if conf[k_conf] == nil then error(('BUG - config key typo: %s'):format(k)) end
		conf[k_conf] = settings.startup[k].value
	end
	conf.code_history_enabled = settings.startup['gui-textbox-edit-history'].value
end

return conf
