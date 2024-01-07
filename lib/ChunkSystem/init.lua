-- ChunkSystem.lua
-- tyridge77
-- December 12, 2019

--[[
    Allows for the creation of simple "ChunkSystem" objects, which hold an array of x*x(*x) stud cells which can hold information.
    You can use these in many applications to iterate through objects on a per chunk basis, so you're not iterating through potentially thousands of entities.

    There are other ways/data structures to go about spatial partitioning, and this is by no means the best solution, but I believe these are a bit easier for beginners to understand and use effectively


    API:

    ChunkSystem:


    ChunkSystem ChunkSystem.new(int Dimensions,int ChunkSize)
        Creates a ChunkSystem with 2 or 3 dimensions, and a given ChunkSize

    Chunk ChunkSystem:GetChunk(Vector3 position,boolean CreateIfNotFound)
        Returns the Chunk at the given position
        If a Chunk is not found, create if CreateIfNotFound is true
    
    Chunk ChunkSystem:CreateChunk(Vector3 position)
        Creates a Chunk at the given position if one does not exist
        Returns the Chunk

    void ChunkSystem:RemoveChunk(Vector3 position)
        Removes the chunk at the given position

    Chunk:

    Table Chunk:GetObjects(String IncludeType)
        Returns all of the objects added to this chunk

        You can optionally pass in "Surrounding" or "Adjacent" for IncludeType.
        This will include objects from either the adjacent(directly touching) or surrounding chunks.

    Vector3 Chunk:GetPosition()
        Returns the position of this chunk. For 2 dimensional chunks, y will always be 0

    void Chunk:AddObject(Variant object)
        Add this object to the chunk
        You can only add tables or instances to chunks

    void Chunk:AddObjects(Table objects)
        Add multiple objects to this chunk
        You can only add tables or instances to chunks

    void Chunk:RemoveObject(Variant object)
        Removes object from chunk, if it exists

    boolean Chunk:ObjectExists(Variant object)
        Returns whether or not the object exists in this chunk

    Table Chunk:GetAdjacentChunks()
        Returns a table of chunks that are directly touching this chunk

    Table Chunk:GetSurroundingChunks()
        Returns a table of chunks that are surrounding this chunk

    
--]]

local ChunkSystem = {}
ChunkSystem.__index = ChunkSystem
export type ChunkSystem = typeof(ChunkSystem.new())

local function Round(x: number, int: number): number
	return math.floor(x / int + 0.5) * int
end
local function Round2D(v3: number, int: number): (number, number)
	return Round(v3.x, int), Round(v3.z, int)
end
local function Round3D(v3: number, int: number): (number, number, number)
	return Round(v3.x, int), Round(v3.y, int), Round(v3.z, int)
end

local Chunk = require(script.Chunk)
type Chunk = Chunk.Chunk
type ChunkArray = {
	[number]: Chunk,
}

function ChunkSystem.new(Dimensions: number, ChunkSize: number): ChunkSystem
	local self = setmetatable({}, ChunkSystem)

	if Dimensions ~= 2 and Dimensions ~= 3 then
		warn("Must be two or three dimensions!")
		return
	end

	if not ChunkSize or typeof(ChunkSize) ~= "number" then
		warn("No specified chunk size!")
		return
	end

	ChunkSize = Round(ChunkSize, 1) -- Only integers

	self.Dimensions = Dimensions

	self.ChunkSize = ChunkSize

	self.Grid = {}

	return self
end
function ChunkSystem:GetChunk(Position: Vector3, CreateIfNotFound: boolean?): Chunk?
	self:_assertPosition(Position)
	local gotChunk = self:_getChunk(Position)
	if gotChunk then
		return gotChunk
	elseif CreateIfNotFound then
		return self:_createChunk(Position)
	end
end
function ChunkSystem:CreateChunk(Position: Vector3): Chunk
	self:_assertPosition(Position)
	local gotChunk = self:_getChunk(Position)
	if not gotChunk then
		gotChunk = self:_createChunk(Position)
	end
	return gotChunk
end
function ChunkSystem:RemoveChunk(Position: Vector3)
	self:_removeChunk(Position)
end

function ChunkSystem:_assertPosition(Position)
	assert(typeof(Position) == "Vector3", "Input Position must be a Vector3!")
end

function ChunkSystem:_getChunk(Position: Vector3): Chunk?
	if self.Dimensions == 2 then
		local x, y = Round2D(Position, self.ChunkSize)
		return self:_getChunkXY(x, y)
	else
		local x, y, z = Round3D(Position, self.ChunkSize)
		return self:_getChunkXYZ(x, y, z)
	end
end
function ChunkSystem:_getChunkXY(x: number, y: number): Chunk?
	local Grid = self.Grid
	if Grid[x] then
		local chunk = Grid[x][y]
		return chunk
	end
end
function ChunkSystem:_getChunkXYZ(x: number, y: number, z: number): Chunk?
	local Grid = self.Grid
	if Grid[x] then
		if Grid[x][y] then
			local chunk = Grid[x][y][z]
			return chunk
		end
	end
end

function ChunkSystem:_createChunk(Position: Vector3): Chunk
	if self.Dimensions == 2 then
		local x, y = Round2D(Position, self.ChunkSize)

		local Grid = self.Grid

		if not Grid[x] then
			Grid[x] = {}
		end
		local chunk = Grid[x][y]
		if not chunk then
			chunk = Chunk.new(self, Vector3.new(x, 0, y))
			Grid[x][y] = chunk
		end
		return chunk
	else
		local x, y, z = Round3D(Position, self.ChunkSize)

		local Grid = self.Grid

		if not Grid[x] then
			Grid[x] = {}
		end
		if not Grid[x][y] then
			Grid[x][y] = {}
		end
		local chunk = Grid[x][y][z]
		if not chunk then
			chunk = Chunk.new(self, Vector3.new(x, y, z))
			Grid[x][y][z] = chunk
		end
		return chunk
	end
end
function ChunkSystem:_removeChunk(Position: Vector3)
	if self.Dimensions == 2 then
		local x, y = Round2D(Position, self.ChunkSize)

		local Grid = self.Grid

		if Grid[x] then
			local chunk = Grid[x][y]
			if chunk then
				Grid[x][y] = nil
			end
		end
	else
		local x, y, z = Round3D(Position, self.ChunkSize)

		local Grid = self.Grid

		if Grid[x] then
			if Grid[x][y] then
				local chunk = Grid[x][y][z]
				if chunk then
					Grid[x][y][z] = nil
				end
			end
		end
	end
end

return ChunkSystem
