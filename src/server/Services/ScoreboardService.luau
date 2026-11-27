--!strict

-- ScoreboardService:
-- Server-authoritative 8-player Co-op Scoreboard telemetry & presence tracker.
-- Broadcasts structured base-grouped rosters (North, South, East, West — 2 slots each = 8 players)
-- including live network ping, Online / Inactive (AFK) / Disconnected (90s grace) status,
-- and compact player progression stats (Level, Reputation, Coins).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")

export type PlayerConnectionStatus = "Online" | "Inactive" | "Disconnected"

export type ScoreboardPlayerEntry = {
	UserId: number,
	DisplayName: string,
	Username: string,
	Status: PlayerConnectionStatus,
	PingMs: number?,
	Level: number,
	Reputation: number,
	Coins: number,
	DisconnectedSecondsAgo: number?,
}

export type ScoreboardBaseGroup = {
	Slot: BaseService.BaseSlot,
	DisplayName: string,
	MemberCount: number,
	MaxMembers: number,
	HQLevel: number,
	Entries: { ScoreboardPlayerEntry },
}

export type ScoreboardSnapshot = {
	MaxPlayers: number,
	OnlineCount: number,
	ActiveCount: number,
	InactiveCount: number,
	DisconnectedCount: number,
	Bases: { ScoreboardBaseGroup },
	Unassigned: { ScoreboardPlayerEntry },
}

type ActivityRecord = {
	LastActiveAt: number,
	WindowFocused: boolean,
	ClientReportsActive: boolean,
	LastPosition: Vector3?,
	LastSlot: BaseService.BaseSlot?,
	LastRemoteAt: number,
}

type DisconnectedRecord = {
	UserId: number,
	DisplayName: string,
	Username: string,
	Slot: BaseService.BaseSlot,
	Level: number,
	Reputation: number,
	Coins: number,
	DisconnectedAt: number,
	ExpiresAt: number,
}

local ScoreboardService = {}

local BROADCAST_INTERVAL = 1.5
local INACTIVE_IDLE_SECONDS = 45
local UNFOCUSED_IDLE_SECONDS = 15
local DISCONNECT_RETENTION_SECONDS = 90
local MIN_MOVE_STUDS = 1.5

local BASE_DISPLAY_NAMES: { [BaseService.BaseSlot]: string } = {
	North = "NORTH BASE",
	South = "SOUTH BASE",
	East = "EAST BASE",
	West = "WEST BASE",
}

local isRunning = false
local syncRemote: RemoteEvent? = nil
local activityRemote: RemoteEvent? = nil
local broadcastThread: thread? = nil
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local activityConn: RBXScriptConnection? = nil
local unsubBaseAssigned: (() -> ())? = nil
local unsubBaseReleased: (() -> ())? = nil

local activityByPlayer: { [Player]: ActivityRecord } = {}
local disconnectedBySlot: { [BaseService.BaseSlot]: { DisconnectedRecord } } = {
	North = {},
	South = {},
	East = {},
	West = {},
}

local function ensureRemotes(): (RemoteEvent?, RemoteEvent?)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
		remotes = f
	end
	if not remotes then
		return nil, nil
	end

	local sEv = remotes:FindFirstChild("ScoreboardSync")
	if not (sEv and sEv:IsA("RemoteEvent")) then
		local created = Instance.new("RemoteEvent")
		created.Name = "ScoreboardSync"
		created.Parent = remotes
		sEv = created
	end

	local aEv = remotes:FindFirstChild("PlayerActivityPing")
	if not (aEv and aEv:IsA("RemoteEvent")) then
		local created = Instance.new("RemoteEvent")
		created.Name = "PlayerActivityPing"
		created.Parent = remotes
		aEv = created
	end

	syncRemote = sEv :: RemoteEvent
	activityRemote = aEv :: RemoteEvent
	return syncRemote, activityRemote
end

local function ensureActivityRecord(player: Player): ActivityRecord
	local rec = activityByPlayer[player]
	if rec then
		return rec
	end
	local created: ActivityRecord = {
		LastActiveAt = os.clock(),
		WindowFocused = true,
		ClientReportsActive = true,
		LastPosition = nil,
		LastSlot = BaseService.GetPlayerBaseSlot(player),
		LastRemoteAt = 0,
	}
	activityByPlayer[player] = created
	return created
end

local function clearDisconnectedUser(userId: number): ()
	for _, slot in ipairs(BaseService.GetSlotOrder()) do
		local list = disconnectedBySlot[slot]
		if list then
			for i = #list, 1, -1 do
				if list[i].UserId == userId then
					table.remove(list, i)
				end
			end
		end
	end
end

local function pruneDisconnectedRecords(now: number): ()
	for _, slot in ipairs(BaseService.GetSlotOrder()) do
		local list = disconnectedBySlot[slot]
		if list then
			local liveCount = BaseService.GetBasePlayerCount(slot)
			local maxRetained = math.max(0, BaseService.MAX_PLAYERS_PER_BASE - liveCount)
			for i = #list, 1, -1 do
				if now >= list[i].ExpiresAt then
					table.remove(list, i)
				end
			end
			-- If new players filled the base slot(s), drop oldest ghost entries so total entries stay <= 2
			while #list > maxRetained do
				table.remove(list, 1)
			end
		end
	end
