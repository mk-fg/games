local conf = {}

-- Multiplier for roboport radius values
conf.range_multiplier = 1.0

-- Special values: -1 - don't change, -2 - set to construction_radius
conf.range_logistics = -1

-- Special values: -1 - don't change, -2 - set to logistics_radius
conf.range_construction = -1

function conf.update_from_settings()
	conf.range_multiplier = settings.startup['range-multiplier'].value
	conf.range_logistics = settings.startup['range-logistics'].value
	conf.range_construction = settings.startup['range-construction'].value
end

return conf
