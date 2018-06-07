local zones = {}

local conf = require('config')
local utils = require('libs/utils')

local Chunks
local Forests

local function get_any_chunk()
	if not next(Chunks) then return end
	local currentTime = utils.game_seconds()
	for n = 1, conf.zones_attempts do
		local chunk = Chunks[math.random(#Chunks)]
		if chunk.ttu < currentTime then
			chunk.ttu = currentTime + conf.zones_chunk_update_interval
			return chunk
		end
	end
end

local function get_forest_in_area(area)
	local forest = game.surfaces.nauvis.find_entities_filtered{type='tree', area=area}
	if #forest > conf.forest_min_density then return forest end
end

local function get_random_forest()
	if not next(Forests) then return end
	local forest = Forests[math.random(#Forests)]
	if forest.ttu < utils.game_seconds() then table.remove(Forests, key) end
	return forest
end


function zones.find_new_forest()
	if #Forests >= conf.forest_count then return end
	local chunk = get_any_chunk()
	if not chunk then return end
	local forest = get_forest_in_area(chunk.area)
	if forest then
		local trees = {}
		for i = 1, math.floor(#forest * conf.forest_wisp_percent)
			do table.insert(trees, forest[math.random(#forest)]) end
		-- utils.log('Forest found: '..tostring(chunk.area.left_top.x)..':'..tostring(chunk.area.left_top.y))
		table.insert(Forests, { area=chunk.area,
			ttu=utils.game_seconds() + conf.zones_chunk_update_interval, target=trees })
	end
end

function zones.get_wisp_trees_anywhere()
	local forest = get_random_forest()
	if forest then return forest.target end
end

function zones.get_wisp_trees_near_players()
	local wisp_trees = {}
	for _, player in pairs(game.players) do
		if not (player.valid and player.connected) then goto skip end
		local forest = get_forest_in_area(
			utils.get_area(player.position, conf.zones_forest_distance) )
		if not forest then goto skip end
		for i = 1,  math.floor(#forest * conf.forest_wisp_percent)
			do table.insert(wisp_trees, forest[math.random(#forest)]) end
	::skip:: end
	return wisp_trees
end

local function zones.add_chunk(area)
	Chunks[#Chunks+1] = {area=area, ttu=-1}
end

function zones.refresh_chunks()
	for n = 1, #Chunks do Chunks[n] = nil end
	for chunk in game.surfaces.nauvis.get_chunks() do
		zones.add_chunk{
			left_top={chunk.x*32, chunk.y*32},
			right_bottom={(chunk.x+1)*32, (chunk.y+1)*32} }
	end
end

function zones.init(chunks, forests)
	utils.log('Init zones module...')
	Chunks = chunks
	Forests = forests
end

return zones
