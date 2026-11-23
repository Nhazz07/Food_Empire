--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local MonetizationService = require("./MonetizationService")

type DeliveryTarget = {
	Name: string,
	Pos: Vector3,
}

type RunnerSession = {
	Owner: Player,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	StatusLabel: TextLabel,
	Target: DeliveryTarget,
	SpottedWarned: boolean,
}

local DeliveryRunnerService = {}

local COOLDOWN_SECONDS = 15
local RUNNER_MAX_HP = 150
local RUNNER_SPEED = 17.5
local BASE_PAYOUT_GOLD = 165
local BASE_PAYOUT_REP = 32
local BASE_PAYOUT_EXP = 45

local CENTRAL_PARK_TARGETS: { DeliveryTarget } = {
	{ Name = "Central Park Fountain", Pos = Vector3.new(0, 4, 24) },
	{ Name = "Central Park North Lawn", Pos = Vector3.new(0, 4, -52) },
	{ Name = "Central Park Cherry Bench", Pos = Vector3.new(-78, 4, 78) },
	{ Name = "Central Park East Garden", Pos = Vector3.new(78, 4, -78) },
	{ Name = "Central Park West Plaza", Pos = Vector3.new(-78, 4, -22) },
}

local isRunning = false
local runnerFolder: Folder? = nil
local activeRunners: { [Player]: RunnerSession } = {}
local lastDispatchAt: { [Player]: number } = {}
local aiThread: thread? = nil
local playerRemovingConn: RBXScriptConnection? = nil

