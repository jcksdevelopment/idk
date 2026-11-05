--!strict
--[[
	RemoteGuard
	The ONLY way server code listens to client remotes. Every request passes:

	1. Argument count check   - exploit tools often append extra args; reject.
	2. Per-argument validators - strict type / length / pattern checks, so a
	   handler never sees a table where it expects a string, NaN, huge strings,
	   Instances, etc.
	3. Per-remote token bucket - stops auto-clickers / macro spam.
	4. Global per-player bucket - caps total remote traffic from one client.
	5. Protected execution     - a handler error never propagates or leaks.

	Violations are reported to FlagService. Rate-limit drops are cheap; only
	sustained spam accumulates enough weight to matter.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local FlagService = require(script.Parent.FlagService)

export type Validator = (value: unknown) -> boolean

export type RemoteSpec = {
	RatePerSecond: number,
	Burst: number,
	Args: { Validator },
	Silent: boolean?, -- true: rate-limit drops are expected (tap games) and never flagged
}

type Bucket = { Tokens: number, Last: number, Drops: number }

local RemoteGuard = {}

local buckets: { [Player]: { [string]: Bucket } } = {}

local GUID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

-- Validators ----------------------------------------------------------

RemoteGuard.Validators = {}

function RemoteGuard.Validators.ItemId(value: unknown): boolean
	return type(value) == "string" and #value == 36 and string.match(value, GUID_PATTERN) ~= nil
end

function RemoteGuard.Validators.IntRange(min: number, max: number): Validator
	return function(value: unknown): boolean
		return type(value) == "number" and value == math.floor(value) and value >= min and value <= max
	end
end

function RemoteGuard.Validators.OneOf(options: { string }): Validator
	return function(value: unknown): boolean
		return type(value) == "string" and table.find(options, value) ~= nil
	end
end

function RemoteGuard.Validators.BooleanOrShortString(value: unknown): boolean
	return type(value) == "boolean" or (type(value) == "string" and #value <= 16)
end

function RemoteGuard.Validators.KeyOf(map: { [string]: any }): Validator
	return function(value: unknown): boolean
		return type(value) == "string" and #value <= 64 and map[value] ~= nil
	end
end

-- Token bucket --------------------------------------------------------

local function take(player: Player, name: string, rate: number, burst: number): (boolean, Bucket)
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local bucket = perPlayer[name]
	local now = os.clock()
	if not bucket then
		bucket = { Tokens = burst, Last = now, Drops = 0 }
		perPlayer[name] = bucket
	end
	bucket.Tokens = math.min(burst, bucket.Tokens + (now - bucket.Last) * rate)
	bucket.Last = now
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true, bucket
	end
	bucket.Drops += 1
	return false, bucket
end

-- Binding -------------------------------------------------------------

function RemoteGuard.Bind(name: string, spec: RemoteSpec, handler: (Player, ...any) -> ())
	local remote = Net.Get(name)
	local expectedArgs = #spec.Args

	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		-- Global budget first: the cheapest possible rejection for floods.
		local globalOk, globalBucket = take(player, "__global", Config.AntiExploit.GlobalRatePerSecond, Config.AntiExploit.GlobalBurst)
		if not globalOk then
			if globalBucket.Drops % 50 == 1 then
				FlagService.Flag(player, "RemoteFlood", 10)
			end
			return
		end

		local ok, bucket = take(player, name, spec.RatePerSecond, spec.Burst)
		if not ok then
			-- Humans hit this occasionally; macros hit it constantly.
			if not spec.Silent and bucket.Drops % 20 == 0 then
				FlagService.Flag(player, "RateLimit:" .. name, 5)
			end
			return
		end

		local argCount = select("#", ...)
		if argCount ~= expectedArgs then
			FlagService.Flag(player, string.format("ArgCount:%s(%d)", name, argCount), 10)
			return
		end

		for index, validator in spec.Args do
			local value = select(index, ...)
			if not validator(value) then
				FlagService.Flag(player, string.format("BadArg:%s#%d(%s)", name, index, typeof(value)), 10)
				return
			end
		end

		local args = table.pack(...)
		local success, err = pcall(handler, player, table.unpack(args, 1, args.n))
		if not success then
			warn(string.format("[RemoteGuard] %s handler error for %s: %s", name, player.Name, tostring(err)))
		end
	end)
end

function RemoteGuard.Start()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return RemoteGuard
