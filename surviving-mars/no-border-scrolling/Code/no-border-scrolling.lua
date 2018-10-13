local function disable_scrolling()
	cameraRTS.SetProperties(1, {ScrollBorder=-10000})
	const.DefaultCameraRTS.ScrollBorder = -10000
end

function OnMsg.LoadGame() disable_scrolling() end
function OnMsg.GameTimeStart() disable_scrolling() end
