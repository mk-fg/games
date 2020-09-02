local conf = {}

-- Multiplier for roboport radius values
conf.range_multiplier = 1.0

-- Special values: -1 - don't change, -2 - set to construction_radius
conf.range_logistics = -1

-- Special values: -1 - don't change, -2 - set to logistics_radius
conf.range_construction = -1

-- If range is less than this value, skip it as a "recharge station" and such non-roboports.
conf.range_min_to_affect = 5

-- Multiplier for logistic/construction robot max_energy values
conf.robot_energy_multiplier = 1.0

-- Whether mod will patch all roboports/robots in their category (if true) or just vanilla ones (if false)
conf.affect_mod_entities = true

function conf.update_from_settings()
	local k_conf
	for _, k in ipairs{
			'range-multiplier', 'range-logistics', 'range-construction',
			'range-min-to-affect', 'robot-energy-multiplier', 'affect-mod-entities' } do
		k_conf = k:gsub('%-', '_')
		if conf[k_conf] == nil then error(('BUG - config key typo: %s'):format(k)) end
		conf[k_conf] = settings.startup[k].value
	end
end

return conf
