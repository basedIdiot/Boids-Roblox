local BoidGroup = {}
BoidGroup.__index = {}
function BoidGroup.new(ID: string)
	local self = {
		Id = ID,
		Include = {},
		Exclude = {},
	}
	return setmetatable(self, BoidGroup)
end
function BoidGroup.hi() end
return BoidGroup
