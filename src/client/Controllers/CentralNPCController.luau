--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

type LimbRig = {
	Model: Model,
	RootPart: Part,
	Torso: Part,
	Head: Part,
	LeftArm: Part,
	RightArm: Part,
	LeftLeg: Part,
	RightLeg: Part,
	ChatLabel: TextLabel,
	ChatGui: BillboardGui,
	Waypoints: { Vector3 },
	TargetIndex: number,
	CurrentPos: Vector3,
	FacingYaw: number,
	WalkSpeed: number,
	WalkPhase: number,
	PauseTimer: number,
	ChatTimer: number,
}

local CentralNPCController = {}

local PLATFORM_Y = 1.35
local heartbeatConn: RBXScriptConnection? = nil
local npcFolder: Folder? = nil
local rigs: { LimbRig } = {}

local SKIN_TONES = {
	Color3.fromRGB(246, 212, 178),
	Color3.fromRGB(224, 178, 138),
	Color3.fromRGB(178, 128, 92),
	Color3.fromRGB(252, 224, 198),
}

local OUTFIT_COLORS = {
	Color3.fromRGB(238, 92, 78),
	Color3.fromRGB(58, 152, 224),
	Color3.fromRGB(246, 178, 48),
	Color3.fromRGB(84, 178, 86),
	Color3.fromRGB(164, 94, 224),
	Color3.fromRGB(244, 126, 168),
	Color3.fromRGB(246, 246, 250), -- Chef white
	Color3.fromRGB(48, 178, 174),
}

local PANTS_COLORS = {
	Color3.fromRGB(48, 56, 74),
	Color3.fromRGB(72, 64, 56),
	Color3.fromRGB(42, 74, 108),
	Color3.fromRGB(62, 68, 78),
}

local HAIR_COLORS = {
	Color3.fromRGB(58, 38, 26),
	Color3.fromRGB(184, 128, 56),
	Color3.fromRGB(34, 34, 40),
	Color3.fromRGB(142, 66, 38),
}

local CHAT_LINES = {
	"Mmm, smells delicious here!",
	"Heading to Sushi Palace!",
	"Fresh pastries at the Bakery!",
	"Who's the Food Emperor?",
	"Best burgers on the island!",
	"Love these cherry blossoms!",
	"Craving a Tropical Smoothie!",
	"Checking out Spice Market!",
	"That Crown Hall is huge!",
	"Time for a sizzling steak!",
	"Great food at Ramen Bar!",
	"Such a lively town square!",
}

