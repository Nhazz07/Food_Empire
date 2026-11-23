--!strict

-- SyndicateContractService:
--  1. Mafia Reputation Ranks (6 progression tiers from Street Runner -> Food Emperor Don) granting
--     passive Dish Payout multipliers (+0% to +45%) and Max HP bonuses (+0 to +75 HP).
--  2. 3 Rotating Syndicate Contracts per player with live progress tracking and instant Gold/Rep payouts.
--  3. High-Value Smuggler Convoy Escort Missions: spawns an armored 3D supply transport from a Corner Hub
--     to Central Plaza while hostile Rival Ambushers attempt to intercept it.
--  4. Gang War Contraband Drop Skirmishes: contested central contraband crate guarded by armed enforcers.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local WeaponConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WeaponConfig")
)
local RivalFactionConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RivalFactionConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local WarehouseService = require("./WarehouseService")

export type RankSpec = {
	Tier: number,
	Title: string,
	MinRep: number,
	PayoutBonus: number,
	BonusMaxHP: number,
}

export type ContractKind =
	"CookDishes"
	| "EliminateHostiles"
	| "StockWarehouse"
	| "SpecialtyFeast"
	| "ConvoyOrRunner"
	| "EmpireExpansion"

export type ContractTemplate = {
	Id: string,
	Kind: ContractKind,
	Title: string,
	Description: string,
	Goal: number,
	RewardGold: number,
	RewardRep: number,
	RewardExp: number,
}

export type ActiveContract = {
	SlotIndex: number,
	TemplateId: string,
	Kind: ContractKind,
	Title: string,
	Description: string,
	Progress: number,
	Goal: number,
	RewardGold: number,
	RewardRep: number,
	RewardExp: number,
	Completed: boolean,
}

local SyndicateContractService = {}

SyndicateContractService.RANKS = {
	{ Tier = 1, Title = "STREET RUNNER", MinRep = 0, PayoutBonus = 0.00, BonusMaxHP = 0 },
	{ Tier = 2, Title = "SYNDICATE ASSOCIATE", MinRep = 75, PayoutBonus = 0.06, BonusMaxHP = 10 },
	{ Tier = 3, Title = "SOLDIER ENFORCER", MinRep = 200, PayoutBonus = 0.12, BonusMaxHP = 20 },
	{ Tier = 4, Title = "CAPOREGIME", MinRep = 450, PayoutBonus = 0.20, BonusMaxHP = 35 },
	{ Tier = 5, Title = "UNDERBOSS", MinRep = 850, PayoutBonus = 0.30, BonusMaxHP = 50 },
	{ Tier = 6, Title = "FOOD EMPEROR DON", MinRep = 1500, PayoutBonus = 0.45, BonusMaxHP = 75 },
} :: { RankSpec }

local CONTRACT_TEMPLATES: { ContractTemplate } = {
	{
		Id = "CookDishes_3",
		Kind = "CookDishes",
		Title = "CULINARY HUSTLE",
		Description = "Cook and serve 3 dishes from your Restaurant Kitchen.",
		Goal = 3,
		RewardGold = 220,
		RewardRep = 35,
		RewardExp = 55,
	},
	{
		Id = "EliminateHostiles_3",
		Kind = "EliminateHostiles",
		Title = "STREET ENFORCEMENT",
		Description = "Eliminate 3 Rival Syndicate or Food Mafia units.",
		Goal = 3,
		RewardGold = 280,
		RewardRep = 45,
		RewardExp = 70,
	},
	{
		Id = "StockWarehouse_10",
		Kind = "StockWarehouse",
		Title = "SUPPLY LOGISTICS",
		Description = "Deliver or store 10 fresh ingredients into your Warehouses.",
		Goal = 10,
		RewardGold = 240,
		RewardRep = 38,
		RewardExp = 60,
	},
	{
		Id = "SpecialtyFeast_2",
		Kind = "SpecialtyFeast",
		Title = "HIGH-ROLLER CUISINE",
		Description = "Cook 2 high-tier specialty platters (Sushi, Steak, Crab, or Tuna).",
		Goal = 2,
		RewardGold = 320,
		RewardRep = 50,
		RewardExp = 80,
	},
	{
		Id = "ConvoyOrRunner_1",
		Kind = "ConvoyOrRunner",
		Title = "ARMORED CONVOY ESCORT",
		Description = "Complete 1 Smuggler Convoy Escort or Motorbike Express Run.",
		Goal = 1,
		RewardGold = 350,
		RewardRep = 55,
		RewardExp = 85,
	},
	{
		Id = "EmpireExpansion_1",
		Kind = "EmpireExpansion",
		Title = "SYNDICATE EXPANSION",
		Description = "Hire staff, upgrade a Warehouse/HQ, or expand your Bistro.",
		Goal = 1,
		RewardGold = 260,
		RewardRep = 42,
		RewardExp = 65,
	},
}

