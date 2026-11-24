--!strict

-- CentralNPCController: 36 authentic Roblox R15 MeshPart strolling citizens & street chefs
-- across Central Park, Central Plaza & Mid-Town Boulevards.
-- Reacts realistically to nearby gunfire & fights: startled scream, hands raised / head-shielding,
-- nervous shoulder glances, frantic sprint directly away from danger, then shaky nervous cooldown!

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local AudioController = require("./AudioController")

type JointCache = {
	Waist: Motor6D?,
	Neck: Motor6D?,
	LeftShoulder: Motor6D?,
	RightShoulder: Motor6D?,
	LeftElbow: Motor6D?,
	RightElbow: Motor6D?,
	LeftHip: Motor6D?,
	RightHip: Motor6D?,
	LeftKnee: Motor6D?,
	RightKnee: Motor6D?,
}

type CitizenRig = {
	Model: Model,
	RootPart: BasePart,
	Head: BasePart,
	Joints: JointCache,
	FootOffset: number,
	ChatLabel: TextLabel,
	ChatStroke: UIStroke,
	ChatGui: BillboardGui,
	Waypoints: { Vector3 },
	TargetIndex: number,
	CurrentPos: Vector3,
	FacingYaw: number,
	WalkSpeed: number,
	WalkPhase: number,
	PauseTimer: number,
	ChatTimer: number,
	PanicUntil: number,
	NervousUntil: number,
	ThreatPos: Vector3,
	PanicStyle: number, -- 1 = arms thrown up waving, 2 = shielding head crouched sprint
	WeaveSeed: number,
	WasPanicking: boolean,
}

local CentralNPCController = {}

local PLATFORM_Y = 1.35
local PANIC_TRIGGER_RADIUS = 115
local PANIC_SAFE_DIST = 108
local heartbeatConn: RBXScriptConnection? = nil
local npcFolder: Folder? = nil
local rigs: { CitizenRig } = {}
local threatWired = false
local globalRng = Random.new(20261130)

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

local PANIC_LINES = {
	"GUNSHOTS! RUN!",
	"GET OUT OF HERE!",
	"TAKE COVER! SHOOTING!",
	"MAFIA FIGHT! RUN AWAY!",
	"HELP! SOMEONE'S SHOOTING!",
	"OH NO! GET DOWN!",
	"STAY BACK! DON'T LOOK BACK!",
	"CLEAR THE PLAZA! RUN!",
}

local NERVOUS_LINES = {
	"Is the shooting over...?",
	"My heart is pounding...",
	"That was way too close...",
	"Better stay away from there...",
	"Are they still fighting...?",
}

local C_CALM_STROKE = Color3.fromRGB(64, 68, 78)
local C_CALM_TEXT = Color3.fromRGB(228, 224, 216)
local C_PANIC_STROKE = Color3.fromRGB(168, 36, 44)
local C_PANIC_TEXT = Color3.fromRGB(248, 178, 174)
local C_NERVOUS_STROKE = Color3.fromRGB(172, 142, 76)
local C_NERVOUS_TEXT = Color3.fromRGB(236, 218, 174)

local CHEF_APRONS = {
	Color3.fromRGB(128, 34, 40),
	Color3.fromRGB(48, 72, 58),
	Color3.fromRGB(52, 62, 82),
	Color3.fromRGB(98, 74, 46),
}

local function cacheR15Joints(model: Model): JointCache
	local function getMotor(name: string): Motor6D?
		local m = model:FindFirstChild(name, true)
		return if m and m:IsA("Motor6D") then m else nil
	end
	return {
		Waist = getMotor("Waist"),
		Neck = getMotor("Neck"),
		LeftShoulder = getMotor("LeftShoulder"),
		RightShoulder = getMotor("RightShoulder"),
		LeftElbow = getMotor("LeftElbow"),
		RightElbow = getMotor("RightElbow"),
		LeftHip = getMotor("LeftHip"),
		RightHip = getMotor("RightHip"),
		LeftKnee = getMotor("LeftKnee"),
		RightKnee = getMotor("RightKnee"),
	}
end

