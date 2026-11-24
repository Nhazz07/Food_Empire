--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local PlayerDataService = require("./PlayerDataService")
local WarehouseService = require("./WarehouseService")
local BlackMarketService = require("./BlackMarketService")

type RaidStage = number

local SyndicateRaidService = {}

local COMPOUND_POS = Vector3.new(-155, 1.35, 148)

local activeStage: RaidStage = 0
local activeRaider: Player? = nil
local raidCooldownUntil = 0
local activeUnits: { { Model: Model, Humanoid: Humanoid, Root: BasePart, IsBoss: boolean, Damage: number, LastShotAt: number } } = {}
local compoundModel: Model? = nil
local raidFolder: Folder? = nil
local statusLbl: TextLabel? = nil
local isRunning = false
local aiThread: thread? = nil

local function sendToast(msg: string, target: Player?): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		if target then ev:FireClient(target, msg) else ev:FireAllClients(msg) end
	end
end

local function updateSign(): ()
	if not statusLbl then return end
	if activeStage == 0 then
		statusLbl.Text = "THE CRIMSON DON'S PENTHOUSE COMPOUND  |  3-STAGE ENDGAME HEIST  [E]"
		statusLbl.TextColor3 = Color3.fromRGB(238, 196, 122)
	elseif activeStage == 1 then
		statusLbl.Text = "PENTHOUSE HEIST STAGE 1 / 3  |  BREACH OUTER ENFORCER PERIMETER"
		statusLbl.TextColor3 = Color3.fromRGB(238, 134, 114)
	elseif activeStage == 2 then
		statusLbl.Text = "PENTHOUSE HEIST STAGE 2 / 3  |  ELIMINATE VAULT REINFORCEMENTS"
		statusLbl.TextColor3 = Color3.fromRGB(238, 162, 92)
	else
		statusLbl.Text = "PENTHOUSE HEIST FINAL STAGE 3 / 3  |  DEFEAT ARMORED CRIMSON DON!"
		statusLbl.TextColor3 = Color3.fromRGB(246, 92, 98)
	end
end

local function clearUnits(): ()
	for _, u in ipairs(activeUnits) do
		if u.Model.Parent then u.Model:Destroy() end
	end
	table.clear(activeUnits)
end

local function spawnRaidEnemy(title: string, kind: "ApexWarlord" | "ApexAssassin", hp: number, dmg: number, scale: number, isBoss: boolean, pos: Vector3): ()
	local rig = MafiaVisualBuilder.BuildSyndicateSpecialistRig("PenthouseGuard_" .. title, kind, scale, CFrame.new(pos), false)
	local model = rig.Model
	local root = rig.Root
	local head = rig.Head

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 42)
	bb.StudsOffset = Vector3.new(0, 3.2 * scale, 0)
	bb.MaxDistance = 200
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = title
	lbl.TextSize = 10
	lbl.TextColor3 = if isBoss then Color3.fromRGB(242, 198, 112) else Color3.fromRGB(234, 128, 128)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.03, 0, 0, 23)
	hpBg.Size = UDim2.new(0.94, 0, 0, 14)
	hpBg.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
	hpBg.Parent = bb
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(162, 30, 38)
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = hp
	hum.Health = hp
	hum.WalkSpeed = if isBoss then 18 else 20
	hum.HipHeight = 2.42 * scale
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	hum.HealthChanged:Connect(function(newHp: number)
		hpFill.Size = UDim2.fromScale(math.clamp(newHp / math.max(1, hum.MaxHealth), 0, 1), 1)
	end)

	hum.Died:Connect(function()
		MafiaVisualBuilder.PlayDeathSequence(model, isBoss, function(impactPos: Vector3)
			BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
		end)
	end)

	model.PrimaryPart = root
	model:SetAttribute("MafiaTitle", title)
	model:SetAttribute("IsPenthouseRaidUnit", true)
	model:SetAttribute("BountyGold", if isBoss then 500 else 160)
	model:SetAttribute("BountyExp", if isBoss then 220 else 75)
	model:SetAttribute("BountyRep", if isBoss then 90 else 30)
	CollectionService:AddTag(model, "PenthouseBossUnit")
	CollectionService:AddTag(model, "AnimatedRaiderLimbs")
	model.Parent = raidFolder or Workspace

	table.insert(activeUnits, {
		Model = model,
		Humanoid = hum,
		Root = root,
		IsBoss = isBoss,
		Damage = dmg,
		LastShotAt = 0,
	})
end

