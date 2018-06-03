local changes = {}

local utils = require('libs/utils')

function changes.set_corrosion_resistance()
	-- Corrosion resistance is 100% (immune) for everything but:
	--  - Entities in affected_categories (data.raw keys) but not in immune_prototypes
	--  - Entities in affected_prototypes from any other categories
	-- Entities in vulnerable_categories have no resistance and take extra damage.
	-- Affected entities have corrosion resistance equal to acid resistance.

	local affected_prototypes = utils.t('player')
	local immune_prototypes = utils.t('small-electric-pole')
	local affected_categories = utils.t([[
		electric-pole radar offshore-pump pump
		gate wall ammo-turret electric-turret
		boiler solar-panel reactor
		storage-tank container car locomotive armor ]])
	local vulnerable_categories = utils.t('boiler solar-panel reactor')

	local corrosion_immunity = {type='corrosion', decrease=0, percent=100}
	local corrosion_vulnerability = {type='corrosion', decrease=-2, percent=0}

	local function set_corrosion_resistance(proto, preset)
		-- Set corrosion resistance to preset, or equal to acid resistance if nil
		if proto.resistances then
			if preset then table.insert(proto.resistances, preset)
			else
				for _, acid_resist in pairs(proto.resistances) do
					if acid_resist.type == 'acid' then goto acid_resist_found end end
				acid_resist = nil ::acid_resist_found::
				if acid_resist then
					table.insert( proto.resistances,
						{type='corrosion', decrease=resist.decrease, percent=resist.percent} )
				end
			end
		elseif preset then
			if proto.max_health and proto.max_health > 0 then
				proto.resistances = {}
				table.insert(proto.resistances, preset)
			end
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

function changes.update_tech_recipies()
	if data.raw['technology']['solar-energy'] then
		table.insert(
			data.raw['technology']['solar-energy'].effects,
			{type='unlock-recipe', recipe='UV-lamp'} )
	end
end

return changes
