--!strict
local Boid = {}
Boid.Interface = {}
Boid.Schema = {}
Boid.Metatable = { __index = Boid.Schema }
Boid.__index = {}

local Janitor = require(script.Parent.janitor)

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")

local AutoUpdate = false -- determines whether the script will automatically update the boids position each frame
-- Good for benchmarking certain functions

local NUM_ACTORS = 16

local MIN_SPEED = 2
local MAX_SPEED = 10
local MAX_ACCELERATION = 20

local RANGE = 10
local VIEW_ANGLE = math.pi -- measured in radians
local AVOID_RADIUS = 2

local PHI = 1.618033988749
local ANGLE_INCREMENT = 2 * math.pi * PHI
local NUM_VIEW_DIRECTIONS = 100
local OBSTACLE_AVOID_RADIUS = 30
local OBSTACLE_MARGIN = 1
local DEFAULT_RAYCAST_PARAMS = RaycastParams.new()

local SEPERATION_WEIGHT = 10
local ALIGN_WEIGHT = 1
local COHESIVE_WEIGHT = 1
local OBSTACLE_AVOID_WEIGHT = 20
local TARGET_WEIGHT = 1


local BoidArray = {}
Boid.BoidArray = BoidArray
local SharedBoidTable = SharedTable.new()
local BoidIdMap = {}
SharedTableRegistry:SetSharedTable("BoidTable", SharedBoidTable)

local ActorArray = {}
local CurrentActor = 0
for i = 1, NUM_ACTORS do
	local NewActor = script.BoidActor:Clone()
	NewActor.BoidActorScript.Enabled = true
	NewActor.Parent = script
	ActorArray[i] = NewActor
end

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
local function slice(t, minIndex, maxIndex)
	local result = {}
	return table.move(t, minIndex, maxIndex - 1, 1, result)
end
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
function Boid.Interface.GetBoidFromId(BoidId): Boid?
	return BoidIdMap[BoidId]
end

function Boid.Interface.Pause()
	AutoUpdate = false
	for _, Actor in ActorArray do
		Actor:SendMessage("Pause")
	end
end
function Boid.Interface.Unpause()
	AutoUpdate = true
	for _, Actor in ActorArray do
		Actor:SendMessage("Unpause")
	end
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

	local Id = HttpService:GenerateGUID()
	-- Have to be comically unlucky for while loop to happen
	while BoidIdMap[Id] do
		Id = HttpService:GenerateGUID()
	end
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
		ObstacleMargin = OBSTACLE_MARGIN,

		MinSpeed = MIN_SPEED,
		MaxSpeed = MAX_SPEED,
		MaxAcceleration = MAX_ACCELERATION,

		Target = nil,

		SeparationWeight = SEPERATION_WEIGHT,
		AlignWeight = ALIGN_WEIGHT,
		CohesiveWeight = COHESIVE_WEIGHT,
		ObstacleAvoidWeight = OBSTACLE_AVOID_WEIGHT,
		TargetWeight = TARGET_WEIGHT,

		Id = Id,

		__LastVelocityUpdateTime = os.clock(),

		__Directions = ComputeSphereVectors(OBSTACLE_AVOID_RADIUS),
		__Janitor = Janitor.new(),
		__Actor = ActorArray[CurrentActor + 1]
	}
	self.__Actor:SendMessage("NewBoid", self)
	CurrentActor = (CurrentActor + 1) % NUM_ACTORS
	if self.Model then
		self.__Janitor:Add(Model, "Destroy")
	end
	table.insert(BoidArray, self)
	BoidIdMap[Id] = self
	SharedBoidTable[Id] = {
		Id = self.Id,
		Position = self.Position,
		Velocity = self.Velocity
	}
	return setmetatable(self, Boid.Metatable)
end
function Boid.Schema:Destroy()
	self.__Actor:SendMessage("DestroyBoid", self.Id)
	self.__Janitor:Destroy()
	table.remove(BoidIdMap, self.Id)
	table.remove(BoidArray, table.find(BoidArray, self))
end
function Boid.Schema:GetDirection(): Vector3
	return self.Velocity.Unit
end
function Boid.Schema:SetPosition(Position: Vector3)
	self.Position = Position
	self.Model:PivotTo(CFrame.lookAt(Position, Position + self.Velocity))
	self.__Actor:SendMessage("UpdateBoid", self.Id, "Position", Position)
end
function Boid.Schema:SetVelocity(Velocity: Vector3)
	self.Velocity = Velocity
	self.Model:PivotTo(CFrame.lookAt(self.Position, self.Position + Velocity))
	self.__Actor:SendMessage("UpdateBoid", self.Id, "Velocity", Velocity)
end
function Boid.Schema:SetObstacleAvoidRadius(Radius: number)
	self.ObstacleAvoidRadius = Radius
	self.__Directions = ComputeSphereVectors(Radius)
	self.__Actor:SendMessage("UpdateBoid", self.Id, "ObstacleAvoidRadius", Radius)
end
function Boid.Schema:Set(Property: string, input)
	if Property == "Position" then
		self:SetPosition(input)
		return
	end
	if Property == "Velocity" then
		self:SetVelocity(input)
		return
	end
	if Property == "ObstacleAvoidRadius" then
		self:SetObstacleAvoidRadius(input)
		return
	end
	self[Property] = input
	self.__Actor:SendMessage("UpdateBoid", self.Id, Property, input)
end
-- Position update --
RunService.Heartbeat:Connect(function(DeltaTime)
	if not AutoUpdate then
		return
	end
	local PartTable = table.create(#BoidArray)
	local PositionTable = table.create(#BoidArray)
	for _, Boid in ipairs(BoidArray) do
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
	workspace:BulkMoveTo(PartTable, PositionTable, Enum.BulkMoveMode.FireCFrameChanged)
end)
-- Velocity update --
-- Seperated from position update due to possible differing update frequencies
script.BoidDone.Event:Connect(function (BoidId, Position, Velocity, Acceleration)
	local Boid = Boid.Interface.GetBoidFromId(BoidId)
	Boid.Position = Position
	Boid.Velocity = Velocity
	Boid.Acceleration = Acceleration
end)

return Boid.Interface
