-- Green Mars Terraforming Lightmodel mod for Surviving Mars
-- Feel free to use anything here in any way you want
-- License - http://www.wtfpl.net/txt/copying/

local lightmodel_list = 'Dreamers'
-- local lightmodel_list = 'TheMartian'

local function set_lightmodel_list()
	SetNormalLightmodelList(lightmodel_list)
end

-- LoadGame/CityStart seem to be too early
function OnMsg.MarsResume() set_lightmodel_list() end