local CONVOY_START_POINTS = {
	{ Name = "Fishing Port Docks", Category = "Fish" :: WarehouseConfig.WarehouseCategory, Pos = Vector3.new(260, 4.5, 260) },
	{ Name = "Highland Meat Ranch", Category = "Meat" :: WarehouseConfig.WarehouseCategory, Pos = Vector3.new(260, 4.5, -260) },
	{ Name = "Emerald Veg Farm", Category = "Vegetable" :: WarehouseConfig.WarehouseCategory, Pos = Vector3.new(-260, 4.5, -260) },
	{ Name = "Sunset Fruit Orchard", Category = "Fruit" :: WarehouseConfig.WarehouseCategory, Pos = Vector3.new(-260, 4.5, 260) },
}

local CONVOY_DEST = Vector3.new(0, 4.5, -24)
local CONVOY_COOLDOWN = 22
local GANG_WAR_POS = Vector3.new(-48, 1.35, -36)
local GANG_WAR_COOLDOWN = 30

local isRunning = false
local playerContracts: { [Player]: { ActiveContract } } = {}
local playerTemplateCursor: { [Player]: number } = {}
local playerRankTier: { [Player]: number } = {}
local activeConvoys: { [Player]: Model } = {}
local convoyCooldownUntil: { [Player]: number } = {}
local activeGangWarModel: Model? = nil
local gangWarGuards: { Model } = {}
local gangWarCooldownUntil = 0
local serviceFolder: Folder? = nil
local onChangedCb: ((Player) -> ())? = nil
local unsubProfile: (() -> ())? = nil

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

function SyndicateContractService.SetChangedCallback(cb: (Player) -> ()): ()
	onChangedCb = cb
end

local function notifyPlayer(player: Player): ()
	if onChangedCb and player.Parent then
		onChangedCb(player)
	end
end

function SyndicateContractService.GetRankSpecForRep(rep: number): (RankSpec, RankSpec?)
	local current = SyndicateContractService.RANKS[1]
	local nextRank: RankSpec? = nil
	for i, spec in ipairs(SyndicateContractService.RANKS) do
		if rep >= spec.MinRep then
			current = spec
			nextRank = SyndicateContractService.RANKS[i + 1]
		else
			if not nextRank then
				nextRank = spec
			end
			break
		end
	end
	return current, nextRank
end

function SyndicateContractService.GetRankPayoutMultiplier(player: Player): number
	local rep = PlayerDataService.GetProfile(player).Reputation
	local cur = SyndicateContractService.GetRankSpecForRep(rep)
	return 1.0 + cur.PayoutBonus
end

local function applyRankHealthBonus(player: Player, rankSpec: RankSpec): ()
	local char = player.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not hum or hum.Health <= 0 then
		return
	end
	local targetMax = 100 + rankSpec.BonusMaxHP
	if hum.MaxHealth < targetMax then
		local diff = targetMax - hum.MaxHealth
		hum.MaxHealth = targetMax
		hum.Health = math.min(targetMax, hum.Health + diff)
	end
end

