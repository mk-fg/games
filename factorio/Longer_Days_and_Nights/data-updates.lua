local conf = require('config')
conf.multiplier = settings.startup['day-night-multiplier'].value
conf.adjust_accumulators = settings.startup['adjust-accumulator-capacity'].value

local function multiply_bc(bc)
	local n, unit = string.match(bc, '([%d%.]+)(%a+)')
	if n == nil then return '0MJ' end
	return ('%d%s'):format(n * conf.multiplier, unit)
end

if conf.adjust_accumulators then
	for _, e in pairs(data.raw.accumulator) do
		if not (e.energy_source and e.energy_source.buffer_capacity) then return end
		e.energy_source.buffer_capacity = multiply_bc(e.energy_source.buffer_capacity)
	end
end
