-- Chunk.lua
-- tyridge77
-- December 12, 2019

local Chunk = {}
Chunk.__index = Chunk

export type Chunk = typeof(Chunk.new())
type ChunkArray = {
	[number]: Chunk,
}
type Array = {
	[number]: any,
}

function Chunk.new(ChunkSystem, Position): Chunk
	local self = setmetatable({}, Chunk)
	self.ChunkSystem = ChunkSystem
	self.Objects = {}
	self.Position = Position
	return self
end

local function Fill(tab: Array, tab2: Array)
	for i = 1, #tab2 do
		local obj = tab2[i]
		if obj then
			table.insert(tab, obj)
		end
	end
end

-- Rounds away from zero to a multiple of int closest to n
local function Ceil(n: number, int: number)
	return math.sign(n) * math.ceil(math.abs(n / int)) * int
end

function Chunk:GetObjects(IncludeType: string): Array
	if not IncludeType then
		return self.Objects
	else
		local Objects = {}

		Fill(Objects, self.Objects)

		if IncludeType == "Adjacent" then
			local AdjacentChunks = self:_getAdjacentChunks()

			if AdjacentChunks then
				for i = 1, #AdjacentChunks do
					local chunk = AdjacentChunks[i]
					if chunk then
						local objects = chunk.Objects
						Fill(Objects, objects)
					end
				end
			end
		elseif IncludeType == "Surrounding" then
			local SurroundingChunks = self:_getSurroundingChunks()
			if SurroundingChunks then
				for i = 1, #SurroundingChunks do
					local chunk = SurroundingChunks[i]
					if chunk then
						local objects = chunk.Objects
						Fill(Objects, objects)
					end
				end
			end
		end

		return Objects
	end
end

function Chunk:AddObject(Object)
	self:_addObject(Object)
end
function Chunk:AddObjects(Objects)
	for i = 1, #Objects do
		local obj = Objects[i]
		if obj then
			self:_addObject(obj)
		end
	end
end
function Chunk:RemoveObject(Object)
	self:_removeObject(Object)
end
function Chunk:ObjectExists(Object)
	self:_objectExists(Object)
end

function Chunk:GetAdjacentChunks()
	return self:_getAdjacentChunks()
end
function Chunk:GetSurroundingChunks()
	return self:_getSurroundingChunks()
end

function Chunk:GetPosition()
	return self.Position
end

function Chunk:_draw(t: number)
	if not self.Drawn then
		self.Drawn = true
		local p = Instance.new("Part")
		p.Anchored = true
		p.Transparency = 0.5
		p.Size = Vector3.new(1, 1, 1) * self.ChunkSystem.ChunkSize
		p.CFrame = CFrame.new(self.Position)
		p.Parent = workspace
		task.delay(t, function()
			self.Drawn = false
			p:Destroy()
		end)
	end
end

function Chunk:_addObject(Object)
	assert(typeof(Object) == "Instance" or typeof(Object) == "table", "Object must be an instance or a table!")
	table.insert(self.Objects, Object)
end
function Chunk:_removeObject(Object)
	assert(typeof(Object) == "Instance" or typeof(Object) == "table", "Object must be an instance or a table!")
	for i = 1, #self.Objects do
		local obj = self.Objects[i]
		if obj == Object then
			table.remove(self.Objects, i)
		end
	end
end
function Chunk:_objectExists(Object): boolean
	assert(typeof(Object) == "Instance" or typeof(Object) == "table", "Object must be an instance or a table!")
	for i = 1, #self.Objects do
		local obj = self.Objects[i]
		if obj == Object then
			return true
		end
	end
	return false
end

