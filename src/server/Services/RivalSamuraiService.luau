--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BlackMarketService = require("./BlackMarketService")
local CombatLockService = require("./CombatLockService")

type RivalBladeAgent = {
	SlotId: string,
	Style: "Samurai" | "Ninja",
	IsCaptain: boolean,
	AnchorPos: Vector3,
	PatrolOffset: Vector3,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Damage: number,
	Cooldown: number,
	LastAttackAt: number,
	ProvokedUntil: number,
	LastHealth: number,
}

local RivalSamuraiService = {}

-- 4 Rival Samurai Mafia & 4 Rival Ninja Assassin Mafia stationed in Central Park.
-- CENTRAL PARK PEACE TRUCE: They never attack visitors unless the player steals a Central Park shipment or attacks them!
-- Intentionally slightly weaker than Player's Hired Samurai (1550 HP / 134 DMG) & Hired Ninja (1350 HP / 124 DMG).
local SPAWN_SLOTS: { { Id: string, Style: "Samurai" | "Ninja", IsCaptain: boolean, Pos: Vector3 } } = {
	{ Id = "CPSamurai_1", Style = "Samurai", IsCaptain = false, Pos = Vector3.new(-68, 4.2, 66) },
	{ Id = "CPSamurai_2", Style = "Samurai", IsCaptain = false, Pos = Vector3.new(-82, 4.2, 66) },
	{ Id = "CPSamurai_3", Style = "Samurai", IsCaptain = false, Pos = Vector3.new(-68, 4.2, 82) },
	{ Id = "CPSamurai_Cap", Style = "Samurai", IsCaptain = true, Pos = Vector3.new(-82, 4.2, 82) },
	{ Id = "CPNinja_1", Style = "Ninja", IsCaptain = false, Pos = Vector3.new(-70, 4.2, -50) },
	{ Id = "CPNinja_2", Style = "Ninja", IsCaptain = false, Pos = Vector3.new(-84, 4.2, -50) },
	{ Id = "CPNinja_3", Style = "Ninja", IsCaptain = false, Pos = Vector3.new(-70, 4.2, -66) },
	{ Id = "CPNinja_Cap", Style = "Ninja", IsCaptain = true, Pos = Vector3.new(-84, 4.2, -66) },
}

local agentsById: { [string]: RivalBladeAgent } = {}
local respawnUntil: { [string]: number } = {}
local folder: Folder? = nil
local isRunning = false
local aiThread: thread? = nil

local function hasPlayerStolenShipment(player: Player): boolean
	local untilAttr = player:GetAttribute("StolenShipmentUntil")
	if typeof(untilAttr) == "number" and untilAttr > os.clock() then
		return true
	end
	return player:GetAttribute("CarryingCrate") ~= nil
end

local function alertCamp(style: "Samurai" | "Ninja", now: number): ()
	for _, other in pairs(agentsById) do
		if other.Style == style and other.Model.Parent and other.Humanoid.Health > 0 then
			other.ProvokedUntil = math.max(other.ProvokedUntil, now + 28)
			other.Model:SetAttribute("Provoked", true)
		end
	end
end

