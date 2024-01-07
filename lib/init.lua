--!strict
local Boid = {}
Boid.Interface = {}
Boid.Schema = {}
Boid.Metatable = { __index = Boid.Schema }
Boid.__index = {}

local BoxContainer = require(script.BoxContainer)
type BoxContainer = BoxContainer.BoxContainer

local VectorVisualizer = require(script.VectorVisualizer)
local ChunkSystem = require(script.ChunkSystem)
local Janitor = require(script.Parent.janitor)
local Gizmo = require(script.CeiveImGizmo)
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local AutoUpdate = false -- determines whether the script will automatically update the boids position each frame
-- Good for benchmarking certain functions

local DIRECTION_UPDATE_FREQUENCY = 1 / 60

local MIN_SPEED = 2
local MAX_SPEED = 5
local MAX_ACCELERATION = 10

local RANGE = 5
local VIEW_ANGLE = math.pi -- measured in radians
local AVOID_RADIUS = 2

local PHI = 1.618033988749
local ANGLE_INCREMENT = 2 * math.pi * PHI
local NUM_VIEW_DIRECTIONS = 200
local OBSTACLE_AVOID_RADIUS = 10
local OBSTACLE_MARGIN = 0.1
local DEFAULT_RAYCAST_PARAMS = nil

local SEPERATION_WEIGHT = 2
local ALIGN_WEIGHT = 1
local COHESIVE_WEIGHT = 1
local TARGET_WEIGHT = 1
local OBSTACLE_AVOID_WEIGHT = 10

local BoidArray = {}
Boid.BoidArray = BoidArray
local Chunks = ChunkSystem.new(3, 10)

export type Boid = typeof(Boid.Interface.new(table.unpack(...)))--[[{
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
}]]

local function GetAngleBetweenVectors(V1: Vector3, V2: Vector3): number
	return math.acos(V1:Dot(V2) / V1.Magnitude / V2.Magnitude)
end
local function ClampVector(Vector: Vector3, Max: number): Vector3
	if Vector.Magnitude >= Max then
		return Vector.Unit * Max
	end
	return Vector
end
local function ComputeSphereVectors(Length: number?): { [number]: Vector3 }
	local Directions = table.create(NUM_VIEW_DIRECTIONS)
	Length = Length or 1

	for I = 1, NUM_VIEW_DIRECTIONS do
		local T = I / NUM_VIEW_DIRECTIONS
		local Inclination = math.acos(1 - 2 * T)
		local Azimuth = ANGLE_INCREMENT * I

		local X = math.sin(Inclination) * math.cos(Azimuth)
		local Y = math.sin(Inclination) * math.sin(Azimuth)
		local Z = math.cos(Inclination)
		Directions[I] = Vector3.new(X, Y, Z) * Length
	end
	return Directions
end
function Boid.Interface.GetBoids(): { [number]: Boid }
	return table.clone(BoidArray)
end
function Boid.Interface.Pause()
	AutoUpdate = false
end
function Boid.Interface.Unpause()
	AutoUpdate = true
end
function Boid.Interface.new(
	Model: BasePart | Model,
	Position: Vector3?,
	Velocity: Vector3?,
	Range: number?,
	ViewAngle: number?
): Boid
	local NewModel = Model:Clone()
	NewModel:PivotTo(CFrame.lookAt(Position, Position + Velocity))
	NewModel.Parent = workspace.Boids
	local self = {
		Model = NewModel,

		Position = Position or Vector3.zero,
		Velocity = Velocity or Vector3.one,
		Acceleration = Vector3.one,

		Range = Range or RANGE,
		ViewAngle = ViewAngle or VIEW_ANGLE,
		AvoidRadius = AVOID_RADIUS,

		IsObstacleAvoidanceEnabled = true,
		ObstacleAvoidRadius = OBSTACLE_AVOID_RADIUS,
		ObstacleParams = DEFAULT_RAYCAST_PARAMS,

		MinSpeed = MIN_SPEED,
		MaxSpeed = MAX_SPEED,
		MaxAcceleration = MAX_ACCELERATION,

		Target = nil,

		Id = HttpService:GenerateGUID(),

		__Directions = ComputeSphereVectors(OBSTACLE_AVOID_RADIUS),
		__Janitor = Janitor.new(),
	}
	if self.Model then
		self.__Janitor:Add(Model, "Destroy")
	end
	table.insert(BoidArray, self)
	return setmetatable(self, Boid.Metatable)
end
function Boid.Schema:Destroy()
	self.__Janitor:Destroy()
	table.remove(BoidArray, table.find(BoidArray, self))
end
function Boid.Schema:IsBoidVisible(OtherBoid: Boid)
	if OtherBoid.Id == self.Id then
		return true
	end

	if (self.Position - OtherBoid.Position).Magnitude > self.Range then
		return false
	end
	if GetAngleBetweenVectors(self.Position, OtherBoid.Position) > self.ViewAngle then
		return false
	end
	return true
end
function Boid.Schema:GetDirection(): Vector3
	return self.Velocity.Unit
end
function Boid.Schema:SetPosition(Position: Vector3)
	self.Position = Position
	self.Model:PivotTo(CFrame.lookAt(Position, Position + self.Velocity))
end
function Boid.Schema:SetVelocity(Velocity: Vector3)
	self.Velocity = Velocity
	self.Model:PivotTo(CFrame.lookAt(self.Position, self.Position + Velocity))
end
function Boid.Schema:SetObstacleAvoidRadius(Radius: number)
	self.ObstacleAvoidRadius = Radius
	self.__Directions = ComputeSphereVectors(Radius)
end
function Boid.Schema:IsHeadingForCollision()
	if workspace:Spherecast(self.Position, OBSTACLE_MARGIN, self.Velocity.Unit * self.ObstacleAvoidRadius, self.ObstacleParams) then
		return true
	end
	return false
