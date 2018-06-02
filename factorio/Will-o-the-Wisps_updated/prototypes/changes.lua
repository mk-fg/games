local changes = {}

local function getResistance(resistances, type)
		for _, resist in pairs(resistances) do
				if resist.type == type then
						return resist
				end
		end
		return nil
end

function changes.updateResistances()
		-- preset corrosion resistance for everything excluding the following
		local excludePrototype = {
				["player"]=true
		}
		local excludeCategory = {
				["electric-pole"]=true,
				["radar"]=true,
				["offshore-pump"]=true,
				["pump"]=true,

				["gate"]=true,
				["wall"]=true,
				["ammo-turret"]=true,
				["electric-turret"]=true,

				["boiler"]=true,
				["solar-panel"]=true,

				["storage-tank"]=true,
				["container"]=true,
				["car"]=true,
				["locomotive"]=true,
				["armor"]=true
		}

		local corrosionResistance={type = "corrosion", decrease = 0, percent = 100};
		local function addCorrosionResistance(prototype)
				if prototype.resistances then
						table.insert(prototype.resistances, corrosionResistance);
				else
						if prototype.max_health and prototype.max_health > 0 then
								prototype.resistances = {}
								table.insert(prototype.resistances, corrosionResistance);
						end
				end
		end

		for categoryName, category in pairs(data.raw) do
				if not excludeCategory[categoryName] then
						-- set absolute corrosion resistance (except of entities from list)
						for prototypeName, prototype in pairs(category) do
								if not excludePrototype[prototypeName] then
										addCorrosionResistance(prototype)
								end
						end
				else
						-- set corrosion resistance equal to acid resistance
						for prototypeName, prototype in pairs(category) do
										if prototype.resistances then
												local resist = getResistance(prototype.resistances, "acid")
												if resist then
														table.insert(prototype.resistances, {type = "corrosion", decrease = resist.decrease, percent = resist.percent});
												end
										end

										-- add resistance to the small poles (because they are manufactured from an alien wood :) )
										if prototypeName == "small-electric-pole" then
												addCorrosionResistance(prototype)
										end

										-- extra damage for solar plants
										if categoryName == "solar-panel" then
												prototype.resistances = {}
												table.insert(prototype.resistances, {type = "corrosion", decrease = -2, percent = 0});
										end
						end
				end
		end
end

function changes.updateAlienTechnology()
	if(data.raw['technology']['solar-energy']) then
				table.insert(data.raw['technology']['solar-energy'].effects,
		{
			type = "unlock-recipe",
			recipe = "UV-lamp"
		})
	end
end

return changes
