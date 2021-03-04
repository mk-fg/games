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

local function tdc(object)
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


-- ----- Circuit network controls -----

local cn_sig_str_prefix = {item='#', fluid='=', virtual='@'}
local function cn_sig_str(t, name)
	-- Translates name or type/name or signal to its type-prefixed string-id
	if not name then
		if type(t) == 'string' then
			name = global.signals_short[t]
			if name == false then return end -- ambiguous name
			return name or t
		else t, name = t.type, t.name end
	end
	return cn_sig_str_prefix[t]..name
end

local function cn_sig_name(sig_str)
	-- Returns abbreviated signal name without prefix
	local k = sig_str:sub(2)
	local sig_str2 = global.signals_short[k]
	if sig_str2 == false then return sig_str
	elseif sig_str2 == sig_str then return k
	elseif not sig_str2 then error(('MOD BUG - abbreviation for invalid signal string: %s'):format(sig_str))
	else error(('MOD BUG - signal string/abbrev mismatch: %s != %s'):format(sig_str, sig_str2)) end
end

local function cn_sig(k, err_level)
	local sig = global.signals_short[k]
	if type(sig) ~= false then sig = global.signals[sig or k] end
	if sig then return sig end
	if not err_level then return end
	if sig == false then
		local m = {}
		for _,t in ipairs{'virtual', 'item', 'fluid'} do
			sig = cn_sig_str(t, k)
			if global.signals[sig] then table.insert(m, sig) end
		end
		error(( 'Ambiguous short signal name "%s",'..
			' matching: %s' ):format(k, table.concat(m, ' ')), err_level)
	end
	error('Unknown signal: '..k, err_level)
end

local function cn_wire_signals(e, wire_type, canon)
	-- Returns signal=count table, with signal names abbreviated where possible
	local res, cn, k = {}, e.get_or_create_control_behavior()
		.get_circuit_network(wire_type, defines.circuit_connector_id.combinator_input)
	for _, sig in pairs(cn and cn.signals or {}) do
		if canon then k = cn_sig_str(sig.signal)
		else k = global.signals_short[sig.signal.name]
			and sig.signal.name or cn_sig_str(sig.signal) end
		res[k] = sig.count
	end
	return res
end

local function cn_input_signal(wenv, wire_type, k)
	local signals = wenv._cache
	if wenv._cache_tick ~= game.tick then
		signals = cn_wire_signals(wenv._e, wire_type, true)
		wenv._cache, wenv._cache_tick = signals, game.tick
	end
	if k then signals = signals[cn_sig_str(cn_sig(k, 4))] end
	return signals
end

local function cn_input_signal_get(wenv, k)
	local v = cn_input_signal(wenv, defines.wire_type[wenv._wire], k) or 0
	if wenv._debug then wenv._debug[conf.get_wire_label(wenv._wire)..'['..k..']'] = v end
	return v
end
local function cn_input_signal_set(wenv, k, v)
	error(( 'Attempt to set value on input wire:'..
		' %s[%s] = %s' ):format(conf.get_wire_label(wenv._wire), k, v), 2)
end

local function cn_input_signal_len(wenv)
	local n, sigs = 0, cn_input_signal(wenv, defines.wire_type[wenv._wire])
	for sig, c in pairs(sigs) do if c ~= 0 then n = n + 1 end end
	return n
end
local function cn_input_signal_iter(wenv)
	-- This returns shortened signal names for simplicity and compatibility
	local signals, sig_cache = {}, cn_input_signal(wenv, defines.wire_type[wenv._wire])
	for k, v in pairs(sig_cache) do signals[cn_sig_name(k)] = cache[k] end
	if wenv._debug then
		local sig_fmt = conf.get_wire_label(wenv._wire)..'[%s]'
		for sig, v in pairs(signals) do wenv._debug[sig_fmt:format(sig)] = v or 0 end
	end
	return signals
end

local function cn_input_signal_table_serialize(wenv)
	return {__wire_inputs=conf.get_wire_label(wenv._wire)}
