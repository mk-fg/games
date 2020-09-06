local conf = require('config')


local function help_window_toggle(pn, toggle_on)
	local player = game.players[pn]
	local gui_exists = player.gui.screen['mlc-help']
	if gui_exists and not toggle_on then return gui_exists.destroy()
	elseif toggle_on == false then return end

	local gui = player.gui.screen.add{ type='frame',
		name='mlc-help', caption='Moon Logic Combinator Info', direction='vertical' }
	gui.location = {math.max(50, player.display_resolution.width - 800), 20}
	local scroll = gui.add{type='scroll-pane',  name='mlc-help-scroll', direction='vertical'}
	scroll.style.maximal_height = player.display_resolution.height - 200
	local lines = {
		'Combinator has separate input and output leads, but note that you can connect them.',
		' ',
		'Special variables available/handled in Lua environment:',
		'  [color=#ffe6c0]uid[/color] (int) -- globally-unique number of this combinator.',
		('  [color=#ffe6c0]%s[/color] {signal-name=value, ...} -- signals in the %s network (read-only).')
			:format(conf.red_wire_name, conf.red_wire_name),
		'    Any keys queried there are always numbers, returns 0 for missing signal.',
		('  [color=#ffe6c0]%s[/color] {signal-name=value, ...} -- same as above for %s network.')
			:format(conf.green_wire_name, conf.green_wire_name),
		'  [color=#ffe6c0]out[/color] {signal-name=value, ...} -- table with all signals sent to networks.',
		'    They are persistent, so to remove a signal you need to set its entry',
		'     to nil or 0, or flush all signals by entering "[color=#ffe6c0]out = {}[/color]" (creates a fresh table).',
		'  [color=#ffe6c0]delay[/color] (number) -- delay in ticks until next run - use for intervals or performance.',
		'    Defaults to 1 (run again on next tick), and gets reset to it before each run,',
		'    so must be set on every individual run if you want to delay the next one.',
		'  [color=#ffe6c0]var[/color] {} -- table to easily store values between code runs (per-mlc globals work too).',
		'  [color=#ffe6c0]debug[/color] (bool) -- set to true to print debug info about next code run to factorio log.',
		' ',
		'Factorio APIs available, aside from general Lua stuff:',
		'  [color=#ffe6c0]game.tick[/color] -- read-only int for factorio game tick, to measure time intervals.',
		'  [color=#ffe6c0]game.log(...)[/color] -- prints passed value(s) to factorio log.',
		'  [color=#ffe6c0]game.print(...)[/color] -- prints values to an in-game console output.',
		'  [color=#ffe6c0]game.print_color(msg, c)[/color] -- for a more [color=#08c2ca]co[/color]'..
				'[color=#ed7a7e]lor[/color][color=#5cd568]ful[/color] console output, c={r[0-1],g,b}.',
		'  [color=#ffe6c0]serpent.line(...)[/color] and [color=#ffe6c0]serpent.block(...)[/color] -- dump tables to strings.',
		' ',
		'Presets - buttons with numbers on top of the UI:',
		'  Save and Load - [color=#ffe6c0]left-click[/color], Delete - [color=#ffe6c0]right-click[/color],'..
				' Overwrite - [color=#ffe6c0]right[/color] then [color=#ffe6c0]left[/color].',
		'  These are shared between all combinators, and can be used to copy code snippets.',
		'  Another way to copy code is the usual [color=#ffe6c0]shift+right-click[/color]'..
				' - [color=#ffe6c0]shift+left-click[/color].',
		' ',
		'Default UI hotkeys (rebindable, do not work when editing text-box is focused):',
		'  [color=#ffe6c0]Esc[/color] - unfocus/close code textbox (makes all other hotkeys work again),',
		'  [color=#ffe6c0]Ctrl-S[/color] - save/apply code changes,'..
				' [color=#ffe6c0]Ctrl-Left/Right[/color] - undo/redo last change,',
		'  [color=#ffe6c0]Ctrl-Q[/color] - close all UIs,'..
				' [color=#ffe6c0]Ctrl-Enter[/color] - save/apply and close,'..
				' [color=#ffe6c0]Ctrl-F[/color] - toggle env window.',
		' ',
		'To learn signal names, connect anything with signals to this combinator,',
		'and their names will be printed as colored inputs on the right of the code window.',
		' ' }
	for n, line in ipairs(lines) do scroll.add{
		type='label', name='line_'..n, direction='horizontal', caption=line } end
	gui.add{type='button', name='mlc-help-close', caption='Got it'}
