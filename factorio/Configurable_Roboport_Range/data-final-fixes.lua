local conf = require('config')
conf.update_from_settings()

local function round(num, dec_places)
	local mult = 10^(dec_places or 0)
	return math.floor(num * mult + 0.5) / mult
end

local function multiply_energy(e, m)
	local n, unit = string.match(e, '([%d%.]+)(%a+)')
	if n == nil then return '0MJ' end
	return ('%.1f%s'):format(n * m, unit)
end

-- Value multipliers
if conf.range_multiplier ~= 1.0 then
	for _, p in pairs(data.raw.roboport) do
		p.logistics_radius = round(p.logistics_radius * conf.range_multiplier)
		p.construction_radius = round(p.construction_radius * conf.range_multiplier)
	end
end

-- Static values
if conf.range_logistics >= 0
	then for _, p in pairs(data.raw.roboport)
		do p.logistics_radius = round(conf.range_logistics) end end
if conf.range_construction >= 0
	then for _, p in pairs(data.raw.roboport)
		do p.construction_radius = round(conf.range_construction) end end

-- Copy values
if conf.range_logistics == -2
	then for _, p in pairs(data.raw.roboport)
		do p.logistics_radius = p.construction_radius end end
if conf.range_construction == -2
	then for _, p in pairs(data.raw.roboport)
		do p.construction_radius = p.logistics_radius end end

-- Robot energy multiplier
if conf.robot_energy_multiplier ~= 1.0 then
	for _, p in pairs(data.raw['logistic-robot'])
		do p.max_energy = multiply_energy(
			p.max_energy, conf.robot_energy_multiplier ) end
	for _, p in pairs(data.raw['construction-robot'])
		do p.max_energy = multiply_energy(
			p.max_energy, conf.robot_energy_multiplier ) end
end
