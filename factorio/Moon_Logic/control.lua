local conf = require('config')
conf.update_from_settings()

local guis = require('gui')


-- Stores code and built environments as {code=..., ro=..., vars=...}
-- This stuff can't be global, built locally, might be cause for desyncs
local Combinators = {}
local CombinatorEnv = {} -- to avoid self-recursive tables


local function tt(s, value)
	-- Helper to make padded table from other table keys or a string of keys
	local t = {}
	if not value then value = true end
	if type(s) == 'table' then for k,_ in pairs(s) do t[k] = value end
	else s:gsub('(%S+)', function(k) t[k] = value end) end
	return t
end

local function tc(src)
	-- Shallow-copy a table with keys
	local t = {}
	for k, v in pairs(src) do t[k] = v end
	return t
end

function tdc(object)
	-- Deep-copy of lua table, from factorio util.lua
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= 'table' then return object
			elseif object.__self then return object
			elseif lookup_table[object] then return lookup_table[object] end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object)
			do new_table[_copy(index)] = _copy(value) end
		return setmetatable(new_table, getmetatable(object))
	end
	return _copy(object)
end


-- ----- Sandboxing and control network inputs code -----

local sandbox_env_pairs_mt_iter = {}
function sandbox_env_pairs(tbl) -- allows to iterate over red/green ro-tables
	local mt = getmetatable(tbl)
	if mt and sandbox_env_pairs_mt_iter[mt.__index] then tbl = tbl._iter(tbl) end
	return pairs(tbl)
end

-- This env gets modified on ticks, which might cause mp desyncs
local sandbox_env_base = {
	_init = false,

	pairs = sandbox_env_pairs,
	ipairs = ipairs,
	next = next,
	pcall = pcall,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	assert = assert,
	error = error,
	select = select,

	serpent = { block = serpent.block },
	string = {
		byte = string.byte, char = string.char, find = string.find,
		format = string.format, gmatch = string.gmatch, gsub = string.gsub,
		len = string.len, lower = string.lower, match = string.match,
		rep = string.rep, reverse = string.reverse, sub = string.sub,
		upper = string.upper },
	table = {
		concat = table.concat, insert = table.insert, remove = table.remove,
		sort = table.sort, pack = table.pack, unpack = table.unpack, },
	math = {
		abs = math.abs, acos = math.acos, asin = math.asin,
		atan = math.atan, atan2 = math.atan2, ceil = math.ceil, cos = math.cos,
		cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor,
		fmod = math.fmod, frexp = math.frexp, huge = math.huge,
		ldexp = math.ldexp, log = math.log, max = math.max,
		min = math.min, modf = math.modf, pi = math.pi, pow = math.pow,
		rad = math.rad, random = math.random, sin = math.sin, sinh = math.sinh,
		sqrt = math.sqrt, tan = math.tan, tanh = math.tanh },
	bit32 = {
		arshift = bit32.arshift, band = bit32.band, bnot = bit32.bnot,
		bor = bit32.bor, btest = bit32.btest, bxor = bit32.bxor,
		extract = bit32.extract, replace = bit32.replace , lrotate = bit32.lrotate ,
		lshift = bit32.lshift , rrotate = bit32.rrotate , rshift = bit32.rshift }
}


local function cn_wire_signals(e, wire_type, output)
	local res, cn, sig_name = {}, e.get_or_create_control_behavior()
		.get_circuit_network(wire_type, defines.circuit_connector_id.constant_combinator)
	output = output or {}
	for _, sig in pairs(cn and cn.signals or {}) do
		sig_name = sig.signal.name
		res[sig_name] = sig.count - (output[sig_name] or 0)
	end
	return res
end

local function cn_input_signal(wenv, wire_type, k)
	if wenv._cache_tick == game.tick then return wenv._cache[k] end
	local signals = cn_wire_signals(wenv._e, wire_type, wenv._out)
	wenv._cache, wenv._cache_tick = signals, game.tick
	if k then signals = signals[k] end
	return signals
end

local function cn_input_signal_get(wenv, k)
	local v = cn_input_signal(wenv, defines.wire_type[wenv._wire], k) or 0
	if wenv._debug then wenv._debug[conf.get_wire_label(wenv._wire)..'['..k..']'] = v end
	return v
