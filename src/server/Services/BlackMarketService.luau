--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WeaponConfig = require(
	ReplicatedStorage:WaitForChild("shared"):WaitForChild("config"):WaitForChild("WeaponConfig")
)
local PlayerDataService = require("./PlayerDataService")
local BaseService = require("./BaseService")
local MonetizationService = require("./MonetizationService")
local SyndicateContractService = require("./SyndicateContractService")

export type BlackMarketItemSpec = {
	Id: string,
	DisplayName: string,
	Icon: string,
	Price: number,
	RobuxItemId: string?,
	RobuxPrice: number?,
	RequiredLevel: number?,
	Category: string?,
	Rarity: string?,
	Description: string,
	Kind: "Weapon" | "Armor" | "Consumable",
	Damage: number?,
	Range: number?,
	Cooldown: number?,
	Pellets: number?,
	Spread: number?,
	AmmoType: WeaponConfig.AmmoTypeId?,
	AmmoLabel: string?,
	ReloadStyle: ("Magazine" | "ShellByShell")?,
	MagSize: number?,
	ReserveMax: number?,
	ReloadTime: number?,
	ShellStartTime: number?,
	ShellLoadTime: number?,
	ShellFinishTime: number?,
	AudioKey: ("PistolShot" | "ShotgunBlast" | "SMGShot")?,
	ModelStyle: string?,
	AccentColor: Color3,
}

local BlackMarketService = {}

BlackMarketService.ORDER = {} :: { string }
BlackMarketService.ITEMS = {} :: { [string]: BlackMarketItemSpec }

-- Populate all weapons from shared WeaponConfig so server & client never drift
for _, weaponId in ipairs(WeaponConfig.WEAPON_ORDER) do
	local w = WeaponConfig.WEAPONS[weaponId]
	if w then
		local ammoSpec = WeaponConfig.AMMO_TYPES[w.AmmoType]
		table.insert(BlackMarketService.ORDER, weaponId)
		BlackMarketService.ITEMS[weaponId] = {
			Id = w.Id,
			DisplayName = w.DisplayName,
			Icon = w.Icon,
			Price = w.Price,
			RobuxItemId = w.RobuxItemId,
			RobuxPrice = w.RobuxPrice,
			RequiredLevel = w.RequiredLevel,
			Category = w.Category,
			Rarity = w.Rarity,
			Description = w.Description,
			Kind = "Weapon",
			Damage = w.Damage,
			Range = w.Range,
			Cooldown = w.Cooldown,
			Pellets = w.Pellets,
			Spread = w.Spread,
			AmmoType = w.AmmoType,
			AmmoLabel = if ammoSpec then ammoSpec.ShortName else w.AmmoType,
			ReloadStyle = w.ReloadType,
			MagSize = w.MagSize,
			ReserveMax = if ammoSpec then ammoSpec.MaxReserve else 96,
			ReloadTime = w.ReloadTime,
			ShellStartTime = 0.20,
			ShellLoadTime = w.ReloadTime,
			ShellFinishTime = w.ShellFinishTime or 0.24,
			AudioKey = w.AudioKey,
			ModelStyle = w.ModelStyle,
			AccentColor = w.AccentColor,
		}
	end
end

-- Add Player Tactical Protection & Healing Items
table.insert(BlackMarketService.ORDER, "KevlarVest")
BlackMarketService.ITEMS.KevlarVest = {
	Id = "KevlarVest",
	DisplayName = "Kevlar Chef Armor",
	Icon = "ARMOR",
	Price = 420,
	RequiredLevel = 1,
	Category = "Armor",
	Rarity = "Rare",
	Description = "+100 Breakable Tactical Armor Shield. Absorbs bullet and melee damage before HP until depleted.",
	Kind = "Armor",
	AccentColor = Color3.fromRGB(68, 108, 148),
}

table.insert(BlackMarketService.ORDER, "Medkit")
BlackMarketService.ITEMS.Medkit = {
	Id = "Medkit",
	DisplayName = "Flash-Spice Medkit",
	Icon = "MED",
	Price = 150,
	RequiredLevel = 1,
	Category = "Consumable",
	Rarity = "Common",
	Description = "Instant 100% Full Heal + 6-second adrenaline speed boost. Available anytime at low HP.",
	Kind = "Consumable",
	AccentColor = Color3.fromRGB(68, 128, 86),
}

local BLACK_MARKET_WARP_POS = Vector3.new(-264, 5.5, 130)
local BLACK_MARKET_LOOK_POS = Vector3.new(-295, 5.5, 130)
local SAFE_ZONE_RADIUS = 114

local isRunning = false
local fireEv: RemoteEvent? = nil
local reloadEv: RemoteEvent? = nil
local ammoSyncEv: RemoteEvent? = nil
local sfxEv: RemoteEvent? = nil
local openUiEv: RemoteEvent? = nil
local lastFireAt: { [Player]: number } = {}
local conns: { RBXScriptConnection } = {}
local charConns: { [Player]: RBXScriptConnection } = {}
local charRemoveConns: { [Player]: RBXScriptConnection } = {}

type WeaponMagState = {
	Mag: number,
	Reloading: boolean,
	ReloadToken: number,
}

-- Loaded magazine state per weapon; shared caliber reserves live authoritatively in PlayerDataService.AmmoInventory!
local playerMagState: { [Player]: { [string]: WeaponMagState } } = {}

local KILL_SCAVENGE_AMMO: { [WeaponConfig.AmmoTypeId]: number } = {
	Pistol9mm = 6,
	Shotgun12G = 2,
	SMG45 = 12,
	Rifle556 = 10,
	Sniper308 = 2,
}

local function emitCombatSFX(sfxName: string, origin: Vector3, excludePlayer: Player?): ()
	if not sfxEv then
		return
	end
	if excludePlayer then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= excludePlayer then
				sfxEv:FireClient(p, sfxName, origin)
			end
		end
	else
		sfxEv:FireAllClients(sfxName, origin)
	end
end

function BlackMarketService.BroadcastSFX(sfxName: string, origin: Vector3): ()
	emitCombatSFX(sfxName, origin, nil)
end

local function playerOwnsWeapon(player: Player, weaponId: string): boolean
	local spec = BlackMarketService.ITEMS[weaponId]
	if not spec or spec.Kind ~= "Weapon" then
		return false
	end
	local profile = PlayerDataService.GetProfile(player)
	if profile.OwnedWeapons and profile.OwnedWeapons[weaponId] then
		return true
	end
	if spec.RobuxItemId and MonetizationService.HasPass(player, spec.RobuxItemId) then
		PlayerDataService.UnlockWeapon(player, weaponId)
		return true
	end
	return false
end

local function getReserveForWeapon(player: Player, spec: BlackMarketItemSpec): (number, number)
	local ammoType = spec.AmmoType or "Pistol9mm"
	local ammoSpec = WeaponConfig.AMMO_TYPES[ammoType]
	local maxRes = if ammoSpec then ammoSpec.MaxReserve else (spec.ReserveMax or 96)
	local cur = math.clamp(PlayerDataService.GetAmmo(player, ammoType), 0, maxRes)
	return cur, maxRes
