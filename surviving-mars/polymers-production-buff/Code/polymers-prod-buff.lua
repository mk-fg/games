-- Polymers Production Buff mod for Surviving Mars
-- Feel free to use anything here in any way you want
-- License - http://www.wtfpl.net/txt/copying/

local function init_modifiers()
	-- Default production value = 9000
	local prod_increase = 0 -- use either this or *_percent, not both

	-- Increase/reduce by percent value - much simplier
	local prod_percent = 50

	CreateLabelModifier(
		'fg-polymer-production-buff',
		'PolymerPlant',
		'production_per_day1',
		prod_increase, prod_percent ) -- 10x
end

local function remove_modifiers()
	RemoveLabelModifier('fg-polymer-production-buff', 'PolymerPlant', 'production_per_day1')
end

function OnMsg.LoadGame() init_modifiers() end
-- function OnMsg.LoadGame() remove_modifiers() end
