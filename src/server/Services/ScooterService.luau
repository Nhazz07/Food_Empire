--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SectorConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("SectorConfig")
)
local BaseService = require("./BaseService")
local PlayerDataService = require("./PlayerDataService")
local MonetizationService = require("./MonetizationService")

local ScooterService = {}

ScooterService.MOTORBIKE_COIN_COST = 750
ScooterService.SEDAN_COIN_COST = 1250

local MOTORBIKE_WALK_SPEED = 44
local MOTORBIKE_TURBO_SPEED = 66
local SEDAN_WALK_SPEED = 50
local SEDAN_TURBO_SPEED = 74
local TURBO_DURATION = 4.5
local TURBO_COOLDOWN = 9.0
local NORMAL_WALK_SPEED = 16
local WHEEL_RADIUS = 1.35

local activeBikes: { [Player]: Model } = {}
local turboCooldownUntil: { [Player]: number } = {}
local turboToken: { [Player]: number } = {}
local isRunning = false
local playerRemovingConn: RBXScriptConnection? = nil
local charConns: { [Player]: RBXScriptConnection } = {}

function ScooterService.OwnsMotorbike(player: Player): boolean
	if PlayerDataService.GetProfile(player).OwnsMotorbike then
		return true
	end
	if MonetizationService.HasPass(player, "DeliveryMotorbike") then
		return true
	end
	return false
end

function ScooterService.OwnsMafiaSedan(player: Player): boolean
	return PlayerDataService.GetProfile(player).OwnsMafiaSedan == true
end

local function unmountMotorbike(player: Player): ()
	local existing = activeBikes[player]
	if existing and existing.Parent then
		existing:Destroy()
	end
	activeBikes[player] = nil
	player:SetAttribute("OnScooter", false)

	local char = player.Character
	if char then
		char:SetAttribute("RidingMotorbike", false)
		char:SetAttribute("RidingMafiaSedan", false)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.WalkSpeed = NORMAL_WALK_SPEED
		end
	end
end

