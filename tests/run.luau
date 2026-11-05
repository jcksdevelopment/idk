--[[
	Headless test runner (Lune: https://lune-org.github.io/docs).
	Run from the repo root:   lune run tests/run.luau

	What it does (no Roblox needed):
	1. Compiles EVERY .luau file in src/ with the real Luau compiler.
	2. Loads the shared modules (src/shared) through a tiny emulation of
	   Roblox's script tree / require(script.Parent.X), with mocked services.
	3. Runs unit checks on items, localization, progression, valuation,
	   formatting, events, pets and icons.
	4. Simulates a kid playing for 60 minutes to sanity-check the economy.
	Exits with code 1 if anything fails.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local failures = 0
local passes = 0

local function check(condition: any, message: string)
	if condition then
		passes += 1
	else
		failures += 1
		print("  ❌ " .. message)
	end
end

local function section(title: string)
	print("\n== " .. title .. " ==")
end

------------------------------------------------------------------------
-- 1. Compile every file
------------------------------------------------------------------------
section("Compile all .luau files with the Luau compiler")

local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
	return out
end

local files = walk("src", {})
table.sort(files)
local compiled = 0
for _, path in files do
	local ok, err = pcall(luau.compile, fs.readFile(path))
	check(ok, "compile " .. path .. ": " .. tostring(err))
	if ok then
		compiled += 1
	end
end
print(string.format("  compiled %d / %d files", compiled, #files))

------------------------------------------------------------------------
-- 2. Minimal Roblox emulation for shared modules
------------------------------------------------------------------------

local function vector3(x: number?, y: number?, z: number?)
	return { X = x or 0, Y = y or 0, Z = z or 0 }
end
local mocks = {
	Vector3 = { new = vector3, zero = vector3() },
	Vector2 = { new = function(x, y)
		return { X = x, Y = y }
	end },
	Color3 = {
		fromRGB = function(r, g, b)
			return { R = r / 255, G = g / 255, B = b / 255 }
		end,
		new = function(r, g, b)
			return { R = r, G = g, B = b }
		end,
	},
	UDim = { new = function(s, o)
		return { Scale = s, Offset = o }
	end },
	UDim2 = {
		new = function(...)
			return { ... }
		end,
		fromScale = function(x, y)
			return { x, 0, y, 0 }
		end,
		fromOffset = function(x, y)
			return { 0, x, 0, y }
		end,
	},
	Enum = setmetatable({}, {
		__index = function(_, enumName)
			return setmetatable({}, {
				__index = function(_, item)
					return enumName .. "." .. item
				end,
			})
		end,
	}),
}

local guidCounter = 0
local services = {
	RunService = {
		IsStudio = function()
			return false
		end,
		IsServer = function()
			return true
		end,
	},
	HttpService = {
		JSONEncode = function(_, v)
			return serde.encode("json", v)
		end,
		JSONDecode = function(_, s)
			return serde.decode("json", s)
		end,
		GenerateGUID = function()
			guidCounter += 1
			return string.format("00000000-0000-0000-0000-%012d", guidCounter)
		end,
	},
}

-- Script-tree node backed by a file or folder (Rojo naming rules).
local Node = {}
Node.__index = function(self, key)
	local method = rawget(Node, key)
	if method then
		return method
	end
	local child = self:FindFirstChild(key)
	if child then
		return child
	end
	error("No child '" .. tostring(key) .. "' under " .. self.Path, 2)
end

function Node.new(path: string, name: string, parent: any)
	return setmetatable({ Path = path, Name = name, Parent = parent, _children = nil }, Node)
end

-- Directory listings are read up front: Lune's fs calls yield, and yielding
-- inside a metamethod (__index) is not allowed.
local listings: { [string]: { string } } = {}
local function preload(dir: string)
	local entries = fs.readDir(dir)
	listings[dir] = entries
	for _, entry in entries do
		if fs.isDir(dir .. "/" .. entry) then
			preload(dir .. "/" .. entry)
		end
	end
end
preload("src/shared")

function Node.FindFirstChild(self, name: string)
	local entries = listings[self.Path]
	if not entries then
		return nil
	end
	for _, entry in entries do
		local childName = string.gsub(string.gsub(entry, "%.luau$", ""), "%.client$", "")
		childName = string.gsub(childName, "%.server$", "")
		if childName == name then
			return Node.new(self.Path .. "/" .. entry, name, self)
		end
	end
	return nil
end
Node.WaitForChild = Node.FindFirstChild
function Node.IsA(self, className: string)
	return className == "ModuleScript" and listings[self.Path] == nil
end

local shared = Node.new("src/shared", "Shared", nil)
local cache: { [string]: any } = {}

local customRequire

function customRequire(node: any)
	local path = node.Path
	if cache[path] ~= nil then
		return cache[path]
	end
	-- Lune copies the environment's own fields (it does not follow
	-- metatables), so mocks are copied in explicitly.
	local moduleEnv: { [string]: any } = { script = node, require = customRequire }
	for name, value in mocks do
		moduleEnv[name] = value
	end
	moduleEnv.game = {
		GetService = function(_, name)
			if name == "ReplicatedStorage" then
				return { WaitForChild = function()
					return shared
				end, Shared = shared }
			end
			return services[name] or {}
		end,
	}
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = moduleEnv })
	local result = fn()
	cache[path] = if result == nil then false else result
	return result
end

------------------------------------------------------------------------
-- 3. Unit checks
------------------------------------------------------------------------
section("Shared modules")

local Config = customRequire(shared.Config)
local Items = customRequire(shared.Items)
local Locale = customRequire(shared.Locale)
local Progression = customRequire(shared.Progression)
local Valuation = customRequire(shared.Valuation)
local Format = customRequire(shared.Format)
local Pets = customRequire(shared.Pets)
local Events = customRequire(shared.Events)
local Icons = customRequire(shared.Icons)
check(Config and Items and Locale and Progression and Valuation and Format and Pets and Events and Icons, "load shared modules")
print("  loaded Config, Items, Locale, Progression, Valuation, Format, Pets, Events, Icons")

-- Items
local regular = Items.All()
check(#regular == 21, "21 regular items (got " .. #regular .. ")")
for _, rarity in Items.Rarities do
	check(#Items.GetByRarity(rarity) > 0, "regular pool for " .. rarity)
	check(#Items.GetEventPool("Winter", rarity) > 0, "Winter pool for " .. rarity)
	check(#Items.GetEventPool("Halloween", rarity) > 0, "Halloween pool for " .. rarity)
end
for _, crate in Config.Crates do
	local total = 0
	for _, w in crate.Weights do
		total += w
	end
	check(total == 100, "crate weights sum to 100")
end
check(Config.Crates.JunkBox.Weights.Trash == 70 and Config.Crates.JunkBox.Weights.Rare == 25, "JunkBox is 70/25/5")

-- Localization
Locale.SetLanguage("sk")
check(Locale.ItemName("RustySpoon") == "Hrdzavá lyžica", "SK item name")
check(Locale.T("N_Sold", { "@item:GoldenSamovar", "$800" }) == "Predané: Zlatý samovar za $800!", "SK formatting with @item")
check(string.find(Locale.T("N_RewardClaimed", { Locale.EncodeReward({ Cash = 100, Tokens = 2 }) }), "$100", 1, true) ~= nil, "reward encode/decode")
check(Locale.T("Pet_Dragon") == "Drak", "SK pet name")
Locale.SetLanguage("en")
check(Locale.T("Pet_Dragon") == "Dragon", "EN pet name")
check(Locale.Resolve("auto", "sk-sk") == "sk" and Locale.Resolve("auto", "cs-cz") == "sk" and Locale.Resolve("auto", "en-us") == "en", "language auto-detect")
check(Locale.T("Definitely_Missing_Key") == "Definitely_Missing_Key", "missing keys fall back to the key")

-- Progression
check(Progression.XPForLevel(1) == 25, "XP for level 1->2 is 25")
local level, into = Progression.FromTotal(25)
check(level == 2 and into == 0, "25 XP = level 2")
check(Progression.LevelFromTotal(0) == 1, "0 XP = level 1")
check(Progression.LevelCapacityBonus(10) == 4, "level 10 gives +4 slots")

-- Valuation
local item = { TemplateId = "GoldenSamovar", Rarity = "Legendary", State = "Clean", Quality = 1, Shiny = false }
check(Valuation.CleanValue(item) == 800, "clean value")
item.Shiny = true
check(Valuation.CleanValue(item) == 2000, "shiny = 2.5x")
item.Shiny = false
item.State = "Dirty"
check(Valuation.SellValue(item, 1) == 280, "dirty = 35%")
check(Valuation.SellValue(item, 2) == 560, "2x boost")

-- Format
check(Format.Cash(1234) == "$1,234", "cash commas")
check(Format.Cash(1234567) == "$1.23M", "cash suffix")
check(Format.Duration(3725) == "1:02:05" and Format.Duration(65) == "1:05", "durations")

-- Events (UTC dates)
local function at(y, m, d)
	return os.time({ year = y, month = m, day = d, hour = 12 })
end
check(Events.IsActive("Winter", at(2026, 12, 15)), "Winter active Dec 15")
check(Events.IsActive("Winter", at(2027, 1, 3)), "Winter active Jan 3 (wraps New Year)")
check(not Events.IsActive("Winter", at(2026, 7, 1)), "Winter inactive in July")
check(Events.IsActive("Halloween", at(2026, 10, 20)), "Halloween active Oct 20")
check(not Events.IsActive("Halloween", at(2026, 11, 5)), "Halloween over Nov 5")

-- Pets & icons
check(Pets.Get("Dragon") ~= nil and #Pets.ByRarity("Legendary") == 3, "pet catalog")
check(Icons.Lookup("Items", "RustySpoon") == nil, "empty image id falls back to emoji")
for _, template in Items.All() do
	check(Config.Images.Items[template.Id] ~= nil, "image slot for " .. template.Id)
end

-- Box balance: average item value must beat the price, and pricier
-- regular boxes must earn more per minute (repair time ~70% with scrubbing).
local avgQuality = (Config.QualityRange.Min + Config.QualityRange.Max) / 2
local shinyFactor = 1 + Config.Shiny.Chance * (Config.Shiny.ValueMultiplier - 1)
local function crateStats(crate)
	local total, value, seconds = 0, 0, 0
	for _, w in crate.Weights do
		total += w
	end
	for rarity, w in crate.Weights do
		local pool = if crate.Event then Items.GetEventPool(crate.Event, rarity) else Items.GetByRarity(rarity)
		local sum = 0
		for _, template in pool do
			sum += template.BaseValue
		end
		value += (w / total) * (sum / #pool) * avgQuality * shinyFactor
		seconds += (w / total) * Config.Repair.SecondsByRarity[rarity]
	end
	seconds = seconds * 0.7 + 6
	return value, (value - crate.Price) / seconds * 60
end
local regularCrates = {}
for key, crate in Config.Crates do
	local value, perMinute = crateStats(crate)
	check(value > crate.Price, string.format("box %s is profitable (EV %.0f > price %d)", key, value, crate.Price))
	print(string.format("  %-14s price %5s  avg value %6s  profit/min %5s", key, Format.Cash(crate.Price), Format.Cash(value), Format.Cash(perMinute)))
	if not crate.Event then
		table.insert(regularCrates, { Key = key, Price = crate.Price, PerMinute = perMinute })
	end
end
table.sort(regularCrates, function(a, b)
	return a.Price < b.Price
end)
for i = 2, #regularCrates do
	check(
		regularCrates[i].PerMinute > regularCrates[i - 1].PerMinute,
		regularCrates[i].Key .. " earns more per minute than " .. regularCrates[i - 1].Key
	)
end

------------------------------------------------------------------------
-- 4. Economy simulation: one kid, 60 minutes, 1 workbench slot
------------------------------------------------------------------------
section("Economy simulation (60 min, no Robux, scrubbing ~30% of the time)")

math.randomseed(7)
local function roll(weights)
	local r = math.random() * 100
	for _, rarity in Items.Rarities do
		r -= weights[rarity]
		if r < 0 then
			return rarity
		end
	end
	return "Trash"
end

local cash, xp, t, boxes = Config.Economy.StartingCash, 0, 0, 0
local freeUsed = false
local milestones = { [600] = true, [1800] = true, [3600] = true }
while t < 3600 do
	local lvl = Progression.LevelFromTotal(xp)
	-- pick the best affordable unlocked non-event crate
	local best, bestKey = nil, nil
	for key, crate in Config.Crates do
		if not crate.Event and lvl >= crate.UnlockLevel and (cash >= crate.Price or (key == "JunkBox" and not freeUsed)) then
			if not best or crate.Price > best.Price then
				best, bestKey = crate, key
			end
		end
	end
	if not best then
		break
	end
	local price = if bestKey == "JunkBox" and not freeUsed then 0 else best.Price
	if price == 0 then
		freeUsed = true
	end
	cash -= price
	boxes += 1
	local rarity = roll(best.Weights)
	local pool = Items.GetByRarity(rarity)
	local template = pool[math.random(1, #pool)]
	local rec = {
		TemplateId = template.Id,
		Rarity = rarity,
		State = "Clean",
		Quality = 0.8 + math.random() * 0.45,
		Shiny = math.random() < Config.Shiny.Chance,
	}
	local repair = Valuation.RepairSeconds(rarity) * 0.7 -- some scrubbing
	t += repair + 6 -- + walking between stalls
	cash += Valuation.SellValue(rec, 1)
	xp += Config.Progression.XP.CrateOpened + Config.Progression.XP.Repaired[rarity] + Config.Progression.XP.Sold[rarity]
	local newLevel = Progression.LevelFromTotal(xp)
	for l = lvl + 1, newLevel do
		cash += l * Config.Progression.LevelUpCashPerLevel
	end
	for mark in milestones do
		if t >= mark then
			milestones[mark] = nil
			print(string.format("  after %2d min: level %d, cash %s, boxes opened %d", mark // 60, newLevel, Format.Cash(cash), boxes))
		end
	end
end
local finalLevel = Progression.LevelFromTotal(xp)
check(finalLevel >= 5, "a kid reaches at least level 5 in an hour (got " .. finalLevel .. ")")
check(cash > Config.Economy.StartingCash, "economy is profitable without Robux")

------------------------------------------------------------------------
print(string.format("\nResult: %d checks passed, %d failed", passes, failures))
process.exit(if failures == 0 then 0 else 1)
