--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local PlayerDataService = require("./PlayerDataService")
local BlackMarketService = require("./BlackMarketService")
local CombatLockService = require("./CombatLockService")

export type MafiaRestaurantSpec = {
	Id: string,
	DisplayName: string,
	FactionName: string,
	SpecialistKind: "ApexWarlord" | "ApexAssassin" | "SamuraiMafia" | "NinjaMafia",
	BladeStyle: ("Samurai" | "Ninja")?,
	Position: Vector3,
	YawDeg: number,
	AccentColor: Color3,
	EnforcerHP: number,
	BossHP: number,
	GunDamage: number,
	ChefHireCost: number,
	CycleGold: number,
	CycleRep: number,
	BountyGold: number,
}

type GarrisonUnit = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	IsBoss: boolean,
	Damage: number,
	LastShotAt: number,
	LastAttacker: Player?,
}

type RestaurantRuntime = {
	Spec: MafiaRestaurantSpec,
	Owner: Player?,
	ChefHired: boolean,
	ChefModel: Model?,
	UnderRevenge: boolean,
	RevengeEndsAt: number,
	NextRevengeAt: number,
	NextPayoutAt: number,
	ProvokedUntil: number,
	Garrison: { GarrisonUnit },
	RevengeSquad: { GarrisonUnit },
	StatusLabel: TextLabel?,
	Prompt: ProximityPrompt?,
	RootPart: BasePart?,
	Model: Model?,
}

local MafiaRestaurantService = {}

MafiaRestaurantService.ORDER = {
	"ObsidianNoodleHouse",
	"VelvetSteakhouse",
	"ImperialOysterBar",
}

MafiaRestaurantService.SPECS = {
	ObsidianNoodleHouse = {
		Id = "ObsidianNoodleHouse",
		DisplayName = "Obsidian Dragon Noodle House",
		FactionName = "Iron Shogun Samurai Mafia",
		SpecialistKind = "SamuraiMafia",
		BladeStyle = "Samurai",
		Position = Vector3.new(114, 1.35, -98),
		YawDeg = -135,
		AccentColor = Color3.fromRGB(142, 34, 42),
		EnforcerHP = 540,
		BossHP = 1150,
		GunDamage = 20,
		ChefHireCost = 2100,
		CycleGold = 55,
		CycleRep = 18,
		BountyGold = 240,
	},
	VelvetSteakhouse = {
		Id = "VelvetSteakhouse",
		DisplayName = "Velvet Vendetta Steakhouse",
		FactionName = "Black Hand Ninja Mafia",
		SpecialistKind = "NinjaMafia",
		BladeStyle = "Ninja",
		Position = Vector3.new(-118, 1.35, -98),
		YawDeg = 135,
		AccentColor = Color3.fromRGB(162, 126, 62),
		EnforcerHP = 620,
		BossHP = 1350,
		GunDamage = 24,
		ChefHireCost = 2600,
		CycleGold = 75,
		CycleRep = 24,
		BountyGold = 310,
	},
	ImperialOysterBar = {
		Id = "ImperialOysterBar",
		DisplayName = "Imperial Crown Oyster Bar",
		FactionName = "Apex Syndicate Warlords",
		SpecialistKind = "ApexWarlord",
		BladeStyle = nil,
		Position = Vector3.new(114, 1.35, 110),
		YawDeg = -45,
		AccentColor = Color3.fromRGB(128, 30, 38),
		EnforcerHP = 720,
		BossHP = 1600,
		GunDamage = 28,
		ChefHireCost = 3250,
		CycleGold = 100,
		CycleRep = 32,
		BountyGold = 420,
	},
} :: { [string]: MafiaRestaurantSpec }

local runtimes: { [string]: RestaurantRuntime } = {}
local isRunning = false
local rootFolder: Folder? = nil
local unitFolder: Folder? = nil
local aiThread: thread? = nil
local onChangedCb: ((player: Player?) -> ())? = nil

function MafiaRestaurantService.SetChangedCallback(cb: (player: Player?) -> ()): ()
	onChangedCb = cb
end

local function broadcastToast(msg: string, targetPlayer: Player?): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		if targetPlayer then
			ev:FireClient(targetPlayer, msg)
		else
			ev:FireAllClients(msg)
		end
	end
end