local function spawnStageWave(stage: RaidStage): ()
	clearUnits()
	activeStage = stage
	updateSign()
	if stage == 1 then
		spawnRaidEnemy("PENTHOUSE PERIMETER GUARD", "ApexAssassin", 520, 20, 1.04, false, COMPOUND_POS + Vector3.new(-14, 4, 16))
		spawnRaidEnemy("PENTHOUSE PERIMETER GUARD", "ApexAssassin", 520, 20, 1.04, false, COMPOUND_POS + Vector3.new(14, 4, 16))
		spawnRaidEnemy("PENTHOUSE SECURITY CAPTAIN", "ApexWarlord", 740, 24, 1.10, false, COMPOUND_POS + Vector3.new(0, 4, 20))
	elseif stage == 2 then
		spawnRaidEnemy("VAULT HEAVY ENFORCER", "ApexWarlord", 680, 24, 1.08, false, COMPOUND_POS + Vector3.new(-16, 4, 10))
		spawnRaidEnemy("VAULT SHADOW ASSASSIN", "ApexAssassin", 640, 26, 1.04, false, COMPOUND_POS + Vector3.new(16, 4, 10))
		spawnRaidEnemy("BULLION VAULT WARDEN", "ApexWarlord", 920, 28, 1.14, false, COMPOUND_POS + Vector3.new(0, 4, 14))
	elseif stage == 3 then
		spawnRaidEnemy("DON'S ROYAL BODYGUARD", "ApexAssassin", 720, 26, 1.08, false, COMPOUND_POS + Vector3.new(-10, 4, 12))
		spawnRaidEnemy("THE CRIMSON DON [ARMORED]", "ApexWarlord", 1950, 34, 1.24, true, COMPOUND_POS + Vector3.new(0, 4, 15))
	end
end

local function buildPenthouseCompound(): ()
	local m = Instance.new("Model")
	m.Name = "CrimsonDonPenthouseCompound"
	local cf = CFrame.lookAt(COMPOUND_POS, Vector3.new(0, COMPOUND_POS.Y, 0))

	local function pPart(name: string, sz: Vector3, rel: CFrame, col: Color3, mat: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = cf * rel
		p.Color = col
		p.Material = mat
		p.Anchored = true
		p.CanCollide = true
		p.Parent = m
		return p
	end

	local obsidian = Color3.fromRGB(16, 17, 22)
	local brass = Color3.fromRGB(184, 146, 74)
	local crimson = Color3.fromRGB(132, 26, 34)

	local base = pPart("PenthousePlinth", Vector3.new(34, 1.6, 26), CFrame.new(0, 0.8, 0), Color3.fromRGB(28, 30, 36), Enum.Material.Marble)
	pPart("FortressTower", Vector3.new(28, 22, 18), CFrame.new(0, 12.6, -2), obsidian, Enum.Material.Marble)
	pPart("BrassCornice", Vector3.new(30, 1.0, 20), CFrame.new(0, 24.0, -2), brass, Enum.Material.Metal)
	pPart("PenthouseBanner", Vector3.new(12, 4.5, 0.5), CFrame.new(0, 16.5, 7.2), crimson, Enum.Material.Fabric)
	local vaultDoor = pPart("BullionVaultDoor", Vector3.new(8.5, 9.0, 0.8), CFrame.new(0, 6.2, 7.2), Color3.fromRGB(36, 38, 46), Enum.Material.Metal)

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(360, 46)
	bb.StudsOffset = Vector3.new(0, 26.5, 0)
	bb.MaxDistance = 300
	bb.Parent = base
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
	lbl.BackgroundTransparency = 0.06
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 11
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)
	local st = Instance.new("UIStroke")
	st.Color = crimson
	st.Thickness = 1.6
	st.Parent = lbl
	statusLbl = lbl
	updateSign()

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StartPenthouseHeistPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 20
	prompt.RequiresLineOfSight = false
	prompt.ActionText = "Launch 3-Stage Crimson Don Penthouse Heist (+1,200G)"
	prompt.ObjectText = "Syndicate Endgame Compound"
	prompt.Parent = vaultDoor

	prompt.Triggered:Connect(function(player: Player)
		local _, msg = SyndicateRaidService.StartHeist(player)
		sendToast(msg, player)
	end)

	m.PrimaryPart = base
	m.Parent = Workspace
	compoundModel = m
end

function SyndicateRaidService.StartHeist(player: Player): (boolean, string)
	local now = os.clock()
	if activeStage > 0 then
		local char = player.Character
		if char then
			local dest = COMPOUND_POS + Vector3.new(0, 4.5, 30)
			pcall(function() player:RequestStreamAroundAsync(dest) end)
			char:PivotTo(CFrame.lookAt(dest, COMPOUND_POS + Vector3.new(0, 4.5, 0)))
		end
		return true, string.format("Penthouse Heist Stage %d / 3 is LIVE! Warped to Syndicate Compound.", activeStage)
	end
	if raidCooldownUntil > now then
		return false, string.format("Crimson Don's Penthouse Compound is locked down (%ds cooldown)!", math.ceil(raidCooldownUntil - now))
	end
	activeRaider = player
	spawnStageWave(1)
	local char = player.Character
	if char then
		local dest = COMPOUND_POS + Vector3.new(0, 4.5, 32)
		pcall(function() player:RequestStreamAroundAsync(dest) end)
		char:PivotTo(CFrame.lookAt(dest, COMPOUND_POS + Vector3.new(0, 4.5, 0)))
	end
	sendToast("PENTHOUSE HEIST STAGE 1 / 3: Breach the Crimson Don's Outer Enforcer Perimeter!", nil)
	return true, "PENTHOUSE HEIST LAUNCHED! Stage 1 / 3: Eliminate the Perimeter Enforcers!"
