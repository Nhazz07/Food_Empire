--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WarehouseConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WarehouseConfig")
)
local SectorService = require("./SectorService")
local BaseService = require("./BaseService")
local WarehouseService = require("./WarehouseService")
local PlayerDataService = require("./PlayerDataService")

export type DeliveryCategory = WarehouseConfig.WarehouseCategory

local DeliveryService = {}

local MANUAL_DELIVERY_PER_ITEM = 5 -- +5 of each of the 3 category ingredients = +15 total!
local MANUAL_DELIVERY_COINS = 25
local MANUAL_DELIVERY_EXP = 10
local NODE_HARVEST_PER_ITEM = 2
local NODE_COOLDOWN_SEC = 5.0

local HARVEST_VERBS: { [DeliveryCategory]: string } = {
	Fish = "Catch Fresh Fish",
	Vegetable = "Harvest Veggies",
	Fruit = "Pick Fresh Fruit",
	Meat = "Collect Fresh Meat",
}

local carriedCategory: { [Player]: DeliveryCategory } = {}
local carriedCrates: { [Player]: Part } = {}
local nodeCooldowns: { [Instance]: number } = {}
local isRunning = false
local promptConnections: { RBXScriptConnection } = {}
local playerRemovingConn: RBXScriptConnection? = nil
local charConns: { [Player]: RBXScriptConnection } = {}