local function makePart(parent: Instance, name: string, size: Vector3, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = col
	p.Material = mat
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildNPCModel(parent: Instance, index: number, rng: Random, startPos: Vector3, waypoints: { Vector3 }, startIdx: number): LimbRig
	local m = Instance.new("Model")
	m.Name = "PlazaCitizen_" .. tostring(index)

	local skin = SKIN_TONES[rng:NextInteger(1, #SKIN_TONES)]
	local shirt = OUTFIT_COLORS[(index - 1) % #OUTFIT_COLORS + 1]
	local pants = PANTS_COLORS[rng:NextInteger(1, #PANTS_COLORS)]
	local hair = HAIR_COLORS[rng:NextInteger(1, #HAIR_COLORS)]
	local isChef = (index % 4 == 0)

	-- Charming stylized 1.25x proportion NPC
	local root = makePart(m, "Root", Vector3.new(1, 1, 1), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, nil)
	root.Transparency = 1
	local torso = makePart(m, "Torso", Vector3.new(2.2, 2.5, 1.2), if isChef then Color3.fromRGB(248, 248, 252) else shirt, Enum.Material.SmoothPlastic, nil)
	local head = makePart(m, "Head", Vector3.new(1.75, 1.75, 1.75), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local leftArm = makePart(m, "LeftArm", Vector3.new(0.85, 2.2, 0.85), if isChef then Color3.fromRGB(248, 248, 252) else shirt, Enum.Material.SmoothPlastic, nil)
	local rightArm = makePart(m, "RightArm", Vector3.new(0.85, 2.2, 0.85), if isChef then Color3.fromRGB(248, 248, 252) else shirt, Enum.Material.SmoothPlastic, nil)
	local leftLeg = makePart(m, "LeftLeg", Vector3.new(0.95, 2.3, 0.95), pants, Enum.Material.SmoothPlastic, nil)
	local rightLeg = makePart(m, "RightLeg", Vector3.new(0.95, 2.3, 0.95), pants, Enum.Material.SmoothPlastic, nil)

	-- Hat or Hair accessory welded logically via head CFrame each step? Easier: WeldConstraint to Head (unanchored? No, keep Anchored = false? Wait: Anchored parts don't move with WeldConstraints! So attach accessories using a tiny table or just weld? Even cleaner: position hat directly or put a tiny Face + Hat inside a local update! Actually: make Hair/Hat a Decal + SpecialMesh or simple hat part updated from headCF — super cheap for 16 NPCs!)
	-- Even simpler & super crisp: cute eyes on Head via SurfaceGui/Decal? No, let's attach Hat directly as a child part positioned from headCF!
	local hat: Part? = nil
	if isChef then
		hat = makePart(m, "ChefHat", Vector3.new(1.5, 1.35, 1.5), Color3.fromRGB(252, 252, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	else
		hat = makePart(m, "HairCap", Vector3.new(1.85, 0.85, 1.85), hair, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	if hat then
		hat:SetAttribute("IsChefHat", isChef)
	end

	-- Friendly floating foodie chat bubble (shown briefly when pausing at shops!)
	local bb = Instance.new("BillboardGui")
	bb.Name = "CitizenChat"
	bb.Size = UDim2.fromOffset(185, 34)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 72
	bb.Enabled = false
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(255, 250, 236)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = ""
	lbl.TextColor3 = Color3.fromRGB(40, 36, 48)
	lbl.TextSize = 13
	lbl.TextWrapped = true
	lbl.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = lbl

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(230, 196, 128)
	stroke.Thickness = 2
	stroke.Parent = lbl

	m.PrimaryPart = root
	m.Parent = parent

	return {
		Model = m,
		RootPart = root,
		Torso = torso,
		Head = head,
		LeftArm = leftArm,
		RightArm = rightArm,
		LeftLeg = leftLeg,
		RightLeg = rightLeg,
		ChatLabel = lbl,
		ChatGui = bb,
		Waypoints = waypoints,
		TargetIndex = startIdx,
		CurrentPos = startPos,
		FacingYaw = 0,
		WalkSpeed = rng:NextNumber(8.2, 11.8),
		WalkPhase = rng:NextNumber(0, math.pi * 2),
		PauseTimer = rng:NextNumber(0, 1.5),
		ChatTimer = 0,
	}
end

local function updateRigPose(rig: LimbRig, isWalking: boolean)
	local bob = if isWalking then math.abs(math.sin(rig.WalkPhase)) * 0.22 else 0
	local swing = if isWalking then math.sin(rig.WalkPhase) * math.rad(34) else 0

	local baseCF = CFrame.new(rig.CurrentPos.X, PLATFORM_Y + bob, rig.CurrentPos.Z) * CFrame.Angles(0, rig.FacingYaw, 0)
	rig.RootPart.CFrame = baseCF * CFrame.new(0, 3.4, 0)
	rig.Torso.CFrame = baseCF * CFrame.new(0, 3.55, 0)

	local headCF = baseCF * CFrame.new(0, 5.65, 0)
	rig.Head.CFrame = headCF

	local hat = rig.Model:FindFirstChild("ChefHat") or rig.Model:FindFirstChild("HairCap")
	if hat and hat:IsA("BasePart") then
		if hat:GetAttribute("IsChefHat") then
			hat.CFrame = headCF * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90))
		else
			hat.CFrame = headCF * CFrame.new(0, 0.52, 0.12)
		end
	end

	-- Pivot arms from shoulder & legs from hip for crisp natural walking swing
	rig.LeftArm.CFrame = baseCF * CFrame.new(-1.55, 4.45, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -0.95, 0)
	rig.RightArm.CFrame = baseCF * CFrame.new(1.55, 4.45, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -0.95, 0)
	rig.LeftLeg.CFrame = baseCF * CFrame.new(-0.55, 2.3, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1.15, 0)
	rig.RightLeg.CFrame = baseCF * CFrame.new(0.55, 2.3, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1.15, 0)
end

local function makeCircleWaypoints(radius: number, count: number, reverse: boolean): { Vector3 }
	local pts: { Vector3 } = {}
	for i = 1, count do
		local idx = if reverse then (count - i + 1) else i
		local a = (idx / count) * math.pi * 2
		table.insert(pts, Vector3.new(math.cos(a) * radius, PLATFORM_Y, math.sin(a) * radius))
	end
	return pts
end

function CentralNPCController.Start(): ()
	if heartbeatConn then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "CentralDistrictCitizens"
	folder.Parent = Workspace
	npcFolder = folder

	local rng = Random.new(20261130)
	table.clear(rigs)

	-- Circuit 1: Expanded Grand Central Shop Promenade (fits 384x384 Central District!)
	local outerCW: { Vector3 } = {
		Vector3.new(-112, PLATFORM_Y, -96),
		Vector3.new(0, PLATFORM_Y, -96),
		Vector3.new(112, PLATFORM_Y, -96),
		Vector3.new(116, PLATFORM_Y, 0),
		Vector3.new(116, PLATFORM_Y, 112),
		Vector3.new(0, PLATFORM_Y, 116),
		Vector3.new(-116, PLATFORM_Y, 112),
		Vector3.new(-116, PLATFORM_Y, 0),
	}
	local outerCCW: { Vector3 } = {}
	for i = #outerCW, 1, -1 do
		table.insert(outerCCW, outerCW[i] + Vector3.new(5, 0, -5))
	end

	-- Circuit 2: Inner Turquoise Fountain & Shipment Bay Plaza Ring
	local fountainCW = makeCircleWaypoints(36, 12, false)
	local fountainCCW = makeCircleWaypoints(44, 12, true)

	-- Circuit 3: Grand Avenue Crosswalks inside Expanded Central Plaza
	local ewRoute: { Vector3 } = {
		Vector3.new(-126, PLATFORM_Y, 10),
		Vector3.new(-42, PLATFORM_Y, 10),
		Vector3.new(-42, PLATFORM_Y, -10),
		Vector3.new(-126, PLATFORM_Y, -10),
	}
	local ewRouteEast: { Vector3 } = {
		Vector3.new(126, PLATFORM_Y, -10),
		Vector3.new(42, PLATFORM_Y, -10),
		Vector3.new(42, PLATFORM_Y, 10),
		Vector3.new(126, PLATFORM_Y, 10),
	}
	local southRoute: { Vector3 } = {
		Vector3.new(-10, PLATFORM_Y, 126),
		Vector3.new(-10, PLATFORM_Y, 42),
		Vector3.new(10, PLATFORM_Y, 42),
		Vector3.new(10, PLATFORM_Y, 126),
	}

	-- Circuit 4: NEW Mid-Town Culinary Boulevard Sidewalks (passes the 16 new Mid-Town Shops!)
	local midNorth: { Vector3 } = {
		Vector3.new(-22, PLATFORM_Y, -245),
		Vector3.new(-22, PLATFORM_Y, -455),
		Vector3.new(22, PLATFORM_Y, -455),
		Vector3.new(22, PLATFORM_Y, -245),
	}
	local midSouth: { Vector3 } = {
		Vector3.new(-22, PLATFORM_Y, 245),
		Vector3.new(-22, PLATFORM_Y, 455),
		Vector3.new(22, PLATFORM_Y, 455),
		Vector3.new(22, PLATFORM_Y, 245),
	}
	local midEast: { Vector3 } = {
		Vector3.new(245, PLATFORM_Y, -22),
		Vector3.new(455, PLATFORM_Y, -22),
		Vector3.new(455, PLATFORM_Y, 22),
		Vector3.new(245, PLATFORM_Y, 22),
	}
	local midWest: { Vector3 } = {
		Vector3.new(-245, PLATFORM_Y, -22),
		Vector3.new(-455, PLATFORM_Y, -22),
		Vector3.new(-455, PLATFORM_Y, 22),
		Vector3.new(-245, PLATFORM_Y, 22),
	}

	-- 36 Living Strolling Citizens, Foodies & Street Chefs across the 2x Mega Metropolis!
	local routeDefs: { { Waypoints: { Vector3 }, StartIdx: number } } = {
		-- 12 Outer Central Promenade Strollers
		{ Waypoints = outerCW, StartIdx = 1 }, { Waypoints = outerCW, StartIdx = 2 },
		{ Waypoints = outerCW, StartIdx = 3 }, { Waypoints = outerCW, StartIdx = 5 },
		{ Waypoints = outerCW, StartIdx = 6 }, { Waypoints = outerCW, StartIdx = 7 },
		{ Waypoints = outerCCW, StartIdx = 1 }, { Waypoints = outerCCW, StartIdx = 2 },
		{ Waypoints = outerCCW, StartIdx = 4 }, { Waypoints = outerCCW, StartIdx = 5 },
		{ Waypoints = outerCCW, StartIdx = 6 }, { Waypoints = outerCCW, StartIdx = 8 },
		-- 6 Central Fountain & Shipment Bay Visitors
		{ Waypoints = fountainCW, StartIdx = 1 }, { Waypoints = fountainCW, StartIdx = 5 }, { Waypoints = fountainCW, StartIdx = 9 },
		{ Waypoints = fountainCCW, StartIdx = 2 }, { Waypoints = fountainCCW, StartIdx = 6 }, { Waypoints = fountainCCW, StartIdx = 10 },
		-- 6 Central Avenue Strollers
		{ Waypoints = ewRoute, StartIdx = 1 }, { Waypoints = ewRoute, StartIdx = 3 },
		{ Waypoints = ewRouteEast, StartIdx = 1 }, { Waypoints = ewRouteEast, StartIdx = 3 },
		{ Waypoints = southRoute, StartIdx = 1 }, { Waypoints = southRoute, StartIdx = 3 },
		-- 12 Mid-Town Culinary Boulevard Citizens (3 per cardinal district!)
		{ Waypoints = midNorth, StartIdx = 1 }, { Waypoints = midNorth, StartIdx = 2 }, { Waypoints = midNorth, StartIdx = 4 },
		{ Waypoints = midSouth, StartIdx = 1 }, { Waypoints = midSouth, StartIdx = 2 }, { Waypoints = midSouth, StartIdx = 4 },
		{ Waypoints = midEast, StartIdx = 1 }, { Waypoints = midEast, StartIdx = 2 }, { Waypoints = midEast, StartIdx = 4 },
		{ Waypoints = midWest, StartIdx = 1 }, { Waypoints = midWest, StartIdx = 2 }, { Waypoints = midWest, StartIdx = 4 },
	}

	for i, def in ipairs(routeDefs) do
		local wp = def.Waypoints
		local startPos = wp[def.StartIdx]
		local nextIdx = (def.StartIdx % #wp) + 1
		local rig = buildNPCModel(folder, i, rng, startPos, wp, nextIdx)
		updateRigPose(rig, false)
		table.insert(rigs, rig)
	end

	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		local clampedDt = math.min(dt, 0.05)
		for _, rig in ipairs(rigs) do
			if rig.ChatTimer > 0 then
				rig.ChatTimer -= clampedDt
				if rig.ChatTimer <= 0 then
					rig.ChatGui.Enabled = false
				end
			end

			if rig.PauseTimer > 0 then
				rig.PauseTimer -= clampedDt
				updateRigPose(rig, false)
				continue
			end

			local target = rig.Waypoints[rig.TargetIndex]
			local delta = Vector3.new(target.X - rig.CurrentPos.X, 0, target.Z - rig.CurrentPos.Z)
			local dist = delta.Magnitude

			if dist < 1.2 then
				rig.TargetIndex = (rig.TargetIndex % #rig.Waypoints) + 1
				-- Brief natural pause at shopfronts/corners ~35% of the time
				if rng:NextNumber(0, 1) < 0.35 then
					rig.PauseTimer = rng:NextNumber(1.8, 3.6)
					if rng:NextNumber(0, 1) < 0.45 then
						rig.ChatLabel.Text = CHAT_LINES[rng:NextInteger(1, #CHAT_LINES)]
						rig.ChatGui.Enabled = true
						rig.ChatTimer = 3.2
					end
				end
			else
				local step = math.min(dist, rig.WalkSpeed * clampedDt)
				local dir = delta / dist
				rig.CurrentPos += dir * step

				-- Smoothly turn toward movement direction
				local desiredYaw = math.atan2(-dir.X, -dir.Z)
				local diff = (desiredYaw - rig.FacingYaw + math.pi) % (math.pi * 2) - math.pi
				rig.FacingYaw += diff * math.min(1, clampedDt * 8)

				rig.WalkPhase += clampedDt * (rig.WalkSpeed * 0.92)
				updateRigPose(rig, true)
			end
		end
	end)
end

function CentralNPCController.Stop(): ()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	if npcFolder then
		npcFolder:Destroy()
		npcFolder = nil
	end
	table.clear(rigs)
end

return CentralNPCController