local function sendToast(player: Player, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

local function clearRunner(player: Player): ()
	local s = activeRunners[player]
	if s then
		if s.Model.Parent then
			s.Model:Destroy()
		end
		activeRunners[player] = nil
	end
end

local function getFrontGateSpawn(player: Player): Vector3
	local slot = BaseService.GetPlayerBaseSlot(player)
	if slot then
		local base = BaseService.GetBaseModel(slot)
		local bp = if base then (base:FindFirstChild("BasePivot") or base.PrimaryPart) else nil
		if bp and bp:IsA("BasePart") then
			return (bp.CFrame * CFrame.new(0, 4.5, 118)).Position
		end
	end
	return Vector3.new(0, 4.5, 220)
end

local function buildDeliveryRunnerModel(owner: Player, spawnPos: Vector3, target: DeliveryTarget): RunnerSession
	local slot = BaseService.GetPlayerBaseSlot(owner)
	local teamCol = if slot and SectorConfig.FactionColors[slot]
		then SectorConfig.FactionColors[slot]
		else Color3.fromRGB(48, 184, 112)

	local model = Instance.new("Model")
	model.Name = "DeliveryRunner_" .. tostring(owner.UserId)

	local function makePart(name: string, sz: Vector3, col: Color3, mat: Enum.Material, shape: Enum.PartType?, collide: boolean): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.Color = col
		p.Material = mat
		if shape then p.Shape = shape end
		p.CanCollide = collide
		p.CanTouch = collide
		p.Massless = not collide
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local function weldTo(p0: BasePart, p1: BasePart, rel: CFrame): ()
		p1.CFrame = p0.CFrame * rel
		local w = Instance.new("WeldConstraint")
		w.Part0 = p0
		w.Part1 = p1
		w.Parent = p1
	end

	local function makeJoint(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame): ()
		p1.CFrame = p0.CFrame * c0 * c1:Inverse()
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = p0
	end

	local skin = Color3.fromRGB(246, 212, 178)
	local root = makePart("HumanoidRootPart", Vector3.new(2.2, 2.6, 1.3), teamCol, Enum.Material.SmoothPlastic, nil, true)
	root.CFrame = CFrame.new(spawnPos)

	-- Insulated Hot Food Delivery Backpack!
	local pack = makePart("DeliveryBackpack", Vector3.new(2.4, 2.5, 1.8), Color3.fromRGB(248, 246, 238), Enum.Material.SmoothPlastic, nil, false)
	weldTo(root, pack, CFrame.new(0, 0.35, 1.55))
	local packStripe = makePart("PackStripe", Vector3.new(2.5, 0.45, 1.9), Color3.fromRGB(255, 206, 52), Enum.Material.Neon, nil, false)
	weldTo(pack, packStripe, CFrame.new(0, 0.4, 0))

	local head = makePart("Head", Vector3.new(1.85, 1.85, 1.85), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	weldTo(root, head, CFrame.new(0, 2.2, 0))
	local cap = makePart("DeliveryCap", Vector3.new(1.95, 0.75, 2.2), teamCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	weldTo(head, cap, CFrame.new(0, 0.65, -0.15))

	local leftArm = makePart("LeftArm", Vector3.new(0.85, 2.25, 0.85), teamCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("LeftArmJoint", root, leftArm, CFrame.new(-1.55, 0.95, 0), CFrame.new(0, 0.95, 0))
	local rightArm = makePart("RightArm", Vector3.new(0.85, 2.25, 0.85), teamCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("RightArmJoint", root, rightArm, CFrame.new(1.55, 0.95, 0), CFrame.new(0, 0.95, 0))

	local leftLeg = makePart("LeftLeg", Vector3.new(0.95, 2.35, 0.95), Color3.fromRGB(46, 54, 70), Enum.Material.SmoothPlastic, nil, false)
	makeJoint("LeftLegJoint", root, leftLeg, CFrame.new(-0.55, -1.3, 0), CFrame.new(0, 1.15, 0))
	local rightLeg = makePart("RightLeg", Vector3.new(0.95, 2.35, 0.95), Color3.fromRGB(46, 54, 70), Enum.Material.SmoothPlastic, nil, false)
	makeJoint("RightLegJoint", root, rightLeg, CFrame.new(0.55, -1.3, 0), CFrame.new(0, 1.15, 0))

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 48)
	bb.StudsOffset = Vector3.new(0, 3.8, 0)
	bb.MaxDistance = 240
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 26)
	lbl.BackgroundColor3 = Color3.fromRGB(20, 34, 52)
	lbl.BackgroundTransparency = 0.06
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "📦 STEALTH DELIVERY -> PARK"
	lbl.TextSize = 12
	lbl.TextColor3 = Color3.fromRGB(134, 248, 178)
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = lbl

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.08, 0, 0, 31)
	hpBg.Size = UDim2.new(0.84, 0, 0, 10)
	hpBg.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
	hpBg.Parent = bb
	local hpc = Instance.new("UICorner")
	hpc.CornerRadius = UDim.new(0, 5)
	hpc.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(68, 224, 118)
	hpFill.Parent = hpBg
	local hpfc = Instance.new("UICorner")
	hpfc.CornerRadius = UDim.new(0, 5)
	hpfc.Parent = hpFill

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = RUNNER_MAX_HP
	hum.Health = RUNNER_MAX_HP
	hum.WalkSpeed = RUNNER_SPEED
	hum.HipHeight = 2.45
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	hum.HealthChanged:Connect(function(hp: number)
		local frac = math.clamp(hp / math.max(1, hum.MaxHealth), 0, 1)
		hpFill.Size = UDim2.fromScale(frac, 1)
		hpFill.BackgroundColor3 = if frac > 0.5 then Color3.fromRGB(68, 224, 118) elseif frac > 0.25 then Color3.fromRGB(246, 188, 44) else Color3.fromRGB(238, 56, 62)
	end)

	model.PrimaryPart = root
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("Faction", "Player_" .. tostring(owner.UserId))
	CollectionService:AddTag(model, "PlayerDeliveryRunner")
	CollectionService:AddTag(model, "AnimatedCustomerLimbs")
	model.Parent = runnerFolder or Workspace

	return {
		Owner = owner,
		Model = model,
		Humanoid = hum,
		Root = root,
		StatusLabel = lbl,
		Target = target,
		SpottedWarned = false,
	}
end

function DeliveryRunnerService.GetActiveRunnerPosition(player: Player): Vector3?
	local s = activeRunners[player]
	if s and s.Model.Parent and s.Humanoid.Health > 0 then
		return s.Root.Position
	end
	return nil
end

function DeliveryRunnerService.IsActive(player: Player): boolean
	local s = activeRunners[player]
	return s ~= nil and s.Model.Parent ~= nil and s.Humanoid.Health > 0
end

function DeliveryRunnerService.GetCooldownRemaining(player: Player): number
	local last = lastDispatchAt[player] or 0
	return math.max(0, math.ceil((last + COOLDOWN_SECONDS) - os.clock()))
end

function DeliveryRunnerService.DispatchRunner(player: Player): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza first!"
	end
	if DeliveryRunnerService.IsActive(player) then
		return false, "Your Stealth Delivery Runner is already heading to Central Park!"
	end
	local cd = DeliveryRunnerService.GetCooldownRemaining(player)
	if cd > 0 then
		return false, string.format("Next Delivery Runner ready in %ds!", cd)
	end

	lastDispatchAt[player] = os.clock()
	local target = CENTRAL_PARK_TARGETS[math.random(1, #CENTRAL_PARK_TARGETS)]
	local spawnPos = getFrontGateSpawn(player)
	local session = buildDeliveryRunnerModel(player, spawnPos, target)
	activeRunners[player] = session

	session.Humanoid.Died:Connect(function()
		if activeRunners[player] == session then
			activeRunners[player] = nil
			sendToast(player, "⚠️ Rival Chef / Mafia knocked out your Delivery Runner! Escort him or hire Bodyguards!")
			task.delay(2.5, function()
				if session.Model.Parent then
					session.Model:Destroy()
				end
			end)
		end
	end)

	return true, string.format("📦 Delivery Runner dispatched to %s! Don't let Rivals spot him (+%dG)!", target.Name, BASE_PAYOUT_GOLD)
end

local function findThreatNear(pos: Vector3, radius: number): Vector3?
	local closest: Vector3? = nil
	local bestDist = radius
	for _, tagName in ipairs({ "RivalAIUnit", "MafiaUnit" }) do
		for _, unit in ipairs(CollectionService:GetTagged(tagName)) do
			if unit:IsA("Model") then
				local r = unit:FindFirstChild("HumanoidRootPart")
				local h = unit:FindFirstChildOfClass("Humanoid")
				if r and r:IsA("BasePart") and h and h.Health > 0 then
					local d = (r.Position - pos).Magnitude
					if d < bestDist then
						bestDist = d
						closest = r.Position
					end
				end
			end
		end
	end
	return closest
end

function DeliveryRunnerService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local existing = Workspace:FindFirstChild("PlayerDeliveryRunners")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		runnerFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "PlayerDeliveryRunners"
		f.Parent = Workspace
		runnerFolder = f
	end

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		clearRunner(player)
		lastDispatchAt[player] = nil
	end)

	aiThread = task.spawn(function()
		while isRunning do
			task.wait(0.8)
			if not isRunning then
				break
			end

			for owner, session in pairs(activeRunners) do
				if not owner.Parent or not session.Model.Parent or session.Humanoid.Health <= 0 then
					clearRunner(owner)
					continue
				end

				local pos = session.Root.Position
				local dest = session.Target.Pos
				local distToGoal = (Vector3.new(dest.X, pos.Y, dest.Z) - pos).Magnitude

				-- Delivered safely to Central Park Customer!
				if distToGoal <= 13 then
					local passMult = MonetizationService.GetPayoutMultiplier(owner)
					local repMult = MonetizationService.GetRepMultiplier(owner)
					local gold = math.floor(BASE_PAYOUT_GOLD * passMult)
					local rep = math.floor(BASE_PAYOUT_REP * repMult)
					PlayerDataService.AddRewards(owner, gold, BASE_PAYOUT_EXP, rep)
					sendToast(owner, string.format("📦 Delivery Runner reached %s safely! +%d Gold & +%d Rep!", session.Target.Name, gold, rep))
					clearRunner(owner)
					continue
				end

				-- Check if spotted by Rival Chef or Food Mafia -> sidestep stealthily & alert boss!
				local threatPos = findThreatNear(pos, 42)
				local moveTarget = dest
				if threatPos then
					session.StatusLabel.Text = "⚠️ SPOTTED! EVADING RIVAL!"
					session.StatusLabel.TextColor3 = Color3.fromRGB(255, 118, 118)
					if not session.SpottedWarned then
						session.SpottedWarned = true
						sendToast(owner, "👀 A Rival / Mafia SPOTTED your Delivery Runner in Central Park! Defend him!")
					end
					-- Sidestep perpendicular to threat while still advancing toward Central Park
					local toGoal = (dest - pos)
					local away = (pos - threatPos)
					local evadeDir = Vector3.new(toGoal.X + away.X * 1.4, 0, toGoal.Z + away.Z * 1.4)
					if evadeDir.Magnitude > 0.1 then
						moveTarget = pos + evadeDir.Unit * 28
					end
				else
					session.StatusLabel.Text = "📦 STEALTH DELIVERY -> PARK"
					session.StatusLabel.TextColor3 = Color3.fromRGB(134, 248, 178)
				end

				local path = PathfindingService:CreatePath({ AgentRadius = 2.4, AgentHeight = 6, AgentCanJump = true })
				local ok = pcall(function()
					path:ComputeAsync(pos, moveTarget)
				end)
				if ok and path.Status == Enum.PathStatus.Success then
					local wps = path:GetWaypoints()
					local step = wps[math.min(5, #wps)]
					if step then
						if step.Action == Enum.PathWaypointAction.Jump then
							session.Humanoid.Jump = true
						end
						session.Humanoid:MoveTo(step.Position)
					else
						session.Humanoid:MoveTo(moveTarget)
					end
				else
					session.Humanoid:MoveTo(moveTarget)
				end
			end
		end
	end)

	print("[Food Empire] DeliveryRunnerService started (Stealth Central Park Delivery Runner NPCs active)!")
end

function DeliveryRunnerService.Stop(): ()
	isRunning = false
	if aiThread then
		task.cancel(aiThread)
		aiThread = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for p in pairs(activeRunners) do
		clearRunner(p)
	end
	table.clear(lastDispatchAt)
end

return DeliveryRunnerService
