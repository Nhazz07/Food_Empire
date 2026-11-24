--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

type BobbingBoat = {
	Model: Model,
	BasePivot: CFrame,
	Phase: number,
}

type DriftingCloud = {
	Model: Model,
	Speed: number,
}

local AmbientEffectsController = {}

local heartbeatConn: RBXScriptConnection? = nil

function AmbientEffectsController.Start(): ()
	if heartbeatConn then
		return
	end

	local cachedBlades: Model? = nil
	local cachedBoats: { BobbingBoat } = {}
	local cachedClouds: { DriftingCloud } = {}
	local kitchenBasePivots: { [Model]: CFrame } = {}
	local dyingDustPlayed: { [Model]: boolean } = {}
	local dyingOrigTrans: { [Model]: { { Obj: BasePart | Decal, BaseT: number } } } = {}
	local npcPrevHealth: { [Model]: number } = {}
	local npcFlinchStart: { [Model]: number } = {}
	local npcFlinchSide: { [Model]: number } = {}
	local cachedSailboats = false
	local searchCooldown = 0
	local elapsed = 0

	local function easeOutCubic(t: number): number
		local x = math.clamp(t, 0, 1)
		local inv = 1 - x
		return 1 - inv * inv * inv
	end

	local function easeInQuad(t: number): number
		local x = math.clamp(t, 0, 1)
		return x * x
	end

	local function spawnGroundDust(pos: Vector3, scale: number): ()
		local holder = Instance.new("Part")
		holder.Name = "DeathImpactDust"
		holder.Size = Vector3.new(0.5, 0.2, 0.5)
		holder.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0))
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanTouch = false
		holder.CanQuery = false
		holder.Parent = Workspace

		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(Color3.fromRGB(132, 128, 122), Color3.fromRGB(78, 76, 74))
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42),
			NumberSequenceKeypoint.new(0.6, 0.72),
			NumberSequenceKeypoint.new(1, 1.0),
		})
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.65 * scale),
			NumberSequenceKeypoint.new(1, 2.35 * scale),
		})
		pe.Lifetime = NumberRange.new(0.45, 0.75)
		pe.Speed = NumberRange.new(3.5, 7.5)
		pe.Drag = 4.5
		pe.SpreadAngle = Vector2.new(82, 82)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Parent = holder
		pe:Emit(14)

		task.delay(0.95, function()
			if holder.Parent then
				holder:Destroy()
			end
		end)
	end

	local function animateDyingNPC(model: Model, serverNow: number): ()
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local startAttr = model:GetAttribute("DeathStartTime")
		local baseCFAttr = model:GetAttribute("DeathBaseCF")
		if typeof(startAttr) ~= "number" or typeof(baseCFAttr) ~= "CFrame" then
			return
		end

		local styleAttr = model:GetAttribute("DeathStyle")
		local sideAttr = model:GetAttribute("DeathSide")
		local floorAttr = model:GetAttribute("DeathFloorY")
		local scaleAttr = model:GetAttribute("DeathScale")
		local hitDirAttr = model:GetAttribute("DeathHitDir")

		local style = if typeof(styleAttr) == "number" then styleAttr else 1
		local side = if typeof(sideAttr) == "number" then sideAttr else 1
		local scale = if typeof(scaleAttr) == "number" then scaleAttr else 1.0
		local floorY = if typeof(floorAttr) == "number" then floorAttr else (baseCFAttr.Position.Y - 3.6 * scale)
		local hitDir = if typeof(hitDirAttr) == "Vector3" and hitDirAttr.Magnitude > 0.05
			then hitDirAttr.Unit
			else -baseCFAttr.LookVector

		local t = math.max(0, serverNow - startAttr)
		local basePos = baseCFAttr.Position
		local baseRot = baseCFAttr - basePos

		local neck = root:FindFirstChild("NeckJoint") or model:FindFirstChild("Neck", true)
		local la = root:FindFirstChild("LeftArmJoint") or model:FindFirstChild("LeftShoulder", true)
		local ra = root:FindFirstChild("RightArmJoint") or model:FindFirstChild("RightShoulder", true)
		local ll = root:FindFirstChild("LeftLegJoint") or model:FindFirstChild("LeftHip", true)
		local rl = root:FindFirstChild("RightLegJoint") or model:FindFirstChild("RightHip", true)

		local posOffset = Vector3.zero
		local targetY = basePos.Y
		local rotOffset = CFrame.identity
		local neckRot = CFrame.identity
		local laRot = CFrame.identity
		local raRot = CFrame.identity
		local llRot = CFrame.identity
		local rlRot = CFrame.identity

		if style == 1 then
			-- STYLE 1: Directional Backwards Stagger & Heavy Collapse onto Back
			local groundCenterY = floorY + 0.62 * scale
			if t < 0.16 then
				local u = easeOutCubic(t / 0.16)
				posOffset = hitDir * (0.65 * scale * u)
				targetY = basePos.Y - 0.12 * scale * u
				rotOffset = CFrame.Angles(math.rad(18 * u), math.rad(side * 8 * u), math.rad(side * 4 * u))
				neckRot = CFrame.Angles(math.rad(-32 * u), 0, math.rad(side * 10 * u))
				laRot = CFrame.Angles(math.rad(62 * u), 0, math.rad(-26 * u))
				raRot = CFrame.Angles(math.rad(70 * u), 0, math.rad(34 * u))
				llRot = CFrame.Angles(math.rad(-14 * u), 0, 0)
				rlRot = CFrame.Angles(math.rad(18 * u), 0, 0)
			elseif t < 0.52 then
				local u = (t - 0.16) / 0.36
				local grav = easeInQuad(u)
				local lin = easeOutCubic(u)
				posOffset = hitDir * ((0.65 + 1.85 * lin) * scale)
				targetY = basePos.Y - 0.12 * scale + (groundCenterY - (basePos.Y - 0.12 * scale)) * grav
				rotOffset = CFrame.Angles(math.rad(18 + 68 * grav), math.rad(side * (8 + 10 * lin)), math.rad(side * 4 * (1 - grav)))
				neckRot = CFrame.Angles(math.rad(-32 + 24 * grav), math.rad(side * 22 * grav), math.rad(side * 10))
				laRot = CFrame.Angles(math.rad(62 - 44 * grav), 0, math.rad(-26 - 24 * grav))
				raRot = CFrame.Angles(math.rad(70 - 82 * grav), 0, math.rad(34 + 30 * grav))
				llRot = CFrame.Angles(math.rad(-14 + 22 * grav), 0, math.rad(-12 * grav))
				rlRot = CFrame.Angles(math.rad(18 - 10 * grav), 0, math.rad(14 * grav))
			else
				local settleT = math.min(1, (t - 0.52) / 0.22)
				local bounce = math.sin(settleT * math.pi) * math.exp(-3.5 * settleT)
				if not dyingDustPlayed[model] then
					dyingDustPlayed[model] = true
					spawnGroundDust(Vector3.new(basePos.X + hitDir.X * 2.5 * scale, floorY, basePos.Z + hitDir.Z * 2.5 * scale), scale)
				end
				posOffset = hitDir * (2.50 * scale)
				targetY = groundCenterY + 0.10 * scale * bounce
				rotOffset = CFrame.Angles(math.rad(86 - 4.5 * bounce), math.rad(side * 18), 0)
				neckRot = CFrame.Angles(math.rad(-8 - 6 * bounce), math.rad(side * (22 + 12 * settleT)), math.rad(side * 14))
				laRot = CFrame.Angles(math.rad(18 + 10 * bounce), 0, math.rad(-50 - 8 * settleT))
				raRot = CFrame.Angles(math.rad(-12 + 14 * bounce), 0, math.rad(64 + 8 * settleT))
				llRot = CFrame.Angles(math.rad(8 + 6 * bounce), 0, math.rad(-12))
				rlRot = CFrame.Angles(math.rad(8 + 4 * bounce), 0, math.rad(14))
			end
		elseif style == 2 then
			-- STYLE 2: Dramatic Drop-to-Knees -> Stagger -> Heavy Face-Down Collapse (Signature Boss/Enforcer Death)
			local groundCenterY = floorY + 0.58 * scale
			local kneeY = floorY + 2.15 * scale
			local fwdDir = Vector3.new(baseCFAttr.LookVector.X, 0, baseCFAttr.LookVector.Z)
			if fwdDir.Magnitude > 0.05 then fwdDir = fwdDir.Unit else fwdDir = Vector3.new(0, 0, -1) end

			if t < 0.34 then
				local u = easeOutCubic(t / 0.34)
				posOffset = hitDir * (0.35 * scale * u)
				targetY = basePos.Y + (kneeY - basePos.Y) * u
				rotOffset = CFrame.Angles(math.rad(-18 * u), math.rad(side * 6 * u), 0)
				neckRot = CFrame.Angles(math.rad(28 * u), 0, math.rad(side * 8 * u))
				laRot = CFrame.Angles(math.rad(42 * u), 0, math.rad(24 * u))
				raRot = CFrame.Angles(math.rad(32 * u), 0, math.rad(-18 * u))
				llRot = CFrame.Angles(math.rad(-76 * u), 0, math.rad(-6 * u))
				rlRot = CFrame.Angles(math.rad(-72 * u), 0, math.rad(6 * u))
			elseif t < 0.50 then
				local u = (t - 0.34) / 0.16
				local sway = math.sin(u * math.pi)
				posOffset = hitDir * (0.35 * scale) + fwdDir * (0.18 * scale * u)
				targetY = kneeY - 0.08 * scale * u
				rotOffset = CFrame.Angles(math.rad(-18 - 10 * u), math.rad(side * 6), math.rad(side * 5 * sway))
				neckRot = CFrame.Angles(math.rad(28 + 10 * u), math.rad(side * 10 * u), math.rad(side * 8))
				laRot = CFrame.Angles(math.rad(42 - 12 * u), 0, math.rad(24))
				raRot = CFrame.Angles(math.rad(32 - 12 * u), 0, math.rad(-18))
				llRot = CFrame.Angles(math.rad(-76), 0, math.rad(-6))
				rlRot = CFrame.Angles(math.rad(-72), 0, math.rad(6))
			elseif t < 0.84 then
				local u = (t - 0.50) / 0.34
				local grav = easeInQuad(u)
				posOffset = hitDir * (0.35 * scale) + fwdDir * ((0.18 + 1.85 * grav) * scale)
				targetY = (kneeY - 0.08 * scale) + (groundCenterY - (kneeY - 0.08 * scale)) * grav
				rotOffset = CFrame.Angles(math.rad(-28 - 58 * grav), math.rad(side * (6 + 8 * grav)), 0)
				neckRot = CFrame.Angles(math.rad(38 - 32 * grav), math.rad(side * (10 + 36 * grav)), math.rad(side * 12))
				laRot = CFrame.Angles(math.rad(30 + 96 * grav), 0, math.rad(24 - 52 * grav))
				raRot = CFrame.Angles(math.rad(20 + 78 * grav), 0, math.rad(-18 + 46 * grav))
				llRot = CFrame.Angles(math.rad(-76 + 68 * grav), 0, math.rad(-8))
				rlRot = CFrame.Angles(math.rad(-72 + 66 * grav), 0, math.rad(10))
			else
				local settleT = math.min(1, (t - 0.84) / 0.20)
				local bounce = math.sin(settleT * math.pi) * math.exp(-3.8 * settleT)
				if not dyingDustPlayed[model] then
					dyingDustPlayed[model] = true
					spawnGroundDust(Vector3.new(basePos.X + fwdDir.X * 2.0 * scale, floorY, basePos.Z + fwdDir.Z * 2.0 * scale), scale * 1.15)
				end
				posOffset = hitDir * (0.35 * scale) + fwdDir * (2.03 * scale)
				targetY = groundCenterY + 0.09 * scale * bounce
				rotOffset = CFrame.Angles(math.rad(-86 + 4 * bounce), math.rad(side * 14), 0)
				neckRot = CFrame.Angles(math.rad(6), math.rad(side * 46), math.rad(side * 12))
				laRot = CFrame.Angles(math.rad(126 - 8 * bounce), 0, math.rad(-28))
				raRot = CFrame.Angles(math.rad(98 - 8 * bounce), 0, math.rad(28))
				llRot = CFrame.Angles(math.rad(-8), 0, math.rad(-8))
				rlRot = CFrame.Angles(math.rad(-6), 0, math.rad(10))
			end
		else
			-- STYLE 3: Side-Spin Flank Collapse onto Shoulder/Hip
			local groundCenterY = floorY + 0.66 * scale
			local sideVec = Vector3.new(-hitDir.Z, 0, hitDir.X) * side
			if t < 0.20 then
				local u = easeOutCubic(t / 0.20)
				posOffset = (hitDir * 0.45 + sideVec * 0.45) * (scale * u)
				targetY = basePos.Y - 0.18 * scale * u
				rotOffset = CFrame.Angles(math.rad(10 * u), math.rad(side * 42 * u), math.rad(side * 18 * u))
				neckRot = CFrame.Angles(math.rad(-14 * u), math.rad(-side * 24 * u), math.rad(side * 16 * u))
				laRot = CFrame.Angles(math.rad(36 * u), 0, math.rad(-44 * u))
				raRot = CFrame.Angles(math.rad(46 * u), 0, math.rad(42 * u))
				llRot = CFrame.Angles(math.rad(22 * u), 0, 0)
				rlRot = CFrame.Angles(math.rad(-16 * u), 0, 0)
			elseif t < 0.56 then
				local u = (t - 0.20) / 0.36
				local grav = easeInQuad(u)
				posOffset = (hitDir * (0.45 + 0.85 * grav) + sideVec * (0.45 + 1.45 * grav)) * scale
				targetY = (basePos.Y - 0.18 * scale) + (groundCenterY - (basePos.Y - 0.18 * scale)) * grav
				rotOffset = CFrame.Angles(math.rad(10 * (1 - grav)), math.rad(side * (42 + 18 * grav)), math.rad(side * (18 + 68 * grav)))
				neckRot = CFrame.Angles(math.rad(-14 + 22 * grav), math.rad(-side * 24), math.rad(side * (16 + 18 * grav)))
				laRot = CFrame.Angles(math.rad(36 + 18 * grav), 0, math.rad(-44 + 28 * grav))
				raRot = CFrame.Angles(math.rad(46 - 24 * grav), 0, math.rad(42 + 14 * grav))
				llRot = CFrame.Angles(math.rad(22 + 8 * grav), 0, math.rad(-8 * grav))
				rlRot = CFrame.Angles(math.rad(-16 + 4 * grav), 0, math.rad(10 * grav))
			else
				local settleT = math.min(1, (t - 0.56) / 0.20)
				local bounce = math.sin(settleT * math.pi) * math.exp(-3.6 * settleT)
				if not dyingDustPlayed[model] then
					dyingDustPlayed[model] = true
					spawnGroundDust(Vector3.new(basePos.X + (hitDir.X * 1.3 + sideVec.X * 1.9) * scale, floorY, basePos.Z + (hitDir.Z * 1.3 + sideVec.Z * 1.9) * scale), scale)
				end
				posOffset = (hitDir * 1.30 + sideVec * 1.90) * scale
				targetY = groundCenterY + 0.09 * scale * bounce
				rotOffset = CFrame.Angles(0, math.rad(side * 60), math.rad(side * (86 - 4 * bounce)))
				neckRot = CFrame.Angles(math.rad(8), math.rad(-side * 24), math.rad(side * 34))
				laRot = CFrame.Angles(math.rad(54), 0, math.rad(-16))
				raRot = CFrame.Angles(math.rad(22), 0, math.rad(56))
				llRot = CFrame.Angles(math.rad(30), 0, math.rad(-8))
				rlRot = CFrame.Angles(math.rad(-12), 0, math.rad(10))
			end
		end

		root.CFrame = CFrame.new(basePos.X + posOffset.X, targetY, basePos.Z + posOffset.Z) * baseRot * rotOffset
		if neck and neck:IsA("Motor6D") then neck.Transform = neckRot end
		if la and la:IsA("Motor6D") then la.Transform = laRot end
		if ra and ra:IsA("Motor6D") then ra.Transform = raRot end
		if ll and ll:IsA("Motor6D") then ll.Transform = llRot end
		if rl and rl:IsA("Motor6D") then rl.Transform = rlRot end

		-- Clean fade-out starting at 2.25s so bodies vanish smoothly instead of popping!
		if t >= 2.25 then
			local list = dyingOrigTrans[model]
			if not list then
				list = {}
				for _, desc in ipairs(model:GetDescendants()) do
					if desc:IsA("BasePart") or desc:IsA("Decal") then
						table.insert(list, { Obj = desc, BaseT = desc.Transparency })
					end
				end
				dyingOrigTrans[model] = list
			end
			local fadeAlpha = math.clamp((t - 2.25) / 0.75, 0, 1)
			for _, item in ipairs(list) do
				if item.Obj.Parent then
					item.Obj.Transparency = item.BaseT + (1 - item.BaseT) * fadeAlpha
				end
			end
		end
	end

	-- Client-only 60 FPS ambient animations (Ranch Windmill, Boats, Sailboats & Drifting Sky Clouds)
	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		searchCooldown -= dt

		if searchCooldown <= 0 then
			searchCooldown = 2.5
			local map = Workspace:FindFirstChild("FoodEmpireMap")
			local sectors = if map then map:FindFirstChild("Sectors") else nil
			local env = if map then map:FindFirstChild("Environment") else nil
			local polish = if env then env:FindFirstChild("Pass3_IslandPolish") else nil

			if (not cachedBlades or not cachedBlades.Parent) and sectors then
				local ranch = sectors:FindFirstChild("Ranch_Territory")
				local wm = if ranch then ranch:FindFirstChild("Ranch_Windmill") else nil
				local blades = if wm then wm:FindFirstChild("WindmillBlades") else nil
				if blades and blades:IsA("Model") and blades.PrimaryPart then
					cachedBlades = blades
				end
			end

			if #cachedBoats == 0 and sectors then
				local port = sectors:FindFirstChild("FishingPort_Territory")
				if port then
					for i = 1, 3 do
						local boat = port:FindFirstChild("FishingBoat_" .. tostring(i))
						if boat and boat:IsA("Model") then
							table.insert(cachedBoats, {
								Model = boat,
								BasePivot = boat:GetPivot(),
								Phase = i * 2.1,
							})
						end
					end
				end
			end

			if not cachedSailboats and polish then
				local sailboats = polish:FindFirstChild("OceanSailboats")
				if sailboats then
					cachedSailboats = true
					local idx = 10
					for _, sb in ipairs(sailboats:GetChildren()) do
						if sb:IsA("Model") then
							idx += 1
							table.insert(cachedBoats, {
								Model = sb,
								BasePivot = sb:GetPivot(),
								Phase = idx * 1.7,
							})
						end
					end
				end
			end

			if #cachedClouds == 0 and polish then
				local cloudGroup = polish:FindFirstChild("StylizedSkyClouds")
				if cloudGroup then
					for _, c in ipairs(cloudGroup:GetChildren()) do
						if c:IsA("Model") and c.PrimaryPart then
							local spd = c:GetAttribute("DriftSpeed")
							table.insert(cachedClouds, {
								Model = c,
								Speed = if type(spd) == "number" then spd else 6.0,
							})
						end
					end
				end
			end
		end

		-- 1. Spin Northeast Ranch Windmill Blades
		if cachedBlades and cachedBlades.Parent then
			local pivot = cachedBlades:GetPivot()
			cachedBlades:PivotTo(pivot * CFrame.Angles(0, 0, dt * 0.85))
		end

		-- 2. Gently bob the Fishing Port Boats & Ocean Sailboats on the turquoise waves
		for i = #cachedBoats, 1, -1 do
			local b = cachedBoats[i]
			if not b.Model.Parent then
				table.remove(cachedBoats, i)
			else
				local waveY = math.sin(elapsed * 1.6 + b.Phase) * 0.45
				local roll = math.cos(elapsed * 1.2 + b.Phase) * math.rad(2.2)
				b.Model:PivotTo(b.BasePivot * CFrame.new(0, waveY, 0) * CFrame.Angles(0, 0, roll))
			end
		end

		-- 3. Smoothly drift the 24 fluffy low-poly clouds across the island sky
		for i = #cachedClouds, 1, -1 do
			local c = cachedClouds[i]
			if not c.Model.Parent then
				table.remove(cachedClouds, i)
			else
				local piv = c.Model:GetPivot()
				local nextX = piv.Position.X + c.Speed * dt
				if nextX > 1150 then
					nextX = -1150
				end
				c.Model:PivotTo(CFrame.new(nextX, piv.Position.Y, piv.Position.Z) * piv.Rotation)
			end
		end

		-- 4. Animate R15 (and legacy) Rival, Mafia, Citizen, Chef, Waiter & Bodyguard walking/idle limbs smoothly at 60 FPS
		local function animateMarchingUnit(unit: Instance)
			if unit:IsA("Model") then
				if unit:GetAttribute("IsDying") == true then
					return
				end
				local hum = unit:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health <= 0 then
					return
				end
				local root = unit:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local vel = root.AssemblyLinearVelocity
					local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
					local isR15 = unit:GetAttribute("IsR15Rig") == true
					if isR15 then
						local upperTorso = unit:FindFirstChild("UpperTorso")
						local head = unit:FindFirstChild("Head")
						local lUpperArm = unit:FindFirstChild("LeftUpperArm")
						local rUpperArm = unit:FindFirstChild("RightUpperArm")
						local lLowerArm = unit:FindFirstChild("LeftLowerArm")
						local rLowerArm = unit:FindFirstChild("RightLowerArm")
						local lUpperLeg = unit:FindFirstChild("LeftUpperLeg")
						local rUpperLeg = unit:FindFirstChild("RightUpperLeg")
						local lLowerLeg = unit:FindFirstChild("LeftLowerLeg")
						local rLowerLeg = unit:FindFirstChild("RightLowerLeg")

						local waist = if upperTorso then upperTorso:FindFirstChild("Waist") else nil
						local neck = if head then head:FindFirstChild("Neck") else nil
						local ls = if lUpperArm then lUpperArm:FindFirstChild("LeftShoulder") else nil
						local rs = if rUpperArm then rUpperArm:FindFirstChild("RightShoulder") else nil
						local le = if lLowerArm then lLowerArm:FindFirstChild("LeftElbow") else nil
						local re = if rLowerArm then rLowerArm:FindFirstChild("RightElbow") else nil
						local lh = if lUpperLeg then lUpperLeg:FindFirstChild("LeftHip") else nil
						local rh = if rUpperLeg then rUpperLeg:FindFirstChild("RightHip") else nil
						local lk = if lLowerLeg then lLowerLeg:FindFirstChild("LeftKnee") else nil
						local rk = if rLowerLeg then rLowerLeg:FindFirstChild("RightKnee") else nil

						local diningPose = unit:GetAttribute("DiningPose")
						local waiterState = unit:GetAttribute("WaiterState")
						local combatStyle = unit:GetAttribute("CombatStyle")
						local lastAttackAttr = unit:GetAttribute("LastAttackAt")
						local comboStep = tonumber(unit:GetAttribute("AttackCombo")) or 1
						local phaseSeed = (string.byte(unit.Name, -1) or 1) * 0.75
						local serverNowLocal = Workspace:GetServerTimeNow()

						-- Client-side Hit-Stagger Flinch detection (visibly jolts any Rival or Comrade when hit!)
						if hum and typeof(combatStyle) == "string" then
							local prevHp = npcPrevHealth[unit]
							if prevHp ~= nil and hum.Health < prevHp - 0.5 then
								npcFlinchStart[unit] = elapsed
								npcFlinchSide[unit] = if math.random() < 0.5 then -1 else 1
							end
							npcPrevHealth[unit] = hum.Health
						end
						local flinchT = if npcFlinchStart[unit] then (elapsed - npcFlinchStart[unit]) else 99
						local attackElapsed = if typeof(lastAttackAttr) == "number" then math.max(0, serverNowLocal - lastAttackAttr) else 99
						local inCombatRecent = (attackElapsed < 3.6)

						if diningPose == "SeatedWaiting" or diningPose == "Eating" then
							-- Authentic R15 Seated Dining Pose (bent hips & knees on chair!)
							if lh and lh:IsA("Motor6D") then lh.Transform = CFrame.Angles(math.rad(86), 0, math.rad(-4)) end
							if rh and rh:IsA("Motor6D") then rh.Transform = CFrame.Angles(math.rad(86), 0, math.rad(4)) end
							if lk and lk:IsA("Motor6D") then lk.Transform = CFrame.Angles(math.rad(-86), 0, 0) end
							if rk and rk:IsA("Motor6D") then rk.Transform = CFrame.Angles(math.rad(-86), 0, 0) end

							if diningPose == "Eating" then
								-- Realistic Eating Cycle: dipping fork down to plate -> raising bite to mouth -> happy nod!
								local eatWave = math.sin(elapsed * 3.1 + phaseSeed)
								local biteLift = (eatWave + 1) * 0.5 -- 0 = plate, 1 = mouth
								if rs and rs:IsA("Motor6D") then
									rs.Transform = CFrame.Angles(math.rad(44 + biteLift * 46), math.rad(-14 * biteLift), math.rad(8))
								end
								if re and re:IsA("Motor6D") then
									re.Transform = CFrame.Angles(math.rad(38 + biteLift * 68), 0, 0)
								end
								if ls and ls:IsA("Motor6D") then
									ls.Transform = CFrame.Angles(math.rad(34), 0, math.rad(-10))
								end
								if le and le:IsA("Motor6D") then
									le.Transform = CFrame.Angles(math.rad(42), 0, 0)
								end
								if waist and waist:IsA("Motor6D") then
									waist.Transform = CFrame.Angles(math.rad(-7 - biteLift * 3), 0, 0)
								end
								if neck and neck:IsA("Motor6D") then
									neck.Transform = CFrame.Angles(math.rad(-10 + biteLift * 14), math.sin(elapsed * 1.4 + phaseSeed) * math.rad(8), 0)
								end
							else
								-- Seated Waiting: resting arms near table, looking around & occasionally waving for Waiter!
								local lookAround = math.sin(elapsed * 1.2 + phaseSeed) * math.rad(22)
								local signalWave = math.max(0, math.sin(elapsed * 0.55 + phaseSeed) - 0.65) / 0.35
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(38), 0, math.rad(-8)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(46), 0, 0) end
								if rs and rs:IsA("Motor6D") then
									rs.Transform = CFrame.Angles(math.rad(38 + signalWave * 88), 0, math.rad(8 + signalWave * 14))
								end
								if re and re:IsA("Motor6D") then
									re.Transform = CFrame.Angles(math.rad(46 - signalWave * 18), 0, 0)
								end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-4), 0, 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(2), lookAround, 0) end
							end
						elseif waiterState == "ServingTable" then
							-- Polite formal Waiter table-side bow presenting the plated dish!
							if lh and lh:IsA("Motor6D") then lh.Transform = CFrame.identity end
							if rh and rh:IsA("Motor6D") then rh.Transform = CFrame.identity end
							if lk and lk:IsA("Motor6D") then lk.Transform = CFrame.identity end
							if rk and rk:IsA("Motor6D") then rk.Transform = CFrame.identity end
							if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-16), 0, 0) end
							if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(68), 0, math.rad(6)) end
							if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(28), 0, 0) end
							if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(-14), 0, math.rad(-10)) end
							if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(48), 0, 0) end
							if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(-8), 0, 0) end
						elseif typeof(combatStyle) == "string" and (attackElapsed < 0.44 or flinchT < 0.24) then
							-- =====================================================================
							-- REALISTIC 60 FPS FIGHTING CHOREOGRAPHY (3-Hit Combos, Recoil & Flinch!)
							-- =====================================================================
							-- Keep legs actively striding if moving during combat, or planted in athletic combat stance!
							if speed > 0.8 then
								local freq = math.clamp(speed * 0.58, 7.6, 14.2)
								local ph = elapsed * freq
								local stride = math.sin(ph) * math.rad(38)
								if lh and lh:IsA("Motor6D") then lh.Transform = CFrame.Angles(-stride, 0, 0) end
								if rh and rh:IsA("Motor6D") then rh.Transform = CFrame.Angles(stride, 0, 0) end
								if lk and lk:IsA("Motor6D") then lk.Transform = CFrame.Angles(-math.max(0, math.cos(ph)) * math.rad(48), 0, 0) end
								if rk and rk:IsA("Motor6D") then rk.Transform = CFrame.Angles(-math.max(0, -math.cos(ph)) * math.rad(48), 0, 0) end
							else
								-- Athletic planted combat lunge stance (bent knees, front foot forward!)
								if lh and lh:IsA("Motor6D") then lh.Transform = CFrame.Angles(math.rad(22), 0, math.rad(-6)) end
								if rh and rh:IsA("Motor6D") then rh.Transform = CFrame.Angles(math.rad(-18), 0, math.rad(6)) end
								if lk and lk:IsA("Motor6D") then lk.Transform = CFrame.Angles(math.rad(-26), 0, 0) end
								if rk and rk:IsA("Motor6D") then rk.Transform = CFrame.Angles(math.rad(-20), 0, 0) end
							end

							if flinchT < 0.24 and attackElapsed >= 0.30 then
								-- Visceral Hit-Stagger Flinch!
								local fu = math.sin(math.clamp(flinchT / 0.24, 0, 1) * math.pi)
								local fSide = npcFlinchSide[unit] or 1
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(16 * fu), math.rad(fSide * 18 * fu), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(18 * fu), math.rad(-fSide * 14 * fu), 0) end
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(24 * fu), 0, math.rad(-26 * fu)) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(34 * fu), 0, math.rad(26 * fu)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(48), 0, 0) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(48), 0, 0) end
							elseif combatStyle == "Katana" then
								-- SAMURAI 3-HIT IAIJUTSU KATANA COMBO!
								local u = math.clamp(attackElapsed / 0.42, 0, 1)
								local strike = if u < 0.24 then -(u / 0.24) else math.sin(((u - 0.24) / 0.76) * math.pi)
								if comboStep == 1 then
									-- Combo 1: Kesa-Giri Overhead Diagonal Cleave
									local rPitch = if u < 0.24 then (85 + 75 * (u / 0.24)) else (160 - 155 * easeOutCubic((u - 0.24) / 0.76))
									if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(rPitch), math.rad(-22 * strike), math.rad(22 - 36 * strike)) end
									if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(26 + 24 * (1 - u)), 0, 0) end
									if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(rPitch * 0.72), math.rad(32), math.rad(-14)) end
									if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(48), 0, 0) end
									if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-14 * strike), math.rad(32 * strike - 16), 0) end
									if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(8), math.rad(-24 * strike + 10), 0) end
								elseif comboStep == 2 then
									-- Combo 2: Gyaku-Kiri Wide Horizontal Reverse Slash
									local sweep = math.sin(u * math.pi)
									local yaw = -58 + 128 * easeOutCubic(u)
									if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(78), math.rad(yaw * 0.65), math.rad(42 - 74 * u)) end
									if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(22), 0, 0) end
									if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(64), math.rad(yaw * 0.45 + 24), math.rad(-18)) end
									if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(42), 0, 0) end
									if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-10 * sweep), math.rad(yaw * 0.55), 0) end
									if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(6), math.rad(-yaw * 0.42), 0) end
								else
									-- Combo 3: Deep Lunge Thrust Execution
									local thrust = math.sin(u * math.pi)
									if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(92 + 12 * thrust), math.rad(-16 * thrust), math.rad(6)) end
									if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(46 - 40 * thrust), 0, 0) end
									if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(78), math.rad(36), math.rad(-14)) end
									if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(54 - 28 * thrust), 0, 0) end
									if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-22 * thrust), math.rad(28 * thrust), 0) end
									if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(14 * thrust), math.rad(-22 * thrust), 0) end
								end
							elseif combatStyle == "DualNinja" then
								-- NINJA ASSASSIN 3-HIT DUAL-TANTO FLURRY!
								local u = math.clamp(attackElapsed / 0.36, 0, 1)
								local whip = math.sin(u * math.pi)
								if comboStep == 1 then
									-- Rapid Right Cross-Slash
									if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(124 - 110 * u), math.rad(-42 * whip), math.rad(36 - 68 * u)) end
									if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(32), 0, 0) end
									if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(-24), 0, math.rad(-24)) end
									if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(56), 0, 0) end
									if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-20), math.rad(38 * whip), 0) end
									if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(16), math.rad(-32 * whip), 0) end
								elseif comboStep == 2 then
									-- Rapid Left Counter-Slash
									if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(124 - 110 * u), math.rad(42 * whip), math.rad(-36 + 68 * u)) end
									if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(32), 0, 0) end
									if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(-24), 0, math.rad(24)) end
									if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(56), 0, 0) end
									if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-20), math.rad(-38 * whip), 0) end
									if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(16), math.rad(32 * whip), 0) end
								else
									-- Twin X-Slash Execution (both tanto cross inward then blast wide open!)
									local open = easeOutCubic(u)
									if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(110 - 54 * open), math.rad(-34 + 68 * open), math.rad(-26 + 86 * open)) end
									if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(110 - 54 * open), math.rad(34 - 68 * open), math.rad(26 - 86 * open)) end
									if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(38 - 18 * open), 0, 0) end
									if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(38 - 18 * open), 0, 0) end
									if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-24 + 14 * open), 0, 0) end
									if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(18 - 10 * open), 0, 0) end
								end
							elseif combatStyle == "Melee" then
								-- Heavy Street Cleaver / Spatula Overhead Smash
								local u = math.clamp(attackElapsed / 0.42, 0, 1)
								local rPitch = if u < 0.25 then (70 + 86 * (u / 0.25)) else (156 - 148 * easeOutCubic((u - 0.25) / 0.75))
								local whip = math.sin(u * math.pi)
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(rPitch), math.rad(-14 * whip), math.rad(14)) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(32), 0, 0) end
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(-12 + 24 * whip), 0, math.rad(-18)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(46), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-14 * whip), math.rad(26 * whip), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(8), math.rad(-18 * whip), 0) end
							else
								-- REALISTIC FIREARM AIM & RECOIL KICK (Rifle / Pistol / Shield!)
								local u = math.clamp(attackElapsed / 0.34, 0, 1)
								local kick = math.sin(math.min(1, u * 3.2) * math.pi) * math.exp(-3.4 * u)
								if combatStyle == "Shield" then
									-- Ballistic Shield braced defensively forward while Shotgun fires over rim!
									if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(68), math.rad(42), math.rad(-10)) end
									if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(48), 0, 0) end
									if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(86 + 24 * kick), math.rad(-8), math.rad(6)) end
									if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(18 + 18 * kick), 0, 0) end
									if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-6 + 10 * kick), math.rad(-18), 0) end
									if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(4 + 6 * kick), math.rad(16), 0) end
								elseif combatStyle == "Pistol" then
									-- Two-Handed Weaver Pistol Stance with snappy wrist/shoulder kick!
									if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(88 + 20 * kick), math.rad(-14), math.rad(4)) end
									if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(12 + 16 * kick), 0, 0) end
									if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(82 + 18 * kick), math.rad(34), math.rad(-6)) end
									if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(28 + 14 * kick), 0, 0) end
									if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-5 + 8 * kick), math.rad(-14), 0) end
									if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(4 + 5 * kick), math.rad(14), 0) end
								else
									-- Tactical Two-Handed Shoulder-Braced Rifle/SMG/Sniper Firing + Recoil Impulse!
									if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(84 + 18 * kick), math.rad(-12), math.rad(8)) end
									if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(22 + 16 * kick), 0, 0) end
									if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(76 + 16 * kick), math.rad(42), math.rad(-8)) end
									if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(44 + 12 * kick), 0, 0) end
									if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-7 + 9 * kick), math.rad(-22), 0) end
									if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(4 + 5 * kick), math.rad(20), math.rad(-6)) end
								end
							end
						elseif speed > 0.8 then
							local freq = math.clamp(speed * 0.56, 7.2, 13.5)
							local phase = elapsed * freq
							local stride = math.sin(phase) * math.rad(36)
							local lKneeBend = -math.max(0, math.cos(phase)) * math.rad(46)
							local rKneeBend = -math.max(0, -math.cos(phase)) * math.rad(46)
							local armSwing = math.sin(phase) * math.rad(28)
							if lh and lh:IsA("Motor6D") then lh.Transform = CFrame.Angles(-stride, 0, 0) end
							if rh and rh:IsA("Motor6D") then rh.Transform = CFrame.Angles(stride, 0, 0) end
							if lk and lk:IsA("Motor6D") then lk.Transform = CFrame.Angles(lKneeBend, 0, 0) end
							if rk and rk:IsA("Motor6D") then rk.Transform = CFrame.Angles(rKneeBend, 0, 0) end
							if waiterState == "CarryingTray" then
								-- Waiter holds silver serving tray proudly steady & level while briskly walking to table!
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(armSwing * 0.55, 0, math.rad(-6)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(24), 0, 0) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(62), 0, math.rad(8)) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(34), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-3), math.sin(phase) * math.rad(3), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(2), 0, 0) end
							elseif combatStyle == "DualNinja" then
								-- Authentic Low-Crouched Shinobi Sprint (arms swept back holding twin tanto!)
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(-42) + armSwing * 0.25, 0, math.rad(-16)) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(-42) - armSwing * 0.25, 0, math.rad(16)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(26), 0, 0) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(26), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-22), math.sin(phase) * math.rad(7), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(18), 0, 0) end
							elseif combatStyle == "Katana" then
								-- Disciplined Samurai Combat Sprint (Katana gripped low-ready, focused torso!)
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(36) + armSwing * 0.35, math.rad(14), math.rad(-6)) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(52) - armSwing * 0.2, math.rad(-10), math.rad(8)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(42), 0, 0) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(38), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-10), math.sin(phase) * math.rad(6), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(8), 0, 0) end
							elseif combatStyle == "Shield" then
								-- Heavy Breacher March (Ballistic shield held forward protecting chest!)
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(60), math.rad(36), math.rad(-8)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(44), 0, 0) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(62) - armSwing * 0.2, 0, math.rad(8)) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(28), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-6), math.rad(-10), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(4), math.rad(10), 0) end
							elseif combatStyle == "Rifle" or combatStyle == "Pistol" then
								-- Tactical High-Ready Firearm Advance (both hands gripping weapon across chest!)
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(58) + armSwing * 0.15, math.rad(34), math.rad(-6)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(44), 0, 0) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(66) - armSwing * 0.15, math.rad(-10), math.rad(6)) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(28), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-7), math.rad(-12) + math.sin(phase) * math.rad(4), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(5), math.rad(10), 0) end
							else
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(armSwing, 0, math.rad(-4)) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(-armSwing * 0.55 + math.rad(22), 0, math.rad(4)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(24) + math.max(0, armSwing) * 0.6, 0, 0) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(32), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-4), math.sin(phase) * math.rad(6), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(3), -math.sin(phase) * math.rad(4), 0) end
							end
						else
							-- Weapon-Matched Alert Combat-Ready Idle Stance (living breathing, alert head scan!)
							local breath = math.sin(elapsed * 2.2 + phaseSeed)
							if combatStyle == "Katana" then
								-- Chudan-no-kamae Samurai Guard
								if lh and lh:IsA("Motor6D") then lh.Transform = CFrame.Angles(math.rad(12), 0, math.rad(-4)) end
								if rh and rh:IsA("Motor6D") then rh.Transform = CFrame.Angles(math.rad(-10), 0, math.rad(4)) end
								if lk and lk:IsA("Motor6D") then lk.Transform = CFrame.Angles(math.rad(-14), 0, 0) end
								if rk and rk:IsA("Motor6D") then rk.Transform = CFrame.Angles(math.rad(-12), 0, 0) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(62 + breath * 2.5), math.rad(-14), math.rad(6)) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(32), 0, 0) end
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(54 + breath * 2.5), math.rad(28), math.rad(-10)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(42), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-4 + breath * 1.5), math.rad(-14), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(4), math.rad(14) + math.sin(elapsed * 0.9 + phaseSeed) * math.rad(8), 0) end
							elseif combatStyle == "DualNinja" then
								-- Predatory Crouched Shinobi Guard
								if lh and lh:IsA("Motor6D") then lh.Transform = CFrame.Angles(math.rad(22), 0, math.rad(-6)) end
								if rh and rh:IsA("Motor6D") then rh.Transform = CFrame.Angles(math.rad(-18), 0, math.rad(6)) end
								if lk and lk:IsA("Motor6D") then lk.Transform = CFrame.Angles(math.rad(-26), 0, 0) end
								if rk and rk:IsA("Motor6D") then rk.Transform = CFrame.Angles(math.rad(-22), 0, 0) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(48 + breath * 3), math.rad(-16), math.rad(14)) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(48), 0, 0) end
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(-18 + breath * 3), math.rad(12), math.rad(-18)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(54), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-14 + breath * 2), math.rad(10), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(12), math.rad(-10) + math.sin(elapsed * 1.2 + phaseSeed) * math.rad(10), 0) end
							elseif combatStyle == "Shield" then
								-- Heavy Riot Shield Ready Stance
								if lh and lh:IsA("Motor6D") then lh.Transform = CFrame.Angles(math.rad(10), 0, math.rad(-4)) end
								if rh and rh:IsA("Motor6D") then rh.Transform = CFrame.Angles(math.rad(-8), 0, math.rad(4)) end
								if lk and lk:IsA("Motor6D") then lk.Transform = CFrame.Angles(math.rad(-12), 0, 0) end
								if rk and rk:IsA("Motor6D") then rk.Transform = CFrame.Angles(math.rad(-10), 0, 0) end
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(64 + breath * 2), math.rad(38), math.rad(-10)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(46), 0, 0) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(68 + breath * 2), math.rad(-6), math.rad(6)) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(24), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-4 + breath * 1.4), math.rad(-16), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(3), math.rad(14) + math.sin(elapsed * 0.8 + phaseSeed) * math.rad(7), 0) end
							elseif combatStyle == "Rifle" or combatStyle == "Pistol" then
								-- Tactical Low-Ready / Aiming Stance
								local aimLift = if inCombatRecent then 18 else 0
								if lh and lh:IsA("Motor6D") then lh.Transform = CFrame.Angles(math.rad(8), 0, math.rad(-4)) end
								if rh and rh:IsA("Motor6D") then rh.Transform = CFrame.Angles(math.rad(-8), 0, math.rad(4)) end
								if lk and lk:IsA("Motor6D") then lk.Transform = CFrame.Angles(math.rad(-10), 0, 0) end
								if rk and rk:IsA("Motor6D") then rk.Transform = CFrame.Angles(math.rad(-10), 0, 0) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(62 + aimLift + breath * 2), math.rad(-12), math.rad(6)) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(26), 0, 0) end
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(56 + aimLift + breath * 2), math.rad(38), math.rad(-6)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(42), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-4 + breath * 1.5), math.rad(-18), 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(3), math.rad(16) + math.sin(elapsed * 0.85 + phaseSeed) * math.rad(8), 0) end
							else
								-- Natural living idle breathing & subtle stance sway
								if lh and lh:IsA("Motor6D") then lh.Transform = CFrame.identity end
								if rh and rh:IsA("Motor6D") then rh.Transform = CFrame.identity end
								if lk and lk:IsA("Motor6D") then lk.Transform = CFrame.identity end
								if rk and rk:IsA("Motor6D") then rk.Transform = CFrame.identity end
								if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(4), 0, math.rad(-3 - breath * 1.5)) end
								if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(16), 0, math.rad(3 + breath * 1.5)) end
								if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(14), 0, 0) end
								if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(24), 0, 0) end
								if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(breath * 1.8), 0, 0) end
								if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(0, math.sin(elapsed * 0.7) * math.rad(6), 0) end
							end
						end
					else
						local swing = if speed > 0.8 then math.sin(elapsed * 8.5) * math.rad(34) else 0
						local la = root:FindFirstChild("LeftArmJoint")
						local ra = root:FindFirstChild("RightArmJoint")
						local ll = root:FindFirstChild("LeftLegJoint")
						local rl = root:FindFirstChild("RightLegJoint")
						if la and la:IsA("Motor6D") then la.Transform = CFrame.Angles(swing, 0, 0) end
						if ra and ra:IsA("Motor6D") then ra.Transform = CFrame.Angles(-swing + math.rad(16), 0, 0) end
						if ll and ll:IsA("Motor6D") then ll.Transform = CFrame.Angles(-swing, 0, 0) end
						if rl and rl:IsA("Motor6D") then rl.Transform = CFrame.Angles(swing, 0, 0) end
					end
				end
			end
		end
		for _, rival in ipairs(CollectionService:GetTagged("RivalAIUnit")) do
			animateMarchingUnit(rival)
		end
		for _, mafia in ipairs(CollectionService:GetTagged("MafiaUnit")) do
			animateMarchingUnit(mafia)
		end
		for _, cust in ipairs(CollectionService:GetTagged("AnimatedCustomerLimbs")) do
			animateMarchingUnit(cust)
		end
		for _, raider in ipairs(CollectionService:GetTagged("AnimatedRaiderLimbs")) do
			animateMarchingUnit(raider)
		end

		-- 4a. Realistic 60 FPS Commercial Kitchen Chef Animations (Tossing Sauté Pan, Searing, Chopping & Plating!)
		for _, chef in ipairs(CollectionService:GetTagged("AnimatedKitchenChef")) do
			if chef:IsA("Model") then
				local upperTorso = chef:FindFirstChild("UpperTorso")
				local head = chef:FindFirstChild("Head")
				local lUpperArm = chef:FindFirstChild("LeftUpperArm")
				local rUpperArm = chef:FindFirstChild("RightUpperArm")
				local lLowerArm = chef:FindFirstChild("LeftLowerArm")
				local rLowerArm = chef:FindFirstChild("RightLowerArm")
				local waist = if upperTorso then upperTorso:FindFirstChild("Waist") else nil
				local neck = if head then head:FindFirstChild("Neck") else nil
				local ls = if lUpperArm then lUpperArm:FindFirstChild("LeftShoulder") else nil
				local rs = if rUpperArm then rUpperArm:FindFirstChild("RightShoulder") else nil
				local le = if lLowerArm then lLowerArm:FindFirstChild("LeftElbow") else nil
				local re = if rLowerArm then rLowerArm:FindFirstChild("RightElbow") else nil

				local action = tostring(chef:GetAttribute("ChefAction") or "Searing")
				local idx = tonumber(chef:GetAttribute("ChefIndex")) or 1
				local seed = idx * 1.45

				if action == "TossingPan" then
					local toss = math.sin(elapsed * 5.8 + seed)
					local flick = math.max(0, toss)
					if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(42 + flick * 36), 0, math.rad(6)) end
					if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(28 + flick * 34), 0, 0) end
					-- Left hand sprinkles seasoning over the sizzling pan!
					local sprinkle = math.sin(elapsed * 10.5 + seed)
					if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(62 + sprinkle * 12), math.rad(14), math.rad(-10)) end
					if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(54), 0, 0) end
					if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-8 - flick * 4), math.sin(elapsed * 2.4 + seed) * math.rad(6), 0) end
					if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(-14 + flick * 8), 0, 0) end
				elseif action == "Chopping" then
					local chop = math.sin(elapsed * 12.0 + seed)
					if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(48 + chop * 18), math.rad(-8), math.rad(6)) end
					if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(44 + chop * 26), 0, 0) end
					if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(46), math.rad(12), math.rad(-8)) end
					if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(42), 0, 0) end
					if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-10), math.sin(elapsed * 1.8 + seed) * math.rad(5), 0) end
					if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(-18), 0, 0) end
				elseif action == "Plating" then
					local sweep = math.sin(elapsed * 3.2 + seed)
					if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(52), math.rad(sweep * 18), math.rad(8)) end
					if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(46 + math.abs(sweep) * 16), 0, 0) end
					if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(48), math.rad(-sweep * 14), math.rad(-8)) end
					if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(42), 0, 0) end
					if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-7), sweep * math.rad(12), 0) end
					if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(-12), sweep * math.rad(10), 0) end
				else
					-- Searing / Stirring smoothly over stove flames
					local stir = math.sin(elapsed * 4.6 + seed)
					local stirY = math.cos(elapsed * 4.6 + seed)
					if rs and rs:IsA("Motor6D") then rs.Transform = CFrame.Angles(math.rad(46 + stir * 14), math.rad(stirY * 14), math.rad(6)) end
					if re and re:IsA("Motor6D") then re.Transform = CFrame.Angles(math.rad(36 + stir * 12), 0, 0) end
					if ls and ls:IsA("Motor6D") then ls.Transform = CFrame.Angles(math.rad(38 - stir * 8), math.rad(10), math.rad(-6)) end
					if le and le:IsA("Motor6D") then le.Transform = CFrame.Angles(math.rad(34), 0, 0) end
					if waist and waist:IsA("Motor6D") then waist.Transform = CFrame.Angles(math.rad(-8), stir * math.rad(7), 0) end
					if neck and neck:IsA("Motor6D") then neck.Transform = CFrame.Angles(math.rad(-14), stirY * math.rad(8), 0) end
				end
			end
		end

		-- 4b. 60 FPS Articulated Death Collapse Animations for Rivals, Bodyguards & Mafia
		local serverNow = Workspace:GetServerTimeNow()
		for _, dying in ipairs(CollectionService:GetTagged("DyingNPCUnit")) do
			if dying:IsA("Model") then
				animateDyingNPC(dying, serverNow)
			end
		end
		for m in pairs(dyingDustPlayed) do
			if not m.Parent then
				dyingDustPlayed[m] = nil
				dyingOrigTrans[m] = nil
			end
		end
		for m in pairs(npcPrevHealth) do
			if not m.Parent then
				npcPrevHealth[m] = nil
				npcFlinchStart[m] = nil
				npcFlinchSide[m] = nil
			end
		end

		-- 4c. Spin 3D Delivery Motorbike Wheels & Central Market Lucky Spin Wheel smoothly at 60 FPS
		for _, bikeNpc in ipairs(CollectionService:GetTagged("AnimatedMotorbikeWheels")) do
			if bikeNpc:IsA("Model") and bikeNpc:GetAttribute("IsDying") ~= true then
				local root = bikeNpc:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local vel = root.AssemblyLinearVelocity
					local spd = Vector3.new(vel.X, 0, vel.Z).Magnitude
					local fw = root:FindFirstChild("FrontWheelJoint")
					local rw = root:FindFirstChild("RearWheelJoint")
					local spin = CFrame.Angles(-elapsed * math.max(0, spd) * 0.72, 0, 0)
					if fw and fw:IsA("Motor6D") then fw.Transform = spin end
					if rw and rw:IsA("Motor6D") then rw.Transform = spin end
				end
			end
		end

		for _, wheelPart in ipairs(CollectionService:GetTagged("SpinningMarketWheel")) do
			if wheelPart:IsA("BasePart") then
				wheelPart.CFrame = wheelPart.CFrame * CFrame.Angles(0, 0, dt * 0.65)
			end
		end

		-- 5. Hustle Master Pro Chef, Elite Sous-Chefs & Crew Chefs lively at the kitchen!
		local chefIdx = 0
		for _, chef in ipairs(CollectionService:GetTagged("AnimatedKitchenChef")) do
			if chef:IsA("Model") and chef.PrimaryPart then
				chefIdx += 1
				local basePiv = kitchenBasePivots[chef]
				if not basePiv then
					basePiv = chef:GetPivot()
					kitchenBasePivots[chef] = basePiv
				end
				local isMaster = (chef.Name == "MasterProChef_NPC")
				local phase = elapsed * (if isMaster then 2.4 else 1.8) + chefIdx * 1.3
				local hustleX = if isMaster then math.sin(phase * 0.65) * 6.2 else math.sin(phase * 0.5) * 1.4
				local bounceY = math.abs(math.sin(phase * 2.2)) * (if isMaster then 0.55 else 0.25)
				local turnYaw = if isMaster then math.cos(phase * 0.65) * math.rad(28) else math.sin(phase * 0.5) * math.rad(12)
				chef:PivotTo(basePiv * CFrame.new(hustleX, bounceY, 0) * CFrame.Angles(0, turnYaw, 0))
			end
		end
	end)
end

function AmbientEffectsController.Stop(): ()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

return AmbientEffectsController
