-- See doc/research-cost-chart.html for easy reduction representation

-- Formula for tech cost reduction (python3):
--   cost = lambda v: (a + max(0,v-a)*b**(v/(v+c)))
--   a,b,c=50,0.2,200
--   list(map(int, [cost(100),cost(200),cost(300),cost(500),cost(1000),cost(2000),cost(5000)]))
--   [100=79, 200=117, 300=145, 500=192, 1000=298, 2000=501, 5000=1103]
reduction_a = 50 -- reduction only applies to cost part that's above this amount
reduction_b = 0.2
reduction_c = 200

-- Static divisor for time it takes to research a technology.
reduction_time = 0


for _, tech in pairs(data.raw.technology) do

	local cost = tech.unit.count
	if cost ~= nil then
		tech.unit.count = math.ceil(
			math.min(cost, reduction_a)
			+ math.max(0, cost - reduction_a)
				* reduction_b ^ (cost / (cost + reduction_c)) )
	end

	local time = tech.unit.time
	if time ~= nil and reduction_time ~= 0 then
		tech.unit.time = math.ceil(time / reduction_time)
	end

end