local function pickNextTemplate(player: Player, usedIds: { [string]: boolean }): ContractTemplate
	local cursor = (playerTemplateCursor[player] or 0)
	for offset = 1, #CONTRACT_TEMPLATES do
		local idx = ((cursor + offset - 1) % #CONTRACT_TEMPLATES) + 1
		local cand = CONTRACT_TEMPLATES[idx]
		if not usedIds[cand.Id] then
			playerTemplateCursor[player] = idx
			return cand
		end
	end
	playerTemplateCursor[player] = (cursor % #CONTRACT_TEMPLATES) + 1
	return CONTRACT_TEMPLATES[playerTemplateCursor[player]]
end

local function makeContractFromTemplate(slotIndex: number, tpl: ContractTemplate): ActiveContract
	return {
		SlotIndex = slotIndex,
		TemplateId = tpl.Id,
		Kind = tpl.Kind,
		Title = tpl.Title,
		Description = tpl.Description,
		Progress = 0,
		Goal = tpl.Goal,
		RewardGold = tpl.RewardGold,
		RewardRep = tpl.RewardRep,
		RewardExp = tpl.RewardExp,
		Completed = false,
	}
end

local function ensureContracts(player: Player): { ActiveContract }
	local existing = playerContracts[player]
	if existing and #existing == 3 then
		return existing
	end
	local used: { [string]: boolean } = {}
	local list: { ActiveContract } = {}
	for slot = 1, 3 do
		local tpl = pickNextTemplate(player, used)
		used[tpl.Id] = true
		table.insert(list, makeContractFromTemplate(slot, tpl))
	end
	playerContracts[player] = list
	return list
end

function SyndicateContractService.RecordProgress(player: Player, kind: ContractKind, amount: number?): ()
	if not player or not player.Parent then
		return
	end
	local list = ensureContracts(player)
	local delta = math.max(1, math.floor(amount or 1))
	local changed = false

	for _, c in ipairs(list) do
		if c.Kind == kind and not c.Completed then
			c.Progress = math.min(c.Goal, c.Progress + delta)
			changed = true
			if c.Progress >= c.Goal then
				c.Completed = true
				-- Automatically credit contract reward and rotate a fresh contract after a brief moment,
				-- or let player also claim manually from Empire menu!
				PlayerDataService.AddRewards(player, c.RewardGold, c.RewardExp, c.RewardRep)
				sendToast(
					player,
					string.format("CONTRACT COMPLETE: %s (+%d Gold, +%d Rep)!", c.Title, c.RewardGold, c.RewardRep)
				)
				local slotIdx = c.SlotIndex
				task.delay(2.5, function()
					if not player.Parent then return end
					local curList = playerContracts[player]
					if not curList then return end
					local curEntry = curList[slotIdx]
					if curEntry and curEntry.Completed then
						local used: { [string]: boolean } = {}
						for _, other in ipairs(curList) do
							used[other.TemplateId] = true
						end
						local nextTpl = pickNextTemplate(player, used)
						curList[slotIdx] = makeContractFromTemplate(slotIdx, nextTpl)
						notifyPlayer(player)
					end
				end)
			end
		end
	end

	if changed then
		notifyPlayer(player)
	end
end

function SyndicateContractService.ClaimOrRerollContract(player: Player, slotIndex: number): (boolean, string)
	local list = ensureContracts(player)
	local entry = list[slotIndex]
	if not entry then
		return false, "Invalid contract slot"
	end

	local used: { [string]: boolean } = {}
	for _, other in ipairs(list) do
		used[other.TemplateId] = true
	end
	local nextTpl = pickNextTemplate(player, used)
	list[slotIndex] = makeContractFromTemplate(slotIndex, nextTpl)
	notifyPlayer(player)
	return true, string.format("Assigned new Syndicate Contract: %s!", nextTpl.Title)
end

-- Spawns a high-value 3D Armored Smuggler Convoy from a Corner Supply Hub to Central Plaza with 2 Rival Ambushers!
function SyndicateContractService.StartSmugglerConvoy(player: Player): (boolean, string)
	if not BaseService.GetPlayerBaseSlot(player) then
		return false, "Claim your Restaurant Plaza Base first!"
	end
	local existing = activeConvoys[player]
	if existing and existing.Parent then
		return false, "Your Smuggler Convoy is already en route to Central Plaza!"
	end
	local now = os.clock()
	local cdUntil = convoyCooldownUntil[player] or 0
	if cdUntil > now then
		return false, string.format("Next Smuggler Convoy ready in %ds!", math.ceil(cdUntil - now))
	end

	convoyCooldownUntil[player] = now + CONVOY_COOLDOWN
	local route = CONVOY_START_POINTS[math.random(1, #CONVOY_START_POINTS)]
	local teamCol = Color3.fromRGB(168, 138, 76)
	local rig, cratePart = MafiaVisualBuilder.BuildMotorbikeCourierRig(
		"SmugglerConvoy_" .. tostring(player.UserId),
		teamCol,
		1.18,
		CFrame.lookAt(route.Pos, CONVOY_DEST)
	)
	local convoy = rig.Model
	local root = rig.Root
	cratePart.Color = Color3.fromRGB(168, 138, 76)
	cratePart.Transparency = 0

	-- Add extra armored side-panniers so the Smuggler Convoy looks heavy and distinct
	rig.AddPart(root, "ArmoredPannierL", Vector3.new(0.55, 1.15, 1.75), CFrame.new(-1.18, -0.65, 2.2), Color3.fromRGB(36, 40, 48), Enum.Material.Metal, nil)
	rig.AddPart(root, "ArmoredPannierR", Vector3.new(0.55, 1.15, 1.75), CFrame.new(1.18, -0.65, 2.2), Color3.fromRGB(36, 40, 48), Enum.Material.Metal, nil)

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 320
	hum.Health = 320
	hum.WalkSpeed = 25
	hum.HipHeight = 3.65
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = convoy

	local bb = Instance.new("BillboardGui")
	bb.Name = "ConvoyBadge"
	bb.Size = UDim2.fromOffset(238, 44)
	bb.StudsOffset = Vector3.new(0, 3.6, 0)
	bb.MaxDistance = 260
	bb.Parent = rig.Head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 22)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "SMUGGLER CONVOY  |  ESCORT TO PLAZA"
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.fromRGB(228, 198, 122)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)

	local hpBg = Instance.new("Frame")
	hpBg.Position = UDim2.new(0.06, 0, 0, 26)
	hpBg.Size = UDim2.new(0.88, 0, 0, 10)
	hpBg.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
	hpBg.Parent = bb
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 3)

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(78, 148, 96)
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 3)

	hum.HealthChanged:Connect(function(hp: number)
		hpFill.Size = UDim2.fromScale(math.clamp(hp / 320, 0, 1), 1)
	end)

	convoy.PrimaryPart = root
	convoy:SetAttribute("OwnerUserId", player.UserId)
	convoy:SetAttribute("Faction", "Player_" .. tostring(player.UserId))
	CollectionService:AddTag(convoy, "PlayerDeliveryRunner")
	convoy.Parent = serviceFolder or Workspace
	activeConvoys[player] = convoy

	-- Spawn 1 Highway Ambusher mid-route to challenge the convoy escort
	local midPoint = route.Pos:Lerp(CONVOY_DEST, 0.55) + Vector3.new(14, 0, -12)
	local ambRig = MafiaVisualBuilder.BuildRivalRig(
		"ConvoyAmbusher",
		"HarborHookCartel",
		false,
		1.04,
		CFrame.lookAt(midPoint, CONVOY_DEST),
		false
	)
	local ambModel = ambRig.Model
	local ambHum = Instance.new("Humanoid")
	ambHum.MaxHealth = 160
	ambHum.Health = 160
	ambHum.WalkSpeed = 18
	ambHum.HipHeight = 2.45
	ambHum.BreakJointsOnDeath = false
	ambHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	ambHum.Parent = ambModel
	ambModel.PrimaryPart = ambRig.Root
	ambModel:SetAttribute("Faction", "Rival")
	ambModel:SetAttribute("RivalTitle", "HIGHWAY AMBUSHER")
	ambModel:SetAttribute("BountyGold", 95)
	ambModel:SetAttribute("BountyExp", 35)
	ambModel:SetAttribute("BountyRep", 20)
	CollectionService:AddTag(ambModel, "RivalAIUnit")
	ambModel.Parent = serviceFolder or Workspace
	ambHum.Died:Connect(function()
		MafiaVisualBuilder.PlayDeathSequence(ambModel, false, nil)
		if player.Parent then
			SyndicateContractService.RecordProgress(player, "EliminateHostiles", 1)
		end
	end)

	task.spawn(function()
		local startedAt = os.clock()
		while isRunning and convoy.Parent and hum.Health > 0 and player.Parent do
			local pos = root.Position
			local dist = Vector3.new(CONVOY_DEST.X - pos.X, 0, CONVOY_DEST.Z - pos.Z).Magnitude
			if dist <= 16 or (os.clock() - startedAt) >= 24 then
				-- Arrived safely at Central Plaza!
				PlayerDataService.AddRewards(player, 420, 95, 65)
				local spec = WarehouseConfig.Specs[route.Category]
				if spec then
					for i = 1, 8 do
						local ing = spec.Ingredients[((i - 1) % #spec.Ingredients) + 1]
						if ing ~= "golden_tuna" and ing ~= "king_crab" then
							WarehouseService.AddIngredient(player, ing, 1)
						end
					end
				end
				for _, aid in ipairs(WeaponConfig.AMMO_ORDER) do
					local aSpec = WeaponConfig.AMMO_TYPES[aid]
					if aSpec then
						PlayerDataService.AddAmmo(player, aid, 24, aSpec.MaxReserve)
					end
				end
				SyndicateContractService.RecordProgress(player, "ConvoyOrRunner", 1)
				SyndicateContractService.RecordProgress(player, "StockWarehouse", 8)
				sendToast(player, "SMUGGLER CONVOY ARRIVED! +420 Gold, +65 Rep, +8 Ingredients & Ammo Resupply!")
				if ambModel.Parent then ambModel:Destroy() end
				convoy:Destroy()
				activeConvoys[player] = nil
				notifyPlayer(player)
				return
			end

			hum:MoveTo(CONVOY_DEST)
			if ambModel.Parent and ambHum.Health > 0 then
				ambHum:MoveTo(pos)
				if (ambRig.Root.Position - pos).Magnitude <= 14 then
					hum:TakeDamage(10)
				end
			end
			task.wait(0.45)
		end

		if ambModel.Parent then
			ambModel:Destroy()
		end
		if convoy.Parent then
			MafiaVisualBuilder.PlayDeathSequence(convoy, false, nil)
		end
		activeConvoys[player] = nil
		if player.Parent then
			sendToast(player, "Your Smuggler Convoy was destroyed! Escort it on your Motorbike with Bodyguards.")
			notifyPlayer(player)
		end
	end)

	notifyPlayer(player)
	return true, string.format("Smuggler Convoy departed %s! Escort it to Central Plaza (+420G & +65 Rep).", route.Name)
end

-- Spawns a contested Gang War Contraband Supply Drop in Central District guarded by 2 Rival Enforcers!
function SyndicateContractService.StartGangWarDrop(requestingPlayer: Player?): (boolean, string)
	if activeGangWarModel and activeGangWarModel.Parent then
		if requestingPlayer and requestingPlayer.Character then
			requestingPlayer.Character:PivotTo(CFrame.lookAt(GANG_WAR_POS + Vector3.new(0, 4.5, -18), GANG_WAR_POS))
		end
		return true, "Gang War Contraband Drop is active in Central District! Eliminate guards & claim [E]!"
	end

	local now = os.clock()
	if gangWarCooldownUntil > now then
		return false, string.format("Next Gang War Contraband Drop arrives in %ds!", math.ceil(gangWarCooldownUntil - now))
	end
	gangWarCooldownUntil = now + GANG_WAR_COOLDOWN

	for _, g in ipairs(gangWarGuards) do
		if g.Parent then g:Destroy() end
	end
	table.clear(gangWarGuards)

	local m = Instance.new("Model")
	m.Name = "GangWarContrabandDrop"
	local baseCF = CFrame.new(GANG_WAR_POS)

	local pallet = Instance.new("Part")
	pallet.Name = "CratePallet"
	pallet.Size = Vector3.new(6.4, 0.5, 4.8)
	pallet.CFrame = baseCF * CFrame.new(0, 0.25, 0)
	pallet.Color = Color3.fromRGB(58, 42, 30)
	pallet.Material = Enum.Material.WoodPlanks
	pallet.Anchored = true
	pallet.Parent = m

	local chest = Instance.new("Part")
	chest.Name = "ContrabandChest"
	chest.Size = Vector3.new(5.2, 3.2, 3.6)
	chest.CFrame = baseCF * CFrame.new(0, 2.1, 0)
	chest.Color = Color3.fromRGB(24, 27, 34)
	chest.Material = Enum.Material.Metal
	chest.Anchored = true
	chest.Parent = m

	local band = Instance.new("Part")
	band.Name = "BrassStrap"
	band.Size = Vector3.new(5.3, 0.45, 3.7)
	band.CFrame = baseCF * CFrame.new(0, 2.3, 0)
	band.Color = Color3.fromRGB(168, 138, 76)
	band.Material = Enum.Material.Metal
	band.Anchored = true
	band.CanCollide = false
	band.Parent = m

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 44)
	bb.StudsOffset = Vector3.new(0, 4.2, 0)
	bb.MaxDistance = 260
	bb.Parent = chest

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = "GANG WAR CONTRABAND DROP\n+380G  |  +55 REP  |  100 ARMOR  [E]"
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.fromRGB(228, 198, 122)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 5)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(134, 28, 36)
	st.Thickness = 1.2
	st.Parent = lbl

	-- Spawn 2 Elite Gang War Enforcers guarding the contraband chest
	for idx = 1, 2 do
		local guardPos = GANG_WAR_POS + Vector3.new(if idx == 1 then -6 else 6, 2.5, -5)
		local gRig = MafiaVisualBuilder.BuildRivalRig(
			"GangWarEnforcer_" .. tostring(idx),
			"ObsidianKnifeOrder",
			false,
			1.08,
			CFrame.lookAt(guardPos, GANG_WAR_POS + Vector3.new(0, 2.5, -18)),
			false
		)
		local gModel = gRig.Model
		local gHum = Instance.new("Humanoid")
		gHum.MaxHealth = 220
		gHum.Health = 220
		gHum.WalkSpeed = 16
		gHum.HipHeight = 2.45
		gHum.BreakJointsOnDeath = false
		gHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		gHum.Parent = gModel
		gModel.PrimaryPart = gRig.Root
		gModel:SetAttribute("Faction", "Rival")
		gModel:SetAttribute("RivalTitle", "CONTRABAND ENFORCER")
		gModel:SetAttribute("BountyGold", 110)
		gModel:SetAttribute("BountyExp", 40)
		gModel:SetAttribute("BountyRep", 25)
		CollectionService:AddTag(gModel, "RivalAIUnit")
		gModel.Parent = serviceFolder or Workspace
		gHum.Died:Connect(function()
			MafiaVisualBuilder.PlayDeathSequence(gModel, false, nil)
		end)
		table.insert(gangWarGuards, gModel)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SeizeContrabandPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.ActionText = "Seize Syndicate Contraband"
	prompt.ObjectText = "Gang War Supply Drop"
	prompt.Parent = chest

	prompt.Triggered:Connect(function(winner: Player)
		if not m.Parent then return end
		m:Destroy()
		activeGangWarModel = nil
		for _, g in ipairs(gangWarGuards) do
			if g.Parent then g:Destroy() end
		end
		table.clear(gangWarGuards)

		PlayerDataService.AddRewards(winner, 380, 90, 55)
		PlayerDataService.SetArmor(winner, 100)
		for _, cat in ipairs(WarehouseConfig.Categories) do
			local spec = WarehouseConfig.Specs[cat]
			if spec and WarehouseService.IsUnlocked(winner, cat) then
				WarehouseService.AddIngredient(winner, spec.Ingredients[1], 3)
			end
		end
		SyndicateContractService.RecordProgress(winner, "ConvoyOrRunner", 1)
		broadcastToast(string.format("GANG WAR DROP SEIZED by %s (+380 Gold, +55 Rep & 100 Kevlar)!", winner.DisplayName))
		for _, p in ipairs(Players:GetPlayers()) do
			notifyPlayer(p)
		end
	end)

	m.PrimaryPart = chest
	m.Parent = serviceFolder or Workspace
	activeGangWarModel = m

	if requestingPlayer and requestingPlayer.Character then
		pcall(function()
			requestingPlayer:RequestStreamAroundAsync(GANG_WAR_POS)
		end)
		requestingPlayer.Character:PivotTo(CFrame.lookAt(GANG_WAR_POS + Vector3.new(0, 4.5, -18), GANG_WAR_POS))
	end

	broadcastToast("GANG WAR CONTRABAND DROP landed in Central District! Fight off the enforcers & claim [E]!")
	for _, p in ipairs(Players:GetPlayers()) do
		notifyPlayer(p)
	end
	return true, "Warped to the Gang War Contraband Drop! Defeat the enforcers and press [E] to seize!"
