--!strict

-- RestaurantExpansionBuilder: Reusable modular Level 1-10 physical expansion builder
-- for Player RestaurantHQs inside the expanded 336x288 Grand Base Estate.
--  * Builds relative to RestaurantHQ.PrimaryPart.CFrame (identical across all 4 bases).
--  * Relocates Grand Staircases cleanly into a spacious Rear Atrium Hall (Lv.3+ 1F->2F,
--    Lv.7+ 2F->3F) so Ground Floor dining stays 100% open and uncrowded!
--  * Uses thick 1.4-stud 2nd/3rd floor ceiling slabs + raised seat Y offsets so seated
--    customers' feet NEVER poke through downstairs ceilings.
--  * Scales physically at EVERY level from Lv.1 (78W x 22H x 52D, 1F) up to
--    Lv.10 (252W x 88H x 106D, 3 Full Walkable Floors + Imperial Sky-Atrium Dome).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RestaurantExpansionConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("RestaurantExpansionConfig")
)

local RestaurantExpansionBuilder = {}

type ThemePalette = {
	WallPrimary: Color3,
	WallTrim: Color3,
	FloorWood: Color3,
	TableTop: Color3,
	TableMat: Enum.Material,
	SeatLeather: Color3,
	BrassAccent: Color3,
	RoofColor: Color3,
	BrandTitle: string,
}

local SLOT_PALETTES: { [string]: ThemePalette } = {
	East = {
		WallPrimary = Color3.fromRGB(238, 222, 192), -- Warm Classical Sandstone Cream (matches HQ icon!)
		WallTrim = Color3.fromRGB(246, 240, 226),    -- Crisp Ivory Marble Columns & Cornices
		FloorWood = Color3.fromRGB(122, 82, 48),
		TableTop = Color3.fromRGB(156, 108, 66),
		TableMat = Enum.Material.Wood,
		SeatLeather = Color3.fromRGB(142, 28, 42),
		BrassAccent = Color3.fromRGB(238, 192, 68),  -- Gleaming Classical Gold Trim
		RoofColor = Color3.fromRGB(54, 106, 122),    -- Signature Classical Dome Teal-Slate
		BrandTitle = "KUROSHIO IZAKAYA",
	},
	West = {
		WallPrimary = Color3.fromRGB(238, 222, 192),
		WallTrim = Color3.fromRGB(246, 240, 226),
		FloorWood = Color3.fromRGB(112, 74, 44),
		TableTop = Color3.fromRGB(142, 94, 58),
		TableMat = Enum.Material.Wood,
		SeatLeather = Color3.fromRGB(148, 26, 40),
		BrassAccent = Color3.fromRGB(240, 194, 70),
		RoofColor = Color3.fromRGB(54, 106, 122),
		BrandTitle = "TRATTORIA CORLEONE",
	},
	North = {
		WallPrimary = Color3.fromRGB(238, 222, 192),
		WallTrim = Color3.fromRGB(246, 240, 226),
		FloorWood = Color3.fromRGB(108, 76, 52),
		TableTop = Color3.fromRGB(236, 232, 224),
		TableMat = Enum.Material.Marble,
		SeatLeather = Color3.fromRGB(146, 26, 40),
		BrassAccent = Color3.fromRGB(242, 196, 72),
		RoofColor = Color3.fromRGB(54, 106, 122),
		BrandTitle = "BRASSERIE LE NOIR",
	},
	South = {
		WallPrimary = Color3.fromRGB(238, 222, 192),
		WallTrim = Color3.fromRGB(246, 240, 226),
		FloorWood = Color3.fromRGB(124, 82, 48),
		TableTop = Color3.fromRGB(154, 102, 58),
		TableMat = Enum.Material.Wood,
		SeatLeather = Color3.fromRGB(150, 28, 38),
		BrassAccent = Color3.fromRGB(240, 194, 70),
		RoofColor = Color3.fromRGB(54, 106, 122),
		BrandTitle = "CANTINA EL CARTEL",
	},
}

local UPPER_STORY_PART_NAMES: { [string]: boolean } = {
	UpperFrontWall = true,
	LeftUpper = true,
	RightUpper = true,
	RoofEaves = true,
	RoofFascia = true,
	RoofSlope_Front = true,
	RoofSlope_Back = true,
	RoofRidgeCap = true,
	SignFacadeBox = true,
	SignTopTrim = true,
	RestaurantMarquee = true,
}

local ROOF_ONLY_PART_NAMES: { [string]: boolean } = {
	RoofEaves = true,
	RoofFascia = true,
	RoofSlope_Front = true,
	RoofSlope_Back = true,
	RoofRidgeCap = true,
	SignFacadeBox = true,
	SignTopTrim = true,
	RestaurantMarquee = true,
}

local function isUpperStoryPart(name: string): boolean
	if UPPER_STORY_PART_NAMES[name] then
		return true
	end
	return string.find(name, "UpWin", 1, true) ~= nil
		or string.find(name, "BalconyRail", 1, true) ~= nil
		or string.find(name, "Roof", 1, true) ~= nil
end

local function isRoofPart(name: string): boolean
	if ROOF_ONLY_PART_NAMES[name] then
		return true
	end
	return string.find(name, "Roof", 1, true) ~= nil
end

local function captureAndRestoreArchBaseline(hq: Model, hqCF: CFrame): ()
	for _, folderName in ipairs({ "BistroArchitecture", "InteriorFurniture", "OrderReceiptStation", "Anchors", "CustomVibeDecor" }) do
		local folder = hq:FindFirstChild(folderName)
		if not folder then
			continue
		end
		for _, desc in ipairs(folder:GetDescendants()) do
			if desc:IsA("BasePart") then
				if desc:GetAttribute("OrigCaptured") ~= true then
					desc:SetAttribute("OrigCaptured", true)
					desc:SetAttribute("OrigTransp", desc.Transparency)
					desc:SetAttribute("OrigCollide", desc.CanCollide)
					desc:SetAttribute("OrigSize", desc.Size)
					desc:SetAttribute("OrigRelPos", hqCF:ToObjectSpace(desc.CFrame).Position)
					local rx, ry, rz = hqCF:ToObjectSpace(desc.CFrame):ToOrientation()
					desc:SetAttribute("OrigRelRot", Vector3.new(rx, ry, rz))
				else
					local origT = desc:GetAttribute("OrigTransp")
					local origC = desc:GetAttribute("OrigCollide")
					local origS = desc:GetAttribute("OrigSize")
					local origP = desc:GetAttribute("OrigRelPos")
					local origR = desc:GetAttribute("OrigRelRot")
					if typeof(origT) == "number" then desc.Transparency = origT end
					if typeof(origC) == "boolean" then desc.CanCollide = origC end
					if typeof(origS) == "Vector3" then desc.Size = origS end
					if typeof(origP) == "Vector3" and typeof(origR) == "Vector3" then
						desc.CFrame = hqCF * CFrame.new(origP) * CFrame.fromOrientation(origR.X, origR.Y, origR.Z)
					end
				end
				for _, gui in ipairs(desc:GetChildren()) do
					if gui:IsA("SurfaceGui") then
						gui.Enabled = true
					end
				end
			end
		end
	end
end

local function hideArchPart(p: BasePart): ()
	p.Transparency = 1
	p.CanCollide = false
	for _, gui in ipairs(p:GetChildren()) do
		if gui:IsA("SurfaceGui") then
			gui.Enabled = false
		end
	end
end

local function setArchMarqueeText(p: BasePart, title: string, subtitle: string, accent: Color3): ()
	for _, child in ipairs(p:GetChildren()) do
		if child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sgui = Instance.new("SurfaceGui")
		sgui.Name = "ExpansionMarqueeGui"
		sgui.Face = face
		sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sgui.PixelsPerStud = 30
		sgui.Parent = p

		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
		bg.BorderSizePixel = 0
		bg.Parent = sgui

		local topBar = Instance.new("Frame")
		topBar.Size = UDim2.new(1, 0, 0, 5)
		topBar.BackgroundColor3 = accent
		topBar.BorderSizePixel = 0
		topBar.Parent = bg

		local t1 = Instance.new("TextLabel")
		t1.Position = UDim2.new(0.03, 0, 0.10, 0)
		t1.Size = UDim2.new(0.94, 0, 0.44, 0)
		t1.BackgroundTransparency = 1
		t1.Font = Enum.Font.GothamBlack
		t1.TextScaled = true
		t1.Text = title
		t1.TextColor3 = Color3.fromRGB(242, 238, 228)
		t1.Parent = bg

		local t2 = Instance.new("TextLabel")
		t2.Position = UDim2.new(0.04, 0, 0.56, 0)
		t2.Size = UDim2.new(0.92, 0, 0.24, 0)
		t2.BackgroundTransparency = 1
		t2.Font = Enum.Font.GothamBold
		t2.TextScaled = true
		t2.Text = subtitle
		t2.TextColor3 = accent
		t2.Parent = bg
	end
end

