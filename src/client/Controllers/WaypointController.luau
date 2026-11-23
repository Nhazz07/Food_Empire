--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local WaypointController = {}

local BASE_POSITIONS: { [string]: Vector3 } = {
	North = Vector3.new(0, 4, -820),
	South = Vector3.new(0, 4, 820),
	East = Vector3.new(820, 4, 0),
	West = Vector3.new(-820, 4, 0),
}

local isEnabled = true
local arrowModel: Model? = nil
local arrowLabel: TextLabel? = nil
local customBeacon: Model? = nil
local customTargetPos: Vector3? = nil
local customTargetLabel: string? = nil
local onCustomChanged: ((Vector3?, string?) -> ())? = nil
local latestState: { [string]: any }? = nil
local heartbeatConn: RBXScriptConnection? = nil

local function buildPointerArrow(): (Model, TextLabel)
	local m = Instance.new("Model")
	m.Name = "FoodEmpireGuideArrow"

	-- Bold sleek 3D directional arrow pointing along local -Z (LookVector) without blinding neon glare
	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.85, 0.3, 2.5)
	shaft.Color = Color3.fromRGB(244, 194, 42)
	shaft.Material = Enum.Material.SmoothPlastic
	shaft.Anchored = true
	shaft.CanCollide = false
	shaft.CanTouch = false
	shaft.CanQuery = false
	shaft.CastShadow = false
	shaft.Parent = m

	local head = Instance.new("WedgePart")
	head.Name = "Tip"
	head.Size = Vector3.new(0.32, 1.9, 1.9)
	head.CFrame = shaft.CFrame * CFrame.new(0, 0, -1.95) * CFrame.Angles(0, 0, math.rad(90))
	head.Color = Color3.fromRGB(255, 216, 78)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.CanTouch = false
	head.CanQuery = false
	head.CastShadow = false
	head.Parent = m

	local bb = Instance.new("BillboardGui")
	bb.Name = "GPSLabel"
	bb.Size = UDim2.fromOffset(220, 30)
	bb.StudsOffset = Vector3.new(0, 2.0, 0)
	bb.AlwaysOnTop = true
	bb.Parent = shaft

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 26, 42)
	lbl.BackgroundTransparency = 0.2
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = ""
	lbl.TextSize = 12
	lbl.TextColor3 = Color3.fromRGB(112, 242, 255)
	lbl.Visible = false
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = lbl

	m.PrimaryPart = shaft
	m.Parent = Workspace
	return m, lbl
end

