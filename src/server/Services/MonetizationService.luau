--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local MonetizationConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("MonetizationConfig")
)
local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local WeaponConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WeaponConfig")
)
local MafiaVisualBuilder = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("utils"):WaitForChild("MafiaVisualBuilder")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local WarehouseService = require("./WarehouseService")

export type AutoCookHandler = (player: Player) -> ()
export type PurchaseChangedHandler = (player: Player, message: string) -> ()

local MonetizationService = {}

local ownedPasses: { [Player]: { [string]: boolean } } = {}
local processedReceipts: { [string]: boolean } = {}
local pendingDualGrants: { [Player]: { [number]: () -> (boolean, string) } } = {}
local proVisuals: { [Player]: { Model } } = {}
local proStatusLabels: { [Player]: TextLabel } = {}
local proSparkles: { [Player]: ParticleEmitter } = {}
local lastGourmetSupplyAt: { [Player]: number } = {}

local autoCookHandler: AutoCookHandler? = nil
local purchaseChangedHandler: PurchaseChangedHandler? = nil
local mercenaryGrantHandler: ((player: Player, mercType: string) -> ())? = nil

local isRunning = false
local autoCookThread: thread? = nil
local conns: { RBXScriptConnection } = {}
local unsubscribeBase: (() -> ())? = nil

local function ensureOwned(player: Player): { [string]: boolean }
	local existing = ownedPasses[player]
	if existing then
		return existing
	end
	local tbl: { [string]: boolean } = {}
	ownedPasses[player] = tbl
	return tbl
end

function MonetizationService.SetAutoCookHandler(handler: AutoCookHandler): ()
	autoCookHandler = handler
end

function MonetizationService.SetPurchaseChangedHandler(handler: PurchaseChangedHandler): ()
	purchaseChangedHandler = handler
end

function MonetizationService.SetMercenaryGrantHandler(handler: (player: Player, mercType: string) -> ()): ()
	mercenaryGrantHandler = handler
end

function MonetizationService.HasPass(player: Player, passId: string): boolean
	local map = ownedPasses[player]
	return if map then map[passId] == true else false
end

function MonetizationService.GetOwnedMap(player: Player): { [string]: boolean }
	local map = ensureOwned(player)
	local copy: { [string]: boolean } = {}
	for k, v in pairs(map) do
		copy[k] = v
	end
	return copy
end

function MonetizationService.GetCookSpeedMultiplier(player: Player): number
	return if MonetizationService.HasPass(player, "MasterProChef") then 1.50 else 1.0
end

function MonetizationService.GetPayoutMultiplier(player: Player): number
	local mult = 1.0
	if MonetizationService.HasPass(player, "MasterProChef") then
		mult *= 1.35
	end
	if MonetizationService.HasPass(player, "DoubleEmpireVIP") then
		mult *= 2.0
	end
	return mult
end

function MonetizationService.GetRepMultiplier(player: Player): number
	return if MonetizationService.HasPass(player, "DoubleEmpireVIP") then 2.0 else 1.0
end

function MonetizationService.GetDeliveryMultiplier(player: Player): number
	return if MonetizationService.HasPass(player, "VIPEmpireStaff") then 2 else 1
end

function MonetizationService.GetBonusCrewSlots(player: Player): number
	return if MonetizationService.HasPass(player, "VIPEmpireStaff") then 2 else 0
end

local function clearProVisuals(player: Player): ()
	local list = proVisuals[player]
	if not list then
		return
	end
	for _, m in ipairs(list) do
		if m.Parent then
			m:Destroy()
		end
	end
	proVisuals[player] = nil
	proStatusLabels[player] = nil
	proSparkles[player] = nil
end

function MonetizationService.SetProChefStatus(player: Player, text: string, burstSparkles: boolean?): ()
	local lbl = proStatusLabels[player]
	if lbl and lbl.Parent then
		lbl.Text = text
	end
	if burstSparkles then
		local pe = proSparkles[player]
		if pe and pe.Parent then
			pe:Emit(16)
		end
	end
end