end

local function cn_output_table_len(out) -- rawlen won't skip 0 and doesn't work anyway
	local n = 0
	for k, v in pairs(out) do if v ~= 0 then n = n + 1 end end
	return n
end
local function cn_output_table_value(out, k)
	if k == '__self' then return end -- for table.deepcopy to tell this apart from factorio object
	return rawget(out, k) or rawget(out, global.signals_short[k]) or 0
end
local function cn_output_table_replace(out, new_tbl)
	-- Note: validation for sig_names/values is done when output table is used later
	for sig, v in pairs(out) do out[sig] = nil end
	for sig, v in pairs(new_tbl or {}) do out[sig] = v end
end


-- ----- Sandbox base -----

local sandbox_env_pairs_mt_iter = {}
local function sandbox_env_pairs(tbl) -- allows to iterate over red/green ro-tables
	local mt = getmetatable(tbl)
	if mt and sandbox_env_pairs_mt_iter[mt.__index] then tbl = tbl._iter(tbl) end
	return pairs(tbl)
end

local function sandbox_clean_table(tbl, apply_func)
	local tbl_clean = {}
	for k, v in sandbox_env_pairs(tbl) do tbl_clean[k] = v end
	if apply_func then return apply_func(tbl_clean) else return tbl_clean end
end

local function sandbox_game_print(...)
	local args, msg = table.pack(...), ''
	for _, arg in ipairs(args) do
		if msg ~= '' then msg = msg..' ' end
		if type(arg) == 'table' then arg = sandbox_clean_table(arg, serpent.line) end
		msg = msg..(tostring(arg or 'nil') or '[value]')
	end
	game.print(msg)
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

	serpent = {
		block = function(tbl) return sandbox_clean_table(tbl, serpent.block) end,
		line = function(tbl) return sandbox_clean_table(tbl, serpent.line) end },
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

-- ----- MLC update processing -----

local mlc_err_sig = {type='virtual', name='mlc-error'}

local function mlc_update_output(mlc, output)
	-- Sets signal outputs on invisible mlc-core combinators connected to visible outputs
	local signals, errors = {red={}, green={}}, {}

	local sig_err, sig, st, err, pre, pre_label = tc(output)
	for _, k in ipairs{false, 'red', 'green'} do
		st = signals[k] and {signals[k]} or {signals.red, signals.green}
		if not k then pre, pre_label = '^.+$', '^.+$'
			else pre, pre_label = '^'..k..'/(.+)$', '^'..conf.get_wire_label(k)..'/(.+)$' end
		for k, v in pairs(output) do
			sig, err = cn_sig(k:match(pre) or k:match(pre_label))
			if not sig then goto skip end
			sig_err[k] = nil
			if type(v) == 'boolean' then v = v and 1 or 0
			elseif type(v) ~= 'number' then
				err = ('signal must be a number [%s=(%s) %s]'):format(sig.name, type(v), v)
			elseif not (v >= -2147483648 and v <= 2147483647) then
				err = ('signal value out of range [%s=%s]'):format(sig.name, v) end
			if err then table.insert(errors, err); goto skip end
			for _, sig_table in ipairs(st) do sig_table[cn_sig_str(sig)] = v end
	::skip:: end end
	for sig, _ in pairs(sig_err)
		do table.insert(errors, ('unknown signal [%s]'):format(sig)) end

	local ps, ecc, n, n_max
	for _, k in ipairs{'red', 'green'} do
		ps, ecc = {}, mlc['out_'..k].get_or_create_control_behavior()
		if not (ecc and ecc.valid) then goto skip end
		n, n_max = 1, ecc.signals_count
		for sig, v in pairs(signals[k]) do
			ps[n] = {signal=global.signals[sig], count=v, index=n}
			n = n + 1
			if n > n_max then
				table.insert( errors,
					('too many signals (wire=%s max=%d)')
					:format(conf.get_wire_label(k), n_max) )
				break
		end end
		ecc.enabled, ecc.parameters = true, ps
	::skip:: end

	if next(errors) then mlc.err_out = table.concat(errors, ', ') end
