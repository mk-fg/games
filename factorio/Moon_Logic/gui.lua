local conf = require('config')

local gui_manager = {}
local comb_gui_class = {}


local function preset_help_tooltip(code)
	if not code
		then code = '-- [ left-click to save script here ] --'
		else code = code:match('^%s*(.-)%s*$')..
			'\n-- [ left-click - load, right-click - clear ] --' end
	return code
end

local function find_eid_for_gui_element(v)
	-- Returns eid of the gui table for the clicked element,
	--  along with local name of the button in data table and index of preset-btn
	for eid, e_g_els in pairs(global.guis) do
		if type(eid) ~= 'number' then goto skip end
		for elname, vv in pairs(e_g_els) do
			if elname == 'preset_btns' then
				for n, vvv in pairs(vv) do
					if v == vvv then return eid, 'preset_btn', n
				end end
			elseif vv == v then return eid, elname end
		end
	::skip:: end
	-- log(('BUG: GUI element not found: %s [gui dump follows]'):format(v and v.name or '???'))
	-- log(serpent.block(global.guis))
end

local function help_window_toggle(pn)
	local player = game.players[pn]
	if player.gui.screen['mlc_helper_'..pn] then
		player.gui.screen['mlc_helper_'..pn].destroy()
		return
	end
	local gui = player.gui.screen.add{ type='frame',
		name='mlc_helper_'..pn, caption='Moon Logic Combinator Info', direction='vertical' }
	gui.location = {math.max(50, player.display_resolution.width - 800), 150}
	local lines = {
		'Special variables available/handled in Lua environment:',
		'  uid (int) -- globally-unique number of this combinator.',
		('  %s {signal-name=value, ...} -- signals in the %s network (read only).')
			:format(conf.red_wire_name, conf.red_wire_name),
		('  %s {signal-name=value, ...} -- same for the %s network.')
			:format(conf.green_wire_name, conf.green_wire_name),
		'  out {signal-name=value, ...} -- a table with all signals sent to networks.',
		'    They are permanent, so to remove a signal you need to set its entry',
		'     to nil or 0, or flush all signals by entering "out = {}" (creates a fresh table).',
		'  var {} -- a table to easily store values between code runs (per-mlc globals work too).',
		'  delay (number) -- delay in ticks until next run (saves ups), has to be set on each run!',
		'  debug (bool) -- set to true to print debug info about next code run to factorio log.',
		' ',
		'Factorio APIs available, aside from general Lua stuff:',
		'  game.tick -- read-only int for factorio game tick, to measure time intervals.',
		'  game.print(...) -- prints string as in-game console output.',
		'  game.log(...) -- prints to factorio log.',
		' ',
		'Presets (buttons with numbers):',
		'  Save and Load - left-click, Delete - right-click, Overwrite - right then left.',
		'Default Hotkeys (rebindable, do not work when editing text-box is focused):',
		'  Ctrl-S - save, Ctrl-Left/Right - undo/redo, Ctrl-Enter - save and close.',
		' ',
		'To learn signal names, connect anything with signals to this combinator,',
		'and their names will be printed as colored inputs on the right of the code window.',
		' ' }
	for n, line in ipairs(lines) do gui.add{
		type='label', name='line_'..n, direction='horizontal', caption=line } end
	gui.add{type='button', name='mlc_help_x', caption='Got it'}
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


-- XXX: get rid of all this pretend-class nonsense

function gui_manager:on_gui_text_changed(ev)
	local eid = find_eid_for_gui_element(ev.element)
	if not eid then return end
	global.guis[eid]:on_gui_text_changed(eid, ev)
end

function gui_manager:on_gui_click(ev)
	if ev.element.name == 'mlc_help_x' -- untracked "help" windows
		then return ev.element.parent.destroy() end
	local eid, elname, n = find_eid_for_gui_element(ev.element)
	if not eid then return end
	global.guis[eid]:on_gui_click(eid, elname, n, ev)
end

function gui_manager:open(player, entity)
	local gui_data = self:create_gui(player, entity)
	setmetatable(gui_data, {__index=comb_gui_class})
	global.guis[entity.unit_number]=gui_data
	player.opened=gui_data.gui
end

