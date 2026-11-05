--!strict
--[[
	PetsPanel
	Hatch eggs (in-game cash only), choose up to 3 pets to follow you, and
	send extra pets home. All rolls and checks are done by the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Items = require(Shared.Items)
local Locale = require(Shared.Locale)
local Pets = require(Shared.Pets)
local Types = require(Shared.Types)

local Controllers = script.Parent.Parent.Controllers
local SoundController = require(Controllers.SoundController)
local StateController = require(Controllers.StateController)
local UIController = require(Controllers.UIController)

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local PetsPanel = {}

type EggCard = { Key: string, Price: number, UnlockLevel: number, Button: TextButton, Lock: TextLabel }
type PetCard = {
	Frame: Frame,
	Stroke: UIStroke,
	Icon: TextLabel,
	Name: TextLabel,
	Bonus: TextLabel,
	Equip: TextButton,
	Sell: TextButton,
	Fuse: TextButton,
}

local function bonusText(kind: string, amount: number): string
	local percent = amount * 100
	local shown = if percent < 1 then string.format("%.1f", percent) else tostring(math.floor(percent + 0.5))
	return Locale.T("Pets_Bonus_" .. kind, { shown })
end

function PetsPanel.Build(gui: ScreenGui)
	local panel, header, close =
		Create.Panel("Pets", Locale.T("Title_Pets", { "0", tostring(Config.Pets.MaxOwned) }), Theme.Colors.Pink, 1.5, gui)
	close.Activated:Connect(UIController.Close)

	------------------------------------------------------------------
	-- Eggs
	------------------------------------------------------------------
	Create.Label({
		Text = Locale.T("Pets_Eggs"),
		Font = Theme.Fonts.Display,
		TextColor3 = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.6, 0.05),
		Position = UDim2.fromScale(0.03, 0.145),
		MaxTextSize = 24,
		Parent = panel,
	})
	local eggRow: Frame = Create.new("Frame", {
		Position = UDim2.fromScale(0.03, 0.2),
		Size = UDim2.fromScale(0.94, 0.2),
		BackgroundTransparency = 1,
		Parent = panel,
	}, { Create.List(Enum.FillDirection.Horizontal, 0.02) })

	local eggKeys: { string } = {}
	for key in Config.Pets.Eggs do
		table.insert(eggKeys, key)
	end
	table.sort(eggKeys, function(a, b)
		return (Config.Pets.Eggs :: any)[a].Order < (Config.Pets.Eggs :: any)[b].Order
	end)

	local eggCards: { EggCard } = {}
	for index, key in eggKeys do
		local egg = (Config.Pets.Eggs :: any)[key]
		local card: Frame = Create.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromScale(0.49, 1),
			BackgroundColor3 = Theme.Colors.PanelLight,
			Parent = eggRow,
		}, { Create.Corner(UDim.new(0.15, 0)), Create.Stroke(Theme.Colors.Accent, 2) })
		Create.Label({
			Text = egg.Icon,
			Size = UDim2.fromScale(0.2, 0.8),
			Position = UDim2.fromScale(0.02, 0.1),
			MaxTextSize = 60,
			Parent = card,
		})
		Create.Label({
			Text = Locale.T("Egg_" .. key),
			Font = Theme.Fonts.Display,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.42, 0.35),
			Position = UDim2.fromScale(0.23, 0.08),
			MaxTextSize = 26,
			Parent = card,
		})
		local total = 0
		for _, rarity in Items.Rarities do
			total += egg.Weights[rarity] or 0
		end
		local odds = {}
		for _, rarity in Items.Rarities do
			table.insert(
				odds,
				string.format("%s %d%%", Locale.RarityName(rarity), math.floor((egg.Weights[rarity] or 0) / math.max(total, 1) * 100 + 0.5))
			)
		end
		Create.Label({
			Text = table.concat(odds, " · "),
			Font = Theme.Fonts.Regular,
			TextColor3 = Theme.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.42, 0.3),
			Position = UDim2.fromScale(0.23, 0.55),
			MaxTextSize = 15,
			Parent = card,
		})
		local button = Create.Button({
			Text = Locale.T("Pets_Hatch", { Format.Cash(egg.Price) }),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.97, 0.5),
			Size = UDim2.fromScale(0.3, 0.6),
			BackgroundColor3 = Theme.Colors.Success,
			MaxTextSize = 20,
			Parent = card,
		}, function()
			local snapshot = StateController.Current
			if snapshot and snapshot.Level < egg.UnlockLevel then
				Toast.Show("error", Locale.T("N_EggLocked", { tostring(egg.UnlockLevel) }))
				return
			end
			if snapshot and snapshot.Cash < egg.Price then
				Toast.Show("error", Locale.T("N_NotEnoughCash"))
				return
			end
			SoundController.Play("Buy")
			StateController.Fire("BuyEgg", key)
		end)
		local lock = Create.Label({
			Text = Locale.T("Pets_Locked", { tostring(egg.UnlockLevel) }),
			Font = Theme.Fonts.Display,
			BackgroundTransparency = 0.25,
			BackgroundColor3 = Theme.Colors.PanelDark,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 6,
			MaxTextSize = 30,
			Parent = card,
		})
		Create.Corner(UDim.new(0.15, 0)).Parent = lock
		table.insert(eggCards, { Key = key, Price = egg.Price, UnlockLevel = egg.UnlockLevel, Button = button, Lock = lock })
	end

	------------------------------------------------------------------
	-- Team summary + pet grid
	------------------------------------------------------------------
	local summary = Create.Label({
		Text = "",
		TextColor3 = Theme.Colors.Pink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.94, 0.05),
		Position = UDim2.fromScale(0.03, 0.42),
		MaxTextSize = 22,
		Parent = panel,
	})
	local scroller: ScrollingFrame = Create.new("ScrollingFrame", {
		Position = UDim2.fromScale(0.03, 0.48),
		Size = UDim2.fromScale(0.94, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.Muted,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	})
	local grid: UIGridLayout = Create.new("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroller })
	local function resize()
		local width = scroller.AbsoluteSize.X - 12
		local cell = math.floor(width * 0.19)
		grid.CellSize = UDim2.fromOffset(cell, math.floor(cell * 1.3))
		grid.CellPadding = UDim2.fromOffset(math.floor(width * 0.012), math.floor(width * 0.012))
	end
	UIController.Track(scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()

	local empty = Create.Label({
		Text = Locale.T("Pets_Empty"),
		Font = Theme.Fonts.Regular,
		TextColor3 = Theme.Colors.Muted,
		Size = UDim2.fromScale(0.8, 0.1),
		Position = UDim2.fromScale(0.1, 0.65),
		Visible = false,
		MaxTextSize = 26,
		Parent = panel,
	})

	local cards: { [string]: PetCard } = {}
	local confirmSell: { [string]: number } = {}

	local function makeCard(uid: string): PetCard
		local stroke = Create.Stroke(Theme.Colors.Muted, 3)
		local frame: Frame = Create.new("Frame", {
			Name = uid,
			BackgroundColor3 = Theme.Colors.PanelLight,
			Parent = scroller,
		}, { Create.Corner(UDim.new(0.1, 0)), stroke })
		local icon = Create.Label({
			Text = "",
			Size = UDim2.fromScale(1, 0.32),
			Position = UDim2.fromScale(0, 0.03),
			MaxTextSize = 56,
			Parent = frame,
		})
		local name = Create.Label({
			Text = "",
			Size = UDim2.fromScale(0.9, 0.12),
			Position = UDim2.fromScale(0.05, 0.36),
			MaxTextSize = 20,
			Parent = frame,
		})
		local bonus = Create.Label({
			Text = "",
			Font = Theme.Fonts.Regular,
			TextColor3 = Theme.Colors.Accent,
			Size = UDim2.fromScale(0.9, 0.1),
			Position = UDim2.fromScale(0.05, 0.49),
			MaxTextSize = 16,
			Parent = frame,
		})
		local equip = Create.Button({
			Text = "",
			Size = UDim2.fromScale(0.9, 0.17),
			Position = UDim2.fromScale(0.05, 0.62),
			BackgroundColor3 = Theme.Colors.Info,
			MaxTextSize = 18,
			Parent = frame,
		}, function()
			local snapshot = StateController.Current
			if not snapshot then
				return
			end
			for _, pet in snapshot.Pets do
				if pet.Id == uid then
					StateController.Fire("EquipPet", uid, not pet.Equipped)
					return
				end
			end
		end)
		local sell: TextButton
		sell = Create.Button({
			Text = "",
			Size = UDim2.fromScale(0.9, 0.14),
			Position = UDim2.fromScale(0.05, 0.82),
			BackgroundColor3 = Theme.Colors.PanelDark,
			MaxTextSize = 15,
			Parent = frame,
		}, function()
			if (confirmSell[uid] or 0) > os.clock() then
				confirmSell[uid] = nil
				StateController.Fire("SellPet", uid)
				return
			end
			confirmSell[uid] = os.clock() + 3
			local previous = sell.Text
			sell.Text = Locale.T("Rebirth_Confirm")
			task.delay(3.1, function()
				if sell.Parent and (confirmSell[uid] or 0) <= os.clock() then
					sell.Text = previous
				end
			end)
		end)
		local fuse = Create.Button({
			Text = Locale.T("Pets_Fuse"),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(0.98, 0.02),
			Size = UDim2.fromScale(0.56, 0.13),
			BackgroundColor3 = Theme.Colors.VIP,
			Visible = false,
			ZIndex = 3,
			MaxTextSize = 14,
			Parent = frame,
		}, function()
			StateController.Fire("FusePets", uid)
		end)
		return { Frame = frame, Stroke = stroke, Icon = icon, Name = name, Bonus = bonus, Equip = equip, Sell = sell, Fuse = fuse }
	end

	local function render(snapshot: Types.Snapshot)
		local titleLabel = header:FindFirstChild("Title") :: TextLabel?
		if titleLabel then
			titleLabel.Text = Locale.T("Title_Pets", { tostring(#snapshot.Pets), tostring(Config.Pets.MaxOwned) })
		end
		for _, egg in eggCards do
			egg.Lock.Visible = snapshot.Level < egg.UnlockLevel
			Create.SetButtonEnabled(egg.Button, snapshot.Cash >= egg.Price, Theme.Colors.Success)
			egg.Button.Active = true
		end

		local equippedCount = 0
		for _, pet in snapshot.Pets do
			if pet.Equipped then
				equippedCount += 1
			end
		end
		local parts = {}
		for _, kind in { "Money", "Repair", "XP", "Luck" } do
			local amount = snapshot.PetBonuses[kind] or 0
			if amount > 0 then
				table.insert(parts, bonusText(kind, amount))
			end
		end
		summary.Text = Locale.T("Pets_Equipped", { tostring(equippedCount), tostring(Config.Pets.MaxEquipped) })
			.. (if #parts > 0 then "  ·  " .. Locale.T("Pets_Total", { table.concat(parts, ", ") }) else "")
		empty.Visible = #snapshot.Pets == 0

		-- How many pets share kind + star level (fusion needs 3).
		local groupSize: { [string]: number } = {}
		for _, pet in snapshot.Pets do
			local groupKey = pet.PetId .. ":" .. tostring(pet.Stars or 0)
			groupSize[groupKey] = (groupSize[groupKey] or 0) + 1
		end

		local seen: { [string]: boolean } = {}
		for order, pet in snapshot.Pets do
			local def = Pets.Get(pet.PetId)
			if def then
				seen[pet.Id] = true
				local card = cards[pet.Id]
				if not card then
					card = makeCard(pet.Id)
					cards[pet.Id] = card
				end
				local color = Items.RarityColors[def.Rarity] or Theme.Colors.Muted
				card.Frame.LayoutOrder = order
				card.Stroke.Color = if pet.Equipped then Theme.Colors.Success else color
				card.Stroke.Thickness = if pet.Equipped then 4 else 3
				card.Icon.Text = def.Icon
				local stars = pet.Stars or 0
				card.Name.Text = Locale.T("Pet_" .. def.Id) .. (if stars > 0 then " " .. string.rep("⭐", stars) else "")
				card.Fuse.Visible = stars < Config.Pets.MaxStars and (groupSize[def.Id .. ":" .. tostring(stars)] or 0) >= 3
				card.Name.TextColor3 = color
				card.Bonus.Text = bonusText(def.Bonus, def.Amount * (Config.Pets.StarMultipliers[stars] or 1))
				card.Equip.Text = Locale.T(if pet.Equipped then "Pets_Unequip" else "Pets_Equip")
				card.Equip.BackgroundColor3 = if pet.Equipped then Theme.Colors.PanelDark else Theme.Colors.Info
				if (confirmSell[pet.Id] or 0) <= os.clock() then
					card.Sell.Text = Locale.T("Pets_Sell", { Format.Cash((Config.Pets.SellValue :: any)[def.Rarity] or 0) })
				end
			end
		end
		for uid, card in cards do
			if not seen[uid] then
				card.Frame:Destroy()
				cards[uid] = nil
			end
		end
	end

	UIController.Track(StateController.Changed:Connect(render))
	if StateController.Current then
		render(StateController.Current)
	end

	UIController.Register({ Name = "Pets", Frame = panel })
end

return PetsPanel
