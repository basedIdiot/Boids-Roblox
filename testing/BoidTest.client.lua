local Boids = require(script.Parent.Parent.Boids)
--local BoxContainer = require(script.Parent.BoxContainer).new(Vector3.zero, Vector3.new(200, 200, 200))
local RandomGenerator = Random.new()
local BoidTemplate = Instance.new("Part")
BoidTemplate.Size = Vector3.new(1, 1, 1)
BoidTemplate.Material = Enum.Material.SmoothPlastic
BoidTemplate.CanCollide = false
BoidTemplate.CanQuery = false
BoidTemplate.Anchored = true
for _ = 1, 500, 1 do
	local X = RandomGenerator:NextNumber(-50, 50)
	local Y = RandomGenerator:NextNumber(-50, 50)
	local Z = RandomGenerator:NextNumber(-50, 50)
	local Position = Vector3.new(X, Y, Z)
	X = RandomGenerator:NextNumber(-10, 10)
	Y = RandomGenerator:NextNumber(-10, 10)
	Z = RandomGenerator:NextNumber(-10, 10)
	local Velocity = Vector3.new(X, Y, Z)
	print(Position, Velocity)
	local Boid = Boids.new(BoidTemplate, Position, Velocity)
	--Boid.BoxContainer = BoxContainer
	Boid:ShowAcceleration()
	Boid:ShowVelocity()
end
task.wait(5)
Boids.Unpause()