local function refreshRestaurantSign(rt: RestaurantRuntime): ()
	local lbl = rt.StatusLabel
	local prompt = rt.Prompt
	if rt.UnderRevenge then
		local rem = math.max(0, math.ceil(rt.RevengeEndsAt - os.clock()))
		if lbl then
			lbl.Text = string.format("%s  |  MAFIA REVENGE RAID (%ds) — DEFEND NOW!", string.upper(rt.Spec.DisplayName), rem)
			lbl.TextColor3 = Color3.fromRGB(246, 118, 118)
		end
		if prompt then
			prompt.ActionText = "Mafia Revenge Raid Active — Eliminate Raiders!"
		end
	elseif rt.Owner and rt.Owner.Parent then
		if lbl then
			local chefTag = if rt.ChefHired then string.format("CHEF SELLING (+%dG/18s)", rt.Spec.CycleGold) else string.format("HIRE CHEF (%dG) [E]", rt.Spec.ChefHireCost)
			lbl.Text = string.format("%s'S %s  |  %s", string.upper(rt.Owner.DisplayName), string.upper(rt.Spec.DisplayName), chefTag)
			lbl.TextColor3 = Color3.fromRGB(168, 224, 178)
		end
		if prompt then
			prompt.ActionText = if rt.ChefHired
				then string.format("Chef Operating (+%dG / +%d Rep)", rt.Spec.CycleGold, rt.Spec.CycleRep)
				else string.format("Hire Restaurant Chef (%d Gold)", rt.Spec.ChefHireCost)
		end
	else
		local alive = 0
		for _, u in ipairs(rt.Garrison) do
			if u.Model.Parent and u.Humanoid.Health > 0 then
				alive += 1
			end
		end
		if lbl then
			lbl.Text = string.format("%s  |  CONTROLLED BY %s (%d ALIVE)", string.upper(rt.Spec.DisplayName), string.upper(rt.Spec.FactionName), alive)
			lbl.TextColor3 = Color3.fromRGB(234, 196, 126)
		end
		if prompt then
			prompt.ActionText = string.format("Defeat %s (%d left) to Take Over!", rt.Spec.FactionName, alive)
		end
	end
end

local function clearChefVisual(rt: RestaurantRuntime): ()
	if rt.ChefModel and rt.ChefModel.Parent then
		rt.ChefModel:Destroy()
	end
	rt.ChefModel = nil
end

local function spawnChefVisual(rt: RestaurantRuntime): ()
	clearChefVisual(rt)
	if not rt.RootPart then return end
	local chefCF = rt.RootPart.CFrame * CFrame.new(0, 3.6, -2.5)
	local rig = MafiaVisualBuilder.BuildChefRig("CapturedRestaurantChef_" .. rt.Spec.Id, rt.Spec.AccentColor, 1.0, chefCF, false)
	rig.Root.Anchored = true
	rig.Model.Parent = rt.Model or Workspace

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(180, 32)
	bb.StudsOffset = Vector3.new(0, 3.0, 0)
	bb.MaxDistance = 120
	bb.Parent = rig.Head
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = string.format("CITY BRANCH CHEF  |  +%dG", rt.Spec.CycleGold)
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.fromRGB(178, 226, 184)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)
	rt.ChefModel = rig.Model
end

