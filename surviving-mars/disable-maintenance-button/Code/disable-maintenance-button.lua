-- Disable Maintenance button mod for Surviving Mars
-- Feel free to use anything here in any way you want
-- License - http://www.wtfpl.net/txt/copying/

local RequestMaintenance_base = RequiresMaintenance.RequestMaintenance

function RequiresMaintenance:RequestMaintenance()
	if not self.mkfg_maintenance_disabled
		then RequestMaintenance_base(self) end
end

local function toggle_maintenance(obj)
	obj.mkfg_maintenance_disabled = not obj.mkfg_maintenance_disabled
	if not obj.mkfg_maintenance_disabled
		then obj:AccumulateMaintenancePoints(0)
		else obj:ResetMaintenanceRequests() end
end


function OnMsg.ClassesBuilt()
	local loc_id_base = 0x6d6b66675f0100 -- mkfg_<mod_n><n>
	local function TT(s)
		loc_id_base = loc_id_base + 1
		return T{loc_id_base, s}
	end

	local s_ro_tpl = (
		'Toggles whether drones will patch building up when maintenance is required.'
		.. '<newline>Maintenance: <em>%s</em>' )
	local s_ro_on, s_disable, s_ro_off, s_enable =
		TT(s_ro_tpl:format('enabled')), TT('<left_click> Disable Maintenance'),
		TT(s_ro_tpl:format('disabled')), TT('<left_click> Enable Maintenance')

	local dst = XTemplates.sectionCustom
	local n = table.find(dst, 'mkfg_maintenance_toggle', true)
	if n then DoneObject(dst[n]); table.remove(dst, n) end
	dst[#dst+1] = PlaceObj('XTemplateTemplate', {
		'mkfg_maintenance_toggle', true,
		'__template', 'InfopanelButton',
		'__context_of_kind', 'BaseBuilding',
		'__condition',
			function(parent, context)
				return not context.destroyed
					and context:DoesRequireMaintenance()
			end,
		'Icon', 'UI/Icons/IPButtons/pierce.tga',
		'RolloverText', s_ro_on,
		'RolloverTitle', TT('Maintenance Toggle'),
		'RolloverHint', TT('<left_click> Toggle'),
		'OnPress',
			function(self, gamepad)
				PlayFX('UIChangePriority')
				toggle_maintenance(self.context)
				ObjModified(self.context)
			end,
		'OnContextUpdate',
			function(self, context)
				if not context.mkfg_maintenance_disabled then
					self:SetIcon('UI/Icons/IPButtons/pierce.tga')
					self:SetRolloverText(s_ro_on)
					self:SetRolloverHint(s_disable)
				else
					self:SetIcon('UI/Icons/IPButtons/salvage_off.tga')
					self:SetRolloverText(s_ro_off)
					self:SetRolloverHint(s_enable)
				end
			end })

end