function gui_manager:set_history_btns_state(gui_t)
	-- XXX: index history, historystate, textboxes by uid, not some special gui.name
	-- XXX: is this even get cleared, like ever?
	local gui_name = gui_t.gui.name
	local n, hist_log = global.historystate[gui_name], global.history[gui_name]
	if hist_log[n-1] then
		gui_t.bw_btn.sprite = 'mlc_back_enabled'
		gui_t.bw_btn.ignored_by_interaction = false
	else
		gui_t.bw_btn.sprite = 'mlc_back'
		gui_t.bw_btn.ignored_by_interaction = true
	end
	if hist_log[n+1] then
		gui_t.fw_btn.sprite = 'mlc_forward_enabled'
		gui_t.fw_btn.ignored_by_interaction = false
	else
		gui_t.fw_btn.sprite = 'mlc_forward'
		gui_t.fw_btn.ignored_by_interaction = true
	end
end

function gui_manager:create_gui(player, entity)
	local uid = entity.unit_number -- XXX: remove it from all names
	local mlc = global.combinators[uid]
	local mlc_err = mlc.err_parse or mlc.err_run

	-- Main frame
	local gui_t, el = {}
	local gui = player.gui.screen.add{ type='frame',
		name='mlc_gui_'..uid, caption='', direction='vertical' }
	gui.location = {20, 150}
	gui_t.gui = gui
		gui.caption =
			('Moon Logic [%s] - %s {}, %s {}, out {}, var {}, delay (int)')
			:format(uid, conf.red_wire_name, conf.green_wire_name)
		gui.style.top_padding = 1
		gui.style.right_padding = 4
		gui.style.bottom_padding = 4
		gui.style.left_padding = 4
		--gui.style.scaleable = false

	-- Main table
	local mt = gui.add{type='table', column_count=2, name='main_table', direction='vertical'}
		mt.style.vertical_align = 'top'


	-- MT column-1
	local mt_left = mt.add{type='flow', column_count=1, name='left', direction='vertical'}
		mt_left.style.vertical_align = 'top'
		-- mt_left.style.vertically_stretchable = true
		-- mt_left.style.vertically_squashable = false

	-- MT column-1: action button bar at the top
	local top_btns = mt_left.add{type='flow', name='flow', direction='horizontal'}
		top_btns.style.width = 799
	el = top_btns.add{type='sprite-button', name='mlc_x_'..uid, direction='horizontal'}
	gui_t.x_btn = el
		el.style.height=20
		el.style.width=20
		el.style.top_padding=0
		el.style.bottom_padding=0
		el.style.left_padding=0
		el.style.right_padding=0
		--el.style.disabled_font_color ={r=1,g=1,b=1}
		el.sprite='mlc_close'
		el.tooltip = 'Discard changes and close [[color=#e69100]Esc[/color]]'
	el = top_btns.add{type='sprite-button', name='mlc_help', direction='horizontal'}
	gui_t.help_btn = el
		el.style.height=20
		el.style.width=20
		el.style.top_padding=0
		el.style.bottom_padding=0
		el.style.left_padding=0
		el.style.right_padding=0
		el.sprite='mlc_questionmark'
		el.tooltip = 'Open quick reference window'
	el = top_btns.add{type = 'flow', name = 'flow1', direction = 'horizontal'}
		el.style.width=15

	el = top_btns.add{type='sprite-button', name='mlc_back', state=true}
	gui_t.bw_btn = el
		el.style.height=20
		el.style.width=20
		el.style.top_padding=0
		el.style.bottom_padding=0
		el.style.left_padding=0
		el.style.right_padding=0
		el.sprite='mlc_back'
		el.hovered_sprite ='mlc_back'
		el.clicked_sprite ='mlc_back'
		el.tooltip = 'Undo [[color=#e69100]Ctrl-Left[/color]]\nRight-click - undo 5, +shift - undo 50'
	el = top_btns.add{type='sprite-button', name='mlc_forward', state=true}
	gui_t.fw_btn = el
		el.style.height=20
		el.style.width=20
		el.style.top_padding=0
		el.style.bottom_padding=0
		el.style.left_padding=0
		el.style.right_padding=0
		el.sprite='mlc_forward'
		el.hovered_sprite ='mlc_forward'
		el.clicked_sprite  ='mlc_forward'
		el.tooltip = 'Redo [[color=#e69100]Ctrl-Right[/color]]\nRight-click - redo 5, +shift - redo 50'
	self:set_history_btns_state(gui_t)

	el = top_btns.add{type='sprite-button', name='mlc_clear', state=true}
	gui_t.clear_btn = el
		el.style.height=20
		el.style.width=20
		el.style.top_padding=0
		el.style.bottom_padding=0
		el.style.left_padding=0
		el.style.right_padding=0
		el.sprite='mlc_clear'
		el.hovered_sprite ='mlc_clear'
		el.clicked_sprite  ='mlc_clear'
		el.tooltip = 'Clear code window'

	-- MT column-1: preset buttons at the top
	local preset_btns = {}
	for n=0, 20 do
		el = top_btns.add{type='button', name='mlc_preset_'..n, direction='horizontal', caption=n}
		preset_btns[n] = el
			el.style.height=20
			el.style.width=27
			el.style.top_padding=0
			el.style.bottom_padding=0
			el.style.left_padding=0
			el.style.right_padding=0
		if not global.presets[n+1] then el.style, el.tooltip = 'button', preset_help_tooltip()
		else el.style, el.tooltip = 'green_button', preset_help_tooltip(global.presets[n+1]) end
	end
	gui_t.preset_btns = preset_btns

	-- MT column-1: code text-box
	local code_pane = mt_left.add{type='scroll-pane',  name='code_scroll', direction='vertical'}
		-- code_pane.style.vertically_stretchable = true
		-- code_pane.style.vertically_squashable = false
		code_pane.style.maximal_height = 700
	local code_table = code_pane.add{
		type='table', column_count=1, name='code_table', direction='vertical' }
		-- code_table.style.vertically_stretchable = true
		-- code_table.style.vertically_squashable = false
	el = code_table.add{type='text-box', name='mlc_code', direction='vertical'}
	gui_t.code_tb = el
		el.style.vertically_stretchable = true
		-- el.style.vertically_squashable = false
		el.style.width = 800
		el.style.minimal_height = 300
		el.text = mlc.code or ''
		if mlc_err
			then el.text = code_error_highlight(el.text, string.gsub(mlc_err,'.+:(%d+):.+', '%1'))
			else el.text = code_error_highlight(el.text) end
	global.textboxes[gui.name] = el.text
	if not global.history[gui.name] then
		global.history[gui.name] = {el.text}
		global.historystate[gui.name] = 1
	end

	-- MT column-1: error bar at the bottom
	local code_errors = mt_left.add{type='table', column_count=2, name='under_text', direction='vertical'}
		code_errors.style.width = 800
	el = code_errors.add{type='label', name='errors', direction='horizontal'}
	gui_t.code_errs = el
		el.style.width = 760


	-- MT column-2
	local mt_right = mt.add{type='flow', column_count=1, name='right', direction='vertical'}
		mt_right.style.vertical_align = 'top'
		-- mt_left.style.vertically_stretchable = true
		-- mt_left.style.vertically_squashable = false

	-- MT column-2: input signal list
	el = mt_right.add{type='label', name='signals_header', caption='Input Signals:'}
		el.style.font = 'heading-2'
	el = mt_right.add{type='scroll-pane', name='signal_pane', direction='vertical'}
	gui_t.signal_pane = el
		el.style.vertically_stretchable = true
		el.style.vertically_squashable = true
		el.style.maximal_height = 700

	-- MT column-2: input signal list
	local control_btns = mt_right.add{
		type='flow', name='control-btns', direction='horizontal' }
	el = control_btns.add{type='button', name='mlc_ok_'..uid, caption='Save'}
		el.style.width = 60
	gui_t.ok_btn = el

	el = control_btns.add{type='button', name='mlc_close_'..uid, caption='Close'}
		el.style.width = 60
	el = control_btns.add{type='button', name='mlc_commit_'..uid, caption='Save & Close'}

	return gui_t