end

local function getEffectiveMagSize(player: Player, weaponId: string, spec: BlackMarketItemSpec): number
	local baseMag = spec.MagSize or 12
	if PlayerDataService.HasWeaponMod(player, weaponId, "ExtendedMag") then
		return math.max(baseMag + 2, math.ceil(baseMag * 1.5))
	end
	return baseMag
end

local function ensureWeaponMag(player: Player, weaponId: string): WeaponMagState?
	local spec = BlackMarketService.ITEMS[weaponId]
	if not spec or spec.Kind ~= "Weapon" then
		return nil
	end
	local byWeapon = playerMagState[player]
	if not byWeapon then
		byWeapon = {}
		playerMagState[player] = byWeapon
	end
	local st = byWeapon[weaponId]
	if not st then
		st = {
			Mag = getEffectiveMagSize(player, weaponId, spec),
			Reloading = false,
			ReloadToken = 0,
		}
		byWeapon[weaponId] = st
	end
	return st
end

local function findPlayerWeaponTool(player: Player, weaponId: string): Tool?
	local char = player.Character
	if char then
		for _, ch in ipairs(char:GetChildren()) do
			if ch:IsA("Tool") and ch:GetAttribute("WeaponId") == weaponId then
				return ch
			end
		end
	end
	local bp = player:FindFirstChild("Backpack")
	if bp then
		for _, ch in ipairs(bp:GetChildren()) do
			if ch:IsA("Tool") and ch:GetAttribute("WeaponId") == weaponId then
				return ch
			end
		end
	end
	return nil
end

local function getEquippedWeaponIdForPlayer(player: Player): string?
	local char = player.Character
	if not char then
		return nil
	end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then
		return nil
	end
	local wid = tool:GetAttribute("WeaponId")
	if typeof(wid) == "string" then
		return wid
	end
	return nil
end

local function syncToolGunsmithAttachments(player: Player, weaponId: string, tool: Tool): ()
	local hasSup = PlayerDataService.HasWeaponMod(player, weaponId, "Suppressor")
	local hasExt = PlayerDataService.HasWeaponMod(player, weaponId, "ExtendedMag")
	local hasHvy = PlayerDataService.HasWeaponMod(player, weaponId, "HeavyBarrel")
	tool:SetAttribute("Mod_Suppressor", hasSup)
	tool:SetAttribute("Mod_ExtendedMag", hasExt)
	tool:SetAttribute("Mod_HeavyBarrel", hasHvy)

	if hasSup and not tool:FindFirstChild("GunsmithSuppressor") then
		local handle = tool:FindFirstChild("Handle")
		local muzzle = tool:FindFirstChild("MuzzleTip")
		if handle and handle:IsA("BasePart") and muzzle and muzzle:IsA("BasePart") then
			local sup = Instance.new("Part")
			sup.Name = "GunsmithSuppressor"
			sup.Shape = Enum.PartType.Cylinder
			sup.Size = Vector3.new(0.92, 0.28, 0.28)
			sup.Color = Color3.fromRGB(22, 24, 30)
			sup.Material = Enum.Material.Metal
			sup.CanCollide = false
			sup.CanTouch = false
			sup.CanQuery = false
			sup.Massless = true
			sup.CFrame = muzzle.CFrame * CFrame.new(0, 0, -0.42) * CFrame.Angles(0, math.rad(90), 0)
			sup.Parent = tool
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = sup
			w.Parent = sup
		end
	end
end

local function syncToolAmmoAttributes(player: Player, weaponId: string): ()
	local spec = BlackMarketService.ITEMS[weaponId]
	local st = ensureWeaponMag(player, weaponId)
	local tool = findPlayerWeaponTool(player, weaponId)
	if not spec or not st or not tool then
		return
	end
	local reserve, reserveMax = getReserveForWeapon(player, spec)
	local maxMag = getEffectiveMagSize(player, weaponId, spec)
	tool:SetAttribute("AmmoMag", st.Mag)
	tool:SetAttribute("AmmoMaxMag", maxMag)
	tool:SetAttribute("AmmoReserve", reserve)
	tool:SetAttribute("AmmoReserveMax", reserveMax)
	tool:SetAttribute("AmmoType", spec.AmmoType or "Pistol9mm")
	tool:SetAttribute("AmmoLabel", spec.AmmoLabel or "9mm")
	tool:SetAttribute("ReloadStyle", spec.ReloadStyle or "Magazine")
	tool:SetAttribute("IsReloading", st.Reloading)
	syncToolGunsmithAttachments(player, weaponId, tool)
end

local function sendWeaponAmmoSync(
	player: Player,
	eventType: string,
	weaponId: string,
	extra: { [string]: any }?
): ()
	local spec = BlackMarketService.ITEMS[weaponId]
	local st = ensureWeaponMag(player, weaponId)
	if not ammoSyncEv or not spec or not st or not player.Parent then
		return
	end
	local reserve, reserveMax = getReserveForWeapon(player, spec)
	local maxMag = getEffectiveMagSize(player, weaponId, spec)
	local payload: { [string]: any } = {
		Type = eventType,
		WeaponId = weaponId,
		Mag = st.Mag,
		MaxMag = maxMag,
		Reserve = reserve,
		ReserveMax = reserveMax,
		AmmoType = spec.AmmoType or "Pistol9mm",
		AmmoLabel = spec.AmmoLabel or "9mm",
		ReloadStyle = spec.ReloadStyle or "Magazine",
		IsReloading = st.Reloading,
	}
	if extra then
		for k, v in pairs(extra) do
			payload[k] = v
		end
	end
	ammoSyncEv:FireClient(player, payload)
end

local function syncAllWeaponsForAmmoType(player: Player, ammoType: WeaponConfig.AmmoTypeId, skipWeaponId: string?): ()
	for _, weaponId in ipairs(WeaponConfig.WEAPON_ORDER) do
		local spec = BlackMarketService.ITEMS[weaponId]
		if spec and spec.AmmoType == ammoType and playerOwnsWeapon(player, weaponId) then
			syncToolAmmoAttributes(player, weaponId)
			if weaponId ~= skipWeaponId then
				sendWeaponAmmoSync(player, "Update", weaponId, nil)
			end
		end
	end
end

local function sendFullAmmoSync(player: Player): ()
	if not ammoSyncEv or not player.Parent then
		return
	end
	local weaponsPayload: { [string]: any } = {}
	for _, weaponId in ipairs(WeaponConfig.WEAPON_ORDER) do
		local spec = BlackMarketService.ITEMS[weaponId]
		if spec and playerOwnsWeapon(player, weaponId) then
			local st = ensureWeaponMag(player, weaponId)
			if st then
				syncToolAmmoAttributes(player, weaponId)
				local reserve, reserveMax = getReserveForWeapon(player, spec)
				local maxMag = getEffectiveMagSize(player, weaponId, spec)
				weaponsPayload[weaponId] = {
					Mag = st.Mag,
					MaxMag = maxMag,
					Reserve = reserve,
					ReserveMax = reserveMax,
					AmmoType = spec.AmmoType or "Pistol9mm",
					AmmoLabel = spec.AmmoLabel or "9mm",
					ReloadStyle = spec.ReloadStyle or "Magazine",
					IsReloading = st.Reloading,
				}
			end
		end
	end
	ammoSyncEv:FireClient(player, {
		Type = "Full",
		Weapons = weaponsPayload,
	})