local function syncCustomBeacon(): ()
	if customBeacon and customBeacon.Parent then
		customBeacon:Destroy()
		customBeacon = nil
	end
	if not customTargetPos then
		return
	end
	local b = Instance.new("Model")
	b.Name = "CustomGPSBeacon"

	local beam = Instance.new("Part")
	beam.Name = "SkyBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(130, 5.5, 5.5)
	beam.CFrame = CFrame.new(customTargetPos.X, 66, customTargetPos.Z) * CFrame.Angles(0, 0, math.rad(90))
	beam.Color = Color3.fromRGB(48, 224, 255)
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.45
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Parent = b

	local ring = Instance.new("Part")
	ring.Name = "GroundRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 18, 18)
	ring.CFrame = CFrame.new(customTargetPos.X, 1.5, customTargetPos.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(48, 224, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Parent = b

	b.Parent = Workspace
	customBeacon = b
end

function WaypointController.SetCustomWaypoint(worldPos: Vector3, label: string): ()
	isEnabled = true
	customTargetPos = Vector3.new(worldPos.X, 4, worldPos.Z)
	customTargetLabel = label
	syncCustomBeacon()
	if onCustomChanged then
		onCustomChanged(customTargetPos, customTargetLabel)
	end
end

function WaypointController.ClearCustomWaypoint(): ()
	customTargetPos = nil
	customTargetLabel = nil
	syncCustomBeacon()
	if onCustomChanged then
		onCustomChanged(nil, nil)
	end
end

function WaypointController.GetCustomWaypoint(): (Vector3?, string?)
	return customTargetPos, customTargetLabel
end

function WaypointController.OnCustomWaypointChanged(cb: (Vector3?, string?) -> ()): ()
	onCustomChanged = cb
end

local function setArrowColor(arrow: Model, primary: Color3, tip: Color3): ()
	local s = arrow:FindFirstChild("Shaft")
	local t = arrow:FindFirstChild("Tip")
	if s and s:IsA("BasePart") then s.Color = primary end
	if t and t:IsA("BasePart") then t.Color = tip end
end

local function resolveTargetPosition(playerPos: Vector3): (Vector3?, string?, boolean)
	-- Priority 0: Player's own Custom Map GPS Pin (Click anywhere on the Island Map!)
	if customTargetPos then
		return customTargetPos, customTargetLabel or "Custom Pin", true
	end

	local player = Players.LocalPlayer
	local state = latestState
	if not state then
		return nil, nil, false
	end

	-- Priority 1: Carrying a Manual Delivery Crate -> point directly to matching Warehouse in your Castle Base!
	local carrying = player:GetAttribute("CarryingCrate")
	local slot = state.BaseSlot
	if typeof(carrying) == "string" and typeof(slot) == "string" then
		for _, plot in ipairs(CollectionService:GetTagged("WarehousePlot")) do
			if plot:IsA("Model") and plot:GetAttribute("BaseSlot") == slot and plot:GetAttribute("Category") == carrying then
				return plot:GetPivot().Position, carrying .. " Warehouse", false
			end
		end
		if BASE_POSITIONS[slot] then
			return BASE_POSITIONS[slot], "Your Base", false
		end
	end

	-- Priority 1.5: Active Express Delivery Mission (Motorbike Rush!) -> point straight to drop-off beacon!
	local express = state.ExpressDelivery
	if typeof(express) == "table" and express.Status == "Active" and typeof(express.DropX) == "number" and typeof(express.DropZ) == "number" then
		return Vector3.new(express.DropX, 4, express.DropZ), "Express Drop-Off", false
	end

	-- Priority 2: Ready dishes to sell -> guide back to your Restaurant Plaza
	local kitchen = state.Kitchen
	if kitchen and (kitchen.ReadyTotal or 0) > 0 and typeof(slot) == "string" and BASE_POSITIONS[slot] then
		return BASE_POSITIONS[slot], "Restaurant Serve Counter", false
	end

	-- Priority 3: Guide straight to an Arrived or Incoming Shipment Bay in the Expanded Central District!
	local shipments = state.Shipments
	local whLevels = state.Warehouse and state.Warehouse.Levels
	if typeof(shipments) == "table" then
		local bestBay: Vector3? = nil
		local bestLabel: string? = nil
		local bestScore = -math.huge
		for _, sh in pairs(shipments) do
			if typeof(sh) == "table" and typeof(sh.BayX) == "number" and typeof(sh.BayZ) == "number" then
				local unlocked = (whLevels and (whLevels[sh.Category] or 0) >= 1) or (sh.Category == "Fish")
				local bayPos = Vector3.new(sh.BayX, 4, sh.BayZ)
				local dist = (bayPos - playerPos).Magnitude
				local score = (if sh.Phase == "Arrived" then 600 elseif sh.Phase == "EnRoute" then 350 else 50)
					+ (if unlocked then 200 else 0)
					- dist * 0.3
				if score > bestScore then
					bestScore = score
					bestBay = bayPos
					bestLabel = tostring(sh.Category) .. " Shipment"
				end
			end
		end
		if bestBay then
			return bestBay, bestLabel, false
		end
	end

	return Vector3.new(0, 4, 0), "Central Market", false
end

function WaypointController.Start(): ()
	if heartbeatConn then
		return
	end

	local createdArrow, createdLbl = buildPointerArrow()
	arrowModel = createdArrow
	arrowLabel = createdLbl
	local elapsed = 0

	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		local arrow = arrowModel
		if not arrow or not arrow.Parent then
			arrow, arrowLabel = buildPointerArrow()
			arrowModel = arrow
		end

		local char = Players.LocalPlayer.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if not isEnabled or not root or not root:IsA("BasePart") then
			arrow:PivotTo(CFrame.new(0, -500, 0))
			if arrowLabel then arrowLabel.Visible = false end
			return
		end

		local target, targetLabel, isCustom = resolveTargetPosition(root.Position)
		if not target then
			arrow:PivotTo(CFrame.new(0, -500, 0))
			if arrowLabel then arrowLabel.Visible = false end
			return
		end

		local flatTarget = Vector3.new(target.X, root.Position.Y, target.Z)
		local delta = flatTarget - root.Position
		local dist = delta.Magnitude

		-- Auto-clear Custom GPS Pin once player arrives within 22 studs!
		if isCustom and dist <= 22 then
			WaypointController.ClearCustomWaypoint()
			return
		end

		if dist < 16 then
			arrow:PivotTo(CFrame.new(0, -500, 0))
			if arrowLabel then arrowLabel.Visible = false end
			return
		end

		if isCustom then
			setArrowColor(arrow, Color3.fromRGB(48, 224, 255), Color3.fromRGB(168, 250, 255))
		else
			setArrowColor(arrow, Color3.fromRGB(255, 214, 58), Color3.fromRGB(255, 236, 128))
		end

		if arrowLabel then
			arrowLabel.Visible = true
			arrowLabel.Text = string.format("%s %s • %dm", if isCustom then "📍" else "➤", targetLabel or "Target", math.floor(dist))
			arrowLabel.TextColor3 = if isCustom then Color3.fromRGB(112, 246, 255) else Color3.fromRGB(255, 228, 118)
		end

		local dir = delta.Unit
		local bob = math.sin(elapsed * 4.5) * 0.28
		local arrowPos = root.Position + dir * 5.6 + Vector3.new(0, 0.35 + bob, 0)
		arrow:PivotTo(CFrame.lookAt(arrowPos, arrowPos + dir))
	end)
end

function WaypointController.Update(state: { [string]: any }): ()
	latestState = state
end

function WaypointController.Toggle(): boolean
	isEnabled = not isEnabled
	return isEnabled
end

return WaypointController
