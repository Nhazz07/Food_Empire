--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local TurfConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("TurfConfig")
)
local WaypointController = require("./WaypointController")
local AudioController = require("./AudioController")

local MinimapController = {}

local MAP_HALF_WORLD = 1050 -- Expanded 2x Mega-Island spans [-1020, +1020]
local MAP_PIXEL_SIZE = 178

local playerArrow: TextLabel? = nil
local gpsPinFrame: Frame? = nil
local gpsStatusLabel: TextLabel? = nil
local clearPinBtn: TextButton? = nil
local sectorMarkers: { [string]: TextButton } = {}
local turfMarkers: { [string]: TextButton } = {}
local turfStrokes: { [string]: UIStroke } = {}
local heartbeatConn: RBXScriptConnection? = nil

local function makeCorner(parent: Instance, r: number): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function worldToMinimap(x: number, z: number): UDim2
	local u = math.clamp((x + MAP_HALF_WORLD) / (MAP_HALF_WORLD * 2), 0.04, 0.96)
	local v = math.clamp((z + MAP_HALF_WORLD) / (MAP_HALF_WORLD * 2), 0.04, 0.96)
	return UDim2.fromScale(u, v)
end

local function setMapDestination(x: number, z: number, label: string): ()
	AudioController.PlayClick()
	WaypointController.SetCustomWaypoint(Vector3.new(x, 4, z), label)
end

