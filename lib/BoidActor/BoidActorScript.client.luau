local SharedTableRegistry = game:GetService("SharedTableRegistry")
local RunService = game:GetService("RunService")

local SharedBoidTable = SharedTableRegistry:GetSharedTable("BoidTable")
local LocalBoidTable = {}

local Actor = script:GetActor()
local BoidDone = Actor.Parent.BoidDone

local BoidsToUpdate = {}

local Paused = false

local function GetAngleBetweenVectors(V1: Vector3, V2: Vector3): number
	return math.acos(V1:Dot(V2) / V1.Magnitude / V2.Magnitude)
end
local function ClampVector(Vector: Vector3, Max: number): Vector3
	if Vector.Magnitude >= Max then
		return Vector.Unit * Max
	end
	return Vector
end

local function IsBoidVisible(self, OtherBoid)
	if OtherBoid.Id == self.Id then
		return false
	end

	if (self.Position - OtherBoid.Position).Magnitude > self.Range then
		return false
	end
	if GetAngleBetweenVectors(self.Position, OtherBoid.Position) > self.ViewAngle then
		return false
	end
	return true
end
local function IsHeadingForCollision(self)
	if
		workspace:Spherecast(
			self.Position,
			self.ObstacleMargin,
			self.Velocity.Unit * self.ObstacleAvoidRadius,
			self.ObstacleParams
		)
	then
		return true
	end
	return false
end
local function GetFurthestUnobstructedDirection(self)
	local BestDirection = Vector3.zero
	local FurthestUnobstructedDistance = 0
	for _, Direction in self.__Directions do
		Direction = CFrame.lookAt(Vector3.zero, self.Velocity.Unit) * -Direction
		local Hit = workspace:Spherecast(self.Position, self.ObstacleMargin, Direction, self.ObstacleParams)
		if not Hit then
			BestDirection = Direction
			break
		end
		if Hit.Distance > FurthestUnobstructedDistance then
			BestDirection = Direction
			FurthestUnobstructedDistance = Hit.Distance
		end
	end
	--Gizmo.PushProperty("AlwaysOnTop", true)
	--Gizmo.Ray:Draw(self.Position, self.Position + BestDirection)
	return BestDirection
end
local function ComputeAcceleration(self): Vector3?
	local Acceleration = Vector3.zero

	local TargetHeading = if self.Target then (self.Target - self.Position) * self.TargetWeight else Vector3.zero
	Acceleration += TargetHeading

	if self.IsObstacleAvoidanceEnabled and IsHeadingForCollision(self) then
		Acceleration += GetFurthestUnobstructedDirection(self).Unit * self.ObstacleAvoidWeight
	end

	local NumBoids = 0
	local AvoidBoids = 0

	local AverageHeading = Vector3.zero
	local AveragePosition = Vector3.zero
	local SeperationHeading = Vector3.zero
	for _, OtherBoid in LocalBoidTable do
		if OtherBoid.Id == self.Id then
			continue
		end
		if not IsBoidVisible(self, OtherBoid) then
			continue
		end
		local Offset = OtherBoid.Position - self.Position
		local Distance = Offset.Magnitude
		AverageHeading += OtherBoid.Velocity
		AveragePosition += OtherBoid.Position
		if Distance < self.AvoidRadius then
			SeperationHeading -= Offset / (Distance + 1)
			AvoidBoids += 1
		end
		NumBoids += 1
	end
	if NumBoids > 0 then
		AverageHeading /= NumBoids
		AverageHeading *= self.AlignWeight
		Acceleration += AverageHeading

		AveragePosition = AveragePosition / NumBoids - self.Position
		AveragePosition *= self.CohesiveWeight
		Acceleration += AveragePosition
	end
	if AvoidBoids > 0 then
		SeperationHeading /= AvoidBoids
		SeperationHeading *= self.SeparationWeight
		Acceleration += SeperationHeading
	end

	Acceleration = ClampVector(Acceleration, self.MaxAcceleration)
	return Acceleration
end
function ComputeVelocity(self, Acceleration, Dt)
	return ClampVector(self.Velocity + Acceleration * Dt, self.MaxSpeed)
end
local function UpdateLocalBoidTable()
	debug.profilebegin("table shit")
	for i, Boid in SharedBoidTable do
		if BoidsToUpdate[i] then
			LocalBoidTable[i] = BoidsToUpdate[i]
			continue
		end
		local LocalBoid = LocalBoidTable[i]
		if not LocalBoid then
			LocalBoid = table.create(3)
			LocalBoidTable[i] = LocalBoid
		end
		LocalBoid.Position = Boid.Position
		LocalBoid.Velocity = Boid.Velocity
		LocalBoid.Id = Boid.Id
	end
	debug.profileend()
end
RunService.Heartbeat:ConnectParallel(function(Dt)
	if Paused then
		return
	end
	UpdateLocalBoidTable()
	for _, Boid in BoidsToUpdate do
		local Acceleration = ComputeAcceleration(Boid)
		local Velocity = ComputeVelocity(Boid, Acceleration, Dt)
		local Position = Boid.Position + Velocity * Dt

		if Position ~= Position then
			Position = Vector3.zero
		end
		if Velocity ~= Velocity then
			Position = Vector3.zero
		end
		if Acceleration ~= Acceleration then
			Position = Vector3.zero
		end

		Boid.Acceleration = Acceleration
		Boid.Velocity = Velocity
		Boid.Position = Position

		SharedBoidTable[Boid.Id].Position = Position
		SharedBoidTable[Boid.Id].Velocity = Velocity

		BoidDone:Fire(Boid.Id, Position, Velocity, Acceleration)
	end
end)
Actor:BindToMessage("NewBoid", function(Boid)
	BoidsToUpdate[Boid.Id] = Boid
end)
Actor:BindToMessage("DestroyBoid", function(Id)
	BoidsToUpdate[Id] = nil
end)
Actor:BindToMessage("UpdateBoid", function(Id, Property, Input)
	BoidsToUpdate[Id][Property] = Input
end)
Actor:BindToMessage("Pause", function()
	Paused = true
end)
Actor:BindToMessage("Unpause", function()
	Paused = false
end)