local function buildNPCModel(parent: Instance, index: number, rng: Random, startPos: Vector3, waypoints: { Vector3 }, startIdx: number): CitizenRig
	local isChef = (index % 4 == 0)
	local spawnCF = CFrame.new(startPos.X, PLATFORM_Y + 3.0, startPos.Z)
	local scale = rng:NextNumber(0.95, 1.05)

	local rigHandle: MafiaVisualBuilder.RigHandle
	if isChef then
		local apronCol = CHEF_APRONS[(index % #CHEF_APRONS) + 1]
		rigHandle = MafiaVisualBuilder.BuildChefRig("PlazaCitizen_" .. tostring(index), apronCol, scale, spawnCF, false)
	else
		rigHandle = MafiaVisualBuilder.BuildCustomerRig("PlazaCitizen_" .. tostring(index), index, scale, spawnCF)
	end

	local m = rigHandle.Model
	local root = rigHandle.Root
	local head = rigHandle.Head

	-- Measure exact vertical offset from HumanoidRootPart center down to the sole of LeftFoot
	local footOffset = math.clamp(root.Position.Y - (rigHandle.LeftFoot.Position.Y - rigHandle.LeftFoot.Size.Y * 0.5), 2.5, 3.6)

	-- Anchor ONLY HumanoidRootPart; keep all R15 limbs & welded accessories massless/non-collidable
	root.Anchored = true
	for _, desc in ipairs(m:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			desc.CastShadow = false
			if desc ~= root then
				desc.Anchored = false
				desc.Massless = true
			end
		end
	end

	m:SetAttribute("IsPanicking", false)
	m:SetAttribute("PanicState", "Calm")

	-- Dark-noir refined citizen speech bubble
	local bb = Instance.new("BillboardGui")
	bb.Name = "CitizenChat"
	bb.Size = UDim2.fromOffset(198, 32)
	bb.StudsOffset = Vector3.new(0, 2.35, 0)
	bb.MaxDistance = 82
	bb.Enabled = false
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = ""
	lbl.TextColor3 = C_CALM_TEXT
	lbl.TextSize = 11
	lbl.TextWrapped = true
	lbl.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = lbl

	local stroke = Instance.new("UIStroke")
	stroke.Color = C_CALM_STROKE
	stroke.Thickness = 1.3
	stroke.Parent = lbl

	m.Parent = parent

	return {
		Model = m,
		RootPart = root,
		Head = head,
		Joints = cacheR15Joints(m),
		FootOffset = footOffset,
		ChatLabel = lbl,
		ChatStroke = stroke,
		ChatGui = bb,
		Waypoints = waypoints,
		TargetIndex = startIdx,
		CurrentPos = startPos,
		FacingYaw = 0,
		WalkSpeed = rng:NextNumber(8.0, 11.2),
		WalkPhase = rng:NextNumber(0, math.pi * 2),
		PauseTimer = rng:NextNumber(0, 1.5),
		ChatTimer = 0,
		PanicUntil = 0,
		NervousUntil = 0,
		ThreatPos = Vector3.zero,
		PanicStyle = rng:NextInteger(1, 2),
		WeaveSeed = rng:NextNumber(0, math.pi * 2),
		WasPanicking = false,
	}
end

local function updateRigPose(rig: CitizenRig, mode: "Walk" | "Idle" | "Panic" | "Nervous", now: number): ()
	local j = rig.Joints
	local phase = rig.WalkPhase
	local bob = 0

	if mode == "Panic" then
		bob = math.abs(math.sin(phase)) * 0.28
		local legSwing = math.sin(phase) * math.rad(56)
		local kneeL = -math.max(0, -math.cos(phase)) * math.rad(68)
		local kneeR = -math.max(0, math.cos(phase)) * math.rad(68)

		if j.LeftHip then j.LeftHip.Transform = CFrame.Angles(-legSwing, 0, 0) end
		if j.RightHip then j.RightHip.Transform = CFrame.Angles(legSwing, 0, 0) end
		if j.LeftKnee then j.LeftKnee.Transform = CFrame.Angles(kneeL, 0, 0) end
		if j.RightKnee then j.RightKnee.Transform = CFrame.Angles(kneeR, 0, 0) end

		local wave = math.sin(now * 14 + rig.WeaveSeed)
		if rig.PanicStyle == 1 then
			-- Hands thrown high overhead waving frantically in terror!
			if j.LeftShoulder then
				j.LeftShoulder.Transform = CFrame.Angles(math.rad(152 + wave * 16), 0, math.rad(-24 + wave * 10))
			end
			if j.RightShoulder then
				j.RightShoulder.Transform = CFrame.Angles(math.rad(152 - wave * 16), 0, math.rad(24 + wave * 10))
			end
			if j.LeftElbow then j.LeftElbow.Transform = CFrame.Angles(math.rad(36 + math.abs(wave) * 22), 0, 0) end
			if j.RightElbow then j.RightElbow.Transform = CFrame.Angles(math.rad(36 + math.abs(wave) * 22), 0, 0) end
		else
			-- Arms curled up shielding head while leaning forward sprinting!
			if j.LeftShoulder then
				j.LeftShoulder.Transform = CFrame.Angles(math.rad(128 + wave * 8), 0, math.rad(-14))
			end
			if j.RightShoulder then
				j.RightShoulder.Transform = CFrame.Angles(math.rad(128 - wave * 8), 0, math.rad(14))
			end
			if j.LeftElbow then j.LeftElbow.Transform = CFrame.Angles(math.rad(82), 0, math.rad(18)) end
			if j.RightElbow then j.RightElbow.Transform = CFrame.Angles(math.rad(82), 0, math.rad(-18)) end
		end

		-- Leaning forward into sprint + anxious glances left/right & back over shoulder!
		local shoulderGlance = math.sin(now * 6.5 + rig.WeaveSeed) * math.rad(42)
		if j.Waist then j.Waist.Transform = CFrame.Angles(math.rad(-14), math.sin(phase) * math.rad(9), 0) end
		if j.Neck then j.Neck.Transform = CFrame.Angles(math.rad(8), shoulderGlance, 0) end
	elseif mode == "Nervous" then
		-- Shaky nervous pause: hunched shoulders, defensive raised hands, darting eyes/head!
		local shiver = math.sin(now * 18 + rig.WeaveSeed) * math.rad(2.5)
		local scanYaw = math.sin(now * 4.4 + rig.WeaveSeed) * math.rad(46)
		if j.LeftHip then j.LeftHip.Transform = CFrame.Angles(math.rad(6), 0, 0) end
		if j.RightHip then j.RightHip.Transform = CFrame.Angles(math.rad(-6), 0, 0) end
		if j.LeftKnee then j.LeftKnee.Transform = CFrame.Angles(math.rad(-10), 0, 0) end
		if j.RightKnee then j.RightKnee.Transform = CFrame.Angles(math.rad(-10), 0, 0) end
		if j.LeftShoulder then j.LeftShoulder.Transform = CFrame.Angles(math.rad(64) + shiver, 0, math.rad(-12)) end
		if j.RightShoulder then j.RightShoulder.Transform = CFrame.Angles(math.rad(64) - shiver, 0, math.rad(12)) end
		if j.LeftElbow then j.LeftElbow.Transform = CFrame.Angles(math.rad(72), 0, 0) end
		if j.RightElbow then j.RightElbow.Transform = CFrame.Angles(math.rad(72), 0, 0) end
		if j.Waist then j.Waist.Transform = CFrame.Angles(math.rad(-10), shiver * 1.4, 0) end
		if j.Neck then j.Neck.Transform = CFrame.Angles(math.rad(4), scanYaw, 0) end
	elseif mode == "Walk" then
		bob = math.abs(math.sin(phase)) * 0.16
		local swing = math.sin(phase) * math.rad(34)
		local kneeL = -math.max(0, -math.cos(phase)) * math.rad(38)
		local kneeR = -math.max(0, math.cos(phase)) * math.rad(38)
		if j.LeftHip then j.LeftHip.Transform = CFrame.Angles(-swing, 0, 0) end
		if j.RightHip then j.RightHip.Transform = CFrame.Angles(swing, 0, 0) end
		if j.LeftKnee then j.LeftKnee.Transform = CFrame.Angles(kneeL, 0, 0) end
		if j.RightKnee then j.RightKnee.Transform = CFrame.Angles(kneeR, 0, 0) end
		if j.LeftShoulder then j.LeftShoulder.Transform = CFrame.Angles(swing * 0.78, 0, math.rad(-4)) end
		if j.RightShoulder then j.RightShoulder.Transform = CFrame.Angles(-swing * 0.78, 0, math.rad(4)) end
		if j.LeftElbow then j.LeftElbow.Transform = CFrame.Angles(math.rad(18) + math.max(0, swing) * 0.45, 0, 0) end
		if j.RightElbow then j.RightElbow.Transform = CFrame.Angles(math.rad(18) + math.max(0, -swing) * 0.45, 0, 0) end
		if j.Waist then j.Waist.Transform = CFrame.Angles(math.rad(-3), math.sin(phase) * math.rad(5), 0) end
		if j.Neck then j.Neck.Transform = CFrame.Angles(math.rad(2), -math.sin(phase) * math.rad(3), 0) end
	else
		local breath = math.sin(now * 2.1 + rig.WeaveSeed)
		if j.LeftHip then j.LeftHip.Transform = CFrame.identity end
		if j.RightHip then j.RightHip.Transform = CFrame.identity end
		if j.LeftKnee then j.LeftKnee.Transform = CFrame.identity end
		if j.RightKnee then j.RightKnee.Transform = CFrame.identity end
		if j.LeftShoulder then j.LeftShoulder.Transform = CFrame.Angles(math.rad(4), 0, math.rad(-3 - breath * 1.4)) end
		if j.RightShoulder then j.RightShoulder.Transform = CFrame.Angles(math.rad(4), 0, math.rad(3 + breath * 1.4)) end
		if j.LeftElbow then j.LeftElbow.Transform = CFrame.Angles(math.rad(12), 0, 0) end
		if j.RightElbow then j.RightElbow.Transform = CFrame.Angles(math.rad(12), 0, 0) end
		if j.Waist then j.Waist.Transform = CFrame.Angles(math.rad(breath * 1.6), 0, 0) end
		if j.Neck then j.Neck.Transform = CFrame.Angles(0, math.sin(now * 0.8 + rig.WeaveSeed) * math.rad(10), 0) end
	end

	rig.RootPart.CFrame = CFrame.new(rig.CurrentPos.X, PLATFORM_Y + rig.FootOffset + bob, rig.CurrentPos.Z)
		* CFrame.Angles(0, rig.FacingYaw, 0)
end

local function triggerPanicNear(threatPos: Vector3): ()
	local now = os.clock()
	local panickedAny = false
	local closestDist = 9999

	for _, rig in ipairs(rigs) do
		local d = (Vector3.new(rig.CurrentPos.X - threatPos.X, 0, rig.CurrentPos.Z - threatPos.Z)).Magnitude
		if d <= PANIC_TRIGGER_RADIUS then
			local newlyScared = rig.PanicUntil <= now
			rig.ThreatPos = threatPos
			local dur = globalRng:NextNumber(7.5, 10.5)
			rig.PanicUntil = math.max(rig.PanicUntil, now + dur)
			rig.NervousUntil = rig.PanicUntil + globalRng:NextNumber(3.0, 4.2)
			rig.PauseTimer = 0
			rig.Model:SetAttribute("IsPanicking", true)
			rig.Model:SetAttribute("PanicState", "Panic")

			if newlyScared or rig.ChatTimer <= 0.4 then
				rig.ChatLabel.Text = PANIC_LINES[globalRng:NextInteger(1, #PANIC_LINES)]
				rig.ChatLabel.TextColor3 = C_PANIC_TEXT
				rig.ChatStroke.Color = C_PANIC_STROKE
				rig.ChatGui.Enabled = true
				rig.ChatTimer = globalRng:NextNumber(3.2, 4.8)
			end
			panickedAny = true
			if d < closestDist then
				closestDist = d
			end
		end
	end

	if panickedAny then
		local playerChar = Players.LocalPlayer.Character
		local pRoot = if playerChar then playerChar:FindFirstChild("HumanoidRootPart") else nil
		local listenerDist = if pRoot and pRoot:IsA("BasePart")
			then (pRoot.Position - threatPos).Magnitude
			else closestDist
		if listenerDist <= 140 then
			local vol = math.clamp(1 - (listenerDist / 145), 0.25, 1.0)
			AudioController.PlayCivilianPanicScream(vol)
		end
	end
end

local function findNearestWaypointIdx(pos: Vector3, waypoints: { Vector3 }): number
	local bestIdx = 1
	local bestDist = math.huge
	for i, wp in ipairs(waypoints) do
		local d = (Vector3.new(wp.X - pos.X, 0, wp.Z - pos.Z)).Magnitude
		if d < bestDist then
			bestDist = d
			bestIdx = i
		end
	end
	return bestIdx
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

	if not threatWired then
		threatWired = true
		AudioController.OnCombatThreat(function(worldPos: Vector3, _kind: string)
			triggerPanicNear(worldPos)
		end)
	end

	local existing = Workspace:FindFirstChild("CentralDistrictCitizens")
	if existing then existing:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = "CentralDistrictCitizens"
	folder.Parent = Workspace
	npcFolder = folder

	local rng = Random.new(20261130)
	table.clear(rigs)

	-- Circuit 1: Expanded Grand Central Shop Promenade
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

	-- Circuit 4: Mid-Town Culinary Boulevard Sidewalks
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

	local routeDefs: { { Waypoints: { Vector3 }, StartIdx: number } } = {
		{ Waypoints = outerCW, StartIdx = 1 }, { Waypoints = outerCW, StartIdx = 2 },
		{ Waypoints = outerCW, StartIdx = 3 }, { Waypoints = outerCW, StartIdx = 5 },
		{ Waypoints = outerCW, StartIdx = 6 }, { Waypoints = outerCW, StartIdx = 7 },
		{ Waypoints = outerCCW, StartIdx = 1 }, { Waypoints = outerCCW, StartIdx = 2 },
		{ Waypoints = outerCCW, StartIdx = 4 }, { Waypoints = outerCCW, StartIdx = 5 },
		{ Waypoints = outerCCW, StartIdx = 6 }, { Waypoints = outerCCW, StartIdx = 8 },
		{ Waypoints = fountainCW, StartIdx = 1 }, { Waypoints = fountainCW, StartIdx = 5 }, { Waypoints = fountainCW, StartIdx = 9 },
		{ Waypoints = fountainCCW, StartIdx = 2 }, { Waypoints = fountainCCW, StartIdx = 6 }, { Waypoints = fountainCCW, StartIdx = 10 },
		{ Waypoints = ewRoute, StartIdx = 1 }, { Waypoints = ewRoute, StartIdx = 3 },
		{ Waypoints = ewRouteEast, StartIdx = 1 }, { Waypoints = ewRouteEast, StartIdx = 3 },
		{ Waypoints = southRoute, StartIdx = 1 }, { Waypoints = southRoute, StartIdx = 3 },
		{ Waypoints = midNorth, StartIdx = 1 }, { Waypoints = midNorth, StartIdx = 2 }, { Waypoints = midNorth, StartIdx = 4 },
		{ Waypoints = midSouth, StartIdx = 1 }, { Waypoints = midSouth, StartIdx = 2 }, { Waypoints = midSouth, StartIdx = 4 },
		{ Waypoints = midEast, StartIdx = 1 }, { Waypoints = midEast, StartIdx = 2 }, { Waypoints = midEast, StartIdx = 4 },
		{ Waypoints = midWest, StartIdx = 1 }, { Waypoints = midWest, StartIdx = 2 }, { Waypoints = midWest, StartIdx = 4 },
	}

	local initNow = os.clock()
	for i, def in ipairs(routeDefs) do
		local wp = def.Waypoints
		local startPos = wp[def.StartIdx]
		local nextIdx = (def.StartIdx % #wp) + 1
		local rig = buildNPCModel(folder, i, rng, startPos, wp, nextIdx)
		updateRigPose(rig, "Idle", initNow)
		table.insert(rigs, rig)
	end

	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		local clampedDt = math.min(dt, 0.05)
		local now = os.clock()
		for _, rig in ipairs(rigs) do
			if rig.ChatTimer > 0 then
				rig.ChatTimer -= clampedDt
				if rig.ChatTimer <= 0 then
					rig.ChatGui.Enabled = false
				end
			end

			local isPanicking = now < rig.PanicUntil
			local isNervous = (not isPanicking) and (now < rig.NervousUntil)

			if isPanicking then
				rig.WasPanicking = true
				local away = Vector3.new(rig.CurrentPos.X - rig.ThreatPos.X, 0, rig.CurrentPos.Z - rig.ThreatPos.Z)
				local distFromThreat = away.Magnitude
				if distFromThreat >= PANIC_SAFE_DIST then
					-- Reached safe distance -> transition into shaky nervous look-around!
					rig.PanicUntil = now
					rig.NervousUntil = now + rng:NextNumber(2.8, 4.0)
					rig.Model:SetAttribute("PanicState", "Nervous")
					rig.ChatLabel.Text = NERVOUS_LINES[rng:NextInteger(1, #NERVOUS_LINES)]
					rig.ChatLabel.TextColor3 = C_NERVOUS_TEXT
					rig.ChatStroke.Color = C_NERVOUS_STROKE
					rig.ChatGui.Enabled = true
					rig.ChatTimer = 3.0
					updateRigPose(rig, "Nervous", now)
					continue
				end

				local baseDir = if distFromThreat > 0.2 then (away / distFromThreat) else Vector3.new(math.cos(rig.WeaveSeed), 0, math.sin(rig.WeaveSeed))
				-- Slight realistic organic weave so fleeing citizens scatter naturally
				local perp = Vector3.new(-baseDir.Z, 0, baseDir.X)
				local fleeDir = (baseDir + perp * (math.sin(now * 2.2 + rig.WeaveSeed) * 0.26)).Unit
				local fleeSpeed = math.clamp(rig.WalkSpeed * 2.15, 19.5, 24.5)
				local nextPos = rig.CurrentPos + fleeDir * (fleeSpeed * clampedDt)

				-- Keep Central Plaza / Boulevard citizens safely on dry island ground
				nextPos = Vector3.new(
					math.clamp(nextPos.X, -470, 470),
					PLATFORM_Y,
					math.clamp(nextPos.Z, -470, 470)
				)
				rig.CurrentPos = nextPos

				local desiredYaw = math.atan2(-fleeDir.X, -fleeDir.Z)
				local diff = (desiredYaw - rig.FacingYaw + math.pi) % (math.pi * 2) - math.pi
				rig.FacingYaw += diff * math.min(1, clampedDt * 13)

				rig.WalkPhase += clampedDt * (fleeSpeed * 1.05)
				updateRigPose(rig, "Panic", now)
				continue
			elseif isNervous then
				if rig.WasPanicking then
					rig.WasPanicking = false
					rig.Model:SetAttribute("PanicState", "Nervous")
					if rig.ChatTimer <= 0.4 then
						rig.ChatLabel.Text = NERVOUS_LINES[rng:NextInteger(1, #NERVOUS_LINES)]
						rig.ChatLabel.TextColor3 = C_NERVOUS_TEXT
						rig.ChatStroke.Color = C_NERVOUS_STROKE
						rig.ChatGui.Enabled = true
						rig.ChatTimer = 2.8
					end
				end
				updateRigPose(rig, "Nervous", now)
				continue
			elseif rig.Model:GetAttribute("IsPanicking") == true then
				rig.WasPanicking = false
				rig.Model:SetAttribute("IsPanicking", false)
				rig.Model:SetAttribute("PanicState", "Calm")
				rig.TargetIndex = findNearestWaypointIdx(rig.CurrentPos, rig.Waypoints)
			end

			if rig.PauseTimer > 0 then
				rig.PauseTimer -= clampedDt
				updateRigPose(rig, "Idle", now)
				continue
			end

			local target = rig.Waypoints[rig.TargetIndex]
			local delta = Vector3.new(target.X - rig.CurrentPos.X, 0, target.Z - rig.CurrentPos.Z)
			local dist = delta.Magnitude

			if dist < 1.3 then
				rig.TargetIndex = (rig.TargetIndex % #rig.Waypoints) + 1
				if rng:NextNumber(0, 1) < 0.35 then
					rig.PauseTimer = rng:NextNumber(1.8, 3.6)
					if rng:NextNumber(0, 1) < 0.45 then
						rig.ChatLabel.Text = CHAT_LINES[rng:NextInteger(1, #CHAT_LINES)]
						rig.ChatLabel.TextColor3 = C_CALM_TEXT
						rig.ChatStroke.Color = C_CALM_STROKE
						rig.ChatGui.Enabled = true
						rig.ChatTimer = 3.2
					end
				end
			else
				local step = math.min(dist, rig.WalkSpeed * clampedDt)
				local dir = delta / dist
				rig.CurrentPos += dir * step

				local desiredYaw = math.atan2(-dir.X, -dir.Z)
				local diff = (desiredYaw - rig.FacingYaw + math.pi) % (math.pi * 2) - math.pi
				rig.FacingYaw += diff * math.min(1, clampedDt * 8)

				rig.WalkPhase += clampedDt * (rig.WalkSpeed * 0.92)
				updateRigPose(rig, "Walk", now)
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
