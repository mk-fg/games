local zones = {}

local utils = require('libs/utils')

-- Refs to globals
local conf
local ChunkList, ChunkMap -- always up-to-date, existing chunks never removed
local ForestArea -- {chunk_key=area}
local ChunkSpreadQueue -- see control.lua for info on how sets are managed
local ChartLabels -- only set via debug commands
local Cache -- for stuff that can be easily reset to nil
-- Cache.spawn_chance - cached list of chunk-chances, discarded on ForestArea changes


-- Chunk table: { (cx, cy, surface) - where the chunk is
--   (scan_trees, scan_spread) - ticks when to scan for stuff
--   spread - used in update_* periodic routines, see comments below }

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
	return bit32.band(cx, 0x3ffffff) -- cx & (2**26-1)
		+ bit32.band(cy, 0x3ffffff) * 0x4000000 -- * 2**26
end

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
--  - Weighted random from ForestArea by pollution-level in get_wisp_trees_anywhere.
--
-- Chunk flags checked in periodics:
--  - "spread" - chunk is in ChunkSpreadQueue, no point re-adding it there.

function zones.update_wisp_spread(step, steps, rescan)
	local tick, out, count, k, chunk = game.tick, ChunkSpreadQueue, 0
	rescan = rescan and -1 or 1
	local tick_max_spread = tick - conf.chunk_rescan_spread_interval * rescan
	local tick_max_trees = tick - conf.chunk_rescan_tree_growth_interval * rescan
	for n = step, #ChunkList, steps do
		k = ChunkList[n]; chunk = ChunkMap[k]

		if chunk.spread or ForestArea[k] -- already in queue or spawn zone
				or (chunk.scan_spread or 0) > tick_max_spread -- too soon
			then goto skip end

		count = count + 1
		local pollution = chunk.surface.get_pollution{chunk.cx * cs, chunk.cy * cs}
		chunk.pollution = pollution
		chunk.scan_spread = tick + utils.pick_jitter(conf.chunk_rescan_jitter)
		if pollution <= 0 then goto skip end

		local m = out.n + 1
		chunk.spread, out.n, out[m] = true, m, k
	::skip:: end
	return count -- get_pollution count, probably lite
end

function zones.update_forests_in_spread(step, steps, rescan)
	local tick, set = game.tick, ChunkSpreadQueue
	local tick_min_spread = tick - conf.chunk_rescan_spread_interval * 3
	rescan = rescan and -1 or 1
	local tick_max_trees = tick - conf.chunk_rescan_tree_growth_interval * rescan
	local n, count, k, chunk, area, trees = step, 0
	if step > set.n and set.n > 0 then step = set.n end -- process at least one
	while n <= set.n do
		k = set[n]; chunk = ChunkMap[k]

		if not chunk -- should not happen normally, only on mod updates and such
				or (chunk.scan_spread or 0) < tick_min_spread -- too old spread info
				or (chunk.scan_trees or 0) > tick_max_trees -- too soon
			then goto drop end

		count = count + 1
		area = utils.get_area(forest_radius, chunk.cx*cs + cs/2, chunk.cy*cs + cs/2)
		trees = chunk.surface.find_entities_filtered{type='tree', area=area}
		chunk.scan_trees = tick + utils.pick_jitter(conf.chunk_rescan_jitter)

		if #trees >= conf.wisp_forest_min_density
			then ForestArea[k], Cache.spawn_chance = area end

		::drop::
		if chunk then chunk.spread = nil end
		set[n], set.n, set[set.n] = set[set.n], set.n - 1
		n = n + steps - 1 -- 1 was dropped
	end
	return count -- count of find_entities_filtered() calls
end


local function get_forest_spawn_chances(pollution_factor)
	if Cache.spawn_chance then return table.unpack(Cache.spawn_chance) end
	local chances, chance_sum, p_max, chunk, p = {}, 0, 0
	if not pollution_factor
		then pollution_factor = conf.wisp_forest_spawn_pollution_factor end
	for k, area in pairs(ForestArea) do
		chunk = ChunkMap[k]
		p = chunk and chunk.pollution or 0
		chances[k] = p
		if p > p_max then p_max = p end
	end
	if p_max > 0 then for k, chance in pairs(chances) do
		p = 1 + pollution_factor * chance / p_max
		chances[k], chance_sum = p, chance_sum + p
	end end
	Cache.spawn_chance = {chances, chance_sum}
	return chances, chance_sum
