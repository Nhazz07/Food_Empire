--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TurfConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("TurfConfig")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local BlackMarketService = require("./BlackMarketService")
local MonetizationService = require("./MonetizationService")

export type BlockStatus = "Controlled" | "Contested" | "Capturing"

export type TurfBlockState = {
	Id: string,
	Spec: TurfConfig.TurfBlockSpec,
	Owner: string,
	Status: BlockStatus,
	CapturingFaction: string?,
	CaptureProgress: number,
	UnderAttackUntil: number,
	AttackerName: string?,
	DefendersAlive: number,
}

type TurfAgent = {
	Kind: "Mafia" | "PlayerGuard" | "MafiaRaider",
	FactionId: string,
	HomeBlockId: string,
	TargetBlockId: string,
	IsBoss: boolean,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	PatrolPoints: { Vector3 },
	PatrolIndex: number,
	LastAttackAt: number,
	AlertedUntil: number,
	OwnerUserId: number?,
}

type ActiveRaid = {
	TargetBlockId: string,
	MafiaFactionId: string,
	OwnerPlayer: Player?,
	Raiders: { TurfAgent },
	StartedAt: number,
}

export type TurfChangedCallback = () -> ()

local TurfService = {}

local CAPTURE_TICK = 0.25
local AI_TICK = 0.75
local INCOME_INTERVAL = 20
local RAID_INTERVAL = 56
local GARRISON_RESPAWN_DELAY = 30
local EXTRA_UNIT_SPEED_BONUS = 0.25
local DECAY_PER_SECOND = 0.18
local VAULT_COOLDOWN = 45
local KIOSK_COOLDOWN = 20

local isRunning = false
local blockStates: { [string]: TurfBlockState } = {}
local blockColorParts: { [string]: { BasePart } } = {}
local blockBillboards: { [string]: BillboardGui } = {}
local blockZones: { [string]: BasePart } = {}

local npcFolder: Folder? = nil
local activeAgents: { TurfAgent } = {}
local activeRaids: { ActiveRaid } = {}
local lastGuardDiedAt: { [string]: number } = {}
local vaultCooldowns: { [string]: number } = {} -- key: userId .. "_" .. blockId
local kioskCooldowns: { [number]: number } = {}

local listeners: { TurfChangedCallback } = {}
local conns: { RBXScriptConnection } = {}
local captureThread: thread? = nil
local aiThread: thread? = nil
local economyThread: thread? = nil
local unsubBase: (() -> ())? = nil
local lastBroadcastAt = 0

local function sendToast(player: Player, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

local function broadcastToast(msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireAllClients(msg)
	end
end

local function notifyChanged(force: boolean?): ()
	local now = os.clock()
	if not force and (now - lastBroadcastAt) < 0.35 then
		return
	end
	lastBroadcastAt = now
	for _, cb in ipairs(listeners) do
		task.spawn(cb)
	end
end

function TurfService.OnTurfChanged(cb: TurfChangedCallback): () -> ()
	table.insert(listeners, cb)
	return function()
		local idx = table.find(listeners, cb)
		if idx then
			table.remove(listeners, idx)
		end
	end
end

local function getPlayerFromFaction(factionId: string): Player?
	local uidStr = string.match(factionId, "^Player_(%d+)$")
	if not uidStr then
		return nil
	end
	return Players:GetPlayerByUserId(tonumber(uidStr) or 0)
end

local function spawnCaptureBurst(pos: Vector3, color: Color3): ()
	local p = Instance.new("Part")
	p.Name = "TurfCaptureBurst"
	p.Size = Vector3.new(2, 2, 2)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0))
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Parent = Workspace

	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.7, 1.3)
	pe.Speed = NumberRange.new(18, 34)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = p
	pe:Emit(36)

	task.delay(1.8, function()
		if p.Parent then
			p:Destroy()
		end
	end)
end

-- Automatically syncs all 3D turf borders, beacons, flag banners, skyline trims & billboards to controlling faction's Base Color!
local function syncBlockVisuals(blockId: string): ()
	local st = blockStates[blockId]
	if not st then
		return
	end

	local ownerColor = TurfConfig.ResolveFactionColor(st.Owner)
	local visualColor = if st.Status == "Contested" then TurfConfig.ContestedColor else ownerColor

	local parts = blockColorParts[blockId]
	if parts then
		for _, part in ipairs(parts) do
			if part.Parent then
				part.Color = visualColor
				local pl = part:FindFirstChildOfClass("PointLight")
				if pl then
					pl.Color = visualColor
				end
			end
		end
	end

	local bb = blockBillboards[blockId]
	if bb and bb.Parent then
		local ownerLbl = bb:FindFirstChild("OwnerLabel")
		if ownerLbl and ownerLbl:IsA("TextLabel") then
			local ownerName = TurfConfig.GetFactionDisplayName(st.Owner)
			if st.Status == "Contested" then
				ownerLbl.Text = "⚔️ CONTESTED!"
				ownerLbl.BackgroundColor3 = TurfConfig.ContestedColor
			elseif TurfConfig.IsMafiaFaction(st.Owner) then
				ownerLbl.Text = ownerName .. " TURF"
				ownerLbl.BackgroundColor3 = ownerColor
			else
				ownerLbl.Text = "OWNED BY " .. ownerName
				ownerLbl.BackgroundColor3 = ownerColor
			end
		end

		local pBg = bb:FindFirstChild("ProgressBar")
		if pBg then
			local fill = pBg:FindFirstChild("ProgressFill")
			if fill and fill:IsA("Frame") then
				fill.Size = UDim2.fromScale(math.clamp(st.CaptureProgress, 0, 1), 1)
				fill.BackgroundColor3 = if st.CapturingFaction
					then TurfConfig.ResolveFactionColor(st.CapturingFaction)
					else ownerColor
			end
			local statusLbl = pBg:FindFirstChild("StatusLabel")
			if statusLbl and statusLbl:IsA("TextLabel") then
				if st.Status == "Contested" then
					statusLbl.Text = "⚔️ CLEAR ENEMIES IN PLAZA!"
				elseif st.CaptureProgress > 0.01 and st.CapturingFaction then
					local capName = TurfConfig.GetFactionDisplayName(st.CapturingFaction)
					statusLbl.Text = string.format("%s CAPTURING %d%%", capName, math.floor(st.CaptureProgress * 100))
				elseif TurfConfig.IsMafiaFaction(st.Owner) then
					if st.DefendersAlive > 0 then
						statusLbl.Text = string.format("🕶️ %d MAFIA GUARD%s • FIGHT!", st.DefendersAlive, if st.DefendersAlive == 1 then "" else "S")
					else
						statusLbl.Text = "⚡ GUARDS CLEARED • STAND TO CAPTURE!"
					end
				else
					statusLbl.Text = string.format("🛡️ +%dG/20s • %d GUARD%s", st.Spec.IncomeGold, st.DefendersAlive, if st.DefendersAlive == 1 then "" else "S")
				end
			end
		end
	end
end

local function configureLightweightHumanoid(hum: Humanoid): ()
	hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
end