end

local function mlc_update_led(mlc, mlc_env)
	-- This should set state in a way that doesn't actually produce any signals
	-- Combinator is not considered 'active', as it ends up with 0 value, unless it's mlc-error
	-- It's possible to have it output value and cancel it out, but shows-up on ALT-display
	-- First constant on the combinator encodes its uid value, to copy code from in blueprints
	if mlc.state == mlc_env._state then return end
	local st, cb = mlc.state, mlc.e.get_or_create_control_behavior()
	if not (cb and cb.valid) then return end

	local op, a, b, out = '*', mlc_env._uid, 0
	-- uid is uint, signal is int (signed), so must be negative if >=2^31
	if a >= 0x80000000 then a = a - 0x100000000 end
	if not st then op = '*'
	elseif st == 'run' then op = '%'
	elseif st == 'sleep' then op = '-'
	elseif st == 'no-power' then op = '^'
	elseif st == 'error' then op, b, out = '+', 1 - a, mlc_err_sig end -- shown with ALT
	mlc_env._state, cb.parameters = st, {
		operation=op, first_signal=nil, second_signal=nil,
		first_constant=a, second_constant=b, output_signal=out }
end

local function mlc_update_code(mlc, mlc_env, lua_env)
	mlc.next_tick, mlc.state, mlc.err_parse, mlc.err_run, mlc.err_out = 0
	local code, err = (mlc.code or '')
	if code:match('^%s*(.-)%s*$') ~= '' then
		mlc_env._func, err = load(
			code, code, 't', lua_env or CombinatorEnv[mlc_env._uid] )
		if not mlc_env._func then mlc.err_parse, mlc.state = err, 'error' end
	else
		mlc_env._func = nil
		cn_output_table_replace(mlc_env._out)
		mlc_update_output(mlc, mlc_env._out)
	end
	mlc_update_led(mlc, mlc_env)
end


-- ----- MLC (+ sandbox) init / remove -----

-- Create/connect/remove invisible constant-combinator entities for wire outputs
local function out_wire_connect(e, wire)
	local core = e.surface.create_entity{
		name='mlc-core', position=e.position,
		force=e.force, create_build_effect_smoke=false }
	e.connect_neighbour{ wire=wire, target_entity=core,
		source_circuit_id=defines.circuit_connector_id.combinator_output }
	core.destructible = false
	return core
end
local function out_wire_connect_both(e)
	return
		out_wire_connect(e, defines.wire_type.red),
		out_wire_connect(e, defines.wire_type.green)
end
local function out_wire_clear_mlc(mlc)
	for _, e in ipairs{'core', 'out_red', 'out_green'} do
		e, mlc[e] = mlc[e]
		if e and e.valid then e.destroy() end
	end
	return mlc
end
local function out_wire_connect_mlc(mlc)
	out_wire_clear_mlc(mlc)
	mlc.out_red, mlc.out_green = out_wire_connect_both(mlc.e)
	return mlc
end

local function mlc_log(...) log(...) end -- to avoid logging func code

