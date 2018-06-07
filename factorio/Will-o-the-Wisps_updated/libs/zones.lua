local zones = {}

local conf = require('config')
local utils = require('libs/utils')

local ChunkList, ChunkMap
local ChunkSetWispy, ForestSetWispy


-- Where to spawn wisps outside of player proximity:
--
--  - Find and track all chunks via ChunkList/ChunkMap.
--
--  - Scan ChunkList & scan_tick for pollution values, add to ChunkSetWispy.
--    These will be polluted areas where wisps
--     wisps are most likely to appear, if there are any trees left.
--
--  - Scan ChunkSetWispy for tree count, setting "scan_tick" and populating ForestSetWispy.
--    As forests eat pollution, and their exact chunks might not show up there,
--     scanned areas are extended to cover neighboring chunks as well.
--
--  - Weighted random from ForestSetWispy by pollution-level.

-- Where to spawn wisps in player proximity:
--
--  - Find trees in wisp_near_player_radius around each player.
--  - Return count * wisp_near_player_percent random ones from each per-player list.


local cs = 32 -- chunk size, to name all "32" where it's that
local forest_radius = cs * 3 / 2 -- radius in which to look for forests, centered on chunk


local function chunk_xy(area)
	local left_top
	if area[1] then left_top = area[1] else left_top = area.left_top end
	return math.floor(left_top.x / cs), math.floor(left_top.y / cs)
end

local function chunk_key(x, y)
	-- Returns 64-bit int key with chunk y in higher 32 bits, x in lower
	return bit32.bor(
		bit32.band(math.floor(x / cs), 4294967295),
		bit32.arshift(bit32.band(math.floor(y / cs), 4294967295), 32) ) end

local function replace_chunk(surface, cx, cy)
	local k = chunk_key(cx, cy)
	if not ChunkMap[k] then ChunkList[#ChunkList+1] = k end
	ChunkMap[k] = {cx=cx, cy=cy, surface=surface}
end


local function update_wisp_spread(step, steps)
	local tick = game.tick
	local scan_tick_max = tick - conf.chunk_rescan_interval

	for n = step, #ChunkList, steps do
		local chunk = ChunkMap[ChunkList[n]]
		if chunk.scan_tick > scan_tick_max then goto skip end

		local pollution = chunk.surface.get_pollution{chunk.cx, chunk.cy}
		if pollution <= 0 then goto skip end

		if not chunk.scan_tick then
			local m = ChunkSetWispy.n + 1
			ChunkSetWispy.n, ChunkSetWispy[m] = m, k
		end
		chunk.pollution, chunk.scan_tick = pollution, tick
	::skip:: end
end

local function find_forests_in_spread(step, steps)
	local tick = game.tick
	local scan_tick_max = tick - conf.chunk_rescan_interval

	local set, n, k, chunk = ChunkSetWispy, step
	while n <= set.n do
		k = set[n]; chunk = ChunkMap[k]
		if not chunk then goto skip end -- can only happen on refresh
		if chunk.scan_tick > scan_tick_max then
			set[n], set.n = set[set.n], set.n - 1
			goto skip
		end

		local forest_area = utils.get_area(
			forest_radius, chunk.cx + cs/2, chunk.cy + cs/2 )
		local forest_trees = chunk.surface.find_entities_filtered{type='tree', area=forest_area}
		if #forest_trees < conf.forest_min_density then
			-- Forget about this chunk until next rescan via scan_tick
			-- Not permanently due to possibility of tree-growing mods
			set[n], set.n = set[set.n], set.n - 1
			goto skip
		end
		local m = ForestSetWispy.n + 1
		ForestSetWispy.n, ForestSetWispy[m] = m, {area=forest_area, chunk_key=k}
		n = n + steps
	::skip:: end
	return math.floor((n - step) / steps) -- count
end


function zones.get_wisp_trees_anywhere(count)
	-- Return up to N random trees from same
	--  pollution-weighted-random forest_radius area for spawning wisps around.
	local set, wisp_trees = ForestSetWispy, {}
	if set.n == 0 then return wisp_trees end
	while set.n > 0 do
		local chances = {}
		for n = 1, set.n do
			local chunk = ChunkMap[set[n].chunk_key]
			chances[#chances+1] = chunk and chunk.pollution or 0
		end
		local trees = chunk.surface.find_entities_filtered{
			type='tree', area=set[utils.pick_weight(chances)].area }
		if next(trees) then break end
		set[n], set.n = set[set.n], set.n - 1 -- remove destroyed forest, repeat
	end
	if trees then for n = 1, count do
		table.insert(wisp_trees, trees[math.random(trees)])
	end end
	return wisp_trees
end

function zones.get_wisp_trees_near_pos(surface, pos, radius)
	-- Return random trees around player in wisp_near_player_radius.
	-- Number of returned trees is math.floor(#trees-in-area * conf.forest_wisp_percent).
	local wisp_trees = {}
	local trees = surface.find_entities_filtered{type='tree', area=utils.get_area(radius, pos)}
	for n = 1, math.floor(#trees * conf.wisp_near_player_percent)
		do wisp_trees[#wisp_trees+1] = trees[math.random(#trees)] end
	return wisp_trees
end


function zones.on_nth_tick(surface)
	-- XXX: run scan and all that
end

function zones.reset_chunk(surface, area)
	-- Adds or resets all stored info (scan_tick, pollution, etc)
	--  for chunk, identified by left-top corner of the area (assumed to be chunk area).
	replace_chunk(surface, chunk_xy(area))
end

function zones.refresh_chunks(surface)
	-- Forces re-scan of all existing chunks and adds any newly-revealed ones.
	-- Should only be called on game/mod updates,
	--  in case these might change chunks or how they are handled.
	for n = 1, #ChunkList do ChunkList[n] = nil end
	for n = 1, #ChunkMap do ChunkMap[n] = nil end
	for chunk in surface.get_chunks()
		do replace_chunk(surface, chunk.x, chunk.y) end
end

function zones.init(zs)
	for _, k in ipairs{'chunk_list', 'chunk_map'}
		do if not zs[k] then zs[k] = {} end end
	for _, k in ipairs{'wispy_chunk_set', 'wispy_forest_set'}
		do if not zs[k] then zs[k] = {n=0} end end
	ChunkList, ChunkMap = zs.chunk_list, zs.chunk_map
	ChunkSetWispy, ForestSetWispy = zs.wispy_chunk_set, zs.wispy_forest_set
	utils.log(
		' - Zone stats: chunks=%d wispy-chunks=%d wispy-forests=%d',
		#ChunkList, ChunkSetWispy.n, ForestSetWispy.n )
end

return zones