local function buildApexUnit(rt: RestaurantRuntime, isBoss: boolean, isRevenge: boolean, spawnPos: Vector3): GarrisonUnit
	local spec = rt.Spec
	local kind: "ApexWarlord" | "ApexAssassin" | "SamuraiMafia" | "NinjaMafia" = if spec.BladeStyle
		then spec.SpecialistKind
		elseif isBoss then "ApexWarlord"
		else spec.SpecialistKind
	local scale = if isBoss then 1.18 else 1.04
	local maxHP = if isBoss then spec.BossHP else spec.EnforcerHP
	if isRevenge then
		maxHP = math.floor(maxHP * 0.78)
	end
	local title = if isRevenge
		then (if isBoss then "REVENGE CAPTAIN" else "REVENGE ENFORCER")
		else (if isBoss then (string.upper(spec.FactionName) .. " BOSS") else (string.upper(spec.FactionName) .. " GUARD"))

	local modelName = string.format("ApexMafia_%s_%s", spec.Id, if isBoss then "Boss" else "Guard")
	local rig = MafiaVisualBuilder.BuildSyndicateSpecialistRig(modelName, kind, scale, CFrame.new(spawnPos), false)
	local model = rig.Model
	local root = rig.Root
	local head = rig.Head

	local bb = Instance.new("BillboardGui")
	bb.Name = "ApexMafiaTag"
	bb.Size = UDim2.fromOffset(210, 42)
	bb.StudsOffset = Vector3.new(0, 3.2 * scale, 0)
	bb.MaxDistance = 165
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = title
	lbl.TextSize = 10
	lbl.TextColor3 = if isBoss then Color3.fromRGB(238, 192, 114) else Color3.fromRGB(224, 126, 128)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(132, 34, 42)
	st.Thickness = 1.2
	st.Parent = lbl

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.03, 0, 0, 23)
	hpBg.Size = UDim2.new(0.94, 0, 0, 14)
	hpBg.BackgroundColor3 = Color3.fromRGB(14, 15, 19)
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
	hum.WalkSpeed = if isBoss then 18.5 else 20.0
	hum.HipHeight = 2.42 * scale
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	hum.HealthChanged:Connect(function(hp: number)
		local cur = math.max(0, math.ceil(hp))
		local maxH = math.max(1, math.ceil(hum.MaxHealth))
		hpFill.Size = UDim2.fromScale(math.clamp(hp / maxH, 0, 1), 1)
		hpTxt.Text = string.format("%d / %d HP", cur, maxH)
	end)

	model.PrimaryPart = root
	model:SetAttribute("Faction", "ApexMafia")
	model:SetAttribute("MafiaTitle", title)
	model:SetAttribute("MafiaRestaurantId", spec.Id)
	model:SetAttribute("IsRevengeRaider", isRevenge)
	if spec.BladeStyle then
		model:SetAttribute("BladeStyle", spec.BladeStyle)
	end
	model:SetAttribute("BountyGold", if isBoss then spec.BountyGold else math.floor(spec.BountyGold * 0.5))
	model:SetAttribute("BountyExp", if isBoss then 140 else 75)
	model:SetAttribute("BountyRep", if isBoss then 65 else 30)
	model:SetAttribute("MafiaRestaurantId", rt.Spec.Id)
	model:SetAttribute("UnderRevenge", isRevenge)
	model:SetAttribute("Provoked", isRevenge)
	CollectionService:AddTag(model, "ApexMafiaUnit")
	CollectionService:AddTag(model, "AnimatedRaiderLimbs")
	model.Parent = unitFolder or Workspace

	local unit: GarrisonUnit = {
		Model = model,
		Humanoid = hum,
		Root = root,
		IsBoss = isBoss,
		Damage = if isBoss then math.ceil(spec.GunDamage * 1.35) else spec.GunDamage,
		LastShotAt = 0,
		LastAttacker = nil,
	}

	local lastHp = hum.MaxHealth
	hum.HealthChanged:Connect(function(hp: number)
		if hp < lastHp and hp > 0 then
			rt.ProvokedUntil = math.max(rt.ProvokedUntil, os.clock() + 35)
			for _, g in ipairs(rt.Garrison) do
				if g.Model.Parent then
					g.Model:SetAttribute("Provoked", true)
				end
			end
		end
		lastHp = hp
	end)

	hum.Died:Connect(function()
		MafiaVisualBuilder.PlayDeathSequence(model, isBoss, function(impactPos: Vector3)
			BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
		end)
	end)

	return unit
end

local function clearUnits(list: { GarrisonUnit }): ()
	for _, u in ipairs(list) do
		if u.Model.Parent then
			u.Model:Destroy()
		end
	end
	table.clear(list)
end

local function spawnGarrisonForRestaurant(rt: RestaurantRuntime): ()
	clearUnits(rt.Garrison)
	local basePos = rt.Spec.Position
	local offsets = {
		Vector3.new(-12, 3.8, 12),
		Vector3.new(12, 3.8, 12),
		Vector3.new(-6, 3.8, 18),
		Vector3.new(6, 3.8, 18),
	}
	table.insert(rt.Garrison, buildApexUnit(rt, false, false, basePos + offsets[1]))
	table.insert(rt.Garrison, buildApexUnit(rt, false, false, basePos + offsets[2]))
	table.insert(rt.Garrison, buildApexUnit(rt, false, false, basePos + offsets[3]))
	table.insert(rt.Garrison, buildApexUnit(rt, true, false, basePos + offsets[4]))
	refreshRestaurantSign(rt)
end

