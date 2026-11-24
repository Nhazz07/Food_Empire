--!strict

-- UrbanNPCController: 48 authentic Roblox R15 MeshPart friendly neighborhood citizens
-- across all 16 Urban Turf Districts. Reacts realistically to nearby gunshots, mafia fights,
-- and turf wars: panicked scream, hands raised / head-shielding sprint directly away from
-- combat, shaky nervous cooldown glancing around, then calm return to neighborhood sidewalks!

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TurfConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("TurfConfig")
)
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

type UrbanCitizen = {
	BlockId: string,
	HomeCenter: Vector3,
	Model: Model,
	RootPart: BasePart,
	Head: BasePart,
	Joints: JointCache,
	FootOffset: number,
	ChatGui: BillboardGui,
	ChatLabel: TextLabel,
	ChatStroke: UIStroke,
	Waypoints: { Vector3 },
	TargetIndex: number,
	CurrentPos: Vector3,
	FacingYaw: number,
	BaseWalkSpeed: number,
	WalkPhase: number,
	PauseTimer: number,
	ChatTimer: number,
	PanicUntil: number,
	NervousUntil: number,
	ThreatPos: Vector3,
	PanicStyle: number,
	WeaveSeed: number,
	WasPanicking: boolean,
}

local UrbanNPCController = {}

local SIDEWALK_Y = 1.55
local PANIC_TRIGGER_RADIUS = 115
local PANIC_SAFE_DIST = 105
local heartbeatConn: RBXScriptConnection? = nil
local npcFolder: Folder? = nil
local citizens: { UrbanCitizen } = {}
local blockStatesCache: { [string]: { Owner: string, Status: string, UnderAttack: boolean, OwnerName: string } } = {}
local threatWired = false
local globalRng = Random.new(20261123)

local MAFIA_CHAT_LINES = {
	"Keep your head down, Mafia runs this block...",
	"Great coffee at the corner shop!",
	"Hope someone drives the syndicate out soon!",
	"Love these new midtown towers!",
	"Heading to the bistro for lunch!",
	"Watch out for armed enforcers near the plaza!",
	"Busy neighborhood today!",
	"Best street food in the district!",
}

local LIBERATED_CHAT_LINES = {
	"Streets feel way safer under the new boss!",
	"So glad the Mafia got kicked off our block!",
	"Business is booming on this street!",
	"Best neighborhood in Food Empire!",
	"Grabbing a snack at the plaza kiosk!",
	"Love the new colors on the plaza!",
}

local PANIC_CHAT_LINES = {
	"GUNSHOTS! RUN!",
	"TAKE COVER! SHOOTOUT!",
	"MAFIA FIGHT! GET OUT OF HERE!",
	"HELP! SOMEONE'S SHOOTING!",
	"OH NO! GET OFF THE STREET!",
	"RUN! DON'T LOOK BACK!",
}

local NERVOUS_CHAT_LINES = {
	"Is the fight over...?",
	"My hands are shaking...",
	"That was terrifying...",
	"Stay clear of that corner...",
}

local C_CALM_STROKE = Color3.fromRGB(64, 68, 78)
local C_CALM_TEXT = Color3.fromRGB(228, 224, 216)
local C_PANIC_STROKE = Color3.fromRGB(168, 36, 44)
local C_PANIC_TEXT = Color3.fromRGB(248, 178, 174)
local C_NERVOUS_STROKE = Color3.fromRGB(172, 142, 76)
local C_NERVOUS_TEXT = Color3.fromRGB(236, 218, 174)

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