end


local function vars_window_update(player, uid)
	local gui = player.gui.screen['mlc-vars']
	if not gui then return end
	gui.caption = ('Moon Logic Environment Variables [%s]'):format(uid)
	local mlc, vars_box = global.combinators[uid], gui['mlc-vars-scroll']['mlc-vars-box']
	if not mlc then vars_box.text = '--- [color=#911818]Moon Logic Combinator is Offline[/color] ---'
	else
		local text, esc, vs, c = '', function(s) return tostring(s):gsub('%[', '[ ') end
		for k, v in pairs(mlc.vars) do
			if text ~= '' then text = text..'\n' end
			vs = serpent.line(v, {nocode=true})
			if vs:len() > conf.gui_vars_line_len_max
			then vs = serpent.block(v, {nocode=true})
			elseif vs:len() > conf.gui_vars_line_len_max * 0.6 then vs = '\n  '..vs end
			text = text..('[color=#520007][font=default-bold]%s[/font][/color] = %s'):format(esc(k), esc(vs))
		end
		vars_box.text = text
	end
end

local function vars_window_switch_or_toggle(pn, uid, toggle_on)
	-- Switches variables-window to specified combinator or toggles it on/off
	local player, gui_k = game.players[pn], 'vars.'..pn
	local gui_exists = player.gui.screen['mlc-vars']
	if gui_exists then
		if toggle_on == nil and global.guis_player[gui_k] ~= uid then
			global.guis_player[gui_k] = uid
			return vars_window_update(player, uid)
		elseif not toggle_on then return gui_exists.destroy() end
	elseif toggle_on == false then return end -- force off toggle

	global.guis_player[gui_k] = uid
	local gui = player.gui.screen.add{ type='frame',
		name='mlc-vars', caption='', direction='vertical' }
	gui.location = {math.max(50, player.display_resolution.width - 800), 45}
	local scroll = gui.add{type='scroll-pane',  name='mlc-vars-scroll', direction='vertical'}
	scroll.style.maximal_height = player.display_resolution.height - 300
	local tb = scroll.add{type='text-box', name='mlc-vars-box', text=''}
	tb.style.width = conf.gui_vars_line_px
	tb.read_only, tb.selectable, tb.word_wrap = true, false, true
	gui.add{type='button', name='mlc-vars-close', caption='Close'}
	vars_window_update(player, uid)
end


local err_icon_sub_add = '[color=#c02a2a]%1[/color]'
local err_icon_sub_clear = '%[color=#c02a2a%]([^\n]+)%[/color%]'
local function code_error_highlight(text, line_err)
	-- Add/strip rich error highlight tags
	text = text:gsub(err_icon_sub_clear, '%1')
	line_err = tonumber(line_err)
	if not line_err then return text end
	local _, line_count = text:gsub('([^\n]*)\n?','')
	if string.sub(text, -1) == '\n'
		then line_count = line_count + 1 end
	local n, result = 0, ''
	for line in text:gmatch('([^\n]*)\n?') do
		n = n + 1
		if n < line_count then
			if n == line_err
				then line = line:gsub('^(.+)$', err_icon_sub_add) end
			if n > 1 then line = '\n'..line end
			result = result..line
	end end
	return result
end

local function set_history_btns_state(gui_t, mlc)
	local hist_log, n = mlc.history, mlc.history_state
	if n and hist_log[n-1] then
		gui_t.mlc_back.sprite = 'mlc-back-enabled'
		gui_t.mlc_back.ignored_by_interaction = false
	else
		gui_t.mlc_back.sprite = 'mlc-back'
		gui_t.mlc_back.ignored_by_interaction = true
	end
	if n and hist_log[n+1] then
		gui_t.mlc_fwd.sprite = 'mlc-fwd-enabled'
		gui_t.mlc_fwd.ignored_by_interaction = false
	else
		gui_t.mlc_fwd.sprite = 'mlc-fwd'
		gui_t.mlc_fwd.ignored_by_interaction = true
	end
