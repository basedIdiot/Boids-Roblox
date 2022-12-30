--!strict
local Boid = {}
Boid.__index = {}

local BoxContainer = require(script.BoxContainer)
type BoxContainer = BoxContainer.BoxContainer

local VectorVisualizer = require(script.VectorVisualizer)

local RunService = game:GetService("RunService")

local AutoUpdate = true -- determines whether the script will automatically update the boids position each frame
-- Good for benchmarking certain functions

local DIRECTION_UPDATE_FREQUENCY = 1 / 10

local ZERO_VECTOR = Vector3.zero
local ONE_VECTOR = Vector3.one

local MIN_SPEED = 1
local MAX_SPEED = 10
local MAX_ACCELERATION = 5

local RANGE = 20
local VIEW_ANGLE = math.pi -- measured in radians
local AVOID_RADIUS = 1

local SEPERATION_WEIGHT = 10
local ALIGN_WEIGHT = 1
local COHESIVE_WEIGHT = 1
local TARGET_WEIGHT = 10

local BoidId = 0

local RandomGenerator = Random.new()
local BoidArray = {}

export type Boid = {
	Model: BasePart | Model,

	Position: Vector3,
	Velocity: Vector3,
	Acceleration: Vector3,

	Range: number,
	ViewAngle: number,
	AvoidRadius: number,

	MinSpeed: number,
	MaxSpeed: number,
	MaxAcceleration: number,

	Target: Vector3?,

	Id: number,
}

local function GetAngleBetweenVectors(V1: Vector3, V2: Vector3): number
	return math.acos(V1:Dot(V2) / V1.Magnitude / V2.Magnitude)
end
local function ClampVector(Vector: Vector3, Max: number): Vector3
	if Vector.Magnitude >= Max then
		return Vector.Unit * Max
	end
	return Vector
end
local function CopyArray(Array: { [number]: Boid }): { [number]: Boid }
	local Result = {}
	for Index, Value in ipairs(Array) do
		Result[Index] = Value
	end
	return Result
end

function Boid.GetBoids(): { [number]: Boid }
	return CopyArray(BoidArray)
end
function Boid.Pause()
	AutoUpdate = false
end
function Boid.Unpause()
	AutoUpdate = true
end
function Boid.new(
	Model: BasePart | Model,
	Position: Vector3?,
	Velocity: Vector3?,
	Range: number?,
	ViewAngle: number?
): Boid
	local NewModel = Model:Clone() :: Instance
	NewModel.Parent = workspace.Boids
	local self = {
		Model = NewModel,
		--VectorVisualizer = VectorVisualizer.VisualizeVector(Vector3.new(), Vector3.new()),

		Position = Position or ZERO_VECTOR,
		Velocity = Velocity or ONE_VECTOR,
		Acceleration = ONE_VECTOR,

		Range = Range or RANGE,
		ViewAngle = ViewAngle or VIEW_ANGLE,
		AvoidRadius = AVOID_RADIUS,

		MinSpeed = MIN_SPEED,
		MaxSpeed = MAX_SPEED,
		MaxAcceleration = MAX_ACCELERATION,

		Target = nil,

		Id = BoidId + 1,
	}
	BoidId += 1
	table.insert(BoidArray, self)
	return setmetatable(self, Boid)
end
function Boid.__index:Destroy()
	self.Model:Destroy()
	if self.VelocityPart then
		self.VelocityPart:Destroy()
	end
	if self.AccelerationPart then
		self.AccelerationPart:Destroy()
	end
	table.remove(BoidArray, table.find(BoidArray, self))
end
function Boid.__index:GetDirection(): Vector3
	return self.Velocity.Unit
