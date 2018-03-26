-- Geologist Uniform Recolor mod for Surviving Mars
-- Feel free to use anything here in any way you want
-- License - http://www.wtfpl.net/txt/copying/

-- Set revert_icons = true to remove/revert all changes made by this mod
local revert_icons = false
-- local revert_icons = true

local mod_path = 'AppData/Mods/geologist-uniform-recolor/'
local icon_replace_map = {
	['UI/Icons/Colonists/IP/IP_Geologist_Male.tga'] = mod_path..'UI/ip-geo-m.tga',
	['UI/Icons/Colonists/IP/IP_Geologist_Female.tga'] = mod_path..'UI/ip-geo-f.tga',
	['UI/Icons/Colonists/Pin/Geologist_Male.tga'] = mod_path..'UI/pin-geo-m.tga',
	['UI/Icons/Colonists/Pin/Geologist_Female.tga'] = mod_path..'UI/pin-geo-f.tga' }

if revert_icons then for k,v in pairs(icon_replace_map) do
	-- Flip icon_replace_map to replace all existing icons in the opposite direction
	icon_replace_map[v], icon_replace_map[k] = icon_replace_map[k], nil
end end

local ColonistGSI_base = Colonist.GetSpecializationIcons
function Colonist:GetSpecializationIcons()
	local ip, pin = ColonistGSI_base(self)
	ip = icon_replace_map[ip] or ip
	pin = icon_replace_map[pin] or pin
	return ip, pin
end

function OnMsg.LoadGame()
	for _,c in ipairs(GetObjects{class='Colonist'}) do
		c.ip_specialization_icon, c.pin_specialization_icon = c:GetSpecializationIcons()
	end
end
