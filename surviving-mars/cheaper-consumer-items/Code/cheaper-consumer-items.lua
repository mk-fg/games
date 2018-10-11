-- Cheaper Consumer Items mod for Surviving Mars
-- Feel free to use anything here in any way you want
-- License - http://www.wtfpl.net/txt/copying/

local function init_modifiers()
	-- Default consumption_amount=200 - 0.2 polymers/electronics per visit
	local reduction_amount = 0 -- use either this or reduction_percent, not both

	-- Add/reduce by percent value - much simplier
	local reduction_percent = -70

	CreateLabelModifier(
		'fg-cheaper-consumer-items-art-workshop',
		'ShopsJewelry',
		'consumption_amount',
		reduction_amount, reduction_percent )

	CreateLabelModifier(
		'fg-cheaper-consumer-items-electronics-shop',
		'ShopsElectronics',
		'consumption_amount',
		reduction_amount, reduction_percent )

end

local function remove_modifiers()
	RemoveLabelModifier(
		'fg-cheaper-consumer-items-art-workshop',
		'ShopsJewelry', 'consumption_amount' )
	RemoveLabelModifier(
		'fg-cheaper-consumer-items-electronics-shop',
		'ShopsElectronics', 'consumption_amount' )
end

function OnMsg.LoadGame() init_modifiers() end
-- function OnMsg.LoadGame() remove_modifiers() end
