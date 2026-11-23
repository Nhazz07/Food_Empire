--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

export type BaseSlot = "North" | "South" | "East" | "West"
export type BaseAssignedCallback = (player: Player, slot: BaseSlot) -> ()

local BaseService = {}

local SLOT_ORDER: { BaseSlot } = { "North", "South", "East", "West" }

local slotOwners: { [BaseSlot]: Player? } = {
	North = nil,
	South = nil,
	East = nil,
	West = nil,
}
local playerSlots: { [Player]: BaseSlot } = {}
local baseDefenseTiers: { [BaseSlot]: number } = {
	North = 1,
	South = 1,
	East = 1,
	West = 1,
}

local listeners: { BaseAssignedCallback } = {}
local isRunning = false
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local charConnections: { [Player]: RBXScriptConnection } = {}
local turretThread: thread? = nil

function BaseService.GetBaseModel(slot: BaseSlot): Model?
	if typeof(slot) ~= "string" then
		return nil
	end
	local map = workspace:FindFirstChild("FoodEmpireMap")
	local bases = if map then map:FindFirstChild("PlayerBases") else nil
	local direct = if bases then bases:FindFirstChild(slot .. "Base") else nil
	if direct and direct:IsA("Model") then
		return direct
	end
	for _, base in ipairs(CollectionService:GetTagged("PlayerBase")) do
		if base:IsA("Model") and base:IsDescendantOf(workspace) and base:GetAttribute("BaseSlot") == slot then
			return base
		end
	end
	return nil
end

function BaseService.GetPlayerBaseSlot(player: Player): BaseSlot?
	return playerSlots[player]
end

function BaseService.GetDefenseTier(slot: BaseSlot): number
	return baseDefenseTiers[slot] or 1
end

local function syncDefenseVisuals(slot: BaseSlot, tier: number): ()
	local baseModel = BaseService.GetBaseModel(slot)
	if not baseModel then
		return
	end

	local defenses = baseModel:FindFirstChild("Defenses")
	if not defenses then
		return
	end

	local tier2Folder = defenses:FindFirstChild("Tier2")
	local tier3Folder = defenses:FindFirstChild("Tier3")
	local accentAttr = baseModel:GetAttribute("AccentColor")
	local accentColor = if typeof(accentAttr) == "Color3" then accentAttr else Color3.fromRGB(248, 196, 56)

	-- Tier 2+: Mount defensive watchtower turrets on all 4 corner tower TurretMounts
	if tier2Folder then
		tier2Folder:ClearAllChildren()
		if tier >= 2 then
			for _, desc in ipairs(defenses:GetDescendants()) do
				if desc.Name == "TurretMount" and desc:IsA("BasePart") then
					local turret = Instance.new("Model")
					turret.Name = "WatchtowerTurret"

					local ped = Instance.new("Part")
					ped.Name = "Pedestal"
					ped.Shape = Enum.PartType.Cylinder
					ped.Size = Vector3.new(3.2, 4.4, 4.4)
					ped.CFrame = desc.CFrame * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90))
					ped.Color = Color3.fromRGB(68, 74, 88)
					ped.Material = Enum.Material.Metal
					ped.Anchored = true
					ped.CanCollide = false
					ped.Parent = turret

					local orb = Instance.new("Part")
					orb.Name = "DefenseCrystal"
					orb.Shape = Enum.PartType.Ball
					orb.Size = Vector3.new(3.4, 3.4, 3.4)
					orb.CFrame = desc.CFrame * CFrame.new(0, 4.8, 0)
					orb.Color = if tier >= 3 then Color3.fromRGB(255, 212, 64) else accentColor
					orb.Material = Enum.Material.Neon
					orb.Anchored = true
					orb.CanCollide = false
					orb.CastShadow = false
					orb.Parent = turret

					local light = Instance.new("PointLight")
					light.Color = orb.Color
					light.Brightness = if tier >= 3 then 2.2 else 1.4
					light.Range = 28
					light.Shadows = false
					light.Parent = orb

					turret.PrimaryPart = orb
					turret.Parent = tier2Folder
				end
			end
		end
	end

	-- Tier 3: Golden Emperor Gate Shield Arch over GrandFrontGate
	if tier3Folder then
		tier3Folder:ClearAllChildren()
		if tier >= 3 then
			local gate = defenses:FindFirstChild("GrandFrontGate", true)
			local archLintel = if gate then gate:FindFirstChild("ArchLintel") else nil
			if archLintel and archLintel:IsA("BasePart") then
				local crest = Instance.new("Part")
				crest.Name = "EmperorShieldCrest"
				crest.Size = Vector3.new(16, 2.2, 2.2)
				crest.CFrame = archLintel.CFrame * CFrame.new(0, 3.4, 0)
				crest.Color = Color3.fromRGB(255, 212, 64)
				crest.Material = Enum.Material.Neon
				crest.Anchored = true
				crest.CanCollide = false
				crest.CastShadow = false
				crest.Parent = tier3Folder
			end
		end
	end