-- Build a Faction-Colored Mafia Enforcer / Capo OR a Player-Base-Colored Turf Guard!
local function buildTurfAgentModel(
	kind: "Mafia" | "PlayerGuard" | "MafiaRaider",
	factionId: string,
	homeBlockId: string,
	targetBlockId: string,
	spawnPos: Vector3,
	isBoss: boolean,
	patrolPoints: { Vector3 }
): TurfAgent
	local isMafia = (kind ~= "PlayerGuard")
	local scale = if isBoss then 1.18 elseif kind == "MafiaRaider" then 1.04 else 0.96
	local factionCol = TurfConfig.ResolveFactionColor(factionId)
	local mafiaSpec = TurfConfig.MafiaFactions[factionId]

	local suitCol = if isMafia and mafiaSpec then mafiaSpec.SuitColor else Color3.fromRGB(32, 38, 52)
	local trimCol = if isMafia and mafiaSpec then mafiaSpec.BaseColor else factionCol
	local badgeCol = if isMafia and mafiaSpec then mafiaSpec.BaseColor else factionCol
	local skinCol = Color3.fromRGB(240, 202, 170)

	local model = Instance.new("Model")
	local shortTag = if isMafia then (if isBoss then "MafiaCapo" else "MafiaGuard") else "PlayerTurfGuard"
	model.Name = string.format("%s_%s", shortTag, homeBlockId)

	local function makePart(name: string, sz: Vector3, col: Color3, mat: Enum.Material, shape: Enum.PartType?, collide: boolean): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz * scale
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
		p1.CFrame = p0.CFrame * CFrame.new(rel.Position * scale) * rel.Rotation
		local w = Instance.new("WeldConstraint")
		w.Part0 = p0
		w.Part1 = p1
		w.Parent = p1
	end

	local function makeJoint(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame): ()
		local sc0 = CFrame.new(c0.Position * scale) * c0.Rotation
		local sc1 = CFrame.new(c1.Position * scale) * c1.Rotation
		p1.CFrame = p0.CFrame * sc0 * sc1:Inverse()
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = sc0
		m.C1 = sc1
		m.Parent = p0
	end

	-- 1. Torso
	local rootCol = if isMafia then suitCol else trimCol
	local root = makePart("HumanoidRootPart", Vector3.new(2.4, 2.75, 1.35), rootCol, Enum.Material.SmoothPlastic, nil, true)
	root.CFrame = CFrame.new(spawnPos)

	if isMafia then
		local shirt = makePart("DressShirt", Vector3.new(0.95, 2.1, 0.22), Color3.fromRGB(246, 246, 250), Enum.Material.SmoothPlastic, nil, false)
		weldTo(root, shirt, CFrame.new(0, 0.2, -0.65))
		local tie = makePart("FactionTie", Vector3.new(0.42, 1.85, 0.28), trimCol, Enum.Material.SmoothPlastic, nil, false)
		weldTo(root, tie, CFrame.new(0, 0.1, -0.72))
	else
		local vest = makePart("GuardVest", Vector3.new(2.5, 1.65, 1.48), Color3.fromRGB(30, 34, 46), Enum.Material.Metal, nil, false)
		weldTo(root, vest, CFrame.new(0, 0.05, 0))
		local emblem = makePart("FactionEmblem", Vector3.new(0.85, 0.85, 0.2), trimCol, Enum.Material.Neon, nil, false)
		weldTo(vest, emblem, CFrame.new(0, 0.25, -0.78))
	end

	-- 2. Head + Shades + Hat (Fedora for Mafia / Team Beret for Player Turf Guard)
	local head = makePart("Head", Vector3.new(1.9, 1.9, 1.9), skinCol, Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	weldTo(root, head, CFrame.new(0, 2.3, 0))

	local shades = makePart("Sunglasses", Vector3.new(1.48, 0.38, 0.32), Color3.fromRGB(16, 18, 24), Enum.Material.Glass, nil, false)
	weldTo(head, shades, CFrame.new(0, 0.14, -0.85))

	if isMafia then
		local brim = makePart("FedoraBrim", Vector3.new(0.3, 3.0, 3.0), suitCol, Enum.Material.Fabric, Enum.PartType.Cylinder, false)
		weldTo(head, brim, CFrame.new(0, 0.88, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local crown = makePart("FedoraCrown", Vector3.new(1.1, 1.95, 1.95), suitCol, Enum.Material.Fabric, Enum.PartType.Cylinder, false)
		weldTo(head, crown, CFrame.new(0, 1.42, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local band = makePart("FedoraBand", Vector3.new(0.32, 2.08, 2.08), trimCol, Enum.Material.Neon, Enum.PartType.Cylinder, false)
		weldTo(head, band, CFrame.new(0, 1.08, 0) * CFrame.Angles(0, 0, math.rad(90)))
	else
		local cap = makePart("GuardBeret", Vector3.new(2.1, 0.85, 2.1), trimCol, Enum.Material.Fabric, Enum.PartType.Ball, false)
		weldTo(head, cap, CFrame.new(0.1, 0.85, 0))
	end

	-- 3. Articulated Arms + Weapon
	local leftArm = makePart("LeftArm", Vector3.new(0.9, 2.35, 0.9), rootCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("LeftArmJoint", root, leftArm, CFrame.new(-1.7, 1.0, 0), CFrame.new(0, 1.0, 0))
	local rightArm = makePart("RightArm", Vector3.new(0.9, 2.35, 0.9), rootCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("RightArmJoint", root, rightArm, CFrame.new(1.7, 1.0, 0), CFrame.new(0, 1.0, 0))

	local gun = makePart(
		"TurfWeapon",
		Vector3.new(0.34, 0.36, 2.2),
		if isBoss then Color3.fromRGB(246, 198, 52) else Color3.fromRGB(58, 64, 78),
		Enum.Material.Metal,
		nil,
		false
	)
	weldTo(rightArm, gun, CFrame.new(0, -1.25, -1.15))

	-- 4. Articulated Legs
	local pantsCol = if isMafia then suitCol else Color3.fromRGB(38, 44, 58)
	local leftLeg = makePart("LeftLeg", Vector3.new(0.98, 2.4, 0.98), pantsCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("LeftLegJoint", root, leftLeg, CFrame.new(-0.58, -1.35, 0), CFrame.new(0, 1.2, 0))
	local rightLeg = makePart("RightLeg", Vector3.new(0.98, 2.4, 0.98), pantsCol, Enum.Material.SmoothPlastic, nil, false)
	makeJoint("RightLegJoint", root, rightLeg, CFrame.new(0.58, -1.35, 0), CFrame.new(0, 1.2, 0))

	-- 5. Overhead Nameplate & Live HP Bar
	local maxHp = if isBoss then 280 elseif kind == "MafiaRaider" then 155 elseif isMafia then 135 else 155

	local bb = Instance.new("BillboardGui")
	bb.Name = "TurfAgentTag"
	bb.Size = UDim2.fromOffset(if isBoss then 196 else 168, 44)
	bb.StudsOffset = Vector3.new(0, 4.0 * scale, 0)
	bb.MaxDistance = 135
	bb.Parent = head

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 22)
	title.BackgroundColor3 = badgeCol
	title.BackgroundTransparency = 0.06
	title.Font = Enum.Font.GothamBlack
	title.TextSize = if isBoss then 12 else 11
	title.TextColor3 = Color3.new(1, 1, 1)
	if isMafia and mafiaSpec then
		if isBoss then
			title.Text = "👑 " .. mafiaSpec.ShortName .. " CAPO"
		elseif kind == "MafiaRaider" then
			title.Text = "🔥 " .. mafiaSpec.ShortName .. " RAIDER"
		else
			title.Text = "🕶️ " .. mafiaSpec.ShortName
		end
	else
		title.Text = "🛡️ " .. TurfConfig.GetFactionDisplayName(factionId) .. " GUARD"
	end
	title.Parent = bb
	local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 6); tc.Parent = title
	local ts = Instance.new("UIStroke"); ts.Color = Color3.fromRGB(16, 18, 26); ts.Thickness = 1.4; ts.Parent = title

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBarBg"
	hpBg.Position = UDim2.new(0.05, 0, 0, 26)
	hpBg.Size = UDim2.new(0.90, 0, 0, 14)
	hpBg.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	hpBg.Parent = bb
	local hpc = Instance.new("UICorner"); hpc.CornerRadius = UDim.new(0, 5); hpc.Parent = hpBg

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = if isMafia then Color3.fromRGB(238, 62, 72) else Color3.fromRGB(64, 214, 114)
	hpFill.Parent = hpBg
	local hpfc = Instance.new("UICorner"); hpfc.CornerRadius = UDim.new(0, 5); hpfc.Parent = hpFill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBlack
	hpText.Text = string.format("❤️ %d / %d", maxHp, maxHp)
	hpText.TextSize = 10
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.ZIndex = 3
	hpText.Parent = hpBg

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = maxHp
	hum.Health = maxHp
	hum.WalkSpeed = if isBoss then 15.5 elseif kind == "MafiaRaider" then 18.5 else 16.0
	hum.HipHeight = 2.55 * scale
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	configureLightweightHumanoid(hum)
	hum.Parent = model

	hum.HealthChanged:Connect(function(hp: number)
		local cur = math.max(0, math.ceil(hp))
		local maxH = math.max(1, math.ceil(hum.MaxHealth))
		hpFill.Size = UDim2.fromScale(math.clamp(hp / maxH, 0, 1), 1)
		hpText.Text = string.format("❤️ %d / %d", cur, maxH)
	end)

	local ownerUidStr = string.match(factionId, "^Player_(%d+)$")
	local ownerUid = if ownerUidStr then tonumber(ownerUidStr) else nil

	model.PrimaryPart = root
	model:SetAttribute("Faction", factionId)
	model:SetAttribute("BlockId", homeBlockId)
	model:SetAttribute("IsMafiaBoss", isBoss)
	model:SetAttribute("IsTurfUnit", true)
	if ownerUid then
		model:SetAttribute("OwnerUserId", ownerUid)
	end

	if isMafia then
		CollectionService:AddTag(model, "MafiaUnit")
	else
		CollectionService:AddTag(model, "TurfGuardUnit")
		CollectionService:AddTag(model, "AnimatedRaiderLimbs")
	end

	model.Parent = npcFolder or Workspace

	return {
		Kind = kind,
		FactionId = factionId,
		HomeBlockId = homeBlockId,
		TargetBlockId = targetBlockId,
		IsBoss = isBoss,
		Model = model,
		Humanoid = hum,
		Root = root,
		PatrolPoints = patrolPoints,
		PatrolIndex = math.random(1, math.max(1, #patrolPoints)),
		LastAttackAt = 0,
		AlertedUntil = 0,
		OwnerUserId = ownerUid,
	}
end

local function clearBlockGarrison(blockId: string, factionFilter: string?): ()
	for i = #activeAgents, 1, -1 do
		local a = activeAgents[i]
		if a.HomeBlockId == blockId and a.Kind ~= "MafiaRaider" then
			if not factionFilter or a.FactionId == factionFilter then
				if a.Model.Parent then
					a.Model:Destroy()
				end
				table.remove(activeAgents, i)
			end
		end
	end
end

local function countLivingDefendersForBlock(blockId: string, ownerFaction: string): number
	local n = 0
	for _, a in ipairs(activeAgents) do
		if a.HomeBlockId == blockId and a.FactionId == ownerFaction and a.Model.Parent and a.Humanoid.Health > 0 then
			n += 1
		end
	end
	return n
end

local function populateBlockGarrison(blockId: string): ()
	local st = blockStates[blockId]
	if not st then
		return
	end
	local spec = st.Spec
	local pts = spec.PatrolPoints
	local isMafia = TurfConfig.IsMafiaFaction(st.Owner)

	local existingNormal = 0
	local existingBoss = false
	for _, a in ipairs(activeAgents) do
		if a.HomeBlockId == blockId and a.FactionId == st.Owner and a.Kind ~= "MafiaRaider" and a.Model.Parent and a.Humanoid.Health > 0 then
			if a.IsBoss then
				existingBoss = true
			else
				existingNormal += 1
			end
		end
	end

	local targetNormal = 2
	local kind: "Mafia" | "PlayerGuard" = if isMafia then "Mafia" else "PlayerGuard"

	while existingNormal < targetNormal do
		existingNormal += 1
		local sp = pts[((existingNormal - 1) % #pts) + 1] + Vector3.new(math.random(-4, 4), 1.5, math.random(-4, 4))
		table.insert(activeAgents, buildTurfAgentModel(kind, st.Owner, blockId, blockId, sp, false, pts))
	end

	if isMafia and spec.IsHQ and not existingBoss then
		local bossPos = spec.PlazaPos + Vector3.new(0, 3.5, 6)
		table.insert(activeAgents, buildTurfAgentModel("Mafia", st.Owner, blockId, blockId, bossPos, true, pts))
	end

	st.DefendersAlive = countLivingDefendersForBlock(blockId, st.Owner)
end

local function isInsideSafePlayerBase(pos: Vector3): boolean
	for _, base in ipairs(CollectionService:GetTagged("PlayerBase")) do
		if base:IsA("Model") and base:IsDescendantOf(Workspace) then
			local piv = base:GetPivot().Position
			if math.abs(pos.X - piv.X) <= 112 and math.abs(pos.Z - piv.Z) <= 112 then
				return true
			end
		end
	end
	return false
end

local function findBestEnemyTarget(agent: TurfAgent): (Humanoid?, BasePart?, number)
	local myPos = agent.Root.Position
	local myFaction = agent.FactionId
	local isMafia = (agent.Kind ~= "PlayerGuard")
	local isNight = ReplicatedStorage:GetAttribute("IsNight") == true
	local maxRange = if agent.Kind == "MafiaRaider" then 72 elseif isNight and isMafia then 64 else 54

	local bestHum: Humanoid? = nil
	local bestRoot: BasePart? = nil
	local bestDist = maxRange

	local function considerModel(model: Model, targetFaction: string?): ()
		if targetFaction == myFaction then
			return
		end
		local r = model:FindFirstChild("HumanoidRootPart")
		local h = model:FindFirstChildOfClass("Humanoid")
		if not r or not r:IsA("BasePart") or not h or h.Health <= 0 then
			return
		end
		if isInsideSafePlayerBase(r.Position) then
			return
		end
		local d = (r.Position - myPos).Magnitude
		if d < bestDist then
			bestDist = d
			bestHum = h
			bestRoot = r
		end
	end

	-- 1. Players (hostile if different faction!)
	for _, player in ipairs(Players:GetPlayers()) do
		local pFaction = "Player_" .. tostring(player.UserId)
		if pFaction ~= myFaction and player.Character then
			if BaseService.GetPlayerBaseSlot(player) or player:GetAttribute("BaseSlot") ~= nil then
				considerModel(player.Character, pFaction)
			end
		end
	end

	-- 2. Enemy Turf Guards, Raider Chefs & Bodyguards
	for _, tagName in ipairs({ "TurfGuardUnit", "PlayerRaiderUnit", "PlayerBodyguardUnit" }) do
		for _, unit in ipairs(CollectionService:GetTagged(tagName)) do
			if unit:IsA("Model") then
				local fAttr = unit:GetAttribute("Faction")
				if typeof(fAttr) == "string" and fAttr ~= myFaction then
					considerModel(unit, fAttr)
				end
			end
		end
	end

	-- 3. Player Turf Guards also fight all Mafia & Rival AI units!
	if not isMafia then
		for _, tagName in ipairs({ "MafiaUnit", "RivalAIUnit" }) do
			for _, unit in ipairs(CollectionService:GetTagged(tagName)) do
				if unit:IsA("Model") then
					local fAttr = unit:GetAttribute("Faction")
					considerModel(unit, if typeof(fAttr) == "string" then fAttr else "Mafia")
				end
			end
		end
	end

	return bestHum, bestRoot, bestDist
end

local function stepAgentAI(agent: TurfAgent, now: number): ()
	if not agent.Model.Parent or agent.Humanoid.Health <= 0 then
		return
	end

	local homeState = blockStates[agent.TargetBlockId]
	local homePlaza = if homeState then homeState.Spec.PlazaPos else agent.Root.Position
	local distFromHome = (agent.Root.Position - homePlaza).Magnitude

	-- Leash garrison defenders back to their territory block so they don't wander across the whole island!
	if agent.Kind ~= "MafiaRaider" and distFromHome > 95 then
		agent.Humanoid:MoveTo(homePlaza + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)))
		return
	end

	local enemyHum, enemyRoot, enemyDist = findBestEnemyTarget(agent)
	if enemyHum and enemyRoot then
		local meleeRange = 11.5
		local shootRange = if agent.IsBoss then 60 else 50
		local cd = if agent.IsBoss then 1.05 elseif agent.Kind == "PlayerGuard" then 1.15 else 1.45

		if enemyDist <= meleeRange and (now - agent.LastAttackAt) >= 1.1 then
			agent.LastAttackAt = now
			enemyHum:TakeDamage(if agent.IsBoss then 22 else 14)
			BlackMarketService.BroadcastSFX("MeleeHit", enemyRoot.Position)
		elseif enemyDist > meleeRange and enemyDist <= shootRange and (now - agent.LastAttackAt) >= cd then
			agent.LastAttackAt = now
			local fromPos = agent.Root.Position + Vector3.new(0, 1.4, 0)
			local tracerCol = TurfConfig.ResolveFactionColor(agent.FactionId)
			BlackMarketService.SpawnBulletTracer(fromPos, enemyRoot.Position, tracerCol)
			BlackMarketService.BroadcastSFX(if agent.IsBoss then "SMGShot" else "EnemyShot", fromPos)
			if math.random() < 0.68 then
				enemyHum:TakeDamage(if agent.IsBoss then 15 else 10)
				BlackMarketService.BroadcastSFX("MeleeHit", enemyRoot.Position)
			end
		end

		-- Strafe / close toward enemy while staying inside territory combat zone
		if enemyDist > 18 then
			agent.Humanoid:MoveTo(enemyRoot.Position)
		else
			agent.Humanoid:MoveTo(agent.Root.Position)
		end
		return
	end

	-- Mafia Raiders march relentlessly into their target block's Capture Plaza!
	if agent.Kind == "MafiaRaider" and homeState then
		local targetDest = homeState.Spec.PlazaPos + Vector3.new(math.random(-8, 8), 2, math.random(-8, 8))
		if (agent.Root.Position - targetDest).Magnitude > 12 then
			agent.Humanoid:MoveTo(targetDest)
		end
		return
	end

	-- If home block is being captured or contested, rally straight to the Capture Plaza!
	if homeState and (homeState.Status == "Contested" or homeState.CaptureProgress > 0.05) then
		if distFromHome > 14 then
			agent.Humanoid:MoveTo(homePlaza + Vector3.new(math.random(-6, 6), 2, math.random(-6, 6)))
		end
		return
	end

	-- Calm Sidewalk & Plaza Patrol
	local pts = agent.PatrolPoints
	if #pts > 0 then
		local dest = pts[agent.PatrolIndex]
		if (agent.Root.Position - dest).Magnitude <= 9 then
			agent.PatrolIndex = (agent.PatrolIndex % #pts) + 1
			dest = pts[agent.PatrolIndex]
		end
		agent.Humanoid:MoveTo(dest)
	end
end

local function transferBlockOwnership(blockId: string, newOwner: string): ()
	local st = blockStates[blockId]
	if not st or st.Owner == newOwner then
		return
	end

	local oldOwner = st.Owner
	st.Owner = newOwner
	st.Status = "Controlled"
	st.CaptureProgress = 0
	st.CapturingFaction = nil
	st.UnderAttackUntil = 0
	st.AttackerName = nil

	-- Replace old garrison with new owner's garrison!
	clearBlockGarrison(blockId, oldOwner)
	populateBlockGarrison(blockId)

	-- Clean up any finished Mafia Raid targeting this block
	for i = #activeRaids, 1, -1 do
		local raid = activeRaids[i]
		if raid.TargetBlockId == blockId then
			for _, r in ipairs(raid.Raiders) do
				if r.Model.Parent then
					r.Model:Destroy()
				end
			end
			table.remove(activeRaids, i)
		end
	end

	local newColor = TurfConfig.ResolveFactionColor(newOwner)
	local newName = TurfConfig.GetFactionDisplayName(newOwner)
	local oldName = TurfConfig.GetFactionDisplayName(oldOwner)

	syncBlockVisuals(blockId)
	spawnCaptureBurst(st.Spec.PlazaPos, newColor)
	BlackMarketService.BroadcastSFX("MeleeHit", st.Spec.PlazaPos)

	-- Reward Player capturer & notify former Player owner!
	local winnerPlayer = getPlayerFromFaction(newOwner)
	if winnerPlayer then
		local passMult = MonetizationService.GetPayoutMultiplier(winnerPlayer)
		local repMult = MonetizationService.GetRepMultiplier(winnerPlayer)
		local gold = math.floor(st.Spec.CaptureBountyGold * passMult)
		local rep = math.floor(st.Spec.CaptureBountyRep * repMult)
		PlayerDataService.AddRewards(winnerPlayer, gold, 45, rep)
		broadcastToast(string.format("🏙️ %s captured %s from %s! (+%dG, +%d Rep)", winnerPlayer.DisplayName, st.Spec.DisplayName, oldName, gold, rep))
	else
		broadcastToast(string.format("🕶️ %s seized %s from %s!", newName, st.Spec.DisplayName, oldName))
	end

	local loserPlayer = getPlayerFromFaction(oldOwner)
	if loserPlayer and loserPlayer ~= winnerPlayer then
		sendToast(loserPlayer, string.format("🚨 YOU LOST %s to %s! Fight back to reclaim it!", st.Spec.DisplayName, newName))
	end

	print(string.format("[TurfService] Block %s transferred: %s -> %s", blockId, oldOwner, newOwner))
	notifyChanged(true)
end

local function collectPlazaOccupants(st: TurfBlockState): { [string]: number }
	local counts: { [string]: number } = {}
	local center = st.Spec.PlazaPos
	local rSq = st.Spec.CaptureRadius * st.Spec.CaptureRadius

	local function addIfInside(root: BasePart, factionId: string): ()
		local dx = root.Position.X - center.X
		local dz = root.Position.Z - center.Z
		if (dx * dx + dz * dz) <= rSq and math.abs(root.Position.Y - center.Y) <= 18 then
			counts[factionId] = (counts[factionId] or 0) + 1
		end
	end

	-- 1. Living Players (only those who claimed a Castle Base!)
	for _, player in ipairs(Players:GetPlayers()) do
		if BaseService.GetPlayerBaseSlot(player) or player:GetAttribute("BaseSlot") ~= nil then
			local char = player.Character
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			if hum and hum.Health > 0 and root and root:IsA("BasePart") then
				addIfInside(root, "Player_" .. tostring(player.UserId))
			end
		end
	end

	-- 2. Living Player Raider Chefs & Turf Guards
	for _, tagName in ipairs({ "PlayerRaiderUnit", "TurfGuardUnit" }) do
		for _, unit in ipairs(CollectionService:GetTagged(tagName)) do
			if unit:IsA("Model") then
				local hum = unit:FindFirstChildOfClass("Humanoid")
				local root = unit:FindFirstChild("HumanoidRootPart")
				local fAttr = unit:GetAttribute("Faction")
				if hum and hum.Health > 0 and root and root:IsA("BasePart") and typeof(fAttr) == "string" then
					addIfInside(root, fAttr)
				end
			end
		end
	end

	-- 3. Living Mafia Units (garrison + raiding squads!)
	for _, unit in ipairs(CollectionService:GetTagged("MafiaUnit")) do
		if unit:IsA("Model") then
			local hum = unit:FindFirstChildOfClass("Humanoid")
			local root = unit:FindFirstChild("HumanoidRootPart")
			local fAttr = unit:GetAttribute("Faction")
			if hum and hum.Health > 0 and root and root:IsA("BasePart") and typeof(fAttr) == "string" then
				local factionId = if TurfConfig.MafiaFactions[fAttr] then fAttr else st.Spec.InitialOwner
				addIfInside(root, factionId)
			end
		end
	end

	return counts
end

local function stepBlockCapture(st: TurfBlockState, dt: number, now: number): ()
	local prevDefenders = st.DefendersAlive
	st.DefendersAlive = countLivingDefendersForBlock(st.Id, st.Owner)
	if st.DefendersAlive < prevDefenders then
		lastGuardDiedAt[st.Id] = now
	end

	local occupants = collectPlazaOccupants(st)
	local factions: { string } = {}
	for fid in pairs(occupants) do
		table.insert(factions, fid)
	end

	local prevStatus = st.Status
	local prevProgress = st.CaptureProgress
	local prevCapFaction = st.CapturingFaction

	if #factions > 1 then
		-- Multiple rival factions fighting inside the Capture Plaza -> CONTESTED!
		st.Status = "Contested"
		if not TurfConfig.IsMafiaFaction(st.Owner) then
			st.UnderAttackUntil = now + 8
		end
	elseif #factions == 1 then
		local activeFaction = factions[1]
		local unitCount = occupants[activeFaction]

		if activeFaction == st.Owner then
			-- Owner controls plaza cleanly -> heal/decay any enemy capture progress
			st.Status = "Controlled"
			if st.CaptureProgress > 0 then
				st.CaptureProgress = math.max(0, st.CaptureProgress - DECAY_PER_SECOND * 2.4 * dt)
				if st.CaptureProgress <= 0 then
					st.CapturingFaction = nil
				end
			end
		else
			-- Alert any nearby defenders belonging to the current owner so they rush to defend the plaza!
			for _, ag in ipairs(activeAgents) do
				if ag.HomeBlockId == st.Id and ag.FactionId == st.Owner and ag.Model.Parent and ag.Humanoid.Health > 0 then
					if (ag.Root.Position - st.Spec.PlazaPos).Magnitude > (st.Spec.CaptureRadius * 0.65) then
						ag.Humanoid:MoveTo(st.Spec.PlazaPos)
					end
				end
			end

			-- Challenging faction holds the plaza uncontested!
			if st.CapturingFaction ~= activeFaction then
				st.CapturingFaction = activeFaction
				st.CaptureProgress = 0
				-- Warn player owner if someone starts capturing their turf!
				local ownerPlayer = getPlayerFromFaction(st.Owner)
				if ownerPlayer then
					st.UnderAttackUntil = now + 12
					st.AttackerName = TurfConfig.GetFactionDisplayName(activeFaction)
					sendToast(ownerPlayer, string.format("⚠️ %s is capturing your block %s!", st.AttackerName or "Rivals", st.Spec.DisplayName))
				end
			end

			st.Status = "Capturing"
			local speedMult = 1 + math.max(0, unitCount - 1) * EXTRA_UNIT_SPEED_BONUS
			local nextProg = st.CaptureProgress + (dt / math.max(3, st.Spec.CaptureTime)) * speedMult
			if nextProg >= 1 then
				transferBlockOwnership(st.Id, activeFaction)
				return
			else
				st.CaptureProgress = nextProg
			end
		end
	else
		-- Empty plaza -> decay partial progress back to 0
		st.Status = "Controlled"
		if st.CaptureProgress > 0 then
			st.CaptureProgress = math.max(0, st.CaptureProgress - DECAY_PER_SECOND * dt)
			if st.CaptureProgress <= 0 then
				st.CapturingFaction = nil
			end
		end
	end

	if
		st.Status ~= prevStatus
		or st.CapturingFaction ~= prevCapFaction
		or st.DefendersAlive ~= prevDefenders
		or math.abs(st.CaptureProgress - prevProgress) >= 0.04
	then
		syncBlockVisuals(st.Id)
		notifyChanged(false)
	end
end

-- Periodic Dynamic Mafia Counter-Attack / Turf Raid against Player-Controlled Blocks!
local function tryLaunchMafiaRaid(): ()
	if #activeRaids >= 2 then
		return
	end

	local playerOwnedBlocks: { TurfBlockState } = {}
	for _, st in pairs(blockStates) do
		if not TurfConfig.IsMafiaFaction(st.Owner) and st.Status == "Controlled" then
			local alreadyTargeted = false
			for _, raid in ipairs(activeRaids) do
				if raid.TargetBlockId == st.Id then
					alreadyTargeted = true
					break
				end
			end
			if not alreadyTargeted then
				table.insert(playerOwnedBlocks, st)
			end
		end
	end

	if #playerOwnedBlocks == 0 then
		return
	end

	local target = playerOwnedBlocks[math.random(1, #playerOwnedBlocks)]
	local ownerPlayer = getPlayerFromFaction(target.Owner)
	if not ownerPlayer then
		return
	end

	-- Prefer an adjacent Mafia faction (realistic street expansion!), otherwise original quadrant Mafia!
	local attackingMafia = target.Spec.InitialOwner
	local spawnOrigin = target.Spec.PlazaPos
	for _, neighborId in ipairs(target.Spec.Neighbors) do
		local nState = blockStates[neighborId]
		if nState and TurfConfig.IsMafiaFaction(nState.Owner) then
			attackingMafia = nState.Owner
			spawnOrigin = nState.Spec.PlazaPos
			break
		end
	end

	-- Spawn squad partway between neighboring block & target street edge so they arrive promptly!
	local approachDir = (spawnOrigin - target.Spec.PlazaPos)
	local spawnBase = if approachDir.Magnitude > 5
		then target.Spec.PlazaPos + approachDir.Unit * 72
		else target.Spec.PlazaPos + Vector3.new(65, 0, 0)

	local playerOwnedCount = 0
	for _, st in pairs(blockStates) do
		if st.Owner == target.Owner then
			playerOwnedCount += 1
		end
	end

	local raiderCount = if playerOwnedCount >= 5 then 3 else 2
	local raiders: { TurfAgent } = {}
	for i = 1, raiderCount do
		local offset = Vector3.new((i - 2) * 6, 3.5, math.random(-5, 5))
		local isCapo = (i == 1 and playerOwnedCount >= 4)
		local agent = buildTurfAgentModel(
			"MafiaRaider",
			attackingMafia,
			target.Id,
			target.Id,
			Vector3.new(spawnBase.X, 4, spawnBase.Z) + offset,
			isCapo,
			target.Spec.PatrolPoints
		)
		table.insert(activeAgents, agent)
		table.insert(raiders, agent)
	end

	local mafiaName = TurfConfig.GetFactionDisplayName(attackingMafia)
	target.UnderAttackUntil = os.clock() + 45
	target.AttackerName = mafiaName

	table.insert(activeRaids, {
		TargetBlockId = target.Id,
		MafiaFactionId = attackingMafia,
		OwnerPlayer = ownerPlayer,
		Raiders = raiders,
		StartedAt = os.clock(),
	})

	sendToast(ownerPlayer, string.format("🚨 %s MAFIA is raiding %s! Defend your territory!", mafiaName, target.Spec.DisplayName))
	notifyChanged(true)
	print(string.format("[TurfService] %s launched a %d-unit raid on %s!", mafiaName, raiderCount, target.Id))
end

local function updateActiveRaids(now: number): ()
	for i = #activeRaids, 1, -1 do
		local raid = activeRaids[i]
		local alive = 0
		for _, r in ipairs(raid.Raiders) do
			if r.Model.Parent and r.Humanoid.Health > 0 then
				alive += 1
			end
		end

		local st = blockStates[raid.TargetBlockId]
		if alive == 0 then
			-- Raid defeated -> reward defender!
			if raid.OwnerPlayer and raid.OwnerPlayer.Parent and st and st.Owner == ("Player_" .. tostring(raid.OwnerPlayer.UserId)) then
				PlayerDataService.AddRewards(raid.OwnerPlayer, 110, 40, 25)
				sendToast(raid.OwnerPlayer, string.format("🛡️ DEFENDED %s! Repelled %s raid (+110G, +25 Rep)!", st.Spec.DisplayName, TurfConfig.GetFactionDisplayName(raid.MafiaFactionId)))
				st.UnderAttackUntil = 0
			end
			table.remove(activeRaids, i)
			notifyChanged(true)
		elseif (now - raid.StartedAt) > 75 then
			-- Raid timed out -> survivors retreat
			for _, r in ipairs(raid.Raiders) do
				if r.Model.Parent then
					r.Model:Destroy()
				end
			end
			if st then
				st.UnderAttackUntil = 0
			end
			table.remove(activeRaids, i)
			notifyChanged(true)
		end
	end
end

-- Passive Territory Income + Quadrant Monopoly Bonus!
local function payPassiveTurfIncome(): ()
	for _, player in ipairs(Players:GetPlayers()) do
		local factionId = "Player_" .. tostring(player.UserId)
		local totalGold = 0
		local totalRep = 0
		local ownedCount = 0
		local quadCounts: { [string]: number } = { NW = 0, NE = 0, SW = 0, SE = 0 }

		for _, st in pairs(blockStates) do
			if st.Owner == factionId then
				ownedCount += 1
				totalGold += st.Spec.IncomeGold
				totalRep += st.Spec.IncomeRep
				quadCounts[st.Spec.Quadrant] = (quadCounts[st.Spec.Quadrant] or 0) + 1
			end
		end

		if ownedCount > 0 then
			local monopolies = 0
			for _, c in pairs(quadCounts) do
				if c >= 4 then
					monopolies += 1
				end
			end
			local monopolyMult = 1 + monopolies * 0.5
			local passMult = MonetizationService.GetPayoutMultiplier(player)
			local repMult = MonetizationService.GetRepMultiplier(player)
			local finalGold = math.floor(totalGold * monopolyMult * passMult)
			local finalRep = math.floor(totalRep * monopolyMult * repMult)
			PlayerDataService.AddRewards(player, finalGold, ownedCount * 4, finalRep)
		end
	end
end

-- Wire All 16 Interactive Tribute Vaults & Neighborhood Street Food / Buff Kiosks!
local function wireInteractivePOIs(): ()
	-- 1. Tribute Cash Vaults
	for _, vault in ipairs(CollectionService:GetTagged("TurfTributeVault")) do
		local blockIdAttr = vault:GetAttribute("BlockId")
		local prompt = vault:FindFirstChild("TributeVaultPrompt", true)
		if typeof(blockIdAttr) == "string" and prompt and prompt:IsA("ProximityPrompt") then
			table.insert(
				conns,
				prompt.Triggered:Connect(function(player: Player)
					local st = blockStates[blockIdAttr]
					if not st then return end
					local myFaction = "Player_" .. tostring(player.UserId)
					local key = tostring(player.UserId) .. "_" .. blockIdAttr
					local now = os.clock()
					local readyAt = vaultCooldowns[key] or 0
					if now < readyAt then
						sendToast(player, string.format("⏳ Vault refilling (%ds left)!", math.ceil(readyAt - now)))
						return
					end

					if st.Owner == myFaction then
						vaultCooldowns[key] = now + VAULT_COOLDOWN
						local amount = if st.Spec.IsHQ then 115 else 65
						local rep = if st.Spec.IsHQ then 15 else 8
						PlayerDataService.AddRewards(player, amount, 15, rep)
						sendToast(player, string.format("💰 Collected %s Turf Tribute: +%d Gold & +%d Rep!", st.Spec.DisplayName, amount, rep))
					else
						if st.DefendersAlive > 0 then
							sendToast(player, string.format("🔒 Clear the %d Mafia guards or capture %s first!", st.DefendersAlive, st.Spec.DisplayName))
						else
							vaultCooldowns[key] = now + VAULT_COOLDOWN
							PlayerDataService.AddRewards(player, 40, 10, 5)
							sendToast(player, string.format("🔓 Raided %s Mafia Stash: +40 Gold! Capture the block for full Tribute!", st.Spec.DisplayName))
						end
					end
				end)
			)
		end
	end

	-- 2. Neighborhood Buff Kiosks (Speed Espresso / Noodle Heal / Tactical Med-Cabinet / Stim)
	for _, kiosk in ipairs(CollectionService:GetTagged("UrbanBuffKiosk")) do
		local blockIdAttr = kiosk:GetAttribute("BlockId")
		local buffAttr = kiosk:GetAttribute("BuffType")
		local prompt = kiosk:FindFirstChild("BuffKioskPrompt", true)
		if typeof(blockIdAttr) == "string" and typeof(buffAttr) == "string" and prompt and prompt:IsA("ProximityPrompt") then
			table.insert(
				conns,
				prompt.Triggered:Connect(function(player: Player)
					local st = blockStates[blockIdAttr]
					if not st then return end
					local now = os.clock()
					local readyAt = kioskCooldowns[player.UserId] or 0
					if now < readyAt then
						sendToast(player, string.format("⏳ Street stand ready in %ds!", math.ceil(readyAt - now)))
						return
					end

					local myFaction = "Player_" .. tostring(player.UserId)
					local isFree = (st.Owner == myFaction)
					if not isFree then
						if not PlayerDataService.SpendCoins(player, 25) then
							sendToast(player, "Need 25 Gold (or capture this block for FREE neighborhood buffs!)")
							return
						end
					end

					kioskCooldowns[player.UserId] = now + KIOSK_COOLDOWN
					local char = player.Character
					local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
					if not hum or hum.Health <= 0 then return end

					local tagStr = if isFree then " (FREE on your turf!)" else " (-25G)"
					if buffAttr == "Speed" then
						hum.WalkSpeed = math.max(hum.WalkSpeed, 25)
						task.delay(15, function()
							if hum.Parent and hum.WalkSpeed >= 24 then
								hum.WalkSpeed = 16
							end
						end)
						sendToast(player, "⚡ " .. st.Spec.BuffTitle .. " active for 15s!" .. tagStr)
					elseif buffAttr == "Heal" then
						hum.Health = math.min(hum.MaxHealth, hum.Health + 45)
						sendToast(player, "🍜 " .. st.Spec.BuffTitle .. " restored +45 HP!" .. tagStr)
					elseif buffAttr == "ArmorPatch" then
						hum.Health = math.min(hum.MaxHealth, hum.Health + 50)
						local prof = PlayerDataService.GetProfile(player)
						local nextArmor = math.min(100, (prof.Armor or 0) + 35)
						PlayerDataService.SetArmor(player, nextArmor)
						if char then
							char:SetAttribute("Armor", nextArmor)
							hum.MaxHealth = 100 + nextArmor
							hum.Health = math.min(hum.MaxHealth, hum.Health + 35)
						end
						sendToast(player, "🛡️ " .. st.Spec.BuffTitle .. ": +50 HP & +35 Armor!" .. tagStr)
					else -- CombatStim
						hum.Health = math.min(hum.MaxHealth, hum.Health + 30)
						hum.WalkSpeed = math.max(hum.WalkSpeed, 23)
						task.delay(14, function()
							if hum.Parent and hum.WalkSpeed >= 22 then
								hum.WalkSpeed = 16
							end
						end)
						sendToast(player, "🔥 " .. st.Spec.BuffTitle .. ": +30 HP & Speed Boost!" .. tagStr)
					end
				end)
			)
		end
	end
end

-- Public API for RaiderChefService & RestaurantService
function TurfService.GetBestCaptureTargetForPlayer(player: Player, fromPos: Vector3): (string?, Vector3?)
	local myFaction = "Player_" .. tostring(player.UserId)
	local bestId: string? = nil
	local bestPos: Vector3? = nil
	local bestScore = -math.huge

	for _, blockId in ipairs(TurfConfig.BlockOrder) do
		local st = blockStates[blockId]
		if st then
			local dist = (st.Spec.PlazaPos - fromPos).Magnitude
			local priority = 0
			if st.Owner == myFaction and (st.Status == "Contested" or os.clock() < st.UnderAttackUntil) then
				priority = 800 -- Rush to defend player's block under attack!
			elseif st.Owner ~= myFaction then
				priority = if st.Spec.IsHQ then 520 else 580
			else
				priority = 60
			end
			local score = priority - dist * 0.45
			if score > bestScore then
				bestScore = score
				bestId = blockId
				bestPos = st.Spec.PlazaPos
			end
		end
	end
	return bestId, bestPos
end

function TurfService.GetSnapshotForPlayer(player: Player): { [string]: any }
	local myFaction = "Player_" .. tostring(player.UserId)
	local blocksOut: { [string]: any } = {}
	local ownedCount = 0
	local totalIncome = 0
	local quadCounts: { [string]: number } = { NW = 0, NE = 0, SW = 0, SE = 0 }
	local now = os.clock()

	for _, blockId in ipairs(TurfConfig.BlockOrder) do
		local st = blockStates[blockId]
		if st then
			local col = TurfConfig.ResolveFactionColor(st.Owner)
			local capCol = if st.CapturingFaction then TurfConfig.ResolveFactionColor(st.CapturingFaction) else col
			local isUnderAttack = (now < st.UnderAttackUntil) or (st.Status == "Contested")
			if st.Owner == myFaction then
				ownedCount += 1
				totalIncome += st.Spec.IncomeGold
				quadCounts[st.Spec.Quadrant] = (quadCounts[st.Spec.Quadrant] or 0) + 1
			end
			blocksOut[blockId] = {
				Id = blockId,
				DisplayName = st.Spec.DisplayName,
				ShortCode = st.Spec.ShortCode,
				Owner = st.Owner,
				OwnerName = TurfConfig.GetFactionDisplayName(st.Owner),
				ColorR = math.floor(col.R * 255),
				ColorG = math.floor(col.G * 255),
				ColorB = math.floor(col.B * 255),
				CapColorR = math.floor(capCol.R * 255),
				CapColorG = math.floor(capCol.G * 255),
				CapColorB = math.floor(capCol.B * 255),
				Status = st.Status,
				Progress = st.CaptureProgress,
				CapturingName = if st.CapturingFaction then TurfConfig.GetFactionDisplayName(st.CapturingFaction) else nil,
				UnderAttack = isUnderAttack,
				DefendersAlive = st.DefendersAlive,
				IsHQ = st.Spec.IsHQ,
				PlazaX = st.Spec.PlazaPos.X,
				PlazaZ = st.Spec.PlazaPos.Z,
				CaptureRadius = st.Spec.CaptureRadius,
				IncomeGold = st.Spec.IncomeGold,
			}
		end
	end

	local monopolies = 0
	for _, c in pairs(quadCounts) do
		if c >= 4 then monopolies += 1 end
	end

	return {
		Blocks = blocksOut,
		OwnedCount = ownedCount,
		TotalBlocks = #TurfConfig.BlockOrder,
		IncomePerCycle = math.floor(totalIncome * (1 + monopolies * 0.5)),
		Monopolies = monopolies,
	}
end

local function indexWorldInstances(): ()
	table.clear(blockColorParts)
	table.clear(blockBillboards)
	table.clear(blockZones)

	for _, part in ipairs(CollectionService:GetTagged("TurfBlockColorPart")) do
		if part:IsA("BasePart") then
			local bid = part:GetAttribute("BlockId")
			if typeof(bid) == "string" then
				local list = blockColorParts[bid]
				if not list then
					list = {}
					blockColorParts[bid] = list
				end
				table.insert(list, part)
			end
		end
	end

	for _, zone in ipairs(CollectionService:GetTagged("TurfCaptureZone")) do
		if zone:IsA("BasePart") then
			local bid = zone:GetAttribute("BlockId")
			if typeof(bid) == "string" then
				blockZones[bid] = zone
			end
		end
	end

	for _, blockModel in ipairs(CollectionService:GetTagged("TurfBlockModel")) do
		local bid = blockModel:GetAttribute("BlockId")
		if typeof(bid) == "string" then
			local bb = blockModel:FindFirstChild("BlockBillboard", true)
			if bb and bb:IsA("BillboardGui") then
				blockBillboards[bid] = bb
			end
		end
	end
end

function TurfService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local existing = Workspace:FindFirstChild("UrbanTurfForces")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		npcFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "UrbanTurfForces"
		f.Parent = Workspace
		npcFolder = f
	end

	indexWorldInstances()

	-- Initialize all 16 urban blocks owned by The Main Mafia Factions!
	table.clear(blockStates)
	local now = os.clock()
	for _, blockId in ipairs(TurfConfig.BlockOrder) do
		local spec = TurfConfig.Blocks[blockId]
		if spec then
			blockStates[blockId] = {
				Id = blockId,
				Spec = spec,
				Owner = spec.InitialOwner,
				Status = "Controlled",
				CapturingFaction = nil,
				CaptureProgress = 0,
				UnderAttackUntil = 0,
				AttackerName = nil,
				DefendersAlive = 0,
			}
			lastGuardDiedAt[blockId] = 0
			populateBlockGarrison(blockId)
			syncBlockVisuals(blockId)
		end
	end

	wireInteractivePOIs()

	-- Re-sync colors if a player claims a Castle Base (so their territories always match their Base Color!)
	unsubBase = BaseService.OnBaseAssigned(function(player: Player)
		local myFaction = "Player_" .. tostring(player.UserId)
		for blockId, st in pairs(blockStates) do
			if st.Owner == myFaction then
				syncBlockVisuals(blockId)
			end
		end
		notifyChanged(true)
	end)

	-- If a player leaves, return their controlled blocks cleanly to their original Main Mafia Faction
	table.insert(
		conns,
		Players.PlayerRemoving:Connect(function(player: Player)
			local myFaction = "Player_" .. tostring(player.UserId)
			for blockId, st in pairs(blockStates) do
				if st.Owner == myFaction then
					st.Owner = st.Spec.InitialOwner
					st.Status = "Controlled"
					st.CaptureProgress = 0
					st.CapturingFaction = nil
					st.UnderAttackUntil = 0
					clearBlockGarrison(blockId, myFaction)
					populateBlockGarrison(blockId)
					syncBlockVisuals(blockId)
				end
			end
			kioskCooldowns[player.UserId] = nil
			notifyChanged(true)
		end)
	)

	-- 1. Real-Time Block-by-Block Capture Engine (0.25s tick)
	captureThread = task.spawn(function()
		while isRunning do
			task.wait(CAPTURE_TICK)
			if not isRunning then break end
			local t = os.clock()
			for _, blockId in ipairs(TurfConfig.BlockOrder) do
				local st = blockStates[blockId]
				if st then
					stepBlockCapture(st, CAPTURE_TICK, t)
				end
			end
		end
	end)

	-- 2. Mafia Defenders, Player Turf Guards & Raid Squad AI Loop (0.75s tick)
	aiThread = task.spawn(function()
		task.wait(3)
		while isRunning do
			task.wait(AI_TICK)
			if not isRunning then break end
			local t = os.clock()

			-- Clean up dead agents & record death timestamps so killed guards never instant-respawn!
			for i = #activeAgents, 1, -1 do
				local a = activeAgents[i]
				if not a.Model.Parent or a.Humanoid.Health <= 0 then
					lastGuardDiedAt[a.HomeBlockId] = t
					if a.Model.Parent then
						local dying = a.Model
						task.delay(2.5, function()
							if dying.Parent then dying:Destroy() end
						end)
					end
					table.remove(activeAgents, i)
				else
					stepAgentAI(a, t)
				end
			end

			-- Garrison replenishment (waits a full 30s AFTER the last guard died AND only while block is calm & uncontested!)
			for _, blockId in ipairs(TurfConfig.BlockOrder) do
				local st = blockStates[blockId]
				if st and st.Status == "Controlled" and st.CaptureProgress <= 0.01 then
					local expected = if TurfConfig.IsMafiaFaction(st.Owner) and st.Spec.IsHQ then 3 else 2
					if st.DefendersAlive < expected and (t - (lastGuardDiedAt[blockId] or 0)) >= GARRISON_RESPAWN_DELAY then
						lastGuardDiedAt[blockId] = t
						local before = st.DefendersAlive
						populateBlockGarrison(blockId)
						if st.DefendersAlive ~= before then
							syncBlockVisuals(blockId)
							notifyChanged(false)
						end
					end
				end
			end

			updateActiveRaids(t)
		end
	end)

	-- 3. Passive Turf Income & Dynamic Mafia Counter-Attack Raids Loop
	economyThread = task.spawn(function()
		local incomeAcc = 0
		local raidAcc = 22 -- First possible raid ~34s after capturing a block
		while isRunning do
			task.wait(4)
			if not isRunning then break end
			incomeAcc += 4
			raidAcc += 4

			if incomeAcc >= INCOME_INTERVAL then
				incomeAcc = 0
				payPassiveTurfIncome()
			end
			if raidAcc >= RAID_INTERVAL then
				raidAcc = 0
				tryLaunchMafiaRaid()
			end
		end
	end)

	print("[Food Empire] TurfService started (16 Urban Territory Blocks • 4 Main Mafia Factions • Dynamic Raids & Base-Color Ownership live)!")
end

function TurfService.Stop(): ()
	isRunning = false
	if captureThread then task.cancel(captureThread); captureThread = nil end
	if aiThread then task.cancel(aiThread); aiThread = nil end
	if economyThread then task.cancel(economyThread); economyThread = nil end
	if unsubBase then unsubBase(); unsubBase = nil end
	for _, c in ipairs(conns) do c:Disconnect() end
	table.clear(conns)
	if npcFolder then npcFolder:ClearAllChildren() end
	table.clear(activeAgents)
	table.clear(activeRaids)
end

return TurfService