local function spawnSlot(slot: { Id: string, Style: "Samurai" | "Ninja", IsCaptain: boolean, Pos: Vector3 }): RivalBladeAgent
	local isSamurai = (slot.Style == "Samurai")
	local rigKind: "SamuraiMafia" | "NinjaMafia" = if isSamurai then "SamuraiMafia" else "NinjaMafia"
	local scale = if slot.IsCaptain then 1.12 else 1.02
	-- Intentionally slightly weaker than Player's Hired Samurai (1550 HP / 134 DMG) & Hired Ninja (1350 HP / 124 DMG)!
	local maxHP = if isSamurai
		then (if slot.IsCaptain then 1180 else 960)
		else (if slot.IsCaptain then 1040 else 860)
	local dmg = if isSamurai
		then (if slot.IsCaptain then 88 else 72)
		else (if slot.IsCaptain then 82 else 68)
	local cd = if isSamurai then 0.72 else 0.56
	local spd = if isSamurai then 20 else 24
	local title = if isSamurai
		then (if slot.IsCaptain then "RIVAL SAMURAI CAPTAIN" else "RIVAL SAMURAI MAFIA")
		else (if slot.IsCaptain then "RIVAL NINJA ASSASSIN BOSS" else "RIVAL NINJA ASSASSIN")

	local rig = MafiaVisualBuilder.BuildSyndicateSpecialistRig(slot.Id, rigKind, scale, CFrame.new(slot.Pos), false)
	local model = rig.Model
	local root = rig.Root
	local head = rig.Head

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(206, 40)
	bb.StudsOffset = Vector3.new(0, 3.15 * scale, 0)
	bb.MaxDistance = 165
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = title
	lbl.TextSize = 10
	lbl.TextColor3 = if isSamurai then Color3.fromRGB(224, 126, 128) else Color3.fromRGB(192, 188, 212)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(134, 30, 38)
	st.Thickness = 1.2
	st.Parent = lbl

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.03, 0, 0, 23)
	hpBg.Size = UDim2.new(0.94, 0, 0, 13)
	hpBg.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
	hpBg.Parent = bb
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(154, 30, 38)
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

	local hpTxt = Instance.new("TextLabel")
	hpTxt.Size = UDim2.fromScale(1, 1)
	hpTxt.BackgroundTransparency = 1
	hpTxt.Font = Enum.Font.GothamBold
	hpTxt.Text = string.format("%d / %d HP", maxHP, maxHP)
	hpTxt.TextSize = 9
	hpTxt.TextColor3 = Color3.fromRGB(238, 236, 232)
	hpTxt.ZIndex = 3
	hpTxt.Parent = hpBg

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = maxHP
	hum.Health = maxHP
	hum.WalkSpeed = spd
	hum.HipHeight = 2.42 * scale
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	local agent: RivalBladeAgent = {
		SlotId = slot.Id,
		Style = slot.Style,
		IsCaptain = slot.IsCaptain,
		AnchorPos = slot.Pos,
		PatrolOffset = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10)),
		Model = model,
		Humanoid = hum,
		Root = root,
		Damage = dmg,
		Cooldown = cd,
		LastAttackAt = 0,
		ProvokedUntil = 0,
		LastHealth = maxHP,
	}

	hum.HealthChanged:Connect(function(hp: number)
		local cur = math.max(0, math.ceil(hp))
		local maxH = math.max(1, math.ceil(hum.MaxHealth))
		hpFill.Size = UDim2.fromScale(math.clamp(hp / maxH, 0, 1), 1)
		hpTxt.Text = string.format("%d / %d HP", cur, maxH)
		if hp < agent.LastHealth and hp > 0 then
			local now = os.clock()
			agent.ProvokedUntil = math.max(agent.ProvokedUntil, now + 28)
			model:SetAttribute("Provoked", true)
			alertCamp(slot.Style, now)
		end
		agent.LastHealth = hp
	end)

	hum.Died:Connect(function()
		respawnUntil[slot.Id] = os.clock() + 34
		MafiaVisualBuilder.PlayDeathSequence(model, slot.IsCaptain, function(impactPos: Vector3)
			BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
		end)
	end)

	model.PrimaryPart = root
	model:SetAttribute("Faction", "RivalSamurai")
	model:SetAttribute("MafiaTitle", title)
	model:SetAttribute("BladeStyle", slot.Style)
	model:SetAttribute("Provoked", false)
	model:SetAttribute("BountyGold", if slot.IsCaptain then 280 else 180)
	model:SetAttribute("BountyExp", if slot.IsCaptain then 125 else 80)
	model:SetAttribute("BountyRep", if slot.IsCaptain then 55 else 35)
	CollectionService:AddTag(model, "RivalSamuraiUnit")
	CollectionService:AddTag(model, "AnimatedRaiderLimbs")
	model.Parent = folder or Workspace

	return agent
end

