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


local function get_entities(t)
	local entities = {}
	for _, e in pairs(data.raw[t]) do
		if not conf.affect_mod_entities
			and e.name ~= t then goto skip end
		table.insert(entities, e)
	::skip:: end
	return entities
end

local roboports = get_entities('roboport')
local robots_logistic = get_entities('logistic-robot')
local robots_cons = get_entities('construction-robot')


-- Value multipliers
if conf.range_multiplier ~= 1.0 then
	for _, p in pairs(roboports) do
		if p.logistics_radius >= conf.range_min_to_affect
			then p.logistics_radius = round(p.logistics_radius * conf.range_multiplier) end
		if p.construction_radius >= conf.range_min_to_affect
			then p.construction_radius = round(p.construction_radius * conf.range_multiplier) end
	end
end

-- Static values
if conf.range_logistics >= 0 then
	for _, p in pairs(roboports) do
		if p.logistics_radius >= conf.range_min_to_affect then
			p.logistics_radius = round(conf.range_logistics)
end end end
if conf.range_construction >= 0 then
	for _, p in pairs(roboports) do
		if p.construction_radius >= conf.range_min_to_affect then
			p.construction_radius = round(conf.range_construction)
end end end

-- Copy values
if conf.range_logistics == -2 then
	for _, p in pairs(roboports) do
		if p.logistics_radius >= conf.range_min_to_affect then
			p.logistics_radius = p.construction_radius
end end end
if conf.range_construction == -2 then
	for _, p in pairs(roboports) do
		if p.construction_radius >= conf.range_min_to_affect then
			p.construction_radius = p.logistics_radius
end end end

-- Robot energy multiplier
if conf.robot_energy_multiplier ~= 1.0 then
	for _, p in pairs(robots_logistic)
		do p.max_energy = multiply_energy(
			p.max_energy, conf.robot_energy_multiplier ) end
	for _, p in pairs(robots_cons)
		do p.max_energy = multiply_energy(
			p.max_energy, conf.robot_energy_multiplier ) end
end
