--!strict

-- DayNightService: Live server-wide Day/Night cycle for Food Empire.
--  * Smoothly animates Lighting (sun, sky, ambient, atmosphere, bloom, color grade) between Day and Night.
--  * Switches ON every street light, restaurant lantern & warehouse light at dusk (brighter & wider at night).
--  * Night gameplay: +35% Gold on food (Night Market), Mafia hunt from farther away,
--    but your Stealth Delivery Runner is much harder to spot in the dark.
--  * Exposes ReplicatedStorage attributes: IsNight (bool), GameClock (number), DayPhase (string).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DayNightService = {}

-- Real-time lengths: daytime (06:00 -> 18:00) lasts 7 minutes, night (18:00 -> 06:00) lasts 4 minutes.
local DAY_REAL_SECONDS = 420
local NIGHT_REAL_SECONDS = 240
local TICK = 0.2
local START_CLOCK = 19.8
local SKIP_COOLDOWN = 1.5

type LightingSnapshot = {
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Exposure: number,
	EnvDiffuse: number,
	EnvSpecular: number,
}

local isRunning = false
local loopThread: thread? = nil
local clock = START_CLOCK
local lightsAreOn: boolean? = nil
local lastIsNight: boolean? = nil
local lastSkipAt: { [Player]: number } = {}
local daySnap: LightingSnapshot? = nil
local effectDay: { [Instance]: { [string]: any } } = {}
local syncEv: RemoteEvent? = nil

local NIGHT_LIGHTING = {
	Brightness = 1.15,
	Ambient = Color3.fromRGB(62, 70, 104),
	OutdoorAmbient = Color3.fromRGB(78, 90, 132),
	Exposure = -0.05,
	EnvDiffuse = 0.35,
	EnvSpecular = 0.45,
}

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0 = full day, 1 = full night. Dusk ramps 17:00 -> 19:30, dawn ramps 05:00 -> 07:00.
local function getNightFactor(c: number): number
	if c >= 12 then
		return smoothstep(17.0, 19.5, c)
	end
	return 1 - smoothstep(5.0, 7.0, c)
end

local function getPhaseName(c: number): string
	if c >= 5 and c < 7 then
		return "Dawn"
	elseif c >= 7 and c < 17 then
		return "Day"
	elseif c >= 17 and c < 19.5 then
		return "Dusk"
	end
	return "Night"
end

local function captureDaySnapshot(): ()
	daySnap = {
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Exposure = Lighting.ExposureCompensation,
		EnvDiffuse = Lighting.EnvironmentDiffuseScale,
		EnvSpecular = Lighting.EnvironmentSpecularScale,
	}
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("ColorCorrectionEffect") then
			effectDay[child] = { TintColor = child.TintColor, Saturation = child.Saturation, Contrast = child.Contrast, Brightness = child.Brightness }
		elseif child:IsA("BloomEffect") then
			effectDay[child] = { Intensity = child.Intensity, Threshold = child.Threshold, Size = child.Size }
		elseif child:IsA("SunRaysEffect") then
			effectDay[child] = { Intensity = child.Intensity }
		elseif child:IsA("Atmosphere") then
			effectDay[child] = { Color = child.Color, Decay = child.Decay, Density = child.Density, Glare = child.Glare, Haze = child.Haze }
		elseif child:IsA("Sky") then
			effectDay[child] = { StarCount = child.StarCount }
		end
	end
end

