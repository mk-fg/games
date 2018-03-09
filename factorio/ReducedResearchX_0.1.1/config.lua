--config.lua

Mod_Name = "__ReducedResearchX__"

-- Formula for tech cost reduction (python3):
--   cost = lambda v: (a + max(0,v-a)*b**(v/(v+c)))
--   a,b,c=50,0.2,200
--   list(map(int, [cost(100),cost(200),cost(300),cost(500),cost(1000),cost(2000),cost(5000)]))
--   [100=79, 200=117, 300=145, 500=192, 1000=298, 2000=501, 5000=1103]
reduction_a = 50
reduction_b = 0.2
reduction_c = 200

-- Static divisor for time it takes to research a technology.
reduction_time = 0