end

local function preset_help_tooltip(code)
	if not code
		then code = '-- [ left-click to save script here ] --'
		else code = code:match('^%s*(.-)%s*$')..
			'\n-- [ left-click - load, right-click - clear ] --' end
	return code
end

local function create_gui(player, entity)
	local uid = entity.unit_number
	local mlc = global.combinators[uid]
	local mlc_err = mlc.err_parse or mlc.err_run
	local max_height = player.display_resolution.height - 350

	-- Main frame
	local el_map, el = {} -- map is to check if el belonds to this gui
	local gui_t = {uid=uid, el_map=el_map}

	local function elc(parent, props, style)
		el = parent.add(props)
		for k,v in pairs(style or {}) do el.style[k] = v end
		gui_t[props.name:gsub('%-', '_')], el_map[el.index] = el, el
		return el
	end

	local gui = elc( player.gui.screen,
			{ type='frame', name='mlc-gui',
				direction='vertical', caption =
					('Moon Logic [%s] - %s {}, %s {}, out {}, var {}, delay (int)')
					:format(uid, conf.red_wire_name, conf.green_wire_name) },
			{top_padding=1, right_padding=4, bottom_padding=4, left_padding=4} )
		el.location = {20, 150} -- doesn't work from initial props

	-- Main table
	local mt = elc(gui, {type='table', column_count=2, name='mt', direction='vertical'})

	-- MT column-1
	local mt_left = elc(mt, {type='flow', name='mt-left', direction='vertical'})

	-- MT column-1: action button bar at the top
	local top_btns = elc( mt_left,
		{type='flow', name='mt-top-btns', direction='horizontal'}, {width=799} )

	local function top_btns_add(name, tooltip)
		local sz, pad = 20, 0
		return elc( top_btns,
			{type='sprite-button', name=name, sprite=name, direction='horizontal', tooltip=tooltip},
			{height=sz, width=sz, top_padding=pad, bottom_padding=pad, left_padding=pad, right_padding=pad} )
	end

	top_btns_add('mlc-close', 'Discard changes and close [[color=#e69100]Esc[/color]]')
	top_btns_add('mlc-help', 'Toggle quick reference window')
	top_btns_add( 'mlc-vars',
		'Toggle environment window for this combinator\n'..
		'Right-click to clear all environment variables on it' )

	elc(top_btns, {type='flow', name='mt-top-spacer-a', direction='horizontal'}, {width=10})

	top_btns_add( 'mlc-back',
		'Undo [[color=#e69100]Ctrl-Left[/color]]\nRight-click - undo 5, right+shift - undo 50' )
	top_btns_add( 'mlc-fwd',
		'Redo [[color=#e69100]Ctrl-Right[/color]]\nRight-click - redo 5, right+shift - redo 50' )
	set_history_btns_state(gui_t, mlc)

	top_btns_add('mlc-clear', 'Clear code window')

	elc(top_btns, {type='flow', name='mt-top-spacer-b', direction='horizontal'}, {width=10})

	-- MT column-1: preset buttons at the top
	for n=0, 19 do
		elc( top_btns,
			{ type='button', name='mlc-preset-'..n, direction='horizontal', caption=n,
				tooltip='Discard changes and close [[color=#e69100]Esc[/color]]' },
			{height=20, width=27, top_padding=0, bottom_padding=0, left_padding=0, right_padding=0} )
		if not global.presets[n] then el.style, el.tooltip = 'button', preset_help_tooltip()
		else el.style, el.tooltip = 'green_button', preset_help_tooltip(global.presets[n]) end
	end

	-- MT column-1: code text-box
	elc(mt_left, { type='scroll-pane',
		name='mlc-code-scroll', direction='vertical' }, {maximal_height=max_height})
	elc( el, {type='text-box', name='mlc-code', direction='vertical', text=mlc.code or ''},
		{vertically_stretchable=true, width=800, minimal_height=300} )
	if mlc_err
		then el.text = code_error_highlight(el.text, string.gsub(mlc_err,'.+:(%d+):.+', '%1'))
		else el.text = code_error_highlight(el.text) end
	mlc.textbox = el.text -- XXX: maybe restore mlc.textbox instead with revert-to-code button?

	-- MT column-1: error bar at the bottom
	elc(mt_left, {type='label', name='mlc-errors', direction='horizontal'}, {horizontally_stretchable=true})

	-- MT column-2
	local mt_right = elc(mt, {type='flow', name='mt-right', direction='vertical'})

	-- MT column-2: input signal list
	elc(mt_right, {type='label', name='signal-header', caption='Wire Signals:'}, {font='heading-2'})
	elc( mt_right, {type='scroll-pane', name='signal-pane', direction='vertical'},
		{vertically_stretchable=true, vertically_squashable=true, maximal_height=max_height} )

	-- MT column-2: input signal list
	local control_btns = elc(mt_right, {type='flow', name='mt-br-btns', direction='horizontal'})
	elc(control_btns, {type='button', name='mlc-save', caption='Save'}, {width=60})
	elc(control_btns, {type='button', name='mlc-close', caption='Close'}, {width=60})
	elc(control_btns, {type='button', name='mlc-commit', caption='Save & Close'})

	return gui_t
