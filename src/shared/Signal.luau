--!strict
--[[
	Signal
	Tiny pure-Luau signal. Handlers run in their own thread so one erroring
	handler cannot break the others.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { [Connection]: (T...) -> () } = {}

	local self = {}

	function self.Connect(_: any, handler: (T...) -> ()): Connection
		local connection = {} :: any
		connection.Connected = true
		function connection.Disconnect(conn: any)
			conn.Connected = false
			handlers[conn] = nil
		end
		handlers[connection] = handler
		return connection :: Connection
	end

	function self.Fire(_: any, ...: T...)
		-- Snapshot first: handlers may connect/disconnect while we fire.
		local list = {}
		for connection, handler in handlers do
			table.insert(list, { connection, handler })
		end
		for _, pair in list do
			if pair[1].Connected then
				task.spawn(pair[2], ...)
			end
		end
	end

	function self.DisconnectAll(_: any)
		for connection in handlers do
			connection.Connected = false
		end
		table.clear(handlers)
	end

	return (self :: any) :: Signal<T...>
end

return Signal