end

function SyndicateContractService.GetSnapshot(player: Player): { [string]: any }
	local prof = PlayerDataService.GetProfile(player)
	local curRank, nextRank = SyndicateContractService.GetRankSpecForRep(prof.Reputation)
	local list = ensureContracts(player)
	local contractsOut = {}
	for _, c in ipairs(list) do
		table.insert(contractsOut, {
			SlotIndex = c.SlotIndex,
			Title = c.Title,
			Description = c.Description,
			Progress = c.Progress,
			Goal = c.Goal,
			RewardGold = c.RewardGold,
			RewardRep = c.RewardRep,
			Completed = c.Completed,
		})
	end

	local now = os.clock()
	local convoyActive = activeConvoys[player] ~= nil and (activeConvoys[player] :: Model).Parent ~= nil
	local convoyCd = math.max(0, math.ceil((convoyCooldownUntil[player] or 0) - now))
	local gangWarActive = activeGangWarModel ~= nil and (activeGangWarModel :: Model).Parent ~= nil
	local gangWarCd = math.max(0, math.ceil(gangWarCooldownUntil - now))

	return {
		RankTier = curRank.Tier,
		RankTitle = curRank.Title,
		PayoutBonusPct = math.floor(curRank.PayoutBonus * 100 + 0.5),
		BonusMaxHP = curRank.BonusMaxHP,
		NextRankTitle = if nextRank then nextRank.Title else "MAX RANK",
		NextRankRep = if nextRank then nextRank.MinRep else curRank.MinRep,
		Contracts = contractsOut,
		ConvoyActive = convoyActive,
		ConvoyCooldown = convoyCd,
		GangWarActive = gangWarActive,
		GangWarCooldown = gangWarCd,
	}
