-- Compatibility fix for older SchallCircuitGroup mod version, before circuit-input subgroup was introduced
if mods.SchallCircuitGroup then
	local subgroups, proto = data.raw['item-subgroup'], data.raw.item.mlc
	for _, sg in ipairs{'circuit-input', 'circuit-combinator', 'circuit-network'} do
		if not subgroups[sg] then goto skip end
		if proto.subgroup ~= sg then proto.subgroup = sg end
		break
	::skip:: end
end