local function buildRestaurantBuilding(rt: RestaurantRuntime): ()
	local spec = rt.Spec
	local model = Instance.new("Model")
	model.Name = "MafiaRestaurant_" .. spec.Id
	local cf = CFrame.new(spec.Position) * CFrame.Angles(0, math.rad(spec.YawDeg), 0)

	local function part(name: string, sz: Vector3, rel: CFrame, col: Color3, mat: Enum.Material, collide: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = cf * rel
		p.Color = col
		p.Material = mat
		p.Anchored = true
		p.CanCollide = if collide ~= nil then collide else true
		p.Parent = model
		return p
	end

	local obsidian = Color3.fromRGB(20, 22, 28)
	local stone = Color3.fromRGB(36, 38, 44)
	local brass = Color3.fromRGB(178, 144, 78)
	local warmWood = Color3.fromRGB(84, 54, 36)

	local floor = part("RestaurantDeck", Vector3.new(28, 1.2, 22), CFrame.new(0, 0.6, 0), stone, Enum.Material.Slate, true)
	part("BackWall", Vector3.new(28, 11.5, 1.4), CFrame.new(0, 6.4, -10.3), obsidian, Enum.Material.Brick, true)
	part("LeftWall", Vector3.new(1.4, 11.5, 16), CFrame.new(-13.3, 6.4, -2.5), obsidian, Enum.Material.Brick, true)
	part("RightWall", Vector3.new(1.4, 11.5, 16), CFrame.new(13.3, 6.4, -2.5), obsidian, Enum.Material.Brick, true)
	part("RoofSlab", Vector3.new(30, 1.4, 24), CFrame.new(0, 12.6, 0), obsidian, Enum.Material.Metal, true)
	part("BrassCornice", Vector3.new(30.4, 0.7, 24.4), CFrame.new(0, 13.4, 0), brass, Enum.Material.Metal, false)
	part("AccentAwning", Vector3.new(26, 0.8, 5.5), CFrame.new(0, 9.6, 10.2) * CFrame.Angles(math.rad(14), 0, 0), spec.AccentColor, Enum.Material.Fabric, false)
	part("KitchenCounter", Vector3.new(16, 3.4, 3.2), CFrame.new(0, 2.8, -5.0), warmWood, Enum.Material.WoodPlanks, true)
	part("CounterMarbleTop", Vector3.new(16.4, 0.35, 3.6), CFrame.new(0, 4.65, -5.0), Color3.fromRGB(224, 220, 212), Enum.Material.Marble, true)

	-- Outdoor Bistro Dining Tables
	for _, tx in ipairs({ -7.5, 0, 7.5 }) do
		part("PatioTable", Vector3.new(3.6, 2.4, 3.6), CFrame.new(tx, 2.4, 5.5), warmWood, Enum.Material.Wood, true)
		part("TableCloth", Vector3.new(3.8, 0.22, 3.8), CFrame.new(tx, 3.68, 5.5), Color3.fromRGB(228, 224, 216), Enum.Material.Fabric, false)
	end

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 224, 166)
	light.Brightness = 1.8
	light.Range = 36
	light.Shadows = false
	light.Parent = floor

	local bb = Instance.new("BillboardGui")
	bb.Name = "MafiaRestaurantSign"
	bb.Size = UDim2.fromOffset(330, 46)
	bb.StudsOffset = Vector3.new(0, 16.0, 0)
	bb.MaxDistance = 260
	bb.Parent = floor

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
	lbl.BackgroundTransparency = 0.08
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 11
	lbl.TextColor3 = Color3.fromRGB(234, 196, 126)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)
	local st = Instance.new("UIStroke")
	st.Color = spec.AccentColor
	st.Thickness = 1.5
	st.Parent = lbl

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MafiaRestaurantPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.ObjectText = spec.DisplayName
	prompt.ActionText = "Conquer Mafia Restaurant"
	prompt.Parent = floor

	prompt.Triggered:Connect(function(player: Player)
		local _, msg = MafiaRestaurantService.TryHireChef(player, spec.Id)
		broadcastToast(msg, player)
	end)

	model.PrimaryPart = floor
	model.Parent = rootFolder or Workspace
	rt.Model = model
	rt.RootPart = floor
	rt.StatusLabel = lbl
	rt.Prompt = prompt
end

local function awardTakeover(rt: RestaurantRuntime, newOwner: Player): ()
	rt.Owner = newOwner
	rt.ChefHired = false
	rt.UnderRevenge = false
	rt.NextRevengeAt = os.clock() + math.random(145, 195)
	rt.NextPayoutAt = os.clock() + 18
	clearChefVisual(rt)
	PlayerDataService.AddRewards(newOwner, 350, 120, 65)
	broadcastToast(
		string.format(
			"%s CONQUERED %s (+350G, +65 Rep)! Hire a Chef (%dG) to start selling food here — watch out for Mafia Revenge!",
			newOwner.DisplayName,
			rt.Spec.DisplayName,
			rt.Spec.ChefHireCost
		),
		nil
	)
	refreshRestaurantSign(rt)
	if onChangedCb then onChangedCb(newOwner) end