end

function BaseService.SetDefenseTier(slot: BaseSlot, tier: number): ()
	local clamped = math.clamp(tier, 1, 3)
	baseDefenseTiers[slot] = clamped

	local baseModel = BaseService.GetBaseModel(slot)
	if baseModel then
		baseModel:SetAttribute("DefenseTier", clamped)
	end

	syncDefenseVisuals(slot, clamped)
end

function BaseService.OnBaseAssigned(callback: BaseAssignedCallback): () -> ()
	table.insert(listeners, callback)
	return function()
		local idx = table.find(listeners, callback)
		if idx then
			table.remove(listeners, idx)
		end
	end
end

local function teleportToBaseSpawn(player: Player, character: Model): ()
	local slot = playerSlots[player]
	if not slot then
		return
	end

	local baseModel = BaseService.GetBaseModel(slot)
	if not baseModel then
		return
	end

	local spawnPart = baseModel:FindFirstChild("BaseSpawn")
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return
	end

	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root and root:IsA("BasePart") then
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(spawnPart.Position)
			end)
			if character.Parent then
				character:PivotTo(spawnPart.CFrame + Vector3.new(0, 5.5, 0))
			end
		end)
	end
end

local function updateGateOwnerSign(slot: BaseSlot, ownerName: string?): ()
	local baseModel = BaseService.GetBaseModel(slot)
	if not baseModel then
		return
	end
	local gate = baseModel:FindFirstChild("GrandFrontGate", true)
	local crest = if gate then gate:FindFirstChild("ArchTeamCrest") else nil
	if not crest or not crest:IsA("BasePart") then
		return
	end

	local gui = crest:FindFirstChild("BaseOwnerGui")
	local label: TextLabel
	if gui and gui:IsA("SurfaceGui") then
		local existing = gui:FindFirstChildOfClass("TextLabel")
		if existing then
			label = existing
		else
			label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.25
			label.Parent = gui
		end
	else
		local newGui = Instance.new("SurfaceGui")
		newGui.Name = "BaseOwnerGui"
		newGui.Face = Enum.NormalId.Back
		newGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		newGui.PixelsPerStud = 35
		newGui.Parent = crest

		label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.25
		label.Parent = newGui
	end

	label.Text = if ownerName then (string.upper(ownerName) .. "'S EMPIRE") else (string.upper(slot) .. " CASTLE")
end

local function teleportToCentralLobby(character: Model): ()
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root and root:IsA("BasePart") then
		task.defer(function()
			if character.Parent then
				character:PivotTo(CFrame.lookAt(Vector3.new(0, 5.5, 42), Vector3.new(0, 5.5, 0)))
			end
		end)
	end
end

function BaseService.GetSlotAvailability(): { [string]: string? }
	local out: { [string]: string? } = {}
	for _, slot in ipairs(SLOT_ORDER) do
		local owner = slotOwners[slot]
		out[slot] = if owner then owner.DisplayName else nil
	end
	return out
end

