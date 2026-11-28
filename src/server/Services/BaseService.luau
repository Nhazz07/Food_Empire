--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local RestaurantExpansionBuilder = require("./RestaurantExpansionBuilder")

export type BaseSlot = "North" | "South" | "East" | "West"
export type BaseAssignedCallback = (player: Player, slot: BaseSlot) -> ()
export type BaseReleasedCallback = (slot: BaseSlot, leavingPlayer: Player, remainingCount: number) -> ()

local BaseService = {}

BaseService.MAX_PLAYERS_PER_BASE = 2

local SLOT_ORDER: { BaseSlot } = { "North", "South", "East", "West" }

local slotMembers: { [BaseSlot]: { Player } } = {
	North = {},
	South = {},
	East = {},
	West = {},
}
local playerSlots: { [Player]: BaseSlot } = {}
local baseDefenseTiers: { [BaseSlot]: number } = {
	North = 1,
	South = 1,
	East = 1,
	West = 1,
}
local baseInteriorFlags: { [BaseSlot]: { HasDualStove: boolean, HasVIPBooths: boolean } } = {
	North = { HasDualStove = false, HasVIPBooths = false },
	South = { HasDualStove = false, HasVIPBooths = false },
	East = { HasDualStove = false, HasVIPBooths = false },
	West = { HasDualStove = false, HasVIPBooths = false },
}

local listeners: { BaseAssignedCallback } = {}
local releaseListeners: { BaseReleasedCallback } = {}
local isRunning = false
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local charConnections: { [Player]: RBXScriptConnection } = {}
local turretThread: thread? = nil

function BaseService.GetSlotOrder(): { BaseSlot }
	return SLOT_ORDER
end

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

function BaseService.GetBasePlayers(slot: BaseSlot): { Player }
	local out: { Player } = {}
	local members = slotMembers[slot]
	if members then
		for _, p in ipairs(members) do
			if p.Parent then
				table.insert(out, p)
			end
		end
	end
	return out
end

function BaseService.GetBasePlayerCount(slot: BaseSlot): number
	return #BaseService.GetBasePlayers(slot)
end

function BaseService.GetBaseLeadPlayer(slot: BaseSlot): Player?
	local members = BaseService.GetBasePlayers(slot)
	return members[1]
end

function BaseService.GetTeammates(player: Player): { Player }
	local slot = playerSlots[player]
	if not slot then
		return {}
	end
	local out: { Player } = {}
	for _, p in ipairs(BaseService.GetBasePlayers(slot)) do
		if p ~= player then
			table.insert(out, p)
		end
	end
	return out
end

function BaseService.AreBaseTeammates(a: Player, b: Player): boolean
	if a == b then
		return true
	end
	local slotA = playerSlots[a]
	return slotA ~= nil and slotA == playerSlots[b]
end

function BaseService.GetBaseFactionId(slot: BaseSlot): string
	return "Base_" .. slot
end

function BaseService.GetPlayerFactionId(player: Player): string
	local slot = playerSlots[player]
	if slot then
		return "Base_" .. slot
	end
	local slotAttr = player:GetAttribute("BaseSlot")
	if typeof(slotAttr) == "string" and slotAttr ~= "" then
		return "Base_" .. slotAttr
	end
	return "Player_" .. tostring(player.UserId)
end

function BaseService.GetPlayersForFaction(factionId: string): { Player }
	local slotStr = string.match(factionId, "^Base_(%a+)$")
	if slotStr and slotMembers[slotStr :: BaseSlot] then
		return BaseService.GetBasePlayers(slotStr :: BaseSlot)
	end
	local uidStr = string.match(factionId, "^Player_(%d+)$")
	if uidStr then
		local p = Players:GetPlayerByUserId(tonumber(uidStr) or 0)
		if p then
			return { p }
		end
	end
	return {}
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

function BaseService.OnBaseReleased(callback: BaseReleasedCallback): () -> ()
	table.insert(releaseListeners, callback)
	return function()
		local idx = table.find(releaseListeners, callback)
		if idx then
			table.remove(releaseListeners, idx)
		end
	end
end

function BaseService.GetSpawnCFrameForPlayer(player: Player): CFrame?
	local slot = playerSlots[player]
	if not slot then
		return nil
	end

	local baseModel = BaseService.GetBaseModel(slot)
	if not baseModel then
		return nil
	end

	local members = BaseService.GetBasePlayers(slot)
	local memberIndex = table.find(members, player) or 1
	local infra = baseModel:FindFirstChild("BaseCoopInfrastructure")
	local coopPadName = if memberIndex == 1 then "CoopSpawn_1" else "CoopSpawn_2"
	local coopPad = if infra then infra:FindFirstChild(coopPadName) else nil
	if coopPad and coopPad:IsA("BasePart") then
		return coopPad.CFrame + Vector3.new(0, 4.5, 0)
	end

	local spawnPart = baseModel:FindFirstChild("BaseSpawn")
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return nil
	end

	local sideOffset = if memberIndex == 1 then -11 else 11
	return (spawnPart.CFrame * CFrame.new(sideOffset, 0, 0)) + Vector3.new(0, 5.0, 0)
end

local function teleportToBaseSpawn(player: Player, character: Model): ()
	local spawnCF = BaseService.GetSpawnCFrameForPlayer(player)
	if not spawnCF then
		return
	end

	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root and root:IsA("BasePart") then
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(spawnCF.Position)
			end)
			if character.Parent then
				character:PivotTo(spawnCF)
			end
		end)
	end
end

local function updateGateOwnerSign(slot: BaseSlot): ()
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
			label.Font = Enum.Font.GothamBlack
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
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.25
		label.Parent = newGui
	end

	local members = BaseService.GetBasePlayers(slot)
	if #members >= 2 then
		label.Text = string.format("%s & %s (CO-OP 2/2)", string.upper(members[1].DisplayName), string.upper(members[2].DisplayName))
	elseif #members == 1 then
		label.Text = string.format("%s'S EMPIRE (1/2)", string.upper(members[1].DisplayName))
	else
		label.Text = string.format("%s CO-OP BASE (0/2)", string.upper(slot))
	end
end