end

function MafiaRestaurantService.TriggerRevengeRaid(restId: string): (boolean, string)
	local rt = runtimes[restId]
	if not rt or not rt.Owner or not rt.Owner.Parent then
		return false, "Restaurant is not currently owned by a player!"
	end
	if rt.UnderRevenge then
		return false, "Revenge Raid already underway!"
	end
	rt.UnderRevenge = true
	rt.RevengeEndsAt = os.clock() + 55
	clearUnits(rt.RevengeSquad)
	local basePos = rt.Spec.Position
	table.insert(rt.RevengeSquad, buildApexUnit(rt, false, true, basePos + Vector3.new(-16, 3.8, 18)))
	table.insert(rt.RevengeSquad, buildApexUnit(rt, false, true, basePos + Vector3.new(16, 3.8, 18)))
	table.insert(rt.RevengeSquad, buildApexUnit(rt, false, true, basePos + Vector3.new(-7, 3.8, 22)))
	table.insert(rt.RevengeSquad, buildApexUnit(rt, true, true, basePos + Vector3.new(7, 3.8, 22)))
	broadcastToast(
		string.format("MAFIA REVENGE RAID! %s is storming %s (55s) — Defend it or unleash your Samurai/Ninja Mafia!", rt.Spec.FactionName, rt.Spec.DisplayName),
		rt.Owner
	)
	refreshRestaurantSign(rt)
	if onChangedCb then onChangedCb(rt.Owner) end
	return true, "Mafia Revenge Raid triggered!"
end

function MafiaRestaurantService.TryHireChef(player: Player, restId: string): (boolean, string)
	local rt = runtimes[restId]
	if not rt then
		return false, "Unknown City Restaurant!"
	end
	if rt.Owner ~= player then
		return false, string.format("Defeat the %s garrison at %s first (or order your Samurai/Ninja Mafia to capture it)!", rt.Spec.FactionName, rt.Spec.DisplayName)
	end
	if rt.ChefHired then
		return false, string.format("A dedicated Chef is already cooking and selling food at %s (+%dG/18s)!", rt.Spec.DisplayName, rt.Spec.CycleGold)
	end
	if not PlayerDataService.SpendCoins(player, rt.Spec.ChefHireCost) then
		return false, string.format("Need %d Gold to hire a Chef for %s!", rt.Spec.ChefHireCost, rt.Spec.DisplayName)
	end
	rt.ChefHired = true
	rt.NextPayoutAt = os.clock() + 18
	spawnChefVisual(rt)
	refreshRestaurantSign(rt)
	if onChangedCb then onChangedCb(player) end
	return true, string.format("Hired City Chef at %s! Now cooking & selling food (+%dG & +%d Rep every 18s)!", rt.Spec.DisplayName, rt.Spec.CycleGold, rt.Spec.CycleRep)
end

function MafiaRestaurantService.TeleportToRestaurant(player: Player, restId: string): (boolean, string)
	local canTp, lockMsg = CombatLockService.CanTeleport(player)
	if not canTp then
		return false, lockMsg
	end
	local rt = runtimes[restId]
	if not rt then
		return false, "Unknown City Restaurant!"
	end
	local char = player.Character
	if not char then return false, "Character unavailable!" end
	local dest = rt.Spec.Position + Vector3.new(0, 4.5, 28)
	pcall(function() player:RequestStreamAroundAsync(dest) end)
	char:PivotTo(CFrame.lookAt(dest, rt.Spec.Position + Vector3.new(0, 4.5, 0)))
	return true, "Arrived at " .. rt.Spec.DisplayName
end

function MafiaRestaurantService.GetRestaurantPosition(restId: string): Vector3?
	local rt = runtimes[restId]
	return if rt then rt.Spec.Position else nil
end

function MafiaRestaurantService.GetActiveHostiles(restId: string): { Model }
	local out: { Model } = {}
	local rt = runtimes[restId]
	if not rt then return out end
	local list = if rt.UnderRevenge then rt.RevengeSquad else rt.Garrison
	for _, u in ipairs(list) do
		if u.Model.Parent and u.Humanoid.Health > 0 then
			table.insert(out, u.Model)
		end
	end
	return out