local function sendToast(player: Player, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if toastEv and toastEv:IsA("RemoteEvent") then
		toastEv:FireClient(player, msg)
	end
end

local function clearCarriedCrate(player: Player): ()
	carriedCategory[player] = nil
	local crate = carriedCrates[player]
	if crate and crate.Parent then
		crate:Destroy()
	end
	carriedCrates[player] = nil
	player:SetAttribute("CarryingCrate", nil)
end

local function attachCrateVisual(player: Player, category: DeliveryCategory): ()
	clearCarriedCrate(player)

	local character = player.Character
	if not character then
		return
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	if not torso or not torso:IsA("BasePart") then
		return
	end

	local spec = WarehouseConfig.Specs[category]
	local crate = Instance.new("Part")
	crate.Name = "CarriedIngredientCrate"
	crate.Size = Vector3.new(2.2, 1.8, 1.8)
	crate.Color = spec.AccentColor
	crate.Material = Enum.Material.WoodPlanks
	crate.CanCollide = false
	crate.CanTouch = false
	crate.CanQuery = false
	crate.Massless = true
	crate.CFrame = torso.CFrame * CFrame.new(0, 0.3, 1.45)
	crate.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = crate
	weld.Parent = crate

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(130, 26)
	bb.StudsOffset = Vector3.new(0, 1.6, 0)
	bb.MaxDistance = 80
	bb.Parent = crate

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = spec.AccentColor
	lbl.Font = Enum.Font.FredokaOne
	lbl.Text = spec.ShortLabel .. " CRATE"
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Parent = bb

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = lbl

	carriedCategory[player] = category
	carriedCrates[player] = crate
	player:SetAttribute("CarryingCrate", category)
	player:SetAttribute("StolenShipmentUntil", os.clock() + 35)
end

local function wireTerritoryPickupCrates(): ()
	for _, root in ipairs(CollectionService:GetTagged("SectorVisualRoot")) do
		local sectorIdAttr = root:GetAttribute("SectorId")
		if typeof(sectorIdAttr) == "string" then
			local sector = SectorService.GetSector(sectorIdAttr)
			local rig = root:FindFirstChild("TerritoryCaptureRig")
			local zone = if rig then rig:FindFirstChild("CaptureZone") else nil

			if sector and zone and zone:IsA("BasePart") then
				local category = sector.Category :: DeliveryCategory
				local spec = WarehouseConfig.Specs[category]
				if spec then
					local existing = root:FindFirstChild("ManualPickupCrate")
					local pickupPart: BasePart
					if existing and existing:IsA("BasePart") then
						pickupPart = existing
					else
						local p = Instance.new("Part")
						p.Name = "ManualPickupCrate"
						p.Size = Vector3.new(4.2, 3.2, 4.2)
						p.CFrame = CFrame.new(zone.Position.X + 10, zone.Position.Y - 5.4, zone.Position.Z)
						p.Color = spec.AccentColor
						p.Material = Enum.Material.WoodPlanks
						p.Anchored = true
						p.CanCollide = true
						p.Parent = root
						pickupPart = p
					end

					local oldPrompt = pickupPart:FindFirstChild("GrabCratePrompt")
					if oldPrompt then oldPrompt:Destroy() end

					local prompt = Instance.new("ProximityPrompt")
					prompt.Name = "GrabCratePrompt"
					prompt.KeyboardKeyCode = Enum.KeyCode.F
					prompt.HoldDuration = 0.2
					prompt.MaxActivationDistance = 14
					prompt.RequiresLineOfSight = false
					prompt.ActionText = "Grab " .. spec.ShortLabel .. " Crate"
					prompt.ObjectText = sector.DisplayName .. " (Manual Delivery)"
					prompt.Parent = pickupPart

					table.insert(
						promptConnections,
						prompt.Triggered:Connect(function(player)
							local liveSector = SectorService.GetSector(sectorIdAttr)
							if not liveSector then
								return
							end
							local ownerId = "Player_" .. tostring(player.UserId)
							if liveSector.Owner ~= ownerId then
								sendToast(player, "Capture " .. liveSector.DisplayName .. " first to grab big Supply Crates!")
								return
							end
							if not WarehouseService.IsUnlocked(player, category) then
								sendToast(player, string.format("LOCKED: Unlock your %s (%dG) in Storage [B] before stealing %s!", spec.DisplayName, spec.UnlockCost, spec.ShortLabel))
								return
							end
							if carriedCategory[player] then
								sendToast(player, "Deliver your current crate to your Warehouse first!")
								return
							end
							attachCrateVisual(player, category)
							sendToast(player, string.format("Carrying %s Crate! Deliver to your %s (+15 stock, +%dG)!", spec.ShortLabel, spec.DisplayName, MANUAL_DELIVERY_COINS))
							print(string.format("[DeliveryService] %s picked up a %s crate from %s!", player.Name, category, liveSector.DisplayName))
						end)
					)
				end
			end
		end
	end
end

local function wireResourceNodeHarvesting(): ()
	for _, node in ipairs(CollectionService:GetTagged("ResourceNode")) do
		local sectorIdAttr = node:GetAttribute("SectorId")
		if node:IsA("BasePart") and typeof(sectorIdAttr) == "string" then
			local sector = SectorService.GetSector(sectorIdAttr)
			if sector then
				local category = sector.Category :: DeliveryCategory
				local spec = WarehouseConfig.Specs[category]
				if spec then
					local oldPrompt = node:FindFirstChild("HarvestResourcePrompt")
					if oldPrompt then oldPrompt:Destroy() end

					local prompt = Instance.new("ProximityPrompt")
					prompt.Name = "HarvestResourcePrompt"
					prompt.KeyboardKeyCode = Enum.KeyCode.E
					prompt.HoldDuration = 0.2
					prompt.MaxActivationDistance = 14
					prompt.RequiresLineOfSight = false
					prompt.ActionText = HARVEST_VERBS[category] or ("Harvest " .. spec.ShortLabel)
					prompt.ObjectText = sector.DisplayName .. " Resource"
					prompt.Parent = node

					table.insert(
						promptConnections,
						prompt.Triggered:Connect(function(player)
							local liveSector = SectorService.GetSector(sectorIdAttr)
							if not liveSector then
								return
							end
							local ownerId = "Player_" .. tostring(player.UserId)
							if liveSector.Owner ~= ownerId and liveSector.Owner ~= "Neutral" then
								sendToast(player, "Defeat Rival Chef & capture " .. liveSector.DisplayName .. " to harvest here!")
								return
							end
							if not WarehouseService.IsUnlocked(player, category) then
								sendToast(player, string.format("LOCKED: Unlock your %s (%dG) in Storage [B] to store %s!", spec.DisplayName, spec.UnlockCost, spec.ShortLabel))
								return
							end
							local now = os.clock()
							if (nodeCooldowns[node] or 0) > now then
								return
							end
							nodeCooldowns[node] = now + NODE_COOLDOWN_SEC

							local storedParts: { string } = {}
							local totalAdded = 0
							for _, ing in ipairs(spec.Ingredients) do
								local added = WarehouseService.AddIngredient(player, ing, NODE_HARVEST_PER_ITEM)
								if added > 0 then
									totalAdded += added
									table.insert(storedParts, string.format("+%d %s", added, ing))
								end
							end

							if totalAdded > 0 then
								local origTrans = node.Transparency
								node.Transparency = 0.65
								task.delay(NODE_COOLDOWN_SEC, function()
									if node.Parent then
										node.Transparency = origTrans
									end
								end)
								PlayerDataService.AddRewards(player, 3, 4, 1)
								sendToast(player, string.format("Stored %s in %s!", table.concat(storedParts, ", "), spec.DisplayName))
							else
								sendToast(player, string.format("%s is FULL! Upgrade it or cook dishes in Kitchen (C)!", spec.DisplayName))
							end
						end)
					)
				end
			end
		end
	end
end

local function wireWarehouseDropoffs(): ()
	for _, plot in ipairs(CollectionService:GetTagged("WarehousePlot")) do
		local catAttr = plot:GetAttribute("Category")
		local slotAttr = plot:GetAttribute("BaseSlot")
		local door = plot:FindFirstChild("CargoDoor", true)

		if
			typeof(catAttr) == "string"
			and typeof(slotAttr) == "string"
			and door
			and door:IsA("BasePart")
			and WarehouseConfig.Specs[catAttr :: DeliveryCategory]
		then
			local category = catAttr :: DeliveryCategory
			local spec = WarehouseConfig.Specs[category]

			local oldPrompt = door:FindFirstChild("DeliverCratePrompt")
			if oldPrompt then oldPrompt:Destroy() end

			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "DeliverCratePrompt"
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.HoldDuration = 0.15
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.ActionText = "Deliver " .. spec.ShortLabel .. " Crate"
			prompt.ObjectText = spec.DisplayName
			prompt.Parent = door

			table.insert(
				promptConnections,
				prompt.Triggered:Connect(function(player)
					if BaseService.GetPlayerBaseSlot(player) ~= slotAttr then
						return
					end
					if carriedCategory[player] ~= category then
						return
					end

					if not WarehouseService.IsUnlocked(player, category) then
						sendToast(player, string.format("Build %s (%d Gold) first to store this crate!", spec.DisplayName, spec.UnlockCost))
						return
					end

					local totalStored = 0
					for _, ing in ipairs(spec.Ingredients) do
						totalStored += WarehouseService.AddIngredient(player, ing, MANUAL_DELIVERY_PER_ITEM)
					end

					clearCarriedCrate(player)
					PlayerDataService.AddRewards(player, MANUAL_DELIVERY_COINS, MANUAL_DELIVERY_EXP, 5)
					sendToast(player, string.format("Delivered +%d %s to %s (+%d Gold)!", totalStored, spec.ShortLabel, spec.DisplayName, MANUAL_DELIVERY_COINS))
					print(
						string.format(
							"[DeliveryService] %s manually delivered %d %s ingredients (+%d Coins)!",
							player.Name,
							totalStored,
							category,
							MANUAL_DELIVERY_COINS
						)
					)
				end)
			)
		end
	end
end

function DeliveryService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	-- Keep the 4 map corners strictly True Neutral & uninteractable (strip any old corner pickup crates/prompts)
	for _, root in ipairs(CollectionService:GetTagged("SectorVisualRoot")) do
		local oldCrate = root:FindFirstChild("ManualPickupCrate")
		if oldCrate then
			oldCrate:Destroy()
		end
	end
	for _, node in ipairs(CollectionService:GetTagged("ResourceNode")) do
		local oldPrompt = node:FindFirstChild("HarvestResourcePrompt")
		if oldPrompt then
			oldPrompt:Destroy()
		end
	end

	wireWarehouseDropoffs()

	local function hookPlayer(player: Player)
		if charConns[player] then
			charConns[player]:Disconnect()
		end
		charConns[player] = player.CharacterAdded:Connect(function()
			clearCarriedCrate(player)
		end)
	end

	Players.PlayerAdded:Connect(hookPlayer)
	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		clearCarriedCrate(player)
		if charConns[player] then
			charConns[player]:Disconnect()
			charConns[player] = nil
		end
	end)

	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayer(p)
	end

	print("[Food Empire] DeliveryService started (Manual Territory Crate -> Warehouse drop-offs live, Press F)!")
end

function DeliveryService.Stop(): ()
	isRunning = false
	for _, conn in ipairs(promptConnections) do
		conn:Disconnect()
	end
	table.clear(promptConnections)
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for player, conn in pairs(charConns) do
		conn:Disconnect()
		charConns[player] = nil
		clearCarriedCrate(player)
	end
end

return DeliveryService
