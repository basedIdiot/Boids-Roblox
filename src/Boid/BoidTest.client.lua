local Boids = require(script.Parent)
local BoxContainer = require(script.Parent.BoxContainer).new(Vector3.zero, Vector3.new(50, 50, 50))
print(BoxContainer.IsInside)
local BoidTemplate = Instance.new("Part")
local RandomGenerator = Random.new()
BoidTemplate.Size = Vector3.new(1, 1, 1)
BoidTemplate.Material = Enum.Material.SmoothPlastic
BoidTemplate.CanCollide = false
BoidTemplate.CanQuery = false
BoidTemplate.Anchored = true
for i = 1, 100, 1 do
    local X = RandomGenerator:NextNumber(-95, 105)
    local Y = RandomGenerator:NextNumber(-95, 105)
    local Z = RandomGenerator:NextNumber(-95, 105)
    local Position = Vector3.new(X, Y, Z)
    X = RandomGenerator:NextNumber(-10, 10)
    Y = RandomGenerator:NextNumber(-10, 10)
    Z = RandomGenerator:NextNumber(-10, 10)
    local Velocity = Vector3.new(X, Y, Z)
    local Boid = Boids.new(BoidTemplate, Position, Velocity)
    Boid.BoxContainer = BoxContainer
    Boid.Target = Vector3.one
    Boid:ShowAcceleration()
    Boid:ShowVelocity()
end
