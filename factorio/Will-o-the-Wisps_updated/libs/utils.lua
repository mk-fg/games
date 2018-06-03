local utils = {}

local conf = require('config')


local debug_logger
if conf.debug_log then
	require('libs/logger')
	debug_logger = Logger.new(
		'Will-o-the-wisps_updated', 'debug', true, {log_ticks=true} )
end

function utils.log(msg, ...)
	if debug_logger then
		local args, fmt_args = table.pack(...), {}
		if #args > 0 then
			for n,v in pairs(args) do
				if type(v) ~= 'string' then v = serpent.line(v, {nocode=true, sparse=true}) end
				fmt_args[n] = v
			end
			debug_logger.log(string.format(msg, table.unpack(fmt_args)))
		else debug_logger.log(msg) end
	end
	return msg
end


function utils.t(v)
	-- Helper to make lookup table from string of keys
	if type(v) == 'table' then return v end
	local t = {}
	v:gsub('(%S+)', function(k) t[k] = true end)
	return t
end


function utils.game_seconds()
	return game.tick / 60 --SEC
end

function utils.check_chance(chance)
	return math.random() < chance
end

function utils.get_area(position, radius)
	return {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}}
end

function utils.get_deviation(value, deviation)
	return value + math.random(-deviation, deviation)
end

function utils.getSafely(entity, key)
	local callResult, value =  pcall(function() return entity[key]; end)
	if callResult then return value end
	return nil
end

local function NtoZ(x, y)
	return (x >= 0 and (x * 2) or (-x * 2 - 1)), (y >= 0 and (y * 2) or (-y * 2 - 1))
end
function utils.cantorPair(x, y)
	x,y = NtoZ(x, y)
	return (x + y +1)*(x + y)/2 + x
end


return utils