end


-- ----- Interface for control.lua -----

local function find_gui(ev)
	-- Finds uid and gui table for specified event-target element
	if ev.entity and ev.entity.valid then
		local uid = ev.entity.unit_number
		local gui_t = global.guis[uid]
		if gui_t then return uid, gui_t end
	end
	local el, el_chk = ev.element
	if not el then return end
	for uid, gui_t in pairs(global.guis) do
		el_chk = gui_t.el_map[el.index]
		if el_chk and el_chk == el then return uid, gui_t end
	end
end

local guis = {}

function guis.open(player, e)
	local uid_old = global.guis_player[player.index]
	if uid_old then player.opened = guis.close(uid_old) end
	local gui_t = create_gui(player, e)
	global.guis[e.unit_number] = gui_t
	player.opened = gui_t.mlc_gui
	global.guis_player[player.index] = e.unit_number
end

function guis.close(uid)
	local gui_t = global.guis[uid]
	local gui = gui_t and (gui_t.mlc_gui or gui_t.gui)
	if gui then gui.destroy() end
	global.guis[uid] = nil
end

function guis.history_insert(gui_t, mlc, code)
	local hist_log, n = mlc.history, mlc.history_state
	-- XXX: do not store empty strings
	if not hist_log then
		mlc.history = {mlc.textbox}
		mlc.history_state = 1
	else
		if hist_log[n] == code then n = n
		elseif #hist_log == n then
			n = n + 1
			table.insert(hist_log, code)
		else
			n = n + 1
			hist_log[n] = code
			for a = n + 1, #hist_log do hist_log[a] = nil end
		end
		while n > conf.code_history_limit do
			n = n - 1
			table.remove(hist_log, 1)
		end
		mlc.history_state = n
	end
	if gui_t then set_history_btns_state(gui_t, mlc) end
end

