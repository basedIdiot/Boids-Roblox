-- Currently, this system will use a flat spatial hashing scheme
local SpatialHash = {}
SpatialHash.__index = {}

local CELL_SIZE = 10
local HASH_TABLE_SIZE = 256

local function AbsVector3(Vector: Vector3): Vector3
    return Vector3.new(math.abs(Vector.X), math.abs(Vector.Y), math.abs(Vector.Z))
end

function SpatialHash.new(StartPosition: Vector3, EndPosition: Vector3)
    -- Cells go from 0 to the max number of cells in a row/column
    local XCells = math.ceil(math.abs(EndPosition.X - StartPosition.X) / CELL_SIZE)
    local YCells = math.ceil(math.abs(EndPosition.Y - StartPosition.Y) / CELL_SIZE)
    local ZCells = math.ceil(math.abs(EndPosition.Z - StartPosition.Z) / CELL_SIZE)

    -- Hashtable is one indexed
    local HashTable = table.create(HASH_TABLE_SIZE)

    local self = {
        HashTable = HashTable,
        StartPosition = StartPosition,
        EndPosition = EndPosition,
        Size = AbsVector3(StartPosition - EndPosition),

        Length = XCells,
        Height = YCells,
        Width = ZCells,

    }
    return setmetatable(self, SpatialHash)
end
function SpatialHash.__index:GetGridPosition(Position: Vector3) : (number, number, number)
    local X = math.clamp(math.round(Position.X) / CELL_SIZE, 0, self.XSize)
    local Y = math.clamp(math.round(Position.Y) / CELL_SIZE, 0, self.YSize)
    local Z = math.clamp(math.round(Position.Z) / CELL_SIZE, 0, self.ZSize)
    return X, Y, Z
end
function SpatialHash.__index:GetHash(X : number, Y : number, Z : number) : number
    -- I have no idea what this is, but it doesn't collide as much so it's fine
    return bit32.bxor(73856093*X, 19349663*Y, 83492791*Z) % HASH_TABLE_SIZE --  bit shit ;3
end
function SpatialHash.__index:AddBoid(Boid)
    self:AddBoidAtHash(Boid)
end
function SpatialHash.__index:AddBoidAtHash(Boid, Hash : number)
    if not Hash then
        Hash = self:GetHash(self:GetGridPosition(Boid.Position))
    end
    local HashBoid = self.HashTable[Hash]
    if not HashBoid then
        self.HashTable[Hash] = Boid
        return
    end
    HashBoid.Previous = Boid
    Boid.Next = HashBoid
end
function SpatialHash.__index:RemoveBoid(Boid)
    if Boid.Previous then Boid.Previous.Next = Boid.Next end
    if Boid.Next then Boid.Next.Previous = Boid.Previous end
end
function SpatialHash.__index:MoveBoid(Boid, NewPosition: Vector3)
    local Hash = self:GetHash(self:GetGridPosition(Boid.Position))
    local NewHash = self:GetHash(self:GetGridPosition(NewPosition))

    self.Position = NewPosition
    if Hash == NewHash then return end

    self:RemoveBoid(Boid)

    self:AddBoidAtHash(Boid, NewHash)
end
-- Note: This is approximate, and not every hash returned is guaranteed to be in range
function SpatialHash.__index:GetHashesInRange(Boid, Range : number) : {number: number}
    local CellRange = math.ceil(Range / CELL_SIZE)
    local BoidPosition = self:GetGridPosition(Boid.Position)
    local LowerBoundX, UpperBoundX = math.clamp(BoidPosition - CellRange, 0, self.Length), math.clamp(BoidPosition + CellRange, 0, self.Length)
    local LowerBoundY, UpperBoundY = math.clamp(BoidPosition - CellRange, 0, self.Height), math.clamp(BoidPosition + CellRange, 0, self.Height)
    local LowerBoundZ, UpperBoundZ = math.clamp(BoidPosition - CellRange, 0, self.Width), math.clamp(BoidPosition + CellRange, 0, self.Width)
    local Hashes = table.create((UpperBoundX - LowerBoundX) * (UpperBoundY - LowerBoundY) * (UpperBoundZ - LowerBoundZ))
    for X = LowerBoundX, UpperBoundX do
        for Y  = LowerBoundY, UpperBoundY do
            for Z = LowerBoundZ, UpperBoundZ do
                table.insert(Hashes, self:GetHash(X, Y, Z))
            end
        end
    end
    return Hashes
end

function SpatialHash.__index:ShowDebugParts()
    if self.DebugParts then
        for _, Part in self.DebugParts do
            Part.Transparency = 0.5
        end
    end
end
return SpatialHash