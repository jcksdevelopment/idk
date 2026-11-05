--!strict
--[[
	Icons
	Shows an uploaded image (Config.Images) on a TextLabel when one is set,
	otherwise keeps the emoji. Lets the game ship with emoji today and switch
	to real art just by pasting asset ids into Config.Images.
]]

local Config = require(script.Parent.Config)

local Icons = {}

-- category: "Items" | "Pets" | "Crates" | "Eggs" | "Shop"
function Icons.Lookup(category: string, key: string): string?
	local group = (Config.Images :: any)[category]
	local id = if group then group[key] else nil
	if type(id) == "string" and id ~= "" then
		return id
	end
	return nil
end

-- Sets the label to an image (if given) or the emoji text. Returns the label.
function Icons.Set<T>(label: T, image: string?, emoji: string): T
	local textLabel = label :: any
	local existing = textLabel:FindFirstChild("IconImage")
	if image then
		local img = existing
		if not img then
			img = Instance.new("ImageLabel")
			img.Name = "IconImage"
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.ScaleType = Enum.ScaleType.Fit
			img.ZIndex = textLabel.ZIndex
			img.Parent = textLabel
		end
		img.Image = image
		textLabel.Text = ""
	else
		if existing then
			existing:Destroy()
		end
		textLabel.Text = emoji
	end
	return label
end

-- Convenience: look up + set in one call.
function Icons.Apply<T>(label: T, category: string, key: string): T
	local textLabel = label :: any
	return Icons.Set(label, Icons.Lookup(category, key), textLabel.Text)
end

return Icons