function guis.history_restore(gui_t, mlc, offset)
	if not mlc.history then return end
	local n = math.min(#mlc.history, math.max(1, mlc.history_state + offset))
	mlc.history_state = n
	gui_t.mlc_code.text = mlc.history[n]
	set_history_btns_state(gui_t, mlc)
	mlc.textbox = gui_t.mlc_code.text
end

function guis.save_code(eid, code)
	local gui_t = global.guis[eid]
	if not gui_t then return end
	local clean_code = code_error_highlight(code or gui_t.mlc_code.text)
	load_code_from_gui(clean_code, eid)
	gui_t.mlc_code.text = clean_code
end

function guis.on_gui_text_changed(ev)
	if ev.element.name ~= 'mlc-code' then return end
	local uid, gui_t = find_gui(ev)
	if not uid then return end
	local mlc = global.combinators[uid]
	if not mlc then return end
	guis.history_insert(gui_t, mlc, ev.element.text)
	global.combinators[uid].textbox = ev.element.text
end

function guis.on_gui_click(ev)
	local el = ev.element
	-- Separate "help" and "vars" windows, tracked separately from main guis
	if el.name == 'mlc-help-close' then return el.parent.destroy() end
	if el.name == 'mlc-vars-close' then return el.parent.destroy() end

	local uid, gui_t = find_gui(ev)
	if not uid then return end
	local mlc = global.combinators[uid]
	if not mlc then return guis.close(uid) end
	local el_id = el.name
	local preset_n = tonumber(el_id:match('^mlc%-preset%-(%d+)$'))
	local rmb = defines.mouse_button_type.right

	if el_id == 'mlc-code' then gui_t.code_focused = true -- disables hotkeys

	elseif el_id == 'mlc-save' then guis.save_code(uid)
	elseif el_id == 'mlc-commit' then guis.save_code(uid); guis.close(uid)
	elseif el_id == 'mlc-clear' then
		guis.save_code(uid, '')
		guis.on_gui_text_changed{element=gui_t.mlc_code}
	elseif el_id == 'mlc-close' then guis.close(uid)
	elseif el_id == 'mlc-help' then help_window_toggle(ev.player_index)

	elseif el_id == 'mlc-vars' then
		if ev.button == rmb then
			for k, _ in pairs(mlc.vars) do mlc.vars[k] = nil end -- clear env
			vars_window_update(game.players[ev.player_index], uid)
		else vars_window_switch_or_toggle(ev.player_index, uid) end

	elseif preset_n then
		if ev.button == defines.mouse_button_type.left then
			if global.presets[preset_n] then
				gui_t.mlc_code.text = global.presets[preset_n]
				mlc.textbox = gui_t.mlc_code.text
				guis.history_insert(gui_t, mlc, gui_t.mlc_code.text)
			else
				global.presets[preset_n] = gui_t.mlc_code.text
				el.style = 'green_button'
				el.tooltip = preset_help_tooltip(global.presets[preset_n])
			end
		elseif ev.button == rmb then
			global.presets[preset_n] = nil
			el.style = 'button'
			el.tooltip = preset_help_tooltip()
		end

	elseif el_id == 'mlc-back' then
		if ev.button == rmb and ev.shift then guis.history_restore(gui_t, mlc, -50)
		elseif ev.button == rmb then guis.history_restore(gui_t, mlc, -5)
		else guis.history_restore(gui_t, mlc, -1) end
	elseif el_id == 'mlc-fwd' then
		if ev.button == rmb and ev.shift then guis.history_restore(gui_t, mlc, 50)
		elseif ev.button == rmb then guis.history_restore(gui_t, mlc, 5)
		else guis.history_restore(gui_t, mlc, 1) end
	end
end

function guis.on_gui_close(ev)
	-- Also fired for original auto-closed combinator GUI, which is ignored due to uid=gui_t=nil
	-- How unfocus/close sequence works:
	--  - click on code -  sets "code_focused = true", and game suppresses hotkeys except for esc
	--  - esc - with code_focused set, it is cleared, unfocus(), player.opened re-set to this gui again
	--  - esc again - as gui_t.code_focused is unset now, gui is simply closed here
	local uid, gui_t = find_gui(ev)
	if not uid then return end
	local p = game.players[ev.player_index]
	if p.valid and gui_t.code_focused then
		gui_t.mlc_gui.focus()
		p.opened, gui_t.code_focused = gui_t.mlc_gui
	else guis.close(uid) end
end

function guis.help_window_toggle(pn, toggle_on)
	help_window_toggle(pn, toggle_on)
end

function guis.vars_window_update(pn, uid)
	local player, vars_uid = game.players[pn], global.guis_player['vars.'..pn]
	if not player or vars_uid ~= uid then return end
	vars_window_update(player, uid)
end

function guis.vars_window_toggle(pn, toggle_on)
	local gui = game.players[pn].gui.screen['mlc-gui']
	local uid, gui_t = find_gui{element=gui}
	if not uid then return end
	vars_window_switch_or_toggle(pn, uid, toggle_on)
end

return guis