function RestaurantExpansionBuilder.BuildTierForHQ(
	baseModel: Model,
	hq: Model,
	slot: string,
	restaurantLevel: number
): { Tier: number, PartCount: number, BoundsViolations: number, Width: number, Height: number, Depth: number }
	local primary = hq.PrimaryPart
	if not primary then
		return { Tier = 1, PartCount = 0, BoundsViolations = 0, Width = 78, Height = 22, Depth = 52 }
	end

	local hqCF = primary.CFrame
	local tier = math.clamp(math.floor(restaurantLevel or 1), 1, RestaurantExpansionConfig.MAX_PHYSICAL_TIER)
	local spec = RestaurantExpansionConfig.GetTierSpec(tier)
	local palette = SLOT_PALETTES[slot] or SLOT_PALETTES.East
	local safe = RestaurantExpansionConfig.SAFE_BOUNDS

	-- 1. Restore BistroArchitecture to clean baseline first
	captureAndRestoreArchBaseline(hq, hqCF)

	local oldExp = hq:FindFirstChild("HQPhysicalExpansion")
	if oldExp then oldExp:Destroy() end
	local oldLegacy = hq:FindFirstChild("HQUpgradeVisuals")
	if oldLegacy then oldLegacy:Destroy() end

	-- 2A. REMOVE THE DOORWAY BLOCK & CLEAR THE ENTIRE GRAND ENTRANCE (relocate Grill inside Kitchen pass & shift front register out of doorway!)
	local FLOOR1_LIFT = 5.5 -- Raises Floor 1 ceiling from 15.7 -> 21.2 studs (airy, modern, head-clear luxury hall!)
	local orderStation = hq:FindFirstChild("OrderReceiptStation")
	if orderStation then
		for _, desc in ipairs(orderStation:GetDescendants()) do
			if desc:IsA("BasePart") then
				local n = desc.Name
				local origP = desc:GetAttribute("OrigRelPos")
				local origR = desc:GetAttribute("OrigRelRot")
				if typeof(origP) == "Vector3" and typeof(origR) == "Vector3" then
					if n == "GrillBase" or n == "GrillTop" or n == "SizzleSkillet" or n == "CookingFoodProp" then
						-- Relocate the grill cleanly off the front entrance red carpet into the rear kitchen line!
						local shifted = Vector3.new(origP.X - 22.5, origP.Y, origP.Z - 46.0)
						desc.CFrame = hqCF * CFrame.new(shifted) * CFrame.fromOrientation(origR.X, origR.Y, origR.Z)
					elseif n == "RegisterBody" or n == "RegisterDrawer" or n == "RegisterScreen" or n == "ReceiptCurl" then
						-- Shift host cash register slightly right so the 24-stud front entrance is 100% unobstructed
						local shifted = Vector3.new(origP.X + 6.5, origP.Y, origP.Z)
						desc.CFrame = hqCF * CFrame.new(shifted) * CFrame.fromOrientation(origR.X, origR.Y, origR.Z)
					end
				end
			end
		end
	end
	local anchorsFolder = hq:FindFirstChild("Anchors")
	if anchorsFolder then
		local serveCounter = anchorsFolder:FindFirstChild("ServeCounter")
		if serveCounter and serveCounter:IsA("BasePart") then
			local origP = serveCounter:GetAttribute("OrigRelPos")
			local origR = serveCounter:GetAttribute("OrigRelRot")
			if typeof(origP) == "Vector3" and typeof(origR) == "Vector3" then
				serveCounter.CFrame = hqCF * CFrame.new(origP.X + 6.5, origP.Y, origP.Z) * CFrame.fromOrientation(origR.X, origR.Y, origR.Z)
			end
		end
	end

	-- 2B. Raise low head-hitting interior pendant lamps, wooden lantern shades, ceiling rafters & exhaust hood up into our new airy 21-stud ceiling!
	local interiorFurn = hq:FindFirstChild("InteriorFurniture")
	if interiorFurn then
		for _, desc in ipairs(interiorFurn:GetDescendants()) do
			if desc:IsA("BasePart") then
				local n = desc.Name
				local origP = desc:GetAttribute("OrigRelPos")
				local origR = desc:GetAttribute("OrigRelRot")
				if typeof(origP) == "Vector3" and typeof(origR) == "Vector3" then
					if n == "PendantBulb" or n == "Cord" or n == "RangeHood" or string.find(n, "Lamp", 1, true) or string.find(n, "Shade", 1, true) then
						desc.CFrame = hqCF * CFrame.new(origP.X, origP.Y + FLOOR1_LIFT, origP.Z) * CFrame.fromOrientation(origR.X, origR.Y, origR.Z)
						if n == "PendantBulb" then
							desc.CanCollide = false
						end
					end
				end
			end
		end
	end
	local customVibe = hq:FindFirstChild("CustomVibeDecor")
	if customVibe then
		for _, desc in ipairs(customVibe:GetDescendants()) do
			if desc:IsA("BasePart") then
				local n = desc.Name
				local origP = desc:GetAttribute("OrigRelPos")
				local origR = desc:GetAttribute("OrigRelRot")
				if typeof(origP) == "Vector3" and typeof(origR) == "Vector3" then
					if n == "LanternShade" or n == "CeilingRafter" or n == "IslandExhaustHood" or n == "HoodBrassTrim" or n == "HoodDuctL" or n == "HoodDuctR" then
						desc.CFrame = hqCF * CFrame.new(origP.X, origP.Y + FLOOR1_LIFT, origP.Z) * CFrame.fromOrientation(origR.X, origR.Y, origR.Z)
						if n == "LanternShade" then
							desc.CanCollide = false
						end
					elseif n == "ServeCounterTop" or n == "ServeBrassTrim" then
						desc.CFrame = hqCF * CFrame.new(origP.X + 6.5, origP.Y, origP.Z) * CFrame.fromOrientation(origR.X, origR.Y, origR.Z)
					end
				end
			end
		end
	end

	-- 2C. Configure BistroArchitecture: BIGGER 24-stud Grand Entrance Door + Taller 21-stud Ceiling + Elevated Upper Floors!
	local arch = hq:FindFirstChild("BistroArchitecture")
	if arch then
		for _, desc in ipairs(arch:GetDescendants()) do
			if desc:IsA("BasePart") then
				local n = desc.Name
				local origP = desc:GetAttribute("OrigRelPos")
				local origR = desc:GetAttribute("OrigRelRot")
				local origS = desc:GetAttribute("OrigSize")

				-- Always hide cramped old narrow door parts, striped bistro awnings, shutters, umbrellas & legacy sloped roofs
				-- so our Classical Sandstone & Golden-Domed Palace architecture matches the UI icon 1:1 at every level!
				if n == "DoorPillarL" or n == "DoorPillarR" or n == "DoorTransom" or n == "DoorSconce"
					or n == "OpenDoorFrame" or n == "OpenDoorGlass" or n == "WelcomeMat" or n == "StoryBelt"
					or string.find(n, "Awning", 1, true) or string.find(n, "StringBulb", 1, true)
					or string.find(n, "Shutter", 1, true) or string.find(n, "Umb", 1, true)
					or n == "UpWinFrame" or n == "UpWinGlass" or n == "BalconyRail"
					or n == "KitchenChimney" or n == "ChimneyCap"
					or isRoofPart(n) then
					hideArchPart(desc)
				elseif n == "FrontBrickL" then
					desc.Size = Vector3.new(24.5, 4.8, 1.8)
					desc.CFrame = hqCF * CFrame.new(-25.8, 2.9, 18.0)
					desc.Color = palette.WallPrimary
					desc.Material = Enum.Material.SmoothPlastic
				elseif n == "FrontBrickR" then
					desc.Size = Vector3.new(24.5, 4.8, 1.8)
					desc.CFrame = hqCF * CFrame.new(25.8, 2.9, 18.0)
					desc.Color = palette.WallPrimary
					desc.Material = Enum.Material.SmoothPlastic
				elseif n == "FrontGlassL" then
					desc.Size = Vector3.new(21.5, 14.2, 0.35)
					desc.CFrame = hqCF * CFrame.new(-25.8, 12.6, 18.0)
					desc.Color = Color3.fromRGB(255, 224, 152)
					desc.Transparency = 0.38
				elseif n == "FrontGlassR" then
					desc.Size = Vector3.new(21.5, 14.2, 0.35)
					desc.CFrame = hqCF * CFrame.new(25.8, 12.6, 18.0)
					desc.Color = Color3.fromRGB(255, 224, 152)
					desc.Transparency = 0.38
				elseif n == "WinSill" or n == "WinTopBar" then
					desc.Color = palette.WallTrim
					desc.Material = Enum.Material.Marble
				elseif n == "Mullion" and typeof(origP) == "Vector3" then
					if math.abs(origP.X) < 13.0 then
						hideArchPart(desc)
					else
						desc.Size = Vector3.new(0.45, 14.4, 0.7)
						desc.CFrame = hqCF * CFrame.new(origP.X, 12.6, origP.Z)
						desc.Color = palette.BrassAccent
						desc.Material = Enum.Material.Metal
					end
				elseif n == "ChalkboardMenu" and typeof(origP) == "Vector3" then
					desc.CFrame = hqCF * CFrame.new(-28.0, 3.1, 21.8) * CFrame.Angles(0, math.rad(14), 0)
				elseif n == "OpenNeonBox" and typeof(origP) == "Vector3" and typeof(origR) == "Vector3" then
					desc.CFrame = hqCF * CFrame.new(-24.0, origP.Y + 4.5, origP.Z) * CFrame.fromOrientation(origR.X, origR.Y, origR.Z)
				elseif (n == "LeftMidL" or n == "LeftMidR" or n == "RightMidL" or n == "RightMidR" or n == "LeftGlass" or n == "RightGlass") and typeof(origP) == "Vector3" and typeof(origS) == "Vector3" then
					if (tier >= 2 and (n == "RightGlass")) or (tier >= 3 and (n == "LeftGlass")) or (tier <= 2 and n == "LeftGlass") then
						hideArchPart(desc)
					else
						local newH = origS.Y + FLOOR1_LIFT
						desc.Size = Vector3.new(origS.X, newH, origS.Z)
						desc.CFrame = hqCF * CFrame.new(origP.X, 6.5 + newH * 0.5, origP.Z)
						if n ~= "LeftGlass" and n ~= "RightGlass" then
							desc.Color = palette.WallPrimary
							desc.Material = Enum.Material.SmoothPlastic
						end
					end
				elseif (tier >= 2 and n == "RightBrick") or n == "LeftBrick" then
					hideArchPart(desc)
				elseif tier <= 2 then
					-- Genuine tall 1-story Classical Sandstone starter palace (21-stud ceiling!): hide upper-story walls
					local isHighPart = typeof(origP) == "Vector3" and origP.Y > 16.4 and n ~= "BackStucco" and n ~= "CornerPilaster"
					if isUpperStoryPart(n) or isHighPart or n == "BackBrick" or n == "BackStucco" then
						hideArchPart(desc)
					elseif n == "CornerPilaster" and typeof(origP) == "Vector3" then
						desc.Size = Vector3.new(2.8, 21.6, 2.8)
						desc.CFrame = hqCF * CFrame.new(origP.X, 11.4, origP.Z)
						desc.Color = palette.WallTrim
						desc.Material = Enum.Material.Marble
					end
				else
					-- Levels 3-15: Classical 2nd-story Sandstone Palace walls (sits cleanly on Y=22.20 Floor 2 deck!)
					if n == "BackBrick" or n == "BackStucco" then
						hideArchPart(desc)
					elseif n == "CornerPilaster" and typeof(origP) == "Vector3" then
						local pilH = if tier >= 7 then 42.5 else 42.0
						desc.Size = Vector3.new(3.0, pilH, 3.0)
						desc.CFrame = hqCF * CFrame.new(origP.X, pilH * 0.5 + 0.6, origP.Z)
						desc.Color = palette.WallTrim
						desc.Material = Enum.Material.Marble
					elseif (isUpperStoryPart(n) or (typeof(origP) == "Vector3" and origP.Y > 16.4)) and typeof(origP) == "Vector3" and typeof(origR) == "Vector3" then
						if n == "UpperFrontWall" or n == "LeftUpper" or n == "RightUpper" then
							-- Stretch 2nd-floor Classical Sandstone walls cleanly from Floor 2 (22.2) to Floor 3 (42.8)
							if typeof(origS) == "Vector3" then
								desc.Size = Vector3.new(origS.X, 20.4, origS.Z)
								desc.CFrame = hqCF * CFrame.new(origP.X, 32.4, origP.Z) * CFrame.fromOrientation(origR.X, origR.Y, origR.Z)
								desc.Color = palette.WallPrimary
								desc.Material = Enum.Material.SmoothPlastic
							end
						else
							hideArchPart(desc)
						end
					end
				end
			end
		end
	end

	-- 3. Build modular physical expansion geometry strictly validated inside expanded base SAFE_BOUNDS
	local expFolder = Instance.new("Folder")
	expFolder.Name = "HQPhysicalExpansion"
	expFolder:SetAttribute("PhysicalTier", tier)
	expFolder:SetAttribute("DisplayName", spec.DisplayName)
	expFolder:SetAttribute("Floors", spec.Floors)

	local partCount = 0
	local boundsViolations = 0
	local minX, maxX = -38.0, 38.0
	local minY, maxY = 0.0, if tier >= 3 then 42.5 else 18.5
	local minZ, maxZ = -31.0, 19.0

	local function recordAndCheckBounds(relCF: CFrame, sz: Vector3): boolean
		local hx, hy, hz = sz.X * 0.5, sz.Y * 0.5, sz.Z * 0.5
		local rv, uv, lv = relCF.RightVector, relCF.UpVector, relCF.LookVector
		local ex = math.abs(rv.X) * hx + math.abs(uv.X) * hy + math.abs(lv.X) * hz
		local ey = math.abs(rv.Y) * hx + math.abs(uv.Y) * hy + math.abs(lv.Y) * hz
		local ez = math.abs(rv.Z) * hx + math.abs(uv.Z) * hy + math.abs(lv.Z) * hz
		local relPos = relCF.Position
		local pMinX, pMaxX = relPos.X - ex, relPos.X + ex
		local pMinY, pMaxY = relPos.Y - ey, relPos.Y + ey
		local pMinZ, pMaxZ = relPos.Z - ez, relPos.Z + ez

		if pMinX < safe.MinX - 0.5 or pMaxX > safe.MaxX + 0.5 or pMinZ < safe.MinZ - 0.5 or pMaxZ > safe.MaxZ + 0.5 or pMaxY > safe.MaxY + 0.5 then
			boundsViolations += 1
			warn(string.format(
				"[RestaurantExpansionBuilder] Clamped out-of-bounds part at (%.1f, %.1f, %.1f) ext(%.1f, %.1f, %.1f)",
				relPos.X, relPos.Y, relPos.Z, ex * 2, ey * 2, ez * 2
			))
			return false
		end

		minX = math.min(minX, pMinX)
		maxX = math.max(maxX, pMaxX)
		minY = math.min(minY, pMinY)
		maxY = math.max(maxY, pMaxY)
		minZ = math.min(minZ, pMinZ)
		maxZ = math.max(maxZ, pMaxZ)
		return true
	end

	local function mPart(
		name: string,
		sz: Vector3,
		relCF: CFrame,
		col: Color3,
		mat: Enum.Material,
		collide: boolean?,
		transp: number?,
		shape: Enum.PartType?
	): Part?
		if not recordAndCheckBounds(relCF, sz) then
			return nil
		end
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = hqCF * relCF
		p.Color = col
		p.Material = mat
		p.Anchored = true
		p.CanCollide = if collide == nil then true else collide
		p.CanTouch = false
		p.CanQuery = p.CanCollide
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if transp then p.Transparency = transp end
		if shape then p.Shape = shape end
		p.Parent = expFolder
		partCount += 1
		return p
	end

	local function addWarmLight(parent: Instance?, range: number, brightness: number, col: Color3?): ()
		if not parent then return end
		local pl = Instance.new("PointLight")
		pl.Color = col or Color3.fromRGB(255, 224, 168)
		pl.Range = range
		pl.Brightness = brightness
		pl.Shadows = false
		pl.Parent = parent
	end

	-- Reusable dining table + 2 plush chairs module (matches exact zero-clipping SeatOffset/TableOffset!)
	local function addDiningTableSet(tag: string, tx: number, floorY: number, tz: number, isLuxury: boolean): ()
		local topCol = if isLuxury then Color3.fromRGB(240, 236, 228)
			elseif tier >= 4 then Color3.fromRGB(52, 56, 66)
			else palette.TableTop
		local topMat = if isLuxury or tier >= 4 then Enum.Material.Marble else palette.TableMat
		local legCol = if isLuxury then palette.BrassAccent else Color3.fromRGB(36, 38, 44)
		local seatCol = if isLuxury then Color3.fromRGB(122, 28, 38) else palette.SeatLeather

		mPart(tag .. "_Base", Vector3.new(2.2, 0.35, 2.2), CFrame.new(tx, floorY + 0.18, tz), legCol, Enum.Material.Metal, false)
		mPart(tag .. "_Pedestal", Vector3.new(0.7, 2.75, 0.7), CFrame.new(tx, floorY + 1.65, tz), legCol, Enum.Material.Metal, true)
		mPart(tag .. "_Top", Vector3.new(6.2, 0.32, 4.4), CFrame.new(tx, floorY + 3.12, tz), topCol, topMat, true)
		if isLuxury then
			mPart(tag .. "_GoldRim", Vector3.new(6.4, 0.14, 4.6), CFrame.new(tx, floorY + 3.04, tz), palette.BrassAccent, Enum.Material.Metal, false)
		end
		mPart(tag .. "_Candle", Vector3.new(0.7, 0.45, 0.45), CFrame.new(tx, floorY + 3.62, tz) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(246, 224, 162), Enum.Material.SmoothPlastic, false, nil, Enum.PartType.Cylinder)

		for _, dz in ipairs({ 3.25, -3.25 }) do
			local dir = if dz > 0 then 1 else -1
			mPart(tag .. "_Seat", Vector3.new(2.3, 0.45, 2.2), CFrame.new(tx, floorY + 1.65, tz + dz), seatCol, Enum.Material.Fabric, false)
			mPart(tag .. "_Legs", Vector3.new(1.9, 1.45, 1.8), CFrame.new(tx, floorY + 0.72, tz + dz), legCol, Enum.Material.Wood, false)
			mPart(tag .. "_Back", Vector3.new(2.3, 2.1, 0.32), CFrame.new(tx, floorY + 2.85, tz + dz + dir * 1.0), seatCol, Enum.Material.Fabric, false)
		end
	end

	-- Reusable Side Wing Shell helper (builds clean walled + panoramic glass wing seamlessly!)
	local darkSteel = Color3.fromRGB(36, 40, 48)
	local brushedSteel = Color3.fromRGB(154, 160, 170)
	local copper = Color3.fromRGB(184, 108, 62)
	local glassCol = Color3.fromRGB(168, 198, 218)
	local marbleWhite = Color3.fromRGB(246, 240, 226)
	local stoneWainscot = Color3.fromRGB(224, 208, 178)
	local velvetRed = Color3.fromRGB(168, 24, 38)
	local warmWinGlow = Color3.fromRGB(255, 214, 128)
	local hedgeCol = Color3.fromRGB(58, 134, 62)

	-- Iconic Ribbed Classical Palace Dome Builder (1:1 visual match to the Restaurant HQ UI icon!)
	local function buildClassicalDome(
		prefix: string,
		cx: number,
		baseY: number,
		cz: number,
		radius: number,
		drumH: number,
		isGoldCrown: boolean
	): ()
		local domeMainCol = if isGoldCrown then Color3.fromRGB(240, 194, 68) else palette.RoofColor
		local goldCol = palette.BrassAccent

		-- Square Sandstone/Marble Plinth Base + Golden Cornice Belt
		local plinthW = radius * 2.25
		mPart(prefix .. "_Plinth", Vector3.new(plinthW, 2.2, plinthW), CFrame.new(cx, baseY + 1.1, cz), palette.WallPrimary, Enum.Material.SmoothPlastic, false)
		mPart(prefix .. "_PlinthGold", Vector3.new(plinthW + 0.9, 0.65, plinthW + 0.9), CFrame.new(cx, baseY + 2.35, cz), goldCol, Enum.Material.Metal, false)

		-- Circular Classical Marble Drum with Illuminated Warm Drum Windows
		local drumY = baseY + 2.4 + drumH * 0.5
		mPart(prefix .. "_Drum", Vector3.new(drumH, radius * 2.02, radius * 2.02), CFrame.new(cx, drumY, cz) * CFrame.Angles(0, 0, math.rad(90)), marbleWhite, Enum.Material.Marble, false, nil, Enum.PartType.Cylinder)
		mPart(prefix .. "_DrumCrown", Vector3.new(0.85, radius * 2.16, radius * 2.16), CFrame.new(cx, baseY + 2.4 + drumH, cz) * CFrame.Angles(0, 0, math.rad(90)), goldCol, Enum.Material.Metal, false, nil, Enum.PartType.Cylinder)

		-- 8 Warm Illuminated Drum Windows around the circular drum
		for i = 0, 7 do
			local ang = math.rad(i * 45)
			local wx = cx + math.sin(ang) * (radius * 0.98)
			local wz = cz + math.cos(ang) * (radius * 0.98)
			mPart(prefix .. "_DrumWin_" .. i, Vector3.new(radius * 0.34, drumH * 0.56, 0.55), CFrame.new(wx, drumY, wz) * CFrame.Angles(0, ang, 0), warmWinGlow, Enum.Material.Neon, false, 0.12)
		end

		-- True Hemispherical Classical Dome Shell (sunk slightly into drum crown so bottom half hides cleanly!)
		local domeCenterY = baseY + 2.4 + drumH + 0.2
		mPart(prefix .. "_DomeShell", Vector3.new(radius * 1.98, radius * 1.72, radius * 1.98), CFrame.new(cx, domeCenterY, cz), domeMainCol, Enum.Material.Metal, false, nil, Enum.PartType.Ball)

		-- 6 Bold Gleaming Golden Meridian Ribs hugging the classical dome (pops crisply day & night!)
		local ribGold = Color3.fromRGB(252, 206, 72)
		for r = 0, 5 do
			local rotY = math.rad(r * 30)
			mPart(prefix .. "_DomeRib_" .. r, Vector3.new(radius * 2.08, radius * 1.80, math.max(0.95, radius * 0.105)), CFrame.new(cx, domeCenterY, cz) * CFrame.Angles(0, rotY, 0), ribGold, Enum.Material.Metal, false, nil, Enum.PartType.Ball)
		end

		-- Classical Golden Lantern Cupola + Tapered Spire Finial
		local lanternBaseY = domeCenterY + radius * 0.86
		mPart(prefix .. "_CupolaRing", Vector3.new(0.75, radius * 0.54, radius * 0.54), CFrame.new(cx, lanternBaseY, cz) * CFrame.Angles(0, 0, math.rad(90)), goldCol, Enum.Material.Metal, false, nil, Enum.PartType.Cylinder)
		local lanternCore = mPart(prefix .. "_CupolaLantern", Vector3.new(radius * 0.34, radius * 0.42, radius * 0.42), CFrame.new(cx, lanternBaseY + radius * 0.20, cz) * CFrame.Angles(0, 0, math.rad(90)), warmWinGlow, Enum.Material.Neon, false, 0.08, Enum.PartType.Cylinder)
		addWarmLight(lanternCore, math.min(95, radius * 3.8), 1.8, Color3.fromRGB(255, 224, 148))
		mPart(prefix .. "_CupolaCap", Vector3.new(radius * 0.48, radius * 0.38, radius * 0.48), CFrame.new(cx, lanternBaseY + radius * 0.40, cz), goldCol, Enum.Material.Metal, false, nil, Enum.PartType.Ball)
		mPart(prefix .. "_SpireShaft", Vector3.new(radius * 0.52, math.max(0.6, radius * 0.08), math.max(0.6, radius * 0.08)), CFrame.new(cx, lanternBaseY + radius * 0.72, cz) * CFrame.Angles(0, 0, math.rad(90)), goldCol, Enum.Material.Metal, false, nil, Enum.PartType.Cylinder)
		mPart(prefix .. "_SpireOrb", Vector3.new(radius * 0.19, radius * 0.19, radius * 0.19), CFrame.new(cx, lanternBaseY + radius * 0.98, cz), Color3.fromRGB(255, 232, 146), Enum.Material.Neon, false, nil, Enum.PartType.Ball)
	end

	-- Reusable Warm Glowing Classical Arched Window Bay (matches the golden arched windows in the HQ icon!)
	local function addClassicalArchedWindow(prefix: string, wx: number, wy: number, wz: number, w: number, h: number): ()
		mPart(prefix .. "_Frame", Vector3.new(w + 0.9, h + 0.6, 0.65), CFrame.new(wx, wy, wz), marbleWhite, Enum.Material.Marble, false)
		mPart(prefix .. "_Glass", Vector3.new(w, h, 0.42), CFrame.new(wx, wy, wz + 0.22), warmWinGlow, Enum.Material.Neon, false, 0.14)
		mPart(prefix .. "_ArchTop", Vector3.new(0.42, w, w), CFrame.new(wx, wy + h * 0.5, wz + 0.22) * CFrame.Angles(0, math.rad(90), 0), warmWinGlow, Enum.Material.Neon, false, 0.14, Enum.PartType.Cylinder)
		mPart(prefix .. "_ArchRim", Vector3.new(0.6, w + 0.85, w + 0.85), CFrame.new(wx, wy + h * 0.5, wz + 0.05) * CFrame.Angles(0, math.rad(90), 0), marbleWhite, Enum.Material.Marble, false, nil, Enum.PartType.Cylinder)
		mPart(prefix .. "_Sill", Vector3.new(w + 1.4, 0.55, 1.15), CFrame.new(wx, wy - h * 0.5 - 0.3, wz + 0.3), marbleWhite, Enum.Material.Marble, false)
		mPart(prefix .. "_MullionV", Vector3.new(0.24, h + w * 0.45, 0.55), CFrame.new(wx, wy + w * 0.15, wz + 0.28), palette.BrassAccent, Enum.Material.Metal, false)
		mPart(prefix .. "_MullionH", Vector3.new(w + 0.1, 0.24, 0.55), CFrame.new(wx, wy + 0.2, wz + 0.28), palette.BrassAccent, Enum.Material.Metal, false)
	end

	local function buildWingShell(
		prefix: string,
		innerX: number,
		outerX: number,
		zBack: number,
		zFront: number,
		floorColor: Color3,
		floorMat: Enum.Material,
		wallLowColor: Color3,
		wallLowMat: Enum.Material
	): ()
		local w = math.abs(outerX - innerX)
		local cx = (innerX + outerX) * 0.5
		local d = zFront - zBack
		local cz = (zBack + zFront) * 0.5
		local outerSign = if outerX > innerX then 1 else -1

		mPart(prefix .. "_Foundation", Vector3.new(w + 1.0, 1.2, d + 1.6), CFrame.new(cx, 0.0, cz), stoneWainscot, Enum.Material.Concrete, true)
		mPart(prefix .. "_Floor", Vector3.new(w + 0.4, 0.4, d), CFrame.new(cx, 0.6, cz), floorColor, floorMat, true)
		mPart(prefix .. "_Ceiling", Vector3.new(w + 1.4, 1.2, d + 1.2), CFrame.new(cx, 21.2, cz), palette.WallTrim, Enum.Material.Wood, true)
		mPart(prefix .. "_Roof", Vector3.new(w + 2.4, 1.6, d + 2.4), CFrame.new(cx, 22.6, cz), palette.RoofColor, Enum.Material.Slate, true)
		mPart(prefix .. "_RoofTrim", Vector3.new(w + 2.8, 0.80, d + 2.8), CFrame.new(cx, 23.7, cz), palette.BrassAccent, Enum.Material.Metal, false)

		-- Outer End Wall (tall airy 12.8-stud panoramic glass!)
		mPart(prefix .. "_WallOut_Low", Vector3.new(1.6, 5.2, d + 0.6), CFrame.new(outerX, 3.2, cz), wallLowColor, wallLowMat, true)
		mPart(prefix .. "_WallOut_Glass", Vector3.new(0.4, 12.8, math.max(8, d - 6.0)), CFrame.new(outerX, 12.2, cz), glassCol, Enum.Material.Glass, true, 0.52)
		mPart(prefix .. "_WallOut_Top", Vector3.new(1.6, 2.8, d + 0.6), CFrame.new(outerX, 19.8, cz), palette.WallPrimary, Enum.Material.SmoothPlastic, true)

		-- Front Wall (tall panoramic glass) & Rear Wall
		mPart(prefix .. "_WallF_Low", Vector3.new(w, 5.2, 1.6), CFrame.new(cx, 3.2, zFront), wallLowColor, wallLowMat, true)
		mPart(prefix .. "_WallF_Glass", Vector3.new(math.max(8, w - 6.0), 12.8, 0.4), CFrame.new(cx, 12.2, zFront), glassCol, Enum.Material.Glass, true, 0.52)
		mPart(prefix .. "_WallF_Top", Vector3.new(w, 2.8, 1.6), CFrame.new(cx, 19.8, zFront), palette.WallPrimary, Enum.Material.SmoothPlastic, true)
		mPart(prefix .. "_WallB_Low", Vector3.new(w, 5.2, 1.6), CFrame.new(cx, 3.2, zBack), wallLowColor, wallLowMat, true)
		mPart(prefix .. "_WallB_Top", Vector3.new(w, 15.6, 1.6), CFrame.new(cx, 13.4, zBack), palette.WallPrimary, Enum.Material.SmoothPlastic, true)

		-- Tall Fluted Ivory Classical Columns + Golden Cornice Trim (matches HQ icon!)
		for _, pz in ipairs({ zBack, cz, zFront }) do
			mPart(prefix .. "_Col", Vector3.new(21.2, 2.3, 2.3), CFrame.new(outerX + outerSign * 0.2, 11.1, pz) * CFrame.Angles(0, 0, math.rad(90)), marbleWhite, Enum.Material.Marble, true, nil, Enum.PartType.Cylinder)
			mPart(prefix .. "_ColCap", Vector3.new(2.9, 0.85, 2.9), CFrame.new(outerX + outerSign * 0.2, 21.2, pz), palette.BrassAccent, Enum.Material.Metal, false)
		end
		mPart(prefix .. "_ClassicalCorniceF", Vector3.new(math.max(12, w + 1.4), 0.9, 2.4), CFrame.new(cx, 21.8, zFront + 0.8), marbleWhite, Enum.Material.Marble, false)
	end

	-- =========================================================================
	-- ALL LEVELS (LV.1-15): CLASSICAL GRAND PALACE FRONT ENTRANCE, CORINTHIAN COLUMNS,
	-- ROYAL RED CARPET STEPS & MANICURED BOXWOOD HEDGES (1:1 MATCH TO HQ ICON!)
	-- =========================================================================
	mPart("GrandDoor_Threshold", Vector3.new(26.4, 0.28, 9.0), CFrame.new(0, 0.65, 20.6), marbleWhite, Enum.Material.Marble, false)
	-- Royal Red Velvet Carpet Runner with Golden Trim right up the Front Entrance (from Lv.1+ just like the icon!)
	mPart("Classic_RedCarpet", Vector3.new(11.6, 0.14, 14.0), CFrame.new(0, 0.82, 23.2), velvetRed, Enum.Material.Fabric, false)
	mPart("Classic_CarpetTrimL", Vector3.new(0.45, 0.16, 14.0), CFrame.new(-5.8, 0.83, 23.2), palette.BrassAccent, Enum.Material.Metal, false)
	mPart("Classic_CarpetTrimR", Vector3.new(0.45, 0.16, 14.0), CFrame.new(5.8, 0.83, 23.2), palette.BrassAccent, Enum.Material.Metal, false)

	-- Classical Fluted Ivory Corinthian Columns flanking the Grand Archway + Facade Bays!
	for _, cx in ipairs({ -36.5, -24.8, -13.0, 13.0, 24.8, 36.5 }) do
		local isDoorCol = (math.abs(cx) < 14.0)
		local colZ = if isDoorCol then 19.2 else 18.6
		mPart("Classic_ColBase", Vector3.new(3.2, 1.5, 3.2), CFrame.new(cx, 1.35, colZ), marbleWhite, Enum.Material.Marble, false)
		mPart("Classic_ColShaft", Vector3.new(19.0, 2.35, 2.35), CFrame.new(cx, 11.4, colZ) * CFrame.Angles(0, 0, math.rad(90)), marbleWhite, Enum.Material.Marble, isDoorCol, nil, Enum.PartType.Cylinder)
		mPart("Classic_ColCap", Vector3.new(3.3, 0.9, 3.3), CFrame.new(cx, 20.9, colZ), palette.BrassAccent, Enum.Material.Metal, false)
	end
	for _, dx in ipairs({ -13.0, 13.0 }) do
		local lantern = mPart("GrandDoor_Lantern", Vector3.new(1.2, 2.2, 1.2), CFrame.new(dx, 14.5, 20.8), warmWinGlow, Enum.Material.Neon, false, 0.12)
		addWarmLight(lantern, 28, 1.3)
		-- Swung-open decorative glass & brass double-door leaves neatly tucked alongside the wide 24-stud opening!
		local leafSign = if dx < 0 then 1 else -1
		mPart("GrandDoor_OpenLeaf", Vector3.new(0.45, 17.0, 5.2), CFrame.new(dx + leafSign * 1.4, 9.2, 15.2), palette.BrassAccent, Enum.Material.Metal, false)
		mPart("GrandDoor_OpenGlass", Vector3.new(0.22, 14.6, 4.0), CFrame.new(dx + leafSign * 1.4, 9.2, 15.2), warmWinGlow, Enum.Material.Glass, false, 0.45)
	end

	-- Classical Entablature Header & Golden Pediment Trim above Entrance
	mPart("GrandDoor_Header", Vector3.new(78.6, 2.2, 2.6), CFrame.new(0, 20.2, 18.4), marbleWhite, Enum.Material.Marble, true)
	mPart("GrandDoor_BrassArch", Vector3.new(79.4, 0.65, 3.0), CFrame.new(0, 21.5, 18.4), palette.BrassAccent, Enum.Material.Metal, false)
	-- Manicured Green Boxwood Hedges in Classical Sandstone Planters flanking Front Entrance (exact icon match!)
	for _, hx in ipairs({ -24.5, 24.5 }) do
		mPart("Classic_Planter", Vector3.new(16.0, 1.8, 2.8), CFrame.new(hx, 1.5, 21.0), marbleWhite, Enum.Material.Marble, false)
		mPart("Classic_Hedge", Vector3.new(15.2, 2.2, 2.2), CFrame.new(hx, 3.2, 21.0), hedgeCol, Enum.Material.Grass, false)
	end
	-- Front upper frieze beam connecting left/right walls cleanly at Y = 20.2
	mPart("FrontWall_TopBeamL", Vector3.new(25.0, 2.0, 1.8), CFrame.new(-25.8, 20.2, 18.0), palette.WallPrimary, Enum.Material.SmoothPlastic, true)
	mPart("FrontWall_TopBeamR", Vector3.new(25.0, 2.0, 1.8), CFrame.new(25.8, 20.2, 18.0), palette.WallPrimary, Enum.Material.SmoothPlastic, true)

	-- =========================================================================
	-- LEVEL 1 & 2: TALL AIRY SINGLE-STORY PARAPET ROOF, CO-OP REAR/SIDE SERVICE DOORS & GRAND SIGN
	-- =========================================================================
	if tier <= 2 then
		-- Co-op Back Wall (Z = -30.5) with wide 13-stud Rear Service Archway (X = +22..+35) straight to the 4 Warehouses!
		mPart("CoopBackWall_LeftLow", Vector3.new(59.6, 6.0, 1.8), CFrame.new(-8.2, 3.5, -30.5), stoneWainscot, Enum.Material.Brick, true)
		mPart("CoopBackWall_LeftUp", Vector3.new(59.6, 15.2, 1.6), CFrame.new(-8.2, 13.9, -30.5), palette.WallPrimary, Enum.Material.SmoothPlastic, true)
		mPart("CoopBackWall_RightLow", Vector3.new(3.2, 6.0, 1.8), CFrame.new(36.4, 3.5, -30.5), stoneWainscot, Enum.Material.Brick, true)
		mPart("CoopBackWall_RightUp", Vector3.new(3.2, 15.2, 1.6), CFrame.new(36.4, 13.9, -30.5), palette.WallPrimary, Enum.Material.SmoothPlastic, true)
		mPart("CoopBackDoor_Header", Vector3.new(14.8, 6.2, 2.0), CFrame.new(28.5, 18.4, -30.5), palette.WallTrim, Enum.Material.Wood, true)
		mPart("CoopBackDoor_PillarL", Vector3.new(1.8, 16.0, 2.2), CFrame.new(21.6, 8.6, -30.5), palette.WallTrim, Enum.Material.Wood, true)
		mPart("CoopBackDoor_PillarR", Vector3.new(1.8, 16.0, 2.2), CFrame.new(35.0, 8.6, -30.5), palette.WallTrim, Enum.Material.Wood, true)
		mPart("CoopBackDoor_BrassTrim", Vector3.new(13.6, 0.45, 2.4), CFrame.new(28.5, 15.3, -30.5), palette.BrassAccent, Enum.Material.Metal, false)
		mPart("CoopBackDoor_Threshold", Vector3.new(14.2, 0.22, 6.4), CFrame.new(28.5, 0.65, -31.8), marbleWhite, Enum.Material.Marble, false)

		-- Co-op West Kitchen Side Wall (X = -37.5) with wide 13-stud Kitchen Delivery Doorway (Z = -17..-4) directly beside the stove!
		mPart("CoopWestWall_RearLow", Vector3.new(1.8, 6.0, 14.0), CFrame.new(-37.5, 3.5, -24.0), stoneWainscot, Enum.Material.Brick, true)
		mPart("CoopWestWall_FrontLow", Vector3.new(1.8, 6.0, 22.0), CFrame.new(-37.5, 3.5, 7.0), stoneWainscot, Enum.Material.Brick, true)
		mPart("CoopWestWall_FrontGlass", Vector3.new(0.4, 14.5, 8.0), CFrame.new(-37.5, 13.75, 0.0), glassCol, Enum.Material.Glass, true, 0.52)
		mPart("CoopWestDoor_Header", Vector3.new(2.0, 6.2, 14.4), CFrame.new(-37.5, 18.4, -10.5), palette.WallTrim, Enum.Material.Wood, true)
		mPart("CoopWestDoor_PillarN", Vector3.new(2.2, 16.0, 1.6), CFrame.new(-37.5, 8.6, -17.2), palette.WallTrim, Enum.Material.Wood, true)
		mPart("CoopWestDoor_PillarS", Vector3.new(2.2, 16.0, 1.6), CFrame.new(-37.5, 8.6, -3.8), palette.WallTrim, Enum.Material.Wood, true)
		mPart("CoopWestDoor_BrassTrim", Vector3.new(2.4, 0.45, 13.4), CFrame.new(-37.5, 15.3, -10.5), palette.BrassAccent, Enum.Material.Metal, false)
		mPart("CoopWestDoor_Threshold", Vector3.new(6.8, 0.22, 13.6), CFrame.new(-39.2, 0.65, -10.5), marbleWhite, Enum.Material.Marble, false)

		mPart("Lv12_ParapetRoof", Vector3.new(80.4, 1.6, 52.4), CFrame.new(0, 22.1, -6.5), marbleWhite, Enum.Material.Marble, true)
		mPart("Lv12_RoofTrimFront", Vector3.new(81.6, 1.4, 1.6), CFrame.new(0, 23.1, 18.8), marbleWhite, Enum.Material.Marble, false)
		mPart("Lv12_RoofTrimBack", Vector3.new(81.6, 1.4, 1.6), CFrame.new(0, 23.1, -31.6), marbleWhite, Enum.Material.Marble, false)
		mPart("Lv12_BrassCornice", Vector3.new(82.2, 0.6, 53.4), CFrame.new(0, 23.9, -6.5), palette.BrassAccent, Enum.Material.Metal, false)
		mPart("Lv12_SignBox", Vector3.new(36.0, 5.4, 2.2), CFrame.new(0, 25.8, 18.2), marbleWhite, Enum.Material.Marble, false)
		local signFace = mPart("Lv12_SignMarquee", Vector3.new(34.2, 4.6, 0.3), CFrame.new(0, 25.8, 19.4), Color3.fromRGB(16, 18, 22), Enum.Material.SmoothPlastic, false)
		if signFace then
			setArchMarqueeText(signFace, palette.BrandTitle, spec.Subtitle, palette.BrassAccent)
		end

		-- Iconic Classical Ribbed Golden-Teal Palace Dome right from Lv.1-2 (matches HQ icon immediately!)
		buildClassicalDome("Lv12_PalaceDome", 0, 23.2, -6.5, if tier >= 2 then 13.5 else 11.5, 4.4, false)
	end

	-- =========================================================================
	-- LEVEL 2+ (GROWS PROGRESSIVELY AT LV.2, LV.5, LV.8, LV.10!): EAST DINING WING CHAIN
	-- =========================================================================
	if tier >= 2 then
		-- Tall Open East Archway from Main Hall (X = +37.5, Z = -18..+6, 19 studs tall!)
		mPart("EastArch_Header", Vector3.new(2.2, 2.6, 25.0), CFrame.new(37.5, 19.6, -6.0), palette.WallTrim, Enum.Material.Wood, true)
		mPart("EastArch_PillarN", Vector3.new(2.2, 20.2, 1.8), CFrame.new(37.5, 10.6, -18.0), palette.WallTrim, Enum.Material.Wood, true)
		mPart("EastArch_PillarS", Vector3.new(2.2, 20.2, 1.8), CFrame.new(37.5, 10.6, 6.0), palette.WallTrim, Enum.Material.Wood, true)
		mPart("EastArch_BrickS", Vector3.new(1.8, 6.0, 12.0), CFrame.new(37.5, 3.5, 12.0), stoneWainscot, Enum.Material.Brick, true)
		mPart("EastArch_BrickN", Vector3.new(1.8, 6.0, 12.5), CFrame.new(37.5, 3.5, -24.2), stoneWainscot, Enum.Material.Brick, true)

		-- East Wing Outer X grows progressively wider with level (up to +150 at Lv.11-15)!
		local eastOuterX = if tier >= 11 then 150.0
			elseif tier >= 10 then 134.0
			elseif tier >= 8 then 118.0
			elseif tier >= 5 then 94.0
			else 70.0
		local eastWallCol = if tier >= 8 then marbleWhite else stoneWainscot
		local eastWallMat = if tier >= 8 then Enum.Material.Marble else Enum.Material.Brick
		buildWingShell("EastWing", 37.5, eastOuterX, -26.0, 18.0, palette.FloorWood, Enum.Material.WoodPlanks, eastWallCol, eastWallMat)

		-- Lv.2+: 3 Spacious Dining Tables at X = +54 (+6 seats)
		addDiningTableSet("EastWingTable_1", 54.0, 0.80, 8.0, tier >= 5)
		addDiningTableSet("EastWingTable_2", 54.0, 0.80, -6.0, tier >= 5)
		addDiningTableSet("EastWingTable_3", 54.0, 0.80, -20.0, tier >= 5)

		-- Lv.5+: 3 Grand East Banquet Hall Tables at X = +80 (+6 seats!)
		if tier >= 5 then
			addDiningTableSet("EastBanquet_1", 80.0, 0.80, 8.0, true)
			addDiningTableSet("EastBanquet_2", 80.0, 0.80, -6.0, true)
			addDiningTableSet("EastBanquet_3", 80.0, 0.80, -20.0, true)
		end
		-- Lv.8+: 2 Imperial Colonnade East Tables at X = +106 (+4 seats!)
		if tier >= 8 then
			addDiningTableSet("EastImperial_1", 106.0, 0.80, 4.0, true)
			addDiningTableSet("EastImperial_2", 106.0, 0.80, -14.0, true)
		end
		-- Lv.10+: Grand Palace Wing VIP Table at X = +124 (+2 seats!)
		if tier >= 10 then
			addDiningTableSet("EastPalace_VIP", 124.0, 0.80, -4.0, true)
		end
		-- Lv.11+: Outer Imperial Arcade VIP Tables at X = +138 (+4 seats!)
		if tier >= 11 then
			addDiningTableSet("EastOuterArcade_1", 138.0, 0.80, 6.0, true)
			addDiningTableSet("EastOuterArcade_2", 138.0, 0.80, -14.0, true)
		end
		-- Lv.15: Supreme Food Empire Royal Throne Banquet Table at X = +124, Z = +10
		if tier >= 15 then
			addDiningTableSet("EastSupremeThrone_VIP", 124.0, 0.80, 10.0, true)
		end

		-- Elevated warm brass pendant lamps (Y = 17.5 — well above head height!)
		local lampXList = { 54.0 }
		if tier >= 5 then table.insert(lampXList, 80.0) end
		if tier >= 8 then table.insert(lampXList, 106.0) end
		if tier >= 11 then table.insert(lampXList, 136.0) end
		for _, lx in ipairs(lampXList) do
			for _, lz in ipairs({ 6.0, -14.0 }) do
				mPart("EastWing_LampRod", Vector3.new(0.18, 3.2, 0.18), CFrame.new(lx, 19.2, lz), darkSteel, Enum.Material.Metal, false)
				local shade = mPart("EastWing_LampShade", Vector3.new(2.2, 1.0, 2.2), CFrame.new(lx, 17.4, lz), palette.BrassAccent, Enum.Material.Metal, false)
				addWarmLight(shade, 34, 1.2)
			end
		end

		-- Improved Kitchen Prep Island (positioned cleanly clear of VIP Curved Booth!) & Elevated Copper Pot Rack
		mPart("Lv2_PrepIslandBase", Vector3.new(7.4, 2.8, 3.2), CFrame.new(-30.5, 2.2, -21.0), darkSteel, Enum.Material.Metal, true)
		mPart("Lv2_PrepIslandTop", Vector3.new(7.8, 0.25, 3.6), CFrame.new(-30.5, 3.72, -21.0), brushedSteel, Enum.Material.Metal, true)
		mPart("Lv2_PotRackBar", Vector3.new(9.2, 0.25, 2.4), CFrame.new(-17.5, 16.4, -19.5), copper, Enum.Material.Metal, false)
		for _, px in ipairs({ -20.5, -17.5, -14.5 }) do
			mPart("Lv2_CopperPan", Vector3.new(0.55, 1.4, 1.4), CFrame.new(px, 15.6, -19.5) * CFrame.Angles(0, 0, math.rad(90)), copper, Enum.Material.Metal, false, nil, Enum.PartType.Cylinder)
		end
	end

	-- =========================================================================
	-- LEVEL 3+: WIDE-OPEN FLOOR 1 (21-STUD CEILING!) + REAR ATRIUM + SOLID 2ND FLOOR (Y=22.2) + WEST WING!
	-- =========================================================================
	if tier >= 3 then
		-- 3A. SOLID 1.4-STUD-THICK 2ND FLOOR DECK (Y = 20.8..22.2, top = 22.20 -> ZERO feet poking through ceiling!)
		mPart("Floor2_MainDeck", Vector3.new(74.4, 1.4, 48.2), CFrame.new(0.0, 21.5, -6.5), palette.FloorWood, Enum.Material.WoodPlanks, true)
		mPart("Floor2_ExtBeltF", Vector3.new(79.4, 1.4, 1.8), CFrame.new(0, 21.8, 18.6), marbleWhite, Enum.Material.Marble, false)
		mPart("Floor2_GoldBeltF", Vector3.new(80.0, 0.55, 2.2), CFrame.new(0, 22.7, 18.6), palette.BrassAccent, Enum.Material.Metal, false)

		-- Classical 2nd-Story Fluted Columns & 4 Warm Glowing Arched Windows across Front Facade (exact 2-story HQ icon match!)
		for _, cx2 in ipairs({ -36.5, -18.5, 0.0, 18.5, 36.5 }) do
			mPart("Floor2_ClassicCol", Vector3.new(19.6, 2.1, 2.1), CFrame.new(cx2, 32.4, 18.8) * CFrame.Angles(0, 0, math.rad(90)), marbleWhite, Enum.Material.Marble, false, nil, Enum.PartType.Cylinder)
			mPart("Floor2_ClassicCap", Vector3.new(2.8, 0.8, 2.8), CFrame.new(cx2, 42.1, 18.8), palette.BrassAccent, Enum.Material.Metal, false)
		end
		for _, wx2 in ipairs({ -27.5, -9.2, 9.2, 27.5 }) do
			addClassicalArchedWindow("Floor2_ArchWin_" .. tostring(math.floor(wx2)), wx2, 31.2, 18.9, 6.2, 7.6)
		end

		-- For Levels 3-6: Classical Marble Cornice Roof + Marquee + Grand Ribbed Golden-Teal Palace Dome!
		if tier <= 6 then
			mPart("Floor2_ClassicRoof", Vector3.new(80.6, 1.6, 52.6), CFrame.new(0, 42.9, -6.5), marbleWhite, Enum.Material.Marble, true)
			mPart("Floor2_RoofCornice", Vector3.new(82.4, 1.4, 54.4), CFrame.new(0, 44.1, -6.5), marbleWhite, Enum.Material.Marble, false)
			mPart("Floor2_RoofGoldTrim", Vector3.new(83.2, 0.65, 55.2), CFrame.new(0, 45.0, -6.5), palette.BrassAccent, Enum.Material.Metal, false)
			mPart("Floor2_SignBox", Vector3.new(38.0, 5.8, 2.2), CFrame.new(0, 47.4, 18.4), marbleWhite, Enum.Material.Marble, false)
			local sign2 = mPart("Floor2_SignMarquee", Vector3.new(36.2, 5.0, 0.3), CFrame.new(0, 47.4, 19.6), Color3.fromRGB(16, 18, 22), Enum.Material.SmoothPlastic, false)
			if sign2 then
				setArchMarqueeText(sign2, palette.BrandTitle, spec.Subtitle, palette.BrassAccent)
			end
			buildClassicalDome("Lv36_GrandPalaceDome", 0, 44.0, -6.5, if tier >= 5 then 16.5 else 15.0, 5.2, false)
		end

		-- Framed Rear Back Wall with a HUGE 28-stud-wide open Grand Archway (X = -14..+14) into the Rear Atrium!
		local backTopH = if tier >= 7 then 43.0 else 41.5
		for _, sx in ipairs({ -26.0, 26.0 }) do
			mPart("RearWallSide_Low", Vector3.new(23.5, 6.0, 1.8), CFrame.new(sx, 3.5, -30.5), stoneWainscot, Enum.Material.Brick, true)
			mPart("RearWallSide_Up", Vector3.new(23.5, backTopH - 6.0, 1.6), CFrame.new(sx, 6.5 + (backTopH - 6.0) * 0.5, -30.5), palette.WallPrimary, Enum.Material.SmoothPlastic, true)
		end
		mPart("RearArch_PillarL", Vector3.new(2.2, backTopH, 2.2), CFrame.new(-14.2, backTopH * 0.5 + 0.5, -30.5), palette.WallTrim, Enum.Material.Wood, true)
		mPart("RearArch_PillarR", Vector3.new(2.2, backTopH, 2.2), CFrame.new(14.2, backTopH * 0.5 + 0.5, -30.5), palette.WallTrim, Enum.Material.Wood, true)
		mPart("RearArch_Header1F", Vector3.new(28.4, 2.2, 2.0), CFrame.new(0, 20.4, -30.5), palette.WallTrim, Enum.Material.Wood, true)
		if tier >= 7 then
			mPart("RearArch_Header2F", Vector3.new(28.4, 2.2, 2.0), CFrame.new(0, 41.8, -30.5), palette.WallTrim, Enum.Material.Wood, true)
		end

		-- 3B. REAR GRAND STAIRCASE ATRIUM HALL (X = -26..+26, Z = -58..-30.5 -> keeps Ground Floor 100% uncrowded!)
		local atriumBackZ = if tier >= 7 then -58.5 else -49.5
		local atriumD = -30.5 - atriumBackZ
		local atriumCZ = (-30.5 + atriumBackZ) * 0.5
		local atriumTopY = if tier >= 9 then 62.5 elseif tier >= 7 then 59.5 else 42.5

		mPart("Atrium_Foundation", Vector3.new(53.0, 1.2, atriumD + 1.4), CFrame.new(0, 0.0, atriumCZ), stoneWainscot, Enum.Material.Concrete, true)
		mPart("Atrium_Floor1", Vector3.new(52.0, 0.4, atriumD), CFrame.new(0, 0.6, atriumCZ), palette.FloorWood, Enum.Material.WoodPlanks, true)
		mPart("Atrium_WallL", Vector3.new(1.6, atriumTopY, atriumD + 1.0), CFrame.new(-26.0, atriumTopY * 0.5 + 0.5, atriumCZ), palette.WallPrimary, Enum.Material.SmoothPlastic, true)
		mPart("Atrium_WallR", Vector3.new(1.6, atriumTopY, atriumD + 1.0), CFrame.new(26.0, atriumTopY * 0.5 + 0.5, atriumCZ), palette.WallPrimary, Enum.Material.SmoothPlastic, true)
		-- Split Rear Atrium Back Wall with wide 16-stud Co-op Rear Warehouse Archway (X = +4..+20, full 14-stud headroom!)
		mPart("Atrium_WallB_LowL", Vector3.new(30.4, 5.2, 1.6), CFrame.new(-11.2, 3.2, atriumBackZ), stoneWainscot, Enum.Material.Brick, true)
		mPart("Atrium_WallB_LowR", Vector3.new(6.4, 5.2, 1.6), CFrame.new(23.2, 3.2, atriumBackZ), stoneWainscot, Enum.Material.Brick, true)
		mPart("Atrium_WallB_GlassL", Vector3.new(28.0, atriumTopY - 7.0, 0.4), CFrame.new(-11.2, 5.8 + (atriumTopY - 7.0) * 0.5, atriumBackZ), glassCol, Enum.Material.Glass, true, 0.52)
		mPart("Atrium_WallB_GlassR", Vector3.new(5.2, atriumTopY - 7.0, 0.4), CFrame.new(23.2, 5.8 + (atriumTopY - 7.0) * 0.5, atriumBackZ), glassCol, Enum.Material.Glass, true, 0.52)
		mPart("Atrium_WallB_GlassTop", Vector3.new(16.0, math.max(8, atriumTopY - 17.5), 0.4), CFrame.new(12.0, 16.8 + math.max(8, atriumTopY - 17.5) * 0.5, atriumBackZ), glassCol, Enum.Material.Glass, true, 0.52)
		mPart("Atrium_RearDoor_PillarL", Vector3.new(1.8, 16.0, 2.2), CFrame.new(3.8, 8.6, atriumBackZ), palette.WallTrim, Enum.Material.Wood, true)
		mPart("Atrium_RearDoor_PillarR", Vector3.new(1.8, 16.0, 2.2), CFrame.new(20.2, 8.6, atriumBackZ), palette.WallTrim, Enum.Material.Wood, true)
		mPart("Atrium_RearDoor_Header", Vector3.new(18.2, 2.2, 2.2), CFrame.new(12.0, 15.8, atriumBackZ), palette.WallTrim, Enum.Material.Wood, true)
		mPart("Atrium_RearDoor_BrassTrim", Vector3.new(16.6, 0.45, 2.5), CFrame.new(12.0, 14.6, atriumBackZ), palette.BrassAccent, Enum.Material.Metal, false)
		mPart("Atrium_RearDoor_Threshold", Vector3.new(16.8, 0.22, 6.2), CFrame.new(12.0, 0.65, atriumBackZ - 1.4), marbleWhite, Enum.Material.Marble, false)
		mPart("Atrium_Roof", Vector3.new(54.6, 1.6, atriumD + 2.6), CFrame.new(0, atriumTopY + 1.2, atriumCZ), palette.RoofColor, Enum.Material.Slate, true)
		mPart("Atrium_RoofTrim", Vector3.new(55.2, 0.75, atriumD + 3.0), CFrame.new(0, atriumTopY + 2.2, atriumCZ), palette.BrassAccent, Enum.Material.Metal, false)

		-- Atrium 2nd-Floor Upper Landing Bridge (Y = 22.20 top!)
		mPart("Atrium_2FLandingR", Vector3.new(14.0, 1.4, atriumD), CFrame.new(19.0, 21.5, atriumCZ), palette.FloorWood, Enum.Material.WoodPlanks, true)
		mPart("Atrium_2FBridge", Vector3.new(28.0, 1.4, 6.2), CFrame.new(0.0, 21.5, -33.4), palette.FloorWood, Enum.Material.WoodPlanks, true)
		mPart("Atrium_2FRail", Vector3.new(25.5, 3.0, 0.4), CFrame.new(-0.5, 23.7, -36.4), palette.BrassAccent, Enum.Material.Metal, true)

		-- Smooth 1F -> 2F Grand Staircase (Z = -40.5, Width = 7.6, climbs X = -14.0 Y=0.80 -> X = +12.5 Y=22.20!)
		local s1Steps = 22
		local s1StartX, s1EndX = -14.0, 12.5
		local s1StartY, s1EndY = 0.80, 22.20
		local s1Z = -40.5
		local dx1 = (s1EndX - s1StartX) / s1Steps
		local dy1 = (s1EndY - s1StartY) / s1Steps
		for i = 1, s1Steps do
			local sx = s1StartX + (i - 0.5) * dx1
			local sy = s1StartY + (i - 0.5) * dy1
			mPart("Stair1F_Step_" .. tostring(i), Vector3.new(dx1 + 0.16, dy1 + 0.16, 7.4), CFrame.new(sx, sy, s1Z), palette.FloorWood, Enum.Material.WoodPlanks, false)
			mPart("Stair1F_Nose_" .. tostring(i), Vector3.new(0.18, 0.12, 7.46), CFrame.new(sx - dx1 * 0.48, sy + dy1 * 0.46, s1Z), palette.BrassAccent, Enum.Material.Metal, false)
		end
		local ramp1H = s1EndY - s1StartY
		local ramp1Len = s1EndX - s1StartX
		local ramp1CF = CFrame.new((s1StartX + s1EndX) * 0.5, s1StartY + ramp1H * 0.5, s1Z) * CFrame.Angles(0, math.rad(90), 0)
		if recordAndCheckBounds(ramp1CF, Vector3.new(7.4, ramp1H, ramp1Len)) then
			local w1 = Instance.new("WedgePart")
			w1.Name = "Stair1F_WalkRamp"
			w1.Size = Vector3.new(7.4, ramp1H, ramp1Len)
			w1.CFrame = hqCF * ramp1CF
			w1.Transparency = 1
			w1.Anchored = true
			w1.CanCollide = true
			w1.CanTouch = false
			w1.Parent = expFolder
			partCount += 1
		end
		local slope1Ang = math.atan2(ramp1H, ramp1Len)
		local slope1Diag = math.sqrt(ramp1H * ramp1H + ramp1Len * ramp1Len)
		for _, dz in ipairs({ -3.9, 3.9 }) do
			mPart("Stair1F_Rail", Vector3.new(slope1Diag, 0.34, 0.34), CFrame.new((s1StartX + s1EndX) * 0.5, (s1StartY + s1EndY) * 0.5 + 3.2, s1Z + dz) * CFrame.Angles(0, 0, slope1Ang), palette.BrassAccent, Enum.Material.Metal, false)
		end

		local atLight = mPart("Atrium_Light", Vector3.new(5.0, 0.6, 5.0), CFrame.new(0, atriumTopY - 0.4, atriumCZ), palette.BrassAccent, Enum.Material.Metal, false)
		addWarmLight(atLight, 56, 1.55)

		-- 3C. 2nd-Floor Dining Tables (Floor 2 top = 22.20!)
		addDiningTableSet("Floor2Table_RF", 24.0, 22.20, 8.0, tier >= 5)
		addDiningTableSet("Floor2Table_RM", 24.0, 22.20, -10.0, tier >= 5)
		addDiningTableSet("Floor2Table_LF", -24.0, 22.20, 8.0, tier >= 5)
		addDiningTableSet("Floor2Table_CF", 0.0, 22.20, 8.0, tier >= 5)

		for _, lx in ipairs({ -20.0, 0.0, 20.0 }) do
			for _, lz in ipairs({ 8.0, -12.0 }) do
				local f2Light = mPart("Floor2_Light", Vector3.new(2.0, 0.55, 2.0), CFrame.new(lx, 41.2, lz), palette.BrassAccent, Enum.Material.Metal, false)
				addWarmLight(f2Light, 38, 1.25)
			end
		end

		-- 3D. West Culinary Kitchen & Estate Dining Wing (wider at every level up to -150!)
		local westOuterX = if tier >= 11 then -150.0
			elseif tier >= 10 then -134.0
			elseif tier >= 8 then -118.0
			elseif tier >= 6 then -98.0
			elseif tier >= 4 then -70.0
			else -62.0
		local westFrontZ = if tier >= 4 then 18.0 else 12.0
		local westWallCol = if tier >= 8 then marbleWhite else stoneWainscot
		local westWallMat = if tier >= 8 then Enum.Material.Marble else Enum.Material.Brick

		mPart("WestArch_Header", Vector3.new(2.2, 2.6, 25.0), CFrame.new(-37.5, 19.6, -6.0), palette.WallTrim, Enum.Material.Wood, true)
		mPart("WestArch_PillarN", Vector3.new(2.2, 20.2, 1.8), CFrame.new(-37.5, 10.6, -18.0), palette.WallTrim, Enum.Material.Wood, true)
		mPart("WestArch_PillarS", Vector3.new(2.2, 20.2, 1.8), CFrame.new(-37.5, 10.6, 6.0), palette.WallTrim, Enum.Material.Wood, true)
		mPart("WestArch_BrickS", Vector3.new(1.8, 6.0, 12.0), CFrame.new(-37.5, 3.5, 12.0), stoneWainscot, Enum.Material.Brick, true)
		mPart("WestArch_BrickN", Vector3.new(1.8, 6.0, 12.5), CFrame.new(-37.5, 3.5, -24.2), stoneWainscot, Enum.Material.Brick, true)

		buildWingShell("WestWing", -37.5, westOuterX, -26.0, westFrontZ, Color3.fromRGB(64, 68, 74), Enum.Material.Slate, westWallCol, westWallMat)

		-- Commercial Kitchen Fixtures tucked cleanly in the inner West Kitchen zone
		mPart("WestKitchen_HearthBase", Vector3.new(6.4, 7.6, 7.4), CFrame.new(-54.0, 4.6, -18.5), Color3.fromRGB(132, 62, 46), Enum.Material.Brick, true)
		mPart("WestKitchen_HearthChimney", Vector3.new(3.2, 13.0, 3.2), CFrame.new(-54.0, 14.5, -18.5), Color3.fromRGB(118, 56, 42), Enum.Material.Brick, false)
		local emberBox = mPart("WestKitchen_HearthFire", Vector3.new(2.2, 2.0, 3.2), CFrame.new(-51.6, 4.4, -18.5), Color3.fromRGB(238, 114, 42), Enum.Material.SmoothPlastic, false)
		addWarmLight(emberBox, 26, 1.4, Color3.fromRGB(255, 162, 74))
		mPart("WestKitchen_ColdVault", Vector3.new(8.2, 8.4, 1.2), CFrame.new(-45.5, 5.0, -24.4), brushedSteel, Enum.Material.Metal, true)
		mPart("WestKitchen_PrepCounter", Vector3.new(10.0, 3.0, 3.8), CFrame.new(-48.0, 2.3, -4.0), darkSteel, Enum.Material.Metal, true)
		mPart("WestKitchen_PrepTop", Vector3.new(10.4, 0.28, 4.2), CFrame.new(-48.0, 3.92, -4.0), brushedSteel, Enum.Material.Metal, true)

		-- Lv.6+: Grand West Estate Dining Pavilion Tables (X = -84 -> +6 seats!)
		if tier >= 6 then
			mPart("WestDining_WoodFloor", Vector3.new(math.abs(westOuterX) - 64.0, 0.42, 43.2), CFrame.new((-64.0 + westOuterX) * 0.5, 0.62, -4.0), palette.FloorWood, Enum.Material.WoodPlanks, true)
			addDiningTableSet("WestEstate_1", -84.0, 0.80, 8.0, true)
			addDiningTableSet("WestEstate_2", -84.0, 0.80, -6.0, true)
			addDiningTableSet("WestEstate_3", -84.0, 0.80, -20.0, true)
		end
		-- Lv.8+: Imperial West Colonnade Table at X = -106 (+2 seats!)
		if tier >= 8 then
			addDiningTableSet("WestImperial_1", -106.0, 0.80, -4.0, true)
		end
		-- Lv.10+: Grand Palace West Wing VIP Table at X = -124 (+2 seats!)
		if tier >= 10 then
			addDiningTableSet("WestPalace_VIP", -124.0, 0.80, -4.0, true)
		end
		-- Lv.11+: Outer Imperial West Arcade VIP Tables at X = -138 (+4 seats!)
		if tier >= 11 then
			addDiningTableSet("WestOuterArcade_1", -138.0, 0.80, 6.0, true)
			addDiningTableSet("WestOuterArcade_2", -138.0, 0.80, -14.0, true)
		end
		-- Lv.15: Supreme Food Empire West Royal Throne Banquet Table at X = -124, Z = +10
		if tier >= 15 then
			addDiningTableSet("WestSupremeThrone_VIP", -124.0, 0.80, 10.0, true)
		end
	end

	-- =========================================================================
	-- LEVEL 4+: SOARING CANTILEVERED GLASS PORTICO (Y=20.6!), FACADE FINS, WINE WALL & 2F LOUNGES
	-- =========================================================================
	if tier >= 4 then
		mPart("Lv4_PorticoRoof", Vector3.new(34.0, 1.2, 13.4), CFrame.new(0, 20.6, 24.4), darkSteel, Enum.Material.Metal, false)
		mPart("Lv4_PorticoTrim", Vector3.new(34.6, 0.4, 13.8), CFrame.new(0, 21.4, 24.4), palette.BrassAccent, Enum.Material.Metal, false)
		mPart("Lv4_PorticoGlass", Vector3.new(28.0, 0.25, 10.6), CFrame.new(0, 19.9, 24.4), glassCol, Enum.Material.Glass, false, 0.55)
		local pLamp = mPart("Lv4_PorticoSoffit", Vector3.new(12.0, 0.25, 4.4), CFrame.new(0, 19.8, 24.0), Color3.fromRGB(246, 230, 186), Enum.Material.SmoothPlastic, false)
		addWarmLight(pLamp, 38, 1.4)
		for _, px in ipairs({ -15.2, 15.2 }) do
			mPart("Lv4_PorticoCol", Vector3.new(1.7, 19.8, 1.7), CFrame.new(px, 10.4, 29.8), darkSteel, Enum.Material.Metal, true)
			mPart("Lv4_PorticoPlinth", Vector3.new(2.4, 1.4, 2.4), CFrame.new(px, 1.3, 29.8), marbleWhite, Enum.Material.Marble, false)
		end
		for _, fx in ipairs({ -66, -54, -42, 42, 54, 66 }) do
			mPart("Lv4_FacadeFin", Vector3.new(0.7, 20.4, 1.2), CFrame.new(fx, 10.9, 18.9), darkSteel, Enum.Material.Metal, false)
		end

		-- Additional 2nd-Floor Lounge Tables (Floor 2 = 22.20!)
		addDiningTableSet("Floor2Modern_LM", -24.0, 22.20, -10.0, tier >= 5)
		addDiningTableSet("Floor2Modern_RB", 24.0, 22.20, -23.0, tier >= 5)
		addDiningTableSet("Floor2Modern_LB", -24.0, 22.20, -23.0, tier >= 5)

		-- Modern Illuminated Glass Wine Cellar Feature on 2F Front Center Wall
		mPart("Lv4_WineCabinet", Vector3.new(14.0, 11.2, 1.6), CFrame.new(0.0, 27.8, 16.8), darkSteel, Enum.Material.Wood, true)
		mPart("Lv4_WineGlass", Vector3.new(12.8, 9.8, 0.2), CFrame.new(0.0, 27.8, 15.9), glassCol, Enum.Material.Glass, false, 0.55)
		for row = 1, 4 do
			mPart("Lv4_WineShelf_" .. tostring(row), Vector3.new(12.4, 0.22, 1.2), CFrame.new(0.0, 23.2 + row * 2.1, 16.5), palette.BrassAccent, Enum.Material.Metal, false)
		end
	end

	-- =========================================================================
	-- LEVEL 5+: WIDE UNOBSTRUCTED VIP VELVET CARPET, STANCHIONS & COURTYARD FOUNTAINS
	-- =========================================================================
	if tier >= 5 then
		mPart("Lv5_RedCarpet", Vector3.new(12.4, 0.14, 16.0), CFrame.new(0, 0.66, 26.8), velvetRed, Enum.Material.Fabric, false)
		mPart("Lv5_CarpetEdgeL", Vector3.new(0.45, 0.16, 16.0), CFrame.new(-6.2, 0.67, 26.8), palette.BrassAccent, Enum.Material.Metal, false)
		mPart("Lv5_CarpetEdgeR", Vector3.new(0.45, 0.16, 16.0), CFrame.new(6.2, 0.67, 26.8), palette.BrassAccent, Enum.Material.Metal, false)
		for _, sx in ipairs({ -7.4, 7.4 }) do
			for _, sz in ipairs({ 22.0, 27.5, 33.0 }) do
				mPart("Lv5_Stanchion", Vector3.new(0.42, 3.2, 0.42), CFrame.new(sx, 2.2, sz), palette.BrassAccent, Enum.Material.Metal, false)
				mPart("Lv5_StanchionBall", Vector3.new(0.75, 0.75, 0.75), CFrame.new(sx, 3.9, sz), palette.BrassAccent, Enum.Material.Metal, false, nil, Enum.PartType.Ball)
			end
		end
		for _, fx in ipairs({ -46.0, 46.0 }) do
			mPart("Lv5_FountainBasin", Vector3.new(1.8, 8.2, 8.2), CFrame.new(fx, 1.4, 25.0) * CFrame.Angles(0, 0, math.rad(90)), marbleWhite, Enum.Material.Marble, true, nil, Enum.PartType.Cylinder)
			mPart("Lv5_FountainWater", Vector3.new(0.5, 7.0, 7.0), CFrame.new(fx, 2.1, 25.0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(76, 178, 214), Enum.Material.Glass, false, 0.32, Enum.PartType.Cylinder)
			mPart("Lv5_FountainSpire", Vector3.new(4.2, 1.4, 1.4), CFrame.new(fx, 4.0, 25.0) * CFrame.Angles(0, 0, math.rad(90)), palette.BrassAccent, Enum.Material.Metal, false, nil, Enum.PartType.Cylinder)
		end
	end

	-- =========================================================================
	-- LEVEL 6+: EXECUTIVE COPPER RANGE HOOD & ELEVATED WING ROOFTOP BALUSTRADES
	-- =========================================================================
	if tier >= 6 then
		mPart("Lv6_ExecutiveCopperHood", Vector3.new(12.4, 2.4, 6.4), CFrame.new(-18.0, 15.6, -20.5), copper, Enum.Material.Metal, false)
		mPart("Lv6_ExecutiveHoodTrim", Vector3.new(12.8, 0.35, 6.8), CFrame.new(-18.0, 14.4, -20.5), palette.BrassAccent, Enum.Material.Metal, false)
		for _, wx in ipairs({ -68.0, 68.0 }) do
			mPart("Lv6_WingParapetGlassF", Vector3.new(58.0, 2.8, 0.3), CFrame.new(wx, 25.2, 18.2), glassCol, Enum.Material.Glass, false, 0.45)
			mPart("Lv6_WingParapetCapF", Vector3.new(58.6, 0.3, 0.55), CFrame.new(wx, 26.7, 18.2), palette.BrassAccent, Enum.Material.Metal, false)
		end
	end

	-- =========================================================================
	-- LEVEL 7+: WALKABLE 3RD FLOOR SKY-TERRACE (Y=43.60!) + 2F->3F UPPER GRAND STAIRCASE!
	-- =========================================================================
	if tier >= 7 then
		-- Solid 1.4-stud-thick 3rd-Floor Deck (Y = 42.2..43.6, top = 43.60!)
		mPart("Floor3_MainDeck", Vector3.new(78.4, 1.4, 51.6), CFrame.new(0.0, 42.9, -6.5), marbleWhite, Enum.Material.Marble, true)
		mPart("Floor3_GoldCorniceF", Vector3.new(79.4, 0.85, 1.2), CFrame.new(0.0, 43.1, 19.2), palette.BrassAccent, Enum.Material.Metal, false)

		mPart("Atrium_3FLandingL", Vector3.new(14.0, 1.4, 27.6), CFrame.new(-19.0, 42.9, -44.5), marbleWhite, Enum.Material.Marble, true)
		mPart("Atrium_3FBridge", Vector3.new(28.0, 1.4, 6.2), CFrame.new(0.0, 42.9, -33.4), marbleWhite, Enum.Material.Marble, true)
		mPart("Atrium_3FRail", Vector3.new(25.5, 3.0, 0.4), CFrame.new(0.5, 45.1, -36.4), palette.BrassAccent, Enum.Material.Metal, true)

		-- Smooth 2F -> 3F Upper Grand Staircase (Z = -50.5, Width = 7.6, climbs X = +12.5 Y=22.20 -> X = -14.0 Y=43.60!)
		local s2Steps = 22
		local s2StartX, s2EndX = 12.5, -14.0
		local s2StartY, s2EndY = 22.20, 43.60
		local s2Z = -50.5
		local dx2 = (s2EndX - s2StartX) / s2Steps
		local dy2 = (s2EndY - s2StartY) / s2Steps
		for i = 1, s2Steps do
			local sx = s2StartX + (i - 0.5) * dx2
			local sy = s2StartY + (i - 0.5) * dy2
			mPart("Stair2F_Step_" .. tostring(i), Vector3.new(math.abs(dx2) + 0.16, dy2 + 0.16, 7.4), CFrame.new(sx, sy, s2Z), marbleWhite, Enum.Material.Marble, false)
			mPart("Stair2F_Nose_" .. tostring(i), Vector3.new(0.18, 0.12, 7.46), CFrame.new(sx - dx2 * 0.48, sy + dy2 * 0.46, s2Z), palette.BrassAccent, Enum.Material.Metal, false)
		end
		local ramp2H = s2EndY - s2StartY
		local ramp2Len = math.abs(s2EndX - s2StartX)
		local ramp2CF = CFrame.new((s2StartX + s2EndX) * 0.5, s2StartY + ramp2H * 0.5, s2Z) * CFrame.Angles(0, math.rad(-90), 0)
		if recordAndCheckBounds(ramp2CF, Vector3.new(7.4, ramp2H, ramp2Len)) then
			local w2 = Instance.new("WedgePart")
			w2.Name = "Stair2F_WalkRamp"
			w2.Size = Vector3.new(7.4, ramp2H, ramp2Len)
			w2.CFrame = hqCF * ramp2CF
			w2.Transparency = 1
			w2.Anchored = true
			w2.CanCollide = true
			w2.CanTouch = false
			w2.Parent = expFolder
			partCount += 1
		end
		local slope2Ang = math.atan2(ramp2H, ramp2Len)
		local slope2Diag = math.sqrt(ramp2H * ramp2H + ramp2Len * ramp2Len)
		for _, dz in ipairs({ -3.9, 3.9 }) do
			mPart("Stair2F_Rail", Vector3.new(slope2Diag, 0.34, 0.34), CFrame.new((s2StartX + s2EndX) * 0.5, (s2StartY + s2EndY) * 0.5 + 3.2, s2Z + dz) * CFrame.Angles(0, 0, -slope2Ang), palette.BrassAccent, Enum.Material.Metal, false)
		end

		if tier < 9 then
			mPart("Floor3_RailF", Vector3.new(78.0, 3.4, 0.4), CFrame.new(0, 45.3, 18.8), glassCol, Enum.Material.Glass, true, 0.42)
			mPart("Floor3_CapF", Vector3.new(78.6, 0.35, 0.65), CFrame.new(0, 47.1, 18.8), palette.BrassAccent, Enum.Material.Metal, false)
			mPart("Floor3_RailL", Vector3.new(0.4, 3.4, 51.0), CFrame.new(-38.8, 45.3, -6.5), glassCol, Enum.Material.Glass, true, 0.42)
			mPart("Floor3_RailR", Vector3.new(0.4, 3.4, 51.0), CFrame.new(38.8, 45.3, -6.5), glassCol, Enum.Material.Glass, true, 0.42)
			for _, cx in ipairs({ -34.0, 0.0, 34.0 }) do
				for _, cz in ipairs({ -22.0, 14.0 }) do
					mPart("Floor3_Col", Vector3.new(2.0, 15.5, 2.0), CFrame.new(cx, 51.3, cz), marbleWhite, Enum.Material.Marble, true)
				end
			end
			mPart("Floor3_SkyRoof", Vector3.new(78.0, 1.6, 44.0), CFrame.new(0, 59.6, -4.0), marbleWhite, Enum.Material.Marble, true)
			mPart("Floor3_SkyRoofTrim", Vector3.new(79.4, 0.85, 45.4), CFrame.new(0, 60.6, -4.0), palette.BrassAccent, Enum.Material.Metal, false)
			local sign3 = mPart("Floor3_Marquee", Vector3.new(38.0, 6.4, 0.5), CFrame.new(0, 64.4, 17.5), Color3.fromRGB(16, 18, 22), Enum.Material.SmoothPlastic, false)
			if sign3 then
				setArchMarqueeText(sign3, palette.BrandTitle, spec.Subtitle, palette.BrassAccent)
			end
			buildClassicalDome("Lv78_SkyPalaceDome", 0, 60.6, -6.5, 17.8, 5.6, false)
		end

		addDiningTableSet("Floor3Sky_R", 24.0, 43.60, 8.0, true)
		addDiningTableSet("Floor3Sky_L", -24.0, 43.60, 8.0, true)
		addDiningTableSet("Floor3Sky_C", 0.0, 43.60, 8.0, true)
	end

	-- =========================================================================
	-- LEVEL 8+: TALL IMPERIAL MARBLE COLONNADE WING PAVILIONS & 2-STORY CRYSTAL CHANDELIER!
	-- =========================================================================
	if tier >= 8 then
		local colX = if tier >= 11 then 151.0 elseif tier >= 10 then 135.0 else 119.0
		for _, side in ipairs({ -1, 1 }) do
			for _, pz in ipairs({ -22.0, -4.0, 14.0 }) do
				mPart("Lv8_FlutedCol", Vector3.new(22.6, 2.4, 2.4), CFrame.new(side * colX, 11.9, pz) * CFrame.Angles(0, 0, math.rad(90)), marbleWhite, Enum.Material.Marble, false, nil, Enum.PartType.Cylinder)
				mPart("Lv8_ColCap", Vector3.new(3.0, 1.0, 3.0), CFrame.new(side * colX, 23.4, pz), palette.BrassAccent, Enum.Material.Metal, false)
			end
		end
		local chY = if tier >= 9 then 54.0 else 51.0
		mPart("Lv8_ChandChain", Vector3.new(0.35, 7.0, 0.35), CFrame.new(0.0, chY + 3.6, -41.0), palette.BrassAccent, Enum.Material.Metal, false)
		mPart("Lv8_ChandRing1", Vector3.new(0.5, 9.0, 9.0), CFrame.new(0.0, chY, -41.0) * CFrame.Angles(0, 0, math.rad(90)), palette.BrassAccent, Enum.Material.Metal, false, nil, Enum.PartType.Cylinder)
		mPart("Lv8_ChandRing2", Vector3.new(0.5, 5.8, 5.8), CFrame.new(0.0, chY - 2.0, -41.0) * CFrame.Angles(0, 0, math.rad(90)), palette.BrassAccent, Enum.Material.Metal, false, nil, Enum.PartType.Cylinder)
		local crystal = mPart("Lv8_ChandCore", Vector3.new(2.6, 3.0, 2.6), CFrame.new(0.0, chY - 0.9, -41.0), Color3.fromRGB(244, 240, 224), Enum.Material.Glass, false, 0.2, Enum.PartType.Ball)
		addWarmLight(crystal, 66, 2.0, Color3.fromRGB(255, 226, 162))
	end

	-- =========================================================================
	-- LEVEL 9+: FULL ENCLOSED 3RD-FLOOR ROYAL GRAND BALLROOM (Y = 43.6..61.8!)
	-- =========================================================================
	if tier >= 9 then
		mPart("Ballroom_WallF_Low", Vector3.new(78.4, 4.4, 1.4), CFrame.new(0, 45.8, 18.8), marbleWhite, Enum.Material.Marble, true)
		mPart("Ballroom_WallF_Glass", Vector3.new(72.0, 11.4, 0.4), CFrame.new(0, 53.7, 18.8), glassCol, Enum.Material.Glass, true, 0.45)
		mPart("Ballroom_WallF_Top", Vector3.new(78.4, 2.4, 1.4), CFrame.new(0, 60.6, 18.8), marbleWhite, Enum.Material.Marble, true)
		for _, sx in ipairs({ -38.8, 38.8 }) do
			mPart("Ballroom_SideLow", Vector3.new(1.4, 4.4, 51.6), CFrame.new(sx, 45.8, -6.5), marbleWhite, Enum.Material.Marble, true)
			mPart("Ballroom_SideGlass", Vector3.new(0.4, 11.4, 46.0), CFrame.new(sx, 53.7, -6.5), glassCol, Enum.Material.Glass, true, 0.45)
			mPart("Ballroom_SideTop", Vector3.new(1.4, 2.4, 51.6), CFrame.new(sx, 60.6, -6.5), marbleWhite, Enum.Material.Marble, true)
		end
		mPart("Ballroom_Ceiling", Vector3.new(80.6, 1.6, 53.6), CFrame.new(0, 62.2, -6.5), marbleWhite, Enum.Material.Marble, true)
		mPart("Ballroom_MansardBase", Vector3.new(82.4, 6.0, 55.4), CFrame.new(0, 66.0, -6.5), palette.RoofColor, Enum.Material.Slate, true)
		mPart("Ballroom_MansardGold", Vector3.new(83.2, 1.1, 56.2), CFrame.new(0, 69.4, -6.5), palette.BrassAccent, Enum.Material.Metal, false)
		mPart("Ballroom_UpperDeck", Vector3.new(66.0, 2.2, 38.0), CFrame.new(0, 71.0, -6.5), palette.RoofColor, Enum.Material.Slate, false)

		local sign9 = mPart("Ballroom_Marquee", Vector3.new(44.0, 7.6, 0.6), CFrame.new(0, 66.8, 21.8), Color3.fromRGB(16, 18, 22), Enum.Material.SmoothPlastic, false)
		if sign9 then
			setArchMarqueeText(sign9, palette.BrandTitle, spec.Subtitle, palette.BrassAccent)
		end

		local bChand = mPart("Ballroom_Chand", Vector3.new(0.6, 10.2, 10.2), CFrame.new(0, 58.6, -6.5) * CFrame.Angles(0, 0, math.rad(90)), palette.BrassAccent, Enum.Material.Metal, false, nil, Enum.PartType.Cylinder)
		addWarmLight(bChand, 66, 2.0, Color3.fromRGB(255, 228, 168))

		addDiningTableSet("BallroomVIP_R", 24.0, 43.60, -14.0, true)
		addDiningTableSet("BallroomVIP_L", -24.0, 43.60, -14.0, true)
		addDiningTableSet("BallroomVIP_C", 0.0, 43.60, -14.0, true)
		if tier == 9 then
			buildClassicalDome("Lv9_RoyalBallroomDome", 0, 71.8, -6.5, 19.5, 6.0, false)
		end
	end

	-- =========================================================================
	-- LEVEL 10+: FOOD EMPEROR IMPERIAL PALACE — SOARING RIBBED GOLDEN-TEAL CLASSICAL DOME!
	-- =========================================================================
	if tier >= 10 then
		buildClassicalDome("Lv10_ImperialPalaceDome", 0, 71.8, -6.5, 22.0, 6.8, tier >= 15)
		addDiningTableSet("EmperorPenthouse_VIP", 0.0, 43.60, -28.0, true)
	end

	-- =========================================================================
	-- LEVEL 11+: OUTER IMPERIAL COLONNADE ARCADES & ROOFTOP BALUSTRADE GALLERY
	-- =========================================================================
	if tier >= 11 then
		for _, side in ipairs({ -1, 1 }) do
			mPart("Lv11_OuterParapetF", Vector3.new(110.0, 2.8, 0.5), CFrame.new(side * 94.0, 25.4, 18.8), marbleWhite, Enum.Material.Marble, false)
			mPart("Lv11_OuterGoldCapF", Vector3.new(111.0, 0.45, 0.9), CFrame.new(side * 94.0, 27.0, 18.8), palette.BrassAccent, Enum.Material.Metal, false)
			for _, pz in ipairs({ -16.0, 0.0, 16.0 }) do
				local archGlow = mPart("Lv11_ArcadeSconce", Vector3.new(1.1, 2.4, 1.1), CFrame.new(side * 149.2, 13.5, pz), Color3.fromRGB(255, 224, 150), Enum.Material.Glass, false, 0.15)
				addWarmLight(archGlow, 28, 1.2)
			end
		end
	end

	-- =========================================================================
	-- LEVEL 12+: TWIN WING ROOFTOP SKY-TOWER PAVILIONS (EAST & WEST CUPOLAS!)
	-- =========================================================================
	if tier >= 12 then
		for _, side in ipairs({ -1, 1 }) do
			local tx = side * 86.0
			local tz = -4.0
			mPart("Lv12_SkyTowerPlinth", Vector3.new(26.0, 3.0, 22.0), CFrame.new(tx, 25.0, tz), marbleWhite, Enum.Material.Marble, false)
			mPart("Lv12_SkyTowerGoldBelt", Vector3.new(27.0, 0.8, 23.0), CFrame.new(tx, 26.9, tz), palette.BrassAccent, Enum.Material.Metal, false)
			mPart("Lv12_SkyTowerGlass", Vector3.new(21.0, 12.6, 17.0), CFrame.new(tx, 33.6, tz), glassCol, Enum.Material.Glass, false, 0.35)
			for _, cx in ipairs({ -10.5, 10.5 }) do
				for _, cz in ipairs({ -8.5, 8.5 }) do
					mPart("Lv12_SkyTowerCol", Vector3.new(1.8, 13.2, 1.8), CFrame.new(tx + cx, 33.6, tz + cz), marbleWhite, Enum.Material.Marble, false)
				end
			end
			mPart("Lv12_SkyTowerRoof", Vector3.new(25.4, 2.2, 21.4), CFrame.new(tx, 41.2, tz), marbleWhite, Enum.Material.Marble, false)
			buildClassicalDome("Lv12_WingDome_" .. (if side < 0 then "W" else "E"), tx, 42.2, tz, 8.6, 3.0, tier >= 15)
		end
	end

	-- =========================================================================
	-- LEVEL 13+: GILDED SYNDICATE PALAZZO FACADE & 3F VIP ALCOVES
	-- =========================================================================
	if tier >= 13 then
		for _, gx in ipairs({ -122, -96, -70, -34, 34, 70, 96, 122 }) do
			mPart("Lv13_GoldPilaster", Vector3.new(1.1, 20.6, 1.1), CFrame.new(gx, 11.0, 19.0), palette.BrassAccent, Enum.Material.Metal, false)
		end
		mPart("Lv13_PorticoCrestArch", Vector3.new(35.0, 2.2, 1.4), CFrame.new(0, 22.8, 30.2), palette.BrassAccent, Enum.Material.Metal, false)
		addDiningTableSet("Palazzo3F_VIP_R", 24.0, 43.60, -28.0, true)
		addDiningTableSet("Palazzo3F_VIP_L", -24.0, 43.60, -28.0, true)
	end

	-- =========================================================================
	-- LEVEL 14+: FOUR-SPIRE CULINARY CITADEL — SOARING CORNER IMPERIAL TOWERS!
	-- =========================================================================
	if tier >= 14 then
		for _, sx in ipairs({ -38.0, 38.0 }) do
			for _, sz in ipairs({ -30.0, 17.5 }) do
				mPart("Lv14_CornerTowerBase", Vector3.new(8.4, 18.0, 8.4), CFrame.new(sx, 78.5, sz), marbleWhite, Enum.Material.Marble, false)
				mPart("Lv14_CornerTowerBand", Vector3.new(9.2, 1.2, 9.2), CFrame.new(sx, 88.0, sz), palette.BrassAccent, Enum.Material.Metal, false)
				mPart("Lv14_CornerTowerLantern", Vector3.new(6.2, 9.0, 6.2), CFrame.new(sx, 93.1, sz), glassCol, Enum.Material.Glass, false, 0.3)
				mPart("Lv14_CornerTowerCap", Vector3.new(7.6, 2.2, 7.6), CFrame.new(sx, 98.7, sz), darkSteel, Enum.Material.Metal, false)
				local cSpire = mPart("Lv14_CornerSpire", Vector3.new(11.0, 2.8, 2.8), CFrame.new(sx, 105.2, sz) * CFrame.Angles(0, 0, math.rad(90)), palette.BrassAccent, Enum.Material.Metal, false, nil, Enum.PartType.Cylinder)
				addWarmLight(cSpire, 48, 1.5, Color3.fromRGB(255, 218, 134))
			end
		end
	end

	-- =========================================================================
	-- LEVEL 15 (MAX): SUPREME FOOD EMPIRE CITADEL — GOLDEN IMPERIAL CROWN BEACON!
	-- =========================================================================
	if tier >= 15 then
		local goldBright = Color3.fromRGB(246, 198, 68)
		local crownBeacon = mPart("Lv15_SupremeStarOrb", Vector3.new(5.6, 5.6, 5.6), CFrame.new(0, 124.5, -6.5), Color3.fromRGB(255, 232, 162), Enum.Material.Neon, false, 0.08, Enum.PartType.Ball)
		addWarmLight(crownBeacon, 115, 2.8, Color3.fromRGB(255, 224, 140))
		mPart("Lv15_SupremeHaloRing", Vector3.new(1.1, 14.5, 14.5), CFrame.new(0, 121.0, -6.5) * CFrame.Angles(0, 0, math.rad(90)), goldBright, Enum.Material.Neon, false, 0.2, Enum.PartType.Cylinder)

		local sign15 = mPart("Lv15_SupremeCrestMarquee", Vector3.new(52.0, 8.4, 0.7), CFrame.new(0, 75.5, 20.6), Color3.fromRGB(16, 18, 22), Enum.Material.SmoothPlastic, false)
		if sign15 then
			setArchMarqueeText(sign15, "★ " .. palette.BrandTitle .. " ★", "LV.15 MAX • STRONGEST FOOD EMPIRE IN THE CITY", goldBright)
		end

		for _, tx in ipairs({ -22.5, 22.5 }) do
			mPart("Lv15_TriumphColumn", Vector3.new(21.6, 2.6, 2.6), CFrame.new(tx, 11.4, 30.0) * CFrame.Angles(0, 0, math.rad(90)), goldBright, Enum.Material.Metal, true, nil, Enum.PartType.Cylinder)
			mPart("Lv15_TriumphOrb", Vector3.new(3.2, 3.2, 3.2), CFrame.new(tx, 23.4, 30.0), Color3.fromRGB(255, 230, 158), Enum.Material.Neon, false, nil, Enum.PartType.Ball)
		end
	end

	local bp = baseModel:FindFirstChild("BasePivot")
	if bp and bp:IsA("BasePart") then
		expFolder:SetAttribute("BaseWidth", 336)
		expFolder:SetAttribute("BaseDepth", 288)
	end

	expFolder.Parent = hq

	local actualW = math.floor((maxX - minX) * 10 + 0.5) / 10
	local actualH = math.floor((maxY - minY) * 10 + 0.5) / 10
	local actualD = math.floor((maxZ - minZ) * 10 + 0.5) / 10
	hq:SetAttribute("PhysicalTier", tier)
	hq:SetAttribute("PhysicalWidth", actualW)
	hq:SetAttribute("PhysicalHeight", actualH)
	hq:SetAttribute("PhysicalDepth", actualD)

	return {
		Tier = tier,
		PartCount = partCount,
		BoundsViolations = boundsViolations,
		Width = actualW,
		Height = actualH,
		Depth = actualD,
	}
end

-- =========================================================================
-- FRONT WOOD RESTAURANT WITH ROOF (FrontDiningPlaza — Levels 1 to 15!)
-- Progressively upgrades & widens the covered wooden outdoor dining restaurant
-- in front of RestaurantHQ so a higher-level restaurant looks bigger & seats more customers!
-- =========================================================================
function RestaurantExpansionBuilder.BuildFrontWoodPavilion(baseModel: Model, slot: string, restaurantLevel: number): ()
	local bp = baseModel:FindFirstChild("BasePivot")
	local plaza = baseModel:FindFirstChild("FrontDiningPlaza")
	if not bp or not bp:IsA("BasePart") or not plaza then
		return
	end

	local tier = math.clamp(math.floor(restaurantLevel or 1), 1, RestaurantExpansionConfig.MAX_PHYSICAL_TIER)
	local palette = SLOT_PALETTES[slot] or SLOT_PALETTES.East
	local bCF = bp.CFrame

	local oldRoofs = plaza:FindFirstChild("PergolaPavilionRoofs")
	if oldRoofs then
		oldRoofs:Destroy()
	end
	local roofFolder = Instance.new("Folder")
	roofFolder.Name = "PergolaPavilionRoofs"
	roofFolder:SetAttribute("PavilionLevel", tier)

	local cedarWood = Color3.fromRGB(134, 86, 48)
	local richTimber = palette.WallTrim
	local deckWood = Color3.fromRGB(118, 78, 46)
	local soffitWood = Color3.fromRGB(148, 102, 62)
	local roofShingle = if tier >= 15 then Color3.fromRGB(184, 134, 42) else Color3.fromRGB(58, 42, 32)
	local slateRoof = palette.RoofColor
	local brassCol = if tier >= 13 then Color3.fromRGB(238, 192, 72) else palette.BrassAccent
	local skylightCol = Color3.fromRGB(186, 214, 236)
	local lanternGlow = Color3.fromRGB(255, 224, 156)
	local darkIron = Color3.fromRGB(34, 38, 44)
	local hedgeGreen = Color3.fromRGB(48, 96, 52)

	local function rPart(
		prefix: string,
		name: string,
		sz: Vector3,
		relCF: CFrame,
		col: Color3,
		mat: Enum.Material,
		transp: number?,
		collide: boolean?,
		shape: Enum.PartType?
	): Part
		local part = Instance.new("Part")
		part.Name = prefix .. name
		part.Size = sz
		part.CFrame = bCF * relCF
		part.Color = col
		part.Material = mat
		if shape then
			part.Shape = shape
		end
		part.Anchored = true
		part.CanCollide = if collide == nil then true else collide
		part.CanTouch = false
		part.CanQuery = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if transp then
			part.Transparency = transp
		end
		part.Parent = roofFolder
		return part
	end

	local function addGlow(parent: BasePart, range: number, brightness: number): ()
		local pl = Instance.new("PointLight")
		pl.Color = lanternGlow
		pl.Range = range
		pl.Brightness = brightness
		pl.Shadows = false
		pl.Parent = parent
	end

	local function buildWoodDiningTable(tag: string, tx: number, tz: number, isVIP: boolean): ()
		local topCol = if isVIP then Color3.fromRGB(162, 110, 62) else cedarWood
		local seatCol = if isVIP then Color3.fromRGB(132, 34, 40) else palette.SeatLeather
		rPart(tag, "Pedestal", Vector3.new(1.1, 2.5, 1.1), CFrame.new(tx, 1.65, tz), darkIron, Enum.Material.Metal, nil, true)
		rPart(tag, "Foot", Vector3.new(2.2, 0.22, 2.2), CFrame.new(tx, 0.50, tz), brassCol, Enum.Material.Metal, nil, false)
		rPart(tag, "WoodTop", Vector3.new(4.8, 0.36, 4.0), CFrame.new(tx, 3.06, tz), topCol, Enum.Material.Wood, nil, true)
		if isVIP then
			rPart(tag, "BrassRim", Vector3.new(5.0, 0.16, 4.2), CFrame.new(tx, 3.06, tz), brassCol, Enum.Material.Metal, nil, false)
			local candle = rPart(tag, "TableLantern", Vector3.new(0.45, 0.75, 0.45), CFrame.new(tx, 3.60, tz), lanternGlow, Enum.Material.Neon, 0.1, false)
			addGlow(candle, 12, 0.7)
		end
		for _, dz in ipairs({ -3.1, 3.1 }) do
			local faceIn = if dz > 0 then math.rad(180) else 0
			local sCF = CFrame.new(tx, 0.40, tz + dz) * CFrame.Angles(0, faceIn, 0)
			rPart(tag, "ChairBase", Vector3.new(2.1, 1.5, 2.0), sCF * CFrame.new(0, 0.85, 0), richTimber, Enum.Material.Wood, nil, false)
			rPart(tag, "ChairCushion", Vector3.new(2.15, 0.32, 2.05), sCF * CFrame.new(0, 1.72, 0), seatCol, Enum.Material.Leather, nil, false)
			rPart(tag, "ChairBack", Vector3.new(2.15, 1.85, 0.34), sCF * CFrame.new(0, 2.65, -0.86), richTimber, Enum.Material.Wood, nil, false)
		end
	end

	local function buildPitchedWoodRoof(
		tag: string,
		cx: number,
		cz: number,
		w: number,
		dLen: number,
		eaveY: number,
		roofMat: Enum.Material,
		roofCol: Color3
	): ()
		-- Cedar Timber Fascia Beam Ring
		rPart(tag, "FasciaF", Vector3.new(w + 1.4, 1.35, 0.95), CFrame.new(cx, eaveY + 0.55, cz + dLen * 0.5), richTimber, Enum.Material.Wood, nil, false)
		rPart(tag, "FasciaB", Vector3.new(w + 1.4, 1.35, 0.95), CFrame.new(cx, eaveY + 0.55, cz - dLen * 0.5), richTimber, Enum.Material.Wood, nil, false)
		rPart(tag, "FasciaL", Vector3.new(0.95, 1.35, dLen + 1.4), CFrame.new(cx - w * 0.5, eaveY + 0.55, cz), richTimber, Enum.Material.Wood, nil, false)
		rPart(tag, "FasciaR", Vector3.new(0.95, 1.35, dLen + 1.4), CFrame.new(cx + w * 0.5, eaveY + 0.55, cz), richTimber, Enum.Material.Wood, nil, false)

		-- Brushed Brass Eave Trim
		rPart(tag, "BrassF", Vector3.new(w + 1.8, 0.34, 1.18), CFrame.new(cx, eaveY + 1.24, cz + dLen * 0.5), brassCol, Enum.Material.Metal, nil, false)
		rPart(tag, "BrassB", Vector3.new(w + 1.8, 0.34, 1.18), CFrame.new(cx, eaveY + 1.24, cz - dLen * 0.5), brassCol, Enum.Material.Metal, nil, false)
		rPart(tag, "BrassL", Vector3.new(1.18, 0.34, dLen + 1.8), CFrame.new(cx - w * 0.5, eaveY + 1.24, cz), brassCol, Enum.Material.Metal, nil, false)
		rPart(tag, "BrassR", Vector3.new(1.18, 0.34, dLen + 1.8), CFrame.new(cx + w * 0.5, eaveY + 1.24, cz), brassCol, Enum.Material.Metal, nil, false)

		-- Solid Pitched Wood & Shingle Roof Slopes + Warm Cedar Plank Ceiling Soffit
		local slopeW = w * 0.45
		local pitchRad = math.rad(12)
		local roofMidY = eaveY + 2.45
		rPart(tag, "RoofSlopeL", Vector3.new(slopeW, 0.68, dLen + 1.8), CFrame.new(cx - w * 0.27, roofMidY, cz) * CFrame.Angles(0, 0, pitchRad), roofCol, roofMat, nil, true)
		rPart(tag, "RoofSlopeR", Vector3.new(slopeW, 0.68, dLen + 1.8), CFrame.new(cx + w * 0.27, roofMidY, cz) * CFrame.Angles(0, 0, -pitchRad), roofCol, roofMat, nil, true)
		rPart(tag, "CedarSoffitL", Vector3.new(slopeW - 0.6, 0.30, dLen - 0.4), CFrame.new(cx - w * 0.27, roofMidY - 0.44, cz) * CFrame.Angles(0, 0, pitchRad), soffitWood, Enum.Material.WoodPlanks, nil, false)
		rPart(tag, "CedarSoffitR", Vector3.new(slopeW - 0.6, 0.30, dLen - 0.4), CFrame.new(cx + w * 0.27, roofMidY - 0.44, cz) * CFrame.Angles(0, 0, -pitchRad), soffitWood, Enum.Material.WoodPlanks, nil, false)

		-- Center Frosted Skylight Ridge & Illuminated Cedar/Brass Ridge Beam
		rPart(tag, "Skylight", Vector3.new(w * 0.18, 0.36, dLen + 0.6), CFrame.new(cx, eaveY + 4.35, cz), skylightCol, Enum.Material.Glass, 0.36, true)
		local ridge = rPart(tag, "RidgeCap", Vector3.new(1.3, 0.72, dLen + 2.4), CFrame.new(cx, eaveY + 4.78, cz), brassCol, Enum.Material.Metal, nil, false)
		addGlow(ridge, 46, 1.35)

		-- Carved Cedar Gable Ends
		rPart(tag, "GableLowF", Vector3.new(w * 0.86, 2.2, 0.6), CFrame.new(cx, eaveY + 2.25, cz + dLen * 0.49), cedarWood, Enum.Material.Wood, nil, false)
		rPart(tag, "GableLowB", Vector3.new(w * 0.86, 2.2, 0.6), CFrame.new(cx, eaveY + 2.25, cz - dLen * 0.49), cedarWood, Enum.Material.Wood, nil, false)
		rPart(tag, "GableHighF", Vector3.new(w * 0.42, 1.5, 0.6), CFrame.new(cx, eaveY + 3.70, cz + dLen * 0.49), richTimber, Enum.Material.Wood, nil, false)
		rPart(tag, "GableHighB", Vector3.new(w * 0.42, 1.5, 0.6), CFrame.new(cx, eaveY + 3.70, cz - dLen * 0.49), richTimber, Enum.Material.Wood, nil, false)
	end

	for _, side in ipairs({ -1, 1 }) do
		local sideTag = if side < 0 then "LeftWoodRest_" else "RightWoodRest_"
		local innerCX = side * 58.0
		local innerCZ = 62.0
		local innerW = 54.4
		local innerD = 62.4
		local topY = 11.4

		-- Stone Column Plinths on Inner Terrace Corners (All Levels)
		for _, sx in ipairs({ -innerW * 0.47, innerW * 0.47 }) do
			for _, sz in ipairs({ -innerD * 0.47, innerD * 0.47 }) do
				rPart(sideTag, "CornerPlinth", Vector3.new(2.5, 2.2, 2.5), CFrame.new(innerCX + sx, 1.4, innerCZ + sz), Color3.fromRGB(84, 80, 74), Enum.Material.Brick, nil, false)
			end
		end

		if tier == 1 then
			-- LEVEL 1: Starter Open Cedar Pergola with Timber Rafters & Warm Bistro Bulbs
			rPart(sideTag, "StarterBeamF", Vector3.new(innerW, 1.0, 0.8), CFrame.new(innerCX, topY + 0.4, innerCZ + innerD * 0.5), cedarWood, Enum.Material.Wood, nil, false)
			rPart(sideTag, "StarterBeamB", Vector3.new(innerW, 1.0, 0.8), CFrame.new(innerCX, topY + 0.4, innerCZ - innerD * 0.5), cedarWood, Enum.Material.Wood, nil, false)
			for rz = 36, 88, 13 do
				rPart(sideTag, "OpenRafter", Vector3.new(innerW - 1.0, 0.55, 0.55), CFrame.new(innerCX, topY + 0.65, rz), soffitWood, Enum.Material.WoodPlanks, nil, false)
				local bulb = rPart(sideTag, "BistroBulb", Vector3.new(0.65, 0.65, 0.65), CFrame.new(innerCX, topY + 0.1, rz), lanternGlow, Enum.Material.Neon, 0.1, false, Enum.PartType.Ball)
				if rz == 62 then
					addGlow(bulb, 36, 1.1)
				end
			end
		else
			-- LEVEL 2+: Full Pitched Cedar & Shingle Wood Restaurant Roof over Entire 54x62 Terrace!
			buildPitchedWoodRoof(sideTag .. "Inner_", innerCX, innerCZ, innerW, innerD, topY, Enum.Material.WoodPlanks, roofShingle)
		end

		-- LEVEL 3+: Carved Cedar Host & Appetizer Bar Counter + Hanging Timber Lanterns
		if tier >= 3 then
			local barX = side * 34.8
			rPart(sideTag, "HostBarBody", Vector3.new(3.4, 3.2, 9.6), CFrame.new(barX, 2.0, 36.8), cedarWood, Enum.Material.Wood, nil, true)
			rPart(sideTag, "HostBarTop", Vector3.new(4.0, 0.34, 10.2), CFrame.new(barX, 3.75, 36.8), brassCol, Enum.Material.WoodPlanks, nil, true)
			rPart(sideTag, "EspressoMachine", Vector3.new(1.8, 1.6, 2.2), CFrame.new(barX, 4.7, 35.0), brassCol, Enum.Material.Metal, nil, false)
			for _, lz in ipairs({ 43.0, 62.0, 81.0 }) do
				rPart(sideTag, "LanternCord", Vector3.new(0.16, 2.0, 0.16), CFrame.new(innerCX, topY - 0.6, lz), darkIron, Enum.Material.Metal, nil, false)
				local lant = rPart(sideTag, "WarmLantern", Vector3.new(1.3, 1.8, 1.3), CFrame.new(innerCX, topY - 2.1, lz), lanternGlow, Enum.Material.Glass, 0.15, false)
				addGlow(lant, 26, 0.95)
			end
		end

		-- LEVEL 4+: Cedar Planter Boxes & Decorative Gable Crest Trim
		if tier >= 4 then
			for _, pz in ipairs({ 31.6, 92.4 }) do
				rPart(sideTag, "CedarPlanter", Vector3.new(18.0, 1.8, 2.2), CFrame.new(innerCX, 1.3, pz), richTimber, Enum.Material.Wood, nil, true)
				rPart(sideTag, "BoxwoodHedge", Vector3.new(17.2, 1.6, 1.7), CFrame.new(innerCX, 2.7, pz), hedgeGreen, Enum.Material.Grass, nil, false)
			end
		end

		-- LEVEL 5+: EXPANDED COVERED SIDE WOOD VERANDA (X = +/-85..+/-127, +6 Wood Tables at Lv.5 & +6 at Lv.9!)
		if tier >= 5 then
			local midCX = side * 106.0
			local midW = 42.0
			local midD = 60.0
			local midTag = sideTag .. "Veranda_"

			-- Seamless Flush Cedar Plank Deck (top Y = 0.40, matching DiningTerraceDeck!)
			rPart(midTag, "WoodDeck", Vector3.new(midW + 0.8, 0.40, midD), CFrame.new(midCX, 0.20, innerCZ), deckWood, Enum.Material.WoodPlanks, nil, true)
			rPart(midTag, "DeckBorderF", Vector3.new(midW + 1.2, 0.44, 0.8), CFrame.new(midCX, 0.22, innerCZ + midD * 0.5), richTimber, Enum.Material.Wood, nil, false)
			rPart(midTag, "DeckBorderB", Vector3.new(midW + 1.2, 0.44, 0.8), CFrame.new(midCX, 0.22, innerCZ - midD * 0.5), richTimber, Enum.Material.Wood, nil, false)

			-- Heavy Cedar Support Columns (clear of all table & chair lanes!)
			for _, px in ipairs({ side * 87.0, side * 125.0 }) do
				for _, pz in ipairs({ 33.0, 52.0, 72.0, 91.0 }) do
					rPart(midTag, "Plinth", Vector3.new(2.2, 1.8, 2.2), CFrame.new(px, 1.1, pz), Color3.fromRGB(84, 80, 74), Enum.Material.Brick, nil, false)
					rPart(midTag, "CedarPost", Vector3.new(1.5, 10.6, 1.5), CFrame.new(px, 6.2, pz), richTimber, Enum.Material.Wood, nil, true)
					if tier >= 8 then
						rPart(midTag, "BrassCap", Vector3.new(1.9, 0.55, 1.9), CFrame.new(px, 11.2, pz), brassCol, Enum.Material.Metal, nil, false)
					end
				end
			end

			buildPitchedWoodRoof(midTag, midCX, innerCZ, midW, midD, 11.0, Enum.Material.Slate, slateRoof)

			-- Lv.5+: Column A Handcrafted Wood Dining Tables (X = +/-98, Z = 43, 62, 81)
			for _, tz in ipairs({ 43.0, 62.0, 81.0 }) do
				buildWoodDiningTable(midTag .. "TblA_" .. tostring(tz) .. "_", side * 98.0, tz, tier >= 8)
			end
		end

		-- LEVEL 6+: Outdoor Cedar & Stone Wood-Fired Grill Bar at Rear of Veranda
		if tier >= 6 then
			local gx = side * 107.0
			local gz = 33.4
			rPart(sideTag, "GrillStoneBase", Vector3.new(9.6, 3.4, 2.8), CFrame.new(gx, 2.1, gz), Color3.fromRGB(116, 62, 48), Enum.Material.Brick, nil, true)
			rPart(sideTag, "GrillWoodCounter", Vector3.new(10.2, 0.36, 3.4), CFrame.new(gx, 3.95, gz), cedarWood, Enum.Material.Wood, nil, true)
			local ember = rPart(sideTag, "GrillEmbers", Vector3.new(4.2, 0.25, 1.6), CFrame.new(gx, 4.18, gz), Color3.fromRGB(242, 112, 38), Enum.Material.Neon, 0.08, false)
			addGlow(ember, 18, 1.1)
			rPart(sideTag, "GrillCopperHood", Vector3.new(5.4, 2.2, 2.4), CFrame.new(gx, 8.6, gz), Color3.fromRGB(184, 108, 64), Enum.Material.Metal, nil, false)
		end

		-- LEVEL 7+: Carved Cedar Entry Archway Welcoming Diners from Center Walkway
		if tier >= 7 then
			local archX = side * 31.2
			for _, az in ipairs({ 55.5, 68.5 }) do
				rPart(sideTag, "EntryArchPost", Vector3.new(1.6, 11.4, 1.6), CFrame.new(archX, 6.1, az), richTimber, Enum.Material.Wood, nil, true)
			end
			rPart(sideTag, "EntryArchBeam", Vector3.new(2.0, 1.6, 15.6), CFrame.new(archX, 12.2, 62.0), cedarWood, Enum.Material.Wood, nil, false)
			rPart(sideTag, "EntryArchGold", Vector3.new(2.2, 0.38, 16.0), CFrame.new(archX, 13.1, 62.0), brassCol, Enum.Material.Metal, nil, false)
		end

		-- LEVEL 8+: Exposed Cedar King-Post Trusses Across Inner & Veranda Roofs
		if tier >= 8 then
			for _, tz in ipairs({ 42.0, 62.0, 82.0 }) do
				rPart(sideTag, "KingTrussTie", Vector3.new(innerW - 2.0, 0.55, 0.65), CFrame.new(innerCX, topY + 0.9, tz), cedarWood, Enum.Material.Wood, nil, false)
				rPart(sideTag, "KingPost", Vector3.new(0.75, 3.2, 0.75), CFrame.new(innerCX, topY + 2.6, tz), brassCol, Enum.Material.Metal, nil, false)
			end
		end

		-- LEVEL 9+: TWO-TIER PAGODA CLERESTORY WOOD ROOF & COLUMN B WOOD TABLES (+12 Seats!)
		if tier >= 9 then
			local pagW = 28.0
			local pagD = 38.0
			local pagBaseY = topY + 4.4
			rPart(sideTag, "PagodaClerestoryGlass", Vector3.new(pagW - 2.0, 2.8, pagD - 2.0), CFrame.new(innerCX, pagBaseY + 1.4, innerCZ), skylightCol, Enum.Material.Glass, 0.28, false)
			for _, cx in ipairs({ -pagW * 0.46, pagW * 0.46 }) do
				for _, czOff in ipairs({ -pagD * 0.46, pagD * 0.46 }) do
					rPart(sideTag, "PagodaPost", Vector3.new(1.4, 3.2, 1.4), CFrame.new(innerCX + cx, pagBaseY + 1.5, innerCZ + czOff), richTimber, Enum.Material.Wood, nil, false)
				end
			end
			buildPitchedWoodRoof(sideTag .. "PagodaTop_", innerCX, innerCZ, pagW + 3.0, pagD + 3.0, pagBaseY + 2.8, Enum.Material.WoodPlanks, roofShingle)

			for _, tz in ipairs({ 43.0, 62.0, 81.0 }) do
				buildWoodDiningTable(sideTag .. "Veranda_TblB_" .. tostring(tz) .. "_", side * 116.0, tz, true)
			end
		end

		-- LEVEL 10+: Twin Illuminated Wood Restaurant Level Marquee Signs Facing City Gate!
		if tier >= 10 then
			local mBacking = rPart(sideTag, "MarqueeWoodFrame", Vector3.new(28.0, 4.6, 1.2), CFrame.new(innerCX, topY + 3.4, innerCZ + innerD * 0.5 + 0.8), richTimber, Enum.Material.Wood, nil, false)
			local mFace = rPart(sideTag, "MarqueeSignFace", Vector3.new(26.4, 3.6, 0.35), CFrame.new(innerCX, topY + 3.4, innerCZ + innerD * 0.5 + 1.35), Color3.fromRGB(18, 20, 26), Enum.Material.SmoothPlastic, nil, false)
			setArchMarqueeText(mFace, palette.BrandTitle .. " WOOD PAVILION", string.format("LV.%d OUTDOOR DINING HALL", tier), brassCol)
			mBacking.CanQuery = false
		end

		-- LEVEL 11+: Suspended Brass & Cedar Ring Chandeliers + Connecting Cedar Bridges
		if tier >= 11 then
			local chRing = rPart(sideTag, "WoodPavilionChandelier", Vector3.new(0.45, 6.4, 6.4), CFrame.new(side * 106.0, 9.2, 62.0) * CFrame.Angles(0, 0, math.rad(90)), brassCol, Enum.Material.Metal, nil, false, Enum.PartType.Cylinder)
			addGlow(chRing, 38, 1.4)
			rPart(sideTag, "ArcadeBridgeBeam", Vector3.new(10.0, 1.2, 58.0), CFrame.new(side * 85.5, 11.4, 62.0), cedarWood, Enum.Material.Wood, nil, false)
		end

		-- LEVEL 12+: ROYAL OUTER WOOD RESTAURANT WINGS (X = +/-127..+/-157, +4 VIP Tables at Lv.12 & +2 at Lv.14!)
		if tier >= 12 then
			local outCX = side * 142.0
			local outW = 30.0
			local outD = 54.0
			local outTag = sideTag .. "RoyalWing_"

			rPart(outTag, "WoodDeck", Vector3.new(outW + 0.8, 0.40, outD), CFrame.new(outCX, 0.20, innerCZ), deckWood, Enum.Material.WoodPlanks, nil, true)
			for _, px in ipairs({ side * 128.0, side * 156.0 }) do
				for _, pz in ipairs({ 36.0, 53.0, 71.0, 88.0 }) do
					rPart(outTag, "Plinth", Vector3.new(2.0, 1.8, 2.0), CFrame.new(px, 1.1, pz), Color3.fromRGB(84, 80, 74), Enum.Material.Brick, nil, false)
					rPart(outTag, "CedarPost", Vector3.new(1.4, 10.2, 1.4), CFrame.new(px, 5.9, pz), richTimber, Enum.Material.Wood, nil, true)
					rPart(outTag, "BrassCap", Vector3.new(1.8, 0.5, 1.8), CFrame.new(px, 10.8, pz), brassCol, Enum.Material.Metal, nil, false)
				end
			end
			buildPitchedWoodRoof(outTag, outCX, innerCZ, outW, outD, 10.6, Enum.Material.WoodPlanks, roofShingle)

			buildWoodDiningTable(outTag .. "VIP_44_", outCX, 44.0, true)
			buildWoodDiningTable(outTag .. "VIP_80_", outCX, 80.0, true)
		end

		-- LEVEL 13+: Outdoor Cedar Teppanyaki Chef Counter & Gilded Gable Trim
		if tier >= 13 then
			local tepX = side * 142.0
			rPart(sideTag, "TeppanyakiCounter", Vector3.new(8.6, 3.3, 2.6), CFrame.new(tepX, 2.05, 36.2), richTimber, Enum.Material.Wood, nil, true)
			rPart(sideTag, "TeppanyakiSteelPlate", Vector3.new(6.8, 0.24, 1.9), CFrame.new(tepX, 3.82, 36.2), Color3.fromRGB(178, 184, 194), Enum.Material.Metal, nil, false)
			rPart(sideTag, "GildedGableBar", Vector3.new(innerW * 0.90, 0.45, 0.85), CFrame.new(innerCX, topY + 2.25, innerCZ + innerD * 0.50), brassCol, Enum.Material.Metal, nil, false)
		end

		-- LEVEL 14+: Twin Golden Pagoda Roof Finials & Center Royal VIP Wood Table
		if tier >= 14 then
			local fin = rPart(sideTag, "GoldenPagodaFinial", Vector3.new(5.4, 1.8, 1.8), CFrame.new(innerCX, topY + 14.2, innerCZ) * CFrame.Angles(0, 0, math.rad(90)), brassCol, Enum.Material.Metal, nil, false, Enum.PartType.Cylinder)
			addGlow(fin, 42, 1.5)
			buildWoodDiningTable(sideTag .. "RoyalWing_VIP_62_", side * 142.0, 62.0, true)
		end

		-- LEVEL 15 (MAX): SUPREME GOLDEN-ROOF WOOD EMPIRE BEACONS & IMPERIAL CREST!
		if tier >= 15 then
			local goldOrb = rPart(sideTag, "SupremeWoodCrestOrb", Vector3.new(2.8, 2.8, 2.8), CFrame.new(innerCX, topY + 17.5, innerCZ), Color3.fromRGB(255, 232, 152), Enum.Material.Neon, 0.06, false, Enum.PartType.Ball)
			addGlow(goldOrb, 64, 2.0)
			rPart(sideTag, "SupremeVerandaGoldRidge", Vector3.new(1.5, 0.9, 62.0), CFrame.new(side * 106.0, 16.2, innerCZ), Color3.fromRGB(248, 202, 68), Enum.Material.Metal, nil, false)
		end
	end

	roofFolder.Parent = plaza
end

return RestaurantExpansionBuilder