local function stepAgent(ag: RivalBladeAgent, now: number): ()
	if not ag.Model.Parent or ag.Humanoid.Health <= 0 then return end
	local isProvoked = (ag.ProvokedUntil > now)
	if not isProvoked and ag.Model:GetAttribute("Provoked") == true then
		ag.Model:SetAttribute("Provoked", false)
	end

	local myPos = ag.Root.Position
	local bestH: Humanoid? = nil
	local bestR: BasePart? = nil
	local bestM: Model? = nil
	local bestD = 76

	-- Priority 1: Clash head-to-head against Player's Hired Samurai/Ninja Mafia or Bodyguards ONLY if provoked or owner stole a Central Park shipment!
	for _, tagName in ipairs({ "MercenaryMafiaUnit", "PlayerBodyguardUnit" }) do
		for _, ally in ipairs(CollectionService:GetTagged(tagName)) do
			if ally:IsA("Model") then
				local ownerUid = ally:GetAttribute("OwnerUserId")
				local ownerPlayer = if typeof(ownerUid) == "number" then Players:GetPlayerByUserId(ownerUid) else nil
				local ownerStole = (ownerPlayer ~= nil and hasPlayerStolenShipment(ownerPlayer))
				if isProvoked or ownerStole then
					local r = ally:FindFirstChild("HumanoidRootPart")
					local h = ally:FindFirstChildOfClass("Humanoid")
					if r and r:IsA("BasePart") and h and h.Health > 0 then
						local d = (r.Position - myPos).Magnitude
						if d < bestD then
							bestD = d; bestH = h; bestR = r; bestM = ally
						end
					end
				end
			end
		end
	end

	-- Priority 2: CENTRAL PARK PEACE TRUCE — Never attack players who are just visiting Central Park!
	-- Only attack a player if they stole a Central Park shipment OR attacked the Central Park Samurai/Ninja Mafia!
	for _, p in ipairs(Players:GetPlayers()) do
		if isProvoked or hasPlayerStolenShipment(p) then
			local ch = p.Character
			local r = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
			local h = if ch then ch:FindFirstChildOfClass("Humanoid") else nil
			if r and r:IsA("BasePart") and h and h.Health > 0 then
				local smokeUntil = p:GetAttribute("InSmokeUntil")
				local maxSight = if typeof(smokeUntil) == "number" and smokeUntil > now then 15 else 54
				local d = (r.Position - myPos).Magnitude
				if d < math.min(bestD, maxSight) then
					bestD = d; bestH = h; bestR = r; bestM = ch
				end
			end
		end
	end

	if bestH and bestR and bestM then
		local stunUntil = ag.Model:GetAttribute("StunnedUntil")
		if typeof(stunUntil) == "number" and stunUntil > now then
			return
		end
		if bestD > 10 then
			ag.Humanoid:MoveTo(bestR.Position)
		end
		if bestD <= 14 and (now - ag.LastAttackAt) >= ag.Cooldown then
			local targetP = Players:GetPlayerFromCharacter(bestM)
			local dodgeUntil = if targetP then targetP:GetAttribute("ShadowDodgeUntil") else nil
			if typeof(dodgeUntil) == "number" and dodgeUntil > now then
				return
			end
			ag.LastAttackAt = now
			MafiaVisualBuilder.TriggerAttackAnim(ag.Model)
			if targetP then
				CombatLockService.MarkUnderAttack(targetP, myPos, ag.Style .. " Mafia")
			end
			bestH:TakeDamage(ag.Damage)
			local clashPoint = (myPos + bestR.Position) * 0.5 + Vector3.new(0, 1.5, 0)
			local targetStyle = tostring(bestM:GetAttribute("MercenaryType") or bestM:GetAttribute("BladeStyle") or "Samurai")
			BlackMarketService.SpawnBladeClashVFX(clashPoint, ag.Style, targetStyle)
			local slashCol = if ag.Style == "Samurai" then Color3.fromRGB(204, 48, 56) else Color3.fromRGB(168, 184, 214)
			BlackMarketService.SpawnBulletTracer(myPos + Vector3.new(0, 1.4, 0), bestR.Position, slashCol)
			BlackMarketService.BroadcastSFX("MeleeHit", clashPoint)
		end
	else
		local patrolPt = ag.AnchorPos + ag.PatrolOffset
		if (patrolPt - myPos).Magnitude > 6 then
			ag.Humanoid:MoveTo(patrolPt)
		elseif math.random() < 0.08 then
			ag.PatrolOffset = Vector3.new(math.random(-14, 14), 0, math.random(-14, 14))
		end
	end
end

function RivalSamuraiService.Start(): ()
	if isRunning then return end
	isRunning = true

	local existing = Workspace:FindFirstChild("CentralParkRivalSamurai")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		folder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "CentralParkRivalSamurai"
		f.Parent = Workspace
		folder = f
	end

	for _, slot in ipairs(SPAWN_SLOTS) do
		agentsById[slot.Id] = spawnSlot(slot)
	end

	aiThread = task.spawn(function()
		while isRunning do
			task.wait(0.42)
			if not isRunning then break end
			local now = os.clock()
			for _, slot in ipairs(SPAWN_SLOTS) do
				local ag = agentsById[slot.Id]
				if not ag or not ag.Model.Parent or ag.Humanoid.Health <= 0 then
					if (respawnUntil[slot.Id] or 0) <= now then
						agentsById[slot.Id] = spawnSlot(slot)
					end
				else
					stepAgent(ag, now)
				end
			end
		end
	end)

	print("[Food Empire] RivalSamuraiService started (Central Park Rival Samurai Mafia & Rival Ninja Mafia active)!")
end

function RivalSamuraiService.Stop(): ()
	isRunning = false
	if aiThread then task.cancel(aiThread); aiThread = nil end
	for _, ag in pairs(agentsById) do
		if ag.Model.Parent then ag.Model:Destroy() end
	end
	table.clear(agentsById)
end

return RivalSamuraiService
