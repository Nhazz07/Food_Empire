--!strict

-- Custom Dark-Mafia Numbered Hotbar (Positions 1..5+, expanding cleanly as tools are unlocked).
-- Preserves exact 1-9 key & click equip/unequip behavior while adding a consistent 3D ViewportFrame
-- thumbnail underneath each slot's visible number and readable name.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ModelPreviewHelper = require("./ModelPreviewHelper")

local HotbarController = {}

local MIN_SLOTS = 5
local MAX_SLOTS = 9
local SLOT_PAD = 6

local KEY_CODES: { Enum.KeyCode } = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local BG_DEFAULT = Color3.fromRGB(15, 18, 25)
local BG_HOVER = Color3.fromRGB(24, 28, 38)
local BG_SELECTED = Color3.fromRGB(28, 31, 40)
local BORDER_DEFAULT = Color3.fromRGB(54, 60, 74)
local BORDER_HOVER = Color3.fromRGB(118, 102, 62)
local BORDER_SELECTED = Color3.fromRGB(212, 178, 102)
local ACCENT_GOLD = Color3.fromRGB(212, 178, 102)

type SlotWidget = {
	Index: number,
	Button: TextButton,
	Stroke: UIStroke,
	SelectedBar: Frame,
	NumLabel: TextLabel,
	NameLabel: TextLabel,
	ThumbHost: Frame,
	CurrentTool: Tool?,
	LastPreviewKey: string?,
	IsHovered: boolean,
}

local hotbarGui: ScreenGui? = nil
local hotbarScale: UIScale? = nil
local scaleConn: RBXScriptConnection? = nil
local barFrame: Frame? = nil
local slots: { SlotWidget } = {}
local orderedTools: { Tool } = {}
local activeConns: { RBXScriptConnection } = {}
local refreshScheduled = false

local function computeHudScale(): number
	local cam = Workspace.CurrentCamera
	if not cam then
		return 1
	end
	local vp = cam.ViewportSize
	if vp.X <= 1 or vp.Y <= 1 then
		return 1
	end
	return math.clamp(math.min(vp.X / 1360, vp.Y / 760), 0.62, 1.15)
end

local function getShortDisplayName(tool: Tool): string
	local n = tool.Name
	if n == "Shadow .308 Sniper" then
		return "Shadow Sniper"
	elseif n == "Breacher Combat Shotgun" then
		return "Combat Shotgun"
	elseif n == "Syndicate 5.56 Carbine" then
		return "5.56 Carbine"
	elseif n == "Enforcer Heavy Pistol" then
		return "Heavy Pistol"
	elseif n == "Golden Emperor Pistol" then
		return "Emperor Pistol"
	elseif n == "Crimson Dragon AR" then
		return "Crimson AR"
	end
	return n
end

local function getPreviewKey(tool: Tool): string
	local wid = tool:GetAttribute("WeaponId")
	if typeof(wid) == "string" then
		return "W:" .. wid
	end
	return "T:" .. tool.Name
end

local function collectPlayerTools(): ({ Tool }, Tool?)
	local player = Players.LocalPlayer
	local char = player.Character
	local bp = player:FindFirstChild("Backpack")

	local present: { [Tool]: boolean } = {}
	local equipped: Tool? = nil

	if char then
		for _, ch in ipairs(char:GetChildren()) do
			if ch:IsA("Tool") then
				present[ch] = true
				equipped = ch
			end
		end
	end
	if bp then
		for _, ch in ipairs(bp:GetChildren()) do
			if ch:IsA("Tool") then
				present[ch] = true
			end
		end
	end

	-- Keep existing slot positions stable so tools never jump between 1..5 when equipped/unequipped
	for i = #orderedTools, 1, -1 do
		if not present[orderedTools[i]] then
			table.remove(orderedTools, i)
		end
	end

	-- Append any newly gained tools (putting Golden Spatula first if present)
	local newTools: { Tool } = {}
	for t in pairs(present) do
		if not table.find(orderedTools, t) then
			table.insert(newTools, t)
		end
	end
	table.sort(newTools, function(a: Tool, b: Tool): boolean
		local aSpat = string.find(string.lower(a.Name), "spatula") ~= nil
		local bSpat = string.find(string.lower(b.Name), "spatula") ~= nil
		if aSpat ~= bSpat then
			return aSpat
		end
		return a.Name < b.Name
	end)
	for _, t in ipairs(newTools) do
		if #orderedTools < MAX_SLOTS then
			if string.find(string.lower(t.Name), "spatula") then
				table.insert(orderedTools, 1, t)
			else
				table.insert(orderedTools, t)
			end
		end
	end

	return orderedTools, equipped
end

local function toggleEquipSlot(index: number): ()
	local player = Players.LocalPlayer
	local char = player.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not char or not hum or hum.Health <= 0 then
		return
	end

	local tool = orderedTools[index]
	if not tool or not tool.Parent then
		return
	end

	if tool.Parent == char then
		hum:UnequipTools()
	else
		hum:EquipTool(tool)
	end
end