end

function MafiaRestaurantService.RecordUnitKiller(restId: string, killer: Player): ()
	local rt = runtimes[restId]
	if not rt then return end
	if rt.UnderRevenge then
		local alive = 0
		for _, u in ipairs(rt.RevengeSquad) do
			if u.Model.Parent and u.Humanoid.Health > 0 then alive += 1 end
		end
		if alive == 0 then
			rt.UnderRevenge = false
			rt.NextRevengeAt = os.clock() + math.random(150, 210)
			if rt.Owner and rt.Owner.Parent then
				PlayerDataService.AddRewards(rt.Owner, 450, 140, 70)
				broadcastToast(string.format("REVENGE CRUSHED! Defended %s (+450G & +70 Rep)!", rt.Spec.DisplayName), rt.Owner)
			end
			refreshRestaurantSign(rt)
			if onChangedCb then onChangedCb(rt.Owner) end
		end
	elseif rt.Owner == nil then
		local alive = 0
		for _, u in ipairs(rt.Garrison) do
			if u.Model.Parent and u.Humanoid.Health > 0 then alive += 1 end
		end
		if alive == 0 then
			awardTakeover(rt, killer)
		else
			refreshRestaurantSign(rt)
		end
	end
end

function MafiaRestaurantService.GetSnapshot(player: Player): { [string]: any }
	local list: { { [string]: any } } = {}
	local now = os.clock()
	for _, restId in ipairs(MafiaRestaurantService.ORDER) do
		local rt = runtimes[restId]
		if rt then
			local alive = 0
			local src = if rt.UnderRevenge then rt.RevengeSquad else rt.Garrison
			for _, u in ipairs(src) do
				if u.Model.Parent and u.Humanoid.Health > 0 then alive += 1 end
			end
			table.insert(list, {
				Id = rt.Spec.Id,
				DisplayName = rt.Spec.DisplayName,
				FactionName = rt.Spec.FactionName,
				OwnedByMe = (rt.Owner == player),
				OwnerName = if rt.Owner and rt.Owner.Parent then rt.Owner.DisplayName else nil,
				ChefHired = rt.ChefHired,
				ChefHireCost = rt.Spec.ChefHireCost,
				CycleGold = rt.Spec.CycleGold,
				CycleRep = rt.Spec.CycleRep,
				DefendersAlive = alive,
				UnderRevenge = rt.UnderRevenge,
				RevengeTimeLeft = if rt.UnderRevenge then math.max(0, math.ceil(rt.RevengeEndsAt - now)) else 0,
			})
		end
	end
	return list
end

local function hasPlayerStolenInCentralMarket(player: Player): boolean
	local untilAttr = player:GetAttribute("StolenShipmentUntil")
	if typeof(untilAttr) == "number" and untilAttr > os.clock() then
		return true
	end
	return player:GetAttribute("CarryingCrate") ~= nil
end

