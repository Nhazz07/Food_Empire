--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local DeliveryRunnerService = require("./DeliveryRunnerService")
local BlackMarketService = require("./BlackMarketService")

type BodyguardAgent = {
	Owner: Player,
	Index: number,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	StatusLabel: TextLabel,
	LastAttackAt: number,
}

local BodyguardService = {}

BodyguardService.MAX_BODYGUARDS = 2
BodyguardService.COSTS = { [1] = 280, [2] = 520 }

local GUARD_MAX_HP = 240
local GUARD_SPEED = 23
local GUARD_DAMAGE = 34
local GUARD_ATTACK_RANGE = 11.5
local GUARD_COOLDOWN = 0.9
local PROTECT_RADIUS = 44
local RESPAWN_DELAY = 12

local isRunning = false
local guardFolder: Folder? = nil
local guardsByPlayer: { [Player]: { BodyguardAgent } } = {}
local playerUnderAttackUntil: { [Player]: number } = {}
local charConns: { [Player]: RBXScriptConnection } = {}
local hpConns: { [Player]: RBXScriptConnection } = {}
local aiThread: thread? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local unsubBase: (() -> ())? = nil

function BodyguardService.GetGuardCount(player: Player): number
	return math.clamp(PlayerDataService.GetProfile(player).BodyguardCount or 0, 0, BodyguardService.MAX_BODYGUARDS)
end

function BodyguardService.GetNextCost(player: Player): number?
	local count = BodyguardService.GetGuardCount(player)
	if count >= BodyguardService.MAX_BODYGUARDS then
		return nil
	end
	return BodyguardService.COSTS[count + 1]
end

local function spawnGuardHitBurst(pos: Vector3): ()
	local bp = Instance.new("Part")
	bp.Size = Vector3.new(1, 1, 1)
	bp.CFrame = CFrame.new(pos)
	bp.Transparency = 1
	bp.Anchored = true
	bp.CanCollide = false
	bp.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 224, 78))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.2, 0.38)
	pe.Speed = NumberRange.new(10, 16)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = bp
	pe:Emit(12)
	task.delay(0.5, function()
		if bp.Parent then bp:Destroy() end
	end)
end

local function getOwnerAnchorPos(owner: Player, index: number): Vector3
	local char = owner.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local side = if index == 1 then -6.5 else 6.5
		return (root.CFrame * CFrame.new(side, 0, 5.5)).Position
	end
	local slot = BaseService.GetPlayerBaseSlot(owner)
	if slot then
		local base = BaseService.GetBaseModel(slot)
		local sp = if base then base:FindFirstChild("BaseSpawn") else nil
		if sp and sp:IsA("BasePart") then
			return sp.Position + Vector3.new(if index == 1 then -6 else 6, 4, 0)
		end
	end
	return Vector3.new(0, 5, 20)
end

