local env -- set to _G from console after init(load)


-- ----- Local helpers

local function strim(s) return s:match('^%s*(.-)%s*$') end

local function fmt(msg, ...)
	-- Format message using string.format if extra args are passed
	-- Non-string arguments are formatted via serpent.line
	local args, fmt_args = table.pack(...), {}
	if #args > 0 then
		for n = 1,args.n do
			local v = args[n]
			if type(v) == 'table' -- lua is especially unhelpful with these
				then v = tostring(v) end -- XXX: oneline-fomat
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
		then msg = tostring(msg) end --- XXX: block-format
	return msg
end

local function fmt_n_comma(n, digits)
	if type(n) == 'number' then n = ('%.'..tostring(digits or 0)..'f'):format(n) end
	local res, k = n, 1
	while k ~= 0 do res, k = string.gsub(res, '^(-?%d+)(%d%d%d)', '%1,%2') end
	return res
end

-- try + trace_stack from Lua Console by special_snowcat

local trace_stack = function(sidx)
	sidx = sidx or 2
	local idx, trace = sidx, ''
	local mod_src = env.debug.getinfo(function() end).source
	while true do
		local info = env.debug.getinfo(idx)
		if not info then break end
		local txt = ""
		if info.name then txt = info.name .. "()" end
		if info.source == mod_src then break
		elseif info.short_src:match('^.string "') then
			if txt ~= "" then txt = txt .. "@" end
			if info.source == "<console input>" then
				if idx == 2 then trace = nil; return x end
				txt = ""
			end
			txt = txt .. info.source .. ":" .. tostring(info.currentline)
		elseif info.short_src == "[C]" then txt = txt .. " [C]"
		else txt = txt .. info.source .. ":" .. tostring(info.currentline)
		end
		local lidx, lcount = 1, 1
		while true do
			local ln, lv = env.debug.getlocal(idx, lidx)
			if not ln then break
			end
			if ln:sub(1,1) ~= "(" then
				if lcount == 1 then txt = txt .. ", locals:" end
				if type(lv) == "table" then lv = "<table>"
				elseif type(lv) == "function" then
					local fn = env.debug.getinfo(lv).name
					if fn then lv = "<function " .. fn .. ">"
					else lv = "<function>" end
				elseif type(lv) == "string" then
					if #lv > 15 then lv = lv:sub(1, 15) .. "..." end
					lv = '"' .. lv .. '"'
				end
				txt = txt .. " " .. tostring(ln) .. "=" .. tostring(lv)
				lcount = lcount + 1
				if lcount > 8 then txt = txt .. " ..."; break end
			end
			lidx = lidx + 1
		end
		trace = trace .. tostring(idx-sidx+1) .. ". " .. txt .. "\n"
		idx = idx + 1
		if idx-sidx >= 15 then trace = trace .. "...\n"; break end
	end
	return trace
end

local try_traceback = nil
local try = function(try_fun, catch_fun, ...)
	try_traceback = nil
	local s, r = xpcall(try_fun, function(x)
		local is, ir = pcall(trace_stack, 4)
		if is then try_traceback = ir end
		return x
	end, ...)
	if not s then catch_fun(r) else return r end
end


-- ----- Global namespace for all exports

c = {}


-- ----- Bootstrap for all privileged stuff
-- Basically init(load) to have proper _G available

function c.init(load)
	env = load('return _G')()
	local success = type(env.AsyncStringToFile) == 'function'
	c.log(('ENV init success: %s'):format(success))
end


-- ----- Short global console helper functions: c, hide

function c.log(s, ...) -- print to console
	local args = #(table.pack(...))
	if args then s = fmt(s, ...) end
	AddConsoleLog(s, true)
end

local console_hidden = false
function c.hide() -- hide/show console log
	ShowConsoleLog(console_hidden)
	console_hidden = not console_hidden
end

c.cls = cls


-- ----- Dumper: pp, pf, j

local function clean_table(t, with_mt, data)
	data = data or {}
	for k,v in pairs(t) do if k ~= '__index' then data[k] = data[k] or v end end
	if not with_mt then return data end
	local mt = getmetatable(t)
	if type(mt) ~= 'table' then return data end
	local index = mt.__index
	if type(index) ~= 'table' then return data end
	return clean_table(index, with_mt, data)
end

function c.pp(s, max_depth, limit, table_skip)
	local out, max_depth, limit, skip = '', max_depth or 100, limit or 8000, {}
	for k,v in pairs(table_skip or {}) do skip[v] = true end
	local function pp(s, sk, d)
		sk, d, limit = sk or '', (d or 0) + 1, limit - 1
		if limit == 0 then out = out..'... ERROR: Item limit reached.\n' return end
		if limit < 0 then return end
		local ts = type(s)
		if (ts ~= 'table') then
			out = out..('%s\t%s\t%s\n'):format(sk, ts, s):match('^\t*(.*)$') -- value
			return
		end
		s = clean_table(s, true)
		out = out..('%s\t%s\n'):format(sk, s):match('^\t*(.*)$') -- table header
		if d > max_depth then out = out..sk..'... ERROR: Depth limit reached.\n' return end
		if skip[strim(sk)] then out = out..sk..'... [contents skipped]\n' return end
		for k,v in pairs(s) do pp(v, ('%s\t[%s]'):format(sk, k), d) end -- table contents
	end
	pp(s)
	return out
end

function c.pl(obj, ...) c.log(c.pp(obj, ...)) end