local function stepApexUnit(rt: RestaurantRuntime, u: GarrisonUnit, now: number): ()
	if not u.Model.Parent or u.Humanoid.Health <= 0 then return end
	local stunUntil = u.Model:GetAttribute("StunnedUntil")
	if typeof(stunUntil) == "number" and stunUntil > now then
		return
	end
	local isProvoked = rt.UnderRevenge or (rt.ProvokedUntil > now)
	if not isProvoked and u.Model:GetAttribute("Provoked") == true then
		u.Model:SetAttribute("Provoked", false)
	end

	local myPos = u.Root.Position
	local bestHum: Humanoid? = nil
	local bestRoot: BasePart? = nil
	local bestDist = 72

	-- Central Market Truce: Restaurant garrisons inside Central Market NEVER randomly attack peaceful visitors!
	-- They only engage if: (1) UnderRevenge raid, (2) Provoked/attacked first, or (3) Player STOLE a Central Market shipment!
	for _, tagName in ipairs({ "MercenaryMafiaUnit", "PlayerBodyguardUnit" }) do
		for _, ally in ipairs(CollectionService:GetTagged(tagName)) do
			if ally:IsA("Model") then
				local ownerUid = ally:GetAttribute("OwnerUserId")
				local ownerPlayer = if typeof(ownerUid) == "number" then Players:GetPlayerByUserId(ownerUid) else nil
				local ownerStole = (ownerPlayer ~= nil and hasPlayerStolenInCentralMarket(ownerPlayer))
				if isProvoked or ownerStole then
					local r = ally:FindFirstChild("HumanoidRootPart")
					local h = ally:FindFirstChildOfClass("Humanoid")
					if r and r:IsA("BasePart") and h and h.Health > 0 then
						local d = (r.Position - myPos).Magnitude
						if d < bestDist then
							bestDist = d; bestHum = h; bestRoot = r
						end
					end
				end
			end
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if isProvoked or hasPlayerStolenInCentralMarket(p) then
			local ch = p.Character
			local r = if ch then ch:FindFirstChild("HumanoidRootPart") else nil
			local h = if ch then ch:FindFirstChildOfClass("Humanoid") else nil
			if r and r:IsA("BasePart") and h and h.Health > 0 then
				local smokeUntil = p:GetAttribute("InSmokeUntil")
				local maxSight = if typeof(smokeUntil) == "number" and smokeUntil > now then 16 else bestDist
				local d = (r.Position - myPos).Magnitude
				if d < maxSight then
					bestDist = d; bestHum = h; bestRoot = r
				end
			end
		end
	end

	if bestHum and bestRoot then
		local isBladeSquad = (rt.Spec.BladeStyle ~= nil)
		local closeThreshold = if isBladeSquad then 10 else 18
		if bestDist > closeThreshold then
			u.Humanoid:MoveTo(bestRoot.Position)
		end
		local targetModel = bestRoot.Parent
		local victimPlayer = if targetModel and targetModel:IsA("Model") then Players:GetPlayerFromCharacter(targetModel) else nil
		if bestDist <= 14 and isBladeSquad and rt.Spec.BladeStyle and (now - u.LastShotAt) >= 0.85 then
			u.LastShotAt = now
			MafiaVisualBuilder.TriggerAttackAnim(u.Model)
			if victimPlayer then
				CombatLockService.MarkUnderAttack(victimPlayer, myPos, rt.Spec.FactionName)
			end
			bestHum:TakeDamage(u.Damage)
			local clashPoint = (myPos + bestRoot.Position) * 0.5 + Vector3.new(0, 1.5, 0)
			local targetStyle = if targetModel then tostring(targetModel:GetAttribute("MercenaryType") or targetModel:GetAttribute("BladeStyle") or "Samurai") else "Samurai"
			BlackMarketService.SpawnBladeClashVFX(clashPoint, rt.Spec.BladeStyle, targetStyle)
			local slashCol = if rt.Spec.BladeStyle == "Ninja" then Color3.fromRGB(168, 184, 214) else Color3.fromRGB(204, 48, 56)
			BlackMarketService.SpawnBulletTracer(myPos + Vector3.new(0, 1.5, 0), bestRoot.Position, slashCol)
			BlackMarketService.BroadcastSFX("MeleeHit", clashPoint)
		elseif bestDist <= 68 and (now - u.LastShotAt) >= 0.95 then
			u.LastShotAt = now
			MafiaVisualBuilder.TriggerAttackAnim(u.Model)
			if victimPlayer then
				CombatLockService.MarkUnderAttack(victimPlayer, myPos, rt.Spec.FactionName)
			end
			bestHum:TakeDamage(u.Damage)
			BlackMarketService.SpawnBulletTracer(myPos + Vector3.new(0, 1.5, 0), bestRoot.Position, Color3.fromRGB(224, 72, 64))
			BlackMarketService.BroadcastSFX("SMGShot", myPos)
		end
	else
		local anchor = rt.Spec.Position + Vector3.new(0, 3.8, 12)
		if (anchor - myPos).Magnitude > 14 then
			u.Humanoid:MoveTo(anchor)
		end
	end
end

