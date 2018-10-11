-- Unlock Oval Dome mod for Surviving Mars
-- Heavily inspired by FGRaptor's Oval Dome Unlocked mod, but less clunky.
-- Feel free to use anything here in any way you want
-- License - http://www.wtfpl.net/txt/copying/

local function unlock_check()
	if not IsTechDiscovered('MultispiralArchitecture')
		then return end
	if next(UICity.labels.DomeMedium or empty_table)
			and next(UICity.labels['Dome Spires'] or empty_table)
		then DiscoverTech('MultispiralArchitecture') end
end

function OnMsg.GameTimeStart() unlock_check() end
function OnMsg.LoadGame() unlock_check() end

function OnMsg.ConstructionComplete()
	if not IsTechDiscovered('MultispiralArchitecture')
		then return end
	DelayedCall(500, unlock_check)
end