local function buildCitizen(parent: Instance, blockId: string, homeCenter: Vector3, index: number, rng: Random, waypoints: { Vector3 }, startIdx: number): UrbanCitizen
	local startPos = waypoints[startIdx]
	local nextIdx = (startIdx % #waypoints) + 1
	local spawnCF = CFrame.new(startPos.X, SIDEWALK_Y + 3.0, startPos.Z)
	local scale = rng:NextNumber(0.95, 1.05)
	local isChef = (index % 5 == 0)

	local rigHandle: MafiaVisualBuilder.RigHandle
	if isChef then
		rigHandle = MafiaVisualBuilder.BuildChefRig("UrbanCitizen_" .. blockId .. "_" .. tostring(index), Color3.fromRGB(52, 64, 78), scale, spawnCF, false)
	else
		rigHandle = MafiaVisualBuilder.BuildCustomerRig("UrbanCitizen_" .. blockId .. "_" .. tostring(index), index, scale, spawnCF)
	end

	local m = rigHandle.Model
	local root = rigHandle.Root
	local head = rigHandle.Head
	local footOffset = math.clamp(root.Position.Y - (rigHandle.LeftFoot.Position.Y - rigHandle.LeftFoot.Size.Y * 0.5), 2.5, 3.6)

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

	local bb = Instance.new("BillboardGui")
	bb.Name = "CitizenChat"
	bb.Size = UDim2.fromOffset(196, 32)
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
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 5); c.Parent = lbl
	local st = Instance.new("UIStroke"); st.Color = C_CALM_STROKE; st.Thickness = 1.3; st.Parent = lbl

	m.Parent = parent

	return {
		BlockId = blockId,
		HomeCenter = homeCenter,
		Model = m,
		RootPart = root,
		Head = head,
		Joints = cacheR15Joints(m),
		FootOffset = footOffset,
		ChatGui = bb,
		ChatLabel = lbl,
		ChatStroke = st,
		Waypoints = waypoints,
		TargetIndex = nextIdx,
		CurrentPos = startPos,
		FacingYaw = 0,
		BaseWalkSpeed = rng:NextNumber(7.8, 11.0),
		WalkPhase = rng:NextNumber(0, math.pi * 2),
		PauseTimer = rng:NextNumber(0, 1.6),
		ChatTimer = 0,
		PanicUntil = 0,
		NervousUntil = 0,
		ThreatPos = Vector3.zero,
		PanicStyle = rng:NextInteger(1, 2),
		WeaveSeed = rng:NextNumber(0, math.pi * 2),
		WasPanicking = false,
	}
end

local function updateCitizenPose(c: UrbanCitizen, mode: "Walk" | "Idle" | "Panic" | "Nervous", now: number): ()
	local j = c.Joints
	local phase = c.WalkPhase
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

		local wave = math.sin(now * 14 + c.WeaveSeed)
		if c.PanicStyle == 1 then
			if j.LeftShoulder then
				j.LeftShoulder.Transform = CFrame.Angles(math.rad(152 + wave * 16), 0, math.rad(-24 + wave * 10))
			end
			if j.RightShoulder then
				j.RightShoulder.Transform = CFrame.Angles(math.rad(152 - wave * 16), 0, math.rad(24 + wave * 10))
			end
			if j.LeftElbow then j.LeftElbow.Transform = CFrame.Angles(math.rad(36 + math.abs(wave) * 22), 0, 0) end
			if j.RightElbow then j.RightElbow.Transform = CFrame.Angles(math.rad(36 + math.abs(wave) * 22), 0, 0) end
		else
			if j.LeftShoulder then
				j.LeftShoulder.Transform = CFrame.Angles(math.rad(128 + wave * 8), 0, math.rad(-14))
			end
			if j.RightShoulder then
				j.RightShoulder.Transform = CFrame.Angles(math.rad(128 - wave * 8), 0, math.rad(14))
			end
			if j.LeftElbow then j.LeftElbow.Transform = CFrame.Angles(math.rad(82), 0, math.rad(18)) end
			if j.RightElbow then j.RightElbow.Transform = CFrame.Angles(math.rad(82), 0, math.rad(-18)) end
		end

		local shoulderGlance = math.sin(now * 6.5 + c.WeaveSeed) * math.rad(42)
		if j.Waist then j.Waist.Transform = CFrame.Angles(math.rad(-14), math.sin(phase) * math.rad(9), 0) end
		if j.Neck then j.Neck.Transform = CFrame.Angles(math.rad(8), shoulderGlance, 0) end
	elseif mode == "Nervous" then
		local shiver = math.sin(now * 18 + c.WeaveSeed) * math.rad(2.5)
		local scanYaw = math.sin(now * 4.4 + c.WeaveSeed) * math.rad(46)
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
		local breath = math.sin(now * 2.1 + c.WeaveSeed)
		if j.LeftHip then j.LeftHip.Transform = CFrame.identity end
		if j.RightHip then j.RightHip.Transform = CFrame.identity end
		if j.LeftKnee then j.LeftKnee.Transform = CFrame.identity end
		if j.RightKnee then j.RightKnee.Transform = CFrame.identity end
		if j.LeftShoulder then j.LeftShoulder.Transform = CFrame.Angles(math.rad(4), 0, math.rad(-3 - breath * 1.4)) end
		if j.RightShoulder then j.RightShoulder.Transform = CFrame.Angles(math.rad(4), 0, math.rad(3 + breath * 1.4)) end
		if j.LeftElbow then j.LeftElbow.Transform = CFrame.Angles(math.rad(12), 0, 0) end
		if j.RightElbow then j.RightElbow.Transform = CFrame.Angles(math.rad(12), 0, 0) end
		if j.Waist then j.Waist.Transform = CFrame.Angles(math.rad(breath * 1.6), 0, 0) end
		if j.Neck then j.Neck.Transform = CFrame.Angles(0, math.sin(now * 0.8 + c.WeaveSeed) * math.rad(10), 0) end
	end

	c.RootPart.CFrame = CFrame.new(c.CurrentPos.X, SIDEWALK_Y + c.FootOffset + bob, c.CurrentPos.Z)
		* CFrame.Angles(0, c.FacingYaw, 0)