end

local function recordPlayerDisconnect(player: Player, slot: BaseService.BaseSlot?): ()
	local resolvedSlot = slot or (activityByPlayer[player] and activityByPlayer[player].LastSlot)
	if not resolvedSlot then
		return
	end
	local list = disconnectedBySlot[resolvedSlot]
	if not list then
		return
	end

	clearDisconnectedUser(player.UserId)

	local profile = PlayerDataService.GetProfile(player)
	local now = os.clock()
	table.insert(list, {
		UserId = player.UserId,
		DisplayName = player.DisplayName,
		Username = player.Name,
		Slot = resolvedSlot,
		Level = math.max(1, math.floor(profile.Level or 1)),
		Reputation = math.max(0, math.floor(profile.Reputation or 0)),
		Coins = math.max(0, math.floor(profile.Coins or 0)),
		DisconnectedAt = now,
		ExpiresAt = now + DISCONNECT_RETENTION_SECONDS,
	})
	pruneDisconnectedRecords(now)
end

local function samplePlayerPingMs(player: Player): number
	local ok, rawPing = pcall(function()
		return player:GetNetworkPing()
	end)
	if not ok or typeof(rawPing) ~= "number" or rawPing ~= rawPing then
		return 0
	end
	return math.clamp(math.floor(rawPing * 1000 + 0.5), 0, 9999)
end

local function evaluatePlayerStatus(player: Player, now: number): PlayerConnectionStatus
	local rec = ensureActivityRecord(player)

	-- Server-side movement heartbeat fallback so moving players are always marked Online
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local pos = root.Position
		if rec.LastPosition then
			if (pos - rec.LastPosition).Magnitude >= MIN_MOVE_STUDS then
				rec.LastActiveAt = now
			end
		end
		rec.LastPosition = pos
	end

	local idleSec = now - rec.LastActiveAt
	if not rec.ClientReportsActive then
		return "Inactive"
	end
	if not rec.WindowFocused and idleSec >= UNFOCUSED_IDLE_SECONDS then
		return "Inactive"
	end
	if idleSec >= INACTIVE_IDLE_SECONDS then
		return "Inactive"
	end
	return "Online"
end

local function buildLiveEntry(player: Player, now: number): ScoreboardPlayerEntry
	local profile = PlayerDataService.GetProfile(player)
	local status = evaluatePlayerStatus(player, now)
	return {
		UserId = player.UserId,
		DisplayName = player.DisplayName,
		Username = player.Name,
		Status = status,
		PingMs = samplePlayerPingMs(player),
		Level = math.max(1, math.floor(profile.Level or 1)),
		Reputation = math.max(0, math.floor(profile.Reputation or 0)),
		Coins = math.max(0, math.floor(profile.Coins or 0)),
		DisconnectedSecondsAgo = nil,
	}
end

function ScoreboardService.GetSnapshot(): ScoreboardSnapshot
	local now = os.clock()
	pruneDisconnectedRecords(now)

	local slotOrder = BaseService.GetSlotOrder()
	local maxPlayers = #slotOrder * BaseService.MAX_PLAYERS_PER_BASE
	local basesOut: { ScoreboardBaseGroup } = {}
	local assignedSet: { [Player]: boolean } = {}

	local onlineCount = 0
	local activeCount = 0
	local inactiveCount = 0
	local disconnectedCount = 0

	for _, slot in ipairs(slotOrder) do
		local members = BaseService.GetBasePlayers(slot)
		local entries: { ScoreboardPlayerEntry } = {}
		local hqLevel = 1

		for _, plr in ipairs(members) do
			assignedSet[plr] = true
			local rec = ensureActivityRecord(plr)
			rec.LastSlot = slot

			local prof = PlayerDataService.GetProfile(plr)
			hqLevel = math.max(hqLevel, math.floor(prof.RestaurantLevel or 1))

			local entry = buildLiveEntry(plr, now)
			onlineCount += 1
			if entry.Status == "Inactive" then
				inactiveCount += 1
			else
				activeCount += 1
			end
			table.insert(entries, entry)
		end

		local ghostList = disconnectedBySlot[slot]
		if ghostList then
			for _, g in ipairs(ghostList) do
				if #entries >= BaseService.MAX_PLAYERS_PER_BASE then
					break
				end
				disconnectedCount += 1
				table.insert(entries, {
					UserId = g.UserId,
					DisplayName = g.DisplayName,
					Username = g.Username,
					Status = "Disconnected",
					PingMs = nil,
					Level = g.Level,
					Reputation = g.Reputation,
					Coins = g.Coins,
					DisconnectedSecondsAgo = math.max(0, math.floor(now - g.DisconnectedAt)),
				})
			end
		end

		table.insert(basesOut, {
			Slot = slot,
			DisplayName = BASE_DISPLAY_NAMES[slot] or (string.upper(slot) .. " BASE"),
			MemberCount = #members,
			MaxMembers = BaseService.MAX_PLAYERS_PER_BASE,
			HQLevel = hqLevel,
			Entries = entries,
		})
	end

	local unassigned: { ScoreboardPlayerEntry } = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if not assignedSet[plr] then
			local entry = buildLiveEntry(plr, now)
			onlineCount += 1
			if entry.Status == "Inactive" then
				inactiveCount += 1
			else
				activeCount += 1
			end
			table.insert(unassigned, entry)
		end
	end

	return {
		MaxPlayers = maxPlayers,
		OnlineCount = onlineCount,
		ActiveCount = activeCount,
		InactiveCount = inactiveCount,
		DisconnectedCount = disconnectedCount,
		Bases = basesOut,
		Unassigned = unassigned,
	}
