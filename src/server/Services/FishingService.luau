--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WarehouseService = require("./WarehouseService")
local PlayerDataService = require("./PlayerDataService")
local MonetizationService = require("./MonetizationService")

type ActiveCast = {
	Token: number,
	StartedAt: number,
	RodModel: Model?,
}

local FishingService = {}

local COOLDOWN_SEC = 1.5
local activeCasts: { [Player]: ActiveCast } = {}
local lastFinishAt: { [Player]: number } = {}
local nextToken = 1
local isRunning = false
local startEv: RemoteEvent? = nil
local resultEv: RemoteEvent? = nil
local conns: { RBXScriptConnection } = {}

local function sendToast(player: Player, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

local function clearRodVisual(player: Player): ()
	local cast = activeCasts[player]
	if cast and cast.RodModel and cast.RodModel.Parent then
		cast.RodModel:Destroy()
	end
	if cast then
		cast.RodModel = nil
	end
end

local function attachFishingRod(player: Player): Model?
	local char = player.Character
	local torso = if char then (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")) else nil
	if not char or not torso or not torso:IsA("BasePart") then
		return nil
	end

	local rodModel = Instance.new("Model")
	rodModel.Name = "EquippedFishingRod"

	local pole = Instance.new("Part")
	pole.Name = "RodPole"
	pole.Size = Vector3.new(0.24, 7.2, 0.24)
	pole.Color = Color3.fromRGB(168, 112, 58)
	pole.Material = Enum.Material.Wood
	pole.CanCollide = false
	pole.CanTouch = false
	pole.CanQuery = false
	pole.Massless = true
	pole.CFrame = torso.CFrame * CFrame.new(1.1, 1.4, -3.2) * CFrame.Angles(math.rad(-52), 0, 0)
	pole.Parent = rodModel

	local w1 = Instance.new("WeldConstraint")
	w1.Part0 = torso
	w1.Part1 = pole
	w1.Parent = pole

	local line = Instance.new("Part")
	line.Name = "FishingLine"
	line.Size = Vector3.new(0.08, 6.0, 0.08)
	line.Color = Color3.fromRGB(232, 244, 255)
	line.Material = Enum.Material.Neon
	line.Transparency = 0.35
	line.CanCollide = false
	line.CanTouch = false
	line.CanQuery = false
	line.Massless = true
	line.CFrame = torso.CFrame * CFrame.new(1.1, 0.5, -6.0)
	line.Parent = rodModel

	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = torso
	w2.Part1 = line
	w2.Parent = line

	local bobber = Instance.new("Part")
	bobber.Name = "Bobber"
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.new(0.85, 0.85, 0.85)
	bobber.Color = Color3.fromRGB(246, 62, 54)
	bobber.Material = Enum.Material.SmoothPlastic
	bobber.CanCollide = false
	bobber.CanTouch = false
	bobber.CanQuery = false
	bobber.Massless = true
	bobber.CFrame = torso.CFrame * CFrame.new(1.1, -2.5, -6.0)
	bobber.Parent = rodModel

	local w3 = Instance.new("WeldConstraint")
	w3.Part0 = torso
	w3.Part1 = bobber
	w3.Parent = bobber

	rodModel.Parent = char
	return rodModel
end

local function startFishingForPlayer(player: Player): ()
	if activeCasts[player] then
		return
	end
	if (os.clock() - (lastFinishAt[player] or 0)) < COOLDOWN_SEC then
		return
	end

	nextToken += 1
	local token = nextToken
	local rod = attachFishingRod(player)
	activeCasts[player] = {
		Token = token,
		StartedAt = os.clock(),
		RodModel = rod,
	}

	if startEv then
		-- Slight speed variation each cast for exciting skill play!
		local speed = 1.45 + math.random() * 0.45
		startEv:FireClient(player, token, speed)
	end

	-- Auto-expire stale cast after 18s
	task.delay(18, function()
		local cur = activeCasts[player]
		if cur and cur.Token == token then
			clearRodVisual(player)
			activeCasts[player] = nil
		end
	end)
end

local function handleFishingResult(player: Player, token: any, accuracy: any): ()
	local cast = activeCasts[player]
	if not cast or cast.Token ~= token then
		return
	end

	clearRodVisual(player)
	activeCasts[player] = nil
	lastFinishAt[player] = os.clock()

	if accuracy == "Golden" then
		local isTuna = math.random() < 0.5
		local rareId = if isTuna then "golden_tuna" else "king_crab"
		local rareLabel = if isTuna then "✨ RARE GOLDEN TUNA" else "🦞 GIANT KING CRAB"
		local recipeHint = if isTuna then "Golden Tuna Sashimi (+240G)" else "Giant King Crab Platter (+260G)"

		local addedRare = WarehouseService.AddIngredient(player, rareId, 1)
		local addedFish = WarehouseService.AddIngredient(player, "fish", 2)
		local passMult = MonetizationService.GetPayoutMultiplier(player)
		local bonusGold = math.floor(35 * passMult)
		PlayerDataService.AddRewards(player, bonusGold, 25, 12)

		if addedRare > 0 then
			sendToast(player, string.format("🌟 %s CAUGHT! (+%dG) Cook %s in Kitchen (C)!", rareLabel, bonusGold, recipeHint))
		elseif addedFish > 0 then
			sendToast(player, string.format("🌟 %s! Fish Warehouse almost full — upgrade Fish Warehouse!", rareLabel))
		else
			sendToast(player, "📦 Fish Warehouse is FULL! Upgrade it to store rare catches!")
		end
		print(string.format("[FishingService] %s reeled in a %s!", player.Name, rareLabel))
	elseif accuracy == "Good" then
		local f = WarehouseService.AddIngredient(player, "fish", 3)
		local s = WarehouseService.AddIngredient(player, "shrimp", 2)
		PlayerDataService.AddRewards(player, 12, 8, 3)
		if (f + s) > 0 then
			sendToast(player, string.format("🎣 Nice Catch! +%d fish, +%d shrimp stored in Fish Warehouse (+12G)!", f, s))
		else
			sendToast(player, "📦 Fish Warehouse is FULL! Upgrade it or cook dishes in Kitchen (C)!")
		end
	else
		sendToast(player, "🎣 The fish slipped off the hook — cast again!")
	end
end

local function wirePierSpot(part: Instance): ()
	if not part:IsA("BasePart") then
		return
	end
	local old = part:FindFirstChild("CastFishingRodPrompt")
	if old then
		old:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CastFishingRodPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.ActionText = "Cast Fishing Rod (Rare Catch!)"
	prompt.ObjectText = "Fishing Port Pier"
	prompt.Parent = part

	table.insert(
		conns,
		prompt.Triggered:Connect(function(player)
			startFishingForPlayer(player)
		end)
	)
end

function FishingService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
		remotes = f
	end

	local function ensureRemote(name: string): RemoteEvent
		local ex = remotes:FindFirstChild(name)
		if ex and ex:IsA("RemoteEvent") then
			return ex
		end
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = remotes
		return created
	end

	startEv = ensureRemote("FishingStart")
	resultEv = ensureRemote("FishingResult")

	if resultEv then
		table.insert(conns, resultEv.OnServerEvent:Connect(handleFishingResult))
	end

	for _, spot in ipairs(CollectionService:GetTagged("PierFishingSpot")) do
		wirePierSpot(spot)
	end
	table.insert(conns, CollectionService:GetInstanceAddedSignal("PierFishingSpot"):Connect(wirePierSpot))

	table.insert(
		conns,
		Players.PlayerRemoving:Connect(function(player)
			clearRodVisual(player)
			activeCasts[player] = nil
			lastFinishAt[player] = nil
		end)
	)

	print("[Food Empire] FishingService started (Fishing Port Pier Mini-Game & Rare Golden Tuna / King Crab active)!")
end

function FishingService.Stop(): ()
	isRunning = false
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	table.clear(conns)
	for p in pairs(activeCasts) do
		clearRodVisual(p)
	end
	table.clear(activeCasts)
end

return FishingService