end

local function triggerUrbanPanicNear(threatPos: Vector3): ()
	local now = os.clock()
	local panickedAny = false
	local closestDist = 9999

	for _, c in ipairs(citizens) do
		local d = (Vector3.new(c.CurrentPos.X - threatPos.X, 0, c.CurrentPos.Z - threatPos.Z)).Magnitude
		if d <= PANIC_TRIGGER_RADIUS then
			local newlyScared = c.PanicUntil <= now
			c.ThreatPos = threatPos
			local dur = globalRng:NextNumber(7.5, 10.5)
			c.PanicUntil = math.max(c.PanicUntil, now + dur)
			c.NervousUntil = c.PanicUntil + globalRng:NextNumber(3.0, 4.2)
			c.PauseTimer = 0
			c.Model:SetAttribute("IsPanicking", true)
			c.Model:SetAttribute("PanicState", "Panic")

			if newlyScared or c.ChatTimer <= 0.4 then
				c.ChatLabel.Text = PANIC_CHAT_LINES[globalRng:NextInteger(1, #PANIC_CHAT_LINES)]
				c.ChatLabel.TextColor3 = C_PANIC_TEXT
				c.ChatStroke.Color = C_PANIC_STROKE
				c.ChatGui.Enabled = true
				c.ChatTimer = globalRng:NextNumber(3.2, 4.8)
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

local function getBlockWalkRoutes(spec: TurfConfig.TurfBlockSpec): { { Vector3 } }
	local uv = TurfConfig.UVToWorld
	local w = spec.Wedge
	if spec.Ring == "Inner" then
		if w == "WSW" then
			local loopA = {
				uv(w, 186, 274, SIDEWALK_Y),
				uv(w, 244, 274, SIDEWALK_Y),
				uv(w, 244, 332, SIDEWALK_Y),
				uv(w, 186, 332, SIDEWALK_Y),
			}
			local loopB = {
				uv(w, 92, 232, SIDEWALK_Y),
				uv(w, 92, 340, SIDEWALK_Y),
				uv(w, 178, 340, SIDEWALK_Y),
				uv(w, 178, 274, SIDEWALK_Y),
			}
			return { loopA, loopB }
		else
			local plazaLoop = {
				uv(w, 114, 250, SIDEWALK_Y),
				uv(w, 194, 250, SIDEWALK_Y),
				uv(w, 194, 312, SIDEWALK_Y),
				uv(w, 114, 312, SIDEWALK_Y),
			}
			local alleyLoop = {
				uv(w, 95, 224, SIDEWALK_Y),
				uv(w, 95, 342, SIDEWALK_Y),
				uv(w, 196, 342, SIDEWALK_Y),
				uv(w, 196, 260, SIDEWALK_Y),
			}
			return { plazaLoop, alleyLoop }
		end
	else
		local outerPlazaLoop = {
			uv(w, 174, 392, SIDEWALK_Y),
			uv(w, 264, 392, SIDEWALK_Y),
			uv(w, 264, 448, SIDEWALK_Y),
			uv(w, 174, 448, SIDEWALK_Y),
		}
		local streetLoop = {
			uv(w, 98, 366, SIDEWALK_Y),
			uv(w, 264, 366, SIDEWALK_Y),
			uv(w, 264, 470, SIDEWALK_Y),
			uv(w, 98, 470, SIDEWALK_Y),
		}
		return { outerPlazaLoop, streetLoop }
	end
end

function UrbanNPCController.Update(state: { [string]: any }): ()
	local turf = state.Turf
	if typeof(turf) == "table" and typeof(turf.Blocks) == "table" then
		for blockId, info in pairs(turf.Blocks) do
			if typeof(info) == "table" then
				blockStatesCache[blockId] = {
					Owner = tostring(info.Owner or ""),
					Status = tostring(info.Status or "Controlled"),
					UnderAttack = info.UnderAttack == true,
					OwnerName = tostring(info.OwnerName or ""),
				}
			end
		end
	end
end

function UrbanNPCController.Start(): ()
	if heartbeatConn then
		return
	end

	if not threatWired then
		threatWired = true
		AudioController.OnCombatThreat(function(worldPos: Vector3, _kind: string)
			triggerUrbanPanicNear(worldPos)
		end)
	end

	local existing = Workspace:FindFirstChild("UrbanDistrictCitizens")
	if existing then existing:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = "UrbanDistrictCitizens"
	folder.Parent = Workspace
	npcFolder = folder

	local rng = Random.new(20261123)
	table.clear(citizens)

	local initNow = os.clock()
	local globalIdx = 0
	for _, blockId in ipairs(TurfConfig.BlockOrder) do
		local spec = TurfConfig.Blocks[blockId]
		if spec then
			local routes = getBlockWalkRoutes(spec)
			for localSlot = 1, 3 do
				globalIdx += 1
				local route = routes[((localSlot - 1) % #routes) + 1]
				local startIdx = ((localSlot - 1) % #route) + 1
				local c = buildCitizen(folder, blockId, spec.PlazaPos, globalIdx, rng, route, startIdx)
				updateCitizenPose(c, "Idle", initNow)
				table.insert(citizens, c)
			end
		end
	end

	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		local clampedDt = math.min(dt, 0.05)
		local now = os.clock()
		for _, c in ipairs(citizens) do
			if c.ChatTimer > 0 then
				c.ChatTimer -= clampedDt
				if c.ChatTimer <= 0 then
					c.ChatGui.Enabled = false
				end
			end

			local bState = blockStatesCache[c.BlockId]
			local isConflict = bState ~= nil and (bState.Status == "Contested" or bState.UnderAttack)
			local isPlayerOwned = bState ~= nil and not TurfConfig.IsMafiaFaction(bState.Owner) and bState.Owner ~= ""

			-- If their block enters an active turf conflict, automatically flee from the plaza!
			if isConflict and now >= c.PanicUntil then
				c.ThreatPos = c.HomeCenter
				c.PanicUntil = now + 4.0
				c.NervousUntil = now + 7.2
				c.Model:SetAttribute("IsPanicking", true)
				c.Model:SetAttribute("PanicState", "Panic")
			end

			local isPanicking = now < c.PanicUntil
			local isNervous = (not isPanicking) and (now < c.NervousUntil)

			if isPanicking then
				c.WasPanicking = true
				local away = Vector3.new(c.CurrentPos.X - c.ThreatPos.X, 0, c.CurrentPos.Z - c.ThreatPos.Z)
				local distFromThreat = away.Magnitude
				if distFromThreat >= PANIC_SAFE_DIST and not isConflict then
					c.PanicUntil = now
					c.NervousUntil = now + rng:NextNumber(2.8, 4.0)
					c.Model:SetAttribute("PanicState", "Nervous")
					c.ChatLabel.Text = NERVOUS_CHAT_LINES[rng:NextInteger(1, #NERVOUS_CHAT_LINES)]
					c.ChatLabel.TextColor3 = C_NERVOUS_TEXT
					c.ChatStroke.Color = C_NERVOUS_STROKE
					c.ChatGui.Enabled = true
					c.ChatTimer = 3.0
					updateCitizenPose(c, "Nervous", now)
					continue
				end

				local baseDir = if distFromThreat > 0.2 then (away / distFromThreat) else Vector3.new(math.cos(c.WeaveSeed), 0, math.sin(c.WeaveSeed))
				local perp = Vector3.new(-baseDir.Z, 0, baseDir.X)
				local fleeDir = (baseDir + perp * (math.sin(now * 2.2 + c.WeaveSeed) * 0.26)).Unit
				local fleeSpeed = math.clamp(c.BaseWalkSpeed * 2.1, 19.0, 23.8)
				local nextPos = c.CurrentPos + fleeDir * (fleeSpeed * clampedDt)

				-- Keep within safe neighborhood leash radius (125 studs of their block) & dry land
				local fromHome = Vector3.new(nextPos.X - c.HomeCenter.X, 0, nextPos.Z - c.HomeCenter.Z)
				if fromHome.Magnitude > 118 then
					nextPos = c.HomeCenter + fromHome.Unit * 118
				end
				c.CurrentPos = Vector3.new(
					math.clamp(nextPos.X, -515, 515),
					SIDEWALK_Y,
					math.clamp(nextPos.Z, -515, 515)
				)

				local desiredYaw = math.atan2(-fleeDir.X, -fleeDir.Z)
				local diff = (desiredYaw - c.FacingYaw + math.pi) % (math.pi * 2) - math.pi
				c.FacingYaw += diff * math.min(1, clampedDt * 13)

				c.WalkPhase += clampedDt * (fleeSpeed * 1.05)
				updateCitizenPose(c, "Panic", now)
				continue
			elseif isNervous then
				if c.WasPanicking then
					c.WasPanicking = false
					c.Model:SetAttribute("PanicState", "Nervous")
					if c.ChatTimer <= 0.4 then
						c.ChatLabel.Text = NERVOUS_CHAT_LINES[rng:NextInteger(1, #NERVOUS_CHAT_LINES)]
						c.ChatLabel.TextColor3 = C_NERVOUS_TEXT
						c.ChatStroke.Color = C_NERVOUS_STROKE
						c.ChatGui.Enabled = true
						c.ChatTimer = 2.8
					end
				end
				updateCitizenPose(c, "Nervous", now)
				continue
			elseif c.Model:GetAttribute("IsPanicking") == true then
				c.WasPanicking = false
				c.Model:SetAttribute("IsPanicking", false)
				c.Model:SetAttribute("PanicState", "Calm")
				c.TargetIndex = findNearestWaypointIdx(c.CurrentPos, c.Waypoints)
			end

			if c.PauseTimer > 0 then
				c.PauseTimer -= clampedDt
				updateCitizenPose(c, "Idle", now)
				continue
			end

			local speed = c.BaseWalkSpeed
			local target = c.Waypoints[c.TargetIndex]
			local delta = Vector3.new(target.X - c.CurrentPos.X, 0, target.Z - c.CurrentPos.Z)
			local dist = delta.Magnitude

			if dist < 1.4 then
				c.TargetIndex = (c.TargetIndex % #c.Waypoints) + 1
				if rng:NextNumber(0, 1) < 0.32 then
					c.PauseTimer = rng:NextNumber(1.4, 3.2)
				end
				if rng:NextNumber(0, 1) < 0.32 then
					local pool = if isPlayerOwned then LIBERATED_CHAT_LINES else MAFIA_CHAT_LINES
					c.ChatLabel.Text = pool[rng:NextInteger(1, #pool)]
					c.ChatLabel.TextColor3 = C_CALM_TEXT
					c.ChatStroke.Color = C_CALM_STROKE
					c.ChatGui.Enabled = true
					c.ChatTimer = 3.0
				end
			else
				local step = math.min(dist, speed * clampedDt)
				local dir = delta / dist
				c.CurrentPos += dir * step

				local desiredYaw = math.atan2(-dir.X, -dir.Z)
				local diff = (desiredYaw - c.FacingYaw + math.pi) % (math.pi * 2) - math.pi
				c.FacingYaw += diff * math.min(1, clampedDt * 8)

				c.WalkPhase += clampedDt * (speed * 0.92)
				updateCitizenPose(c, "Walk", now)
			end
		end
	end)
end

function UrbanNPCController.Stop(): ()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	if npcFolder then
		npcFolder:Destroy()
		npcFolder = nil
	end
	table.clear(citizens)
end

return UrbanNPCController