local function spawnProChefModel(parent: Instance, name: string, labelText: string, worldCF: CFrame, coatCol: Color3, apronCol: Color3, hasCrown: boolean): Model
	-- Check Studio NPCTemplates first so creators can replace legacy Pro Chefs with real Roblox R15 NPCs!
	local tplCandidates = if hasCrown
		then { "MasterProChef", "ProChef" }
		else { "EliteSousChef", "SousChef" }
	local customRig = MafiaVisualBuilder.TryBuildFromTemplate(tplCandidates, name, 1.08, worldCF * CFrame.new(0, 3.05, 0), false, nil)
	if customRig then
		local npc = customRig.Model
		local footOffset = math.clamp(customRig.Root.Position.Y - (customRig.LeftFoot.Position.Y - customRig.LeftFoot.Size.Y * 0.5), 2.5, 3.8)
		npc:PivotTo(worldCF * CFrame.new(0, footOffset, 0))
		customRig.Root.Anchored = true

		if hasCrown then
			local sparkles = Instance.new("ParticleEmitter")
			sparkles.Name = "CookSparkles"
			sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 224, 72), Color3.fromRGB(255, 168, 42))
			sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
			sparkles.Lifetime = NumberRange.new(0.6, 1.1)
			sparkles.Rate = 4
			sparkles.Speed = NumberRange.new(4, 9)
			sparkles.SpreadAngle = Vector2.new(120, 120)
			sparkles.Parent = customRig.RightHand
		end

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(195, if hasCrown then 54 else 30)
		bb.StudsOffset = Vector3.new(0, 3.2, 0)
		bb.MaxDistance = 105
		bb.Parent = customRig.Head

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 26)
		lbl.BackgroundColor3 = apronCol
		lbl.Font = Enum.Font.GothamBlack
		lbl.Text = labelText
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextSize = 14
		lbl.Parent = bb
		Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(24, 24, 34)
		st.Thickness = 2
		st.Parent = lbl

		if hasCrown then
			local statusLbl = Instance.new("TextLabel")
			statusLbl.Name = "ProStatusLabel"
			statusLbl.Position = UDim2.new(0, 0, 0, 30)
			statusLbl.Size = UDim2.new(1, 0, 0, 22)
			statusLbl.BackgroundColor3 = Color3.fromRGB(22, 28, 42)
			statusLbl.BackgroundTransparency = 0.1
			statusLbl.Font = Enum.Font.GothamBold
			statusLbl.Text = "Ready to Auto-Cook!"
			statusLbl.TextColor3 = Color3.fromRGB(255, 232, 132)
			statusLbl.TextSize = 11
			statusLbl.Parent = bb
			Instance.new("UICorner", statusLbl).CornerRadius = UDim.new(0, 6)
		end

		npc.PrimaryPart = customRig.Root
		CollectionService:AddTag(npc, "AnimatedKitchenChef")
		npc.Parent = parent
		return npc
	end

	local npc = Instance.new("Model")
	npc.Name = name
	local cf = worldCF * CFrame.new(0, 3.9, 0)

	local function cPart(pName: string, sz: Vector3, rel: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = pName
		p.Size = sz
		p.CFrame = cf * rel
		p.Color = col
		p.Material = mat
		if shape then p.Shape = shape end
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Parent = npc
		return p
	end

	local body = cPart("Torso", Vector3.new(2.6, 3.0, 1.5), CFrame.new(), coatCol, Enum.Material.SmoothPlastic, nil)
	cPart("Apron", Vector3.new(2.7, 1.55, 1.6), CFrame.new(0, -0.75, 0), apronCol, Enum.Material.SmoothPlastic, nil)
	local head = cPart("Head", Vector3.new(2.05, 2.05, 2.05), CFrame.new(0, 2.5, 0), Color3.fromRGB(246, 212, 178), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	cPart("EyeL", Vector3.new(0.24, 0.26, 0.12), CFrame.new(-0.36, 2.58, -0.96), Color3.fromRGB(24, 24, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	cPart("EyeR", Vector3.new(0.24, 0.26, 0.12), CFrame.new(0.36, 2.58, -0.96), Color3.fromRGB(24, 24, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	cPart("HatBand", Vector3.new(0.85, 2.1, 2.1), CFrame.new(0, 3.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(248, 246, 242), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	cPart("ProChefHat", Vector3.new(2.55, 1.7, 2.5), CFrame.new(0, 4.5, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	cPart("LeftArm", Vector3.new(0.95, 2.55, 0.95), CFrame.new(-1.8, 0.05, 0), coatCol, Enum.Material.SmoothPlastic, nil)
	cPart("RightArm", Vector3.new(0.95, 2.55, 0.95), CFrame.new(1.8, 0.25, -0.5) * CFrame.Angles(math.rad(38), 0, 0), coatCol, Enum.Material.SmoothPlastic, nil)
	local spatula = cPart("GoldenSpatulaProp", Vector3.new(0.75, 2.6, 0.18), CFrame.new(1.8, 0.85, -1.75) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(255, 212, 54), Enum.Material.Neon, nil)
	cPart("LeftLeg", Vector3.new(1.05, 2.6, 1.05), CFrame.new(-0.65, -2.65, 0), Color3.fromRGB(40, 44, 56), Enum.Material.SmoothPlastic, nil)
	cPart("RightLeg", Vector3.new(1.05, 2.6, 1.05), CFrame.new(0.65, -2.65, 0), Color3.fromRGB(40, 44, 56), Enum.Material.SmoothPlastic, nil)
	cPart("LeftBoot", Vector3.new(1.12, 0.62, 1.45), CFrame.new(-0.65, -3.75, -0.16), Color3.fromRGB(24, 26, 32), Enum.Material.SmoothPlastic, nil)
	cPart("RightBoot", Vector3.new(1.12, 0.62, 1.45), CFrame.new(0.65, -3.75, -0.16), Color3.fromRGB(24, 26, 32), Enum.Material.SmoothPlastic, nil)

	if hasCrown then
		local crown = cPart("ProCrown", Vector3.new(0.8, 2.2, 2.2), CFrame.new(0, 5.55, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 212, 54), Enum.Material.Neon, Enum.PartType.Cylinder)
		crown.CastShadow = false

		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "CookSparkles"
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 224, 72), Color3.fromRGB(255, 168, 42))
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Lifetime = NumberRange.new(0.6, 1.1)
		sparkles.Rate = 4
		sparkles.Speed = NumberRange.new(4, 9)
		sparkles.SpreadAngle = Vector2.new(120, 120)
		sparkles.Parent = spatula
	end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(195, if hasCrown then 54 else 30)
	bb.StudsOffset = Vector3.new(0, 4.3, 0)
	bb.MaxDistance = 105
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 26)
	lbl.BackgroundColor3 = apronCol
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = labelText
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextSize = 14
	lbl.Parent = bb

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = lbl

	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(24, 24, 34)
	st.Thickness = 2
	st.Parent = lbl

	if hasCrown then
		local statusLbl = Instance.new("TextLabel")
		statusLbl.Name = "ProStatusLabel"
		statusLbl.Position = UDim2.new(0, 0, 0, 30)
		statusLbl.Size = UDim2.new(1, 0, 0, 22)
		statusLbl.BackgroundColor3 = Color3.fromRGB(22, 28, 42)
		statusLbl.BackgroundTransparency = 0.1
		statusLbl.Font = Enum.Font.GothamBold
		statusLbl.Text = "🔥 Ready to Auto-Cook!"
		statusLbl.TextColor3 = Color3.fromRGB(255, 232, 132)
		statusLbl.TextSize = 11
		statusLbl.Parent = bb

		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0, 6)
		sc.Parent = statusLbl
	end

	npc.PrimaryPart = body
	CollectionService:AddTag(npc, "AnimatedKitchenChef")
	npc.Parent = parent
	return npc
end

function MonetizationService.SyncProStaffVisuals(player: Player): ()
	clearProVisuals(player)
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then
		return
	end
	local baseModel = BaseService.GetBaseModel(slot)
	local hq = if baseModel then baseModel:FindFirstChild("RestaurantHQ") else nil
	if not hq or not hq:IsA("Model") or not hq.PrimaryPart then
		return
	end

	local spawned: { Model } = {}
	local baseCF = hq.PrimaryPart.CFrame

	if MonetizationService.HasPass(player, "MasterProChef") then
		local master = spawnProChefModel(
			hq,
			"MasterProChef_NPC",
			"MASTER PRO CHEF",
			baseCF * CFrame.new(-20, 1.6, -24.5),
			Color3.fromRGB(255, 250, 236),
			Color3.fromRGB(238, 166, 28),
			true
		)
		local statusLbl = master:FindFirstChild("ProStatusLabel", true)
		if statusLbl and statusLbl:IsA("TextLabel") then
			proStatusLabels[player] = statusLbl
		end
		local pe = master:FindFirstChild("CookSparkles", true)
		if pe and pe:IsA("ParticleEmitter") then
			proSparkles[player] = pe
		end
		table.insert(spawned, master)
	end

	if MonetizationService.HasPass(player, "VIPEmpireStaff") then
		local sousL = spawnProChefModel(
			hq,
			"EliteSousChef_1",
			"ELITE SOUS-CHEF",
			baseCF * CFrame.new(-28, 1.6, -24.5),
			Color3.fromRGB(248, 244, 255),
			Color3.fromRGB(142, 72, 224),
			false
		)
		local sousR = spawnProChefModel(
			hq,
			"EliteSousChef_2",
			"ELITE SOUS-CHEF",
			baseCF * CFrame.new(-12, 1.6, -24.5),
			Color3.fromRGB(248, 244, 255),
			Color3.fromRGB(142, 72, 224),
			false
		)
		table.insert(spawned, sousL)
		table.insert(spawned, sousR)
	end

	proVisuals[player] = spawned
end

local function applyPassBenefitsToProfile(player: Player, itemId: string, isNewPurchase: boolean): ()
	local prof = PlayerDataService.GetProfile(player)
	if itemId == "GoldenEmperorPistolPass" then
		if not prof.OwnedWeapons.GoldenEmperorPistol then
			PlayerDataService.UnlockWeapon(player, "GoldenEmperorPistol")
		end
		if isNewPurchase then
			local ammoSpec = WeaponConfig.AMMO_TYPES.Pistol9mm
			if ammoSpec and PlayerDataService.GetAmmo(player, "Pistol9mm") < ammoSpec.StarterReserve then
				PlayerDataService.SetAmmo(player, "Pistol9mm", ammoSpec.StarterReserve, ammoSpec.MaxReserve)
			end
		end
	elseif itemId == "CrimsonDragonARPass" then
		if not prof.OwnedWeapons.CrimsonDragonAR then
			PlayerDataService.UnlockWeapon(player, "CrimsonDragonAR")
		end
		if isNewPurchase then
			local ammoSpec = WeaponConfig.AMMO_TYPES.Rifle556
			if ammoSpec and PlayerDataService.GetAmmo(player, "Rifle556") < ammoSpec.StarterReserve then
				PlayerDataService.SetAmmo(player, "Rifle556", ammoSpec.StarterReserve, ammoSpec.MaxReserve)
			end
		end
	elseif itemId == "BossBodyguardPass" then
		prof.UnlockedGuardClasses.BossBodyguard = true
		if isNewPurchase then
			local hasBoss = false
			for _, cls in ipairs(prof.ActiveBodyguards) do
				if cls == "BossBodyguard" then
					hasBoss = true
					break
				end
			end
			if not hasBoss and #prof.ActiveBodyguards < 4 then
				PlayerDataService.AddBodyguardClass(player, "BossBodyguard")
			end
		end
	elseif itemId == "GoldenEmperorSuitPass" then
		if not prof.OwnedGuardGear.GoldenEmperorSuit then
			PlayerDataService.UnlockGuardGear(player, "GoldenEmperorSuit")
		end
	end
end

local function grantItemReward(player: Player, itemId: string, studioPreview: boolean): (boolean, string)
	local spec = MonetizationConfig.Items[itemId]
	if not spec then
		return false, "Unknown Shop Item"
	end

	local prefix = if studioPreview then "[Studio Preview] " else ""
	if spec.Kind == "GamePass" then
		local map = ensureOwned(player)
		if map[itemId] then
			return false, spec.DisplayName .. " is already unlocked!"
		end
		map[itemId] = true
		applyPassBenefitsToProfile(player, itemId, true)
		MonetizationService.SyncProStaffVisuals(player)
		local msg = prefix .. "Unlocked " .. spec.DisplayName .. "!"
		print("[MonetizationService]", player.Name, msg)
		if purchaseChangedHandler then
			purchaseChangedHandler(player, msg)
		end
		return true, msg
	else
		local msg: string
		if itemId == "TacticalAmmoCrate" then
			-- Refill ALL 5 Black Market ammunition calibers to 100% Max Reserve!
			for _, ammoId in ipairs(WeaponConfig.AMMO_ORDER) do
				local aSpec = WeaponConfig.AMMO_TYPES[ammoId]
				if aSpec then
					PlayerDataService.SetAmmo(player, ammoId, aSpec.MaxReserve, aSpec.MaxReserve)
				end
			end
			msg = prefix .. "Full Ammo Resupply Crate: ALL 5 calibers refilled to 100%!"
		elseif itemId == "SyndicateArmorBundle" then
			-- 100/100 Kevlar Armor + Full Base HP + +750 Gold + Ammo Bonus!
			PlayerDataService.SetArmor(player, 100)
			PlayerDataService.AddRewards(player, 750, 25, 15)
			local char = player.Character
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			if hum and hum.Health > 0 then
				hum.MaxHealth = 200
				hum.Health = 200
			end
			PlayerDataService.AddAmmo(player, "Pistol9mm", 60, WeaponConfig.AMMO_TYPES.Pistol9mm.MaxReserve)
			PlayerDataService.AddAmmo(player, "Shotgun12G", 24, WeaponConfig.AMMO_TYPES.Shotgun12G.MaxReserve)
			PlayerDataService.AddAmmo(player, "SMG45", 60, WeaponConfig.AMMO_TYPES.SMG45.MaxReserve)
			PlayerDataService.AddAmmo(player, "Rifle556", 60, WeaponConfig.AMMO_TYPES.Rifle556.MaxReserve)
			PlayerDataService.AddAmmo(player, "Sniper308", 15, WeaponConfig.AMMO_TYPES.Sniper308.MaxReserve)
			msg = prefix .. "Syndicate War Chest: 100 Armor, Full HP, +750 Gold & Ammo Pack!"
		elseif itemId == "SamuraiMafiaContract" then
			if mercenaryGrantHandler then
				mercenaryGrantHandler(player, "Samurai")
			end
			msg = prefix .. "Kurogane Samurai Mafia Strike Squad hired for 5 MINUTES! Click ATTACK to unleash them!"
		elseif itemId == "NinjaMafiaContract" then
			if mercenaryGrantHandler then
				mercenaryGrantHandler(player, "Ninja")
			end
			msg = prefix .. "Kage Ninja Assassin Mafia Squad hired for 5 MINUTES! Click ATTACK to unleash them!"
		else
			-- Instant Empire Supply & Coin Crate (repeatable DevProduct)
			PlayerDataService.AddRewards(player, 600, 30, 15)
			for ingredient in pairs(WarehouseConfig.IngredientToCategory) do
				WarehouseService.AddIngredient(player, ingredient, 10)
			end
			msg = prefix .. "Instant Empire Crate: +600 Coins & +10 ALL Ingredients!"
		end

		print("[MonetizationService]", player.Name, msg)
		if purchaseChangedHandler then
			purchaseChangedHandler(player, msg)
		end
		return true, msg
	end
end

-- Unified Dual-Currency Robux Checkout (supports HQ upgrades, Warehouses, Bodyguards, Weapons & Empire items!)
function MonetizationService.TryPromptDualPurchase(
	player: Player,
	productKey: string,
	robuxPrice: number,
	displayName: string,
	grantFn: () -> (boolean, string)
): (boolean, string)
	local dualSpec = MonetizationConfig.DualRobuxOptions[productKey]
	local assetId = if dualSpec then dualSpec.AssetId else 0
	if assetId > 0 then
		local map = pendingDualGrants[player]
		if not map then
			map = {}
			pendingDualGrants[player] = map
		end
		map[assetId] = grantFn
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, assetId)
		end)
		if ok then
			return true, string.format("Opening Robux Checkout (R$ %d) for %s...", robuxPrice, displayName)
		end
		return false, "Could not open Robux checkout: " .. tostring(err)
	end

	-- Studio development preview mode when AssetId == 0 so both Gold & Robux options can be tested immediately!
	if RunService:IsStudio() then
		local gOk, gMsg = grantFn()
		if gOk then
			local msg = string.format("[Robux Preview • R$ %d] %s", robuxPrice, gMsg)
			if purchaseChangedHandler then
				purchaseChangedHandler(player, msg)
			end
			return true, msg
		end
		return false, gMsg
	end

	return false, string.format("Creator must assign Developer Product ID for %s (R$ %d) in MonetizationConfig!", displayName, robuxPrice)
end

function MonetizationService.TryPromptPurchase(player: Player, itemId: string): (boolean, string)
	local spec = MonetizationConfig.Items[itemId]
	if not spec then
		return false, "Shop item not found"
	end

	if spec.Kind == "GamePass" and MonetizationService.HasPass(player, itemId) then
		return false, spec.DisplayName .. " already owned!"
	end

	-- Live published Game Pass / Dev Product flow when real Creator Hub AssetId is configured
	if spec.AssetId > 0 then
		local ok, err = pcall(function()
			if spec.Kind == "GamePass" then
				MarketplaceService:PromptGamePassPurchase(player, spec.AssetId)
			else
				MarketplaceService:PromptProductPurchase(player, spec.AssetId)
			end
		end)
		if ok then
			return true, "Opening Robux Checkout for " .. spec.DisplayName .. "..."
		end
		return false, "Could not open Robux checkout: " .. tostring(err)
	end

	-- Studio development preview mode when AssetId == 0 so you can test Pro Chefs live right away!
	if RunService:IsStudio() then
		return grantItemReward(player, itemId, true)
	end

	return false, "Creator must set AssetId in MonetizationConfig before live purchases"
end

local function loadPlayerPasses(player: Player): ()
	local map = ensureOwned(player)
	for _, itemId in ipairs(MonetizationConfig.Order) do
		local spec = MonetizationConfig.Items[itemId]
		if spec and spec.Kind == "GamePass" and spec.AssetId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, spec.AssetId)
			end)
			if ok and owns then
				map[itemId] = true
				applyPassBenefitsToProfile(player, itemId, false)
			end
		end
	end
	MonetizationService.SyncProStaffVisuals(player)
end

local function findItemByAssetId(assetId: number, kind: MonetizationConfig.MonetizationKind): string?
	for _, itemId in ipairs(MonetizationConfig.Order) do
		local spec = MonetizationConfig.Items[itemId]
		if spec and spec.Kind == kind and spec.AssetId == assetId and assetId > 0 then
			return itemId
		end
	end
	return nil
end

function MonetizationService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	-- Live Game Pass purchase completion callback
	table.insert(
		conns,
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
			if not wasPurchased then
				return
			end
			local itemId = findItemByAssetId(passId, "GamePass")
			if itemId then
				grantItemReward(player, itemId, false)
			end
		end)
	)

	-- Live Developer Product ProcessReceipt handler
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local receiptKey = tostring(receiptInfo.PurchaseId)
		if processedReceipts[receiptKey] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- Check Dual-Currency pending grant callbacks first!
		local pMap = pendingDualGrants[player]
		if pMap and pMap[receiptInfo.ProductId] then
			local fn = pMap[receiptInfo.ProductId]
			pMap[receiptInfo.ProductId] = nil
			local gOk, gMsg = fn()
			if gOk then
				processedReceipts[receiptKey] = true
				if purchaseChangedHandler then
					purchaseChangedHandler(player, gMsg)
				end
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local itemId = findItemByAssetId(receiptInfo.ProductId, "DevProduct")
		if not itemId then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok = grantItemReward(player, itemId, false)
		if ok then
			processedReceipts[receiptKey] = true
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(
		conns,
		Players.PlayerAdded:Connect(function(player)
			task.spawn(loadPlayerPasses, player)
		end)
	)

	table.insert(
		conns,
		Players.PlayerRemoving:Connect(function(player)
			clearProVisuals(player)
			ownedPasses[player] = nil
		end)
	)

	unsubscribeBase = BaseService.OnBaseAssigned(function(player)
		MonetizationService.SyncProStaffVisuals(player)
	end)

	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(loadPlayerPasses, p)
	end

	-- Master Pro Chef active loop (every 4s: sources free Gourmet Fish every 16s + Auto-Cooks & Auto-Serves!)
	autoCookThread = task.spawn(function()
		while isRunning do
			task.wait(4)
			if not isRunning then
				break
			end
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				if MonetizationService.HasPass(player, "MasterProChef") then
					local lastSupply = lastGourmetSupplyAt[player] or 0
					if (now - lastSupply) >= 16 then
						lastGourmetSupplyAt[player] = now
						WarehouseService.AddIngredient(player, "fish", 2)
						WarehouseService.AddIngredient(player, "shrimp", 1)
						MonetizationService.SetProChefStatus(player, "🐟 Sourced Fresh Fish!", true)
					end
					if autoCookHandler then
						autoCookHandler(player)
					end
				end
			end
		end
	end)

	print("[Food Empire] MonetizationService started (Robux Pro Chef, VIP Staff, 2x Boost & Supply Crate ready)!")
end

function MonetizationService.Stop(): ()
	isRunning = false
	if autoCookThread then
		task.cancel(autoCookThread)
		autoCookThread = nil
	end
	if unsubscribeBase then
		unsubscribeBase()
		unsubscribeBase = nil
	end
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	table.clear(conns)
	for p in pairs(proVisuals) do
		clearProVisuals(p)
	end
end

return MonetizationService
