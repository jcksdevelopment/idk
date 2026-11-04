--!strict
--[[
	MockDataStore
	In-memory stand-in for a GlobalDataStore, used ONLY in Studio when API
	access is disabled. Values are deep-copied through JSON so code behaves as
	if it were talking to a real, serialising store.
]]

local HttpService = game:GetService("HttpService")

local MockDataStore = {}

export type MockStore = {
	UpdateAsync: (self: MockStore, key: string, transform: (any) -> any) -> any,
	GetAsync: (self: MockStore, key: string) -> any,
}

local function roundTrip(value: any): any
	if value == nil then
		return nil
	end
	return HttpService:JSONDecode(HttpService:JSONEncode(value))
end

function MockDataStore.new(): MockStore
	local data: { [string]: string } = {}
	local store = {}

	function store.UpdateAsync(_: any, key: string, transform: (any) -> any): any
		task.wait(0.05) -- emulate network latency so yields happen like in production
		local raw = data[key]
		local current = if raw then HttpService:JSONDecode(raw) else nil
		local result = transform(current)
		if result == nil then
			return roundTrip(current) -- cancelled write
		end
		data[key] = HttpService:JSONEncode(result)
		return roundTrip(result)
	end

	function store.GetAsync(_: any, key: string): any
		local raw = data[key]
		return if raw then HttpService:JSONDecode(raw) else nil
	end

	return (store :: any) :: MockStore
end

return MockDataStore