end

function ScoreboardService.BroadcastNow(): ()
	local ev = syncRemote or select(1, ensureRemotes())
	if not ev then
		return
	end
	if #Players:GetPlayers() == 0 then
		return
	end
	ev:FireAllClients(ScoreboardService.GetSnapshot())
end

function ScoreboardService.MarkPlayerActive(player: Player): ()
	if not player.Parent then
		return
	end
	local rec = ensureActivityRecord(player)
	rec.LastActiveAt = os.clock()
	rec.ClientReportsActive = true
end

function ScoreboardService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local sEv, aEv = ensureRemotes()

	for _, plr in ipairs(Players:GetPlayers()) do
		ensureActivityRecord(plr)
	end

	playerAddedConn = Players.PlayerAdded:Connect(function(plr)
		clearDisconnectedUser(plr.UserId)
		ensureActivityRecord(plr)
		task.defer(function()
			if isRunning and plr.Parent and sEv then
				sEv:FireClient(plr, ScoreboardService.GetSnapshot())
				ScoreboardService.BroadcastNow()
			end
		end)
	end)

	playerRemovingConn = Players.PlayerRemoving:Connect(function(plr)
		local lastSlot = BaseService.GetPlayerBaseSlot(plr) or (activityByPlayer[plr] and activityByPlayer[plr].LastSlot)
		if lastSlot then
			recordPlayerDisconnect(plr, lastSlot)
		end
		activityByPlayer[plr] = nil
		task.defer(function()
			if isRunning then
				ScoreboardService.BroadcastNow()
			end
		end)
	end)

	unsubBaseAssigned = BaseService.OnBaseAssigned(function(plr, slot)
		clearDisconnectedUser(plr.UserId)
		local rec = ensureActivityRecord(plr)
		rec.LastSlot = slot
		rec.LastActiveAt = os.clock()
		pruneDisconnectedRecords(os.clock())
		ScoreboardService.BroadcastNow()
	end)

	unsubBaseReleased = BaseService.OnBaseReleased(function(slot, leavingPlayer, _)
		recordPlayerDisconnect(leavingPlayer, slot)
		ScoreboardService.BroadcastNow()
	end)

	if aEv then
		activityConn = aEv.OnServerEvent:Connect(function(plr: Player, isActive: any, isFocused: any)
			local now = os.clock()
			local rec = ensureActivityRecord(plr)
			if (now - rec.LastRemoteAt) < 0.25 then
				return
			end
			rec.LastRemoteAt = now

			local prevActive = rec.ClientReportsActive
			local prevFocus = rec.WindowFocused

			if typeof(isActive) == "boolean" then
				rec.ClientReportsActive = isActive
				if isActive then
					rec.LastActiveAt = now
				end
			end
			if typeof(isFocused) == "boolean" then
				rec.WindowFocused = isFocused
				if isFocused then
					rec.LastActiveAt = now
				end
			end

			if prevActive ~= rec.ClientReportsActive or prevFocus ~= rec.WindowFocused then
				ScoreboardService.BroadcastNow()
			end
		end)
	end

	broadcastThread = task.spawn(function()
		while isRunning do
			task.wait(BROADCAST_INTERVAL)
			if not isRunning then
				break
			end
			ScoreboardService.BroadcastNow()
		end
	end)

	print("[Food Empire] ScoreboardService started (8-Player Co-op Base Roster, Ping & Online/Inactive/Disconnected telemetry live)!")
end

function ScoreboardService.Stop(): ()
	isRunning = false
	if broadcastThread then
		task.cancel(broadcastThread)
		broadcastThread = nil
	end
	if playerAddedConn then
		playerAddedConn:Disconnect()
		playerAddedConn = nil
	end
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	if activityConn then
		activityConn:Disconnect()
		activityConn = nil
	end
	if unsubBaseAssigned then
		unsubBaseAssigned()
		unsubBaseAssigned = nil
	end
	if unsubBaseReleased then
		unsubBaseReleased()
		unsubBaseReleased = nil
	end
	table.clear(activityByPlayer)
end

return ScoreboardService
