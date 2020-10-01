local conf, suff = {}, {}

-- Options that have corresponding mod settings
-- "suff" changes mod setting name to reset its value for players
conf.spark_interval = 24 * 60 * 60
conf.spark_interval_jitter = 22 * 60 * 60

conf.check_interval = 3 * 60
conf.check_radius = 4 * 32
suff.check_radius = 2
conf.check_limit = 10

conf.check_sample_n = 5
conf.check_sample_offset = 12 * 32

conf.min_green_trees = 400
conf.max_dead_trees = 500
conf.green_dead_balance = 2
-- End of mods-settings-options
-- DONT FORGET TO UPDATE LOCALE AFTER CHANGING OPTION SUFFIX

local conf_settings_map, s = {}
for k, v in pairs(conf) do
	s = 'wf-'..k:gsub('_', '-')
	if suff[k] then s = s..'-v'..tostring(suff[k]) end
	conf_settings_map[s] = k
end
conf.sm, conf.ms = conf_settings_map, {}
for s, k in pairs(conf.sm) do conf.ms[k] = s end

function conf.s(props)
	local k = props.name
	props.name = conf.ms[k]
	props.default_value = conf[k]
	return props
end

function conf.update_from_settings()
	for s, k in pairs(conf.sm)
		do conf[k] = settings.startup[s].value end
end

return conf
