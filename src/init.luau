--!strict
--!optimize 2
--!native

local ByeByeCFrame = CFrame.new(1e9, 1e9, 1e9)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Packages = ReplicatedStorage.Packages
local Trove = require(Packages.Trove)

--[=[
	@class PoolService

	Object pooling done right.
]=]
local PoolService = {
	_pools = {} :: { [string]: Pool },
}

local Parts = {}
local CFrames = {}

--[=[
	@class Pool

	An object pool, to relieve the stress on the server/client of making and destroying new parts over and over again.
]=]
local Pool = {}
Pool.__index = Pool

local Updating = false
local ByeByeFunction = coroutine.wrap(function(): thread
	while true do
		workspace:BulkMoveTo(Parts, CFrames, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(Parts)
		table.clear(CFrames)

		Updating = false
		coroutine.yield()
	end
end)

export type Pool = typeof(setmetatable(
	{} :: {
		Template: BasePart | Model,
		InUse: { [BasePart | Model]: boolean },
		Open: { BasePart | Model },
		PoolSize: number,
		ExpansionSize: number,
		_trove: Trove.Trove,
		_name: string,
		_model: boolean,
	},
	Pool
))

--[=[
	@method init
	@within PoolService

	Initializes PoolService, creating a pool for each instance tagged with 'Pool', and making a pool for each child of an instance tagged with 'PoolChildren'
]=]
function PoolService.Init(self: PoolService)
	for _, PoolHolder in CollectionService:GetTagged("PoolChildren") do
		for _, child in PoolHolder:GetChildren() do
			self._new(child, child.Name)
		end
	end

	for _, Pool in CollectionService:GetTagged("Pool") do
		self._new(Pool, Pool.Name)
	end
end

--[=[
	@method GetPool
	@within PoolService
	@param name string
	@return Pool Pool

	Get a pool by name, throw an error otherwise.
]=]
function PoolService.GetPool(self: PoolService, name: string): Pool
	return assert(self._pools[name], `Failed to find pool of name '{name}'`)
end

--[=[
	Return a part to its appropiate pool or poolgroup. One or the other must be provided.

	:::warn
	`:ReturnPart(...)` should be called on its Pool if the script has access to it instead of calling it on PoolService, or using the Return function provided by :GetPart(...).
	This function would be used for something like 2 projectiles colliding, and them needing to be returned.
	:::

	@method ReturnPart
	@within PoolService
	@param Part BasePart | Model
	@param PoolName string?
	@param PoolGroup string?
	@return ()
]=]
function PoolService.ReturnPart(self: PoolService, Part: BasePart | Model, PoolName: string?): ()
	assert(PoolName, "PoolName was nil or an invalid type")

	local Pool = self:GetPool(PoolName)
	Pool:ReturnPart(Part)
end

--[=[
	Construct a new pool.
	```lua
	local Pool = PoolService._new(workspace.Part, "Projectile", 67)
	local part, Return = pool:GetPart()

	-- do whatever you want with part...

	Return()
	```

	@constructor
	@private
	@param Template BasePart | Model
	@param PoolName string
	@param PoolSize number? -- Optional. Defaults to 5.
	@return Pool
]=]
function PoolService._new(Template: BasePart | Model, PoolName: string, PoolSize: number?): Pool
	local IsModel = Template:IsA("Model")

	local Pool = setmetatable({
		Template = Template,
		InUse = {},
		Open = {},
		PoolSize = PoolSize or 5,
		ExpansionSize = 10,
		_trove = Trove.new(),
		_name = PoolName,
		_model = IsModel,
	}, Pool)

	for i = 1, PoolSize or 5 do
		local Part = Template:Clone()
		local PrimaryPart = IsModel and (Part :: Model).PrimaryPart or (Part :: BasePart)
		PrimaryPart.CFrame = ByeByeCFrame
		PrimaryPart.Anchored = true

		table.insert(Pool.Open, Part)
		Pool._trove:Add(Part)
	end

	PoolService._pools[PoolName] = Pool
	return Pool
end

--[=[
	Return a part to the pool.

	@method ReturnPart
	@within Pool
	@param Part BasePart | Model
	@return ()
]=]
function Pool.ReturnPart(self: Pool, Part: BasePart | Model): ()
	if table.find(self.Open, Part) then
		warn(`'{Part:GetFullName()}' is already returned`)
		return
	end

	assert(self.InUse[Part], `Part of of name '{Part:GetFullName()}' is not part of pool '{self._name}'`)

	self.InUse[Part] = nil
	local PrimaryPart = self._model and (Part :: Model).PrimaryPart or (Part :: BasePart)
	PrimaryPart.Anchored = true

	table.insert(self.Open, Part)
	table.insert(Parts, Part)
	table.insert(CFrames, ByeByeCFrame)

	if not Updating then
		Updating = true
		task.defer(ByeByeFunction)
	end
end

--[=[
	Get a part from the pool, and set its CFrame to the given CFrame, if provided.

	@method GetPart
	@within Pool
	@param CFrame CFrame?
	@return Part BasePart | Model
	@return ReturnFunction () -> ()
]=]
function Pool.GetPart(self: Pool, CFrame: CFrame?): (BasePart | Model, () -> ())
	local Part = table.remove(self.Open) or self:_expand(self.ExpansionSize) :: BasePart | Model -- or expand
	self.InUse[Part] = true

	if CFrame then
		table.insert(Parts, Part)
		table.insert(CFrames, CFrame)

		if not Updating then
			Updating = true
			task.defer(ByeByeFunction)
		end
	end

	return Part, function()
		self:ReturnPart(Part)
	end
end

--[=[
	Expand the pool.

	@private
	@method Expand
	@within Pool
	@return Part BasePart | Model
]=]
function Pool._expand(self: Pool, size: number)
	for i = 1, size or 5 do
		local Part = self.Template:Clone()
		local PrimaryPart = self._model and (Part :: Model).PrimaryPart or (Part :: BasePart)
		PrimaryPart.CFrame = ByeByeCFrame
		PrimaryPart.Anchored = true

		table.insert(self.Open, Part)
		self._trove:Add(Part)
	end

	self.PoolSize += size or 5

	return table.remove(self.Open)
end

--[=[
	Destroy the pool.

	@method Destroy
	@within Pool
	@return ()
]=]
function Pool.Destroy(self: Pool): ()
	self._trove:Destroy()
	setmetatable(self :: any, nil)
end

export type PoolService = typeof(PoolService)

return PoolService :: PoolService