end

function zones.get_wisp_trees_anywhere(count, pollution_factor)
	-- Return up to N random trees from same
	--  pollution-weighted-random forest_radius area for spawning wisps around.
	local wisp_trees, n, chunk, area, trees = {}
	while next(ForestArea) do
		k = utils.pick_weight(get_forest_spawn_chances(pollution_factor))
		chunk, area = ChunkMap[k], ForestArea[k]
		trees = chunk and area
			and chunk.surface.find_entities_filtered{type='tree', area=area}
		if trees and #trees >= conf.wisp_forest_min_density then break end
		trees, ForestArea[k], Cache.spawn_chance = nil
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

function zones.find_industrial_pos(surface, pos, radius)
	-- Find center of the most polluted chunk in the vicinity of position.
	-- Done by checking chunks in straight/diagonal + player directions,
	--  while pollution value keeps increasing and until radius is reached,
	--  picking max of the resulting chunks.
	local directions, cx, cy, p = {{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}}
	for _, p in pairs(game.connected_players) do
		if not p.valid then goto skip end
		cx, cy = p.position.x - pos.x, p.position.y - pos.y
		p = math.max(math.abs(cx), math.abs(cy))
		table.insert(directions, {cx/p, cy/p})
	::skip:: end

	cx, cy, p = pos_chunk_xy(pos)
	pos, p = {}, surface.get_pollution{cx * cs, cy * cs}
	for n, dd in pairs(directions) do pos[n] = {cx, cy, p} end

	local p0 = true
	while p0 and radius >= 0 do
		radius, p0 = radius - 1
		for n, dd in pairs(directions) do
			cx, cy, p0 = table.unpack(pos[n])
			cx, cy = cx + dd[1], cy + dd[2]
			p = {cx * cs, cy * cs}
			p = surface.is_chunk_generated{cx, cy} and surface.get_pollution(p) or 0
			if p >= p0 then pos[n] = {cx, cy, p} else directions[n] = nil end
		end
	end

	p = {[3]=0}
	for _, dd in pairs(pos) do if dd[3] >= p[3] then p = dd end end
	cx, cy, p = table.unpack(p)
	return {x=(cx + 0.5) * cs, y=(cy + 0.5) * cs}
end


function zones.reset_chunk_area(surface, area)
	-- Adds or resets all stored info (scan ticks, pollution, etc)
	--  for chunk, identified by left-top corner of the area (assumed to be chunk area).
	replace_chunk(surface, area_chunk_xy(area))
end