end

function SyndicateContractService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local f = Workspace:FindFirstChild("SyndicateOperations")
	if f and f:IsA("Folder") then
		f:ClearAllChildren()
		serviceFolder = f
	else
		local created = Instance.new("Folder")
		created.Name = "SyndicateOperations"
		created.Parent = Workspace
		serviceFolder = created
	end

	unsubProfile = PlayerDataService.OnProfileChanged(function(player, profile)
		local rankSpec = SyndicateContractService.GetRankSpecForRep(profile.Reputation)
		local prevTier = playerRankTier[player] or 1
		if rankSpec.Tier > prevTier then
			playerRankTier[player] = rankSpec.Tier
			applyRankHealthBonus(player, rankSpec)
			sendToast(
				player,
				string.format(
					"SYNDICATE PROMOTION: %s (+%d%% Dish Payout & +%d Max HP)!",
					rankSpec.Title,
					math.floor(rankSpec.PayoutBonus * 100 + 0.5),
					rankSpec.BonusMaxHP
				)
			)
		else
			playerRankTier[player] = rankSpec.Tier
			applyRankHealthBonus(player, rankSpec)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		ensureContracts(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.4)
			if player.Parent then
				local rankSpec = SyndicateContractService.GetRankSpecForRep(PlayerDataService.GetProfile(player).Reputation)
				applyRankHealthBonus(player, rankSpec)
			end
		end)
	end)

	for _, p in ipairs(Players:GetPlayers()) do
		ensureContracts(p)
		local rankSpec = SyndicateContractService.GetRankSpecForRep(PlayerDataService.GetProfile(p).Reputation)
		playerRankTier[p] = rankSpec.Tier
		applyRankHealthBonus(p, rankSpec)
	end

	Players.PlayerRemoving:Connect(function(player)
		playerContracts[player] = nil
		playerTemplateCursor[player] = nil
		playerRankTier[player] = nil
		convoyCooldownUntil[player] = nil
		local c = activeConvoys[player]
		if c and c.Parent then c:Destroy() end
		activeConvoys[player] = nil
	end)

	print("[Food Empire] SyndicateContractService started (6 Mafia Ranks, 3 Live Contracts, Smuggler Convoys & Gang War Drops active)!")
end

function SyndicateContractService.Stop(): ()
	isRunning = false
	if unsubProfile then
		unsubProfile()
		unsubProfile = nil
	end
	if serviceFolder then
		serviceFolder:ClearAllChildren()
	end
end

return SyndicateContractService