local function applySlotVisualState(slot: SlotWidget, isSelected: boolean): ()
	local hasTool = slot.CurrentTool ~= nil
	slot.SelectedBar.Visible = isSelected
	if isSelected then
		slot.Button.BackgroundColor3 = BG_SELECTED
		slot.Stroke.Color = BORDER_SELECTED
		slot.Stroke.Thickness = 1.6
		slot.NumLabel.TextColor3 = ACCENT_GOLD
		slot.NameLabel.TextColor3 = Color3.fromRGB(246, 244, 238)
	elseif slot.IsHovered and hasTool then
		slot.Button.BackgroundColor3 = BG_HOVER
		slot.Stroke.Color = BORDER_HOVER
		slot.Stroke.Thickness = 1.3
		slot.NumLabel.TextColor3 = Color3.fromRGB(218, 212, 196)
		slot.NameLabel.TextColor3 = Color3.fromRGB(232, 230, 224)
	else
		slot.Button.BackgroundColor3 = BG_DEFAULT
		slot.Stroke.Color = BORDER_DEFAULT
		slot.Stroke.Thickness = 1.1
		slot.NumLabel.TextColor3 = if hasTool then Color3.fromRGB(168, 174, 186) else Color3.fromRGB(86, 92, 104)
		slot.NameLabel.TextColor3 = if hasTool then Color3.fromRGB(218, 216, 210) else Color3.fromRGB(78, 84, 96)
	end
end

local function createSlotWidget(parent: Instance, index: number): SlotWidget
	local btn = Instance.new("TextButton")
	btn.Name = "HotbarSlot_" .. tostring(index)
	btn.LayoutOrder = index
	btn.Size = UDim2.fromOffset(78, 86)
	btn.BackgroundColor3 = BG_DEFAULT
	btn.BackgroundTransparency = 0.04
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = BORDER_DEFAULT
	stroke.Thickness = 1.1
	stroke.Parent = btn

	-- Subtle brushed-gold top highlight bar shown ONLY on the selected slot
	local selBar = Instance.new("Frame")
	selBar.Name = "SelectedIndicator"
	selBar.Position = UDim2.new(0, 8, 0, 0)
	selBar.Size = UDim2.new(1, -16, 0, 2)
	selBar.BackgroundColor3 = ACCENT_GOLD
	selBar.BorderSizePixel = 0
	selBar.Visible = false
	selBar.Parent = btn

	-- 1. Visible Slot Number at top-left (1, 2, 3, 4, 5)
	local numLbl = Instance.new("TextLabel")
	numLbl.Name = "SlotNumber"
	numLbl.Position = UDim2.new(0, 6, 0, 3)
	numLbl.Size = UDim2.new(0, 18, 0, 14)
	numLbl.BackgroundTransparency = 1
	numLbl.Font = Enum.Font.GothamBlack
	numLbl.Text = tostring(index)
	numLbl.TextSize = 11
	numLbl.TextXAlignment = Enum.TextXAlignment.Left
	numLbl.TextColor3 = Color3.fromRGB(168, 174, 186)
	numLbl.Parent = btn

	-- 2. Consistent Aspect-Ratio Thumbnail Container in the center
	local thumbHost = Instance.new("Frame")
	thumbHost.Name = "ThumbnailFrame"
	thumbHost.AnchorPoint = Vector2.new(0.5, 0)
	thumbHost.Position = UDim2.new(0.5, 0, 0, 19)
	thumbHost.Size = UDim2.new(1, -12, 0, 44)
	thumbHost.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
	thumbHost.BorderSizePixel = 0
	thumbHost.Parent = btn
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 5)
	tc.Parent = thumbHost
	local ts = Instance.new("UIStroke")
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ts.Color = Color3.fromRGB(48, 54, 66)
	ts.Thickness = 1
	ts.Parent = thumbHost

	-- 3. Readable Tool Name cleanly underneath thumbnail
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "ItemName"
	nameLbl.Position = UDim2.new(0, 4, 1, -20)
	nameLbl.Size = UDim2.new(1, -8, 0, 17)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.Text = "—"
	nameLbl.TextSize = 9
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.TextColor3 = Color3.fromRGB(78, 84, 96)
	nameLbl.Parent = btn

	local widget: SlotWidget = {
		Index = index,
		Button = btn,
		Stroke = stroke,
		SelectedBar = selBar,
		NumLabel = numLbl,
		NameLabel = nameLbl,
		ThumbHost = thumbHost,
		CurrentTool = nil,
		LastPreviewKey = nil,
		IsHovered = false,
	}

	btn.MouseEnter:Connect(function()
		widget.IsHovered = true
		local char = Players.LocalPlayer.Character
		local isSel = widget.CurrentTool ~= nil and char ~= nil and widget.CurrentTool.Parent == char
		applySlotVisualState(widget, isSel)
	end)

	btn.MouseLeave:Connect(function()
		widget.IsHovered = false
		local char = Players.LocalPlayer.Character
		local isSel = widget.CurrentTool ~= nil and char ~= nil and widget.CurrentTool.Parent == char
		applySlotVisualState(widget, isSel)
	end)

	btn.MouseButton1Click:Connect(function()
		toggleEquipSlot(index)
	end)

	return widget
