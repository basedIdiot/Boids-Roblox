local ProximityPromptService = game:GetService("ProximityPromptService")
local BoxContainer = {}
BoxContainer.__index = {}

export type BoxContainer = {
    Position: Vector3,
	Size: Vector3,

}

function BoxContainer.new(Position: Vector3, Size: Vector3) 
    return setmetatable({
        Position = Position,
        Size = Size
    }, BoxContainer)
end

function BoxContainer.__index:IsInside(Position): boolean
    local MinX = self.Position.X - self.Size.X / 2
    local MaxX = self.Position.X + self.Size.X / 2
    local MinY = self.Position.Y - self.Size.Y / 2
    local MaxY = self.Position.Y + self.Size.Y / 2
    local MinZ = self.Position.Z - self.Size.Z / 2
    local MaxZ = self.Position.Z + self.Size.Z / 2
	if Position.X > MaxX or Position.X < MinX then
		return false
	end
	if Position.Y > MaxY or Position.Y < MinY then
		return false
	end
	if Position.Z > MaxZ or Position.Z < MinZ then
		return false
	end
	return true
end
function BoxContainer.__index:ConstrainPosition(Position)
    local objectCoords = Position - self.Position
    local scalingFactor = 2/math.max(
        math.abs(objectCoords.X/(self.Size.X/4)),
        math.abs(objectCoords.Y/(self.Size.Y/4)),
        math.abs(objectCoords.Z/(self.Size.Z/4)))
    return (objectCoords*scalingFactor) + self.Position
end
return BoxContainer
