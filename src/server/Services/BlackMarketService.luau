--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local PlayerDataService = require("./PlayerDataService")
local BaseService = require("./BaseService")

export type BlackMarketItemSpec = {
	Id: string,
	DisplayName: string,
	Icon: string,
	Price: number,
	Description: string,
	Kind: "Weapon" | "Armor" | "Consumable",
	Damage: number?,
	Range: number?,
	Cooldown: number?,
	Pellets: number?,
	AccentColor: Color3,
}

local BlackMarketService = {}

BlackMarketService.ORDER = {
	"StreetPistol",
	"PepperShotgun",
	"TacticalSMG",
	"KevlarVest",
	"Medkit",
}

BlackMarketService.ITEMS = {
	StreetPistol = {
		Id = "StreetPistol",
		DisplayName = "Street Pistol",
		Icon = "🔫",
		Price = 250,
		Description = "Reliable semi-auto pistol (32 DMG, 95 range). Aim & click to shoot Rival Chefs & Mafia!",
		Kind = "Weapon",
		Damage = 32,
		Range = 95,
		Cooldown = 0.36,
		Pellets = 1,
		AccentColor = Color3.fromRGB(142, 152, 174),
	},
	PepperShotgun = {
		Id = "PepperShotgun",
		DisplayName = "Pepper Shotgun",
		Icon = "💥",
		Price = 550,
		Description = "Heavy close-quarters 4-pellet scattergun (96 burst DMG!). Shreds Mafia Enforcers up close!",
		Kind = "Weapon",
		Damage = 24,
		Range = 58,
		Cooldown = 0.85,
		Pellets = 4,
		AccentColor = Color3.fromRGB(238, 92, 48),
	},
	TacticalSMG = {
		Id = "TacticalSMG",
		DisplayName = "Tactical SMG",
		Icon = "🔥",
		Price = 950,
		Description = "High-rate automatic submachine gun (22 DMG, 0.17s fire rate, 100 range). Melts Mafia Bosses!",
		Kind = "Weapon",
		Damage = 22,
		Range = 100,
		Cooldown = 0.17,
		Pellets = 1,
		AccentColor = Color3.fromRGB(238, 174, 38),
	},
	KevlarVest = {
		Id = "KevlarVest",
		DisplayName = "Kevlar Chef Armor",
		Icon = "🛡️",
		Price = 420,
		Description = "+100 Breakable Tactical Armor Shield! Absorbs bullet & melee damage before your HP until it breaks.",
		Kind = "Armor",
		AccentColor = Color3.fromRGB(48, 158, 232),
	},
	Medkit = {
		Id = "Medkit",
		DisplayName = "Flash-Spice Medkit",
		Icon = "💊",
		Price = 150,
		Description = "Instant 100% Full Heal + 6-second adrenaline speed boost! Buy anytime you're low HP.",
		Kind = "Consumable",
		AccentColor = Color3.fromRGB(54, 196, 108),
	},
} :: { [string]: BlackMarketItemSpec }

local BLACK_MARKET_WARP_POS = Vector3.new(-264, 5.5, 130)
local BLACK_MARKET_LOOK_POS = Vector3.new(-295, 5.5, 130)
local SAFE_ZONE_RADIUS = 114

local isRunning = false
local fireEv: RemoteEvent? = nil
local sfxEv: RemoteEvent? = nil
local openUiEv: RemoteEvent? = nil
local lastFireAt: { [Player]: number } = {}
local conns: { RBXScriptConnection } = {}
local charConns: { [Player]: RBXScriptConnection } = {}

local function emitCombatSFX(sfxName: string, origin: Vector3): ()
	if sfxEv then
		sfxEv:FireAllClients(sfxName, origin)
	end
end

function BlackMarketService.BroadcastSFX(sfxName: string, origin: Vector3): ()
	emitCombatSFX(sfxName, origin)
end

local function isInsideOwnBase(player: Player, pos: Vector3): boolean
	local slot = BaseService.GetPlayerBaseSlot(player)
	if not slot then return false end
	local base = BaseService.GetBaseModel(slot)
	if not base or not base.PrimaryPart then return false end
	local d = pos - base.PrimaryPart.Position
	return math.abs(d.X) <= SAFE_ZONE_RADIUS and math.abs(d.Z) <= SAFE_ZONE_RADIUS