end

local function cancelReload(player: Player, weaponId: string, notifyClient: boolean): ()
	local byWeapon = playerMagState[player]
	if not byWeapon then
		return
	end
	local st = byWeapon[weaponId]
	if not st or not st.Reloading then
		return
	end
	st.Reloading = false
	st.ReloadToken += 1
	syncToolAmmoAttributes(player, weaponId)
	if notifyClient then
		sendWeaponAmmoSync(player, "ReloadCancel", weaponId, nil)
	end
end

local function cancelAllReloads(player: Player, notifyClient: boolean): ()
	local byWeapon = playerMagState[player]
	if not byWeapon then
		return
	end
	for weaponId, st in pairs(byWeapon) do
		if st.Reloading then
			st.Reloading = false
			st.ReloadToken += 1
			syncToolAmmoAttributes(player, weaponId)
			if notifyClient then
				sendWeaponAmmoSync(player, "ReloadCancel", weaponId, nil)
			end
		end
	end
end

local function grantKillAmmoBonus(player: Player, usedWeaponId: string?): ()
	local ammoType: WeaponConfig.AmmoTypeId = "Pistol9mm"
	if usedWeaponId then
		local spec = BlackMarketService.ITEMS[usedWeaponId]
		if spec and spec.AmmoType then
			ammoType = spec.AmmoType
		end
	end
	local ammoSpec = WeaponConfig.AMMO_TYPES[ammoType]
	if not ammoSpec then
		return
	end
	local bonus = KILL_SCAVENGE_AMMO[ammoType] or 6
	local before = PlayerDataService.GetAmmo(player, ammoType)
	if before < ammoSpec.MaxReserve then
		PlayerDataService.AddAmmo(player, ammoType, bonus, ammoSpec.MaxReserve)
		syncAllWeaponsForAmmoType(player, ammoType, nil)
	end
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
	beam.Size = Vector3.new(0.20, 0.20, len)
	beam.CFrame = CFrame.lookAt((fromPos + toPos) * 0.5, toPos)
	beam.Color = color
	beam.Material = Enum.Material.Neon
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Parent = Workspace

	task.delay(0.085, function()
		if beam.Parent then
			beam:Destroy()
		end
	end)
end