c.j = LuaToJSON
c.pf = print_format


-- ----- Query

-- Useful I/O stuff:
--	 LuaToJSON(obj)
--	 print_format(obj[, ...])
--	 AddConsoleLog(str, true)
--	 ModLog(str)
--	 WaitCustomPopupNotification('title', 'contents', {'button'})
--	 local file_error = AsyncStringToFile('AppData/debug.txt', msg)
--	 xxhash(obj)

-- function OnMsg.Autorun() WaitCustomPopupNotification('Mod Reloaded', 'No Syntax Errors', {'Yay!'}) end
-- local all_objects = GetObjects{class='Object', area='realm'}

local grid_keys = { -- p(obj, 4, 8000, grid_keys)
	'[command_centers]', '[producers]', '[city]', '[units]',
	'[workers]', '[connections]', '[electricity]', '[water]',
	'[rough_terrain_modifier]' }

local dst_dir = 'AppData/console'

-- oh -- Object Hash -- Usage: oh(obj)
function c.oh(obj) return string.sub(('%08x'):format(obj.handle), -8) end

-- find -- Find Object by Hash -- Usage: find('77359404')
-- Find object by its 8-char hash string.
function c.find(h)
	local obj_list = GetObjects{class='Object', area='realm'}
	for _, obj in ipairs(obj_list) do if oh(obj) == h then return obj end end
end

-- po -- Dump Objects -- Usage: po(10)
-- Query all objects in N meters around cursor,
--	print their class/id to console,
--	save "{class}.{id}.json" (shallow)
--	and *.txt (deep) dumps for each in dst_dir
--	(%AppData%/Surviving Mars/console).
function c.po(r_or_obj_list)
	error(env.AsyncCreatePath(dst_dir))
	xpcall(function()
		local obj_list = r_or_obj_list
		if type(obj_list) ~= 'table' then
			obj_list = GetObjects{ class='Object',
				area=GetTerrainCursor(), arearadius=obj_list*guim }
		end
		for _, obj in ipairs(obj_list) do
			local obj_hash = c.oh(obj)
			c.log((' - %s %s'):foramt(obj.class, obj_hash))
			error(env.AsyncStringToFile(
				('%s/po.%s.%s.p.txt'):format(dst_dir, obj.class, obj_hash),
				c.pp(obj, 4, 8000, grid_keys) ))
			error(env.AsyncStringToFile(
				('%s/po.%s.%s.pf.txt'):format(dst_dir, obj.class, obj_hash),
				c.pf(obj) ))
			error(env.AsyncStringToFile(
				('%s/po.%s.%s.json'):format(dst_dir, obj.class, obj_hash),
				c.j(obj):match('^%c*(.*)$') ))
		end
	end,
	function(err)
		if err == 'Not in a thread or within a pcall' then return false end
		WaitCustomPopupNotification(
			'ERROR when running po() routine',
			F('----- Details:\n%s\n%s\n----- :end\n', err, debug.traceback()),
			{'Oops!'})
		return false
	end)
end

-- po10 -- Dump Objects in 10m -- Usage: po10()
function c.po10(r) c.po(r or 10) end

-- po10 -- Dump Selected Object -- Usage: ps()
function c.ps() c.po{SelectedObj} end


-- ----- Eval

function c.run(name)
	local path = env.ConvertToOSPath(('AppData/%s.lua'):format(name or 'test'))
	c.log('Running file: %s', path)
	local src = env.io.open(path, 'r')
	if not src then return c.log('ERROR: failed to open file') end
	local code = src:read('*a')
	src:close()

	local fun, err = env.load(code, '<tmp>')
	if err then return c.log('ERROR: failed to load code - %s', err) end

	try(fun, function(err)
		c.log('ERROR: xpcall - %s', err)
		if try_traceback then c.log('  traceback:\n%s', try_traceback) end
	end)
end


-- ----- Help

function c.h()
	c.log('Raw Lua console, useful functions (among others) listed below.')
	c.log('Be sure to run init first: c.init(load)')
	c.log('Everything else is available under "c" global ns, e.g. c.log("test")')
	c.log(' - Console:')
	c.log('   - log(stuff) -- print stuff to console, example: log(3 + 10)')
	c.log('   - cls() / hide() -- clear and hide/show console log')
	c.log('   - 123 / {k=123} / SelectedObj / any_table - evaluation results get pretty-printed')
	c.log(' - String formatting:')
	c.log('   - pp(obj[, max_depth[, limit=8000[, skip]]]) -- obj to string w/ length/depth limits')
	c.log('   - pl(obj[, pp_opts]) -- pretty-print to console, same as log(pp(obj))')
	c.log('   - po(obj) -- dump obj table to a file')
	c.log('   - j(obj) / pf(obj) -- obj to string in JSON/Lua format')
	c.log(' - Queries:')
	c.log('   - find(hash) -- find/return object by its 8-char hash string')
	c.log('   - oh(obj) -- get 8-char hash string of an in-game object')
	c.log('   - po(10) / po10() -- query and save info on all objects within 10m from cursor')
	c.log('   - ps() -- query and save info on selected object')
	c.log(' - Misc:')
	c.log('   - run() / run(\'myfile\') -- load/run test.lua/myfile.lua from SM AppData dir with _G')
	c.log('   - p() -- set point on the map, not related to console-print commands')
end

CreateRealTimeThread(function()
	Sleep(1000)
	c.log('*** Console mod loaded')
	c.log('*** [hit enter, type c.h(), enter]')
end)