function BaseService.ClaimBaseSlot(player: Player, slot: BaseSlot): (boolean, string)
	if playerSlots[player] then
		return false, "You already own " .. playerSlots[player] .. " Castle Base!"
	end

	local isValid = false
	for _, s in ipairs(SLOT_ORDER) do
		if s == slot then
			isValid = true
			break
		end
	end
	if not isValid then
		return false, "Invalid Castle Base choice"
	end

	if slotOwners[slot] ~= nil then
		return false, slot .. " Castle Base is already taken — choose another!"
	end

	slotOwners[slot] = player
	playerSlots[player] = slot
	player:SetAttribute("BaseSlot", slot)

	local baseModel = BaseService.GetBaseModel(slot)
	if baseModel then
		baseModel:SetAttribute("OwnerUserId", player.UserId)
	end
	updateGateOwnerSign(slot, player.DisplayName)

	print(string.format("[BaseService] %s claimed %s Castle Base!", player.Name, slot))

	for _, cb in ipairs(listeners) do
		task.spawn(cb, player, slot)
	end

	if charConnections[player] then
		charConnections[player]:Disconnect()
	end
	charConnections[player] = player.CharacterAdded:Connect(function(character)
		teleportToBaseSpawn(player, character)
	end)
	if player.Character then
		teleportToBaseSpawn(player, player.Character)
	end

	return true, string.format("Welcome to %s Castle Base! Starter Fish Warehouse unlocked!", slot)
end

local function releaseSlot(player: Player): ()
	local slot = playerSlots[player]
	if slot then
		slotOwners[slot] = nil
		playerSlots[player] = nil
		BaseService.SetDefenseTier(slot, 1)
		updateGateOwnerSign(slot, nil)
		local baseModel = BaseService.GetBaseModel(slot)
		if baseModel then
			baseModel:SetAttribute("OwnerUserId", nil)
		end
	end

	if charConnections[player] then
		charConnections[player]:Disconnect()
		charConnections[player] = nil
	end
end

-- Active Castle Defense Turrets repel Rival AI raiders who approach upgraded bases
local function runDefenseTurretTick(): ()
	local rivals = CollectionService:GetTagged("RivalAIUnit")
	if #rivals == 0 then
		return
	end

	for _, slot in ipairs(SLOT_ORDER) do
		local tier = baseDefenseTiers[slot] or 1
		if tier >= 2 and slotOwners[slot] ~= nil then
			local baseModel = BaseService.GetBaseModel(slot)
			if baseModel and baseModel.PrimaryPart then
				local basePos = baseModel.PrimaryPart.Position
				local range = if tier >= 3 then 145 else 115
				local damage = if tier >= 3 then 35 else 20

				for _, unit in ipairs(rivals) do
					if unit:IsA("Model") then
						local hum = unit:FindFirstChildOfClass("Humanoid")
						local root = unit:FindFirstChild("HumanoidRootPart")
						if hum and hum.Health > 0 and root and root:IsA("BasePart") then
							if (root.Position - basePos).Magnitude <= range then
								hum:TakeDamage(damage)
							end
						end
					end
				end
			end
		end
	end
end

function BaseService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	for _, slot in ipairs(SLOT_ORDER) do
		updateGateOwnerSign(slot, nil)
	end

	local function hookPendingPlayer(player: Player)
		if playerSlots[player] then
			return
		end
		if charConnections[player] then
			charConnections[player]:Disconnect()
		end
		charConnections[player] = player.CharacterAdded:Connect(function(character)
			if playerSlots[player] then
				teleportToBaseSpawn(player, character)
			else
				teleportToCentralLobby(character)
			end
		end)
		if player.Character then
			teleportToCentralLobby(player.Character)
		end
	end

	playerAddedConn = Players.PlayerAdded:Connect(hookPendingPlayer)
	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		releaseSlot(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		hookPendingPlayer(player)
	end

	turretThread = task.spawn(function()
		while isRunning do
			task.wait(1.5)
			if not isRunning then
				break
			end
			runDefenseTurretTick()
		end
	end)

	print("[Food Empire] BaseService started (4 Cardinal Castle Bases + Tier 1-3 Defenses ready)!")
end

function BaseService.Stop(): ()
	isRunning = false
	if turretThread then
		task.cancel(turretThread)
		turretThread = nil
	end
	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for player, conn in pairs(charConnections) do
		conn:Disconnect()
		charConnections[player] = nil
	end
end

return BaseService