end

local function refreshHotbar(): ()
	refreshScheduled = false
	if not barFrame then
		return
	end

	local tools, equipped = collectPlayerTools()
	local visibleCount = math.clamp(math.max(MIN_SLOTS, #tools), MIN_SLOTS, MAX_SLOTS)
	local slotW = if visibleCount <= 5 then 78 elseif visibleCount <= 7 then 72 else 64

	while #slots < visibleCount do
		table.insert(slots, createSlotWidget(barFrame, #slots + 1))
	end

	for i, slot in ipairs(slots) do
		local isVisible = (i <= visibleCount)
		slot.Button.Visible = isVisible
		if isVisible then
			slot.Button.Size = UDim2.fromOffset(slotW, 86)
			local tool = tools[i]
			slot.CurrentTool = tool
			local isSelected = (tool ~= nil and tool == equipped)

			if tool then
				slot.NameLabel.Text = getShortDisplayName(tool)
				local pKey = getPreviewKey(tool)
				if slot.LastPreviewKey ~= pKey then
					slot.LastPreviewKey = pKey
					for _, ch in ipairs(slot.ThumbHost:GetChildren()) do
						if ch:IsA("ViewportFrame") then
							ch:Destroy()
						end
					end
					ModelPreviewHelper.CreateToolPreview(slot.ThumbHost, tool, UDim2.fromScale(1, 1), UDim2.new())
				end
			else
				slot.NameLabel.Text = "—"
				if slot.LastPreviewKey ~= nil then
					slot.LastPreviewKey = nil
					for _, ch in ipairs(slot.ThumbHost:GetChildren()) do
						if ch:IsA("ViewportFrame") then
							ch:Destroy()
						end
					end
				end
			end

			applySlotVisualState(slot, isSelected)
		end
	end

	local totalW = visibleCount * slotW + math.max(0, visibleCount - 1) * SLOT_PAD
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		pg:SetAttribute("FoodEmpireHotbarHalfW", totalW * 0.5)
	end
end

local function scheduleRefresh(): ()
	if refreshScheduled then
		return
	end
	refreshScheduled = true
	task.defer(refreshHotbar)
end

local function bindInventoryListeners(): ()
	for _, c in ipairs(activeConns) do
		c:Disconnect()
	end
	table.clear(activeConns)

	local player = Players.LocalPlayer
	local function hookContainer(inst: Instance?)
		if not inst then return end
		table.insert(activeConns, inst.ChildAdded:Connect(function(ch)
			if ch:IsA("Tool") then scheduleRefresh() end
		end))
		table.insert(activeConns, inst.ChildRemoved:Connect(function(ch)
			if ch:IsA("Tool") then scheduleRefresh() end
		end))
	end

	hookContainer(player:FindFirstChild("Backpack"))
	hookContainer(player.Character)

	table.insert(activeConns, player.ChildAdded:Connect(function(ch)
		if ch.Name == "Backpack" then
			hookContainer(ch)
			scheduleRefresh()
		end
	end))

	table.insert(activeConns, player.CharacterAdded:Connect(function(newChar)
		hookContainer(newChar)
		task.delay(0.25, scheduleRefresh)
	end))
end

function HotbarController.Init(): ()
	-- Hide Roblox's bare text-only default Backpack bar cleanly so our numbered 3D-thumbnail bar replaces it
	task.spawn(function()
		for _ = 1, 8 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			if ok then break end
			task.wait(0.4)
		end
	end)

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("FoodEmpireHotbar")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "FoodEmpireHotbar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	hotbarGui = gui

	-- Match FoodEmpireHUD's exact viewport-reactive UIScale so the Hotbar stays pixel-locked with flanking panels!
	local uis = Instance.new("UIScale")
	uis.Name = "ResponsiveHotbarScale"
	uis.Scale = computeHudScale()
	uis.Parent = gui
	hotbarScale = uis
	if scaleConn then
		scaleConn:Disconnect()
	end
	local function bindResize(): ()
		local cam = Workspace.CurrentCamera
		if cam then
			local function sync()
				if hotbarScale then
					hotbarScale.Scale = computeHudScale()
				end
			end
			sync()
			scaleConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(sync)
		end
	end
	bindResize()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if scaleConn then
			scaleConn:Disconnect()
		end
		bindResize()
	end)

	local frame = Instance.new("Frame")
	frame.Name = "NumberedHotbar"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -30)
	frame.Size = UDim2.fromOffset(720, 88)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	barFrame = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame

	table.clear(slots)
	for i = 1, MIN_SLOTS do
		table.insert(slots, createSlotWidget(frame, i))
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
		if gp then
			return
		end
		for idx, kc in ipairs(KEY_CODES) do
			if input.KeyCode == kc then
				toggleEquipSlot(idx)
				return
			end
		end
	end)

	bindInventoryListeners()
	scheduleRefresh()
end

return HotbarController
