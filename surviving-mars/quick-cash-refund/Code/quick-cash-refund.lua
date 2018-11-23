-- Quick Cash Refund mod for Surviving Mars
-- Feel free to use anything here in any way you want
-- License - http://www.wtfpl.net/txt/copying/

local function destroy(obj)
	if obj
			and type(obj) == 'table'
			and obj.delete
			and (not obj.IsValid or obj:IsValid())
		then DoneObject(obj) end
end

function OnMsg.ClassesPostprocess()
	local function action_replace(action)
		local gs, act = XTemplates.GameShortcuts
		for n, act in pairs(gs) do
			act = type(act) == 'table' and act.ActionId
			if act == action.ActionId then destroy(act); table.remove(gs, n) end
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
		ActionName = 'Quick Cash Refund',
		ActionId = 'mkfg_quick-cash-refund',
		ActionShortcut = 'Ctrl-Alt-Shift-L',
		OnAction = function() ChangeFunding(500) end }
end