end


function comb_gui_class:insert_history(gui_t, code)
	local gui_name = gui_t.gui.name
	local n, hist_log = global.historystate[gui_name], global.history[gui_name]
	code = code:match('^%s*(.-)%s*$')..'\n' -- normalize leading/trailing spaces
	-- XXX: do not store empty strings

	if hist_log[n] == code then n = n
	elseif #hist_log == n then
		n = n + 1
		table.insert(hist_log, code)
		global.historystate[gui_name] = n
	else
		n = n + 1
		hist_log[n] = code
		global.historystate[gui_name] = n
		for a = n + 1, #hist_log do hist_log[a] = nil end
	end

	while n > conf.code_history_max do
		n = n - 1
		table.remove(hist_log, 1)
		global.historystate[gui_name] = n
	end

	gui_manager:set_history_btns_state(gui_t)
end

function comb_gui_class:close(eid)
	local gui_t = global.guis[eid]
	if gui_t and gui_t.gui then gui_t.gui.destroy() end
	global.guis[eid] = nil
end

function comb_gui_class:save_code(eid, code)
	local gui_t = global.guis[eid]
	if not gui_t then return end
	local clean_code = code_error_highlight(code or gui_t.code_tb.text)
	load_code_from_gui(clean_code, eid)
	gui_t.code_tb.text = clean_code
