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
local BaseService = require("./BaseService")
local SyndicateFamilyService = require("./SyndicateFamilyService")

type ActiveHitTarget = {
	Owner: Player,
	TargetName: string,
	RewardGold: number,
	RewardRep: number,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
}

local BountyService = {}

local HIT_TARGETS = {
	{ Name = "Vito 'Iron Jaw' Moretti", Kind = "ApexWarlord" :: "ApexWarlord", HP = 880, Gold = 460, Rep = 65, Pos = Vector3.new(178, 4.2, -162) },
	{ Name = "Kenji 'Ghost Blade' Sato", Kind = "ApexAssassin" :: "ApexAssassin", HP = 820, Gold = 520, Rep = 75, Pos = Vector3.new(-178, 4.2, 162) },
	{ Name = "Marco 'The Butcher' Bellini", Kind = "ApexWarlord" :: "ApexWarlord", HP = 960, Gold = 620, Rep = 90, Pos = Vector3.new(182, 4.2, 166) },
}

local playerBounties: { [Player]: number } = {}
local activeHits: { [Player]: ActiveHitTarget } = {}
local hitCooldownUntil: { [Player]: number } = {}
local bountyFolder: Folder? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local isRunning = false

local function sendToast(player: Player?, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		if player then ev:FireClient(player, msg) else ev:FireAllClients(msg) end
	end
end

local function isAlliedPlayer(a: Player, b: Player): boolean
	return a == b or BaseService.AreBaseTeammates(a, b) or SyndicateFamilyService.AreFamilyAllies(a, b)
end

function BountyService.PlacePlayerBounty(placer: Player, targetName: string?, amountRaw: number?): (boolean, string)
	local amount = math.clamp(math.floor(amountRaw or 250), 200, 1000)
	local target: Player? = nil
	if typeof(targetName) == "string" and targetName ~= "" then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= placer and (string.lower(p.Name) == string.lower(targetName) or string.lower(p.DisplayName) == string.lower(targetName)) then
				if isAlliedPlayer(placer, p) then
					return false, "You cannot place a Syndicate Bounty on your own Co-op Base Partner or Family ally!"
				end
				target = p
				break
			end
		end
	else
		for _, p in ipairs(Players:GetPlayers()) do
			if not isAlliedPlayer(placer, p) then
				target = p
				break
			end
		end
	end
	if not target then
		return false, "No rival player online to place a bounty on — accept a Syndicate Hit Contract instead!"
	end
	if not PlayerDataService.SpendCoins(placer, amount) then
		return false, string.format("Need %d Gold to post a Syndicate Bounty!", amount)
	end
	playerBounties[target] = (playerBounties[target] or 0) + amount
	target:SetAttribute("SyndicateBounty", playerBounties[target])
	sendToast(nil, string.format("BOUNTY POSTED: %d Gold on %s's head (posted by %s)!", playerBounties[target], target.DisplayName, placer.DisplayName))
	return true, string.format("Posted %d Gold Syndicate Bounty on %s!", amount, target.DisplayName)
end

function BountyService.AcceptHitContract(player: Player): (boolean, string)
	local existing = activeHits[player]
	if existing and existing.Model.Parent and existing.Humanoid.Health > 0 then
		local canTp, lockMsg = CombatLockService.CanTeleport(player)
		if not canTp then
			return false, lockMsg
		end
		local char = player.Character
		if char then
			local dest = existing.Root.Position + Vector3.new(0, 2, 24)
			pcall(function() player:RequestStreamAroundAsync(dest) end)
			char:PivotTo(CFrame.lookAt(dest, existing.Root.Position))
		end
		return true, string.format("Warped near active Hit Target: %s (+%dG & +%d Rep)!", existing.TargetName, existing.RewardGold, existing.RewardRep)
	end

	local now = os.clock()
	local cd = hitCooldownUntil[player] or 0
	if cd > now then
		return false, string.format("Next Syndicate Hit Contract available in %ds!", math.ceil(cd - now))
	end

	local spec = HIT_TARGETS[math.random(1, #HIT_TARGETS)]
	local rig = MafiaVisualBuilder.BuildSyndicateSpecialistRig("HitContractTarget_" .. tostring(player.UserId), spec.Kind, 1.12, CFrame.new(spec.Pos), false)
	local model = rig.Model
	local root = rig.Root
	local head = rig.Head

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(230, 42)
	bb.StudsOffset = Vector3.new(0, 3.3, 0)
	bb.MaxDistance = 260
	bb.Parent = head
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	lbl.BackgroundTransparency = 0.06
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = string.format("HIT CONTRACT: %s  (+%dG)", string.upper(spec.Name), spec.Gold)
	lbl.TextSize = 10
	lbl.TextColor3 = Color3.fromRGB(238, 194, 114)
	lbl.Parent = bb
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 5)

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = spec.HP
	hum.Health = spec.HP
	hum.WalkSpeed = 19
	hum.HipHeight = 2.42 * 1.12
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model

	hum.Died:Connect(function()
		MafiaVisualBuilder.PlayDeathSequence(model, true, function(impactPos: Vector3)
			BlackMarketService.BroadcastSFX("BodyDrop", impactPos)
		end)
	end)

	model.PrimaryPart = root
	model:SetAttribute("MafiaTitle", spec.Name)
	model:SetAttribute("HitContractOwner", player.UserId)
	model:SetAttribute("BountyGold", spec.Gold)
	model:SetAttribute("BountyExp", 160)
	model:SetAttribute("BountyRep", spec.Rep)
	CollectionService:AddTag(model, "ApexMafiaUnit")
	CollectionService:AddTag(model, "AnimatedRaiderLimbs")
	model.Parent = bountyFolder or Workspace

	activeHits[player] = {
		Owner = player,
		TargetName = spec.Name,
		RewardGold = spec.Gold,
		RewardRep = spec.Rep,
		Model = model,
		Humanoid = hum,
		Root = root,
	}

	return true, string.format("SYNDICATE HIT ACCEPTED: Eliminate %s (+%dG & +%d Rep)! Click again to warp near target.", spec.Name, spec.Gold, spec.Rep)
end

function BountyService.GetSnapshot(player: Player): { [string]: any }
	local hit = activeHits[player]
	local hitActive = (hit ~= nil and hit.Model.Parent ~= nil and hit.Humanoid.Health > 0)
	local cd = math.max(0, math.ceil((hitCooldownUntil[player] or 0) - os.clock()))
	local myBounty = playerBounties[player] or 0
	return {
		HitActive = hitActive,
		HitTargetName = if hitActive and hit then hit.TargetName else nil,
		HitRewardGold = if hitActive and hit then hit.RewardGold else 520,
		HitCooldown = cd,
		MyBounty = myBounty,
	}
end

function BountyService.Start(): ()
	if isRunning then return end
	isRunning = true

	local existing = Workspace:FindFirstChild("BountyHitTargets")
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		bountyFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "BountyHitTargets"
		f.Parent = Workspace
		bountyFolder = f
	end

	BlackMarketService.OnHostileKilled(function(killer: Player, hitModel: Model)
		local ownerId = hitModel:GetAttribute("HitContractOwner")
		if typeof(ownerId) == "number" then
			local ownerP = Players:GetPlayerByUserId(ownerId)
			if ownerP and activeHits[ownerP] and activeHits[ownerP].Model == hitModel then
				local h = activeHits[ownerP]
				activeHits[ownerP] = nil
				hitCooldownUntil[ownerP] = os.clock() + 30
				sendToast(killer, string.format("HIT CONTRACT COMPLETED: Eliminated %s (+%dG & +%d Rep)!", h.TargetName, h.RewardGold, h.RewardRep))
			end
		end
		local victimP = Players:GetPlayerFromCharacter(hitModel)
		if victimP and (playerBounties[victimP] or 0) > 0 then
			local amt = playerBounties[victimP]
			playerBounties[victimP] = nil
			victimP:SetAttribute("SyndicateBounty", nil)
			PlayerDataService.AddRewards(killer, amt, 100, 45)
			sendToast(nil, string.format("%s claimed the %d Gold Bounty on %s!", killer.DisplayName, amt, victimP.DisplayName))
		end
	end)

	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	playerRemovingConn = Players.PlayerRemoving:Connect(function(p: Player)
		playerBounties[p] = nil
		if activeHits[p] and activeHits[p].Model.Parent then
			activeHits[p].Model:Destroy()
		end
		activeHits[p] = nil
		hitCooldownUntil[p] = nil
	end)

	print("[Food Empire] BountyService started (Syndicate Hit Contracts & Player Bounties active)!")
end

function BountyService.Stop(): ()
	isRunning = false
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for _, h in pairs(activeHits) do
		if h.Model.Parent then h.Model:Destroy() end
	end
	table.clear(activeHits)
end

return BountyService
