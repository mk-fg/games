-- University Entrance Exams mod for Surviving Mars
-- Feel free to use anything here in any way you want
-- License - http://www.wtfpl.net/txt/copying/

local MUCanTrain_base = MartianUniversity.CanTrain
function MartianUniversity:CanTrain(unit)
	return not unit.traits.Idiot and MUCanTrain_base(self, unit)
end
