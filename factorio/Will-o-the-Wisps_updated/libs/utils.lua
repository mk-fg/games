local utils = {}

local conf = require('config')


local debug_logger
if conf.debug_log then
	require('libs/logger')
	debug_logger = Logger.new(
		'Will-o-the-wisps_updated', 'debug', true, {log_ticks=true} )
end

function utils.f(msg, ...)
	-- Format message using string.format if extra args are passed
	-- Non-string arguments are formatted via serpent.line
	local args, fmt_args = table.pack(...), {}
	if #args > 0 then
		for n = 1,args.n do
			local v = args[n]
			if type(v) == 'table' -- lua is especially unhelpful with these
				then v = serpent.line(v, {nocode=true, sparse=true}) end
			fmt_args[n] = v
		end
		local done, res = pcall(string.format, msg, table.unpack(fmt_args))
		if not done then -- try padding fmt_args with "nil" until it works
			local res0 = res
			for n = 1,math.floor((#msg-#fmt_args*2)/2) do
				if done then goto fixed end
				if not res:match('%(no value%)') then break end
				table.insert(fmt_args, 'nil')
				done, res = pcall(string.format, msg, table.unpack(fmt_args))
			end
			error(res0) ::fixed::
		end
		msg = res
	end
	return msg
end

function utils.log(msg, ...) if debug_logger then debug_logger.log(utils.f(msg, ...)) end end
function utils.error(msg, ...) error(utils.f(msg, ...)) end


function utils.version_to_num(ver, padding)
	local ver_nums = {}
	ver:gsub('(%d+)', function(v) ver_nums[#ver_nums+1] = tonumber(v) end)
	ver = 0
	for n,v in pairs(ver_nums)
		do ver = ver + v * math.pow(10, ((#ver_nums-n)*(padding or 3))) end
	return ver
end
function utils.version_less_than(v1, v2)
	if utils.version_to_num(v1) < utils.version_to_num(v2) then
		utils.log('  - Update from pre-'..v2)
		return true
	end
	return false
end


function utils.pick_weight(...)
	-- Returns key for randomly-picked weight value from args/table
	-- E.g. pick_weight{a=0.3, b=0.7} will return 'b' with 70% chance
	local args, sum, dice = {...}, 0, math.random()
	if #args == 1 and type(args[1]) == 'table' then args = args[1] end
	for _,v in pairs(args) do sum = sum + v end
	dice, sum = dice * sum, 0
	for k,v in pairs(args) do
		sum = sum + v
		if dice <= sum then return k end
	end
end

function utils.pick_chance(...)
	-- Returns key for randomly-picked chance value from args/table or nil
	-- All values are summed-up to [0,1] chance of returning non-nil
	-- pick_chance(0.3, 0.2) will return nil 50% of the times, 1 - 30%, 2 - 20%
	local args, sum = {...}, 0
	if #args == 1 and type(args[1]) == 'table' then args = args[1] end
	for _,v in pairs(args) do sum = sum + v end
	args['__none'] = math.max(0, 1 - sum)
	local res = utils.pick_weight(args)
	if res == '__none' then res = nil end
	return res
end

function utils.pick_jitter(limit, positive)
	return math.random(positive and -limit or 0, limit)
end


function utils.t(s, value)
	-- Helper to make padded table from other table keys or a string of keys
	local t = {}
	if not value then value = true end
	if type(s) == 'table' then for k,_ in pairs(s) do t[k] = value end
	else s:gsub('(%S+)', function(k) t[k] = value end) end
	return t
end

function utils.get_area(radius, x, y)
	if not y then x, y = x.x, x.y end
	return {{x - radius, y - radius}, {x + radius, y + radius}}
end

return utils
