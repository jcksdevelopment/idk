--!strict
-- Display formatting helpers (client + server).

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa" }

function Format.Commas(n: number): string
	local whole = tostring(math.floor(math.abs(n)))
	local formatted = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return (if n < 0 then "-" else "") .. formatted
end

function Format.Cash(n: number): string
	if math.abs(n) < 100000 then
		return "$" .. Format.Commas(n)
	end
	local tier = 1
	local value = n
	while math.abs(value) >= 1000 and tier < #SUFFIXES do
		value /= 1000
		tier += 1
	end
	return string.format("$%.2f%s", value, SUFFIXES[tier])
end

function Format.Duration(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

return table.freeze(Format)