local function mlc_init(e)
	-- Inits *local* mlc_env state for combinator - builds env, evals lua code, etc
	-- *global* state will be used for init values if it exists, otherwise empty defaults
	-- Lua env for code is composed from: sandbox_env_base + local mlc_env proxies + global mlc.vars
	if not e.valid then return end
	local uid = e.unit_number
	if Combinators[uid] then error('Double-init for existing combinator unit_number') end
	Combinators[uid] = {} -- some state (e.g. loaded func) has to be local
	if not global.combinators[uid] then global.combinators[uid] = {e=e} end
	local mlc_env, mlc = Combinators[uid], global.combinators[uid]

	if not sandbox_env_base._init then
		-- This is likely to cause mp desyncs
		sandbox_env_base.game = {
			tick=game.tick, log=mlc_log,
			print=sandbox_game_print, print_color=game.print }
		sandbox_env_base._api = { game=game, script=script,
			remote=remote, commands=commands, settings=settings,
			rcon=rcon, rendering=rendering, global=global, defines=defines }
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
		out = setmetatable( mlc_env._out,
			{__index=cn_output_table_value, __len=cn_output_table_len} ),
		red = setmetatable(env_wire_red, {
			__serialize=cn_input_signal_table_serialize, __len=cn_input_signal_len,
			__index=cn_input_signal_get, __newindex=cn_input_signal_set }),
		green = setmetatable(env_wire_green, {
			__serialize=cn_input_signal_table_serialize, __len=cn_input_signal_len,
			__index=cn_input_signal_get, __newindex=cn_input_signal_set }) }
	env_ro[conf.red_wire_name] = env_ro.red
	env_ro[conf.green_wire_name] = env_ro.green
	setmetatable(env_ro, {__index=sandbox_env_base})

	if not mlc.vars.var then mlc.vars.var = {} end
	local env = setmetatable(mlc.vars, { -- env_ro + mlc.vars
		__index=env_ro, __newindex=function(vars, k, v)
			if k == 'out' then
				cn_output_table_replace(env_ro.out, v)
				rawset(env_wire_red, '_debug', v)
				rawset(env_wire_green, '_debug', v)
			else rawset(vars, k, v) end end })

	mlc_env.debug_wires_set = function(v)
		local v_prev = rawget(env_wire_red, '_debug')
		rawset(env_wire_red, '_debug', v or false)
		rawset(env_wire_green, '_debug', v or false)
		return v_prev end

	-- Migration from pre-0.0.52 to separate wire outputs
	if mlc.core then out_wire_connect_mlc(mlc) end

	CombinatorEnv[uid] = env
	mlc_update_code(mlc, mlc_env, env)
	return mlc_env
end

local function mlc_remove(uid, keep_entities, to_be_mined)
	guis.close(uid)
	if not keep_entities then
		local mlc = out_wire_clear_mlc(global.combinators[uid] or {})
		if not to_be_mined and mlc.e and mlc.e.valid then mlc.e.destroy() end
	end
	Combinators[uid], CombinatorEnv[uid], global.combinators[uid], global.guis[uid] = nil
end


-- ----- Misc events -----

local mlc_filter = {{filter='name', name='mlc'}}

local function on_built(ev)
	local e = ev.created_entity or ev.entity -- latter for revive event
	if not e.valid then return end
	local mlc = out_wire_connect_mlc{e=e}
	global.combinators[e.unit_number] = mlc

	-- Copy combinator settings from the original one when blueprinted
	local ecc_params = e.get_or_create_control_behavior().parameters
	local uid_src = ecc_params.first_constant or 0

	if uid_src < 0 then uid_src = uid_src + 0x100000000 end -- int -> uint conversion
	if uid_src ~= 0 then
		local mlc_src = global.combinators[uid_src]
		if mlc_src then mlc.code = mlc_src.code else
			mlc.code = ('-- Moon Logic [%s] is unavailable for OTA code update'):format(uid_src) end
	end
end

script.on_event(defines.events.on_built_entity, on_built, mlc_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, mlc_filter)
script.on_event(defines.events.script_raised_built, on_built, mlc_filter)
script.on_event(defines.events.script_raised_revive, on_built, mlc_filter)