end

function SyndicateRaidService.GetSnapshot(): { [string]: any }
	return {
		ActiveStage = activeStage,
		Cooldown = math.max(0, math.ceil(raidCooldownUntil - os.clock())),
	}
end

function SyndicateRaidService.Start(): ()
	if isRunning then return end
	isRunning = true

	local existing = Workspace:FindFirstChild("PenthouseRaidUnits")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		raidFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "PenthouseRaidUnits"
		f.Parent = Workspace
		raidFolder = f
	end

	local oldComp = Workspace:FindFirstChild("CrimsonDonPenthouseCompound")
	if oldComp then oldComp:Destroy() end
	buildPenthouseCompound()

	aiThread = task.spawn(function()
		while isRunning do
			task.wait(0.55)
			if not isRunning then break end
			if activeStage == 0 then continue end
			local now = os.clock()
			local alive = 0
			for _, u in ipairs(activeUnits) do
				if u.Model.Parent and u.Humanoid.Health > 0 then
					alive += 1
					-- Combat AI targeting players / bodyguards / mercenary mafia
					local myPos = u.Root.Position
					local bestH: Humanoid? = nil
					local bestR: BasePart? = nil
					local bestD = 88
					for _, p in ipairs(Players:GetPlayers()) do
						local ch = p.Character
						local r = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
						local h = if ch then ch:FindFirstChildOfClass("Humanoid") else nil
						if r and r:IsA("BasePart") and h and h.Health > 0 then
							local d = (r.Position - myPos).Magnitude
							if d < bestD then bestD = d; bestH = h; bestR = r end
						end
					end
					for _, tagName in ipairs({ "PlayerBodyguardUnit", "MercenaryMafiaUnit" }) do
						for _, unit in ipairs(CollectionService:GetTagged(tagName)) do
							if unit:IsA("Model") then
								local r = unit:FindFirstChild("HumanoidRootPart")
								local h = unit:FindFirstChildOfClass("Humanoid")
								if r and r:IsA("BasePart") and h and h.Health > 0 then
									local d = (r.Position - myPos).Magnitude
									if d < bestD then bestD = d; bestH = h; bestR = r end
								end
							end
						end
					end
					if bestH and bestR then
						if bestD > 20 then u.Humanoid:MoveTo(bestR.Position) end
						if bestD <= 75 and (now - u.LastShotAt) >= 0.90 then
							u.LastShotAt = now
							bestH:TakeDamage(u.Damage)
							BlackMarketService.SpawnBulletTracer(myPos + Vector3.new(0, 1.5, 0), bestR.Position, Color3.fromRGB(238, 62, 68))
							BlackMarketService.BroadcastSFX("SMGShot", myPos)
						end
					end
				end
			end

			if alive == 0 then
				if activeStage == 1 then
					sendToast("PENTHOUSE HEIST STAGE 2 / 3: Vault Alarm Triggered! Survive the Bullion Reinforcements!", nil)
					spawnStageWave(2)
				elseif activeStage == 2 then
					sendToast("PENTHOUSE HEIST FINAL STAGE 3 / 3: THE ARMORED CRIMSON DON HAS ENTERED!", nil)
					spawnStageWave(3)
				else
					-- Victory!
					activeStage = 0
					raidCooldownUntil = now + 90
					updateSign()
					local victor = activeRaider
					if victor and victor.Parent then
						PlayerDataService.AddRewards(victor, 1200, 420, 180)
						PlayerDataService.SetHasPenthouseTrophy(victor, true)
						if WarehouseService.IsUnlocked(victor, "Fish") then
							WarehouseService.AddIngredient(victor, "golden_tuna", 1)
							WarehouseService.AddIngredient(victor, "king_crab", 1)
						end
						sendToast(string.format("%s COMPLETED THE CRIMSON DON'S PENTHOUSE HEIST (+1,200G, +180 Rep, Rare Catches & Golden Trophy)!", victor.DisplayName), nil)
					end
				end
			end
		end
	end)

	print("[Food Empire] SyndicateRaidService started (3-Stage Crimson Don Penthouse Heist active)!")
end

function SyndicateRaidService.Stop(): ()
	isRunning = false
	if aiThread then task.cancel(aiThread); aiThread = nil end
	clearUnits()
end

return SyndicateRaidService
