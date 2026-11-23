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
	local cachedSailboats = false
	local searchCooldown = 0
	local elapsed = 0

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

		-- 4. Animate Rival Chef & Player Raider Chef full-body walking limbs smoothly at 60 FPS
		local function animateMarchingUnit(unit: Instance)
			if unit:IsA("Model") then
				local root = unit:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local vel = root.AssemblyLinearVelocity
					local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
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