local function buildBodyguardModel(owner: Player, index: number, spawnPos: Vector3): BodyguardAgent
	local slot = BaseService.GetPlayerBaseSlot(owner)
	local teamCol = if slot and SectorConfig.FactionColors[slot]
		then SectorConfig.FactionColors[slot]
		else Color3.fromRGB(48, 162, 232)

	local model = Instance.new("Model")
	model.Name = string.format("Bodyguard_%d_%d", owner.UserId, index)

	local function gPart(name: string, sz: Vector3, col: Color3, mat: Enum.Material, shape: Enum.PartType?, collide: boolean): Part
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

	local armorCol = Color3.fromRGB(28, 34, 48)
	local goldCol = Color3.fromRGB(255, 212, 58)
	local skin = Color3.fromRGB(244, 208, 176)

	-- 1. Armored Bodyguard Jacket + Team Chest Badge + Shoulder Pads
	local root = gPart("HumanoidRootPart", Vector3.new(2.65, 2.85, 1.5), armorCol, Enum.Material.SmoothPlastic, nil, true)
	root.CFrame = CFrame.new(spawnPos)

	local vest = gPart("GuardVest", Vector3.new(2.75, 1.8, 1.62), teamCol, Enum.Material.Metal, nil, false)
	weldTo(root, vest, CFrame.new(0, 0.15, 0))
	local badge = gPart("ShieldBadge", Vector3.new(0.85, 0.95, 0.2), goldCol, Enum.Material.Neon, nil, false)
	weldTo(vest, badge, CFrame.new(-0.6, 0.3, -0.82))

	-- 2. Head + Tactical Sunglasses + Guard Beret
	local head = gPart("Head", Vector3.new(1.98, 1.98, 1.98), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	weldTo(root, head, CFrame.new(0, 2.38, 0))
	local shades = gPart("GuardShades", Vector3.new(1.55, 0.42, 0.35), Color3.fromRGB(16, 20, 30), Enum.Material.Glass, nil, false)
	weldTo(head, shades, CFrame.new(0, 0.14, -0.88))
	local beret = gPart("GuardBeret", Vector3.new(2.2, 0.85, 2.2), teamCol, Enum.Material.Fabric, Enum.PartType.Ball, false)
	weldTo(head, beret, CFrame.new(0.12, 0.85, 0))

	-- 3. Articulated Arms + Left Glowing Shield + Right Golden Cleaver!
	local leftArm = gPart("LeftArm", Vector3.new(0.98, 2.45, 0.98), armorCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("LeftArmJoint", root, leftArm, CFrame.new(-1.82, 1.05, 0), CFrame.new(0, 1.05, 0))
	local shield = gPart("GuardShield", Vector3.new(0.35, 2.5, 1.85), teamCol, Enum.Material.Metal, nil, false)
	weldTo(leftArm, shield, CFrame.new(-0.65, -0.35, -0.25))
	local shieldRim = gPart("ShieldRim", Vector3.new(0.4, 2.65, 0.25), goldCol, Enum.Material.Neon, nil, false)
	weldTo(shield, shieldRim, CFrame.new(0, 0, -0.92))

	local rightArm = gPart("RightArm", Vector3.new(0.98, 2.45, 0.98), armorCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("RightArmJoint", root, rightArm, CFrame.new(1.82, 1.05, 0), CFrame.new(0, 1.05, 0))
	local baton = gPart("GuardCleaver", Vector3.new(0.32, 0.85, 2.6), goldCol, Enum.Material.Neon, nil, false)
	weldTo(rightArm, baton, CFrame.new(0, -1.25, -1.35))

	-- 4. Articulated Legs + Combat Boots
	local leftLeg = gPart("LeftLeg", Vector3.new(1.05, 2.5, 1.05), armorCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("LeftLegJoint", root, leftLeg, CFrame.new(-0.62, -1.4, 0), CFrame.new(0, 1.25, 0))
	local rightLeg = gPart("RightLeg", Vector3.new(1.05, 2.5, 1.05), armorCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("RightLegJoint", root, rightLeg, CFrame.new(0.62, -1.4, 0), CFrame.new(0, 1.25, 0))

	-- 5. Nameplate + Live HP Bar
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(195, 46)
	bb.StudsOffset = Vector3.new(0, 3.9, 0)
	bb.MaxDistance = 150
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 25)
	lbl.BackgroundColor3 = Color3.fromRGB(20, 32, 54)
	lbl.BackgroundTransparency = 0.06
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "🛡️ BODYGUARD #" .. tostring(index)
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.fromRGB(134, 242, 255)
	lbl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = lbl
	local st = Instance.new("UIStroke")
	st.Color = goldCol
	st.Thickness = 1.6
	st.Parent = lbl

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.08, 0, 0, 30)
	hpBg.Size = UDim2.new(0.84, 0, 0, 10)
	hpBg.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
	hpBg.Parent = bb
	local hpc = Instance.new("UICorner")
	hpc.CornerRadius = UDim.new(0, 5)
	hpc.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(72, 224, 118)
	hpFill.Parent = hpBg
	local hpfc = Instance.new("UICorner")
	hpfc.CornerRadius = UDim.new(0, 5)
	hpfc.Parent = hpFill

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = GUARD_MAX_HP
	hum.Health = GUARD_MAX_HP
	hum.WalkSpeed = GUARD_SPEED
	hum.HipHeight = 2.6
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	hum.HealthChanged:Connect(function(hp: number)
		hpFill.Size = UDim2.fromScale(math.clamp(hp / math.max(1, hum.MaxHealth), 0, 1), 1)
	end)

	model.PrimaryPart = root
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("Faction", "Player_" .. tostring(owner.UserId))
	CollectionService:AddTag(model, "PlayerBodyguardUnit")
	CollectionService:AddTag(model, "AnimatedRaiderLimbs")
	model.Parent = guardFolder or Workspace

	return {
		Owner = owner,
		Index = index,
		Model = model,
		Humanoid = hum,
		Root = root,
		StatusLabel = lbl,
		LastAttackAt = 0,
	}
end

local function clearPlayerGuards(player: Player): ()
	local list = guardsByPlayer[player]
	if list then
		for _, g in ipairs(list) do
			if g.Model.Parent then g.Model:Destroy() end
		end
		guardsByPlayer[player] = nil
	end
end

function BodyguardService.SyncGuardsForPlayer(player: Player): ()
	if not BaseService.GetPlayerBaseSlot(player) then
		return
	end
	local targetCount = BodyguardService.GetGuardCount(player)
	local list = guardsByPlayer[player]
	if not list then
		list = {}
		guardsByPlayer[player] = list
	end

	for i = #list, 1, -1 do
		if not list[i].Model.Parent or list[i].Humanoid.Health <= 0 then
			table.remove(list, i)
		end
	end

	while #list < targetCount do
		local idx = #list + 1
		local sp = getOwnerAnchorPos(player, idx)
		local agent = buildBodyguardModel(player, idx, sp)
		agent.Humanoid.Died:Connect(function()
			task.delay(2.5, function()
				if agent.Model.Parent then agent.Model:Destroy() end
			end)
			task.delay(RESPAWN_DELAY, function()
				if isRunning and player.Parent then
					BodyguardService.SyncGuardsForPlayer(player)
				end
			end)
		end)
		table.insert(list, agent)
	end
end

function BodyguardService.TryHireBodyguard(player: Player): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza first!"
	end
	local count = BodyguardService.GetGuardCount(player)
	local cost = BodyguardService.GetNextCost(player)
	if not cost then
		return false, "Max Bodyguards hired (2/2)!"
	end
	if not PlayerDataService.SpendCoins(player, cost) then
		return false, string.format("Need %d Gold to hire Bodyguard #%d!", cost, count + 1)
	end

	PlayerDataService.SetBodyguardCount(player, count + 1)
	BodyguardService.SyncGuardsForPlayer(player)
	return true, string.format("🛡️ Hired Bodyguard #%d! Follows & protects you from Mafia & Rival Chefs!", count + 1)
end

local function hookPlayerDamageDefense(player: Player): ()
	local function attachChar(char: Model)
		if hpConns[player] then
			hpConns[player]:Disconnect()
			hpConns[player] = nil
		end
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and hum:IsA("Humanoid") then
			local lastHp = hum.Health
			hpConns[player] = hum.HealthChanged:Connect(function(newHp: number)
				if newHp < lastHp then
					-- Boss was hit! Trigger heightened Bodyguard defense for 10 seconds!
					playerUnderAttackUntil[player] = os.clock() + 10
				end
				lastHp = newHp
			end)
		end
	end

	if charConns[player] then
		charConns[player]:Disconnect()
	end
	charConns[player] = player.CharacterAdded:Connect(attachChar)
	if player.Character then
		task.spawn(attachChar, player.Character)
	end
end

local function findNearestHostileToPoint(anchor: Vector3, radius: number, ownerFaction: string?): (Humanoid?, BasePart?, Model?)
	local bestHum: Humanoid? = nil
	local bestRoot: BasePart? = nil
	local bestModel: Model? = nil
	local bestDist = radius

	for _, tagName in ipairs({ "MafiaUnit", "RivalAIUnit", "TurfGuardUnit" }) do
		for _, unit in ipairs(CollectionService:GetTagged(tagName)) do
			if unit:IsA("Model") then
				if tagName == "TurfGuardUnit" and ownerFaction and unit:GetAttribute("Faction") == ownerFaction then
					continue
				end
				local r = unit:FindFirstChild("HumanoidRootPart")
				local h = unit:FindFirstChildOfClass("Humanoid")
				if r and r:IsA("BasePart") and h and h.Health > 0 then
					local d = (r.Position - anchor).Magnitude
					if d < bestDist then
						bestDist = d
						bestHum = h
						bestRoot = r
						bestModel = unit
					end
				end
			end
		end
	end
	return bestHum, bestRoot, bestModel
end

local function stepGuard(agent: BodyguardAgent): ()
	if not agent.Model.Parent or agent.Humanoid.Health <= 0 then
		return
	end
	local owner = agent.Owner
	local char = owner.Character
	local ownerRoot = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not ownerRoot or not ownerRoot:IsA("BasePart") then
		return
	end

	local now = os.clock()
	local ownerPos = ownerRoot.Position
	local guardPos = agent.Root.Position

	-- If owner zoomed far away (e.g. Motorbike or Return Home), regroup smoothly beside them!
	if (ownerPos - guardPos).Magnitude > 115 then
		local snap = getOwnerAnchorPos(owner, agent.Index)
		agent.Model:PivotTo(CFrame.new(snap))
		return
	end

	-- 1. Priority Defense: Protect Boss (expanded 60-stud alert radius if Boss just took damage!)
	local ownerFaction = "Player_" .. tostring(owner.UserId)
	local alertRadius = if (playerUnderAttackUntil[owner] or 0) > now then 62 else PROTECT_RADIUS
	local targetHum, targetRoot, targetModel = findNearestHostileToPoint(ownerPos, alertRadius, ownerFaction)

	-- 2. Also defend your active Stealth Delivery Runner if nearby!
	if not targetHum then
		local runnerPos = DeliveryRunnerService.GetActiveRunnerPosition(owner)
		if runnerPos and (runnerPos - ownerPos).Magnitude < 120 then
			targetHum, targetRoot, targetModel = findNearestHostileToPoint(runnerPos, 40, ownerFaction)
		end
	end

	if targetHum and targetRoot and targetModel then
		agent.StatusLabel.Text = "🛡️ PROTECTING BOSS!"
		agent.StatusLabel.TextColor3 = Color3.fromRGB(255, 224, 96)
		local dist = (targetRoot.Position - guardPos).Magnitude
		if dist <= GUARD_ATTACK_RANGE then
			if (now - agent.LastAttackAt) >= GUARD_COOLDOWN then
				agent.LastAttackAt = now
				targetHum:TakeDamage(GUARD_DAMAGE)
				spawnGuardHitBurst(targetRoot.Position)
				BlackMarketService.BroadcastSFX("MeleeHit", targetRoot.Position)
				if targetHum.Health <= 0 then
					local isMafia = CollectionService:HasTag(targetModel, "MafiaUnit")
					local isBoss = targetModel:GetAttribute("IsMafiaBoss") == true
					local rewardGold = if isBoss then 220 elseif isMafia then 90 else 35
					local rewardRep = if isBoss then 45 elseif isMafia then 20 else 10
					PlayerDataService.AddRewards(owner, rewardGold, 25, rewardRep)
				end
			end
		end
		agent.Humanoid:MoveTo(targetRoot.Position)
		return
	end

	-- 3. Calm Escort Mode: Walk loyally alongside the Boss!
	agent.StatusLabel.Text = "🛡️ BODYGUARD #" .. tostring(agent.Index)
	agent.StatusLabel.TextColor3 = Color3.fromRGB(134, 242, 255)
	local escortPos = getOwnerAnchorPos(owner, agent.Index)
	if (escortPos - guardPos).Magnitude > 5.5 then
		agent.Humanoid:MoveTo(escortPos)
	end
end

function BodyguardService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local existing = Workspace:FindFirstChild("PlayerBodyguards")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		guardFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "PlayerBodyguards"
		f.Parent = Workspace
		guardFolder = f
	end

	unsubBase = BaseService.OnBaseAssigned(function(player)
		BodyguardService.SyncGuardsForPlayer(player)
	end)

	Players.PlayerAdded:Connect(hookPlayerDamageDefense)
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayerDamageDefense(p)
		BodyguardService.SyncGuardsForPlayer(p)
	end

	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		clearPlayerGuards(player)
		playerUnderAttackUntil[player] = nil
		if charConns[player] then charConns[player]:Disconnect(); charConns[player] = nil end
		if hpConns[player] then hpConns[player]:Disconnect(); hpConns[player] = nil end
	end)

	aiThread = task.spawn(function()
		while isRunning do
			task.wait(0.45)
			if not isRunning then
				break
			end
			for _, player in ipairs(Players:GetPlayers()) do
				if BodyguardService.GetGuardCount(player) > 0 then
					BodyguardService.SyncGuardsForPlayer(player)
				end
				local list = guardsByPlayer[player]
				if list then
					for _, g in ipairs(list) do
						stepGuard(g)
					end
				end
			end
		end
	end)

	print("[Food Empire] BodyguardService started (Loyal Player Bodyguard Protector NPCs active)!")
end

function BodyguardService.Stop(): ()
	isRunning = false
	if aiThread then task.cancel(aiThread); aiThread = nil end
	if unsubBase then unsubBase(); unsubBase = nil end
	if playerRemovingConn then playerRemovingConn:Disconnect(); playerRemovingConn = nil end
	for p in pairs(guardsByPlayer) do
		clearPlayerGuards(p)
	end
end

return BodyguardService
