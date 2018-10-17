return PlaceObj('ModDef', {
	'title', "Disable Maintenance button",
	'description', "Adds button to toggle whether drones will patch building up when maintenance is required.\nUnmaintained building will keep working until it finally breaks down.\nDisabling/enabling maintenance mode should have immediate effect on drones, stopping ones that are en-route if necessary.",
	'image', "thumb.png",
	'last_changes', "Initial release.",
	'id', "mk-fg/disable-maintenance-button",
	'steam_id', "1541524054",
	'author', "mk-fg",
	'version', 2,
	'lua_revision', LuaRevision,
	'code', {"Code/disable-maintenance-button.lua"},
	'saved', 1539814130,
})