function Chunk:_getAdjacentChunks(): ChunkArray
	local ChunkSystem = self.ChunkSystem
	local ChunkSize = ChunkSystem.ChunkSize
	local Dimensions = ChunkSystem.Dimensions

	local Position = self:GetPosition()

	if Dimensions == 2 then
		local x, y = Position.x, Position.y
		local Chunks = {
			ChunkSystem:_getChunkXY(x - ChunkSize, y),
			ChunkSystem:_getChunkXY(x + ChunkSize, y),
			ChunkSystem:_getChunkXY(x, y - ChunkSize),
			ChunkSystem:_getChunkXY(x, y + ChunkSize),
		}
		return Chunks
	elseif Dimensions == 3 then
		local x, y, z = Position.x, Position.y, Position.z
		local Chunks = {
			ChunkSystem:_getChunkXYZ(x - ChunkSize, y, z),
			ChunkSystem:_getChunkXYZ(x + ChunkSize, y, z),
			ChunkSystem:_getChunkXYZ(x, y - ChunkSize, z),
			ChunkSystem:_getChunkXYZ(x, y + ChunkSize, z),
			ChunkSystem:_getChunkXYZ(x, y, z - ChunkSize),
			ChunkSystem:_getChunkXYZ(x, y, z + ChunkSize),
		}
		return Chunks
	end
end
function Chunk:_getSurroundingChunks(): ChunkArray
	local ChunkSystem = self.ChunkSystem
	local ChunkSize = ChunkSystem.ChunkSize
	local Dimensions = ChunkSystem.Dimensions

	local Position = self:GetPosition()

	if Dimensions == 2 then
		local posX, posY = Position.x, Position.y

		local Chunks = table.create(8)

		for x = posX - ChunkSize, posX + ChunkSize, ChunkSize do
			for y = posY - ChunkSize, posY + ChunkSize, ChunkSize do
				local chunk = ChunkSystem:_getChunkXY(x, y)
				if chunk and chunk ~= self then
					table.insert(Chunks, chunk)
				end
			end
		end
		return Chunks
	elseif Dimensions == 3 then
		local posX, posY, posZ = Position.x, Position.y, Position.z

		local Chunks = table.create(26)

		for x = posX - ChunkSize, posX + ChunkSize, ChunkSize do
			for y = posY - ChunkSize, posY + ChunkSize, ChunkSize do
				for z = posZ - ChunkSize, posZ + ChunkSize, ChunkSize do
					local chunk = ChunkSystem:_getChunkXYZ(x, y, z)
					if chunk and chunk ~= self then
						table.insert(Chunks, chunk)
					end
				end
			end
		end
		return Chunks
	end
end
function Chunk:__getChunksInRange(r: number): ChunkArray
	local ChunkSystem = self.ChunkSystem
	local ChunkSize = ChunkSystem.ChunkSize
	local Dimensions = ChunkSystem.Dimensions

	local Position = self:GetPosition()

	if r == 0 then
		return
	end
	if r <= ChunkSize then
		return Chunk:__getSurroundingChunks()
	end

	if Dimensions == 2 then
		local posX, posY = Position.x, Position.y

		local Chunks = { table.create(8) }

		for x = Ceil(posX - r), Ceil(posX + r), ChunkSize do
			for y = Ceil(posY - r), Ceil(posY + r), ChunkSize do
				local chunk = ChunkSystem:_getChunkXY(x, y)
				if chunk and chunk ~= self then
					table.insert(Chunks, chunk)
				end
			end
		end
		return Chunks
	elseif Dimensions == 3 then
		local posX, posY, posZ = Position.x, Position.y, Position.z

		local Chunks = table.create(26)

		for x = Ceil(posX - r), Ceil(posX + r), ChunkSize do
			for y = Ceil(posY - r), posY + r, ChunkSize do
				for z = Ceil(posZ - r), Ceil(posZ + r), ChunkSize do
					local chunk = ChunkSystem:_getChunkXYZ(x, y, z)
					if chunk and chunk ~= self then
						table.insert(Chunks, chunk)
					end
				end
			end
		end
		return Chunks
	end
end

return Chunk