function MafiaRestaurantService.Start(): ()
	if isRunning then return end
	isRunning = true

	local existing = Workspace:FindFirstChild("MafiaRestaurants")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		rootFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "MafiaRestaurants"
		f.Parent = Workspace
		rootFolder = f
	end

	local existingUnits = Workspace:FindFirstChild("ApexMafiaUnits")
	if existingUnits and existingUnits:IsA("Folder") then
		existingUnits:ClearAllChildren()
		unitFolder = existingUnits
	else
		local f = Instance.new("Folder")
		f.Name = "ApexMafiaUnits"
		f.Parent = Workspace
		unitFolder = f
	end

	for _, restId in ipairs(MafiaRestaurantService.ORDER) do
		local spec = MafiaRestaurantService.SPECS[restId]
		local rt: RestaurantRuntime = {
			Spec = spec,
			Owner = nil,
			ChefHired = false,
			ChefModel = nil,
			UnderRevenge = false,
			RevengeEndsAt = 0,
			NextRevengeAt = 0,
			NextPayoutAt = 0,
			ProvokedUntil = 0,
			Garrison = {},
			RevengeSquad = {},
			StatusLabel = nil,
			Prompt = nil,
			RootPart = nil,
			Model = nil,
		}
		runtimes[restId] = rt
		buildRestaurantBuilding(rt)
		spawnGarrisonForRestaurant(rt)
	end

	BlackMarketService.OnHostileKilled(function(killer: Player, hitModel: Model)
		local rid = hitModel:GetAttribute("MafiaRestaurantId")
		if typeof(rid) == "string" then
			MafiaRestaurantService.RecordUnitKiller(rid, killer)
		end
	end)

	Players.PlayerRemoving:Connect(function(p: Player)
		for _, rt in pairs(runtimes) do
			if rt.Owner == p then
				rt.Owner = nil
				rt.ChefHired = false
				rt.UnderRevenge = false
				clearChefVisual(rt)
				clearUnits(rt.RevengeSquad)
				spawnGarrisonForRestaurant(rt)
			end
		end
	end)

	aiThread = task.spawn(function()
		while isRunning do
			task.wait(0.65)
			if not isRunning then break end
			local now = os.clock()
			for _, rt in pairs(runtimes) do
				-- Step Garrison or Revenge Raiders
				if rt.UnderRevenge then
					local alive = 0
					for _, u in ipairs(rt.RevengeSquad) do
						if u.Model.Parent and u.Humanoid.Health > 0 then
							alive += 1
							stepApexUnit(rt, u, now)
						end
					end
					if alive == 0 then
						rt.UnderRevenge = false
						rt.NextRevengeAt = now + math.random(150, 210)
						if rt.Owner and rt.Owner.Parent then
							PlayerDataService.AddRewards(rt.Owner, 450, 140, 70)
							broadcastToast(string.format("REVENGE CRUSHED! Defended %s (+450G & +70 Rep)!", rt.Spec.DisplayName), rt.Owner)
						end
						refreshRestaurantSign(rt)
						if onChangedCb then onChangedCb(rt.Owner) end
					elseif now >= rt.RevengeEndsAt then
						-- Mafia Revenge succeeded: Mafia retakes the restaurant!
						local prevOwner = rt.Owner
						rt.Owner = nil
						rt.ChefHired = false
						rt.UnderRevenge = false
						clearChefVisual(rt)
						clearUnits(rt.RevengeSquad)
						spawnGarrisonForRestaurant(rt)
						if prevOwner and prevOwner.Parent then
							broadcastToast(string.format("REVENGE LOST! %s retook %s! Regroup or hire Samurai/Ninja Mafia to reclaim it!", rt.Spec.FactionName, rt.Spec.DisplayName), prevOwner)
						end
						if onChangedCb then onChangedCb(prevOwner) end
					else
						refreshRestaurantSign(rt)
					end
				elseif rt.Owner and rt.Owner.Parent then
					-- Passive Chef Cooking & Selling income
					if rt.ChefHired and now >= rt.NextPayoutAt then
						rt.NextPayoutAt = now + 18
						PlayerDataService.AddRewards(rt.Owner, rt.Spec.CycleGold, 35, rt.Spec.CycleRep)
					end
					-- Periodic Mafia Revenge Counter-Attack!
					if rt.NextRevengeAt > 0 and now >= rt.NextRevengeAt then
						MafiaRestaurantService.TriggerRevengeRaid(rt.Spec.Id)
					end
				else
					for _, u in ipairs(rt.Garrison) do
						if u.Model.Parent and u.Humanoid.Health > 0 then
							stepApexUnit(rt, u, now)
						end
					end
				end
			end
		end
	end)

	print("[Food Empire] MafiaRestaurantService started (3 Apex Mafia-Controlled City Restaurants + Takeover, Chef Hiring & Revenge Raids active)!")
end

function MafiaRestaurantService.Stop(): ()
	isRunning = false
	if aiThread then task.cancel(aiThread); aiThread = nil end
	for _, rt in pairs(runtimes) do
		clearUnits(rt.Garrison)
		clearUnits(rt.RevengeSquad)
		clearChefVisual(rt)
	end
	table.clear(runtimes)
end

return MafiaRestaurantService