end
local function cn_input_signal_set(wenv, k, v)
	error(( 'Attempt to set value to input wire:'..
		' %s[%s] = %s' ):format(conf.get_wire_label(wenv._wire), k, v), 2)
end

local function cn_input_signal_iter(wenv)
	return cn_input_signal(wenv, defines.wire_type[wenv._wire])
end

local function cn_output_table_value(out, k) return rawget(out, k) or 0 end
local function cn_output_table_update(out, update)
	-- Note: validation for sig_names/values is done when output table is used later
	for sig_name, v in pairs(update) do out[sig_name] = v end
end


local function mlc_update_code(mlc, mlc_env, lua_env)
	mlc.next_tick, mlc.err_parse, mlc.err_run, mlc.err_out = 0
	local code, err = (mlc.code or ''):match('^%s*(.-)%s*$')
	if code == '' then mlc_env._func = nil; return end
	mlc_env._func, err = load(
		code, code, 't', lua_env or CombinatorEnv[mlc_env._uid] )
	if not mlc_env._func then mlc.err_parse = err end
end

local function mlc_init(e)
	-- Inits *local* mlc_env state for combinator - builds env, evals lua code, etc
	-- *global* state will be used for init values if it exists, otherwise empty defaults
	-- Lua env for code is composed from: sandbox_env_base + local mlc_env proxies + global mlc.vars
	local uid = e.unit_number
	if Combinators[uid] then error('Double-init for existing combinator unit_number') end
	Combinators[uid] = {} -- some state (e.g. loaded func) has to be local
	if not global.combinators[uid] then global.combinators[uid] = {e=e} end
	local mlc_env, mlc = Combinators[uid], global.combinators[uid]

	if not sandbox_env_base._init then
		-- This gotta cause mp desyncs, +1 metatable layer should probably be used instead
		sandbox_env_base.game = {
			tick=game.tick, print=game.print, log=conf.debug_print }
		sandbox_env_pairs_mt_iter[cn_input_signal_get] = true
		sandbox_env_base._init = true
	end

	mlc.output, mlc.vars = mlc.output or {}, mlc.vars or {}
	mlc_env._e, mlc_env._uid, mlc_env._out = e, uid, mlc.output

	local env_wire_red = {
		_e=mlc_env._e, _wire='red', _debug=false, _out=mlc_env._out,
		_iter=cn_input_signal_iter, _cache={}, _cache_tick=-1 }
	local env_wire_green = tc(env_wire_red)
	env_wire_green._wire = 'green'

	local env_ro = { -- sandbox_env_base + mlc_env proxies
		uid = mlc_env._uid,
		out = setmetatable(mlc_env._out, {__index=cn_output_table_value}),
		red = setmetatable(env_wire_red, {
			__index=cn_input_signal_get, __newindex=cn_input_signal_set }),
		green = setmetatable(env_wire_green, {
			__index=cn_input_signal_get, __newindex=cn_input_signal_set }) }
	env_ro[conf.red_wire_name] = env_ro.red
	env_ro[conf.green_wire_name] = env_ro.green
	setmetatable(env_ro, {__index=sandbox_env_base})

	if not mlc.vars.var then mlc.vars.var = {} end
	local env = setmetatable(mlc.vars, { -- env_ro + mlc.vars
		__index=env_ro, __newindex=function(vars, k, v)
			if k == 'out' then cn_output_table_update(env_ro.out, v)
				env_wire_red._debug, env_wire_green._debug = v, v
			else rawset(vars, k, v) end end })

	mlc_env.debug_wires_set = function(v)
		local v_prev = rawget(env_wire_red, '_debug')
		rawset(env_wire_red, '_debug', v or false)
		rawset(env_wire_green, '_debug', v or false)
		return v_prev end

	CombinatorEnv[uid] = env
	mlc_update_code(mlc, mlc_env, env)
	return mlc_env
end

local function mlc_remove(uid)
	guis.close(uid)
	Combinators[uid], CombinatorEnv[uid], global.combinators[uid], global.guis[uid] = nil
end


-- ----- Misc events -----

local mlc_filter = {{filter='name', name='mlc'}}

local function on_destroyed(ev)
	if ev.entity.name == 'mlc' then mlc_remove(ev.entity.unit_number) end
end

