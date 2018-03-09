require("config")

local technologies = data.raw["technology"]

for _, tech in pairs(technologies) do

	local cost = tech.unit.count
	if cost ~= nil then
		tech.unit.count = math.ceil(
			reduction_a + math.max(0, cost - reduction_a)
				* reduction_b ^ (cost / (cost + reduction_c)) )
	end

	local time = tech.unit.time
	if time ~= nil and reduction_time ~= 0 then
		tech.unit.time = math.ceil(time / reduction_time)
	end

end
