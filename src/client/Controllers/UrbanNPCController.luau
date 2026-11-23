--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TurfConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("TurfConfig")
)

type UrbanCitizen = {
	BlockId: string,
	Model: Model,
	RootPart: Part,
	Torso: Part,
	Head: Part,
	LeftArm: Part,
	RightArm: Part,
	LeftLeg: Part,
	RightLeg: Part,
	Hat: Part,
	IsChefHat: boolean,
	ChatGui: BillboardGui,
	ChatLabel: TextLabel,
	Waypoints: { Vector3 },
	TargetIndex: number,
	CurrentPos: Vector3,
	FacingYaw: number,
	BaseWalkSpeed: number,
	WalkPhase: number,
	PauseTimer: number,
	ChatTimer: number,
}

local UrbanNPCController = {}

local SIDEWALK_Y = 1.55
local heartbeatConn: RBXScriptConnection? = nil
local npcFolder: Folder? = nil
local citizens: { UrbanCitizen } = {}
local blockStatesCache: { [string]: { Owner: string, Status: string, UnderAttack: boolean, OwnerName: string } } = {}

local SKIN_TONES = {
	Color3.fromRGB(224, 188, 156),
	Color3.fromRGB(204, 166, 134),
	Color3.fromRGB(168, 124, 92),
	Color3.fromRGB(234, 202, 174),
	Color3.fromRGB(142, 98, 68),
}

local OUTFIT_COLORS = {
	Color3.fromRGB(48, 52, 62),
	Color3.fromRGB(92, 42, 46),
	Color3.fromRGB(78, 62, 48),
	Color3.fromRGB(46, 62, 54),
	Color3.fromRGB(62, 56, 72),
	Color3.fromRGB(116, 88, 64),
	Color3.fromRGB(228, 226, 220),
	Color3.fromRGB(42, 58, 72),
	Color3.fromRGB(66, 48, 42),
}

local PANTS_COLORS = {
	Color3.fromRGB(32, 36, 44),
	Color3.fromRGB(48, 42, 38),
	Color3.fromRGB(30, 44, 62),
	Color3.fromRGB(40, 42, 48),
}

local HAIR_COLORS = {
	Color3.fromRGB(46, 30, 20),
	Color3.fromRGB(132, 92, 44),
	Color3.fromRGB(24, 24, 28),
	Color3.fromRGB(98, 52, 32),
	Color3.fromRGB(120, 122, 128),
}

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
	"Whoa! Turf war in the plaza!",
	"Take cover! Shootout happening!",
	"Mafia fight! Stay on the sidewalk!",
	"Who's taking over this block?!",
}