script.on_event(defines.events.on_pre_player_mined_item, on_destroyed, mlc_filter)
script.on_event(defines.events.on_robot_pre_mined, on_destroyed, mlc_filter)
script.on_event(defines.events.on_entity_died, on_destroyed, mlc_filter)
script.on_event(defines.events.script_raised_destroy, on_destroyed, mlc_filter)

local function on_built(ev)
	local e = ev.created_entity or ev.entity -- latter for revive event
	if not e.valid then return end
	if e.name == 'mlc' then global.combinators[e.unit_number] = {e=e} end
end

script.on_event(defines.events.on_built_entity, on_built, mlc_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, mlc_filter)
script.on_event(defines.events.script_raised_built, on_built, mlc_filter)
script.on_event(defines.events.script_raised_revive, on_built, mlc_filter)

local function on_entity_settings_pasted(ev)
	if not (ev.source.name == 'mlc' and ev.destination.name == 'mlc') then return end
	local uid_src, uid_dst = ev.source.unit_number, ev.destination.unit_number
	mlc_remove(uid_dst)
	global.combinators[uid_dst] = tdc(global.combinators[uid_src])
	local mlc_dst, mlc_src = global.combinators[uid_dst], global.combinators[uid_src]
	mlc_dst.e, mlc_dst.next_tick = ev.destination, 0
	guis.history_insert(global.guis[uid_dst], mlc_src, mlc_src.code or '')
end

script.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)


-- ----- on_tick handling - lua code, gui updates -----

local function format_mlc_err_msg(mlc)
	if not (mlc.err_parse or mlc.err_run or mlc.err_out) then return end
	local err_msg = ''
	for prefix, err in pairs{ ParserError=mlc.err_parse,
			RuntimeError=mlc.err_run, OutputError=mlc.err_out } do
		if not err then goto skip end
		if err_msg ~= '' then err_msg = err_msg..' :: ' end
		err_msg = err_msg..('%s: %s'):format(prefix, err)
	::skip:: end
	return err_msg
end

local function update_signals_in_guis()
	local gui_flow, e, cap
	for uid, gui_t in pairs(global.guis) do
		e = Combinators[uid] and Combinators[uid]._e
		if e and not e.valid then mlc_remove(uid); goto skip end
		gui_flow = gui_t.signal_pane
		if gui_flow then gui_flow.clear() end
		for k, color in pairs{red={r=1,g=0.3,b=0.3}, green={r=0.3,g=1,b=0.3}} do
			for sig, v in pairs(cn_wire_signals(e, defines.wire_type[k])) do
				cap = gui_flow.add{ type='label', name=k..'_'..sig,
					caption=('[%s] %s = %s'):format(conf.get_wire_label(k), sig, v) }
				cap.style.font_color = color
		end end
		cap = format_mlc_err_msg(global.combinators[uid]) or ''
		gui_t.mlc_errors.caption = cap
	::skip:: end
end

local function update_signals_diff(mlc, output, output_diff)
	local ecc = mlc.e.get_or_create_control_behavior()
	if not (ecc and ecc.valid) then return end
	local signals, err_msg, n, n_max, err, t = {}, '', 1, ecc.signals_count
	for sig, v in pairs(output) do
		t, err = global.signals[sig]
		if not t then err = ('unknown signal [%s]'):format(sig)
		elseif type(v) ~= 'number'
			then err = ('signal must be a number [%s=(%s) %s]'):format(sig, type(v), v)
		elseif not (v >= -2147483648 and v <= 2147483647)
			then err = ('signal value out of range [%s=%s]'):format(sig, v) end
		if err then
			if err_msg ~= '' then err_msg = err_msg..', ' end
			err_msg = err_msg..err
			goto skip
		end
		signals[n] = {signal={type=t, name=sig}, count=v, index=n}
		n = n + 1
		if n > n_max then break end
	::skip:: end
	if err_msg ~= '' then mlc.err_out = err_msg end
	ecc.enabled, ecc.parameters = true, {parameters=signals}
end

