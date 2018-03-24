local F = string.format
local function strim(s) return s:match('^%s*(.-)%s*$') end


-- ----- Lua Console
-- Nicked from special_snowcat's Lua Console mod
-- http://steamcommunity.com/sharedfiles/filedetails/?id=1335979800

function dbg(func)
	local res
	xpcall(
		function() res = func() end,
		function(err)
			c(F( '----------\nERROR in dbg()-wrapped call: %s\n'..
				'%s\n----------\n', err, debug.traceback() ))
		end)
	return res
end

Console.Exec = function(self, text)
	AddConsoleLog('$ ', true)
	AddConsoleLog(text, false)
	self:AddHistory(text)

	local fun, err = load(text, nil, nil, _G)
	if err then
		fun, err2 = load('return ' .. text, nil, nil, _G)
		if err2 then
			AddConsoleLog(err, true)
			return
		end
	end

	res = dbg(fun)
	-- c('Eval result: '..tostring(res))
	if res then res = print_format(res) end
	AddConsoleLog(res, true)
end

local delayedStart = function()
	Sleep(1000)

	ShowConsoleLog(true)
	AddConsoleLog('*** [hit enter, type h(), enter]', true)

	local Actions = {
		{
			key = 'Enter',
			description = 'Show Lua Console',
			action = function()
				ShowConsoleLog(true)
				ShowConsole(true)
			end
		}
	}
	UserActions.AddActions(Actions)
end

config.ConsoleDim = 1
CreateRealTimeThread(delayedStart)

function c(s) AddConsoleLog(tostring(s), true) end -- print to console
function hide() ShowConsoleLog(false) end -- hide console log


-- ----- Dumper

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

function p(s, max_depth, limit, table_skip)
	local out, max_depth, limit, skip = '', max_depth or 100, limit or 8000, {}
	for k,v in pairs(table_skip or {}) do skip[v] = true end
	local function pp(s, sk, d)
		sk, d, limit = sk or '', (d or 0) + 1, limit - 1
		if limit == 0 then out = out..'... ERROR: Item limit reached.\n' return end
		if limit < 0 then return end
		local ts = type(s)
		if (ts ~= 'table') then
			out = out..F('%s\t%s\t%s\n', sk, ts, s):match('^\t*(.*)$') -- value
			return
		end
		s = clean_table(s, true)
		out = out..F('%s\t%s\n', sk, s):match('^\t*(.*)$') -- table header
		if d > max_depth then out = out..sk..'... ERROR: Depth limit reached.\n' return end
		if skip[strim(sk)] then out = out..sk..'... [contents skipped]\n' return end
		for k,v in pairs(s) do pp(v, F('%s\t[%s]', sk, k), d) end -- table contents
	end
	pp(s)
	return out
end

j = LuaToJSON
pf = print_format


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
function oh(obj) return string.sub(F('%08x', obj.handle), -8) end

-- find -- Find Object by Hash -- Usage: find('77359404')
-- Find object by its 8-char hash string.
function find(h)
	local obj_list = GetObjects{class='Object', area='realm'}
	for _, obj in ipairs(obj_list) do if oh(obj) == h then return obj end end
end

-- po -- Dump Objects -- Usage: po(10)
-- Query all objects in N meters around cursor,
--	print their class/id to console,
--	save "{class}.{id}.json" (shallow)
--	and *.txt (deep) dumps for each in dst_dir
--	(%AppData%/Surviving Mars/console).
function po(r_or_obj_list)
	error(AsyncCreatePath(dst_dir))
	xpcall(function()
		local obj_list = r_or_obj_list
		if type(obj_list) ~= 'table' then
			obj_list = GetObjects{ class='Object',
				area=GetTerrainCursor(), arearadius=obj_list*guim }
		end
		for _, obj in ipairs(obj_list) do
			local obj_hash = oh(obj)
			c(F(' - %s %s', obj.class, obj_hash))
			error(AsyncStringToFile(
				F('%s/po.%s.%s.p.txt', dst_dir, obj.class, obj_hash),
				p(obj, 4, 8000, grid_keys) ))
			error(AsyncStringToFile(
				F('%s/po.%s.%s.pf.txt', dst_dir, obj.class, obj_hash),
				pf(obj) ))
			error(AsyncStringToFile(
				F('%s/po.%s.%s.json', dst_dir, obj.class, obj_hash),
				j(obj):match('^%c*(.*)$') ))
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
function po10(r) po(r or 10) end

-- po10 -- Dump Selected Object -- Usage: ps()
function ps() po({SelectedObj}) end


-- ----- Help

function h()
	c("Raw Lua console, useful functions (among others) listed below.")
	c(" - Console:")
	c("   - c(stuff) -- print stuff to console, example: c(3 + 10)")
	c("   - dbg(func[, ...]) - call func, printing errors to console")
	c("   - cls() / hide() -- clear/hide console log")
	c("   - 123 / {k=123} / SelectedObj / any_table - evaluation results get pretty-printed")
	c(" - String formatting:")
	c("   - p(obj[, max_depth[, limit=8000[, skip]]]) -- obj to string w/ length/depth limits")
	c("   - j(obj) / pf(obj) -- obj to string in JSON/Lua format")
	c(" - Queries:")
	c("   - find(hash) -- find/return object by its 8-char hash string")
	c("   - oh(obj) -- get 8-char hash string of an in-game object")
	c("   - po(10) / po10() -- query and save info on all objects within 10m from cursor")
	c("   - ps() -- query and save info on selected object")
end
