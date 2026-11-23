--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local BlackMarketService = require("./BlackMarketService")

local CombatService = {}

local ATTACK_COOLDOWN = 0.45
local ATTACK_RANGE = 11.5
local ATTACK_DAMAGE = 35
local SAFE_ZONE_RADIUS = 118 -- Matches expanded 224x224 Castle Base walls

local RIVAL_KILL_COINS = 35
local RIVAL_KILL_EXP = 20
local RIVAL_KILL_REP = 10

local MAFIA_KILL_COINS = 90
local MAFIA_KILL_EXP = 35
local MAFIA_KILL_REP = 20

local BOSS_KILL_COINS = 220
local BOSS_KILL_EXP = 80
local BOSS_KILL_REP = 45

local PVP_KILL_COINS = 50
local PVP_KILL_EXP = 25
local PVP_KILL_REP = 15

local lastAttackTime: { [Player]: number } = {}
local isRunning = false
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local charConns: { [Player]: RBXScriptConnection } = {}

local function isInsideOwnBase(player: Player, pos: Vector3): boolean
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return false
	end
	local baseModel = BaseService.GetBaseModel(slot)
	if not baseModel or not baseModel.PrimaryPart then
		return false
	end
	local delta = pos - baseModel.PrimaryPart.Position
	return math.abs(delta.X) <= SAFE_ZONE_RADIUS and math.abs(delta.Z) <= SAFE_ZONE_RADIUS
end

local function spawnHitBurst(position: Vector3): ()
	local burstPart = Instance.new("Part")
	burstPart.Name = "HitBurst"
	burstPart.Size = Vector3.new(1, 1, 1)
	burstPart.CFrame = CFrame.new(position)
	burstPart.Transparency = 1
	burstPart.Anchored = true
	burstPart.CanCollide = false
	burstPart.CanTouch = false
	burstPart.CanQuery = false
	burstPart.Parent = workspace

	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 224, 82))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.25, 0.45)
	pe.Speed = NumberRange.new(10, 18)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = burstPart
	pe:Emit(14)

	task.delay(0.6, function()
		if burstPart.Parent then
			burstPart:Destroy()
		end
	end)
end