-- Automatically fixes Black Market off-road placement, seamless Roundabout Road Intersections, and Territory Arch alignment!
local function fixWorldMapLayout(): ()
	local map = Workspace:FindFirstChild("FoodEmpireMap")
	if not map then
		return
	end

	-- 1. Move BlackMarketOutpost OFF the SW diagonal highway onto its own paved side-lot at (-295, 1.6, 130) facing East (+X) toward Ring_West!
	local bm = map:FindFirstChild("BlackMarketOutpost")
	if bm and bm:IsA("Model") then
		bm:PivotTo(CFrame.lookAt(Vector3.new(-295, 1.6, 130), Vector3.new(-204, 1.6, 130)))
		if not bm:FindFirstChild("AlleyDriveway") then
			local drive = Instance.new("Part")
			drive.Name = "AlleyDriveway"
			drive.Size = Vector3.new(74, 0.34, 18)
			drive.CFrame = CFrame.new(-250, 1.13, 130)
			drive.Color = Color3.fromRGB(54, 58, 68)
			drive.Material = Enum.Material.Asphalt
			drive.Anchored = true
			drive.TopSurface = Enum.SurfaceType.Smooth
			drive.BottomSurface = Enum.SurfaceType.Smooth
			drive.Parent = bm

			for _, cz in ipairs({ 120.0, 140.0 }) do
				local curb = Instance.new("Part")
				curb.Name = "AlleyCurb"
				curb.Size = Vector3.new(70, 0.54, 2.0)
				curb.CFrame = CFrame.new(-251, 1.27, cz)
				curb.Color = Color3.fromRGB(164, 168, 176)
				curb.Material = Enum.Material.Concrete
				curb.Anchored = true
				curb.TopSurface = Enum.SurfaceType.Smooth
				curb.BottomSurface = Enum.SurfaceType.Smooth
				curb.Parent = bm
			end
		end
	end

	-- 2. Rebuild TerritoryHighways with unified heights, split CrossStreet curbs & clean Circular Roundabout Plazas!
	local roads = map:FindFirstChild("Roads")
	if roads then
		local oldTh = roads:FindFirstChild("TerritoryHighways")
		if oldTh then
			oldTh:Destroy()
		end
		local thFolder = Instance.new("Folder")
		thFolder.Name = "TerritoryHighways"
		thFolder.Parent = roads

		local ASPHALT_COL = Color3.fromRGB(54, 58, 68)
		local ROUNDABOUT_COL = Color3.fromRGB(50, 54, 64)
		local CURB_COL = Color3.fromRGB(164, 168, 176)
		local DASH_COL = Color3.fromRGB(246, 206, 72)
		local ASPHALT_Y, ASPHALT_H = 1.13, 0.34
		local PAD_Y, PAD_H = 1.134, 0.34
		local ROUNDABOUT_Y, ROUNDABOUT_H = 1.16, 0.42
		local CURB_Y, CURB_H = 1.27, 0.54
		local DASH_Y, DASH_H = 1.310, 0.05

		local function makeRoadPart(parent: Instance, name: string, sz: Vector3, cf: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Size = sz
			p.CFrame = cf
			p.Color = col
			p.Material = mat
			if shape then p.Shape = shape end
			p.Anchored = true
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = parent
			return p
		end

		local function addRoundabout(parent: Instance, name: string, x: number, z: number): ()
			makeRoadPart(
				parent,
				name .. "_Asphalt",
				Vector3.new(ROUNDABOUT_H, 42, 42),
				CFrame.new(x, ROUNDABOUT_Y, z) * CFrame.Angles(0, 0, math.rad(90)),
				ROUNDABOUT_COL,
				Enum.Material.Asphalt,
				Enum.PartType.Cylinder
			)
			makeRoadPart(
				parent,
				name .. "_Island",
				Vector3.new(0.65, 8.5, 8.5),
				CFrame.new(x, 1.54, z) * CFrame.Angles(0, 0, math.rad(90)),
				CURB_COL,
				Enum.Material.Concrete,
				Enum.PartType.Cylinder
			)
			local orb = makeRoadPart(
				parent,
				name .. "_LanternGlass",
				Vector3.new(2.4, 2.4, 2.4),
				CFrame.new(x, 3.10, z),
				Color3.fromRGB(255, 224, 132),
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			orb.CanCollide = false
			local pl = Instance.new("PointLight")
			pl.Color = Color3.fromRGB(255, 214, 120)
			pl.Brightness = 1.6
			pl.Range = 32
			pl.Shadows = false
			pl.Parent = orb
		end

		local function addCleanHighwaySegment(parent: Instance, p1: Vector3, p2: Vector3, isInner: boolean): ()
			local delta = p2 - p1
			local fullDist = delta.Magnitude
			if fullDist < 28 then return end
			local dir = delta.Unit
			local rightVec = dir:Cross(Vector3.new(0, 1, 0)).Unit

			local startS = 18.0
			local endS = fullDist - 18.0
			local segLen = endS - startS
			local midPos = p1 + dir * ((startS + endS) * 0.5)
			local cf = CFrame.lookAt(Vector3.new(midPos.X, ASPHALT_Y, midPos.Z), Vector3.new(midPos.X + dir.X, ASPHALT_Y, midPos.Z + dir.Z))

			makeRoadPart(parent, "Asphalt", Vector3.new(20, ASPHALT_H, segLen), cf, ASPHALT_COL, Enum.Material.Asphalt, nil)

			local curbSegs: { { number } } = if isInner
				then { { 18.6, 187.74 }, { 213.19, fullDist - 24.5 } }
				else { { 21.5, fullDist - 21.5 } }

			for _, side in ipairs({ { Name = "Curb_L", Off = -10.9 }, { Name = "Curb_R", Off = 10.9 } }) do
				for _, seg in ipairs(curbSegs) do
					local cLen = seg[2] - seg[1]
					if cLen > 1 then
						local midS = (seg[1] + seg[2]) * 0.5
						local cPos = p1 + dir * midS + rightVec * side.Off
						local cCF = CFrame.lookAt(Vector3.new(cPos.X, CURB_Y, cPos.Z), Vector3.new(cPos.X + dir.X, CURB_Y, cPos.Z + dir.Z))
						makeRoadPart(parent, side.Name, Vector3.new(1.8, CURB_H, cLen), cCF, CURB_COL, Enum.Material.Concrete, nil)
					end
				end
			end

			local s = 32.0
			while s <= endS - 14.0 do
				local blocked = isInner and (s + 5 >= 184.0 and s - 5 <= 220.0)
				if not blocked then
					local dp = p1 + dir * s
					local dCF = CFrame.lookAt(Vector3.new(dp.X, DASH_Y, dp.Z), Vector3.new(dp.X + dir.X, DASH_Y, dp.Z + dir.Z))
					local dash = makeRoadPart(parent, "Dash", Vector3.new(0.75, DASH_H, 9.5), dCF, DASH_COL, Enum.Material.SmoothPlastic, nil)
					dash.CanCollide = false
				end
				s += 24.0
			end

			if isInner then
				local jPos = p1 + dir * 201.75
				local jCF = CFrame.lookAt(Vector3.new(jPos.X, PAD_Y, jPos.Z), Vector3.new(jPos.X + dir.X, PAD_Y, jPos.Z + dir.Z))
				makeRoadPart(parent, "CrossStreet_JunctionPad", Vector3.new(20.4, PAD_H, 28.0), jCF, ASPHALT_COL, Enum.Material.Asphalt, nil)

				local cpPos = p1 + dir * (startS + segLen * 0.65)
				local cpCF = CFrame.lookAt(Vector3.new(cpPos.X, 0, cpPos.Z), Vector3.new(cpPos.X + dir.X, 0, cpPos.Z + dir.Z))
				for _, sx in ipairs({ -12.0, 12.0 }) do
					makeRoadPart(parent, "MafiaPost", Vector3.new(2.2, 14, 2.2), cpCF * CFrame.new(sx, 8.2, 0), Color3.fromRGB(36, 38, 46), Enum.Material.Metal, nil)
					local beacon = makeRoadPart(parent, "MafiaBeacon", Vector3.new(1.5, 1.5, 1.5), cpCF * CFrame.new(sx, 15.7, 0), Color3.fromRGB(238, 48, 58), Enum.Material.Neon, Enum.PartType.Ball)
					local bLight = Instance.new("PointLight")
					bLight.Color = Color3.fromRGB(255, 64, 72)
					bLight.Brightness = 1.5
					bLight.Range = 26
					bLight.Parent = beacon
				end
				makeRoadPart(parent, "MafiaCheckpointBeam", Vector3.new(26, 2.5, 1.4), cpCF * CFrame.new(0, 13.8, 0), Color3.fromRGB(186, 34, 44), Enum.Material.Metal, nil)
			end
		end

		local function buildCleanTerritoryArch(parent: Instance, pos: Vector3, lookTarget: Vector3, titleText: string, accentCol: Color3): ()
			local old = parent:FindFirstChild("TerritoryArch")
			if old then old:Destroy() end

			local arch = Instance.new("Model")
			arch.Name = "TerritoryArch"
			local cf = CFrame.lookAt(Vector3.new(pos.X, 1.2, pos.Z), Vector3.new(lookTarget.X, 1.2, lookTarget.Z))
			local woodDark = Color3.fromRGB(108, 68, 38)
			local woodMid = Color3.fromRGB(142, 92, 52)

			-- Tall posts placed at X = ±13.2 (completely OUTSIDE the 20-stud road + curbs!)
			for _, sx in ipairs({ -13.2, 13.2 }) do
				makeRoadPart(arch, "PostBase", Vector3.new(3.4, 1.6, 3.4), cf * CFrame.new(sx, 0.8, 0), Color3.fromRGB(146, 150, 160), Enum.Material.Concrete, nil)
				makeRoadPart(arch, "Post", Vector3.new(2.4, 16.5, 2.4), cf * CFrame.new(sx, 9.5, 0), woodDark, Enum.Material.Wood, nil)
				local lantern = makeRoadPart(arch, "Lantern", Vector3.new(1.3, 1.6, 1.3), cf * CFrame.new(sx * 0.86, 12.2, 0), Color3.fromRGB(255, 224, 148), Enum.Material.SmoothPlastic, nil)
				local pl = Instance.new("PointLight")
				pl.Color = Color3.fromRGB(255, 214, 132)
				pl.Brightness = 0.85
				pl.Range = 22
				pl.Shadows = false
				pl.Parent = lantern
			end

			-- Overhead crossbeam & pitched roof high above trucks & motorbikes (Y = 17.5..19.4)
			makeRoadPart(arch, "Beam", Vector3.new(30.5, 2.4, 2.8), cf * CFrame.new(0, 17.6, 0), woodMid, Enum.Material.Wood, nil)
			makeRoadPart(arch, "Roof", Vector3.new(32.5, 1.2, 4.4), cf * CFrame.new(0, 19.3, 0), accentCol, Enum.Material.SmoothPlastic, nil)

			local signPart = makeRoadPart(arch, "Sign", Vector3.new(22.5, 3.6, 1.0), cf * CFrame.new(0, 15.2, 0), Color3.fromRGB(32, 26, 22), Enum.Material.SmoothPlastic, nil)
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				local sg = Instance.new("SurfaceGui")
				sg.Face = face
				sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				sg.PixelsPerStud = 28
				sg.Parent = signPart
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.fromScale(1, 1)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamBlack
				lbl.Text = titleText
				lbl.TextSize = 52
				lbl.TextColor3 = Color3.fromRGB(255, 234, 142)
				lbl.Parent = sg
			end

			arch.Parent = parent
		end

		local function addCurvedHighwayToEntry(parent: Instance, midPos: Vector3, targetPos: Vector3, targetForward: Vector3, targetWidth: number): ()
			local u = Vector3.new(targetForward.X, 0, targetForward.Z).Unit
			local right = u:Cross(Vector3.new(0, 1, 0)).Unit
			local flatMid = Vector3.new(midPos.X, 0, midPos.Z)
			local flatTarget = Vector3.new(targetPos.X, 0, targetPos.Z)
			local delta = flatTarget - flatMid
			local L = delta:Dot(u)
			local h = delta:Dot(right)

			if L <= 24 then
				return
			end

			if math.abs(h) < 0.25 then
				addCleanHighwaySegment(parent, flatMid, flatTarget, false)
				return
			end

			local sign = if h >= 0 then 1 else -1
			local absH = math.abs(h)
			local v = right * sign
			local R = (L * L + absH * absH) / (2 * absH)
			local center = flatMid + u * L + v * (absH - R)
			local thetaTotal = math.atan2(L, R - absH)
			local totalArcLen = R * thetaTotal

			local function arcPoint(phi: number): Vector3
				return center - u * (R * math.sin(phi)) + v * (R * math.cos(phi))
			end

			local function arcTangent(phi: number): Vector3
				return (u * math.cos(phi) + v * math.sin(phi)).Unit
			end

			local sStart = 18
			local sCurbStart = 21.5
			local numSegs = 14
			local phiStart = thetaTotal - (sStart / R)
			local terrain = Workspace.Terrain

			for i = 1, numSegs do
				local t0 = (i - 1) / numSegs
				local t1 = i / numSegs
				local phi0 = phiStart * (1 - t0)
				local phi1 = phiStart * (1 - t1)

				local p0 = arcPoint(phi0)
				local p1 = arcPoint(phi1)
				local segDelta = p1 - p0
				local chordLen = segDelta.Magnitude
				local segMid = (p0 + p1) * 0.5
				local segCF = CFrame.lookAt(segMid, p1)

				local halfW0 = 10 + (targetWidth * 0.5 - 10) * t0
				local halfW1 = 10 + (targetWidth * 0.5 - 10) * t1
				local segWidth = math.max(halfW0, halfW1) * 2 + 0.12
				local segLen = chordLen + (if i == numSegs then 0.8 else 0.45)
				local yStagger = if (i % 2) == 0 then -0.003 else 0

				-- Clear any stray terrain grass voxels poking above ground along the road ribbon
				terrain:FillBlock(segCF * CFrame.new(0, 4.0, 0), Vector3.new(segWidth + 4, 6.0, segLen + 2), Enum.Material.Air)

				makeRoadPart(
					parent,
					"Asphalt",
					Vector3.new(segWidth, ASPHALT_H, segLen),
					segCF * CFrame.new(0, ASPHALT_Y + yStagger, if i == numSegs then -0.15 else 0),
					ASPHALT_COL,
					Enum.Material.Asphalt,
					nil
				)
			end

			-- Smooth tapering curbs starting cleanly outside MidRoundabout rim and meeting RoadEmbankment flush
			local phiCurbStart = thetaTotal - (sCurbStart / R)
			for i = 1, numSegs do
				local t0 = (i - 1) / numSegs
				local t1 = i / numSegs
				local phi0 = phiCurbStart * (1 - t0)
				local phi1 = phiCurbStart * (1 - t1)

				local p0 = arcPoint(phi0)
				local p1 = arcPoint(phi1)
				local r0 = arcTangent(phi0):Cross(Vector3.new(0, 1, 0)).Unit
				local r1 = arcTangent(phi1):Cross(Vector3.new(0, 1, 0)).Unit

				local halfW0 = 10 + (targetWidth * 0.5 - 10) * t0
				local halfW1 = 10 + (targetWidth * 0.5 - 10) * t1
				local cw0 = 1.8 + (0.9 - 1.8) * t0
				local cw1 = 1.8 + (0.9 - 1.8) * t1
				local off0 = halfW0 + cw0 * 0.5 - 0.05 * t0
				local off1 = halfW1 + cw1 * 0.5 - 0.05 * t1

				local cwMid = (cw0 + cw1) * 0.5
				local tMid = (t0 + t1) * 0.5
				local curbH = CURB_H + (0.50 - CURB_H) * tMid
				local curbY = CURB_Y + (1.12 - CURB_Y) * tMid

				for _, side in ipairs({ { Name = "Curb_L", Sign = -1 }, { Name = "Curb_R", Sign = 1 } }) do
					local q0 = p0 + r0 * (off0 * side.Sign)
					local q1 = p1 + r1 * (off1 * side.Sign)
					local qLen = (q1 - q0).Magnitude + 0.35
					local qMid = (q0 + q1) * 0.5
					local qCF = CFrame.lookAt(qMid, q1)
					makeRoadPart(
						parent,
						side.Name,
						Vector3.new(cwMid, curbH, qLen),
						qCF * CFrame.new(0, curbY, 0),
						CURB_COL,
						Enum.Material.Concrete,
						nil
					)
				end
			end

			-- Evenly spaced center yellow dashes following the curve centerline
			local s = 32
			while s <= totalArcLen - 14 do
				local phi = thetaTotal - (s / R)
				local dp = arcPoint(phi)
				local dDir = arcTangent(phi)
				local dCF = CFrame.lookAt(dp, dp + dDir)
				local dash = makeRoadPart(
					parent,
					"Dash",
					Vector3.new(0.75, DASH_H, 9.5),
					dCF * CFrame.new(0, DASH_Y, 0),
					DASH_COL,
					Enum.Material.SmoothPlastic,
					nil
				)
				dash.CanCollide = false
				s += 24
			end
		end

		local highwaySpecs = {
			{ Name = "Highway_VegetableFarm_NW", Inner1 = Vector3.new(-204, 0, -204), Mid = Vector3.new(-490, 0, -490), Outer2 = Vector3.new(-730, 0, -730) },
			{ Name = "Highway_Ranch_NE",         Inner1 = Vector3.new(204, 0, -204),  Mid = Vector3.new(490, 0, -490),  Outer2 = Vector3.new(730, 0, -730) },
			{ Name = "Highway_FruitOrchard_SW",  Inner1 = Vector3.new(-204, 0, 204),  Mid = Vector3.new(-490, 0, 490),  Outer2 = Vector3.new(-730, 0, 730) },
			{ Name = "Highway_FishingPort_SE",   Inner1 = Vector3.new(204, 0, 204),   Mid = Vector3.new(490, 0, 490),   Outer2 = Vector3.new(730, 0, 730) },
		}

		for _, hs in ipairs(highwaySpecs) do
			local hModel = Instance.new("Model")
			hModel.Name = hs.Name
			hModel.Parent = thFolder

			addRoundabout(hModel, "InnerRoundabout", hs.Inner1.X, hs.Inner1.Z)
			addRoundabout(hModel, "MidRoundabout", hs.Mid.X, hs.Mid.Z)
			addRoundabout(hModel, "CornerRoundabout", hs.Outer2.X, hs.Outer2.Z)

			addCleanHighwaySegment(hModel, hs.Inner1, hs.Mid, true)
			addCleanHighwaySegment(hModel, hs.Mid, hs.Outer2, false)
		end
	end
end

local function applyLighting(nf: number): ()
	local d = daySnap
	if not d then
		return
	end
	Lighting.Brightness = lerpNumber(d.Brightness, NIGHT_LIGHTING.Brightness, nf)
	Lighting.Ambient = d.Ambient:Lerp(NIGHT_LIGHTING.Ambient, nf)
	Lighting.OutdoorAmbient = d.OutdoorAmbient:Lerp(NIGHT_LIGHTING.OutdoorAmbient, nf)
	Lighting.ExposureCompensation = lerpNumber(d.Exposure, NIGHT_LIGHTING.Exposure, nf)
	Lighting.EnvironmentDiffuseScale = lerpNumber(d.EnvDiffuse, NIGHT_LIGHTING.EnvDiffuse, nf)
	Lighting.EnvironmentSpecularScale = lerpNumber(d.EnvSpecular, NIGHT_LIGHTING.EnvSpecular, nf)

	for inst, props in pairs(effectDay) do
		if inst.Parent then
			if inst:IsA("ColorCorrectionEffect") then
				inst.TintColor = (props.TintColor :: Color3):Lerp(Color3.fromRGB(196, 210, 255), nf)
				inst.Saturation = lerpNumber(props.Saturation, -0.08, nf)
				inst.Contrast = lerpNumber(props.Contrast, 0.12, nf)
			elseif inst:IsA("BloomEffect") then
				-- Gentle, non-blinding bloom at night so nothing glares or washes out the screen
				inst.Intensity = lerpNumber(props.Intensity, 0.22, nf)
				inst.Threshold = lerpNumber(props.Threshold, 1.75, nf)
				inst.Size = math.floor(lerpNumber(props.Size, 14, nf))
			elseif inst:IsA("SunRaysEffect") then
				inst.Intensity = lerpNumber(props.Intensity, 0, nf)
			elseif inst:IsA("Atmosphere") then
				inst.Color = (props.Color :: Color3):Lerp(Color3.fromRGB(58, 72, 118), nf)
				inst.Decay = (props.Decay :: Color3):Lerp(Color3.fromRGB(34, 40, 78), nf)
				inst.Density = lerpNumber(props.Density, math.max(props.Density, 0.34), nf)
				inst.Glare = lerpNumber(props.Glare, 0, nf)
				inst.Haze = lerpNumber(props.Haze, math.max(props.Haze, 1.6), nf)
			elseif inst:IsA("Sky") then
				inst.StarCount = math.floor(lerpNumber(props.StarCount, 5000, nf))
			end
		end
	end
end

local function isCharacterOrTransient(inst: Instance): boolean
	local model = inst:FindFirstAncestorOfClass("Model")
	if model and Players:GetPlayerFromCharacter(model) then
		return true
	end
	return false
end

-- Turns all city lights ON (bright & wide) at night and back to soft daytime glow at sunrise.
local function setCityLights(on: boolean): ()
	if lightsAreOn == on then
		return
	end
	lightsAreOn = on
	task.spawn(function()
		local count = 0
		for _, d in ipairs(Workspace:GetDescendants()) do
			if (d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight")) and not isCharacterOrTransient(d) then
				if d:GetAttribute("DayBrightness") == nil then
					d:SetAttribute("DayBrightness", d.Brightness)
					d:SetAttribute("DayRange", d.Range)
					d:SetAttribute("DayEnabled", d.Enabled)
				end
				local dayB = d:GetAttribute("DayBrightness") :: number
				local dayR = d:GetAttribute("DayRange") :: number
				if on then
					d.Enabled = true
					d.Brightness = math.min(1.05, math.max(dayB * 1.1, 0.85))
					d.Range = math.min(34, math.max(dayR * 1.15, 16))
					d.Shadows = false
				else
					d.Enabled = d:GetAttribute("DayEnabled") ~= false
					d.Brightness = dayB
					d.Range = dayR
				end
				count += 1
				if count % 400 == 0 then
					task.wait()
				end
			elseif d:IsA("BasePart") and d.Name == "LanternGlass" then
				d.Material = Enum.Material.SmoothPlastic
				d.Color = Color3.fromRGB(255, 224, 150)
				d.Transparency = 0.08
			end
		end
	end)
end

local function broadcastToast(msg: string): ()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
	if toastEv and toastEv:IsA("RemoteEvent") then
		toastEv:FireAllClients(msg)
	end
end

local function step(dt: number): ()
	-- Advance clock: daytime hours run faster than night hours (night lasts 4 real minutes)
	local isDayHours = clock >= 6 and clock < 18
	local hoursPerSecond = if isDayHours then (12 / DAY_REAL_SECONDS) else (12 / NIGHT_REAL_SECONDS)
	clock = (clock + hoursPerSecond * dt) % 24

	local nf = getNightFactor(clock)
	Lighting.ClockTime = clock
	applyLighting(nf)
	setCityLights(nf >= 0.3)

	local isNight = nf >= 0.5
	local phaseName = getPhaseName(clock)
	ReplicatedStorage:SetAttribute("GameClock", clock)
	ReplicatedStorage:SetAttribute("DayPhase", phaseName)
	ReplicatedStorage:SetAttribute("NightFactor", nf)
	if syncEv then
		syncEv:FireAllClients(isNight, clock, phaseName, nf)
	end
	if isNight ~= lastIsNight then
		ReplicatedStorage:SetAttribute("IsNight", isNight)
		if lastIsNight ~= nil then
			if isNight then
				broadcastToast("🌙 NIGHT HAS FALLEN! Night Market +35% Gold • Mafia hunt farther • Delivery Runners sneak easier!")
			else
				broadcastToast("☀️ SUNRISE! A new day in the Food Empire — Mafia vision back to normal.")
			end
		end
		lastIsNight = isNight
	end
end

function DayNightService.IsNight(): boolean
	return ReplicatedStorage:GetAttribute("IsNight") == true
end

function DayNightService.GetClock(): number
	return clock
end

-- Jump globally to the next phase (Day -> Night, Night -> Day) for ALL players on the server!
function DayNightService.SkipPhase(player: Player?): (boolean, string)
	if player then
		local now = os.clock()
		local last = lastSkipAt[player]
		if last and (now - last) < SKIP_COOLDOWN then
			return false, string.format("Wait %ds before changing time again!", math.ceil(SKIP_COOLDOWN - (now - last)))
		end
		lastSkipAt[player] = now
	end
	local who = if player then player.DisplayName else "Server"
	if DayNightService.IsNight() then
		clock = 13.5
		step(0)
		broadcastToast("☀️ " .. who .. " switched the island to GLOBAL DAY MODE!")
		return true, "☀️ Global Day Mode activated for all players!"
	end
	clock = 20.2
	step(0)
	broadcastToast("🌙 " .. who .. " switched the island to GLOBAL NIGHT MODE (+35% Gold)!")
	return true, "🌙 Global Night Mode activated for all players!"
end

function DayNightService.Start(): ()
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
	local ev = remotes:FindFirstChild("DayNightSync")
	if ev and ev:IsA("RemoteEvent") then
		syncEv = ev
	else
		local created = Instance.new("RemoteEvent")
		created.Name = "DayNightSync"
		created.Parent = remotes
		syncEv = created
	end
	if syncEv then
		syncEv.OnServerEvent:Connect(function(player: Player)
			DayNightService.SkipPhase(player)
		end)
	end

	pcall(fixWorldMapLayout)
	captureDaySnapshot()
	clock = START_CLOCK
	step(0)

	loopThread = task.spawn(function()
		local last = os.clock()
		while isRunning do
			task.wait(TICK)
			local now = os.clock()
			step(now - last)
			last = now
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		lastSkipAt[p] = nil
	end)

	print("[Food Empire] DayNightService started (Live Day/Night cycle, city street lights & Night Market active)!")
end

function DayNightService.Stop(): ()
	isRunning = false
	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end
end

return DayNightService
