local targeting = {}

local conf = require('config')
local utils = require('libs/utils')

local Chunks
local Forests

function targeting.init(chunks, forests)
	utils.log('Init targeting module...')
	Chunks = chunks
	Forests = forests
end

------------------------------------------------------------
-- Targeting
------------------------------------------------------------

local function getChunk()
	if next(Chunks) ~= nil then
		local currentTime = utils.game_seconds()
		for i = 1, conf.targeting_attempts do
			local chunk = Chunks[math.random(#Chunks)]
			if chunk.ttu < currentTime then
				chunk.ttu = currentTime + conf.targeting_chunk_update_interval
				return chunk
			end
		end
	end
	return false
end

local function isForest(area)
	local forest = game.surfaces.nauvis.find_entities_filtered{type= 'tree', area = area}
	if #forest > conf.forest_min_density then return forest end
	return false
end

local function findForest(forests)
	if #Forests < conf.forest_count_with_wisps then
		local chunk = getChunk()
		if chunk then
			local forest = isForest(chunk.area)
			if forest then
				local trees = {}
				for i = 1, math.floor(#forest * conf.forest_wisp_percent) do
					table.insert(trees, forest[math.random(#forest)])
				end
				utils.log('Forest found: '..tostring(chunk.area.left_top.x)..':'..tostring(chunk.area.left_top.y))
				table.insert(Forests, { area=chunk.area,
					ttu=utils.game_seconds() + conf.targeting_chunk_update_interval, target=trees })
			end
		end
	end
end

function targeting.prepareTarget(chunks, forests) findForest() end

local function getForest()
	if next(Forests) ~= nil then
		local forest = Forests[math.random(#Forests)]
		-- if data expired
		if forest.ttu < utils.game_seconds() then table.remove(Forests, key) end
		return forest
	end
	return false
end

function targeting.getTreesEverywhere()
	local forest = getForest()
	if forest then return forest.target end
	return false
end

function targeting.getTreesNearPlayers()
	local treesWithWisps = {}
	for _, player in pairs(game.players) do
		if player.valid and player.connected then
			local forest = isForest(utils.get_area(player.position, conf.targeting_forest_distance))
			if forest then
				for i = 1,  math.floor(#forest * conf.forest_wisp_percent) do
					table.insert(treesWithWisps, forest[math.random(#forest)])
				end
			end
		end
	end
	return treesWithWisps
end

return targeting