end
function Boid.__index:CalculateAcceleration(): Vector3?
	local AverageHeading = ZERO_VECTOR
	local AveragePosition = ZERO_VECTOR
	local SeperationHeading = ZERO_VECTOR
	local TargetHeading = ZERO_VECTOR
	if self.Target then
		TargetHeading = (self.Target - self.Position) * TARGET_WEIGHT
	end
	local NumBoids = 0
	local AvoidBoids = 0
	for _, OtherBoid: Boid in ipairs(BoidArray) do
		if OtherBoid.Id == self.Id then
			continue
		end
		local Offset = OtherBoid.Position - self.Position
		local Distance = Offset.Magnitude

		-- Distance check
		if Distance > self.Range then
			continue
		end

		-- FOV check
		if GetAngleBetweenVectors(self.Position, OtherBoid.Position) > self.ViewAngle then
			continue
		end
		AverageHeading += OtherBoid.Velocity
		AveragePosition += OtherBoid.Position
		if Distance < AVOID_RADIUS then
			-- Ensures no division by zero
			SeperationHeading -= Offset / (Distance + 1)
			AvoidBoids += 1
		end
		NumBoids += 1
	end
	if NumBoids > 0 then
		AverageHeading /= NumBoids
		AverageHeading *= ALIGN_WEIGHT
		AveragePosition = AveragePosition / NumBoids - self.Position
		AveragePosition *= COHESIVE_WEIGHT
	end
	-- Dividing by 0 results in nan values, which caused me way too much headache :/
	if AvoidBoids > 0 then
		SeperationHeading /= AvoidBoids
		SeperationHeading *= SEPERATION_WEIGHT
	end
	return ClampVector(AverageHeading + AveragePosition + SeperationHeading + TargetHeading, self.MaxAcceleration)
end
function Boid.__index:UpdateVelocity(dt: NumberValue)
	local Acceleration = self:CalculateAcceleration()
	if Acceleration then
		self.Acceleration = Acceleration
		self.Velocity += Acceleration * dt
		self.Velocity = ClampVector(self.Velocity, self.MaxSpeed)
	end
end
function Boid.__index:UpdatePosition(dt: NumberValue)
	self.Position += self.Velocity * dt
	if self.BoxContainer then
		if not self.BoxContainer:IsInside(self.Position) then
			self.Position = self.BoxContainer:ConstrainPosition(-(self.Position - self.BoxContainer.Position) + self.BoxContainer.Position)
		end
	end
end
function Boid.__index:ShowVelocity()
	if self.VelocityPart then
		return
	end
	self.VelocityPart = VectorVisualizer.VisualizeUnitVector(self.Velocity, self.Position)
	self.VelocityPart.Color = Color3.new(0.686274, 0.086274, 0.086274)
end
function Boid.__index:HideVelocity()
	if self.VelocityPart then
		self.VelocityPart:Destroy()
	end
end
function Boid.__index:ShowAcceleration()
	if self.AccelerationPart then
		return
	end
	self.AccelerationPart = VectorVisualizer.VisualizeUnitVector(self.Acceleration, self.Position)
	self.AccelerationPart.Color = Color3.new(0.078431, 0.701960, 0.286274)
end
function Boid.__index:HideAcceleration()
	if self.AccelerationPart then
		self.AccelerationPart:Destroy()
	end
end

-- Position update --
RunService.Heartbeat:Connect(function(DeltaTime)
	if not AutoUpdate then
		return
	end
	local PartTable = table.create(#BoidArray)
	local PositionTable = table.create(#BoidArray)
	for _, Boid in ipairs(BoidArray) do
		Boid:UpdatePosition(DeltaTime)
		if Boid.Position ~= Boid.Position then 
			error("NAN Detected", Boid.Id)
			Boid.Position = Boid.BoxContainer.Position 
		end
 		if Boid.Model:IsA("BasePart") then
			table.insert(PartTable, Boid.Model)
			table.insert(PositionTable, CFrame.new(Boid.Position, Boid.Position + Boid.Velocity))
		else
			Boid.Model:PivotTo(CFrame.new(Boid.Position, Boid.Position + Boid.Velocity))
		end
		if Boid.VelocityPart then
			VectorVisualizer.UpdateUnitVector(Boid.VelocityPart, Boid.Velocity, Boid.Position)
		end
		if Boid.AccelerationPart then
			VectorVisualizer.UpdateUnitVector(Boid.AccelerationPart, Boid.Acceleration, Boid.Position)
		end
	end
	workspace:BulkMoveTo(PartTable, PositionTable)
end)
-- Velocity update --
-- Seperated from position update due to possible differing update frequencies
task.spawn(function()
	local DeltaTime = DIRECTION_UPDATE_FREQUENCY
	while true do
		if AutoUpdate then
			for _, Boid in ipairs(BoidArray) do
				Boid:UpdateVelocity(DeltaTime)
			end
		end
		DeltaTime = task.wait(DIRECTION_UPDATE_FREQUENCY)
	end
end)

return Boid
