--!strict

export type ChooseBaseCallback = (slot: "North" | "South" | "East" | "West") -> ()

type BaseOptionSpec = {
	Slot: "North" | "South" | "East" | "West",
	Title: string,
	Subtitle: string,
	Color: Color3,
	DarkColor: Color3,
}

local BaseSelectController = {}

local BASE_OPTIONS: { BaseOptionSpec } = {
	{
		Slot = "North",
		Title = "NORTH CASTLE",
		Subtitle = "Purple Kingdom • Near 🥕 Veg Farm & 🥩 Ranch",
		Color = Color3.fromRGB(142, 74, 224),
		DarkColor = Color3.fromRGB(92, 42, 158),
	},
	{
		Slot = "South",
		Title = "SOUTH CASTLE",
		Subtitle = "Gold Kingdom • Near 🐟 Fishing Port & 🥭 Orchard",
		Color = Color3.fromRGB(224, 168, 28),
		DarkColor = Color3.fromRGB(168, 118, 16),
	},
	{
		Slot = "East",
		Title = "EAST CASTLE",
		Subtitle = "Cyan Kingdom • Near 🥩 Ranch & 🐟 Fishing Port",
		Color = Color3.fromRGB(38, 152, 224),
		DarkColor = Color3.fromRGB(22, 102, 164),
	},
	{
		Slot = "West",
		Title = "WEST CASTLE",
		Subtitle = "Red Kingdom • Near 🥕 Veg Farm & 🥭 Orchard",
		Color = Color3.fromRGB(218, 58, 62),
		DarkColor = Color3.fromRGB(154, 34, 38),
	},
}

local overlayFrame: Frame? = nil
local claimButtons: { [string]: TextButton } = {}
local statusLabels: { [string]: TextLabel } = {}

local function makeCorner(parent: Instance, radius: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeStroke(parent: Instance, color: Color3, thickness: number, mode: Enum.ApplyStrokeMode?): ()
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
end

function BaseSelectController.Init(parentGui: ScreenGui, onChooseBase: ChooseBaseCallback): ()
	local overlay = Instance.new("Frame")
	overlay.Name = "BaseSelectOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
	overlay.BackgroundTransparency = 0.32
	overlay.ZIndex = 20
	overlay.Visible = false
	overlay.Parent = parentGui
	overlayFrame = overlay

	local modal = Instance.new("Frame")
	modal.Name = "BaseSelectModal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromOffset(680, 460)
	modal.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
	modal.ZIndex = 21
	modal.Parent = overlay
	makeCorner(modal, 18)
	makeStroke(modal, Color3.fromRGB(255, 206, 56), 2.5)

	local title = Instance.new("TextLabel")
	title.Position = UDim2.new(0, 20, 0, 16)
	title.Size = UDim2.new(1, -40, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = "🏰 WELCOME TO FOOD EMPIRE"
	title.TextSize = 24
	title.TextColor3 = Color3.fromRGB(255, 224, 92)
	title.ZIndex = 22
	title.Parent = modal
	makeStroke(title, Color3.fromRGB(16, 20, 30), 2, Enum.ApplyStrokeMode.Contextual)

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.new(0, 24, 0, 54)
	sub.Size = UDim2.new(1, -48, 0, 38)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextWrapped = true
	sub.Text = "Choose your 1 Castle Base below! Includes your Restaurant HQ & starter Seafood & Fish Ingredient Warehouse (unlock Vegetable, Fruit & Meat Warehouses with Gold)."
	sub.TextSize = 13
	sub.TextColor3 = Color3.fromRGB(224, 232, 248)
	sub.ZIndex = 22
	sub.Parent = modal

	local gridHolder = Instance.new("Frame")
	gridHolder.Position = UDim2.new(0, 24, 0, 104)
	gridHolder.Size = UDim2.new(1, -48, 1, -124)
	gridHolder.BackgroundTransparency = 1
	gridHolder.ZIndex = 22
	gridHolder.Parent = modal

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(308, 158)
	grid.CellPadding = UDim2.fromOffset(16, 16)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.Parent = gridHolder

	for _, opt in ipairs(BASE_OPTIONS) do
		local card = Instance.new("Frame")
		card.Name = "Card_" .. opt.Slot
		card.BackgroundColor3 = Color3.fromRGB(30, 38, 56)
		card.ZIndex = 22
		card.Parent = gridHolder
		makeCorner(card, 14)
		makeStroke(card, opt.Color, 2.2)

		local topBand = Instance.new("Frame")
		topBand.Size = UDim2.new(1, 0, 0, 42)
		topBand.BackgroundColor3 = opt.Color
		topBand.BorderSizePixel = 0
		topBand.ZIndex = 23
		topBand.Parent = card
		makeCorner(topBand, 12)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -16, 1, 0)
		nameLbl.Position = UDim2.new(0, 8, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBlack
		nameLbl.Text = "🏰 " .. opt.Title
		nameLbl.TextSize = 16
		nameLbl.TextColor3 = Color3.new(1, 1, 1)
		nameLbl.ZIndex = 24
		nameLbl.Parent = topBand
		makeStroke(nameLbl, Color3.fromRGB(16, 20, 30), 1.6, Enum.ApplyStrokeMode.Contextual)

		local infoLbl = Instance.new("TextLabel")
		infoLbl.Position = UDim2.new(0, 12, 0, 48)
		infoLbl.Size = UDim2.new(1, -24, 0, 34)
		infoLbl.BackgroundTransparency = 1
		infoLbl.Font = Enum.Font.GothamBold
		infoLbl.TextWrapped = true
		infoLbl.Text = opt.Subtitle
		infoLbl.TextSize = 12
		infoLbl.TextColor3 = Color3.fromRGB(218, 226, 244)
		infoLbl.ZIndex = 23
		infoLbl.Parent = card

		local statusLbl = Instance.new("TextLabel")
		statusLbl.Position = UDim2.new(0, 12, 0, 82)
		statusLbl.Size = UDim2.new(1, -24, 0, 18)
		statusLbl.BackgroundTransparency = 1
		statusLbl.Font = Enum.Font.GothamBold
		statusLbl.Text = "AVAILABLE  •  Starter Seafood & Fish Ingredient Warehouse"
		statusLbl.TextSize = 11
		statusLbl.TextColor3 = Color3.fromRGB(132, 242, 168)
		statusLbl.ZIndex = 23
		statusLbl.Parent = card
		statusLabels[opt.Slot] = statusLbl

		local btn = Instance.new("TextButton")
		btn.Name = "Claim_" .. opt.Slot
		btn.Position = UDim2.new(0, 14, 1, -48)
		btn.Size = UDim2.new(1, -28, 0, 38)
		btn.BackgroundColor3 = opt.Color
		btn.Font = Enum.Font.GothamBlack
		btn.Text = "CLAIM " .. string.upper(opt.Slot) .. " BASE"
		btn.TextSize = 14
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.ZIndex = 24
		btn.Parent = card
		makeCorner(btn, 10)
		makeStroke(btn, Color3.fromRGB(16, 20, 30), 1.5, Enum.ApplyStrokeMode.Contextual)
		claimButtons[opt.Slot] = btn

		btn.MouseButton1Click:Connect(function()
			onChooseBase(opt.Slot)
		end)
	end
end

function BaseSelectController.Update(_state: { [string]: any }): ()
	if not overlayFrame then
		return
	end
	-- Bases are automatically assigned at random by the server on join — never show manual base picker!
	overlayFrame.Visible = false
end

return BaseSelectController