-- Preserves existing StreetPistol, PepperShotgun & TacticalSMG models intact,
-- and builds distinct sculpted realistic models for the 6 new expansion weapons!
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
	local chromeSilver = Color3.fromRGB(196, 204, 216)
	local polymerGrip = Color3.fromRGB(24, 26, 32)
	local woodStock = Color3.fromRGB(122, 68, 36)
	local goldTrim = Color3.fromRGB(228, 176, 48)
	local crimsonAccent = Color3.fromRGB(218, 38, 56)
	local oliveTactical = Color3.fromRGB(58, 68, 56)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.28, 0.92, 0.42)
	handle.Color = if weaponId == "GoldenEmperorPistol" then Color3.fromRGB(242, 236, 224) else polymerGrip
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
		-- Preserved Existing Pepper Shotgun Model
		gPart("WoodStock", Vector3.new(0.32, 0.56, 1.35), CFrame.new(0, 0.28, 0.78) * CFrame.Angles(math.rad(-10), 0, 0), woodStock, Enum.Material.Wood, nil)
		gPart("ButtPad", Vector3.new(0.34, 0.62, 0.14), CFrame.new(0, 0.18, 1.44) * CFrame.Angles(math.rad(-10), 0, 0), polymerGrip, Enum.Material.SmoothPlastic, nil)
		gPart("Receiver", Vector3.new(0.36, 0.48, 1.25), CFrame.new(0, 0.52, -0.38), darkSteel, Enum.Material.Metal, nil)
		gPart("EjectionPort", Vector3.new(0.38, 0.18, 0.45), CFrame.new(0.01, 0.56, -0.45), brushedSteel, Enum.Material.Metal, nil)
		gPart("UpperBarrel", Vector3.new(2.45, 0.24, 0.24), CFrame.new(0, 0.62, -2.15) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("MagTube", Vector3.new(1.95, 0.22, 0.22), CFrame.new(0, 0.39, -1.90) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("PumpForeGrip", Vector3.new(0.42, 0.36, 0.92), CFrame.new(0, 0.38, -1.78), woodStock, Enum.Material.Wood, nil)
		gPart("FrontBeadSight", Vector3.new(0.08, 0.14, 0.08), CFrame.new(0, 0.78, -3.25), goldTrim, Enum.Material.Metal, nil)
		gPart("MuzzleTip", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0, 0.62, -3.38), Color3.fromRGB(18, 20, 24), Enum.Material.Metal, nil)
	elseif weaponId == "TacticalSMG" then
		-- Preserved Existing Tactical SMG Model
		gPart("UpperReceiver", Vector3.new(0.34, 0.46, 1.35), CFrame.new(0, 0.56, -0.42), darkSteel, Enum.Material.Metal, nil)
		gPart("GoldTrimRail", Vector3.new(0.26, 0.10, 1.28), CFrame.new(0, 0.82, -0.42), goldTrim, Enum.Material.Metal, nil)
		gPart("ExtendedMag", Vector3.new(0.24, 1.05, 0.34), CFrame.new(0, -0.14, -0.78) * CFrame.Angles(math.rad(-14), 0, 0), darkSteel, Enum.Material.Metal, nil)
		gPart("MagBase", Vector3.new(0.26, 0.12, 0.38), CFrame.new(0, -0.66, -0.91) * CFrame.Angles(math.rad(-14), 0, 0), goldTrim, Enum.Material.Metal, nil)
		gPart("HoloHousing", Vector3.new(0.28, 0.30, 0.42), CFrame.new(0, 0.98, -0.35), polymerGrip, Enum.Material.Metal, nil)
		gPart("HoloRedDot", Vector3.new(0.18, 0.18, 0.06), CFrame.new(0, 0.99, -0.35), Color3.fromRGB(255, 58, 58), Enum.Material.SmoothPlastic, nil)
		gPart("Handguard", Vector3.new(0.36, 0.38, 0.85), CFrame.new(0, 0.52, -1.48), polymerGrip, Enum.Material.Metal, nil)
		gPart("VerticalForeGrip", Vector3.new(0.22, 0.55, 0.24), CFrame.new(0, 0.12, -1.48), polymerGrip, Enum.Material.SmoothPlastic, nil)
		gPart("SuppressorBarrel", Vector3.new(1.05, 0.28, 0.28), CFrame.new(0, 0.54, -2.35) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("StockStrut", Vector3.new(0.16, 0.18, 0.95), CFrame.new(0, 0.52, 0.72), darkSteel, Enum.Material.Metal, nil)
		gPart("StockButt", Vector3.new(0.28, 0.62, 0.16), CFrame.new(0, 0.42, 1.18), polymerGrip, Enum.Material.SmoothPlastic, nil)
		gPart("MuzzleTip", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0, 0.54, -2.88), Color3.fromRGB(18, 20, 24), Enum.Material.Metal, nil)
	elseif weaponId == "SilencedDeagle" then
		-- Enforcer Heavy Pistol: Brushed chrome heavy slide, ventilated rail, tactical suppressor & laser unit
		gPart("MagBasePlate", Vector3.new(0.32, 0.12, 0.48), CFrame.new(0, -0.49, 0.02), chromeSilver, Enum.Material.Metal, nil)
		gPart("LowerFrame", Vector3.new(0.30, 0.25, 1.62), CFrame.new(0, 0.43, -0.56), darkSteel, Enum.Material.Metal, nil)
		gPart("HeavySlide", Vector3.new(0.34, 0.36, 1.72), CFrame.new(0, 0.68, -0.58), chromeSilver, Enum.Material.Metal, nil)
		gPart("EjectionPort", Vector3.new(0.35, 0.16, 0.42), CFrame.new(0.01, 0.72, -0.35), darkSteel, Enum.Material.Metal, nil)
		gPart("UnderLaser", Vector3.new(0.24, 0.16, 0.54), CFrame.new(0, 0.26, -1.04), polymerGrip, Enum.Material.Metal, nil)
		gPart("Suppressor", Vector3.new(0.95, 0.24, 0.24), CFrame.new(0, 0.66, -1.88) * CFrame.Angles(0, math.rad(90), 0), polymerGrip, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("FrontSight", Vector3.new(0.08, 0.11, 0.10), CFrame.new(0, 0.90, -1.34), Color3.fromRGB(58, 178, 255), Enum.Material.Neon, nil)
		gPart("MuzzleTip", Vector3.new(0.20, 0.20, 0.10), CFrame.new(0, 0.66, -2.38), Color3.fromRGB(16, 18, 22), Enum.Material.Metal, nil)
	elseif weaponId == "AutoCombatShotgun" then
		-- Breacher Combat Shotgun: Matte black tactical frame, heat-shield barrel, extended 8-shell tube & rail optic
		gPart("TacStock", Vector3.new(0.34, 0.60, 1.30), CFrame.new(0, 0.34, 0.80), polymerGrip, Enum.Material.SmoothPlastic, nil)
		gPart("Receiver", Vector3.new(0.40, 0.54, 1.40), CFrame.new(0, 0.54, -0.42), darkSteel, Enum.Material.Metal, nil)
		gPart("TopRail", Vector3.new(0.24, 0.08, 1.35), CFrame.new(0, 0.84, -0.48), brushedSteel, Enum.Material.Metal, nil)
		gPart("ReflexOptic", Vector3.new(0.28, 0.26, 0.40), CFrame.new(0, 0.99, -0.32), polymerGrip, Enum.Material.Metal, nil)
		gPart("HeatShield", Vector3.new(0.34, 0.28, 1.95), CFrame.new(0, 0.64, -2.02), darkSteel, Enum.Material.Metal, nil)
		gPart("ExtendedTube", Vector3.new(2.25, 0.26, 0.26), CFrame.new(0, 0.38, -2.05) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("RibbedPump", Vector3.new(0.46, 0.38, 1.05), CFrame.new(0, 0.38, -1.78), polymerGrip, Enum.Material.SmoothPlastic, nil)
		gPart("VioletStripe", Vector3.new(0.42, 0.10, 0.85), CFrame.new(0, 0.56, -0.45), Color3.fromRGB(168, 74, 236), Enum.Material.Metal, nil)
		gPart("MuzzleTip", Vector3.new(0.28, 0.28, 0.14), CFrame.new(0, 0.64, -3.22), Color3.fromRGB(18, 20, 24), Enum.Material.Metal, nil)
	elseif weaponId == "SyndicateCarbine" then
		-- Syndicate 5.56 Carbine: Full tactical AR receiver, rail handguard, curved 5.56 mag, buffer stock & red-dot
		gPart("BufferTube", Vector3.new(0.95, 0.24, 0.24), CFrame.new(0, 0.56, 0.68) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("CarbineStock", Vector3.new(0.32, 0.72, 0.56), CFrame.new(0, 0.44, 1.18), oliveTactical, Enum.Material.SmoothPlastic, nil)
		gPart("UpperReceiver", Vector3.new(0.36, 0.50, 1.48), CFrame.new(0, 0.56, -0.46), darkSteel, Enum.Material.Metal, nil)
		gPart("RifleMag", Vector3.new(0.24, 1.10, 0.42), CFrame.new(0, -0.18, -0.84) * CFrame.Angles(math.rad(-16), 0, 0), polymerGrip, Enum.Material.Metal, nil)
		gPart("RailHandguard", Vector3.new(0.38, 0.42, 1.38), CFrame.new(0, 0.56, -1.84), oliveTactical, Enum.Material.Metal, nil)
		gPart("AngledGrip", Vector3.new(0.22, 0.42, 0.34), CFrame.new(0, 0.22, -1.78) * CFrame.Angles(math.rad(24), 0, 0), polymerGrip, Enum.Material.SmoothPlastic, nil)
		gPart("AcogScope", Vector3.new(0.68, 0.30, 0.30), CFrame.new(0, 0.96, -0.42) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("Barrel", Vector3.new(1.15, 0.20, 0.20), CFrame.new(0, 0.58, -3.02) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("MuzzleTip", Vector3.new(0.24, 0.24, 0.16), CFrame.new(0, 0.58, -3.62), darkSteel, Enum.Material.Metal, nil)
	elseif weaponId == "ShadowSniper" then
		-- Shadow .308 Sniper: Long precision chassis, high-magnification scope, bolt handle, fluted barrel & muzzle brake
		gPart("SniperStock", Vector3.new(0.34, 0.68, 1.45), CFrame.new(0, 0.40, 0.92), polymerGrip, Enum.Material.SmoothPlastic, nil)
		gPart("CheekRiser", Vector3.new(0.36, 0.22, 0.72), CFrame.new(0, 0.78, 0.84), darkSteel, Enum.Material.SmoothPlastic, nil)
		gPart("ChassisBody", Vector3.new(0.38, 0.48, 2.25), CFrame.new(0, 0.54, -0.82), darkSteel, Enum.Material.Metal, nil)
		gPart("BoxMag", Vector3.new(0.26, 0.65, 0.48), CFrame.new(0, 0.04, -0.78), brushedSteel, Enum.Material.Metal, nil)
		gPart("BoltKnob", Vector3.new(0.36, 0.12, 0.12), CFrame.new(0.28, 0.62, -0.18), chromeSilver, Enum.Material.Metal, nil)
		gPart("ScopeTube", Vector3.new(1.48, 0.26, 0.26), CFrame.new(0, 1.02, -0.62) * CFrame.Angles(0, math.rad(90), 0), polymerGrip, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("ScopeLens", Vector3.new(0.32, 0.34, 0.34), CFrame.new(0, 1.02, -1.40) * CFrame.Angles(0, math.rad(90), 0), goldTrim, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("LongBarrel", Vector3.new(2.25, 0.22, 0.22), CFrame.new(0, 0.60, -2.98) * CFrame.Angles(0, math.rad(90), 0), brushedSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("MuzzleBrake", Vector3.new(0.32, 0.28, 0.38), CFrame.new(0, 0.60, -4.18), darkSteel, Enum.Material.Metal, nil)
		gPart("MuzzleTip", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0, 0.60, -4.40), Color3.fromRGB(16, 18, 22), Enum.Material.Metal, nil)
	elseif weaponId == "GoldenEmperorPistol" then
		-- Mythic 24K Gold Precision Pistol with Ivory Grip & Gold Compensator
		gPart("MagBasePlate", Vector3.new(0.32, 0.12, 0.48), CFrame.new(0, -0.49, 0.02), goldTrim, Enum.Material.Metal, nil)
		gPart("LowerFrame", Vector3.new(0.30, 0.24, 1.48), CFrame.new(0, 0.42, -0.50), darkSteel, Enum.Material.Metal, nil)
		gPart("GoldSlide", Vector3.new(0.32, 0.34, 1.58), CFrame.new(0, 0.66, -0.52), goldTrim, Enum.Material.Metal, nil)
		gPart("Compensator", Vector3.new(0.32, 0.32, 0.38), CFrame.new(0, 0.66, -1.46), goldTrim, Enum.Material.Metal, nil)
		gPart("FrontSight", Vector3.new(0.09, 0.11, 0.11), CFrame.new(0, 0.88, -1.48), Color3.fromRGB(255, 226, 94), Enum.Material.Neon, nil)
		gPart("MuzzleTip", Vector3.new(0.18, 0.18, 0.10), CFrame.new(0, 0.66, -1.68), Color3.fromRGB(22, 20, 18), Enum.Material.Metal, nil)
	elseif weaponId == "CrimsonDragonAR" then
		-- Mythic Crimson-Gold 5.56mm Custom Assault Rifle
		gPart("BufferTube", Vector3.new(0.95, 0.24, 0.24), CFrame.new(0, 0.56, 0.68) * CFrame.Angles(0, math.rad(90), 0), darkSteel, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("DragonStock", Vector3.new(0.34, 0.72, 0.58), CFrame.new(0, 0.44, 1.18), crimsonAccent, Enum.Material.Metal, nil)
		gPart("UpperReceiver", Vector3.new(0.38, 0.52, 1.52), CFrame.new(0, 0.56, -0.46), darkSteel, Enum.Material.Metal, nil)
		gPart("CrimsonAccent", Vector3.new(0.40, 0.16, 1.42), CFrame.new(0, 0.68, -0.48), crimsonAccent, Enum.Material.Metal, nil)
		gPart("ExtendedDragonMag", Vector3.new(0.24, 1.24, 0.44), CFrame.new(0, -0.22, -0.84) * CFrame.Angles(math.rad(-16), 0, 0), crimsonAccent, Enum.Material.Metal, nil)
		gPart("GoldMagBase", Vector3.new(0.28, 0.14, 0.48), CFrame.new(0, -0.84, -1.02) * CFrame.Angles(math.rad(-16), 0, 0), goldTrim, Enum.Material.Metal, nil)
		gPart("RailHandguard", Vector3.new(0.40, 0.44, 1.45), CFrame.new(0, 0.56, -1.86), darkSteel, Enum.Material.Metal, nil)
		gPart("GoldTrimRail", Vector3.new(0.26, 0.10, 2.55), CFrame.new(0, 0.84, -1.16), goldTrim, Enum.Material.Metal, nil)
		gPart("HoloOptic", Vector3.new(0.30, 0.30, 0.46), CFrame.new(0, 1.00, -0.38), polymerGrip, Enum.Material.Metal, nil)
		gPart("CrimsonDot", Vector3.new(0.16, 0.16, 0.08), CFrame.new(0, 1.01, -0.38), Color3.fromRGB(255, 68, 86), Enum.Material.Neon, nil)
		gPart("Barrel", Vector3.new(1.22, 0.22, 0.22), CFrame.new(0, 0.58, -3.08) * CFrame.Angles(0, math.rad(90), 0), goldTrim, Enum.Material.Metal, Enum.PartType.Cylinder)
		gPart("MuzzleTip", Vector3.new(0.26, 0.26, 0.16), CFrame.new(0, 0.58, -3.72), Color3.fromRGB(18, 20, 24), Enum.Material.Metal, nil)
	else
		-- Preserved Existing Street Pistol Model
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
						toastEv:FireClient(player, "Kevlar Armor depleted. Visit the Black Market to replace it.")
					end
				end
				updating = false
			end
		end)
	end
end

local function grantOwnedGearToPlayer(player: Player, fillMagsOnGrant: boolean?): ()
	local char = player.Character
	if char then
		syncCharacterArmor(player)
	end

	local bp = player:FindFirstChild("Backpack")
	if not bp then return end

	for _, weaponId in ipairs(WeaponConfig.WEAPON_ORDER) do
		local spec = BlackMarketService.ITEMS[weaponId]
		if spec and spec.Kind == "Weapon" and playerOwnsWeapon(player, weaponId) then
			local existingTool = findPlayerWeaponTool(player, weaponId)
			if not existingTool then
				local tool = buildGunTool(weaponId)
				tool.Parent = bp
			end
			local st = ensureWeaponMag(player, weaponId)
			if st and fillMagsOnGrant and not st.Reloading then
				st.Mag = spec.MagSize or 12
			end
			syncToolAmmoAttributes(player, weaponId)
		end
	end
	sendFullAmmoSync(player)
end

function BlackMarketService.SyncPlayerAmmoAndGear(player: Player): ()
	grantOwnedGearToPlayer(player, false)
end

local function applyBulletHit(player: Player, root: BasePart, hitModel: Model, hitPos: Vector3, dmg: number, usedWeaponId: string): boolean
	local targetHum = hitModel:FindFirstChildOfClass("Humanoid")
	if not targetHum or targetHum.Health <= 0 then
		return false
	end

	local isRival = CollectionService:HasTag(hitModel, "RivalAIUnit")
	local isMafia = CollectionService:HasTag(hitModel, "MafiaUnit")
	local isEnemyTurfGuard = CollectionService:HasTag(hitModel, "TurfGuardUnit")
		and hitModel:GetAttribute("Faction") ~= ("Player_" .. tostring(player.UserId))
	if isRival or isMafia or isEnemyTurfGuard then
		local hitDir = hitPos - root.Position
		if hitDir.Magnitude > 0.05 then
			hitModel:SetAttribute("LastHitDir", hitDir.Unit)
		end
		targetHum:TakeDamage(dmg)
		emitCombatSFX("MeleeHit", hitPos, nil)
		if targetHum.Health <= 0 then
			local isMafiaBoss = hitModel:GetAttribute("IsMafiaBoss") == true
			local isRivalBoss = hitModel:GetAttribute("IsRivalBoss") == true
			if isRivalBoss then
				local goldAttr = hitModel:GetAttribute("BountyGold")
				local expAttr = hitModel:GetAttribute("BountyExp")
				local repAttr = hitModel:GetAttribute("BountyRep")
				local g = if typeof(goldAttr) == "number" then goldAttr else 480
				local e = if typeof(expAttr) == "number" then expAttr else 185
				local r = if typeof(repAttr) == "number" then repAttr else 110
				PlayerDataService.AddRewards(player, g, e, r)
				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				local toastEv = if remotes then remotes:FindFirstChild("MilestoneToast") else nil
				if toastEv and toastEv:IsA("RemoteEvent") then
					toastEv:FireAllClients(string.format("%s eliminated THE CRIMSON DON (+%dG, +%d Rep).", player.DisplayName, g, r))
				end
			elseif isMafiaBoss then
				PlayerDataService.AddRewards(player, 220, 80, 45)
			elseif isMafia then
				PlayerDataService.AddRewards(player, 90, 35, 20)
			elseif isEnemyTurfGuard then
				PlayerDataService.AddRewards(player, 65, 25, 15)
			else
				local goldAttr = hitModel:GetAttribute("BountyGold")
				local expAttr = hitModel:GetAttribute("BountyExp")
				local repAttr = hitModel:GetAttribute("BountyRep")
				local g = if typeof(goldAttr) == "number" then goldAttr else 50
				local e = if typeof(expAttr) == "number" then expAttr else math.floor(g * 0.55)
				local r = if typeof(repAttr) == "number" then repAttr else math.floor(g * 0.28)
				PlayerDataService.AddRewards(player, g, e, r)
			end
			grantKillAmmoBonus(player, usedWeaponId)
			SyndicateContractService.RecordProgress(player, "EliminateHostiles", 1)
		end
		return true
	end

	-- PvP outside safe plazas
	local otherPlayer = Players:GetPlayerFromCharacter(hitModel)
	if otherPlayer and otherPlayer ~= player then
		if not isInsideOwnBase(otherPlayer, hitPos) and not isInsideOwnBase(player, root.Position) then
			targetHum:TakeDamage(math.floor(dmg * 0.75))
			emitCombatSFX("MeleeHit", hitPos, nil)
			if targetHum.Health <= 0 then
				PlayerDataService.AddRewards(player, 50, 25, 15)
				grantKillAmmoBonus(player, usedWeaponId)
			end
			return true
		end
	end
	return false
end

local function handleWeaponFire(player: Player, weaponId: any, aimPoint: any, shotSeq: any): ()
	if typeof(weaponId) ~= "string" or typeof(aimPoint) ~= "Vector3" then
		return
	end
	local spec = BlackMarketService.ITEMS[weaponId]
	if not spec or spec.Kind ~= "Weapon" then
		return
	end
	if not playerOwnsWeapon(player, weaponId) then
		return
	end

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not char or not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then
		return
	end

	if getEquippedWeaponIdForPlayer(player) ~= weaponId then
		return
	end

	local st = ensureWeaponMag(player, weaponId)
	if not st then
		return
	end

	local ackSeq = if typeof(shotSeq) == "number" then shotSeq else nil

	-- If reloading: allow interrupting shell-by-shell shotgun reload when >= 1 shell is chambered
	if st.Reloading then
		if spec.ReloadStyle == "ShellByShell" and st.Mag >= 1 then
			cancelReload(player, weaponId, true)
		else
			sendWeaponAmmoSync(player, "Update", weaponId, { AckSeq = ackSeq })
			return
		end
	end

	-- Authoritatively block firing when magazine/tube is empty
	if st.Mag <= 0 then
		sendWeaponAmmoSync(player, "DryFire", weaponId, { AckSeq = ackSeq })
		return
	end

	local now = os.clock()
	local cd = spec.Cooldown or 0.35
	if lastFireAt[player] and (now - lastFireAt[player]) < (cd * 0.78) then
		return
	end
	lastFireAt[player] = now

	-- Deduct 1 round authoritatively and sync immediately
	st.Mag = math.max(0, st.Mag - 1)
	syncToolAmmoAttributes(player, weaponId)
	sendWeaponAmmoSync(player, "Update", weaponId, { AckSeq = ackSeq })

	local muzzlePart = char:FindFirstChild("MuzzleTip", true)
	local origin = if muzzlePart and muzzlePart:IsA("BasePart") then muzzlePart.Position else (root.Position + Vector3.new(0, 1.5, 0))
	local hasHeavyBarrel = PlayerDataService.HasWeaponMod(player, weaponId, "HeavyBarrel")
	local hasSuppressor = PlayerDataService.HasWeaponMod(player, weaponId, "Suppressor")
	local range = math.floor((spec.Range or 95) * (if hasHeavyBarrel then 1.18 else 1.0))
	local pellets = spec.Pellets or 1
	local dmg = math.ceil((spec.Damage or 25) * (if hasHeavyBarrel then 1.22 else 1.0))
	local spread = (spec.Spread or (if pellets > 1 then 0.072 else 0.014)) * (if hasHeavyBarrel then 0.78 else 1.0)

	local rawDir = aimPoint - origin
	if rawDir.Magnitude < 0.2 then
		rawDir = root.CFrame.LookVector
	end
	local baseDir = rawDir.Unit

	-- Broadcast gunshot audio to OTHER players only (suppressed shots are silent at distance!)
	if not hasSuppressor then
		local sfxType = spec.AudioKey or "PistolShot"
		emitCombatSFX(sfxType, origin, player)
	end

	local ignoreList: { Instance } = { char }
	for _, ch in ipairs(Workspace:GetChildren()) do
		if ch.Name == "SportMotorbike_" .. player.Name or ch.Name == "FoodEmpireGuideArrow" or ch.Name == "BulletTracer" then
			table.insert(ignoreList, ch)
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreList

	for _ = 1, pellets do
		local dir = (baseDir + Vector3.new((math.random() - 0.5) * spread, (math.random() - 0.5) * spread, (math.random() - 0.5) * spread)).Unit
		local result = Workspace:Raycast(origin, dir * range, rayParams)
		local hitPos = if result then result.Position else (origin + dir * range)
		local didHit = false

		if result and result.Instance then
			local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
			if hitModel then
				if hasSuppressor then
					hitModel:SetAttribute("SuppressedHitAt", os.clock())
				end
				didHit = applyBulletHit(player, root, hitModel, hitPos, dmg, weaponId)
			end
		end

		local tracerCol = if didHit
			then Color3.fromRGB(255, 108, 56)
			elseif weaponId == "GoldenEmperorPistol" then Color3.fromRGB(255, 224, 96)
			elseif weaponId == "CrimsonDragonAR" then Color3.fromRGB(255, 86, 104)
			elseif weaponId == "ShadowSniper" then Color3.fromRGB(196, 138, 255)
			else Color3.fromRGB(255, 224, 92)
		BlackMarketService.SpawnBulletTracer(origin, hitPos, tracerCol)
	end
end

local function handleWeaponReload(player: Player, weaponId: any, action: any): ()
	if typeof(weaponId) ~= "string" then
		return
	end
	local spec = BlackMarketService.ITEMS[weaponId]
	if not spec or spec.Kind ~= "Weapon" then
		return
	end
	if not playerOwnsWeapon(player, weaponId) then
		return
	end

	if action == "Cancel" then
		cancelReload(player, weaponId, true)
		return
	end

	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if not char or not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then
		return
	end

	if getEquippedWeaponIdForPlayer(player) ~= weaponId then
		return
	end

	local st = ensureWeaponMag(player, weaponId)
	if not st or st.Reloading then
		return
	end

	local ammoType = spec.AmmoType or "Pistol9mm"
	local ammoSpec = WeaponConfig.AMMO_TYPES[ammoType]
	local reserveMax = if ammoSpec then ammoSpec.MaxReserve else 96
	local magSize = getEffectiveMagSize(player, weaponId, spec)
	local curReserve = PlayerDataService.GetAmmo(player, ammoType)

	if st.Mag >= magSize then
		sendWeaponAmmoSync(player, "Update", weaponId, nil)
		return
	end
	if curReserve <= 0 then
		sendWeaponAmmoSync(player, "NoReserve", weaponId, nil)
		return
	end

	st.Reloading = true
	st.ReloadToken += 1
	local token = st.ReloadToken
	syncToolAmmoAttributes(player, weaponId)

	if spec.ReloadStyle == "ShellByShell" then
		local startTime = spec.ShellStartTime or 0.20
		local shellTime = spec.ShellLoadTime or 0.48
		local finishTime = spec.ShellFinishTime or 0.24

		sendWeaponAmmoSync(player, "ReloadStart", weaponId, {
			ReloadStyle = "ShellByShell",
			StartTime = startTime,
			ShellTime = shellTime,
			FinishTime = finishTime,
		})

		task.spawn(function()
			task.wait(startTime)
			while st.Reloading and st.ReloadToken == token and st.Mag < magSize do
				local liveRes = PlayerDataService.GetAmmo(player, ammoType)
				if liveRes <= 0 then
					break
				end
				local curChar = player.Character
				local curHum = if curChar then curChar:FindFirstChildOfClass("Humanoid") else nil
				if not player.Parent or not curHum or curHum.Health <= 0 or getEquippedWeaponIdForPlayer(player) ~= weaponId then
					cancelReload(player, weaponId, true)
					return
				end

				task.wait(shellTime)

				curChar = player.Character
				curHum = if curChar then curChar:FindFirstChildOfClass("Humanoid") else nil
				if not st.Reloading or st.ReloadToken ~= token then
					return
				end
				if not player.Parent or not curHum or curHum.Health <= 0 or getEquippedWeaponIdForPlayer(player) ~= weaponId then
					cancelReload(player, weaponId, true)
					return
				end

				liveRes = PlayerDataService.GetAmmo(player, ammoType)
				if liveRes <= 0 then
					break
				end

				st.Mag = math.min(magSize, st.Mag + 1)
				PlayerDataService.SetAmmo(player, ammoType, liveRes - 1, reserveMax)
				syncToolAmmoAttributes(player, weaponId)
				syncAllWeaponsForAmmoType(player, ammoType, weaponId)

				local nextRes = PlayerDataService.GetAmmo(player, ammoType)
				local hasMore = (st.Mag < magSize and nextRes > 0)
				sendWeaponAmmoSync(player, "ShellLoaded", weaponId, {
					ReloadStyle = "ShellByShell",
					HasMore = hasMore,
					ShellTime = shellTime,
					FinishTime = finishTime,
				})
			end

			if not st.Reloading or st.ReloadToken ~= token then
				return
			end

			task.wait(finishTime)
			if not st.Reloading or st.ReloadToken ~= token then
				return
			end

			st.Reloading = false
			syncToolAmmoAttributes(player, weaponId)
			sendWeaponAmmoSync(player, "ReloadComplete", weaponId, {
				ReloadStyle = "ShellByShell",
			})
		end)
	else
		local reloadTime = spec.ReloadTime or 1.45
		sendWeaponAmmoSync(player, "ReloadStart", weaponId, {
			ReloadStyle = "Magazine",
			Duration = reloadTime,
		})

		task.delay(reloadTime, function()
			if not st.Reloading or st.ReloadToken ~= token then
				return
			end
			local curChar = player.Character
			local curHum = if curChar then curChar:FindFirstChildOfClass("Humanoid") else nil
			if not player.Parent or not curHum or curHum.Health <= 0 or getEquippedWeaponIdForPlayer(player) ~= weaponId then
				cancelReload(player, weaponId, true)
				return
			end

			local liveRes = PlayerDataService.GetAmmo(player, ammoType)
			local needed = magSize - st.Mag
			local loaded = math.min(needed, liveRes)
			st.Mag += loaded
			PlayerDataService.SetAmmo(player, ammoType, liveRes - loaded, reserveMax)
			st.Reloading = false
			syncToolAmmoAttributes(player, weaponId)
			syncAllWeaponsForAmmoType(player, ammoType, weaponId)
			sendWeaponAmmoSync(player, "ReloadComplete", weaponId, {
				ReloadStyle = "Magazine",
			})
		end)
	end
end

-- Dedicated Server-Authoritative Ammunition Purchasing (3 Pack Quantities per Caliber!)
function BlackMarketService.BuyAmmo(player: Player, ammoTypeRaw: string, packIndex: number): (boolean, string)
	local ammoSpec = WeaponConfig.AMMO_TYPES[ammoTypeRaw :: WeaponConfig.AmmoTypeId]
	if not ammoSpec then
		return false, "Unknown ammunition caliber!"
	end
	local idx = math.floor(packIndex)
	local pack = ammoSpec.Packs[idx]
	if not pack then
		return false, "Invalid ammunition pack quantity!"
	end

	local cur = PlayerDataService.GetAmmo(player, ammoSpec.Id)
	if cur >= ammoSpec.MaxReserve then
		return false, string.format("%s reserve is already full (%d / %d)!", ammoSpec.ShortName, cur, ammoSpec.MaxReserve)
	end

	if not PlayerDataService.SpendCoins(player, pack.Price) then
		return false, string.format("Need %d Gold for +%d %s!", pack.Price, pack.Quantity, ammoSpec.ShortName)
	end

	local newVal = PlayerDataService.AddAmmo(player, ammoSpec.Id, pack.Quantity, ammoSpec.MaxReserve)
	local added = newVal - cur
	syncAllWeaponsForAmmoType(player, ammoSpec.Id, nil)

	return true, string.format("Bought +%d %s (%d / %d reserve).", added, ammoSpec.ShortName, newVal, ammoSpec.MaxReserve)
end

function BlackMarketService.BuyItem(player: Player, itemId: string): (boolean, string)
	local spec = BlackMarketService.ITEMS[itemId]
	if not spec then
		return false, "Unknown Black Market item!"
	end

	local profile = PlayerDataService.GetProfile(player)

	-- Optional Robux Weapons -> verify duplicate prevention & delegate securely to MonetizationService
	if spec.RobuxItemId then
		if playerOwnsWeapon(player, itemId) then
			grantOwnedGearToPlayer(player, false)
			return true, spec.DisplayName .. " is already unlocked and ready in your hotbar!"
		end
		return MonetizationService.TryPromptPurchase(player, spec.RobuxItemId)
	end

	if spec.Kind == "Weapon" and playerOwnsWeapon(player, itemId) then
		grantOwnedGearToPlayer(player, false)
		return true, spec.DisplayName .. " is already owned and ready in your hotbar!"
	end

	if spec.Kind == "Armor" and (profile.Armor or 0) >= 100 then
		return false, "Your Kevlar Armor is already full (100 / 100)!"
	end

	local reqLv = spec.RequiredLevel or 1
	if profile.Level < reqLv then
		return false, string.format("Requires Player Lv.%d to unlock %s!", reqLv, spec.DisplayName)
	end

	if not PlayerDataService.SpendCoins(player, spec.Price) then
		return false, string.format("Need %d Gold to buy %s!", spec.Price, spec.DisplayName)
	end

	if spec.Kind == "Weapon" then
		PlayerDataService.UnlockWeapon(player, itemId)
		-- Ensure first-time buyer has at least starter reserve of that caliber
		local ammoType = spec.AmmoType or "Pistol9mm"
		local ammoSpec = WeaponConfig.AMMO_TYPES[ammoType]
		if ammoSpec then
			local curRes = PlayerDataService.GetAmmo(player, ammoType)
			if curRes < ammoSpec.StarterReserve then
				PlayerDataService.SetAmmo(player, ammoType, ammoSpec.StarterReserve, ammoSpec.MaxReserve)
			end
		end
		local st = ensureWeaponMag(player, itemId)
		if st then
			st.Mag = spec.MagSize or 12
		end
		grantOwnedGearToPlayer(player, false)
		return true, string.format("%s unlocked with full magazine. Press [R] to reload.", spec.DisplayName)
	elseif spec.Kind == "Armor" then
		PlayerDataService.SetArmor(player, 100)
		syncCharacterArmor(player)
		return true, "Kevlar Chef Armor equipped (100 / 100 Armor). Absorbs damage until broken."
	else
		-- Medkit consumable (heals Base 100 HP + 6s speed boost without granting free armor)
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
		return true, "Flash-Spice Medkit used. Full HP restored + 6s speed boost."
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
	return true, "Arrived at the Underground Black Market."
end

-- Gunsmith Attachment Workbench: Suppressor, ExtendedMag, HeavyBarrel per owned firearm!
function BlackMarketService.BuyWeaponMod(player: Player, weaponId: string, modId: string): (boolean, string)
	local spec = BlackMarketService.ITEMS[weaponId]
	if not spec or spec.Kind ~= "Weapon" then
		return false, "Invalid firearm for Gunsmith attachment!"
	end
	if not playerOwnsWeapon(player, weaponId) then
		return false, string.format("Unlock %s first before installing Gunsmith attachments!", spec.DisplayName)
	end
	local modSpec = WeaponConfig.GUNSMITH_MODS[modId]
	if not modSpec then
		return false, "Unknown Gunsmith attachment!"
	end
	if PlayerDataService.HasWeaponMod(player, weaponId, modId) then
		return false, string.format("%s is already installed on %s!", modSpec.DisplayName, spec.DisplayName)
	end
	if not PlayerDataService.SpendCoins(player, modSpec.Price) then
		return false, string.format("Need %d Gold to install %s on %s!", modSpec.Price, modSpec.DisplayName, spec.DisplayName)
	end

	PlayerDataService.UnlockWeaponMod(player, weaponId, modId)
	local st = ensureWeaponMag(player, weaponId)
	if st and modId == "ExtendedMag" then
		st.Mag = getEffectiveMagSize(player, weaponId, spec)
	end
	syncToolAmmoAttributes(player, weaponId)
	sendWeaponAmmoSync(player, "Update", weaponId, nil)
	return true, string.format("Installed %s on %s!", modSpec.DisplayName, spec.DisplayName)
end

function BlackMarketService.GetCatalogPayload(player: Player): { [string]: any }
	local profile = PlayerDataService.GetProfile(player)
	local armor = math.clamp(math.floor(profile.Armor or 0), 0, 100)
	local ownedMap: { [string]: boolean } = {}
	for _, wid in ipairs(WeaponConfig.WEAPON_ORDER) do
		if playerOwnsWeapon(player, wid) then
			ownedMap[wid] = true
		end
	end
	local ammoCopy: { [string]: number } = {}
	for _, aid in ipairs(WeaponConfig.AMMO_ORDER) do
		ammoCopy[aid] = PlayerDataService.GetAmmo(player, aid)
	end
	return {
		OwnedWeapons = ownedMap,
		AmmoInventory = ammoCopy,
		WeaponMods = profile.WeaponMods or {},
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
	reloadEv = ensureRemote("WeaponReload")
	ammoSyncEv = ensureRemote("AmmoSync")
	sfxEv = ensureRemote("CombatSFX")
	openUiEv = ensureRemote("OpenBlackMarketUI")

	if fireEv then
		table.insert(conns, fireEv.OnServerEvent:Connect(handleWeaponFire))
	end
	if reloadEv then
		table.insert(conns, reloadEv.OnServerEvent:Connect(handleWeaponReload))
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

	local function hookCharacter(player: Player, char: Model)
		if charRemoveConns[player] then
			charRemoveConns[player]:Disconnect()
			charRemoveConns[player] = nil
		end
		charRemoveConns[player] = char.ChildRemoved:Connect(function(child: Instance)
			if child:IsA("Tool") then
				local wid = child:GetAttribute("WeaponId")
				if typeof(wid) == "string" then
					cancelReload(player, wid, true)
				end
			end
		end)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Died:Connect(function()
				cancelAllReloads(player, false)
			end)
		end
	end

	local function hookPlayer(player: Player)
		if charConns[player] then charConns[player]:Disconnect() end
		charConns[player] = player.CharacterAdded:Connect(function(newChar: Model)
			cancelAllReloads(player, false)
			hookCharacter(player, newChar)
			task.delay(0.4, function()
				if player.Parent then
					grantOwnedGearToPlayer(player, true)
				end
			end)
		end)
		if player.Character then
			hookCharacter(player, player.Character)
			grantOwnedGearToPlayer(player, true)
		end
	end

	table.insert(conns, Players.PlayerAdded:Connect(hookPlayer))
	table.insert(
		conns,
		Players.PlayerRemoving:Connect(function(p)
			lastFireAt[p] = nil
			playerMagState[p] = nil
			if charConns[p] then charConns[p]:Disconnect(); charConns[p] = nil end
			if charRemoveConns[p] then charRemoveConns[p]:Disconnect(); charRemoveConns[p] = nil end
		end)
	)
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayer(p)
	end

	print("[Food Empire] BlackMarketService started (9 Weapons, 5 Ammo Calibers, Server Reload, Kevlar Armor & CombatSFX ready)!")
end

function BlackMarketService.Stop(): ()
	isRunning = false
	for _, c in ipairs(conns) do c:Disconnect() end
	table.clear(conns)
	for p, c in pairs(charConns) do c:Disconnect(); charConns[p] = nil end
	for p, c in pairs(charRemoveConns) do c:Disconnect(); charRemoveConns[p] = nil end
	table.clear(playerMagState)
end

return BlackMarketService
