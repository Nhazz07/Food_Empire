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

local MAX_FAMILY_MEMBERS = 4

local familiesById: { [string]: SyndicateFamily } = {}
local familyByPlayer: { [Player]: SyndicateFamily } = {}
local changeListeners: { () -> () } = {}
local playerRemovingConn: RBXScriptConnection? = nil
local nextFamilyCounter = 0
local isRunning = false

local function notifyFamiliesChanged(): ()
	for _, cb in ipairs(changeListeners) do
		task.spawn(cb)
	end
end

local function sendToast(player: Player, msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, msg)
	end
end

local function sanitizeFamilyName(rawName: string?, fallbackPlayer: Player): string
	if typeof(rawName) == "string" then
		-- Strip control chars, collapse spaces, trim leading/trailing whitespace
		local cleaned = rawName:gsub("[%c]", ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
		if #cleaned >= 2 then
			return string.upper(string.sub(cleaned, 1, 20))
		end
	end
	local base = (fallbackPlayer.DisplayName:gsub("[%c]", "")):match("^%s*(.-)%s*$") or "DON"
	return string.upper(string.sub(base, 1, 12)) .. " FAMILY"
end

function SyndicateFamilyService.OnFamilyChanged(callback: () -> ()): () -> ()
	table.insert(changeListeners, callback)
	return function()
		local idx = table.find(changeListeners, callback)
		if idx then
			table.remove(changeListeners, idx)
		end
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
	local clean = sanitizeFamilyName(rawName, player)
	for _, existing in pairs(familiesById) do
		if existing.Name == clean then
			return false, string.format("A Syndicate Family named %s already exists — pick another name or join it!", clean)
		end
	end

	nextFamilyCounter += 1
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
	notifyFamiliesChanged()
	return true, string.format("FOUNDED SYNDICATE FAMILY: %s! Allies share friendly-fire immunity & +20%% co-op raid dividends!", fam.Name)
end

function SyndicateFamilyService.JoinFamily(player: Player, familyId: string?): (boolean, string)
	if familyByPlayer[player] then
		return false, "Leave your current Syndicate Family first!"
	end
	local targetFam: SyndicateFamily? = nil
	if typeof(familyId) == "string" and familyId ~= "" then
		targetFam = familiesById[familyId]
		if not targetFam then
			return false, "That Syndicate Family is no longer active!"
		end
	else
		for _, f in pairs(familiesById) do
			if #f.Members > 0 and #f.Members < MAX_FAMILY_MEMBERS then
				targetFam = f
				break
			end
		end
	end
	if not targetFam then
		return false, "No open Syndicate Families in this server yet — found your own!"
	end
	if #targetFam.Members >= MAX_FAMILY_MEMBERS then
		return false, string.format("%s is full (%d/%d members)!", targetFam.Name, MAX_FAMILY_MEMBERS, MAX_FAMILY_MEMBERS)
	end
	table.insert(targetFam.Members, player)
	familyByPlayer[player] = targetFam
	player:SetAttribute("SyndicateFamilyName", targetFam.Name)
	for _, m in ipairs(targetFam.Members) do
		if m ~= player and m.Parent then
			sendToast(m, string.format("%s joined %s!", player.DisplayName, targetFam.Name))
		end
	end
	notifyFamiliesChanged()
	return true, string.format("Joined %s! Friendly-fire immunity & +20%% Co-op Family Dividends active!", targetFam.Name)
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

	-- Prune any disconnected members & cleanly promote next Don if Founder left!
	for i = #fam.Members, 1, -1 do
		if not fam.Members[i].Parent then
			table.remove(fam.Members, i)
		end
	end
	if #fam.Members == 0 then
		familiesById[fam.Id] = nil
	else
		if fam.FounderUserId == player.UserId then
			local newDon = fam.Members[1]
			fam.FounderUserId = newDon.UserId
			fam.FounderName = newDon.DisplayName
			sendToast(newDon, string.format("You are now the Don of %s!", fam.Name))
		end
		for _, m in ipairs(fam.Members) do
			if m.Parent then
				sendToast(m, string.format("%s left %s.", player.DisplayName, fam.Name))
			end
		end
	end
	notifyFamiliesChanged()
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
	local memberDetails: { { UserId: number, DisplayName: string, BaseSlot: string, IsFounder: boolean } } = {}
	if myFam then
		for _, m in ipairs(myFam.Members) do
			if m.Parent then
				table.insert(myMembers, m.DisplayName)
				local slotAttr = m:GetAttribute("BaseSlot")
				table.insert(memberDetails, {
					UserId = m.UserId,
					DisplayName = m.DisplayName,
					BaseSlot = if typeof(slotAttr) == "string" and slotAttr ~= "" then slotAttr else "Unassigned",
					IsFounder = m.UserId == myFam.FounderUserId,
				})
			end
		end
	end
	local openList: { { Id: string, Name: string, FounderName: string, Count: number, MaxCount: number } } = {}
	for _, f in pairs(familiesById) do
		local liveCount = 0
		for _, m in ipairs(f.Members) do
			if m.Parent then liveCount += 1 end
		end
		if f ~= myFam and liveCount > 0 then
			table.insert(openList, {
				Id = f.Id,
				Name = f.Name,
				FounderName = f.FounderName,
				Count = liveCount,
				MaxCount = MAX_FAMILY_MEMBERS,
			})
		end
	end
	table.sort(openList, function(a, b)
		if a.Count ~= b.Count then return a.Count > b.Count end
		return a.Name < b.Name
	end)
	return {
		InFamily = myFam ~= nil,
		FamilyId = if myFam then myFam.Id else nil,
		FamilyName = if myFam then myFam.Name else nil,
		FounderUserId = if myFam then myFam.FounderUserId else nil,
		FounderName = if myFam then myFam.FounderName else nil,
		MaxMembers = MAX_FAMILY_MEMBERS,
		Members = myMembers,
		MemberDetails = memberDetails,
		OpenFamilies = openList,
	}
end

function SyndicateFamilyService.Start(): ()
	if isRunning then return end
	isRunning = true
	playerRemovingConn = Players.PlayerRemoving:Connect(function(p: Player)
		SyndicateFamilyService.LeaveFamily(p)
	end)
	print("[Food Empire] SyndicateFamilyService started (Co-op Mafia Families, Friendly-Fire Immunity & Raid Dividends active)!")
end

function SyndicateFamilyService.Stop(): ()
	isRunning = false
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	table.clear(familiesById)
	table.clear(familyByPlayer)
end

return SyndicateFamilyService
