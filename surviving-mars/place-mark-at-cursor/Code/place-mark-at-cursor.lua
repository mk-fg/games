-- Place Mark at Cursor mod for Surviving Mars
-- Feel free to use anything here in any way you want
-- License - http://www.wtfpl.net/txt/copying/

-- Colors for bound 1-9 keys (i.e. up to 9), in the same order
local key_colors = {
	0xe6194b, 0x800000, 0x4363d8, 0x000075, 0x3cb44b,
	0x008080, 0x00ff00, 0x000000, 0xaaffc3 }

local action_id_tpl = 'mkfg_color-tile_%s'
DefineClass.mkfg_tile = {__parents={'CObject'}, entity='GridTile'}
GlobalVar('g_mkfg_color_marks')


local function toggle_cursor_tile_color(hex_color)
	if not g_mkfg_color_marks
		then g_mkfg_color_marks = {} end
	local pos = GetTerrainCursor()
	if not pos then return end
	local q, r = WorldToHex(pos)
	local key = ('%s:%s'):format(q, r)
	if g_mkfg_color_marks[key] then
		DoneObject(g_mkfg_color_marks[key])
		g_mkfg_color_marks[key] = nil
	else
		local x, y = HexToWorld(q, r)
		local tile = PlaceObject('mkfg_tile')
		tile:SetPos(point(x, y):SetStepZ():AddZ(100))
		tile:SetColorModifier(hex_color - 0xffffff)
		g_mkfg_color_marks[key] = tile
	end
end

local function remove_tiles()
	for key, tile in pairs(g_mkfg_color_marks or {})
		do DoneObject(tile) end
	g_mkfg_color_marks = {}
end


local function action_replace(action)
	local gs, act = XTemplates.GameShortcuts
	for n, act in pairs(gs) do
		act = type(act) == 'table' and act.ActionId
		if act == action.ActionId then table.remove(gs, n) end
	end
	act = {
		'ActionMode', 'Game',
		'ActionBindable', true,
		'replace_matching_id', true,
		'IgnoreRepeated', true }
	for k, v in pairs(action) do act[#act+1] = k; act[#act+1] = v end
	gs[#gs+1] = PlaceObj('XTemplateAction', act)
end

local function init_actions()
	for n = 1, 9 do
		local color = key_colors[n]
		if not color then goto skip end
		action_replace{
			ActionName = ('Place Mark [%o]'):format(color),
			ActionId = action_id_tpl:format(n),
			ActionShortcut = ('Ctrl-%s'):format(n),
			OnAction = function() toggle_cursor_tile_color(color) end }
	::skip:: end
	action_replace{
		ActionName = 'Remove All Marks',
		ActionId = action_id_tpl:format(0),
		ActionShortcut = 'Ctrl-0',
		OnAction = function() remove_tiles() end }
end

local function remove_actions()
	local gs = XTemplates.GameShortcuts
	for n, act in pairs(gs) do
		act = type(act) == 'table' and act.ActionId
		for m = 0, 9 do if act == action_id_tpl:format(n)
			then table.remove(gs, n) end end
	end
end


function OnMsg.ClassesPostprocess() init_actions() end
-- function OnMsg.ClassesPostprocess() remove_actions() end
