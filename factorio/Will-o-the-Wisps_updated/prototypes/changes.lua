local changes = {}

local utils = require('libs/utils')

function changes.set_corrosion_resistance()
	-- Corrosion resistance is 100% (immune) for everything but:
	--  - Entities in affected_categories (data.raw keys) but not in immune_prototypes
	--  - Entities in affected_prototypes from any other categories
	-- Entities in vulnerable_categories have no resistance and take extra damage.
	-- Affected entities have corrosion resistance equal to acid resistance.

	local affected_prototypes = utils.t('player oil-refinery centrifuge')
	local immune_prototypes = {}

	local affected_categories = utils.t([[
		gate wall ammo-turret electric-turret radar car armor
		offshore-pump boiler solar-panel reactor ]])
	local vulnerable_categories = utils.t('boiler solar-panel reactor')

	local corrosion_immunity = {type='corrosion', decrease=0, percent=100}
	local corrosion_vulnerability = {type='corrosion', decrease=-2, percent=0}

	local function set_corrosion_resistance(proto, preset)
		-- Set corrosion resistance to preset, or equal to acid resistance if nil
		if proto.resistances then
			if preset then table.insert(proto.resistances, preset)
			else
				for _, resist in pairs(proto.resistances) do if resist.type == 'acid' then
					table.insert( proto.resistances,
						{type='corrosion', decrease=resist.decrease, percent=resist.percent} )
					break
			end end end
		elseif preset and proto.max_health and proto.max_health > 0 then
			proto.resistances = {}
			table.insert(proto.resistances, preset)
		end
	end

	for cat_name, cat in pairs(data.raw) do for proto_name, proto in pairs(cat) do
		local preset = corrosion_immunity
		if immune_prototypes[proto_name] then
		elseif vulnerable_categories[cat_name] then preset = corrosion_vulnerability
		elseif affected_categories[cat_name] then preset = nil
		elseif affected_prototypes[proto_name] then preset = nil
		end
		set_corrosion_resistance(proto, preset)
	end end
end

function changes.set_electric_immunity()
	-- Set resistance to wisps' electric attacks to rails, so that they'd ignore them
	local electric_immunity = {type='electric', decrease=0, percent=100}
	local immune_categories = utils.t('straight-rail curved-rail')

	local function set_electric_immunity(proto)
		if proto.resistances then
			for n, resist in pairs(proto.resistances) do
				if resist.type == 'electric' then
					table.remove(proto.resistances, n); break
			end end
		elseif proto.max_health and proto.max_health > 0 then
			proto.resistances = {}
		else goto skip end
		table.insert(proto.resistances, electric_immunity)
	::skip:: end

	for cat_name, cat in pairs(data.raw) do
		if immune_categories[cat_name] then
			for proto_name, proto in pairs(cat) do
				set_electric_immunity(proto)
	end end end
end

function changes.update_tech_recipes()
	local function add_tech_unlock(tech, recipe)
		tech = data.raw.technology[tech]
		if not tech then return end
		table.insert(tech.effects, {type='unlock-recipe', recipe=recipe})
	end
	add_tech_unlock('solar-energy', 'UV-lamp')
	add_tech_unlock('combat-robotics', 'wisp-drone-blue-capsule')
end

return changes