local function on_entity_copy(ev)
	if ev.destination.name == 'mlc-core' then return ev.destination.destroy() end -- for clone event
	if not (ev.source.name == 'mlc' and ev.destination.name == 'mlc') then return end
	local uid_src, uid_dst = ev.source.unit_number, ev.destination.unit_number
	local mlc_old_outs = global.combinators[uid_dst]
	mlc_remove(uid_dst, true)
	if mlc_old_outs
		then mlc_old_outs = {mlc_old_outs.out_red, mlc_old_outs.out_green}
		-- For cloned entities, mlc-core's might not yet exist - create/register them here, remove clones above
		-- It'd give zero-outputs for one tick, but probably not an issue, easier to handle it like this
		else mlc_old_outs = {out_wire_connect_both(ev.destination)} end
	global.combinators[uid_dst] = tdc(global.combinators[uid_src])
	local mlc_dst, mlc_src = global.combinators[uid_dst], global.combinators[uid_src]
	mlc_dst.e, mlc_dst.next_tick, mlc_dst.core = ev.destination, 0
	mlc_dst.out_red, mlc_dst.out_green = table.unpack(mlc_old_outs)
	guis.history_insert(mlc_src, mlc_src.code or '', global.guis[uid_dst])
end

script.on_event(
	defines.events.on_entity_cloned, on_entity_copy, -- can be tested via clone in /editor
	{{filter='name', name='mlc'}, {filter='name', name='mlc-core'}} )
script.on_event(defines.events.on_entity_settings_pasted, on_entity_copy)

local function on_destroyed(ev) mlc_remove(ev.entity.unit_number) end
local function on_mined(ev) mlc_remove(ev.entity.unit_number, nil, true) end

script.on_event(defines.events.on_pre_player_mined_item, on_mined, mlc_filter)
script.on_event(defines.events.on_robot_pre_mined, on_mined, mlc_filter)
script.on_event(defines.events.on_entity_died, on_destroyed, mlc_filter)
script.on_event(defines.events.script_raised_destroy, on_destroyed, mlc_filter)


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

local function signal_icon_tag(sig)
	local sig = global.signals[sig]
	if not sig then return '' end
	if sig.type == 'virtual' then return '[virtual-signal='..sig.name..'] ' end
	if game.is_valid_sprite_path(sig.type..'/'..sig.name)
		then return '[img='..sig.type..'/'..sig.name..'] ' end
end