local function createRigidPart(
	parent: Instance,
	chassis: BasePart,
	name: string,
	size: Vector3,
	relCF: CFrame,
	color: Color3,
	mat: Enum.Material,
	shape: Enum.PartType?,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = chassis.CFrame * relCF
	p.Color = color
	p.Material = mat
	if shape then
		p.Shape = shape
	end
	if transparency then
		p.Transparency = transparency
	end
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function buildSpinningWheel(
	parent: Instance,
	chassis: BasePart,
	jointName: string,
	localOffset: Vector3,
	accentColor: Color3
): Part
	-- Cylinder's local X axis is the axle, so width = X, diameter = Y & Z!
	local tire = Instance.new("Part")
	tire.Name = jointName .. "_Tire"
	tire.Shape = Enum.PartType.Cylinder
	tire.Size = Vector3.new(0.95, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
	tire.CFrame = chassis.CFrame * CFrame.new(localOffset)
	tire.Color = Color3.fromRGB(26, 28, 34)
	tire.Material = Enum.Material.SmoothPlastic
	tire.CanCollide = false
	tire.CanTouch = false
	tire.CanQuery = false
	tire.Massless = true
	tire.CastShadow = false
	tire.Parent = parent

	-- Motor6D allows smooth real-time spinning around local X axis!
	local motor = Instance.new("Motor6D")
	motor.Name = jointName
	motor.Part0 = chassis
	motor.Part1 = tire
	motor.C0 = CFrame.new(localOffset)
	motor.C1 = CFrame.new()
	motor.Parent = chassis

	local function addWheelDetail(name: string, size: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?)
		local d = Instance.new("Part")
		d.Name = name
		d.Size = size
		d.CFrame = tire.CFrame * relCF
		d.Color = col
		d.Material = mat
		if shape then
			d.Shape = shape
		end
		d.CanCollide = false
		d.CanTouch = false
		d.CanQuery = false
		d.Massless = true
		d.CastShadow = false
		d.Parent = parent

		local w = Instance.new("WeldConstraint")
		w.Part0 = tire
		w.Part1 = d
		w.Parent = d
	end

	-- Metallic alloy rim, colored rim stripe, brake hub, and crossed spokes (so wheel spin is clearly visible!)
	addWheelDetail("Rim", Vector3.new(1.02, WHEEL_RADIUS * 1.25, WHEEL_RADIUS * 1.25), CFrame.new(), Color3.fromRGB(196, 202, 212), Enum.Material.Metal, Enum.PartType.Cylinder)
	addWheelDetail("RimAccent", Vector3.new(1.04, WHEEL_RADIUS * 1.40, WHEEL_RADIUS * 1.40), CFrame.new(), accentColor, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	addWheelDetail("Hub", Vector3.new(1.16, 0.65, 0.65), CFrame.new(), Color3.fromRGB(64, 70, 82), Enum.Material.Metal, Enum.PartType.Cylinder)
	addWheelDetail("SpokeA", Vector3.new(1.08, 0.28, WHEEL_RADIUS * 1.24), CFrame.new(), Color3.fromRGB(236, 240, 248), Enum.Material.Metal, nil)
	addWheelDetail("SpokeB", Vector3.new(1.08, WHEEL_RADIUS * 1.24, 0.28), CFrame.new(), Color3.fromRGB(236, 240, 248), Enum.Material.Metal, nil)

	return tire
end

local function mountMotorbike(player: Player): (boolean, string)
	if not ScooterService.OwnsMotorbike(player) then
		return false, "LOCKED_BIKE"
	end

	local char = player.Character
	if not char then
		return false, "Character not loaded"
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then
		return false, "Cannot ride right now"
	end

	unmountMotorbike(player)

	local slot = BaseService.GetPlayerBaseSlot(player)
	local bodyColor = if slot and SectorConfig.FactionColors[slot]
		then SectorConfig.FactionColors[slot]
		else Color3.fromRGB(228, 72, 54)
	local darkMetal = Color3.fromRGB(42, 46, 56)
	local chrome = Color3.fromRGB(208, 214, 224)
	local leather = Color3.fromRGB(32, 34, 42)

	local bike = Instance.new("Model")
	bike.Name = "FoodDeliveryMotorbike"

	-- Dynamic ground height calculation so tires rest flush on the road even for 1.5x players!
	local groundY = -(root.Size.Y * 0.5 + hum.HipHeight)
	local wheelY = groundY + WHEEL_RADIUS

	-- Invisible Chassis Pivot attached to HumanoidRootPart via Motor6D (enables smooth cornering lean!)
	local chassis = Instance.new("Part")
	chassis.Name = "BikeChassis"
	chassis.Size = Vector3.new(1.6, 1.0, 4.6)
	chassis.CFrame = root.CFrame * CFrame.new(0, wheelY, 0)
	chassis.Transparency = 1
	chassis.CanCollide = false
	chassis.CanTouch = false
	chassis.CanQuery = false
	chassis.Massless = true
	chassis.CastShadow = false
	chassis.Parent = bike

	local tiltJoint = Instance.new("Motor6D")
	tiltJoint.Name = "BikeTiltJoint"
	tiltJoint.Part0 = root
	tiltJoint.Part1 = chassis
	tiltJoint.C0 = CFrame.new(0, wheelY, 0)
	tiltJoint.C1 = CFrame.new()
	tiltJoint.Parent = chassis

	-- 1. Real Spinning Spoked Alloy Wheels (Front Z = -3.45, Rear Z = +3.15)
	buildSpinningWheel(bike, chassis, "FrontWheelJoint", Vector3.new(0, 0, -3.45), bodyColor)
	buildSpinningWheel(bike, chassis, "RearWheelJoint", Vector3.new(0, 0, 3.15), bodyColor)

	-- 2. Exposed Engine Block, Radiator & Tubular Frame
	createRigidPart(bike, chassis, "EngineBlock", Vector3.new(1.75, 1.65, 2.3), CFrame.new(0, 0.75, -0.35), darkMetal, Enum.Material.Metal, nil, nil)
	createRigidPart(bike, chassis, "EngineHead", Vector3.new(1.9, 0.55, 1.5), CFrame.new(0, 1.4, -0.45), chrome, Enum.Material.Metal, nil, nil)
	createRigidPart(bike, chassis, "FrameLeft", Vector3.new(0.28, 0.45, 4.4), CFrame.new(-0.92, 1.55, -0.1) * CFrame.Angles(math.rad(-14), 0, 0), darkMetal, Enum.Material.Metal, nil, nil)
	createRigidPart(bike, chassis, "FrameRight", Vector3.new(0.28, 0.45, 4.4), CFrame.new(0.92, 1.55, -0.1) * CFrame.Angles(math.rad(-14), 0, 0), darkMetal, Enum.Material.Metal, nil, nil)
	createRigidPart(bike, chassis, "SwingarmL", Vector3.new(0.26, 0.42, 2.8), CFrame.new(-0.78, 0.12, 1.85), darkMetal, Enum.Material.Metal, nil, nil)
	createRigidPart(bike, chassis, "SwingarmR", Vector3.new(0.26, 0.42, 2.8), CFrame.new(0.78, 0.12, 1.85), darkMetal, Enum.Material.Metal, nil, nil)

	-- 3. Twin Chrome Exhaust Pipes + Live Exhaust Smoke Emitter
	createRigidPart(bike, chassis, "ExhaustPipeL", Vector3.new(3.8, 0.48, 0.48), CFrame.new(-1.12, 0.25, 1.85) * CFrame.Angles(0, math.rad(90), math.rad(10)), chrome, Enum.Material.Metal, Enum.PartType.Cylinder, nil)
	local exhaustR = createRigidPart(bike, chassis, "ExhaustPipeR", Vector3.new(3.8, 0.48, 0.48), CFrame.new(1.12, 0.25, 1.85) * CFrame.Angles(0, math.rad(90), math.rad(10)), chrome, Enum.Material.Metal, Enum.PartType.Cylinder, nil)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "ExhaustSmoke"
	smoke.Color = ColorSequence.new(Color3.fromRGB(220, 224, 232), Color3.fromRGB(170, 176, 188))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1.9) })
	smoke.Lifetime = NumberRange.new(0.45, 0.8)
	smoke.Rate = 5
	smoke.Speed = NumberRange.new(3, 6)
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Parent = exhaustR

	-- 4. Telescopic Chrome Front Forks, Mudguard Fender & Steering Triple-Clamp
	createRigidPart(bike, chassis, "ForkL", Vector3.new(3.9, 0.34, 0.34), CFrame.new(-0.72, 1.7, -2.72) * CFrame.Angles(math.rad(-22), 0, math.rad(90)), chrome, Enum.Material.Metal, Enum.PartType.Cylinder, nil)
	createRigidPart(bike, chassis, "ForkR", Vector3.new(3.9, 0.34, 0.34), CFrame.new(0.72, 1.7, -2.72) * CFrame.Angles(math.rad(-22), 0, math.rad(90)), chrome, Enum.Material.Metal, Enum.PartType.Cylinder, nil)
	createRigidPart(bike, chassis, "FrontFender", Vector3.new(1.25, 0.35, 2.0), CFrame.new(0, 1.48, -3.45) * CFrame.Angles(math.rad(14), 0, 0), bodyColor, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(bike, chassis, "RearFender", Vector3.new(1.35, 0.35, 2.2), CFrame.new(0, 1.65, 3.15) * CFrame.Angles(math.rad(-18), 0, 0), darkMetal, Enum.Material.SmoothPlastic, nil, nil)

	-- 5. Sculpted Aerodynamic Sport Fairing, Tinted Windshield & Glowing Digital Dash
	createRigidPart(bike, chassis, "FrontFairing", Vector3.new(2.15, 2.25, 2.1), CFrame.new(0, 2.55, -2.45) * CFrame.Angles(math.rad(-24), 0, 0), bodyColor, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(bike, chassis, "SideFairingL", Vector3.new(0.35, 1.8, 2.5), CFrame.new(-1.05, 1.65, -1.65) * CFrame.Angles(math.rad(-10), 0, 0), bodyColor, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(bike, chassis, "SideFairingR", Vector3.new(0.35, 1.8, 2.5), CFrame.new(1.05, 1.65, -1.65) * CFrame.Angles(math.rad(-10), 0, 0), bodyColor, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(bike, chassis, "Windshield", Vector3.new(1.75, 1.35, 0.18), CFrame.new(0, 3.95, -2.55) * CFrame.Angles(math.rad(-38), 0, 0), Color3.fromRGB(38, 48, 66), Enum.Material.Glass, nil, 0.45)
	createRigidPart(bike, chassis, "SpeedoDash", Vector3.new(1.3, 0.55, 0.2), CFrame.new(0, 3.55, -2.1) * CFrame.Angles(math.rad(35), 0, 0), Color3.fromRGB(64, 224, 255), Enum.Material.Neon, nil, nil)

	-- 6. Handlebars, Rubber Grips & Twin Rearview Mirrors
	createRigidPart(bike, chassis, "Handlebar", Vector3.new(3.6, 0.28, 0.28), CFrame.new(0, 3.55, -1.95), chrome, Enum.Material.Metal, Enum.PartType.Cylinder, nil)
	createRigidPart(bike, chassis, "GripL", Vector3.new(0.95, 0.38, 0.38), CFrame.new(-1.55, 3.55, -1.95), leather, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, nil)
	createRigidPart(bike, chassis, "GripR", Vector3.new(0.95, 0.38, 0.38), CFrame.new(1.55, 3.55, -1.95), leather, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, nil)
	createRigidPart(bike, chassis, "MirrorL", Vector3.new(0.75, 0.42, 0.18), CFrame.new(-1.45, 4.15, -2.15), darkMetal, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(bike, chassis, "MirrorR", Vector3.new(0.75, 0.42, 0.18), CFrame.new(1.45, 4.15, -2.15), darkMetal, Enum.Material.SmoothPlastic, nil, nil)

	-- 7. Sculpted Fuel Tank, Padded Stepped Leather Seat & Steel Footpegs
	createRigidPart(bike, chassis, "FuelTank", Vector3.new(1.95, 1.35, 2.2), CFrame.new(0, 2.6, -1.15) * CFrame.Angles(math.rad(10), 0, 0), bodyColor, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(bike, chassis, "TankCap", Vector3.new(0.2, 0.55, 0.55), CFrame.new(0, 3.28, -1.15) * CFrame.Angles(0, 0, math.rad(90)), chrome, Enum.Material.Metal, Enum.PartType.Cylinder, nil)
	createRigidPart(bike, chassis, "RiderSeat", Vector3.new(1.65, 0.65, 2.35), CFrame.new(0, 2.35, 0.75) * CFrame.Angles(math.rad(-6), 0, 0), leather, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(bike, chassis, "TailCowling", Vector3.new(1.75, 0.85, 2.1), CFrame.new(0, 2.3, 2.25) * CFrame.Angles(math.rad(8), 0, 0), bodyColor, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(bike, chassis, "FootpegL", Vector3.new(0.85, 0.24, 0.24), CFrame.new(-1.35, 0.65, 0.25), chrome, Enum.Material.Metal, Enum.PartType.Cylinder, nil)
	createRigidPart(bike, chassis, "FootpegR", Vector3.new(0.85, 0.24, 0.24), CFrame.new(1.35, 0.65, 0.25), chrome, Enum.Material.Metal, Enum.PartType.Cylinder, nil)

	-- 8. Bright Dual LED Headlight + Forward SpotLight & Glowing Crimson Brake Taillight
	local headlight = createRigidPart(bike, chassis, "Headlight", Vector3.new(1.45, 0.65, 0.3), CFrame.new(0, 2.65, -3.55), Color3.fromRGB(255, 244, 188), Enum.Material.Neon, nil, nil)
	local spot = Instance.new("SpotLight")
	spot.Color = Color3.fromRGB(255, 244, 200)
	spot.Brightness = 2.4
	spot.Range = 42
	spot.Face = Enum.NormalId.Front
	spot.Shadows = false
	spot.Parent = headlight

	createRigidPart(bike, chassis, "TailLight", Vector3.new(1.25, 0.45, 0.28), CFrame.new(0, 2.35, 3.35), Color3.fromRGB(255, 42, 48), Enum.Material.Neon, nil, nil)

	-- 9. Compact Food Empire Insulated Delivery Top-Box on Rear Rack
	createRigidPart(bike, chassis, "RackBar", Vector3.new(1.4, 0.25, 1.8), CFrame.new(0, 2.75, 2.95), darkMetal, Enum.Material.Metal, nil, nil)
	createRigidPart(bike, chassis, "DeliveryBox", Vector3.new(2.25, 1.85, 2.0), CFrame.new(0, 3.8, 3.15), Color3.fromRGB(248, 246, 240), Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(bike, chassis, "DeliveryLid", Vector3.new(2.38, 0.42, 2.12), CFrame.new(0, 4.78, 3.15), bodyColor, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(bike, chassis, "GoldStripe", Vector3.new(2.4, 0.22, 2.14), CFrame.new(0, 3.8, 3.15), Color3.fromRGB(255, 208, 52), Enum.Material.SmoothPlastic, nil, nil)

	bike.PrimaryPart = chassis
	bike.Parent = char
	activeBikes[player] = bike
	player:SetAttribute("OnScooter", true)
	char:SetAttribute("RidingMotorbike", true)
	char:SetAttribute("RidingMafiaSedan", false)
	char:SetAttribute("BikeTurboActive", false)
	hum.WalkSpeed = MOTORBIKE_WALK_SPEED

	return true, "Sport Motorbike Mounted! Press [LeftShift] for NITRO BOOST or [V] to dismount."
end

local function mountMafiaSedan(player: Player): (boolean, string)
	if not ScooterService.OwnsMafiaSedan(player) then
		return false, "LOCKED_SEDAN"
	end

	local char = player.Character
	if not char then
		return false, "Character not loaded"
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then
		return false, "Cannot drive right now"
	end

	unmountMotorbike(player)

	local obsidian = Color3.fromRGB(16, 18, 22)
	local darkSteel = Color3.fromRGB(30, 34, 42)
	local brass = Color3.fromRGB(178, 144, 78)
	local chrome = Color3.fromRGB(204, 210, 220)
	local oxbloodLeather = Color3.fromRGB(72, 24, 28)

	local sedan = Instance.new("Model")
	sedan.Name = "FoodDeliveryMotorbike"

	local groundY = -(root.Size.Y * 0.5 + hum.HipHeight)
	local wheelY = groundY + WHEEL_RADIUS

	local chassis = Instance.new("Part")
	chassis.Name = "BikeChassis"
	chassis.Size = Vector3.new(6.4, 1.2, 11.8)
	chassis.CFrame = root.CFrame * CFrame.new(0, wheelY, 0)
	chassis.Transparency = 1
	chassis.CanCollide = false
	chassis.CanTouch = false
	chassis.CanQuery = false
	chassis.Massless = true
	chassis.CastShadow = false
	chassis.Parent = sedan

	local tiltJoint = Instance.new("Motor6D")
	tiltJoint.Name = "BikeTiltJoint"
	tiltJoint.Part0 = root
	tiltJoint.Part1 = chassis
	tiltJoint.C0 = CFrame.new(0, wheelY, 0)
	tiltJoint.C1 = CFrame.new()
	tiltJoint.Parent = chassis

	-- 4 Spinning Spoked Alloy & Brass Wheels
	buildSpinningWheel(sedan, chassis, "FrontWheelJoint", Vector3.new(-3.25, 0, -3.85), brass)
	buildSpinningWheel(sedan, chassis, "FrontRightWheelJoint", Vector3.new(3.25, 0, -3.85), brass)
	buildSpinningWheel(sedan, chassis, "RearWheelJoint", Vector3.new(-3.25, 0, 3.85), brass)
	buildSpinningWheel(sedan, chassis, "RearRightWheelJoint", Vector3.new(3.25, 0, 3.85), brass)

	-- Lower Armored Chassis, Running Boards, Sweeping Fenders & Long V8 Hood
	createRigidPart(sedan, chassis, "LowerChassis", Vector3.new(6.1, 1.45, 11.6), CFrame.new(0, 0.9, 0), obsidian, Enum.Material.Metal, nil, nil)
	createRigidPart(sedan, chassis, "RunningBoardL", Vector3.new(0.65, 0.35, 6.2), CFrame.new(-3.35, 0.35, 0.1), darkSteel, Enum.Material.Metal, nil, nil)
	createRigidPart(sedan, chassis, "RunningBoardR", Vector3.new(0.65, 0.35, 6.2), CFrame.new(3.35, 0.35, 0.1), darkSteel, Enum.Material.Metal, nil, nil)
	createRigidPart(sedan, chassis, "LongHood", Vector3.new(5.2, 1.65, 4.2), CFrame.new(0, 2.05, -3.7), obsidian, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(sedan, chassis, "BrassHoodTrim", Vector3.new(0.18, 0.18, 4.1), CFrame.new(0, 2.92, -3.7), brass, Enum.Material.Metal, nil, nil)
	createRigidPart(sedan, chassis, "WaterfallGrille", Vector3.new(3.4, 1.85, 0.35), CFrame.new(0, 1.95, -5.85), chrome, Enum.Material.Metal, nil, nil)
	createRigidPart(sedan, chassis, "FrontBumper", Vector3.new(6.6, 0.55, 0.55), CFrame.new(0, 0.85, -6.05), chrome, Enum.Material.Metal, nil, nil)
	createRigidPart(sedan, chassis, "RearBumper", Vector3.new(6.6, 0.55, 0.55), CFrame.new(0, 0.85, 6.05), chrome, Enum.Material.Metal, nil, nil)
	createRigidPart(sedan, chassis, "RearTrunk", Vector3.new(5.6, 1.65, 2.8), CFrame.new(0, 1.95, 4.45), obsidian, Enum.Material.SmoothPlastic, nil, nil)

	-- Passenger Cabin Doors, Oxblood Leather Seats & Steering Wheel (Open visibility so you see your Bodyguards inside!)
	createRigidPart(sedan, chassis, "DoorLeft", Vector3.new(0.45, 1.65, 5.8), CFrame.new(-2.95, 2.05, 0.45), obsidian, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(sedan, chassis, "DoorRight", Vector3.new(0.45, 1.65, 5.8), CFrame.new(2.95, 2.05, 0.45), obsidian, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(sedan, chassis, "BrassBeltlineL", Vector3.new(0.52, 0.14, 11.2), CFrame.new(-2.95, 2.82, 0), brass, Enum.Material.Metal, nil, nil)
	createRigidPart(sedan, chassis, "BrassBeltlineR", Vector3.new(0.52, 0.14, 11.2), CFrame.new(2.95, 2.82, 0), brass, Enum.Material.Metal, nil, nil)
	createRigidPart(sedan, chassis, "FrontBenchSeat", Vector3.new(5.1, 0.85, 1.8), CFrame.new(0, 1.65, -0.15), oxbloodLeather, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(sedan, chassis, "RearBenchSeat", Vector3.new(5.1, 0.95, 1.9), CFrame.new(0, 1.7, 2.35), oxbloodLeather, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(sedan, chassis, "SteeringWheel", Vector3.new(0.25, 1.25, 1.25), CFrame.new(-1.35, 2.85, -1.25) * CFrame.Angles(math.rad(25), math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder, nil)

	-- Armored Cabin Roof, Pillars & Tinted Windshield
	createRigidPart(sedan, chassis, "CabinRoof", Vector3.new(5.6, 0.35, 5.8), CFrame.new(0, 4.95, 0.55), obsidian, Enum.Material.SmoothPlastic, nil, nil)
	createRigidPart(sedan, chassis, "Windshield", Vector3.new(5.2, 2.05, 0.22), CFrame.new(0, 3.85, -2.05) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(28, 34, 44), Enum.Material.Glass, nil, 0.52)
	createRigidPart(sedan, chassis, "RearWindow", Vector3.new(5.0, 1.85, 0.22), CFrame.new(0, 3.85, 3.25) * CFrame.Angles(math.rad(20), 0, 0), Color3.fromRGB(28, 34, 44), Enum.Material.Glass, nil, 0.52)
	for _, px in ipairs({ -2.65, 2.65 }) do
		for _, pz in ipairs({ -1.75, 0.65, 3.05 }) do
			createRigidPart(sedan, chassis, "RoofPillar", Vector3.new(0.28, 2.2, 0.28), CFrame.new(px, 3.85, pz), darkSteel, Enum.Material.Metal, nil, nil)
		end
	end

	-- Dual Warm Headlights, Taillights & Twin Chrome Exhaust Pipes
	local hlL = createRigidPart(sedan, chassis, "HeadlightL", Vector3.new(0.45, 0.95, 0.95), CFrame.new(-2.25, 2.1, -5.85) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 240, 192), Enum.Material.Neon, Enum.PartType.Cylinder, nil)
	createRigidPart(sedan, chassis, "HeadlightR", Vector3.new(0.45, 0.95, 0.95), CFrame.new(2.25, 2.1, -5.85) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 240, 192), Enum.Material.Neon, Enum.PartType.Cylinder, nil)
	local spot = Instance.new("SpotLight")
	spot.Color = Color3.fromRGB(255, 242, 198)
	spot.Brightness = 2.6
	spot.Range = 48
	spot.Face = Enum.NormalId.Front
	spot.Shadows = false
	spot.Parent = hlL

	createRigidPart(sedan, chassis, "TailLightL", Vector3.new(1.1, 0.45, 0.28), CFrame.new(-2.15, 1.95, 5.88), Color3.fromRGB(218, 36, 42), Enum.Material.Neon, nil, nil)
	createRigidPart(sedan, chassis, "TailLightR", Vector3.new(1.1, 0.45, 0.28), CFrame.new(2.15, 1.95, 5.88), Color3.fromRGB(218, 36, 42), Enum.Material.Neon, nil, nil)

	createRigidPart(sedan, chassis, "ExhaustPipeL", Vector3.new(2.4, 0.42, 0.42), CFrame.new(-1.85, 0.45, 5.45) * CFrame.Angles(0, math.rad(90), 0), chrome, Enum.Material.Metal, Enum.PartType.Cylinder, nil)
	local exhaustR = createRigidPart(sedan, chassis, "ExhaustPipeR", Vector3.new(2.4, 0.42, 0.42), CFrame.new(1.85, 0.45, 5.45) * CFrame.Angles(0, math.rad(90), 0), chrome, Enum.Material.Metal, Enum.PartType.Cylinder, nil)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "ExhaustSmoke"
	smoke.Color = ColorSequence.new(Color3.fromRGB(210, 214, 222), Color3.fromRGB(150, 156, 168))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.1) })
	smoke.Lifetime = NumberRange.new(0.45, 0.85)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(3, 7)
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Parent = exhaustR

	sedan.PrimaryPart = chassis
	sedan.Parent = char
	activeBikes[player] = sedan
	player:SetAttribute("OnScooter", true)
	char:SetAttribute("RidingMotorbike", true)
	char:SetAttribute("RidingMafiaSedan", true)
	char:SetAttribute("BikeTurboActive", false)
	hum.WalkSpeed = SEDAN_WALK_SPEED

	return true, "Armored Black Mafia Sedan Mounted (50 Speed, Bodyguards riding inside)! Press [LeftShift] for V8 OVERDRIVE (74 Speed) or [J] to park."
end

function ScooterService.TriggerTurbo(player: Player): (boolean, string)
	if not ScooterService.IsOnScooter(player) then
		-- If player owns the bike and isn't mounted yet, mount and immediately engage Nitro!
		if ScooterService.OwnsMotorbike(player) then
			local mountedOk = mountMotorbike(player)
			if not mountedOk then
				return false, "Mount your Sport Motorbike [V] first!"
			end
		else
			return false, "Unlock & mount your Sport Motorbike [V] first!"
		end
	end

	local char = player.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	local bike = activeBikes[player]
	if not char or not hum or hum.Health <= 0 or not bike or not bike.Parent then
		return false, "Mount your Sport Motorbike [V] first!"
	end

	local now = os.clock()
	local cdUntil = turboCooldownUntil[player] or 0
	if cdUntil > now then
		return false, string.format("Motorbike Nitro recharging (%ds)!", math.ceil(cdUntil - now))
	end

	turboCooldownUntil[player] = now + TURBO_COOLDOWN
	local nextTok = (turboToken[player] or 0) + 1
	turboToken[player] = nextTok

	local isSedan = char:GetAttribute("RidingMafiaSedan") == true
	char:SetAttribute("BikeTurboActive", true)
	hum.WalkSpeed = if isSedan then SEDAN_TURBO_SPEED else MOTORBIKE_TURBO_SPEED

	local exhaust = bike:FindFirstChild("ExhaustPipeR")
	local smoke = if exhaust then exhaust:FindFirstChild("ExhaustSmoke") else nil
	if smoke and smoke:IsA("ParticleEmitter") then
		smoke.Color = ColorSequence.new(Color3.fromRGB(255, 168, 62), Color3.fromRGB(120, 124, 134))
		smoke.Rate = 38
		smoke.Speed = NumberRange.new(12, 22)
	end

	task.delay(TURBO_DURATION, function()
		if turboToken[player] ~= nextTok then
			return
		end
		if char.Parent then
			char:SetAttribute("BikeTurboActive", false)
		end
		if ScooterService.IsOnScooter(player) and hum.Parent and hum.Health > 0 then
			local stillSedan = char:GetAttribute("RidingMafiaSedan") == true
			hum.WalkSpeed = if stillSedan then SEDAN_WALK_SPEED else MOTORBIKE_WALK_SPEED
		end
		if smoke and smoke.Parent then
			smoke.Color = ColorSequence.new(Color3.fromRGB(220, 224, 232), Color3.fromRGB(170, 176, 188))
			smoke.Rate = 5
			smoke.Speed = NumberRange.new(3, 6)
		end
	end)

	if isSedan then
		return true, "MAFIA SEDAN V8 OVERDRIVE ENGAGED (74 Speed for 4.5s)!"
	end
	return true, "MOTORBIKE NITRO OVERDRIVE ENGAGED (66 Speed for 4.5s)!"
end

function ScooterService.BuySedanWithCoins(player: Player): (boolean, string)
	if ScooterService.OwnsMafiaSedan(player) then
		return mountMafiaSedan(player)
	end
	if not PlayerDataService.SpendCoins(player, ScooterService.SEDAN_COIN_COST) then
		return false, string.format("Need %d Gold to buy the Armored Black Mafia Sedan!", ScooterService.SEDAN_COIN_COST)
	end
	PlayerDataService.SetOwnsMafiaSedan(player, true)
	mountMafiaSedan(player)
	return true, "Purchased Armored Black Mafia Sedan! Your Bodyguards ride inside with you (Press [J] anytime)."
end

function ScooterService.ToggleMafiaSedan(player: Player): (boolean, string)
	local char = player.Character
	if activeBikes[player] and activeBikes[player].Parent and char and char:GetAttribute("RidingMafiaSedan") == true then
		unmountMotorbike(player)
		return true, "Armored Black Mafia Sedan Parked"
	end
	if not ScooterService.OwnsMafiaSedan(player) then
		return false, string.format("Unlock the Armored Black Mafia Sedan (%d Gold) in Empire Upgrades (U) first!", ScooterService.SEDAN_COIN_COST)
	end
	return mountMafiaSedan(player)
end

function ScooterService.BuyWithCoins(player: Player): (boolean, string)
	if ScooterService.OwnsMotorbike(player) then
		return false, "You already own the Sport Motorbike!"
	end
	if not PlayerDataService.SpendCoins(player, ScooterService.MOTORBIKE_COIN_COST) then
		return false, string.format("Need %d Gold to buy Motorbike (or unlock with 79 R$!)", ScooterService.MOTORBIKE_COIN_COST)
	end
	PlayerDataService.SetOwnsMotorbike(player, true)
	mountMotorbike(player)
	print(string.format("[ScooterService] %s bought the Sport Delivery Motorbike with %d Gold!", player.Name, ScooterService.MOTORBIKE_COIN_COST))
	return true, "Unlocked Sport Delivery Motorbike! (Press V anytime to ride)"
end

function ScooterService.ToggleScooter(player: Player): (boolean, string)
	if activeBikes[player] and activeBikes[player].Parent then
		unmountMotorbike(player)
		return true, "Motorbike Parked"
	end
	return mountMotorbike(player)
end

function ScooterService.IsOnScooter(player: Player): boolean
	return activeBikes[player] ~= nil and activeBikes[player].Parent ~= nil
end

function ScooterService.Start(): ()
	if isRunning then
		return
	end
	isRunning = true

	local function hookPlayer(player: Player)
		if charConns[player] then
			charConns[player]:Disconnect()
		end
		charConns[player] = player.CharacterAdded:Connect(function()
			unmountMotorbike(player)
		end)
	end

	Players.PlayerAdded:Connect(hookPlayer)
	playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
		unmountMotorbike(player)
		if charConns[player] then
			charConns[player]:Disconnect()
			charConns[player] = nil
		end
	end)

	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayer(p)
	end

	print("[Food Empire] ScooterService started (Realistic Sport Motorbike — 450 Gold or 79 R$)!")
end

function ScooterService.Stop(): ()
	isRunning = false
	if playerRemovingConn then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for p, conn in pairs(charConns) do
		conn:Disconnect()
		charConns[p] = nil
		unmountMotorbike(p)
	end
end

return ScooterService