local function on_tick(ev)
	local tick = ev.tick
	if next(global.guis) then update_signals_in_guis() end
	if sandbox_env_base.game then sandbox_env_base.game.tick = tick end

	for uid, mlc in pairs(global.combinators) do
		local mlc_env = Combinators[uid]
		if not mlc_env then mlc_env = mlc_init(mlc.e)
		elseif not (mlc_env._e and mlc_env._e.valid)
			then mlc_remove(uid); goto skip end

		local err_msg = format_mlc_err_msg(mlc)
		if err_msg then
			if tick % conf.logic_alert_interval == 0 then
				for _, player in ipairs(game.connected_players) do
					player.add_custom_alert(
						mlc_env._e, {type='virtual', name='mlc_error'},
						'Moon Logic Error(s): '..err_msg, true )
			end end
			goto skip -- suspend combinator logic until errors are addressed
		end

		if tick >= (mlc.next_tick or 0) and mlc_env._func
			then run_moon_logic_tick(mlc, mlc_env, tick) end
	::skip:: end
end

function run_moon_logic_tick(mlc, mlc_env, tick)
	-- Runs logic of the specified combinator, reading its input and setting outputs
	local out_tick, out_diff = mlc.next_tick, tc(mlc_env._out)
	local dbg = mlc.vars.debug and function(fmt, ...)
		conf.debug_print((' -- moon-logic [%s]: %s'):format(mlc_env._uid, fmt:format(...))) end
	mlc.vars.delay, mlc.vars.debug = 1

	if dbg then -- debug
		dbg('--- debug-run start [tick=%s] ---', tick)
		mlc_env.debug_wires_set({})
		dbg('env-before :: %s', serpent.line(mlc.vars))
		dbg('out-before :: %s', serpent.line(mlc_env._out)) end

	do
		local st, err = pcall(mlc_env._func)
		if not st then mlc.err_run = err or '[unspecified lua error]' else mlc.err_run = nil end
	end

	if dbg then -- debug
		dbg('used-inputs :: %s', serpent.line(mlc_env.debug_wires_set()))
		dbg('env-after :: %s', serpent.line(mlc.vars))
		dbg('out-after :: %s', serpent.line(mlc_env._out)) end

	local delay = tonumber(mlc.vars.delay or 1) or 1
	mlc.next_tick = tick + delay

	for sig, v in pairs(mlc_env._out) do
		if out_diff[sig] ~= v then out_diff[sig] = v
		else out_diff[sig] = nil end
	end
	local out_sync = next(out_diff) or out_tick == 0 -- force sync after reset

	if dbg then -- debug
		for sig, v in pairs(out_diff) do
			if not mlc_env._out[sig] then out_diff[sig] = '-'
		end end
		dbg('out-sync=%s out-diff :: %s', out_sync and true, serpent.line(out_diff)) end

	if out_sync then update_signals_diff(mlc, mlc_env._out, out_diff) end

	local err_msg = format_mlc_err_msg(mlc)
	if err_msg then
		if dbg then dbg('err=%s', serpent.line(err_msg)) end -- debug
		for _, player in pairs(mlc_env._e.last_user.force.connected_players) do
			player.add_custom_alert( mlc_env._e,
				{type='virtual', name='mlc_error'}, 'Moon Logic Error(s): '..err_msg, true )
	end end

	if dbg then dbg('--- debug-run end [tick=%s] ---', tick) end -- debug
end

script.on_event(defines.events.on_tick, on_tick)


-- ----- GUI events and entity interactions -----

function load_code_from_gui(code, uid) -- note: in global _ENV, used from gui.lua
	local mlc, mlc_env = global.combinators[uid], Combinators[uid]
	if not (mlc and mlc.e and mlc.e.valid) then return mlc_remove(uid) end
	mlc.code = code or ''
	if not mlc_env then return mlc_init(mlc.e) end
	mlc_update_code(mlc, mlc_env)
	if not mlc.err_parse then
		for _, player in pairs(game.players) do
			player.remove_alert{entity=mlc_env._e}
	end end
end

script.on_event(defines.events.on_gui_opened, function(ev)
	if not ev.entity then return end
	local player = game.players[ev.player_index]
	if not (player.opened ~= nil and player.opened.name == 'mlc') then return end
	local e = player.opened
	player.opened = nil
	if not global.guis[e.unit_number]
		then guis.open(player, e)
		else player.print(
			game.players[global.guis[e.unit_number].gui.player_index].name..
				' already opened this combinator', {1,1,0} ) end
end)

script.on_event(defines.events.on_gui_click, guis.on_gui_click)
script.on_event(defines.events.on_gui_text_changed, guis.on_gui_text_changed)
script.on_event(defines.events.on_gui_closed, guis.on_gui_close)


