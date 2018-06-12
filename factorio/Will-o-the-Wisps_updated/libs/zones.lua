local zones = {}

local conf = require('config')
local utils = require('libs/utils')

local ChunkList, ChunkMap -- always up-to-date, existing chunks never removed
local ChunkSpreadQueue, ForestSet


local cs = 32 -- chunk size, to name all "32" where it's that
local forest_radius = cs * 3 / 2 -- radius in which to look for forests, centered on chunk

local function area_chunk_xy(area)
	local left_top
	if area[1] then left_top = area[1] else left_top = area.left_top end
	return math.floor(left_top.x / cs), math.floor(left_top.y / cs)
end
local function pos_chunk_xy(pos)
	return math.floor(pos.x / cs), math.floor(pos.y / cs)
end

local function chunk_key(cx, cy)
	-- Returns 52-bit int key with chunk y in higher 26 bits, x in lower
	-- Not sure why math seem to break down when going for full 64-bit ints
	return bit32.band(cx, 67108863) -- cx & (2**26-1)
		+ bit32.band(cy, 67108863) * 67108864 end

local function replace_chunk(surface, cx, cy)
	local k = chunk_key(cx, cy)
	if not ChunkMap[k] then ChunkList[#ChunkList+1] = k end
	ChunkMap[k] = {cx=cx, cy=cy, surface=surface}
end


-- How wisps spawn on the map:
--
--  - Find and track all chunks via ChunkList/ChunkMap.
--    Done via refresh_chunks + reset_chunk in on_chunk_generated.
--
--  - Scan ChunkList & scan_spread for pollution values, add to ChunkSpreadQueue.
--    ChunkSpreadQueue is a queue of polluted areas where
--     wisps are most likely to appear, if there are any trees left.
--    Periodic update_wisp_spread task.
--
--  - Go through (check and remove) chunks in ChunkSpreadQueue & scan_trees,
--     scanning for tree count around these chunks' center.
--    As forests eat pollution, and their exact chunks might not show up there,
--     scanned areas are extended to cover some area around chunks as well.
--    Periodic update_forests_in_spread task.
--
--  - Weighted random from ForestSet by pollution-level in get_wisp_trees_anywhere.

function zones.update_wisp_spread(step, steps)
	local tick, out, k, chunk = game.tick, ChunkSpreadQueue
	local tick_max_spread = tick - conf.chunk_rescan_spread_interval
	local tick_max_trees = tick - conf.chunk_rescan_tree_growth_interval
	local count = 0
	for n = step, #ChunkList, steps do
		k, count = ChunkList[n], count + 1; chunk = ChunkMap[k]
		if chunk.spread
				or (chunk.scan_spread or 0) > tick_max_spread
			then goto skip end

		local pollution = chunk.surface.get_pollution{chunk.cx * cs, chunk.cy * cs}
		if pollution <= 0 then goto skip end
		chunk.pollution = pollution
		chunk.scan_spread = tick + utils.pick_jitter(conf.chunk_rescan_jitter)

		if not (
				chunk.spread or chunk.forest
				or (chunk.scan_trees or 0) > tick_max_trees ) then
			local m = out.n + 1
			chunk.spread, out.n, out[m] = true, m, k
		end
	::skip:: end
	return count -- get_pollution count, probably lite
end

function zones.update_forests_in_spread(step, steps)
	local tick, set, out = game.tick, ChunkSpreadQueue, ForestSet
	local tick_min_spread = tick - conf.chunk_rescan_spread_interval
	local tick_max_trees = tick - conf.chunk_rescan_tree_growth_interval
	local n, count, k, chunk, area, trees = step, 0
	if step > set.n and set.n > 0 then step = set.n end -- process at least one
	while n <= set.n do
		k, count = set[n], count + 1; chunk = ChunkMap[k]

		if not chunk then goto drop -- should not happen normally
		elseif chunk.scan_spread < tick_min_spread
			then chunk.spread = nil; goto drop -- old spread data
		elseif (chunk.scan_trees or 0) > tick_max_trees then goto drop end

		area = utils.get_area(forest_radius, chunk.cx*cs + cs/2, chunk.cy*cs + cs/2)
		trees = chunk.surface.find_entities_filtered{type='tree', area=area}
		chunk.scan_trees = tick + utils.pick_jitter(conf.chunk_rescan_jitter)

		if #trees >= conf.wisp_forest_min_density then
			local m = out.n + 1
			chunk.forest, out.n, out[m] = true, m, {area=area, chunk_key=k}
		end

		::drop:: set[n], set.n = set[set.n], set.n - 1
		n = n + steps - 1 -- 1 was dropped
	end
	return count -- find_entities_filtered count
end

function zones.full_update()
	-- Only for manual use from console, can take
	--  a second or few of real time if nothing was pre-scanned
	local n
	utils.log('zones: running full update')
	n = zones.update_wisp_spread(1, 1)
	utils.log('zones:  - updated spread chunks: %d', n)
	n = zones.update_forests_in_spread(1, 1)
	utils.log('zones:  - scanned chunks for forests: %d', n)
	utils.log(
		'zones:  - done, spread-queue=%d forests=%d',
		ChunkSpreadQueue.n, ForestSet.n )
end

function zones.print_stats(print_func)
	local fmt_bign = function(v) return utils.fmt_n_comma(v) end
	local function percentiles(t, perc)
		local fmt, fmt_vals = {}, {}
		for n = 1, #perc do
			table.insert(fmt, ('p%02d=%%s'):format(perc[n]))
			table.insert(fmt_vals, fmt_bign(t[math.floor((perc[n]/100) * #t)]))
		end
		return fmt, fmt_vals
	end

	local function pollution_table_stats(key, chunks)
		local p_table, p_sum, chunk = {}, 0
		for n = 1, #chunks do
			chunk = ChunkMap[chunks[n]]
			if not (chunk.pollution and chunk.pollution > 0) then goto skip end
			table.insert(p_table, chunk.pollution)
			p_sum = p_sum + chunk.pollution
		::skip:: end
		table.sort(p_table)
		local p_mean = p_sum / #p_table
		print_func(
			('zones:  - %s pollution chunks=%s min=%s max=%s mean=%s sum=%s')
			:format( key, table.unpack(utils.map( fmt_bign,
				{#p_table, p_table[1], p_table[#p_table], p_mean, p_sum} )) ) )
		local fmt, fmt_vals = percentiles(p_table, {10, 25, 50, 75, 90, 95, 99})
		print_func(('zones:  - %s pollution %s'):format(
			key, table.concat(fmt, ' ') ):format(table.unpack(fmt_vals)))
	end

	print_func('zones: stats')
	pollution_table_stats('spread', ChunkList)
	local forest_chunks = {}
	for n = 1, ForestSet.n
		do table.insert(forest_chunks, ForestSet[n].chunk_key) end
	pollution_table_stats('forest', forest_chunks)
end


function zones.get_wisp_trees_anywhere(count)
	-- Return up to N random trees from same
	--  pollution-weighted-random forest_radius area for spawning wisps around.
	local set, wisp_trees, trees = ForestSet, {}
	if set.n == 0 then return wisp_trees end
	while set.n > 0 do
		local chances, chunk, n = {}
		for n = 1, set.n do
			chunk = ChunkMap[set[n].chunk_key]
			chances[n] = chunk and chunk.pollution or 0
		end
		n = utils.pick_weight(chances)
		chunk = ChunkMap[set[n].chunk_key]
		trees = chunk.surface.find_entities_filtered{type='tree', area=set[n].area}
		if #trees >= conf.wisp_forest_min_density then break end
		trees, chunk.forest, set[n], set.n = nil, false, set[set.n], set.n - 1
	end
	if trees then for n = 1, count do
		table.insert(wisp_trees, trees[math.random(#trees)])
	end end
	return wisp_trees
end

function zones.get_wisp_trees_near_pos(surface, pos, radius)
	-- Return random trees around player in wisp_near_player_radius.
	-- Number of returned trees is math.floor(#trees-in-area * conf.wisp_near_player_percent).
	local wisp_trees = {}
	local trees = surface.find_entities_filtered{type='tree', area=utils.get_area(radius, pos)}
	for n = 1, math.floor(#trees * conf.wisp_near_player_percent)
		do wisp_trees[#wisp_trees+1] = trees[math.random(#trees)] end
	return wisp_trees
end


function zones.reset_chunk_area(surface, area)
	-- Adds or resets all stored info (scan ticks, pollution, etc)
	--  for chunk, identified by left-top corner of the area (assumed to be chunk area).
	replace_chunk(surface, area_chunk_xy(area))
end

function zones.refresh_chunks(surface)
	-- Forces re-scan of all existing chunks and adds any newly-revealed ones.
	-- Should only be called on game/mod updates,
	--  in case these might change chunks or how they are handled.
	local chunks_found, chunks_diff, k, c = {}, 0

	for chunk in surface.get_chunks() do
		k = chunk_key(chunk.x, chunk.y)
		c = ChunkMap[k]
		if c then c.scan_spread, c.scan_trees = nil else
			chunks_diff = chunks_diff + 1
			replace_chunk(surface, chunk.x, chunk.y)
		end
		chunks_found[k] = true
	end
	if chunks_diff > 0
		then utils.log(' - Detected ChunkMap additions: %d', chunks_diff) end

	chunks_diff = 0
	for k,_ in pairs(ChunkMap) do if not chunks_found[k]
		then chunks_diff, ChunkMap[k] = chunks_diff + 1, nil end end
	if chunks_diff > 0 then
		utils.log(' - Detected ChunkMap removals (mod bug?): %d', chunks_diff)
		for n = 1, #ChunkList do ChunkList[n] = nil end
		for k,_ in pairs(ChunkMap) do ChunkList[#ChunkList+1] = k end
	end
end

function zones.init(zs)
	for _, k in ipairs{'chunk_list', 'chunk_map'}
		do if not zs[k] then zs[k] = {} end end
	for _, k in ipairs{'chunk_spread_queue', 'forest_set'}
		do if not zs[k] then zs[k] = {n=0} end end
	ChunkList, ChunkMap = zs.chunk_list, zs.chunk_map
	ChunkSpreadQueue, ForestSet = zs.chunk_spread_queue, zs.forest_set
	utils.log(
		' - Zone stats: chunks=%d spread-queue=%d forests=%d',
		#ChunkList, ChunkSpreadQueue.n, ForestSet.n )
end

return zones