end

function comb_gui_class:on_gui_click(eid, elname, preset_n, ev)
	local gui_t = global.guis[eid]
	local gui = gui_t.gui

	if elname == 'ok_btn' then self:save_code(eid)
	elseif elname == 'clear_btn' then
		self:save_code(eid, '')
		self:on_gui_text_changed(eid, {element=gui_t.code_tb})
	elseif elname == 'x_btn' then self:close(eid)
	elseif elname == 'help_btn' then help_window_toggle(ev.player_index)

	elseif elname == 'preset_btn' then
		local id = preset_n + 1
		if ev.button == defines.mouse_button_type.left then
			local code_textbox = gui_t.code_tb
			if global.presets[id] then
				code_textbox.text = global.presets[id]
				global.textboxes[gui.name] = code_textbox.text
				if not global.history[gui.name] then
					global.history[gui.name] = {code_textbox.text}
					global.historystate[gui.name] = 1
				else self:insert_history(gui_t, code_textbox.text) end
			else
				global.presets[id] = code_textbox.text
				ev.element.style = 'green_button'
				ev.element.tooltip = preset_help_tooltip(global.presets[id])
			end
		elseif ev.button == defines.mouse_button_type.right then
			global.presets[id] = nil
			ev.element.style = 'button'
			ev.element.tooltip = preset_help_tooltip()
		end

	elseif elname == 'bw_btn' then
		-- XXX: mention keys in the tooltip
		if ev.button == defines.mouse_button_type.right then self:history(gui_t, -5)
		elseif ev.button == defines.mouse_button_type.right and ev.shift then self:history(gui_t, -50)
		else self:history(gui_t, -1) end
	elseif elname == 'fw_btn' then
		if ev.button == defines.mouse_button_type.right then self:history(gui_t, 5)
		elseif ev.button == defines.mouse_button_type.right and ev.shift then self:history(gui_t, 50)
		else self:history(gui_t, 1) end
	end

end

function comb_gui_class:on_gui_text_changed(eid, ev)
	if ev.element.name ~= 'mlc_code' then return end
	if not global.textboxes then global.textboxes = {} end
	local gui_t = global.guis[eid]
	local gui_name = gui_t.gui.name
	if not global.history[gui_name] then
		global.history[gui_name] = {ev.element.text}
		global.historystate[gui_name] = 1
	else self:insert_history(gui_t, ev.element.text) end
	global.textboxes[gui_name] = ev.element.text
end

function comb_gui_class:history(gui_t, interval)
	local gui_name = gui_t.gui.name
	local eid = find_eid_for_gui_element(gui_t.gui)
	local codebox = global.guis[eid].code_tb
	local n = math.min(
		#global.history[gui_name],
		math.max(1, global.historystate[gui_name] + interval) )
	global.historystate[gui_name] = n
	codebox.text = global.history[gui_name][n]
	gui_manager:set_history_btns_state(gui_t)
	global.textboxes[gui_name] = codebox.text
end


return {gui_manager, comb_gui_class}
