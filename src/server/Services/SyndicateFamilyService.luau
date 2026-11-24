--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require("./PlayerDataService")

export type SyndicateFamily = {
	Id: string,
	Name: string,
	FounderUserId: number,
	FounderName: string,
	Members: { Player },
}

local SyndicateFamilyService = {}

local familiesById: { [string]: SyndicateFamily } = {}
local familyByPlayer: { [Player]: SyndicateFamily } = {}
local nextFamilyCounter = 0
local isRunning = false

local function sendToast(player: Player, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

function SyndicateFamilyService.AreFamilyAllies(p1: Player, p2: Player): boolean
	if p1 == p2 then return true end
	local f1 = familyByPlayer[p1]
	local f2 = familyByPlayer[p2]
	return f1 ~= nil and f1 == f2
end

function SyndicateFamilyService.GetFamilyName(player: Player): string?
	local f = familyByPlayer[player]
	return if f then f.Name else nil
end

function SyndicateFamilyService.CreateFamily(player: Player, rawName: string?): (boolean, string)
	if familyByPlayer[player] then
		return false, string.format("You are already in %s! Leave first to found a new Family.", familyByPlayer[player].Name)
	end
	nextFamilyCounter += 1
	local clean = if typeof(rawName) == "string" and #rawName >= 2
		then string.upper(string.sub(rawName, 1, 20))
		else (string.upper(string.sub(player.DisplayName, 1, 12)) .. " FAMILY")
	local fam: SyndicateFamily = {
		Id = "FAM_" .. tostring(nextFamilyCounter),
		Name = clean,
		FounderUserId = player.UserId,
		FounderName = player.DisplayName,
		Members = { player },
	}
	familiesById[fam.Id] = fam
	familyByPlayer[player] = fam
	player:SetAttribute("SyndicateFamilyName", fam.Name)
	return true, string.format("FOUNDED SYNDICATE FAMILY: %s! Allies share friendly-fire immunity & co-op raid dividends!", fam.Name)
end

function SyndicateFamilyService.JoinFamily(player: Player, familyId: string?): (boolean, string)
	if familyByPlayer[player] then
		return false, "Leave your current Syndicate Family first!"
	end
	local targetFam: SyndicateFamily? = nil
	if typeof(familyId) == "string" and familiesById[familyId] then
		targetFam = familiesById[familyId]
	else
		for _, f in pairs(familiesById) do
			targetFam = f
			break
		end
	end
	if not targetFam then
		return SyndicateFamilyService.CreateFamily(player, nil)
	end
	if #targetFam.Members >= 4 then
		return false, targetFam.Name .. " is full (4/4 members)!"
	end
	table.insert(targetFam.Members, player)
	familyByPlayer[player] = targetFam
	player:SetAttribute("SyndicateFamilyName", targetFam.Name)
	for _, m in ipairs(targetFam.Members) do
		if m ~= player and m.Parent then
			sendToast(m, string.format("%s joined %s!", player.DisplayName, targetFam.Name))
		end
	end
	return true, string.format("Joined %s! Friendly-fire protection & +20%% Co-op Family Dividends active!", targetFam.Name)
end

function SyndicateFamilyService.LeaveFamily(player: Player): (boolean, string)
	local fam = familyByPlayer[player]
	if not fam then
		return false, "You are not currently in a Syndicate Family."
	end
	local idx = table.find(fam.Members, player)
	if idx then
		table.remove(fam.Members, idx)
	end
	familyByPlayer[player] = nil
	player:SetAttribute("SyndicateFamilyName", nil)
	if #fam.Members == 0 then
		familiesById[fam.Id] = nil
	end
	return true, "Left " .. fam.Name
end

function SyndicateFamilyService.ShareFamilyDividend(earner: Player, baseGold: number, baseRep: number, reason: string): ()
	local fam = familyByPlayer[earner]
	if not fam then return end
	local shareG = math.max(15, math.floor(baseGold * 0.20))
	local shareR = math.max(5, math.floor(baseRep * 0.20))
	for _, m in ipairs(fam.Members) do
		if m ~= earner and m.Parent then
			PlayerDataService.AddRewards(m, shareG, math.floor(shareG * 0.2), shareR)
			sendToast(m, string.format("FAMILY CO-OP DIVIDEND (%s): +%dG & +%d Rep from %s!", fam.Name, shareG, shareR, reason))
		end
	end
end

function SyndicateFamilyService.GetSnapshot(player: Player): { [string]: any }
	local myFam = familyByPlayer[player]
	local myMembers: { string } = {}
	if myFam then
		for _, m in ipairs(myFam.Members) do
			if m.Parent then table.insert(myMembers, m.DisplayName) end
		end
	end
	local openList: { { Id: string, Name: string, Count: number } } = {}
	for _, f in pairs(familiesById) do
		if f ~= myFam and #f.Members > 0 and #f.Members < 4 then
			table.insert(openList, { Id = f.Id, Name = f.Name, Count = #f.Members })
		end
	end
	return {
		InFamily = myFam ~= nil,
		FamilyId = if myFam then myFam.Id else nil,
		FamilyName = if myFam then myFam.Name else nil,
		Members = myMembers,
		OpenFamilies = openList,
	}
end

function SyndicateFamilyService.Start(): ()
	if isRunning then return end
	isRunning = true
	Players.PlayerRemoving:Connect(function(p: Player)
		SyndicateFamilyService.LeaveFamily(p)
	end)
	print("[Food Empire] SyndicateFamilyService started (Co-op Mafia Families, Friendly-Fire Immunity & Raid Dividends active)!")
end

function SyndicateFamilyService.Stop(): ()
	isRunning = false
	table.clear(familiesById)
	table.clear(familyByPlayer)
end

return SyndicateFamilyService