local function update_signals_in_guis()
	local gui_flow, label, mlc, cb, sig, mlc_out, mlc_out_idx, mlc_out_err
	local colors = {red={1,0.3,0.3}, green={0.3,1,0.3}}
	for uid, gui_t in pairs(global.guis) do
		mlc = global.combinators[uid]
		if not (mlc and mlc.e.valid) then mlc_remove(uid); goto skip end
		gui_flow = gui_t.signal_pane
		if not (gui_flow and gui_flow.valid) then goto skip end
		gui_flow.clear()

		-- Inputs
		for k, color in pairs(colors) do
			cb = cn_wire_signals(mlc.e, defines.wire_type[k])
			for sig, v in pairs(cb) do
				if v == 0 then goto skip end
				label = gui_flow.add{
					type='label', name='in-'..k..'-'..sig,
					caption=('[%s] %s%s = %s'):format(
						conf.get_wire_label(k), signal_icon_tag(cn_sig_str(sig)), sig, v ) }
				label.style.font_color = color
		::skip:: end end

		-- Outputs
		mlc_out, mlc_out_idx, mlc_out_err = {}, {}, tc((Combinators[uid] or {})._out or {})
		for k, cb in pairs{red=mlc.out_red, green=mlc.out_green} do
			cb = cb.get_control_behavior()
			for _, cbs in pairs(cb.parameters or {}) do
				sig, label = cbs.signal.name, conf.get_wire_label(k)
				if not sig then goto cb_slot_skip end
				mlc_out_err[sig],
					mlc_out_err[('%s/%s'):format(k, sig)],
					mlc_out_err[('%s/%s'):format(label, sig)] = nil
				sig = cn_sig_str(cbs.signal)
				mlc_out_err[sig],
					mlc_out_err[('%s/%s'):format(k, sig)],
					mlc_out_err[('%s/%s'):format(label, sig)] = nil
				if cbs.count == 0 then goto cb_slot_skip end
				if not mlc_out[sig] then mlc_out_idx[#mlc_out_idx+1], mlc_out[sig] = sig, {} end
				mlc_out[sig][k] = cbs.count
		end ::cb_slot_skip:: end
		table.sort(mlc_out_idx)
		for val, k in pairs(mlc_out_idx) do
			val, sig, label = mlc_out[k], global.signals[k].name, signal_icon_tag(k)
			if val['red'] == val['green'] then
				gui_flow.add{ type='label', name='out-'..sig,
					caption=('[out] %s%s = %s'):format(label, sig, val['red'] or 0) }
			else for k, color in pairs(colors) do
				k = gui_flow.add{ type='label', name='out/'..k..'-'..sig,
					caption=('[out/%s] %s%s = %s'):format(conf.get_wire_label(k), label, sig, val[k] or 0) }
				k.style.font_color = color
		end end end

		-- Remaining invalid signals and errors
		for sig, val in pairs(mlc_out_err) do
			val = serpent.line(val, {compact=true, nohuge=false})
			if val:len() > 8 then val = val:sub(1, 8)..'+' end
			gui_flow.add{ type='label', name='out/err-'..sig,
				caption=('[color=#ce9f7f][out-invalid] %s = %s[/color]'):format(sig, val) }
		end
		gui_t.mlc_errors.caption = format_mlc_err_msg(mlc) or ''
	::skip:: end
end

local function alert_about_mlc_error(mlc_env, err_msg)
	local p = mlc_env._e.last_user
	if p.valid and p.connected
		then p = {p} else p = p.force.connected_players end
	mlc_env._alert = p
	for _, p in ipairs(p) do
		p.add_custom_alert( mlc_env._e, mlc_err_sig,
			'Moon Logic Error ['..mlc_env._uid..']: '..err_msg, true )
	end
end

local function alert_clear(mlc_env)
	local p = mlc_env._alert or {}
	for _, p in ipairs(p) do
		if p.valid and p.connected then p.remove_alert{icon=mlc_err_sig} end
	end
	mlc_env._alert = nil
end

local function run_moon_logic_tick(mlc, mlc_env, tick)
	-- Runs logic of the specified combinator, reading its input and setting outputs
	local out_tick, out_diff = mlc.next_tick, tc(mlc_env._out)
	local dbg = mlc.vars.debug and function(fmt, ...)
		mlc_log((' -- moon-logic [%s]: %s'):format(mlc_env._uid, fmt:format(...))) end
	mlc.vars.delay, mlc.vars.var, mlc.vars.debug, mlc.vars.irq, mlc.irq = 1, mlc.vars.var or {}

	if mlc.e.energy < conf.energy_fail_level then
		mlc.state = 'no-power'
		mlc_update_led(mlc, mlc_env)
		mlc.next_tick = game.tick + conf.energy_fail_delay
		return
	end

	if dbg then -- debug
		dbg('--- debug-run start [tick=%s] ---', tick)
		mlc_env.debug_wires_set({})
		dbg('env-before :: %s', serpent.line(mlc.vars))
		dbg('out-before :: %s', serpent.line(mlc_env._out)) end
	mlc_env._out['mlc-error'] = nil -- for internal use

	do
		local st, err = pcall(mlc_env._func)
		if not st then mlc.err_run = err or '[unspecified lua error]'
		else
			mlc.state, mlc.err_run = 'run'
			if mlc_env._out['mlc-error'] ~= 0 then -- can be used to stop combinator
				mlc.err_run = 'Internal mlc-error signal set'
				mlc_env._out['mlc-error'] = nil -- signal will be emitted via mlc.state
			end
		end
	end

	if dbg then -- debug
		dbg('used-inputs :: %s', serpent.line(mlc_env.debug_wires_set()))
		dbg('env-after :: %s', serpent.line(mlc.vars))
		dbg('out-after :: %s', serpent.line(mlc_env._out)) end

	local delay = tonumber(mlc.vars.delay) or 1
	if delay > conf.led_sleep_min then mlc.state = 'sleep' end
	mlc.next_tick = tick + delay

	local sig = mlc.vars.irq
	if sig then
		sig = cn_sig(sig)
		if sig then mlc.irq, mlc.irq_delay = sig, tonumber(mlc.vars.irq_min_interval) else
			mlc.err_run = ('Unknown/ambiguous "irq" signal: %s'):format(serpent.line(mlc.vars.irq)) end
	end

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

	if out_sync then mlc_update_output(mlc, mlc_env._out) end

	local err_msg = format_mlc_err_msg(mlc)
	if err_msg then
		mlc.state = 'error'
		if dbg then dbg('error :: %s', err_msg) end -- debug
		alert_about_mlc_error(mlc_env, err_msg)
	end

	if dbg then dbg('--- debug-run end [tick=%s] ---', tick) end -- debug
	mlc_update_led(mlc, mlc_env)

	if mlc.vars.ota_update_from_uid then
		local mlc_src = mlc.vars.ota_update_from_uid
		mlc_src = mlc_src ~= mlc_env._uid and
			global.combinators[mlc.vars.ota_update_from_uid]
		if mlc_src and mlc_src.code ~= mlc.code
			then guis.save_code(mlc_env._uid, mlc_src.code) end
		mlc.vars.ota_update_from_uid = nil
	end
end

local function on_tick(ev)
	local tick = ev.tick
	if sandbox_env_base.game then sandbox_env_base.game.tick = tick end

	for uid, mlc in pairs(global.combinators) do
		local mlc_env = Combinators[uid]
		if not mlc_env then mlc_env = mlc_init(mlc.e) end
		if not ( mlc_env and mlc.e.valid
				and mlc.out_red.valid and mlc.out_green.valid )
			then mlc_remove(uid); goto skip end

		local err_msg = format_mlc_err_msg(mlc)
		if err_msg then
			if tick % conf.logic_alert_interval == 0
				then alert_about_mlc_error(mlc_env, err_msg) end
			goto skip -- suspend combinator logic until errors are addressed
		elseif mlc_env._alert then alert_clear(mlc_env) end

		if mlc.irq and (mlc.irq_tick or 0) < tick - (mlc.irq_delay or 0)
				and mlc.e.get_merged_signal(mlc.irq, defines.circuit_connector_id.combinator_input) ~= 0
			then mlc.irq_tick, mlc.next_tick = tick end
		if tick >= (mlc.next_tick or 0) and mlc_env._func then
			run_moon_logic_tick(mlc, mlc_env, tick)
			for _, p in ipairs(game.connected_players)
				do guis.vars_window_update(p.index, uid) end
			if mlc.err_run then guis.update_error_highlight(uid, mlc, mlc.err_run) end
		end
	::skip:: end

	if next(global.guis)
			and game.tick % conf.gui_signals_update_interval == 0
		then update_signals_in_guis() end
end

script.on_event(defines.events.on_tick, on_tick)


-- ----- GUI events and entity interactions -----

function load_code_from_gui(code, uid) -- note: in global _ENV, used from gui.lua
	local mlc, mlc_env = global.combinators[uid], Combinators[uid]
	if not ( mlc and mlc.e.valid
			and mlc.out_red.valid and mlc.out_green.valid )
		then return mlc_remove(uid) end
	mlc.code = code or ''
	if not mlc_env then return mlc_init(mlc.e) end
	mlc_update_code(mlc, mlc_env)
	if not mlc.err_parse then
		for _, player in pairs(game.players)
			do player.remove_alert{entity=mlc_env._e} end
	else guis.update_error_highlight(uid, mlc, mlc.err_parse) end
end

function clear_outputs_from_gui(uid) -- note: in global _ENV, used from gui.lua
	local mlc, mlc_env = global.combinators[uid], Combinators[uid]
	if not (mlc and mlc_env) then return end
	cn_output_table_replace(mlc_env._out)
	mlc_update_output(mlc, mlc_env._out)
end

script.on_event(defines.events.on_gui_opened, function(ev)
	if not ev.entity then return end
	local player = game.players[ev.player_index]
	local e = player.opened
	if not (e and e.name == 'mlc') then return end
	if not global.combinators[e.unit_number] then
		player.opened = nil
		return player.print( 'BUG: Moon Logic Combinator #'..
			e.unit_number..' is not registered with mod code', {1, 0.3, 0} )
	end
	local gui_t = global.guis[e.unit_number]
	if not gui_t then guis.open(player, e)
	elseif player.index == gui_t.mlc_gui.player_index then
		-- This can happen when clicking same mlc again with code box focused
		-- "return" here will open regular combinator gui, so do something else
		-- Not sure how to handle this better - setting anything to player.opened closes stuff
		local code = gui_t.mlc_code.text
		gui_t = guis.open(player, e)
		gui_t.mlc_code.text = code -- restore currently-edited code
	else
		e = game.players[gui_t.mlc_gui.player_index or 0]
		e = e and e.name or 'Another player'
		player.print(e..' already opened this combinator', {1,1,0})
	end
end)

script.on_event(defines.events.on_gui_click, guis.on_gui_click)
script.on_event(defines.events.on_gui_closed, guis.on_gui_close)

if conf.code_history_enabled -- this adds a lot of unpleasant lag to editing text in that textbox
	then script.on_event(defines.events.on_gui_text_changed, guis.on_gui_text_changed) end


-- ----- Keyboard editing hotkeys -----
-- Most editing hotkeys only work if one window is opened,
--  as I don't know how to check which one is focused otherwise.
-- Keybindings don't work in general when text-box element is focused.

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
	local mlc = global.combinators[gui_t.uid]
	if mlc then guis.history_restore(gui_t, mlc, -1) end
end)

