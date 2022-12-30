local VectorVisualizer = {}
local THICKNESS = 0.1
function VectorVisualizer.VisualizeVector(Direction: Vector3?, Origin: Vector3?): Part
    Direction = Direction or Vector3.xAxis
    Origin = Origin or Vector3.zero
    local Part = Instance.new("Part")
    Part.CFrame = CFrame.lookAt(Origin + (Direction / 2), Origin + Direction * 2)
    Part.Size = Vector3.new(THICKNESS, THICKNESS, Direction.Magnitude)
    Part.CanCollide = false
    Part.CanTouch = false
    Part.CanQuery = false
    Part.Parent = workspace

    return Part
end
function VectorVisualizer.VisualizeUnitVector(Direction: Vector3?, Origin: Vector3?): Part
    return VectorVisualizer.VisualizeVector(Direction.Unit, Origin)
end
function VectorVisualizer.UpdateVector(Part: Part, Direction: Vector3?, Origin: Vector3?)
    Direction = Direction or Vector3.xAxis
    Origin = Origin or Vector3.zero
    Part.CFrame = CFrame.lookAt(Origin + (Direction / 2), Origin + Direction * 2)
    Part.Size = Vector3.new(THICKNESS, THICKNESS, Direction.Magnitude)
end
function VectorVisualizer.UpdateUnitVector(Part: Part, Direction: Vector3?, Origin: Vector3?)
    VectorVisualizer.UpdateVector(Part, Direction.Unit, Origin)
end
return VectorVisualizer