local function createGoldenSpatulaTool(owner: Player): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Golden Spatula"
	tool.ToolTip = "Swing to fight Rival Chefs & rival players over territories!"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(-15), 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 3.4, 0.45)
	handle.Color = Color3.fromRGB(132, 86, 54)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local blade = Instance.new("Part")
	blade.Name = "SpatulaBlade"
	blade.Size = Vector3.new(1.5, 1.8, 0.22)
	blade.CFrame = handle.CFrame * CFrame.new(0, 2.3, 0)
	blade.Color = Color3.fromRGB(248, 198, 56)
	blade.Material = Enum.Material.SmoothPlastic
	blade.CanCollide = false
	blade.Massless = true
	blade.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = blade
	weld.Parent = blade

	tool.Activated:Connect(function()
		local now = os.clock()
		if lastAttackTime[owner] and (now - lastAttackTime[owner]) < ATTACK_COOLDOWN then
			return
		end
		lastAttackTime[owner] = now

		local character = owner.Character
		if not character then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		local hum = character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then
			return
		end

		blade.Material = Enum.Material.Neon
		BlackMarketService.BroadcastSFX("MeleeSwing", root.Position)
		task.delay(0.14, function()
			if blade.Parent then
				blade.Material = Enum.Material.SmoothPlastic
			end
		end)

		-- 1. Hit nearby Rival AI Raiders
		for _, unit in ipairs(CollectionService:GetTagged("RivalAIUnit")) do
			if unit:IsA("Model") then
				local enemyHum = unit:FindFirstChildOfClass("Humanoid")
				local enemyRoot = unit:FindFirstChild("HumanoidRootPart")
				if enemyHum and enemyHum.Health > 0 and enemyRoot and enemyRoot:IsA("BasePart") then
					if (enemyRoot.Position - root.Position).Magnitude <= ATTACK_RANGE then
						enemyHum:TakeDamage(ATTACK_DAMAGE)
						spawnHitBurst(enemyRoot.Position)
						BlackMarketService.BroadcastSFX("MeleeHit", enemyRoot.Position)

						local pushDir = enemyRoot.Position - root.Position
						if pushDir.Magnitude > 0.01 then
							enemyRoot.AssemblyLinearVelocity = pushDir.Unit * 28 + Vector3.new(0, 12, 0)
						end

						if enemyHum.Health <= 0 then
							PlayerDataService.AddRewards(owner, RIVAL_KILL_COINS, RIVAL_KILL_EXP, RIVAL_KILL_REP)
						end
					end
				end
			end
		end

		-- 1.5. Hit nearby Food Mafia Enforcers & Mafia Capo Boss!
		for _, unit in ipairs(CollectionService:GetTagged("MafiaUnit")) do
			if unit:IsA("Model") then
				local enemyHum = unit:FindFirstChildOfClass("Humanoid")
				local enemyRoot = unit:FindFirstChild("HumanoidRootPart")
				if enemyHum and enemyHum.Health > 0 and enemyRoot and enemyRoot:IsA("BasePart") then
					if (enemyRoot.Position - root.Position).Magnitude <= ATTACK_RANGE + 1.5 then
						enemyHum:TakeDamage(ATTACK_DAMAGE)
						spawnHitBurst(enemyRoot.Position)
						BlackMarketService.BroadcastSFX("MeleeHit", enemyRoot.Position)

						local pushDir = enemyRoot.Position - root.Position
						if pushDir.Magnitude > 0.01 then
							enemyRoot.AssemblyLinearVelocity = pushDir.Unit * 26 + Vector3.new(0, 12, 0)
						end

						if enemyHum.Health <= 0 then
							local isBoss = unit:GetAttribute("IsMafiaBoss") == true
							if isBoss then
								PlayerDataService.AddRewards(owner, BOSS_KILL_COINS, BOSS_KILL_EXP, BOSS_KILL_REP)
							else
								PlayerDataService.AddRewards(owner, MAFIA_KILL_COINS, MAFIA_KILL_EXP, MAFIA_KILL_REP)
							end
						end
					end
				end
			end
		end

		-- 2. Territory PvP against other Players (Safe-Zone protected inside their own Castle Base)
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= owner and other.Character then
				local otherHum = other.Character:FindFirstChildOfClass("Humanoid")
				local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
				if otherHum and otherHum.Health > 0 and otherRoot and otherRoot:IsA("BasePart") then
					if (otherRoot.Position - root.Position).Magnitude <= ATTACK_RANGE then
						if not isInsideOwnBase(other, otherRoot.Position) and not isInsideOwnBase(owner, root.Position) then
							otherHum:TakeDamage(ATTACK_DAMAGE)
							spawnHitBurst(otherRoot.Position)

							local pushDir = otherRoot.Position - root.Position
							if pushDir.Magnitude > 0.01 then
								otherRoot.AssemblyLinearVelocity = pushDir.Unit * 24 + Vector3.new(0, 10, 0)
							end

							if otherHum.Health <= 0 then
								PlayerDataService.AddRewards(owner, PVP_KILL_COINS, PVP_KILL_EXP, PVP_KILL_REP)
							end
						end
					end
				end
			end
		end
	end)

	return tool
end

local function giveSpatula(player: Player): ()
	local backpack = player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	if backpack:FindFirstChild("Golden Spatula") then
		return
	end
	if player.Character and player.Character:FindFirstChild("Golden Spatula") then
		return
	end
	local tool = createGoldenSpatulaTool(player)
	tool.Parent = backpack
end

local function hookPlayer(player: Player): ()
	if charConns[player] then
		charConns[player]:Disconnect()
	end
	charConns[player] = player.CharacterAdded:Connect(function()
		task.defer(function()
			if player.Parent then
				giveSpatula(player)
			end
		end)
	end)
	if player.Character then
		giveSpatula(player)
	end
end

function CombatService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	playerAddedConn = Players.PlayerAdded:Connect(hookPlayer)
	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		lastAttackTime[player] = nil
		if charConns[player] then
			charConns[player]:Disconnect()
			charConns[player] = nil
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
	end

	print("[Food Empire] CombatService started (Golden Spatula PvE + Safe-Zone PvP combat live)!")
end

function CombatService.Stop(): ()
	isRunning = false
	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for player, conn in pairs(charConns) do
		conn:Disconnect()
		charConns[player] = nil
	end
end

return CombatService
