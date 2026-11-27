--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local RestaurantExpansionBuilder = require("./RestaurantExpansionBuilder")

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

	label.Text = if ownerName then (string.upper(ownerName) .. "'S EMPIRE") else (string.upper(slot) .. " SYNDICATE")
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

	-- 3A. Realistic Commercial Chef's Island Range on top of CookingStation (-17.5, 2.2, -17.5)
	dPart("RangeCounterTop", Vector3.new(10.6, 0.28, 6.0), CFrame.new(-17.5, 3.94, -17.5), steel, Enum.Material.Metal, nil, false)
	dPart("RangeBacksplash", Vector3.new(10.6, 1.45, 0.35), CFrame.new(-17.5, 4.75, -20.3), steel, Enum.Material.Metal, nil, false)
	dPart("OvenDoorL", Vector3.new(4.2, 2.1, 0.18), CFrame.new(-20.0, 2.15, -14.65), darkSteel, Enum.Material.Metal, nil, false)
	dPart("OvenDoorR", Vector3.new(4.2, 2.1, 0.18), CFrame.new(-15.0, 2.15, -14.65), darkSteel, Enum.Material.Metal, nil, false)
	dPart("OvenHandleL", Vector3.new(3.4, 0.16, 0.24), CFrame.new(-20.0, 2.95, -14.5), steel, Enum.Material.Metal, nil, false)
	dPart("OvenHandleR", Vector3.new(3.4, 0.16, 0.24), CFrame.new(-15.0, 2.95, -14.5), steel, Enum.Material.Metal, nil, false)

	-- 4 Cast-Iron Gas Burners + Simmering Stockpot & Copper Skillet + Teppanyaki Griddle + Hardwood Cutting Board
	for bx = -21.2, -18.2, 3.0 do
		for _, bz in ipairs({ -18.7, -16.3 }) do
			dPart("BurnerGrate", Vector3.new(2.1, 0.18, 2.1), CFrame.new(bx, 4.15, bz), castIron, Enum.Material.Metal, nil, false)
			dPart("BurnerFlame", Vector3.new(0.14, 1.25, 1.25), CFrame.new(bx, 4.12, bz) * CFrame.Angles(0, 0, math.rad(90)), ember, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, false)
		end
	end
	-- Stockpot & Sauté Pan on the grates
	dPart("CopperStockPot", Vector3.new(1.45, 1.55, 1.55), CFrame.new(-21.2, 4.92, -18.7) * CFrame.Angles(0, 0, math.rad(90)), copper, Enum.Material.Metal, Enum.PartType.Cylinder, false)
	dPart("StockPotLid", Vector3.new(0.18, 1.62, 1.62), CFrame.new(-21.2, 5.72, -18.7) * CFrame.Angles(0, 0, math.rad(90)), steel, Enum.Material.Metal, Enum.PartType.Cylinder, false)
	dPart("SauteSkillet", Vector3.new(0.32, 1.55, 1.55), CFrame.new(-18.2, 4.38, -16.3) * CFrame.Angles(0, 0, math.rad(90)), castIron, Enum.Material.Metal, Enum.PartType.Cylinder, false)
	-- Steel Teppanyaki / Plancha Flat Griddle + Hardwood Prep Board
	dPart("TeppanyakiPlancha", Vector3.new(3.6, 0.22, 3.8), CFrame.new(-14.6, 4.16, -18.0), Color3.fromRGB(82, 88, 98), Enum.Material.Metal, nil, false)
	dPart("PrepCuttingBoard", Vector3.new(2.6, 0.18, 1.6), CFrame.new(-14.6, 4.16, -15.4), Color3.fromRGB(168, 124, 78), Enum.Material.Wood, nil, false)

	-- Chrome temperature knobs along the front of the range
	for kx = -21.5, -13.5, 1.3 do
		dPart("RangeKnob", Vector3.new(0.22, 0.28, 0.28), CFrame.new(kx, 3.55, -14.62) * CFrame.Angles(0, math.rad(90), 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder, false)
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
	local baseModel = BaseService.GetBaseModel(slot)
	local hq = if baseModel then baseModel:FindFirstChild("RestaurantHQ") else nil
	if not hq or not hq:IsA("Model") or not hq.PrimaryPart then
		return
	end
	local hqCF = hq.PrimaryPart.CFrame
	local theme = RESTAURANT_THEMES[slot] or RESTAURANT_THEMES.East

	local oldStove2 = hq:FindFirstChild("DualStoveExpansion")
	if oldStove2 then oldStove2:Destroy() end
	if hasDualStove then
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
		local steel = Color3.fromRGB(148, 154, 164)
		local darkSteel = Color3.fromRGB(36, 40, 46)
		local castIron = Color3.fromRGB(24, 26, 30)
		local copper = Color3.fromRGB(184, 108, 64)
		local ember = Color3.fromRGB(238, 112, 44)

		sPart("Stove2Body", Vector3.new(7.4, 3.2, 5.2), CFrame.new(-7.4, 2.2, -17.5), Color3.fromRGB(46, 50, 58), Enum.Material.Metal, nil)
		sPart("Stove2Top", Vector3.new(7.8, 0.28, 5.6), CFrame.new(-7.4, 3.94, -17.5), steel, Enum.Material.Metal, nil)
		for _, bx in ipairs({ -9.2, -5.6 }) do
			for _, bz in ipairs({ -18.7, -16.3 }) do
				sPart("Burner2Grate", Vector3.new(1.9, 0.18, 1.9), CFrame.new(bx, 4.15, bz), castIron, Enum.Material.Metal, nil)
				sPart("Burner2Flame", Vector3.new(0.14, 1.15, 1.15), CFrame.new(bx, 4.12, bz) * CFrame.Angles(0, 0, math.rad(90)), ember, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			end
		end
		sPart("BraisingPan2", Vector3.new(0.55, 1.5, 1.5), CFrame.new(-9.2, 4.45, -18.7) * CFrame.Angles(0, 0, math.rad(90)), copper, Enum.Material.Metal, Enum.PartType.Cylinder)
		sPart("Hood2", Vector3.new(8.0, 2.0, 5.8), CFrame.new(-7.4, 16.4, -17.5), darkSteel, Enum.Material.Metal, nil)
		sPart("Hood2Brass", Vector3.new(8.1, 0.22, 5.9), CFrame.new(-7.4, 15.42, -17.5), theme.BrassAccent, Enum.Material.Metal, nil)
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
			p.Parent = vipFolder
			return p
		end
		-- Open-air VIP Private Dining Alcove (low brass stanchion corner posts — zero giant blocking wall!)
		vPart("VIPCarpet", Vector3.new(12.5, 0.12, 11.5), CFrame.new(-25.5, 0.72, -6.5), Color3.fromRGB(94, 24, 30), Enum.Material.Fabric, nil)
		vPart("VIPTable", Vector3.new(7.4, 0.45, 4.6), CFrame.new(-25.5, 3.75, -6.5), Color3.fromRGB(224, 220, 212), Enum.Material.Marble, nil)
		vPart("VIPTableBase", Vector3.new(1.4, 3.0, 1.4), CFrame.new(-25.5, 2.1, -6.5), theme.BrassAccent, Enum.Material.Metal, nil)
		vPart("VIPBoothBackN", Vector3.new(7.6, 3.6, 1.0), CFrame.new(-25.5, 2.6, -10.8), theme.SeatColor, Enum.Material.Leather, nil)
		vPart("VIPBoothSeatN", Vector3.new(7.4, 1.6, 2.0), CFrame.new(-25.5, 1.6, -9.5), theme.SeatColor, Enum.Material.Leather, nil)
		vPart("VIPBoothBackS", Vector3.new(7.6, 3.6, 1.0), CFrame.new(-25.5, 2.6, -2.2), theme.SeatColor, Enum.Material.Leather, nil)
		vPart("VIPBoothSeatS", Vector3.new(7.4, 1.6, 2.0), CFrame.new(-25.5, 1.6, -3.5), theme.SeatColor, Enum.Material.Leather, nil)
		for _, pz in ipairs({ -11.6, -1.4 }) do
			vPart("VIPStanchionPost", Vector3.new(0.45, 3.1, 0.45), CFrame.new(-19.2, 2.2, pz), theme.BrassAccent, Enum.Material.Metal, nil)
			vPart("VIPStanchionTop", Vector3.new(0.7, 0.7, 0.7), CFrame.new(-19.2, 3.85, pz), theme.BrassAccent, Enum.Material.Metal, Enum.PartType.Ball)
		end
		vPart("VIPCandleLamp", Vector3.new(0.85, 0.7, 0.85), CFrame.new(-25.5, 4.35, -6.5) * CFrame.Angles(0, 0, math.rad(90)), theme.BrassAccent, Enum.Material.Metal, Enum.PartType.Cylinder)
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

	return true, string.format("Welcome to %s Castle Base! Starter Seafood & Fish Ingredient Warehouse unlocked!", slot)
end

function BaseService.AssignRandomAvailableBase(player: Player): (boolean, string)
	if playerSlots[player] then
		return true, "Already assigned to " .. playerSlots[player] .. " Castle Base"
	end
	local open: { BaseSlot } = {}
	for _, slot in ipairs(SLOT_ORDER) do
		if slotOwners[slot] == nil then
			table.insert(open, slot)
		end
	end
	if #open == 0 then
		return false, "All 4 Castle Bases are currently occupied!"
	end
	local chosen = open[math.random(1, #open)]
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
		slotOwners[slot] = nil
		playerSlots[player] = nil
		BaseService.SetDefenseTier(slot, 1)
		updateGateOwnerSign(slot, nil)
		local baseModel = BaseService.GetBaseModel(slot)
		if baseModel then
			baseModel:SetAttribute("OwnerUserId", nil)
			local hq = baseModel:FindFirstChild("RestaurantHQ")
			if hq and hq:IsA("Model") then
				RestaurantExpansionBuilder.BuildTierForHQ(baseModel, hq, slot, 1)
			end
			RestaurantExpansionBuilder.BuildFrontWoodPavilion(baseModel, slot, 1)
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
		if tier >= 2 and slotOwners[slot] ~= nil then
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

-- Expands every Castle Base estate from 224x224 to a spacious 336x288 Grand Estate
-- (keeps BasePivot.CFrame & GrandFrontGate at Z=+112 100% locked to the City Road,
-- widens +/-X by +56 studs each side, deepens -Z rear by +64 studs, and shifts
-- WarehousePlots & rear gardens rearward by -46 studs for huge Lv.1-10 Restaurant growth!).
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
	local WH_SHIFT_Z = -46 -- Push WarehousePlots & rear garden back 46 studs (huge rear room for HQ!)

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
	-- Left & Right 56-stud wide estate extensions (spanning full Z = -176..+112)
	addFloorSlab("EstateSlab_Left", Vector3.new(SIDE_EXPAND + 2, floorH, 288 + 2), Vector3.new(-112 - SIDE_EXPAND * 0.5, floorY, -REAR_EXPAND * 0.5))
	addFloorSlab("EstateSlab_Right", Vector3.new(SIDE_EXPAND + 2, floorH, 288 + 2), Vector3.new(112 + SIDE_EXPAND * 0.5, floorY, -REAR_EXPAND * 0.5))
	-- Rear 64-stud deep estate extension (spanning center X = -112..+112)
	addFloorSlab("EstateSlab_Rear", Vector3.new(224 + 4, floorH, REAR_EXPAND + 2), Vector3.new(0, floorY, -112 - REAR_EXPAND * 0.5))
	extFolder.Parent = baseModel

	-- 2. Shift WarehousePlots & rear landscaping rearward by -46 studs so HQ can expand rearward up to Z = -76!
	local shiftList = { "WarehousePlots", "GardenTurf_1", "GardenTurf_2", "GardenCanopy_1", "GardenCanopy_2", "GardenTrunk_1", "GardenTrunk_2", "Bush_1", "Bush_2" }
	for _, childName in ipairs(shiftList) do
		local obj = baseModel:FindFirstChild(childName)
		if obj then
			if obj:IsA("BasePart") then
				local rel = bCF:ToObjectSpace(obj.CFrame)
				obj.CFrame = bCF * (CFrame.new(0, 0, WH_SHIFT_Z) * rel)
			else
				for _, d in ipairs(obj:GetDescendants()) do
					if d:IsA("BasePart") then
						local rel = bCF:ToObjectSpace(d.CFrame)
						d.CFrame = bCF * (CFrame.new(0, 0, WH_SHIFT_Z) * rel)
					end
				end
			end
		end
	end

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
					-- Rear corner towers & corner pillars move outward in BOTH X and -Z
					px += (if px > 0 then SIDE_EXPAND else -SIDE_EXPAND)
					pz -= REAR_EXPAND
				elseif isSideWall and isFrontFlank then
					-- Front corner towers move outward in X only (staying flush with front road at Z = +112)
					px += (if px > 0 then SIDE_EXPAND else -SIDE_EXPAND)
				elseif isSideWall then
					-- Long Left/Right side walls shift outward by +/-56 and lengthen rearward to close the +64 depth!
					px += (if px > 0 then SIDE_EXPAND else -SIDE_EXPAND)
					if sz > sx and sz >= 30 then
						sz += REAR_EXPAND
						pz -= REAR_EXPAND * 0.5
					elseif sx > sz and sx >= 30 then
						sx += REAR_EXPAND
						pz -= REAR_EXPAND * 0.5
					end
				elseif isRear then
					-- Long Rear wall shifts back -64 and widens +112 across the full 336-stud width!
					pz -= REAR_EXPAND
					if sx > sz and sx >= 30 then
						sx += SIDE_EXPAND * 2
					elseif sz > sx and sz >= 30 then
						sz += SIDE_EXPAND * 2
					end
				elseif isFrontFlank then
					-- Left & Right front wall wings extend outward to meet the widened front corner towers!
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
		-- Automatically pick a random available Castle Base for the player (no manual base picker needed!)
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
