-- Green Mars Terraforming Lightmodel mod for Surviving Mars
-- Feel free to use anything here in any way you want
-- License - http://www.wtfpl.net/txt/copying/

GlobalVar('g_mkfg_lightmodel_disabled')

local function set_lightmodel_list()
	if not g_mkfg_lightmodel_disabled
		then SetNormalLightmodelList('Dreamers')
		else SetNormalLightmodelList('TheMartian') end
end

-- LoadGame/CityStart seem to be too early
function OnMsg.MarsResume() set_lightmodel_list() end

function OnMsg.ClassesPostprocess()
	local function action_replace(action)
		local gs, act = XTemplates.GameShortcuts
		for n, act in pairs(gs) do
			act = type(act) == 'table' and act.ActionId
			if act == action.ActionId
				then DoneObject(act); table.remove(gs, n) end
		end
		act = {
			'ActionMode', 'Game',
			'ActionBindable', true,
			'replace_matching_id', true,
			'IgnoreRepeated', true }
		for k, v in pairs(action) do act[#act+1] = k; act[#act+1] = v end
		gs[#gs+1] = PlaceObj('XTemplateAction', act)
	end
	action_replace{
		ActionName = 'Green Mars Toggle',
		ActionId = 'mkfg_green-mars_toggle',
		ActionShortcut = 'Ctrl-Alt-Shift-K',
		OnAction = function()
			g_mkfg_lightmodel_disabled = not g_mkfg_lightmodel_disabled
			set_lightmodel_list()
		end }
end
