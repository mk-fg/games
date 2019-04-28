
local function add_tech_unlock(tech, recipe)
	tech = data.raw.technology[tech]
	if not tech then return end
	table.insert(tech.effects, {type='unlock-recipe', recipe=recipe})
end

add_tech_unlock('circuit-network', 'circuit-electric-pole')