script.on_event('mlc-code-redo', function(ev)
	local uid, gui_t = get_active_gui()
	if not gui_t then return end
	local mlc = global.combinators[gui_t.uid]
	if mlc then guis.history_restore(gui_t, mlc, 1) end
end)

script.on_event('mlc-code-commit', function(ev)
	local uid, gui_t = next(global.guis)
	if not uid then return end
	guis.save_code(uid)
	guis.close(uid)
end)

script.on_event('mlc-code-close', function(ev)
	guis.vars_window_toggle(ev.player_index, false)
	guis.help_window_toggle(ev.player_index, false)
	local uid, gui_t = next(global.guis)
	if not uid then return end
	guis.close(uid)
end)

script.on_event('mlc-code-vars', function(ev)
	guis.vars_window_toggle(ev.player_index)
end)

script.on_event('mlc-open-gui', function(ev)
	local player = game.players[ev.player_index]
	local e = player.selected
	if e and e.name == 'mlc' then player.opened = e end
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
	global.signals, global.signals_short = {}, {} -- short=false for ambiguous ones
	local sig_str, sig
	for k, sig in pairs(game.virtual_signal_prototypes) do
		if sig.special then goto skip end -- anything/everything/each
		sig_str, sig = cn_sig_str('virtual', k), {type='virtual', name=k}
		global.signals_short[k], global.signals[sig_str] = sig_str, sig
	::skip:: end
	for t, protos in pairs{ fluid=game.fluid_prototypes,
			item=game.get_filtered_item_prototypes{{filter='flag', flag='hidden', invert=true}} } do
		for k, _ in pairs(protos) do
			sig_str, sig = cn_sig_str(t, k), {type=t, name=k}
			global.signals_short[k] = global.signals_short[k] == nil and sig_str or false
			global.signals[sig_str] = sig
	end end
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
	for k, _ in pairs(tt('combinators presets guis guis_player')) do global[k] = {} end
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

		if version_less_than('0.0.27') then
			error( 'Update from Moon Logic versions <=0.0.27 were removed in 0.0.61+'..
				' - please download/install 0.0.60 manually, then update normally from there.' )
		end
	end

	update_recipes()
end)

script.on_load(function() strict_mode_enable() end)


-- Activate Global Variable Viewer (gvv) mod, if installed/enabled - https://mods.factorio.com/mod/gvv
if script.active_mods['gvv'] then require('__gvv__.gvv')() end
