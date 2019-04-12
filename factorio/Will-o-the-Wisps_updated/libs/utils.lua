local utils = {}

local conf = require('config')


function utils.fmt(msg, ...)
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
	if type(msg) ~= 'string'
		then msg = serpent.block(msg, {comment=false, nocode=true, sparse=true}) end
	return msg
end

function utils.fmt_n_comma(n, digits)
	if type(n) == 'number' then n = ('%.'..tostring(digits or 0)..'f'):format(n) end
	local res, k = n, 1
	while k ~= 0 do res, k = string.gsub(res, '^(-?%d+)(%d%d%d)', '%1,%2') end
	return res
end

function utils.fmt_ticks(ticks)
	if not ticks then return '--:--:--.--' end
	local ts, unit = {3600*60,  60*60, 60, 1}
	for n = 1, #ts do
		unit, ts[n] = ts[n], math.floor(ticks / ts[n])
		ticks = ticks - ts[n] * unit
	end
	ts[1] = ts[1] % 100 -- not actual daytime hours anyway
	return ('%02d:%02d:%02d.%02d'):format(table.unpack(ts))
end

function utils.log(msg, ...)
	if not conf.debug_log then return end
	local log_func = conf.debug_log_direct and print or log
	log_func(utils.fmt_ticks(game and game.tick)..' :: '..utils.fmt(msg, ...))
end

function utils.error(msg, ...) error(utils.fmt(msg, ...)) end


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


function utils.pick_weight(chances, sum)
	-- Returns key for randomly-picked weight value from table
	-- E.g. pick_weight{a=0.3, b=0.7} will return 'b' with 70% chance
	if not sum then
		sum = 0
		for _,v in pairs(chances) do sum = sum + v end
	end
	local dice, sum = math.random() * sum, 0
	for k,v in pairs(chances) do
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


function utils.match_word(s, word)
	-- Returns non-nil if s ~ /\bword\b/ (pcre)
	return s:match('^'..word..'$')
		or s:match('^'..word..'[%W]')
		or s:match('[%W]'..word..'$')
		or s:match('[%W]'..word..'[%W]')
end

function utils.map(t, func)
	if type(t) ~= 'table' then t, func = func, t end
	if not func then return t
	elseif type(func) ~= 'function' then
		local key = func
		func = function(v) return v[key] end
	end
	local res = {}
	for n = 1, #t do table.insert(res, func(t[n], n)) end
	return res
end

function utils.tc(opts)
	-- Copy table, applying any specified updates (tables/keys) to it.
	-- Usage: tc{table, update1, update2, ..., k1=v1, k2=v2, ...}
	local t, n = {}, 1
	while true do
		if opts[n] then
			for k,v in pairs(opts[n]) do t[k] = v end
			opts[n], n = nil, n + 1
		else break end
	end
	for k,v in pairs(opts) do t[k] = v end
	return t
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

function utils.get_distance(pos1, pos2)
	return ((pos1.x - pos2.x)^2 + (pos1.y - pos2.y)^2)^0.5
end

return utils