function zones.refresh_chunks(surface)
	-- Forces re-scan of all existing chunks and adds any newly-revealed ones.
	-- Ideally should only be called on game/mod updates,
	--  in case these might change chunks or how they are handled.
	-- But in practice, get_chunks() always returns more chunks after
	--  game load than on_chunk_generated events do prior to save, no idea why.
	local chunks_found, chunks_diff, k, c = {}, 0

	for chunk in surface.get_chunks() do
		k = chunk_key(chunk.x, chunk.y)
		c = ChunkMap[k]
		if c then
			c.spread, c.scan_spread, c.scan_trees = nil -- rescan
		else
			chunks_diff = chunks_diff + 1
			replace_chunk(surface, chunk.x, chunk.y)
		end
		chunks_found[k] = true
	end
	if chunks_diff > 0
		then utils.log(' - Detected ChunkMap additions: %d', chunks_diff) end

	chunks_diff = 0
	for k,_ in pairs(ChunkMap) do if not chunks_found[k] then
		chunks_diff, ChunkMap[k], ForestArea[k] = chunks_diff + 1
	end end
	if chunks_diff > 0
		then utils.log(' - Detected ChunkMap removals: %d', chunks_diff) end

	for n, _ in pairs(ChunkList) do ChunkList[n] = nil end
	for k,_ in pairs(ChunkMap) do ChunkList[#ChunkList+1] = k end
	Cache.spawn_chance = nil
end

function zones.scan_new_chunks(surface)
	-- Check for any new chunks, ran "just in case",
	--  as not sure if events emitted for all new ones with various mods.
	local n = 0
	for chunk in surface.get_chunks() do
		if ChunkMap[chunk_key(chunk.x, chunk.y)] then goto skip end
		n = n + 1
		replace_chunk(surface, chunk.x, chunk.y)
	::skip:: end
	return n
end

function zones.init_globals(zs)
	for _, k in ipairs{'chunk_list', 'chunk_map', 'forest_area', 'cache'}
		do if not zs[k] then zs[k] = {} end end
	for _, k in ipairs{'chunk_spread_queue', 'chart_labels'}
		do if not zs[k] then zs[k] = {n=0} end end
end

function zones.init_refs(zs)
	conf = global.conf
	ChunkList, ChunkMap = zs.chunk_list, zs.chunk_map
	ChunkSpreadQueue, ForestArea = zs.chunk_spread_queue, zs.forest_area
	ChartLabels, Cache = zs.chart_labels, zs.cache
	utils.log(
		' - Zone stats: chunks=%d forests=%d spread-queue=%d labels=%d',
		#ChunkList, table_size(ForestArea), ChunkSpreadQueue.n, ChartLabels.n )
	if table_size(ChunkList) ~= #ChunkList
		then utils.log(' - WARNING: ChunkList has broken index!!!') end
end


------------------------------------------------------------
-- Various debug info routines
------------------------------------------------------------

function zones.full_update(rescan)
	-- Only for manual use from console, can take
	--  a second or few of real time if nothing was pre-scanned
	local n
	utils.log('zones: running full update (rescan=%s)', rescan and 1 or 0)
	n = zones.update_wisp_spread(1, 1, rescan)
	utils.log('zones:  - updated spread chunks: %d', n)
	n = zones.update_forests_in_spread(1, 1, rescan)
	utils.log('zones:  - scanned chunks for forests: %d', n)
	n = 0
	for k, _ in pairs(ForestArea) do n = n + 1 end
	utils.log( 'zones:  - done,'..
		' spread-queue=%d forests=%d', ChunkSpreadQueue.n, n )
end

function zones.print_stats(print_func)
	local fmt_bign = function(v) return utils.fmt_n_comma(v or '') end
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
			('zones:  - %s pollution: chunks=%s min=%s max=%s mean=%s sum=%s')
			:format( key, table.unpack(utils.map( fmt_bign,
				{#p_table, p_table[1], p_table[#p_table], p_mean, p_sum} )) ) )
		local fmt, fmt_vals = percentiles(p_table, {10, 25, 50, 75, 90, 95, 99})
		print_func(('zones:  - %s pollution: %s'):format(
			key, table.concat(fmt, ' ') ):format(table.unpack(fmt_vals)))
	end

	print_func('zones: stats')
	print_func(('zones:  - total: chunks=%s'):format(#ChunkList))
	pollution_table_stats('spread', ChunkList)
	local forest_chunks = {}
	for k, _ in pairs(ForestArea) do table.insert(forest_chunks, k) end
	pollution_table_stats('forest', forest_chunks)
end

function zones.forest_labels_add(surface, force, threshold)
	-- Adds map ("chart") labels for each forest on the map
	zones.forest_labels_remove(force)
	local set, chances, chance_sum, n = ChartLabels, get_forest_spawn_chances()
	for k, area in pairs(ForestArea) do
		label = {(area[1][1] + area[2][1])/2, (area[1][2] + area[2][2])/2}
		n = chances[k] / chance_sum
		if n < threshold then n = nil end
		label = {force_name=force.name, label=force.add_chart_tag(
			surface, { position=label,
				icon={type='item', name='raw-wood'},
				text=n and ('%.2f%%'):format(100 * n) } )}
		set[set.n+1], set.n = label, set.n+1
	end
end
function zones.forest_labels_remove(force)
	local set, n = ChartLabels, 1
	while n <= set.n do
		if force.name ~= set[n].force_name then goto skip end
		if set[n].label.valid then set[n].label.destroy() end
		n, set[n], set.n, set[set.n] = n-1, set[set.n], set.n-1
	::skip:: n = n + 1 end
end

return zones
