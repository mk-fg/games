local common = {}

local _DEBUG = true

if _DEBUG then
		require("libs/logger")
		--inspect = require('libs/inspect')
		DBG = Logger.new("Will-o-the-wisps", "Will-o-the-wisps", true, {log_ticks = true})
end

function common.log(msg)
		if _DEBUG then
				DBG.log(msg)
		end
		return msg
end

function common.echo(msg)
		game.print(msg)
end

local Nauvis
function common.getNauvis()
		if not Nauvis then
				Nauvis = game.surfaces.nauvis
		end
		return Nauvis
end

function common.getSafely(entity, key)
		local callResult, value =  pcall(function() return entity[key]; end)
		if callResult then
				return value
		end
		return nil
end

local function NtoZ(x, y)
		return (x >= 0 and (x * 2) or (-x * 2 - 1)), (y >= 0 and (y * 2) or (-y * 2 - 1))
end

function common.cantorPair(x, y)
		x,y = NtoZ(x, y)
		return (x + y +1)*(x + y)/2 + x
end

return common