end

function BlackMarketService.SpawnBulletTracer(fromPos: Vector3, toPos: Vector3, color: Color3): ()
	local delta = toPos - fromPos
	local len = delta.Magnitude
	if len < 0.5 then return end

	local beam = Instance.new("Part")
	beam.Name = "BulletTracer"
	beam.Size = Vector3.new(0.22, 0.22, len)
	beam.CFrame = CFrame.lookAt((fromPos + toPos) * 0.5, toPos)
	beam.Color = color
	beam.Material = Enum.Material.Neon
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Parent = Workspace

	task.delay(0.09, function()
		if beam.Parent then
			beam:Destroy()
		end
	end)
end

local function buildGunTool(weaponId: string): Tool
	local spec = BlackMarketService.ITEMS[weaponId]
	local tool = Instance.new("Tool")
	tool.Name = if spec then spec.DisplayName else weaponId
	tool.ToolTip = if spec then spec.Description else "Black Market Gun"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", weaponId)
	tool.Grip = CFrame.new(0, -0.25, 0.15)

	local darkSteel = Color3.fromRGB(38, 42, 50)
	local brushedSteel = Color3.fromRGB(116, 124, 138)
	local polymerGrip = Color3.fromRGB(24, 26, 32)
	local woodStock = Color3.fromRGB(122, 68, 36)
	local goldTrim = Color3.fromRGB(228, 176, 48)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.28, 0.92, 0.42)
	handle.Color = polymerGrip
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local function gPart(name: string, sz: Vector3, relCF: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.Color = col
		p.Material = mat
		if shape then p.Shape = shape end
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CFrame = handle.CFrame * relCF
		p.Parent = tool
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
		return p
	end

	-- Common Trigger Guard & Curved Metallic Trigger
	gPart("TriggerGuardBottom", Vector3.new(0.14, 0.08, 0.42), CFrame.new(0, 0.16, -0.34), darkSteel, Enum.Material.Metal, nil)
	gPart("TriggerGuardFront", Vector3.new(0.14, 0.28, 0.08), CFrame.new(0, 0.28, -0.52), darkSteel, Enum.Material.Metal, nil)
	gPart("Trigger", Vector3.new(0.08, 0.22, 0.10), CFrame.new(0, 0.28, -0.32) * CFrame.Angles(math.rad(22), 0, 0), brushedSteel, Enum.Material.Metal, nil)

	if weaponId == "PepperShotgun" then
		-- Realistic Pump-Action Tactical Combat Shotgun: wooden stock, receiver, twin barrel + mag tube, ribbed pump fore-end & iron sights!
		gPart("WoodStock", Vector3.new(0.32, 0.56, 1.35), CFrame.new(0, 0.28, 0.78) * CFrame.Angles(math.rad(-10), 0, 0), woodStock, Enum.Material.Wood, nil)
		gPart("ButtPad", Vector3.new(0.34, 0.62, 0.14), CFrame.new(0, 0.18, 1.44) * CFrame.Angles(math.rad(-10), 0, 0), polymerGrip, Enum.Material.SmoothPlastic, nil)
		gPart("Receiver", Vector3.new(0.36, 0.48, 1.25), CFrame.new(0, 0.52, -0.38), darkSteel, Enum.Material.Metal, nil)
		gPart("EjectionPort", Vector3.new(0.38, 0.18, 0.45), CFrame.new(0.01, 0.56, -0.45), brushedSteel, Enum.Material.Metal, nil)
		-- Upper steel barrel (Cylinder along Z via 90-deg Y rotation)
		gPart("UpperBarrel", Vector3.new(2.45, 0.24, 0.24), CFrame.new(0, 0.62, -2.15) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		-- Under-barrel shell magazine tube
		gPart("MagTube", Vector3.new(1.95, 0.22, 0.22), CFrame.new(0, 0.39, -1.90) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		-- Ribbed Wooden Pump Fore-end Grip
		gPart("PumpForeGrip", Vector3.new(0.42, 0.36, 0.92), CFrame.new(0, 0.38, -1.78), woodStock, Enum.Material.Wood, nil)
		gPart("FrontBeadSight", Vector3.new(0.08, 0.14, 0.08), CFrame.new(0, 0.78, -3.25), goldTrim, Enum.Material.Metal, nil)
		gPart("MuzzleTip", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0, 0.62, -3.38), Color3.fromRGB(18, 20, 24), Enum.Material.Metal, nil)
	elseif weaponId == "TacticalSMG" then
		-- Realistic Submachine Gun: compact receiver, curved 30-rd extended magazine, holographic optic, barrel shroud, folding stock & suppressor!
		gPart("UpperReceiver", Vector3.new(0.34, 0.46, 1.35), CFrame.new(0, 0.56, -0.42), darkSteel, Enum.Material.Metal, nil)
		gPart("GoldTrimRail", Vector3.new(0.26, 0.10, 1.28), CFrame.new(0, 0.82, -0.42), goldTrim, Enum.Material.Metal, nil)
		-- Curved Extended 30-Round Magazine
		gPart("ExtendedMag", Vector3.new(0.24, 1.05, 0.34), CFrame.new(0, -0.14, -0.78) * CFrame.Angles(math.rad(-14), 0, 0), darkSteel, Enum.Material.Metal, nil)
		gPart("MagBase", Vector3.new(0.26, 0.12, 0.38), CFrame.new(0, -0.66, -0.91) * CFrame.Angles(math.rad(-14), 0, 0), goldTrim, Enum.Material.Metal, nil)
		-- Holographic Red-Dot Sight on Top Rail
		gPart("HoloHousing", Vector3.new(0.28, 0.30, 0.42), CFrame.new(0, 0.98, -0.35), polymerGrip, Enum.Material.Metal, nil)
		gPart("HoloRedDot", Vector3.new(0.18, 0.18, 0.06), CFrame.new(0, 0.99, -0.35), Color3.fromRGB(255, 58, 58), Enum.Material.SmoothPlastic, nil)
		-- Vented Fore-end Handguard & Tactical Suppressor Barrel
		gPart("Handguard", Vector3.new(0.36, 0.38, 0.85), CFrame.new(0, 0.52, -1.48), polymerGrip, Enum.Material.Metal, nil)
		gPart("VerticalForeGrip", Vector3.new(0.22, 0.55, 0.24), CFrame.new(0, 0.12, -1.48), polymerGrip, Enum.Material.SmoothPlastic, nil)
		gPart("SuppressorBarrel", Vector3.new(1.05, 0.28, 0.28), CFrame.new(0, 0.54, -2.35) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		-- Folding Rear Tactical Stock
		gPart("StockStrut", Vector3.new(0.16, 0.18, 0.95), CFrame.new(0, 0.52, 0.72), darkSteel, Enum.Material.Metal, nil)
		gPart("StockButt", Vector3.new(0.28, 0.62, 0.16), CFrame.new(0, 0.42, 1.18), polymerGrip, Enum.Material.SmoothPlastic, nil)
		gPart("MuzzleTip", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0, 0.54, -2.88), Color3.fromRGB(18, 20, 24), Enum.Material.Metal, nil)
	else
		-- Realistic Semi-Auto Street Pistol: polymer frame, brushed steel slide, ejection port, iron sights, under-rail & magazine baseplate!
		gPart("MagBasePlate", Vector3.new(0.30, 0.10, 0.46), CFrame.new(0, -0.48, 0.02), darkSteel, Enum.Material.Metal, nil)
		gPart("LowerFrame", Vector3.new(0.28, 0.22, 1.38), CFrame.new(0, 0.42, -0.45), polymerGrip, Enum.Material.SmoothPlastic, nil)
		gPart("Slide", Vector3.new(0.30, 0.30, 1.46), CFrame.new(0, 0.64, -0.46), brushedSteel, Enum.Material.Metal, nil)
		gPart("EjectionPort", Vector3.new(0.31, 0.14, 0.36), CFrame.new(0.01, 0.68, -0.35), darkSteel, Enum.Material.Metal, nil)
		gPart("RearSight", Vector3.new(0.24, 0.09, 0.12), CFrame.new(0, 0.82, 0.18), darkSteel, Enum.Material.Metal, nil)
		gPart("FrontSight", Vector3.new(0.08, 0.09, 0.10), CFrame.new(0, 0.82, -1.10), Color3.fromRGB(255, 214, 72), Enum.Material.SmoothPlastic, nil)
		gPart("BarrelCylinder", Vector3.new(0.32, 0.18, 0.18), CFrame.new(0, 0.63, -1.26) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("MuzzleTip", Vector3.new(0.16, 0.16, 0.10), CFrame.new(0, 0.63, -1.42), Color3.fromRGB(16, 18, 22), Enum.Material.Metal, nil)
	end

	return tool
end

local function syncKevlarVestVisual(char: Model, hasArmor: boolean): ()
	local existing = char:FindFirstChild("KevlarArmorVisual")
	if not hasArmor then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	if not torso or not torso:IsA("BasePart") then
		return
	end

	local vest = Instance.new("Model")
	vest.Name = "KevlarArmorVisual"

	local function vPart(name: string, sz: Vector3, rel: CFrame, col: Color3, mat: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.Color = col
		p.Material = mat
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CFrame = torso.CFrame * rel
		p.Parent = vest
		local w = Instance.new("WeldConstraint")
		w.Part0 = torso
		w.Part1 = p
		w.Parent = p
		return p
	end

	local slateArmor = Color3.fromRGB(34, 44, 62)
	local bluePlate = Color3.fromRGB(48, 146, 224)
	vPart("ChestBody", Vector3.new(2.12, 1.65, 1.18), CFrame.new(0, 0.05, 0), slateArmor, Enum.Material.Metal)
	vPart("FrontPlate", Vector3.new(1.55, 1.15, 0.14), CFrame.new(0, 0.10, -0.58), bluePlate, Enum.Material.Metal)
	vPart("BackPlate", Vector3.new(1.55, 1.15, 0.14), CFrame.new(0, 0.10, 0.58), bluePlate, Enum.Material.Metal)
	vPart("StrapL", Vector3.new(0.42, 0.35, 1.22), CFrame.new(-0.68, 0.82, 0), slateArmor, Enum.Material.Fabric)
	vPart("StrapR", Vector3.new(0.42, 0.35, 1.22), CFrame.new(0.68, 0.82, 0), slateArmor, Enum.Material.Fabric)

	vest.Parent = char
end

local armorHookedChars: { [Model]: boolean } = {}

local function syncCharacterArmor(player: Player): ()
	local profile = PlayerDataService.GetProfile(player)
	local char = player.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not char or not hum or hum.Health <= 0 then
		return
	end

	local armor = math.clamp(math.floor(profile.Armor or 0), 0, 100)
	char:SetAttribute("Armor", armor)
	char:SetAttribute("MaxArmor", 100)
	syncKevlarVestVisual(char, armor > 0)

	local baseHp = math.clamp(hum.Health, 1, 100)
	hum.MaxHealth = 100 + armor
	hum.Health = baseHp + armor

	if not armorHookedChars[char] then
		armorHookedChars[char] = true
		local updating = false
		hum.HealthChanged:Connect(function(newHealth: number)
			if updating or not char.Parent or hum.Health <= 0 then
				return
			end
			local curArmor = math.clamp(math.floor(PlayerDataService.GetProfile(player).Armor or 0), 0, 100)
			if curArmor <= 0 then
				if hum.MaxHealth > 100 then
					updating = true
					hum.MaxHealth = 100
					updating = false
				end
				return
			end

			-- Any health above 100 is finite Armor; once chipped away, clamp MaxHealth down so Armor never auto-regenerates!
			local remainingArmor = math.clamp(math.ceil(newHealth) - 100, 0, curArmor)
			if remainingArmor < curArmor then
				updating = true
				PlayerDataService.SetArmor(player, remainingArmor)
				char:SetAttribute("Armor", remainingArmor)
				hum.MaxHealth = 100 + remainingArmor
				syncKevlarVestVisual(char, remainingArmor > 0)
				if remainingArmor == 0 then
					local remotes = ReplicatedStorage:FindFirstChild("Remotes")
					local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
					if toastEv and toastEv:IsA("RemoteEvent") then
						toastEv:FireClient(player, "🛡️ Your Kevlar Armor broke! Visit the Black Market to buy new armor!")
					end
				end
				updating = false
			end
		end)
	end
end

local function grantOwnedGearToPlayer(player: Player): ()
	local profile = PlayerDataService.GetProfile(player)
	local char = player.Character
	if char then
		syncCharacterArmor(player)
	end

	local bp = player:FindFirstChild("Backpack")
	if not bp then return end
	for weaponId, owned in pairs(profile.OwnedWeapons or {}) do
		if owned and BlackMarketService.ITEMS[weaponId] then
			local displayName = BlackMarketService.ITEMS[weaponId].DisplayName
			local hasInBp = bp:FindFirstChild(displayName) ~= nil
			local hasInChar = char ~= nil and char:FindFirstChild(displayName) ~= nil
			if not hasInBp and not hasInChar then
				local tool = buildGunTool(weaponId)
				tool.Parent = bp
			end
		end
	end
end

local function applyBulletHit(player: Player, root: BasePart, hitModel: Model, hitPos: Vector3, dmg: number): boolean
	local targetHum = hitModel:FindFirstChildOfClass("Humanoid")
	if not targetHum or targetHum.Health <= 0 then
		return false
	end

	local isRival = CollectionService:HasTag(hitModel, "RivalAIUnit")
	local isMafia = CollectionService:HasTag(hitModel, "MafiaUnit")
	local isEnemyTurfGuard = CollectionService:HasTag(hitModel, "TurfGuardUnit")
		and hitModel:GetAttribute("Faction") ~= ("Player_" .. tostring(player.UserId))
	if isRival or isMafia or isEnemyTurfGuard then
		targetHum:TakeDamage(dmg)
		emitCombatSFX("MeleeHit", hitPos)
		if targetHum.Health <= 0 then
			local isBoss = hitModel:GetAttribute("IsMafiaBoss") == true
			if isBoss then
				PlayerDataService.AddRewards(player, 220, 80, 45)
			elseif isMafia then
				PlayerDataService.AddRewards(player, 90, 35, 20)
			elseif isEnemyTurfGuard then
				PlayerDataService.AddRewards(player, 65, 25, 15)
			else
				local bountyAttr = hitModel:GetAttribute("BountyGold")
				local bounty = if typeof(bountyAttr) == "number" then bountyAttr else 45
				PlayerDataService.AddRewards(player, bounty, math.floor(bounty * 0.55), math.floor(bounty * 0.28))
			end
		end
		return true
	end

	-- PvP outside safe plazas
	local otherPlayer = Players:GetPlayerFromCharacter(hitModel)
	if otherPlayer and otherPlayer ~= player then
		if not isInsideOwnBase(otherPlayer, hitPos) and not isInsideOwnBase(player, root.Position) then
			targetHum:TakeDamage(math.floor(dmg * 0.75))
			emitCombatSFX("MeleeHit", hitPos)
			if targetHum.Health <= 0 then
				PlayerDataService.AddRewards(player, 50, 25, 15)
			end
			return true
		end
	end
	return false
end

local function findMagneticTargetAlongRay(
	shooter: Player,
	shooterRoot: BasePart,
	origin: Vector3,
	dir: Vector3,
	range: number,
	magnetRadius: number
): (Model?, Vector3?)
	local bestModel: Model? = nil
	local bestPos: Vector3? = nil
	local bestScore = math.huge

	local function consider(model: Model): ()
		local hum = model:FindFirstChildOfClass("Humanoid")
		local r = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if not hum or hum.Health <= 0 or not r or not r:IsA("BasePart") then
			return
		end
		local toTarget = r.Position - origin
		local proj = toTarget:Dot(dir)
		if proj < -2 or proj > (range + 6) then
			return
		end
		local closestPoint = origin + dir * math.clamp(proj, 0, range)
		local perpDist = (r.Position - closestPoint).Magnitude
		if perpDist <= magnetRadius then
			local score = perpDist * 3 + math.max(0, proj) * 0.12
			if score < bestScore then
				bestScore = score
				bestModel = model
				bestPos = r.Position
			end
		end
	end

	for _, m in ipairs(CollectionService:GetTagged("MafiaUnit")) do
		if m:IsA("Model") then consider(m) end
	end
	for _, m in ipairs(CollectionService:GetTagged("RivalAIUnit")) do
		if m:IsA("Model") then consider(m) end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= shooter and other.Character then
			local oRoot = other.Character:FindFirstChild("HumanoidRootPart")
			if oRoot and oRoot:IsA("BasePart") and not isInsideOwnBase(other, oRoot.Position) and not isInsideOwnBase(shooter, shooterRoot.Position) then
				consider(other.Character)
			end
		end
	end

	return bestModel, bestPos
end

local function handleWeaponFire(player: Player, weaponId: any, aimPoint: any): ()
	if typeof(weaponId) ~= "string" or typeof(aimPoint) ~= "Vector3" then
		return
	end
	local spec = BlackMarketService.ITEMS[weaponId]
	if not spec or spec.Kind ~= "Weapon" then
		return
	end
	local profile = PlayerDataService.GetProfile(player)
	if not (profile.OwnedWeapons and profile.OwnedWeapons[weaponId]) then
		return
	end

	local now = os.clock()
	local cd = spec.Cooldown or 0.35
	if lastFireAt[player] and (now - lastFireAt[player]) < (cd * 0.85) then
		return
	end
	lastFireAt[player] = now

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not char or not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then
		return
	end

	local muzzlePart = char:FindFirstChild("MuzzleTip", true)
	local origin = if muzzlePart and muzzlePart:IsA("BasePart") then muzzlePart.Position else (root.Position + Vector3.new(0, 1.5, 0))
	local range = spec.Range or 95
	local pellets = spec.Pellets or 1
	local dmg = spec.Damage or 25

	local rawDir = aimPoint - origin
	if rawDir.Magnitude < 0.2 then
		rawDir = root.CFrame.LookVector
	end
	local baseDir = rawDir.Unit

	-- Play distinct Gun Sound Effect for all nearby players!
	local sfxType = if weaponId == "PepperShotgun" then "ShotgunBlast" elseif weaponId == "TacticalSMG" then "SMGShot" else "PistolShot"
	emitCombatSFX(sfxType, origin)

	-- Exclude player character + player's own motorbike so shooting while riding never hits your own bike!
	local ignoreList: { Instance } = { char }
	for _, ch in ipairs(Workspace:GetChildren()) do
		if ch.Name == "SportMotorbike_" .. player.Name or ch.Name == "FoodEmpireGuideArrow" then
			table.insert(ignoreList, ch)
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreList

	for p = 1, pellets do
		local spread = if pellets > 1 then 0.075 else 0.014
		local dir = (baseDir + Vector3.new((math.random() - 0.5) * spread, (math.random() - 0.5) * spread, (math.random() - 0.5) * spread)).Unit
		local result = Workspace:Raycast(origin, dir * range, rayParams)
		local hitPos = if result then result.Position else (origin + dir * range)
		local didHit = false

		if result and result.Instance then
			local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
			if hitModel then
				didHit = applyBulletHit(player, root, hitModel, hitPos, dmg)
			end
		end

		BlackMarketService.SpawnBulletTracer(origin, hitPos, if didHit then Color3.fromRGB(255, 118, 62) else Color3.fromRGB(255, 224, 92))
	end
end

function BlackMarketService.BuyItem(player: Player, itemId: string): (boolean, string)
	local spec = BlackMarketService.ITEMS[itemId]
	if not spec then
		return false, "Unknown Black Market item!"
	end

	local profile = PlayerDataService.GetProfile(player)
	if spec.Kind == "Weapon" and profile.OwnedWeapons and profile.OwnedWeapons[itemId] then
		grantOwnedGearToPlayer(player)
		return true, spec.DisplayName .. " equipped to your hotbar!"
	end
	if spec.Kind == "Armor" and (profile.Armor or 0) >= 100 then
		return false, "Your Kevlar Armor is already full (100 / 100)!"
	end

	if not PlayerDataService.SpendCoins(player, spec.Price) then
		return false, string.format("Need %d Gold to buy %s!", spec.Price, spec.DisplayName)
	end

	if spec.Kind == "Weapon" then
		PlayerDataService.UnlockWeapon(player, itemId)
		grantOwnedGearToPlayer(player)
		return true, string.format("%s %s bought! Equip from hotbar & click to shoot!", spec.Icon, spec.DisplayName)
	elseif spec.Kind == "Armor" then
		PlayerDataService.SetArmor(player, 100)
		syncCharacterArmor(player)
		return true, "🛡️ Kevlar Chef Armor equipped (100 / 100 Armor)! Absorbs damage until broken!"
	else
		-- Medkit consumable (heals Base 100 HP + speed boost without giving free armor!)
		local char = player.Character
		local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if hum and hum.Health > 0 then
			local curArmor = math.clamp(math.floor(profile.Armor or 0), 0, 100)
			hum.MaxHealth = 100 + curArmor
			hum.Health = 100 + curArmor
			local origSpeed = hum.WalkSpeed
			hum.WalkSpeed = math.max(origSpeed, 28)
			task.delay(6, function()
				if hum.Parent and hum.WalkSpeed == 28 then
					hum.WalkSpeed = 16
				end
			end)
		end
		return true, "💊 Flash-Spice Medkit used! Full HP + Speed Boost!"
	end
end

function BlackMarketService.TeleportToBlackMarket(player: Player): (boolean, string)
	local char = player.Character
	if not char then
		return false, "Character unavailable"
	end
	local warpPos = BLACK_MARKET_WARP_POS
	local lookPos = BLACK_MARKET_LOOK_POS
	local map = Workspace:FindFirstChild("FoodEmpireMap")
	local bm = if map then map:FindFirstChild("BlackMarketOutpost") else nil
	if bm and bm:IsA("Model") then
		local bmCF = bm:GetPivot()
		lookPos = bmCF.Position + Vector3.new(0, 4.3, 0)
		warpPos = (bmCF * CFrame.new(0, 4.3, 24)).Position
	end
	pcall(function()
		player:RequestStreamAroundAsync(warpPos)
	end)
	char:PivotTo(CFrame.lookAt(warpPos, lookPos))
	return true, "🕶️ Arrived at the Underground Black Market! Buy guns & gear now!"
end

function BlackMarketService.GetCatalogPayload(player: Player): { [string]: any }
	local profile = PlayerDataService.GetProfile(player)
	local armor = math.clamp(math.floor(profile.Armor or 0), 0, 100)
	return {
		OwnedWeapons = profile.OwnedWeapons or {},
		HasKevlarVest = armor > 0,
		Armor = armor,
	}
end

function BlackMarketService.Start(): ()
	if isRunning then return end
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
		if ex and ex:IsA("RemoteEvent") then return ex end
		local c = Instance.new("RemoteEvent")
		c.Name = name
		c.Parent = remotes
		return c
	end

	fireEv = ensureRemote("WeaponFire")
	sfxEv = ensureRemote("CombatSFX")
	openUiEv = ensureRemote("OpenBlackMarketUI")

	if fireEv then
		table.insert(conns, fireEv.OnServerEvent:Connect(handleWeaponFire))
	end

	-- Wire 3D Black Market Dealer ProximityPrompt
	local map = Workspace:FindFirstChild("FoodEmpireMap")
	local bm = if map then map:FindFirstChild("BlackMarketOutpost") else nil
	local prompt = if bm then bm:FindFirstChild("OpenBlackMarketPrompt", true) else nil
	if prompt and prompt:IsA("ProximityPrompt") then
		table.insert(
			conns,
			prompt.Triggered:Connect(function(player)
				if openUiEv then
					openUiEv:FireClient(player)
				end
			end)
		)
	end

	local function hookPlayer(player: Player)
		if charConns[player] then charConns[player]:Disconnect() end
		charConns[player] = player.CharacterAdded:Connect(function()
			task.delay(0.4, function()
				if player.Parent then
					grantOwnedGearToPlayer(player)
				end
			end)
		end)
		if player.Character then
			grantOwnedGearToPlayer(player)
		end
	end

	table.insert(conns, Players.PlayerAdded:Connect(hookPlayer))
	table.insert(
		conns,
		Players.PlayerRemoving:Connect(function(p)
			lastFireAt[p] = nil
			if charConns[p] then charConns[p]:Disconnect(); charConns[p] = nil end
		end)
	)
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayer(p)
	end

	print("[Food Empire] BlackMarketService started (Underground Guns, Kevlar Vest, Medkit & CombatSFX ready)!")
end

function BlackMarketService.Stop(): ()
	isRunning = false
	for _, c in ipairs(conns) do c:Disconnect() end
	table.clear(conns)
	for p, c in pairs(charConns) do c:Disconnect(); charConns[p] = nil end
end

return BlackMarketService
