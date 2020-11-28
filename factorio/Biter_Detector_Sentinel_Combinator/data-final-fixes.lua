-- Compatibility fix for older SchallCircuitGroup mod version, before circuit-input subgroup was introduced
if mods.SchallCircuitGroup then
	local subgroups = data.raw['item-subgroup']
	for _, sg in ipairs{'circuit-input', 'circuit-combinator', 'circuit-network'} do
		if not subgroups[sg] then goto skip end
		for _, proto in ipairs{'sentinel-combinator', 'sentinel-alarm'} do
			proto = data.raw.item[proto]
			if proto.subgroup ~= sg then proto.subgroup = sg end
		end
		break
	::skip:: end
end
