local targeting = {}
local consts = require("libs/consts")

local ATTEMPTS = consts.ATTEMPTS
local FOREST_MIN_DENSITY = consts.FOREST_MIN_DENSITY
local FORESTS_WITH_WISPS = consts.FORESTS_WITH_WISPS
local FOREST_WISP_PERCENT = consts.FOREST_WISP_PERCENT
local NEAR_PLAYER = consts.NEAR_PLAYER
local TTU = consts.TTU

local utils = require("libs/utils")
local getArea = utils.getArea
local getSec = utils.getSec
local echo = utils.echo

local commonUtils = require("libs/common")
local getNauvis = commonUtils.getNauvis
local log = commonUtils.log

local Chunks
local Forests
function targeting.init(chunks, forests)
		log("Init targeting module")
		Chunks = chunks
		Forests = forests
end

------------------------------------------------------------
-- Targeting
------------------------------------------------------------

local function getChunk()
		if next(Chunks) ~= nil then
				local currentTime = getSec()
				for i = 1, ATTEMPTS do
						local chunk = Chunks[math.random(#Chunks)]
						if chunk.TTU < currentTime then
								chunk.TTU = currentTime + TTU
								return chunk
						end
				end
		end
		return false
end

local function isForest(area)
		local forest = getNauvis().find_entities_filtered{type= "tree", area = area}
		if #forest > FOREST_MIN_DENSITY then
				return forest
		end
		return false
end

local function findForest(forests)
		if #Forests < FORESTS_WITH_WISPS then
				local chunk = getChunk()
				if chunk then
						local forest = isForest(chunk.area)
						if forest then
								local trees = {}
								for i = 1, math.floor(#forest * FOREST_WISP_PERCENT) do
										table.insert(trees, forest[math.random(#forest)])
								end
								log("Forest found: "..tostring(chunk.area.left_top.x)..":"..tostring(chunk.area.left_top.y))
								table.insert(Forests, {area = chunk.area, TTU = getSec() + TTU, target = trees})
						end
				end
		end
end

function targeting.prepareTarget(chunks, forests)
		findForest()
end

local function getForest()
		if next(Forests) ~= nil then
				local forest = Forests[math.random(#Forests)]
				-- if data expired
				if forest.TTU < getSec() then
						table.remove(Forests, key)
				end
				return forest
		end
		return false
end

function targeting.getTreesEverywhere()
		local forest = getForest()
		if forest then
				return forest.target
		end
		return false
end

function targeting.getTreesNearPlayers()
		local treesWithWisps = {}
		for _, player in pairs(game.players) do
			if player.valid and player.connected then
						local forest = isForest(getArea(player.position, NEAR_PLAYER))
						if forest then
								for i = 1,  math.floor(#forest * FOREST_WISP_PERCENT) do
										table.insert(treesWithWisps, forest[math.random(#forest)])
								end
						end
				end
		end
		return treesWithWisps
end

return targeting