local function syncBaseTeamAttributes(slot: BaseSlot): ()
	local members = BaseService.GetBasePlayers(slot)
	local baseModel = BaseService.GetBaseModel(slot)
	if baseModel then
		baseModel:SetAttribute("OwnerUserId", if members[1] then members[1].UserId else nil)
		baseModel:SetAttribute("CoopCount", #members)
		local idParts: { string } = {}
		for _, m in ipairs(members) do
			table.insert(idParts, tostring(m.UserId))
		end
		baseModel:SetAttribute("CoopMemberIds", table.concat(idParts, ","))
	end

	for idx, m in ipairs(members) do
		m:SetAttribute("BaseSlot", slot)
		m:SetAttribute("BaseFactionId", "Base_" .. slot)
		m:SetAttribute("BaseMemberIndex", idx)
		local partner = if idx == 1 then members[2] else members[1]
		m:SetAttribute("CoopPartnerName", if partner then partner.DisplayName else "")
		m:SetAttribute("BaseTeamCount", #members)
	end

	updateGateOwnerSign(slot)
end

type RestaurantThemeSpec = {
	BrandTitle: string,
	BrandSub: string,
	WainscotColor: Color3,
	WainscotMat: Enum.Material,
	UpperWallColor: Color3,
	UpperWallMat: Enum.Material,
	WoodTrimColor: Color3,
	FloorColor: Color3,
	FloorMat: Enum.Material,
	KitchenFloorColor: Color3,
	AwningPrimary: Color3,
	AwningSecondary: Color3,
	SeatColor: Color3,
	TableColor: Color3,
	BrassAccent: Color3,
}

local RESTAURANT_THEMES: { [BaseSlot]: RestaurantThemeSpec } = {
	East = {
		BrandTitle = "KUROSHIO OMAKASE & IZAKAYA",
		BrandSub = "HARBOR SEAFOOD GRILL  |  TEPPANYAKI & SASHIMI",
		WainscotColor = Color3.fromRGB(38, 42, 48),
		WainscotMat = Enum.Material.Slate,
		UpperWallColor = Color3.fromRGB(30, 28, 27),
		UpperWallMat = Enum.Material.WoodPlanks,
		WoodTrimColor = Color3.fromRGB(132, 94, 58),
		FloorColor = Color3.fromRGB(118, 84, 54),
		FloorMat = Enum.Material.WoodPlanks,
		KitchenFloorColor = Color3.fromRGB(44, 48, 54),
		AwningPrimary = Color3.fromRGB(28, 52, 76),
		AwningSecondary = Color3.fromRGB(228, 224, 214),
		SeatColor = Color3.fromRGB(34, 44, 58),
		TableColor = Color3.fromRGB(142, 102, 64),
		BrassAccent = Color3.fromRGB(176, 144, 82),
	},
	West = {
		BrandTitle = "TRATTORIA CORLEONE CHOPHOUSE",
		BrandSub = "WOOD-AGED STEAKS  |  VINTAGE CELLAR & ESPRESSO",
		WainscotColor = Color3.fromRGB(92, 34, 32),
		WainscotMat = Enum.Material.Brick,
		UpperWallColor = Color3.fromRGB(186, 172, 152),
		UpperWallMat = Enum.Material.Slate,
		WoodTrimColor = Color3.fromRGB(58, 34, 24),
		FloorColor = Color3.fromRGB(72, 44, 30),
		FloorMat = Enum.Material.WoodPlanks,
		KitchenFloorColor = Color3.fromRGB(58, 54, 52),
		AwningPrimary = Color3.fromRGB(116, 26, 32),
		AwningSecondary = Color3.fromRGB(234, 226, 212),
		SeatColor = Color3.fromRGB(108, 26, 32),
		TableColor = Color3.fromRGB(68, 42, 28),
		BrassAccent = Color3.fromRGB(172, 138, 74),
	},
	North = {
		BrandTitle = "LE NOIR IMPERIAL BRASSERIE",
		BrandSub = "PARISIENNE FINE DINING  |  RAW BAR & LOUNGE",
		WainscotColor = Color3.fromRGB(22, 24, 30),
		WainscotMat = Enum.Material.Marble,
		UpperWallColor = Color3.fromRGB(24, 44, 38),
		UpperWallMat = Enum.Material.SmoothPlastic,
		WoodTrimColor = Color3.fromRGB(158, 128, 72),
		FloorColor = Color3.fromRGB(82, 60, 42),
		FloorMat = Enum.Material.Wood,
		KitchenFloorColor = Color3.fromRGB(36, 40, 46),
		AwningPrimary = Color3.fromRGB(24, 54, 44),
		AwningSecondary = Color3.fromRGB(226, 220, 206),
		SeatColor = Color3.fromRGB(28, 62, 48),
		TableColor = Color3.fromRGB(218, 214, 206),
		BrassAccent = Color3.fromRGB(184, 152, 86),
	},
	South = {
		BrandTitle = "EL CARTEL ASADOR & SMOKEHOUSE",
		BrandSub = "MESQUITE PARILLA GRILL  |  OPEN HEARTH & CANTINA",
		WainscotColor = Color3.fromRGB(114, 54, 38),
		WainscotMat = Enum.Material.Brick,
		UpperWallColor = Color3.fromRGB(172, 148, 122),
		UpperWallMat = Enum.Material.Cobblestone,
		WoodTrimColor = Color3.fromRGB(64, 42, 28),
		FloorColor = Color3.fromRGB(86, 56, 36),
		FloorMat = Enum.Material.WoodPlanks,
		KitchenFloorColor = Color3.fromRGB(62, 54, 48),
		AwningPrimary = Color3.fromRGB(132, 42, 30),
		AwningSecondary = Color3.fromRGB(228, 218, 202),
		SeatColor = Color3.fromRGB(84, 46, 30),
		TableColor = Color3.fromRGB(96, 62, 38),
		BrassAccent = Color3.fromRGB(164, 126, 68),
	},
}

local function applyDistinctRestaurantTheme(slot: BaseSlot): ()
	local baseModel = BaseService.GetBaseModel(slot)
	local hq = if baseModel then baseModel:FindFirstChild("RestaurantHQ") else nil
	if not hq or not hq:IsA("Model") or not hq.PrimaryPart then
		return
	end

	local theme = RESTAURANT_THEMES[slot] or RESTAURANT_THEMES.East
	local hqCF = hq.PrimaryPart.CFrame

	-- 1. Restyle existing BistroArchitecture & InteriorFurniture parts to match this restaurant's unique vibe!
	local arch = hq:FindFirstChild("BistroArchitecture")
	if arch then
		for _, p in ipairs(arch:GetDescendants()) do
			if p:IsA("BasePart") then
				local n = p.Name
				if string.find(n, "Brick") then
					p.Color = theme.WainscotColor
					p.Material = theme.WainscotMat
				elseif string.find(n, "Stucco") or string.find(n, "MidL") or string.find(n, "MidR") or n == "UpperFrontWall" then
					p.Color = theme.UpperWallColor
					p.Material = theme.UpperWallMat
				elseif n == "DiningFloor" then
					p.Color = theme.FloorColor
					p.Material = theme.FloorMat
				elseif n == "KitchenTileFloor" then
					p.Color = theme.KitchenFloorColor
					p.Material = Enum.Material.Slate
				elseif string.find(n, "Pilaster") or n == "StoryBelt" or string.find(n, "DoorPillar") or n == "DoorTransom" or n == "RoofEaves" or n == "RoofRidgeCap" or n == "SignFacadeBox" then
					p.Color = theme.WoodTrimColor
					p.Material = Enum.Material.Wood
				elseif string.find(n, "Shutter") or n == "RoofFascia" or n == "SignTopTrim" then
					p.Color = theme.AwningPrimary
					p.Material = Enum.Material.Metal
				elseif string.find(n, "AwningStripe_") then
					local idx = tonumber(string.match(n, "_(%d+)$") or "1") or 1
					p.Color = if idx % 2 == 1 then theme.AwningPrimary else theme.AwningSecondary
				elseif string.find(n, "AwningValance_") then
					local idx = tonumber(string.match(n, "_(%d+)$") or "1") or 1
					p.Color = if idx % 2 == 1 then theme.AwningPrimary else theme.AwningSecondary
				elseif n == "RestaurantMarquee" then
					p.Color = Color3.fromRGB(16, 18, 22)
					for _, gui in ipairs(p:GetChildren()) do
						if gui:IsA("SurfaceGui") then
							gui:Destroy()
						end
					end
					for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
						local sgui = Instance.new("SurfaceGui")
						sgui.Name = "BrandMarqueeGui"
						sgui.Face = face
						sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
						sgui.PixelsPerStud = 30
						sgui.Parent = p

						local bg = Instance.new("Frame")
						bg.Size = UDim2.fromScale(1, 1)
						bg.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
						bg.BorderSizePixel = 0
						bg.Parent = sgui

						local bar = Instance.new("Frame")
						bar.Size = UDim2.new(1, 0, 0, 5)
						bar.BackgroundColor3 = theme.BrassAccent
						bar.BorderSizePixel = 0
						bar.Parent = bg

						local t1 = Instance.new("TextLabel")
						t1.Position = UDim2.new(0.03, 0, 0.12, 0)
						t1.Size = UDim2.new(0.94, 0, 0.46, 0)
						t1.BackgroundTransparency = 1
						t1.Font = Enum.Font.GothamBlack
						t1.TextScaled = true
						t1.Text = theme.BrandTitle
						t1.TextColor3 = Color3.fromRGB(238, 234, 224)
						t1.Parent = bg

						local t2 = Instance.new("TextLabel")
						t2.Position = UDim2.new(0.04, 0, 0.60, 0)
						t2.Size = UDim2.new(0.92, 0, 0.28, 0)
						t2.BackgroundTransparency = 1
						t2.Font = Enum.Font.GothamBold
						t2.TextScaled = true
						t2.Text = theme.BrandSub
						t2.TextColor3 = theme.BrassAccent
						t2.Parent = bg
					end
				end
			end
		end
	end

	local furn = hq:FindFirstChild("InteriorFurniture")
	if furn then
		for _, p in ipairs(furn:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name == "Seat" then
					p.Color = theme.SeatColor
					p.Material = Enum.Material.Leather
				elseif string.find(p.Name, "InTable_") then
					p.Color = theme.TableColor
					p.Material = if slot == "North" then Enum.Material.Marble else Enum.Material.Wood
				elseif p.Name == "KitchenBackCounter" or p.Name == "RangeHood" then
					p.Color = Color3.fromRGB(72, 76, 84)
					p.Material = Enum.Material.Metal
				elseif p.Name == "PendantBulb" then
					p.Color = Color3.fromRGB(255, 218, 158)
					p.Material = Enum.Material.SmoothPlastic
				end
			end
		end
	end

	-- 2. Transform the plain orange CookingStation block, ServeCounter & neon UpgradePad into realistic commercial fixtures!
	local anchors = hq:FindFirstChild("Anchors")
	if anchors then
		local cookPart = anchors:FindFirstChild("CookingStation")
		if cookPart and cookPart:IsA("BasePart") then
			cookPart.Color = Color3.fromRGB(46, 50, 58)
			cookPart.Material = Enum.Material.Metal
			cookPart.Size = Vector3.new(10.2, 3.2, 5.6)
			cookPart.CFrame = hqCF * CFrame.new(-17.5, 2.2, -17.5)
		end

		local servePart = anchors:FindFirstChild("ServeCounter")
		if servePart and servePart:IsA("BasePart") then
			servePart.Color = theme.WoodTrimColor
			servePart.Material = Enum.Material.Wood
		end

		local upgPart = anchors:FindFirstChild("UpgradePad")
		if upgPart and upgPart:IsA("BasePart") then
			upgPart.Color = Color3.fromRGB(32, 35, 42)
			upgPart.Material = Enum.Material.Slate
			upgPart.Size = Vector3.new(7.2, 0.22, 7.2)
			upgPart.CFrame = hqCF * CFrame.new(-18.8, 0.72, 27.5)
		end
	end

	-- 3. Build detailed Custom Interior Architecture & Commercial Kitchen Range inside CustomVibeDecor
	local oldDecor = hq:FindFirstChild("CustomVibeDecor")
	if oldDecor then
		oldDecor:Destroy()
	end
	local decor = Instance.new("Folder")
	decor.Name = "CustomVibeDecor"

	local function dPart(
		name: string,
		sz: Vector3,
		relCF: CFrame,
		col: Color3,
		mat: Enum.Material,
		shape: Enum.PartType?,
		collide: boolean?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = hqCF * relCF
		p.Color = col
		p.Material = mat
		if shape then
			p.Shape = shape
		end
		p.Anchored = true
		p.CanCollide = if collide == nil then false else collide
		p.CanTouch = false
		p.CanQuery = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = decor
		return p
	end

	local steel = Color3.fromRGB(148, 154, 164)
	local darkSteel = Color3.fromRGB(36, 40, 46)
	local castIron = Color3.fromRGB(24, 26, 30)
	local copper = Color3.fromRGB(184, 108, 64)
	local marble = Color3.fromRGB(226, 222, 214)
	local ember = Color3.fromRGB(238, 112, 44)

	-- 3A. Gleaming Stainless Steel Commercial Range on top of CookingStation (-17.5, 2.2, -17.5) — matches Dual-Stove icon!
	local brightSteel = Color3.fromRGB(196, 204, 216)
	local brushedBody = Color3.fromRGB(168, 176, 188)
	local flameOrange = Color3.fromRGB(255, 148, 36)
	dPart("RangeBodyFront", Vector3.new(10.4, 3.2, 5.8), CFrame.new(-17.5, 2.25, -17.5), brushedBody, Enum.Material.Metal, nil, false)
	dPart("RangeCounterTop", Vector3.new(10.8, 0.34, 6.2), CFrame.new(-17.5, 3.96, -17.5), brightSteel, Enum.Material.Metal, nil, false)
	dPart("RangeBacksplash", Vector3.new(10.8, 2.0, 0.36), CFrame.new(-17.5, 5.05, -20.4), brightSteel, Enum.Material.Metal, nil, false)
	dPart("RangeControlStrip", Vector3.new(10.5, 0.65, 0.28), CFrame.new(-17.5, 3.52, -14.55), Color3.fromRGB(48, 54, 66), Enum.Material.Metal, nil, false)
	-- Wide Commercial Oven Doors with Glowing Viewing Windows & Brushed Stainless Tubular Handles
	for _, ox in ipairs({ -20.0, -15.0 }) do
		dPart("OvenDoor", Vector3.new(4.3, 2.2, 0.22), CFrame.new(ox, 2.0, -14.58), brightSteel, Enum.Material.Metal, nil, false)
		dPart("OvenWindow", Vector3.new(3.1, 1.15, 0.26), CFrame.new(ox, 1.85, -14.54), Color3.fromRGB(255, 174, 82), Enum.Material.Neon, nil, false)
		dPart("OvenWindowGlass", Vector3.new(3.2, 1.22, 0.28), CFrame.new(ox, 1.85, -14.51), Color3.fromRGB(28, 22, 18), Enum.Material.Glass, nil, false)
		dPart("OvenHandle", Vector3.new(3.6, 0.18, 0.32), CFrame.new(ox, 2.86, -14.34), brightSteel, Enum.Material.Metal, nil, false)
	end

	-- 4 Heavy Cast-Iron Gas Burners with Glowing Orange Flame Rings + Copper Sauté Skillets & Stockpot!
	for bx = -21.2, -18.2, 3.0 do
		for _, bz in ipairs({ -18.7, -16.3 }) do
			dPart("BurnerGrate", Vector3.new(2.2, 0.22, 2.2), CFrame.new(bx, 4.18, bz), castIron, Enum.Material.Metal, nil, false)
			dPart("BurnerFlame", Vector3.new(0.16, 1.45, 1.45), CFrame.new(bx, 4.18, bz) * CFrame.Angles(0, 0, math.rad(90)), flameOrange, Enum.Material.Neon, Enum.PartType.Cylinder, false)
		end
	end
	dPart("CopperStockPot", Vector3.new(1.45, 1.65, 1.65), CFrame.new(-21.2, 4.98, -18.7) * CFrame.Angles(0, 0, math.rad(90)), copper, Enum.Material.Metal, Enum.PartType.Cylinder, false)
	dPart("StockPotSauce", Vector3.new(0.18, 1.45, 1.45), CFrame.new(-21.2, 5.66, -18.7) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(246, 188, 62), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, false)
	dPart("SauteSkillet", Vector3.new(0.38, 1.75, 1.75), CFrame.new(-18.2, 4.44, -16.3) * CFrame.Angles(0, 0, math.rad(90)), castIron, Enum.Material.Metal, Enum.PartType.Cylinder, false)
	dPart("SkilletHandle", Vector3.new(0.22, 0.22, 1.6), CFrame.new(-18.2, 4.55, -14.85) * CFrame.Angles(math.rad(12), 0, 0), brightSteel, Enum.Material.Metal, nil, false)
	-- Steel Teppanyaki / Plancha Flat Griddle + Hardwood Prep Board
	dPart("TeppanyakiPlancha", Vector3.new(3.6, 0.22, 3.8), CFrame.new(-14.6, 4.18, -18.0), Color3.fromRGB(82, 88, 98), Enum.Material.Metal, nil, false)
	dPart("PrepCuttingBoard", Vector3.new(2.6, 0.18, 1.6), CFrame.new(-14.6, 4.18, -15.4), Color3.fromRGB(168, 124, 78), Enum.Material.Wood, nil, false)

	-- 6 Sculpted Chrome & Red-Accent Rotary Control Knobs along front strip
	for kx = -21.5, -13.5, 1.3 do
		dPart("RangeKnob", Vector3.new(0.26, 0.34, 0.34), CFrame.new(kx, 3.52, -14.38) * CFrame.Angles(0, math.rad(90), 0), brightSteel, Enum.Material.Metal, Enum.PartType.Cylinder, false)
	end

	-- Commercial Overhead Island Exhaust Canopy Hood + Twin Flue Ducts
	local hood = dPart("IslandExhaustHood", Vector3.new(11.0, 2.2, 6.4), CFrame.new(-17.5, 11.2, -17.5), darkSteel, Enum.Material.Metal, nil, false)
	dPart("HoodBrassTrim", Vector3.new(11.1, 0.24, 6.5), CFrame.new(-17.5, 10.15, -17.5), theme.BrassAccent, Enum.Material.Metal, nil, false)
	dPart("HoodDuctL", Vector3.new(1.8, 4.2, 1.8), CFrame.new(-20.2, 14.2, -17.5), steel, Enum.Material.Metal, nil, false)
	dPart("HoodDuctR", Vector3.new(1.8, 4.2, 1.8), CFrame.new(-14.8, 14.2, -17.5), steel, Enum.Material.Metal, nil, false)
	local hoodLight = Instance.new("PointLight")
	hoodLight.Color = Color3.fromRGB(255, 224, 172)
	hoodLight.Brightness = 1.6
	hoodLight.Range = 24
	hoodLight.Shadows = false
	hoodLight.Parent = hood

	-- Commercial Back-Wall Kitchen Pass Shelf, Prep Fridge & Hanging Copper Skillets
	dPart("BackFridgeUnit", Vector3.new(6.8, 7.8, 3.4), CFrame.new(-29.5, 4.6, -27.5), steel, Enum.Material.Metal, nil, false)
	dPart("PassShelfLower", Vector3.new(18.0, 0.25, 2.2), CFrame.new(-16.0, 5.8, -27.8), steel, Enum.Material.Metal, nil, false)
	dPart("PassShelfUpper", Vector3.new(18.0, 0.25, 2.2), CFrame.new(-16.0, 8.2, -27.8), steel, Enum.Material.Metal, nil, false)
	for px = -22, -10, 3 do
		dPart("StackedPlates", Vector3.new(0.65, 1.35, 1.35), CFrame.new(px, 6.25, -27.8) * CFrame.Angles(0, 0, math.rad(90)), marble, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, false)
		dPart("HangingCopperPan", Vector3.new(0.24, 1.3, 1.3), CFrame.new(px, 9.5, -28.4), copper, Enum.Material.Metal, Enum.PartType.Cylinder, false)
	end

	-- ServeCounter Marble Top Slab & Brass Heat-Lamp Bridge (15.0, 2.9, 26.2)
	dPart("ServeCounterTop", Vector3.new(15.4, 0.32, 4.9), CFrame.new(15.0, 5.22, 26.2), marble, Enum.Material.Marble, nil, false)
	dPart("ServeBrassTrim", Vector3.new(15.5, 0.22, 5.0), CFrame.new(15.0, 3.2, 26.2), theme.BrassAccent, Enum.Material.Metal, nil, false)
	dPart("UpgradePadRim", Vector3.new(7.6, 0.14, 7.6), CFrame.new(-18.8, 0.68, 27.5), theme.BrassAccent, Enum.Material.Metal, nil, false)

	-- 3B. Architectural Ceiling Rafters & Shaded Pendant Lanterns across the Dining Hall
	for rz = -24, 12, 9 do
		dPart("CeilingRafter", Vector3.new(72.0, 0.85, 1.1), CFrame.new(0, 14.8, rz), theme.WoodTrimColor, Enum.Material.Wood, nil, false)
	end
	for _, lx in ipairs({ -22.0, 0.0, 20.0 }) do
		for _, lz in ipairs({ -14.0, 4.0 }) do
			dPart("LanternShade", Vector3.new(2.4, 1.8, 2.4), CFrame.new(lx, 10.9, lz), theme.WoodTrimColor, if slot == "North" then Enum.Material.Metal else Enum.Material.Wood, nil, false)
		end
	end

	-- 3C. Theme-Specific Signature Showpiece Zone (Center & Back Dining Hall: X = -4..+8, Z = -14..-29)
	if slot == "East" then
		-- EAST: KUROSHIO OMAKASE SUSHI BAR, CHILLED SASHIMI CASE & SAKE BARREL WALL
		dPart("OmakaseBarBase", Vector3.new(14.5, 3.6, 3.2), CFrame.new(1.5, 2.4, -18.5), theme.WoodTrimColor, Enum.Material.WoodPlanks, nil, true)
		dPart("OmakaseHinokiTop", Vector3.new(15.0, 0.35, 3.6), CFrame.new(1.5, 4.35, -18.5), Color3.fromRGB(214, 178, 126), Enum.Material.Wood, nil, false)
		dPart("SashimiGlassCase", Vector3.new(7.5, 1.1, 1.6), CFrame.new(1.5, 5.05, -17.6), Color3.fromRGB(182, 218, 232), Enum.Material.Glass, nil, false)
		dPart("ToroDisplaySlab", Vector3.new(2.0, 0.35, 0.9), CFrame.new(-0.5, 4.72, -17.6), Color3.fromRGB(212, 62, 68), Enum.Material.SmoothPlastic, nil, false)
		dPart("SalmonDisplaySlab", Vector3.new(2.0, 0.35, 0.9), CFrame.new(2.2, 4.72, -17.6), Color3.fromRGB(238, 118, 76), Enum.Material.SmoothPlastic, nil, false)
		-- Back-wall Sake & Cedar Barrel Alcove
		dPart("SakeWallRack", Vector3.new(14.0, 9.5, 1.6), CFrame.new(1.5, 5.8, -28.6), Color3.fromRGB(28, 24, 22), Enum.Material.Wood, nil, false)
		for sx = -3.5, 6.5, 3.3 do
			dPart("SakeCask", Vector3.new(2.1, 2.2, 2.2), CFrame.new(sx, 7.4, -28.2) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(218, 208, 186), Enum.Material.Fabric, Enum.PartType.Cylinder, false)
			dPart("CaskWrap", Vector3.new(0.8, 2.26, 2.26), CFrame.new(sx, 7.4, -28.2) * CFrame.Angles(0, 0, math.rad(90)), theme.AwningPrimary, Enum.Material.Fabric, Enum.PartType.Cylinder, false)
		end
		-- Hanging Japanese Noren Curtain Panels above the Omakase bar
		for nx = -4.0, 6.5, 3.5 do
			dPart("NorenPanel", Vector3.new(3.1, 2.6, 0.18), CFrame.new(nx, 11.4, -17.0), theme.AwningPrimary, Enum.Material.Fabric, nil, false)
		end

	elseif slot == "West" then
		-- WEST: TRATTORIA CORLEONE MAHOGANY WINE CELLAR, AGING CASKS & BRASS ESPRESSO BAR
		dPart("TrattoriaBarBase", Vector3.new(14.5, 3.6, 3.2), CFrame.new(1.5, 2.4, -18.5), theme.WoodTrimColor, Enum.Material.Wood, nil, true)
		dPart("TrattoriaMarbleTop", Vector3.new(15.0, 0.35, 3.6), CFrame.new(1.5, 4.35, -18.5), marble, Enum.Material.Marble, nil, false)
		dPart("BrassEspressoMachine", Vector3.new(3.2, 2.1, 1.8), CFrame.new(-2.2, 5.4, -18.5), theme.BrassAccent, Enum.Material.Metal, nil, false)
		dPart("EspressoDome", Vector3.new(0.8, 2.4, 2.4), CFrame.new(-2.2, 6.6, -18.5) * CFrame.Angles(0, 0, math.rad(90)), copper, Enum.Material.Metal, Enum.PartType.Cylinder, false)
		-- Back-wall Floor-to-Ceiling Mahogany Wine Rack & Oak Barrels
		dPart("WineCellarCabinet", Vector3.new(15.2, 10.5, 1.8), CFrame.new(1.5, 6.0, -28.6), theme.WoodTrimColor, Enum.Material.Wood, nil, false)
		for wy = 3.6, 9.2, 1.8 do
			dPart("WineShelf", Vector3.new(14.4, 0.24, 1.9), CFrame.new(1.5, wy, -28.5), theme.BrassAccent, Enum.Material.Metal, nil, false)
			for wx = -4.2, 7.0, 1.6 do
				dPart("VintageWineBottle", Vector3.new(1.3, 0.44, 0.44), CFrame.new(wx, wy + 0.38, -28.3) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(24, 58, 34), Enum.Material.Glass, Enum.PartType.Cylinder, false)
			end
		end

	elseif slot == "North" then
		-- NORTH: LE NOIR IMPERIAL ART-DECO GILDED MIRROR WALL & MARBLE RAW BAR
		dPart("BrasserieBarBase", Vector3.new(14.5, 3.6, 3.2), CFrame.new(1.5, 2.4, -18.5), Color3.fromRGB(20, 24, 28), Enum.Material.Marble, nil, true)
		dPart("BrasserieBrassInlay", Vector3.new(14.7, 0.25, 3.3), CFrame.new(1.5, 2.8, -18.5), theme.BrassAccent, Enum.Material.Metal, nil, false)
		dPart("BrasserieMarbleTop", Vector3.new(15.0, 0.35, 3.6), CFrame.new(1.5, 4.35, -18.5), marble, Enum.Material.Marble, nil, false)
		dPart("TieredSeafoodStand", Vector3.new(1.8, 2.4, 2.4), CFrame.new(1.5, 5.6, -18.5) * CFrame.Angles(0, 0, math.rad(90)), theme.BrassAccent, Enum.Material.Metal, Enum.PartType.Cylinder, false)
		-- Back-wall Gilded Art-Deco Mirror Triptych
		dPart("ArtDecoFrameBack", Vector3.new(15.4, 10.2, 0.8), CFrame.new(1.5, 6.4, -29.0), theme.BrassAccent, Enum.Material.Metal, nil, false)
		dPart("ArtDecoMirrorGlass", Vector3.new(14.2, 9.0, 0.9), CFrame.new(1.5, 6.4, -28.9), Color3.fromRGB(148, 176, 184), Enum.Material.Glass, nil, false)
		for mx = -3.0, 6.0, 4.5 do
			dPart("ArtDecoPillar", Vector3.new(0.45, 9.8, 1.1), CFrame.new(mx, 6.4, -28.8), theme.BrassAccent, Enum.Material.Metal, nil, false)
		end

	else
		-- SOUTH: EL CARTEL ASADOR WOOD-FIRED BRICK HEARTH OVEN & BUTCHER CARVING ISLAND
		dPart("AsadorIslandBase", Vector3.new(14.5, 3.6, 3.2), CFrame.new(1.5, 2.4, -18.5), theme.WainscotColor, Enum.Material.Brick, nil, true)
		dPart("AsadorButcherTop", Vector3.new(15.0, 0.42, 3.6), CFrame.new(1.5, 4.35, -18.5), Color3.fromRGB(146, 98, 58), Enum.Material.Wood, nil, false)
		-- Back-wall Brick & Wrought-Iron Wood-Fired Parilla Hearth Oven
		dPart("ParillaHearthBody", Vector3.new(13.5, 10.4, 3.4), CFrame.new(1.5, 5.8, -28.0), theme.WainscotColor, Enum.Material.Brick, nil, false)
		dPart("HearthFirebox", Vector3.new(8.2, 3.6, 2.2), CFrame.new(1.5, 4.2, -26.8), castIron, Enum.Material.Slate, nil, false)
		dPart("HearthEmberBed", Vector3.new(7.2, 0.55, 1.8), CFrame.new(1.5, 2.9, -26.6), ember, Enum.Material.Slate, nil, false)
		dPart("HearthIronMantel", Vector3.new(14.0, 0.65, 3.8), CFrame.new(1.5, 6.4, -27.9), castIron, Enum.Material.Metal, nil, false)
	end

	-- 3D Table Centerpiece Lamps & Place Runners on all 4 Indoor Dining Tables
	for _, tPos in ipairs({
		Vector3.new(18.0, 4.05, 6.0),
		Vector3.new(18.0, 4.05, -10.0),
		Vector3.new(18.0, 4.05, -22.0),
		Vector3.new(-22.0, 4.05, 6.0),
	}) do
		dPart("TableRunner", Vector3.new(2.2, 0.08, 4.3), CFrame.new(tPos), theme.AwningSecondary, Enum.Material.Fabric, nil, false)
		dPart("TableLampBase", Vector3.new(0.45, 0.55, 0.55), CFrame.new(tPos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), theme.BrassAccent, Enum.Material.Metal, Enum.PartType.Cylinder, false)
		dPart("TableLampShade", Vector3.new(0.55, 0.85, 0.85), CFrame.new(tPos + Vector3.new(0, 0.72, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(246, 224, 178), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, false)
	end

	decor.Parent = hq
end

function BaseService.SyncInteriorStations(slot: BaseSlot, hasDualStove: boolean, hasVIPBooths: boolean): ()
	baseInteriorFlags[slot] = {
		HasDualStove = hasDualStove,
		HasVIPBooths = hasVIPBooths,
	}
	local baseModel = BaseService.GetBaseModel(slot)
	local hq = if baseModel then baseModel:FindFirstChild("RestaurantHQ") else nil
	if not hq or not hq:IsA("Model") or not hq.PrimaryPart then
		return
	end
	local hqCF = hq.PrimaryPart.CFrame
	local theme = RESTAURANT_THEMES[slot] or RESTAURANT_THEMES.East
	local showSecondRange = hasDualStove or (BaseService.GetBasePlayerCount(slot) >= 2)

	local oldStove2 = hq:FindFirstChild("DualStoveExpansion")
	if oldStove2 then oldStove2:Destroy() end
	if showSecondRange then
		local stFolder = Instance.new("Model")
		stFolder.Name = "DualStoveExpansion"
		local function sPart(name: string, sz: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Size = sz
			p.CFrame = hqCF * relCF
			p.Color = col
			p.Material = mat
			if shape then p.Shape = shape end
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.Parent = stFolder
			return p
		end
		local steel = Color3.fromRGB(196, 204, 216)
		local brushedBody = Color3.fromRGB(168, 176, 188)
		local darkSteel = Color3.fromRGB(46, 52, 64)
		local castIron = Color3.fromRGB(24, 26, 30)
		local copper = Color3.fromRGB(194, 114, 62)
		local flameOrange = Color3.fromRGB(255, 148, 36)

		-- Exact Icon-Matched Gleaming Stainless Steel Dual-Stove Commercial Range!
		sPart("Stove2Body", Vector3.new(7.6, 3.2, 5.4), CFrame.new(-7.4, 2.25, -17.5), brushedBody, Enum.Material.Metal, nil)
		sPart("Stove2Top", Vector3.new(8.0, 0.34, 5.8), CFrame.new(-7.4, 3.96, -17.5), steel, Enum.Material.Metal, nil)
		sPart("Stove2Backsplash", Vector3.new(8.0, 2.0, 0.34), CFrame.new(-7.4, 5.05, -20.25), steel, Enum.Material.Metal, nil)
		sPart("Stove2ControlStrip", Vector3.new(7.7, 0.62, 0.26), CFrame.new(-7.4, 3.52, -14.74), darkSteel, Enum.Material.Metal, nil)
		for kx = -10.2, -4.6, 1.12 do
			sPart("Stove2Knob", Vector3.new(0.24, 0.32, 0.32), CFrame.new(kx, 3.52, -14.56) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		-- Wide Commercial Oven Door + Warm Glowing Oven Window + Stainless Tubular Handle
		sPart("Stove2OvenDoor", Vector3.new(6.6, 2.15, 0.22), CFrame.new(-7.4, 1.98, -14.76), steel, Enum.Material.Metal, nil)
		sPart("Stove2OvenGlow", Vector3.new(4.8, 1.12, 0.26), CFrame.new(-7.4, 1.85, -14.72), Color3.fromRGB(255, 174, 82), Enum.Material.Neon, nil)
		sPart("Stove2OvenGlass", Vector3.new(4.95, 1.2, 0.28), CFrame.new(-7.4, 1.85, -14.69), Color3.fromRGB(28, 22, 18), Enum.Material.Glass, nil)
		sPart("Stove2OvenHandle", Vector3.new(5.6, 0.18, 0.32), CFrame.new(-7.4, 2.86, -14.52), steel, Enum.Material.Metal, nil)

		-- 4 Heavy Cast-Iron Burners with Glowing Orange Flame Rings + Twin Sauté Skillets!
		for _, bx in ipairs({ -9.2, -5.6 }) do
			for _, bz in ipairs({ -18.7, -16.3 }) do
				sPart("Burner2Grate", Vector3.new(2.05, 0.22, 2.05), CFrame.new(bx, 4.18, bz), castIron, Enum.Material.Metal, nil)
				sPart("Burner2Flame", Vector3.new(0.16, 1.38, 1.38), CFrame.new(bx, 4.18, bz) * CFrame.Angles(0, 0, math.rad(90)), flameOrange, Enum.Material.Neon, Enum.PartType.Cylinder)
			end
		end
		sPart("BraisingPan2", Vector3.new(0.55, 1.75, 1.75), CFrame.new(-9.2, 4.5, -18.7) * CFrame.Angles(0, 0, math.rad(90)), copper, Enum.Material.Metal, Enum.PartType.Cylinder)
		sPart("BraisingPan2Sauce", Vector3.new(0.16, 1.5, 1.5), CFrame.new(-9.2, 4.78, -18.7) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(246, 188, 62), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		sPart("BraisingPan2Handle", Vector3.new(0.2, 0.2, 1.5), CFrame.new(-9.2, 4.65, -17.2) * CFrame.Angles(math.rad(14), 0, 0), steel, Enum.Material.Metal, nil)
		sPart("SautePan2R", Vector3.new(0.45, 1.65, 1.65), CFrame.new(-5.6, 4.46, -16.3) * CFrame.Angles(0, 0, math.rad(90)), castIron, Enum.Material.Metal, Enum.PartType.Cylinder)
		sPart("SautePan2RHandle", Vector3.new(0.2, 0.2, 1.45), CFrame.new(-5.6, 4.62, -14.9) * CFrame.Angles(math.rad(14), 0, 0), steel, Enum.Material.Metal, nil)
		if hasDualStove then
			local hood2 = sPart("Hood2", Vector3.new(8.2, 2.1, 6.0), CFrame.new(-7.4, 16.4, -17.5), steel, Enum.Material.Metal, nil)
			sPart("Hood2Brass", Vector3.new(8.3, 0.24, 6.1), CFrame.new(-7.4, 15.38, -17.5), theme.BrassAccent, Enum.Material.Metal, nil)
			local h2Light = Instance.new("PointLight")
			h2Light.Color = Color3.fromRGB(255, 224, 168)
			h2Light.Brightness = 1.3
			h2Light.Range = 20
			h2Light.Shadows = false
			h2Light.Parent = hood2
		end
		stFolder.Parent = hq
	end

	local oldVip = hq:FindFirstChild("VIPPrivateBoothsExpansion")
	if oldVip then oldVip:Destroy() end
	if hasVIPBooths then
		local vipFolder = Instance.new("Model")
		vipFolder.Name = "VIPPrivateBoothsExpansion"
		local function vPart(name: string, sz: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Size = sz
			p.CFrame = hqCF * relCF
			p.Color = col
			p.Material = mat
			if shape then p.Shape = shape end
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = vipFolder
			return p
		end

		-- Exact Icon-Matched Curved Semicircular Crimson Velvet Tufted VIP Booth + Round Table + Glowing Brass Lamp!
		local cx, cz = -25.5, -6.5
		local velvetCrimson = Color3.fromRGB(158, 22, 38)
		local velvetDark = Color3.fromRGB(116, 16, 28)
		local walnutWood = Color3.fromRGB(94, 50, 28)
		local goldBrass = Color3.fromRGB(238, 192, 68)
		local lampGlow = Color3.fromRGB(255, 222, 134)

		-- Plush Circular Crimson & Gold-Trimmed VIP Carpet Rug
		vPart("VIPCarpetGold", Vector3.new(0.10, 13.6, 13.6), CFrame.new(cx, 0.69, cz) * CFrame.Angles(0, 0, math.rad(90)), goldBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		vPart("VIPCarpet", Vector3.new(0.12, 12.8, 12.8), CFrame.new(cx, 0.72, cz) * CFrame.Angles(0, 0, math.rad(90)), velvetDark, Enum.Material.Fabric, Enum.PartType.Cylinder)

		-- Curved 180-degree Semicircular Velvet Tufted Banquette sweeping cleanly around the west/north/south (opening east toward dining hall!)
		local segCount = 7
		local arcRadius = 4.65
		for i = 0, segCount - 1 do
			-- Sweep from North (-90 deg) through West (180 deg) to South (+90 deg)
			local frac = i / (segCount - 1)
			local ang = math.rad(95 + frac * 170) -- X = cos(ang) goes ~0 -> -1 -> ~0, Z = sin(ang) goes +1 -> 0 -> -1
			local sx = cx + math.cos(ang) * arcRadius
			local sz = cz + math.sin(ang) * arcRadius
			local faceCenter = CFrame.lookAt(Vector3.new(sx, 0, sz), Vector3.new(cx, 0, cz))
			local rotOnly = faceCenter - faceCenter.Position

			-- Brass Kick-Plate Base + Walnut Curved Outer Wood Shell
			vPart("VIPKick_" .. i, Vector3.new(2.75, 0.55, 2.35), CFrame.new(sx, 1.0, sz) * rotOnly, goldBrass, Enum.Material.Metal, nil)
			vPart("VIPShell_" .. i, Vector3.new(2.9, 4.4, 0.55), CFrame.new(sx, 2.95, sz) * rotOnly * CFrame.new(0, 0, 1.15), walnutWood, Enum.Material.Wood, nil)
			vPart("VIPShellGoldTop_" .. i, Vector3.new(2.95, 0.28, 0.65), CFrame.new(sx, 5.2, sz) * rotOnly * CFrame.new(0, 0, 1.15), goldBrass, Enum.Material.Metal, nil)
			-- Plush Tufted Velvet Seat Cushion + Curved Backrest + Rolled Bolster Top + Vertical Tufting Ribs
			vPart("VIPSeat_" .. i, Vector3.new(2.65, 1.15, 2.15), CFrame.new(sx, 1.82, sz) * rotOnly * CFrame.new(0, 0, -0.05), velvetCrimson, Enum.Material.Fabric, nil)
			vPart("VIPBack_" .. i, Vector3.new(2.65, 2.85, 0.78), CFrame.new(sx, 3.55, sz) * rotOnly * CFrame.new(0, 0, 0.62), velvetCrimson, Enum.Material.Fabric, nil)
			vPart("VIPTuftRib_" .. i, Vector3.new(0.18, 2.65, 0.84), CFrame.new(sx, 3.55, sz) * rotOnly * CFrame.new(0, 0, 0.60), velvetDark, Enum.Material.Fabric, nil)
			vPart("VIPBolster_" .. i, Vector3.new(2.72, 0.68, 0.85), CFrame.new(sx, 4.95, sz) * rotOnly * CFrame.new(0, 0, 0.64), velvetCrimson, Enum.Material.Fabric, nil)
		end

		-- Round Dark-Mahogany & Brass-Rimmed Luxury VIP Dining Table on Sculpted Brass Pedestal!
		local tx = cx + 0.55
		vPart("VIPTableFoot", Vector3.new(0.32, 3.0, 3.0), CFrame.new(tx, 0.88, cz) * CFrame.Angles(0, 0, math.rad(90)), goldBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		vPart("VIPTablePedestal", Vector3.new(2.8, 0.9, 0.9), CFrame.new(tx, 2.35, cz) * CFrame.Angles(0, 0, math.rad(90)), goldBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		vPart("VIPTableBrassRim", Vector3.new(0.42, 5.35, 5.35), CFrame.new(tx, 3.78, cz) * CFrame.Angles(0, 0, math.rad(90)), goldBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		vPart("VIPTableTop", Vector3.new(0.46, 5.05, 5.05), CFrame.new(tx, 3.81, cz) * CFrame.Angles(0, 0, math.rad(90)), walnutWood, Enum.Material.Wood, Enum.PartType.Cylinder)

		-- Signature Warm Glowing Golden Table Lamp centered on the Round VIP Table (exact icon match!)
		vPart("VIPLampFoot", Vector3.new(0.22, 0.95, 0.95), CFrame.new(tx, 4.14, cz) * CFrame.Angles(0, 0, math.rad(90)), goldBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		vPart("VIPLampStem", Vector3.new(1.05, 0.24, 0.24), CFrame.new(tx, 4.65, cz) * CFrame.Angles(0, 0, math.rad(90)), goldBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		local shade = vPart("VIPLampGlowShade", Vector3.new(1.15, 1.35, 1.15), CFrame.new(tx, 5.35, cz), lampGlow, Enum.Material.Neon, Enum.PartType.Ball)
		vPart("VIPLampBrassCap", Vector3.new(0.28, 1.32, 1.32), CFrame.new(tx, 5.72, cz) * CFrame.Angles(0, 0, math.rad(90)), goldBrass, Enum.Material.Metal, Enum.PartType.Cylinder)
		local vipLight = Instance.new("PointLight")
		vipLight.Color = lampGlow
		vipLight.Brightness = 1.8
		vipLight.Range = 22
		vipLight.Shadows = false
		vipLight.Parent = shade

		-- Matching Brass Entrance Stanchions flanking the VIP Alcove
		for _, pz in ipairs({ -11.6, -1.4 }) do
			vPart("VIPStanchionPost", Vector3.new(0.45, 3.1, 0.45), CFrame.new(-19.2, 2.2, pz), goldBrass, Enum.Material.Metal, nil)
			vPart("VIPStanchionTop", Vector3.new(0.75, 0.75, 0.75), CFrame.new(-19.2, 3.85, pz), goldBrass, Enum.Material.Metal, Enum.PartType.Ball)
		end
		vipFolder.Parent = hq
	end
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

function BaseService.GetSlotAvailability(): { [string]: any }
	local out: { [string]: any } = {}
	for _, slot in ipairs(SLOT_ORDER) do
		local members = BaseService.GetBasePlayers(slot)
		if #members == 0 then
			out[slot] = nil
		elseif #members == 1 then
			out[slot] = members[1].DisplayName .. " (1/2)"
		else
			out[slot] = string.format("%s & %s (2/2)", members[1].DisplayName, members[2].DisplayName)
		end
	end
	return out
end

function BaseService.ClaimBaseSlot(player: Player, slot: BaseSlot): (boolean, string)
	if playerSlots[player] then
		return false, "You are already on " .. playerSlots[player] .. " Co-op Base!"
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

	local members = BaseService.GetBasePlayers(slot)
	slotMembers[slot] = members
	if #members >= BaseService.MAX_PLAYERS_PER_BASE then
		return false, string.format("%s Co-op Base is full (%d/%d) — choose another!", slot, #members, BaseService.MAX_PLAYERS_PER_BASE)
	end

	local partner = members[1]
	table.insert(members, player)
	playerSlots[player] = slot
	syncBaseTeamAttributes(slot)

	local flags = baseInteriorFlags[slot]
	if flags then
		BaseService.SyncInteriorStations(slot, flags.HasDualStove, flags.HasVIPBooths)
	end

	print(string.format("[BaseService] %s joined %s Co-op Base (%d/%d)!", player.Name, slot, #members, BaseService.MAX_PLAYERS_PER_BASE))

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

	if partner and partner.Parent then
		return true, string.format("Joined %s Co-op Base with %s! You share Restaurant, Warehouses & Territory!", slot, partner.DisplayName)
	end
	return true, string.format("Welcome to %s Co-op Base (1/2)! A co-op partner can join to run this empire together!", slot)
end

function BaseService.AssignRandomAvailableBase(player: Player): (boolean, string)
	if playerSlots[player] then
		return true, "Already assigned to " .. playerSlots[player] .. " Co-op Base"
	end
	-- Balanced 8-player co-op assignment: fill empty bases first (1 per base), then pair up to 2/2 across all 4 bases!
	local minCount = BaseService.MAX_PLAYERS_PER_BASE
	for _, slot in ipairs(SLOT_ORDER) do
		local c = BaseService.GetBasePlayerCount(slot)
		if c < minCount then
			minCount = c
		end
	end
	if minCount >= BaseService.MAX_PLAYERS_PER_BASE then
		return false, "All 4 Co-op Bases are currently full (8/8 players)!"
	end
	local candidates: { BaseSlot } = {}
	for _, slot in ipairs(SLOT_ORDER) do
		if BaseService.GetBasePlayerCount(slot) == minCount then
			table.insert(candidates, slot)
		end
	end
	local chosen = candidates[math.random(1, #candidates)]
	return BaseService.ClaimBaseSlot(player, chosen)
end

function BaseService.AssignPendingPlayers(): ()
	for _, player in ipairs(Players:GetPlayers()) do
		if not playerSlots[player] then
			BaseService.AssignRandomAvailableBase(player)
		end
	end
end

local function releaseSlot(player: Player): ()
	local slot = playerSlots[player]
	if slot then
		playerSlots[player] = nil
		local members = slotMembers[slot]
		if members then
			for i = #members, 1, -1 do
				if members[i] == player or not members[i].Parent then
					table.remove(members, i)
				end
			end
		end
		local remaining = BaseService.GetBasePlayerCount(slot)
		syncBaseTeamAttributes(slot)

		if remaining == 0 then
			BaseService.SetDefenseTier(slot, 1)
			baseInteriorFlags[slot] = { HasDualStove = false, HasVIPBooths = false }
			BaseService.SyncInteriorStations(slot, false, false)
			local baseModel = BaseService.GetBaseModel(slot)
			if baseModel then
				local hq = baseModel:FindFirstChild("RestaurantHQ")
				if hq and hq:IsA("Model") then
					RestaurantExpansionBuilder.BuildTierForHQ(baseModel, hq, slot, 1)
				end
				RestaurantExpansionBuilder.BuildFrontWoodPavilion(baseModel, slot, 1)
			end
		else
			local flags = baseInteriorFlags[slot]
			if flags then
				BaseService.SyncInteriorStations(slot, flags.HasDualStove, flags.HasVIPBooths)
			end
		end

		for _, cb in ipairs(releaseListeners) do
			task.spawn(cb, slot, player, remaining)
		end
	end

	if charConnections[player] then
		charConnections[player]:Disconnect()
		charConnections[player] = nil
	end
end

-- Active Castle Defense Turrets repel Rival AI & Night Mafia raiders who approach upgraded bases
local function runDefenseTurretTick(): ()
	local targets: { Instance } = {}
	for _, unit in ipairs(CollectionService:GetTagged("RivalAIUnit")) do
		table.insert(targets, unit)
	end
	for _, unit in ipairs(CollectionService:GetTagged("NightRaidMafiaUnit")) do
		table.insert(targets, unit)
	end
	if #targets == 0 then
		return
	end

	for _, slot in ipairs(SLOT_ORDER) do
		local tier = baseDefenseTiers[slot] or 1
		if tier >= 2 and BaseService.GetBasePlayerCount(slot) > 0 then
			local baseModel = BaseService.GetBaseModel(slot)
			if baseModel and baseModel.PrimaryPart then
				local basePos = baseModel.PrimaryPart.Position
				local range = if tier >= 3 then 145 else 115
				local damage = if tier >= 3 then 35 else 20

				for _, unit in ipairs(targets) do
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

-- Expands every Castle Base estate from 224x224 to a spacious 336x288 2-Player Co-op Estate
-- (keeps BasePivot.CFrame & GrandFrontGate at Z=+112 100% locked to the City Road,
-- widens +/-X by +56 studs each side, deepens -Z rear by +64 studs, reorganizes the 4 existing
-- WarehousePlots with wide 72-stud spacing & unobstructed aprons, and adds paved low-poly
-- dual-player circulation paths & dual spawn medallions — ZERO duplicated buildings!).
local function expandBaseEstate(slot: BaseSlot): ()
	local baseModel = BaseService.GetBaseModel(slot)
	if not baseModel or baseModel:GetAttribute("EstateExpandedV2") == true then
		return
	end
	local bp = baseModel:FindFirstChild("BasePivot")
	if not bp or not bp:IsA("BasePart") then
		return
	end
	baseModel:SetAttribute("EstateExpandedV2", true)

	local bCF = bp.CFrame
	local SIDE_EXPAND = 56 -- +/-112 -> +/-168 (336 studs wide!)
	local REAR_EXPAND = 64 -- -112 -> -176 (288 studs deep!)

	-- 1. Seamless Estate Ground Apron Extensions (keeps BasePivot.CFrame untouched!)
	local oldExt = baseModel:FindFirstChild("BaseEstateExtension")
	if oldExt then oldExt:Destroy() end
	local extFolder = Instance.new("Folder")
	extFolder.Name = "BaseEstateExtension"

	local function addFloorSlab(name: string, sz: Vector3, relPos: Vector3): ()
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = bCF * CFrame.new(relPos)
		p.Color = bp.Color
		p.Material = bp.Material
		p.Anchored = true
		p.CanCollide = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = extFolder
	end

	local floorY = 0
	local floorH = math.max(0.8, bp.Size.Y)
	addFloorSlab("EstateSlab_Left", Vector3.new(SIDE_EXPAND + 2, floorH, 288 + 2), Vector3.new(-112 - SIDE_EXPAND * 0.5, floorY, -REAR_EXPAND * 0.5))
	addFloorSlab("EstateSlab_Right", Vector3.new(SIDE_EXPAND + 2, floorH, 288 + 2), Vector3.new(112 + SIDE_EXPAND * 0.5, floorY, -REAR_EXPAND * 0.5))
	addFloorSlab("EstateSlab_Rear", Vector3.new(224 + 4, floorH, REAR_EXPAND + 2), Vector3.new(0, floorY, -112 - REAR_EXPAND * 0.5))
	extFolder.Parent = baseModel

	-- 2. Reorganize the 4 EXISTING WarehousePlots across the 336-stud rear estate with wide 72-stud spacing
	--    (36-stud open walking alleys between every warehouse, 45+ studs clear logistics apron in front of CargoDoors!)
	local WAREHOUSE_COOP_SLOTS: { [number]: Vector3 } = {
		[1] = Vector3.new(-108, 0, -134),
		[2] = Vector3.new(-36, 0, -134),
		[3] = Vector3.new(36, 0, -134),
		[4] = Vector3.new(108, 0, -134),
	}
	local CATEGORY_FALLBACK_IDX: { [string]: number } = {
		Fish = 1,
		Vegetable = 2,
		Fruit = 3,
		Meat = 4,
	}
	local whFolder = baseModel:FindFirstChild("WarehousePlots")
	if whFolder then
		for _, plot in ipairs(whFolder:GetChildren()) do
			if plot:IsA("Model") then
				local pivotPart = plot:FindFirstChild("PlotPivot")
				if pivotPart and pivotPart:IsA("BasePart") then
					local idxAttr = plot:GetAttribute("PlotIndex")
					local catAttr = plot:GetAttribute("Category")
					local pIdx = if typeof(idxAttr) == "number"
						then idxAttr
						elseif typeof(catAttr) == "string" then (CATEGORY_FALLBACK_IDX[catAttr] or 1)
						else 1
					local targetXZ = WAREHOUSE_COOP_SLOTS[pIdx] or WAREHOUSE_COOP_SLOTS[1]
					local curRel = bCF:PointToObjectSpace(pivotPart.Position)
					local dx = targetXZ.X - curRel.X
					local dz = targetXZ.Z - curRel.Z
					for _, d in ipairs(plot:GetDescendants()) do
						if d:IsA("BasePart") then
							local rel = bCF:ToObjectSpace(d.CFrame)
							d.CFrame = bCF * (CFrame.new(dx, 0, dz) * rel)
						end
					end
				end
			end
		end
	end

	-- Move rear garden landscaping cleanly into the far rear corners (X = +/-148, Z = -152) so ZERO trees block warehouse CargoDoors!
	local rearGardenShifts: { { Prefix: string, TargetX: number, TargetZ: number } } = {
		{ Prefix = "_1", TargetX = -148, TargetZ = -152 },
		{ Prefix = "_2", TargetX = 148, TargetZ = -152 },
	}
	for _, g in ipairs(rearGardenShifts) do
		local turf = baseModel:FindFirstChild("GardenTurf" .. g.Prefix)
		if turf and turf:IsA("BasePart") then
			local curRel = bCF:PointToObjectSpace(turf.Position)
			local dx = g.TargetX - curRel.X
			local dz = g.TargetZ - curRel.Z
			for _, child in ipairs(baseModel:GetChildren()) do
				if child:IsA("BasePart") and (
					child.Name == ("GardenTurf" .. g.Prefix)
					or child.Name == ("GardenTrunk" .. g.Prefix)
					or child.Name == ("GardenCanopy" .. g.Prefix)
					or child.Name == ("Bush" .. g.Prefix)
				) then
					local rel = bCF:ToObjectSpace(child.CFrame)
					child.CFrame = bCF * (CFrame.new(dx, 0, dz) * rel)
				end
			end
		end
	end

	-- 2B. Build Low-Poly 2-Player Co-op Circulation Network, Loading Aprons & Dual Spawn Medallions!
	local oldInfra = baseModel:FindFirstChild("BaseCoopInfrastructure")
	if oldInfra then oldInfra:Destroy() end
	local infraFolder = Instance.new("Folder")
	infraFolder.Name = "BaseCoopInfrastructure"

	local mainPath = baseModel:FindFirstChild("CourtyardPath_Main")
	local pathColor = if mainPath and mainPath:IsA("BasePart") then mainPath.Color else Color3.fromRGB(146, 142, 134)
	local pathMat = if mainPath and mainPath:IsA("BasePart") then mainPath.Material else Enum.Material.Cobblestone
	local curbColor = Color3.fromRGB(98, 96, 92)
	local accentAttr = baseModel:GetAttribute("AccentColor")
	local teamAccent = if typeof(accentAttr) == "Color3" then accentAttr else Color3.fromRGB(184, 152, 86)

	-- Widen existing main courtyard boulevard & front cross connector for smooth 2-player traffic
	if mainPath and mainPath:IsA("BasePart") then
		mainPath.Size = Vector3.new(32, mainPath.Size.Y, mainPath.Size.Z)
	end
	local cross2 = baseModel:FindFirstChild("CourtyardPath_Cross2")
	if cross2 and cross2:IsA("BasePart") then
		cross2.Size = Vector3.new(320, cross2.Size.Y, 16)
	end
	local frontPlaza = baseModel:FindFirstChild("FrontDiningPlaza")
	local backAlley = if frontPlaza then frontPlaza:FindFirstChild("BackServiceAlley") else nil
	if backAlley and backAlley:IsA("BasePart") then
		backAlley.Transparency = 1
	end

	local function addPathSlab(name: string, sz: Vector3, relPos: Vector3, col: Color3?, mat: Enum.Material?, collide: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = bCF * CFrame.new(relPos)
		p.Color = col or pathColor
		p.Material = mat or pathMat
		p.Anchored = true
		p.CanCollide = if collide == nil then false else collide
		p.CanTouch = false
		p.CanQuery = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = infraFolder
		return p
	end

	-- Rear Warehouse Logistics Boulevard (22 studs wide across full 324-stud span in front of all 4 CargoDoors!)
	addPathSlab("CoopWarehouseBoulevard", Vector3.new(324, 0.14, 22), Vector3.new(0, 0.34, -102), pathColor, pathMat, false)
	addPathSlab("CoopWarehouseCurbN", Vector3.new(324, 0.18, 1.0), Vector3.new(0, 0.38, -113.2), curbColor, Enum.Material.Concrete, false)
	addPathSlab("CoopWarehouseCurbS", Vector3.new(324, 0.18, 1.0), Vector3.new(0, 0.38, -90.8), curbColor, Enum.Material.Concrete, false)

	-- 4 Spacious Warehouse Loading Aprons connecting Boulevard directly to each CargoDoor (X = -108, -36, +36, +108)
	for idx, wx in ipairs({ -108, -36, 36, 108 }) do
		addPathSlab("WarehouseApron_" .. tostring(idx), Vector3.new(26, 0.14, 18), Vector3.new(wx, 0.34, -116), pathColor, pathMat, false)
		addPathSlab("WarehouseApronStripe_" .. tostring(idx), Vector3.new(18, 0.16, 0.9), Vector3.new(wx, 0.36, -110.5), teamAccent, Enum.Material.SmoothPlastic, false)
	end

	-- Twin Outer Perimeter Co-op Bypass Avenues (X = +/-158.5 -> 100% clear even at Max HQ Lv.15 wings at +/-150!)
	for _, side in ipairs({ -1, 1 }) do
		local tag = if side < 0 then "West" else "East"
		addPathSlab("CoopOuterBypass_" .. tag, Vector3.new(13, 0.14, 208), Vector3.new(side * 158.5, 0.34, -8), pathColor, pathMat, false)
		-- Inner Courtyard Fast-Loop Lanes (connect front courtyard around Lv.1-5 restaurant straight to rear boulevard)
		addPathSlab("CoopInnerLoop_" .. tag, Vector3.new(12, 0.14, 104), Vector3.new(side * 96, 0.32, -50), pathColor, pathMat, false)
	end

	-- Rear Restaurant-to-Warehouse Direct Service Spines (serves Lv.3-15 Rear Atrium Archway at X=+12 AND Lv.1-2 Back/West Kitchen Doors!)
	addPathSlab("CoopRearServiceSpine_Main", Vector3.new(18, 0.14, 48), Vector3.new(12, 0.34, -78), pathColor, pathMat, false)
	addPathSlab("CoopRearServiceSpine_Lv1Back", Vector3.new(14, 0.14, 48), Vector3.new(28.5, 0.33, -78), pathColor, pathMat, false)
	addPathSlab("CoopRearServiceSpine_WestKitchen", Vector3.new(12, 0.14, 74), Vector3.new(-46, 0.33, -65), pathColor, pathMat, false)

	-- Dual Co-op Spawn Medallions (flanking BaseSpawn at X = -11 and +11 so 2 teammates never spawn stacked!)
	for idx, sx in ipairs({ -11, 11 }) do
		local pad = addPathSlab("CoopSpawn_" .. tostring(idx), Vector3.new(8.2, 0.38, 8.2), Vector3.new(sx, 0.48, 72.0), Color3.fromRGB(48, 52, 60), Enum.Material.Slate, true)
		pad.CanQuery = true
		addPathSlab("CoopSpawnTrim_" .. tostring(idx), Vector3.new(8.8, 0.18, 8.8), Vector3.new(sx, 0.42, 72.0), teamAccent, Enum.Material.Metal, false)
	end

	infraFolder.Parent = baseModel

	-- 3. Expand Perimeter Castle Defenses outward cleanly while keeping GrandFrontGate at Z = +112 locked to City Road!
	local defenses = baseModel:FindFirstChild("Defenses")
	if defenses then
		local gateModel = defenses:FindFirstChild("GrandFrontGate", true)
		for _, d in ipairs(defenses:GetDescendants()) do
			if d:IsA("BasePart") then
				if gateModel and d:IsDescendantOf(gateModel) then
					continue
				end
				local rel = bCF:ToObjectSpace(d.CFrame)
				local rx, ry, rz = rel:ToOrientation()
				local px, py, pz = rel.Position.X, rel.Position.Y, rel.Position.Z
				local sx, sy, sz = d.Size.X, d.Size.Y, d.Size.Z

				local isSideWall = math.abs(px) > 96
				local isRear = pz < -92
				local isFrontFlank = pz > 92 and math.abs(px) > 16

				if isSideWall and isRear then
					px += (if px > 0 then SIDE_EXPAND else -SIDE_EXPAND)
					pz -= REAR_EXPAND
				elseif isSideWall and isFrontFlank then
					px += (if px > 0 then SIDE_EXPAND else -SIDE_EXPAND)
				elseif isSideWall then
					px += (if px > 0 then SIDE_EXPAND else -SIDE_EXPAND)
					if sz > sx and sz >= 30 then
						sz += REAR_EXPAND
						pz -= REAR_EXPAND * 0.5
					elseif sx > sz and sx >= 30 then
						sx += REAR_EXPAND
						pz -= REAR_EXPAND * 0.5
					end
				elseif isRear then
					pz -= REAR_EXPAND
					if sx > sz and sx >= 30 then
						sx += SIDE_EXPAND * 2
					elseif sz > sx and sz >= 30 then
						sz += SIDE_EXPAND * 2
					end
				elseif isFrontFlank then
					local signX = if px > 0 then 1 else -1
					if sx > sz and sx >= 20 then
						sx += SIDE_EXPAND
						px += signX * (SIDE_EXPAND * 0.5)
					elseif sz > sx and sz >= 20 then
						sz += SIDE_EXPAND
						px += signX * (SIDE_EXPAND * 0.5)
					else
						px += signX * SIDE_EXPAND
					end
				end

				d.Size = Vector3.new(sx, sy, sz)
				d.CFrame = bCF * CFrame.new(px, py, pz) * CFrame.fromOrientation(rx, ry, rz)
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
		expandBaseEstate(slot)
		applyDistinctRestaurantTheme(slot)
		local bm = BaseService.GetBaseModel(slot)
		local hq = if bm then bm:FindFirstChild("RestaurantHQ") else nil
		if bm and hq and hq:IsA("Model") then
			RestaurantExpansionBuilder.BuildTierForHQ(bm, hq, slot, 1)
			RestaurantExpansionBuilder.BuildFrontWoodPavilion(bm, slot, 1)
		end
		syncBaseTeamAttributes(slot)
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
		task.defer(function()
			if player.Parent and not playerSlots[player] then
				BaseService.AssignRandomAvailableBase(player)
			end
		end)
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

	print("[Food Empire] BaseService started (4 Co-op Bases x 2 Players = 8-Player Co-op + Expanded Dual-Access Layouts ready)!")
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
