-- Full Uniform Recolor mod for Surviving Mars
-- Feel free to use anything here in any way you want
-- License - http://www.wtfpl.net/txt/copying/

-- Set revert_icons = true to remove/revert all changes made by this mod
local revert_icons = false
-- local revert_icons = true

-- mod_id is used to get mod path, and is listed in metadata.lua
local mod_id = 'Fh4vwgZ'
local mod_path_fallback = 'AppData/Mods/full-uniform-recolor/'

-- icon_replace_map looks like e.g.:
--   'UI/Icons/Colonists/IP/IP_Medic_Female.tga' -> '{mod}/UI/ip-medic-f.tga'
local icon_replace_map = {}
local function make_icon_replace_map(mod_path)
	local map = {}
	if revert_icons then return map end
	local specs, genders, templates =
		{Geologist='geo', Botanist='botan', Medic='medic'}, {Female='f', Male='m'},
		{ ['UI/Icons/Colonists/IP/IP_%s_%s.tga'] = mod_path..'UI/ip-%s-%s.tga',
			['UI/Icons/Colonists/Pin/%s_%s.tga'] = mod_path..'UI/pin-%s-%s.tga' }
	for spec_src, spec_dst in pairs(specs) do
		for g_src, g_dst in pairs(genders) do
			for tpl_src, tpl_dst in pairs(templates) do
				map[string.format(tpl_src, spec_src, g_src)] =
					string.format(tpl_dst, spec_dst, g_dst)
	end end end
	return map
end

local ColonistGSI_base = Colonist.GetSpecializationIcons
function Colonist:GetSpecializationIcons()
	local ip, pin = ColonistGSI_base(self)
	ip = icon_replace_map[ip] or ip
	pin = icon_replace_map[pin] or pin
	return ip, pin
end

function OnMsg.LoadGame()
	local mod_path
	if Mods[mod_id] then mod_path = Mods[mod_id]:GetModRootPath()
	else mod_path = mod_path_fallback end -- fallback option
	icon_replace_map = make_icon_replace_map(mod_path)

	for _,c in ipairs(GetObjects{class='Colonist', area='realm'}) do
		c.ip_specialization_icon, c.pin_specialization_icon = c:GetSpecializationIcons()
end end