end
function Boid.Schema:GetFurthestUnobstructedDirection()
	local BestDirection = Vector3.zero
	local FurthestUnobstructedDistance = 0
	for _, Direction in self.__Directions do
		Direction = CFrame.lookAt(Vector3.zero, self:GetDirection()) * -Direction
		local Hit = workspace:Spherecast(self.Position, OBSTACLE_MARGIN, Direction, self.ObstacleParams)
		if not Hit then
			BestDirection = Direction
			break
		end
		if Hit.Distance > FurthestUnobstructedDistance then
			BestDirection = Direction
			FurthestUnobstructedDistance = Hit.Distance
		end
	end
	Gizmo.PushProperty("AlwaysOnTop", true)
	Gizmo.Ray:Draw(self.Position, self.Position + BestDirection)
	return BestDirection
end
function Boid.Schema:__CalculateAcceleration(): Vector3?
	local Acceleration = Vector3.zero

	local TargetHeading = if self.Target then (self.Target - self.Position * TARGET_WEIGHT) else Vector3.zero
	Acceleration += TargetHeading

	if self.IsObstacleAvoidanceEnabled and self:IsHeadingForCollision() then
		self.Model.Color = Color3.new(1)
		Acceleration += self:GetFurthestUnobstructedDirection().Unit * OBSTACLE_AVOID_WEIGHT
	else
		self.Model.Color = Color3.new(0, 1)
	end

	local NumBoids = 0
	local AvoidBoids = 0

	local AverageHeading = Vector3.zero
	local AveragePosition = Vector3.zero
	local SeperationHeading = Vector3.zero
	for _, OtherBoid: Boid in ipairs(BoidArray) do
		if OtherBoid.Id == self.Id then
			continue
		end
		if not self:IsBoidVisible(OtherBoid) then
			continue
		end
		local Offset = OtherBoid.Position - self.Position
		local Distance = Offset.Magnitude
		AverageHeading += OtherBoid.Velocity
		AveragePosition += OtherBoid.Position
		if Distance < AVOID_RADIUS then
			SeperationHeading -= Offset / (Distance + 1)
			AvoidBoids += 1
		end
		NumBoids += 1
	end
	if NumBoids > 0 then
		AverageHeading /= NumBoids
		AverageHeading *= ALIGN_WEIGHT
		Acceleration += AverageHeading

		AveragePosition = AveragePosition / NumBoids - self.Position
		AveragePosition *= COHESIVE_WEIGHT
		Acceleration += AveragePosition
	end
	if AvoidBoids > 0 then
		SeperationHeading /= AvoidBoids
		SeperationHeading *= SEPERATION_WEIGHT
		Acceleration += SeperationHeading
	end

	Acceleration = ClampVector(Acceleration, self.MaxAcceleration)
	return Acceleration
end
function Boid.Schema:UpdateVelocity(dt: NumberValue)
	local Acceleration = self:__CalculateAcceleration()
	if Acceleration then
		self.Acceleration = Acceleration
		self.Velocity += Acceleration * dt
		self.Velocity = ClampVector(self.Velocity, self.MaxSpeed)
	end
end
function Boid.Schema:UpdatePosition(dt: NumberValue)
	self.Position += self.Velocity * dt
	if self.BoxContainer then
		if not self.BoxContainer:IsInside(self.Position) then
			self.Position = self.BoxContainer:ConstrainPosition(
				-(self.Position - self.BoxContainer.Position) + self.BoxContainer.Position
			)
		end
	end
end
function Boid.Schema:ShowVelocity()
	if self.VelocityPart then
		return
	end
	self.VelocityPart = VectorVisualizer.VisualizeUnitVector(self.Velocity, self.Position)
	self.VelocityPart.Color = Color3.new(0.686274, 0.086274, 0.086274)
	self.__Janitor:Add(self.VelocityPart, "Destroy", "Velocity Part")
end
function Boid.Schema:HideVelocity()
	if self.VelocityPart then
		self.VelocityPart:Destroy()
		self.__Janitor:Remove("Velocity Part")
	end
end
function Boid.Schema:ShowAcceleration()
	if self.AccelerationPart then
		return
	end
	self.AccelerationPart = VectorVisualizer.VisualizeUnitVector(self.Acceleration, self.Position)
	self.AccelerationPart.Color = Color3.new(0.078431, 0.701960, 0.286274)
	self.__Janitor:Add(self.AccelerationPart, "Destroy", "Acceleration Part")
end
function Boid.Schema:HideAcceleration()
	if self.AccelerationPart then
		self.AccelerationPart:Destroy()
		self.__Janitor:Remove("Acceleration Part")
	end
end

-- Position update --
RunService.Heartbeat:Connect(function(DeltaTime)
	debug.profilebegin("Position update step")
	if not AutoUpdate then
		return
	end
	local PartTable = table.create(#BoidArray)
	local PositionTable = table.create(#BoidArray)
	for _, Boid in ipairs(BoidArray) do
		Boid:UpdatePosition(DeltaTime)
		if Boid.Position ~= Boid.Position then
			error("NAN Detected: " .. Boid.Id)
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
	debug.profileend()
end)
-- Velocity update --
-- Seperated from position update due to possible differing update frequencies
task.spawn(function()
	local DeltaTime = DIRECTION_UPDATE_FREQUENCY
	while true do
		debug.profilebegin("Velocity update step")
		if AutoUpdate then
			for _, Boid in ipairs(BoidArray) do
				Boid:UpdateVelocity(DeltaTime)
			end
		end
		debug.profileend()
		DeltaTime = task.wait(DIRECTION_UPDATE_FREQUENCY)
	end
end)

return Boid.Interface