local function makePart(parent: Instance, name: string, size: Vector3, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = col
	p.Material = mat
	if shape then p.Shape = shape end
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

local function buildCitizen(parent: Instance, blockId: string, index: number, rng: Random, waypoints: { Vector3 }, startIdx: number): UrbanCitizen
	local m = Instance.new("Model")
	m.Name = "UrbanCitizen_" .. blockId .. "_" .. tostring(index)

	local skin = SKIN_TONES[rng:NextInteger(1, #SKIN_TONES)]
	local shirt = OUTFIT_COLORS[rng:NextInteger(1, #OUTFIT_COLORS)]
	local pants = PANTS_COLORS[rng:NextInteger(1, #PANTS_COLORS)]
	local hair = HAIR_COLORS[rng:NextInteger(1, #HAIR_COLORS)]
	local isChef = (index % 5 == 0)

	local root = makePart(m, "Root", Vector3.new(1, 1, 1), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, nil)
	root.Transparency = 1
	local coatCol = if isChef then Color3.fromRGB(232, 230, 224) else shirt
	local torso = makePart(m, "Torso", Vector3.new(2.02, 2.32, 1.10), coatCol, Enum.Material.Fabric, nil)
	makePart(m, "Collar", Vector3.new(1.50, 0.38, 1.14), if isChef then Color3.fromRGB(122, 28, 34) else Color3.fromRGB(214, 210, 202), Enum.Material.Fabric, nil)
	makePart(m, "Belt", Vector3.new(2.06, 0.22, 1.16), Color3.fromRGB(22, 22, 26), Enum.Material.Leather, nil)

	local head = makePart(m, "Head", Vector3.new(1.24, 1.26, 1.24), skin, Enum.Material.SmoothPlastic, nil)
	local hm = Instance.new("SpecialMesh")
	hm.MeshType = Enum.MeshType.Head
	hm.Scale = Vector3.new(1.18, 1.16, 1.18)
	hm.Parent = head
	makePart(m, "FaceEyes", Vector3.new(0.74, 0.14, 0.08), Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic, nil)

	local leftArm = makePart(m, "LeftArm", Vector3.new(0.76, 2.12, 0.76), coatCol, Enum.Material.Fabric, nil)
	local rightArm = makePart(m, "RightArm", Vector3.new(0.76, 2.12, 0.76), coatCol, Enum.Material.Fabric, nil)
	local leftLeg = makePart(m, "LeftLeg", Vector3.new(0.84, 2.24, 0.86), pants, Enum.Material.Fabric, nil)
	local rightLeg = makePart(m, "RightLeg", Vector3.new(0.84, 2.24, 0.86), pants, Enum.Material.Fabric, nil)

	local hat: Part
	if isChef then
		hat = makePart(m, "ChefHat", Vector3.new(0.78, 1.34, 1.34), Color3.fromRGB(238, 236, 232), Enum.Material.Fabric, Enum.PartType.Cylinder)
	else
		hat = makePart(m, "HairCap", Vector3.new(1.32, 0.42, 1.36), hair, Enum.Material.SmoothPlastic, nil)
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "CitizenChat"
	bb.Size = UDim2.fromOffset(185, 32)
	bb.StudsOffset = Vector3.new(0, 2.2, 0)
	bb.MaxDistance = 68
	bb.Enabled = false
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamMedium
	lbl.Text = ""
	lbl.TextColor3 = Color3.fromRGB(228, 224, 216)
	lbl.TextSize = 11
	lbl.TextWrapped = true
	lbl.Parent = bb
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 5); c.Parent = lbl
	local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(64, 68, 78); st.Thickness = 1.2; st.Parent = lbl

	m.PrimaryPart = root
	m.Parent = parent

	local startPos = waypoints[startIdx]
	local nextIdx = (startIdx % #waypoints) + 1

	return {
		BlockId = blockId,
		Model = m,
		RootPart = root,
		Torso = torso,
		Head = head,
		LeftArm = leftArm,
		RightArm = rightArm,
		LeftLeg = leftLeg,
		RightLeg = rightLeg,
		Hat = hat,
		IsChefHat = isChef,
		ChatGui = bb,
		ChatLabel = lbl,
		Waypoints = waypoints,
		TargetIndex = nextIdx,
		CurrentPos = startPos,
		FacingYaw = 0,
		BaseWalkSpeed = rng:NextNumber(7.8, 11.2),
		WalkPhase = rng:NextNumber(0, math.pi * 2),
		PauseTimer = rng:NextNumber(0, 1.6),
		ChatTimer = 0,
	}
end

local function updateCitizenPose(c: UrbanCitizen, isWalking: boolean): ()
	local bob = if isWalking then math.abs(math.sin(c.WalkPhase)) * 0.2 else 0
	local swing = if isWalking then math.sin(c.WalkPhase) * math.rad(34) else 0

	local baseCF = CFrame.new(c.CurrentPos.X, SIDEWALK_Y + bob, c.CurrentPos.Z) * CFrame.Angles(0, c.FacingYaw, 0)
	c.RootPart.CFrame = baseCF * CFrame.new(0, 3.3, 0)
	c.Torso.CFrame = baseCF * CFrame.new(0, 3.42, 0)

	local collar = c.Model:FindFirstChild("Collar")
	if collar and collar:IsA("BasePart") then collar.CFrame = baseCF * CFrame.new(0, 4.38, -0.02) end
	local belt = c.Model:FindFirstChild("Belt")
	if belt and belt:IsA("BasePart") then belt.CFrame = baseCF * CFrame.new(0, 2.38, 0) end

	local headCF = baseCF * CFrame.new(0, 5.34, 0)
	c.Head.CFrame = headCF
	local faceEyes = c.Model:FindFirstChild("FaceEyes")
	if faceEyes and faceEyes:IsA("BasePart") then faceEyes.CFrame = headCF * CFrame.new(0, 0.12, -0.58) end
	if c.IsChefHat then
		c.Hat.CFrame = headCF * CFrame.new(0, 0.88, 0) * CFrame.Angles(0, 0, math.rad(90))
	else
		c.Hat.CFrame = headCF * CFrame.new(0, 0.52, 0.06)
	end

	c.LeftArm.CFrame = baseCF * CFrame.new(-1.38, 4.30, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -0.90, 0)
	c.RightArm.CFrame = baseCF * CFrame.new(1.38, 4.30, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -0.90, 0)
	c.LeftLeg.CFrame = baseCF * CFrame.new(-0.50, 2.24, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1.12, 0)
	c.RightLeg.CFrame = baseCF * CFrame.new(0.50, 2.24, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1.12, 0)
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

	local existing = Workspace:FindFirstChild("UrbanDistrictCitizens")
	if existing then existing:Destroy() end

	local folder = Instance.new("Folder")
	folder.Name = "UrbanDistrictCitizens"
	folder.Parent = Workspace
	npcFolder = folder

	local rng = Random.new(20261123)
	table.clear(citizens)

	-- Spawn 3 lively friendly citizens per Urban Block (48 total across the 16 blocks!)
	local globalIdx = 0
	for _, blockId in ipairs(TurfConfig.BlockOrder) do
		local spec = TurfConfig.Blocks[blockId]
		if spec then
			local routes = getBlockWalkRoutes(spec)
			for localSlot = 1, 3 do
				globalIdx += 1
				local route = routes[((localSlot - 1) % #routes) + 1]
				local startIdx = ((localSlot - 1) % #route) + 1
				local c = buildCitizen(folder, blockId, globalIdx, rng, route, startIdx)
				updateCitizenPose(c, false)
				table.insert(citizens, c)
			end
		end
	end

	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		local clampedDt = math.min(dt, 0.05)
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

			if c.PauseTimer > 0 and not isConflict then
				c.PauseTimer -= clampedDt
				updateCitizenPose(c, false)
				continue
			end

			local speed = if isConflict then c.BaseWalkSpeed * 1.65 else c.BaseWalkSpeed
			local target = c.Waypoints[c.TargetIndex]
			local delta = Vector3.new(target.X - c.CurrentPos.X, 0, target.Z - c.CurrentPos.Z)
			local dist = delta.Magnitude

			if dist < 1.4 then
				c.TargetIndex = (c.TargetIndex % #c.Waypoints) + 1
				if not isConflict and rng:NextNumber(0, 1) < 0.32 then
					c.PauseTimer = rng:NextNumber(1.4, 3.2)
				end
				if rng:NextNumber(0, 1) < (if isConflict then 0.55 else 0.32) then
					local pool = if isConflict
						then PANIC_CHAT_LINES
						elseif isPlayerOwned then LIBERATED_CHAT_LINES
						else MAFIA_CHAT_LINES
					c.ChatLabel.Text = pool[rng:NextInteger(1, #pool)]
					c.ChatLabel.TextColor3 = if isConflict then Color3.fromRGB(224, 96, 102) else Color3.fromRGB(228, 224, 216)
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
				updateCitizenPose(c, true)
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