local function addClickableMarker(
	parent: Instance,
	x: number,
	z: number,
	sizePx: number,
	color: Color3,
	shortLabel: string,
	fullName: string
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = "Marker_" .. shortLabel
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = worldToMinimap(x, z)
	btn.Size = UDim2.fromOffset(sizePx, sizePx)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBlack
	btn.Text = shortLabel
	btn.TextSize = 10
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.ZIndex = 5
	btn.Parent = parent
	makeCorner(btn, 5)

	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	st.Color = Color3.fromRGB(14, 18, 28)
	st.Thickness = 1.4
	st.Parent = btn

	btn.MouseButton1Click:Connect(function()
		setMapDestination(x, z, fullName)
	end)

	return btn
end

function MinimapController.Init(parentGui: ScreenGui): ()
	local frame = Instance.new("Frame")
	frame.Name = "IslandMinimap"
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -14, 1, -14)
	frame.Size = UDim2.fromOffset(MAP_PIXEL_SIZE + 14, MAP_PIXEL_SIZE + 54)
	frame.BackgroundColor3 = Color3.fromRGB(20, 32, 52)
	frame.BackgroundTransparency = 0.1
	frame.Parent = parentGui
	makeCorner(frame, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(248, 196, 56)
	stroke.Thickness = 1.8
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = "🗺️ CLICK MAP FOR ARROW (N^)"
	title.TextSize = 10
	title.TextColor3 = Color3.fromRGB(255, 224, 96)
	title.Parent = frame

	-- Interactive Click-Anywhere Ocean + Island canvas
	local ocean = Instance.new("TextButton")
	ocean.Name = "MapCanvas"
	ocean.Position = UDim2.new(0, 7, 0, 24)
	ocean.Size = UDim2.fromOffset(MAP_PIXEL_SIZE, MAP_PIXEL_SIZE)
	ocean.BackgroundColor3 = Color3.fromRGB(28, 152, 196)
	ocean.Text = ""
	ocean.AutoButtonColor = false
	ocean.ClipsDescendants = true
	ocean.Parent = frame
	makeCorner(ocean, 10)

	local island = Instance.new("Frame")
	island.AnchorPoint = Vector2.new(0.5, 0.5)
	island.Position = UDim2.fromScale(0.5, 0.5)
	island.Size = UDim2.fromScale(0.88, 0.88)
	island.BackgroundColor3 = Color3.fromRGB(82, 174, 76)
	island.BorderSizePixel = 0
	island.ZIndex = 1
	island.Parent = ocean
	makeCorner(island, 14)

	-- Click ANY spot on the map to drop a Custom GPS Pin & Guide Arrow!
	ocean.MouseButton1Click:Connect(function()
		local mouse = Players.LocalPlayer:GetMouse()
		local absPos = ocean.AbsolutePosition
		local absSize = ocean.AbsoluteSize
		if absSize.X <= 0 or absSize.Y <= 0 then return end
		local u = math.clamp((mouse.X - absPos.X) / absSize.X, 0.04, 0.96)
		local v = math.clamp((mouse.Y - absPos.Y) / absSize.Y, 0.04, 0.96)
		local worldX = (u * 2 - 1) * MAP_HALF_WORLD
		local worldZ = (v * 2 - 1) * MAP_HALF_WORLD
		setMapDestination(worldX, worldZ, "Map Pin")
	end)

	-- Central District Hub & Underground Black Market (auto-tracks BlackMarketOutpost position!)
	addClickableMarker(ocean, 0, 0, 26, Color3.fromRGB(224, 206, 168), "HUB", "Central Market")
	local bmX, bmZ = -295, 130
	local mapFolder = workspace:FindFirstChild("FoodEmpireMap")
	local bmOutpost = if mapFolder then mapFolder:FindFirstChild("BlackMarketOutpost") else nil
	if bmOutpost and bmOutpost:IsA("Model") then
		local bmPos = bmOutpost:GetPivot().Position
		bmX, bmZ = bmPos.X, bmPos.Z
	end
	addClickableMarker(ocean, bmX, bmZ, 24, Color3.fromRGB(196, 32, 62), "BM", "Black Market")

	-- 4 Clickable Player Restaurant Plazas
	addClickableMarker(ocean, 0, -820, 24, SectorConfig.FactionColors.North, "N", "North Restaurant Base")
	addClickableMarker(ocean, 0,  820, 24, SectorConfig.FactionColors.South, "S", "South Restaurant Base")
	addClickableMarker(ocean,  820, 0, 24, SectorConfig.FactionColors.East, "E", "East Restaurant Base")
	addClickableMarker(ocean, -820, 0, 24, SectorConfig.FactionColors.West, "W", "West Restaurant Base")

	-- 4 Clickable Corner Territories
	sectorMarkers.VegetableFarm = addClickableMarker(ocean, -725, -725, 24, SectorConfig.FactionColors.Neutral, "VEG", "Vegetable Farm")
	sectorMarkers.Ranch = addClickableMarker(ocean,  725, -725, 26, SectorConfig.FactionColors.Neutral, "MEAT", "Meat Ranch")
	sectorMarkers.FruitOrchard = addClickableMarker(ocean, -725,  725, 24, SectorConfig.FactionColors.Neutral, "FRT", "Fruit Orchard")
	sectorMarkers.FishingPort = addClickableMarker(ocean,  755,  795, 24, SectorConfig.FactionColors.Neutral, "FSH", "Fishing Port")

	-- 16 Clickable Mid-Town Urban Territory Block Tiles (live base-color synced!)
	table.clear(turfMarkers)
	table.clear(turfStrokes)
	for _, blockId in ipairs(TurfConfig.BlockOrder) do
		local spec = TurfConfig.Blocks[blockId]
		if spec then
			local initCol = TurfConfig.ResolveFactionColor(spec.InitialOwner)
			local tile = Instance.new("TextButton")
			tile.Name = "TurfTile_" .. blockId
			tile.AnchorPoint = Vector2.new(0.5, 0.5)
			tile.Position = worldToMinimap(spec.PlazaPos.X, spec.PlazaPos.Z)
			tile.Size = UDim2.fromOffset(if spec.IsHQ then 11 else 9, if spec.IsHQ then 11 else 9)
			tile.BackgroundColor3 = initCol
			tile.BorderSizePixel = 0
			tile.Font = Enum.Font.GothamBlack
			tile.Text = if spec.IsHQ then "★" else ""
			tile.TextSize = 8
			tile.TextColor3 = Color3.new(1, 1, 1)
			tile.ZIndex = 4
			tile.Parent = ocean
			makeCorner(tile, 3)

			local st = Instance.new("UIStroke")
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Color = Color3.fromRGB(16, 20, 30)
			st.Thickness = 1.1
			st.Parent = tile

			tile.MouseButton1Click:Connect(function()
				setMapDestination(spec.PlazaPos.X, spec.PlazaPos.Z, spec.DisplayName)
			end)

			turfMarkers[blockId] = tile
			turfStrokes[blockId] = st
		end
	end

	-- Custom GPS Pin Marker on Minimap
	local pin = Instance.new("Frame")
	pin.Name = "GPSPin"
	pin.AnchorPoint = Vector2.new(0.5, 0.5)
	pin.Size = UDim2.fromOffset(14, 14)
	pin.BackgroundColor3 = Color3.fromRGB(48, 232, 255)
	pin.Visible = false
	pin.ZIndex = 9
	pin.Parent = ocean
	makeCorner(pin, 7)
	local pinStroke = Instance.new("UIStroke")
	pinStroke.Color = Color3.new(1, 1, 1)
	pinStroke.Thickness = 2
	pinStroke.Parent = pin
	gpsPinFrame = pin

	-- Rotating Directional Player Arrow (▲) showing your live heading!
	local pArrow = Instance.new("TextLabel")
	pArrow.Name = "PlayerArrow"
	pArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	pArrow.Size = UDim2.fromOffset(18, 18)
	pArrow.Position = UDim2.fromScale(0.5, 0.5)
	pArrow.BackgroundTransparency = 1
	pArrow.Font = Enum.Font.GothamBlack
	pArrow.Text = "▲"
	pArrow.TextSize = 15
	pArrow.TextColor3 = Color3.fromRGB(255, 255, 255)
	pArrow.ZIndex = 12
	pArrow.Parent = ocean
	local pStroke = Instance.new("UIStroke")
	pStroke.Color = Color3.fromRGB(16, 20, 30)
	pStroke.Thickness = 2
	pStroke.Parent = pArrow
	playerArrow = pArrow

	-- Bottom GPS Status & Clear Button Strip
	local statusBar = Instance.new("Frame")
	statusBar.Position = UDim2.new(0, 7, 1, -26)
	statusBar.Size = UDim2.new(1, -14, 0, 21)
	statusBar.BackgroundColor3 = Color3.fromRGB(14, 22, 36)
	statusBar.Parent = frame
	makeCorner(statusBar, 6)

	local sLbl = Instance.new("TextLabel")
	sLbl.Position = UDim2.new(0, 6, 0, 0)
	sLbl.Size = UDim2.new(1, -28, 1, 0)
	sLbl.BackgroundTransparency = 1
	sLbl.Font = Enum.Font.GothamBold
	sLbl.Text = "Tap any place for GPS arrow!"
	sLbl.TextSize = 10
	sLbl.TextXAlignment = Enum.TextXAlignment.Left
	sLbl.TextColor3 = Color3.fromRGB(186, 226, 255)
	sLbl.TextTruncate = Enum.TextTruncate.AtEnd
	sLbl.Parent = statusBar
	gpsStatusLabel = sLbl

	local clr = Instance.new("TextButton")
	clr.Position = UDim2.new(1, -22, 0, 1)
	clr.Size = UDim2.fromOffset(20, 19)
	clr.BackgroundColor3 = Color3.fromRGB(204, 52, 64)
	clr.Font = Enum.Font.GothamBlack
	clr.Text = "✕"
	clr.TextSize = 10
	clr.TextColor3 = Color3.new(1, 1, 1)
	clr.Visible = false
	clr.Parent = statusBar
	makeCorner(clr, 5)
	clr.MouseButton1Click:Connect(function()
		AudioController.PlayClick()
		WaypointController.ClearCustomWaypoint()
	end)
	clearPinBtn = clr

	WaypointController.OnCustomWaypointChanged(function(pos: Vector3?, label: string?)
		if pos and gpsPinFrame and gpsStatusLabel and clearPinBtn then
			gpsPinFrame.Position = worldToMinimap(pos.X, pos.Z)
			gpsPinFrame.Visible = true
			gpsStatusLabel.Text = "📍 Arrow -> " .. (label or "Pin")
			gpsStatusLabel.TextColor3 = Color3.fromRGB(112, 246, 255)
			clearPinBtn.Visible = true
		elseif gpsPinFrame and gpsStatusLabel and clearPinBtn then
			gpsPinFrame.Visible = false
			gpsStatusLabel.Text = "Tap any place for GPS arrow!"
			gpsStatusLabel.TextColor3 = Color3.fromRGB(186, 226, 255)
			clearPinBtn.Visible = false
		end
	end)

	if heartbeatConn then
		heartbeatConn:Disconnect()
	end
	heartbeatConn = RunService.Heartbeat:Connect(function()
		local char = Players.LocalPlayer.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and playerArrow then
			playerArrow.Position = worldToMinimap(root.Position.X, root.Position.Z)
			local look = root.CFrame.LookVector
			-- North is -Z (0 deg), East is +X (+90 deg)
			local yawDeg = math.deg(math.atan2(look.X, -look.Z))
			playerArrow.Rotation = yawDeg
		end
	end)
end

function MinimapController.Update(state: { [string]: any }): ()
	local sectors = state.Sectors
	if not sectors then
		return
	end
	local slot = state.BaseSlot
	local localOwnerId = "Player_" .. tostring(Players.LocalPlayer.UserId)

	for sectorId, marker in pairs(sectorMarkers) do
		local s = sectors[sectorId]
		if s then
			if s.Status == "Contested" then
				marker.BackgroundColor3 = SectorConfig.FactionColors.Contested
			elseif s.Owner == "Neutral" then
				marker.BackgroundColor3 = SectorConfig.FactionColors.Neutral
			elseif s.Owner == "Rival" then
				marker.BackgroundColor3 = SectorConfig.FactionColors.Rival
			elseif s.Owner == localOwnerId and typeof(slot) == "string" and SectorConfig.FactionColors[slot] then
				marker.BackgroundColor3 = SectorConfig.FactionColors[slot]
			else
				marker.BackgroundColor3 = SectorConfig.FactionColors.Player
			end
		end
	end

	-- Sync all 16 Mid-Town Urban Territory Blocks to controlling faction Base Color!
	local turf = state.Turf
	if typeof(turf) == "table" and typeof(turf.Blocks) == "table" then
		for blockId, tile in pairs(turfMarkers) do
			local b = turf.Blocks[blockId]
			if typeof(b) == "table" then
				local st = turfStrokes[blockId]
				if b.Status == "Contested" then
					tile.BackgroundColor3 = TurfConfig.ContestedColor
					if st then
						st.Color = Color3.fromRGB(255, 255, 255)
						st.Thickness = 1.8
					end
				else
					local r = tonumber(b.ColorR) or 160
					local g = tonumber(b.ColorG) or 160
					local bl = tonumber(b.ColorB) or 160
					tile.BackgroundColor3 = Color3.fromRGB(r, g, bl)
					if st then
						if b.UnderAttack == true then
							st.Color = Color3.fromRGB(255, 86, 86)
							st.Thickness = 2.0
						else
							st.Color = Color3.fromRGB(16, 20, 30)
							st.Thickness = 1.1
						end
					end
				end
			end
		end
	end
end

return MinimapController
