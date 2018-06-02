local utils = {}

local config = require("config")
local MIN_DARKNESS = config.MIN_DARKNESS

function utils.getSec()
		return game.tick / 60 --SEC
end

function utils.checkChance(chance)
		return math.random() < chance
end
function utils.isDark()
		return game.surfaces.nauvis.darkness > MIN_DARKNESS
end
function utils.isCold()
		return utils.checkChance(1 - MIN_DARKNESS*2)
end
function utils.isFullOfTerrors()
		return utils.isDark() and utils.checkChance(game.surfaces.nauvis.darkness - MIN_DARKNESS*8)
end

function utils.getArea(position, radius)
		return {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}}
end

local function round(x)
	if x % 2 ~= 0.5 then
		return math.floor(x + 0.5)
	end
		return x - 0.5
end

function utils.getDeviation(value, deviation)
		return value + math.random(-deviation, deviation)
end

return utils