-- ----- Keyboard editing hotkeys -----
-- Most editing hotkeys only work if one window is opened,
--  as I don't know how to check which one is focused otherwise.

local function get_active_gui()
	local uid, gui_t
	for uid_chk, gui_t_chk in pairs(global.guis) do
		if not uid
			then uid, gui_t = uid_chk, gui_t_chk
			else uid, gui_t = nil; break end
	end
	return uid, gui_t
end

script.on_event('mlc-code-save', function(ev)
	local uid, gui_t = get_active_gui()
	if uid then guis.save_code(uid) end
end)

script.on_event('mlc-code-undo', function(ev)
	local uid, gui_t = get_active_gui()
	if not gui_t then return end
	local mlc = global.combinators(gui_t.uid)
	if mlc then guis.history_restore(gui_t, mlc, -1) end
end)

script.on_event('mlc-code-redo', function(ev)
	local uid, gui_t = get_active_gui()
	if not gui_t then return end
	local mlc = global.combinators(gui_t.uid)
	if mlc then guis.history_restore(gui_t.gui, mlc, 1) end
end)

script.on_event('mlc-code-close', function(ev)
	local uid, gui_t = next(global.guis)
	if not uid then return end
	guis.close(uid)
end)

script.on_event('mlc-code-commit', function(ev)
	local uid, gui_t = next(global.guis)
	if not uid then return end
	guis.save_code(uid)
	guis.close(uid)
end)


-- ----- Init -----

local strict_mode = false
local function strict_mode_enable()
	if strict_mode then return end
	setmetatable(_ENV, {
		__newindex = function(self, key, value)
			error('\n\n[ENV Error] Forbidden global *write*:\n'
				..serpent.line{key=key or '<nil>', value=value or '<nil>'}..'\n', 2) end,
		__index = function(self, key)
			if key == 'game' then return end -- used in utils.log check
			error('\n\n[ENV Error] Forbidden global *read*:\n'
				..serpent.line{key=key or '<nil>'}..'\n', 2) end })
	strict_mode = true
end

local function update_signal_types_table()
	global.signals = {}
	for name, _ in pairs(game.virtual_signal_prototypes) do global.signals[name] = 'virtual' end
	for name, _ in pairs(game.item_prototypes) do global.signals[name] = 'item' end
	for name, _ in pairs(game.fluid_prototypes) do global.signals[name] = 'fluid' end
end

local function update_recipes()
	for _, force in pairs(game.forces) do
		if force.technologies['mlc'].researched then
			force.recipes['mlc'].enabled = true
	end end
end

script.on_init(function()
	strict_mode_enable()
	update_signal_types_table()
	for k, _ in pairs(tt('combinators guis presets')) do global[k] = {} end
end)

script.on_configuration_changed(function(data) -- migration
	strict_mode_enable()
	update_signal_types_table()

	local update = data.mod_changes and data.mod_changes[script.mod_name]
	if update and update.old_version then
		local function version_to_num(ver, padding)
			local ver_nums = {}
			ver:gsub('(%d+)', function(v) ver_nums[#ver_nums+1] = tonumber(v) end)
			ver = 0
			for n,v in pairs(ver_nums)
				do ver = ver + v * math.pow(10, ((#ver_nums-n)*(padding or 3))) end
			return ver
		end
		local v_old_int = version_to_num(update.old_version)
		local function version_less_than(ver)
			if v_old_int < version_to_num(ver)
				then log('- Applying mod update from pre-'..ver); return true end
		end

		if version_less_than('0.0.2') then -- will also trigger missing protos popup
			local mlcs, uid = {}
			for _, e in ipairs(game.surfaces.nauvis.find_entities_filtered{name='mlc'} or {}) do
				uid = e.unit_number
				if global.combinators[uid] then mlcs[uid] = {e=e, code=global.combinators[uid].code} end
			end
			for uid, gui_t in ipairs(global.guis) do guis.close(uid) end
			for k, _ in pairs(tt('guis history historystate textboxes')) do global[k] = {} end
			global.combinators = mlcs
		end

		if version_less_than('0.0.6') then
			for uid, gui_t in ipairs(global.guis) do guis.close(uid) end
			global.history, global.historystate, global.textboxes = nil
		end
	end

	update_recipes()
end)

script.on_load(function() strict_mode_enable() end)
